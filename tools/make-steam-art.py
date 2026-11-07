"""
Steam 商店素材草稿生成器（2026-11-07）
用现有立绘 + 宣纸底 + 标题排版合出三种胶囊图；截图只做尺寸规范化（1920x1055 → 1920x1080）。

规格（Steamworks 2026）：
  主胶囊 1232x706 / 头图 920x430 / 小胶囊 462x174 / 截图 1920x1080

用法：python tools/make-steam-art.py
输出：store/steam/
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "godot", "assets", "cards")
OUT = os.path.join(ROOT, "store", "steam")
SHOTS = os.path.join(ROOT, "godot", "tests")

CREAM = (247, 241, 228)
INK = (29, 26, 22)
SEAL = (124, 31, 26)

FONT_BOLD = "C:/Windows/Fonts/simsun.ttc"          # 宋体（标题骨架）
FONT_SERIF = "C:/Windows/Fonts/msyh.ttc"
for cand in ["C:/Windows/Fonts/NotoSerifSC-Bold.otf", "C:/Windows/Fonts/simsun.ttc"]:
    if os.path.exists(cand):
        FONT_BOLD = cand
        break


def load_fig(name, crop, target_h):
    im = Image.open(os.path.join(ART, name)).convert("RGB")
    im = im.crop(crop)
    w = int(im.width * target_h / im.height)
    return im.resize((w, target_h), Image.LANCZOS)


def fade(img, side, width_px):
    """把一侧做成渐隐，便于和宣纸底融合（side: 'right' | 'left'）"""
    mask = Image.new("L", img.size, 255)
    d = ImageDraw.Draw(mask)
    for i in range(width_px):
        a = int(255 * (i / width_px))
        if side == "right":
            d.line([(img.width - i, 0), (img.width - i, img.height)], fill=a)
        else:
            d.line([(i, 0), (i, img.height)], fill=a)
    out = img.copy()
    out.putalpha(mask)
    return out


def paper_bg(size, tint=CREAM):
    bg = Image.new("RGB", size, tint)
    # 轻微纸纹：噪声 + 大幅模糊，避免死平
    noise = Image.effect_noise(size, 8).convert("L")
    noise = noise.filter(ImageFilter.GaussianBlur(1.2))
    return Image.composite(bg, Image.new("RGB", size, (240, 233, 217)), noise.point(lambda v: int(v * 0.35)))


def draw_title(canvas, cx, cy, main_size, sub_size, spacing=26):
    d = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT_BOLD, main_size)
    dot_font = ImageFont.truetype(FONT_BOLD, int(main_size * 0.55))
    title = ["楚", "汉", "·", "问", "鼎"]
    widths = []
    for ch in title:
        f = dot_font if ch == "·" else font
        widths.append(d.textbbox((0, 0), ch, font=f)[2])
    total = sum(widths) + spacing * (len(title) - 1)
    x = cx - total / 2
    for ch, w in zip(title, widths):
        if ch == "·":
            d.text((x + w / 2, cy + main_size * 0.02), ch, font=dot_font, fill=SEAL, anchor="mm")
        else:
            d.text((x, cy), ch, font=font, fill=INK, anchor="lm")
        x += w + spacing
    # 印章色竖线
    d.rectangle([cx - 1.5, cy - main_size * 0.92, cx + 1.5, cy - main_size * 0.62], fill=SEAL)
    # 副标题：先铺一层奶油色柔光，避免压在深色衣袍上看不清
    sub_font = ImageFont.truetype(FONT_SERIF, sub_size)
    sub = "卡牌对战 · 三列军阵 · 楚汉争霸"
    sb = d.textbbox((0, 0), sub, font=sub_font)
    sw, sh = sb[2] - sb[0], sb[3] - sb[1]
    sy = cy + main_size * 0.78
    glow = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(glow).rounded_rectangle(
        [cx - sw / 2 - 22, sy - sh / 2 - 10, cx + sw / 2 + 22, sy + sh / 2 + 10],
        radius=14, fill=210)
    glow = glow.filter(ImageFilter.GaussianBlur(12))
    canvas.paste(Image.new("RGB", canvas.size, CREAM), (0, 0), glow)
    d = ImageDraw.Draw(canvas)
    d.text((cx, sy), sub, font=sub_font, fill=(84, 72, 56), anchor="mm")


def _compose(W, H, title_size, sub_size, fig_h, liu_x, xiang_dx, spacing):
    canvas = paper_bg((W, H))
    liu = load_fig("liubang.png", (0, 40, 1024, 1230), int(H * fig_h))
    liu = fade(liu, "right", int(W * 0.17))
    canvas.paste(liu, (liu_x, -int(H * 0.07)), liu)

    xiang = load_fig("xiangyu.png", (0, 20, 1024, 1230), int(H * fig_h))
    xiang = fade(xiang, "left", int(W * 0.19))
    canvas.paste(xiang, (W - xiang.width + xiang_dx, -int(H * 0.07)), xiang)

    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse([W * 0.24, -H * 0.15, W * 0.76, H * 1.15], fill=170)
    glow = glow.filter(ImageFilter.GaussianBlur(max(40, W * 0.06)))
    canvas = Image.composite(Image.new("RGB", (W, H), CREAM), canvas, glow)
    draw_title(canvas, W / 2, H * 0.44, title_size, sub_size, spacing)
    return canvas


def make_main():
    W, H = 1232, 706
    canvas = _compose(W, H, 118, 26, 1.18, -70, 70, 30)
    canvas.save(os.path.join(OUT, "capsule-main-1232x706.png"))
    return canvas


def make_header():
    """头图独立构图（不能直接裁主胶囊：905 高裁到 430 会把两颗头都切掉）"""
    W, H = 920, 430
    canvas = _compose(W, H, 84, 19, 1.42, -60, 60, 20)
    canvas.save(os.path.join(OUT, "capsule-header-920x430.png"))


def make_small():
    """小胶囊：独立构图——标题左、刘邦面部特写在右，保证 120x45 缩略可读"""
    W, H = 462, 174
    canvas = paper_bg((W, H))
    # 刘邦头部+红袍肩线：缩略尺寸下「人脸 + 一抹朱红」比全身骑马更抓眼
    liu = load_fig("liubang.png", (300, 90, 780, 640), int(H * 1.55))
    liu = fade(liu, "left", 130)
    canvas.paste(liu, (W - liu.width + 34, -14), liu)
    d = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT_BOLD, 46)
    d.text((30, 56), "楚汉", font=font, fill=INK, anchor="lm")
    d.text((30, 112), "问鼎", font=font, fill=INK, anchor="lm")
    d.rectangle([18, 30, 22, 138], fill=SEAL)
    canvas.save(os.path.join(OUT, "capsule-small-462x174.png"))


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
            print("缺图", src)
            continue
        im = Image.open(p).convert("RGB")
        if im.size != (1920, 1080):
            im = im.resize((1920, 1080), Image.LANCZOS)
        im.save(os.path.join(sdir, dst))
        print("截图", dst, im.size)


def make_vertical(W, H, name, title_size, sub_size, fig_h, spacing):
    """竖版：标题在上三分之一，双雄在下半部对峙（竖版裁切与横版完全不同构图）"""
    canvas = paper_bg((W, H))
    liu = load_fig("liubang.png", (0, 60, 900, 1300), int(H * fig_h))
    liu = fade(liu, "right", int(W * 0.22))
    canvas.paste(liu, (-int(W * 0.20), int(H * 0.30)), liu)

    xiang = load_fig("xiangyu.png", (120, 60, 1024, 1300), int(H * fig_h))
    xiang = fade(xiang, "left", int(W * 0.24))
    canvas.paste(xiang, (W - xiang.width + int(W * 0.27), int(H * 0.28)), xiang)

    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse([-W * 0.2, -H * 0.1, W * 1.2, H * 0.62], fill=210)
    glow = glow.filter(ImageFilter.GaussianBlur(max(40, W * 0.08)))
    canvas = Image.composite(Image.new("RGB", (W, H), CREAM), canvas, glow)
    draw_title(canvas, W / 2, H * 0.24, title_size, sub_size, spacing)
    canvas.save(os.path.join(OUT, name))


def make_logo():
    """库 Logo：透明底，只有字（叠在库英雄图上用）"""
    W, H = 1280, 720
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT_BOLD, 200)
    dot_font = ImageFont.truetype(FONT_BOLD, 110)
    title = ["楚", "汉", "·", "问", "鼎"]
    widths = [d.textbbox((0, 0), c, font=dot_font if c == "·" else font)[2] for c in title]
    total = sum(widths) + 40 * (len(title) - 1)
    x = W / 2 - total / 2
    for c, w in zip(title, widths):
        if c == "·":
            d.text((x + w / 2, H / 2 - 40), c, font=dot_font, fill=SEAL + (255,), anchor="mm")
        else:
            d.text((x, H / 2 - 40), c, font=font, fill=INK + (255,), anchor="lm")
        x += w + 40
    sub_font = ImageFont.truetype(FONT_SERIF, 40)
    d.text((W / 2, H / 2 + 110), "卡牌对战 · 三列军阵 · 楚汉争霸",
           font=sub_font, fill=(90, 78, 62, 255), anchor="mm")
    canvas.save(os.path.join(OUT, "library-logo-1280x720.png"))


def make_icon():
    """应用图标 184×184：刘邦面部特写 + 朱砂细框"""
    S = 184
    im = Image.open(os.path.join(ART, "liubang.png")).convert("RGB")
    face = im.crop((360, 130, 700, 470)).resize((S, S), Image.LANCZOS)
    d = ImageDraw.Draw(face)
    d.rectangle([0, 0, S - 1, S - 1], outline=SEAL, width=5)
    face.save(os.path.join(OUT, "app-icon-184x184.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    make_main()
    make_header()
    make_small()
    make_vertical(748, 896, "capsule-vertical-748x896.png", 124, 24, 0.92, 26)
    make_vertical(600, 900, "library-capsule-600x900.png", 104, 20, 0.86, 22)
    make_logo()
    make_icon()
    make_screenshots()
    for f in sorted(os.listdir(OUT)):
        p = os.path.join(OUT, f)
        if os.path.isfile(p):
            print(f, Image.open(p).size)


if __name__ == "__main__":
    main()
