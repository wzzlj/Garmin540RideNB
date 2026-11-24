"""Build compact BMFont resources from the bundled SIL-licensed typeface."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "assets/TitilliumWeb-Bold.ttf"
SPECS = {
    "TopTime": (27, 0.98), "TopNumber": (28, 1.0),
    "SpeedAverage": (32, 0.84), "PowerAverage": (32, 1.0),
    "SpeedHero": (68, 0.60), "PowerHero": (100, 0.57),
    "SideNumber": (30, 0.90), "LapNumber": (34, 0.98),
    "LapSpeed": (34, 0.84), "LapDistance": (34, 0.94),
    "SmallNumber": (26, 0.76), "Unit11": (11, 1),
    "Unit12": (12, 1), "Unit13": (13, 1),
    "HighSpeed": (58, 1.03), "HighPower": (100, 0.66),
    "HighSide": (47, 0.92), "HighTime": (34, 0.95),
    "Clock": (26, 0.80), "HighPowerThree": (100, 0.90),
    "Grade": (30, 0.70), "SettingsText": (15, 0.95),
}


def build_font(name, height, ratio):
    numeric = not name.startswith("Unit")
    chars = "0123456789.:+-" if numeric else "km/hWbpr%aift"
    if name == "SettingsText":
        chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 :/+.-"
        numeric = False
    source = ImageFont.truetype(str(FONT), 300)
    bounds = source.getbbox("0123456789" if numeric else chars)
    scale = height / (bounds[3] - bounds[1])
    # Garmin BMFont pages use luminance as glyph coverage. RGBA pages can
    # produce solid bounding rectangles and fringes on the device renderer.
    atlas = Image.new("L", (512, 256))
    x = y = 1
    row_height = 0
    entries = []
    for char in chars:
        left, top, right, bottom = source.getbbox(char)
        mask = Image.new("L", (right - left, bottom - top))
        ImageDraw.Draw(mask).text((-left, -top), char, font=source, fill=255)
        width = max(1, round(mask.width * scale * ratio))
        glyph_height = max(1, round(mask.height * scale))
        mask = mask.resize((width, glyph_height), Image.Resampling.LANCZOS)
        if x + width + 1 >= atlas.width:
            x = 1
            y += row_height + 1
            row_height = 0
        assert y + glyph_height <= atlas.height
        atlas.paste(mask, (x, y))
        advance = max(width, round(source.getlength(char) * scale * ratio))
        entries.append(
            f"char id={ord(char)} x={x} y={y} width={width} height={glyph_height} "
            f"xoffset=0 yoffset={round((top - bounds[1]) * scale)} "
            f"xadvance={advance} page=0 chnl=15"
        )
        x += width + 1
        row_height = max(row_height, glyph_height)
    folder = ROOT / "resources/fonts"
    # Font loaders may retain the atlas backing store, including transparent
    # pixels. Remove the unused area before passing resources to the compiler.
    bounds = atlas.getbbox()
    atlas = atlas.crop((0, 0, bounds[2] + 1, bounds[3] + 1))
    atlas.save(folder / f"{name}.png")
    (folder / f"{name}.fnt").write_text(
        f'info face="Titillium Web Bold" size={height} bold=1 italic=0 unicode=1\n'
        f'common lineHeight={height} base={height} scaleW={atlas.width} scaleH={atlas.height} pages=1 packed=0\n'
        f'page id=0 file="{name}.png"\nchars count={len(entries)}\n'
        + "\n".join(entries) + "\nkernings count=0\n"
    )


if __name__ == "__main__":
    for name, spec in SPECS.items():
        build_font(name, *spec)
    (ROOT / "resources/fonts/fonts.xml").write_text(
        "<fonts>\n" + "\n".join(
            f'  <font id="{name}" filename="{name}.fnt" antialias="true"/>'
            for name in SPECS
        ) + "\n</fonts>\n"
    )
    icon = Image.new("RGB", (35, 35), "white")
    draw = ImageDraw.Draw(icon)
    draw.rectangle((18, 1, 34, 15), fill="#0055aa")
    draw.rectangle((1, 17, 17, 34), fill="#5500aa")
    icon.save(ROOT / "resources/drawables/icon.png")
