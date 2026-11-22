"""Recover original Cross Gate cave encounters for the shared sprite batch."""
import argparse
import json
import sys
from pathlib import Path
from PIL import Image

from recover_crossgate_hounds import ACTORS as HOUND_ACTORS, ROOT, TABLE_WIDTH, index_frame, write_atlas

OUT = ROOT / "assets/characters/crossgate/habaru"
ACTIONS = (0, 3, 5, 8, 10, 1)
CAPTAIN_SHARED_AUDIO = {
    106: "assets/characters/crossgate/habaru/cgply02b.wav",
    134: "assets/audio/crossgate/kazi/cgply11b.wav",
    135: "assets/characters/crossgate/zombie_cave/cgply12a.wav",
}
GRAVE_SHARED_AUDIO = {
    **CAPTAIN_SHARED_AUDIO,
    101: "assets/audio/crossgate/hounds/cgply00a.wav",
    132: "assets/characters/crossgate/pirate_cave/cgply10b.wav",
    136: "assets/characters/crossgate/habaru/cgply12b.wav",
}
RUBY_SHARED_AUDIO = {
    103: "assets/audio/crossgate/kazi/cgply01a.wav",
    105: "assets/characters/crossgate/pirate_cave/cgply02a.wav",
    111: "assets/audio/crossgate/ruby/cgply05a.wav",
    131: "assets/characters/crossgate/forest_grave/cgply10a.wav",
    133: "assets/audio/crossgate/kazi/cgply11a.wav",
}
UNDERSEA_SHARED_AUDIO = {
    132: "assets/characters/crossgate/pirate_cave/cgply10b.wav",
    110: "assets/characters/crossgate/habaru/cgply04b.wav",
    103: "assets/audio/crossgate/kazi/cgply01a.wav",
    133: "assets/audio/crossgate/kazi/cgply11a.wav",
    104: "assets/characters/crossgate/pirate_cave/cgply01b.wav",
    134: "assets/audio/crossgate/kazi/cgply11b.wav",
}
FRONTIER_SHARED_AUDIO = {
    **UNDERSEA_SHARED_AUDIO,
    105: "assets/characters/crossgate/pirate_cave/cgply02a.wav",
    135: "assets/characters/crossgate/zombie_cave/cgply12a.wav",
}

def body_rows(image):
    rows = [i // image.width for i, (r,g,b,a) in enumerate(image.getdata())
            if a and (r,g,b) != (20,20,20)]
    return min(rows), max(rows)+1


