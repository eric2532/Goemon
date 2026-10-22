"""Sharpen the existing katana point without changing its length or animation."""
from pathlib import Path
from datetime import datetime
import bpy, bmesh, math, json, shutil, hashlib
from mathutils import Vector

OUT=Path(__file__).resolve().parent
TARGET=OUT/'Samurai_Weapon_Workbench.blend'
ARTIFACTS=OUT.parents[1]/'build/Other Files/Samurai weapon workbench'
source_hash=hashlib.sha256(TARGET.read_bytes()).hexdigest()
backup=ARTIFACTS/('Before sharper tip '+datetime.now().strftime('%Y%m%d-%H%M%S')+'.blend')
shutil.copy2(TARGET,backup)
bpy.ops.wm.open_mainfile(filepath=str(TARGET))
bpy.context.preferences.filepaths.save_version=0
blade=bpy.data.objects['Katana_Blade — enlarged maroon steel']
assert not blade.data.get('long_sharp_kissaki'), 'Tip is already sharpened; preserve current edits'
def animation_digest():
    values=[]
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        values.append((action.name,fc.data_path,fc.array_index,[(list(k.co),list(k.handle_left),list(k.handle_right)) for k in fc.keyframe_points]))
    return hashlib.sha256(json.dumps(values).encode()).hexdigest()
animation_before=animation_digest()
before=[v.co.copy() for v in blade.data.vertices]
tip=max(before,key=lambda p:p.z)
start=tip.z-.24
def point_angle(points):
    ring_z=max(p.z for p in points if p.z<tip.z-1e-5)
    ring=[p for p in points if abs(p.z-ring_z)<1e-5]
    edge=min(ring,key=lambda p:p.x);spine=max(ring,key=lambda p:p.x)
    a=Vector((edge.x-tip.x,edge.z-tip.z));b=Vector((spine.x-tip.x,spine.z-tip.z))
    return math.degrees(a.angle(b))
old_angle=point_angle(before)
for v in blade.data.vertices:
    if start<v.co.z<tip.z-1e-5:
        remaining=(tip.z-v.co.z)/(tip.z-start)
        v.co.x=tip.x+(v.co.x-tip.x)*remaining
        v.co.y*=remaining
blade.data.update()
bm=bmesh.new();bm.from_mesh(blade.data)
bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(blade.data);bm.free()
blade.data['long_sharp_kissaki']=True
blade['edit_note']='Long sharp tapered point. Current 20% larger size and animation controls are preserved.'
after=[v.co.copy() for v in blade.data.vertices]
assert max(v.z for v in after)==tip.z
assert all(a==b for a,b in zip(before,after) if a.z<=start or a.z==tip.z)
assert animation_digest()==animation_before
assert point_angle(after)<old_angle*.5
assert hashlib.sha256(TARGET.read_bytes()).hexdigest()==source_hash,'Workbench changed on disk; preserve the newer file'
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
report={'blade_length_unchanged':True,'current_weapon_scales_unchanged':True,'animation_curves_unchanged':True,'only_final_blade_section_changed':True,'old_tip_profile_angle_degrees':old_angle,'new_tip_profile_angle_degrees':point_angle(after)}
(ARTIFACTS/'sharper-tip-verification.json').write_text(json.dumps(report,indent=2))
print('KATANA_TIP_SHARPENED',json.dumps(report),flush=True)

# Review renders do not alter the saved camera or pose setup.
sc=bpy.data.scenes['01 — Idle'];bpy.context.window.scene=sc;sc.frame_set(1)
sc.cycles.samples=12;sc.render.resolution_x=900;sc.render.resolution_y=1000
sc.render.filepath=str(OUT/'samurai-preview.png');bpy.ops.render.render(write_still=True,scene=sc.name)
sc=bpy.data.scenes['04 — Katana detail'];bpy.context.window.scene=sc
sc.cycles.samples=12;sc.render.resolution_x=900;sc.render.resolution_y=1000
sc.camera.location=(-.05,-5,2.8)
sc.camera.rotation_euler=(Vector((-.37,0,2.58))-sc.camera.location).to_track_quat('-Z','Y').to_euler()
sc.camera.data.ortho_scale=.70
sc.render.filepath=str(ARTIFACTS/'sharper-tip-closeup.png');bpy.ops.render.render(write_still=True,scene=sc.name)
print('SHARPER_TIP_REVIEW_RENDERED',flush=True)
