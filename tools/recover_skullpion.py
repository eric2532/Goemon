"""Recover Skullpion's ROM part list and complete source motion streams."""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import struct
from asset_pipeline.glb import GLB, texture_slots

ROOT = Path(__file__).resolve().parents[1]
BASE = 0x80128158
SOURCE = 'raw/SC03.CD.dir/FILE_028.dir/0.4.dec'
LISTS = [('Part', 0x801ADB18, 22)]
STREAM_START = 0x801ADC24
STREAM_END = 0x801AEA04


def rotation(angles):
    x, y, z = [v * math.pi / 4096 for v in angles]
    cx, cy, cz = math.cos(x), math.cos(y), math.cos(z)
    sx, sy, sz = math.sin(x), math.sin(y), math.sin(z)
    return [sx*cy*cz-cx*sy*sz, -(cx*sy*cz+sx*cy*sz), -(cx*cy*sz-sx*sy*cz), cx*cy*cz+sx*sy*sz]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recovery-root', type=Path, default=ROOT/'build/Other Files/Musashi Asset Recovery')
    parser.add_argument('--output', type=Path, default=ROOT/'assets/characters/recovered_skullpion')
    args = parser.parse_args()
    recover(args)
    recover(args, [('Drill',0x801E2178,3)], 0x801E2458, 0x801E2500, 'drill')
    recover(args, [('Impact',0x801E2B98,1)], 0, 0, 'impact')


