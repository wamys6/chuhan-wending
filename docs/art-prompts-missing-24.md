# 缺立绘的 24 张卡：生图提示词（✅ 已全部生成并接入，2026-11-03）

> **本文件已履行完毕**：24 张按此文档生成、1024×1536、文件名一致，已全部入库
> `godot/assets/cards/` 并在游戏内验收（图鉴/手牌/场上三处均显示真图）。
> 保留它是因为：① 它是以后扩池时的**提示词写法样本**（分组、构图约束、母题统一）；
> ② 实际生成参数与离线预览在 `docs/art-batch-24/`（`prompts.json` / `preview.html`）。
> 下面的约束条目仍然是有效的——**卡面只露纵向 8%~84%** 这条对所有新卡都成立。

> **用途**：把这份文件交给 AI 出图工具（即梦 / 通义万相 / 可灵 / Midjourney 都行）逐张生成，
> 按第一列命名成 `.png` 丢进 `godot/assets/cards/`，**不用改任何代码**——
> `UiTheme.art_texture()` 一找到图就接管，程序化占位（牌名首字）自动让位。
>
> **背景**：卡池 70 张，已有立绘 46 张，缺 24 张（本文档）。
> 缺图期间显示「纸色底 + 牌名首字」的占位，见 `docs/art-assets.md` 第十节。
> 画风必须与已有 46 张一致，规范原文在 `docs/art-assets.md` 第一节。

---

## 〇、先看这三条，能免掉大部分返工

**1. 画面下半部会被盖住，头部位置是硬的**

立绘铺满整张卡，但卡面下缘有一条名字条（从 84% 高度开始），攻血角标从 67% 高度起分列两侧；
图鉴大卡（290×360）还会再裁掉图片上下各 8.6%。所以**一张图实际可用的是纵向 8%~84%**。

| 主体放这里 | 结果 |
|---|---|
| 头部落在画面高度 **15%~30%** | ✅ 手牌、场上、图鉴三处都完整 |
| 人物下缘不低于 **70%** | ✅ 脚被名字条压住也没关系，只要脸和上身清楚 |
| 头部低于 40% 或居中 | ❌ 手牌上只剩半个身子，脸被裁掉 |
| 横向 | 左右不裁，可以放开构图 |

**2. 这 24 张里 16 张是「死战」牌，建议共用一个视觉符号**

死战（阵亡时触发）是这一版新增 Build 的核心。玩家要能从卡面**一眼认出这是死战牌**，
比每张各画各的更有用。见下面「两个母题」。

**3. 全是兵种和计谋，没有具名人物**

不要画成某某将军的肖像。画面靠「兵种身份 + 一个具体动作/道具」立住，
一件对的物件（断铁钳、缺口环首刀、签纸、拒马桩）比多画三个人管用。

---

## 一、画风（照抄，与已有 46 张一致）

### 中文模板（国产工具）

```
中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，
笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，
构图大气，人物位于画面上部居中，大半身，无文字，无边框，无水印，竖幅2:3
```

### 英文模板（Midjourney）

```
Chinese ink-wash painting, ancient Chinese battlefield theme, rice-paper beige
background, bold ink outlines, muted ochre and slate-grey tones, dry-brush
strokes, ink splatter, tattered war banners and gunsmoke in background,
heroic composition, subject in the upper third of the frame, half-body,
no text, no border, no watermark --ar 2:3
```

### 负面提示词

```
文字, 水印, 边框, 卡通, 3D渲染, 塑料质感, 鲜艳配色, 现代元素, 照片
```

### 尺寸

**1024×1536（2:3 竖幅）**，存 `.png`，文件名严格用下表第一列（小写、下划线）。
参考图就取 `godot/assets/cards/n_bing1.png`（兵·新卒），画风最接近这批兵种牌。

---

## 二、两个视觉母题（建议，不是硬性）

### 死战：前倾 + 一点朱砂

