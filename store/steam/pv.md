# 宣传片制作包（40 秒 · Steam 主预告）

> **这份文档是自包含的，不用回头看 `prompts.md`。** 拿它就能开始生成。
> 生成的是**两个 AI 氛围镜头**，其余是游戏录屏 + 已做好的字卡。
> 配套：`store/steam/_pv/` 里两张 16:9 首帧、`title-card-*.png` 三张字卡、`godot/assets/audio/` 全套音效。

---

## 〇、先看这一段：40 秒要说清什么

一条预告片只回答三个问题，按玩家划走的速度排序：

| 顺序 | 玩家此刻在想 | 片子里由谁回答 | 时间 |
|---|---|---|---|
| 1 | 「什么味道？」 | 两个 AI 水墨镜头 | 0–9s |
| 2 | 「玩什么？」 | 真实录屏：铺兵 → 出牌 → 撞阵 | 13–21s |
| 3 | 「有多深？」 | 录屏：险印围杀 + 八关地图 | 24–34s |
| 4 | 「叫什么？」 | 片尾标题卡 | 37–40s |

**核心任务：让「水墨」和「卡牌」两个信息在 15 秒内都进脑子。** 缺一个，商店页就会有人
留言「这是美术集吗」或者「这是动作游戏吗」——两种都是致命的品类误判。

### 三条铁律（违反任意一条，片子白做）

1. **AI 只做 9 秒氛围，战斗一律用真实录屏。** 用 AI 生成一段和游戏里长得不一样的战斗，
   评论区第一句就是「这不是游戏画面」，得不偿失。
2. **不放真人配音、不放旁白。** 战鼓 + 钲 + 游戏自己的音效就够。业余配音会让全片掉档，
   而且中英双语要配两版，成本翻倍收益为负。
3. **第一秒不能是 Logo，不能是黑屏。** 第一秒必须是「有东西在动」。Steam 商店页的预告片
   通常是静音自动播放的，前 3 秒决定他留不留——而静音状态下能传递信息的只有画面。

---

## 一、时间轴（40 秒 / 30fps / 1200 帧）

| 段 | 时间 | 帧 | 画面 | 来源 | 时长来源 |
|---|---|---|---|---|---|
| 冷开场 | 0:00–0:05 | 0–150 | 一骑破纸冲出，墨点炸开 | **AI 镜头 1** | 生成 5s |
| 对峙 | 0:05–0:09 | 150–270 | 双雄隔空，中间一道空纸 | **AI 镜头 2** | 生成 4s（不足则补 1s 静帧） |
| 字卡 1 | 0:09–0:13 | 270–390 | 公元前二〇六年／天下无主 | `title-card-1.png` | 4s |
| 玩法 | 0:13–0:21 | 390–630 | 三列铺兵 → 出牌 → 冲锋 → 掉血 | **真实录屏** | 8s |
| 字卡 2 | 0:21–0:24 | 630–720 | 一手牌／定天下 | `title-card-2.png` | 3s |
| 危 | 0:24–0:29 | 720–870 | 险印亮起 → 被围杀 | **真实录屏**（1.4× 裁切） | 5s |
| 战役 | 0:29–0:34 | 870–1020 | 八关地图逐个点亮 | **真实录屏** | 5s |
| 高潮 | 0:34–0:37 | 1020–1110 | 垓下 · 敌将血条见底 | **真实录屏** 0.5× 慢放 | 3s |
| 片尾 | 0:37–0:40 | 1110–1200 | 标题卡 + 副标题 | `title-card-end.png` | 3s |

**AI 占比 9/40 = 22.5%**，其余是真实画面。这个比例不是审美选择，是可信度预算：
超过 1/3 就会被当成「CG 宣传片」，玩家对 CG 的默认态度是「游戏里肯定不这样」。

### 一个我留着的风险，你自己判断要不要改

前 9 秒只有氛围、13 秒才出现第一张卡牌。按商店页的划走速度，这个顺序是**赌**
「美术先抓人」——楚汉水墨确实抓人，赌得不算大，但它是赌。

**B 方案（0:03 插 1.2 秒玩法闪前）**：在镜头 1 的第 3 秒硬切 1.2 秒录屏（一张牌拍在阵上、
部队砸过去），再切回镜头 1 的后 1.8 秒。代价是冷开场的气势断了；收益是第 3 秒就有人看到
「这是卡牌」。**两种都出，二选一。** 判断依据只有外部平台能给：Steam 后台不提供预告片的
逐段留存，把两条都挂到 YouTube 看 audience retention（第 3 秒和第 13 秒各掉多少），或者看
商店页访问→愿望单的整体转化。这个数只有发出去才知道，我给不了。[待验证]

