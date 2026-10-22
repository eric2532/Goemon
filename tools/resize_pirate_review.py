"""Resize saved Blender review copies in place, preserving every animation key."""
import bpy
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'build/Other Files/Pirate Weapons'
spec=importlib.util.spec_from_file_location('pirate_sizes',ROOT/'tools/pirate_weapon_sizes.py')
sizes=importlib.util.module_from_spec(spec);spec.loader.exec_module(sizes)
sword_size=sizes.SIZES['Weapon_Cutlass'][1]
gun_size=sizes.SIZES['Weapon_Pistol'][1]
paths=[ROOT/'assets/blender/weapons/pirate/pirate_equipped_preview.blend',
       ROOT/'docs/pirate-motion-workbench/Pirate_Animation_Workbench.blend']

def actions_digest():
    actions={}
    for action in bpy.data.actions:
        actions[action.name]=[(fc.data_path,fc.array_index,[(list(p.co),list(p.handle_left),list(p.handle_right),p.interpolation) for p in fc.keyframe_points])
                              for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
    return hashlib.sha256(json.dumps(actions,sort_keys=True).encode()).hexdigest()

result=[]
for path in paths:
    bpy.ops.wm.open_mainfile(filepath=str(path))
    bpy.context.preferences.filepaths.save_version=0
    previous_mode=bpy.context.object.mode if bpy.context.object else 'OBJECT'
    if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    before=actions_digest();active_scene=bpy.context.scene
    for scene in bpy.data.scenes:
        bpy.context.window.scene=scene
        sizes.apply_scene_sizes(scene)
        frames=sorted({scene.frame_start,scene.frame_end,*range(scene.frame_start,scene.frame_end+1,6),*(m.frame for m in scene.timeline_markers)})
        center,scale=sizes.fit_camera(scene,frames)
        scene['review_weapon_sizes']=f'Sword {sword_size:g}x; gun {gun_size:g}x; centered at unchanged hand grips.'
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type=='VIEW_3D':
                    area.spaces.active.region_3d.view_location=center
                    area.spaces.active.region_3d.view_distance=max(7.0,scale*1.5)
        if path==paths[1]:
            frame={'01_Idle':0,'02_Jump':43,'02_Jump_Explorer':22,'03_Gun_Shot':13,
                   '03_Gun_Shot_User':4,'04_Sword_Slash':16,'04_Three_Hit_Slash':29}[scene['clip']]
            scene.frame_set(frame);scene.render.filepath=str(QA/'Motion'/(scene['clip']+'.png'))
            bpy.ops.render.render(write_still=True);scene.frame_set(1)
        else:
            scene.render.filepath=str(QA/'pirate-equipped-three-quarter.png')
            bpy.ops.render.render(write_still=True)
    bpy.context.window.scene=active_scene
    if previous_mode=='POSE' or path==paths[1]:
        rig=next(ob for ob in active_scene.objects if ob.type=='ARMATURE')
        bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
        bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='POSE')
    assert before==actions_digest(),'An animation key changed while resizing geometry'
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    result.append({'file':str(path),'sword_scale':sword_size,'gun_scale':gun_size,'all_animation_keys_unchanged':True})
report_path=QA/'Motion/build-verification.json'
report=json.loads(report_path.read_text())
report['source_hashes'][str(paths[0])]=hashlib.sha256(paths[0].read_bytes()).hexdigest()
report['file_sha256']=hashlib.sha256(paths[1].read_bytes()).hexdigest()
report['weapon_scales']={'sword':sword_size,'gun':gun_size}
report_path.write_text(json.dumps(report,indent=2)+'\n')
(QA/'Motion/weapon-size-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('PIRATE_WEAPON_SIZES_UPDATED',json.dumps(result))