- **姿态**：低姿前压、身体前倾、兵器反握或朝下——不要挺胸竖戟的威风站姿，死战是「往前扑」不是「站得直」
- **色彩**：在淡赭与青灰里点**一处朱砂红**（缠臂红布、颈间布条、旗角、血痕），16 张靠这一处红连成一套
- **气氛**：尸横、断旗、硝烟压得低

### 守御：正面 + 横向工事

- **姿态**：正对观者，盾面 / 墙体 / 木栅占满画面前景下部，横平竖直
- **色彩**：土黄、石灰、木褐，**不加朱砂**（与死战牌形成对比）
- **气氛**：城墙、营垒、箭雨

---

## 三、A 组 · 工事（6 张，建议一套连做）

四张「城」是同一段城墙的四个局部，成套出图才像一套，零散补容易四种土色。

| 文件名 | 卡牌 | 机制 | 画面主体描述 |
|---|---|---|---|
| `n_dun1.png` | 盾·持盾卒 | 守御 · 1/3 · 登场抽牌 | 蹲踞的步卒把一面拼凑的大盾立在身前，盾面由木板与生皮钉成、布满箭孔，人几乎全藏在盾后，只露出一只戒备的眼睛 |
| `n_lei1.png` | 垒·拒马 | 守御 · 1/4 · 登场前锋+1攻 | 削尖的木桩交叉扎成的拒马横陈阵前，桩身缠着浸油麻布、钉着铁刺，桩后一名弓手正张弦瞄准 |
| `n_cheng1.png` | 城·土垣 | 守御 · 1/6 | 一段刚夯成的黄土矮墙，墙面留着夯窝与横木模板痕，墙头插着几支断箭，墙脚堆满沙袋碎石 |
| `n_cheng2.png` | 城·女墙 | 守御 · 2/6 · 死战中军+1攻 | 城墙顶端的垛口近景，一名弓手半蹲墙后只露兜鍪与弓臂，垛口砖石崩缺，远处烟尘漫过城头 |
| `n_cheng3.png` | 城·瓮城 | 守御 · 2/7 · 登场主将回2血 | 从城内仰视的瓮城，两道厚重门洞层层嵌套，门钉与铁箍泛着冷光，门道里横着一架攻城的云梯残件 |
| `n_cheng4.png` | 城·坚壁 | 守御 · 3/8 · 死战全体+1攻 | 高耸的夯土城墙正面压满画面，墙身嵌着加固木骨、裂缝用草泥草草补过，墙下尸骸与断梯枕藉 |

## 四、B 组 · 兵卒（7 张）

| 文件名 | 卡牌 | 机制 | 画面主体描述 |
|---|---|---|---|
| `n_bing5.png` | 兵·刑徒 | 死战 · 2/2 · 阵亡补新卒 | 骊山刑徒，赭色囚衣破到露肉，颈上还挂着断开的铁钳，赤脚握短戈，眼里是豁出去的死气 |
| `n_bing6.png` | 兵·戍兵 | 守御 · 1/4 · 死战补新卒 | 边关戍卒，皮甲外罩磨白的粗布，抱一面旧盾持矛倚墙，脸颊皴裂，身后是望不到头的烽燧 |
| `n_bing7.png` | 兵·死士队 | 死战 · 3/4 · 阵亡补新卒 | 三名赤膊缠红带的死士并肩前压，短刀反握，肩背相抵连成密集锋线，脚下是同伴的尸身 |
| `n_bing8.png` | 兵·降卒 | 死战 · 2/2 · 阵亡抽牌 | 卸甲的降卒低头站着，甲片松松挂着，缚绳垂在地上并没系紧，一只手在身后悄悄攥着一片竹简 |
| `n_bing9.png` | 兵·斥候 | 死战 · 2/2 · 阵亡伤敌前锋1 | 伏在枯草丛里的斥候只露头肩，一手压低草叶、一手按着短刀，远处敌营篝火串成一线 |
| `n_bing10.png` | 兵·死囚 | 死战 · 4/2 · 阵亡重创残血 | 黥面死囚散发遮住半张脸，腕上锁链已断，拖着缺口环首刀向前扑，身上只剩一条腰布 |
| `n_xiangyong.png` | 兵·乡勇 | 无关键词 · 1/3 | 刚被征来的乡里青壮，扛着锄头木棍站成一排，衣不蔽体却神情认真，队形歪斜 |

