"""Prepare Ayame/Emilia's complete staff appearances for Uru's shared combat kit."""
import argparse
from collections import Counter, defaultdict
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import sys

from PIL import Image

from prepare_crossgate_kazi_attack import packed_frame
from recover_crossgate_kazi import ROOT, pack_frames
from recover_crossgate_saizo import retime

OUT = ROOT / "assets/characters/crossgate/fighters/emilia"
REPORT = ROOT / "build/Other Files/Asset Toolkit/Emilia"
# Keep the CH1 records: Joy EX reuses the blue/silver IDs for another character.
RECORDS = {
    120387: ("Emilia + Puck", "update-ex:1916", 120387, True),
    120388: ("Emilia", "update-ex:1911", 120388, True),
    106275: ("Original Brown / Purple", "ex:532", 106279, False),
    106281: ("Original Black / Red", "ex:538", 106285, False),
    106287: ("Original Red / Green", "ex:544", 106291, False),
    106293: ("Original Gold / Pink", "ex:550", 106297, False),
    100774: ("Dark Ayame", "joy-ex:799", 100778, False),
    105430: ("Snow Ayame", "joy-ex:238", 105434, False),
    105824: ("Pink-haired Ayame", "puk3:473", 105828, False),
    105830: ("Blonde Ayame", "puk3:479", 105834, False),
    105837: ("Magenta Hair / Black", "puk3:533", 105841, False),
    106625: ("Blonde / Dark Green", "joy:714", 106629, False),
    111669: ("Brown Hair / White", "puk2:1152", 111669, True),
    120322: ("Sakura Ayame", "v3:957", 120326, False),
    120484: ("Fragrant Ayame", "ch1:782", 120488, False),
    120490: ("Green Hair / White", "ch1:788", 120494, False),
    100224: ("Blue-haired Ayame", "ch1:794", 100228, False),
    100230: ("Silver-haired Ayame", "ch1:800", 100234, False),
}
PLAIN, STAFF = "puk3:531", "puk3:533"


def canvases(*parts):
    left = min(x for image, x, y in parts)
    top = min(y for image, x, y in parts)
    right = max(x + image.width for image, x, y in parts)
    bottom = max(y + image.height for image, x, y in parts)
    result = []
    for image, x, y in parts:
        canvas = Image.new("RGBA", (right - left, bottom - top))
        canvas.paste(image, (x - left, y - top))
        result.append(canvas)
    return result, left, top


