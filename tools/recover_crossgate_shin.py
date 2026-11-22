"""Prepare Shin's original sprites for the two basic-attack fighters."""
import argparse
import json
from pathlib import Path
from shutil import copyfile
import sys

from recover_crossgate_kazi import OUT as KAZ, pack_frames
from prepare_crossgate_kazi_attack import packed_frame

OUT = KAZ.parent / "shin"
REGULAR = {
    100050: "Red Hair / Blue", 100056: "Blond / Green",
    100062: "Brown Hair / Red", 100068: "Blue Hair / Charcoal",
    100175: "Blond / Black and Red", 100181: "White Hair / Black and Red",
    100187: "Blond / Silver and Red", 100193: "White Hair / Silver and Red",
    100200: "Monochrome", 100206: "White Hair / Red",
    100212: "White Hair / Charcoal and Red", 100450: "White Hair / Orange",
    100978: "All White", 105573: "Red Hair / Charcoal",
    105610: "White Hair / Violet", 105616: "White Hair / Yellow",
    105622: "White Hair / Pink", 105628: "White Hair / Cyan",
    105634: "White Hair / Black", 105737: "Dark Hair / Teal",
    105742: "Blond / Violet", 105748: "Pink Hair / Navy",
}
SPECIAL = {
    106707: ("Glowing Sword", "original:3277"),
    109140: ("Ember Shields", "puk2:887"),
    111624: ("Gold Runes", "puk2:1107"),
    111625: ("Gold Lightning", "puk2:1108"),
    118986: ("Gold Crescents", "puk3:941"),
    118987: ("Yellow Flame", "puk3:942"),
    118993: ("Red Lightning", "puk3:948"),
    108313: ("Gold Polearm", "puk2:784"),
    120440: ("All White / Red Weapons", "ch1:660"),
    100055: ("Classic Spear", "original:2428"),
    100053: ("Classic Sword", "original:2426"),
}
ACTIONS = (0, 1, 3, 5, 8, 10)
WEAPON_LABELS = {"unarmed": "空手", "sword": "劍", "polearm": "槍"}


