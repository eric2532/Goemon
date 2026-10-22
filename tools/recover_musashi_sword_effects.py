"""Recover retail USA sword ribbons from byte-verified overlay and pose headers.

The source generates untextured Gouraud quads; there is no slash texture/CLUT.
SC01's actual translation unit overrides two shared header variants. Original
code/table bytes accompany the manifest so claims do not rely on those variants.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

OVERLAY = 'raw/SC01.CD.dir/FILE_000.dir/0.4.dec'
RESIDENT = 'raw/MAIN.CD.dir/FILE_010.dir/1.1'
EXECUTABLE = 'raw/SLUS_007.26'
OVERLAY_BASE = 0x80128158
RESIDENT_BASE = 0x800CEDF8
HASHES = {
    OVERLAY: '66a047a6242db0d212e27087b7576b19dbc12e399ae0d4f64f370e70bea35069',
    RESIDENT: 'f8bcfa41b6a637ed78f327737875ea05998088443c2776e18247c0f45a64014a',
    EXECUTABLE: '66371c3a7517e9eabd7cb6cf0c5abffe7296bd4bac29c85b8bf7bb9db349714a',
}
CLIPS = {
    'fusion_1': ('fusion', 0), 'fusion_2': ('fusion', 1),
    'fusion_3': ('fusion', 2), 'fusion_4': ('fusion', 3),
    'fusion_4_rise': ('fusion', 3), 'fusion_4_apex': ('fusion', 3),
    'fusion_4_drop': ('fusion', 3), 'fusion_4_land': ('fusion', 3),
    'air_fusion': ('fusion', 5), 'moving_air_fusion': ('fusion', 5),
    'lumina': ('lumina', 0), 'air_lumina': ('lumina', 5),
    'rotation': ('lumina', 8), 'rotation_end': ('lumina', 8),
    'counter': ('lumina', 7),
}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def quad_colors(trail_index, alternate, intensity, segments):
    """RGB byte values in native POLY_G4 vertex order, newest pair first.

    Faithfully preserves the alternate branch's per-quad recomputation, including
    its unequal shared-vertex colors. Inputs are the original ring header fields.
    """
    if not 0 <= intensity <= 255 or not 0 <= segments <= 15:
        raise ValueError('Invalid original ring header')
    bright, dim = intensity, intensity >> 1
    result = []
    for _ in range(segments):
        if trail_index < 2:
            if alternate:
                dim = (bright >> 1) + (bright >> 3)
                newest = [bright, bright, dim]
            else:
                newest = [dim, dim, bright]
        else:
            newest = [bright, dim, dim]
        bright -= 16
        dim = max(0, dim - 16)
        if trail_index < 2:
            oldest = [bright, bright, dim] if alternate else [dim, dim, bright]
        else:
            oldest = [bright, dim, dim]
        # C stores u8. The normal recorder/fade invariant avoids negative bright.
        newest = [v & 255 for v in newest]
        oldest = [v & 255 for v in oldest]
        result.append([newest[:], newest[:], oldest[:], oldest[:]])
    return result


def recover(recovery, output, actions_path):
    recovery, output = Path(recovery), Path(output)
    blobs = {}
    for name, label in [(OVERLAY, 'overlay'), (RESIDENT, 'resident'), (EXECUTABLE, 'executable')]:
        data = (recovery / name).read_bytes()
        if sha256(data) != HASHES[name]:
            raise ValueError('%s SHA-256 differs from supplied USA source' % label)
        blobs[name] = data
    overlay, resident = blobs[OVERLAY], blobs[RESIDENT]
    actions = json.loads(Path(actions_path).read_text())
    if actions['source_sha256'] != HASHES[RESIDENT]:
        raise ValueError('Action manifest uses a different resident')

    def read(address, size):
        offset = address - OVERLAY_BASE
        if not 0 <= offset <= len(overlay) - size:
            raise ValueError('Address outside SC01 overlay')
        return overlay[offset:offset + size]

    output.mkdir(parents=True, exist_ok=True)
    rawdir = output / 'sword'
    rawdir.mkdir(exist_ok=True)
    raw_assets = []

    def save(source, base, address, length, filename, purpose):
        data = blobs[source][address - base:address - base + length]
        if len(data) != length:
            raise ValueError('Truncated source region')
        relative = 'sword/' + filename
        (output / relative).write_bytes(data)
        entry = dict(path=relative, source=source, address=hex(address),
                     source_offset=address-base, byte_length=length,
                     sha256=sha256(data), purpose=purpose)
        raw_assets.append(entry)
        return entry

    save(OVERLAY, OVERLAY_BASE, 0x80181B6C, 0x4C,
         'timing_and_length_tables.bin', 'Two original byte-pair delay/duration tables and length-divisor tables')
    for address, end, name in [
        (0x80166690, 0x80166994, 'draw_gouraud_ribbon'),
        (0x80166994, 0x80166F58, 'record_midpoint_and_fade'),
        (0x801681FC, 0x80168430, 'fusion_states'),
        (0x80168430, 0x80168640, 'lumina_states'),
        (0x801484B0, 0x801485B8, 'endpoint_header_selection'),
        (0x801485B8, 0x80148634, 'signed_endpoint_decoder'),
        (0x80165FA4, 0x80166018, 'endpoint_rotation'),
        (0x80149350, 0x80149374, 'endpoint_world_transform'),
        (0x8012F14C, 0x8012F18C, 'endpoint_gte_transform'),
        (0x801555F4, 0x80155818, 'ground_fusion_initializer'),
        (0x80157E38, 0x80157EB4, 'ground_lumina_initializer'),
        (0x8015B6F4, 0x8015B7B4, 'air_fusion_initializer'),
        (0x8015B7B4, 0x8015B870, 'air_lumina_initializer'),
    ]:
        save(OVERLAY, OVERLAY_BASE, address, end-address, name + '.bin', name)
    save(OVERLAY, OVERLAY_BASE, 0x801A1D3C, 7*4, 'effect_actor_dispatch.bin', 'Effect queue type4 and5 select 80166618 and80166654')
    save(OVERLAY, OVERLAY_BASE, 0x80181BB8, 8*4, 'trail_state_dispatch.bin', 'Four-state Fusion and Lumina dispatch tables')
    # PS-X EXE text begins at 0x80010000, file offset 0x800.
    exe_base = 0x80010000 - 0x800
    save(EXECUTABLE, exe_base, 0x80017758, 0x170, 'poly_g4_builder.bin', 'Untextured POLY_G4; RGB byte ordering and submission flags')
    save(EXECUTABLE, exe_base, 0x80018094, 0x100, 'primitive_additive_submit.bin', '0x40000000 enables semitransparency, flag bits28..29 select ABR')

    weapons = {}
    for weapon, count, timing, divisor, actor, dispatch in [
        ('fusion', 10, 0x80181B6C, 0x80181B9C, 4, 0x80166618),
        ('lumina', 14, 0x80181B80, 0x80181BA8, 5, 0x80166654),
    ]:
        descriptors = []
        for i in range(count):
            delay, duration = read(timing + i*2, 2)
            descriptors.append(dict(descriptor=i, delay_ticks=delay, record_ticks=duration,
                                    length_divisor=read(divisor+i, 1)[0],
                                    trail_index=i & 1 if weapon == 'fusion' else 2))
        weapons[weapon] = dict(effect_actor=actor, dispatch=hex(dispatch),
                               descriptors=descriptors,
                               pose_header_offset=0 if weapon == 'fusion' else 8)
    clips = {}
    headers = {}
    for key, (weapon, descriptor) in CLIPS.items():
        action = actions['actions'][key]
        frames = []
        for frame in action['frames']:
            address = int(frame['pose'], 16)
            data = resident[address-RESIDENT_BASE:address-RESIDENT_BASE+16]
            if len(data) != 16:
                raise ValueError('Truncated pose header')
            headers[address] = data
            offset = weapons[weapon]['pose_header_offset']
            values = struct.unpack_from('<6b', data, offset)
            frames.append(dict(tick=frame['tick'], hold_ticks=frame.get('hold_ticks', 1),
                               source_hold_ticks=frame.get('source_hold_ticks', frame.get('hold_ticks', 1)),
                               pose=frame['pose'], pose_header_sha256=sha256(data),
                               endpoints_source=[list(values[:3]), list(values[3:])]))
        continuation = 'fusion_4' if key.startswith('fusion_4_') else ('rotation' if key == 'rotation_end' else None)
        clips[key] = dict(clip=action['clip'], stream=action['address'],
                          weapon=weapon, effect_descriptor=descriptor,
                          ticks=action['ticks'], frames=frames, terminal=action['terminal'],
                          externally_clocked=action.get('externally_clocked', False),
                          continuation_of=continuation)
    # Address+16 original bytes, sorted. Compact lossless data, not the whole ROM.
    header_bytes = b''.join(struct.pack('<I', a) + h for a, h in sorted(headers.items()))
    (rawdir / 'pose_headers.bin').write_bytes(header_bytes)
    raw_assets.append(dict(path='sword/pose_headers.bin', source=RESIDENT,
                           format='repeated little-endian u32 VRAM address + 16 raw pose-header bytes',
                           byte_length=len(header_bytes), count=len(headers), sha256=sha256(header_bytes)))
    result = dict(
        schema_version=1, title='Retail USA Musashi sword ribbons',
        source=dict(overlay=dict(path=OVERLAY, base=hex(OVERLAY_BASE), sha256=HASHES[OVERLAY]),
                    resident=dict(path=RESIDENT, base=hex(RESIDENT_BASE), sha256=HASHES[RESIDENT]),
                    executable=dict(path=EXECUTABLE, sha256=HASHES[EXECUTABLE]),
                    decomp_revision='b6a28f96bac70af70573826f767a96cf212fd5e3',
                    actual_translation_unit='src/ov_SC01_000/ov_SC01_000_jr_8015C32C.c',
                    note='Actual SC01 initializer bodies at801681FC/80168430 override shared variants; raw USA bytes are authoritative.'),
        native_hz=30,
        instruction_evidence=[dict(address=hex(a), little_endian_word=hex(struct.unpack('<I', read(a, 4))[0]), meaning=m)
                              for a, m in [
                                  (0x80166704, 'lui v0,0x5000: quad flags'),
                                  (0x80166A2C, 'addiu v0,zero,244: initial ring brightness'),
                                  (0x801668B0, 'addiu s1,s1,-16: age brightness decrement'),
                                  (0x80166B44, 'sltiu v0,v1,15: segment-count saturation'),
                                  (0x80166B60, 'addiu v0,v0,-16: fade decrement'),
                                  (0x80166B6C, 'sltiu v0,a0,16: fade completion threshold')]],
        primitive=dict(kind='untextured_gouraud_quad', ps1_type='POLY_G4', flags='0x50000000',
                       semitransparent=True, gpu_abr=1, gpu_blend='background_plus_foreground',
                       alpha_parameter=None, texture=None, clut=None,
                       vertex_order=['new_endpoint_0', 'new_endpoint_1', 'old_endpoint_0', 'old_endpoint_1'],
                       triangle_indices=[0, 1, 2, 1, 3, 2]),
        ring=dict(address='0x801a4740', record_bytes=196, capacity_pairs=16, maximum_segments=15,
                  initial_intensity=244, intensity_decrement_per_segment=16,
                  fade_decrement_per_tick=16, fade_stop_below=16, maximum_fade_ticks=15,
                  samples_per_record_tick=2,
                  record_rule='Advance index, store midpoint whose outer-inner direction is normalized to4096 then divided by descriptor divisor; advance again and store current pair; clamp count to15.',
                  fade_rule='Subtract16 from brightness. Stop when<16; otherwise reduce segment count by1 if count>=2 and brightness>>4<count.',
                  static_sample_suppression=False),
        colors=dict(format='RGB8', fusion_flag='0x81',
                    fusion_default=quad_colors(0, False, 244, 15),
                    fusion_flag_set=quad_colors(0, True, 244, 15),
                    lumina=quad_colors(2, False, 244, 15),
                    note='Color is per vertex and age; Fusion alternate selection is save flag0x81, not attack number or equipment.'),
        lifecycle=dict(
            states=['initialize descriptor and clear previous same-weapon effect', 'wait delay then seed ring', 'decrement duration and record or enter fade', 'fade and draw until no quads'],
            record_ticks_semantics='Duration is decremented before recording; an uninterrupted descriptor records duration-1 updates after seeding.',
            owner_active_flag='0x2 at owner+0x44',
            activation='Effect actor initialization/wait states; separate from contact opcode0x14.',
            fusion_four_continuations='Keep existing actor through rise/apex/drop/land; do not restart for each animation stream.',
            rotation_continuation='Ordinary Rotation uses descriptor8 through paused windup, dynamic held-pose spin and rotation_end; do not restart at the tail. Mighty Strike counter uses descriptor7.'),
        endpoints=dict(format='signed byte xyz pair in 16-byte pose header',
                       fusion_offset=0, lumina_offset=8,
                       source_units_per_gltf_unit=100,
                       gltf_position_conversion='(x,-y,-z)*0.01, same double conversion used by source_transform in recovered body GLB',
                       world_transform='Apply recovered model rotation and translation; actor world points remain independent of later movement.',
                       sampling='Use last frame whose tick<=clip time*30; STEP poses hold through next frame tick. Externally clocked continuation poses hold until their native state advances.',
                       midpoint='Average both endpoints with previous pair using arithmetic shift>>1. Normalize outer-minus-inner to4096, divide each axis by original descriptor divisor with truncation towardzero, then add midpoint inner.'),
        weapons=weapons, clips=clips, raw_assets=raw_assets,
        limitations=[
            'Source quad topology/colors/tables and signed pose endpoints are recovered. Host rasterization, PS1 color quantization/dithering and GTE integer precision require separate parity validation.',
            'Absolute first effect tick depends on original actor-queue update order; manifest exposes wait/init/record phases instead of claiming contact-frame alignment.',
            'The semantic in-game name of save flag0x81 is not established here; do not infer it from full equipment.',
            'This manifest covers sword ribbons, including ordinary Rotation and Mighty Strike. Collision/contact flashes and the Mighty Strike vortex have independent source paths.',
        ])
    (output / 'sword_sources.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recovery-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--actions', type=Path, required=True)
    args = parser.parse_args()
    report = recover(args.recovery_root, args.output, args.actions)
    print('Recovered %d attack clips, %d byte-verifiable source regions' % (len(report['clips']), len(report['raw_assets'])))


if __name__ == '__main__':
    main()