---

## 二、AI 镜头 1 · 破纸（5 秒）

**首帧**：`store/steam/_pv/frame-01-charge-16x9.png`（1920×1080）

> 为什么不用库英雄原图：那张是 3840×1240 = 3.1:1，喂给 16:9 的视频工具会被**居中裁**
> 掉左右各 42%，人直接没了。这张是我从原图左侧按 16:9 裁出来的，主体完整、右侧留白。

**这一镜要玩家感受什么**：静止的水墨画突然「活」了——不是动画化，是**纸上的墨挣出来了**。
所以运动必须小、必须重，不能飘。

**运动处方**（给模型的动作预算，别加戏）：

| 项 | 给多少 | 理由 |
|---|---|---|
| 镜头运动 | 缓推 ≤ 3% 画幅 | 再快就变成「幻灯片推拉」，水墨的静气压不住 |
| 主体动作 | 马走一步 + 鬃毛/披风扬起 | 图生视频最容易崩的是四肢和脸，大动作必崩 |
| 墨点 | 一次爆开，向外扩 | 这是唯一的「特效」，也是全片最贵的一秒 |
| 空纸 | **绝对不能动、不能填** | 见下方失败信号 A3 |

```
Camera: very slow push in (about 3% of frame width over the shot), locked horizon, no zoom, no handheld shake.

The ink painting comes alive: the black warhorse takes ONE heavy step toward camera, hooves striking the ground, a burst of black ink splatter exploding from the impact point and blooming outward into the unpainted paper fibers. Torn black cloak and mane lift in the wind and settle. The banner cloth behind him whips once. The rider's face and grip stay still — no head turn, no expression change.

CRITICAL: the empty paper areas on the right and bottom must stay empty. Do not invent scenery, do not fill white space, do not add mountains, clouds, soldiers or background wash. Keep the paper grain and the dry-brush fly-white edges visible and unchanged.

5 seconds, 30 fps, 16:9. Palette locked: warm off-white paper, charcoal-black ink, muted umber, a single vermilion accent.
No text, no lettering, no seal, no logo, no watermark. No camera shake beyond one slight impact jolt. No morphing faces, no extra limbs, no perspective change.
```

**提示词有长度限制时用这条**（约 240 字符，保留全部硬约束）：

```
Slow push in. The ink-painted black warhorse takes one heavy step toward camera; black ink splatter bursts from the hooves and blooms into the empty paper. Cloak and mane lift, banner whips once. Keep all empty paper empty — no added scenery, no clouds. No text, no logo, no morphing faces, no extra limbs.
```

**生成几条**：2–3 条。取「马只走一步、墨点一次性爆开」的那条；走两步以上的删——第二步
必然是滑步，一看就假。

---

## 三、AI 镜头 2 · 对峙（4 秒）

**首帧**：`store/steam/_pv/frame-02-duel-16x9.png`（1920×1080）

> 来源是主胶囊那张 1.75:1 的双人半身图（左刘邦、右项羽、中间空纸 + 朱砂点），
> 只差 1.7% 就是 16:9，裁剪几乎无损。
> **不能用库英雄 duel 那张**：两人相距 0.84 个画面宽，16:9 装不下，一裁两人各少一半。

**这一镜要玩家感受什么**：不是「要打了」，是**「两个人隔着一整张白纸看着对方」**——
那种必须动手之前的长静默。所以它必须是全片唯一完全不动的镜头。

**运动处方**：

| 项 | 给多少 | 理由 |
|---|---|---|
| 镜头 | 横移 3% 画幅，无缩放 | 完全静止的 4 秒在预告片里会「卡住」观感，极慢横移是唯一的救法 |
| 人物 | **零动作** | 一动就变成「两个人站着抖」，比不动更假 |
| 可动的 | 衣角、发丝、浮尘、远处墨雾 | 只给这些东西动，画面才「活而不动」 |
| 朱砂点 | 可微亮一次 | 这是全片唯一的「点睛」，只准亮一次 |

