"""Measure and preview the generated bitmap fonts against the source layout.

This checks resource geometry. It does not replace execution on a Garmin VM.
"""
import re
from pathlib import Path
from PIL import Image
from make_fonts import ROOT, SPECS


class BitmapFont:
    def __init__(self, name):
        folder = ROOT / "resources/fonts"
        lines = (folder / f"{name}.fnt").read_text().splitlines()
        self.height = int(re.search(r"lineHeight=(\d+)", lines[1])[1])
        self.atlas = Image.open(folder / f"{name}.png")
        self.chars = {}
        for line in lines:
            if line.startswith("char id="):
                entry = dict((k, int(v)) for k, v in re.findall(r"(\w+)=(-?\d+)", line))
                self.chars[chr(entry["id"])] = entry

    def width(self, value):
        return sum(self.chars[c]["xadvance"] for c in value)

    def draw(self, image, value, x, y, color):
        for char in value:
            glyph = self.chars[char]
            sx, sy = glyph["x"], glyph["y"]
            alpha = self.atlas.crop((sx, sy, sx + glyph["width"], sy + glyph["height"]))
            image.paste(color, (x + glyph["xoffset"], y + glyph["yoffset"]), alpha)
            x += glyph["xadvance"]


fonts = [BitmapFont(name) for name in SPECS]
source = (ROOT / "source/RideField.mc").read_text()
pattern = r', "([^"]*)", (\d+), (\d+), (\d+), (\d+), ([\w.]+), (true|false)\);'
fields = re.findall(pattern, source)
assert len(fields) == 19
normal_fields = [("am", "4", "3", "104", "18", "0x555555", "false")] + fields[:14]
high_fields = fields[14:]


def draw_page(values, output=None, high=False):
    image = Image.new("RGB", (246, 322), "white")
    if high:
        image.paste("#0055aa", (0, 0, 246, 64))
        image.paste("#5500aa", (0, 65, 246, 170))
    else:
        image.paste("#0055aa", (118, 65, 244, 139))
        image.paste("#5500aa", (2, 141, 148, 245))
    occupied = []
    fallbacks = []
    for value, entry in zip(values, high_fields if high else normal_fields):
        unit, x, y, width, index, color, right = entry
        x, y, width, index = map(int, (x, y, width, index))
        color = "white" if color == "Graphics.COLOR_WHITE" else "#" + color[2:]
        font = fonts[19 if index == 15 and len(value) <= 3 else index]
        row_height = font.height
        unit_font = fonts[13 if index in (3, 7) else 11]
        stacked = unit == "km/h"
        unit_width = 0
        if unit:
            unit_width = unit_font.width(unit) + 1
        if stacked:
            unit_width = max(unit_font.width("km"), unit_font.width("/h")) + 1
        if font.width(value) + unit_width > width:
            font = fonts[4 if index == 5 else 10]
            fallbacks.append(index)
        if font.width(value) + unit_width > width:
            value = value.split(".")[0]
        if font.width(value) + unit_width > width:
            value = "--"
        value_width = font.width(value)
        if 14 <= index <= 17:
            x += (width - value_width - unit_width) // 2
        elif right == "true":
            x += width - value_width - unit_width
        y += (row_height - font.height) // 2
        box = (x, y, x + value_width + unit_width, y + font.height)
        assert 0 <= box[0] < box[2] <= 246 and 0 <= y < box[3] <= 322, box
        for a, b, c, d in occupied:
            assert box[2] <= a or x >= c or box[3] <= b or y >= d, (box, (a, b, c, d))
        occupied.append(box)
        font.draw(image, value, x, y, color)
        if stacked:
            unit_font.draw(image, "km", x + value_width + 1, y + font.height - unit_font.height * 2 - 1, color)
            unit_font.draw(image, "/h", x + value_width + 1, y + font.height - unit_font.height, color)
        elif unit:
            unit_font.draw(image, unit, x + value_width + 1, y + font.height - unit_font.height, color)
    if output:
        image.save(output)
    return fallbacks


sample = ["9:42", "1:24:36", "684", "46.72", "31.6", "216", "32.8", "238", "152", "91", "+5.2", "224", "12:48", "32.1", "6.84"]
assert len(normal_fields) == len(sample)
output = ROOT / "bin/resource-preview.png"
fallbacks = draw_page(sample, output)
assert not fallbacks, fallbacks
print(f"Preview fallback fonts: {fallbacks}")
for values in [
    ["11:59", "25:01:01", "12345", "125.4", "99.9", "1250", "125.4", "1500", "220", "180", "-25.5", "1100", "1:15:00", "99.9", "125.4"],
    ["9:42", "0:00:00", "--", "0.00", "--", "--", "--", "--", "--", "--", "--", "--", "--:--", "--", "--"],
]:
    draw_page(values)
print(f"Font geometry and bounds passed. Preview: {output}")

for power in ("600", "1500", "9999", "--"):
    draw_page(["125", power, "180", "220", "25:01:01"], ROOT / "bin/high-preview.png", high=True)
