# Steam 素材 · AI 生图 / 生视频提示词

配套脚本：`tools/make-steam-art.py`（PIL 排版合成）。
原则：**图由模型出，字由脚本排**——中文标题绝不让模型画（必出错字/伪汉字）。
所以所有提示词都要求「标题区域留空」。

---

## 0. 共用风格段（每条 prompt 都带上，保证一套图同画风）

```
STYLE BLOCK:
digital ink-wash illustration (shuimo) painted on xuan rice paper,
Chinese brush calligraphy strokes, visible dry-brush fly-white texture,
ink splatter and bloom bleeding into the paper fibers, fine gongbi-like
detail only on faces and armor, everything else loose and suggestive;
palette: warm off-white paper (#F2E8D5), dense charcoal-black ink (#1D1A16),
muted umber and warm ochre accents, a single vermilion-red accent (#7C1F1A),
cold grey mist; soft raking light from the upper left; high contrast between
ink mass and empty paper; large negative space.
NEGATIVE: text, lettering, chinese characters, logo, watermark, signature,
frame, border, ui, modern objects, photorealistic skin, 3d render, plastic gloss,
neon, oversaturated, blurry, extra fingers, deformed hands
```

---

## 1. 库英雄图 3840×1240（唯一还缺的一张）

> 要单独发给生图方时用 `store/steam/需求-库英雄图4K.md`——那份是自包含的，不用看本文其余章节。

### 为什么必须重出

现有那张原生只有 **2172×724**，上采 1.77× 到 3840。库页平时显示 1300–1900px 看不出来，
但 4K 屏 + 库页大图会露馅（笔锋飞白糊成灰雾）。**判据只有一条：新图原生宽度必须 ≥3072**，
否则等于换个方式再糊一次。

顺带修掉第二个问题：Steam 库页把游戏名 Logo 叠在**左侧**，现在靠把 `charge` 水平镜像
才腾出左边的空白。新图直接让主体站在右边，不用再镜像（镜像会让衣纹方向反逻辑）。

### 出图参数

| 项 | 要求 |
|---|---|
| 目标 | 3840×1240 = **3.097 : 1** |
| 首选 | 直出 3:1（3072×1024 / 4096×1365 都行），差 3% 由脚本按宽贴合裁高 |
| 次选 | 21:9 → 裁到 3.097 会切掉 **25%** 的高度，构图上下各留 15% 余量 |
| 别用 | 16:9 → 裁掉 **43%** 高度，人物必被切 |
| 分辨率 | 能给多大给多大，**宽度 <3072 就重出** |

### 提示词

```
Ultra-wide cinematic banner for a game library header, 3:1 aspect ratio,
high resolution (3840 × 1240), ink-wash illustration on xuan rice paper.

COMPOSITION — this is the whole point, follow it strictly:
- The LEFT 40% of the frame is EMPTY PAPER. No figure, no horse, no armor,
  no strong ink mass — only faint dry-brush dust and one or two loose
  splatter droplets. A publisher logo will be overlaid on this area.
- The SUBJECT lives entirely inside x 52%–92% of the width, and inside the
  middle 74% of the height (top 13% and bottom 13% contain only paper and
  mist, so the image can be re-cropped without cutting anyone).
- Nothing important touches the frame edges.

SUBJECT: Xiang Yu, Hegemon of Chu — a massive warrior in black lacquered
lamellar armor with bronze rivets, a torn black cloak streaming to the right,
a long halberd angled across his body, wild mane and beard, defiant stare,
one gloved hand gripping the reins of a black warhorse whose head rises at
his hip. Ink splatter and shredded banner cloth burst outward from him toward
the right edge, as if he has just ridden through the paper.

BACKGROUND: a low vermilion sun bleeding into cold grey ink clouds at the far
right; behind him a faint dissolving line of Han banners in the mist,
deliberately unreadable — no literal soldiers, no gore.

LIGHT: one hard rim light from the upper left; everything else falls back
into bare paper.

NEGATIVE: text, lettering, Chinese characters, seal stamp, logo, watermark,
signature, frame, border, ui, modern objects, photorealistic skin, 3d render,
plastic gloss, neon, oversaturated, blurry, extra fingers, deformed hands,
figure on the left side, figure in the center, crowded composition
```

