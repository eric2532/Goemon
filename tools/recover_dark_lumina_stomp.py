"""Recover actor 0x352's nineteen textured ground-wave sectors, not the finale dome."""
import hashlib
import base64
import json
import math
import shutil
import struct
from asset_pipeline.glb import GLB
from recover_skullpion_effects import ROOT, RECOVERY, load_vram, texture, png


def recover():
    source = 'raw/SC07.CD.dir/FILE_002.dir/0.4.dec'
    data = (RECOVERY/source).read_bytes()
    base = 0x80128158
    word = lambda address: struct.unpack_from('<I', data, address-base)[0]
    assert word(0x80190f40+0x352*4) == 0x80183a34
    assert word(0x80197dcc) == 0x80197c6c
    heights = list(struct.unpack_from('<8H', data, 0x8018a4cc-base))
    assert heights == [8192,14336,18432,17408,16384,12288,8192,4096]
    visual = json.loads((RECOVERY/'visual_manifest.json').read_text())
    occurrence = next(o for o in visual['model_occurrences'] if o['source']==source and o['offset']==0x80197c6c-base)
    model = next(m for m in visual['models'] if m['id']==occurrence['model'])
    out = ROOT/'assets/characters/recovered_monsters/dark_lumina_2_effects'
    shutil.copyfile(RECOVERY/model['path'], out/'stomp_sector.glb')
    g = GLB.read(out/'stomp_sector.glb')
    attributes = g.doc['meshes'][0]['primitives'][0]['attributes']
    for key, accessor in list(attributes.items()):
        rows = g.accessor(accessor)
        assembled = []
        for sector in range(19):
            angle = sector*227*math.tau/4096
            s,c = math.sin(angle),math.cos(angle)
            assembled.extend([(c*p[0]+s*p[2],p[1],-s*p[0]+c*p[2]) if key in ['POSITION','NORMAL'] else p for p in rows])
        attributes[key] = g.append_accessor(assembled, g.doc['accessors'][accessor])
    vram,present = load_vram((RECOVERY/'raw/MAIN.CD.dir/FILE_003').read_bytes())
    for path in ['raw/SC07.CD.dir/FILE_001','raw/SC07.CD.dir/FILE_003']:
        values,mask = load_vram((RECOVERY/path).read_bytes())
        for i,loaded in enumerate(mask):
            if loaded:vram[i]=values[i];present[i]=1
    pixels = texture(vram,present,(768,416,64,96),0x7ed0,8)
    page = bytearray(256*256*4)
    for y in range(96):page[((y+160)*256)*4:((y+160)*256+128)*4]=pixels[y*128*4:(y+1)*128*4]
    png(out/'stomp_wave.png',256,256,page)
    g.doc['images']=[{'uri':'data:image/png;base64,'+base64.b64encode((out/'stomp_wave.png').read_bytes()).decode()}]
    g.doc['textures']=[{'source':0}]
    material=g.doc['materials'][0]
    material['name']='Retail_stomp_tpage_188_clut_32464'
    material['pbrMetallicRoughness']['baseColorTexture']={'index':0}
    material['alphaMode']='BLEND';material['doubleSided']=True
    g.compact();g.write(out/'stomp_wave.glb')
    report=dict(source=source,source_sha256=hashlib.sha256(data).hexdigest(),actor='0x352',spawn='0x801830d8',model='0x80197c6c',
        controller='0x80183458',rise='0x8018439c',travel='0x801838fc',sectors=19,sector_angle=227,
        rise_scales=heights,rise_ticks=8,travel_ticks=48,slow_expansion=32,fast_expansion=128,turn_per_tick=148,
        texture=dict(tpage=188,clut=32464,depth=8,rect=[768,416,64,96],uv_scroll_frames=8,rgba_sha256=hashlib.sha256(pixels).hexdigest()),
        notes=['The local 801F2260/801F2900 dome/ring belong to a different effect controller.',
               'Original nineteen sectors, UVs and palette pixels; transparent unused page space preserves source UVs.',
               'Goemon retains its existing two grounded damage pulses and reach; each now presents the recovered travelling ground wave.'])
    (out/'stomp_sources.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Recovered nineteen-sector textured stomp wave and its rise/travel controller.')


if __name__=='__main__':recover()
