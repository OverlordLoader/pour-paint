#!/usr/bin/env python3
"""Generate the Pour Paint app icon set into Assets.xcassets/AppIcon.appiconset.

Icon concept: a tilted paint-supply tube pouring a stream of paint into a big
canvas tube that already holds rainbow bands — the game's core loop in one
glance. Deep plum background to match the in-game palette.
"""
from PIL import Image, ImageDraw
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "PourPaint" / "Assets.xcassets" / "AppIcon.appiconset"

CANDY = [0xFF3B5C, 0xFF8A00, 0xFFD60A, 0x7ED957, 0x00C2A8, 0x3AB6FF, 0x5B5FE9, 0xA259FF, 0xFF5FD2, 0x00B4D8]

def rgb(h):
    return ((h >> 16) & 0xFF, (h >> 8) & 0xFF, h & 0xFF)

def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Background: deep plum gradient (approximated with horizontal bands).
    top, bottom = (43, 27, 77), (23, 16, 46)
    for y in range(size):
        t = y / size
        d.line([(0, y), (size, y)],
               fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    # Rounded mask.
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size, size], radius=int(size * 0.225), fill=255)

    # Big canvas tube with rainbow bands (bottom-up), centered-right.
    cx, base_y = int(size * 0.56), int(size * 0.82)
    tw, th = int(size * 0.30), int(size * 0.56)
    top_y = base_y - th
    seg_h = th // 5
    band_colors = [0, 3, 5, 7, 1]
    for i, c in enumerate(band_colors):
        y0 = base_y - (i + 1) * seg_h + 4
        d.rounded_rectangle([cx - tw // 2 + 12, y0, cx + tw // 2 - 12, y0 + seg_h - 4],
                            radius=12, fill=rgb(CANDY[c]))
    # Glossy surface on the top band.
    d.ellipse([cx - tw // 2 + 22, top_y + 10, cx + tw // 2 - 22, top_y + 30],
              fill=(255, 255, 255, 200))
    # Glass outline.
    d.rounded_rectangle([cx - tw // 2, top_y, cx + tw // 2, base_y],
                        radius=int(tw * 0.28), outline=(255, 255, 255, 150),
                        width=max(3, size // 128))

    # Tilted supply tube (top-left), pouring a stream into the canvas.
    sx, sy = int(size * 0.22), int(size * 0.20)
    stw, sth = int(size * 0.16), int(size * 0.30)
    pour_color = rgb(CANDY[1])
    # Tube body, rotated ~25 degrees (approximated with a polygon).
    import math
    ang = math.radians(25)
    ca, sa = math.cos(ang), math.sin(ang)
    def rot(px, py):
        rx, ry = px - sx, py - sy
        return (sx + rx * ca - ry * sa, sy + rx * sa + ry * ca)
    corners = [rot(sx - stw / 2, sy), rot(sx + stw / 2, sy),
               rot(sx + stw / 2, sy + sth), rot(sx - stw / 2, sy + sth)]
    d.polygon(corners, outline=(255, 255, 255, 170), width=max(3, size // 128))
    # Paint inside the tilted tube.
    inner = [rot(sx - stw / 2 + 12, sy + sth * 0.35), rot(sx + stw / 2 - 12, sy + sth * 0.35),
             rot(sx + stw / 2 - 12, sy + sth - 12), rot(sx - stw / 2 + 12, sy + sth - 12)]
    d.polygon(inner, fill=pour_color)
    # Pour stream: curved thick line from tube mouth to canvas mouth.
    mouth = rot(sx + stw / 2, sy)
    target = (cx - tw * 0.1, top_y - 6)
    steps = 24
    prev = mouth
    for k in range(1, steps + 1):
        t = k / steps
        x = mouth[0] + (target[0] - mouth[0]) * t
        y = mouth[1] + (target[1] - mouth[1]) * t * t + 30 * t * (1 - t)
        d.line([prev, (x, y)], fill=pour_color + (255,), width=max(4, size // 48))
        prev = (x, y)
    # Splash dots where the stream lands.
    for dx, dy, r in [(-14, -6, 9), (10, -10, 7), (0, 6, 6)]:
        rr = max(3, int(r * size / 1024))
        d.ellipse([target[0] + dx - rr, target[1] + dy - rr,
                   target[0] + dx + rr, target[1] + dy + rr],
                  fill=pour_color + (255,))

    # Sparkles.
    for px, py, sr in [(int(size * 0.82), int(size * 0.18), 12),
                       (int(size * 0.14), int(size * 0.62), 8)]:
        sr = max(3, int(sr * size / 1024))
        d.line([(px - sr, py), (px + sr, py)], fill=(255, 255, 255, 220), width=max(2, sr // 3))
        d.line([(px, py - sr), (px, py + sr)], fill=(255, 255, 255, 220), width=max(2, sr // 3))

    img.putalpha(mask)
    bg = Image.new("RGBA", (size, size), (23, 16, 46, 255))
    bg.paste(img, (0, 0), img)
    return bg.convert("RGB")

SIZES = [
    ("Icon-20@2x.png", 40, "20x20", "2x"),
    ("Icon-20@3x.png", 60, "20x20", "3x"),
    ("Icon-29@2x.png", 58, "29x29", "2x"),
    ("Icon-29@3x.png", 87, "29x29", "3x"),
    ("Icon-40@2x.png", 80, "40x40", "2x"),
    ("Icon-40@3x.png", 120, "40x40", "3x"),
    ("Icon-60@2x.png", 120, "60x60", "2x"),
    ("Icon-60@3x.png", 180, "60x60", "3x"),
    ("Icon-1024.png", 1024, "1024x1024", "1x"),
]

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    master = draw_icon(1024)
    images = []
    for filename, px, size_str, scale in SIZES:
        icon = master.resize((px, px), Image.LANCZOS)
        icon.save(OUT / filename)
        images.append({"filename": filename, "idiom": "iphone",
                       "scale": scale, "size": size_str})
    (OUT / "Contents.json").write_text(json.dumps(
        {"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print("wrote", len(images), "icons")

if __name__ == "__main__":
    main()
