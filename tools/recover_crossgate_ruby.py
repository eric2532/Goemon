"""Recover Ruby's sprites and separate Arcadia's rune pixels offline."""
import argparse
import hashlib
import json
import sys
import wave
from pathlib import Path

from PIL import Image, ImageChops

from recover_crossgate_kazi import ROOT, pack_frames

OUT = ROOT / "assets/characters/crossgate/ruby"
AUDIO = ROOT / "assets/audio/crossgate/ruby"
BODY, BASE, AURA = "joy:813", "puk3:844", "puk3:850"


def recover_regeneration(source):
    import cg_assets as cg
    import cg_sounds

    assets = source / "godot/assets"
    manifest = json.loads((assets / "humanoid-spells/manifest.json").read_text())
    spell = manifest["skills"]["h_recover"]["11"]
    assert (spell["protocolType"], spell["sublevel"], spell["cast"], spell["targets"]) == (64, 10, "110081", ["110176"])
    cast = manifest["clips"][spell["cast"]]
    ring = manifest["clips"][spell["targets"][0]]
    cast_sound, ring_sound = spell["castSound"], ring["sounds"][0]
    assert (cast["duration"], ring["duration"], cast_sound["id"], ring_sound["id"]) == (357, 680, 261, 291)
    for item, target in [(cast, OUT / "recovery-cast.png"), (ring, OUT / "recovery-ring.png"),
                         (cast_sound, AUDIO / "cgefc10.wav"), (ring_sound, AUDIO / "cgefc38.wav")]:
        data = (assets / item["file"]).read_bytes()
        assert hashlib.sha256(data).hexdigest() == item["sha256"]
        target.write_bytes(data)
    hoops = manifest["clips"][manifest["skills"]["heal"]["11"]["targets"][0]]
    assert (hoops["resource"], hoops["frames"], hoops["columns"], hoops["duration"], hoops["bounds"]) == (
        110085, 46, 8, 1598, [-59, -251, 62, 29]
    )
    hoop_sound = hoops["sounds"][0]
    assert (hoop_sound["frame"], hoop_sound["id"]) == (0, 278)
    data = (assets / hoop_sound["file"]).read_bytes()
    assert hashlib.sha256(data).hexdigest() == hoop_sound["sha256"]
    (AUDIO / "cgefc27.wav").write_bytes(data)
    green_row = cg.latest_animation_rows("original")[110165]
    green_clip, = cg.actor(f"original:{green_row}")[2]
    green_cue, = cg_sounds.clip_cues(green_clip)
    assert (green_cue["frame"], green_cue["id"], green_cue["file"]) == (0, 279, "sounds/cgefc28.wav")
    green_sound = (cg.SOURCE / "se/cgefc28.wav").read_bytes()
    assert hashlib.sha256(green_sound).hexdigest() == "e6d3cfd265cd16281cc529392be05b08a79cd85f9842c67dbd23bfa737c9bf3e"
    (AUDIO / "cgefc28.wav").write_bytes(green_sound)
    hoop_source = assets / hoops["file"]
    assert hashlib.sha256(hoop_source.read_bytes()).hexdigest() == hoops["sha256"]
    with Image.open(hoop_source) as atlas:
        # Match the approved green preview while keeping the original frame masks.
        rgba = atlas.convert("RGBA")
        green = rgba.convert("RGB").convert("RGB", (
            .25, .40, .35, 0,
            .60, .25, .15, 0,
            .12, .13, .75, 0,
        ))
        green.putalpha(rgba.getchannel("A"))
        green.save(OUT / "recovery-hoops.png")
    w, h = hoops["width"], hoops["height"]
    frame = 13
    x, y = frame % hoops["columns"] * w, frame // hoops["columns"] * h
    icon = green.crop((x, y, x + w, y + h))
    icon = icon.crop(icon.getbbox())
    icon.thumbnail((54, 54), Image.Resampling.LANCZOS)
    tile = Image.new("RGBA", (64, 64))
    tile.paste(icon, ((64 - icon.width) // 2, (64 - icon.height) // 2))
    tile.save(OUT / "recovery-icon.png")


def recover(source):
    sys.path.insert(0, str(source / "tools"))
    import cg_assets as cg
    import cg_sounds

    keys = (BODY, BASE, AURA)
    actors = [cg.actor(key) for key in keys]
    assert [actor[0] for actor in actors] == [105716, 109901, 109907]
    body_clips, base_clips, aura_clips = [
        {(c["action"], c["direction"]): c for c in actor[2]} for actor in actors
    ]
    OUT.mkdir(parents=True, exist_ok=True)
    unique, clips, layers = {}, {}, {}
    effect_frames = 0

    def stash(image, x, y):
        box = image.getbbox()
        if not box:
            return None
        art = image.crop(box)
        digest = (art.size, hashlib.sha256(art.tobytes()).hexdigest())
        unique.setdefault(digest, art)
        return (digest, x + box[0], y + box[1])

    for pose, clip in body_clips.items():
        frames, runes, sparks = [], [], []
        for i in range(len(clip["frames"])):
            body, bx, by = cg.frame_parts(BODY, clip["index"], i)
            body_frame = stash(body, bx, by)
            assert body_frame
            frames.append(body_frame)
            rune_frame, spark_frame = None, None
            if pose in aura_clips and pose[0] != 10:
                donors = [base_clips[pose], aura_clips[pose]]
                assert all(d["duration"] == clip["duration"] and len(d["frames"]) == len(clip["frames"]) for d in donors)
                plain, px, py = cg.frame_parts(BASE, donors[0]["index"], i)
                aura, ax, ay = cg.frame_parts(AURA, donors[1]["index"], i)
                x, y = min(bx, ax, px), min(by, ay, py)
                w = max(bx + body.width, ax + aura.width, px + plain.width) - x
                h = max(by + body.height, ay + aura.height, py + plain.height) - y
                donor_mask = Image.new("L", (w, h))
                donor_mask.paste(plain.getchannel("A"), (px - x, py - y))
                effect = Image.new("RGBA", (w, h))
                effect.paste(aura, (ax - x, ay - y))
                alpha = ImageChops.subtract(effect.getchannel("A"), donor_mask)
                assert not ImageChops.multiply(alpha, donor_mask).getbbox()
                effect.putalpha(alpha)
                # The lower isometric pixels form the ground ring. Upper sparks remain upright.
                split = max(0, min(h, -20 - y))
                rune_frame = stash(effect.crop((0, split, w, h)), x, y + split)
                spark_frame = stash(effect.crop((0, 0, w, split)), x, y)
                effect_frames += bool(rune_frame or spark_frame)
                if pose == (0, 4) and i == 0:
                    effect.alpha_composite(body, (bx - x, by - y))
                    effect.crop(effect.getbbox()).save(OUT / "portrait.png")
            runes.append(rune_frame)
            sparks.append(spark_frame)
        key = "%d:%d" % pose
        layers[key] = {"runes": runes, "sparks": sparks}
        clips[key] = {
            "duration": clip["duration"] / 1000, "frames": frames,
            "source_clip": clip["index"], "source_frames": clip["frames"], "sounds": cg_sounds.clip_cues(clip),
        }
    assert len(clips) == 152 and effect_frames > 500
    assert {cue["id"] for clip in clips.values() for cue in clip["sounds"]} == {109, 111, 139}
    packed_layers = {key + layer: {"frames": [frame for frame in frames if frame]}
                     for key, entry in layers.items() for layer, frames in entry.items()}
    pages = pack_frames(clips | packed_layers, unique, OUT)
    for key, entry in layers.items():
        for layer, frames in entry.items():
            packed = iter(packed_layers[key + layer]["frames"])
            clips[key][layer] = [next(packed) if frame else None for frame in frames]
    manifest = dict(name="Uru", id=105716, key=BODY, aura=109907, aura_key=AURA,
                    reference_key=BASE, pages=pages, unique_frames=len(unique), clips=clips)
    (OUT / "motions.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")
    AUDIO.mkdir(parents=True, exist_ok=True)
    sounds = json.loads((source / "godot/assets/sounds/manifest.json").read_text())["sounds"]
    for ident in ("109", "111", "139"):
        spec = sounds[ident]
        wav = source / "godot/assets" / spec["file"]
        with wave.open(str(wav), "rb") as stream:
            assert hashlib.sha256(stream.readframes(stream.getnframes())).hexdigest() == spec["pcmSha256"]
        (AUDIO / wav.name).write_bytes(wav.read_bytes())
    (AUDIO / "provenance.json").write_text(json.dumps({n: sounds[n] for n in ("109", "111", "139")}, indent=2) + "\n")
    recover_regeneration(source)
    recover_spirit(source)
    print(f"Uru: {len(clips)} clips, {effect_frames} aura frames, {len(unique)} unique frames, {pages} atlas pages.")


def pack_spirit_icon(rings):
    assert rings.mode == "RGBA" and rings.size == (320, 160)
    ring = rings.crop((40, 80, 80, 160))
    ring = ring.crop(ring.getbbox())
    trail = ring.copy()
    trail.thumbnail((17, 17), Image.Resampling.LANCZOS)
    ring.thumbnail((22, 22), Image.Resampling.LANCZOS)
    icon = Image.new("RGBA", (64, 64))
    for position in ((5, 12), (23, 5), (9, 34), (28, 41)):
        icon.alpha_composite(trail, position)
    icon.alpha_composite(ring, (39, 18))
    icon.save(OUT / "spirit-icon.png")


def recover_spirit(source):
    import struct
    import cg_assets as cg

    client = source / "research/newclient20261030"
    snapshot = (client / "combat/bluecg-virtual-memory.bin").read_bytes()
    assert hashlib.sha256(snapshot).hexdigest() == "8babbe4ad20e4e1e2a6992ecf086d47ef3527426879699f83fa2cebb1a476afe"
    for address, value in [(0x433e3c, 0x42dee5), (0x42dff2, 110052), (0x414bc9, 114177),
                           (0x405db9, 110001), (0x414f87, 110001), (0x41b330, 259), (0x406003, 255)]:
        assert struct.unpack_from("<I", snapshot, address - 0x400000)[0] == value

    archive = cg.SOURCE
    try:
        cg.SOURCE = client / "source/bin"
        for read in (cg.anime_data, cg.actor, cg.latest_animation_rows, cg.graphic_index):
            read.cache_clear()
        rows = cg.latest_animation_rows("v3")
        ring = f"v3:{rows[114177]}"
        ring_clips = cg.actor(ring)[2]
        assert [(c["direction"], c["action"], len(c["frames"])) for c in ring_clips] == [
            (direction, action, 1) for direction in range(8) for action in (0, 3)
        ]
        rings = Image.new("RGBA", (8 * 40, 2 * 80))
        for i, clip in enumerate(ring_clips):
            pixels, x, y = cg.frame_parts(ring, i, 0)
            rings.paste(pixels, (clip["direction"] * 40 + 20 + x, (i % 2) * 80 + 40 + y))
        rings.save(OUT / "spirit-rings.png")
        pack_spirit_icon(rings)
    finally:
        cg.SOURCE = archive


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Preserved Magic Power project")
    recover(parser.parse_args().source.resolve())
