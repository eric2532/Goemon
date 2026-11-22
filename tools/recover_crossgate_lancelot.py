"""Prepare all eight original Lancelot bow skins for the shared Cross Gate owner."""
import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path
from shutil import copyfile

from PIL import Image

from prepare_crossgate_kazi_attack import packed_frame
from recover_crossgate_kazi import OUT as KAZ, pack_frames

OUT = KAZ.parent / 'fighters/lancelot'
RECORDS = {106125: 'ex:457', 106131: 'ex:463', 106137: 'ex:469', 106143: 'ex:475',
           106550: 'joy:693', 105206: 'joy-ex:332', 105212: 'joy-ex:338', 105907: 'joy-ex:98'}


def recover(source):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_library
    import cg_sounds

    for skin, key in RECORDS.items():
        ident, _, originals = cg.actor(key)
        assert ident == skin + 1
        folder = OUT / str(skin)
        folder.mkdir(parents=True, exist_ok=True)
        clips, unique = {}, {}
        for original in originals:
            frames = [packed_frame(*cg.frame_parts(key, original['index'], i), unique)
                      for i in range(len(original['frames']))]
            assert frames and all(frames)
            clip = dict(duration=original['duration']/1000, frames=frames,
                        source_clip=original['index'], source_frames=original['frames'],
                        sounds=cg_sounds.clip_cues(original))
            if original['action'] == 5:
                assert [(cue['frame'], cue['id'], cue['flag']) for cue in clip['sounds']] == [(5, 114, 114), (11, 116, 10116)]
                assert len(frames) == 13 and original['duration'] == 986
                clip.update(draw=clip['sounds'][0]['atMs']/1000, release=clip['sounds'][1]['atMs']/1000)
            clips[f"{original['action']}:{original['direction']}"] = clip
        assert len(clips) == 152 and {int(k.split(':')[1]) for k in clips} == set(range(8))
        pages = pack_frames(clips, unique, folder)
        atlases = [Image.open(folder/f'atlas-{i}.png').convert('RGBA') for i in range(pages)]
        for original in originals:
            for i, frame in enumerate(clips[f"{original['action']}:{original['direction']}"]['frames']):
                art, x, y = cg.frame_parts(key, original['index'], i)
                box = art.getbbox(); page, left, top, w, h, ox, oy = frame
                assert atlases[page].crop((left, top, left+w, top+h)).tobytes() == art.crop(box).tobytes()
                assert (ox, oy) == (x+box[0], y+box[1])
        portrait, x, y = cg.frame_parts(key, clips['0:4']['source_clip'], 0)
        box = portrait.getbbox(); portrait.crop(box).save(folder/'portrait.png')
        assert [x+box[0], y+box[1]] == [-55, -79]
        manifest = dict(id=skin, source_id=ident, key=key, weapon='bow', pages=pages,
                        body_pixels=87, portrait_origin=[-55, -79], clips=clips)
        (folder/'motions.json').write_text(json.dumps(manifest, separators=(',', ':'))+'\n')
        print(f'{skin}: {len(clips)} native bow clips; {pages} pages; all pixels, offsets and cues preserved', flush=True)

    row, = cg.palette_graphics('original')[22050]
    assert row == 19119
    arrow = cg_library.image_from_record('original', row)
    arrow = arrow.crop(arrow.getbbox())
    arrow.save(OUT/'arrow-source.png')
    atlas = Image.new('RGBA', (48*16, 48))
    for direction in range(16):
        graphic, = cg.palette_graphics('original')[22050+direction]
        frame = cg_library.image_from_record('original', graphic)
        frame = frame.crop(frame.getbbox())
        assert max(frame.size) <= 48
        point = (direction*48+(48-frame.width)//2, (48-frame.height)//2)
        atlas.paste(frame, point)
        assert atlas.crop((*point, point[0]+frame.width, point[1]+frame.height)).tobytes() == frame.tobytes()
    atlas.save(OUT/'arrow.png')
    bow_row, = cg.palette_graphics('original')[20800]
    icon = cg_library.image_from_record('original', bow_row)
    icon.crop(icon.getbbox()).save(KAZ.parents[2]/'ui/crossgate/weapons/bow.png')
    audio = KAZ.parents[2]/'audio/crossgate/lancelot'
    audio.mkdir(parents=True, exist_ok=True)
    sources = {}
    for cue in (114, 116, 142):
        filename = cg_sounds.sound_table()[str(cue)]['file'].replace('\\', '/').split('/')[-1]
        original = cg.SOURCE/'se'/filename
        copyfile(original, audio/filename)
        assert (audio/filename).read_bytes() == original.read_bytes()
        sources[cue] = dict(file=filename, source=str(original), sha256=hashlib.sha256(original.read_bytes()).hexdigest())
    (audio/'provenance.json').write_text(json.dumps(dict(sounds=sources,
        draw='Original 114 at frame 5', release='Original 10116 marker at frame 11',
        impact='Prepared Cross Gate arrow contact sample 142',
        arrow=dict(pack='original', serials=list(range(22050,22066)), graphic=row)), indent=2)+'\n')
    random_shot_evidence(source)


def random_shot_evidence(source):
    snapshot = source/'research/newclient20261030/combat/bluecg-virtual-memory.bin'
    memory = snapshot.read_bytes()
    digest = hashlib.sha256(memory).hexdigest()
    assert digest == '8babbe4ad20e4e1e2a6992ecf086d47ef3527426879699f83fa2cebb1a476afe'
    base = 0x400000
    u32 = lambda address: struct.unpack_from('<I', memory, address-base)[0]
    assert u32(0x433CD4+memory[0x433D1C-base+95]*4) == 0x42EFD1
    assert memory[0x42F13B-base:0x42F144-base] == bytes.fromhex('83f85f0f84e8010000')
    assert u32(0x415544+149*4) == 0x40D731
    assert u32(0x415544+18*4) == 0x40667C
    assert memory[0x406695-base:0x40669F-base] == bytes.fromhex('c783a402000021000000')
    assert memory[0x406769-base:0x40676E-base] == bytes.fromhex('6822560000')
    charge = source/'godot/assets/humanoid-spells/110100.png'
    assert Image.open(charge).tobytes() == Image.open(KAZ.parent/'qigong/charge.png').tobytes()
    report = dict(skill='亂射', protocol=95, rank=10, arrows=12,
        snapshot=dict(file=str(snapshot), sha256=digest),
        charge=dict(resource=110100, file='res://assets/characters/crossgate/qigong/charge.png',
                    frames=9, frame_seconds=3/60, sound=251),
        arrow_serials=list(range(22050, 22066)), animation_clock_percent=33,
        trace=dict(packet='0x42f13b -> 0x42f32c: queue physical charge state 149',
                   attack='state 18 at 0x40667c; protocol 95 sets clock 33 at 0x406695',
                   projectile='0x406769 pushes first arrow graphic 22050'),
        reference='https://guide.bluecg.net/blue-cg/452292',
        local_rules=dict(cooldown_seconds=5, damage_per_arrow=250,
                         aim='Random local visible, unobstructed target at each draw; update aim at release.'),
        limits=['Real-time port uses existing Goemon damage, collision, range and cooldown contracts.',
                'Server accuracy, repeated-target damage reduction and R11/EX packet behavior are not reproduced.'])
    (OUT/'random-shot.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print('Random Shot: pinned client dispatch, 33% clock, native arrow graphics and shared shine verified.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    recover(parser.parse_args().source)
