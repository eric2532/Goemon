"""Compose the barrage icon from the preserved original Lancelot game sprite."""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/crossgate/fighters/lancelot/106125/portrait.png"
OUTPUT = ROOT / "assets/ui/crossgate/skills/barrage-shadows.png"


def main():
    sprite = Image.open(SOURCE).convert("RGBA")
    icon = Image.new("RGBA", (128, 128))
    ghost = sprite.copy()
    ghost.thumbnail((78, 78), Image.Resampling.NEAREST)
    ghost.putalpha(ghost.getchannel("A").point(lambda alpha: round(alpha * 0.5)))
    icon.alpha_composite(ghost, (0, 0))
    icon.alpha_composite(ghost, (128 - ghost.width, 0))
    icon.alpha_composite(sprite, ((128 - sprite.width) // 2, 128 - sprite.height))
    assert icon.size == (128, 128) and icon.getbbox() is not None
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
