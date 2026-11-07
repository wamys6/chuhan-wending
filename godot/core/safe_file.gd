class_name SafeFile
## 原子文件读写：先写 .tmp，再 rename 覆盖。任何时刻磁盘上都有一份完整文件。
##
## 为什么需要：直接 `FileAccess.open(path, FileAccess.WRITE)` 是「先截断再写」。
## 断电 / 强退 / 磁盘满 落在写入过程中，磁盘上就留下一个半截 JSON；而读取端的容错
## 是「静默回退到空档」——玩家看到图鉴清零、三个存档位全空，还以为游戏出了 bug。
##
## 语义：
##   write() 成功 = 磁盘上已经是完整的新内容；失败 = 旧内容原样保留。
##   read()  主文件坏 → 备份成 .corrupt → 回退 .tmp（自愈）→ 再回退空串。

const TMP_SUFFIX := ".tmp"
const BAK_SUFFIX := ".corrupt"


static func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p)


## 原子写入。返回 false 时调用方应当认为「这次没保存成功」，但旧数据仍在。
static func write(path: String, text: String) -> bool:
	var tmp := path + TMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SafeFile: 无法写入 %s" % tmp)
		return false
	f.store_string(text)
	f.close()
	# 磁盘满会静默截断：读回长度对不上就放弃，旧文件保持不动
	var back := FileAccess.get_file_as_string(tmp)
	if back.length() != text.length():
		push_warning("SafeFile: 写入不完整（%d/%d），已放弃 %s" % [back.length(), text.length(), path])
		DirAccess.remove_absolute(_abs(tmp))
		return false
	# 同目录 rename 是原子替换；实测 Windows 上目标已存在也能覆盖
	if DirAccess.rename_absolute(_abs(tmp), _abs(path)) != OK:
		push_warning("SafeFile: 替换失败 %s（临时文件保留）" % path)
		return false
	return true


## 读原文。主文件缺失/为空时回退上次没来得及 rename 的 .tmp。
## 注意：这里**不清理** .tmp —— 主文件可能只是「非空但坏」，要等 read_dict 解析成功
## 才能确定它真的可用（第一版在这里删了 tmp，坏主文件就没得救了）。
static func read(path: String) -> String:
	var tmp := path + TMP_SUFFIX
	if FileAccess.file_exists(path):
		var s := FileAccess.get_file_as_string(path)
		if not s.is_empty():
			return s
	if FileAccess.file_exists(tmp):
		push_warning("SafeFile: 主文件缺失或为空，回退到 %s" % tmp)
		return FileAccess.get_file_as_string(tmp)
	return ""


## 读 JSON 字典。解析失败时备份坏档并返回空字典（调用方按「无数据」处理，不崩）。
static func read_dict(path: String) -> Dictionary:
	var text := read(path)
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		purge_tmp(path)   # 主文件确认可用，清掉上次残留
		return parsed
	_backup_corrupt(path, text)
	# 主文件坏了但上次的 .tmp 是好的：直接提升它，自愈
	var tmp := path + TMP_SUFFIX
	if FileAccess.file_exists(tmp):
		var p2 = JSON.parse_string(FileAccess.get_file_as_string(tmp))
		if typeof(p2) == TYPE_DICTIONARY:
			DirAccess.rename_absolute(_abs(tmp), _abs(path))
			push_warning("SafeFile: 已用临时文件修复 %s" % path)
			return p2
	return {}


## 坏档留证：只保留第一次的那份，别让后续启动把它覆盖掉。
static func _backup_corrupt(path: String, text: String) -> void:
	var bak := path + BAK_SUFFIX
	if FileAccess.file_exists(bak):
		return
	var f := FileAccess.open(bak, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
	push_warning("SafeFile: %s 解析失败，已备份到 %s" % [path, bak])


## 清理临时文件（测试用；正常运行不需要）
static func purge_tmp(path: String) -> void:
	var tmp := path + TMP_SUFFIX
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(_abs(tmp))
