#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""字体子集化：把 20MB 的 Noto Serif SC 裁成只含游戏实际用字的版本。

为什么要做：两个字重共 42MB，比全部 74 张卡图加起来还多，是包体第二大项。

字符集来源（全部扫描，不手写清单）：
  1. godot/data/*.json      卡牌/关卡/军师/天时/事件的全部文案
  2. godot/**/*.gd          UI 字面量、战报模板、提示语
  3. js/**/*.js             JS 参考实现的文案（数据源在这一侧）

兜底：Noto 的 .import 里 allow_system_fallback=true，漏字会回退系统字体
而不是豆腐块；另有 fonts_test.gd 扫描源码字符做覆盖校验。

用法：python tools/subset-fonts.py
源字体：assets/fonts-src/*.otf（不进 Godot 工程，不会被导入进包）
输出：  godot/fonts/*.otf
"""

import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "assets", "fonts-src")
OUT_DIR = os.path.join(ROOT, "godot", "fonts")

# 除源码用字外必须保留的字符：半角可打印 ASCII、中文标点、常用符号
EXTRA = (
    "".join(chr(c) for c in range(0x20, 0x7F))
    + "　、。〃々〈〉《》「」『』【】〔〕〖〗〝〞"
    + "，．：；？！–—⋯‧“”‘’（）［］｛｝"
    + "·×÷±≤≥≠∞°′″‰％＃＆＊＋－／＝＠＼＾＿｜～"
    + "→←↑↓↔⇒⇔●○◎◆◇■□▲△▼▽★☆※§¶†‡"
    + "０１２３４５６７８９"
)


def collect_chars() -> set:
    chars = set(EXTRA)
    patterns = [
        "godot/data/*.json",
        "godot/**/*.gd",
        "js/*.js",
    ]
    files = 0
    for pat in patterns:
        for path in glob.glob(os.path.join(ROOT, pat), recursive=True):
            try:
                with open(path, encoding="utf-8") as fh:
                    chars |= set(fh.read())
                files += 1
            except (UnicodeDecodeError, OSError):
                continue
    print("扫描 %d 个文件，字符集 %d 个码位" % (files, len(chars)))
    return chars


def main() -> int:
    subset = collect_chars()
    text = "".join(sorted(subset))
    tmp_txt = os.path.join(ROOT, ".tmp-subset-chars.txt")
    with open(tmp_txt, "w", encoding="utf-8") as fh:
        fh.write(text)

    fonts = sorted(glob.glob(os.path.join(SRC_DIR, "*.otf")))
    if not fonts:
        print("错误：%s 下没有源字体" % SRC_DIR)
        return 1

    os.makedirs(OUT_DIR, exist_ok=True)
    before = 0
    after = 0
    for src in fonts:
        name = os.path.basename(src)
        dst = os.path.join(OUT_DIR, name)
        before += os.path.getsize(src)
        cmd = [
            sys.executable, "-m", "fontTools.subset", src,
            "--text-file=" + tmp_txt,
            "--output-file=" + dst,
            # 保留 OpenType 布局表，否则 RichTextLabel 的粗体/连字会失效
            "--layout-features=*",
            "--name-IDs=*",
            "--notdef-outline",
            "--recalc-bounds",
            "--drop-tables+=DSIG",
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(res.stdout[-2000:])
            print(res.stderr[-2000:])
            print("错误：子集化失败 %s" % name)
            return 1
        size = os.path.getsize(dst)
        after += size
        print("  %-28s %6.1f MB → %5.0f KB" % (name, os.path.getsize(src) / 1048576, size / 1024))

    os.remove(tmp_txt)
    print("总计 %.1f MB → %.1f MB（省 %.1f MB）" % (
        before / 1048576, after / 1048576, (before - after) / 1048576))
    return 0


if __name__ == "__main__":
    sys.exit(main())
