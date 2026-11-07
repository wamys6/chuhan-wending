"""
库英雄底图 AI 超分（Real-ESRGAN x4 → 降到 3840 宽）

生图交付包只给到 2172×724，而 Steam 库英雄图要 3840×1240 = 1.77×。
`make-steam-art.py` 原先用 hd_resize（两段 1.5× + 锐化）硬上采，笔锋飞白会糊成灰雾。
这里改用 Real-ESRGAN 把细节重建出来，再 0.44× 降回目标宽——**最终是下采**，边缘比
裸上采实得多。

用法：
    python tools/upscale-hero.py                       # 处理 charge / charge_r / duel
    python tools/upscale-hero.py --which duel
    python tools/upscale-hero.py --esrgan D:/_tools/realesrgan

输出：store/steam/_art/_raw4k/library_hero_<which>.png（3840×1280，3:1 原比例的高）
`make-steam-art.py` 的 hero_src() 会优先读这里，宽度 ≥3000 才认，否则回退原图。

工具不在仓库里（约 130MB 的 exe + 模型），需要时按 README 下载：
    https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.5.0
    realesrgan-ncnn-vulkan-20220424-windows.zip
"""
import argparse
import os
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "store", "steam", "_art")
RAW = os.path.join(SRC, "_raw")
RAW4K = os.path.join(SRC, "_raw4k")

TARGET_W = 3840
MODEL = "realesrgan-x4plus"      # photo 向模型：保住墨晕的柔和过渡，anime 模型会把纸纹削平、旗面边缘发脆
DEFAULT_ESRGAN = os.environ.get("ESRGAN_DIR", "D:/_tools/realesrgan")


def upscale(exe_dir, src, dst_tmp):
    exe = os.path.join(exe_dir, "realesrgan-ncnn-vulkan.exe")
    if not os.path.exists(exe):
        sys.exit("找不到 %s —— 先下载 Real-ESRGAN ncnn 包，或用 --esrgan 指路" % exe)
    cmd = [exe, "-i", src.replace("\\", "/"), "-o", dst_tmp.replace("\\", "/"),
           "-n", MODEL, "-s", "4", "-f", "png"]
    print("  ", " ".join(cmd[1:]))
    # 注意：必须用模型原生 -s 4。ncnn 版在 -s 2 下 tile 拼接会错位，输出是拼贴画。
    subprocess.run(cmd, cwd=exe_dir, check=True, stdout=subprocess.DEVNULL)


def one(exe_dir, which):
    src = os.path.join(RAW, "library_hero_%s_raw.png" % which)
    if not os.path.exists(src):
        print("跳过 %s（没有 %s）" % (which, os.path.basename(src)))
        return
    os.makedirs(RAW4K, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        big = os.path.join(td, "x4.png")
        print("[%s] 超分中…" % which)
        upscale(exe_dir, src, big)
        im = Image.open(big).convert("RGB")
        w, h = im.size
        if w < TARGET_W:
            sys.exit("[%s] 超分后只有 %d 宽，不够 %d" % (which, w, TARGET_W))
        out = im.resize((TARGET_W, round(h * TARGET_W / w)), Image.LANCZOS)
        if out.height < 1240:
            sys.exit("[%s] 降到 %d 宽后只剩 %d 高，裁不出 1240" % (which, TARGET_W, out.height))
        dst = os.path.join(RAW4K, "library_hero_%s.png" % which)
        out.save(dst)
        print("  %dx%d → %dx%d  →  %s" % (w, h, out.width, out.height, os.path.relpath(dst, ROOT)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--which", nargs="*", default=["charge", "charge_r", "duel"])
    ap.add_argument("--esrgan", default=DEFAULT_ESRGAN)
    a = ap.parse_args()
    for which in a.which:
        one(a.esrgan, which)


if __name__ == "__main__":
    main()
