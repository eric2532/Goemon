"""Refine the existing animation work copy; never regenerate the character."""
from pathlib import Path
import bpy, math
from mathutils import Quaternion, Vector
OUT=Path(__file__).resolve().parent
ARTIFACTS=OUT.parents[1]/'build/Other Files/Samurai weapon workbench'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Samurai_Weapon_Workbench.blend'))
bpy.context.preferences.filepaths.save_version=0
for name in ['01 — Idle','02 — Run','03 — Five-hit combo']:
    sc=bpy.data.scenes[name];bpy.context.window.scene=sc;sc.frame_set(1)
    if name!='01 — Idle':
        for ob in list(sc.objects):
            if 'Sheath' in ob.name:bpy.data.objects.remove(ob,do_unlink=True)
    rig=next(o for o in sc.objects if o.type=='ARMATURE')
    for side in ['R','L']:
        rig.pose.bones['Forearm_'+side].rotation_quaternion=Quaternion((1,0,0),.05)
        c=next(c for c in rig.pose.bones['Forearm_'+side].constraints if c.type=='IK')
        best=None
        for angle in [0,math.pi/2,-math.pi/2,math.pi]:
            c.pole_angle=angle;bpy.context.view_layer.update()
            start=rig.pose.bones['Arm_'+side].head;target=rig.pose.bones['Hand_IK_'+side].head
            axis=(target-start).normalized();joint=rig.pose.bones['Forearm_'+side].head;pole=rig.pose.bones['Elbow_Pole_'+side].head
            elbow=joint-start-axis*(joint-start).dot(axis);toward=pole-start-axis*(pole-start).dot(axis)
            score=elbow.normalized().dot(toward.normalized())
            if best is None or score>best[0]:best=(score,angle)
        c.pole_angle=best[1]
    visible={'Katana_Control','Foot_IK_R','Foot_IK_L','Pelvis','Chest','Head'}
    for b in rig.data.bones:b.hide=b.name not in visible
    rig.show_in_front=True;rig.data.display_type='STICK'
scene=bpy.data.scenes['01 — Idle'];bpy.context.window.scene=scene;scene.frame_set(1)
rig=bpy.data.objects['Reference_Rig']
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for ob in bpy.context.selected_objects:ob.select_set(False)
rig.hide_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig
for pb in rig.pose.bones:pb.select=False
rig.pose.bones['Katana_Control'].select=True;rig.data.bones.active=rig.data.bones['Katana_Control']
bpy.ops.object.mode_set(mode='POSE')
if 'Animation' in bpy.data.workspaces:bpy.context.window.workspace=bpy.data.workspaces['Animation']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Samurai_Weapon_Workbench.blend'))
print('ANIMATION_RIG_POLISHED',flush=True)
