# 《楚汉·问鼎》技术文档

> 更新：2026-11-02。用途：在任何一台新机器上快速理解并继续开发本项目。
> 配套文档：[user-guide.md](user-guide.md)（使用/日常操作）、[next-steps.md](next-steps.md)（开发计划）、
> [chuhan-card-game-design.md](chuhan-card-game-design.md)（玩法设定）、[roadmap.md](roadmap.md)（战略路线）、[pvp-design.md](pvp-design.md)（联机设计）。

---

## 一、项目一句话

楚汉争霸题材的水墨卡牌 roguelike，主玩法为 8 关 PvE 战役（沛县起兵→垓下），附属「快速开战」单局对战 AI 与**在线 PvP（锁步 WebSocket 中继）**。目标平台 Steam（Windows）。

当前状态：**Godot 主工程功能完整，v0.9.3（卡池 78 + 初阵档位）**，全量回归 **2131 项 + E2E 19 项**全绿，导出单文件约 142MB exe 可直传 Steam。旧 JS/Web 版保留作数值参照与等价性基准。

## 二、新机器环境搭建 Checklist

| # | 要装什么 | 说明 |
|---|---|---|
| 1 | **Godot 4.7.2**（Windows Desktop，建议 `_console.exe` 版） | 测试依赖命令行输出。原机器装在 `D:\godot\`，新机器路径随意，下文用 `<GODOT>` 代指 |
| 2 | **Node.js ≥ 18** | 跑 tools/ 下的脚本（数据导出、中继、录制） |
| 3 | `npm install`（在项目根执行） | 主要为了 `ws` 包（中继/冒烟测试用） |
| 4 | **Godot 4.7.2 导出模板** | 编辑器里「编辑器→管理导出模板」下载；若官方源被墙，用镜像 `https://gh-proxy.com/` 前缀拼 GitHub release 地址。**只需解压 windows x86_64 相关的四个文件** |
| 5 | （可选）Electron | 旧 Web 版桌面壳，已被 Godot 导出取代，仅留作对照，可不装 |

**WorkBuddy 沙箱特有坑**：在 WorkBuddy 的终端里跑 Godot 必须加 `env -u ELECTRON_RUN_AS_NODE` 前缀，否则 Godot 会被当成 Node 执行。普通 CMD/PowerShell 不需要。

验证环境是否 OK（三条命令全绿即可开工）：

```bash
<GODOT> --headless --path godot --script res://tests/replay.gd     # 应输出 541 项通过
node tools/relay-smoke.js                                          # 应输出 13 项通过
```

## 三、目录结构

```
cardgame/
├── godot/                  ★ 主工程（一切新开发都在这里）
│   ├── project.godot       autoload: App(core/app.gd)、Pvp(core/net.gd)
│   ├── core/               逻辑层（见下表）
│   ├── scenes/             场景：menu/slots/campaign_map/stage_intro/battle/
│   │                       reward/advisor/event/ending/codex/lobby/boot
│   ├── ui/                 表现组件：unit_view/card_view/card_tip/coach/
│   │                       settings_panel/ui_theme/widgets/card_art/keyword_stamp
│   ├── data/               game.json（全部数值单源）+ lang-en.json + lang-godot-en.json
│   ├── assets/cards/       115 张 AI 水墨立绘（约 348MB，不进包，只打包 .ctex）
│   ├── fonts/              内置 Noto Serif SC（OFL 许可，勿删 LICENSE）
│   ├── tests/              Godot 测试 + fixtures/trace.json（等价性基准）
│   ├── export/             导出产物 ChuHanWenDing.exe（约 146MB）
│   └── export_presets.cfg  embed_pck、include_filter="*.json"、exclude tests/*
├── js/                     ★ 数据单源 + 旧 Web 版逻辑（见 §五）：data/engine/ai/campaign/
│                           codex/i18n/lang-en/tutorial —— 导出与录制工具都读它，不可删
├── legacy/                 已冻结的网页版（只读，别在这里加功能）
│   ├── web/                index.html + css + ui.js/audio.js + electron 壳（可直接双击运行）
│   └── checks/             网页版的浏览器验收脚本（uicheck/flow/art-check/…，需 CHROME 环境变量）
├── test/                   JS 数值测试与调参脚本（campaign 1828 项、tune-* 全在这）
├── tools/                  node 脚本：relay.js 中继（含 /health）/ trace.js 录制 /
│                           export-data.js / export-i18n.js / relay-smoke.js / pvp-live-test.js
├── docs/                   全部文档
└── package.json            ws 依赖 + 已弃用的 electron 打包脚本（main 指向 legacy/web）
```

### godot/core/ 各文件职责

| 文件 | 职责 |
|---|---|
| `app.gd` | **全局路由**。场景切换、命令行参数（`--headless`/`--shot`/`--tour`/`--relay` 等）、战役进度装配、巡览截图 |
| `rules_engine.gd` | **规则引擎**（炉石式骨架+三列军阵/军粮/守御/迂回/远程/疲劳/先机/冲锋/死战/连击）。注意 `rng` 是静态成员 |
| `rng.gd` | xorshift32 确定性随机数，与 `tools/trace.js` 里的 JS 实现逐位一致 |
| `ai.gd` | 三档难度 AI，名将档会算斩杀 |
| `campaign.gd` | 战役进度/3 存档位（chuhan_slots）/战后三选一奖励/军师 5 选 3/行军事件（16 个）/`engineRules()` 关卡参数合并 |
| `game_data.gd` | 加载 data/game.json（卡牌 78/军师 8/事件 16/关卡 8/心魔 3/天时 6） |
| `net.gd`（autoload 名 Pvp） | WebSocket 客户端状态机：OFF→CONNECTING→LOBBY→IN_ROOM/WAITING；seq 逐条校验防分叉；`process_mode=ALWAYS` |
| `settings.gd` | 音量/动效/全屏/语言/`pvp_relay`（默认 `ws://<你的服务器IP>:27775`） |
| `i18n.gd` | `T()` 收口翻译、`set_lang()`（落盘）/`set_lang_soft()`（仅内存，巡览用） |
| `codex.gd` | 图鉴+成就业绩+PvP 战绩（pvpWins/pvpLosses） |
| `audio.gd` | BGM/SFX 双总线、程序化音效、tension 动态变速 |
| `tutorial.gd` | KEYWORDS 新手引导数据（**必须在 lang-en 之前加载**） |
| `log_text.gd` / `rng.gd` | 战报文本 / 随机数 |

## 四、核心机制：确定性 + 锁步联机