## 五、C 组 · 士与将（6 张）

| 文件名 | 卡牌 | 机制 | 画面主体描述 |
|---|---|---|---|
| `n_shi4.png` | 士·断后 | 守御 · 2/5 · 死战前锋+1攻 | 侧背影的甲士横矛独守隘口断桥，身后是正在撤离的队伍与漫天尘烟，他一动不动 |
| `n_shi5.png` | 士·骸骨 | 死战 · 3/4 · 阵亡中军+1攻 | 半埋土中的骸骨仍披着残甲，指骨紧扣一杆断矛，周围斜插褪色残旗，白骨如刃 |
| `n_shi6.png` | 士·门客 | 死战 · 3/4 · 阵亡抽牌 | 布衣门客束发佩剑，向画外深揖到底，袖中滑出半卷竹简——揖完即转身赴死 |
| `n_shi7.png` | 士·死节 | 守御 · 3/6 · 死战主将回3血 | 重甲卫士跪坐持戟不倒，身中数箭、血染甲绦，身后残旗半卷，仍在守着退路 |
| `n_jiang1.png` | 将·偏将 | 死战 · 4/3 · 阵亡中军+1攻 | 偏将立于阵中高举令旗，盔缨残破，身后士卒按他的旗号整齐转向，甲胄上全是战场灰土 |
| `n_jiang2.png` | 将·死士将 | 死战 · 5/4 · 阵亡全场2伤 | 死士之将身披赤黑重甲、双持长刀，立于尸山顶上回身怒喝，身后营火冲天 |

## 六、D 组 · 杂项（2 张）

| 文件名 | 卡牌 | 机制 | 画面主体描述 |
|---|---|---|---|
| `n_yi1.png` | 医·随军医 | 死战 · 1/3 · 阵亡主将回2血 | 随军医者背着药囊蹲在伤卒身旁包扎，一手持艾柱一手按着伤口，帐下地面有血迹与散落的药草 |
| `n_che4.png` | 车·决死车 | 冲锋 · 4/4 · 死战伤敌前锋2 | 一辆拆了车篷的轻车，马蒙着眼、车厢塞满柴薪，甲士推车狂奔，车尾已窜起火苗 |

## 七、E 组 · 计谋（3 张）

计谋牌画「场景意象」，不要画面孔清楚的主角。

| 文件名 | 卡牌 | 机制 | 画面主体描述 |
|---|---|---|---|
| `n_zhengfa.png` | 令·征发 | 召唤 1/2 新卒到前锋 | 乡野间设着征兵木案，官吏举木牍点人，一排青壮被绳索牵出队列，村舍与征旗在远处 |
| `n_xuanshang.png` | 令·悬赏 | 抽牌 + 主将回2血 | 城门下贴着的悬赏木牌，一串铜钱压着印信挂在牌上，围观人群只见背影，案上搁着几枚金饼 |
| `n_huogong.png` | 令·火攻 | 敌中军列 3 伤 | 夜空下敌营中段起火，火舌卷上粮车与帐篷，远处一排弓手正在射出火箭 |

---

## 八、附录 A · 整段可粘贴（中文）

画风模板已拼在每条末尾，一次复制一条即可。**建议一次做一组**（同组画面更成套）。

**A 组**