def recover(source, check=False):
    sys.path.insert(0, str(source / "tools"))
    import cg_assets as cg

    @lru_cache(maxsize=None)
    def poses(key):
        return {(c["action"], c["direction"]): c for c in cg.actor(key)[2]}

    @lru_cache(maxsize=4096)
    def frame(key, action, direction, index):
        return cg.frame_parts(key, poses(key)[action, direction]["index"], index)

    def palette_map(key):
        counts = defaultdict(Counter)
        for action in (0, 1, 3, 6, 11, 12, 14):
            for direction in range(8):
                clip = poses(key)[action, direction]
                for i in range(min(len(clip["frames"]), len(poses(PLAIN)[action, direction]["frames"]))):
                    (plain, target), _, _ = canvases(frame(PLAIN, action, direction, i),
                                                    frame(key, action, direction, i))
                    for a, b in zip(plain.getdata(), target.getdata()):
                        if a[3] and b[3]:
                            counts[a][b] += 1
        return {color: choices.most_common(1)[0][0] for color, choices in counts.items()}

    @lru_cache(maxsize=None)
    def body_palette(key):
        return {color for action in (0, 1, 3) for direction in range(8)
                for i in range(len(poses(key)[action, direction]["frames"]))
                for color in frame(key, action, direction, i)[0].getdata() if color[3]}

    def fit_staff(key, action, direction, index, mapping):
        target = frame(key, action, direction, index)
        count = len(poses(PLAIN)[action, direction]["frames"])
        reference = min(index, count - 1)
        if key == "update-ex:1916" and action in (0, 9, 11, 20):
            # Puck lengthens stationary clips; match Emilia's actual body, not the cat's clock.
            best = (-1, 0)
            for i in range(count):
                (body, original), _, _ = canvases(target, frame("update-ex:1911", action, direction, i))
                score = sum(a == b and b[3] > 0 for a, b in zip(body.getdata(), original.getdata()))
                best = max(best, (score, i))
            reference = best[1]
        parts = [target, frame(PLAIN, action, direction, reference), frame(STAFF, action, direction, reference)]
        puck_attack = key == "update-ex:1916" and action == 5
        if puck_attack:
            parts.append(frame("update-ex:1911", action, direction, index))
        layers, x, y = canvases(*parts)
        image, plain, staff = layers[:3]
        without_puck = layers[3].load() if puck_attack else None
        body_colors = body_palette("update-ex:1911" if puck_attack else key) if action == 5 else set()
        target_pixels, plain_pixels, staff_pixels = image.load(), plain.load(), staff.load()
        for row in range(image.height):
            for col in range(image.width):
                a, b = plain_pixels[col, row], staff_pixels[col, row]
                if puck_attack and target_pixels[col, row][3] and target_pixels[col, row] != without_puck[col, row]:
                    continue
                # The receiving head is wider than the donor's; clear its vacated outline too.
                if (action == 5 and not b[3] and -35 <= x + col <= 35 and -110 <= y + row <= 15
                        and ((y + row <= -30 and (a[3] or target_pixels[col, row] in body_colors))
                             or (target_pixels[col, row] in body_colors and max(target_pixels[col, row][:3]) < 128
                                 and target_pixels[col, row][1] <= target_pixels[col, row][0]))):
                    target_pixels[col, row] = (0, 0, 0, 0)
                    continue
                if a == b:
                    if action == 5 and b[3] and not target_pixels[col, row][3]:
                        target_pixels[col, row] = mapping.get(b, b)
                    continue
                if b[3]:
                    body = a[3] or (-35 <= x + col <= 35 and -90 <= y + row <= 15)
                    target_pixels[col, row] = mapping.get(b, b) if body else b
                elif a[3] and -65 <= y + row <= -8 and -35 <= x + col <= 35:
                    target_pixels[col, row] = (0, 0, 0, 0)
        assert image.getbbox()
        return image, x, y

    donor = json.loads((ROOT / "assets/characters/crossgate/ruby/motions.json").read_text())["clips"]
    OUT.mkdir(parents=True, exist_ok=True)
    REPORT.mkdir(parents=True, exist_ok=True)
    summary = []
    for skin, (name, key, source_id, fitted) in RECORDS.items():
        assert cg.actor(key)[0] == source_id
        mapping = palette_map("update-ex:1911" if skin == 120387 else key) if fitted else {}
        clips, unique = {}, {}
        out = OUT / str(skin)
        out.mkdir(parents=True, exist_ok=True)
        originals = poses(key)
        assert len(originals) == 152 and {a for a, _ in originals} == set(range(21)) - {2, 4}
        for (action, direction), clip in originals.items():
            native = []
            for i in range(len(clip["frames"])):
                image, x, y = fit_staff(key, action, direction, i, mapping) if fitted else frame(key, action, direction, i)
                packed = packed_frame(image, x, y, unique)
                assert packed is not None
                native.append(packed)
                if action == 0 and direction == 4 and i == 0:
                    portrait = Image.new("RGBA", (128, 160))
                    portrait.paste(image, (x + 64, y + 128))
                    if check:
                        with Image.open(out / "portrait.png") as saved:
                            assert saved.convert("RGBA").tobytes() == portrait.tobytes(), (skin, "portrait")
                    else:
                        portrait.save(out / "portrait.png")
            picks = list(range(len(native)))
            duration = clip["duration"] / 1000
            sounds = []
            if action == 5:
                # Reuse Uru's five exact swing/contact markers without changing his combat.
                anchors = [(0, 0), (14, 5), (15, 6)]
                for contact in (19, 23, 27, 31):
                    anchors.extend([(contact - 2, 4), (contact - 1, 5), (contact, 6)])
                anchors.append((37, len(native) - 1))
                picks = retime(*anchors)
                clock = donor[f"5:{direction}"]
                assert len(picks) == len(clock["frames"]) == 38 and set(picks) == set(range(len(native)))
                duration, sounds = clock["duration"], clock["sounds"]
            clips[f"{action}:{direction}"] = dict(duration=duration, frames=[native[i] for i in picks],
                                                  sounds=sounds, source_clip=clip["index"],
                                                  source_frames=clip["frames"], frame_map=picks,
                                                  source_duration=clip["duration"] / 1000)
        if check:
            manifest = json.loads((out / "motions.json").read_text())
            assert manifest["key"] == key and manifest["source_id"] == source_id
            assert manifest["weapon"] == "staff" and manifest["fitted_staff"] == fitted
            assert manifest["clips"].keys() == clips.keys(), skin
            for pose, expected in clips.items():
                saved = manifest["clips"][pose]
                assert {k: v for k, v in saved.items() if k != "frames"} == json.loads(json.dumps(
                    {k: v for k, v in expected.items() if k != "frames"})), (skin, pose, "clock/source")
                assert len(saved["frames"]) == len(expected["frames"]), (skin, pose)
                for actual, (_, ox, oy) in zip(saved["frames"], expected["frames"]):
                    assert actual[5:] == [ox, oy], (skin, pose, "origin")
            pages = manifest["pages"]
        else:
            pages = pack_frames(clips, unique, out)
            manifest = dict(id=skin, name=name, key=key, source_id=source_id, weapon="staff", pages=pages,
                            fitted_staff=fitted, staff_donor=STAFF if fitted else key, clips=clips)
            (out / "motions.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")
        # Reopen every stored frame; atlas preparation must never change its pixels.
        atlases = [Image.open(out / f"atlas-{i}.png").convert("RGBA") for i in range(pages)]
        checked = 0
        for pose, motion in manifest["clips"].items():
            for index, region in enumerate(motion["frames"]):
                page, x, y, w, h, _, _ = region
                art = atlases[page].crop((x, y, x + w, y + h))
                digest = (art.size, hashlib.sha256(art.tobytes()).hexdigest())
                assert digest in unique and art.tobytes() == unique[digest].tobytes()
                if check:
                    assert digest == clips[pose]["frames"][index][0], (skin, pose, index, "frame order")
                checked += 1
        row = dict(id=skin, name=name, key=key, source_id=source_id, fitted_staff=fitted,
                   actions=19, clips=len(clips), frames_checked=checked, unique_frames=len(unique), pages=pages,
                   rgba_bytes=sum(image.width * image.height * 4 for image in atlases))
        summary.append(row)
        print(json.dumps(row), flush=True)
    (REPORT / ("preservation.json" if check else "recovery.json")).write_text(json.dumps(summary, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Preserved Magic Power compiler project")
    parser.add_argument("--check", action="store_true", help="Verify all prepared frames against source without rewriting assets")
    args = parser.parse_args()
    recover(args.source.resolve(), args.check)