这是全项目最重要的架构决策，**改任何规则代码前必须理解**：

1. **一切随机都走 `Rng.new(seed)`**（xorshift32）。同一个 seed + 同一串动作 = 完全相同的对局。
2. **跨语言等价性测试**：`node tools/trace.js` 让旧 JS 版用固定 seed 打一整局并录制全部动作+每回合状态指纹 → `godot/tests/fixtures/trace.json`；`replay.gd` 在 Godot 侧盲放并逐帧比对指纹。改规则若只有一边改了，这里立刻红。
3. **PvP 锁步**：两端各跑完整引擎，网络只传「玩家动作」（出牌/攻击/结束回合），不传任何状态。中继服务器（`tools/relay.js`）只做转发+留动作日志（供断线重连补放）。seq 逐条校验，指纹不一致立即断开。
4. **`RulesEngine.rng` 是静态成员**：同一进程内开两个引擎实例必须各自注入 `Rng.new(seed)`，否则共享状态会分叉（pvp_test 曾因此重写为「先录后放」架构）。

## 五、数据流：改数值的正确姿势

```
js/data.js（卡牌/英雄/军师/事件的数据源）
js/campaign.js（关卡规则参数）
        │  node tools/export-data.js
        ▼
godot/data/game.json  ──FileAccess──▶ game_data.gd（include_filter 必须含 *.json）

js/lang-en.js ──node tools/export-i18n.js──▶ godot/data/lang-godot-en.json
```

- **改卡牌数值/加新卡：改 `js/data.js`，然后 `node tools/export-data.js`，再跑测试。** 不要直接改 game.json（下次导出会被覆盖）。
- 加新卡还须在 `godot/core/game_data.gd` 的 ART 表登记立绘（缺图回退 glyph），跑 `node legacy/checks/art-check.js` 验收（需 `CHROME=` 指浏览器路径）。
- 新增可见中文文案必须：① GDScript 侧用 `I18n.T()` 包装 ② 在 `godot/data/lang-godot-en.json` 补英文键，否则英文模式残留中文（有 `lang-ui-check.js` 扫描兜底）。

## 六、测试体系

### Godot 测试（主工程，全部用同一模式运行）

```bash
<GODOT> --headless --path godot --script res://tests/<名字>.gd
```

