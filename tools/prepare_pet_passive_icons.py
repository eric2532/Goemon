"""Compose family passive icons around the unchanged recovered pet sprites."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SKILLS = ROOT / "assets/ui/crossgate/skills"


def main():
    for family, cell, scale, name in [
        ("dragon_lizards", 1, 3, "water-dragon-regeneration"),
        ("mantises", 0, 2, "mantis-critical"),
    ]:
        source = ROOT / f"assets/characters/crossgate/{family}/portraits.png"
        original = source.read_bytes()
        with Image.open(source) as sheet:
            sprite = sheet.convert("RGBA").crop((cell * 96, 0, (cell + 1) * 96, 96))
        sprite = sprite.crop(sprite.getbbox())
        sprite = sprite.resize((sprite.width * scale, sprite.height * scale), Image.Resampling.NEAREST)
        assert sprite.width <= 224 and sprite.height <= 224
        effect = Image.new("RGBA", (256, 256))
        draw = ImageDraw.Draw(effect)
        if family == "dragon_lizards":
            color = (68, 244, 132, 230)
            draw.arc((17, 155, 239, 233), 7, 345, fill=color, width=10)
            draw.arc((38, 172, 217, 218), 175, 352, fill=(173, 255, 193, 255), width=4)
            for x, y, side in [(29, 162, -1), (218, 148, 1), (61, 90, -1), (196, 63, 1)]:
                draw.line([(x, y + 25), (x + side * 6, y), (x - side * 5, y - 23), (x + side * 3, y - 44)], fill=color, width=5)
            stars = [(22, 111, 8), (231, 92, 9), (177, 24, 7), (74, 38, 6)]
        else:
            color = (255, 112, 58, 245)
            draw.polygon([(17, 220), (81, 116), (239, 23), (169, 126)], fill=color)
            draw.polygon([(32, 210), (99, 122), (224, 40), (153, 131)], fill=(255, 237, 166, 255))
            draw.line([(13, 158), (69, 143)], fill=(255, 174, 76, 240), width=5)
            draw.line([(187, 82), (241, 58)], fill=(255, 174, 76, 240), width=5)
            stars = [(208, 104, 17), (30, 62, 9), (224, 191, 8)]
        for x, y, radius in stars:
            draw.polygon([(x, y - radius), (x + 3, y - 3), (x + radius, y), (x + 3, y + 3), (x, y + radius), (x - 3, y + 3), (x - radius, y), (x - 3, y - 3)], fill=(218, 255, 228, 255) if family == "dragon_lizards" else (255, 246, 203, 255))
        icon = Image.new("RGBA", (256, 256))
        icon.alpha_composite(effect.filter(ImageFilter.GaussianBlur(8)))
        icon.alpha_composite(effect)
        at = ((256 - sprite.width) // 2, (256 - sprite.height) // 2)
        icon.alpha_composite(sprite, at)
        foreground = icon.crop((at[0], at[1], at[0] + sprite.width, at[1] + sprite.height))
        assert all(a == b for a, b in zip(sprite.getdata(), foreground.getdata()) if a[3] == 255)
        assert source.read_bytes() == original
        icon.save(SKILLS / f"{name}.png")
        print(SKILLS / f"{name}.png")


if __name__ == "__main__":
    main()
