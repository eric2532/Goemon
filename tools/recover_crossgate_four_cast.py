"""Recover Bau, El, Gen and Sarah's reviewed source poses, weapons and cues."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

from PIL import Image

from recover_crossgate_kazi import ROOT, pack_frames
from prepare_crossgate_kazi_attack import packed_frame

ART = ROOT / 'assets/characters/crossgate'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Bau El Gen Sarah'
INVENTORY = Path(__file__).with_name('crossgate_bau_el_gen_sarah.json')
ACTIONS = (0, 1, 3, 5, 6, 8, 9, 10)


def prepare(source, check=False):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_sounds

    inventory = json.loads(INVENTORY.read_text())
    rows = inventory['skins']
    catalogs, routes, receipt = {}, {}, []
    files = {}
    for path in sorted((ROOT / 'assets/audio/crossgate').rglob('*.wav')):
        files.setdefault(path.name.lower(), []).append(path)
    comparisons = 0
    for row in rows:
        folder = ART / 'fighters' / row['name'] / str(row['skin'])
        path = folder / 'motions.json'
        saved = json.loads(path.read_text()) if check else None
        atlases = [Image.open(folder / f'atlas-{i}.png').convert('RGBA')
                   for i in range(saved['pages'])] if check else []
        unique, stances, audio = {}, [], {}
        weapons = row['weapons']
        ordered = sorted(weapons, key=lambda w: (w != 'unarmed', list(weapons).index(w)))
        for stance_index, weapon in enumerate(ordered):
            key = weapons[weapon]
            ident, _, originals = cg.actor(key)
            poses = {(c['action'], c['direction']): c for c in originals if c['frames']}
            clips = {}
            for action in ACTIONS:
                for direction in range(8):
                    original = poses[action, direction]
                    pose = f'{action}:{direction}'
                    cues = cg_sounds.clip_cues(original)
                    for cue in cues:
                        filename = Path(cue['file']).name
                        raw = (cg.SOURCE / 'se' / filename).read_bytes()
                        target = next((p for p in files.get(filename.lower(), [])
                                       if p.read_bytes() == raw), None)
                        if target is None:
                            target = ROOT / 'assets/audio/crossgate/selected_cast' / filename
                            assert not check, ('Missing source sample', target)
                            target.parent.mkdir(parents=True, exist_ok=True)
                            target.write_bytes(raw)
                            files.setdefault(filename.lower(), []).append(target)
                        audio[str(cue['id'])] = 'res://' + str(target.relative_to(ROOT))
                    motion = dict(duration=original['duration'] / 1000,
                                  source_clip=original['index'],
                                  source_frames=[list(f) for f in original['frames']],
                                  sounds=cues)
                    if action == 5:
                        hits = [i for i, f in enumerate(original['frames']) if 10000 <= f[3] < 20000]
                        assert hits, (key, direction, 'Missing native contact')
                        swings = [c for c in cues if c['flag'] < 10000 or c['flag'] >= 20000]
                        motion.update(contacts=[i * motion['duration'] / len(original['frames']) for i in hits],
                                      contact_cues=[original['frames'][i][3] % 10000 for i in hits],
                                      contact=hits[0] / len(original['frames']),
                                      swing=(swings[0]['frame'] if swings else max(0, hits[0]-1)) / len(original['frames']),
                                      sounds=swings)
                        if weapon == 'bow':
                            motion.update(release=motion['contacts'][0],
                                          draw=swings[0]['atMs'] / 1000 if swings else 0.0)
                    elif action == 6:
                        markers = [i for i, f in enumerate(original['frames']) if 10000 <= f[3] < 20000]
                        if len(markers) == 1:
                            motion['release'] = markers[0] * motion['duration'] / len(original['frames'])
                    if check:
                        actual = ([saved] + saved.get('weapons', []))[stance_index]['clips'][pose]
                        assert {k: actual[k] for k in motion} == motion, (key, pose, 'Source clocks/cues changed')
                    frames = []
                    for index in range(len(original['frames'])):
                        image, x, y = cg.frame_parts(key, original['index'], index)
                        if check:
                            page, left, top, w, h, ox, oy = actual['frames'][index]
                            bounds = image.getbbox()
                            assert atlases[page].crop((left, top, left+w, top+h)).tobytes() == image.crop(bounds).tobytes(), (key, pose, index)
                            assert (ox, oy) == (x+bounds[0], y+bounds[1]), (key, pose, index)
                            comparisons += 1
                        else:
                            frames.append(packed_frame(image, x, y, unique))
                    if not check:
                        assert all(frames), (key, pose, 'Empty source artwork')
                        motion['frames'] = frames
                    clips[pose] = motion
            stances.append(dict(weapon=weapon, key=key, source_id=ident, clips=clips))
        key = weapons[ordered[0]]
        stand = next(c for c in cg.actor(key)[2] if c['action'] == 0 and c['direction'] == 4)
        portrait, x, y = cg.frame_parts(key, stand['index'], 0)
        bounds = portrait.getbbox()
        origin = [x+bounds[0], y+bounds[1]]
        # Auras and companions do not define the character's body scale.
        body_pixels = 66 if row['skin'] in (111676, 120447) else bounds[3]-bounds[1]-7
        if not check:
            folder.mkdir(parents=True, exist_ok=True)
            all_clips = {f'{s["weapon"]}:{pose}': motion for s in stances for pose, motion in s['clips'].items()}
            pages = pack_frames(all_clips, unique, folder)
            data = dict(stances[0], id=row['skin'], pages=pages, source_weapons=weapons,
                        portrait_origin=origin, body_pixels=body_pixels, audio=audio)
            if len(stances) > 1:
                data['weapons'] = stances[1:]
            path.write_text(json.dumps(data, separators=(',', ':'))+'\n')
            portrait.crop(bounds).save(folder / 'portrait.png')
            for image in folder.glob('*.png'):
                image.with_suffix('.png.import').write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="res://'+str(image.relative_to(ROOT))+'"\n[params]\ncompress/mode=0\nprocess/fix_alpha_border=true\nmipmaps/generate=false\n')
        else:
            assert saved['source_weapons'] == weapons and saved['audio'] == audio
            for image in atlases:
                image.close()
        catalogs.setdefault(row['name'], []).append((row['skin'], row['label'], origin, body_pixels))
        routes.setdefault(str(row['character']), {})[str(row['skin'])] = {w: {'native': i} for i, w in enumerate(ordered)}
        receipt.append(dict(row, manifest=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        print(f'{"CHECK" if check else "PREPARE"} {row["name"]} {row["skin"]}: {len(stances)} native weapon sets', flush=True)
    definitions = ['extends RefCounted', '## Generated by recover_crossgate_four_cast.py; preserve source keys and saved skin IDs.',
                   'const BAU_HIDDEN=' + str(inventory['hidden_bau_skins'])]
    for name in ('bau', 'el', 'gen', 'sarah'):
        entries = catalogs[name]
        defaults = {'bau': 105000, 'el': 105400, 'gen': 105100, 'sarah': 106250}
        entries.sort(key=lambda entry: (entry[0] != defaults[name], entry[0]))
        definitions.append('const '+name.upper()+'={\n'+''.join(f'\t{skin}:[{json.dumps(label)},Vector2({origin[0]},{origin[1]}),{height}],\n' for skin, label, origin, height in entries)+'}')
    code = '\n\n'.join(definitions)+'\n'
    metadata = ROOT / 'scripts/crossgate_four_cast_skins.gd'
    if check:
        assert metadata.read_text() == code
    else:
        metadata.write_text(code)
        catalog_path = ART / 'weapons/catalog.json'
        published = json.loads(catalog_path.read_text())
        published.update(routes)
        catalog_path.write_text(json.dumps(published, indent=2)+'\n')
    head_catalog = ROOT / 'build/Other Files/Asset Toolkit/Model HUD Heads/Gameplay/catalog.json'
    crop_path = ROOT / 'assets/ui/portraits/crossgate/model-head-crops.json'
    entries = json.loads(head_catalog.read_text())
    crops = json.loads(crop_path.read_text())
    added = []
    for row in rows:
        folder = ART / 'fighters' / row['name'] / str(row['skin'])
        manifest = json.loads((folder / 'motions.json').read_text())
        key = f'{row["character"]}:{row["skin"]}'
        if check:
            assert crops[key] == row['head_crop'], key
        else:
            crops[key] = row['head_crop']
        added.append(dict(character=row['character'], skin=row['skin'], name=row['name'].capitalize(),
                          label=row['label'], body_pixels=manifest['body_pixels'],
                          source='res://' + str((folder / 'portrait.png').relative_to(ROOT))))
    if check:
        assert [e for e in entries if e['character'] in (52,53,54,55)] == added
    else:
        entries = [e for e in entries if e['character'] not in (52,53,54,55)] + added
        head_catalog.write_text(json.dumps(entries, indent=2)+'\n')
        crop_path.write_text(json.dumps(crops, indent=2)+'\n')
    REPORT.mkdir(parents=True, exist_ok=True)
    (REPORT / ('verification.json' if check else 'recovery.json')).write_text(json.dumps(dict(skins=len(rows), source_sets=sum(len(r['weapons']) for r in rows), exact_frames=comparisons, records=receipt), indent=2)+'\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    prepare(args.source.resolve(), args.check)
