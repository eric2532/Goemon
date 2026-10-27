"""Export the saved Skullpion master, retaining source and prepared actions."""
from pathlib import Path
import bpy,json,math,sys,copy
ROOT=Path(__file__).resolve().parents[1]
source=Path(bpy.data.filepath).resolve()
assert source==ROOT/'assets/blender/enemies/skullpion/Skullpion.blend','Open the editable Skullpion master first'
scene=bpy.context.scene
parts=sorted((o for o in scene.objects if o.type=='MESH'),key=lambda o:o.name)
assert [o.name for o in parts]==['Part_%02d'%i for i in range(22)]
assert sum(len(p.vertices)-2 for o in parts for p in o.data.polygons)==1037
assert scene.unit_settings.scale_length==1
prepared=list(scene['skullpion_prepared_actions']);fit={}
for name in prepared:
 action=bpy.data.actions[name];rows=[]
 for ob in parts:
  ob.animation_data.action=action
  ob.animation_data.action_slot=next(s for s in action.slots if s.identifier=='OB'+ob.name)
 for step in range(math.ceil(action.frame_range[1]*2)+1):
  frame=min(step*.5,action.frame_range[1]);scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
  vertices={o.name:[o.matrix_world@v.co for v in o.data.vertices] for o in parts};points=[v for vv in vertices.values() for v in vv]
  feet=min(v.z for n in ['Part_10','Part_11'] for v in vertices[n])
  assert abs(feet)<.025,(name,frame,'Feet drift from the model floor',feet)
  front=min(v.y for n in ['Part_01','Part_02','Part_10','Part_11'] for v in vertices[n])
  if name=='Castle_Cling':assert abs(front+1)<.025,(name,frame,'Wall contact drift',front)
  rows.append({'minimum':[min(v[k] for v in points) for k in range(3)],'maximum':[max(v[k] for v in points) for k in range(3)]})
 fit[name]={'minimum':[min(r['minimum'][k] for r in rows) for k in range(3)],'maximum':[max(r['maximum'][k] for r in rows) for k in range(3)]}
output=ROOT/'assets/models/enemies/skullpion.glb';output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
for ob in parts+[bpy.data.objects['Skullpion']]:ob.hide_set(False);ob.select_set(True)
# Export at the contact bake rate; Blender otherwise samples mixed curves at 24 Hz.
for name in prepared:
 for layer in bpy.data.actions[name].layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for curve in bag.fcurves:
     for key in curve.keyframe_points:
      key.co.x*=5;key.handle_left.x*=5;key.handle_right.x*=5
scene.render.fps*=5
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_optimize_animation_size=False,export_vertex_color='NAME',export_vertex_color_name='Color',export_apply=False,export_yup=True,export_extras=True)
# Preserve the immutable ROM streams without Blender's fractional-frame rounding.
sys.path.insert(0,str(ROOT/'tools'))
from asset_pipeline.glb import GLB
exported=GLB.read(output);original=GLB.read(ROOT/'assets/characters/recovered_skullpion/skullpion.glb')
nodes={n['name']:i for i,n in enumerate(exported.doc['nodes'])}
exported.doc['animations']=[a for a in exported.doc['animations'] if a['name'] in prepared]
for animation in original.doc['animations']:
 animation=copy.deepcopy(animation)
 for channel in animation['channels']:channel['target']['node']=nodes[original.doc['nodes'][channel['target']['node']]['name']]
 for sampler in animation['samplers']:
  for key in ['input','output']:
   index=sampler[key];sampler[key]=exported.append_accessor(original.accessor(index),original.doc['accessors'][index])
   for bound in ['min','max']:
    if bound in original.doc['accessors'][index]:exported.doc['accessors'][sampler[key]][bound]=original.doc['accessors'][index][bound]
 exported.doc['animations'].append(animation)
exported.compact();exported.write(output)
metadata={'source':str(source.relative_to(ROOT)),'runtime_scale':float(scene['skullpion_runtime_multiplier']),'wall_plane':float(scene['skullpion_wall_plane']),'clips':fit}
output.with_name('skullpion_fit.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('SKULLPION_EXPORTED',output,metadata)