```
蹲踞的步卒把一面拼凑的大盾立在身前，盾面由木板与生皮钉成、布满箭孔，人几乎全藏在盾后，只露出一只戒备的眼睛。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，大半身，无文字，无边框，无水印，竖幅2:3
```
```
削尖的木桩交叉扎成的拒马横陈阵前，桩身缠着浸油麻布、钉着铁刺，桩后一名弓手正张弦瞄准。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，主体位于画面上部居中，无文字，无边框，无水印，竖幅2:3
```
```
一段刚夯成的黄土矮墙，墙面留着夯窝与横木模板痕，墙头插着几支断箭，墙脚堆满沙袋碎石。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，主体位于画面上部居中，无文字，无边框，无水印，竖幅2:3
```
```
城墙顶端的垛口近景，一名弓手半蹲墙后只露兜鍪与弓臂，垛口砖石崩缺，远处烟尘漫过城头。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，主体位于画面上部居中，无文字，无边框，无水印，竖幅2:3
```
```
从城内仰视的瓮城，两道厚重门洞层层嵌套，门钉与铁箍泛着冷光，门道里横着一架攻城的云梯残件。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，主体位于画面上部居中，无文字，无边框，无水印，竖幅2:3
```
```
高耸的夯土城墙正面压满画面，墙身嵌着加固木骨、裂缝用草泥草草补过，墙下尸骸与断梯枕藉。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，主体位于画面上部居中，无文字，无边框，无水印，竖幅2:3
```

**B 组**

```
骊山刑徒，赭色囚衣破到露肉，颈上还挂着断开的铁钳，赤脚握短戈，眼里是豁出去的死气，臂上缠一条朱砂红布。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，大半身，身体前倾，无文字，无边框，无水印，竖幅2:3
```
```
边关戍卒，皮甲外罩磨白的粗布，抱一面旧盾持矛倚墙，脸颊皴裂，身后是望不到头的烽燧。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，大半身，无文字，无边框，无水印，竖幅2:3
```
```
三名赤膊缠红带的死士并肩前压，短刀反握，肩背相抵连成密集锋线，脚下是同伴的尸身，臂上皆缠朱砂红布。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，大半身，身体前倾，无文字，无边框，无水印，竖幅2:3
```
```
卸甲的降卒低头站着，甲片松松挂着，缚绳垂在地上并没系紧，一只手在身后悄悄攥着一片竹简。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，大半身，无文字，无边框，无水印，竖幅2:3
```
```
伏在枯草丛里的斥候只露头肩，一手压低草叶、一手按着短刀，远处敌营篝火串成一线。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，无文字，无边框，无水印，竖幅2:3
```
```
黥面死囚散发遮住半张脸，腕上锁链已断，拖着缺口环首刀向前扑，身上只剩一条腰布。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，大半身，身体前倾，无文字，无边框，无水印，竖幅2:3
```
```
刚被征来的乡里青壮，扛着锄头木棍站成一排，衣不蔽体却神情认真，队形歪斜松散。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，大半身，无文字，无边框，无水印，竖幅2:3
```

**C 组**

```
侧背影的甲士横矛独守隘口断桥，身后是正在撤离的队伍与漫天尘烟，他一动不动。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，大半身，无文字，无边框，无水印，竖幅2:3
```
```
半埋土中的骸骨仍披着残甲，指骨紧扣一杆断矛，周围斜插褪色残旗，白骨如刃，缠着一条褪色红布。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，构图大气，主体位于画面上部居中，无文字，无边框，无水印，竖幅2:3
```
```
布衣门客束发佩剑，向画外深揖到底，袖中滑出半卷竹简，背影透着诀别之意。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，大半身，无文字，无边框，无水印，竖幅2:3
```
```
重甲卫士跪坐持戟不倒，身中数箭血染甲绦，身后残旗半卷，仍在守着退路。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，大半身，无文字，无边框，无水印，竖幅2:3
```
```
偏将立于阵中高举令旗，盔缨残破，身后士卒按他的旗号整齐转向，甲胄上全是战场灰土。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，人物位于画面上部居中，大半身，无文字，无边框，无水印，竖幅2:3
```
```
死士之将身披赤黑重甲双持长刀，立于尸山顶上回身怒喝，身后营火冲天，甲上系朱砂红绦。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，构图大气，人物位于画面上部居中，大半身，无文字，无边框，无水印，竖幅2:3
```

**D 组**

