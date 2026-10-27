"""Recover the five selected retail abilities without changing Musashi's body GLB.

Outputs source animations into a temporary GLB for bake_musashi_assimilation.gd,
and native TMD geometry/VRAM pixels into the new skill asset directory.
"""
import ast
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import runpy
import struct
import sys

import numpy as np
from PIL import Image
from asset_pipeline.glb import GLB
from recover_musashi_actions import hidden_parts
from recover_musashi_motion_continuations import quaternion, source_transform, trs

ROOT = Path(__file__).resolve().parents[1]
RECOVERY = ROOT/'build/Other Files/Musashi Asset Recovery'
OUT = ROOT/'assets/characters/recovered_musashi/assimilation'
WORK = ROOT/'build/Other Files/Asset Toolkit/Musashi Assimilation'
BASE = 0x800CAE08
ENTRIES = {'dkick': (32, 0x800CB26C), 'fence': (33, 0x800CB858),
           'three_raise': (38, 0x800CBB44), 'three_lower': (38, 0x800CBB64),
           'three_fire': (38, 0x800CBB84), 'throw': (10, 0x800D57F4)}


def main():
    OUT.mkdir(parents=True, exist_ok=True); WORK.mkdir(parents=True, exist_ok=True)
    resident = runpy.run_path(str(RECOVERY/'tools/recover_musashi_motion.py'))
    original_pose = resident['pose']
    original_word = resident['word']
    current = 10
    modules = {n: (RECOVERY/f'raw/MAIN.CD.dir/FILE_{n:03}.dir/1.1').read_bytes()
               for n in (32, 33, 38, 39, 40)}

    def word(address):
        if BASE <= address < BASE+len(modules.get(current, b'')):
            return struct.unpack_from('<I', modules[current], address-BASE)[0]
        return original_word(address)

    def pose(address):
        if not BASE <= address < BASE+len(modules.get(current, b'')):
            return original_pose(address)
        data = modules[current]; offset = address-BASE
        assert offset+256 <= len(data)
        records = []
        for j in range(30):
            b0, b1, b2, x, y, z, rx = struct.unpack_from('<3B3bh', data, offset+16+j*8)
            records.append(dict(angles=[rx & 4095, b1 | ((b0 & 15) << 8), b2 | ((b0 & 240) << 4)], position=[x,y,z]))
        parts = []
        for part in range(31):
            value = records[3] if part < 2 else records[part-1]
            position = list(struct.unpack_from('<3b', data, offset+16+(0 if part == 0 else 3))) if part < 2 else value['position']
            parts.append(dict(angles=value['angles'], position=position, hair_y_half_turn=part == 0))
        return dict(parts=parts)

    resident['decode'].__globals__.update(word=word, pose=pose)
    glb = GLB.read(ROOT/'assets/characters/recovered_musashi/musashi.glb')
    old_binary = bytes(glb.binary); old_animations = json.dumps(glb.doc['animations'], sort_keys=True)
    parents = {child: i for i,n in enumerate(glb.doc['nodes']) for child in n.get('children', [])}
    parts = {int(n['name'].split('_')[1]): i for i,n in enumerate(glb.doc['nodes']) if n.get('name','').startswith('Part_')}

    def world(i):
        n = glb.doc['nodes'][i]
        local = trs(n.get('translation',[0,0,0]), n.get('rotation',[0,0,0,1]), n.get('scale',[1,1,1]))
        return world(parents[i]) @ local if i in parents else local

    def add(rows, kind):
        return glb.append_accessor(rows, dict(type=kind, componentType=5126))

    clips = {}; checks = 0; maximum_error = 0.0
    for name, (current, address) in ENTRIES.items():
        clip = resident['decode'](address); assert not clip['unsupported'], clip
        frames = clip['frames']+[dict(tick=clip['ticks'], pose=clip['frames'][-1]['pose'])]
        times = add([(f['tick']/30,) for f in frames], 'SCALAR')
        glb.doc['accessors'][times].update(min=[0], max=[clip['ticks']/30])
        animation = dict(name='Assimilation_'+name, channels=[], samplers=[])
        for part, node in parts.items():
            parent = world(parents[node]); inverse = np.linalg.inv(parent)
            translations, rotations, scales = [], [], []
            for frame in frames:
                expected = source_transform(pose(int(frame['pose'],16))['parts'][part])
                local = inverse @ expected; q = quaternion(local[:3,:3])
                # Check encoded float32 data, rather than only the calculation.
                t = np.asarray(local[:3,3],dtype='<f4'); q = np.asarray(q,dtype='<f4')
                error = float(np.max(np.abs(expected-parent @ trs(t,q,[1,1,1]))))
                assert error < .00001, (name,part,error)
                maximum_error = max(maximum_error,error); checks += 1
                translations.append(t.tolist()); rotations.append(q.tolist())
                hidden = part in hidden_parts(clip['events'],frame['tick'])
                scales.append([.000001 if hidden else 1]*3)
            for prop, rows, kind in [('translation',translations,'VEC3'),('rotation',rotations,'VEC4'),('scale',scales,'VEC3')]:
                animation['channels'].append(dict(sampler=len(animation['samplers']),target=dict(node=node,path=prop)))
                animation['samplers'].append(dict(input=times,output=add(rows,kind),interpolation='STEP'))
        glb.doc['animations'].append(animation); clips[name] = clip
    assert bytes(glb.binary[:len(old_binary)]) == old_binary
    assert json.dumps(glb.doc['animations'][:-len(ENTRIES)],sort_keys=True) == old_animations
    glb.write(WORK/'motion.glb')

    # Reuse the validated recovery parser without running its whole-disc scan.
    parser_path = RECOVERY/'tools/recover_visuals.py'
    tree = ast.parse(parser_path.read_text())
    namespace = dict(struct=struct,np=np,math=math,json=json,defaultdict=defaultdict,OUT=OUT)
    def write(path, data): (OUT/path).write_bytes(data)
    namespace['write'] = write
    exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ('packet','tmd','glb','color555')],type_ignores=[]),str(parser_path),'exec'),namespace)
    sys.path.insert(0,str(RECOVERY/'tools/BFM-decomp/tools'))
    from bfm_extract.pac import split_pac

    def vram(module):
        words = np.zeros((512,1024),dtype='<u2'); present = np.zeros((512,1024),dtype=bool)
        for n in (10,module):
            pac = (RECOVERY/f'raw/MAIN.CD.dir/FILE_{n:03}').read_bytes()
            for e in split_pac(pac):
                if e.type != 0: continue
                mask = pac[e.offset+16:e.offset+80]
                indices = [i for i in range(512) if mask[i//8] & (1 << (i%8))]
                assert len(indices) == e.unknown and len(e.payload) == len(indices)*2048
                for j,tile in enumerate(indices):
                    x,y = tile%32*32,tile//32*32
                    words[y:y+32,x:x+32] = np.frombuffer(e.payload,dtype='<u2',count=1024,offset=j*2048).reshape(32,32)
                    present[y:y+32,x:x+32] = True
        # Runtime type9 LoadImage descriptors replace palette rows after PAC upload.
        data = modules[module]
        for offset in range(0,len(data)-20,4):
            kind,index,x,y,w,h,pointer = struct.unpack_from('<6HI',data,offset)
            start=pointer-BASE
            if kind!=9 or w!=16 or h!=1 or x!=352 or not 256<=y<512 or not 0<=start<=len(data)-32: continue
            words[y,x:x+16] = np.frombuffer(data,dtype='<u2',count=16,offset=start)
            present[y,x:x+16] = True
        return words,present

    models = {}
    words,present = vram(33)
    # 1CB6C's source rectangle (416,256), sprite CB8B0, CLUT row0.
    yy,xx = np.indices((32,64)); sx=416+xx//4; sy=256+yy
    indices=(words[sy,sx] >> ((xx%4)*4)) & 15
    assert present[sy,sx].all() and present[281,352+indices].all()
    Image.fromarray(namespace['color555'](words[281,352+indices])).save(OUT/'fence.png')
    words,present = vram(40)
    explosion_frames=[]
    for i in range(10):
        x,y,hold,flags=struct.unpack_from('<4H',modules[40],0x800CB8F8-BASE+i*8)
        assert hold==(193 if i==9 else 1) and flags==0
        yy,xx=np.indices((32,32)); sx=x+xx//4;sy=y+yy
        indices=(words[sy,sx] >> ((xx%4)*4)) & 15
        assert present[sy,sx].all() and present[400,352+indices].all()
        explosion_frames.append(namespace['color555'](words[400,352+indices]))
    Image.fromarray(np.concatenate(explosion_frames,axis=0)).save(OUT/'explosion.png')
    trail_frames=[]
    for i in range(10):
        x,y,hold,flags=struct.unpack_from('<4H',resident['DATA'],0x800D3888-resident['BASE']+i*8)
        assert hold==(193 if i==9 else 1) and flags==0
        yy,xx=np.indices((32,32));sx=x+xx//4;sy=y+yy
        indices=(words[sy,sx] >> ((xx%4)*4)) & 15
        assert present[sy,sx].all() and present[412,352+indices].all()
        trail_frames.append(namespace['color555'](words[412,352+indices]))
    Image.fromarray(np.concatenate(trail_frames,axis=0)).save(OUT/'rocket_trail.png')
    for name, module, offset in [('dkick',32,2028),('three_way',38,5680),('homing',39,4472),('grenade',40,3084)]:
        model = namespace['tmd'](modules[module],offset); textures = {}; words,present = vram(module)
        for obj in model['objects']:
            for p in obj['primitives']:
                if p['tpage'] is None: continue
                tsb,cba = p['tpage'],p['clut']; assert (tsb>>7)&3 == 0
                yy,xx = np.indices((256,256)); sx=((tsb&15)*64+xx//4)%1024; sy=(((tsb>>4)&1)*256+yy)%512
                indices = (words[sy,sx] >> ((xx%4)*4)) & 15
                cx,cy = (cba&63)*16,cba>>6
                coverage = present[sy,sx] & present[cy,cx+indices]
                for u,v in p['uv']: assert coverage[v,u], (name,u,v)
                pixels = namespace['color555'](words[cy,cx+indices])
                texture = f'{name}_{tsb}_{cba}.png'; Image.fromarray(pixels).save(OUT/texture)
                textures[(tsb,cba,bool(p['mode']&2),bool(p['flag']&2))] = texture
        namespace['glb'](model,textures,Path(name+'.glb'))
        native = GLB.read(OUT/(name+'.glb'))
        for mesh in native.doc['meshes']:
            for primitive in mesh['primitives']:
                count=native.doc['accessors'][primitive['attributes']['POSITION']]['count']
                primitive['indices']=native.append_accessor([(i+j,) for i in range(0,count,3) for j in (0,2,1)],dict(type='SCALAR',componentType=5125))
        native.write(OUT/(name+'.glb'))
        models[name] = dict(module=module,offset=offset,polygons=sum(len(o['primitives']) for o in model['objects']),textured_polygons=sum(p['tpage'] is not None for o in model['objects'] for p in o['primitives']))
    report = dict(clips=clips,models=models,joint_frame_checks=checks,maximum_float32_transform_error=maximum_error,
                  sources={str(n):hashlib.sha256(d).hexdigest() for n,d in modules.items()},
                  resident_sha256=hashlib.sha256(resident['DATA']).hexdigest(),
                  notes=['Original source pose ticks at30Hz; original geometry and CLUT pixels.',
                         'Host targeting, terrain, damage scaling and input are adapted to Goemon.',
                         'Dry decoded source audio does not emulate the full PS1 SPU mixer.'])
    (OUT/'sources.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Recovered',len(clips),'body streams;',checks,'joint frames; error',maximum_error)


if __name__ == '__main__': main()
