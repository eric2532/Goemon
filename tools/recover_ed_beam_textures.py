"""Recover Ed's native beam texture indices and animated CLUTs from the scene PAC.

Requires the previously extracted user disc tree, NumPy and Pillow. No pixels are
painted: texture indices come from the original PAC and palettes from its overlay.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import struct
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RECOVERY = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery')
BASE = 0x80128158
SOURCE = 'raw/SC06.CD.dir/FILE_016.dir/0.4.dec'
SOURCE_SHA = '85b54829995fc482dd673019f5c9fed052f618f5f5de65f95d9d50e66c93f98c'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def color555(values):
    values = np.asarray(values, dtype=np.uint16)
    rgb = np.stack([((values >> bit) & 31) for bit in (0, 5, 10)], axis=-1)
    rgb = ((rgb << 3) | (rgb >> 2)).astype(np.uint8)
    return np.concatenate([rgb, np.where(values == 0, 0, 255).astype(np.uint8)[..., None]], axis=-1)


def preserve_native_normals(glb_path, tmd):
    """Keep source Q12 normal bytes in a texture; COLOR_0 carries its byte index."""
    vt,nv,nt,nn,pt,count,_ = struct.unpack_from('<6Ii',tmd,12)
    cursor=12+pt; expanded=[]
    for _ in range(count):
        _,ilen,flag,mode=struct.unpack_from('<4B',tmd,cursor)
        assert not flag&1 and mode&16
        n=4 if mode&8 else 3
        pos=cursor+4+(n*4 if mode&4 else 0)
        if not mode&4:pos+=4*(n if flag&4 else 1)
        normal_indices=[struct.unpack_from('<H',tmd,pos+i*4)[0] for i in range(n)]
        for triangle in (((0,1,2),(1,3,2)) if n==4 else ((0,1,2),)):
            for i in triangle:
                expanded.append([normal_indices[i]/255,0,0])
        cursor+=4+ilen*4
    data=glb_path.read_bytes();length=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+length]); binary=bytearray(data[28+length:])
    primitive=doc['meshes'][0]['primitives'];assert len(primitive)==1
    accessor=doc['accessors'][primitive[0]['attributes']['COLOR_0']]
    assert accessor['count']==len(expanded) and accessor['type']=='VEC3'
    offset=doc['bufferViews'][accessor['bufferView']].get('byteOffset',0)+accessor.get('byteOffset',0)
    for i,normal in enumerate(expanded):struct.pack_into('<3f',binary,offset+i*12,*normal)
    normal_bytes=np.zeros((nn,2,4),dtype=np.uint8);normal_bytes[:,:,3]=255
    for i in range(nn):
        x,y,z=struct.unpack_from('<3h',tmd,12+nt+i*8)
        words=[x+4096,-y+4096,-z+4096]
        normal_bytes[i,0,:3]=[v&255 for v in words]
        normal_bytes[i,1,:3]=[v>>8 for v in words]
    Image.fromarray(normal_bytes).save(glb_path.with_name(glb_path.stem+'_normals.png'))
    doc['asset']['extras']={'native_normal_encoding':'COLOR_0.r=normal_index/255; *_normals.png2xN RGB bytes at x0=low,x1=high of source normal converted x,-y,-z +4096; exact Q12 data, not visible color'}
    meta=json.dumps(doc,separators=(',',':')).encode();meta+=b' '*(-len(meta)%4)
    glb_path.write_bytes(struct.pack('<3I',0x46546C67,2,28+len(meta)+len(binary))+struct.pack('<2I',len(meta),0x4E4F534A)+meta+struct.pack('<2I',len(binary),0x004E4942)+binary)
    return len(expanded)


def recover(recovery, out):
    out.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(recovery / 'tools/BFM-decomp/tools'))
    from bfm_extract.pac import split_pac
    blob = (recovery / SOURCE).read_bytes()
    assert sha(blob) == SOURCE_SHA
    pac = (recovery / 'raw/SC06.CD.dir/FILE_016').read_bytes()
    words = np.zeros((512, 1024), dtype=np.uint16)
    coverage = np.zeros((512, 1024), dtype=bool)
    for entry in split_pac(pac):
        if entry.type == 0:
            tiles = [i for i in range(512) if pac[entry.offset + 16 + i // 8] & (1 << (i % 8))]
            assert len(tiles) == entry.unknown
            assert len(tiles) * 2048 == len(entry.payload)
            for n, tile in enumerate(tiles):
                x, y = (tile % 32) * 32, (tile // 32) * 32
                words[y:y+32, x:x+32] = np.frombuffer(entry.payload, '<u2', 1024, n*2048).reshape(32, 32)
                coverage[y:y+32, x:x+32] = True
        elif entry.type == 6:
            cursor = entry.offset + 160
            for i in range(entry.unknown):
                x, y, w, h = struct.unpack_from('<4H', pac, entry.offset + 16 + i*8)
                words[y:y+h, x:x+w] = np.frombuffer(pac, '<u2', w*h, cursor).reshape(h, w)
                coverage[y:y+h, x:x+w] = True
                cursor += w*h*2
    yy, xx = np.indices((256, 256))
    packed = words[256+yy, 704+xx//4]
    indices = ((packed >> ((xx % 4)*4)) & 15).astype(np.uint8)
    # A raw data texture; red is index / 255, and must not undergo sRGB decoding.
    index_rgba = np.zeros((256, 256, 4), dtype=np.uint8)
    index_rgba[:, :, 0] = indices
    index_rgba[:, :, 3] = 255
    Image.fromarray(index_rgba).save(out / 'indices.png')
    main_words = np.frombuffer(blob, '<u2', 16, 0x80188E6C-BASE)
    # Row 0 is the first visible actor update, after phase is decremented to 15.
    main_frames = np.stack([main_words[(np.arange(16)-frame-1) & 15] for frame in range(16)])
    companion_frames = np.frombuffer(blob, '<u2', 128, 0x80188EAC-BASE).reshape(8, 16)
    assert all(np.count_nonzero(row) == 1 for row in companion_frames)
    assert set(companion_frames.ravel()) == {0, 0x811F}
    for i in range(8):
        desc = struct.unpack_from('<6HI', blob, 0x80188FAC-BASE+i*32)
        assert desc == (9, 96, 352, 352, 16, 1, 0x80188EAC+i*32)
    assert struct.unpack_from('<6HI', blob, 0x80188E8C-BASE) == (9, 95, 352, 351, 16, 1, 0x8019F9DC)
    Image.fromarray(color555(main_frames)).save(out / 'main_palettes.png')
    Image.fromarray(color555(companion_frames)).save(out / 'companion_palettes.png')
    model_manifest = json.loads((recovery / 'visual_manifest.json').read_text())
    models = {m['id']: m for m in model_manifest['models']}
    model_data = {}
    for name, address, model_id, clut, uv_rect in [
        ('main', 0x801913BC, 'model_fe1b4fc44adb4828f227', 0x57D6, (0,64,64,64)),
        ('companion', 0x80191CC4, 'model_8c8b043af0b286264b2c', 0x5816, (0,128,64,64)),
    ]:
        record = models[model_id]
        tmd = (recovery / record['tmd']).read_bytes()
        assert blob[address-BASE:address-BASE+len(tmd)] == tmd
        assert sha(tmd) == record['sha256_tmd']
        assert struct.unpack_from('<i', tmd, 36)[0] == 0
        shutil.copyfile(recovery / record['path'], out / (name + '.glb'))
        if name=='main':preserve_native_normals(out/(name+'.glb'),tmd)
        # Check every referenced textured primitive, including all interior texels
        # in its conservative UV bounding box, against PAC upload coverage.
        vt, nv, nt, nn, pt, count, scale = struct.unpack_from('<6Ii', tmd, 12)
        cursor = 12+pt
        uv_bounds = []
        modes = set()
        for _ in range(count):
            olen, ilen, flags, mode = struct.unpack_from('<4B', tmd, cursor)
            assert mode & 4
            n = 4 if mode & 8 else 3
            uv = [struct.unpack_from('<2BH', tmd, cursor+4+i*4) for i in range(n)]
            assert uv[0][2] == clut and uv[1][2] == 0x3B
            x0, x1 = min(u[0] for u in uv), max(u[0] for u in uv)
            y0, y1 = min(u[1] for u in uv), max(u[1] for u in uv)
            assert coverage[256+y0:256+y1+1, 704+x0//4:704+x1//4+1].all()
            uv_bounds.append([x0,y0,x1,y1]); modes.add(mode)
            cursor += 4+ilen*4
        assert cursor == 12+vt
        model_data[name] = {
            'tmd_address': hex(address), 'tmd_sha256': sha(tmd),
            'glb_sha256': sha((out/(name+'.glb')).read_bytes()),
            'vertices': nv, 'polygons': count, 'tmd_scale_word': scale,
            'primitive_modes': [hex(m) for m in sorted(modes)],
            'clut': hex(clut), 'tpage': '0x3b', 'bpp': 4,
            'blend_mode': 'ABR1: background + foreground (saturating)',
            'uv_bounds': [min(v[0] for v in uv_bounds), min(v[1] for v in uv_bounds), max(v[2] for v in uv_bounds), max(v[3] for v in uv_bounds)],
            'referenced_texel_coverage': 1.0,
        }
    shield_address=0x80192B24
    shield_occ=next(o for o in model_manifest['model_occurrences'] if o['source']==SOURCE and o['offset']==shield_address-BASE)
    shield_record=models[shield_occ['model']]
    shield_path=out.parent/'beam_shield.glb'
    shutil.copyfile(recovery/shield_record['path'],shield_path)
    preserve_native_normals(shield_path,(recovery/shield_record['tmd']).read_bytes())
    report = {
        'source': SOURCE, 'source_sha256': SOURCE_SHA,
        'source_pac': 'raw/SC06.CD.dir/FILE_016', 'source_pac_sha256': sha(pac),
        'texture_page': {'tpage': '0x3b', 'word_origin': [704,256], 'pixels': [256,256],
                         'indices': 'indices.png', 'encoding': 'RGBA8, red = integer index 0..15 (divide sampled red by 1/255); no sRGB conversion; nearest filtering; GLB UV uses (native_uv+0.5)/256'},
        'models': model_data,
        'coordinate_conversion': 'GLB position=(source_x,-source_y,-source_z), unscaled native units. TMDscale0. Native beam front source-Z becomes GLB+Z; rotateYPI when placing in Godot-Z direction.',
        'native_lighting': {'room_descriptor':'0x801891dc','room_lookup':'0x801457a4 → 0x80184e4c default for SC06 room IDs',
                            'light_matrix_q12':[[0,-4096,0],[0,-1365,-3900],[0,4096,0]],
                            'color_matrix_q12':[[401,2875,819],[819,2875,401],[1220,3276,1638]],
                            'background_q12':[2048,2048,2048],
                            'normal_storage':'main.glb and beam_shield.glb COLOR_0.r=normal_index/255; *_normals.png2xN stores converted native Q12 normal+4096 low RGB bytes atx0,high RGB bytes atx1. This survives Godot8-bit vertex color import exactly. Companion unlit.',
                            'matrix_stages':'Quantized actor rotation, native per-axis scale (80020F34), light matrix product (80052F04/80048EAC), normal light transform, color matrix plus background, per-channel RGB modulation; right shift12 and IR saturation at every GTE stage.',
                            'main_emitters':['0x8004fd30 NCCT@0x8004fe2c RGB128','0x800503f0 NCCS@0x80050534 NCCT@0x80050564 RGB128'],
                            'rotation_adapter':'Native roll uses literal ROM Q12 sine/cosine values without column normalization. The current port aim basis is separately quantized to Q12; this is not an emulator replay of original room actor angles.',
                            'shield_glb_sha256':sha(shield_path.read_bytes())},
        'main_palette': {'file':'main_palettes.png','source_address':'0x80188e6c','clut_vram':[352,351],
                         'source_words':[int(x) for x in main_words], 'frame_count':16,
                         'row_mapping':'row=(visible_actor_tick-1)&15; palette index i = source[(i-visible_actor_tick)&15]; actorinit phase0, decremented before upload each active update',
                         'source_functions':['0x8017f784','0x8017f858','0x8017f898'],
                         'rgba_sha256':sha(color555(main_frames).tobytes())},
        'companion_palette': {'file':'companion_palettes.png','source_address':'0x80188eac','descriptor_array':'0x80188fac','clut_vram':[352,352],
                              'source_words':companion_frames.tolist(), 'frame_count':8,
                              'row_mapping':'row=D_800B99DA&7 (global frame counter, not actor-local age)',
                              'source_function':'0x8017f694','rgba_sha256':sha(color555(companion_frames).tobytes())},
        'rgba_palette_encoding':'PSX RGB555 expanded by (v<<3)|(v>>2); alpha0 iff word==0, else255. Bit15=1 on every nonzero color; additive semi-transparency is selected by primitive bit1 and TPAGE ABR1, not alpha opacity.',
        'strips': {'renderer':'0x80180894','primitive':'POLY_G4 0x3a','textured':False,
                   'center_color_address':'0x8019e288','center_rgb':[255,64,0],
                   'edge_color_address':'0x8019e28c','edge_rgb':[0,0,0],
                   'segment0_start_rgb':[0,0,0], 'blend':'func8012E28C(depth,1) → GetTPage(0,1,0,0) → ABR1 background+foreground'},
        'shield': {'actor':'0x30a', 'tmd_address':'0x80192b24', 'initializer':'0x80182990',
                   'attribute':'0x50000000', 'renderer':'0x800243ec', 'draw_mode':'0xe100002a',
                   'blend':'ABR1 background+foreground; source has no fixed opacity factor',
                   'backface_culling':True, 'backface_evidence':'TMD flags4 lacks double-sided bit2; native G3/G4 emitters reject NCLIP<=0; recovered glTF doubleSided=false',
                   'color_update':'0x80181478', 'color_function':'0x801816dc',
                   'native_y_to_band':{'0':0,'-57':1,'-106':2,'-139':3,'-150':4},
                   'phase':'(-199*visible_actor_tick+307*band) modulo1536; visible_actor_tick starts1',
                   'rgb':'(blue>>2,blue>>1,blue); blue in six256step phases:0,ramp0..255,255,255,ramp255..0,0',
                   'release':'Subtract256 from Q12 intensity4096 per actor tick; multiply and rightshift12 each integer color channel separately, reaching0 at tick16; geometry remains full size',
                   'verification':'tools/verify_ed_beam_assets.py executes original MIPS function for all1536phases times17Q12release levels (26112cases)',
                   'rendering_limit':'Dedicated native affine RGB555 rasterization preserves the recovered foreground arithmetic. Display presentation intentionally filters that foreground and adds it to the full-resolution encoded scene without quantizing the background; camera projection and world visibility remain port adapters.'},
        'dedicated_renderer':{'backend':'native/ed_psx_renderer/ed_psx_renderer.gdextension',
                              'class':'EdPsxRasterizer',
                              'pixel_rules':'Integer screen sampling and top-left coverage; affine UV/Gouraud gradients truncated to Q12 with attribute+0.5 initialization; transparent texel zero skipped; texture modulation and RGB555 quantization per primitive before saturating ABR1 accumulation.',
                              'buffer':'RGBA8 data: RGB bytes0..31 saturated foreground contribution, alpha255 coverage. The raw native buffer is unchanged; display samples it with linear filtering and no sRGB conversion.',
                              'compositor':'CanvasLayer after scene tone mapping and before HUD; filtered foreground RGB5/31 is added to the full-resolution encoded scene and clamped to1. Zero foreground preserves the scene exactly. Background pixels are neither downsampled nor quantized. HDR2D uses explicit display encode/decode.',
                              'native_dither':False,'native_destination_mask_test':False,
                              'reference_verification':'20,000 deterministic triangles and81,920,000 pixels compared with unmodified DuckStation software rasterizer: zero RGB555 or coverage mismatches.'},
        'limits':['Extracted exactly from local disc data and static disassembly; no original in-game emulator reference image.', 'The user requested smoother presentation: native foreground pixels are filtered over the full-resolution scene instead of reproducing nearest-neighbor RGB555 display compositing.', 'Modern camera projection, the authorized longer reach and whole-primitive visibility against the painterly world remain explicit port adapters; the original scene ordering table is not replayed.'],
    }
    (out/'source.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({'output':str(out),'models':model_data,'verification':'all 144 primitive UV bounding boxes covered by original PAC; 24 palette rows verified from overlay'},indent=2))


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--recovery',type=Path,default=DEFAULT_RECOVERY)
    parser.add_argument('--output',type=Path,default=ROOT/'assets/characters/recovered_leaders/ed/beam')
    args=parser.parse_args()
    recover(args.recovery,args.output)
