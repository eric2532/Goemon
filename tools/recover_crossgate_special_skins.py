"""Prepare reviewed pet-derived character skins without inventing weapon siblings."""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image

from recover_crossgate_kazi import ROOT, pack_frames
from recover_crossgate_shin import prepare_stance

ART = ROOT / 'assets/characters/crossgate'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Character Pet Variants'
ACTIONS = (0, 1, 3, 5, 6, 8, 9, 10)
WEAPONS = ('axe', 'bow', 'unarmed', 'sword', 'staff', 'polearm')
# These are reviewed artwork identities, not automatic head/silhouette matches.
SKINS = [
    (47, 'fighters/cedi', 111617, 'Blond / Violet', 68, {'polearm': 'puk2:1100'}),
    (47, 'fighters/cedi', 111618, '紫夜', 68, {'polearm': 'puk2:1101'}),
    (47, 'fighters/cedi', 111683, 'Silver / White', 68, {'polearm': 'puk2:1166'}),
    (42, 'fighters/emilia', 106706, 'Pink Ayame', 80, {'staff': 'original:3279'}),
    (42, 'fighters/emilia', 120389, 'Red / Black Ayame', 80, {'sword': 'update-ex:2000'}),
    (46, 'fighters/rei', 109912, 'Red / Gold Runes', 80, {'staff': 'puk3:855'}),
    (46, 'fighters/rei', 100700, 'Black / Gold Armor', 80, dict(zip(WEAPONS, [f'joy:{i}' for i in range(638, 644)]))),
    (46, 'fighters/rei', 100798, 'Ornate / Silver Weapons', 80, {'axe': 'joy-ex:819', 'bow': 'joy-ex:820', 'unarmed': 'joy-ex:821', 'sword': 'joy-ex:822', 'staff': 'joy-ex:823', 'polearm': 'joy-ex:919'}),
    (46, 'fighters/rei', 120428, 'Ornate / Red Weapons', 80, {'axe': 'ch1:663', 'bow': 'ch1:664', 'sword': 'ch1:665', 'staff': 'ch1:666', 'polearm': 'ch1:667'}),
    (37, 'shin', 100462, 'Black Hair / Red', 87, {'sword': 'ex:1538'}),
    (37, 'shin', 108151, 'Black Hair / Charcoal', 87, {'sword': 'joy-ex:219'}),
    (35, 'ruby', 108921, 'Black Hair / Yellow', 81, dict(zip(WEAPONS, [f'puk2:{i}' for i in range(852, 858)]))),
    (35, 'ruby', 109897, 'Gold', 81, dict(zip(WEAPONS, [f'puk3:{i}' for i in range(840, 846)]))),
    (35, 'ruby', 109903, 'Gold Rune Circle', 81, dict(zip(WEAPONS, [f'puk3:{i}' for i in range(846, 852)]))),
    (35, 'ruby', 109909, 'Gold Flame', 81, {'staff': 'puk3:852'}),
]
URU_SKINS = [(35, 'ruby', row['skin'], row['label'], row['body_pixels'], row['weapons'])
             for row in json.loads((ROOT / 'tools/crossgate_uru_skins.json').read_text())['skins']]
URU_IDS = {row[2] for row in URU_SKINS}
CAST_SKINS = [(row['character'], row['root'], row['skin'], row['label'], row['body_pixels'], row['weapons'])
              for filename in ('crossgate_bei_moe_ami.json', 'crossgate_shin_2_skins.json', 'crossgate_kumago.json')
              for row in json.loads((ROOT / 'tools' / filename).read_text())['skins']]
CAST_IDS = {row[0] for row in CAST_SKINS}


