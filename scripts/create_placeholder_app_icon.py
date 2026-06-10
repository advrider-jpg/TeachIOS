#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
out = ROOT / "GradeDraft/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
out.parent.mkdir(parents=True, exist_ok=True)

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
img.save(out)
print(out)
