"""Recover native boomerang flight and matching unarmed throw poses, read-only."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys

from PIL import Image

from prepare_crossgate_kazi_attack import packed_frame
from recover_crossgate_kazi import ROOT, pack_frames

ART = ROOT / 'assets/characters/crossgate'
OUT = ART / 'weapons/boomerang'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Original Boomerang/Implementation'
FAMILIES = {34:'kazi',35:'ruby',36:'maze',37:'shin',38:'shin',39:'fighters/saizo',
            40:'fighters/bog',42:'fighters/emilia',43:'fighters/lancelot',44:'fighters/pete',
            45:'fighters/grace',46:'fighters/rei',47:'fighters/cedi',48:'fighters/bei',
            49:'fighters/moe',50:'fighters/ami',51:'fighters/kumago',52:'fighters/bau',
            53:'fighters/el',54:'fighters/gen',55:'fighters/sarah'}
ACTIONS = (0, 1, 3, 6, 7, 8, 9, 10)


def appearance_path(character, skin):
    folder = ART / FAMILIES[character]
    if character == 34:
        folder /= '' if skin == '102488' else 'skins/' + skin
    elif character != 36 and not (character == 35 and skin == '0'):
        folder /= skin
    return folder / 'motions.json'


def atlas_paths(folder, data):
    if 'art_pages' in data:
        return data['art_pages']
    names = [f'atlas-{i}.png' for i in range(data['pages'])]
    if data.get('has_cast_atlas'):
        names += [f'cast-{i}.png' for i in range(data.get('cast_pages', 1))]
    return ['res://' + str((folder / name).relative_to(ROOT)) for name in names]


def texture(path, image, check):
    if check:
        with Image.open(path) as saved:
            assert saved.size == image.size, path
            assert saved.convert('RGBA').tobytes() == image.tobytes(), path
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path)
        settings = path.with_suffix('.png.import')
        if not settings.exists():
            settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n'
                                '[deps]\nsource_file="res://' + str(path.relative_to(ROOT)) +
                                '"\n[params]\ncompress/mode=0\nprocess/fix_alpha_border=false\n'
                                'mipmaps/generate=false\n')


def prepare(source, check=False, catalog=None):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_library as library
    import cg_sounds
    from prepare_shin_water_dragon import blue_theme

    publish = catalog is None
    if publish:
        catalog = json.loads((ART / 'weapons/catalog.json').read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    REPORT.mkdir(parents=True, exist_ok=True)
    icon = library.image_from_record('original', 13973)
    texture(ROOT / 'assets/ui/crossgate/weapons/defaults/boomerang.png', icon, check)
    flight = Image.new('RGBA', (48 * 8, 48))
    source_records = []
    for index, serial in enumerate(range(22082, 22090)):
        row, = cg.palette_graphics('original')[serial]
        image = library.image_from_record('original', row)
        texture(OUT / f'source-{serial}.png', image, check)
        _, _, record = library.row_data('original', row)
        # The original frame also paints a ground shadow; keep it out of the airborne sprite.
        blade = image.crop((0, 0, image.width, -25 - record[4]))
        flight.alpha_composite(blade, (index * 48 + 24 + record[3], 24 + record[4] + 48))
        source_records.append(dict(serial=serial, row=row, origin=list(record[3:5]),
                                   rgba_sha256=hashlib.sha256(image.tobytes()).hexdigest()))
    texture(OUT / 'projectile.png', flight, check)

    prepared = set()
    supported, excluded = [], []
    comparisons = 0
    for character, skins in catalog.items():
        for skin, routes in skins.items():
            data = json.loads(appearance_path(int(character), skin).read_text())
            water = character == '37' and skin == '900050'
            unarmed = routes.get('unarmed')
            source_folder = appearance_path(int(character), skin).parent
            motion = data
            source_pages = atlas_paths(source_folder, data)
            if water:
                key = 'original:2425'
            elif unarmed is None:
                excluded.append([character, skin, 'No matching native unarmed stance'])
                continue
            elif 'root' in unarmed:
                source_folder = ROOT / unarmed['root'].removeprefix('res://')
                motion = json.loads((source_folder / 'motions.json').read_text())
                source_pages = atlas_paths(source_folder, motion)
                key = motion['key']
            elif int(character) in (36, 39):
                key = data['dagger_key']
                motion = dict(data, clips={k.removeprefix('dagger:'):v for k,v in data['clips'].items() if k.startswith('dagger:')})
            else:
                motion = ([data] + data.get('weapons', []))[unarmed['native']]
                key = motion['key']
            originals = {(c['action'], c['direction']):c for c in cg.actor(key)[2] if c['frames']}
            if not all((action, direction) in originals for action in ACTIONS for direction in range(8)):
                excluded.append([character, skin, 'Native throw/movement set incomplete'])
                continue
            name = 'water-shin-original' if water else key.replace(':', '-')
            folder = OUT / name
            routes['boomerang'] = {'root':'res://' + str(folder.relative_to(ROOT)) + '/'}
            if water:
                routes['water-dragon-boomerang'] = {
                    'root':'res://assets/characters/crossgate/shin/900050/boomerang/',
                    'base_weapon':'boomerang', 'projectile':'water_dragon_boomerang'}
            supported.append([character, skin, key])
            if name in prepared:
                continue
            prepared.add(name)
            saved = json.loads((folder / 'motions.json').read_text()) if check else None
            pages = [Image.open(ROOT / path.removeprefix('res://')).convert('RGBA') for path in saved['art_pages']] if check else []
            unique, clips, baked_poses = {}, {}, set()
            for (action, direction), original in originals.items():
                if action not in ACTIONS:
                    continue
                pose = f'{5 if action == 7 else action}:{direction}'
                if not water and action != 7 and f'{action}:{direction}' in motion['clips']:
                    # Reuse approved movement pixels/anchors instead of exporting another copy.
                    reused = deepcopy(motion['clips'][f'{action}:{direction}'])
                    # Maze's older atlas borrows its timing from the existing Kazi driver.
                    if 'duration' not in reused:
                        driver = json.loads((ART / 'kazi/motions.json').read_text())
                        reused['duration'] = driver['clips'].get(f'{action}:{direction}', {}).get('duration', original['duration']/1000)
                    if check:
                        actual = deepcopy(saved['clips'][pose])
                        for frame in actual['frames']:
                            frame[0] -= saved['throw_pages']
                        assert actual == reused, (key, pose, 'Prepared movement changed')
                    clips[pose] = reused
                    continue
                baked_poses.add(pose)
                clip = dict(duration=original['duration']/1000, source_clip=original['index'],
                            source_action=action, source_frames=[list(frame) for frame in original['frames']], frames=[])
                if action == 7:
                    markers = [i for i, frame in enumerate(original['frames']) if 10000 <= frame[-1] < 20000]
                    assert len(markers) == 1, (key, direction, markers)
                    release = markers[0] * clip['duration'] / len(original['frames'])
                    clip.update(contact=markers[0]/len(original['frames']), swing=markers[0]/len(original['frames']),
                                contacts=[release], contact_cues=[original['frames'][markers[0]][-1] % 10000],
                                release=release, draw=release, sounds=[c for c in cg_sounds.clip_cues(original) if c['flag'] < 10000])
                for index in range(len(original['frames'])):
                    image, x, y = cg.frame_parts(key, original['index'], index)
                    if water:
                        image = blue_theme(image)
                    if check:
                        frame = saved['clips'][pose]['frames'][index]
                        page, left, top, width, height, ox, oy = frame
                        box = image.getbbox()
                        assert pages[page].crop((left, top, left+width, top+height)).tobytes() == image.crop(box).tobytes(), (key, pose, index)
                        assert [ox, oy] == [x+box[0], y+box[1]], (key, pose, index)
                        comparisons += 1
                    else:
                        clip['frames'].append(packed_frame(image, x, y, unique))
                if check:
                    actual = saved['clips'][pose]
                    assert all(actual[k] == v for k, v in clip.items() if k != 'frames'), (key, pose)
                clips[pose] = clip
            if not check:
                folder.mkdir(parents=True, exist_ok=True)
                count = pack_frames({pose:clip for pose,clip in clips.items() if pose in baked_poses}, unique, folder)
                art_pages = ['res://' + str((folder / f'atlas-{i}.png').relative_to(ROOT)) for i in range(count)]
                if not water:
                    for pose, clip in clips.items():
                        if pose not in baked_poses:
                            for frame in clip['frames']:
                                frame[0] += count
                    art_pages += source_pages
                assert all(0 <= frame[0] < len(art_pages) for clip in clips.values() for frame in clip['frames']), name
                manifest = dict(key=key, source_id=cg.actor(key)[0], weapon='boomerang', pages=len(art_pages),
                                throw_pages=count, art_pages=art_pages, clips=clips)
                (folder / 'motions.json').write_text(json.dumps(manifest, separators=(',', ':')) + '\n')
                for path in folder.glob('atlas-*.png'):
                    with Image.open(path) as image:
                        texture(path, image.convert('RGBA'), False)
            print(f'BOOMERANG {"CHECK" if check else "PREPARE"} {name}', flush=True)
    report = dict(icon=dict(pack='original',row=13973,serial=21201,name='木製大型回力鏢',level='1A'),
                  flight=source_records, supported=supported, excluded=excluded,
                  source_sets=len(prepared), frame_comparisons=comparisons)
    if not check:
        (OUT / 'provenance.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    (REPORT / ('source-check.json' if check else 'coverage.json')).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    if publish:
        path = ART / 'weapons/catalog.json'
        if check:
            assert json.loads(path.read_text()) == catalog
        else:
            path.write_text(json.dumps(catalog, indent=2) + '\n')
    print(f'BOOMERANG_RESULT skins={len(supported)} excluded={len(excluded)} source_sets={len(prepared)} exact_frames={comparisons}', flush=True)
    return catalog


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    prepare(args.source.resolve(), args.check)