def recover(args, lists=LISTS, stream_start=STREAM_START, stream_end=STREAM_END, filename='skullpion', source_file=SOURCE, source_base=BASE):
    BASE = source_base
    data = (args.recovery_root/source_file).read_bytes()
    visual = json.loads((args.recovery_root/'visual_manifest.json').read_text())
    models = {m['id']:m for m in visual['models']}
    occurrences = {BASE+o['offset']:o for o in visual['model_occurrences'] if o['source']==source_file}
    def record(address, fmt):
        size = struct.calcsize(fmt)
        if BASE <= address <= BASE+len(data)-size: return struct.unpack_from(fmt, data, address-BASE)
        raise ValueError(f'ROM address out of bounds: {address:#x}')
    doc = {'asset':{'version':'2.0','generator':'Goemon ROM recovery: Skullpion'}, 'scene':0,
           'scenes':[{'nodes':[0]}], 'nodes':[{'name':'Skullpion','scale':[.01]*3,'children':[]}],
           'meshes':[], 'materials':[], 'accessors':[], 'bufferViews':[], 'textures':[], 'images':[], 'samplers':[],
           'extensionsUsed':['KHR_materials_unlit'], 'animations':[]}
    output = GLB(doc, b'')
    parts, groups, poses = [], [], {}
    for group, address, count in lists:
        nodes = []
        for index in range(count):
            pointer, = record(address+index*4, '<I')
            occurrence = occurrences[pointer]
            model = models[occurrence['model']]
            source_path = args.recovery_root/model['path']
            source = GLB.read(source_path)
            sd = copy.deepcopy(source.doc)
            offsets = {key:len(doc[key]) for key in ['meshes','materials','accessors','bufferViews','textures','images','samplers']}
            while len(output.binary)%4: output.binary.append(0)
            start = len(output.binary); output.binary.extend(source.binary)
            for view in sd['bufferViews']: view['byteOffset'] = view.get('byteOffset',0)+start
            for accessor in sd['accessors']: accessor['bufferView'] += offsets['bufferViews']
            for image in sd.get('images',[]): image['bufferView'] += offsets['bufferViews']
            for texture in sd.get('textures',[]):
                texture['source'] += offsets['images']
                if 'sampler' in texture: texture['sampler'] += offsets['samplers']
            for material in sd['materials']:
                for container, key in texture_slots(material): container[key]['index'] += offsets['textures']
            for mesh in sd['meshes']:
                for primitive in mesh['primitives']:
                    primitive['attributes'] = {k:v+offsets['accessors'] for k,v in primitive['attributes'].items()}
                    primitive['material'] += offsets['materials']
                    if 'indices' in primitive: primitive['indices'] += offsets['accessors']
            for key in offsets: doc[key].extend(sd.get(key,[]))
            # PSX packets are clockwise; glTF outer faces are counter-clockwise.
            for primitive in doc['meshes'][offsets['meshes']]['primitives']:
                count_ = doc['accessors'][primitive['attributes']['POSITION']]['count']
                primitive['indices'] = output.append_accessor(
                    [(i+j,) for i in range(0,count_,3) for j in (0,2,1)],
                    {'type':'SCALAR','componentType':5125})
                doc['bufferViews'][doc['accessors'][primitive['indices']]['bufferView']]['target']=34963
            assert len(sd['nodes'])==1 and 'mesh' in sd['nodes'][0], 'Expected single rigid TMD object'
            node = len(doc['nodes']); nodes.append(node); doc['nodes'][0]['children'].append(node)
            name = f'{group}_{index:02d}'
            doc['nodes'].append({'name':name,'mesh':offsets['meshes'], 'extras':{'source_address':hex(pointer),'source_model':model['id']}})
            parts.append({'node':node,'name':name,'group':group,'index':index,'model':model['id'],
                          'source_address':hex(pointer),'source_glb':model['path'],'source_glb_sha256':hashlib.sha256(source_path.read_bytes()).hexdigest(),
                          'source_tmd':model['tmd'],'source_tmd_sha256':model['sha256_tmd'], 'texture_coverage':{k:model[k] for k in ['resolved_texture_polygons','partial_texture_polygons','unresolved_texture_polygons']}})
        assert record(address+count*4,'<I')[0]==0
        groups.append({'name':group,'nodes':nodes,'list_address':hex(address),'count':count})
    clips = []
    address = stream_start
    index = 0
    while address < stream_end:
        streams = [address]; paired = []
        for group, address in zip(groups,streams):
            frames=[]; tick=0; start=address
            for _ in range(512):
                pointer, hold, flags = record(address,'<IhH'); address += 8
                if hold<0:
                    assert pointer==0 and hold in (-1,-2), (hex(address-8),pointer,hold)
                    break
                assert hold>=0 and flags==0
                key=hex(pointer)
                values=[record(pointer+i*12,'<6h') for i in range(group['count'])]
                pose=[{'position':list(p[:3]),'angles':list(p[3:])} for p in values]
                poses[key]=pose
                frames.append({'tick':tick,'hold':hold,'pose':key,'command_address':hex(address-8)})
                tick+=max(1,hold)
                if hold==0: break
            else: raise ValueError('Unterminated animation stream')
            paired.append({'group':group['name'],'address':hex(start),'frames':frames,'ticks':tick,'terminal':'loop' if hold==-1 else ('external_hold' if hold==0 else 'stop'),
                           'stream_sha256':hashlib.sha256(data[start-BASE:address-BASE]).hexdigest()})
        duration=max(s['ticks'] for s in paired)
        animation={'name':f'Source__{streams[0]:08x}','channels':[],'samplers':[],'extras':{'source_table_index':index,'source_pair':[hex(p) for p in streams]}}
        for group, stream in zip(groups,paired):
            frames=stream['frames']; end=stream['ticks']
            if stream['terminal']=='loop':
                repeated=list(frames)
                while end<duration:
                    repeated.extend({**f,'tick':f['tick']+end} for f in frames);end+=stream['ticks']
                frames=[f for f in repeated if f['tick']<duration]
            frames=frames+[{'tick':duration,'pose':frames[0]['pose'] if end==duration and stream['terminal']=='loop' else frames[-1]['pose']}]
            times=output.append_accessor([(f['tick']/30,) for f in frames],{'type':'SCALAR','componentType':5126})
            doc['accessors'][times].update(min=[0],max=[duration/30])
            for part_index,node in enumerate(group['nodes']):
                samples=[poses[f['pose']][part_index] for f in frames]
                translations=[[p['position'][0],-p['position'][1],-p['position'][2]] for p in samples]
                rotations=[rotation(p['angles']) for p in samples]
                if index==0: doc['nodes'][node].update(translation=translations[0],rotation=rotations[0])
                for prop,values,kind in [('translation',translations,'VEC3'),('rotation',rotations,'VEC4')]:
                    accessor=output.append_accessor(values,{'type':kind,'componentType':5126})
                    animation['channels'].append({'sampler':len(animation['samplers']),'target':{'node':node,'path':prop}})
                    animation['samplers'].append({'input':times,'output':accessor,'interpolation':'STEP'})
        doc['animations'].append(animation)
        clips.append({'name':animation['name'],'index':index,'ticks':duration,'streams':paired})
        index += 1
    args.output.mkdir(parents=True,exist_ok=True)
    for key in ['animations','images','samplers','textures']:
        if not doc[key]:doc.pop(key)
    path=args.output/(filename+'.glb'); output.write(path)
    manifest={'name':'Skullpion','source':source_file,'source_base':hex(BASE),'source_sha256':hashlib.sha256(data).hexdigest(),
              'parts':parts,'groups':groups,'clips':clips,'poses':poses,'fps':30,'scale':.01,
              'notes':[f'{len(parts)} original rigid mesh parts; flat nodes preserve actor-space poses and indices convert PSX winding.',
                       'Source stream addresses are authoritative; zero hold is externally released and previewed for one tick.',
                       'Nominal 30 Hz preview; root travel, effects and encounter logic are separate runtime code.'],
              'glb_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    (args.output/('motion.json' if filename=='skullpion' else filename+'_motion.json')).write_text(json.dumps(manifest,indent=2))
    print(json.dumps({'parts':len(parts),'animations':len(clips),'poses':len(poses),'output':str(path)}))

if __name__=='__main__': main()
