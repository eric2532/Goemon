"""Keep the recovered quest bag's original item pictures separate from equipment."""
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan/east_region'
REPORT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Quest Items'


def prepare():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    raw = (OUT / 'items.json').read_bytes()
    items = json.loads(raw)['items']
    lookup = lib.serial_index()
    pictures, records, missing = {}, {}, []
    for serial in sorted({int(r['icon']) for r in items.values()}):
        if serial not in lookup:
            with lib.connection() as db:
                row = db.execute('SELECT pack,row,serial,x,y,w,h FROM graphics WHERE serial=? ORDER BY pack_order,row LIMIT 1', (serial,)).fetchone()
            if row is not None:
                lookup[serial] = dict(row)
        if serial not in lookup:
            missing.append(serial)
            continue
        source = lookup[serial]
        try:
            image = lib.image_from_record(source['pack'], source['row'])
        except ValueError:
            missing.append(serial)
            continue
        bounds = image.getbbox()
        if bounds is None:
            missing.append(serial)
            continue
        image = image.crop(bounds)
        pictures[serial] = image
        records[str(serial)] = dict(pack=source['pack'], row=source['row'], rgba_sha256=hashlib.sha256(image.tobytes()).hexdigest())
    x = y = row_height = 0
    for serial, image in pictures.items():
        if x + image.width + 2 > 1024:
            x = 0; y += row_height; row_height = 0
        records[str(serial)]['rect'] = [x + 1, y + 1, image.width, image.height]
        x += image.width + 2; row_height = max(row_height, image.height + 2)
    atlas = Image.new('RGBA', (1024, max(1, y + row_height)))
    for serial, image in pictures.items():
        atlas.paste(image, tuple(records[str(serial)]['rect'][:2]))
    atlas.save(OUT / 'item-icons.png')
    data = dict(schema=1, item_data_sha256=hashlib.sha256(raw).hexdigest(), art=records, missing=missing,
                limits=['Only exact original graphic IDs are used. Missing pictures remain absent; item names and behavior are retained.'])
    (OUT / 'item-icons.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    REPORT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGB', (800, ((len(pictures) + 15) // 16) * 68), '#28362f')
    draw = ImageDraw.Draw(sheet)
    for i, (serial, image) in enumerate(pictures.items()):
        image = image.copy(); image.thumbnail((46, 46), Image.Resampling.NEAREST)
        at = ((i % 16) * 50, (i // 16) * 68)
        sheet.paste(image, (at[0] + (50 - image.width) // 2, at[1]), image)
        draw.text((at[0], at[1] + 48), str(serial), fill='white')
    sheet.save(REPORT / 'original-item-icons.png')
    (REPORT / 'icon-preservation.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print('EAST_ITEM_ICONS', len(records), 'exact source graphics;', len(missing), 'unavailable IDs')


if __name__ == '__main__':
    prepare()
