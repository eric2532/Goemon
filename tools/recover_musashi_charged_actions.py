"""Distinguish Lumina Rotation from Mighty Strike using original USA code.

The ordinary no-scroll technique runs MAIN/42 in dynamic module slot B;
its code is absent from the location overlay. The charged guard counter runs
SC01 state0x13. Both source chains are recorded instead of guessing from poses.
"""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import struct

MODULE_BASE = 0x800CCB1C
MODULE_SHA256 = 'f9d3559e59926092f513e1b425b26ef43d192a344e050c3c7f6d09eec13c91e7'
RESIDENT_SHA256 = 'f8bcfa41b6a637ed78f327737875ea05998088443c2776e18247c0f45a64014a'
OVERLAY_SHA256 = '66a047a6242db0d212e27087b7576b19dbc12e399ae0d4f64f370e70bea35069'
MANUAL = 'https://db.hfsplay.fr/files/2020/03/27/Brave_Fencer_Musashi_USA_X7SbnlS.pdf'


def recover(root, output):
    paths = dict(norm_module='raw/MAIN.CD.dir/FILE_042.dir/0.1',
                 resident='raw/MAIN.CD.dir/FILE_010.dir/1.1',
                 overlay='raw/SC01.CD.dir/FILE_000.dir/0.4.dec')
    expected = dict(norm_module=MODULE_SHA256,resident=RESIDENT_SHA256,overlay=OVERLAY_SHA256)
    data = {key:(root/path).read_bytes() for key,path in paths.items()}
    for key,blob in data.items():
        if hashlib.sha256(blob).hexdigest() != expected[key]:
            raise ValueError('Different retail source '+key)
    module = data['norm_module']
    word = lambda address: struct.unpack_from('<I',module,address-MODULE_BASE)[0]
    # Assert the actual source chain, and read constants from its instructions.
    if word(0x800CCB28) != 0x3C05800D or word(0x800CCB34) != 0x0C05509D:
        raise ValueError('Ordinary Rotation constructor linkage changed')
    stream = ((word(0x800CCB28)&0xFFFF)<<16) + (word(0x800CCB2C)&0xFFFF)
    initial_speed = word(0x800CCB5C)&0xFFFF
    acceleration = word(0x800CCCA8)&0xFFFF
    limit = word(0x800CCC90)&0xFFFF
    speeds, cumulative = [], []
    speed = initial_speed
    angle = 0
    while angle < limit:
        speed += acceleration
        angle += speed
        speeds.append(speed); cumulative.append(angle)
    reader = runpy.run_path(str(root/'tools/recover_musashi_motion.py'))
    windup = reader['decode'](stream)
    recovery = reader['decode'](0x800D53A4)
    counter = reader['decode'](0x800D552C)
    normal = dict(name='Lumina Rotation',
        entry_chain=['0x80149d10','0x80175150','0x80175184','0x80175218','0x800ccb20'],
        entry_note='Full charge128, Norm scroll selection1; index EC0−1 into80182298. MAIN/42 is loaded into800CCB1C by resident800D0488.',
        module_init='0x800ccb20', module_update='0x800ccba0', spin_update='0x800ccbf0',
        windup=windup,recovery=recovery,
        spin=dict(held_pose='0x800f26e8', starts_after_stream_pause=True,
                  speed_start=initial_speed, acceleration_per_tick=acceleration,
                  speed_samples=speeds,cumulative_angle_samples=cumulative,
                  rotation_limit=limit, fixed_angle_one_turn=4096,
                  contact_each_spin_tick=True, contact_function='0x80155fb0',
                  contact_geometry=dict(selector=2,descriptor_address='0x80180c30',
                      function='0x80156b74',world_transform='0x80156ecc',
                      center_source=[0,-30,0],tip_source=[0,-30,-82],
                      previous_yaw_actor_field='0x24a',
                      description='Sweep between previous and current tip as owner yaw changes; previous tip is rotated by saved previous yaw minus current yaw before world transform.'),
                  contact_descriptor='(status byte80078EC0 &0x7F)−1, namespace0x10000',
                  reset_owner_yaw_on_following_tick=True,
                  resume_by_animation_flag=1,
                  animation_event_note='Opcode2 pauses at800D53A0; reset code writes B8=1 and resumes the four-frame tail at800D53A4.'),
        ribbon_actor=5,ribbon_descriptor=word(0x800CCB44)&0xFFFF,
        sound_id=hex(word(0x800CCB80)&0xFFFF),
        effect_note='Ordinary Rotation uses Lumina ribbon descriptor8. It does not create vortex actor0x19 or shock-ring actor0x1D.',
        blade_scale=dict(function='0x800ccd60',start=0x1000,
                            part_index=25,part_role='drawn Lumina',
                            actor_field='0xf6',global_address='0x80126c4e',
                            renderer_function='0x80020598',matrix_scale_function='0x80020f34',
                            scale_kind='uniform scale of part25 local matrix only; body and other parts unchanged',
                            timer_values_fixed12=[4096+(timer*1024)//7 for timer in range(1,8)],
                            holds_after_timer=7,hold_value_fixed12=5120,
                            reset_on_exit_fixed12=4096,reset_function='0x801752bc',
                            formula='4096 + trunc(sourceEffectTimer*1024/7)',
                            effect_timer_starts_at_event7=True,effect_timer_duration=7))
    mighty = dict(name='Mighty Strike',manual_source=MANUAL,manual_pdf_page=16,
        manual_description='Charge the gauge, then attack with Lumina immediately after a successful defense.',
        guard_hit_entry='0x80160334',guard_hit_init='0x80160410',guard_hit_update='0x80160534',
        guard_state='0x1b',counter_state='0x13',counter_window_source_ticks=8,
        counter_condition='Original guard-recoil update checks charge80078EBF==128 and attack pressed mask0x90 before decrementing the eight-tick timer.',
        guard_flash_actor=6,guard_flash_sound='0x43d',
        init='0x8015f080',update='0x8015f118',body=counter,
        effect_spawn_tick=next(e['tick'] for e in counter['events'] if e['word']=='0x7'),
        ribbon_actor=5,ribbon_descriptor=7,
        blade_scale=dict(part_index=25,fixed12=0x19EB,actor_field='0xf6',global_address='0x80126c4e',
            renderer_function='0x80020598',init='0x8015f080',reset='0x8015f260',reset_fixed12=4096,
            scale_kind='uniform scale of part25 local matrix only'),
        effect_actors=[dict(id=0x19,variant=0),dict(id=0x19,variant=1),dict(id=0x1D,variant=0)],
        effect_sound='0x9da',
        effects_geometry_source='special_sources.json rotation (legacy key; geometry is the Mighty Strike counter effect)',
        correction='Earlier local recovery called Table23 Rotation; original guard-recoil branch identifies it as Mighty Strike.')
    result = dict(schema_version=1,source_region='USA SLUS-007.26',
        sources={key:dict(path=paths[key],sha256=expected[key]) for key in data},
        lumina_rotation=normal,mighty_strike=mighty,
        limitations=['Logical source phases are exact. Host-frame ordering at the pause/resume boundary needs runtime verification.',
                     'The direct number-key shortcut is a host convenience; original Mighty Strike requires a successful charged block.'])
    output.mkdir(parents=True,exist_ok=True)
    (output/'charged_action_sources.json').write_text(json.dumps(result,indent=2)+'\n')
    target=output/'charged';target.mkdir(exist_ok=True)
    (target/'norm_scroll_module.bin').write_bytes(module)
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recovery-root',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();result=recover(args.recovery_root,args.output)
    print(json.dumps(dict(rotation_stream=result['lumina_rotation']['windup']['source_address'],
        mighty_strike_stream=result['mighty_strike']['body']['source_address'],
        spin_ticks=len(result['lumina_rotation']['spin']['speed_samples']))))
