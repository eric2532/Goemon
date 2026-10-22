"""Recover retail Mighty Strike's untextured vortex and procedural shock ring.

Only supplied USA ROM bytes are geometry/palette inputs. Decompiled SC01 bodies
provide control semantics; addresses and code ranges are retained for auditing.
No runtime, body GLB, sword trails, textures or preferences are modified.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

RESIDENT_BASE = 0x800CEDF8
OVERLAY_BASE = 0x80128158
VORTEX_ADDRESS = 0x800DE5A8
SOURCE_HASHES = {
    'resident': 'f8bcfa41b6a637ed78f327737875ea05998088443c2776e18247c0f45a64014a',
    'overlay': '66a047a6242db0d212e27087b7576b19dbc12e399ae0d4f64f370e70bea35069',
    'executable': '66371c3a7517e9eabd7cb6cf0c5abffe7296bd4bac29c85b8bf7bb9db349714a',
}
SOURCE_PATHS = {
    'resident': 'raw/MAIN.CD.dir/FILE_010.dir/1.1',
    'overlay': 'raw/SC01.CD.dir/FILE_000.dir/0.4.dec',
    'executable': 'raw/SLUS_007.26',
}


def checked_source(data, label, expected):
    digest = hashlib.sha256(data).hexdigest()
    if digest != expected:
        raise ValueError(f'{label} SHA-256 differs: {digest}')
    return data


def decode_vortex(resident):
    start = VORTEX_ADDRESS - RESIDENT_BASE
    ident, flags, count = struct.unpack_from('<3I', resident, start)
    if (ident, flags, count) != (0x41, 0, 1):
        raise ValueError('Unexpected vortex TMD header')
    base = start + 12
    vp, nv, np, nn, pp, nt, scale = struct.unpack_from('<7I', resident, base)
    if (vp, nv, np, nn, pp, nt, scale) != (0x91C, 34, 0xA2C, 96, 0x1C, 96, 0):
        raise ValueError('Unexpected vortex object layout')
    vertices = [list(struct.unpack_from('<3h', resident, base + vp + i * 8)) for i in range(nv)]
    normals = [list(struct.unpack_from('<3h', resident, base + np + i * 8)) for i in range(nn)]
    triangles, colors, normal_indices = [], [], []
    offset = base + pp
    for _ in range(nt):
        if resident[offset:offset + 4] != bytes([6, 5, 4, 0x22]):
            raise ValueError('Expected untextured gradated semitransparent triangle packet')
        rgb = [list(resident[offset + 4 + i * 4:offset + 7 + i * 4]) for i in range(3)]
        normal, *indices = struct.unpack_from('<4H', resident, offset + 16)
        if normal >= nn or any(index >= nv for index in indices):
            raise ValueError('Vortex packet index outside original object')
        triangles.append(indices)
        normal_indices.append(normal)
        colors.append(rgb)
        offset += 24
    if offset != base + vp:
        raise ValueError('Vortex packet walk does not close at vertex block')
    end = base + np + nn * 8
    mesh = dict(address=hex(VORTEX_ADDRESS), source_axes='original PSX x,y,z; preserve raw units',
                vertices=vertices, normals=normals, triangles=triangles,
                triangle_normal_indices=normal_indices, triangle_rgb8=colors,
                packet_mode='0x22', packet_flag='0x04', textured=False,
                semitransparent=True, tmd_byte_length=end - start,
                tmd_sha256=hashlib.sha256(resident[start:end]).hexdigest())
    return mesh


def recover_shock_ring(executable):
    # 8004787C is sine, 80047948 is cosine (some decomp comments swap them).
    # Their shared quarter-wave table is at 8006D0A8; use retail fixed integers.
    ram_base = struct.unpack_from('<I', executable, 0x18)[0]
    lut = 0x800 + 0x8006D0A8 - ram_base
    sine = lambda angle: struct.unpack_from('<h', executable, lut + angle * 2)[0]
    points = [[(sine(i * 0x155) * 0x60) >> 12,
               (sine(0x400 - i * 0x155) * 0x60) >> 12] for i in range(4)]
    for i in range(4, 7):
        points.append([points[6 - i][0], -points[6 - i][1]])
    for i in range(7, 12):
        points.append([-points[12 - i][0], points[12 - i][1]])
    return dict(outer_points_source=points, radius_source=0x60,
                source_plane='local x,y; sprite rotation x=0x400 makes a horizontal ring',
                inner_fraction_fixed12=0xCCC, inner_rgb8=[240, 240, 192], outer_rgb8=[0, 0, 0],
                inner_points_local=[[x * 0xCCC / 4096, y * 0xCCC / 4096] for x, y in points],
                note='Inner interpolation is performed after projection by original renderer 800226C0; local points are a portable approximation of that projection step.',
                texture=None, blend='additive: flags0x50000000, GPU code0x3A',
                init=dict(scale_fixed12=[0x1000, 0x1000, 0x1000], rotation_x=0x400,
                          speed=0x700, acceleration=-0x60, height_offset=-0x40),
                update=dict(rgb_decrement_per_tick=16, scale_add_speed_to_xy=True,
                            speed_decrement_before_scale=0x60,
                            growth_ends_when_speed_negative=True,
                            after_growth_scale_increment=0x100,
                            expires_when_rgb_zero=True),
                sine_table_address='0x8006d0a8', geometry_function='0x800233cc',
                render_function='0x800226c0')


def recover(root, output):
    sources = {key: checked_source((root / path).read_bytes(), key, SOURCE_HASHES[key])
               for key, path in SOURCE_PATHS.items()}
    resident, overlay = sources['resident'], sources['overlay']
    read = lambda address: struct.unpack_from('<I', resident, address - RESIDENT_BASE)[0]
    if read(0x800DF2E0) != VORTEX_ADDRESS or read(0x800D6204) != 0x80164744 or read(0x800D6214) != 0x80164BA0:
        raise ValueError('Retail model/actor dispatch linkage differs')
    mesh = decode_vortex(resident)
    ring = recover_shock_ring(sources['executable'])
    variant0 = dict(id=0x19, variant=0, handler='0x80164744', states=['0x801647a4','0x80164864','0x80164930'],
        init_scale_fixed12=[4096,0,4096], init_speed=0, acceleration=512,
        growth=dict(xz_increment=256, y_add_accelerating_speed=True, yaw_increment=113,
                    transitions_after_y_exceeds=0x4000),
        fade=dict(xz_increment=256, yaw_increment=113, lighting_bias_start=128,
                  lighting_bias_decrement=8, expires_when_bias_below=-128,
                  destroys_other_variant_on_expiry=True))
    variant1 = dict(id=0x19, variant=1, handler='0x80164744', states=variant0['states'],
        init_scale_fixed12=[4096,0,4096], init_speed=0, acceleration=512,
        growth=dict(xz_increment=512, y_add_accelerating_speed=True, yaw_increment=-113,
                    transitions_after_y_exceeds=0x2000),
        fade=dict(xz_increment=64, y_decrement_clamped_zero=512, yaw_increment=-113,
                  expires_with_variant0=True))
    rotation = dict(name='Mighty Strike', legacy_key_note='The rotation field is retained for existing runtime compatibility. Table23 is the charged guard counter, not ordinary Lumina Rotation.', command_address='0x800d552c', spawn_function='0x8015f118', spawn_tick=11,
        spawn_event=7, spawn_flag='0x4000', sound_id='0x9da',
        actors=[variant0, variant1, dict(id=0x1D, variant=0, handler='0x80164ba0',
                states=['0x80164bdc','0x80164cd4','0x80164d4c','0x80164db0'])],
        vortex_mesh=mesh, shock_ring=ring, vfx_tick_rate=30,
        spawn_anchor_source=list(struct.unpack_from('<3b', resident, 0x800F0FE8 - RESIDENT_BASE + 8)),
        spawn_anchor_evidence=dict(pose='0x800f0fe8', tick=11, header_byte_offset=8,
            header_address='0x800f0ff0', functions=['0x80148534','0x801485b8','0x80149374'],
            semantics='First signed-byte Lumina endpoint transformed once by owner model matrix, snapshotted in world space; shock adds sourceY -64 after transform.'),
        state_note='Each actor executes one state per update; initialization advances state but does not also execute its first growth update.',
        vortex_blend_note='TMD packet bit1 requests semitransparency. Model flags0x50000000 and per-instance light matrix bias require renderer-specific reproduction; preserve recovered palette rather than replace it with a blue trail.')
    report = dict(schema_version=1, source_region='USA SLUS-007.26',
        sources={key:dict(path=SOURCE_PATHS[key],sha256=SOURCE_HASHES[key]) for key in sources},
        rotation=rotation,
        contact=dict(rotation_damage_type='0x0b', overlap_function='0x80164acc',
                     damage_route=['0x8014c3a4','0x8014c43c','0x8014c4ac'],
                     entry_function='0x80156044', emit_function='0x80156848',
                     branch='Original contact flags &6 emits actor6. Successful-hit branch flags&1 selects its actor from action descriptor byte8.',
                     metal_flash=dict(actor=6, handler='0x80168744', draw_function='0x80168828',
                         primitive_function='0x800173dc',
                         triangles=[[[0,0,2],[-3,0,36],[3,0,40]]],
                         triangle_rgb8=[[64,64,16],[255,192,64],[255,192,64]],
                         rotation_pairs_source=[list(struct.unpack_from('<2h',overlay,0x80181BEC-OVERLAY_BASE+i*4)) for i in range(4)],
                         rotation_table='0x80181bec', rotation_axis_order='XZ; Y=0; original func80049CAC then concatenated owner rotation',
                         render_scales_fixed12=[4096,6144,8192], blend_flags='0x50000000', texture=None,
                         child_sparks=dict(actor=8, count=2, emitted_only_on_init=True)),
                     spark_lines=dict(actor=8, handler='0x80168d58', draw_function='0x80168f40',
                         draw_updates=5, rgb8_start=[8,0,0], rgb8_end=[192,128,128],
                         blend_flags='0x50000000', texture=None,
                         initial_velocity_magnitude_source=36,
                         path='Random rotated direction from original rand; line joins previous and current source positions before position integration.'),
                     note='Recovered common metal/block contact flash plus child line sparks. Successful-hit actor selection varies per original action descriptor; no universal hit-flash parity claim.'),
        limitations=['No original PSX screenshot parity claim. Camera projection, GTE lighting and transparency need runtime validation.',
                     'These Rotation assets have no texture/CLUT; normal sword effect actors are recovered separately.'])
    target = output / 'special'
    target.mkdir(parents=True, exist_ok=True)
    for name, value in [('rotation_vortex_mesh.json',mesh),('rotation_shock_ring.json',ring),('contact_geometry.json',report['contact'])]:
        (target/name).write_text(json.dumps(value,indent=2)+'\n')
    start = VORTEX_ADDRESS - RESIDENT_BASE
    (target/'rotation_vortex.tmd').write_bytes(resident[start:start+mesh['tmd_byte_length']])
    (output/'special_sources.json').write_text(json.dumps(report,indent=2)+'\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recovery-root',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    arguments = parser.parse_args()
    result = recover(arguments.recovery_root,arguments.output)
    print(json.dumps(dict(vertices=len(result['rotation']['vortex_mesh']['vertices']),
                          triangles=len(result['rotation']['vortex_mesh']['triangles']),
                          shock_ring_points=len(result['rotation']['shock_ring']['outer_points_source']))))
