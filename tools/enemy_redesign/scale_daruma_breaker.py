"""Create the requested massive Daruma variant without changing v01 or gameplay."""
import sys,json,hashlib
from pathlib import Path
import bpy
from mathutils import Vector
R=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
import common as c
OLD=R/'assets/blender/enemies/forest_redesign_v01/daruma_breaker.blend'
DOC=R/'docs/enemy-concepts/3d-v02';EDIT=R/'assets/blender/enemies/forest_redesign_v02';OUT=R/'assets/models/enemies/forest_redesign_v02'
for d in [DOC,EDIT,OUT]:d.mkdir(parents=True,exist_ok=True)
FACTOR=4.0
before=hashlib.sha256(OLD.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(OLD))
meshes=c.asset_meshes();lo,hi=c.bounds(meshes);old_dimensions=[hi[i]-lo[i] for i in range(3)]
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:
 o.select_set(True)
 o.location*=FACTOR;o.scale*=FACTOR
 bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.select_set(False)
for o in bpy.context.scene.objects:
 if o.type=='LIGHT':o.location*=FACTOR;o.data.energy*=FACTOR**2;o.data.size*=FACTOR
bpy.context.view_layer.update();lo,hi=c.bounds(meshes);dimensions=[hi[i]-lo[i] for i in range(3)]
for i in range(3):assert abs(dimensions[i]/old_dimensions[i]-FACTOR)<1e-5
height=dimensions[2];focus=Vector((0,0,height*.51));camera=bpy.context.scene.camera
camera.data.clip_end=1000;camera.data.ortho_scale=max(height*1.2,dimensions[0]*1.28)
camera.location=focus+Vector((7,10,1.7))*FACTOR;c.aim(camera,focus)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D' and area.spaces.active.region_3d:
   area.spaces.active.region_3d.view_location=focus;area.spaces.active.region_3d.view_distance=height*1.7;area.spaces.active.clip_end=1000
bpy.context.scene['scale_revision']='4x the previous Daruma in every linear dimension; asset-only, implementation on hold'
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
source=EDIT/'daruma_breaker.blend';output=OUT/'daruma_breaker.glb'
bpy.ops.export_scene.gltf(filepath=str(output),use_selection=True,export_format='GLB',export_yup=True,export_animations=False,export_skins=False,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(source))
for view,offset in {'front':(0,10,0),'side':(-10,0,0),'back':(0,-10,0),'three-quarter':(7,10,1.7)}.items():
 camera.location=focus+Vector(offset)*FACTOR;c.aim(camera,focus);bpy.context.scene.render.filepath=str(DOC/f'daruma_breaker-{view}.png');bpy.ops.render.render(write_still=True)
camera.data.ortho_scale=4.05*FACTOR;camera.location=(0,10*FACTOR,4.10*FACTOR);c.aim(camera,(0,0,4.10*FACTOR))
bpy.context.scene.render.filepath=str(DOC/'daruma_breaker-face-detail.png');bpy.ops.render.render(write_still=True)
report=json.loads((R/'docs/enemy-concepts/3d-v01/daruma_breaker-report.json').read_text())
report.update(source=str(source.relative_to(R)),export=str(output.relative_to(R)),bounds_min=lo,bounds_max=hi,height=height,width=dimensions[0],depth=dimensions[1],height_vs_goemon=height/c.HEIGHT,linear_scale_vs_v01=FACTOR,previous_source=str(OLD.relative_to(R)),previous_dimensions=old_dimensions,implementation_status='Asset revision only. Wait for explicit user instruction to start gameplay implementation.')
report['notes']=[n for n in report['notes'] if 'Height 1.75' not in n]+['Uniform 4x scale in width, depth and height compared with v01. Approximately 7x Goemon height. Face UVs and textures preserved.']
(DOC/'daruma_breaker-report.json').write_text(json.dumps(report,indent=2)+'\n')
assert hashlib.sha256(OLD.read_bytes()).hexdigest()==before
print('MASSIVE_DARUMA_RESULT',json.dumps(report))
