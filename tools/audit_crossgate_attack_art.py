"""Read-only comparison of every active Cross Gate attack drawing with its source."""
import argparse
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import sys

from PIL import Image, ImageChops, ImageDraw

from prepare_crossgate_player_audio import ROOT, ART, manifest_paths

OUT = ROOT / "build/Other Files/Asset Toolkit/Cross Gate Attack Silhouettes"


def source_location(clip, index, first_frame=0):
    if "frame_map" in clip:
        return clip["source_clip"], clip["frame_map"][index]
    records = clip.get("source_frames", [])
    if records and isinstance(records[0], int):
        return clip["source_clip"], records[index]
    if records and len(records[0]) == 2:
        return tuple(records[index])
    return clip["source_clip"], index + first_frame


def matches_frame(prepared, source):
    image, x, y = source
    box = image.getbbox()
    assert box, "Empty source drawing"
    actual, ox, oy = prepared
    expected = image.crop(box)
    return ((ox, oy) == (x + box[0], y + box[1]) and actual.size == expected.size
            and actual.tobytes() == expected.tobytes())


def uncorrected_green_pixels(image, edge_fix):
    if edge_fix:
        return 0
    colors = image.getcolors(65536)
    assert colors is not None, "Unexpected true-color source atlas"
    return sum(count for count, (r, g, b, a) in colors if a == 0 and g-r > 80 and g-b > 80)


def audit(source, out=OUT):
    sys.path.insert(0, str(source / "tools"))
    import cg_assets as cg

    @lru_cache(maxsize=256)
    def original(key, clip, index):
        return cg.frame_parts(key, clip, index)

    out.mkdir(parents=True, exist_ok=True)
    paths = sorted(set(manifest_paths()) | {ART / family / "qi-punch/motions.json" for family in ("kazi", "ruby")})
    entries, mismatches, adapted, unsafe_edges = [], [], [], []
    total = 0
    hashes = {}
    stitched = []
    for path in paths:
        data = json.loads(path.read_text())
        hashes[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
        if data.get('stitched_weapon'):
            from prepare_shin_water_dragon import prepare, OUT as stitched_root
            assert path.parent == stitched_root, 'Unreviewed stitched character'
            prepare(source, check=True)
            stitched.append(dict(path=str(path.relative_to(ROOT)), clips=len(data['clips'])))
            continue
        pages = [Image.open(path.parent / f"atlas-{i}.png").convert("RGBA") for i in range(data["pages"])]
        for i, page in enumerate(pages):
            texture = path.parent / f"atlas-{i}.png"
            edge_fix = "process/fix_alpha_border=true" in texture.with_suffix(".png.import").read_text()
            green = uncorrected_green_pixels(page, edge_fix)
            if green:
                unsafe_edges.append(dict(texture=str(texture.relative_to(ROOT)), green_key_pixels=green))
        verified = set()
        for stance_index, stance in enumerate([data] + data.get("weapons", [])):
            key = stance.get("key", data["key"])
            row = dict(path=str(path.relative_to(ROOT)), stance=stance_index, key=key,
                       weapon=stance.get("weapon", "original"), clips=0, frames=0)
            for pose, clip in stance["clips"].items():
                if pose.split(":")[-2] not in ("5", "7"):
                    continue
                if data.get("fitted_staff") and pose.startswith("5:"):
                    assert path.parent.parent == ART / "fighters/emilia" and data["id"] in (120387, 120388, 111669), "Unreviewed fitted attack"
                    adapted.append(dict(path=row["path"], pose=pose, frames=len(clip["frames"])))
                    continue
                source_key = data.get("dagger_key", key) if pose.startswith(("dagger:", "fist:", "7:")) else key
                row["clips"] += 1
                for index, frame in enumerate(clip["frames"]):
                    source_clip, source_index = source_location(clip, index, int(data.get("first_frame", 0)))
                    page, x, y, width, height, ox, oy = frame
                    assert 0 <= page < len(pages) and x >= 0 and y >= 0
                    assert width > 0 and height > 0 and x + width <= pages[page].width and y + height <= pages[page].height
                    signature = (source_key, source_clip, source_index, tuple(frame))
                    if signature not in verified:
                        actual = pages[page].crop((x, y, x + width, y + height))
                        expected, sx, sy = original(source_key, source_clip, source_index)
                        if not matches_frame((actual, ox, oy), (expected, sx, sy)):
                            left, top = min(ox, sx), min(oy, sy)
                            right, bottom = max(ox + width, sx + expected.width), max(oy + height, sy + expected.height)
                            a = Image.new("RGBA", (right-left, bottom-top)); a.paste(actual, (ox-left, oy-top))
                            b = Image.new("RGBA", a.size); b.paste(expected, (sx-left, sy-top))
                            extra = ImageChops.subtract(a.getchannel("A"), b.getchannel("A"))
                            missing = ImageChops.subtract(b.getchannel("A"), a.getchannel("A"))
                            issue = dict(path=row["path"], stance=stance_index, pose=pose, frame=index,
                                         source_key=source_key, source_clip=source_clip, source_frame=source_index,
                                         added_opaque=sum(extra.histogram()[1:]), missing_opaque=sum(missing.histogram()[1:]))
                            mismatches.append(issue)
                            if len(mismatches) <= 48:
                                board = Image.new("RGB", (a.width*4, a.height*2+24), "#eee6d3")
                                for col, image in enumerate((b, a)):
                                    image = image.resize((image.width*2, image.height*2), Image.Resampling.NEAREST)
                                    board.paste(image, (col*a.width*2, 24), image)
                                ImageDraw.Draw(board).text((3, 4), "Original source | Prepared attack", fill="black")
                                board.save(out / f"difference-{len(mismatches):03d}.png")
                        verified.add(signature)
                    row["frames"] += 1
                    total += 1
            entries.append(row)
        for page in pages:
            page.close()
        print(f"CHECK {path.parent.relative_to(ART)} frames={total} mismatches={len(mismatches)}", flush=True)
    result = dict(manifests=len(paths), stances=len(entries), clips=sum(r["clips"] for r in entries),
                  frames=total, mismatches=mismatches, fitted_emilia=adapted, uncorrected_green_pages=unsafe_edges,
                  entries=entries, manifest_sha256=hashes, stitched_weapons=stitched)
    (out / "source-audit.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"ATTACK_ART_RESULT manifests={len(paths)} frames={total} mismatches={len(mismatches)} adapted_clips={len(adapted)} uncorrected_green_pages={len(unsafe_edges)}")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    result = audit(args.source.resolve(), args.out)
    raise SystemExit(1 if result["mismatches"] or result["uncorrected_green_pages"] else 0)
