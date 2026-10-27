"""Recover Sonic's retail GameCube data; never regenerate an edited Blender master.

Ninja/REL layouts follow X-Hax/sa_tools, including its GC_SADX split maps.
Run with the bundled Python (NumPy, Pillow). Inputs stay read-only.
"""
import argparse
import configparser
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools'))
from asset_pipeline.glb import GLB


def decompressed(data):
    start = data.rfind(b'SaCompGC')
    if start < 0:
        return bytearray(data)
    data = data[start:]
    size = struct.unpack_from('>I', data, 8)[0] & 0x0fffffff
    assert 0 < size < 64*1024*1024
    pos, bits, left = 16, 0, 0
    def take(count):
        nonlocal pos, bits, left
        # GCAX consumes low bits, but its next-word crossing places the old
        # remainder above the newly read low bits (SACompGC_GetData).
        if left < count:
            missing = count-left
            old = bits << missing
            word, = struct.unpack_from('>I', data, pos)
            pos += 4
            bits, left = word >> missing, 32-missing
            return old | (word & ((1 << missing)-1))
        value = bits & ((1 << count)-1)
        bits >>= count
        left -= count
        return value
    out = bytearray()
    while len(out) < size:
        if take(1):
            out.append(take(8))
        else:
            distance, length = take(data[12])+1, take(data[13])+2
            assert distance <= len(out) and len(out)+length <= size
            for _ in range(length):
                out.append(out[-distance])
    return out