| 脚本 | 项数 | 测什么 |
|---|---|---|
| `replay.gd` | 629 | 跨语言等价性（规则引擎没走样；20 个场景，含 8 位军师） |
| `campaign_test.gd` | 181 | 战役闭环（进度/存档/奖励/删牌/军师/事件/心魔/天时/死战专精/**重整机会**）；含「事件的代价不得再用生命上限」守卫 |
| `campaign_test.gd --flow` | 24 | 全流程 E2E（真实点击流）；含**同一关两连败 → 本局终结回存档位** |
| `scene_smoke_test.gd` | 54 | 全场景装配冒烟：13 个 `.tscn` 都 load 得起来、instantiate 出节点、**挂得上脚本且脚本解析通过**（堵「脚本 Parse Error 但 E2E 仍绿」这类假绿） |
| `audio_test.gd` | 89 | 音频总线/变速/设置持久化 |
| `codex_test.gd` | 148 | 图鉴/成就/PvP 战绩/心魔解锁 |
| `tutorial_test.gd` | 160 | 新手引导/暂停菜单/军粮点条/阵亡特效 |
| `i18n_test.gd` | 213 | 双语（用 `set_lang_soft`，不落盘） |
| `pvp_test.gd` | 35 | 联机全链路：**自动起真 relay + 两个 headless 子进程打完整局比指纹**；并有一局**真的把 socket 断开**（`--drop-at 6`）再 resume，断言「补放动作数 > 0 且两端指纹仍一致」 |
| `battle_ui_test.gd` | 83 | 对战界面交互与布局：点牌能出、双方部队同屏、手牌明暗、战报不溢出、关键 UI 不互压、单列满编留白、超编等比缩小 |
| `fonts_test.gd` | 2 | 子集字体覆盖全部用字（扫 `.gd` 字符串 + `data/*.json`），漏字直接报红 |
| `card_art_test.gd` | 416 | 缺图卡面的占位：`subtitle_of` 对**全卡池**在两种语言下都成立（EN 不许留汉字）、占位节点结构与可辨识名、**有图时占位必须让位 / 无图时必须出现**（走 CardView 真实装配路径） |
| `keyword_stamp_test.gd` | 76 | 卡面关键词小印：六个字段的判据（false/null 不算）、双关键词的排列顺序、三档印面（朱砂/墨/靛）的色相与深底、字号随 `box` 走、CardView / UnitView / 图鉴大卡三处装配且不出界不压费用圆、全卡池印数与数据一致、切语言不换字 |
| `art_rect_test.gd` | 51 | 立绘矩形：`UiTheme.texture_rect` 收口（size 不被纹理/切片最小尺寸顶回）、事件页圆图真的铺满 144、主菜单侧立绘 520×900、结局页最后一行不被面板边框切；宽屏舞台对齐：`fill_screen`/`bleed_x` 几何与 `bleed` 标记、每屏都有铺满整屏的底；**卡名 Label 不被文本宽度顶回**（29 字符的英文名必须真的放得下）；**8 位军师全部有立绘**且方窗 160×160 按比例铺满，缺图兜底改用合成军师测（不依赖真实数据） |
| `advisor_test.gd` | 39 | 军师被动：周勃只加我方/只加一个/上限生效/生命上限同步/无兵不空耗；郦食其只削敌方/只削一个/削不到负数/零攻时不空耗次数；其他军师局数值完全不动；8 位数据与中英战报 key 齐全；**文案里的「至多 N 次」必须与 ADV_*_CAP 常量同步**（中文数字 + 英文 at most 各钉一遍） |
| `event_pick_test.gd` | 35 | 事件选牌层：`CardPicker` 的多张选择（选满替换、取消选中、无取消回调时只留确认且居中、缩放随张数自适应不越面板）、事件得牌真进牌组且是要求的那一类、事件删牌真删且同名只删一张、一次删两张、牌组到下限不开删牌层 |
| `anim_peek.gd` | 调试工具 | 抓攻击/阵亡动画帧截图 |

### 旧 JS 测试（`test/`，遗留参照）

- 逻辑类直接 `node test/campaign.js`（1663 项）、`roguelike.js`（786）、`keywords/mulligan/ai-lethal/simulate/diagnose` 等；
- 数值调参：`tune-8.js`（8 关通关率曲线）/ `tune-roguelike.js`（军师收益带）/ `sweep-stages.js`；
- 构筑诊断（1.2 起的标准动作）：`diag-reward.js`（三选一里刷不刷得出、拿到有没有用——先分清「选不到」和「选了没用」再动手）/ `diag-tier.js`（三种选牌策略的牌组浓度分布，用来定专精门槛）/ `tune-run-build.js`（整轮口径 + 同种子配对，`random/quality/death` 三种选牌策略）；
- 单关难度杠杆：`tune-stages.js`（预置部队 / 敌我军粮 / 敌将血量 四个杠杆的量级对比）——动关卡 rules 前先跑，量级差得非常多；
- 心魔梯度与天时：`tune-ascension.js`（0~3 级心魔 + 6 个天时各跑一遍整轮通关率）——加/改心魔等级后必须重跑，八关连乘会放大每一级的修正；
- 奖励强度定价：`tune-skip.js`（血量 vs 一张牌的等价性）/ `tune-skip-drop.js`（删牌收益曲线）——改奖励池或牌组强度前先跑这两个；
**网页版验收脚本已归档到 `legacy/checks/`**（uicheck/clickcheck/flow/art-check/polish-check/slots-check/lang-ui-check/desktop-check），只做回归对照，不参与 Godot 版测试体系。本机 Chrome 卸了就指到 Edge：
```bash
CHROME="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" node legacy/checks/uicheck.js
```

**改规则/数值的最小回归集**：`replay.gd` + `campaign_test.gd` + `pvp_test.gd`（锁步最敏感）；动界面再补 `battle_ui_test.gd`；**动任何场景脚本都加跑 `scene_smoke_test.gd`**（解析错误只有它抓得到）。大改动才跑全部。

## 七、构建与导出（Windows exe）

1. 导出前 `mkdir godot/export`（目录不存在会导出失败）。
2. 编辑器命令行导出：
   ```bash
   <GODOT> --headless --path godot --export-release "Windows Desktop" export/ChuHanWenDing.exe
   ```
3. 产物为**单文件约 146MB**（embed_pck，资源全打包；2026-11-05 补齐连击 8 张立绘后从 143.5MB 涨上来），可直接上传 Steam depot。
4. 冒烟验收：双击 exe 能进主菜单、开一局快速对战、声音正常即 OK。
5. 关键配置在 `godot/export_presets.cfg`：`include_filter="*.json"`（FileAccess 运行时读 json 必需，**删了就会白屏**）、`exclude_filter="tests/*"`。

### 包体构成与压缩口径（2026-11-03）

包体从 **317MB 降到 134MB**，靠两件事，都没有牺牲可见画质：

| 项 | 之前 | 现在 | 手段 |
|---|---|---|---|
| 74 张立绘/场景图（现已 115 张） | 200MB | 27MB | `.import` 的 `compress/mode=1`（WebP 有损）+ `lossy_quality=0.8` |
| 字体两个字重 | 42MB | 1.6MB | `python tools/subset-fonts.py` 子集化到实际用字（950 字） |

**改压缩参数后必须重新导入**：`<GODOT> --headless --path godot --import`，否则读的还是旧 `.godot/imported/*.ctex`。

⚠️ **新加的图不会自动继承压缩设置**：`.import` 是每张图首次导入时按项目默认值生成的，默认 `compress/mode=0`（无损）。2026-11-03 补的 24 张立绘就是这样漏掉的——一次 `--import` + 导出，exe 从 135MB 涨到 181MB（每张约 2.5MB）。**加图后先批量改 `.import`（mode=1、lossy_quality=0.8）再导**，改完 `du -sh .godot/imported` 会从 95MB 掉回 56MB。当前 115 张全部是 mode=1，导出 146MB。

- **为什么选 q0.80**：单张 PSNR 36dB，整屏实测 39.8/43.8dB，肉眼可察差异像素占比 0.03%~1.4%。q0.30 的极端对照只把 PSNR 压到 36.6dB，说明这个量级的图对 WebP 很不敏感，没必要用无损。
- **源 PNG 仍是 348MB**（在 `godot/assets/cards/`）：**它不进包**，导出只带 `.ctex`。工程目录大是正常的，别为了瘦身去删源图——换压缩参数、换分辨率都得靠它们重导。
- **字体源文件在 `assets/fonts-src/`**：47MB，刻意放在 Godot 工程目录**之外**，否则会被 `all_resources` 当成资源打进包，子集化就白做了。`godot/fonts/` 只放子集后的 1.8MB 版本，代码仍按 `res://fonts/NotoSerifSC-*.otf` 加载，路径不用改。
- **加新文案后要重跑子集脚本**，否则新字会回退系统字体（字形不一致）或显示方块。`fonts_test.gd` 会扫全部 `.gd` 字符串与 `data/*.json`，发现缺字直接报红并提示重跑。

## 八、联机中继服务器（已部署）

- **线上地址：`ws://<你的服务器IP>:27775`**（阿里云 ECS，root 登录，安全组已放行 TCP 27775）。
- 服务器布局：`/opt/chuhan-relay/{relay.js, node_modules(ws)}`；systemd 服务 `chuhan-relay`（开机自启、崩溃 3s 重启、内存上限 200M）。
- 运维命令（SSH 后）：
  ```bash
  systemctl status chuhan-relay        # 看状态
  journalctl -u chuhan-relay -n 50     # 看日志
  systemctl restart chuhan-relay       # 重启
  ```
- **更新中继脚本**：本地改 `tools/relay.js` → `pscp tools/relay.js root@<你的服务器IP>:/opt/chuhan-relay/relay.js` → `systemctl restart chuhan-relay`。
- 公网验收：`node tools/pvp-live-test.js`（四步：建房/加入/动作转发/断线重连，输出 ALL_PASS 即通）。
- **监控口（2026-11-05 加）**：同端口的 `GET /health`（不额外开洞，WS 走 upgrade 分流），返回
  `{ok, version, uptimeSec, rooms, peers, clients, actions, peakRooms, servedRooms}`；
  巡检 `curl -s http://<IP>:27775/health`。有人玩时每 5 分钟打一行 `[relay] stats {...}`，空转不刷日志；
  `SIGTERM`/`SIGINT` 会先广播 `{t:"error", msg:"relay shutting down"}` 再退出（客户端停在断线界面而不是崩）。
  中继自测 `node tools/relay-smoke.js` 20 项（建/加/转发/重连拉日志/满房与假码/health/优雅退出）。
- 注意：**Node 在服务器上的路径是 `/usr/local/node-v22.14.0-linux-x64/bin/node`**，systemd 单元里写的是全路径；若升级 Node 要同步改 unit 文件。

## 九、踩坑实录（新环境最容易死的点）

1. **FileAccess 读 json 白屏** → export_presets 的 `include_filter` 必须含 `*.json`。
2. **WorkBuddy 沙箱跑 Godot** → 必须 `env -u ELECTRON_RUN_AS_NODE`。
3. **`RulesEngine.rng` 静态共享** → 多引擎实例必须各自注入 Rng，否则锁步分叉。
4. **测试直接调引擎后动画不播** → 引擎动了必须 `scene._sync_all()`，否则 `unit_views` 为空、动画早退（假通过/假失败都可能出现）。
5. **`set_lang()` 会落盘** → 测试/巡览里用 `set_lang_soft()`，巡览前后要备份/还原设置文件。
6. **脚本加载顺序**：tutorial 必须在 lang-en 之前（KEYWORDS 覆盖依赖）。
7. **battle 场景 `await` + 内联 lambda**：lambda 要先赋给变量再传，否则函数体可能不执行。
8. **battle.gd 里必须在 `board_layer` 建好后才能 `_build_col_frames`**，否则军阵格位静默丢失。
9. **relay.js 断连处理**：必须先广播 `peer_left` 再清房间槽位（`other()` 依赖槽位）。
10. **关卡 id 是 `gaixia` 不是 `gading`**（垓下立绘素材 `sc_gaixia`），找图时别搜错。
11. **战役 rules 合并时 `goal` 必须并进 rules**（历史 bug，survive 关卡会退化成击杀局）。
12. **敌方开局预置部队是最大难度杠杆**（至多 1 个，配玩家首回合多军粮补偿）；单关血量 ±6 在噪声内，不算杠杆。
13. **视图类不会自己接线**：`CardView`/`UnitView` 只管画，`clicked` 信号必须在 `_sync_hand`/`_sync_board` 创建它们时连上；漏连的表现是「点牌没反应、整局打不下去」（battle_ui_test 就是为这个加的）。
14. **`_sync_board` 的 alive 必须跨双方共用**：以前每个 `_sync_board(pid)` 各建一个 `alive`，先刷敌方再刷我方，敌方的视图在第二次调用里被当阵亡清掉——表现是「对面出的兵一上场就没了」。现在 `_sync_all` 建一个 alive 传进去，退场统一处理。
15. **`Label.clip_text = true` 会把最小高度压成 1px**：配 autowrap 用会整条文字消失（战报空白就是这个）。要限行用 `max_lines_visible`，裁剪交给外层固定尺寸 `Control.clip_contents`。
16. **手牌明暗要在 busy 放开后补刷**：`_after_action` 在动画期间同步，`playable` 会算进 `busy` 被判成 false；不同步刷新就一直是灰的（看着像不能出牌）。`busy=false` 后务必 `_refresh_hand_playable()`。
17. **自定义命令行参数必须写在 `--` 之后**：Godot 4.7 只把 `--` 之后的交给 `OS.get_cmdline_user_args()`；`--shot`/`--tour`/`--flow` 漏了 `--` 会静默进主菜单。
18. **`TRANS_BACK` 的入场缩放会 overshoot 到 1.1 倍**：单位视图 rect 短暂超出列框，压住列名带。弹入动画用 `TRANS_QUAD`，别用 BACK/ELASTIC。同理，任何"贴着容器边缘"的元素都不能用带回弹的缩放。
19. **浮层定位要给出「底边不许越过」的约束**：`CardTip.place_near(target, avoid, max_bottom)` 的第三参是手牌区顶线。只给 avoid 矩形不够——浮层压在手牌上时玩家看不清要点哪张牌。
20. **满编"刚好铺满"等于"糊在一起"**：部队 96×132、列内间隔 4 时 3 张总宽正好 296 = 列框宽，牌边与框线严丝合缝，满场时看不出列界。部队收到 **90×124** 后左右各余 9px。`UNIT_SIZE`（battle.gd）与 `UnitView.SIZE` 是两处常量，必须同步改；攻血章的 x 偏移也要跟着调成不出血，否则满编时右章会压到下一张的左章上。
21. **一列的排布不能假设"最多 3 张"**：`COLUMN_LIMIT` 是数据（`js/data.js` → `game.json`），改一个数就会多出第 4 张。`_sync_board` 现在按 `_rank_scale(n)` 整列等比缩小（4 张 0.77 / 5 张 0.62 / 6 张 0.51），保证任何张数都在列框内。改缩放要连 `UnitView.set_base_scale()` 与左上角 `SIZE/2·(1−s)` 补偿一起改，否则牌会整体向右下偏移（缩放轴在中心）。列满提示文案已改成跟随常量（Godot 走 `GameData.column_limit()`，Web 版走 `Data.COLUMN_LIMIT` + `{n}` 占位），细节见第 30 条。
22. **战役难度是 8 关连乘，任何"每关都生效"的修正都会被放大 8 次**：单关看 -8pp 的一个改动，乘起来就是通关率腰斩。所以心魔只做 3 级（实测 19% → 16% → 10% → 6%），第 4 级就会掉进 1% 的不可玩区间——与其摆 5 级好看，不如 3 级每一级都真的能打通。调心魔/天时/关卡难度前后都跑 `test/tune-ascension.js` 与 `test/tune-stages.js`。
23. **`openingDraw` 为负时以前是空效果**：`for (i = 0; i < -1; i++)` 直接不执行，于是"起手少摸一张"这种惩罚写进 rules 也毫无作用（还好心魔测试发现）。现在负值直接从基础起手张数里扣（先手 3 / 后手 4），正负两条分支都要在 Godot 侧一致；`trace.js` 有 `asc-draw-p1/p2` 两个场景专门覆盖。
24. **心魔成绩不能记在"首次通关"分支里**：`Codex.record_clear` 里 `if not cleared.has(stage_id)` 包住的逻辑只跑第一次；通过一轮之后 8 关全在 `clearedStages` 里，再打心魔永远进不去。整轮通关的判定（`cleared.size() >= total`）必须放在那个 `if` 外面。
25. **单关里最强的难度杠杆是"预置部队"，其次是军粮，最弱是敌将血量**：第 3 关把预置轻骑（3 费 3/2）换成戍卒（1 费 1/2），通关率 36% → 52%；而把敌将 22 血改成 18 血，通关率一点没动（36% → 36%）。别再用"给 Boss 加血"当难度旋钮。
26. **版式数值一律进 `battle.gd` 顶部常量区**：栅格/字号/面板尺寸散在函数里，改一处漏一处（重排前就有 9 档字号、3 套按钮尺寸）。规格见 `docs/battle-ui-spec.md`。
27. **禁用样式会盖掉选中样式**：择师页「心魔 N」只有解锁了才可点，未解锁时 `disabled = true` 会把 primary/hover 全换成禁用配色——截选中态时看到的是"一排灰按钮"，误以为选中逻辑没生效。巡览用 `_force_asc()` 必须连解锁上限一起放开，只改 `_asc` 不够。
28. **`Label` 会把超出 rect 的文字裁掉**：天时签纸的水印字一开始给 150px 高的框配 132px 字号，行高不够就出现半截字。装饰性大字要把框放到 1.25 倍字号以上。
29. **别用本地化后的字符串切字符**：签纸水印原本取「天时·清风」的"·"之后一字，英文名变成 "Fate: Fair Wind" 后切不出来，英文版签纸中段直接空一块。装饰字改成按 id 查常量表（`OMEN_GLYPH`），与语言无关。
30. **写死在文案里的数字迟早说错话**：「每列最多 3 员」以前散在 4 处（引擎 reason、战斗 toast、新手提示、英文映射），改 `COLUMN_LIMIT` 就得满仓库找。现在全部从常量拼：Godot 侧 `"%s列已满（每列最多 %d 员）" % [rank, GameData.column_limit()]` 配 `I18n` 的数字模板；Web 侧 `T('每列最多站 {n} 员…', {n: Data.COLUMN_LIMIT})`。同理「小提示」这类前缀要和正文分开翻译——正文带数字，整串拼好再查表必然查不到。
31. **改 `.import` 之后必须 `--import` 重导**：只改 `compress/mode` 不重导，Godot 还会读旧的 `.godot/imported/*.ctex`，看上去"改了个寂寞"。判断是否真生效：看 ctex 字节数变没变，或者用 `Image.load_from_file` 与 `load()` 的像素抽样对比。
32. **别拿"目录里有的截图"当验收对象**：`--tour` 只重出它自己那 19 张（`_gd-menu/map/intro/battle-campaign/...`），`_gd-battle.png` 是早期遗留、巡览根本不截。拿它做前后对比会得到"md5 完全一致"的假结论，一度误判成压缩没生效。**先 grep `[tour] 截图` 的实际清单**，确认文件被重写过（比 mtime）。
33. **`TextureRect` 先赋 `texture` 再 `set_size` 会被顶回原图尺寸**：最小尺寸默认等于纹理尺寸（立绘全是 1024²），于是 `size = 144` 静默失效、画面只显示原画左上角一小块——**不报错、不崩**，只有截图能看出来。事件页十个圆形插图一直是这样（一块空白宣纸），主菜单侧立绘被 1024 硬顶、冲刺残影与阵亡碎片也成了巨型贴图。现在统一走 `UiTheme.texture_rect(tex, box)`（内部先设 `expand_mode` 再给 texture/size），`tests/art_rect_test.gd` 钉住成品界面里这几个矩形到底多大。**判据：任何"图上写字/图进框"的地方都别手写 TextureRect 属性。**
34. **战吼不能只支持"抽牌/点兵"**：`resolve_battlecry` 原本只有 `draw` 与 `tokens` 两个分支，新卡要"战吼：前锋列 +1 攻""战吼：主将 +2 血"就得复制第二套效果器。改成 `tokens` 单独处理、其余字段原样转交 `resolve_effect`——战吼与亡语从此共用一套效果词汇，两边引擎各 4 行。
35. **`replay.gd` 漏传场景牌组**：回放端一直用 `{}` 建局，所以只有"默认牌组"的路径被验过。加自定义牌组场景时全红（第 1 回合手牌就不一样），不是引擎错，是测试脚手架没接上 `sc["decks"]`。**加新场景前先确认回放端吃到了场景的所有字段。**
36. **字体子集重建后要确认 `.fontdata` 真的换了**：`--import` 偶发中断会留下 0 字节 `.tmp`，`.fontdata` 还是旧的，`fonts_test` 会持续报"缺 N 个字"。判断依据看 `.godot/imported/*.fontdata` 的 mtime；清掉 `*.tmp` 再导一次即可。这也是 `fonts_test` 存在的价值——它把"改文案加字"这类隐形回归变成了红灯。
37. **别让源素材躺在 Godot 工程目录里**：`export_filter=all_resources` 会把工程内所有被导入的资源打进包。字体源文件（47MB）必须放 `assets/fonts-src/`（工程外），`godot/fonts/` 只留子集版本；同理 `export/` 里那张历史截图当年就是这么进包的。

38. **`stretch/aspect = expand` 的"多出来的那条"会把整屏挤偏**：版式按 1440×900 写，16:9 全屏时画布被撑到 1638×900，于是每屏整体偏左 7%（窗口 1440×900 时看不出来，所以藏了很久）。做法：`Widgets.stage_offset()` 算出 (视口宽−1440)/2，`App` 在 root 的 `child_entered_tree` 里把 `scenes/` 界面根节点右移（`go()`、直连 `change_scene`、启动主场景三条路全覆盖），窗口尺寸变化时 `size_changed` 重铺。**代价是所有"铺满屏幕"的元素不能再用 anchor**——anchor 铺的元素会跟着舞台一起挪，左边留一条没盖到的亮带（引导聚光灯、设置面板遮罩、暂停遮罩都踩过）。统一用 `Widgets.fill_screen()` / `bleed_x()` 并按 `bleed` 标记重铺；每屏至少要有一个 `bleed=all` 的底，`art_rect_test.gd` 会验。

39. **`Label` 的 `size` 会被文本最小宽度顶回——和 TextureRect 是同一个坑**：Label 的最小尺寸默认等于整句文本宽度，所以 `size = Vector2(124, 28)` 会被「General · Warlord of the Dead」（230px）顶回去；而 `clip_text = true` 时最小尺寸才是 0。**先 `set_size` 再开 `clip_text` 等于没开**，文字照样画出卡外压到邻牌上。正确顺序：先 `clip_text = true` → `text_overrun_behavior` → 再 `size`。中文卡名短，这个 bug 只在英文化之后才看得见（`art_rect_test.gd` 现在用最长那条英文名钉住）。字号也别按字符数猜：中文一字 ≈1em、英文一字母 ≈0.5em，直接用 `Font.get_string_size()` 量。

## 十、本机全局约定速查

- 中文环境，注释/文档全中文；代码里字符串引号用 ASCII 直引号。
- 中国股市式配色直觉（涨红跌绿）仅影响未来金融类展示，本项目暂不涉及。
- 范围纪律（roadmap §五）：在线天梯/内购/装备牌/Mac/Linux 版**不做**；PvP 已解禁为休闲对等卡组对战。
- 工作日志在 `.workbuddy/memory/`（随机器走，重要约定以本文档为准）。
40. **迁移时「简化」掉的分支，文案会替它撒谎**：事件结算在 JS 版里是「按 `fx.card` 的类型抽 3×N 张候选开三选一 / 按 `fx.remove` 开牌组让你挑」，Godot 迁移时被简化成「一律发一张随机兵种牌，`remove` 完全不处理」。后果是「三选一计谋牌」实际给兵种牌、「从牌组移除一张」什么也没发生——**而且所有既有测试都是绿的**，因为它们只断言「事件结算成功」，没人断言「牌组真的变了」。修法不只是补代码：把「选牌层」抽成 `ui/card_picker.gd`（奖励页的删牌也改用它），再新增 `event_pick_test.gd` 专门盯「选了之后牌组变没变、变的是不是那一张」。**加了新 fx 字段却没接上新分支，这种错不会崩、不会报错，只能靠逐条断言抓。**
41. **白字画在纸白底上等于没画**：军师卡缺立绘时的兜底把 glyph 颜色写成了 `UiTheme.PAPER`（纸白）。卡面本身就是纸白，于是夏侯婴那张卡的顶栏从上线起一直是空白——**不报错、不崩、所有测试都绿**，因为没人断言过颜色。这类「颜色语义用错」的 bug 只能靠断言钉：`art_rect_test` 现在直接比对 `glyph.get_theme_color("font_color") == UiTheme.SEAL`。同理，深色印面配纸白字、浅色纸面配朱砂字，写兜底时先问一句「这个颜色画在当前底色上看得见吗」。
42. **调档只改常量、忘了改文案，玩家读到的就是错的规则**：周勃/郦食其为了收敛强度，`ADV_ZHOUBO_CAP` / `ADV_LIYIJI_CAP` 从 2/3 砍到 1，但 `js/campaign.js` 的 `desc` 还写着「每场战斗至多两次/三次」。截图看不出任何异常（字没溢出、没压按钮），只有把三张军师卡并排看才意识到文案在撒谎。同一批还查出夏侯婴的英文 desc 写着「battle rewards lean toward Taunt and Last Stand cards」——**这个机制根本不存在**（中文没这句，是英文单边编的）。做法：`advisor_test` 直接从 `ADV_*_CAP` 生成期望串（中文数字表 `{1:一,2:两,3:三,4:四}` + 英文 `{1:once,2:twice,…}`）去比对 `desc`，改 cap 忘了改文案立刻红。**凡是「文案里写死的数字」，都要有一条从常量反推期望值、而不是抄一遍数字的断言。**
43. **数据没导出去，测试会替它「假装通过」**：`game.json` 里从未包含 `faction` 块，`GameData.faction_of()` 永远返回 `neutral`，于是 Godot 版战役奖励池一直把楚牌发给汉营玩家（项庄、龙且、季布都能拿到），而「汉营不出楚牌」这条测试**一直是绿的**——它检查的是 `faction_of(id) == "chu"`，全 neutral 时永远为 false。发现路径不是看测试，是做连击卡时打印池子内容，看见项庄混在里面。修法：`tools/export-data.js` 补 `faction` 键（用 `D.factionOf()` 构造，`CARD_FACTION` 本身没导出），并在 `campaign_test` 加一条「阵营映射已加载」的守卫。**教训：断言要能证伪——「列表里没有 X」在列表为空时也是真的。凡是「不应该出现」的断言，都要配一条「基准数据确实存在」的前置断言。**
44. **给关键词卡加「条件」却只给平级强度，等于白送一个负面条件**：P2 首批 8 张连击卡按「连击触发后才达到同费标准」设计，实测 combo 策略只有 10%，而同一策略在**排除新卡**后反而 18%（那时它退化成「按体质选」）——说明这批卡比「什么都不想、直接拿大牌」还差 8pp。改法是把底子提到同费标准（1 费 1/3、3 费 3/3、5 费 5/5），连击当**额外**收益，combo 才回到 14.5%。**判据也要选对：必须和「同一策略在无新卡时」对照，否则分不清「连击卡弱」和「这批卡让随机池变差」。**
45. **多层加成叠加要在「最后一步」再钳制，写在中间等于没写**：初阵档位（敌首回合 -1 军粮）在 `engineRules` 里紧跟生命加成写入，随后天时/心魔才逐层叠加——霜降天时（-1）叠上来就把全局 +1 抵穿成 -1。第一次把钳制写在初阵块里，测试立刻红（实际 -1）。**教训：凡是「下限/上限」约束，一律放在所有加成都合完之后、`return` 之前；中途钳制只对已经算过的层生效。**
46. **同一批改动里，JS 侧漏改的旧断言不会自己变红**——它一直在红，只是没人跑**：P2 把卡池加到 78 张，Godot 侧 codex 断言改到 77，JS `test/campaign.js` 的「池子 75 张」与「连营 desc ≤34 字」却留着没动，整整一版都在失败。这轮跑 JS 全量才看见。**改卡池/改文案时两端测试要一起跑，别只跑 Godot。**

47. **文件一移动，相对路径就集体错层，而且没有任何一处会「报错」**：把网页版归档进 `legacy/` 后，同一个「相对路径」要按引用者的深度分别算——`index.html` 在 `legacy/web/` 引用根 `js/` 是 `../../js/`，`ui.js` 里的立绘是 `../../godot/assets/cards/`，而 `css/style.css` 里的背景图还要多一层 `../../../`（css 在下一级目录）。第一次只改了前两处，页面照常打开、逻辑照常跑，只有**两张主将剪影是空的**（404 在控制台，肉眼像是「这张图本来就淡」）。判据：归档后必须真跑一遍浏览器验收（`legacy/checks/uicheck.js`），并且**让报错带上 URL**——只打印「资源加载失败」时你根本不知道丢的是哪个文件。
48. **归档不是 `git mv` 完就完事**：验收脚本里写死的「卡池 45 张」跟着代码一起搬进 `legacy/`，跑起来一堆红，看起来像归档把功能弄坏了，其实全是三年前的数字。做法是把断言改成跟数据走（`Codex.cardStats(Data).total`），顺手把卡池口径统一到同一处——`Data.CARDS` 有 78 个键，图鉴/构筑只列 77 张（有一张不进池），两处各算一套就会差 1。**判据：归档目录能跑出「全部通过」，才算归档完成；跑到红就别急着说是历史遗留。**

49. **脚本解析失败时，E2E 照样能绿**：在 `stage_intro.gd` 里新加一行，变量名与已有的 `rl` 重复 → 整个脚本 Parse Error，过场页变成空壳；但 `--flow` 断言的是 `current_scene.scene_file_path == SCENE_INTRO`，**路径当然还是对的**，24 项 E2E 全过。发现路径是靠截图脚本 load 场景时报错。修法：`scene_smoke_test.gd` 对每个 `.tscn` 做「load → instantiate → `get_script() != null`」，54 项；故意把重复变量注入回去验证它会红（否则又是假绿）。**判据：断言只能看"我关心的那件事"，路径对≠页面在。**
50. **代价货币要先验证它真的值钱**：事件系统原先大量用「生命上限 ±N」当代价/收益，看着是取舍，实测血量 ±6 在噪声内（第 4 关 +0/+4/+8/+12/+16 血：28/40/40/26/34%），而一张牌值 3~6pp、删两张废牌值 +26pp——等于事件在收假币，所有选项退化成「选给牌最多的那项」。改法：全部换成军粮/起手/敌粮/牌，并加数据层守卫「事件的代价不得再用生命上限」，防止长回来。**判据：任何被当作代价/收益的资源，先单独测出它值多少 pp，再拿去设计选择。**

51. **探针在动作生成之后改写字段，会让「校验」和「执行」用上两份参数**：测「出牌选列值多少」时，探针包了一层 `aiNextAction`，把 p2 动作里的 `rank` 删掉以模拟「按卡面固有列出牌」。但 AI 生成动作时是**按选好的列**校验容量的，删掉 rank 后 `playCard` 按 `card.col` 落子——该列已满 → 返回失败 → 状态没变 → AI 下一轮又生成同一个动作，**236/400 局卡死在原地**，胜率表里还混着「未终局」的样本。发现路径是探针打印「未终局局数」，而不是看胜率（胜率当时看着像有结论）。修法：探针改成把 `rank` 覆盖成 `card.col`（而不是删掉），并在执行前确认该列有余位；生产代码里则让 `canPlay` 与 `playCard` 接受同一个 `toRank` 参数。**判据：任何「事后改写动作」的测试脚手架，都要断言「动作被接受」，并且把「未终局局数」打印出来——不然你测的是死循环，不是策略。**

52. **测试总数会自己漂，红了也复现不出来**：`test/roguelike.js` 的「奖励池随机化」把断言写在 `rollRewards(...).forEach` 里，而 forEach 的迭代次数取决于这次抽到了哪些牌（关卡特色牌要跳过断言、牌池不够 3 张时提前结束）——于是同一份代码连跑三次得到 `940 / 934 / 938`，文档里写的「全量 X 项」每次都不一样，某次红了也没法复现。修法：这一段用固定种子的伪随机（`mulberry32`，测试自己实现 8 行），计数与结论从此稳定。**判据：同一个测试连跑三次，通过项数必须完全一致；报数字之前先确认它不是随机的。**

53. **「A/B 差值精确等于 0.0pp」多半不是「技能弱」，是「技能根本没被按过」**：韩信的「点兵」第一轮 A/B 是 `14/16/17` vs `14/16/17`——两个臂逐种子一模一样，看着像「这个技能对胜率没有影响」。真相是 `js/ai.js` 的 `advAction` 少一个 `buffCol` 分支，AI 整轮一次都没按这个按钮。夏侯婴只给「死战次数 +1」时也是 0.0pp（条件太窄，按下去也换不来结果）。修法：`test/tune-run-build.js` 加 `CH_ADVUSE=1` 打印**发动率**（正常情况下 90%~99%），`advisor_test` 加「AI 认得每一种 fx」。**判据：任何「玩家可主动发动」的新机制，先量发动率，再谈强度；0.0 的差值要先排除「没人用」。**

54. **组合技能会掩盖漏分支，测试要「逐个 fx 键」而不是「整份技能」**：`{draw: 1, buffCol: 'front', atk: 1}` 这种组合，`advAction` 只要识别了 `draw` 就返回动作——把 `buffCol` 分支删掉，测试仍然全绿（144 项）。修法：把军师数据里出现过**每一种** fx 键单独喂给 AI（`{buffCol: 'front', atk: 1}` 一个键一份），并要求 AI 返回非空；同时显式维护「参数键」白名单（`atk`/`hp`/`count`/`rank`/`baseId`），新效果想蒙混过去就得先承认自己没接分支。**验证方式：故意把分支改成 `if false:`，测试必须变红**——第一版没做这一步，改完才发现是假绿。

55. **英文文案是「单边漂移」的高发区**：军师主动技的英文写着「+2 Attack and +2 Health」「Restore 3 Health」「Deal 2 damage」「The enemy loses 2 Attack」，实际 fx 全是 1~2 的一半；韩信的英文甚至留着上一版机制（「Summon two fresh troops」，实际是「抽一张牌 + 前锋 +1 攻」）。中文全对、英文全错，中文评审看不出来。修法：`advisor_test` 从 `fx` 反推数字集合，比对**中英两份**文案里出现的每个数字（阿拉伯数字 + 中文「一/两/三」+ 英文 "one/two"）。**判据：文案里出现的每个数字，都必须能在数据里找到来源；写死在文案里的数字，等于第二个真相。**

56. **「每场战斗一次」的按钮在整轮口径下值 4~9pp，成本档只决定「按不按得出来」**：整轮是 8 关连乘，单关一点点优势被放大 8 次——2 费「全体 +1 攻」实测 +6.4pp，4 费「全体 +1 生命」+4.2pp。而把同一个技能从 4 费提到 5 费，差值直接归零（AI 攒不出 5 费空档，真人也不会为 +1 生命留 5 费），不是「变弱」而是「消失」。**调这类按钮先调效果量（伤害/加值/张数），成本档只用来卡发动时机；改费之前先跑 `CH_ADVUSE=1` 看发动率还够不够。**
57. **容器里塞卡片，别用「tween position」的入场动画**：图鉴「解锁」页用 `VBoxContainer` 排 4 张卡，每张调了 `Widgets.rise_in()`，结果截图里 4 张挤成一张、文字互相重叠。原因：`rise_in` 在布局前把 `position` 推到 `(0, offset)` 再 tween 回原值，而容器排好的 position 是布局算出来的——tween 每帧写 position，把布局结果全盖掉。成就页没这问题纯粹因为它没调用 `rise_in`。**判据：容器（VBox/HBox/Grid）里的子节点只用 `custom_minimum_size` + `size_flags` 排版，不要手动 position，也不要用改 position 的动画；要入场动画就动 `modulate`。任何新 UI 页都要拍一张截图看，别只看代码。**

58. **老存档迁移的测试必须走真实读盘路径，注意 `_loaded` 缓存与 `reset()` 的副作用**：`Codex.ensure_loaded()` 有静态缓存，读文件只发生一次；`reset()` 会把 `_loaded` 置回 `true` **并删档**。写迁移测试时若顺序是「写测试档 → `reset()`」，reset 会把刚写的档删掉；若写成「写测试档 → `ensure_loaded()`」，缓存导致根本不读盘，断言拿到内存空档。正确顺序：`reset()` → 写档 → `Codex._loaded = false` → `ensure_loaded()`。**判据：测「读旧格式数据」的用例必须证明它真的读了磁盘——先故意把期望值写错，确认它会红。**

59. **「事后统计」的探针不能在对象已经消失之后去查它的属性**：测敌方意图预告的天花板时，探针在部队死亡后回查它的生命值——死人已从棋盘移除、查到 0，于是「敌军总攻 ≥ 生命」变成「≥ 0」恒真，围杀规则覆盖率虚报成 **100%**（单杀口径 68% / 围杀 81% 才是真值）。发现路径是「100% 太整齐了，回去看代码」。修法：**预测点那一刻就把 uid→hp 快照下来**，归因只用快照。**判据：任何覆盖率/命中率统计，先问一句「被统计的对象在统计时还活着吗」；报出 100% 或 0% 时第一反应是查分母和取值路径，不是庆祝。**

60. **新加的角标/浮层要量它周围有什么，「三块互不压」的旧断言不会管第四块**：主将血条的「险」印第一版放右上角（460−32 处），截图一看正好盖掉第 10 颗军粮圆点——而 `battle_ui_test` 里的布局断言只查「名字 / 血量 / 圆点三块互压」，新元素不在名单里，测试全绿。修法：险印挪到血量与圆点之间的空档（hp 止于 274、圆点起于 312），并在测试里补「险印不压圆点 / 血量 / 名字」三条。**判据：任何新增 UI 元素都要进布局断言，并且必须拍一张截图看——矩形不相交不等于视觉上不难受，但「矩形相交」一定得先排除。**

61. **Label 的实际高度由行高决定，不是你设的 `size.y`**：给血条右栏加「牌库 N」行时按设计稿排了 y=66、size 高 16，实测 `get_global_rect()` 高 **23**（12px 字的行高；FS_SMALL 的军粮行同样是 23）——结果军粮行（y=46，底 69）压住牌库行顶 66，牌库行自己（底 89）还超出血条框（高 88）。布局断言（`不压军粮数字` / `在血条框内`）当场全红。修法：军粮上提到 y=40、牌库行 y=64（底 87 贴内缘）。**判据：容器里的多行文字，行距要按 `UiTheme.font().get_height(字号)` 排，或者干脆先写断言再调坐标；`size.y` 只是给布局的最小提示，Label 会按行高撑开。**

62. **A/B 口径漏掉「容错机制」会把难度高估数倍，并污染所有下游判断**：所有难度数字（战役常规 11.5%、初阵 17%）都是「每关只给一次机会」算的，但真实规则是每关 1 次重整（`RETRY_PER_STAGE`）——两次机会。补上重整后真实整轮通关是 **53%**，比旧口径高 4.6 倍。这不是数值调错，是**分母错**：探针照抄了「输了就 return」的循环，把「玩家可以重来」这个规则漏在了模型外。**判据：写难度探针前先列一遍玩家在规则里拥有的所有容错手段（重整、读档、复活、跳过），每一个都要么显式建模、要么在报告里注明「未建模」——否则得出的绝对值不能进文档。**

63. **写存档必须原子：`FileAccess.open(path, WRITE)` 是「先截断再写」，配合「解析失败静默回退空档」= 玩家进度静默清零**：断电 / 强退 / 磁盘满落在写入过程中，磁盘上留下半截 JSON；读取端 `JSON.parse_string` 失败后返回空字典，于是图鉴清零、三个存档位全空、解锁回到初始档——**界面上没有任何提示**，玩家只会觉得游戏坏了。五处写盘点（codex / campaign 存档位 / settings / tutorial / 截图）原先全是截断写。修法是 `SafeFile`：写 `.tmp` → 读回校验长度 → 同目录 `rename` 原子替换（实测 Windows 上目标已存在也能覆盖）。读取侧顺序：主文件可用就直接用；坏了先备份成 `.corrupt`（只留第一份，别让后续启动覆盖）再回退 `.tmp`；`.tmp` 可解析就提升它自愈。**判据：任何「用户数据」的落盘都要能回答「写到一半崩了会怎样」，答案不能是「下次启动当空档」。**
64. **`reload` 这个名字会撞引擎侧方法，静态调用被静默吞掉**：`Settings.reload()` 写在 `settings.gd` 里是 `static func reload()`，调用时**函数体根本不执行**——不报错、不警告，静态变量停在旧值（表现为「调了 reload，bgm 却回到默认值」）。改名 `reload_from_disk()` 后立刻正常。这个 bug 之前以「巡览后设置残留 en、只能手动改回」的形式出现过一次，当时误判为「备份/恢复链被覆盖」，真因就是恢复函数压根没跑。**判据：`reload` / `reset` / `update` / `load` / `save` 这类撞名高危词不要用作静态方法名；方法「看起来调了但没生效」时，先在里面 print 一行确认它真的进了函数体。**

65. **结构化数据（关卡名 / 事件名 / 军师名）不是扁平文案，`I18n.T()` 命中不了，必须在拼接前单独取译名**：兵败战报第一版写成 `I18n.T("兵败") + " · " + stage_name`，中文正常、英文出来是「DEFEAT · 固陵之战」——因为关名的英文在 `stages[].name` 里（结构化），不在键值表里，`I18n.T` 对整串「兵败 · 固陵之战」也匹配不到任何规则。修法是拼接前先 `I18n.stage_field(stage_id, "name", 中文fallback)`，所以战报的数据里必须带 `stageId` 而不只是 `stage` 名。**判据：英文界面里冒出中文时，先分辨这段文字是「写在代码里的文案」（走 `I18n.T`）还是「从数据里取的字段」（走 `*_field`），两者机制不同、不能互相兜底。**
