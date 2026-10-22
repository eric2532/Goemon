"""Append omitted retail body entries and retain original command/event data.

Uses the supplied SLUS-007.26 resident; never modifies existing GLB animations,
geometry, materials, skins or textures. NumPy is available in the Codex runtime.
"""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import struct
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from recover_musashi_motion_continuations import quaternion, source_transform, trs

MISSING = [0x800D4D88, 0x800D4DA8, 0x800D4DB4, 0x800D4DD4, 0x800D4DF4,
           0x800D4E6C, 0x800D52A8, 0x800D52E8, 0x800D533C, 0x800D5C6C, 0x800D53A4]
ACTION_ENTRIES = dict(fusion_1=0x800D4C94, fusion_2=0x800D4CE4,
                      fusion_3=0x800D4D38, fusion_4=0x800D4D88,
                      fusion_4_rise=0x800D4DA8, fusion_4_apex=0x800D4DB4,
                      fusion_4_drop=0x800D4DD4, fusion_4_land=0x800D4DF4,
                      lumina=0x800D4F14, air_lumina=0x800D4F8C,
                      air_fusion=0x800D4E94, moving_air_fusion=0x800D4ED4,
                      guard=0x800D5734, guard_walk=0x800D5790,
                      rotation=0x800D5360, rotation_end=0x800D53A4,
                      counter=0x800D552C, hurt=0x800D5880)


def hidden_parts(events, tick, initial_flags=0x10000000):
    flags = initial_flags
    for event in events:
        if event['tick'] > tick:
            continue
        op = int(event['word'], 16)
        if op == 16: flags |= 0x10000000
        elif op == 17: flags &= ~0x10000000
        elif op == 18: flags |= 0x20000000
        elif op == 19: flags &= ~0x20000000
        elif op == 25: flags &= ~0x20000
        elif op == 26: flags |= 0x20000
    hidden = {21, 22, 24, 25}
    if not flags & 0x20000:
        hidden.remove(25 if flags & 0x20000000 else 24)
    hidden.remove(22 if flags & 0x10000000 else 21)
    return hidden


