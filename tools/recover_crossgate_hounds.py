"""Pack the approved Blue Crossgate hounds without running or altering the client."""
import argparse
import hashlib
import json
import struct
import sys
import wave
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters/crossgate/hounds"
AUDIO = ROOT / "assets/audio/crossgate/hounds"
ACTORS = (
    (101030, "original:2818"), (101031, "original:2819"), (101032, "original:2820"),
    (101033, "original:2821"), (102335, "ex:1574"), (102336, "ex:1575"),
    (103363, "puk2:1287"), (103364, "puk2:1288"), (103365, "puk2:1289"),
    (108202, "joy-ex:546"), (108331, "puk2:703"), (109497, "joy-ex:931"),
    (109498, "joy-ex:932"), (109499, "joy-ex:933"), (117127, "puk3:328"),
    (117128, "puk3:329"), (119406, "v3:1178"),
    (108448, "ch1:491"), (109927, "puk3:870"), (119618, "ch1:629"), (102007, "ex:1765"),
)
ACTIONS = (0, 3, 5, 8, 10, 1)
PAGE_SIZE = 2048
TABLE_WIDTH = 512


def recover_hud_heads(cg):
    # Front idle frames share one head outline except for the aura, flame and three-headed variants.
    head = [(0, 31), (8, 34), (12, 23), (17, 16), (32, 16), (39, 24),
            (42, 35), (49, 31), (46, 45), (34, 52), (31, 66), (18, 66),
            (15, 52), (4, 45)]
    special = {
        18: [(11, 47), (18, 48), (24, 33), (33, 30), (44, 33), (49, 47),
             (57, 47), (56, 60), (46, 65), (43, 79), (24, 79), (22, 66), (13, 60)],
        19: [(0, 70), (12, 80), (15, 61), (25, 53), (41, 53), (51, 63),
             (54, 82), (66, 70), (61, 103), (46, 114), (42, 130), (24, 130),
             (19, 114), (6, 103)],
        20: [(0, 39), (13, 42), (16, 31), (22, 19), (40, 19), (46, 31),
             (49, 42), (62, 39), (62, 72), (45, 77), (38, 80), (24, 80),
             (17, 75), (0, 73)],
    }
    sheet = Image.new("RGBA", (7 * 32, 3 * 32))
    for skin, (_, key) in enumerate(ACTORS):
        _, _, clips = cg.actor(key)
        idle = next(clip for clip in clips if clip["action"] == 0 and clip["direction"] == 5)
        image, _, _ = cg.frame_parts(key, idle["index"], 0)
        image = image.crop(image.getbbox())
        offset = {10: 22, 17: 56}.get(skin, 0)
        mask = Image.new("L", image.size)
        ImageDraw.Draw(mask).polygon(special.get(skin, [(x + offset, y) for x, y in head]), fill=255)
        image.putalpha(ImageChops.multiply(image.getchannel("A"), mask))
        image = image.crop(image.getbbox())
        image.thumbnail((30, 30), Image.Resampling.LANCZOS)
        sheet.paste(image, (skin % 7 * 32 + (32 - image.width) // 2,
                            skin // 7 * 32 + (32 - image.height) // 2))
    sheet.save(OUT / "hud-heads.png")


def recover_summon(cg):
    # MON's incoming-pet state 0x34 selects original animation 110096.
    key = "original:3076"
    info = cg.clip_metadata(key)
    clip, = info["clips"]
    assert info["id"] == 110096 and clip["available"] and clip["duration"] == 400
    assert clip["frameCount"] == 7 and clip["bounds"] == [-111, -291, 112, 11]
    width, height = clip["cellWidth"], clip["cellHeight"]
    sheet = Image.new("RGBA", (width, height * clip["frameCount"]))
    for index in range(clip["frameCount"]):
        sheet.paste(cg.frame_image(key, 0, index), (0, index * height))
    assert hashlib.sha256(sheet.tobytes()).hexdigest() == (
        "cc1a14a36d85a0f91d624d0da0a6ae4c1f700c2800f5235b80ee0fe8b969a512"
    )
    sheet.save(OUT / "summon.png")


def index_frame(image, ox, oy, palette, palettes, unique):
    bounds = image.getbbox()
    if bounds is None:
        # Original invisible effect frames still occupy their source time.
        image = Image.new("RGBA", (1, 1))
    else:
        image = image.crop(bounds)
        ox += bounds[0]
        oy += bounds[1]
    pixels = list(image.getdata())
    used = sorted({pixel for pixel in pixels if pixel[3]})
    if len(palette) + sum(pixel not in palette for pixel in used) > 256:
        palettes.append(list(palette))
        palette = {(0, 0, 0, 0): 0}
    for pixel in used:
        palette.setdefault(pixel, len(palette))
    indices = bytes(palette[pixel] if pixel[3] else 0 for pixel in pixels)
    colors = list(palette)
    assert all(colors[index] == (pixel if pixel[3] else (0, 0, 0, 0))
               for pixel, index in zip(pixels, indices))
    texture = (image.size, indices)
    unique.setdefault(texture, None)
    return (texture, ox, oy, len(palettes)), palette


def write_atlas(out, unique, palettes, clip_table, frame_table, page_size, table_width, grouped=False):
    pages = []
    shelves = []
    # Keep a selectable pet's frames together so its pack does not load every other skin's pages.
    for texture in unique if grouped else sorted(unique, key=lambda frame: -frame[0][1]):
        (width, height), indices = texture
        shelf = next((row for row in shelves if height <= row[3] and row[2] + width <= page_size), None)
        if shelf is None:
            top = max((row[1] + row[3] for row in shelves if row[0] == len(pages) - 1), default=page_size)
            if top + height > page_size:
                pages.append(Image.new("L", (page_size, page_size)))
                top = 0
            shelf = [len(pages) - 1, top, 0, height]
            shelves.append(shelf)
        page, top, left, _ = shelf
        pages[page].paste(Image.frombytes("L", (width, height), indices), (left, top))
        assert pages[page].crop((left, top, left + width, top + height)).tobytes() == indices
        unique[texture] = ((left, top, width, height), page)
        shelf[2] += width

    out.mkdir(parents=True, exist_ok=True)
    for page, image in enumerate(pages):
        image.save(out / f"atlas-{page}.png")
    palette_image = Image.new("RGBA", (256, len(palettes)))
    for row, palette in enumerate(palettes):
        palette_image.paste(Image.frombytes("RGBA", (len(palette), 1), bytes(v for color in palette for v in color)), (0, row))
    palette_image.save(out / "palette.png")
    table = clip_table.copy()
    for texture, ox, oy, palette in frame_table:
        rect, page = unique[texture]
        table.extend((rect, (ox, oy, page, palette)))
    table.extend([(0, 0, 0, 0)] * (-len(table) % table_width))
    (out / "frames.bin").write_bytes(b"".join(struct.pack("<4f", *row) for row in table))
    return len(pages)


def recover(source):
    sys.path.insert(0, str(source / "tools"))
    import cg_assets as cg
    import cg_sounds

    unique = {}
    clip_table, frame_table, variants, timelines, palettes = [], [], [], [], []
    sound_ids = {204, 205}
    substitutions = []
    for ident, key in ACTORS:
        actor, _, clips = cg.actor(key)
        assert actor == ident
        missing = set()
        sound_ids.update(cue["id"] for clip in clips for cue in cg_sounds.clip_cues(clip, missing=missing))
        assert not missing
        clips = {(c["action"], c["direction"]): c for c in clips}
        assert all(not cg_sounds.clip_cues(clips[action, direction])
                   for action in ACTIONS if action != 5 for direction in range(8))
        attack_directions = []
        for direction in range(8):
            attack = clips[5, direction]
            cues = cg_sounds.clip_cues(attack)
            attack_directions.append(cues)
            timelines.extend((attack["duration"] * .03, len(cues)))
            assert len(cues) <= 13
            for cue in cues:
                timelines.extend((cue["atMs"] * .03, cue["id"]))
            timelines.extend((0, 0) * (13 - len(cues)))
        variants.append({"id": ident, "key": key, "attack": attack_directions[4],
                         "attack_directions": attack_directions,
                         "fall_duration": clips[10, 4]["duration"] / 1000,
                         "cast": cg_sounds.clip_cues(clips[6, 4])})
        # Use the source colors exactly. Index zero is transparent.
        palette = {(0, 0, 0, 0): 0}
        frames = {}
        for action in ACTIONS:
            for direction in range(8):
                clip = clips[action, direction]
                clip_table.append((len(frame_table), len(clip["frames"]), clip["duration"] / 1000, 0))
                for i, frame in enumerate(clip["frames"]):
                    token = (frame[:3], clip["palette"], clip["flags"], clip["high"])
                    if token not in frames:
                        try:
                            image, ox, oy = cg.frame_parts(key, clip["index"], i)
                        except ValueError:
                            if ident != 108448 or frame[0] not in range(174413, 174420):
                                raise
                            # shortcut: seven damaged source frames use nearby original poses until a complete archive is available.
                            backup, index = (clips[3, 4], i) if action == 3 else (clip, 1)
                            image, ox, oy = cg.frame_parts(key, backup["index"], index)
                            substitutions.append({"id": ident, "clip": clip["index"], "frame": i,
                                                  "source_clip": backup["index"], "source_frame": index})
                        frames[token], palette = index_frame(image, ox, oy, palette, palettes, unique)
                    frame_table.append(frames[token])
        palettes.append(list(palette))

    pages = write_atlas(OUT, unique, palettes, clip_table, frame_table, PAGE_SIZE, TABLE_WIDTH)
    AUDIO.mkdir(parents=True, exist_ok=True)
    recover_summon(cg)
    recover_hud_heads(cg)
    manifest = json.loads((source / "godot/assets/sounds/manifest.json").read_text())["sounds"]
    sounds = {}
    for sound_id in sorted(sound_ids):
        spec = manifest[str(sound_id)]
        path = source / "godot/assets" / spec["file"]
        with wave.open(str(path), "rb") as stream:
            pcm = stream.readframes(stream.getnframes())
        assert hashlib.sha256(pcm).hexdigest() == spec["pcmSha256"]
        dest = AUDIO / path.name
        if sound_id in (131, 132, 264):
            dest = AUDIO.parent / "kazi" / path.name
            with wave.open(str(dest), "rb") as stream:
                assert stream.readframes(stream.getnframes()) == pcm
        else:
            dest.write_bytes(path.read_bytes())
        sounds[sound_id] = dict(spec, goemon_file=str(dest.relative_to(ROOT)))
    (OUT / "motions.json").write_text(json.dumps({
        "variants": variants, "pages": pages, "table_width": TABLE_WIDTH,
        "clip_count": len(clip_table), "frame_count": len(frame_table), "timelines": timelines, "sounds": sounds, "substitutions": substitutions,
    }, separators=(",", ":")) + "\n")
    print(f"{len(variants)} variants, {len(frame_table)} frame references, {len(unique)} exact indexed frames, {pages} atlas layers.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Preserved Magic Power project")
    recover(parser.parse_args().source)
