"""Recover the retail Vambee family and Haya Wolf, including every source stream.

Geometry assembly reuses the rigid TMD recovery path. Tagged pointers select
packed 8-byte poses; untagged pointers select full 12-byte poses in the SAME clip.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
from asset_pipeline.glb import GLB
from recover_skullpion import BASE, recover, rotation

ROOT = Path(__file__).resolve().parents[1]
RECOVERY = ROOT/'build/Other Files/Musashi Asset Recovery'
OUT = ROOT/'assets/characters/recovered_monsters'
SLOW_GUY = 'raw/SC04.CD.dir/FILE_002.dir/0.4.dec'
WOLF = 'raw/SC04.CD.dir/FILE_004.dir/0.4.dec'
VAMBEE = 'raw/SC03.CD.dir/FILE_089.dir/0.4.dec'


def streams(data, start, end, base=BASE):
    clips = []
    address = start
    while address < end:
        first = address; tick = 0; frames = []
        while address < end:
            pointer, hold, flags = struct.unpack_from('<IhH', data, address-base)
            command = address; address += 8
            assert flags == 0, hex(command)
            if hold < 0:
                assert (hold in (-1, -2, -5) and pointer == 0) or hold == -4, (hex(command), hold)
                break
            pose = pointer & ~0x1000000
            assert base <= pose < base+len(data), hex(command)
            frames.append(dict(tick=tick, hold=hold, pose=hex(pose), tagged_pointer=hex(pointer),
                               command_address=hex(command), packed=bool(pointer & 0x1000000)))
            tick += max(1, hold)
        assert frames and hold < 0, hex(first)
        source_count = len(frames)
        if hold == -5:
            # 8012AAAC repeats the last pose, then 8012A988 reverses to pose zero.
            for frame in reversed(frames[1:]):
                frames.append(dict(frame, tick=tick))
                tick += max(1, frame['hold'])
        clips.append(dict(name=f'Source__{first:08x}', address=hex(first), frames=frames, ticks=tick,
                          terminal='loop' if hold in (-1, -5) else ('stop' if hold == -2 else 'redirect'), redirect=hex(pointer),
                          source_terminal=hold, source_frame_count=source_count,
                          stream_sha256=hashlib.sha256(data[first-base:address-base]).hexdigest()))
    assert address == end
    return clips


def pose(data, frame, count, base=BASE):
    address = int(frame['pose'], 16); result = []
    for part in range(count):
        if frame['packed']:
            b0,b1,b2,x,y,z,rx = struct.unpack_from('<3B3bh',data,address-base+part*8)
            angles = [rx & 4095, b1 | ((b0 & 15)<<8), b2 | ((b0 & 240)<<4)]
        else:
            x,y,z,*angles = struct.unpack_from('<6h',data,address-base+part*12)
        result.append(dict(position=[x,y,z], angles=angles))
    return result


def assemble(source, name, table, count, clips, semantics, base=BASE, output_dir=OUT):
    args = argparse.Namespace(recovery_root=RECOVERY, output=output_dir)
    recover(args, [('Part',table,count)], 0, 0, name, source_file=source, source_base=base)
    path = output_dir/(name+'.glb'); meta_path = output_dir/(name+'_motion.json')
    meta = json.loads(meta_path.read_text()); glb = GLB.read(path)
    data = (RECOVERY/source).read_bytes(); glb.doc['nodes'][0]['name'] = name
    glb.doc['asset']['generator'] = 'Goemon retail rigid enemy recovery'
    glb.doc['animations'] = []; poses = {}
    for clip in clips:
        frames = clip['frames']
        samples = frames+[dict(frames[0] if clip['terminal']=='loop' else frames[-1], tick=clip['ticks'])]
        times = glb.append_accessor([(f['tick']/30,) for f in samples],dict(type='SCALAR',componentType=5126))
        glb.doc['accessors'][times].update(min=[0],max=[clip['ticks']/30])
        for f in frames:
            if f['pose'] not in poses: poses[f['pose']] = pose(data,f,count,base)
        animation = dict(name=clip['name'],channels=[],samplers=[])
        for index, part in enumerate(meta['parts']):
            values = [poses[f['pose']][index] for f in samples]
            translations = [[p['position'][0],-p['position'][1],-p['position'][2]] for p in values]
            rotations = [rotation(p['angles']) for p in values]
            if clip == clips[0]:glb.doc['nodes'][part['node']].update(translation=translations[0],rotation=rotations[0])
            for prop, rows, kind in [('translation',translations,'VEC3'),('rotation',rotations,'VEC4')]:
                output = glb.append_accessor(rows,dict(type=kind,componentType=5126))
                animation['channels'].append(dict(sampler=len(animation['samplers']),target=dict(node=part['node'],path=prop)))
                animation['samplers'].append(dict(input=times,output=output,interpolation='STEP'))
        glb.doc['animations'].append(animation)
    glb.write(path)
    meta.update(name=name, clips=clips, poses=poses, semantics=semantics,
                glb_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                notes=['Original geometry, vertex colors, UVs and material pixels; PSX winding converted.',
                       'Every numeric source clip retained, including reactions and special states.',
                       'Mixed packed/full poses decoded per pointer tag; STEP presentation at nominal 30Hz.',
                       'Zero-hold source poses are externally advanced; preview gives each one tick.',
                       'Redirect targets retained in metadata; the preview ends at the redirect.',
                       'Actor root travel, life drain and hit timing are separate gameplay code.'])
    meta_path.write_text(json.dumps(meta,indent=2)+'\n')
    print(name, 'parts',count,'clips',len(clips),'poses',len(poses))


def recover_karate_wolf():
    data = (RECOVERY/WOLF).read_bytes()
    # The actor initializer selects this descriptor; its +4 points to 13 meshes.
    assert struct.unpack_from('<I', data, 0x8019db10-BASE)[0] == 0x801a1134
    clips = streams(data,0x801a82f8,0x801a8a58)
    assemble(WOLF,'karate_wolf',0x801a1134,13,clips,
             dict(idle='Source__801a82f8',walk='Source__801a8380',attack='Source__801a84d0',hurt='Source__801a8730',death='Source__801a8898'))


def main():
    slow_guy = streams((RECOVERY/SLOW_GUY).read_bytes(),0x801a16c4,0x801a1e1c)
    vambee = streams((RECOVERY/VAMBEE).read_bytes(),0x801b2100,0x801b4318)
    full = [c for c in vambee if not 0x801b3618 <= int(c['address'],16) < 0x801b3958
            and int(c['address'],16) not in (0x801b3fd0,0x801b4150)]
    torso = [c for c in vambee if 0x801b3618 <= int(c['address'],16) < 0x801b3958 or int(c['address'],16)==0x801b3fd0]
    legs = [c for c in vambee if int(c['address'],16)==0x801b4150]
    # Preserve the historical misnamed recovery and editable master as Slow Guy.
    assemble(SLOW_GUY,'haya_wolf',0x8019bb40,12,slow_guy,
             dict(idle='Source__801a16c4',walk='Source__801a176c',attack='Source__801a1874',hurt='Source__801a1a84',death='Source__801a1d24'))
    recover_karate_wolf()
    semantic=dict(idle='Source__801b3058',walk='Source__801b32d8',attack='Source__801b3958',
                  grab='Source__801b29c8',hurt='Source__801b2920',death='Source__801b3ee8')
    assemble(VAMBEE,'vambee',0x801a8a48,10,full,semantic)
    assemble(VAMBEE,'flying_vambee',0x801aa98c,10,full,semantic)
    assemble(VAMBEE,'vambee_torso',0x801abda8,6,torso,
             dict(idle=torso[0]['name'],walk=torso[-1]['name'],attack=torso[0]['name'],hurt=torso[1]['name'],death=torso[2]['name']))
    assemble(VAMBEE,'vambee_legs',0x801aca0c,5,legs,dict.fromkeys(['idle','walk','attack','hurt','death'],legs[0]['name']))
    assemble(VAMBEE,'flying_vambee_torso',0x801ade14,6,torso,{})
    assemble(VAMBEE,'flying_vambee_legs',0x801aea78,5,legs,{})


if __name__ == '__main__':main()
