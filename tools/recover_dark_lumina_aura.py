"""Bake the original casting aura's four CLUT phases without editing its mesh."""
import hashlib
import io
import json
from PIL import Image
from asset_pipeline.glb import GLB
from recover_skullpion_effects import ROOT, RECOVERY, load_vram, texture, png


def recover():
    sources=['raw/MAIN.CD.dir/FILE_003']+[f'raw/SC07.CD.dir/FILE_{i:03d}' for i in [0,2,4]]
    vram,present=load_vram((RECOVERY/sources[0]).read_bytes())
    for source in sources[1:]:
        values,mask=load_vram((RECOVERY/source).read_bytes())
        for i,loaded in enumerate(mask):
            if loaded:vram[i]=values[i];present[i]=1
    start=343*1024+352;palette=vram[start:start+16];frames=[]
    for phase in range(4):
        frames.append(texture(vram,present,(576,0,64,256),21974))
        colors=vram[start:start+16];vram[start:start+16]=colors[-4:]+colors[:-4]
    assert vram[start:start+16]==palette
    source=GLB.read(ROOT/'assets/characters/recovered_monsters/dark_lumina_3_effects.glb')
    material=next(m for m in source.doc['materials'] if m['name']=='tpage_41_clut_21974')
    image=source.doc['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
    original=Image.open(io.BytesIO(source.image_bytes(source.doc['images'][image]))).convert('RGBA')
    # Only this patch is sampled by the authored aura's preserved UVs.
    patch=(32,224,96,256)
    assert Image.frombytes('RGBA',(256,256),frames[0]).crop(patch).tobytes()==original.crop(patch).tobytes()
    folder=ROOT/'assets/characters/recovered_monsters/dark_lumina_3_effects'
    png(folder/'cast_aura_cycle.png',256,1024,b''.join(frames))
    report={'controller':'0x801ac47c','palette_update':'0x801a9b80','clut':21974,'palette_rect':[352,343,16,1],
            'rotation_entries':4,'frames':4,'fps':30,'sampled_patch':list(patch),
            'source_sha256':{p:hashlib.sha256((RECOVERY/p).read_bytes()).hexdigest() for p in sources},
            'frame_rgba_sha256':[hashlib.sha256(frame).hexdigest() for frame in frames]}
    (folder/'cast_aura_cycle.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Recovered four original aura palette phases; sampled source pixels match.')


if __name__=='__main__':recover()
