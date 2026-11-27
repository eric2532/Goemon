"""Prepare Beast Master for appearances without a normal dagger or boomerang route."""

import argparse
from copy import deepcopy
from functools import cache
import json
from pathlib import Path
import sys

from PIL import Image

from prepare_crossgate_boomerangs import ART, ROOT, appearance_path, atlas_paths, texture
from prepare_crossgate_kazi_attack import packed_frame
from recover_crossgate_kazi import pack_frames


OUT = ART / 'weapons/beast_master'
FALLBACKS = ROOT / 'tools/crossgate_beast_master_fallbacks.json'
BODY_ACTIONS = (0, 1, 3, 6, 8, 9, 10)


@cache
def kazi_driver_clips():
    return json.loads((ART / 'kazi/motions.json').read_text())['clips']


def missing_variants():
    catalog = json.loads((ART / 'weapons/catalog.json').read_text())
    for character, skins in catalog.items():
        for skin, routes in skins.items():
            if 'kunai' not in routes and 'boomerang' not in routes:
                yield character, skin, routes


def selected_body(character, skin, routes):
    path = appearance_path(int(character), skin)
    unarmed = routes.get('unarmed', {})
    if 'root' in unarmed:
        path = ROOT / unarmed['root'].removeprefix('res://') / 'motions.json'
    data = json.loads(path.read_text())
    motion = ([data] + data.get('weapons', []))[unarmed.get('native', 0)]
    return atlas_paths(path.parent, data), motion


def source_clips(cg, key):
    return {(clip['action'], clip['direction']): clip for clip in cg.actor(key)[2] if clip['frames']}


def packed_clip(cg, key, clip, picks, unique):
    frames = [packed_frame(*cg.frame_parts(key, clip['index'], i), unique) for i in picks]
    assert all(frame is not None for frame in frames), (key, clip['index'])
    return dict(duration=clip['duration'] / 1000, frames=frames, source_action=clip['action'],
                source_clip=clip['index'], source_frames=[list(clip['frames'][i]) for i in picks])


def prepare_profile(cg, cg_sounds, character, skin, routes, fallback, check):
    source_pages, motion = selected_body(character, skin, routes)
    body_key = motion['key']
    body = source_clips(cg, body_key)
    key = fallback.get('source_key', body_key) if fallback else body_key
    source = body if key == body_key else source_clips(cg, key)
    action = fallback['action'] if fallback else 7
    unique, reused, baked = {}, {}, {}
    for direction in range(8):
        for body_action in BODY_ACTIONS:
            pose = f'{body_action}:{direction}'
            if pose in motion['clips']:
                prepared = deepcopy(motion['clips'][pose])
                if 'duration' not in prepared:
                    # Older Kaz skins store only their artwork and use the base driver's clock.
                    assert character == '34', (character, skin, pose)
                    prepared['duration'] = kazi_driver_clips()[pose]['duration']
                reused[pose] = prepared
            else:
                clip = body[body_action, direction]
                baked[pose] = packed_clip(cg, body_key, clip, range(len(clip['frames'])), unique)

        clip = source[action, direction]
        if fallback:
            picks = fallback.get('frame_indices', list(range(len(clip['frames']))))
            if isinstance(picks[0], list):
                picks = picks[direction]
            assert picks and all(0 <= index < len(clip['frames']) for index in picks), (key, direction)
            marker = fallback['release_frames'][direction]
            duration = fallback['duration']
        else:
            picks = range(len(clip['frames']))
            marker, = (i for i, frame in enumerate(clip['frames']) if 10000 <= frame[-1] < 20000)
            duration = clip['duration'] / 1000
        assert 0 < marker < len(picks) and duration > 0, (key, direction, marker)
        release = duration * marker / len(picks)
        throw = packed_clip(cg, key, clip, picks, unique)
        throw.update(duration=duration, release=release, draw=release, contacts=[release],
                     swing=marker / len(picks), contact=marker / len(picks))
        if fallback:
            throw.update(frame_map=list(picks), source_duration=clip['duration'] / 1000,
                         adaptation=fallback['reason'])
        else:
            throw.update(contact_cues=[clip['frames'][marker][-1] % 10000],
                         sounds=[cue for cue in cg_sounds.clip_cues(clip) if cue['flag'] < 10000])
        baked[f'5:{direction}'] = throw

    folder = OUT / f'{character}-{skin}'
    manifest = folder / 'motions.json'
    comparisons = 0
    if check:
        saved = json.loads(manifest.read_text())
        page_count = saved['baked_pages']
        pages = [Image.open(folder / f'atlas-{i}.png').convert('RGBA') for i in range(page_count)]
        for pose, clip in baked.items():
            packed = saved['clips'][pose]['frames']
            assert len(packed) == len(clip['frames']), (key, pose)
            for frame, (digest, ox, oy) in zip(packed, clip['frames']):
                page, left, top, width, height, saved_x, saved_y = frame
                assert [saved_x, saved_y] == [ox, oy], (key, pose, 'source origin')
                assert pages[page].crop((left, top, left + width, top + height)).tobytes() == unique[digest].tobytes(), (key, pose, 'source pixels')
                comparisons += 1
            clip['frames'] = packed
    else:
        folder.mkdir(parents=True, exist_ok=True)
        page_count = pack_frames(baked, unique, folder)
        for path in folder.glob('atlas-*.png'):
            with Image.open(path) as image:
                texture(path, image.convert('RGBA'), False)
    for clip in reused.values():
        for frame in clip['frames']:
            frame[0] += page_count
    pages = ['res://' + str((folder / f'atlas-{i}.png').relative_to(ROOT)) for i in range(page_count)] + source_pages
    result = dict(key=key, source_id=cg.actor(body_key)[0], id=int(skin), weapon='kunai',
                  body_source=body_key, pages=len(pages), baked_pages=page_count,
                  art_pages=pages, clips=reused | baked)
    if check:
        assert result == saved, (character, skin, 'appearance, frames, source clocks and page references')
    else:
        manifest.write_text(json.dumps(result, separators=(',', ':')) + '\n')
    print('BEAST_MASTER', 'CHECK' if check else 'PREPARE', character, skin, key, 'adapted' if fallback else 'source throw', flush=True)
    return comparisons


def prepare(source, check=False):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_sounds

    fallbacks = json.loads(FALLBACKS.read_text())
    used = set()
    count = comparisons = 0
    for character, skin, routes in missing_variants():
        name = f'{character}:{skin}'
        fallback = fallbacks.get(name)
        comparisons += prepare_profile(cg, cg_sounds, character, skin, routes, fallback, check)
        if fallback:
            used.add(name)
        count += 1
    assert used == fallbacks.keys(), ('Unused fallback poses', fallbacks.keys() - used)
    print(f'BEAST_MASTER_RESULT appearances={count} adapted={len(used)} exact_frames={comparisons}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    prepare(args.source.resolve(), args.check)
