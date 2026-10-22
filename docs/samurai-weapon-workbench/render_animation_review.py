"""Set a clear editable starting view and render the animation's main poses."""
from pathlib import Path
import bpy, sys
from mathutils import Vector
OUT=Path(__file__).resolve().parent
ARTIFACTS=OUT.parents[1]/'build/Other Files/Samurai weapon workbench'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Samurai_Weapon_Workbench.blend'))
bpy.context.preferences.filepaths.save_version=0
for name in ['01 — Idle','02 — Run','03 — Five-hit combo']:
    sc=bpy.data.scenes[name];bpy.context.window.scene=sc;sc.frame_set(1)
    if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    for ob in sc.objects:ob.select_set(False)
    rig=next(o for o in sc.objects if o.type=='ARMATURE')
    rig.hide_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig
    for pb in rig.pose.bones:pb.select=False
    rig.pose.bones['Katana_Control'].select=True;rig.data.bones.active=rig.data.bones['Katana_Control']
    bpy.ops.object.mode_set(mode='POSE')
bpy.context.window.scene=bpy.data.scenes['01 — Idle']
bpy.context.window.workspace=bpy.data.workspaces['Animation']
for workspace in bpy.data.workspaces:
    for screen in workspace.screens:
        views=sorted([a for a in screen.areas if a.type=='VIEW_3D'],key=lambda a:a.x)
        for i,area in enumerate(views):
            s=area.spaces.active;s.show_region_ui=False
            s.region_3d.view_perspective='ORTHO';s.region_3d.view_location=Vector((0,-.25,1.6));s.region_3d.view_distance=5.8
            s.region_3d.view_rotation=Vector((0,1,-.08) if i==0 else (-.6,1,-.2)).to_track_quat('-Z','Y')
for area in bpy.context.screen.areas:
    if area.type=='DOPESHEET_EDITOR':
        area.spaces.active.mode='ACTION';area.spaces.active.show_pose_markers=True
        region=next((r for r in area.regions if r.type=='WINDOW'),None)
        if region:
            with bpy.context.temp_override(area=area,region=region):bpy.ops.action.view_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Samurai_Weapon_Workbench.blend'))
if '--skip-renders' in sys.argv:sys.exit(0)
for name,frames,prefix in [
    ('01 — Idle',[1],'idle'),
    ('02 — Run',[1,7,13,19],'run'),
    ('03 — Five-hit combo',[6,12,16,30,34,48,52,66,78,87,92],'combo')]:
    sc=bpy.data.scenes[name];bpy.context.window.scene=sc
    sc.render.resolution_x=760;sc.render.resolution_y=840;sc.render.resolution_percentage=100;sc.cycles.samples=12
    for f in frames:
        sc.frame_set(f);sc.render.filepath=str(ARTIFACTS/(prefix+'-%03d.png'%f));bpy.ops.render.render(write_still=True,scene=sc.name)
print('ANIMATION_REVIEW_RENDERED',flush=True)