```
随军医者背着药囊蹲在伤卒身旁包扎，一手持艾柱一手按着伤口，帐下地面有血迹与散落的药草。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，背景隐约有残破战旗与硝烟，构图大气，主体位于画面上部居中，无文字，无边框，无水印，竖幅2:3
```
```
一辆拆了车篷的轻车，马蒙着眼、车厢塞满柴薪，甲士推车狂奔，车尾已窜起火苗，烟尘翻滚。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，画面有战损感，构图大气，主体位于画面上部居中，无文字，无边框，无水印，竖幅2:3
```

**E 组**

```
乡野间设着征兵木案，官吏举木牍点人，一排青壮被绳索牵出队列，村舍与征旗在远处。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，构图大气，主体位于画面上部居中，无文字，无边框，无水印，竖幅2:3
```
```
城门下贴着的悬赏木牌，一串铜钱压着印信挂在牌上，围观人群只见背影，案上搁着几枚金饼。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，构图大气，主体位于画面上部居中，无文字，无边框，无水印，竖幅2:3
```
```
夜空下敌营中段起火，火舌卷上粮车与帐篷，远处一排弓手正在射出火箭，浓烟蔽月。中国水墨画风格插画，古战场题材，宣纸米白色底，浓墨勾勒、淡赭与青灰设色，笔触苍劲带飞白，墨点飞溅，构图大气，无文字，无边框，无水印，竖幅2:3
```

---

## 九、附录 B · Midjourney 英文 prompt

```
A convict of Mount Li, ragged ochre prison garb, a broken iron collar still around his neck, barefoot gripping a short dagger-axe, desperate eyes, a vermilion cloth band on his arm. Chinese ink-wash painting, ancient Chinese battlefield theme, rice-paper beige background, bold ink outlines, muted ochre and slate-grey tones, dry-brush strokes, ink splatter, tattered war banners and gunsmoke, heroic composition, subject in the upper third of the frame, half-body, leaning forward, no text, no border, no watermark --ar 2:3
```

以下只给「主体 + 差异词」，画风后缀同上一条（MJ 里追加到 prompt 末尾即可）：

| 文件 | 英文主体 |
|---|---|
| `n_dun1` | A crouching infantryman behind an improvised shield of nailed planks and hide, pierced by arrows, only one wary eye visible above the rim |
| `n_lei1` | Sharpened stakes lashed into a cheval-de-frise across the front, oiled rags and iron spikes on the wood, an archer drawing his bow behind it |
| `n_cheng1` | A freshly rammed earthen rampart, ramming pits and timber formwork marks on the wall, broken arrows stuck in the parapet, sandbags at its foot |
| `n_cheng2` | Close view of a battlement merlon, an archer crouching behind it with only helmet and bow arm showing, chipped bricks, gunsmoke drifting past the wall top |
| `n_cheng3` | Looking up from inside a barbican, two massive gateways nested one behind the other, iron studs and hoops glinting, a broken siege ladder in the passage |
| `n_cheng4` | A towering rammed-earth city wall filling the frame, timber reinforcement embedded in the body, cracks patched with mud, corpses and broken ladders below |
| `n_bing5` | Mount Li convict, ragged ochre prison garb, a broken iron collar still on his neck, barefoot gripping a short dagger-axe, desperate eyes, vermilion cloth band |
| `n_bing6` | Frontier garrison soldier, worn cloth over leather armour, leaning on a wall with an old shield and spear, cracked weathered face, beacon towers stretching behind |
| `n_bing7` | Three bare-chested death squad soldiers advancing shoulder to shoulder, reversed short blades, vermilion cloth bands on their arms, comrades' bodies underfoot |
| `n_bing8` | A surrendered soldier standing with head down, armour hanging loose, binding ropes trailing untied on the ground, one hand hiding a bamboo slip behind his back |
| `n_bing9` | A scout lying in dry grass with only head and shoulders showing, one hand pressing down the stalks, the other on a short blade, enemy campfires in the distance |
| `n_bing10` | A tattooed condemned prisoner, matted hair over half his face, broken shackles on his wrists, lunging forward with a notched ring-hilted blade, only a loincloth left |
| `n_xiangyong` | Newly conscripted village youths standing in a crooked row with hoes and wooden clubs, barely clothed but earnest, loose undisciplined formation |
| `n_shi4` | Rear view of an armoured soldier holding a spear level alone at a broken bridge pass, retreating troops and dust behind him, utterly still |
| `n_shi5` | A half-buried skeleton still wearing broken armour, finger bones locked around a snapped spear, faded banners stuck in the earth around it, bones like blades |
| `n_shi6` | A retainer in plain cloth, hair bound, sword at his waist, bowing deeply away from the viewer, a bamboo scroll slipping from his sleeve |
| `n_shi7` | An armoured guard kneeling upright on his halberd, arrows in his body, blood soaking the armour cords, a half-furled banner behind him, still holding the retreat |
| `n_jiang1` | A junior commander raising a signal banner in the middle of the line, tattered plume, soldiers turning in unison to his flag, dust over the armour |
| `n_jiang2` | A death-squad commander in crimson-black heavy armour with twin long sabres, standing on a hill of corpses roaring back over his shoulder, campfires behind |
| `n_yi1` | A field physician in a medicine satchel crouching to bandage a wounded soldier, moxa stick in one hand, blood and scattered herbs on the tent floor |
| `n_che4` | A stripped-down light chariot, horse blindfolded, bed packed with firewood, soldiers shoving it at a run, flames catching at the tail |
| `n_zhengfa` | A conscription table in a village, an official holding up a wooden register, young men roped out of the line, farmhouses and banners behind |
| `n_xuanshang` | A bounty board pasted at a city gate, strings of copper coins weighing down a seal tag, onlookers seen only from behind, gold cakes on the table |
| `n_huogong` | An enemy camp's centre caught fire at night, flames climbing over grain carts and tents, a row of archers loosing fire arrows, smoke across the moon |

