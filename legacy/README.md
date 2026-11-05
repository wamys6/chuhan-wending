# legacy/ —— 已冻结的网页/Electron 版

《楚汉·问鼎》v0.9 之前是纯 Web（HTML + 原生 JS + Canvas/DOM 表现层），
2026-11-01 起主线迁到 Godot（`godot/`），发布物是 `export/ChuHanWenDing.exe`。
这套网页版不再加内容、不再修 bug，**留着的唯一理由是两个**：

1. **数值参照**：`js/` 里的规则引擎、卡池、军师、事件仍是**单一数据源**——
   `tools/export-data.js` 把它导出成 `godot/data/game.json`，`tools/trace.js` 录出
   等价性测试用的动作轨迹。换句话说：Godot 版读的是这套数据。改数值要改 `js/`，然后重新导出。
2. **验收脚本**：文字版 UI 的像素级巡检（截图 + CDP 断言）曾经在这里跑，出问题时可对照。

> ⚠️ 别在这里加功能。改卡牌/军师/事件数值请改 `js/` 再 `node tools/export-data.js`；
> 改界面请改 `godot/`。

## 目录

```
legacy/
├── web/                 ← 可直接双击运行（file:// 就行）
│   ├── index.html       ← 页面骨架；脚本引用分为「本目录 js/」与「根 js/」两段
│   ├── css/style.css
│   ├── js/ui.js         ← 页面装配（手牌/军阵/奖励页/设置面板…）
│   ├── js/audio.js      ← WebAudio 音效与 BGM
│   ├── electron-main.js ← 桌面壳（已被 Godot 导出取代）
│   └── electron-preload.js
└── checks/              ← 网页版的浏览器验收脚本（Chrome CDP，跑的时候要 Chrome 路径）
    ├── uicheck.js       ← 界面元素与交互巡检
    ├── clickcheck.js    ← 点击链路
    ├── flow.js          ← 端到端一手牌局
    ├── art-check.js     ← 立绘/头像接图验收
    ├── polish-check.js  ← 表现层（动画、音效钩子）
    ├── slots-check.js   ← 存档位 UI
    ├── lang-ui-check.js ← EN 全屏 CJK 零残留扫描
    └── desktop-check.js ← Electron 壳验收（需先起 electron --remote-debugging-port）
```

`js/` 里另外 8 个文件（data / engine / ai / campaign / codex / i18n / lang-en / tutorial）
**留在根目录**，因为 `tools/` 的导出与录制工具、`test/` 的数值测试都依赖它们。

## 还能跑吗

- 页面：浏览器直接打开 `legacy/web/index.html`（file:// 即可，不需要服务器）。
  立绘路径已改成 `../../godot/assets/cards/`——**直接读 Godot 那份素材**，
  所以不会出现「网页版少几张新卡的图」这种两套素材不同步的问题。
  （根目录的 `assets/` 280MB 重复拷贝已于 2026-11-05 删除，页面完全不依赖它。）
- 验收脚本：`node legacy/checks/uicheck.js`，会拉起本机浏览器走 CDP。
  浏览器路径默认是 Chrome，本机没装 Chrome 时用环境变量指到 Edge：
  `CHROME="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" node legacy/checks/uicheck.js`
  2026-11-05 归档后实测「界面检查全部通过」。
- Electron 壳：`npm start`（`package.json` 的 `main` 已指向 `legacy/web/electron-main.js`）。
  **必须** `env -u ELECTRON_RUN_AS_NODE npm start`，否则沙箱里的环境变量会让它当 Node 跑。

## 什么时候可以删

Steam 上架前若要彻底瘦身：删掉 `legacy/web/` + `legacy/checks/`，
但要**同时**把 `js/data.js`、`js/engine.js` 的数值搬进 `godot/data/`（或把 `export-data.js`
改成读一份独立的 JSON），否则导出链路会断。在那之前，这份归档按「只读」对待即可。

> 2026-11-05：根 `assets/`（280MB）与 `dist/`（501MB Electron 产物）已删除，共省 780MB。