### 出完先自检，别急着排版

```
python tools/make-steam-art.py --check-hero 新图.png
```

三条硬判据（不过就重出）：比例 2.95~3.15（生图只给整数比 3.000，按宽贴合裁高后正好
3.097，只裁 1% 高度）、左 40% 墨量 <3%、主体最左点 ≥40%。
另两条只提示不判死：中缝墨量（越淡标题越好放）、上下 13% 墨量（水墨本来出血，
但贴边太高说明头/盔会被裁）。

过了就放进去（文件名必须是这个，脚本按名认）：

```
store/steam/_art/_raw/library_hero_charge_r_raw.png    ← 原图
store/steam/_art/no-title/library_hero_charge_r.png    ← 同名，直接复制一份即可
python tools/make-steam-art.py     # 多出一张 library-hero-charge-r.png（备选，不镜像）
```

**注意它现在是「备选」不是主交付**。2026-11-07 收到一版实测：构图完全合格
（左 40% 墨量 0.1%、主体起于 43%），但原生仍是 2172×724 —— 分辨率问题一点没解决，
而笔触比原来那套更写实、少了水墨炸裂，放进胶囊套里像另一个项目。
两版叠 Logo 的对照见 `store/steam/_ab-hero.jpg`。
⇒ **真正要解决的是原生宽度 ≥3072，构图已经不用再试了。**

---

## 2. 主胶囊 1232×706

```
Game key art, 16:9, ink-wash illustration, centered composition with a clear
vertical empty band through the middle third for a title.
Left edge: Liu Bang half-length, turned three-quarters toward the center,
dark earth-tone robe, one hand resting on a bronze seal, gaze level and calm.
Right edge: Xiang Yu half-length, turned toward the center, black lamellar
armor, halberd shaft crossing the frame diagonally, ink drips flying off the
blade. Both figures fade into the paper at their outer edges — no hard cut.
Between them: bare xuan paper with faint dry-brush dust and a single vermilion
seal-shaped ink blot in the lower middle. No text anywhere.
```

---

## 3. 竖版胶囊 748×896（4:5，移动端/社交图）

```
Vertical poster, 4:5, ink-wash illustration.
Top two-thirds reserved: empty xuan paper with a few faint ink washes and one
small vermilion splatter, room for a stacked title.
Bottom third: the two warlords seen from behind and slightly below, standing
shoulder to shoulder but turned away from each other, silhouetted almost
entirely in black ink; between them, a thin gap of pale paper like a blade of
light. Their cloaks bleed downward into loose ink that dissolves off the
bottom edge. No faces visible. No text anywhere.
```

---

## 4. 页面背景 1438×810（低对比不抢内容）

```
Atmospheric background texture, 16:9, very low contrast ink-wash.
An empty battlefield at dusk rendered almost entirely in pale grey washes:
distant mountain ridges, flattened grass, a broken chariot wheel half sunk in
mud, scattered spear shafts leaning at angles, thin mist. All forms soft and
desaturated, ink density never above 30%, no focal point, no figures.
Warm off-white paper visible throughout. Designed to sit behind text and UI.
No text anywhere.
```

---

## 5. 宣传片（40 秒）

### 三条铁律，先看这个再动手

1. **AI 只做 3 个氛围镜头，战斗全部用真实录屏。**
   Steam 审核和玩家都认「这是不是游戏画面」。用 AI 生成一段和游戏里长得不一样的
   战斗动画，评论区第一句就是「这不是游戏画面」——得不偿失。40 秒里 AI 占 9 秒。
2. **不放真人配音，不放旁白。** 战鼓 + 钲 + 游戏自己的音效就够，配音一旦业余全片掉档。
3. **第一秒不能是 Logo。** 完播率杀手。第一秒必须是「有东西在动」。

### 时间轴（40 秒 / 30fps）

