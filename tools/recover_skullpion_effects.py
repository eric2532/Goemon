"""Recover Skullpion's VRAM animation frames and original attack-effect geometry."""
import array
import hashlib
import json
from pathlib import Path
import struct
import sys
import zlib
from asset_pipeline.glb import GLB

ROOT=Path(__file__).resolve().parents[1]
RECOVERY=ROOT/'build/Other Files/Musashi Asset Recovery'
sys.path.insert(0,str(RECOVERY/'tools/BFM-decomp/tools'))
from bfm_extract.pac import split_pac


def png(path,w,h,pixels):
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
    scan=b''.join(b'\0'+pixels[y*w*4:(y+1)*w*4] for y in range(h))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>2I5B',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(scan))+chunk(b'IEND',b''))


def load_vram(pac):
    vram=array.array('H',[0])*(1024*512);present=bytearray(1024*512)
    for entry in split_pac(pac):
        if entry.type!=0:continue
        mask=pac[entry.offset+16:entry.offset+80];indices=[i for i in range(512) if mask[i//8]&(1<<(i%8))]
        assert len(indices)==entry.unknown and len(entry.payload)==len(indices)*2048
        for n,tile in enumerate(indices):
            words=array.array('H');words.frombytes(entry.payload[n*2048:(n+1)*2048])
            x,y=tile%32*32,tile//32*32
            for row in range(32):
                start=(y+row)*1024+x;vram[start:start+32]=words[row*32:(row+1)*32];present[start:start+32]=b'\1'*32
    return vram,present


def texture(vram,present,rect,clut,depth=4):
    assert depth in (4,8)
    x,y,w,h=rect;cx,cy=(clut&63)*16,clut>>6
    per_word=16//depth
    result=bytearray()
    for row in range(h):
        for col in range(w*per_word):
            pos=(y+row)*1024+x+col//per_word;assert present[pos]
            index=(vram[pos]>>((col%per_word)*depth))&((1<<depth)-1);palette=cy*1024+cx+index;assert present[palette]
            color=vram[palette]
            rgb=[((color>>s)&31) for s in (0,5,10)]
            result.extend([(c<<3)|(c>>2) for c in rgb]+[0 if color==0 else 255])
    return bytes(result)


def main():
    out=ROOT/'assets/characters/recovered_skullpion/effects';out.mkdir(parents=True,exist_ok=True)
    source='raw/SC03.CD.dir/FILE_028.dir/0.4.dec';data=(RECOVERY/source).read_bytes();base=0x80128158
    pac=(RECOVERY/'raw/SC03.CD.dir/FILE_028').read_bytes()
    vram,present=load_vram(pac)
    sample=lambda rect,clut:texture(vram,present,rect,clut)
    report={'source':source,'source_sha256':hashlib.sha256(data).hexdigest(),
            'pac_sha256':hashlib.sha256(pac).hexdigest(),'animations':{}}
    for name,address,count,clut,first in [('sand',0x801900F8,8,23894,None),('dust',0x80190138,12,23958,(768,416,8,32))]:
        rects=[struct.unpack_from('<4h',data,address-base+i*8) for i in range(count-(1 if first else 0))]
        if first:rects.insert(0,first)
        frames=[sample(rect,clut) for rect in rects];w,h=rects[0][2]*4,rects[0][3]
        png(out/(name+'.png'),w,h*count,b''.join(frames))
        report['animations'][name]={'rect_table':hex(address),'clut':clut,'rects':rects,'frames':count,'frame_size':[w,h],
            'rgba_sha256':hashlib.sha256(b''.join(frames)).hexdigest()}
    sprites=[]
    for i in range(12):
        clut,w,h,x,y,dx,dy=struct.unpack_from('<HBBHHhh',data,0x80190A4C-base+i*12)
        assert (w,h)==(31,31)
        palette_row=clut>>8;clut=((palette_row+256)<<6)|(0x16 if palette_row<224 else 0x10)
        sprites.append(sample((x,y,8,32),clut))
    png(out/'volley.png',32,32*12,b''.join(sprites))
    report['volley']={'actor':0x138,'handler':'0x80186044','sprite_table':'0x80190a4c',
        'frames':12,'clut':clut,'rgba_sha256':hashlib.sha256(b''.join(sprites)).hexdigest(),
        'release_function':'0x80182698','spread_source':[0,512,-512],'lifetime_ticks':150,'bounces':True}
    visual=json.loads((RECOVERY/'visual_manifest.json').read_text());models={m['id']:m for m in visual['models']}
    occurrences={base+o['offset']:o for o in visual['model_occurrences'] if o['source']==source}
    for name,address in [('sand',0x801E0B7C),('dust',0x801E0CA0)]:
        model=models[occurrences[address]['model']];g=GLB.read(RECOVERY/model['path']);p=g.doc['meshes'][0]['primitives'][0]
        report[name+'_mesh']={'address':hex(address),'source_model':model['id'],
            'positions':g.accessor(p['attributes']['POSITION']),'uv':g.accessor(p['attributes']['TEXCOORD_0'])}
    # The drill emergence renderer uses four additive quads with this palette/layout.
    report['drill_glow']={'renderer':'0x80183e04','palette':[v&0xffffff for v in struct.unpack_from('<3I',data,0x801902c8-base)],
        'x_indices':list(data[0x801902d4-base:0x801902d4-base+16]),
        'y_indices':list(data[0x801902e4-base:0x801902e4-base+16]),
        'color_indices':list(data[0x801902f4-base:0x801902f4-base+16]),'inner_fraction':179/256}
    report['notes']=['Original 4-bit texture pixels and CLUTs; no replacement art.',
        'Sand MoveImage cycles are sampled from immutable source tiles, before overlapping destination writes.',
        'Runtime adapts original plume travel, dust emission and drill placement to the native boss encounter.']
    (out/'sources.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Recovered sand (8 frames), dust (12 frames), their original meshes and the drill emergence glow.')


if __name__=='__main__':main()