```
Camera: extremely slow lateral dolly to the right, about 3% of frame width across the whole shot. Locked horizon, no zoom, no parallax, no handheld motion.

Both figures hold ABSOLUTELY still — no walking, no head turn, no breathing exaggeration, no expression change, no hand movement. Only their cloak edges, loose hair and the low ink mist drift very slightly. Fine dust motes rise slowly through the empty paper column between them, catching the light. The small vermilion seal blot at the bottom of the empty column pulses faintly once, then holds.

CRITICAL: keep the large empty paper column between the two figures completely empty. Do not add soldiers, banners, landscape, clouds or background ink wash into it. Do not bring the two figures closer.

4 seconds, 30 fps, 16:9. Same palette and paper texture as the first frame. No text, no lettering, no logo, no seal stamp added, no watermark. No perspective change, no morphing faces, no extra limbs.
```

**提示词有长度限制时用这条**：

```
Extremely slow lateral dolly. Both figures absolutely still — no head turn, no hand movement. Only cloak edges, hair and low ink mist drift; dust rises through the empty paper column between them. Keep that column empty — no added soldiers, banners or landscape. No text, no morphing, no perspective change.
```

**生成几条**：2 条。挑「人物真的没动」的那条。判断方法：首末帧各截一张，量两人在画面里的
水平位移——镜头本身横移 3%，所以位移 **5% 以内算没动，超过 5% 就是他们在偷偷挪**，删。

---

## 四、选工具只看三条

不推荐具体产品——这类工具几个月换一版，写名字等于写过期信息。**三个能力能满足就够用**：

| 能力 | 为什么必须有 |
|---|---|
| 支持**首帧图生视频** | 本片的核心是「这张画活过来」，纯文生视频做不出这个画风 |
| 支持 **16:9** | 竖屏或方形会毁掉构图；3.1:1 要主动避免（工具会自己居中裁） |
| 单条能给 **≥5 秒** | 少于 5 秒镜头 1 就得拆成两段，接缝在墨点爆开处必然露 |

三条都满足的话，出片质量差异主要来自**你给的首帧**和**运动描述写得多克制**，不是来自
换模型。先用现有的试一条，不满意再换工具，别一上来横向比价。

> 下面两条提示词是英文——多数视频模型对英文结构句（尤其否定句）跟得更准。
> 如果你的工具中文优化更好，**直译可以，但两句不能丢**：CRITICAL 那段的「不要填空纸」，
> 和结尾那串 No text / no morphing / no extra limbs。

### 只用一条 8 秒（Sora / Veo 这类）

把两镜压成一条，回来只截前 5 秒（或整条用，把对峙延到 8 秒、字卡 1 缩到 3 秒）。首帧用
`store/steam/_pv/frame-01-charge-16x9.png`。

```
8-second single continuous shot, 16:9, ink-wash illustration on xuan rice paper coming alive.

0–5s: a lone armoured horseman rides one heavy step toward camera out of empty paper; black ink splatter explodes from the hoof impact and blooms into the paper fibers; cloak and mane lift and settle. Camera pushes in about 3%.

5–8s: the camera pulls back and pans right, revealing a second figure standing motionless far across a wide column of bare paper; dust drifts through the gap; the two face each other and neither moves.

CRITICAL: keep all empty paper empty — no invented landscape, no clouds, no additional soldiers. Keep paper grain and dry-brush edges. No text, no lettering, no logo, no watermark. No camera shake after the initial impact. No morphing faces, no extra limbs.
```

⚠️ 单条生成的常见问题：前半段气势对了，后半段「拉远」时把纸面填满风景。**验收只看后 3 秒
的空白纸**，填了就废。

---

## 五、字卡（已生成，直接用）

| 文件 | 内容 | 用多久 | 动效 |
|---|---|---|---|
| `store/steam/title-card-1.png` | 公元前二〇六年／天下无主 | 4s | 102%→100% 缓推 + 墨渗淡入 |
| `store/steam/title-card-2.png` | 一手牌／定天下 | 3s | 同上 |
| `store/steam/title-card-end.png` | 标题 + 卡牌对战 · 三列军阵 | 3s | 定格，尾音淡出 |
| `store/steam/title-card-end-en.png` | 英文版片尾 | 3s | 英文站/英文预告用这条 |

动效只做三样：**不透明度 0→100、缩放 102%→100、0.2s 轻微模糊**。别做弹跳、别做旋转、
别做「墨滴炸开转场」——那类效果在 4K 屏上会暴露素材分辨率。

---

## 六、录屏：全片 21 秒，四个段落

### 6.1 拍之前

```bash
env -u ELECTRON_RUN_AS_NODE "D:/godot/Godot_v4.7.2-stable_win64.exe" \
  --path godot --resolution 1920x1080 --fullscreen
```

