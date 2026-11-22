"""Fit the blue Qi orb and compose Saizo's Assassination icon."""
from pathlib import Path

from PIL import Image

ASSETS = Path(__file__).resolve().parents[1] / "assets"
CROSSGATE = ASSETS / "characters/crossgate"


def main():
    with Image.open(ASSETS / "references/qi-skill-icon/qigong-blue-master.png") as master:
        orb = master.copy()
    orb.putalpha(orb.getchannel("A").point(lambda alpha: alpha if alpha >= 12 else 0))
    orb = orb.crop(orb.getbbox())
    orb.thumbnail((36, 37), Image.Resampling.LANCZOS)
    assert orb.size == (36, 37)
    icon = Image.new("RGBA", (64, 64))
    icon.paste(orb, (14, 13))
    icon.save(CROSSGATE / "kazi/icons/qigong-blue.png")

    with Image.open(ASSETS / "ui/portraits/crossgate/model/39-106052.png") as source:
        saizo = source.crop(source.getbbox())
    saizo.thumbnail((43, 44), Image.Resampling.NEAREST)
    with Image.open(CROSSGATE / "maze/assassination-kill.png") as source:
        kill = source.crop(source.getbbox())
    icon = Image.new("RGBA", (64, 64))
    icon.paste(saizo, ((64 - saizo.width) // 2, 4))
    kill_x = (64 - kill.width) // 2
    icon.paste(kill, (kill_x, 48))
    assert icon.crop((kill_x, 48, kill_x + kill.width, 48 + kill.height)).tobytes() == kill.tobytes()
    icon.save(ASSETS / "ui/crossgate/skills/assassination.png")


if __name__ == "__main__":
    main()
