"""Read-only native252 attributes and exact Il BG/PG1 context, never a route repair."""
import ast
import hashlib
import json
from pathlib import Path
import struct
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Whole Shore Candidate'


def main():
    sys.path.insert(0, str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    path = ROOT/'assets/maps/falan/east_region/il_source_completion/hybrid-map.bin'
    raw = path.read_bytes(); width, height = struct.unpack_from('<II', raw, 12); count = width*height
    values = struct.unpack_from(f'<{count*3}H', raw, 20); table = lib.serial_index(); images = {}
    def image(serial):
        if serial not in images:
            graphic = table[serial]; images[serial] = lib.image_from_record(graphic['pack'], graphic['row']).convert('RGBA')
        return images[serial]
    references = []
    for cx, cz in [(27, 20), (59, 25), (77, 70)]:
        background = Image.new('RGBA', (1000, 750), '#203742')
        for plane in range(2):
            target = background if plane == 0 else background.copy(); rows = []
            for z in range(max(0, cz-6), min(height, cz+7)):
                for x in range(max(0, cx-6), min(width, cx+7)):
                    serial = values[plane*count+z*width+x]
                    if serial < 1000 or serial not in table: continue
                    rows.append((z*11-x*9, x+z, x, z, serial))
            for _, _, x, z, serial in sorted(rows):
                graphic = table[serial]
                target.alpha_composite(image(serial), ((x+z-cx-cz)*32+graphic['x']+500, (z-x-cz+cx)*24+graphic['y']+375))
            if plane == 0: background = target.copy()
            draw = ImageDraw.Draw(target); draw.ellipse((497, 372, 503, 378), outline='red', width=2)
            draw.text((15, 15), f'Original Il {cx},{cz}: BG'+(' +nativePG1; serial<1000 controls omitted' if plane else ' only'), fill='white')
            output = OUT/(f'252-context-{cx}-{cz}-'+('both.jpg' if plane else 'bg.jpg'))
            target.convert('RGB').save(output, quality=94); references.append(str(output.relative_to(ROOT)))
    native = image(252); native.save(OUT/'252-native.png')
    attrs = {}
    for serial in [2, 100, 252, 5000, 5045, 12502]:
        row = table[serial]
        attrs[str(serial)] = {'record': row, 'raw_attribute_bytes': list(lib.cg.RECORD.unpack_from(lib.cg.graphic_index(row['pack'])[0], row['row']*40)[7])}
    helper = ROOT.parent/'Magic Power/tools/prepare_field_assets.py'
    node = next(node for node in ast.parse(helper.read_text()).body if isinstance(node, ast.FunctionDef) and node.name == 'navigation_grid')
    navigation = ast.get_source_segment(helper.read_text(), node)
    controls = [{'cell': [i % width, i // width], 'BG': values[i], 'object': 252, 'marker': values[count*2+i]} for i in range(count) if values[count+i] == 252]
    assert len(controls) == 242
    result = {'source': 2000, 'source_hybrid_sha256': hashlib.sha256(raw).hexdigest(), 'native252_rgba_sha256': hashlib.sha256(native.tobytes()).hexdigest(),
              'native252_size': list(native.size), 'attributes': attrs, 'all242controls': controls, 'native_references': references,
              'navigation_helper_path': str(helper), 'navigation_helper_sha256': hashlib.sha256(helper.read_bytes()).hexdigest(), 'navigation_helper': navigation,
              'confirmed': ['Native252 has raw attribute[2]=1; native water5000 has0. Existing navigation helper explicitly ORs ground/object attribute[2], and ignores<1000object footprints except serial2.',
                            'All242 Il252object rows remain source controls, not visible bank geometry. Runtime Il scenery lists exclude<1000 serials.'],
              'limit': 'This proves current source-attribute interpretation, not original executable height/client behavior. A3D floor height is absent from these native2D bytes. Current actual model/native/physics measurements are still required; no source-open252control is converted to a bank or a bridge.'}
    (OUT/'252-source-contract.json').write_text(json.dumps(result, indent=2)+'\n')
    print('Il252read-only source contract:', len(controls), 'controls; no runtime/physics changes.')


if __name__ == '__main__': main()