- OBS：**60fps**、硬件编码（NVENC）、**隐藏鼠标光标**、不录窗口标题栏。
- 每段**录 15 秒以上**，后期只取最好的一小节。一次拍成的节奏一定是散的。
- 拍**第 4 关（荥阳）**：盘面已有兵，看得出「三列」；第 1 关太空，第 8 关太长。
- 省事路径：`godot/tests/battle_shot_peek.gd` 已经是「AI 双方对下 5 回合后停手」的脚本，
  改成录屏版就能一次拿到有内容的盘面。

### 6.2 玩法段（8 秒，390–630 帧）要拍到这四个动作

| 时间 | 动作 | 音频 | 为什么要有 |
|---|---|---|---|
| 0.0–2.4s | 点一张手牌 → 落在中军列 | `sfx_card`（0.30s） | 第一眼要看到「卡牌」这个实体 |
| 2.4–4.8s | 出攻击牌 → 冲锋动画 → 撞在敌阵上 | `sfx_attack`（0.40s） | 展示「三列」的空间关系 |
| 4.8–7.2s | 敌方反击，我方血条掉一截 | `sfx_hurt`（0.30s） | 有来有回，不是单向演示 |
| 7.2–8.0s | 回合切换 | `sfx_turn`（0.90s） | 落点，给下一段留呼吸 |

**切点必须踩音效**——每个动作点前后各留 2 帧，音效先入 1 帧画面再切。这一步决定片子
「利落」还是「业余」，比任何转场特效都重要。

### 6.3 危段（5 秒，720–870 帧）

- 险印亮起（`sfx_seal` 0.42s）→ 2.0s
- 血条被压到危险区、连续吃伤害（`sfx_hurt` ×2）→ 2.0s
- 定格 1.0s，画面轻微压暗（−8% 亮度），心跳低频

这段要**用 1.4× 数字裁切**（画面推近到血条和险印），因为原始全景里这两个信息太小，
手机上看不清。

### 6.4 战役段（5 秒，870–1020 帧）

八关地图横向运镜，沿路线从沛县推到垓下，**每关 0.6s**，鼓点从 90BPM 加密到 128BPM。
游戏内只能看到当前进度的解锁状态，**不要为了拍片去改存档**——用后期平移推镜头实现，
观众看到的是「一条很长的路线」，不是「八个亮着的点」。
这一段的作用不是展示玩法，是展示**体量**——「八关」是这个游戏最硬的卖点之一。

### 6.5 高潮段（3 秒，1020–1110 帧）

垓下、敌将血条见底，0.5× 慢放，最后 0.5s **音乐完全留白**，只留一次心跳。

> 打不到第 8 关就别硬打。任何一关的「敌将残血 + 我方压上」在 0.5× 慢放下视觉等价，
> 观众分辨不出是第几关。**要的是「快赢了」这个感觉，不是那一关的门牌号。**

留白不是装深沉：前面 36 秒一直在响，最后 3 秒的静音是唯一能让观众「屏住」的手段。

---

## 七、音频

| 项 | 用什么 | 说明 |
|---|---|---|
| 配乐 | `godot/assets/audio/bgm_title.wav`（**43.6 秒**） | 截 40s，0:37 起淡出 1s。正式版再找人重做，但节奏照这条：前 9s 慢、13s 起有鼓、34s 留白 |
| 音效 | 全部用游戏自己的 | 一致性最好，且玩家进游戏会「认得出」 |
| 混音 | 配乐 −18 LUFS 垫底 / 音效 −10 | 别让配乐盖掉卡牌声，卡牌声是这游戏的质感 |

**可用音效清单**（都在 `godot/assets/audio/`，时长已核实）：

| 文件 | 时长 | 用在哪 |
|---|---|---|
| `sfx_card.wav` | 0.30s | 出牌 |
| `sfx_attack.wav` | 0.40s | 撞阵 |
| `sfx_hurt.wav` | 0.30s | 掉血 |
| `sfx_seal.wav` | 0.42s | 险印 |
| `sfx_turn.wav` | 0.90s | 回合切换 |
| `sfx_omen.wav` | 1.40s | 事件（本片未用，备用） |
| `sfx_win.wav` | 1.10s | 通关（本片未用） |
| `sfx_lose.wav` | 1.30s | 兵败（本片未用） |

---

## 八、交付规格（Steam）

