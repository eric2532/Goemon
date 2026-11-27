"""Private material-only source leaf crop; canonical tree art and meshes stay intact."""
from pathlib import Path
import hashlib
import json

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Tree Whole Canopy Candidate'
OUT = BASE / 'Native Leaf Material Candidate'
SOURCE = BASE / '10074-native.png'
BOUNDS = (136, 217, 148, 229)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def linear(channel):
    value = channel / 255
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


def main():
    original = Image.open(SOURCE).convert('RGBA')
    crop = original.crop(BOUNDS)
    pixels = list(crop.getdata())
    opaque = [pixel for pixel in pixels if pixel[3] >= 128]
    assert crop.size == (12, 12) and 0 < len(opaque) < len(pixels)
    assert set(pixel[3] for pixel in pixels) == {0, 255}
    tile = crop.resize((32, 32), Image.Resampling.NEAREST)
    assert set(tile.getdata()) <= set(pixels)
    OUT.mkdir(parents=True, exist_ok=True)
    crop.save(OUT / 'native-leaf-edge-12.png')
    tile.save(OUT / 'native-leaf-edge-32.png')
    original.save(OUT / '10074-native.png')
    contact = Image.new('RGBA', (800, 420), (40, 48, 53, 255))
    draw = ImageDraw.Draw(contact)
    contact.alpha_composite(original, (18, 55))
    draw.rectangle((18 + BOUNDS[0], 55 + BOUNDS[1], 18 + BOUNDS[2], 55 + BOUNDS[3]), outline='white')
    contact.alpha_composite(crop.resize((288, 288), Image.Resampling.NEAREST), (300, 65))
    draw.text((18, 12), 'Untouched native10074 | exact12x12 leaf-edge crop | actual alpha retained', fill='white')
    draw.text((300, 365), 'One asymmetric two-leaf edge; no new alpha mask', fill='white')
    contact.save(OUT / 'source-crop-contact.png')
    record = {
        'scope': 'PRIVATE one material-only native leaf-edge trial; one intact canopy, vertices/normals/UV/index/pose/wood unchanged.',
        'source': str(SOURCE.relative_to(ROOT)), 'source_sha256': sha(SOURCE),
        'crop_bounds': BOUNDS, 'crop_size': crop.size, 'tile_size': tile.size,
        'resampling': 'NEAREST; tile contains only original crop RGBA values, including transparent RGB.',
        'opaque_native_pixels': len(opaque), 'native_pixels': len(pixels),
        'alpha128_coverage_fraction': len(opaque) / len(pixels),
        'opaque_crop_mean_linear': [sum(linear(pixel[k]) for pixel in opaque) / len(opaque) for k in range(3)],
        'native_crown_mean_linear': [.08857533158190967, .27643328086817054, .07347200953225301],
        'palette': 'One material tint compensates existing vertex-color mean and crop mean to the independently sampled original crown mean; source tonal variation/alpha remain.',
        'inferred': 'The original two-leaf edge is repeated on the compatible existing3Dcanopy; individual hidden leaves and their placement are inferred.',
        'outputs': {name: sha(OUT / name) for name in ['native-leaf-edge-12.png', 'native-leaf-edge-32.png', '10074-native.png']},
        'preparer_sha256': sha(Path(__file__)),
        'acceptance': 'Unreviewed material-only studio trial; no canonical/field/gameplay acceptance.'
    }
    (OUT / 'source.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'output': str(OUT.relative_to(ROOT)), 'alpha_coverage': record['alpha128_coverage_fraction'], 'mean_linear': record['opaque_crop_mean_linear'], 'checks': 4}))


if __name__ == '__main__':
    main()
