"""Extract Ed's unconverted integer TMD packets and raw palette/index buffers.

Uses the established packet/tmd parsers without running their asset-scan module.
Every polygon and position/normal record is re-encoded and compared to the ROM.
"""
from pathlib import Path
import argparse
import ast
import hashlib
import json
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
RECOVERY = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery')
SOURCE = 'raw/SC06.CD.dir/FILE_016.dir/0.4.dec'
SOURCE_SHA = '85b54829995fc482dd673019f5c9fed052f618f5f5de65f95d9d50e66c93f98c'
BASE = 0x80128158
ADDRESSES = {'main': 0x801913BC, 'companion': 0x80191CC4, 'shield': 0x80192B24}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def original_parser(recovery):
    path = recovery / 'tools/recover_visuals.py'
    source = path.read_text()
    tree = ast.parse(source, filename=str(path))
    functions = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in ('packet', 'tmd')]
    assert len(functions) == 2
    scope = {'struct': struct}
    exec(compile(ast.Module(body=functions, type_ignores=[]), str(path), 'exec'), scope)
    return scope['tmd'], sha(source.encode())


def extract_model(blob, address, parse):
    offset = address - BASE
    model = parse(blob, offset)
    assert len(model['objects']) == 1
    obj = model['objects'][0]
    vt, nv, nt, nn, pt, np, scale = struct.unpack_from('<6Ii', blob, offset + 12)
    assert scale == 0 and nv == len(obj['vertices']) and nn == len(obj['normals'])
    cursor = offset + 12 + pt
    primitives = []
    for parsed in obj['primitives']:
        olen, ilen, flag, mode = struct.unpack_from('<4B', blob, cursor)
        end = cursor + 4 + 4 * ilen
        count = len(parsed['vertices'])
        lit, smooth, textured = not flag & 1, bool(mode & 16), bool(mode & 4)
        pos = cursor + 4
        uv_words = []
        if textured:
            uv_words = [list(struct.unpack_from('<2BH', blob, pos + 4 * i)) for i in range(count)]
            pos += 4 * count
        stored_colors = []
        if (lit and not textured) or not lit:
            number = count if flag & 4 or (not lit and smooth) else 1
            stored_colors = [list(blob[pos + 4 * i:pos + 4 * i + 4]) for i in range(number)]
            pos += 4 * number
        encoded = bytearray(struct.pack('<4B', olen, ilen, flag, mode))
        for word in uv_words:
            encoded.extend(struct.pack('<2BH', *word))
        for color in stored_colors:
            encoded.extend(bytes(color))
        if lit and smooth:
            for n, v in zip(parsed['normals'], parsed['vertices']):
                encoded.extend(struct.pack('<2H', n, v))
            pos += 4 * count
        elif lit:
            encoded.extend(struct.pack('<H', parsed['normals'][0]))
            encoded.extend(struct.pack('<' + 'H' * count, *parsed['vertices']))
            pos += 2 + 2 * count
        else:
            encoded.extend(struct.pack('<' + 'H' * count, *parsed['vertices']))
            pos += 2 * count
        padding = blob[pos:end]
        encoded.extend(padding)
        raw = blob[cursor:end]
        assert bytes(encoded) == raw, hex(BASE + cursor)
        primitive = dict(parsed)
        primitive.update(olen=olen, ilen=ilen, packet_address=BASE + cursor,
                         packet_hex=raw.hex(), colors_explicit=bool(stored_colors),
                         uv_words=uv_words, stored_colors=stored_colors,
                         padding_hex=padding.hex(), corner_triangles=[[0, 1, 2], [1, 3, 2]] if count == 4 else [[0, 1, 2]])
        primitives.append(primitive)
        cursor = end
    assert len(primitives) == np and cursor == offset + 12 + vt
    vertex_records = [struct.unpack_from('<3hH', blob, offset + 12 + vt + i * 8) for i in range(nv)]
    normal_records = [struct.unpack_from('<3hH', blob, offset + 12 + nt + i * 8) for i in range(nn)]
    assert [list(record[:3]) for record in vertex_records] == [list(v) for v in obj['vertices']]
    assert [list(record[:3]) for record in normal_records] == [list(n) for n in obj['normals']]
    for records, pointer in [(vertex_records, vt), (normal_records, nt)]:
        assert b''.join(struct.pack('<3hH', *record) for record in records) == blob[offset + 12 + pointer:offset + 12 + pointer + 8 * len(records)]
    raw = blob[offset:offset + model['length']]
    return {'tmd_address': address, 'tmd_sha256': sha(raw), 'tmd_byte_length': len(raw),
            'tmd_header_hex': raw[:40].hex(), 'scale': scale,
            'vertices': obj['vertices'], 'normals': obj['normals'],
            'vertex_padding': [v[3] for v in vertex_records],
            'normal_padding': [n[3] for n in normal_records], 'primitives': primitives}