| 项 | 值 |
|---|---|
| 分辨率 | 1920×1080（Steam 推荐值；更高分辨率一般也能传，但播放端会缩放，收益有限） |
| 帧率 | 30 或 60fps，**全场统一**（混帧率会出鬼影） |
| 编码 | H.264 High / 8–12 Mbps / AAC 192k |
| 长度 | 30–60 秒，这条 40 秒 |
| 版本 | 中文版 + 英文版各一条（Steam 按语言挂不同 trailer，同一视频不行） |
| 禁止 | 黑边、片头超过 1s 的空镜、未上市平台图标、除「coming soon」外的任何日期承诺 |

**命名**（放进 `store/steam/_pv/`，`raw/` 子目录自己建，只放生成素材不动原图）：

```
_pv/frame-01-charge-16x9.png      ← 已给
_pv/frame-02-duel-16x9.png        ← 已给
_pv/raw/shot1_take1.mp4           ← 你生成的 AI 素材，一条不改名直接叠
_pv/pv-zh-40s.mp4                 ← 成片
_pv/pv-en-40s.mp4
```

---

## 九、生成后怎么判「这条能不能用」

先把每条 AI 素材**首帧和末帧各截一张**，然后按下面四级判。A 级一条就废，B 级换一条，
C 级能救。

### A 级 · 直接删（不用犹豫）

| # | 症状 | 为什么致命 |
|---|---|---|
| A1 | 出现任何文字、伪汉字、印章、签名 | Steam 审核对乱码文字敏感，观感也脏；而且这是 AI 味最重的标志 |
| A2 | 人物脸变形、多手多脚、马腿混乱 | 一眼假，评论区第一条就是它 |
| A3 | **空白纸被填出风景、云、山、士兵** | 这不是「不好看」，是这条片子从此不属于这个项目的美术体系 |
| A4 | 画面「融化」——笔触边缘变成塑料糊 | 水墨一旦塑料化就救不回来，调色也救不了 |

### B 级 · 换一条（重生成）

| # | 症状 | 判据 |
|---|---|---|
| B1 | 主体位移过大 | 首末帧主体轮廓偏移 >15% 画宽 → 构图垮 |
| B2 | 镜头自己抖了 | 除撞击瞬间那一次，出现任何第二下抖动 |
| B3 | 墨点爆开方向朝镜头外飞散 | 墨应该往纸里渗，不是往观众脸上喷 |

### C 级 · 能救（后期处理）

| # | 症状 | 怎么救 |
|---|---|---|
| C1 | 整体偏色（发黄/发灰） | 对首帧做一次色彩匹配，别手调 |
| C2 | 轻微发虚 | 锐化 0.5px / 15%，只有一次机会，二次锐化就出白边 |
| C3 | 时长比需要的短 | 末尾补 3–5 帧静帧（定格），配乐一直在走，看不出来 |

### 生成量预算

| 镜头 | 建议生成 | 期望留下 | 备注 |
|---|---|---|---|
| 镜头 1（破纸） | 3 条 | 1 条 | 墨点爆开最容易出问题，多生成一条保险 |
| 镜头 2（对峙） | 2 条 | 1 条 | 「人物真的没动」是稀缺品 |
| 合计 | 5 条 | 2 条 | 按单条 5 秒算，纯生成成本约 25 秒素材 |

---

## 十、不做的事（范围纪律）

- ❌ 不做真人出镜、不做实拍空镜
- ❌ 不做配音、不做旁白、不做「燃向」剪辑（快切 + 鼓点轰炸），那和这游戏的气质相反
- ❌ 不在片子里放「即将上线」以外的日期，不做「年度最佳」这类自夸文案
- ❌ 不用 AI 生成战斗画面——一次都不行
- ❌ 不用「墨滴转场」「纸撕裂转场」这类模板特效

---

## 十一、参考：这份文档里哪些数是实测的

| 项 | 来源 |
|---|---|
| BGM 43.6s、各音效时长 | **实测**（读 wav 文件头） |
| 首帧裁切比例、主体位置 | **实测**（从 3840×1240 原图裁，见 `_pv/`） |
| AI 占 22.5%、各段时间分配 | 设计决定，非实测 |
| 每镜 1.2s / 切点踩音效 | **[经验值]**，来自预告片通用节奏，未在本片验证 |
| 「前 9 秒无玩法有流失风险」 | **[待验证]**，靠 YouTube audience retention 或商店页转化率证伪（Steam 后台没有逐段留存） |
