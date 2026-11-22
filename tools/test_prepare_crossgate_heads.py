"""Keep the reviewed hair tips and lower faces in the original-model HUD heads."""
import json
import unittest

from PIL import Image

from prepare_crossgate_heads import ART, ROOT


class HeadCropTest(unittest.TestCase):
    def test_complete_head_pixels(self):
        records = {r['key']: r for r in json.loads((ART / 'model-head-provenance.json').read_text())}
        routes = json.loads((ART / 'model-heads.json').read_text())
        # Original-pose regions that the former body-height/character crop cut off.
        required = {
            '35:100737': (-12, -72, 23, -34),
            '40:100625': (-15, -86, 16, -54),
            '42:106275': (-10, -74, 15, -41),
            '44:106025': (-15, -67, 14, -35),
            '47:106000': (-12, -67, 11, -37),
            '48:105125': (-14, -74, 14, -41),
            '49:105275': (-15, -76, 16, -38),
        }
        for key, (left, top, right, bottom) in required.items():
            with self.subTest(key=key):
                r = records[key]
                cl, ct, cr, cb = r['crop']
                self.assertTrue(cl <= left < right <= cr and ct <= top < bottom <= cb,
                                'Reviewed head pixels must be inside the crop')
                _, x, y, _, _, ox, oy = r['source_frame']
                scale = r['scale']
                with Image.open(ROOT / r['atlas']) as atlas:
                    expected = atlas.convert('RGBA').crop((x + left - ox, y + top - oy,
                                                           x + right - ox, y + bottom - oy))
                expected = expected.resize((expected.width * scale, expected.height * scale),
                                           Image.Resampling.NEAREST)
                bl, bt, br, bb = r['bounds']
                px = (256 - (br - bl) * scale) // 2 + (left - cl - bl) * scale
                py = r['top_y'] + (top - ct - bt) * scale
                with Image.open(ART / routes[key]) as head:
                    actual = head.convert('RGBA').crop((px, py, px + expected.width, py + expected.height))
                self.assertEqual(actual.tobytes(), expected.tobytes())

    def test_all_heads_fit_inside_hud_canvas(self):
        routes = json.loads((ART / 'model-heads.json').read_text())
        for path in set(routes.values()):
            with self.subTest(path=path), Image.open(ART / path) as head:
                self.assertEqual(head.size, (256, 256))
                left, top, right, bottom = head.getbbox()
                self.assertEqual(top, 8, 'Hair tops must meet the top of the HUD circle')
                self.assertTrue(left >= 16 and right <= 240 and bottom <= 240)


if __name__ == '__main__':
    unittest.main()
