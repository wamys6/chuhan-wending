# 行军事件插图 · 第二批 6 张（生图提示词）

> 2026-11-03。第二批行军事件（10 → 16）的插图需求。**目前这 6 张没有图，事件页走「单字朱砂 glyph」兜底**（如「鸿沟之约」显示一个「和」字），不阻塞，出图后即可替换。

---

## 一、开始之前：这张图和卡牌立绘不一样

| | 卡牌立绘 | 事件插图 |
|---|---|---|
| 比例 | 1024×1536（2:3 竖） | **1024×1024（1:1 方）** |
| 显示 | 整卡铺满，名字条压住下 16% | **圆形窗 144×144，`COVER` 铺满** |
| 构图要求 | 头在上 1/3（15%~30%） | **主体必须在正中，四周留一圈空** |

**圆形裁切的后果**：一张方图放进圆窗，四角会被切掉。所以：

1. 主体（人/物）的**视觉重心放在画面正中央**，别贴边、别贴角；
2. 上下左右各留约 **12% 的余量**，宁可空一点也别让主体被圆边削掉；
3. 别画横向长条构图（会被裁成中间一小块），也别在四角放重要细节（必然被切）。

尺寸不对也没关系——`UiTheme.texture_rect()` 会按 `COVER` 等比铺满，但**比例差太多会裁掉主体**，所以还是按 1:1 出。

### 画风模板（中文，与卡牌同一套，只把竖幅改方）

```
中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，
笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，
方形构图，主体居中，四周留白，无文字，无边框，无水印，1:1
```

### 画风模板（英文，Midjourney 用）

```
Chinese ink-wash painting, ancient Chinese battlefield theme, rice-paper beige
background, bold ink outlines, muted ochre and slate-grey tones, dry-brush
strokes, ink splatter, tattered war banners and gunsmoke in background,
square composition, subject centered with generous margins,
no text, no border, no watermark --ar 1:1
```

### 负面提示词

```
文字, 水印, 边框, 卡通, 3D渲染, 塑料质感, 鲜艳配色, 现代元素, 照片, 横构图
```

### 命名与落位

| 项 | 值 |
|---|---|
| 文件名 | 必须完全一致（小写 + 下划线），存 `.png` |
| 放置路径 | `godot/assets/cards/`（98 张素材都在这一个目录里，不分子目录） |
| 出图后 | 告诉我，我登记 `game_data.gd` 的 `UI_ART.events` 并跑 `art_rect_test` 验收 |

---

## 二、六张的画面

### 1. `ev_jieqi.png` —— 借粮于民

- **机制**：立券借粮（+3 军粮 / 生命上限 −2）· 强征（−1 血 + 一张兵种牌）· 分兵屯田（+2 摸牌 / −1 血）
- **画面**：荥阳辕门外，一群布衣乡老捧着手写的券书，为首者躬身递上；旁边停着几辆装满粮袋的牛车；一名军吏执笔在木牍上记数。背景是被围的城墙与稀疏的炊烟。
- **要点**：这是「交易」不是「施舍」——父老的神情要**有底气**（他们握着粮），不是乞求。

### 2. `ev_guren.png` —— 故人夜访

- **机制**：厚赠遣归（敌 −2 军粮）· 恳其缓颊（+4 血 / −1 军粮）· 闭门不见
- **画面**：深夜营门前，一盏孤灯。一名披斗篷的中年男子立在门下，斗篷下露出楚式甲缘；门内一名持戟卫士侧身拦着。远处夜色里有一点楚军营火。
- **要点**：**暧昧**是关键——他是敌营的人，也是故人。灯火只能照亮半张脸。

### 3. `ev_shibing.png` —— 士卒思归

- **机制**：许诺还乡（+3 血 / 少摸一张）· 严防哗变（两张牌 / −3 血）· 就地休整（+1 摸牌）
- **画面**：月下的营地，几个士卒围着将熄的篝火坐在地上，一人低头吹埙（或低声而歌），其余人抱着膝盖听；远处帐影模糊。
- **要点**：**疲惫**，不是悲愤。别画哭天抢地，画「坐着不想动」。

### 4. `ev_dujiang.png` —— 渡河沉舟

- **机制**：减装急渡（+2 军粮 / 随机删一张）· 等水退（+2 摸牌 / 敌 +1 军粮）· 沿河缓行
- **画面**：暴涨的河岸渡口，浊浪翻卷；岸边只停着三五条小船，兵士正把箱笼辎重卸下堆在滩上；一名军校立在船头挥手催渡。
- **要点**：**水要画出力量**（墨色横向飞白），船要显得**不够**——这是这次抉择的由来。

### 5. `ev_qiufeng.png` —— 假王之举

- **机制**：立封齐王（两张牌 / −2 血）· 遣使安抚（+1 摸牌）· 斥其僭越（+3 血）
- **画面**：军帐之内，一名风尘仆仆的使者双手高举帛书；帐中几位将领或垂目、或侧视，无人出声；帐壁上挂着一幅齐地舆图。
- **要点**：**沉默**。这个事件的张力在「一时无人作声」，所以别给任何一张脸明确的表情。

### 6. `ev_honggou.png` —— 鸿沟之约

- **机制**：就此约和（+5 血 / 少摸一张）· 追而击之（−4 血 / 三张牌）· 虚与委蛇（+2 军粮）
- **画面**：鸿沟岸边，一条宽渠把画面分成两半；两岸各立旌旗（一边汉、一边楚），渠上一名使者捧盟书涉水而过，远处两军阵列模糊。
- **要点**：**一分为二的构图**本身就是「中分天下」。这张可以画得最静——它是全场少有的「停战」瞬间。

