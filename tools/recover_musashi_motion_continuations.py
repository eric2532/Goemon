"""Append missed source streams without changing the original 64 GLB actions.

Requires NumPy. Input recovery directory contains the preserved resident blob,
musashi_motion.json and its decoder. Pause resumption keeps the ORIGINAL stream
base and program counter: opcode 6 is an index into that stream, not the tail.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import runpy
import struct

import numpy as np


def decode(reader, start, pc=0):
    stream = start
    rate = 1
    ticks = 0
    frames, events, seen = [], [], {}
    for _ in range(4096):
        state = (stream, pc, rate)
        if state in seen:
            return dict(frames=frames, events=events, ticks=ticks,
                        terminal='loop', loop_tick=seen[state])
        seen[state] = ticks
        address = stream + pc * 4
        op = reader['word'](address)
        event = dict(address=hex(address), tick=ticks, opcode=op)
        if op in (0, 1, 2):
            return dict(frames=frames, events=events, ticks=ticks,
                        terminal={0: 'stop', 1: 'loop', 2: 'pause'}[op], loop_tick=0)
        if op == 3:
            rate = reader['word'](address + 4) & 255
            assert rate > 0, 'Externally clocked streams need separate handling'
            pc += 2
        elif op == 5:
            stream, pc = reader['word'](address + 4), reader['word'](address + 8)
        elif op == 6:
            pc = reader['word'](address + 4)
        elif op in (4, 11, 12, 14, 15, 21, 22):
            pc += 2
        elif op in (7, 8, 9, 10, 13, 16, 17, 18, 19, 20, 25, 26):
            pc += 1
        else:
            assert op > 26, f'Unsupported opcode {op}'
            reader['pose'](op)
            frames.append(dict(tick=ticks, pose=hex(op), address=hex(address)))
            ticks += rate
            pc += 1
            continue
        events.append(event)
    raise ValueError('Command budget exceeded')


def trs(t, q, s):
    x, y, z, w = np.array(q) / np.linalg.norm(q)
    result = np.eye(4)
    result[:3, :3] = np.array([
        [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
        [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
        [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]]) @ np.diag(s)
    result[:3, 3] = t
    return result


def quaternion(r):
    # Stable eigenvector construction; result is glTF x,y,z,w.
    k = np.array([
        [r[0,0]-r[1,1]-r[2,2], r[1,0]+r[0,1], r[2,0]+r[0,2], r[2,1]-r[1,2]],
        [r[1,0]+r[0,1], r[1,1]-r[0,0]-r[2,2], r[2,1]+r[1,2], r[0,2]-r[2,0]],
        [r[2,0]+r[0,2], r[2,1]+r[1,2], r[2,2]-r[0,0]-r[1,1], r[1,0]-r[0,1]],
        [r[2,1]-r[1,2], r[0,2]-r[2,0], r[1,0]-r[0,1], np.trace(r)]]) / 3
    _, vectors = np.linalg.eigh(k)
    q = vectors[:, -1]
    return q if q[3] >= 0 else -q


def source_transform(part):
    x, y, z = [a * math.tau / 4096 for a in part['angles']]
    rx = np.array([[1,0,0],[0,math.cos(x),-math.sin(x)],[0,math.sin(x),math.cos(x)]])
    ry = np.array([[math.cos(y),0,math.sin(y)],[0,1,0],[-math.sin(y),0,math.cos(y)]])
    rz = np.array([[math.cos(z),-math.sin(z),0],[math.sin(z),math.cos(z),0],[0,0,1]])
    r = rz @ ry @ rx
    if part['hair_y_half_turn']:
        r = r @ np.diag([-1,1,-1])
    c = np.array([[1,0,0],[0,0,1],[0,-1,0]])
    conversion = np.eye(4)
    conversion[:3,:3] = c
    result = np.eye(4)
    result[:3,:3] = c @ r @ c.T
    result[:3,3] = c @ np.array(part['position']) * .01
    return conversion @ result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recovery-root', type=Path, required=True)
    parser.add_argument('--glb', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    reader = runpy.run_path(str(args.recovery_root/'tools/recover_musashi_motion.py'))
    manifest = json.loads((args.recovery_root/'animation_recovery/musashi_motion.json').read_text())
    assert hashlib.sha256(reader['DATA']).hexdigest() == manifest['source_sha256']
    blob = args.glb.read_bytes()
    size = struct.unpack_from('<I', blob, 12)[0]
    doc = json.loads(blob[20:20+size])
    binary = bytearray(blob[28+size:])
    original_bytes = bytes(binary)
    original_actions = json.dumps(doc['animations'], sort_keys=True)
    assert not any(a['name'].startswith('Source__') for a in doc['animations']), 'Use the unextended styled GLB'
    parents = {child:i for i,n in enumerate(doc['nodes']) for child in n.get('children', [])}
    part_nodes = {int(n['name'].split('_')[1]):i for i,n in enumerate(doc['nodes']) if n.get('name','').startswith('Part_')}
    def world(i):
        n = doc['nodes'][i]
        local = trs(n.get('translation',[0,0,0]), n.get('rotation',[0,0,0,1]), n.get('scale',[1,1,1]))
        return (world(parents[i]) if i in parents else np.eye(4)) @ local
    def add(values, kind):
        values = np.array(values, dtype='<f4')
        binary.extend(b'\0' * (-len(binary) % 4))
        offset = len(binary)
        binary.extend(values.tobytes())
        view = len(doc['bufferViews'])
        doc['bufferViews'].append(dict(buffer=0, byteOffset=offset, byteLength=values.nbytes))
        accessor = dict(bufferView=view, componentType=5126, count=len(values), type=kind)
        if kind == 'SCALAR':
            accessor.update(min=[float(values.min())], max=[float(values.max())])
        index = len(doc['accessors'])
        doc['accessors'].append(accessor)
        return index
    additions = []
    max_error = 0
    checks = 0
    # First two resume AFTER opcode 2 with PC still relative to the jump stream.
    for start, entry in [(0x800d4a9c,0x800d4ad4), (0x800d4b48,0x800d4b70),
                         (0x800d4ce4,0x800d4ce4), (0x800d4d38,0x800d4d38)]:
        clip = decode(reader, start, (entry-start)//4)
        assert clip['frames']
        clip.update(name=f'Source__{entry:08x}', stream=hex(start), entry=hex(entry))
        prefix = []
        if entry != start:
            prefix = [int(e['word'],16) for e in reader['decode'](start)['events']
                      if int(e['command_address'],16) < entry]
        clip['inherited_opcodes'] = prefix
        def hidden_parts(tick):
            flags = 0x30000000
            for op in prefix + [e['opcode'] for e in clip['events'] if e['tick'] <= tick]:
                if op == 16: flags |= 0x10000000
                elif op == 17: flags &= ~0x10000000
                elif op == 18: flags |= 0x20000000
                elif op == 19: flags &= ~0x20000000
                elif op == 25: flags &= ~0x20000
                elif op == 26: flags |= 0x20000
            hidden = {21,22,24,25}
            if not flags & 0x20000:
                hidden.remove(25 if flags & 0x20000000 else 24)
            hidden.remove(22 if flags & 0x10000000 else 21)
            return hidden
        frames = clip['frames']
        endpoint = frames[-1]
        if clip['terminal'] == 'loop':
            endpoint = next(f for f in frames if f['tick'] == clip['loop_tick'])
        expanded = frames + [dict(tick=clip['ticks'], pose=endpoint['pose'])]
        times = add([f['tick']/30 for f in expanded], 'SCALAR')
        animation = dict(name=clip['name'], channels=[], samplers=[])
        for part, node in part_nodes.items():
            parent = world(parents[node])
            inv_parent = np.linalg.inv(parent)
            translations, rotations, scales = [], [], []
            for frame in expanded:
                pose = reader['pose'](int(frame['pose'],16))
                expected = source_transform(pose['parts'][part])
                hidden = part in hidden_parts(frame['tick'])
                local = inv_parent @ expected
                q = quaternion(local[:3,:3])
                scale = [.000001 if hidden else 1.0] * 3
                translations.append(local[:3,3]);rotations.append(q);scales.append(scale)
                unhidden = parent @ trs(translations[-1], q, [1,1,1])
                error = float(np.max(np.abs(expected-unhidden)))
                max_error = max(max_error,error);checks += 1
                assert error < .00001, (clip['name'], part, error)
            for kind, values, path in [('VEC3',translations,'translation'), ('VEC4',rotations,'rotation'), ('VEC3',scales,'scale')]:
                sampler = len(animation['samplers'])
                animation['samplers'].append(dict(input=times, output=add(values,kind), interpolation='STEP'))
                animation['channels'].append(dict(sampler=sampler, target=dict(node=node,path=path)))
        doc['animations'].append(animation)
        clip['pose_hashes'] = {f['pose']:reader['pose'](int(f['pose'],16))['sha256'] for f in frames}
        additions.append(clip)
    assert json.dumps(doc['animations'][:-4],sort_keys=True) == original_actions
    assert bytes(binary[:len(original_bytes)]) == original_bytes
    doc['buffers'][0]['byteLength'] = len(binary)
    encoded = json.dumps(doc,separators=(',',':')).encode()
    encoded += b' ' * (-len(encoded)%4)
    binary.extend(b'\0' * (-len(binary)%4))
    output = struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))
    output += struct.pack('<II',len(encoded),0x4e4f534a)+encoded
    output += struct.pack('<II',len(binary),0x004e4942)+binary
    args.glb.write_bytes(output)
    report = dict(source_sha256=manifest['source_sha256'], added=additions,
                  unchanged_original_actions=64, joint_frame_checks=checks,
                  maximum_transform_error=max_error, glb_sha256=hashlib.sha256(output).hexdigest())
    args.report.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='added'},indent=2))
    for c in additions:
        print(c['name'],c['ticks'],c['terminal'],'loop_tick',c['loop_tick'])


if __name__ == '__main__':
    main()
