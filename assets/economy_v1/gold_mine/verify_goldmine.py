import bpy, os,json,struct,math,sys
from mathutils import Vector
D=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(D,'goldmine_v1.glb'))
roots=[o for o in bpy.data.objects if o.animation_data]
clips={}
for o in roots:
 for t in o.animation_data.nla_tracks:
  clips.setdefault(t.name,[]).append(o.name)
  t.mute=True
 for t in o.animation_data.nla_tracks:
  if t.name=='work_loop':o.animation_data.action=t.strips[0].action;o.animation_data.use_nla=False
scene=bpy.context.scene;scene.frame_set(1);bpy.context.view_layer.update()
meshes=[o for o in bpy.data.objects if o.type=='MESH']
checks={'reimport_succeeded':True,'mesh_objects':len(meshes),'triangles':sum(len(o.data.polygons) for o in meshes),'materials':len(bpy.data.materials),'clips':clips,'missing_material_meshes':[o.name for o in meshes if not o.data.materials],'socket_nodes':[o.name for o in bpy.data.objects if o.name.startswith('socket_')],'nonfinite_vertices':[o.name for o in meshes if any(not all(math.isfinite(c) for c in v.co) for v in o.data.vertices)]}
checks['all_expected_clips_present']=all(x in clips for x in ['build','reverse_build','work_loop','upgrade_preview'])
checks['all_checks_pass']=checks['mesh_objects']>0 and checks['all_expected_clips_present'] and not checks['missing_material_meshes'] and not checks['nonfinite_vertices'] and len(checks['socket_nodes'])==3
with open(os.path.join(D,'verification','reimport_report.json'),'w') as f:json.dump(checks,f,indent=2)
assert checks['all_checks_pass'],checks
if '--no-render' in sys.argv:
 print('REIMPORT_PASS',json.dumps(checks));sys.exit(0)
with bpy.data.libraries.load(os.path.join(D,'goldmine_v1.blend'),link=False) as (a,b):b.collections=['PRESENTATION_ONLY']
for c in b.collections:scene.collection.children.link(c)
scene.camera=bpy.data.objects.get('Presentation_camera');scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=False
scene.world=bpy.data.worlds.new('Verify_world');scene.world.color=(.22,.22,.22)
scene.view_settings.view_transform='AgX';scene.render.resolution_x=900;scene.render.resolution_y=750;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=os.path.join(D,'verification','glb_reimport.png');bpy.ops.render.render(write_still=True)
print('REIMPORT_PASS',json.dumps(checks))
