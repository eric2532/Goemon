"""Separate the forward attack pixels from the preserved Kaz sprites."""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops

from recover_crossgate_kazi import pack_frames

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/characters/crossgate/kazi'
OUT = ROOT / 'assets/characters/crossgate/kazi_attack'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def outer_effect(frame, protected):
    effect = Image.new('RGBA', frame.size)
    left, top, right, bottom = protected
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = frame.getpixel((x, y))
            energy = (b-g > 20 and b >= r*.85) or min(r,g,b) > 180
            if a and energy and not (left <= x < right and top <= y < bottom):
                effect.putpixel((x, y), (r, g, b, a))
    return effect


def body_colors(frames):
    return {pixel[:3] for frame in frames for pixel in frame.getdata() if pixel[3]}


def split_forward(image, x, y, protected, purple=False, palette=None, red_flame=False):
    if purple:
        effect = outer_effect(image, (0,0,0,0))
    else:
        effect = Image.new('RGBA', image.size)
        source_pixels = image.load()
        effect_pixels = effect.load()
        left, top, right, bottom = protected
        center_x, center_y = (left+right)*.5, (top+bottom)*.5
        rx, ry = (right-left)*.5, (bottom-top)*.5
        for row in range(image.height):
            v = ((y+row-center_y)/ry)**2
            for col in range(image.width):
                r,g,b,a = source_pixels[col,row]
                if not a:
                    continue
                distance = ((x+col-center_x)/rx)**2 + v
                shadow = y+row > -9 and max(r,g,b) < 72 and max(r,g,b)-min(r,g,b) < 24
                body = distance < .55 or (distance < 1 and (r,g,b) in palette)
                # Red Lightning's white hair can extend beyond the body mask.
                if red_flame and max(r,g,b)-min(r,g,b) < 32:
                    body = True
                if not shadow and not body:
                    effect_pixels[col,row] = (r,g,b,a)
    body = image.copy()
    body.putalpha(ImageChops.subtract(image.getchannel('A'), effect.getchannel('A')))
    assert Image.alpha_composite(body, effect).tobytes() == image.tobytes()
    return body, effect


def packed_frame(image, x, y, unique):
    box = image.getbbox()
    if box is None:
        return None
    art = image.crop(box)
    digest = (art.size, hashlib.sha256(art.tobytes()).hexdigest())
    unique.setdefault(digest, art)
    return digest, x + box[0], y + box[1]


def prepare():
    source = json.loads((SOURCE / 'motions.json').read_text())
    pages = [Image.open(SOURCE / f'atlas-{i}.png').convert('RGBA') for i in range(source['pages'])]
    unique, packed, layers = {}, {}, {}
    for direction in range(8):
        frames = []
        for page, x, y, w, h, ox, oy in source['clips'][f'5:{direction}']['frames']:
            frames.append((pages[page].crop((x,y,x+w,y+h)), ox, oy))
        keys = []
        for i,(image,x,y) in enumerate(frames):
            if i in (4,5):
                keys.append(None)
                continue
            body, effect = split_forward(image, x, y, (), True)
            moved = packed_frame(effect, x, y, unique)
            if moved is None:
                keys.append(None)
                continue
            key = f'{direction}:{i}'
            # The core flash entirely covers the original fighter on these two frames.
            if i in (6, 7):
                body, x, y = frames[5]
            held = packed_frame(body, x, y, unique)
            assert held is not None, key
            packed[key] = dict(frames=[held, moved])
            keys.append(key)
        layers[str(direction)] = keys
    pages = pack_frames(packed, unique, OUT)
    clips = {direction: [packed[key]['frames'] if key else [] for key in keys]
             for direction,keys in layers.items()}
    memory = 0
    for path in OUT.glob('atlas-*.png'):
        with Image.open(path) as image:
            memory += image.width*image.height*4
    result = dict(clips=clips, pages=pages, texel_bytes=memory,
                  source_hashes={p.name:sha(p) for p in [SOURCE/'motions.json',*sorted(SOURCE.glob('*.png'))]},
                  texture_hashes={p.name:sha(p) for p in OUT.glob('atlas-*.png')})
    (OUT/'motions.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    print(f'Prepared {len(packed)} split attack frames, {memory/2**20:.3f} MiB shared')


if __name__ == '__main__':
    prepare()
