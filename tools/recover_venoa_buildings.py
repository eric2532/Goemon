"""Recover Venoa's visible building outlines and opaque native surface paint."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image
from recover_venoa_walls import solid_native_paint

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/maps/falan'
# Source pixels: left/near/right feet; visible end-gable outline and rear ridge.
FORMS = {
    11276: dict(floor=[[24,316],[172,435],[312,337]], end='right',
                roof=[[171,327],[191,295],[218,246],[243,210],[269,184],[293,193],[319,205],[338,213]], peak=4, rear=[121,65],
                pots=[dict(base=[98,150],top=[98,45],width=3.0,holes=[[84,13],[105,4]]),
                      dict(base=[254,416],top=[254,159],width=3.0,holes=[[242,126],[264,116]],ground=True)],
                porches=[dict(face='left',anchor=[74,267],roof=[[41,241],[72,225],[110,285]],peak=1,rear=[89,213])]),
    11279: dict(floor=[[28,322],[164,416],[326,300]], end='left',
                roof=[[2,196],[22,186],[45,172],[63,184],[88,215],[118,256],[144,287],[166,305]], peak=2,rear=[246,34],
                flues=[[[87,151],[87,111],2.5],[[195,74],[195,29],2.5],[[155,216],[155,166],2.5],[[261,134],[261,80],2.5]],
                porches=[dict(face='left',anchor=[93,278],roof=[[32,258],[94,198],[135,278]],peak=1,rear=[115,183]),
                         dict(face='right',anchor=[277,253],roof=[[228,239],[276,179],[316,207]],peak=1,rear=[255,164])]),
    11280: dict(floor=[[18,289],[173,405],[316,310]], end='right',
                roof=[[181,318],[199,286],[226,237],[249,196],[273,151],[296,170],[330,189],[366,207]],peak=4,rear=[129,37],
                pots=[dict(base=[115,107],top=[115,43],width=3.0,holes=[[105,17],[126,4]]),
                      dict(base=[225,197],top=[225,126],width=3.0,holes=[[216,99],[237,91]])]),
    11283: dict(floor=[[22,319],[161,419],[318,309]], end='right',
                roof=[[196,327],[211,292],[237,243],[262,196],[288,150],[314,169],[341,190],[368,205]],peak=4,rear=[156,55],
                back_roof=[[8,174],[25,150],[65,111],[112,75],[156,55],[181,70],[209,92],[237,110]],
                dormers=[dict(face='left',anchor=[90,104],roof=[[56,65],[70,48],[84,40],[100,52],[112,74]],peak=2,rear=[149,0]),
                         dict(face='left',anchor=[211,195],roof=[[182,163],[197,144],[211,136],[228,150],[240,171]],peak=2,rear=[281,96])]),
    11284: dict(floor=[[64,519],[183,617],[558,334]],end='left',
                roof=[[2,353],[21,340],[44,327],[62,326],[88,355],[119,396],[148,438],[182,472]],peak=3,rear=[485,16],bottom=3.0,
                dormers=[dict(face='right',anchor=[325,237],roof=[[292,186],[309,167],[326,157],[344,174],[348,199]],peak=2,rear=[252,110])],
                flues=[[[126,299],[126,263],2.2],[[188,264],[188,221],2.2],[[392,104],[392,66],2.2],[[447,64],[447,30],2.2]],
                supports=[[64,516],[184,611],[282,522],[356,465],[563,332]],
                stairs=[[[282,466],[319,440],[367,518],[329,546]],[[475,331],[512,305],[560,383],[522,411]]]),
    11286: dict(floor=[[28,257],[188,366],[333,264]],end='left',
                roof=[[4,126],[35,120],[74,110],[118,95],[146,148],[172,207],[196,272]],peak=3,rear=[252,29],
                yard=[[192,366],[216,390],[374,286]],yard_post=[361,291],
                bell=dict(face='left',anchor=[139,101],roof=[[112,35],[132,20],[145,59]],peak=1,rear=[156,5],center=[130,57])),
}


def dark_pigment(original, pixel):
    px, py = pixel
    candidates = [(x, y) for y in range(max(0, py-12), min(original.height, py+13))
                  for x in range(max(0, px-12), min(original.width, px+13))
                  if (lambda p: p[3] == 255 and max(p[:3]) <= 65)(original.getpixel((x, y)))]
    assert candidates, ('Missing native flue interior', pixel)
    return list(min(candidates, key=lambda p: (p[0]-px)**2 + (p[1]-py)**2))


def prepare(source):
    sys.path.insert(0, str(source / 'tools'))
    import cg_library as library
    lookup = library.serial_index()
    placements, images, records = {}, {}, {}
    x = y = row_height = 0
    for serial, form in FORMS.items():
        form = json.loads(json.dumps(form))
        entry = lookup[serial]
        original = library.image_from_record(entry['pack'], entry['row'])
        paint, shadow_pixels = solid_native_paint(original)
        if x + original.width + 4 > 1024:
            x = 0
            y += row_height
            row_height = 0
        rect = [x + 2, y + 2, original.width, original.height]
        placements[serial] = rect
        images[serial] = paint
        x += original.width + 4
        row_height = max(row_height, original.height + 4)
        east, south = max(1, entry['east']), max(1, entry['south'])
        origin = [-entry['x'] + (east - south) * 16, -entry['y'] - (east + south - 2) * 12]
        points = form['floor'] + form['roof'] + [form['rear']]
        assert all(0 <= px < original.width and 0 <= py < original.height for px, py in points), serial
        assert all(a[0] < b[0] for a, b in zip(form['roof'], form['roof'][1:])), serial
        for flue in form.get('flues', []):
            flue.append(dark_pigment(original, flue[1]))
        records[serial] = {'pack': entry['pack'], 'row': entry['row'],
                           'rgba_sha256': hashlib.sha256(original.tobytes()).hexdigest(), 'ground_shadow_pixels': shadow_pixels,
                           'rect': rect, 'origin': origin, **form}
    atlas = Image.new('RGBA', (1024, y + row_height))
    for serial, paint in images.items():
        ax, ay, _, _ = placements[serial]
        atlas.paste(paint, (ax, ay))
    rows = ['extends RefCounted', '## Generated by tools/recover_venoa_buildings.py; source-visible forms.',
            'const ATLAS=preload("res://assets/maps/falan/venoa_buildings.png")', 'const FORMS={']
    for serial, record in records.items():
        runtime = {key: value for key, value in record.items() if key not in ['pack', 'row', 'rgba_sha256', 'ground_shadow_pixels']}
        rows.append(f' {serial}:' + json.dumps(runtime, separators=(',', ':')) + ',')
    rows.append('}')
    meta = {'graphics': records, 'height_per_pixel': .045,
            'method': 'Visible native foundations, end-gable curves, rear ridges and roof-furniture stations. Hidden volume, concealed supports and rear paint remain fitted 3D interpretations. No collision or route data is generated.'}
    return atlas, '\n'.join(rows) + '\n', meta


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT.parent / 'Magic Power')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    atlas, data, meta = prepare(args.source.resolve())
    path = OUT / 'venoa_buildings'
    if args.check:
        with Image.open(path.with_suffix('.png')) as actual:
            assert actual.tobytes() == atlas.tobytes()
        assert path.with_suffix('.gd').read_text() == data
        assert json.loads(path.with_suffix('.json').read_text()) == json.loads(json.dumps(meta))
        print('PASS: six native Venoa building forms and opaque paint reproduce exactly')
    else:
        atlas.save(path.with_suffix('.png'), optimize=True)
        path.with_suffix('.gd').write_text(data)
        path.with_suffix('.json').write_text(json.dumps(meta, indent=2) + '\n')
        print('Prepared six Venoa building variants; original art preserved')


if __name__ == '__main__':
    main()
