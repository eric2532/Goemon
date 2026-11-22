"""Recover the level-11 追月 projectile and release cue from the archived client."""
import argparse
import hashlib
from math import sqrt
from pathlib import Path, PureWindowsPath
import struct
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def bake_relief(atlas):
    """Shade the original strokes as bevels and copy the silhouette verbatim."""
    linear = [(value / 255 / 12.92 if value <= 10 else ((value / 255 + .055) / 1.055) ** 2.4)
              for value in range(256)]
    heights = atlas.getchannel('R').point([round(255 * (.28 + .72 * value)) for value in linear])
    alpha = atlas.getchannel('A')
    heights.paste(0, mask=alpha.point(lambda value: 255 - value))
    height = heights.load()
    source = atlas.load()
    baked = atlas.copy()
    shaded = baked.load()

    for y in range(atlas.height):
        top = max(y // 128 * 128, y - 3)
        bottom = min(y // 128 * 128 + 127, y + 3)
        for x in range(atlas.width):
            red, green, blue, opacity = source[x, y]
            if opacity == 0:
                continue
            left = max(x // 144 * 144, x - 3)
            right = min(x // 144 * 144 + 143, x + 3)
            dx = (height[left, y] - height[right, y]) / 255
            dy = (height[x, bottom] - height[x, top]) / 255
            normal_length = sqrt(dx * dx + dy * dy + .52 ** 2)
            face = max(0, (-.40 * dx + .69 * dy + .60 * .52) / normal_length)
            glint = max(0, (-.22 * dx + .39 * dy + .89 * .52) / normal_length) ** 18
            color = []
            for pixel, tint, highlight in zip((red, green, blue), (.018, .22, .62), (.31, .67, 1.0)):
                ice = .57 * tint + .43 * linear[pixel]
                value = ice * (.46 + .72 * face) + .65 * highlight * glint
                color.append(round(255 * min(1, 1.055 * value ** (1 / 2.4) - .055)))
            shaded[x, y] = (*color, opacity)

    assert baked.getchannel('A').tobytes() == alpha.tobytes()
    return baked


def recover(source):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_sounds

    client = source / 'research/newclient20261030'
    snapshot = (client / 'combat/bluecg-virtual-memory.bin').read_bytes()
    assert hashlib.sha256(snapshot).hexdigest() == '8babbe4ad20e4e1e2a6992ecf086d47ef3527426879699f83fa2cebb1a476afe'
    assert struct.unpack_from('<I', snapshot, 0x405908 - 0x400000)[0] == 104222
    assert struct.unpack_from('<I', snapshot, 0x405934 - 0x400000)[0] == 268
    cg.SOURCE = client / 'source/bin'
    charge, = cg.actor('original:3080')[2]
    assert (charge['duration'], len(charge['frames']), charge['frames'][0][3]) == (459, 9, 251)
    attacks = [clip for clip in cg.actor('original:2402')[2] if clip['action'] == 5]
    assert len(attacks) == 8
    for clip in attacks:
        assert (clip['duration'], len(clip['frames'])) == (1300, 42)
        flags = [(index, frame[3]) for index, frame in enumerate(clip['frames']) if frame[3]]
        assert flags == [(12, 103), (13, 20133), (26, 103), (27, 10134)]

    out = ROOT / 'assets/characters/crossgate/kazi'
    atlas = Image.new('RGBA', (4 * 144, 16 * 128))
    rows = cg.latest_animation_rows('joy')
    for direction in range(16):
        key = f'joy:{rows[104222 + direction]}'
        clip, = cg.actor(key)[2]
        assert (clip['duration'], len(clip['frames'])) == (2000, 4)
        for frame in range(4):
            pixels, x, y = cg.frame_parts(key, 0, frame)
            box = pixels.getbbox()
            assert box
            pixels = pixels.crop(box)
            left, top = x + box[0] + 72, y + box[1] + 64
            assert 0 <= left <= 144 - pixels.width and 0 <= top <= 128 - pixels.height
            origin = (frame * 144 + left, direction * 128 + top)
            atlas.paste(pixels, origin)
            assert atlas.crop((*origin, origin[0] + pixels.width, origin[1] + pixels.height)).tobytes() == pixels.tobytes()
    atlas.save(out / 'moon-waves.png')
    bake_relief(atlas).save(out / 'moon-waves-relief.png')
    icon = atlas.crop((0, 0, 144, 128))
    icon.crop(icon.getbbox()).save(out / 'icons/moon.png')
    filename = PureWindowsPath(cg_sounds.sound_table()['268']['file']).name
    assert filename.lower() == 'cgefc17.wav'
    audio = (cg.SOURCE / 'se' / filename).read_bytes()
    assert audio[:4] == b'RIFF' and audio[8:12] == b'WAVE'
    (ROOT / 'assets/audio/crossgate/kazi' / filename).write_bytes(audio)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    recover(parser.parse_args().source.resolve())
