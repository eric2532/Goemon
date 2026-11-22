"""Pack Saizo's original art for the shared Maze kit."""
import argparse
import json
import sys
from pathlib import Path

from prepare_crossgate_kazi_attack import packed_frame
from recover_crossgate_kazi import OUT as KAZ, pack_frames

OUT = KAZ.parent / "fighters" / "saizo"
RECORDS = {
    106477: "joy:676", 106052: "ex:386", 106058: "ex:392", 106064: "ex:398",
    106070: "ex:404", 105696: "puk3:441", 105492: "joy-ex:297", 105486: "joy-ex:291",
    106188: "joy-ex:884", 120234: "v3:1089", 105178: "joy-ex:303", 106182: "joy-ex:878",
    119308: "ch1:112",
}
BODY_ACTIONS = (0, 1, 3, 6, 8, 9, 10)


def retime(*anchors):
    # Keep the source contact/release drawings on the existing combat markers.
    frames = []
    for (start, first), (end, last) in zip(anchors, anchors[1:]):
        frames.extend(round(first + (last - first) * (i - start) / (end - start))
                      for i in range(start, end))
    return frames + [anchors[-1][1]]


def recover(source):
    sys.path.insert(0, str(source / "tools"))
    import cg_assets as cg
    import cg_sounds

    maze = json.loads((KAZ.parent / "maze/motions.json").read_text())
    fist_frames = retime((0, 0), (6, 6), (7, 7), (17, 13))
    throw_frames = retime((0, 0), (7, 4), (8, 6))
    for ident, unarmed in RECORDS.items():
        pack, row = unarmed.split(":")
        sword = f"{pack}:{int(row) + 1}"
        assert cg.actor(unarmed)[0] == ident and cg.actor(sword)[0] == ident + 1
        clips, unique = {}, {}
        for record, prefix in ((sword, ""), (unarmed, "dagger:")):
            for clip in cg.actor(record)[2]:
                action, direction = clip["action"], clip["direction"]
                key = f"{action}:{direction}"
                picks = list(range(len(clip["frames"])))
                timing = {"duration": clip["duration"] / 1000}
                if action in BODY_ACTIONS:
                    key = prefix + key
                elif action == 5 or (action == 7 and record == unarmed):
                    if record == sword:
                        assert clip["frames"][6][3] == 10133
                        cues = cg_sounds.clip_cues(clip)
                        timing.update(contacts=[cue['atMs']/1000 for cue in cues if 10000 <= cue['flag'] < 20000],
                                      sounds=[cue for cue in cues if cue['flag'] < 10000])
                    else:
                        if action == 7:
                            assert clip["frames"][4][3] == 10111
                            picks = throw_frames
                        else:
                            assert clip["frames"][7][3] == 10132
                            key = "fist:" + key
                            picks = fist_frames
                        donor = maze["clips"][key]
                        assert len(picks) == len(donor["frames"])
                        timing = {k: donor[k] for k in ("duration", "contacts", "sounds") if k in donor}
                else:
                    continue
                frames = [packed_frame(*cg.frame_parts(record, clip["index"], i), unique) for i in picks]
                assert all(frame is not None for frame in frames)
                clips[key] = dict(frames=frames, source_clip=clip["index"], source_frames=picks, **timing)
        assert len(clips) == (len(BODY_ACTIONS) * 2 + 3) * 8
        for action in BODY_ACTIONS:
            for direction in range(8):
                base = clips[f"{action}:{direction}"]
                alternate = clips[f"dagger:{action}:{direction}"]
                assert (base["duration"], len(base["frames"])) == (alternate["duration"], len(alternate["frames"]))
        out = OUT / str(ident)
        out.mkdir(parents=True, exist_ok=True)
        pages = pack_frames(clips, unique, out)
        portrait, x, y = cg.frame_parts(unarmed, clips["dagger:0:4"]["source_clip"], 0)
        box = portrait.getchannel("A").getbbox()
        portrait.crop(box).save(out / "portrait.png")
        manifest = dict(id=ident, key=sword, dagger_key=unarmed, pages=pages, clips=clips,
                        portrait_origin=[x + box[0], y + box[1]], release_frame=maze["release_frame"])
        (out / "motions.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")
        print(f"{ident}: {len(clips)} clips, {len(unique)} original frames, {pages} pages")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Preserved Magic Power project")
    recover(parser.parse_args().source)
