"""
Steam 商店素材生成器（2026-11-07 第二版：接入六张水墨无字底图）

底图来自生图交付包，已解包到 store/steam/_art/：
  _raw/      原生尺寸（裁切时用，保留最多像素）
  no-title/  已按目标尺寸整理好的无字图（尺寸规格见 _art/manifest.json）

第一版是用游戏内立绘（1024×1536）拼的，放大糊；这一版全部换成原生大图，
标题排版改为「两行竖叠 + 朱砂分隔点」，因为底图中央的留白走廊只有约 370px 宽，
单行五字排不下、竖排又太细——两行两字是这条走廊能装下的最大字号。

规格（Steamworks 2026，2× 上传尺寸）：
  主胶囊 1232x706 / 头图 920x430 / 小胶囊 462x174 / 竖版 748x896
  库胶囊 600x900 / 库英雄图 3840x1240 / 页面背景 1438x810 / 库 Logo 1280x720 / 图标 184x184

用法：python tools/make-steam-art.py
输出：store/steam/
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "godot", "assets", "cards")          # 游戏内立绘（仅图标还在用）
SRC = os.path.join(ROOT, "store", "steam", "_art")
NOTITLE = os.path.join(SRC, "no-title")
RAW = os.path.join(SRC, "_raw")
OUT = os.path.join(ROOT, "store", "steam")
SHOTS = os.path.join(ROOT, "godot", "tests")

CREAM = (247, 241, 228)
INK = (26, 23, 20)
SEAL = (124, 31, 26)
SUBINK = (78, 66, 52)


def _pick(paths, fallback):
    for p in paths:
        if os.path.exists(p):
            return p
    return fallback


# 标题用宋体（骨架重），副标题用楷体（更像手写）——都优先挑系统里最像的
FONT_TITLE_ZH = _pick(["C:/Windows/Fonts/STSONG.TTF", "C:/Windows/Fonts/simsun.ttc"],
                      "C:/Windows/Fonts/simsun.ttc")
FONT_SUB_ZH = _pick(["C:/Windows/Fonts/STKAITI.TTF", "C:/Windows/Fonts/simkai.ttf"],
                    FONT_TITLE_ZH)
FONT_TITLE_EN = _pick(["C:/Windows/Fonts/georgiab.ttf", "C:/Windows/Fonts/timesbd.ttf"],
                      "C:/Windows/Fonts/times.ttf")

SUB_ZH = "卡牌对战 · 三列军阵"
SUB_EN = "A CARD BATTLE FOR THE THRONE"


# ─────────────────────────── 底图 ───────────────────────────

def art(name, size=None, raw=False):
    """读底图；size 给了就 LANCZOS 等比缩放到该尺寸（尺寸不符会报错，避免悄悄变形）。"""
    p = os.path.join(RAW if raw else NOTITLE, name + ("_raw" if raw else "") + ".png")
    im = Image.open(p).convert("RGB")
    if size is not None and im.size != tuple(size):
        im = im.resize(size, Image.LANCZOS)
    return im


def cover(im, size, anchor="center"):
    """等比放大到刚好盖住 size，再按 anchor 裁切（不拉伸、不压扁）。"""
    W, H = size
    s = max(W / im.width, H / im.height)
    im = im.resize((max(W, round(im.width * s)), max(H, round(im.height * s))), Image.LANCZOS)
    x = (im.width - W) // 2 if anchor == "center" else 0
    y = 0 if anchor == "top" else (im.height - H) // 2
    return im.crop((x, y, x + W, y + H))


def crop_bottom(im, size):
    """等比缩到目标宽，只从底部裁——保住人物的头（头在图上方，先裁上面会切脸）。"""
    W, H = size
    im = im.resize((W, round(im.height * W / im.width)), Image.LANCZOS)
    return im.crop((0, 0, W, H))


def fade(im, side, width_px):
    """一侧渐隐，用于把小图融回宣纸底。"""
    mask = Image.new("L", im.size, 255)
    d = ImageDraw.Draw(mask)
    for i in range(width_px):
        a = int(255 * (i / width_px))
        if side == "right":
            d.line([(im.width - i, 0), (im.width - i, im.height)], fill=a)
        else:
            d.line([(i, 0), (i, im.height)], fill=a)
    out = im.copy()
    out.putalpha(mask)
    return out


def soften(canvas, box, radius=None):
    """在标题区域垫一层极淡的宣纸光，压掉背景的墨雾，保证字盖得住。"""
    W, H = canvas.size
    radius = radius or int(W * 0.05)
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).rounded_rectangle(box, radius=radius, fill=64)
    glow = glow.filter(ImageFilter.GaussianBlur(radius))
    canvas.paste(Image.new("RGB", (W, H), CREAM), (0, 0), glow)
    return canvas


def heal_dot(im, cx, cy, r=18):
    """用中值滤波抹掉底图自带的微小朱砂点。
    竖版里这个点只有 8px，缩到库里就成了一粒脏东西；主胶囊里它有 52px，是构图的一部分，别盖。"""
    box = (int(cx - r), int(cy - r), int(cx + r), int(cy + r))
    reg = im.crop(box).filter(ImageFilter.MedianFilter(size=(r * 2 // 3) * 2 + 1))
    mask = Image.new("L", reg.size, 0)
    ImageDraw.Draw(mask).ellipse([2, 2, reg.width - 2, reg.height - 2], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(r * 0.35))
    im.paste(reg, (box[0], box[1]), mask)
    return im



# ─────────────────────────── 标题 ───────────────────────────

def _tracked(d, cx, cy, text, font, fill, track):
    """逐字排（中文字距靠 track；英文也用同一套，字距更均匀）。"""
    widths = [font.getlength(c) for c in text]
    total = sum(widths) + track * (len(text) - 1)
    x = cx - total / 2
    for c, w in zip(text, widths):
        d.text((x + w / 2, cy), c, font=font, fill=fill, anchor="mm")
        x += w + track
    return total


def _rows(lang):
    """两行标题：(文字, 相对字号)。中文两行各两字；英文第一行字标、第二行副题。"""
    if lang == "zh":
        return [("楚汉", 1.0), ("问鼎", 1.0)], True
    return [("CHU–HAN", 0.60), ("BATTLE FOR THE THRONE", 0.235)], False


def draw_title(canvas, cx, top, base, lang="zh", sub=None, sub_scale=1.0):
    """居中两行标题 + 朱砂分隔点 + 副标题；返回占用的底边 y。

    英文第二行本身就是副题（BATTLE FOR THE THRONE），再挂一条小字会重复，默认不挂。
    """
    if sub is None:
        sub = lang == "zh"
    d = ImageDraw.Draw(canvas)
    rows, cjk = _rows(lang)
    fpath = FONT_TITLE_ZH if cjk else FONT_TITLE_EN
    y = top
    for i, (txt, ratio) in enumerate(rows):
        size = max(8, int(base * ratio))
        f = ImageFont.truetype(fpath, size)
        _tracked(d, cx, y + size * 0.5, txt, f, INK, size * (0.12 if cjk else 0.06))
        y += size
        if cjk and i == 0:
            # 朱砂分隔点：比标题小一圈，正好落在两行之间
            dot = max(6, int(size * 0.30))
            d.ellipse([cx - dot / 2, y + size * 0.10, cx + dot / 2, y + size * 0.10 + dot], fill=SEAL)
            y += size * 0.10 + dot + size * 0.10
        elif not cjk and i == 0:
            # 英文用一道极细朱砂横线，比点更像排版分隔
            half = size * 1.05
            d.rectangle([cx - half, y + size * 0.26, cx + half, y + size * 0.26 + max(2, size * 0.022)],
                        fill=SEAL)
            y += size * 0.52
    if sub:
        ssize = max(10, int(base * (0.20 if cjk else 0.075) * sub_scale))
        sf = ImageFont.truetype(FONT_SUB_ZH if cjk else FONT_TITLE_EN, ssize)
        y += base * 0.16
        stxt = SUB_ZH if cjk else SUB_EN
        _tracked(d, cx, y + ssize * 0.6, stxt, sf, SUBINK, ssize * (0.34 if cjk else 0.10))
        y += ssize * 1.2
    return y


# ─────────────────────────── 各尺寸 ───────────────────────────

def make_main(lang="zh", name="capsule-main-1232x706.png"):
    """主胶囊：底图中央走廊约 x 431..800 / y 0..585，标题两行占据这条竖带。"""
    W, H = 1232, 706
    canvas = art("main_capsule", (W, H))
    canvas = soften(canvas, [W * 0.35, H * 0.10, W * 0.65, H * 0.78], radius=int(W * 0.055))
    draw_title(canvas, W * 0.499, H * 0.19, 112 if lang == "zh" else 132, lang)
    canvas.save(os.path.join(OUT, name))
    return canvas


def make_header(lang="zh", name="capsule-header-920x430.png"):
    """头图：从主胶囊底图缩到 920 宽后只裁底部——上面裁会切掉两顶发冠。"""
    W, H = 920, 430
    canvas = crop_bottom(art("main_capsule"), (W, H))
    canvas = soften(canvas, [W * 0.33, H * 0.08, W * 0.67, H * 0.80], radius=int(W * 0.07))
    draw_title(canvas, W * 0.499, H * 0.11, 84 if lang == "zh" else 98, lang)
    canvas.save(os.path.join(OUT, name))
    return canvas


def make_small(lang="zh", name="capsule-small-462x174.png"):
    """小胶囊：库里最小会缩到 120x45，靠「两行大字 + 一张脸」撑可读性。
    脸取主胶囊原生图的项羽头肩（444×444 原生像素），缩到 226 高仍有细节。"""
    W, H = 462, 174
    canvas = Image.new("RGB", (W, H), CREAM)
    head = art("main_capsule", raw=True).crop((1145, 0, 1589, 444))
    head = head.resize((226, 226), Image.LANCZOS)
    head = fade(head, "left", 96)
    canvas.paste(head, (W - 226 + (34 if lang == "zh" else 44), -30), head)
    d = ImageDraw.Draw(canvas)
    size = 50 if lang == "zh" else 34
    fpath = FONT_TITLE_ZH if lang == "zh" else FONT_TITLE_EN
    rows = _rows(lang)[0] if lang == "zh" else [("CHU–HAN", 1.0)]
    y = 34 if lang == "zh" else 30
    for txt, ratio in rows:
        f = ImageFont.truetype(fpath, max(8, int(size * ratio)))
        _tracked(d, 118 if lang == "zh" else 138, y + size * ratio * 0.5, txt, f, INK,
                 4 if lang == "zh" else 1)
        y += size * (1.10 if lang == "zh" else 1.30)
    d.rectangle([26, 30, 30, H - 30], fill=SEAL)
    canvas.save(os.path.join(OUT, name))
    return canvas


def make_vertical(W, H, name, base, lang="zh"):
    """竖版 / 库胶囊：底图下三分之一才是人物，标题整块压在上方留白里。"""
    src = art("vertical_capsule")
    # 先在原尺寸上补掉那个小朱砂点，再缩放裁切——缩放后补会算错位置
    src = heal_dot(src, 553, 457, 18)
    canvas = src if (W, H) == src.size else cover(src, (W, H), anchor="bottom")
    canvas = canvas.copy()
    canvas = soften(canvas, [W * 0.10, H * 0.10, W * 0.90, H * 0.60], radius=int(W * 0.06))
    draw_title(canvas, W / 2, H * 0.17, base, lang)
    canvas.save(os.path.join(OUT, name))
    return canvas


def make_hero(lang="zh", which="duel", titled=False, mirror=False):
    """库英雄图 3840×1240。

    Steam 库页面会把库 Logo 叠在**左侧**，所以左侧必须干净：
    duel 版左边是刘邦、charge 版左边是项羽，都会压住字。charge 版水平镜像后
    人物移到右半、左侧留出大片宣纸，是唯一一版能直接上传的——
    见 `_preview-library-hero.jpg`（合成预览）。
    """
    W, H = 3840, 1240
    canvas = art("library_hero_%s" % which, (W, H))
    if mirror:
        canvas = canvas.transpose(Image.FLIP_LEFT_RIGHT)
    tag = "library-hero-%s%s" % (which, "-mirror" if mirror else "")
    if titled:
        canvas = soften(canvas, [W * 0.30, H * 0.16, W * 0.70, H * 0.84], radius=int(W * 0.03))
        cx = W * 0.475 if which == "duel" else W * 0.705
        draw_title(canvas, cx, H * 0.26, 290 if lang == "zh" else 320, lang, sub_scale=1.5)
        tag += "-titled"
    tag += "" if lang == "zh" else "-en"
    canvas.save(os.path.join(OUT, tag + ".png"))
    return canvas


def make_hero_preview():
    """把库 Logo 叠在推荐版英雄图上，确认「左侧留空」这条约束真的成立。"""
    hero = Image.open(os.path.join(OUT, "library-hero-charge-mirror.png")).convert("RGB")
    hero = hero.resize((1920, 620), Image.LANCZOS)
    logo = Image.open(os.path.join(OUT, "library-logo-1280x720.png")).convert("RGBA")
    logo = logo.resize((560, 315), Image.LANCZOS)
    hero.paste(logo, (90, 130), logo)
    hero.save(os.path.join(OUT, "_preview-library-hero.jpg"), quality=90)


def make_page_bg():
    """页面背景 1438×810：无字。
    试过压暗版（乘系数 / 双色调），底图本身就是淡雾平原，压暗后只剩一片灰，
    比原图难看——所以只出原色，Steam 自己会在页头压渐变。"""
    W, H = 1438, 810
    canvas = cover(art("page_background"), (W, H))
    canvas.save(os.path.join(OUT, "page-background-1438x810.png"))
    return canvas


def make_video_cover():
    """宣传片首帧 1920×1080：无字，Steam 自己会截帧做缩略图。"""
    canvas = art("video_cover", (1920, 1080))
    canvas.save(os.path.join(OUT, "video-cover-1920x1080.png"))
    return canvas


def make_logo(lang="zh"):
    """库 Logo 1280×720 透明底：只有字，Steam 叠在库英雄图上（别把字烤进英雄图）。"""
    W, H = 1280, 720
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lang_key = "zh" if lang == "zh" else "en"
    tmp = Image.new("RGB", (W, H), CREAM)
    draw_title(tmp, W / 2, H * 0.26, 200 if lang_key == "zh" else 236, lang_key, sub_scale=1.1)
    # 把画好的字抠成透明：宣纸底与纯墨的差就是 alpha
    px = tmp.convert("L")
    alpha = px.point(lambda v: max(0, min(255, int((238 - v) * 3.2))))
    canvas.paste(tmp, (0, 0), alpha)
    name = "library-logo-1280x720.png" if lang_key == "zh" else "library-logo-en-1280x720.png"
    canvas.save(os.path.join(OUT, name))
    return canvas


def make_icon():
    """应用图标 184×184：刘邦面部特写 + 朱砂细框（缩到 32×32 也认得出）。"""
    S = 184
    im = Image.open(os.path.join(ART, "liubang.png")).convert("RGB")
    face = im.crop((360, 130, 700, 470)).resize((S, S), Image.LANCZOS)
    d = ImageDraw.Draw(face)
    d.rectangle([0, 0, S - 1, S - 1], outline=SEAL, width=5)
    face.save(os.path.join(OUT, "app-icon-184x184.png"))


def make_screenshots():
    sdir = os.path.join(OUT, "screenshots")
    os.makedirs(sdir, exist_ok=True)
    picks = [
        ("_gd-battle-campaign.png", "01-battle.png"),
        ("_gd-map.png", "02-campaign-map.png"),
        ("_gd-reward.png", "03-reward.png"),
        ("_gd-advisor.png", "04-advisor.png"),
        ("_gd-event.png", "05-event.png"),
        ("_gd-codex-cards.png", "06-codex.png"),
    ]
    for src, dst in picks:
        p = os.path.join(SHOTS, src)
        if not os.path.exists(p):
            print("缺图，跳过", src)
            continue
        im = Image.open(p).convert("RGB")
        if im.size != (1920, 1080):
            im = im.resize((1920, 1080), Image.LANCZOS)
        im.save(os.path.join(sdir, dst))


def make_small_test():
    """缩略可读性测试：小胶囊按 Steam 实际显示尺寸缩两档，肉眼过一遍。"""
    src = os.path.join(OUT, "capsule-small-462x174.png")
    im = Image.open(src)
    for w in (231, 120):
        h = round(174 * w / 462)
        im.resize((w, h), Image.LANCZOS).save(os.path.join(OUT, "_test-small-%dx%d.png" % (w, h)))


def make_preview_sheet():
    """一页看完所有出图，方便一次性验收。"""
    items = [
        ("capsule-main-1232x706.png", "主胶囊 1232×706"),
        ("capsule-header-920x430.png", "头图 920×430"),
        ("capsule-small-462x174.png", "小胶囊 462×174"),
        ("capsule-vertical-748x896.png", "竖版 748×896"),
        ("library-capsule-600x900.png", "库胶囊 600×900"),
        ("video-cover-1920x1080.png", "宣传片首帧 1920×1080"),
    ]
    col_w, pad, label_h = 620, 16, 26
    rows_h = []
    thumbs = []
    for f, label in items:
        p = os.path.join(OUT, f)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB")
        im = im.resize((col_w - pad, round(im.height * (col_w - pad) / im.width)), Image.LANCZOS)
        thumbs.append((im, label))
    per_row = 3
    rows = [thumbs[i:i + per_row] for i in range(0, len(thumbs), per_row)]
    for r in rows:
        rows_h.append(max(t.height for t, _ in r) + label_h + pad)
    W = per_row * col_w
    H = sum(rows_h) + pad
    sheet = Image.new("RGB", (W, H), (32, 29, 26))
    d = ImageDraw.Draw(sheet)
    lf = ImageFont.truetype(FONT_TITLE_ZH, 16)
    y = pad
    for r, rh in zip(rows, rows_h):
        for i, (t, label) in enumerate(r):
            x = i * col_w + pad // 2
            sheet.paste(t, (x, y))
            d.text((x, y + t.height + 4), label, font=lf, fill=(214, 205, 190))
        y += rh
    sheet.save(os.path.join(OUT, "_preview-sheet.jpg"), quality=92)


def main():
    os.makedirs(OUT, exist_ok=True)
    for lang in ("zh", "en"):
        suffix = "" if lang == "zh" else "-en"
        make_main(lang, "capsule-main-1232x706%s.png" % suffix)
        make_header(lang, "capsule-header-920x430%s.png" % suffix)
        make_small(lang, "capsule-small-462x174%s.png" % suffix)
        make_vertical(748, 896, "capsule-vertical-748x896%s.png" % suffix, 104, lang)
        make_vertical(600, 900, "library-capsule-600x900%s.png" % suffix, 80, lang)
        make_logo(lang)
    make_hero("zh", "charge", False, mirror=True)
    make_hero("zh", "duel", False)
    make_hero("zh", "duel", True)
    make_hero("en", "duel", True)
    make_hero_preview()
    make_page_bg()
    make_video_cover()
    make_icon()
    make_screenshots()
    make_small_test()
    make_preview_sheet()
    for f in sorted(os.listdir(OUT)):
        p = os.path.join(OUT, f)
        if os.path.isfile(p) and f.endswith((".png", ".jpg")):
            print(f, Image.open(p).size)


if __name__ == "__main__":
    main()