| 段 | 时间 | 画面 | 素材 | 处理 |
|---|---|---|---|---|
| 冷开场 | 0:00–0:05 | 一骑破纸冲出，墨点炸开 | `library_hero_charge`（原图）→ 图生视频 | 0.3s 黑场后硬切，鼓点进 |
| 对峙 | 0:05–0:09 | 双雄隔空，中间一道白 | `library_hero_duel` → 图生视频 | 慢横移 3%，鼓停、钲一声 |
| 字卡 1 | 0:09–0:13 | 公元前二〇六年／天下无主 | `title-card-1.png` | 102%→100% 缓推，墨渗淡入 |
| 玩法 | 0:13–0:21 | 三列铺兵 → 出牌 → 冲锋 → 掉血 | 真实录屏 | 每 1.2s 一刀，切点踩音效 |
| 字卡 2 | 0:21–0:24 | 一手牌／定天下 | `title-card-2.png` | 同上，短一点 |
| 危 | 0:24–0:29 | 「险」印亮起 → 被围杀 | 真实录屏 + 1.4× 裁切 | 心跳低频，画面轻微压暗 |
| 战役 | 0:29–0:34 | 八关地图逐个点亮 | 真实录屏 | 鼓点加密，横移跟手 |
| 高潮 | 0:34–0:37 | 垓下 · 敌将血条见底 | 真实录屏 0.5× 慢放 | 音乐留白 0.5s |
| 片尾 | 0:37–0:40 | 标题卡 | `title-card-end.png` | 余响淡出 |

### 镜头提示词（图生视频，首帧给下表左列的图）

**镜头 1 · 破纸（5s，首帧 `_art/no-title/library_hero_charge.png`）**

```
Camera: slow push in, locked horizon.
The ink painting comes alive: the black warhorse takes one heavy step toward
camera, hooves striking, a burst of black ink splatter exploding from the
ground and bleeding into the unpainted paper. Torn cloak and mane lift in the
wind, banner cloth whips once.
CRITICAL: the empty paper areas must stay empty — do not invent scenery, do
not fill white space, do not add background. Keep the paper grain visible.
5 seconds, 30 fps. No text, no watermark, no camera shake beyond a slight
impact jolt, no morphing faces, no extra limbs.
```

**镜头 2 · 对峙（4s，首帧 `_art/no-title/library_hero_duel.png`）**

```
Camera: very slow lateral dolly to the right, about 3% of frame width, locked
horizon, no zoom.
Both figures hold absolutely still — no walking, no head turns. Only cloth,
hair and low ink mist drift. Fine dust motes rise slowly through the empty
paper column between them, catching light. The vermilion sun behind the right
figure pulses faintly once.
4 seconds, 30 fps. No text. No added elements. No perspective change.
```

**镜头 8 的替代方案（如果不想录屏）**——不要用这个，录屏更好看也更真：

```
Camera: slow motion, 0.5x. An ink-painted army collapses backward into
splatter as a single figure falls; one seal-stamp-red impact blooms in the
middle of the frame and spreads through the paper like blood in water.
No gore, no bodies, abstract ink only.
```

### 只能一次生成的工具（Sora / Veo 这类单条 8s）

把两个镜头压成一条，一次出 8 秒，回来只截前 5 秒用：

```
8-second ink-wash cinematic, 16:9, single continuous shot.
Opens on a lone armoured horseman exploding out of empty xuan paper in a burst
of black ink splatter, riding toward camera. The camera pulls back and pans
right to reveal a second figure standing motionless far away across a wide
column of bare paper; the two face each other as dust drifts through the gap.
No text, no logo, no camera shake beyond the initial impact, no morphing.
```

### 字卡（已生成，直接用）

| 文件 | 内容 | 用法 |
|---|---|---|
| `title-card-1.png` | 公元前二〇六年／天下无主 | 4s，102%→100% 缓推 |
| `title-card-2.png` | 一手牌／定天下 | 3s，同上 |
| `title-card-end.png` | Logo + 卡牌对战 · 三列军阵 | 3s，定格，尾音淡出 |
| `title-card-end-en.png` | 英文版片尾 | 英文站/英文预告用 |