def recover_bear_icon(cg):
    ident, _, clips = cg.actor("original:2807")
    assert ident == 101010
    idle = next(clip for clip in clips if clip["action"] == 0 and clip["direction"] == 5)
    image, _, _ = cg.frame_parts("original:2807", idle["index"], 0)
    assert image.size == (68, 90)
    face = image.crop((12, 2, 56, 57))
    icon = Image.new("RGBA", (64, 64))
    position = ((64-face.width)//2, (64-face.height)//2)
    icon.paste(face, position)
    assert icon.crop((position[0], position[1], position[0]+face.width, position[1]+face.height)).tobytes() == face.tobytes()
    icon.save(OUT / "bear-icon.png")
    summon = Image.new("RGBA", (128, 128))
    shadow = image.resize((56, 74), Image.Resampling.NEAREST)
    shadow.putalpha(shadow.getchannel("A").point(lambda alpha: round(alpha * 0.5)))
    summon.alpha_composite(shadow, (0, 0))
    summon.alpha_composite(shadow, (72, 0))
    summon.alpha_composite(image, (30, 38))
    assert summon.size == (128, 128) and summon.getbbox() is not None
    summon.save(ROOT / "assets/ui/crossgate/skills/summon-bears.png")


def recover(source, zombie=False, captain=False, grave=False, ruby=False, undersea=False, frontier=False, falken=False, cursed=False, beast=False, shalena=False):
    sys.path.insert(0, str(source / "tools"))
    import cg_assets as cg
    import cg_sounds

    unique, palettes, rows, frames, actors, timelines = {}, [], [], [], [], []
    manifest = json.loads((source / "godot/assets/sounds/manifest.json").read_text())["sounds"]
    sounds = {}
    proportions = (ROOT / "scripts/character_proportions.gd").read_text()
    kazi_height = float(next(line for line in proportions.splitlines() if line.startswith("const GOEMON_HEIGHT=")).split("=")[1])
    output = OUT.parent / "falan_encounters" if frontier else OUT.parent / "undersea" if undersea else OUT.parent / "black_prayer" if ruby else OUT.parent / "forest_grave" if grave else OUT.parent / "pirate_cave" if captain else OUT.parent / "zombie_cave" if zombie else OUT
    if falken:output = OUT.parent / "falken"
    if cursed:output = OUT.parent / "cursed_maze"
    if beast:output = OUT.parent / "beast_maze"
    if shalena:output = OUT.parent / "shalena"
    hound_sounds = json.loads((OUT.parent / "hounds" / "motions.json").read_text())["sounds"] if zombie else {}
    roster = (
        (101100, "original:2822", 3.45, {157:157, 106:106, 135:135}, 1),
        (101100, "original:2822", 2.75, {157:157, 106:106, 135:135}, 1),
        (101103, "original:2825", 2.75, {157:157, 106:106, 135:135}, 3),
        (*HOUND_ACTORS[0], 2.75, {176:157, 101:106, 131:135}, 3),
    ) if zombie else (
        (100625, "original:2759", kazi_height, {106:112, 136:138, 138:164}, 2),
        (101010, "original:2807", 3.35, {110:112, 140:165}, 1),
    )
    if captain:
        # Server enemies 9062, 9063–9064 and 9065–9066 use these three actors.
        roster = (
            (101114, "original:2831", kazi_height, {106:106, 132:135}, 1),
            (101252, "original:2855", 1.95, {191:157, 104:106, 134:135}, 1),
            (101822, "original:2954", 2.85, {105:106, 135:135}, 1),
        )
    if grave:
        roster = (
            (101532, "original:2911", 3.8, {106:106, 134:135}, 1),
            (101114, "original:2831", 2.85, {106:106, 132:135}, 1),
            (107911, "ex:818", 4.35, {106:106, 136:135}, 2),
            (101205, "original:1256", 2.45, {101:106, 131:135}, 1),
        )
    if ruby:
        roster = (
            (100654, "original:1184", kazi_height+.6, {111:135}, 1),
            (101600, "original:1328", kazi_height+.3, {103:106, 133:135}, 2),
            (101121, "original:1248", kazi_height+.3, {105:106, 131:135}, 1),
        )
    if undersea:
        roster = (
            (100802, "original:2797", 4.2, {102:106, 132:135}, 1),
            (101721, "original:2941", kazi_height, {110:106, 132:135}, 1),
            (101700, "original:2931", kazi_height, {103:106, 133:131, 104:112, 134:135}, 1),
        )
    if frontier:
        roster = (
            (101242, "original:2849", kazi_height*.85, {190:157, 105:106, 135:135}, 1),
            (101800, "original:2944", kazi_height*.96, {103:106, 133:135}, 1),
            (101820, "original:2952", kazi_height*.96, {105:106, 135:135}, 1),
            (101313, "original:2865", kazi_height*.85, {117:106, 143:135}, 1),
            (101400, "original:2876", kazi_height*1.65, {102:106, 132:135}, 1),
        )
        species = json.loads((ROOT / "assets/maps/falan/frontier_species.json").read_text())
        assert [r[0] for r in roster] == [r["id"] for r in species[:5]]
        roster += tuple((r["id"], r["key"], kazi_height*r["height"], {}, 0) for r in species[5:])
    if falken:
        roster = ((101531, "original:2910", kazi_height*1.3, {}, 0),
                  (101110, "original:2827", kazi_height, {}, 0),
                  (101701, "original:2932", kazi_height*1.05, {}, 0))
    if cursed:
        roster = ((101204, "original:2840", kazi_height*.8, {}, 0),
                  (101521, "original:2905", kazi_height*.6, {}, 0),
                  (101934, "original:2980", 7.065231834375, {}, 0),
                  (101932, "original:2978", 7.065231834375, {}, 0),
                  (101933, "original:2979", 7.065231834375, {}, 0))
    if shalena:
        species = json.loads((ROOT / "assets/maps/falan/tina/encounters.json").read_text())["species"]
        roster = tuple((r["id"], r["key"], kazi_height*r["height"], {}, 0) for r in species)
    if beast:
        roster = ((101522, "original:2906", kazi_height*.6, {}, 0),)
    if not any((zombie, captain, grave, ruby, undersea, frontier, falken, cursed, beast, shalena)):
        roster += ((101500, "original:2896", 2.3, {112:112, 164:164}, 1),)
    actions = ACTIONS if any((zombie, captain, grave, ruby, falken)) else (*ACTIONS, 9)
    if cursed:actions = (*ACTIONS, 9, 6)
    for actor, (ident, key, height, cue_map, contacts) in enumerate(roster):
        source_id, _, source_clips = cg.actor(key)
        assert source_id == ident
        clips = {(c["action"], c["direction"]): c for c in source_clips}
        idle, _, y = cg.frame_parts(key, clips[0,4]["index"], 0)
        # The source casts an opaque charcoal shadow below the foot edge.
        top, foot = body_rows(idle)
        scale = height / (foot - top)
        if frontier:
            idle_spans = []
            for direction in range(8):
                clip = clips[0,direction]
                for index in range(len(clip["frames"])):
                    first, last = body_rows(cg.frame_parts(key, clip["index"], index)[0])
                    idle_spans.append(last-first)
            # Wing movement changes the silhouette substantially on the bat and bee.
            scale = max(scale, kazi_height*.82/min(idle_spans))
        lift = round(.55 / scale) if captain and ident == 101252 else 0
        shift = y + foot - 10 + lift
        palette, indexed = {(0,0,0,0): 0}, {}
        for action in actions:
            for direction in range(8):
                clip = clips[7 if ruby and ident == 100654 and action == 5 else (0 if cursed and (action,direction) not in clips else action),direction]
                duration = clip["duration"]
                rows.append((len(frames), len(clip["frames"]), duration / 1000, scale))
                if action == 5:
                    cues = cg_sounds.clip_cues(clip)
                    added_frontier = (frontier and actor >= 5) or falken or cursed or beast or shalena
                    if added_frontier:
                        contact_ids = sorted({c["id"] for c in cues if 10000 <= c["flag"] < 20000})
                        sound_ids = sorted({c["id"] for c in cues if not 10000 <= c["flag"] < 20000})
                        assert 0 < len(contact_ids) <= 4 and len(sound_ids) <= 4 and len(cues) <= 15
                    assert added_frontier or sum(c["flag"] >= 10000
                               and (not frontier and ident not in (101205, 101700) or c["flag"] < 20000) for c in cues) == contacts
                    # Use the existing native sprite swing/contact opcodes.
                    timelines.extend((duration * .03, len(cues)))
                    for cue in cues:
                        opcode = ([135,138,164,165][contact_ids.index(cue["id"])] if 10000 <= cue["flag"] < 20000
                                  else [106,112,131,157][sound_ids.index(cue["id"])]) if added_frontier else cue_map[cue["id"]]
                        if grave and 20000 <= cue["flag"] and ident == 101205:
                            opcode = 131
                        if frontier and not added_frontier and cue["flag"] >= 20000:
                            opcode = 131 # Retain the cue without creating a second contact.
                        timelines.extend((cue["atMs"] * .03, opcode))
                        spec = manifest[str(cue["id"])]
                        if ident == HOUND_ACTORS[0][0]:
                            shared = hound_sounds[str(cue["id"])]
                            assert shared["pcmSha256"] == spec["pcmSha256"]
                            sounds[f"{actor}:{opcode}"] = "res://" + shared["goemon_file"]
                            continue
                        relative = Path(spec["file"])
                        audio = (source / "godot/assets" / relative).read_bytes()
                        if ident == 101500:
                            shared = ROOT / "assets/audio/crossgate/slimes" / relative.name
                            assert shared.read_bytes() == audio
                            sounds[f"{actor}:{opcode}"] = "res://" + str(shared.relative_to(ROOT))
                            continue
                        shared_audio = FRONTIER_SHARED_AUDIO if frontier else UNDERSEA_SHARED_AUDIO if undersea else RUBY_SHARED_AUDIO if ruby else GRAVE_SHARED_AUDIO if grave else CAPTAIN_SHARED_AUDIO if captain else {}
                        if cue["id"] in shared_audio:
                            shared = shared_audio[cue["id"]]
                            assert (ROOT / shared).read_bytes() == audio
                            sounds[f"{actor}:{opcode}"] = "res://" + shared
                            continue
                        sounds[f"{actor}:{opcode}"] = relative.name
                        output.mkdir(parents=True, exist_ok=True)
                        (output / relative.name).write_bytes(audio)
                    timelines.extend((0, 0) * ((15 if frontier or shalena else 13)-len(cues)))
                for index, frame in enumerate(clip["frames"]):
                    token = (frame[:3], clip["palette"], clip["flags"], clip["high"])
                    if token not in indexed:
                        image, x, y = cg.frame_parts(key, clip["index"], index)
                        indexed[token], palette = index_frame(image, x, y-shift, palette, palettes, unique)
                    frames.append(indexed[token])
        palettes.append(list(palette))
        actors.append({"id": ident, "standing_height": height, "fall_duration": max(clips[10,d]["duration"] for d in range(8))/1000})
        if frontier:
            actors[-1].update(standing_height=(foot-top)*scale, min_idle_height=min(idle_spans)*scale)
    if not any((zombie, captain, grave, ruby, undersea, frontier, falken, cursed, beast, shalena)):
        # Keep Venoa's fits while the Habaru models grow. All four share the recovered frames.
        count = len(actions) * 8
        bear = actors[1]
        original = rows[count:count*2]
        audio = {name.split(":")[1]: path for name, path in sounds.items() if name.startswith("1:")}
        for skin, height in ((3, 4.2), (4, bear["standing_height"])):
            rows.extend((start, length, duration, scale * height / bear["standing_height"])
                        for start, length, duration, scale in original)
            timelines.extend(timelines[8*28:16*28])
            sounds.update({f"{skin}:{cue}": path for cue, path in audio.items()})
            actors.append(dict(bear, standing_height=height))
        rows[:count*2] = [(start, length, duration, scale*2)
                          for start, length, duration, scale in rows[:count*2]]
        for index in (0, 1):
            actors[index]["standing_height"] *= 2
    pages = write_atlas(output, unique, palettes, rows, frames, 1024, TABLE_WIDTH)
    (output / "motions.json").write_text(json.dumps({
        "variants": actors, "actions": actions, "pages": pages, "table_width": TABLE_WIDTH,
        "clip_count": len(rows), "timelines": timelines, "sounds": sounds,
    }, separators=(",", ":")) + "\n")
    if not any((zombie, captain, grave, ruby, undersea, frontier, falken, cursed, beast, shalena)):
        recover_bear_icon(cg)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--zombie", action="store_true")
    mode.add_argument("--captain", action="store_true")
    mode.add_argument("--grave", action="store_true")
    mode.add_argument("--ruby", action="store_true")
    mode.add_argument("--undersea", action="store_true")
    mode.add_argument("--frontier", action="store_true")
    mode.add_argument("--falken", action="store_true")
    mode.add_argument("--cursed", action="store_true")
    mode.add_argument("--beast", action="store_true")
    mode.add_argument("--shalena", action="store_true")
    args = parser.parse_args()
    recover(args.source, args.zombie, args.captain, args.grave, args.ruby, args.undersea, args.frontier, args.falken, args.cursed, args.beast, args.shalena)
