"""Crop the original front-facing model heads for the existing HUD portrait cache."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/ui/portraits/crossgate'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Model HUD Heads'
CATALOG = REPORT / 'Gameplay/catalog.json'


def prepare(check=False):
    entries = json.loads(CATALOG.read_text())
    crops = json.loads((ART / 'model-head-crops.json').read_text())
    # Hidden classic Shin choices still have valid saved loadouts.
    for skin in (100053, 100055):
        entries.append(dict(character=38, skin=skin, name='Shin Special', label='Hidden classic',
                            source=f'res://assets/characters/crossgate/shin/{skin}/portrait.png', body_pixels=87))
    keys = {str(e['character']) + (':' + str(e['skin']) if e['skin'] else '') for e in entries}
    assert set(crops) == keys, 'Review the standing head crop for every new skin before preparation'
    routes, records, prepared = {}, [], {}
    for entry in entries:
        key = str(entry['character']) + (':' + str(entry['skin']) if entry['skin'] else '')
        folder = ROOT / entry['source'].removeprefix('res://')
        folder = folder.parent
        manifest_path = folder / 'motions.json'
        manifest = json.loads(manifest_path.read_text())
        frame = manifest['clips']['0:5']['frames'][0]
        page, x, y, width, height, ox, oy = frame
        atlas_path = folder / f'atlas-{page}.png'
        with Image.open(atlas_path) as atlas:
            pose = atlas.convert('RGBA').crop((x, y, x + width, y + height))
        # Skins can move the face or change its shape independently of body height.
        crop = crops[key]
        head = pose.crop((crop[0] - ox, crop[1] - oy, crop[2] - ox, crop[3] - oy))
        bounds = head.getbbox()
        assert bounds, key
        head = head.crop(bounds)
        scale = min(224 // head.width, 232 // head.height)
        assert scale >= 1, key
        head = head.resize((head.width * scale, head.height * scale), Image.Resampling.NEAREST)
        canvas = Image.new('RGBA', (256, 256))
        canvas.paste(head, ((256 - head.width) // 2, 8))
        digest = hashlib.sha256(canvas.tobytes()).hexdigest()
        path = prepared.setdefault(digest, ART / 'model' / f'{key.replace(":", "-")}.png')
        if check:
            with Image.open(path) as existing:
                assert existing.convert('RGBA').tobytes() == canvas.tobytes(), key
        else:
            path.parent.mkdir(exist_ok=True)
            canvas.save(path)
            path.with_suffix('.png.import').write_text(
                '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="res://'
                + str(path.relative_to(ROOT))
                + '"\n[params]\ncompress/mode=0\nprocess/fix_alpha_border=false\nmipmaps/generate=false\n')
        routes[key] = str(path.relative_to(ART))
        records.append(dict(key=key, name=entry['name'], label=entry['label'],
                            manifest=str(manifest_path.relative_to(ROOT)), pose='0:5', frame=0,
                            atlas=str(atlas_path.relative_to(ROOT)), source_frame=frame,
                            crop=list(crop), bounds=list(bounds), scale=scale, top_y=8,
                            sha256=digest))
    weapons = json.loads((ROOT / 'assets/characters/crossgate/weapons/catalog.json').read_text())
    expected_keys = {character + (':' + skin if skin != '0' else '')
                     for character, skins in weapons.items() for skin in skins}
    assert set(routes) == expected_keys | {'34:100528'}, 'Refresh the runtime head catalog after skin changes'
    expected = json.dumps(routes, indent=2) + '\n'
    if check:
        assert (ART / 'model-heads.json').read_text() == expected
        assert json.loads((ART / 'model-head-provenance.json').read_text()) == records
    else:
        (ART / 'model-heads.json').write_text(expected)
        (ART / 'model-head-provenance.json').write_text(json.dumps(records, indent=2) + '\n')
        for start in range(0, len(records), 40):
            chunk = records[start:start + 40]
            board = Image.new('RGB', (1280, ((len(chunk) + 7) // 8) * 190), '#28221d')
            draw = ImageDraw.Draw(board)
            for i, record in enumerate(chunk):
                with Image.open(ART / routes[record['key']]) as head:
                    head = head.resize((144, 144), Image.Resampling.NEAREST)
                    at = ((i % 8) * 160, (i // 8) * 190)
                    board.paste(head, at, head)
                draw.text((at[0] + 4, at[1] + 147), record['name'] + ' ' + record['key'], fill='white')
                draw.text((at[0] + 4, at[1] + 163), record['label'][:22], fill='white')
            board.save(REPORT / f'heads-{start // 40}.png')
    print(f'{"CHECK" if check else "PREPARE"}: {len(routes)} original model heads; standing front pose 0:5, nearest pixels, common top alignment with neck')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    prepare(parser.parse_args().check)
