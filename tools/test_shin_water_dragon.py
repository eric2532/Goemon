"""Check the stitched derivative without changing the original character or item."""
import hashlib
import json
from pathlib import Path
import unittest

from PIL import Image

from prepare_shin_water_dragon import ART, OUT, ROOT, SIZE, ORIGIN, RECIPE, SWORD_SCALE, WAVE_ORIGIN, WAVE_SIZE, prepare, blue_theme, blue_waves, stitch


class WaterDragonTest(unittest.TestCase):
    def test_water_attack_layer_is_only_on_water_skin(self):
        bank = json.loads((ROOT / 'assets/audio/crossgate/player-attacks.json').read_text())
        self.assertEqual(bank['mix_recipes']['900010'], [134, 264])
        for direction in range(8):
            self.assertEqual(bank['profiles']['res://assets/characters/crossgate/shin/900050/'][0][f'5:{direction}'], [[104], [900010]])
            self.assertEqual(bank['profiles']['res://assets/characters/crossgate/shin/100050/'][1][f'5:{direction}'], [[104], [134]])
        source = json.loads((ART.parent / 'companions/elemental_sprites/motions.json').read_text())
        water = next(v for v in source['variants'] if v['key'] == 'original:2902')
        for clip in water['clips']:
            if clip['action'] == 5:
                self.assertTrue(any(cue['id'] == 264 and cue.get('file') == 'sounds/cgefc13.wav' for cue in clip['sounds']))

    def test_side_resting_silver_edge_faces_down(self):
        recipe = json.loads(RECIPE.read_text())
        source = json.loads((ART / '100050/motions.json').read_text())
        pages = [Image.open(ART / f'100050/atlas-{i}.png').convert('RGBA') for i in range(source['pages'])]
        sword = Image.new('RGBA', SIZE)
        sword.alpha_composite(Image.open(OUT / 'water-dragon-sword.png').convert('RGBA'))

        def canvas(frame):
            p, x, y, w, h, ox, oy = frame
            image = Image.new('RGBA', SIZE)
            image.alpha_composite(pages[p].crop((x, y, x + w, y + h)), (ORIGIN[0] + ox, ORIGIN[1] + oy))
            return blue_theme(image)

        for direction in (6, 7):
            frames = source['weapons'][0]['clips'][f'0:{direction}']['frames']
            unique = list(dict.fromkeys(tuple(f) for f in frames))
            for index, frame in enumerate(unique):
                pose = recipe[f'0:{direction}:{index}']
                body = canvas(frame)
                bare = canvas(source['clips'][f'0:{direction}']['frames'][frames.index(list(frame))])
                actual, _ = stitch(body, sword, pose, bare)
                gx, gy = [pose['grip'][j] + ORIGIN[j] - (96, 116)[j] for j in (0, 1)]
                vx, vy = [pose['tip'][j] - pose['grip'][j] for j in (0, 1)]
                length = (vx * vx + vy * vy) ** .5
                silver = []
                for y in range(SIZE[1]):
                    for x in range(SIZE[0]):
                        if body.getpixel((x, y))[3]:continue
                        along = ((x - gx) * vx + (y - gy) * vy) / (length * length * SWORD_SCALE)
                        if not .5 < along < 1:continue
                        r, g, b, a = actual.getpixel((x, y))
                        if not a:continue
                        across = (vx * (y - gy) - vy * (x - gx)) / length
                        if min(r, g, b) > 150:silver.append(across)
                self.assertTrue(silver, (direction, index))
                self.assertLess(sum(silver) / len(silver), -1,
                                ('Silver cutting edge must face below the grip-to-tip axis', direction, index))
        for page in pages:
            page.close()

    def test_resting_edge_and_original_blade_removal(self):
        self.assertAlmostEqual(SWORD_SCALE, 1.5 * 1.15)
        recipe = json.loads(RECIPE.read_text())
        data = json.loads((ART / '100050/motions.json').read_text())
        pages = [Image.open(ART / f'100050/atlas-{i}.png').convert('RGBA') for i in range(data['pages'])]
        sword = Image.new('RGBA', SIZE)
        sword.alpha_composite(Image.open(OUT / 'water-dragon-sword.png').convert('RGBA'))
        native = data['weapons'][0]['clips']['0:4']['frames']
        poses = list(dict.fromkeys(tuple(frame) for frame in native))

        def canvas(frame):
            p, x, y, w, h, ox, oy = frame
            image = Image.new('RGBA', SIZE)
            image.alpha_composite(pages[p].crop((x, y, x + w, y + h)), (ORIGIN[0] + ox, ORIGIN[1] + oy))
            return blue_theme(image)

        for i, frame in enumerate(native):
            pose = recipe[f'0:4:{poses.index(tuple(frame))}']
            self.assertTrue(pose['edge_flip'], 'Resting blade must face opposite the raised blade')
            body, bare = canvas(frame), canvas(data['clips']['0:4']['frames'][i])
            result, removed = stitch(body, sword, pose, bare)
            count = 0
            for y in range(100, 129):
                for x in range(80, 114):
                    point = (x + ORIGIN[0] - 96, y + ORIGIN[1] - 116)
                    r, g, b, a = body.getpixel(point)
                    if a and not bare.getpixel(point)[3] and min(r, g, b) > 110 and max(r, g, b) - min(r, g, b) < 43:
                        self.assertEqual(removed.getpixel(point), 255, ('Old blade remains', i, x, y))
                        count += 1
            self.assertGreater(count, 0)
            gx, gy = [pose['grip'][j] + ORIGIN[j] - (96, 116)[j] for j in (0, 1)]
            for y in range(round(gy) - 1, round(gy) + 2):
                for x in range(round(gx) - 1, round(gx) + 2):
                    if body.getpixel((x, y))[3]:
                        self.assertEqual(result.getpixel((x, y)), body.getpixel((x, y)), 'Original resting hand')
        for page in pages:
            page.close()

    def test_purple_hair_preserves_face_alpha_and_original_wave_schedule(self):
        image = Image.new('RGBA', (4, 1))
        image.putdata([(195, 16, 2, 255), (237, 207, 133, 255), (29, 2, 0, 255), (91, 139, 189, 255)])
        themed = list(blue_theme(image).getdata())
        self.assertGreater(themed[0][2], themed[0][0])
        self.assertGreater(themed[0][0], themed[0][1])
        self.assertLess(themed[0][2] - themed[0][1], 100)
        self.assertEqual(themed[0][3], 255)
        self.assertEqual(image.getpixel((0, 0)), (195, 16, 2, 255))
        self.assertEqual(themed[1], (237, 207, 133, 255))
        self.assertEqual(themed[2], (23, 5, 29, 255), 'Keep the dark cleanup edge')
        self.assertEqual(themed[3], (81, 125, 170, 255), 'Slightly darker outfit blue')
        waves = blue_waves()
        image, ox, oy = waves['5:1'][12]
        self.assertEqual(image.getpixel((10 - ox, -95 - oy)), (0, 187, 236, 255),
                         'The donor raised sword must not punch a hole in the wave above the head')
        original = json.loads((ART / '111625/motions.json').read_text())
        for pose, frames in waves.items():
            self.assertEqual(len(frames), 25)
            for frame, source in zip(frames, original['clips'][pose]['frames']):
                self.assertEqual(frame is not None, source[3] >= 150 or source[4] >= 150)
                if frame is not None:
                    image = frame[0]
                    self.assertGreater(sum(n for n, (r, g, b, a) in image.getcolors(image.width * image.height)
                                           if a and b > r), 1000)

    def test_swing_uses_hand_end_of_blade(self):
        recipe = json.loads(RECIPE.read_text())
        for pose in ('5:1:1', '5:2:3'):
            self.assertGreater(recipe[pose]['grip'][0], recipe[pose]['tip'][0] + 5, pose)
        for pose in ('5:0:1', '5:1:2', '5:1:3'):
            self.assertGreater(recipe[pose]['grip'][1], recipe[pose]['tip'][1] + 5, pose)

    def test_movement_keeps_grip_and_edge_through_stride(self):
        recipe = json.loads(RECIPE.read_text())
        for direction in range(2, 8):
            for index in range(6):
                self.assertEqual(recipe[f'1:{direction}:{index}']['edge_flip'], direction in (2, 3, 4, 5))
        for direction in range(7):
            for index in range(6):
                self.assertEqual(recipe[f'3:{direction}:{index}']['edge_flip'], direction <= 4)
        for direction in (5, 6):
            lengths = []
            for index in range(6):
                pose = recipe[f'3:{direction}:{index}']
                self.assertGreater(pose['grip'][0], pose['tip'][0] + 15, ('Hand must stay at the right end', direction, index))
                lengths.append(sum((pose['tip'][j] - pose['grip'][j]) ** 2 for j in (0, 1)) ** .5)
                self.assertGreater(pose['projected_width'], .5)
            self.assertLess(max(lengths) / min(lengths), 1.2, 'Native carry cannot reverse or collapse during a stride')
        for index in range(6):
            self.assertGreater(recipe[f'1:7:{index}']['grip'][0], 104, 'West walking grip is behind the body, not at the visible blade fragment')

    def test_user_approved_swing_edge_faces(self):
        recipe = json.loads(RECIPE.read_text())
        mirrored = {0: set(), 1: {0}, 2: {1, 2, 4, 5, 6}, 3: {1, 2, 4, 5, 6},
                    4: {4, 5, 6}, 5: {4, 5, 6, 7}, 6: {4, 5, 6}, 7: {4, 5, 6}}
        for direction in range(8):
            for pose in range(8):
                frame = recipe[f'5:{direction}:{pose}']
                if frame is not None:
                    self.assertEqual(frame['edge_flip'], pose in mirrored[direction])

    def test_recovery_uses_complete_resting_grip(self):
        recipe = json.loads(RECIPE.read_text())
        manifest = json.loads((OUT / 'motions.json').read_text())
        for direction in (5,):
            pose, rest = f'5:{direction}', f'0:{direction}'
            self.assertEqual(recipe[f'{pose}:7']['body_pose'], f'{rest}:0')
            self.assertEqual(manifest['clips'][pose]['frames'][-1], manifest['clips'][rest]['frames'][0],
                             'Return torso, arm, hand and sword together instead of turning a blade in the old wrist')
        for direction in (6, 7):
            self.assertNotIn('body_pose', recipe[f'5:{direction}:7'])
            self.assertNotEqual(manifest['clips'][f'5:{direction}']['frames'][-1],
                                manifest['clips'][f'0:{direction}']['frames'][0],
                                'Approved recovery retains its original body instead of idle')

    def test_source_pixels_clocks_and_reproducible_atlas(self):
        originals = {p: hashlib.sha256(p.read_bytes()).hexdigest()
                     for skin in ('100050', '111625') for p in (ART / skin).iterdir() if p.is_file()}
        manifest, bodies, masks = prepare(ROOT.parent / 'Magic Power', check=True)
        base = json.loads((ART / '100050/motions.json').read_text())['weapons'][0]
        self.assertEqual(set(manifest['clips']), set(base['clips']) | {f'9:{d}' for d in range(8)})
        for pose, clip in base['clips'].items():
            self.assertEqual({k: v for k, v in clip.items() if k != 'frames'},
                             {k: v for k, v in manifest['clips'][pose].items() if k != 'frames'}, pose)
        pages = [Image.open(OUT / f'atlas-{i}.png').convert('RGBA') for i in range(manifest['pages'])]
        protected = 0
        for pose, frames in bodies.items():
            seen = set()
            for i, (body, index) in enumerate(frames):
                if index in seen:
                    continue
                seen.add(index)
                p, x, y, w, h, ox, oy = manifest['clips'][pose]['frames'][i]
                actual = Image.new('RGBA', body.size)
                actual.alpha_composite(pages[p].crop((x, y, x + w, y + h)), (ORIGIN[0] + ox, ORIGIN[1] + oy))
                self.assertTrue(-WAVE_ORIGIN[0] < ox and -WAVE_ORIGIN[1] < oy
                                and ox + w < WAVE_SIZE[0] - WAVE_ORIGIN[0]
                                and oy + h < WAVE_SIZE[1] - WAVE_ORIGIN[1],
                                'Prepared body and wave fit without clipping: ' + pose)
                mask = masks[f'{pose}:{index}']
                for source_pixel, result_pixel, removed in zip(body.getdata(), actual.getdata(), mask.getdata()):
                    if source_pixel[3] == 255 and not removed:
                        self.assertEqual(source_pixel, result_pixel, pose)
                        protected += 1
                    r, g, b, a = source_pixel
                    if a == 255 and not removed and r > 65 and .48 * r < g < .95 * r and b < .8 * g:
                        self.assertEqual(source_pixel, result_pixel, 'Original grip/skin: ' + pose)
        self.assertGreater(protected, 200000)
        for p, digest in originals.items():
            self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), digest, str(p))
        for page in pages:
            page.close()


if __name__ == '__main__':
    unittest.main()
