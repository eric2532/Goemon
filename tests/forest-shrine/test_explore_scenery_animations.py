"""Recovered scenery uses the existing renderer's complete original clips."""
import hashlib
import json
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import recover_elsa_island as source

OUT = ROOT / 'assets/maps/falan/elsa/scenery'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Explore Access/Scenery animations'


class ExploreSceneryTest(unittest.TestCase):
    def test_existing_animation_records_and_pixels_are_preserved(self):
        before = json.loads((REPORT / 'append-proof.json').read_text())['preserved']
        current = json.loads((OUT / 'data.json').read_text())['animations']
        for serial, record in before.items():
            self.assertEqual(current[serial], record)
            with Image.open(OUT / f'{serial}.png') as image:
                self.assertEqual(hashlib.sha256(image.convert('RGBA').tobytes()).hexdigest(), record['sha256'])

    def test_every_required_clip_preserves_frames_timing_opacity_and_anchors(self):
        catalog = json.loads((ROOT / 'assets/maps/original_crossgate/explore_recovered/catalog.json').read_text())
        current = json.loads((OUT / 'data.json').read_text())['animations']
        serials = sorted({int(g['cut'][0]) for g in catalog['graphics'].values() if g.get('animated')})
        total = 0
        for serial in serials:
            record = current[str(serial)]
            _, _, _, clip = source.scenery_frame(serial)
            for name in ['duration', 'opacity', 'flags']:
                self.assertEqual(record[name], clip[name], (serial, name))
            self.assertEqual(record['source_key'], clip['key'])
            self.assertEqual(record['frames'], len(clip['frames']))
            with Image.open(OUT / f'{serial}.png') as image:
                image = image.convert('RGBA')
                width, height = record['size']
                for i in range(record['frames']):
                    art, x, y, _ = source.scenery_frame(serial, i)
                    expected = Image.new('RGBA', (width, height))
                    expected.alpha_composite(art, (x - record['origin'][0], y - record['origin'][1]))
                    left = i % record['columns'] * width; top = i // record['columns'] * height
                    actual = image.crop((left, top, left + width, top + height))
                    self.assertEqual(hashlib.sha256(actual.tobytes()).hexdigest(), hashlib.sha256(expected.tobytes()).hexdigest(), (serial, i))
                    total += 1
        (REPORT / 'source-frames-proof.json').write_text(json.dumps(dict(clips=len(serials), frames=total, rgba_exact=True, anchors_exact=True, duration_exact=True, opacity_exact=True, flags_exact=True, visual_verified=False), indent=2) + '\n')

    def test_puk3_scenery_header_keeps_opacity_separate_from_frame_offsets(self):
        art, x, y, clip = source.scenery_frame(113200)
        self.assertEqual((clip['key'], clip['opacity'], clip['duration']), ('puk3:122', 185, 1200))
        self.assertEqual(clip['frames'][0], (242, 0, 0, 0))
        self.assertEqual((art.size, x, y), ((56, 77), -27, -38))


if __name__ == '__main__':
    unittest.main()
