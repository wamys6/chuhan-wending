# Steam 素材 · AI 生图提示词

配套脚本：`tools/make-steam-art.py`（PIL 排版合成）。
原则：**图由模型出，字由脚本排**——中文标题绝不让模型画（必出错字/伪汉字）。
所以所有提示词都要求「标题区域留空」。

## 共用风格段（每条 prompt 都带上，保证一套图同画风）

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

## 1. 库英雄图 3840×1240（最缺，优先级最高）

超宽 3.1:1。生成时按最宽比例出（21:9 或 2:1），再 LANCZOS 放大到 3840 宽、上下补纸色裁到 1240。
**标题区必须在正中，且左右各留 12% 安全边。**

### A 版 · 双雄对峙（延续现有双人对称构图）

```
Ultra-wide cinematic banner, 3:1 aspect ratio, ink-wash illustration.
Two warlords facing off across a vast empty void, mirror-symmetric composition.
LEFT: Liu Bang, founder of Han — a composed middle-aged man in simple dark
crimson-brown robes, hands clasped behind his back, a sheathed jian sword at
his waist, calm and watchful expression, slight smile of restraint. He stands
on pale ground, faint ink-wash mountains and a few reed stalks behind him.
RIGHT: Xiang Yu, Hegemon of Chu — a massive warrior in black lacquered lamellar
armor with bronze rivets, flowing black cloak torn by wind, holding a long
halberd diagonally, wild mane and beard, defiant stare, a warhorse's head
emerging from ink splatter behind him. Behind him a low vermilion sun bleeding
into grey ink clouds.
CENTER: intentionally EMPTY — a wide clean unpainted column of xuan paper,
about one third of the width, no figures, no ink, only a few stray splatter
droplets, reserved for a title.
Ground: dry brush sweeps and ink pools suggesting a battlefield, no literal
soldiers, no gore. No text anywhere.
```

### B 版 · 破阵（项羽单骑，更影视感、更抓眼）

```
Ultra-wide cinematic banner, 3:1 aspect ratio, ink-wash illustration.
A lone cavalry charge exploding out of ink: Xiang Yu on a black warhorse,
galloping toward the viewer's left, long halberd couched, black cloak and
mane streaming, lamellar armor catching one hard rim of light. A wall of ink
splatter and torn banner cloth trails behind him. Far background: a faint
Han army banner line dissolving into grey mist, deliberately unreadable.
The right half of the frame is almost entirely empty xuan paper with only
a few scattered splatter marks — reserved for a title.
Palette dominated by black ink and warm paper, one vermilion accent on the
banner tatters and the sun. No text anywhere.
```

---

## 2. 主胶囊 1232×706（16:9 附近，比 PIL 拼版更有画感）

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

## 4. 页面背景 1438×810（Steam 商店页背景，低对比不抢内容）

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

## 5. 宣传片首帧 / 视频封面 1920×1080（可选）

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

1. 出图 → `store/steam/_raw/`（不要直接覆盖成品）
2. 对齐尺寸：等比缩放到目标宽，纵向差额用纸色（`#F2E8D5`）+ 轻微噪声补齐，再轻微锐化
3. 标题用 `python tools/make-steam-art.py` 的排版函数叠上去（字距、朱砂分隔点、副标题柔光）
4. 验收：缩到 50% 看标题是否还认得出；库英雄图要单独看「正中留白有没有被人物侵入」

## 注意

- 模型给不了精确像素尺寸。要 3840×1240 必须**出大图再放大**，别指望一次出对比例。
- 生成图里若出现疑似文字/印章的笔迹，必须擦掉——Steam 审核对乱码文字敏感，观感也脏。
- 立绘一致性：这两张脸不做 IP 锚定，靠 prompt 里的服饰/姿态特征区分即可；不要试图让模型复刻现有 `liubang.png` 的脸，会得到怪脸。
