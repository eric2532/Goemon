"""Recover Shin's original skill sprites and sound from the preserved Magic Power archive."""
import argparse
import json
import sys
from pathlib import Path
from shutil import copyfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters/crossgate/shin"


def pack_meditation_icon():
    skin = OUT / "100050"
    motions = json.loads((skin / "motions.json").read_text())
    sword = next(stance for stance in motions["weapons"] if stance["weapon"] == "sword")
    page, x, y, width, height, offset_x, offset_y = sword["clips"]["6:5"]["frames"][2]
    with Image.open(skin / f"cast-{page - motions['pages']}.png") as atlas:
        assert 0 <= x < x + width <= atlas.width and 0 <= y < y + height <= atlas.height
        body = atlas.crop((x, y, x + width, y + height))

    with Image.open(OUT / "meditation.png") as sheet:
        assert sheet.size == (7 * 340, 342)
        effect = sheet.crop((2 * 340, 0, 3 * 340, 342))
    effect.thumbnail((124, 124), Image.Resampling.LANCZOS)
    icon = Image.new("RGBA", (128, 128))
    icon.alpha_composite(effect, (2, 0))
    icon.alpha_composite(body, (64 + offset_x, 103 + offset_y))
    icon.resize((64, 64), Image.Resampling.LANCZOS).save(OUT / "meditation-icon.png")


def recover(source: Path):
    sys.path.insert(0, str(source / "tools"))
    import cg_assets as cg
    import cg_sounds as sounds

    def export(key, resource, columns, filename, icon_frame):
        ident, _, clips = cg.actor(key)
        assert ident == resource
        clip = clips[0]
        if resource == 110473:
            assert len(clips) == 8 and clips[1]["frames"] == clip["frames"][::-1]
        else:
            assert len(clips) == 1
        frames = [cg.frame_parts(key, clip["index"], i) for i in range(len(clip["frames"]))]
        left = min(x for _, x, _ in frames)
        top = min(y for _, _, y in frames)
        width = max(x + image.width for image, x, _ in frames) - left
        height = max(y + image.height for image, _, y in frames) - top
        sheet = Image.new("RGBA", (columns * width, ((len(frames) + columns - 1) // columns) * height))
        for i, (frame, x, y) in enumerate(frames):
            point = (i % columns * width + x - left, i // columns * height + y - top)
            sheet.paste(frame, point)
            assert sheet.crop((*point, point[0] + frame.width, point[1] + frame.height)).tobytes() == frame.tobytes()
        sheet.save(OUT / (filename + ".png"))
        if icon_frame is not None:
            icon = frames[icon_frame][0].copy()
            icon.thumbnail((60, 60), Image.Resampling.LANCZOS)
            square = Image.new("RGBA", (64, 64))
            square.paste(icon, ((64 - icon.width) // 2, (64 - icon.height) // 2))
            square.save(OUT / (filename + "-icon.png"))
        print(f"{resource}: {len(frames)} frames of {width}×{height}, origin {(-left, -top)}")

    export("v3:472", 111046, 9, "sure-strike", 4)
    export("v3:503", 111047, 7, "double-edge", 2)
    export("v3:94", 110473, 6, "two-birds", 2)
    export("original:3160", 110180, 7, "meditation", None)
    pack_meditation_icon()
    export("v3:470", 111029, 7, "combo-ex", None)
    export("v3:387", 111053, 6, "counter", 6)
    standard = cg.actor("original:3133")
    assert standard[0] == 110153
    cue, = sounds.clip_cues(standard[2][0])
    assert (cue["id"], cue["frame"], cue["file"]) == (253, 0, "sounds/cgefc02.wav")
    copyfile(cg.SOURCE / "se/cgefc02.wav", ROOT / "assets/audio/crossgate/shin/cgefc02.wav")
    copyfile(cg.SOURCE / "se/cgefc04.wav", ROOT / "assets/audio/crossgate/shin/cgefc04.wav")
    assert sounds.sound_table()["256"]["file"].lower() == r"se\cgefc05.wav"
    copyfile(cg.SOURCE / "se/cgefc05.wav", ROOT / "assets/audio/crossgate/shin/cgefc05.wav")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    recover(parser.parse_args().source.resolve())
