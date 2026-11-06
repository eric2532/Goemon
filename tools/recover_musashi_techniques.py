"""Recover learned sword technique evidence and actor0x54's original hit sprite.

Reuses the verified body/trail recovery; no elemental scroll modules are read.
The manifest retains source code, contact descriptors and unavailable branches
so recovering a pose never implies its gameplay has been implemented.
"""
import hashlib
import json
from pathlib import Path
import runpy
import struct
import sys

import numpy as np
from PIL import Image
from recover_musashi_sword_effects import HASHES, OVERLAY, OVERLAY_BASE, RESIDENT

ROOT = Path(__file__).resolve().parents[1]
RECOVERY = ROOT / 'build/Other Files/Musashi Asset Recovery'
OUT = ROOT / 'assets/characters/recovered_musashi/techniques'


def recover():
    blobs = {p: (RECOVERY / p).read_bytes() for p in (OVERLAY, RESIDENT)}
    for p, data in blobs.items():
        if hashlib.sha256(data).hexdigest() != HASHES[p]:
            raise ValueError('Unexpected retail source: ' + p)
    overlay = blobs[OVERLAY]
    read = lambda a, n: overlay[a-OVERLAY_BASE:a-OVERLAY_BASE+n]
    assert struct.unpack('<I', read(0x801A1D3C+0x54*4, 4))[0] == 0x8016E5B8
    assert struct.unpack('<8H', read(0x80180F44, 16)) == (0, 0, 0x24, 0x25, 0x24, 0x27, 0x24, 0x24)
    OUT.mkdir(parents=True, exist_ok=True)
    raw = OUT / 'source'; raw.mkdir(exist_ok=True)
    code = []
    for name, start, end in [
        ('fusion_combo_branches', 0x80155A44, 0x80155B20),
        ('learned_techniques', 0x80157D20, 0x801585AC+64),
        ('crosswise_impact', 0x8016E5B8, 0x8016E8F0),
        ('contact_descriptors', 0x80180AC8, 0x80180C6C),
        ('technique_vectors_dispatch', 0x80180F28, 0x80180F78),
        ('crosswise_quad', 0x80181F54, 0x80181FA4),
    ]:
        data = read(start, end-start); assert len(data) == end-start
        (raw / (name+'.bin')).write_bytes(data)
        code.append(dict(path='source/'+name+'.bin', address=hex(start), bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
    # Original FT4 coordinates pack absolute texel X and VRAM Y. CLUT selector
    # 0x27 resolves to (352,295) through executable80016F18.
    uv = [struct.unpack('<2H', read(0x80181F74+i*8, 4)) for i in range(4)]
    assert uv == [(2112,424),(2159,424),(2112,471),(2159,471)]
    sys.path.insert(0, str(RECOVERY/'tools/BFM-decomp/tools'))
    from bfm_extract.pac import split_pac
    pac = (RECOVERY/'raw/MAIN.CD.dir/FILE_010').read_bytes()
    words = np.zeros((512,1024), dtype='<u2'); present = np.zeros((512,1024), dtype=bool)
    for e in split_pac(pac):
        if e.type != 0: continue
        mask = pac[e.offset+16:e.offset+80]
        tiles = [i for i in range(512) if mask[i//8] & (1 << (i%8))]
        assert len(tiles) == e.unknown and len(e.payload) == len(tiles)*2048
        for j, tile in enumerate(tiles):
            x,y = tile%32*32, tile//32*32
            words[y:y+32,x:x+32] = np.frombuffer(e.payload,dtype='<u2',count=1024,offset=j*2048).reshape(32,32)
            present[y:y+32,x:x+32] = True
    yy,xx = np.indices((48,48)); x=528+xx//4; y=424+yy
    indices = (words[y,x] >> ((xx%4)*4)) & 15
    assert present[y,x].all() and present[295,352+indices].all()
    palette = words[295,352:368]; pixels=palette[indices]
    rgb=np.stack([((pixels >> shift)&31) for shift in (0,5,10)],axis=-1)
    rgb=((rgb << 3) | (rgb >> 2)).astype('uint8')
    rgba=np.concatenate([rgb,np.where(pixels==0,0,255).astype('uint8')[...,None]],axis=-1)
    Image.fromarray(rgba).save(OUT/'crosswise.png')
    (raw/'crosswise_clut.bin').write_bytes(palette.tobytes())
    reader=runpy.run_path(str(RECOVERY/'tools/recover_musashi_motion.py'))
    entries={'crosswise':0x800D4F14,'tenderize':0x800D51E0,'tenderize_end':0x800D524C,
             'desperado':0x800D52A8,'desperado_dual':0x800D52E8,'desperado_end':0x800D533C,
             'dashing_pierce':0x800D4E6C,'throw_fusion':0x800D4FF4,
             'throw_fusion_return':0x800D5060,'throw_fusion_absorb':0x800D5098,
             'shish_kebab':0x800D5128,'shish_kebab_launch':0x800D5178,'shish_kebab_end':0x800D51AC}
    clips={k:reader['decode'](a) for k,a in entries.items()}
    for clip in clips.values(): assert not clip['unsupported']
    source_hashes={p:HASHES[p] for p in blobs}
    source_hashes['raw/MAIN.CD.dir/FILE_010']=hashlib.sha256(pac).hexdigest()
    report=dict(source_region='USA SLUS-007.26',sources=source_hashes,code=code,clips=clips,
        crosswise=dict(input='Fusion contact, then Lumina',flag='0x85',entry='0x80155a44',state='0x24',
            body='0x800d4f14',impact_actor='0x54',impact_once_per_action=True,
            texture_rect=[528,424,12,48],clut=[352,295,16,1],texture_sha256=hashlib.sha256((OUT/'crosswise.png').read_bytes()).hexdigest(),
            quad_source=[list(struct.unpack('<3h',read(0x80181F54+i*8,6))) for i in range(4)],
            growth=dict(speed=256,acceleration=512,limit=12288,hold_ticks=5,fade_step=8,fade_scale_step=1024,brightness=128)),
        tenderize=dict(input='Fusion, Fusion, Lumina',flag='0x86',state='0x25',lift_tick=8,lift=-12,gravity=1,second_hit_stream='0x800d524c'),
        desperado=dict(input='Crosswise, Fusion, Lumina',flag='0x87',state='0x27',lift_tick=8,lift=-6,gravity=1,forward_speed=12,landing_stream='0x800d533c',dual_ribbons=[['fusion',9],['lumina',13]]),
        dashing_pierce=dict(flag='0x82',speed_fixed16=-0xB0000,stream='0x800d4e6c',sound='0x7f',voice='0x5f4',status='resources recovered; travel/contact adapter pending'),
        limitations=['Host combo buffering, collision and damage are adapters; no emulator frame-parity claim.',
            'Throw/absorb and Shish Kebab streams are archived, not enabled: enemy capture/carry lifecycle is not restored.',
            'Rumparoni-SP remains unidentified; no ordinary air strike is relabelled as that technique.',
            'Elemental Lumina scroll spells deliberately excluded.'])
    (OUT/'sources.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Recovered',len(clips),'body streams, verified code/contact tables and the 48x48 Crosswise impact sprite')
    return report


if __name__ == '__main__': recover()
