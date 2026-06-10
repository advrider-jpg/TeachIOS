#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "GradeDraft/Resources/Assets.xcassets/AppIcon.appiconset"
ICON_DIR.mkdir(parents=True, exist_ok=True)

# Keep this generator deterministic so regenerated icons produce stable diffs.
APP_ICON_SLOTS = [
    ("iphone", "20x20", "2x"), ("iphone", "20x20", "3x"),
    ("iphone", "29x29", "2x"), ("iphone", "29x29", "3x"),
    ("iphone", "40x40", "2x"), ("iphone", "40x40", "3x"),
    ("iphone", "60x60", "2x"), ("iphone", "60x60", "3x"),
    ("ipad", "20x20", "1x"), ("ipad", "20x20", "2x"),
    ("ipad", "29x29", "1x"), ("ipad", "29x29", "2x"),
    ("ipad", "40x40", "1x"), ("ipad", "40x40", "2x"),
    ("ipad", "76x76", "1x"), ("ipad", "76x76", "2x"),
    ("ipad", "83.5x83.5", "2x"),
]


def draw_master_icon() -> Image.Image:
    size = 1024
    img = Image.new("RGB", (size, size), (16, 34, 57))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((190, 150, 834, 872), radius=96, fill=(244, 248, 252))
    for y in [272, 396, 520, 644]:
        draw.rounded_rectangle((292, y, 738, y + 44), radius=22, fill=(76, 98, 128))
    draw.rounded_rectangle((260, 236, 340, 316), radius=24, fill=(235, 194, 63))
    draw.rounded_rectangle((260, 360, 340, 440), radius=24, fill=(235, 194, 63))
    draw.rounded_rectangle((260, 484, 340, 564), radius=24, fill=(235, 194, 63))
    draw.line((314, 758, 424, 840, 714, 642), fill=(235, 194, 63), width=58, joint="curve")
    return img


def pixels_for(size: str, scale: str) -> int:
    return int(round(float(size.split("x", 1)[0]) * int(scale.removesuffix("x"))))


def filename_for(idiom: str, size: str, scale: str) -> str:
    return f"AppIcon-{idiom}-{size.replace('.', '_')}@{scale}.png"


def main() -> None:
    master = draw_master_icon()
    master.save(ICON_DIR / "AppIcon-1024.png", optimize=True)

    images = []
    for idiom, size, scale in APP_ICON_SLOTS:
        pixels = pixels_for(size, scale)
        filename = filename_for(idiom, size, scale)
        master.resize((pixels, pixels), Image.Resampling.LANCZOS).save(ICON_DIR / filename, optimize=True)
        images.append({"filename": filename, "idiom": idiom, "scale": scale, "size": size})

    images.append({"filename": "AppIcon-1024.png", "idiom": "ios-marketing", "scale": "1x", "size": "1024x1024"})
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (ICON_DIR / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")
    print(ICON_DIR)


if __name__ == "__main__":
    main()
