"""Copy verified original skill tiers; keep the preserved client assets read-only."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters/crossgate/skill_tiers"
EXISTING = {
    "110100": "qigong/charge.png",
    "110140": "elements/fire.png", "110141": "elements/fire.png", "110142": "elements/fire.png",
    "110020": "elements/ice.png", "110044": "elements/wind.png", "110052": "elements/cast.png",
    "110032": "elements/meteor-1.png", "110033": "elements/meteor-2.png", "110034": "elements/meteor-3.png",
    "110081": "ruby/recovery-cast.png", "110176": "ruby/recovery-ring.png",
    "110180": "shin/meditation.png",
}
EX_ELEMENTS = {"fire": [111008, 111009, 111010], "ice": [111005],
               "wind": [111011], "meteor": [111002, 111003, 111004]}


def recover(source):
    sys.path.insert(0, str(source / "tools"))
    import cg_assets as cg

    cg.SOURCE = source / "research/newclient20261030/source/bin"
    assets = source / "godot/assets"
    manifest = json.loads((assets / "humanoid-spells/manifest.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    result = {"source_snapshot": manifest["snapshotSha256"], "clips": {}, "elements": {}, "recovery": [], "meditation": []}
    paths_by_hash = {}

    def copy(ref):
        if ref in result["clips"]:
            return ref
        if ref in manifest["clips"]:
            clip = manifest["clips"][ref]
            path = assets / clip["file"]
            raw = path.read_bytes()
            assert hashlib.sha256(raw).hexdigest() == clip["sha256"], ref
            atlas = Image.open(path).convert("RGBA")
        else:
            key = f"v3:{cg.latest_animation_rows('v3')[int(ref)]}"
            ident, _, variants = cg.actor(key)
            native, = variants
            assert str(ident) == ref and (native["action"], native["direction"]) == (0, 0)
            info = cg.metadata(key)
            meta, = info["clips"]
            atlas = cg.sheet_image(key, 0, info=info)
            raw = cg.png(atlas)
            clip = dict(width=meta["cellWidth"], height=meta["cellHeight"], frames=meta["frameCount"],
                        columns=meta["columns"], duration=meta["duration"], bounds=meta["bounds"],
                        sha256=hashlib.sha256(raw).hexdigest(), nativeFrames=native["frames"], source_key=key)
        destination = OUT / f"{ref}.png"
        existing = ROOT / "assets/characters/crossgate" / EXISTING[ref] if ref in EXISTING else None
        shared_path = "res://" + existing.relative_to(ROOT).as_posix() if existing else paths_by_hash.get(clip["sha256"])
        if shared_path:
            shared = ROOT / shared_path.removeprefix("res://")
            assert hashlib.sha256(shared.read_bytes()).hexdigest() == clip["sha256"], ref
            if destination.exists():
                assert hashlib.sha256(destination.read_bytes()).hexdigest() == clip["sha256"], ref
                destination.unlink()
                destination.with_suffix(".png.import").unlink(missing_ok=True)
            runtime_path = shared_path
        else:
            destination.write_bytes(raw)
            runtime_path = "res://" + destination.relative_to(ROOT).as_posix()
        paths_by_hash[clip["sha256"]] = runtime_path
        bounds = []
        for i in range(clip["frames"]):
            x, y = i % clip["columns"] * clip["width"], i // clip["columns"] * clip["height"]
            frame = atlas.crop((x, y, x + clip["width"], y + clip["height"]))
            bounds.append(list(frame.getbbox() or (0, 0, 0, 0)))
        result["clips"][ref] = {k: clip[k] for k in ("width", "height", "frames", "columns", "duration", "sha256", "bounds")}
        result["clips"][ref]["runtime_path"] = runtime_path
        result["clips"][ref]["frame_bounds"] = bounds
        result["clips"][ref]["hit_frames"] = [i for i, row in enumerate(clip["nativeFrames"]) if 10000 <= row[3] < 20000]
        if "source_key" in clip:
            result["clips"][ref]["source_key"] = clip["source_key"]
        return ref

    for ref in ("110103", "110102", "110101", "110100", "110055", "110054", "110053", "110052"):
        copy(ref)
    for kind, family in {"fire": "fire", "ice": "h_ice", "wind": "h_wind", "meteor": "h_earth"}.items():
        result["elements"][kind] = []
        for level in (1, 4, 7, 10):
            spec = manifest["skills"][family][str(level)]
            result["elements"][kind].append({"cast": copy(spec["cast"]), "targets": [copy(ref) for ref in spec["targets"]]})
        result["elements"][kind].append({"cast": copy("111001"), "targets": [copy(str(ref)) for ref in EX_ELEMENTS[kind]]})
    for level in (1, 4, 7, 10):
        spec = manifest["skills"]["h_recover"][str(level)]
        result["recovery"].append({"cast": copy(spec["cast"]), "target": copy(spec["targets"][0])})
    assert len(result["recovery"]) == 4
    result["recovery"].append({"cast": copy("111014"), "target": copy("111019")})
    for level in (1, 4, 7, 10):
        result["meditation"].append(copy(manifest["skills"]["h_meditate"][str(level)]["cast"]))
    assert manifest["skills"]["h_meditate"]["11"]["cast"] == result["meditation"][-1]
    result["meditation"].append(copy("111017"))
    for ref in ("111016", "111052", "111054", "111055"):
        copy(ref)
    (OUT / "manifest.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"Mapped {len(result['clips'])} source IDs to {len(paths_by_hash)} shared original sheets; no source pixels changed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    recover(parser.parse_args().source.resolve())