---

## 十、交付与验收

1. **命名**：见第一列，如 `n_bing5.png`；**必须是 `.png`**，小写。
2. **放这里**：`godot/assets/cards/`（注意是 `godot/` 下面那层，不是项目根目录）。
3. **不用改代码**：`UiTheme.art_texture()` 按文件名找图，找到就接管，占位层自动让位；
   手牌、场上单位、图鉴三处同时生效。
4. **单张就能验**：随时丢一张进去跑
   ```
   cd godot && env -u ELECTRON_RUN_AS_NODE "D:/godot/Godot_v4.7.2-stable_win64.exe" --path . -- --tour
   ```
   看 `tests/_gd-battle-campaign.png`（手牌）、`_gd-codex-cards.png`（图鉴大卡）。
5. **重点看两件事**：① 头部有没有被名字条或上边框切到；② 一屏 8~10 张里能否一眼认出死战牌。
6. **24 张全补齐之后**：`card_art_test.gd` 会在检测不到缺图卡时自动放行（打印「卡池已全部有图」并跳过），
   不需要改测试。届时占位层只剩兜底作用，可以留着不动。

---

## 附：本批清单速查（24）

工事 6：`n_dun1` `n_lei1` `n_cheng1` `n_cheng2` `n_cheng3` `n_cheng4`
兵卒 7：`n_bing5` `n_bing6` `n_bing7` `n_bing8` `n_bing9` `n_bing10` `n_xiangyong`
士将 6：`n_shi4` `n_shi5` `n_shi6` `n_shi7` `n_jiang1` `n_jiang2`
杂项 2：`n_yi1` `n_che4`
计谋 3：`n_zhengfa` `n_xuanshang` `n_huogong`

其中**死战 16 张**：`n_bing5` `n_bing6` `n_bing7` `n_bing8` `n_bing9` `n_bing10` `n_shi4` `n_shi5` `n_shi6` `n_shi7` `n_jiang1` `n_jiang2` `n_cheng2` `n_cheng4` `n_yi1` `n_che4`
**守御 9 张**：`n_dun1` `n_lei1` `n_cheng1` `n_cheng2` `n_cheng3` `n_cheng4` `n_shi4` `n_shi7` `n_bing6`
