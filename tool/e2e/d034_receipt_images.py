"""Renders the receipt text fixtures (test/fixtures/receipts/*.txt) as receipt photos (JPEG) for the device scan test.

D-034 A3: integration_test/d034_a_test.dart runs the real on-device text recognition on these pictures.
Columns split on two or more spaces: the first is left-aligned, the last right-aligned (like a till slip).
Run from the repo root:  python tool/e2e/d034_receipt_images.py
"""
import glob
import os
import re

from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH = 720
MARGIN = 36
FONT = r'C:\Windows\Fonts\arial.ttf'
BOLD = r'C:\Windows\Fonts\arialbd.ttf'


def render(txt_path: str, png_path: str) -> None:
    rows = [r.rstrip() for r in open(txt_path, encoding='utf-8').read().splitlines()]
    rows = [r for r in rows if r.strip()]
    font = ImageFont.truetype(FONT, 26)
    bold = ImageFont.truetype(BOLD, 28)
    line = 44
    height = MARGIN * 2 + line * len(rows) + 40
    img = Image.new('RGB', (WIDTH, height), (250, 248, 242))
    draw = ImageDraw.Draw(img)
    y = MARGIN
    for i, row in enumerate(rows):
        cols = re.split(r'\s{2,}', row.strip())
        f = bold if i == 0 or re.search(r'grand total|net payable|net amt|^total', row, re.I) else font
        if len(cols) == 1:
            w = draw.textlength(cols[0], font=f)
            x = (WIDTH - w) / 2 if i < 3 else MARGIN
            draw.text((x, y), cols[0], fill=(25, 25, 25), font=f)
        else:
            draw.text((MARGIN, y), cols[0], fill=(25, 25, 25), font=f)
            last = cols[-1]
            draw.text((WIDTH - MARGIN - draw.textlength(last, font=f), y), last, fill=(25, 25, 25), font=f)
            middle = cols[1:-1]
            for j, c in enumerate(middle):
                cx = WIDTH * (0.52 + 0.16 * j)
                draw.text((cx, y), c, fill=(25, 25, 25), font=f)
        y += line
    # A touch of blur, like a phone photo of thermal paper.
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(png_path, quality=82, optimize=True)


def main() -> None:
    root = os.path.join('test', 'fixtures', 'receipts')
    for txt in sorted(glob.glob(os.path.join(root, '*.txt'))):
        png = txt[:-4] + '.jpg'
        render(txt, png)
        print('wrote', png)


if __name__ == '__main__':
    main()
