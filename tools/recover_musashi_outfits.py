"""Recover the five original equipment texture swaps without changing the rig.

Evidence: US overlay func_80145EE8 tests equipment flags, then func_80146014
walks RECT/destination records and calls MoveImage. Coordinates are VRAM words,
not decoded pixels. This reproduces that operation before CLUT decoding.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct

from PIL import Image

OVERLAY = 'raw/SC01.CD.dir/FILE_000.dir/0.4.dec'
OVERLAY_BASE = 0x80128158
PLAYER_PAC = 'raw/MAIN.CD.dir/FILE_010'
CLUTS = (16918, 16982, 17046, 17174, 17238)
# Bit order is ascending flag number. Execution order follows func_80145EE8.
EQUIPMENT = (
    ('l_goggles', 'L-Goggles', 0x1D, 0x80180678, 2, [4]),
    ('l_belt', 'L-Belt', 0x1E, 0x80180648, 2, [9]),
    ('l_brace', 'L-Brace', 0x1F, 0x801805C8, 2, [29, 30]),
    ('l_vest', 'L-Vest', 0x20, 0x801806A8, 4, [4, 18, 19, 20]),
    ('l_shoes', 'L-Shoes', 0x21, 0x801805F8, 4, [11, 12, 27, 28]),
)
COPY_ORDER = (2, 4, 1, 0, 3)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def apply_moves(vram, width, height, moves):
    """Return a copy; snapshot each source rectangle before writing its rows."""
    if len(vram) != width * height * 2:
        raise ValueError('VRAM byte size does not match dimensions')
    result = bytearray(vram)
    for x, y, w, h, dx, dy in moves:
        if min(x, y, dx, dy) < 0 or min(w, h) <= 0 or max(x + w, dx + w) > width or max(y + h, dy + h) > height:
            raise ValueError('MoveImage rectangle outside VRAM')
        rows = [bytes(result[2*((y+j)*width+x):2*((y+j)*width+x+w)]) for j in range(h)]
        for j, row in enumerate(rows):
            offset = 2 * ((dy + j) * width + dx)
            result[offset:offset + len(row)] = row
    return result


def decode_page(vram, tpage, clut):
    """Decode original PS1 RGB555/4bpp into one 256-square RGBA atlas."""
    if (tpage >> 7) & 3:
        raise ValueError('Resident Musashi materials use four-bit texture pages')
    words = struct.unpack('<524288H', vram)
    px, py = (tpage & 15) * 64, ((tpage >> 4) & 1) * 256
    cx, cy = (clut & 63) * 16, (clut >> 6) & 511
    palette = []
    for word in words[cy * 1024 + cx:cy * 1024 + cx + 16]:
        rgb = [(word >> shift) & 31 for shift in (0, 5, 10)]
        palette.append(tuple((value << 3) | (value >> 2) for value in rgb) + (255 if word else 0,))
    pixels = bytearray()
    for y in range(256):
        for x in range(256):
            word = words[((py + y) % 512) * 1024 + (px + x // 4) % 1024]
            pixels.extend(palette[(word >> ((x & 3) * 4)) & 15])
    return Image.frombytes('RGBA', (256, 256), bytes(pixels))


def load_vram(pac):
    """Replay type-zero tile uploads directly from the original PAC headers."""
    vram = bytearray(1024 * 512 * 2)
    provenance = []
    offset = 0
    while True:
        if pac[offset:offset + 4] != b'PAC\0':
            raise ValueError('Invalid PAC magic')
        kind, last = pac[offset + 4:offset + 6]
        count, length = struct.unpack_from('<2I', pac, offset + 8)
        if length < 2048 or offset + length > len(pac):
            raise ValueError('Invalid PAC length')
        if kind == 0:
            mask = pac[offset + 16:offset + 80]
            tiles = [i for i in range(512) if mask[i // 8] & (1 << (i & 7))]
            assert len(tiles) == count and count * 2048 == length - 2048
            for ordinal, index in enumerate(tiles):
                x, y = (index % 32) * 32, (index // 32) * 32
                start = offset + 2048 + ordinal * 2048
                tile = pac[start:start + 2048]
                for row in range(32):
                    dest = 2 * ((y + row) * 1024 + x)
                    vram[dest:dest + 64] = tile[row * 64:(row + 1) * 64]
                provenance.append({'tile': index, 'rect': [x, y, 32, 32], 'pac_offset': start, 'sha256': sha256(tile)})
        if last:
            break
        offset += (length + 2047) & ~2047
    return vram, provenance


def recover(recovery, output, model=None):
    recovery, output = Path(recovery), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    overlay = (recovery / OVERLAY).read_bytes()
    pac = (recovery / PLAYER_PAC).read_bytes()
    base, tiles = load_vram(pac)
    visual = json.loads((recovery / 'visual_manifest.json').read_text())
    cached = next(v for v in visual['vram_uploads'] if v['source'] == PLAYER_PAC)
    assert bytes(base) == (recovery / cached['vram']).read_bytes(), 'Direct PAC replay disagrees with earlier independent extraction'
    resident_source = 'raw/MAIN.CD.dir/FILE_010.dir/1.1'
    resident = (recovery / resident_source).read_bytes()
    part_list_offset = 0x800DE2A4 - 0x800CEDF8
    addresses = struct.unpack_from('<32I', resident, part_list_offset)
    assert addresses[-1] == 0
    models = {model['id']: model for model in visual['models']}
    occurrences = {0x800CEDF8 + item['offset']: item for item in visual['model_occurrences'] if item['source'] == resident_source}
    geometry = []
    for index, address in enumerate(addresses[:-1]):
        occurrence = occurrences[address]
        original = resident[address - 0x800CEDF8:address - 0x800CEDF8 + occurrence['length']]
        expected = models[occurrence['model']]['sha256_tmd']
        assert sha256(original) == expected
        geometry.append({'part_index': index, 'source_address': hex(address), 'byte_length': len(original), 'tmd_sha256': expected})
    palettes = {}
    for clut in CLUTS:
        x, y = (clut & 63) * 16, (clut >> 6) & 511
        offset = (y * 1024 + x) * 2
        palettes[str(clut)] = {'rect': [x, y, 16, 1], 'rgb555_sha256': sha256(base[offset:offset + 32])}
    equipment = []
    for bit, (key, label, flag, address, count, parts) in enumerate(EQUIPMENT):
        moves = []
        for index in range(count + 1):
            offset = address - OVERLAY_BASE + index * 16
            x, y, w, h, dx, dy = struct.unpack_from('<4H2I', overlay, offset)
            if index == count:
                assert (x, y, w, h, dx, dy) == (0, 0, 0, 0, 0, 0)
                break
            assert h and w
            pixels = b''.join(base[2*((y+j)*1024+x):2*((y+j)*1024+x+w)] for j in range(h))
            moves.append({'record_address': hex(OVERLAY_BASE + offset), 'source': [x, y, w, h], 'destination': [dx, dy], 'source_sha256': sha256(pixels)})
        tuples = [(*m['source'], *m['destination']) for m in moves]
        changed = apply_moves(base, 1024, 512, tuples)
        equipment.append({'id': key, 'label': label, 'flag': hex(flag), 'mask_bit': bit,
                          'copy_list_address': hex(address), 'moves': moves,
                          'source_part_indices': parts,
                          'changed_vram_words': sum(a != b for a, b in zip(struct.unpack('<524288H', base), struct.unpack('<524288H', changed)))})
    looks = []
    pages = {}
    for mask in range(32):
        enabled = [i for i in range(5) if mask & (1 << i)]
        moves = [(*m['source'], *m['destination']) for i in COPY_ORDER if i in enabled for m in equipment[i]['moves']]
        vram = apply_moves(base, 1024, 512, moves)
        textures = {}
        for clut in CLUTS:
            image = decode_page(vram, 24, clut)
            digest = sha256(image.tobytes())
            relative = 'pages/' + digest[:20] + '.png'
            target = output / relative
            if not target.exists():
                target.parent.mkdir(exist_ok=True)
                image.save(target)
            pages[relative] = {'rgba_sha256': digest, 'png_sha256': sha256(target.read_bytes()), 'width': 256, 'height': 256}
            textures[str(clut)] = relative
        looks.append({'id': 'equipment_%02x' % mask, 'mask': mask,
                      'equipment': [equipment[i]['id'] for i in enabled],
                      'pages': textures, 'vram_sha256': sha256(vram),
                      'changed_vram_words': sum(a != b for a, b in zip(struct.unpack('<524288H', base), struct.unpack('<524288H', vram)))})
    text_source = 'raw/SC04.CD.dir/FILE_028.dir/2.1'
    text = (recovery / text_source).read_bytes()
    assert b'L-Cloth' in text and b'miraculous powers' in text and b'L-Vest' in text and b'L-Shoes' in text
    for item in equipment:
        encoded_name = b'\x01\x02' + item['label'].encode() + b'\x01\x01'
        offset = text.index(encoded_name)
        item['usa_name_evidence'] = {'source': text_source, 'offset': offset, 'encoded_bytes_hex': encoded_name.hex()}
    equipment[3]['usa_name_evidence']['also_named_in_equip_message'] = 'L-Armor'
    quilt_source = 'raw/SC01.CD.dir/FILE_009.dir/0.4.dec'
    quilt_text = (recovery / quilt_source).read_bytes()
    assert b'Legendary Cloth' in quilt_text and b'Legendary Quilt' in quilt_text and b'It returns tiredness to 0%' in quilt_text
    model = Path(model) if model else Path(__file__).resolve().parents[1] / 'assets/characters/recovered_musashi/musashi.glb'
    glb = model.read_bytes()
    json_size = struct.unpack_from('<I', glb, 12)[0]
    doc, binary = json.loads(glb[20:20 + json_size]), glb[28 + json_size:]
    original_materials, original_textures = [], {}
    png_files = {sha256(path.read_bytes()): path.name for path in model.parent.glob('*.png')}
    for index, material in enumerate(doc['materials']):
        texture = material.get('pbrMetallicRoughness', {}).get('baseColorTexture')
        if texture is None:
            continue
        assert material['name'].startswith('tpage_24_clut_')
        clut = int(material['name'].split('_')[-1].split('.')[0])
        image = doc['images'][doc['textures'][texture['index']]['source']]
        view = doc['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        png = binary[start:start + view['byteLength']]
        digest = sha256(png)
        decoded = Image.open(io.BytesIO(png)).convert('RGBA')
        base_page = Image.open(output / looks[0]['pages'][str(clut)]).convert('RGBA')
        assert decoded.tobytes() == base_page.tobytes(), 'Base outfit must reproduce embedded original texture'
        binding = {'clut': clut, 'original_png_sha256': digest, 'rgba_sha256': sha256(decoded.tobytes())}
        original_materials.append({'material_index': index, 'material_name': material['name'], **binding})
        if digest in png_files:
            original_textures[png_files[digest]] = binding
    assert len(original_textures) == 5
    report = {'format_version': 1, 'kind': 'original_equipment_texture_variants',
              'sources': {PLAYER_PAC: sha256(pac), resident_source: sha256(resident), OVERLAY: sha256(overlay), text_source: sha256(text), quilt_source: sha256(quilt_text)},
              'base_vram_sha256': sha256(base), 'source_tiles': tiles,
              'source_palettes': palettes, 'source_geometry': geometry,
              'part_list': {'source_address': '0x800de2a4', 'sha256': sha256(resident[part_list_offset:part_list_offset + 128]), 'count': 31},
              'source_functions': {'equipment_dispatch': '0x80145ee8', 'moveimage_list_walker': '0x80146014', 'flag_reader': '0x80029178', 'flag_array': '0x800ae648'},
              'copy_order': [equipment[i]['id'] for i in COPY_ORDER],
              'equipment': equipment, 'looks': looks, 'texture_pages': pages,
              'original_material_bindings': original_materials, 'original_texture_bindings': original_textures,
              'non_costume_items': {'l_cloth': {'label': 'L-Cloth', 'wearable': False, 'evidence': text_source + ':0x1e27; crafting material. ' + quilt_source + ':0x6278d identifies Legendary Cloth; Weaver Dinneretta makes Legendary Quilt.'}, 'legendary_quilt': {'label': 'Legendary Quilt', 'wearable': False, 'flag': '0x1b', 'evidence': quilt_source + ':0x628de; restores tiredness twice as fast plus HP/BP. func_8014ADE0/func_8014B7A4 check flag0x1b for sleep recovery; absent from five wearable texture swaps.'}, 'a_boots': {'label': 'A-Boots', 'wearable': False, 'evidence': text_source + ':0x1e86; appraised antique item, absent from player appearance dispatch'}},
              'integration': {'tpage': 24, 'clut_to_material': 'Match original material name tpage_24_clut_<CLUT>, allowing .NNN suffix. Replace albedo_texture on every matching surface with that look.pages[CLUT]. Keep original geometry, UVs, vertex colours, rig and motions.', 'texture_base': 'res://assets/characters/recovered_musashi/outfits/', 'mask_bits': 'Each equipment entry gives mask_bit; choose looks[mask]. Read equipment_00 for base and equipment_1f for all five.', 'scope': '32 independently selectable combinations of five verified original equipment swaps; this is not evidence of 32 named story costumes. L-Cloth and antique clothes are not invented skins.'}}
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recovery', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = recover(args.recovery, args.output)
    (args.output.parent / 'outfit_sources.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'equipment': len(report['equipment']), 'combinations': len(report['looks']), 'unique_texture_pages': len(report['texture_pages'])}, indent=2))


if __name__ == '__main__':
    main()