def prepare(source, check=False, cast_only=False, only_character=None):
    assert only_character is None or cast_only, '--character requires --cast-only'
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_sounds

    heads_path = ROOT / 'assets/ui/portraits/crossgate/skins.json'
    heads = json.loads(heads_path.read_text())
    weapons_path = ART / 'weapons/catalog.json'
    weapon_catalog = json.loads(weapons_path.read_text())
    existing_audio = {}
    for path in (ROOT / 'assets/audio/crossgate').rglob('*.wav'):
        existing_audio.setdefault(path.name.lower(), []).append(path)
    catalogs, uru_catalog, cast_catalogs, report = {}, [], {}, []
    frames_checked = 0
    selected = CAST_SKINS if cast_only else SKINS + URU_SKINS + CAST_SKINS
    for character, root, skin, label, height, weapons in selected:
        if only_character is not None and character != only_character:
            manifest = json.loads((ART / root / str(skin) / 'motions.json').read_text())
            cast_catalogs.setdefault(character, []).append((skin, label, root, manifest['portrait_origin'], height))
            continue
        if character == 35 and len(weapons) > 1:
            weapons = {'staff': weapons['staff'], **{w: k for w, k in weapons.items() if w != 'staff'}}
        folder = ART / root / str(skin)
        if not check:
            folder.mkdir(parents=True, exist_ok=True)
        unique, stances, audio = {}, [], {}
        for weapon, key in weapons.items():
            ident, _, original = cg.actor(key)
            if check:
                manifest = json.loads((folder / 'motions.json').read_text())
                stance = next(s for s in [manifest] + manifest.get('weapons', []) if s['key'] == key)
                pages = [Image.open(folder / f'atlas-{i}.png').convert('RGBA') for i in range(manifest['pages'])]
            else:
                stance, portrait_clip = prepare_stance(cg, weapon, key, ident, unique, ACTIONS)
            for clip in original:
                if clip['action'] not in ACTIONS or not clip['frames']:
                    continue
                motion = stance['clips'][f'{clip["action"]}:{clip["direction"]}']
                cues = cg_sounds.clip_cues(clip)
                # 20000-series flags are audio-only; 10000 is a valid silent contact.
                hits = [(i, f[3] % 10000) for i, f in enumerate(clip['frames']) if 10000 <= f[3] < 20000]
                swings = [c for c in cues if c['flag'] < 10000 or c['flag'] >= 20000]
                expected = dict(duration=clip['duration'] / 1000, source_frames=[list(f) for f in clip['frames']])
                if clip['action'] == 5:
                    assert hits, (key, clip['direction'])
                    expected.update(contacts=[i * clip['duration'] / len(clip['frames']) / 1000 for i, _ in hits],
                                    contact_cues=[sound for _, sound in hits],
                                    sounds=cues if character == 35 and weapon == 'staff' else swings,
                                    contact=hits[0][0] / len(clip['frames']),
                                    swing=(swings[0]['frame'] if swings else max(0, hits[0][0] - 1)) / len(clip['frames']))
                    if weapon == 'bow':
                        expected.update(draw=swings[0]['atMs'] / 1000 if swings else 0.0,
                                        release=expected['contacts'][0])
                    for cue in cues:
                        name = Path(cue['file']).name
                        raw = (cg.SOURCE / 'se' / name).read_bytes()
                        path = next((p for p in existing_audio.get(name.lower(), []) if p.read_bytes() == raw), None)
                        if path is None:
                            path = ROOT / 'assets/audio/crossgate/special_skins' / name
                            if not check:
                                path.parent.mkdir(parents=True, exist_ok=True)
                                path.write_bytes(raw)
                        assert path.read_bytes() == raw
                        audio[str(cue['id'])] = 'res://' + str(path.relative_to(ROOT))
                if check:
                    for field, value in expected.items():
                        assert motion[field] == value, (key, field)
                    assert len(motion['frames']) == len(clip['frames'])
                    for index, frame in enumerate(motion['frames']):
                        im, x, y = cg.frame_parts(key, clip['index'], index)
                        box = im.getbbox()
                        page, left, top, width, high, ox, oy = frame
                        assert pages[page].crop((left, top, left + width, top + high)).tobytes() == im.crop(box).tobytes(), (key, clip['index'], index)
                        assert (ox, oy) == (x + box[0], y + box[1])
                        frames_checked += 1
                else:
                    motion.update(expected)
            if check:
                for page in pages:
                    page.close()
            stances.append(stance)
        key = next(iter(weapons.values()))
        poses = {(c['action'], c['direction']): c for c in cg.actor(key)[2] if c['frames']}
        im, x, y = cg.frame_parts(key, poses[0, 4]['index'], 0)
        box = im.getbbox()
        origin = (x + box[0], y + box[1])
        portrait = im.crop(box)
        if not check:
            clips = {f'{s["weapon"]}:{pose}': motion for s in stances for pose, motion in s['clips'].items()}
            pages = pack_frames(clips, unique, folder)
            manifest = dict(stances[0], id=skin, pages=pages, source_weapons=weapons,
                            portrait_origin=origin, body_pixels=height, audio=audio)
            if len(stances) > 1:
                manifest['weapons'] = stances[1:]
            (folder / 'motions.json').write_text(json.dumps(manifest, separators=(',', ':')) + '\n')
            portrait.save(folder / 'portrait.png')
            # Crop the body core for HUD heads; rings and weapons stay in the full portrait.
            head = im.crop((-18 - x, -height - y, 19 - x, -height + 34 - y))
            head = head.crop(head.getbbox())
            head.thumbnail((236, 236), Image.Resampling.NEAREST)
            head = head.resize((head.width * 6, head.height * 6), Image.Resampling.NEAREST)
            canvas = Image.new('RGBA', (256, 256))
            canvas.paste(head, ((256 - head.width) // 2, (256 - head.height) // 2))
            prefix = 'uru' if character == 35 and skin in URU_IDS else 'special'
            head_path = ROOT / f'assets/ui/portraits/crossgate/recovered/{prefix}-{skin}.png'
            canvas.save(head_path)
            heads[f'{character}:{skin}'] = f'recovered/{prefix}-{skin}.png'
        label = label if character in CAST_IDS or (character == 35 and skin in URU_IDS) else 'Special · ' + label
        if character in CAST_IDS:
            cast_catalogs.setdefault(character, []).append((skin, label, root, origin, height))
        elif character == 35 and skin in URU_IDS:
            uru_catalog.append((skin, label, root, origin, height))
        else:
            catalogs.setdefault(character, []).append((skin, label, root, origin, height))
        routes = {s['weapon']: {'native': i} for i, s in enumerate(stances)}
        if check:
            assert weapon_catalog[str(character)][str(skin)] == routes
        else:
            weapon_catalog.setdefault(str(character), {})[str(skin)] = routes
        report.append(dict(character=character, skin=skin, label=label, weapons=weapons))
        print(f'{"CHECK" if check else "PREPARE"} {character}:{skin} {list(weapons)}', flush=True)
    assert sum(map(len, catalogs.values())) == (0 if cast_only else len(SKINS))
    assert len(uru_catalog) == (0 if cast_only else len(URU_SKINS))
    assert sum(map(len, cast_catalogs.values())) == len(CAST_SKINS)
    lines = ['extends RefCounted', '## Generated by recover_crossgate_special_skins.py; exact source weapons only.', 'const CATALOG={']
    for character, skins in catalogs.items():
        lines.append(f'\t{character}:{{')
        for skin, label, root, origin, height in skins:
            lines.append(f'\t\t{skin}:[{json.dumps(label, ensure_ascii=False)},Vector2({origin[0]},{origin[1]}),{height}],')
        lines.append('\t},')
    lines.append('}')
    lines.append('const CAST_CATALOG={')
    for character, skins in cast_catalogs.items():
        lines.append(f'\t{character}:{{')
        for skin, label, root, origin, height in skins:
            lines.append(f'\t\t{skin}:[{json.dumps(label, ensure_ascii=False)},Vector2({origin[0]},{origin[1]}),{height}],')
        lines.append('\t},')
    lines.append('}')
    lines.append('const URU_CATALOG={')
    for skin, label, root, origin, height in uru_catalog:
        lines.append(f'\t{skin}:[{json.dumps(label, ensure_ascii=False)},Vector2({origin[0]},{origin[1]}),{height}],')
    lines.append('}')
    metadata = '\n'.join(lines) + '\n'
    metadata_path = ROOT / 'scripts/crossgate_special_skins.gd'
    if cast_only:
        previous = metadata_path.read_text()
        start = previous.find('const CAST_CATALOG={')
        end = previous.index('const URU_CATALOG={')
        metadata = (previous[:start if start >= 0 else end]
                    + metadata[metadata.index('const CAST_CATALOG={'):metadata.index('const URU_CATALOG={')]
                    + previous[end:])
    if check:
        assert metadata_path.read_text() == metadata
    else:
        metadata_path.write_text(metadata)
        heads_path.write_text(json.dumps(heads, ensure_ascii=False, indent=2) + '\n')
        weapons_path.write_text(json.dumps(weapon_catalog, indent=2) + '\n')
        for _, root, skin, *_ in selected:
            for path in (ART / root / str(skin)).glob('*.png'):
                settings = path.with_suffix('.png.import')
                if not settings.exists():
                    settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="res://' + str(path.relative_to(ROOT)) + '"\n[params]\ncompress/mode=0\nprocess/fix_alpha_border=true\nmipmaps/generate=false\n')
    report_folder = ROOT / 'build/Other Files/Asset Toolkit/Kumago' if only_character == 51 else ROOT / 'build/Other Files/Asset Toolkit/Bei Moe Ami' if cast_only else REPORT
    report_folder.mkdir(parents=True, exist_ok=True)
    (report_folder / ('preservation.json' if check else 'recovery.json')).write_text(json.dumps(dict(skins=report, frames_checked=frames_checked), ensure_ascii=False, indent=2) + '\n')
    print('EXACT_FRAME_ORIGIN_CHECKS', frames_checked, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--cast-only', action='store_true', help='Prepare/check the reviewed cast inventories without rewriting earlier character assets')
    parser.add_argument('--character', type=int, choices=sorted(CAST_IDS), help='Prepare/check only this cast identity, retaining other prepared artwork')
    args = parser.parse_args()
    prepare(args.source.resolve(), args.check, args.cast_only, args.character)
