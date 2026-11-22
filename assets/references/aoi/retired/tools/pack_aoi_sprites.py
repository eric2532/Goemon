"""Pack Aoi's offline renders with the existing Cross Gate atlas contract."""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageFilter

from recover_crossgate_kazi import pack_frames

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / 'build/Other Files/Asset Toolkit/Aoi'
OUT = ROOT / 'assets/characters/crossgate/fighters/aoi'
SCALE = 83 / 90


def prepare(image, palette):
    image = image.resize((round(image.width * SCALE), round(image.height * SCALE)), Image.Resampling.LANCZOS)
    alpha = image.getchannel('A').point(lambda value: 255 if value >= 110 else 0)
    rgb = image.convert('RGB').quantize(palette=palette, dither=Image.Dither.NONE).convert('RGBA')
    rgb.putalpha(alpha)
    # One quiet dark rim retains the readable silhouette of the recovered sprites.
    rim = Image.new('RGBA', rgb.size, (44, 31, 47, 255))
    rim.putalpha(alpha.filter(ImageFilter.MaxFilter(3)))
    rim.alpha_composite(rgb)
    return rim


def bake():
    global SCALE
    metadata = json.loads((REVIEW / 'render.json').read_text())
    ruler = Image.open(REVIEW / 'body-ruler.png').getchannel('A').point(lambda a: 255 if a >= 110 else 0).getbbox()
    assert ruler, 'Missing standing body ruler'
    SCALE = 81 / (ruler[3] - ruler[1])
    master = ROOT / 'assets/blender/characters/aoi/aoi.blend'
    assert hashlib.sha256(master.read_bytes()).hexdigest() == metadata['master_sha256'], 'Re-render changed master'
    clock = ROOT / 'assets/characters/crossgate/kazi/motions.json'
    assert hashlib.sha256(clock.read_bytes()).hexdigest() == metadata['clock_sha256'], 'Re-render changed source clock'
    assert metadata['pipe_multiplier'] == 4 and metadata['pipe_length'] == 3.8
    assert set(metadata['clips']) == {f'{action}:{d}' for action in [0, 1, 3, 5, 6, 8, 9, 10] for d in range(8)}
    # One palette for the complete animation prevents per-frame color changes.
    palette_sheet = Image.new('RGB', (8 * 128, 128), (244, 201, 144))
    for d in range(8):
        image = Image.open(REVIEW / 'Frames' / f'0-{d}-00.png').convert('RGBA')
        image.thumbnail((128, 128))
        palette_sheet.paste(image, (d * 128, 0), image)
    palette = palette_sheet.quantize(colors=128, method=Image.Quantize.MEDIANCUT)
    unique, clips, raw = {}, {}, {}
    oy = ruler[3] * SCALE
    for key, source in metadata['clips'].items():
        clip = {k: v for k, v in source.items() if k != 'frames'}
        clip['frames'] = []
        frame_hashes = set()
        for filename in source['frames']:
            path = REVIEW / 'Frames' / filename
            raw[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
            raw_image = Image.open(path).convert('RGBA')
            ox = raw_image.width * .5 * SCALE
            image = prepare(raw_image, palette)
            bounds = image.getbbox()
            assert bounds and min(bounds[:2]) > 1 and bounds[2] < image.width - 1 and bounds[3] < image.height - 1, filename + ' is clipped'
            sprite = image.crop(bounds)
            digest = hashlib.sha256(sprite.tobytes()).hexdigest()
            unique[digest] = sprite
            frame_hashes.add(digest)
            clip['frames'].append((digest, round(bounds[0] - ox), round(bounds[1] - oy + 7)))
        if not key.startswith('9:'):
            assert len(frame_hashes) > 1, key + ' has no motion'
        clips[key] = clip
    OUT.mkdir(parents=True, exist_ok=True)
    count = pack_frames(clips, unique, OUT)
    front = prepare(Image.open(REVIEW / 'Frames/0-4-00.png').convert('RGBA'), palette)
    ox = front.width * .5
    bounds = front.getbbox()
    front.crop(bounds).save(OUT / 'portrait.png')
    front.crop((round(ox) - 22, bounds[1] - 2, round(ox) + 22, bounds[1] + 42)).save(OUT / 'hud-portrait.png')
    data = {'name': 'Aoi', 'id': 'aoi', 'key': 'original:aoi', 'pages': count,
            'unique_frames': len(unique), 'body_pixels': 83, 'clips': clips,
            'portrait_origin': [round(bounds[0] - ox), round(bounds[1] - oy + 7)],
            'authoring': {k: v for k, v in metadata.items() if k != 'clips'},
            'source_frame_hashes': raw}
    (OUT / 'motions.json').write_text(json.dumps(data, separators=(',', ':')) + '\n')
    print('AOI_PACKED', len(clips), 'clips,', len(unique), 'unique frames,', count, 'pages')


if __name__ == '__main__':
    bake()