def texture_buffers(recovery, blob):
    sys.path.insert(0, str(recovery / 'tools/BFM-decomp/tools'))
    from bfm_extract.pac import split_pac
    pac = (recovery / 'raw/SC06.CD.dir/FILE_016').read_bytes()
    vram = bytearray(1024 * 512 * 2)
    coverage = bytearray(1024 * 512)

    def upload(x, y, width, height, pixels):
        assert len(pixels) == width * height * 2
        for row in range(height):
            start = (y + row) * 1024 + x
            vram[start * 2:(start + width) * 2] = pixels[row * width * 2:(row + 1) * width * 2]
            coverage[start:start + width] = b'\1' * width

    for entry in split_pac(pac):
        if entry.type == 0:
            tiles = [i for i in range(512) if pac[entry.offset + 16 + i // 8] & (1 << (i % 8))]
            assert len(tiles) == entry.unknown and len(tiles) * 2048 == len(entry.payload)
            for n, tile in enumerate(tiles):
                upload((tile % 32) * 32, (tile // 32) * 32, 32, 32, entry.payload[n * 2048:(n + 1) * 2048])
        elif entry.type == 6:
            cursor = entry.offset + 160
            for i in range(entry.unknown):
                x, y, width, height = struct.unpack_from('<4H', pac, entry.offset + 16 + i * 8)
                upload(x, y, width, height, pac[cursor:cursor + width * height * 2])
                cursor += width * height * 2
    indices = bytearray(256 * 256)
    for y in range(256):
        for x in range(256):
            word = struct.unpack_from('<H', vram, ((y + 256) * 1024 + 704 + x // 4) * 2)[0]
            indices[y * 256 + x] = (word >> ((x % 4) * 4)) & 15
    main = struct.unpack_from('<16H', blob, 0x80188E6C - BASE)
    palettes = b''.join(struct.pack('<16H', *(main[(i - frame - 1) & 15] for i in range(16))) for frame in range(16))
    palettes += blob[0x80188EAC - BASE:0x80188EAC - BASE + 8 * 16 * 2]
    assert len(indices) == 65536 and len(palettes) == 768
    return bytes(indices), palettes, coverage, sha(pac)


def recover(recovery, output):
    blob = (recovery / SOURCE).read_bytes()
    assert sha(blob) == SOURCE_SHA
    parse, parser_sha = original_parser(recovery)
    models = {name: extract_model(blob, address, parse) for name, address in ADDRESSES.items()}
    indices, palettes, coverage, pac_sha = texture_buffers(recovery, blob)
    for name in ('main', 'companion'):
        for primitive in models[name]['primitives']:
            assert primitive['tpage'] == 0x3B
            xs, ys = zip(*primitive['uv'])
            for y in range(min(ys), max(ys) + 1):
                for x in range(min(xs), max(xs) + 1):
                    assert coverage[(y + 256) * 1024 + 704 + x // 4]
    manifest = json.loads((recovery / 'visual_manifest.json').read_text())
    for name, address in ADDRESSES.items():
        occurrence = next(o for o in manifest['model_occurrences'] if o['source'] == SOURCE and o['offset'] == address - BASE)
        record = next(m for m in manifest['models'] if m['id'] == occurrence['model'])
        assert models[name]['tmd_sha256'] == record['sha256_tmd']
    # Independently compare the raw PAC output to the already recovered data PNG.
    from PIL import Image
    reference = ROOT / 'assets/characters/recovered_leaders/ed/beam'
    png_indices = Image.open(reference / 'indices.png').convert('RGBA')
    assert png_indices.size == (256, 256)
    assert bytes(pixel[0] for pixel in png_indices.getdata()) == indices
    palette_words = struct.unpack('<384H', palettes)
    for name, start, count in [('main_palettes.png', 0, 256), ('companion_palettes.png', 256, 128)]:
        png = Image.open(reference / name).convert('RGBA')
        assert png.size == (16, count // 16)
        pixels = list(png.getdata())
        for pixel, word in zip(pixels, palette_words[start:start + count]):
            expected = tuple((((word >> bit) & 31) << 3) | (((word >> bit) & 31) >> 2) for bit in (0, 5, 10)) + (255 if word else 0,)
            assert pixel == expected
    output.mkdir(parents=True, exist_ok=True)
    (output / 'indices.bin').write_bytes(indices)
    (output / 'palettes.bin').write_bytes(palettes)
    data = {'version': 1, 'source': SOURCE, 'source_sha256': SOURCE_SHA, 'load_base': BASE,
            'coordinates': 'Unconverted signed source x,y,z integers. Positions in original source units; normals in Q12. No axis flip, scale, pose, float normalization or triangulation applied.',
            'parser': {'source': 'Musashi Asset Recovery/tools/recover_visuals.py packet/tmd functions', 'sha256': parser_sha},
            'models': models,
            'texture': {'width': 256, 'height': 256, 'indices_file': 'indices.bin', 'indices_sha256': sha(indices),
                        'indices_encoding': 'One byte per4bpp index0..15, row major, native TPAGE0x3B at VRAMword704,256.',
                        'source_pac': 'raw/SC06.CD.dir/FILE_016', 'source_pac_sha256': pac_sha,
                        'palettes_file': 'palettes.bin', 'palettes_sha256': sha(palettes), 'palette_rows': 24, 'palette_width': 16,
                        'palettes_encoding': 'Little-endian raw16-bit PSX RGB555/STP words. Rows0..15 main row=(main_updates-1)&15; rows16..23 companion row=16+(global_game_frame&7). Word0 transparent; bit15 retained.'},
            'packet_notes': {'colors': 'colors is one RGB per original corner. Lit textured packets omit stored colors; parser supplies source emitter RGB128. stored_colors preserves the original RGB/pad bytes when present.',
                             'ordering': 'Primitives remain in TMD stream order; vertices/normals/UV/colors retain original polygon corner order. corner_triangles records GPU quad subdivision only; native quad is still a single culling/order primitive.',
                             'shield': 'Original static source colors/modes are retained. Runtime80181478 replaces colors per source-Y band and sets G3/G4 semi-transparency; renderer must apply that update.'},
            'verification': {'primitives_round_tripped': sum(len(m['primitives']) for m in models.values()),
                             'vertices_round_tripped': sum(len(m['vertices']) for m in models.values()),
                             'normals_round_tripped': sum(len(m['normals']) for m in models.values()),
                             'indices_match_existing_png': True, 'palette_words_match_existing_png': 384,
                             'all_textured_polygon_bounds_covered_by_PAC': True, 'all_TMD_hashes_match_original_manifest': True}}
    (output / 'geometry.json').write_text(json.dumps(data, indent=2) + '\n')
    print(json.dumps({'geometry': str(output / 'geometry.json'), 'verification': data['verification'],
                      'models': {name: {'vertices': len(m['vertices']), 'normals': len(m['normals']), 'primitives': len(m['primitives']),
                                        'modes': sorted(set(p['mode'] for p in m['primitives'])), 'flags': sorted(set(p['flag'] for p in m['primitives']))} for name, m in models.items()},
                      'indices_sha256': sha(indices), 'palettes_sha256': sha(palettes)}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--recovery', type=Path, default=RECOVERY)
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/characters/recovered_leaders/ed/beam')
    args = parser.parse_args()
    recover(args.recovery, args.output)
