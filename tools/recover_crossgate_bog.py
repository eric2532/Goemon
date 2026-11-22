"""Pack the two approved Bog axe skins with the existing Cross Gate preparers."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from shutil import copyfile

from recover_crossgate_kazi import OUT as KAZ, pack_frames
from recover_crossgate_shin import ACTIONS, prepare_casts, prepare_stance

OUT = KAZ.parent / 'fighters/bog'
RECORDS = {100625: ('joy:620', 'joy:622'), 100942: ('v3:578', 'v3:429')}


def recover(source):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_sounds
    import cg_library

    for ident, (key, unarmed) in RECORDS.items():
        folder = OUT / str(ident)
        folder.mkdir(parents=True, exist_ok=True)
        unique = {}
        stance, _ = prepare_stance(cg, 'axe', key, ident, unique, ACTIONS + (9,))
        for clip in cg.actor(key)[2]:
            if clip['action'] != 5:
                continue
            motion = stance['clips'][f"5:{clip['direction']}"]
            cues = cg_sounds.clip_cues(clip)
            assert [(cue['frame'], cue['id']) for cue in cues] == [(18, 106), (19, 136), (34, 106), (35, 138)]
            motion['sounds'] = [cue for cue in cues if cue['id'] == 106]
            # The source flag distinguishes sounds from confirmed contact events.
            contacts = [cue for cue in cues if cue['flag'] >= 10000]
            motion['contacts'] = [cue['atMs'] / 1000 for cue in contacts]
            motion['contact_cues'] = [cue['id'] for cue in contacts]
            assert len(motion['frames']) == 50 and motion['duration'] == 1.6
        pages = pack_frames(stance['clips'], unique, folder)
        manifest = dict(stance, id=ident, pages=pages)
        prepare_casts(cg, folder, manifest)
        portrait_clip = next(c for c in cg.actor(unarmed)[2] if c['action'] == 0 and c['direction'] == 4)
        portrait, x, y = cg.frame_parts(unarmed, portrait_clip['index'], 0)
        box = portrait.getbbox()
        portrait.crop(box).save(folder / 'portrait.png')
        assert [x + box[0], y + box[1]] == [-19, -86]
        manifest.update(portrait_key=unarmed, portrait_origin=[-19, -86], body_pixels=94)
        (folder / 'motions.json').write_text(json.dumps(manifest, separators=(',', ':')) + '\n')
        print(f'{ident}: axe, {len(manifest["clips"])} clips, {pages} body pages; original pixels and two contacts', flush=True)
    row, = cg.palette_graphics('original')[20200]
    assert row == 13372
    icon = cg_library.image_from_record('original', row)
    icon.crop(icon.getbbox()).save(KAZ.parents[2] / 'ui/crossgate/weapons/axe.png')
    audio = KAZ.parents[2] / 'audio/crossgate/bog'
    audio.mkdir(parents=True, exist_ok=True)
    provenance = {}
    for filename in ('cgply02b.wav', 'cgply12b.wav'):
        original = cg.SOURCE / 'se' / filename
        copyfile(original, audio / filename)
        provenance[filename] = dict(source=str(original), sha256=hashlib.sha256(original.read_bytes()).hexdigest())
        assert (audio / filename).read_bytes() == original.read_bytes()
    (audio / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    recover(parser.parse_args().source)
