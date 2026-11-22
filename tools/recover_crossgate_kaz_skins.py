"""Prepare recovered Kaz costumes and Maze's sword, fist and throwing art."""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

from recover_crossgate_kazi import OUT as KAZ, pack_frames
from prepare_crossgate_kazi_attack import packed_frame

SKINS = {109890: 'puk3:833', 109891: 'puk3:834', 109146: 'puk2:893'}
SKINS.update({
    100028: 'original:2402', 100034: 'original:2408',
    100040: 'original:2414', 100046: 'original:2420', 100049: 'v3:517',
    100891: 'joy:938', 100918: 'joy:785', 100969: 'v3:519',
    105564: 'joy-ex:427', 105570: 'joy-ex:433', 105608: 'joy-ex:421',
})
SWORD_CONTACTS = (13, 27)
SWORD_SWINGS = (12, 26)
YELLOW_ATTACK = [(0, i) for i in (0, 1, 2, 3)] + [(5, i) for i in (0, 1, 2)] + [(0, i) for i in (0, 1, 2, 3)]


def prepare_kunai(out, cg, library):
    row, = cg.palette_graphics('v3')[21100]
    source = library.image_from_record('v3', row)
    assert row == 31 and source.size == (36, 44)
    mask = Image.new('L', source.size)
    # Keep the foreground diagonal blade and its ring where the two silhouettes touch.
    ImageDraw.Draw(mask).polygon([
        (0, 8), (13, 13), (15, 18), (17, 22), (21, 26), (25, 30), (29, 31),
        (34, 32), (34, 37), (30, 40), (26, 40), (25, 39), (24, 35), (21, 33), (0, 28),
    ], fill=255)
    single = source.copy()
    single.putalpha(ImageChops.multiply(mask, source.getchannel('A')))
    assert 0 < single.getchannel('A').histogram()[255] < source.getchannel('A').histogram()[255]
    assert all(pixel == original for pixel, original in zip(single.getdata(), source.getdata()) if pixel[3])
    single = single.crop(single.getbbox())
    single.save(out / 'dagger-icon.png')
    prepare_flight(single, out / 'dagger.png')


def prepare_dagger(out):
    source = KAZ.parents[2] / 'ui/crossgate/weapons/defaults/knife.png'
    with Image.open(source) as image:
        prepare_flight(image.convert('RGBA'), out / 'regular-dagger.png')


