# 《楚汉·问鼎》使用文档

> 更新：2026-11-02。给两类人看：**玩游戏的**（第一部分）和**日常开发的你**（第二部分）。
> 环境搭建与架构原理见 [technical.md](technical.md)，往后做什么见 [next-steps.md](next-steps.md)。

---

# 第一部分 · 玩游戏

## 1. 启动

- **正式版**：双击 `godot/export/ChuHanWenDing.exe`（单文件、免安装，约 300MB，这就是将来上传 Steam 的东西）。
- **开发预览**：Godot 编辑器打开 `godot/project.godot` 按 F5；或命令行 `<GODOT> --path godot`。

窗口默认 1440×900，任意缩放/全屏自适应，右下角设置里可切全屏。

## 2. 主菜单功能

| 入口 | 说明 |
|---|---|
| **战役** | 主玩法：8 关楚汉征程（沛县起兵→鸿门宴→彭城→荥阳→井陉→潍水→固陵→垓下），打完每关三选一加牌，通关有结局叙事 |
| **快速开战** | 单局对战 AI，三档难度，开局可换牌（mulligan），刘邦 30 血续航 vs 项羽 26 血强攻 |
| **联机对战** | 与朋友在线对战，见 §4 |
| **图鉴** | 全部卡牌、成就业绩、生涯战绩（含 PvP 胜负） |
| **设置** | 音量/静音/动效开关（晕动症友好）/全屏/语言（中/英） |

三个存档槽独立保存战役进度，主菜单和战役地图顶部都能切换。

## 3. 战斗规则 30 秒上手

- 炉石式回合制：每回合军粮（法力）递增，出兵、施放主将技能（1 费）、点「结束回合」。
- **三列军阵**：前锋/中军/后备，兵种有守御（挡刀）、迂回（越列攻击）、远程（不打前锋）特性。
- 关键关键词：**冲锋**（登场当回合即可攻击）、**死战**（阵亡时触发）、**连击**（本回合已出过牌时增强）。
- 军粮见顶后进入疲劳：每回合开始扣血，速战速决。
- 每回合 60 秒行动计时（联机时强制，单机也有提示）。
- 打不过可以 Esc → 暂停菜单 → 放弃本局（**同样消耗一次重整机会**）。
- **重整机会**：每关只有 1 次。第一次兵败（或放弃）回地图，这一关可以再打一次；
  同一关第二次兵败 → 本局终结，该存档位清空，回存档位重开（成就与生涯记录不受影响）。
  过场页会写「本关重整：尚有一次 / 已用完 · 再败即终局」，出征前能看见。

## 4. 联机对战（PvP）

中继服务器已上线：`ws://<你的服务器IP>:27775`（游戏内已预填，无需修改）。

1. 两人都打开游戏 → 主菜单 → **联机对战**；
2. 一方点「建房」→ 屏幕出现 **6 位房间码**（如 `GT92CX`）→ 发给对方（微信/QQ）；
3. 对方点「加入」输入房间码 → 自动进入对战；
4. 选边：房主选楚或汉，对方自动拿另一边；卡组为统一对等卡组（休闲模式，无天梯无段位）；
5. 对局中可发六句快捷短语交流；断线后 **90 秒内重进房间码即可续打**（进度不丢）；对方掉线会显示等待浮层。

运维排查（打不开/连不上时）：看 `docs/technical.md` §八，`node tools/pvp-live-test.js` 一条命令验证中继是否存活。

## 5. 新手引导

首次进入战斗有 6 步聚光灯引导 + 悬停卡牌出详细浮层；语言切英文后引导同步切换。

---

# 第二部分 · 日常开发操作

以下 `<GODOT>` 指 Godot 4.7.2 控制台版 exe 路径（本机为 `D:/godot/Godot_v4.7.2-stable_win64_console.exe`；在 WorkBuddy 终端里要加 `env -u ELECTRON_RUN_AS_NODE` 前缀）。

## 6. 跑游戏与看画面