def recover(root: Path, glb_path: Path):
    reader = runpy.run_path(str(root / 'tools/recover_musashi_motion.py'))
    manifest = json.loads((root / 'animation_recovery/musashi_motion.json').read_text())
    source_hash = hashlib.sha256(reader['DATA']).hexdigest()
    assert source_hash == manifest['source_sha256']
    blob = glb_path.read_bytes()
    size = struct.unpack_from('<I', blob, 12)[0]
    doc = json.loads(blob[20:20 + size])
    binary = bytearray(blob[28 + size:])
    old_binary = bytes(binary)
    old_actions = json.dumps(doc['animations'], sort_keys=True)
    original_count = len(doc['animations'])
    names = {a['name'] for a in doc['animations']}
    parents = {child: i for i, n in enumerate(doc['nodes']) for child in n.get('children', [])}
    parts = {int(n['name'].split('_')[1]): i for i, n in enumerate(doc['nodes'])
             if n.get('name', '').startswith('Part_')}

    def world(index):
        node = doc['nodes'][index]
        local = trs(node.get('translation', [0, 0, 0]), node.get('rotation', [0, 0, 0, 1]),
                    node.get('scale', [1, 1, 1]))
        return world(parents[index]) @ local if index in parents else local

    def add(values, kind):
        values = np.array(values, dtype='<f4')
        binary.extend(b'\0' * (-len(binary) % 4))
        view = len(doc['bufferViews'])
        doc['bufferViews'].append(dict(buffer=0, byteOffset=len(binary), byteLength=values.nbytes))
        binary.extend(values.tobytes())
        accessor = dict(bufferView=view, componentType=5126, count=len(values), type=kind)
        if kind == 'SCALAR':
            accessor.update(min=[float(values.min())], max=[float(values.max())])
        index = len(doc['accessors'])
        doc['accessors'].append(accessor)
        return index

    def describe(address):
        clip = reader['decode'](address)
        matching = sorted(n for n in names if n.endswith('%08x' % address))
        active = [e['tick'] for e in clip['events'] if e['word'] == '0x14']
        return dict(address=hex(address), clip=matching[0] if matching else 'Recovered__%08x' % address,
                    ticks=clip['ticks'], terminal=clip['terminal'], frames=clip['frames'],
                    events=clip['events'], active_ticks=active,
                    externally_clocked=any(f['source_hold_ticks'] == 0 for f in clip['frames']))

    max_error = 0.0
    checks = 0
    additions = []
    for address in MISSING:
        clip = describe(address)
        name = 'Recovered__%08x' % address
        append = name not in names
        # Normal gameplay entry context has Fusion drawn and Lumina sheathed.
        # Explicit command flags override this immediately. Bare continuation
        # entries retain that inherited context, recorded in the manifest.
        clip['initial_visibility_opcodes'] = [18] if address == 0x800D53A4 else [19]
        clip['initial_visibility_flags'] = 0x30000000 if address == 0x800D53A4 else 0x10000000
        expanded = clip['frames'] + [dict(tick=clip['ticks'], pose=clip['frames'][-1]['pose'])]
        if append:
            times = add([f['tick'] / 30 for f in expanded], 'SCALAR')
            animation = dict(name=name, channels=[], samplers=[])
        for part, node in parts.items():
            parent = world(parents[node])
            inv_parent = np.linalg.inv(parent)
            translations, rotations, scales = [], [], []
            for frame in expanded:
                hidden = hidden_parts(clip['events'], frame['tick'], clip['initial_visibility_flags'])
                expected = source_transform(reader['pose'](int(frame['pose'], 16))['parts'][part])
                local = inv_parent @ expected
                q = quaternion(local[:3, :3])
                translations.append(local[:3, 3]); rotations.append(q)
                scales.append([0.000001 if part in hidden else 1.0] * 3)
                error = float(np.max(np.abs(expected - parent @ trs(local[:3, 3], q, [1, 1, 1]))))
                assert error < 0.00001, (hex(address), part, error)
                max_error = max(max_error, error); checks += 1
            if append:
                for kind, values, channel in [('VEC3', translations, 'translation'),
                                              ('VEC4', rotations, 'rotation'), ('VEC3', scales, 'scale')]:
                    sampler = len(animation['samplers'])
                    animation['samplers'].append(dict(input=times, output=add(values, kind), interpolation='STEP'))
                    animation['channels'].append(dict(sampler=sampler, target=dict(node=node, path=channel)))
        if append:
            doc['animations'].append(animation)
            names.add(name)
        clip['clip'] = name
        additions.append(clip)
    assert json.dumps(doc['animations'][:original_count], sort_keys=True) == old_actions
    assert bytes(binary[:len(old_binary)]) == old_binary
    if len(doc['animations']) != original_count:
        doc['buffers'][0]['byteLength'] = len(binary)
        encoded = json.dumps(doc, separators=(',', ':')).encode()
        encoded += b' ' * (-len(encoded) % 4)
        binary.extend(b'\0' * (-len(binary) % 4))
        output = struct.pack('<III', 0x46546C67, 2, 28 + len(encoded) + len(binary))
        output += struct.pack('<II', len(encoded), 0x4E4F534A) + encoded
        output += struct.pack('<II', len(binary), 0x004E4942) + binary
        glb_path.write_bytes(output)
    # Read the stored float32 channels back from the GLB. A transform check
    # before encoding alone cannot catch a bad sampler, accessor or channel.
    stored = glb_path.read_bytes()
    stored_size = struct.unpack_from('<I', stored, 12)[0]
    saved_doc = json.loads(stored[20:20 + stored_size])
    saved_binary = stored[28 + stored_size:]

    def accessor(index):
        entry = saved_doc['accessors'][index]
        view = saved_doc['bufferViews'][entry['bufferView']]
        width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[entry['type']]
        offset = view.get('byteOffset', 0) + entry.get('byteOffset', 0)
        return np.frombuffer(saved_binary, dtype='<f4', count=entry['count'] * width,
                             offset=offset).reshape(entry['count'], width)

    stored_checks = 0
    stored_error = 0.0
    for clip in additions:
        animation = next(a for a in saved_doc['animations'] if a['name'] == clip['clip'])
        channels = {}
        for channel in animation['channels']:
            sampler = animation['samplers'][channel['sampler']]
            assert sampler['interpolation'] == 'STEP'
            channels.setdefault(channel['target']['node'], {})[channel['target']['path']] = accessor(sampler['output'])
            expected_times = [f['tick'] / 30 for f in clip['frames']] + [clip['ticks'] / 30]
            assert np.array_equal(accessor(sampler['input']).reshape(-1), np.array(expected_times, dtype='<f4'))
        expanded = clip['frames'] + [dict(tick=clip['ticks'], pose=clip['frames'][-1]['pose'])]
        for part, node in parts.items():
            values = channels[node]
            for i, frame in enumerate(expanded):
                source = reader['pose'](int(frame['pose'], 16))['parts'][part]
                reconstructed = world(parents[node]) @ trs(values['translation'][i], values['rotation'][i], [1, 1, 1])
                error = float(np.max(np.abs(reconstructed - source_transform(source))))
                assert error < 0.00001, (clip['clip'], part, i, error)
                hidden = part in hidden_parts(clip['events'], frame['tick'], clip['initial_visibility_flags'])
                want_scale = np.array([0.000001 if hidden else 1.0] * 3, dtype='<f4')
                assert np.array_equal(values['scale'][i], want_scale), (clip['clip'], part, i, 'visibility')
                stored_error = max(stored_error, error); stored_checks += 1
    actions = {key: describe(address) for key, address in ACTION_ENTRIES.items()}
    return dict(source_sha256=source_hash, source=manifest['source'],
                original_animations_preserved=original_count,
                imported_animation_count=len(doc['animations']), recovered=additions,
                actions=actions, joint_frame_checks=checks, maximum_transform_error=max_error,
                stored_glb_joint_frame_checks=stored_checks, maximum_stored_transform_error=stored_error,
                glb_sha256=hashlib.sha256(glb_path.read_bytes()).hexdigest(),
                timing='Original animation ticks exported at nominal 30 Hz; emulator timing comparison remains pending.',
                visibility='Bare continuation entries use the documented normal drawn-Fusion context; other save-state contexts require runtime flags.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recovery-root', type=Path, required=True)
    parser.add_argument('--glb', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    report = recover(args.recovery_root, args.glb)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k not in ['actions', 'recovered']}, indent=2))


if __name__ == '__main__':
    main()
