"""Preserve battle-module effect meshes and all three 16-frame sprite streams."""
import hashlib
import json
import shutil
import struct
from recover_skullpion_effects import ROOT, RECOVERY, load_vram, texture, png
from recover_dark_lumina import BASE, SOURCE


def main():
    out=ROOT/'assets/characters/recovered_monsters/dark_lumina_2_effects';out.mkdir(parents=True,exist_ok=True)
    data=(RECOVERY/SOURCE).read_bytes();pac=(RECOVERY/'raw/SC07.CD.dir/FILE_003').read_bytes()
    vram,present=load_vram((RECOVERY/'raw/MAIN.CD.dir/FILE_003').read_bytes())
    for source in ['raw/SC07.CD.dir/FILE_001','raw/SC07.CD.dir/FILE_003']:
        values,mask=load_vram((RECOVERY/source).read_bytes())
        for i,loaded in enumerate(mask):
            if loaded:vram[i]=values[i];present[i]=1
    report=dict(source=SOURCE,source_sha256=hashlib.sha256(data).hexdigest(),sprites={},meshes={})
    for name,address in [('fire',0x801a6f08),('impact',0x801a6fc8),('ember',0x801a7088)]:
        frames=[];records=[]
        for i in range(16):
            raw=data[address-BASE+i*12:address-BASE+(i+1)*12]
            encoded,w,h,x,y,dx,dy=struct.unpack('<HBBHHhh',raw);assert w==31 and h in (31,63)
            row=encoded>>8;clut=((row+256)<<6)|(0x16 if row<224 else 0x10)
            frames.append(texture(vram,present,(x,y,8,h+1),clut));records.append(dict(address=hex(address+i*12),raw=raw.hex(),rect=[x,y,8,h+1],clut=clut))
        pixels=b''.join(frames);png(out/(name+'.png'),32,(h+1)*16,pixels)
        report['sprites'][name]=dict(frames=16,records=records,sha256=hashlib.sha256(pixels).hexdigest())
    visual=json.loads((RECOVERY/'visual_manifest.json').read_text());models={m['id']:m for m in visual['models']}
    occurrences={BASE+o['offset']:o for o in visual['model_occurrences'] if o['source']==SOURCE}
    for name,address in [('shock_dome',0x801f2260),('shock_ring',0x801f2900),('fragment',0x801f30b0)]:
        m=models[occurrences[address]['model']];p=RECOVERY/m['path'];shutil.copyfile(p,out/(name+'.glb'))
        report['meshes'][name]=dict(address=hex(address),model=m['id'],sha256=hashlib.sha256(p.read_bytes()).hexdigest())
    report['notes']=['Original PSX vertices, colours, UVs and palette pixels. Effect GLBs retain source dimensions; apply .018 world conversion.',
                     'Fire actor 0x378 uses three trailing sprites; paired releases at body ticks 47/64/81, source angles +320/-320.',
                     'The 16-frame fire/impact/ember streams are at 801A7148/801A71D0/801A7258.']
    (out/'sources.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Recovered 48 sprite frames and all 3 battle effect meshes')


if __name__=='__main__':main()
