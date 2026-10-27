"""Recover finale effect meshes and sprite streams with original ROM provenance."""
import argparse
import hashlib
import json
import struct
from recover_dark_lumina_3 import BASE, SOURCE, RECOVERY, OUT
from recover_skullpion import recover
from recover_skullpion_effects import load_vram, texture, png
from asset_pipeline.glb import GLB

TABLES = [('wind',0x801B75EC,1),('wind_outer',0x801B80FC,1),
          ('sword',0x801B872C,1),('core',0x801BC9EC,1),('core_open',0x801BF01C,1),
          ('sword_wave',0x801EFC18,1),('cast_aura',0x801F0688,1),
          ('burst',0x801F07E0,1),('core_rays',0x801F0C90,1),
          ('ending',0x801F2538,1),('blast',0x801F2D48,1),('arena',0x801F7490,5)]

def main():
    name='dark_lumina_3_effects'
    recover(argparse.Namespace(recovery_root=RECOVERY,output=OUT),TABLES,0,0,name,SOURCE,BASE)
    path=OUT/(name+'.glb');g=GLB.read(path);meta=json.loads((OUT/(name+'_motion.json')).read_text())
    g.doc['nodes'][0]['name']=name
    for i,part in enumerate(meta['parts']):
        part['name']=f'Part_{i:02d}';g.doc['nodes'][part['node']]['name']=part['name']
    # An explicit rest action lets the ordinary editable rigid exporter retain exact meshes.
    times=g.append_accessor([(0,), (1/30,)],dict(type='SCALAR',componentType=5126))
    g.doc['accessors'][times].update(min=[0],max=[1/30])
    zero=g.append_accessor([(0,0,0),(0,0,0)],dict(type='VEC3',componentType=5126))
    g.doc['animations']=[dict(name='Rest',channels=[dict(sampler=0,target=dict(node=p['node'],path='translation')) for p in meta['parts']],samplers=[dict(input=times,output=zero,interpolation='STEP')])]
    from dark_lumina_3_morphs import add_morphs
    add_morphs(g,meta,(RECOVERY/SOURCE).read_bytes(),BASE)
    g.write(path)
    meta.update(name=name,clips=[dict(name='Rest',ticks=1,frames=[dict(tick=0,hold=1,pose='rest')],terminal='loop')],
                poses={'rest':[dict(position=[0,0,0],angles=[0,0,0]) for p in meta['parts']]},
                semantics=dict.fromkeys(['idle','walk','attack','hurt','death'],'Rest'),glb_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    (OUT/(name+'_motion.json')).write_text(json.dumps(meta,indent=2)+'\n')
    out=OUT/name;out.mkdir(exist_ok=True)
    vram,present=load_vram((RECOVERY/'raw/MAIN.CD.dir/FILE_003').read_bytes())
    for file in [0,2,4]:
        values,mask=load_vram((RECOVERY/f'raw/SC07.CD.dir/FILE_{file:03d}').read_bytes())
        for i,loaded in enumerate(mask):
            if loaded:vram[i]=values[i];present[i]=1
    data=(RECOVERY/SOURCE).read_bytes();report=dict(source=SOURCE,sha256=hashlib.sha256(data).hexdigest(),meshes=meta['groups'],sprites={})
    def sprite(name,descriptor,rects,table=0,palette_rows=None,hold=1,scale=1,depth=4):
        encoded,w,h,_,_,dx,dy=struct.unpack_from('<HBBHHhh',data,descriptor-BASE)
        rows=palette_rows if isinstance(palette_rows,list) else [palette_rows if palette_rows is not None else encoded>>8]*len(rects)
        assert len(rows)==len(rects)
        cluts=[((row+256)<<6)|(0x16 if row<224 else 0x10) for row in rows]
        per_word=16//depth
        frames=[texture(vram,present,(x,y,(w+per_word)//per_word,h+1),clut,depth) for (x,y),clut in zip(rects,cluts)]
        visible=[sum(any(frame[i:i+3]) and frame[i+3]>0 for i in range(0,len(frame),4)) for frame in frames]
        assert all(visible),'Unresolved or blank sprite palette: '+name
        pixels=b''.join(frames);png(out/(name+'.png'),((w+per_word)//per_word)*per_word,(h+1)*len(frames),pixels)
        report['sprites'][name]=dict(descriptor=hex(descriptor),table=hex(table),rects=rects,cluts=cluts,palette_rows=rows,pixel_depth=depth,hold_ticks=hold,display_scale=scale,visible_pixels=visible,width=w+1,height=h+1,frames=len(frames),sha256=hashlib.sha256(pixels).hexdigest())
    def timeline(address):
        frames=[]
        for i in range(64):
            x,y,flags=struct.unpack_from('<HHI',data,address-BASE+i*8);frames.append((x,y))
            if flags&0xC0:return frames
        raise ValueError('Unterminated effect stream')
    sprite('fire',0x801B0408,timeline(0x801B0414),0x801B0414,palette_rows=0x59,scale=3)
    sprite('water',0x801B0604,timeline(0x801B061C),0x801B061C,palette_rows=list(struct.unpack_from('<15H',data,0x801B070C-BASE)),hold=2)
    sprite('water_fall',0x801B0610,[(0x300,0x100)],palette_rows=0x64)
    # Actor flag 0x51000000 selects 8-bit pixels in the source sprite renderer.
    sprite('sword_cross',0x801B0770,[(0x280,0x180)],palette_rows=0xff,depth=8)
    for i,address in enumerate(struct.unpack_from('<4I',data,0x801B02B8-BASE)):
        sprite('sky_spark_'+str(i),0x801B01EC,timeline(address),address,palette_rows=0x64,hold=3,scale=2)
    report['notes']=['Original ROM mesh/UV/material pixels and sprites; Rest is an editor layout, not a source motion.',
                     'Dynamic sprite CLUT rows are actor +0x27: fire59, sky64, crossFF; water impact rows101..103 from801B070C. Hold ticks retain source timing.',
                     'Arena geometry is retained for provenance and excluded from attack presentation.']
    (out/'sources.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Recovered',len(meta['parts']),'effect/arena parts and',sum(s['frames'] for s in report['sprites'].values()),'sprite frames')

if __name__=='__main__':main()