---

## 三、附录 · 拼好的完整 prompt

### 中文（直接复制）

1. **jieqi**：荥阳辕门外，一群布衣乡老捧着手写券书躬身递上，为首者有底气地直视军吏；旁边停着装满粮袋的牛车，军吏执笔在木牍上记数，背景是被围的城墙与稀疏炊烟，中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，方形构图，主体居中，四周留白，无文字，无边框，无水印，1:1
2. **guren**：深夜军营门前一盏孤灯，一名披斗篷的中年男子立于门下，斗篷下露出楚式甲缘，门内持戟卫士侧身拦阻，远处夜色里有一点楚军营火，灯火只照亮半张脸，中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，方形构图，主体居中，四周留白，无文字，无边框，无水印，1:1
3. **shibing**：月下营地，几个士卒围着将熄的篝火坐在地上，一人低头吹埙，其余人抱膝而听，神情疲惫，远处帐影模糊，中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，方形构图，主体居中，四周留白，无文字，无边框，无水印，1:1
4. **dujiang**：暴涨的河岸渡口，浊浪翻卷墨色横向飞白，岸边只停着三五条小船，兵士正把箱笼辎重卸下堆在滩上，一名军校立在船头挥手催渡，中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，方形构图，主体居中，四周留白，无文字，无边框，无水印，1:1
5. **qiufeng**：军帐之内，一名风尘仆仆的使者双手高举帛书，帐中几位将领或垂目或侧视，全场沉默无人出声，帐壁挂着齐地舆图，中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，方形构图，主体居中，四周留白，无文字，无边框，无水印，1:1
6. **honggou**：鸿沟岸边一条宽渠把画面分成两半，两岸各立旌旗一汉一楚，渠上一名使者捧盟书涉水而过，远处两军阵列模糊，画面极静，中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，方形构图，主体居中，四周留白，无文字，无边框，无水印，1:1

### 英文（Midjourney）

1. **jieqi**：Outside the gate of Xingyang, a group of village elders in plain cloth hold out written grain bonds, their leader meeting the army clerk's eye with quiet confidence; loaded ox carts wait beside them, the clerk brushes tallies onto a wooden slip, walls under siege and thin cook-smoke behind — Chinese ink-wash painting, ancient Chinese battlefield theme, rice-paper beige background, bold ink outlines, muted ochre and slate-grey tones, dry-brush strokes, ink splatter, square composition, subject centered with generous margins, no text, no border, no watermark --ar 1:1
2. **guren**：A lone lamp at a camp gate deep in the night; a cloaked middle-aged man stands below it, the edge of Chu armour showing beneath the cloak; a halberd guard inside bars the way; a single Chu watchfire glows far off; the lamplight catches only half his face — Chinese ink-wash painting, ancient Chinese battlefield theme, rice-paper beige background, bold ink outlines, muted ochre and slate-grey tones, dry-brush strokes, square composition, subject centered with generous margins, no text, no border, no watermark --ar 1:1
3. **shibing**：A moonlit camp; a few soldiers sit on the ground around a dying campfire, one bowed over a clay ocarina, the others listening with knees drawn up, worn out rather than weeping; tent shadows blur behind — Chinese ink-wash painting, ancient Chinese battlefield theme, rice-paper beige background, bold ink outlines, muted ochre and slate-grey tones, dry-brush strokes, square composition, subject centered with generous margins, no text, no border, no watermark --ar 1:1
4. **dujiang**：A swollen river ford, muddy waves in horizontal dry-brush strokes; only three or four small boats wait at the bank while soldiers unload chests and baggage onto the shoal; an officer on a prow waves them across — Chinese ink-wash painting, ancient Chinese battlefield theme, rice-paper beige background, bold ink outlines, muted ochre and slate-grey tones, dry-brush strokes, ink splatter, square composition, subject centered with generous margins, no text, no border, no watermark --ar 1:1
5. **qiufeng**：Inside a command tent, a travel-stained envoy raises a silk letter in both hands; several generals look down or aside, no one speaking; a map of Qi hangs on the tent wall — Chinese ink-wash painting, ancient Chinese battlefield theme, rice-paper beige background, bold ink outlines, muted ochre and slate-grey tones, dry-brush strokes, square composition, subject centered with generous margins, no text, no border, no watermark --ar 1:1
6. **honggou**：The bank of the Hong Canal — a broad channel divides the frame in two; Han banners on one side, Chu on the other; an envoy wades across holding a treaty scroll; distant armies blur into mist; the whole scene utterly still — Chinese ink-wash painting, ancient Chinese battlefield theme, rice-paper beige background, bold ink outlines, muted ochre and slate-grey tones, dry-brush strokes, ink splatter, square composition, subject centered with generous margins, no text, no border, no watermark --ar 1:1

---

## 四、出图之后

1. 6 张图放进 `godot/assets/cards/`（文件名 `ev_jieqi.png` 等）；
2. 我这边登记 `godot/core/game_data.gd` 的 `UI_ART["events"]`（键是事件 id，不带 `ev_` 前缀）；
3. 跑 `<GODOT> --headless --path godot --import` 重生 `.ctex`（记得先把 `compress/mode` 设 1、`lossy_quality` 0.8，跟其余 98 张一致，否则单张多占 2.5MB）；
4. 跑 `res://tests/art_rect_test.gd`：它会把「事件页取到本事件的插画」「圆图铺满 144 不是原图尺寸」验一遍；
5. `--tour` 出 `_gd-event.png`（事件是随机抽的，抽到谁不一定）——想定向看某一张，用 `Campaign.event_by_id("<id>")` 临时指定。