def relocated(data):
    data = decompressed(data)
    u = lambda o: struct.unpack_from('>I', data, o)[0]
    sections = [u(u(16)+i*8) & ~1 for i in range(u(12))]
    imports = [(u(u(40)+i*8), u(u(40)+i*8+4)) for i in range(u(44)//8)]
    at = next(offset for mid, offset in imports if mid == u(0))
    target = 0
    while True:
        delta, kind, section, addend = struct.unpack_from('>HBBI', data, at)
        at += 8
        target += delta
        if kind == 203:
            break
        if kind == 202:
            target = sections[section]
        elif kind == 1:
            struct.pack_into('>I', data, target, sections[section]+addend)
        elif kind not in (0, 201):
            # Code relocations do not change the model data; leave code intact.
            assert kind in (2, 3, 4, 5, 6, 10), f'Unknown REL relocation {kind}'
    return data


def textures(data):
    result = []
    at = 8 + struct.unpack_from('<I', data, 4)[0]
    while at < len(data):
        assert data[at:at+4] == b'GVRT'
        size, = struct.unpack_from('<I', data, at+4)
        mode = data[at+11]
        w, h = struct.unpack_from('>HH', data, at+12)
        assert mode in (5, 14), f'Unsupported GVR format {mode}'
        pixels = np.zeros((h, w, 4), dtype=np.uint8)
        src = at+16
        if mode == 14:
            def rgb565(v):
                r, g, b = (v >> 11) & 31, (v >> 5) & 63, v & 31
                return np.array([(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2), 255], dtype=np.int32)
            for by in range(0, h, 8):
                for bx in range(0, w, 8):
                    for sy, sx in ((0,0),(0,4),(4,0),(4,4)):
                        a, b = struct.unpack_from('>HH', data, src)
                        colors = [rgb565(a), rgb565(b)]
                        colors += [(2*colors[0]+colors[1])//3, (colors[0]+2*colors[1])//3] if a>b else [(colors[0]+colors[1])//2, np.zeros(4, dtype=int)]
                        for y in range(4):
                            for x in range(4):
                                pixels[by+sy+y,bx+sx+x] = colors[(data[src+4+y] >> (6-2*x)) & 3]
                        src += 8
        else:
            for by in range(0,h,4):
                for bx in range(0,w,4):
                    for y in range(4):
                        for x in range(4):
                            v, = struct.unpack_from('>H',data,src);src+=2
                            if v & 0x8000:
                                values=[(v>>s)&31 for s in (10,5,0)]
                                color=[(c<<3)|(c>>2) for c in values]+[255]
                            else:
                                a=(v>>12)&7
                                color=[((v>>s)&15)*17 for s in (8,4,0)]+[(a<<5)|(a<<2)|(a>>1)]
                            pixels[by+y,bx+x]=color
        out=io.BytesIO();Image.fromarray(pixels).save(out,format='PNG')
        result.append(out.getvalue())
        at += size+8
    assert len(result)==struct.unpack_from('>H',data,10)[0]
    return result


def quat(values, flags=0):
    angles=np.asarray(values)*math.tau/65536
    q=np.array([0.,0.,0.,1.])
    for axis in ((1,0,2) if flags & 32 else (2,1,0)):
        v=np.zeros(3);v[axis]=math.sin(angles[axis]/2);w=math.cos(angles[axis]/2)
        q=np.r_[q[3]*v+w*q[:3]+np.cross(q[:3],v),q[3]*w-np.dot(q[:3],v)]
    return q.tolist()


def recover_model(data, address, clips, images, out):
    u=lambda o:struct.unpack_from('>I',data,o)[0]
    nodes=[];addresses=[];flags=[]
    def visit(at, parent=None):
        while at:
            assert at not in addresses, 'Cycle in source hierarchy'
            f, attach, *rest=struct.unpack_from('>2I3f3i3f2I',data,at)
            index=len(nodes);addresses.append(at);flags.append(f)
            node={'name':f'Node_{index:02d}_{at:06x}', 'translation':list(rest[:3]),'rotation':quat(rest[3:6],f),'scale':list(rest[6:9]),'extras':{'source_address':at,'source_flags':f}}
            nodes.append(node)
            if parent is not None:nodes[parent].setdefault('children',[]).append(index)
            if attach and not f & 8:node['_attach']=attach
            if rest[9] and not f & 16:visit(rest[9],index)
            at=rest[10]
    visit(address)
    glb=GLB({'asset':{'version':'2.0','generator':'Goemon SADX GC recovery'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':nodes,'meshes':[],'materials':[],'textures':[],'images':[],'samplers':[],'animations':[]},b'')
    for image in images:
        while len(glb.binary)%4:glb.binary.append(0)
        glb.doc.setdefault('bufferViews',[]).append({'buffer':0,'byteOffset':len(glb.binary),'byteLength':len(image)})
        glb.doc['images'].append({'bufferView':len(glb.doc['bufferViews'])-1,'mimeType':'image/png'})
        glb.binary.extend(image)
    material_ids={}
    def material(at):
        if at in material_ids:return material_ids[at]
        rgba=list(data[at:at+4]);tex=u(at+12);bits=u(at+16)
        m={'name':f'Material_{at:06x}_texture_{tex}','pbrMetallicRoughness':{'baseColorFactor':[v/255 for v in rgba],'metallicFactor':0,'roughnessFactor':.8},'doubleSided':bool(bits & 0x8000000),'extras':{'source_flags':bits,'source_texture':tex}}
        if bits & 0x200000:
            assert tex<len(images)
            glb.doc['samplers'].append({'magFilter':9729,'minFilter':9987,'wrapS':33071 if bits&0x10000 else 33648 if bits&0x40000 else 10497,'wrapT':33071 if bits&0x8000 else 33648 if bits&0x20000 else 10497})
            glb.doc['textures'].append({'source':tex,'sampler':len(glb.doc['samplers'])-1})
            m['pbrMetallicRoughness']['baseColorTexture']={'index':len(glb.doc['textures'])-1}
        if bits & 0x100000:m['alphaMode']='BLEND'
        material_ids[at]=len(glb.doc['materials']);glb.doc['materials'].append(m)
        return material_ids[at]
    triangles=0
    for node in nodes:
        attach=node.pop('_attach',0)
        if not attach:continue
        vp,np_,vc,mp,matp,mc,matc=struct.unpack_from('>5I2H',data,attach)
        verts=[struct.unpack_from('>3f',data,vp+i*12) for i in range(vc)]
        normals=[struct.unpack_from('>3f',data,np_+i*12) for i in range(vc)] if np_ else [(0,1,0)]*vc
        primitives=[]
        for i in range(mc):
            typ,count,poly,_,pn,colors,uv=struct.unpack_from('>HH5I',data,mp+i*24)
            mid=material(matp+(typ&0x3fff)*20);kind=typ>>14
            rows=[];ns=[];uvs=[];cs=[];indices=[];source_ids=[];corner=0
            for j in range(count):
                reverse=False
                if kind in (2,3):
                    n,=struct.unpack_from('>H',data,poly);poly+=2;reverse=bool(n&0x8000);n&=0x7fff
                else:n=3 if kind==0 else 4
                ids=struct.unpack_from('>'+str(n)+'H',data,poly);poly+=n*2;base=len(rows)
                for idx in ids:
                    assert idx<vc
                    source_ids.append(idx)
                    rows.append(verts[idx]);ns.append(normals[idx])
                    uvs.append(tuple(v/255 for v in struct.unpack_from('>2h',data,uv+corner*4)) if uv else (0,0))
                    cs.append(tuple(c/255 for c in data[colors+corner*4:colors+corner*4+4]) if colors else (1,1,1,1));corner+=1
                if kind==0:faces=[(0,1,2)]
                elif kind==1:faces=[(0,1,2),(2,1,3)]
                elif kind==2:faces=[(0,k-1,k) for k in range(2,n)]
                else:faces=[(k-2,k,k-1) if bool(k%2)^reverse else (k-2,k-1,k) for k in range(2,n)]
                for face in faces:
                    indices.extend(base+k for k in face)
                triangles+=len(faces)
            attrs={'POSITION':glb.append_accessor(rows,{'componentType':5126,'type':'VEC3'}),'NORMAL':glb.append_accessor(ns,{'componentType':5126,'type':'VEC3'}),'TEXCOORD_0':glb.append_accessor(uvs,{'componentType':5126,'type':'VEC2'})}
            if colors:attrs['COLOR_0']=glb.append_accessor(cs,{'componentType':5126,'type':'VEC4'})
            primitives.append({'attributes':attrs,'indices':glb.append_accessor([(i,) for i in indices],{'componentType':5125,'type':'SCALAR'}),'material':mid,'extras':{'source_vertices':source_ids}})
        node['mesh']=len(glb.doc['meshes']);glb.doc['meshes'].append({'name':node['name']+'_Mesh','primitives':primitives})
    animated=[i for i,f in enumerate(flags) if not f&64]
    manifest=[]
    for name,source,at,num in clips:
        p,frames,kind,width=struct.unpack_from('>IIHH',source,at)
        assert kind in (3,7) and num==len(animated), (name,num,len(animated),kind)
        channels=2 if kind==3 else 3
        animation={'name':name,'samplers':[],'channels':[]}
        for i,node_index in enumerate(animated):
            for channel,path in enumerate(('translation','rotation','scale')):
                start,n=(struct.unpack_from('>I',source,p+i*(width&15)*8+channel*4)[0],struct.unpack_from('>I',source,p+i*(width&15)*8+(channels+channel)*4)[0]) if channel<channels else (0,0)
                if not start or not n:
                    input_=glb.append_accessor([(0.,)],{'componentType':5126,'type':'SCALAR'})
                    glb.doc['accessors'][input_].update(min=[0],max=[0])
                    output=glb.append_accessor([nodes[node_index][path]],{'componentType':5126,'type':'VEC4' if path=='rotation' else 'VEC3'})
                    animation['channels'].append({'sampler':len(animation['samplers']),'target':{'node':node_index,'path':path}})
                    animation['samplers'].append({'input':input_,'output':output,'interpolation':'LINEAR'})
                    continue
                keys=[struct.unpack_from('>4i' if path=='rotation' else '>I3f',source,start+k*16) for k in range(n)]
                assert all(0<=k[0]<frames for k in keys), (name,path,start,keys[:2])
                assert all(keys[k][0]<keys[k+1][0] for k in range(n-1))
                # Bake Ninja's Euler interpolation at source ticks before glTF's
                # quaternion interpolation; no runtime retargeting is needed.
                times=list(range(frames))
                values=[]
                for t in times:
                    a=next((j for j in range(n-1) if keys[j+1][0]>t),n-1)
                    b=min(a+1,n-1);mix=(t-keys[a][0])/max(1,keys[b][0]-keys[a][0]) if b!=a else 0
                    lo=np.array(keys[a][1:],float);hi=np.array(keys[b][1:],float)
                    diff=hi-lo
                    if path=='rotation':diff=(diff+32768)%65536-32768
                    v=(lo+diff*mix).tolist()
                    values.append(quat(v,flags[node_index]) if path=='rotation' else v)
                input_=glb.append_accessor([(t/60,) for t in times],{'componentType':5126,'type':'SCALAR'})
                glb.doc['accessors'][input_].update(min=[0],max=[(frames-1)/60])
                output=glb.append_accessor(values,{'componentType':5126,'type':'VEC4' if path=='rotation' else 'VEC3'})
                animation['channels'].append({'sampler':len(animation['samplers']),'target':{'node':node_index,'path':path}})
                animation['samplers'].append({'input':input_,'output':output,'interpolation':'LINEAR'})
        glb.doc['animations'].append(animation)
        manifest.append({'name':name,'address':at,'frames':frames,'parts':num})
    glb.write(out)
    return {'nodes':len(nodes),'animated_nodes':len(animated),'triangles':triangles,'clips':manifest,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--research',type=Path,default=ROOT/'build/Other Files/Asset Toolkit/Sonic/Research');parser.add_argument('--templates',type=Path,required=True)
    args=parser.parse_args();out=ROOT/'assets/characters/recovered_sonic';out.mkdir(parents=True,exist_ok=True)
    models=relocated((args.research/'ModelsMiles.rel').read_bytes());motion=relocated((args.research/'s_mot.rel').read_bytes())
    configs=[]
    for filename,source in [('ModelsMiles.ini',models),('s_mot.ini',motion)]:
        cfg=configparser.ConfigParser(interpolation=None,strict=False);cfg.read_string('[DEFAULT]\n'+(args.templates/filename).read_text(encoding='utf-8-sig'));configs.append((cfg,source))
    images=textures((args.research/'sonic.gvm').read_bytes())
    for i,image in enumerate(images):(out/f'texture_{i:02d}.png').write_bytes(image)
    manifest={'disc':'GXSP8P revision 1','sources':{name:hashlib.sha256((args.research/name).read_bytes()).hexdigest() for name in ('ModelsMiles.rel','s_mot.rel','sonic.gvm')},'models':{}}
    for label,file in [('Sonic','sonic'),('Sonic (Curled)','curled'),('Sonic Jumpball','ball')]:
        spec=configs[0][0][label];num={'sonic':73,'curled':74,'ball':1}[file]
        clips=[]
        for cfg,source in configs:
            for name in cfg.sections():
                row=cfg[name]
                if row.get('type')!='animation' or 'figure/sonic/' not in row.get('filename','') or int(row.get('numparts',0))!=num:continue
                clips.append((name,source,int(row['address'],16),num))
        manifest['models'][file]=recover_model(models,int(spec['address'],16),clips,images,out/(file+'.glb'))
        print(file,manifest['models'][file]['triangles'],'triangles',len(clips),'clips')
    (out/'source_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':main()
