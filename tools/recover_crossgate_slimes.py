"""Recover the 29 inventoried Cross Gate slimes from the preserved client."""
import argparse
import hashlib
import json
import sys
import wave
from pathlib import Path

from recover_crossgate_hounds import ROOT, TABLE_WIDTH, index_frame, write_atlas

OUT = ROOT / "assets/characters/crossgate/slimes"
AUDIO = ROOT / "assets/audio/crossgate/slimes"
IDS = (*range(101500, 101504), *range(102367, 102374), 108335, 109274,
       *range(110904, 110913), 117016, 117017, 117143, *range(119135, 119139))
# Keep the first six slots compatible with the hound batch.
ACTIONS = (0, 3, 5, 8, 10, 1, 2, 4, 6, 9)


def recover(source):
    sys.path.insert(0, str(source / "tools"))
    import cg_assets as cg
    import cg_sounds

    catalog = json.loads((source / "godot/assets/exploration/pets.json").read_text())["pets"]
    keys = {pet["id"]: pet["key"] for pet in catalog}
    unique = {}
    rows, frames, palettes, variants, timelines = [], [], [], [], []
    ids = set()
    for ident in IDS:
        key = keys[ident]
        source_id, _, source_clips = cg.actor(key)
        assert source_id == ident
        clips = {(c["action"], c["direction"]): c for c in source_clips}
        assert len(clips) == len(source_clips) and all(a in ACTIONS for a, _ in clips)
        idle, _, y = cg.frame_parts(key, clips[0, 4]["index"], 0)
        bounds = idle.getbbox()
        scale = 1.8 / (bounds[3] - bounds[1])
        ground_shift = y + bounds[3] - 10
        row = {"id": ident, "key": key, "fall_duration": max(clips[10, d]["duration"] for d in range(8)) / 1000,
               "clips": []}
        palette = {(0, 0, 0, 0): 0}
        indexed = {}
        for action in ACTIONS:
            for direction in range(8):
                clip = clips.get((action, direction))
                if clip is None:
                    assert ident == 108335 and action == 4
                    rows.append((0, 0, 0, scale))
                    continue
                duration = clip["duration"]
                missing = set()
                cues = cg_sounds.clip_cues(clip, missing=missing)
                assert not missing
                ids.update(cue["id"] for cue in cues)
                row["clips"].append({"action": action, "direction": direction, "source_index": clip["index"],
                                     "duration_ms": duration, "frames": len(clip["frames"]), "sounds": cues})
                rows.append((len(frames), len(clip["frames"]), duration / 1000, scale))
                if action == 5:
                    assert sum(cue["flag"] >= 10000 for cue in cues) == 1 and all(cue["atMs"] > 0 for cue in cues)
                    timelines.extend((duration * .03, len(cues)))
                    for cue in cues:
                        timelines.extend((cue["atMs"] * .03, cue["id"]))
                    timelines.extend((0, 0) * (13 - len(cues)))
                for index, frame in enumerate(clip["frames"]):
                    token = (frame[:3], clip["palette"], clip["flags"], clip["high"])
                    if token not in indexed:
                        image, ox, oy = cg.frame_parts(key, clip["index"], index)
                        indexed[token], palette = index_frame(image, ox, oy - ground_shift, palette, palettes, unique)
                    frames.append(indexed[token])
        palettes.append(list(palette))
        variants.append(row)

    pages = write_atlas(OUT, unique, palettes, rows, frames, 2048, TABLE_WIDTH)
    manifest = json.loads((source / "godot/assets/sounds/manifest.json").read_text())["sounds"]
    AUDIO.mkdir(parents=True, exist_ok=True)
    sounds = {}
    for ident in sorted(ids):
        spec = manifest[str(ident)]
        path = source / "godot/assets" / spec["file"]
        with wave.open(str(path), "rb") as audio:
            assert hashlib.sha256(audio.readframes(audio.getnframes())).hexdigest() == spec["pcmSha256"]
        dest = AUDIO / path.name
        dest.write_bytes(path.read_bytes())
        sounds[ident] = dict(spec, goemon_file=str(dest.relative_to(ROOT)))
    (OUT / "motions.json").write_text(json.dumps({
        "variants": variants, "actions": ACTIONS, "pages": pages, "table_width": TABLE_WIDTH,
        "clip_count": len(rows), "frame_count": len(frames), "timelines": timelines, "sounds": sounds,
    }, separators=(",", ":")) + "\n")
    print(f"{len(variants)} slimes, {sum(len(row['clips']) for row in variants)} original clips, "
          f"{len(frames)} frame records, {len(unique)} indexed images, {pages} pages, {len(sounds)} WAVs")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Preserved Magic Power project")
    recover(parser.parse_args().source)