def prepare_stance(cg, weapon, key, source_id, unique, actions=ACTIONS):
    ident, _, source_clips = cg.actor(key)
    assert ident == source_id
    poses = {(c["action"], c["direction"]): c for c in source_clips if c["frames"]}
    clips = {}
    for action in actions:
        for direction in range(8):
            clip = poses[action, direction]
            frames = []
            for index in range(len(clip["frames"])):
                image, x, y = cg.frame_parts(key, clip["index"], index)
                body = packed_frame(image, x, y, unique)
                assert body is not None, (key, clip["index"], index)
                frames.append(body)
            motion = dict(duration=clip["duration"] / 1000, frames=frames, source_clip=clip["index"])
            count = len(clip["frames"])
            assert motion["duration"] > 0, (key, action, direction)
            if action == 5:
                # A basic hit uses one contact even when the source sword has multiple effects.
                flags = [frame[-1] for frame in clip["frames"]]
                swing = next((i for i, flag in enumerate(flags) if 0 < flag < 10000), -1)
                contact = next((i for i, flag in enumerate(flags) if flag >= 10000 and i > swing and i > 0),
                               count // 2)
                motion.update(duration=max(.65, motion["duration"]),
                              contact=contact / count,
                              swing=(swing if 0 <= swing <= contact else max(0, contact - 1)) / count)
            clips[f"{action}:{direction}"] = motion
    return dict(weapon=weapon, source_id=source_id, key=key, clips=clips), poses[0, 4]["index"]


def prepare_casts(cg, folder, manifest):
    unique, clips = {}, {}
    for stance in [manifest] + manifest.get("weapons", []):
        key = stance["key"]
        poses = [clip for clip in cg.actor(key)[2] if clip["action"] == 6 and clip["frames"]]
        assert len(poses) == 8 and {clip["direction"] for clip in poses} == set(range(8))
        for clip in poses:
            frames = [packed_frame(*cg.frame_parts(key, clip["index"], i), unique)
                      for i in range(len(clip["frames"]))]
            assert all(frames)
            ticks = max(1, clip["duration"] // (16 * len(frames)))
            markers = [i for i, frame in enumerate(clip["frames"]) if frame[-1] >= 10000]
            motion = dict(duration=len(frames) * ticks / 60,
                          source_clip=clip["index"], frames=frames)
            # Some aura skins have no unique release; elemental contacts keep their own clock.
            if len(markers) == 1:
                motion["release"] = markers[0] * ticks / 60
            pose = f'6:{clip["direction"]}'
            stance["clips"][pose] = motion
            clips[f'{stance["weapon"]}:{pose}'] = motion
    pages = pack_frames(clips, unique, folder, "cast")
    for motion in clips.values():
        for frame in motion["frames"]:
            frame[0] += manifest["pages"]
    manifest["has_cast_atlas"] = True
    manifest["cast_pages"] = pages


def prepare(cg, skin_id, name, records, special):
    folder = OUT / str(skin_id)
    folder.mkdir(parents=True, exist_ok=True)
    unique, stances = {}, []
    for weapon, key, source_id in records:
        stance, portrait_clip = prepare_stance(cg, weapon, key, source_id, unique)
        if not stances:
            portrait, x, y = cg.frame_parts(key, portrait_clip, 0)
            box = portrait.getbbox()
            portrait.crop(box).save(folder / "portrait.png")
        stances.append(stance)
    clips = {f"{stance['weapon']}:{key}": motion for stance in stances for key, motion in stance["clips"].items()}
    pages = pack_frames(clips, unique, folder)
    manifest = dict(stances[0], id=skin_id, pages=pages)
    if len(stances) > 1:
        manifest["weapons"] = stances[1:]
    prepare_casts(cg, folder, manifest)
    (folder / "motions.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")
    if skin_id == 118993:
        from prepare_shin_red_lightning_run import prepare as prepare_run
        prepare_run(folder)
    print(f"{skin_id}: {len(clips)} clips, {len(unique)} unique frames, {pages} pages")
    return [skin_id, name, [x + box[0], y + box[1]], special]


def recover(source, cast_only=False):
    sys.path.insert(0, str(source / "tools"))
    import cg_assets as cg

    if cast_only:
        for skin_id in REGULAR.keys() | SPECIAL.keys():
            path = OUT / str(skin_id) / "motions.json"
            manifest = json.loads(path.read_text())
            prepare_casts(cg, path.parent, manifest)
            path.write_text(json.dumps(manifest, separators=(",", ":")) + "\n")
            if skin_id == 118993:
                from prepare_shin_red_lightning_run import prepare as prepare_run
                prepare_run(path.parent)
        from prepare_shin_water_dragon import prepare as prepare_water_dragon
        prepare_water_dragon(source)
        return

    skins = json.loads((source / "godot/assets/exploration/skins.json").read_text())["skins"]
    roster = {skin["id"]: skin for skin in skins}
    catalog = []
    for skin_id, name in REGULAR.items():
        if skin_id == 105737:
            records = [("unarmed", "puk3:483", 105738), ("sword", "puk3:484", 105739),
                       ("polearm", "puk3:486", 105741)]
        else:
            records = []
            for weapon, label in WEAPON_LABELS.items():
                member = next(item for item in roster[skin_id]["members"] if item["label"] == label)
                records.append((weapon, member["key"], member["id"]))
        catalog.append(prepare(cg, skin_id, name, records, False))
    for skin_id, (name, key) in SPECIAL.items():
        records = [("polearm" if skin_id in (100055, 108313) else "unarmed" if skin_id == 118986 else "sword", key, skin_id)]
        if skin_id == 120440:
            records = [("sword", key, skin_id), ("polearm", "ch1:661", 120441)]
        catalog.append(prepare(cg, skin_id, name, records, True))
    (OUT / "skins.json").write_text(json.dumps(catalog, indent=2) + "\n")
    from prepare_shin_water_dragon import prepare as prepare_water_dragon
    prepare_water_dragon(source)
    audio = OUT.parents[2] / "audio/crossgate/shin"
    audio.mkdir(parents=True, exist_ok=True)
    for filename in ("cgply00b.wav", "cgply01b.wav", "cgply03b.wav", "cgply13b.wav", "cgply04b.wav", "cgply14b.wav"):
        copyfile(cg.SOURCE / "se" / filename, audio / filename)



if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Preserved Magic Power project")
    parser.add_argument("--cast-only", action="store_true")
    args = parser.parse_args()
    recover(args.source, args.cast_only)