字卡动效别做花活：**不透明度 0→100 + 缩放 102%→100 + 0.2s 轻微模糊**，就够。
想要「墨渗」效果就叠一层纸纹理遮罩，别用那种抖音式的弹跳。

### 音频

- 配乐：`godot/assets/audio/bgm_title.wav` 正好 **43.6 秒**，当临时配乐铺满 40 秒，
  0:37 起淡出 1s。正式版再找人重做，但节奏照这条走（前 9s 慢、13s 起有鼓、34s 留白）。
- 音效：全部用游戏自己的，一致性最好——
  `sfx_card` 出牌 / `sfx_attack` 撞阵 / `sfx_hurt` 掉血 / `sfx_seal` 险印 /
  `sfx_omen` 事件 / `sfx_turn` 回合 / `sfx_win` 通关 / `sfx_lose` 兵败。
- 混音：配乐 −18 LUFS 左右垫底，音效 −10，别让配乐盖掉卡牌声（卡牌声是这游戏的质感）。

### 交付规格

| 项 | 值 |
|---|---|
| 分辨率 | 1920×1080（有 2560×1440 更好，Steam 两者都收） |
| 帧率 | 30fps 或 60fps，全场统一 |
| 编码 | H.264 High / 8–12 Mbps / AAC 192k |
| 长度 | 主预告 **30–60 秒**，这条 40 秒 |
| 版本 | 中文字幕版 + 英文字幕版各一条（Steam 按语言挂不同 trailer） |
| 禁止 | 黑边、片头超过 1s 的空镜、未上市平台图标、任何「coming soon」以外的日期承诺 |

### 录屏怎么录才干净

```bash
env -u ELECTRON_RUN_AS_NODE "D:/godot/Godot_v4.7.2-stable_win64.exe" \
  --path godot --resolution 1920x1080 --fullscreen
```

- 用 OBS 录 60fps、硬件编码，**隐藏鼠标光标**，画面里不要出现窗口标题栏。
- 每段录 15 秒以上，后期只取最好的一小节；一次拍成的东西节奏一定是散的。
- 玩法段建议拍第 4 关（荥阳）：盘面已有兵，看得出「三列」；第 1 关太空，第 8 关太长。
- 想省事：`godot/tests/battle_shot_peek.gd` 已经是「AI 双方对下 5 回合后停手」的脚本，
  改成录屏版就能一次拿到一段有内容的盘面。

---

## 6. 宣传片首帧 / 视频封面 1920×1080（可选）

```
Cinematic still, 16:9, ink-wash illustration in extreme wide shot.
A vast empty plain at dawn, viewed from low ground level. In the far distance
two opposing army blocks are rendered as two masses of ink — one warm umber,
one cold grey-black — with a wide strip of bare paper between them. Foreground:
a single abandoned war drum and a fallen banner, sharply detailed, catching
low vermilion light. Everything else dissolves into mist. Epic stillness,
no characters in focus. No text anywhere.
```

---

## 生成后的处理

1. 出图 → `store/steam/_art/_raw/`（原图不动）+ `store/steam/_art/no-title/`（同名副本）
2. 对齐尺寸：脚本按宽贴合、居中裁高，**不做非等比拉伸**；大幅上采走分段放大 + 轻锐化
3. 标题用 `python tools/make-steam-art.py` 排版（字距、朱砂点、副标题柔光）
4. 验收：缩到 50% 看标题是否还认得出；库英雄图先跑 `--check-hero`

## 注意

- 模型给不了精确像素尺寸。要 3840×1240 必须**出大图再裁/放**，别指望一次出对比例。
- 生成图里若出现疑似文字/印章的笔迹，必须擦掉——Steam 审核对乱码文字敏感，观感也脏。
- 立绘一致性：这两张脸不做 IP 锚定，靠 prompt 里的服饰/姿态特征区分即可；不要试图让
  模型复刻现有 `liubang.png` 的脸，会得到怪脸。
- 别在提示词里写「title area」「leave space for text」以外的文字描述——模型会把
  「text」这个词本身理解成「画一些字」。