```bash
<GODOT> --path godot                          # 正常游玩（开发预览）
<GODOT> --path godot --resolution 1920x1080 -- --tour   # 全场景截图巡览 → godot/tests/_gd-*.png
<GODOT> --path godot -- --shot battle         # 单场景截图（场景名: menu/battle/map/lobby/...）
```

⚠️ **自定义参数必须写在 `--` 之后**：Godot 4.7 只把 `--` 之后的参数交给 `OS.get_cmdline_user_args()`。
写成 `--path godot --tour` 不会报错，但会静默进主菜单（看起来像「巡览坏了」）。

`--tour` 出的截图是验收 UI 改动的标准手段：改完界面跑一遍，对照旧图看有没有布局回归。

## 7. 跑测试

```bash
# 最小回归集（改任何规则/数值/界面后必跑，约 1-2 分钟）
<GODOT> --headless --path godot --script res://tests/replay.gd
<GODOT> --headless --path godot --script res://tests/campaign_test.gd
<GODOT> --headless --path godot --script res://tests/pvp_test.gd
<GODOT> --headless --path godot --script res://tests/battle_ui_test.gd

# 大改动跑全套（audio/codex/tutorial/i18n/battle_ui + campaign --flow），合计 ≈990 项
for t in replay campaign_test audio_test codex_test tutorial_test i18n_test pvp_test battle_ui_test; do
  <GODOT> --headless --path godot --script res://tests/$t.gd
done

# 全流程 E2E（真实点击流，走 App 启动参数）
<GODOT> --headless --path godot -- --flow
```

每项脚本末尾输出「通过 N 项，失败 M 项」，**M 不为 0 就回滚或修**。测试明细见 technical.md §六。

## 8. 改数值、加卡牌（最高频操作）

1. 打开 `js/data.js`（卡牌/军师/事件的**唯一数据源**）或 `js/campaign.js`（关卡参数）；
2. 改完执行 `node tools/export-data.js` → 自动生成 `godot/data/game.json`；
3. 跑最小回归集（§7）；
4. 平衡性检查：`node test/simulate.js`（全量对局）或 `node test/tune-8.js`（战役通关率曲线，基线 ≈70/75/30/55/55/50/40/35）。

⚠️ 不要直接编辑 `godot/data/game.json`——下次导出会被覆盖。加新卡还须登记立绘（technical.md §五）。

## 9. 改文案与翻译

- 界面新增中文：GDScript 里用 `I18n.T("...")` 包装，并在 `godot/data/lang-godot-en.json` 补英文键；
- 数据层英文覆盖改 `js/lang-en.js` → `node tools/export-i18n.js`；
- 完工后 `node legacy/checks/lang-ui-check.js` 扫描（`CHROME=` 指浏览器）英文模式是否残留中文（需 Chrome CDP）。

## 10. 出正式包

```bash
mkdir -p godot/export          # 已存在则跳过
<GODOT> --headless --path godot --export-release "Windows Desktop" export/ChuHanWenDing.exe
```

双击 exe 冒烟：进主菜单 → 快速开战一局 → 联机建房一次 → 设置里切英文再切回来。全 OK 即为可用包。

## 11. 服务器与联机运维

```bash
# 公网验收（本机跑，ALL_PASS 即中继正常）
node tools/pvp-live-test.js

# 更新中继脚本
pscp tools/relay.js root@<你的服务器IP>:/opt/chuhan-relay/relay.js
ssh root@<你的服务器IP> "systemctl restart chuhan-relay"
```

## 12. 开发循环建议（给自己立的规矩）

1. 动手前读 `docs/technical.md` §四（确定性）——理解了它才知道为什么测试这么写；
2. **小步提交**：一次只改一类东西（数值/表现/逻辑），改完立刻跑最小回归集；
3. 界面改动必跑 `--tour` 对照截图；
4. 联机相关改动必跑 `pvp_test.gd`（它会自动起真服务器打完整局，比手测可信）；
5. 踩到新坑，写进 technical.md §九——那份清单就是项目的救命稻草。
