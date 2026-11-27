"""The appended original cow preserves prior kits and the complete source motion."""
import json
import hashlib
from pathlib import Path
import struct
import sys
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
import cg_assets as cg
import cg_sounds
from recover_habaru_encounter import body_rows

BANK = ROOT / 'assets/characters/crossgate/east_region'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Explore Access/Laboratory native'
BASE = REPORT / 'Previous cache'


class LaboratoryNativeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = json.loads((BASE / 'motions.json').read_text())
        cls.new = json.loads((BANK / 'motions.json').read_text())
        cls.a = list(struct.iter_unpack('<4f', (BASE / 'frames.bin').read_bytes()))
        cls.b = list(struct.iter_unpack('<4f', (BANK / 'frames.bin').read_bytes()))

    def test_existing_kits_are_exact(self):
        self.assertEqual(len(self.old['variants']), 167)
        for key in ['variants', 'timelines', 'atlas_paths', 'skin_pages', 'variant_heights', 'variant_sources']:
            self.assertEqual(self.new[key][:len(self.old[key])], self.old[key], key)
        self.assertEqual(self.a[:self.old['clip_count']], self.b[:self.old['clip_count']])
        n = max(int(r[0]+r[1]) for r in self.a[:self.old['clip_count']]) * 2
        self.assertEqual(self.a[self.old['clip_count']:self.old['clip_count']+n], self.b[self.new['clip_count']:self.new['clip_count']+n])
        for cue, path in self.old['sounds'].items():
            self.assertEqual(self.new['sounds'][cue], path)
        with Image.open(BASE / 'palette.png') as a, Image.open(BANK / 'palette.png') as b:
            self.assertEqual(a.tobytes(), b.crop((0, 0, *a.size)).tobytes())
        old_species = json.loads((BASE / 'species.json').read_text())
        self.assertEqual(json.loads((BANK / 'species.json').read_text())[:len(old_species)], old_species)

    def test_original_pixels_anchors_durations_contacts_and_audio(self):
        self.check_original('original:2973', 167, 101921)

    def test_mandatory_members_preserve_their_complete_source_motion(self):
        species = json.loads((BANK / 'species.json').read_text())
        for skin in range(168, 174):
            with self.subTest(appearance=species[skin]['id']):
                self.check_original(species[skin]['key'], skin, species[skin]['id'])

    def check_original(self, key, skin, appearance):
        manifest = self.new; table = self.b
        self.assertEqual(manifest['variants'][skin]['id'], appearance)
        _, _, clips = cg.actor(key); source = {(c['action'], c['direction']): c for c in clips}
        idle, _, oy = cg.frame_parts(key, source[0, 4]['index'], 0)
        _, foot = body_rows(idle); shift = oy + foot - 10
        palette = Image.open(BANK / 'palette.png').convert('RGBA')
        images, colors, frames = {}, {}, 0
        for ai, action in enumerate(manifest['actions']):
            for direction in range(8):
                header = table[(skin*len(manifest['actions'])+ai)*8+direction]
                original = source[action, direction]
                self.assertEqual(int(header[1]), len(original['frames']))
                self.assertAlmostEqual(header[2], original['duration']/1000, places=5)
                for index in range(int(header[1])):
                    frame = int(header[0])+index
                    x,y,w,h = map(int, table[manifest['clip_count']+frame*2])
                    ox,oy,page,row = table[manifest['clip_count']+frame*2+1]; row = int(row)
                    path = manifest['atlas_paths'][int(page)]
                    if path not in images:
                        images[path] = Image.open(ROOT / path.removeprefix('res://')).convert('L')
                    if row not in colors:
                        colors[row] = [palette.getpixel((i,row)) for i in range(256)]
                    actual = Image.new('RGBA',(w,h));actual.putdata([colors[row][v] for v in images[path].crop((x,y,x+w,y+h)).getdata()])
                    image,sx,sy = cg.frame_parts(key, original['index'], index)
                    box = image.getbbox();image = image.crop(box)
                    # The indexed importer canonicalizes invisible palette RGB to zero.
                    image = Image.alpha_composite(Image.new('RGBA', image.size), image)
                    self.assertEqual(actual.size, image.size, (key, action, direction, index))
                    self.assertEqual(hashlib.sha256(actual.tobytes()).hexdigest(), hashlib.sha256(image.tobytes()).hexdigest(), (key, action, direction, index))
                    self.assertEqual((ox,oy), (sx+box[0],sy+box[1]-shift), (action,direction,index))
                    frames += 1
        for direction in range(8):
            clip = source[5,direction]; cues = cg_sounds.clip_cues(clip)
            self.assertTrue(any(10000<=c['flag']<20000 for c in cues))
            expected = [clip['duration']*.03,len(cues)]
            contact_ids = sorted({c['id'] for c in cues if 10000 <= c['flag'] < 20000})
            sound_ids = sorted({c['id'] for c in cues if not 10000 <= c['flag'] < 20000})
            sound_manifest = json.loads((ROOT.parent / 'Magic Power/godot/assets/sounds/manifest.json').read_text())['sounds']
            for cue in cues:
                contact = 10000 <= cue['flag'] < 20000
                opcode = ([135,138,164,165][contact_ids.index(cue['id'])] if contact else [106,112,131,157][sound_ids.index(cue['id'])]) if skin in range(168,172) else (10000 if contact else 20000)+cue['id']
                expected.extend([cue['atMs']*.03,opcode])
                sound = f"{skin}:{opcode if skin in range(168,172) else cue['id']}"
                self.assertTrue(sound in manifest['sounds'], sound)
                target = manifest['sounds'][sound]
                published = ROOT / target.removeprefix('res://') if target.startswith('res://') else BANK / target
                original_sound = ROOT.parent / 'Magic Power/godot/assets' / sound_manifest[str(cue['id'])]['file']
                self.assertEqual(hashlib.sha256(published.read_bytes()).hexdigest(), hashlib.sha256(original_sound.read_bytes()).hexdigest(), (key, direction, cue['id']))
            expected += [0]*(42-len(expected))
            self.assertEqual(manifest['timelines'][(skin*8+direction)*42:(skin*8+direction+1)*42], expected)
        (REPORT / ('original-frame-proof.json' if skin == 167 else f'{appearance}-original-frame-proof.json')).write_text(json.dumps(dict(appearance=appearance,key=key,frames=frames,clips=56,rgba_exact=True,anchors_exact=True,durations_exact=True,source_cues_exact=True,visual_verified=False),indent=2)+'\n')


if __name__ == '__main__':
    unittest.main()