def prepare_flight(single, destination):
    cell_size = 48
    centered = Image.new('RGBA', (cell_size, cell_size))
    centered.paste(single, ((cell_size - single.width) // 2, (cell_size - single.height) // 2))
    atlas = Image.new('RGBA', (cell_size * 16, cell_size))
    for direction in range(16):
        frame = centered.rotate(225 - direction * 22.5, resample=Image.Resampling.NEAREST)
        left, top, right, bottom = frame.getbbox()
        assert left > 0 and top > 0 and right < cell_size and bottom < cell_size
        atlas.paste(frame, (direction * cell_size, 0))
    atlas.save(destination)



def recover_qi_punch(cg, key, ident, out, first, contact, end):
    source_id, _, poses = cg.actor(key)
    assert source_id == ident
    out.mkdir(parents=True, exist_ok=True)
    clips, unique = {}, {}
    for pose in poses:
        if pose['action'] != 5:
            continue
        assert pose['frames'][contact][3] == 10131
        frames = [packed_frame(*cg.frame_parts(key, pose['index'], i), unique)
                  for i in range(first, end + 1)]
        assert all(frame is not None for frame in frames)
        clips[f"5:{pose['direction']}"] = dict(frames=frames, source_clip=pose['index'])
    assert len(clips) == 8
    pages = pack_frames(clips, unique, out)
    assert pages == 1
    (out / 'motions.json').write_text(json.dumps(dict(key=key, id=ident, pages=pages, clips=clips,
                                                     first_frame=first, contact_frame=contact-first),
                                                separators=(',', ':')) + '\n')


def recover(source, maze_only=False, punch_only=False):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_library

    if not maze_only:
        recover_qi_punch(cg, 'joy:816', 100890, KAZ / 'qi-punch', 0, 7, 14)
        recover_qi_punch(cg, 'joy:841', 105714, KAZ.parent / 'ruby' / 'qi-punch', 13, 20, 28)
    if punch_only:
        return

    timeline = json.loads((KAZ / 'motions.json').read_text())['clips']
    records = {100528: 'joy:599'} if maze_only else {**SKINS, 100528: 'joy:599'}
    for ident, record in records.items():
        assert cg.actor(record)[0] == ident
        source_clips = {(c['action'], c['direction']): c for c in cg.actor(record)[2]}
        out = KAZ.parent / 'maze' if ident == 100528 else KAZ / 'skins' / str(ident)
        out.mkdir(parents=True, exist_ok=True)
        clips, unique = {}, {}
        def add_clip(key, action, direction, count, source_key, poses, attack=None):
            clip = poses[action, direction]
            picks = attack or [(action, i * len(clip['frames']) // count) for i in range(count)]
            assert len(picks) == count
            frames, source_frames = [], []
            for pose, index in picks:
                source_clip = poses[pose, direction]['index']
                art, x, y = cg.frame_parts(source_key, source_clip, index)
                body = packed_frame(art, x, y, unique)
                assert body is not None, (source_key, source_clip, index)
                frames.append(body)
                source_frames.append([source_clip, index])
            clips[key] = dict(frames=frames, source_frames=source_frames)

        for key, original in timeline.items():
            action, direction = map(int, key.split(':'))
            count = len(original['frames'])
            attack = YELLOW_ATTACK if action == 5 and ident == 109146 else None
            if action == 5 and attack is None:
                source_frames = source_clips[action, direction]['frames']
                assert tuple(source_frames[i][3] for i in SWORD_CONTACTS) == (20133, 10134)
                assert all(source_frames[i][3] == 103 for i in SWORD_SWINGS)
                count = len(source_frames)
            add_clip(key, action, direction, count, record, source_clips, attack)
            if action == 5:
                duration = original['duration']
                contacts = (5, 6) if attack else SWORD_CONTACTS
                sounds = original['sounds'] if attack else [
                    {'atMs': duration * 1000 * index / count} for index in SWORD_SWINGS
                ]
                clips[key].update(duration=duration, contacts=[duration * i / count for i in contacts],
                                  sounds=sounds)
        if ident == 100528:
            dagger_key = 'joy:598'
            assert cg.actor(dagger_key)[0] == 100527
            unarmed = {(c['action'], c['direction']): c for c in cg.actor(dagger_key)[2]}
            for key, original in timeline.items():
                action, direction = map(int, key.split(':'))
                if action != 5:
                    add_clip('dagger:' + key, action, direction, len(original['frames']), dagger_key, unarmed)
            for direction in range(8):
                punch = unarmed[5, direction]
                count = len(punch['frames'])
                assert (count, punch['frames'][6][3], punch['frames'][7][3]) == (18, 101, 10131)
                key = f'fist:5:{direction}'
                add_clip(key, 5, direction, count, dagger_key, unarmed)
                duration = punch['duration'] / 1000
                clips[key].update(duration=duration, contacts=[duration * 7 / count],
                                  sounds=[{'atMs': duration * 1000 * 6 / count}])
                clip = unarmed[7, direction]
                assert (clip['duration'], len(clip['frames']), clip['frames'][7][3]) == (800, 9, 10111)
                add_clip(f'7:{direction}', 7, direction, 9, dagger_key, unarmed)
                clips[f'7:{direction}']['duration'] = clip['duration'] / 3000
        pages = pack_frames(clips, unique, out)
        portrait_key, portrait_poses = (dagger_key, unarmed) if ident == 100528 else (record, source_clips)
        portrait, _, _ = cg.frame_parts(portrait_key, portrait_poses[0, 4]['index'], 0)
        portrait.crop(portrait.getbbox()).save(out / 'portrait.png')
        manifest = dict(id=ident, key=record, pages=pages, clips=clips)
        if ident == 100528:
            manifest.update(dagger_key=dagger_key, release_frame=7, release_flag=10111,
                            projectile_serial=21100, projectile_key='v3:31')
            prepare_kunai(out, cg, cg_library)
            prepare_dagger(out)
            original_audio = cg.SOURCE / 'se/cgply05a.wav'
            reused_audio = KAZ.parent.parent.parent / 'audio/crossgate/ruby/cgply05a.wav'
            assert original_audio.read_bytes() == reused_audio.read_bytes()
        (out / 'motions.json').write_text(json.dumps(manifest, separators=(',', ':')) + '\n')
        print(f'{ident}: {len(clips)} clips, {len(unique)} original frames, {pages} pages')


def check(source):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg

    count = 0
    for ident, key in {**SKINS, 100528: 'joy:599'}.items():
        folder = KAZ.parent / 'maze' if ident == 100528 else KAZ / 'skins' / str(ident)
        manifest = json.loads((folder / 'motions.json').read_text())
        assert manifest['id'] == ident and manifest['key'] == key and cg.actor(key)[0] == ident
        if ident != 100528:
            assert set(manifest['clips']) == {f'{action}:{direction}' for action in (0, 1, 3, 5, 6, 8, 10) for direction in range(8)}
        pages = [Image.open(folder / f'atlas-{i}.png').convert('RGBA') for i in range(manifest['pages'])]
        for pose, clip in manifest['clips'].items():
            source_key = manifest['dagger_key'] if pose.startswith(('dagger:', 'fist:', '7:')) else key
            assert len(clip['source_frames']) == len(clip['frames'])
            for saved, (source_clip, index) in zip(clip['frames'], clip['source_frames']):
                im, x, y = cg.frame_parts(source_key, source_clip, index)
                box = im.getbbox()
                page, left, top, width, height, ox, oy = saved
                assert pages[page].crop((left, top, left + width, top + height)).tobytes() == im.crop(box).tobytes(), (ident, pose, index)
                assert (ox, oy) == (x + box[0], y + box[1]), (ident, pose, index)
                count += 1
            if pose.startswith('5:'):
                contacts = (5, 6) if ident == 109146 else SWORD_CONTACTS
                assert clip['duration'] == .6
                assert clip['contacts'] == [.6 * i / len(clip['frames']) for i in contacts]
        for page in pages:
            page.close()
    print(f'KAZ_SKINS_CHECK: {len(SKINS) + 1} appearances, {count} exact frame/origin checks')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Preserved Magic Power project')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--maze-only', action='store_true')
    mode.add_argument('--punch-only', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        check(args.source)
    else:
        recover(args.source, args.maze_only, args.punch_only)
