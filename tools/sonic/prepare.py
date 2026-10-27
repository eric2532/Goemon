"""Prepare retail welds as GPU skinning; keep recovered source GLBs untouched.

Type 2 copies the source vertex into the destination's coordinate system
(GXSP8P _Main.rel 0x5bc70..0x5bd40), so these are exact rigid weights, not
guessed proximity welds. This is asset preparation, never a runtime mesh loop.
"""
import json
from pathlib import Path
import struct
import numpy as np
from recover import ROOT, GLB, decompressed, relocated

SOURCE=ROOT/'assets/characters/recovered_sonic'
RESEARCH=ROOT/'build/Other Files/Asset Toolkit/Sonic/Research'

def sections(data):
    count, table=struct.unpack_from('>II',data,12)
    return [struct.unpack_from('>I',data,table+i*8)[0]&~1 for i in range(count)]

def tables():
    data=decompressed((RESEARCH/'_Main.rel').read_bytes())
    modules={1:data,3:relocated((RESEARCH/'ModelsMiles.rel').read_bytes()),32:relocated((RESEARCH/'s_mot.rel').read_bytes())}
    sec={key:sections(value) for key,value in modules.items()}
    refs={};table,size=struct.unpack_from('>II',data,40)
    for module,at in struct.iter_unpack('>II',data[table:table+size]):
        target=0
        while True:
            delta,kind,section,addend=struct.unpack_from('>HBBI',data,at);at+=8;target+=delta
            if kind==203:break
            if kind==202:target=sec[1][section]
            elif kind==1 and module in modules:refs[target]=(module,sec[module][section]+addend)
    welds=[]
    for i in range(22):
        at=0x355ad8+i*24;count,kind=data[at+12:at+14]
        if kind!=2:continue
        a,b=refs[at+4],refs[at+8];offset=refs[at+20][1]
        assert a[0]==b[0]==3
        welds.append({'a':a[1],'b':b[1],'pairs':list(struct.iter_unpack('>HH',data[offset:offset+count*4]))})
    clips=[clip for model in json.loads((SOURCE/'source_manifest.json').read_text())['models'].values() for clip in model['clips']]
    names={clip['address']:clip['name'] for clip in clips}
    animations=[]
    for i in range(146):
        at=0x355020+i*16
        if at not in refs:continue # Super/Metal Sonic are different source models.
        module,action=refs[at]
        motion=struct.unpack_from('>I',modules[module],action+4)[0]
        parts,mode,next_,transition,rate=struct.unpack_from('>BBHff',data,at+4)
        animations.append({'id':i,'clip':names.get(motion,''),'parts':parts,'mode':mode,'next':next_,'transition':transition,'rate':rate})
    fields='jump2_timer pos_error lim_h_spd lim_v_spd max_x_spd max_psh_spd jmp_y_spd nocon_speed slide_speed jog_speed run_speed rush_speed crash_speed dash_speed jmp_addit run_accel air_accel slow_down run_break air_break air_resist_air air_resist air_resist_y air_resist_z grd_frict grd_frict_z lim_frict rat_bound rad height weight eyes_height center_height'.split()
    physics=dict(zip(fields,struct.unpack_from('>i32f',data,0x2c6d28)))
    result={'physics_address':0x2c6d28,'physics':physics,'animations_address':0x355020,'animations':animations,'clip_frames':{clip['name']:clip['frames'] for clip in clips},'welds':welds}
    (SOURCE/'native_tables.json').write_text(json.dumps(result,indent=2)+'\n')
    return welds

def matrix(node):
    x,y,z,w=node['rotation'];m=np.eye(4)
    m[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
               [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
               [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    m[:3,:3]*=node['scale'];m[:3,3]=node['translation']
    return m

def prepare(welds):
    model=GLB.read(SOURCE/'sonic.glb');nodes=model.doc['nodes'];count=len(nodes)
    by_address={n['extras']['source_address']:i for i,n in enumerate(nodes)}
    world={}
    def visit(i,parent):
        world[i]=parent@matrix(nodes[i])
        for child in nodes[i].get('children',[]):visit(child,world[i])
    visit(0,np.eye(4))
    vertices={}
    for i,node in enumerate(nodes):
        if 'mesh' not in node:continue
        for primitive in model.doc['meshes'][node['mesh']]['primitives']:
            for index,pos,normal in zip(primitive['extras']['source_vertices'],model.accessor(primitive['attributes']['POSITION']),model.accessor(primitive['attributes']['NORMAL'])):
                vertices[i,index]=(pos,normal)
    redirects={}
    for weld in welds:
        if weld['a'] not in by_address or weld['b'] not in by_address:continue
        a,b=by_address[weld['a']],by_address[weld['b']]
        for av,bv in weld['pairs']:
            assert (a,av) in vertices and (b,bv) in vertices
            redirects[b,bv]=(a,av)
    for i in range(count):
        node=nodes[i]
        if 'mesh' not in node:continue
        mesh=node.pop('mesh')
        for primitive in model.doc['meshes'][mesh]['primitives']:
            positions=[];normals=[];joints=[]
            for vertex in primitive['extras']['source_vertices']:
                source=redirects.get((i,vertex),(i,vertex));joint=source[0]
                pos,normal=vertices[source]
                positions.append((world[joint]@np.r_[pos,1])[:3].tolist())
                n=np.linalg.inv(world[joint][:3,:3]).T@normal;n/=np.linalg.norm(n)
                normals.append(n.tolist());joints.append((joint,0,0,0))
            attrs=primitive['attributes']
            attrs['POSITION']=model.append_accessor(positions,{'componentType':5126,'type':'VEC3'})
            attrs['NORMAL']=model.append_accessor(normals,{'componentType':5126,'type':'VEC3'})
            attrs['JOINTS_0']=model.append_accessor(joints,{'componentType':5123,'type':'VEC4'})
            attrs['WEIGHTS_0']=model.append_accessor([(1.,0.,0.,0.)]*len(joints),{'componentType':5126,'type':'VEC4'})
        nodes.append({'name':node['name']+'_Geometry','mesh':mesh,'skin':0})
        model.doc['scenes'][0]['nodes'].append(len(nodes)-1)
    inverse=model.append_accessor([np.linalg.inv(world[i]).T.flatten().tolist() for i in range(count)],{'componentType':5126,'type':'MAT4'})
    model.doc['skins']=[{'name':'SonicNativeWelds','joints':list(range(count)),'inverseBindMatrices':inverse,'skeleton':0}]
    model.compact()
    out=RESEARCH/'sonic-prepared.glb';model.write(out)
    print('Prepared',len(redirects),'retail welded vertices; triangles/UVs/textures retained')
    return out

if __name__=='__main__':prepare(tables())
