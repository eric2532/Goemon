import bpy,runpy,json,sys
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[1];d=runpy.run_path(str(P/'tools/build_dogs.py'));args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for r in d['DOGS']:
 if args and r['id'] not in args:continue
 src=P/'sources'/f"{r['id']}_{r['name']}.blend";bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene
 m=bpy.data.materials.get('cloth') or d['mat']('cloth',r['scarf'],0,.89)
 if r['id']=='02':
  for ob in s.objects:
   if ob.name.startswith('TACK | fitted saddle cloth'):ob.data.materials.clear();ob.data.materials.append(m)
 m.diffuse_color=(*r['scarf'],1)
 im=bpy.data.images.load(str(P/'textures'/f"{r['id']}_woven_wave.png"),check_existing=True);im.pack();ns=m.node_tree.nodes;tex=ns.get('Woven wave pattern') or ns.new('ShaderNodeTexImage');tex.name='Woven wave pattern';tex.image=im;m.node_tree.links.new(tex.outputs['Color'],ns.get('Principled BSDF').inputs['Base Color'])
 for o in s.objects:
  if o.type!='MESH' or not any(slot.material==m for slot in o.material_slots):continue
  me=o.data;uv=me.uv_layers.get('Textile UV') or me.uv_layers.new(name='Textile UV');coords=[v.co for v in me.vertices];lo=[min(v[k] for v in coords) for k in range(3)];hi=[max(v[k] for v in coords) for k in range(3)];axes=sorted(range(3),key=lambda k:hi[k]-lo[k],reverse=True)[:2]
  for poly in me.polygons:
   for loop in poly.loop_indices:
    co=coords[me.loops[loop].vertex_index];uv.data[loop].uv=((co[axes[0]]-lo[axes[0]])*4,(co[axes[1]]-lo[axes[1]])*4)
  # Parametric ribbon indexing makes the weave continuous across flowing scarf folds.
  if 'scarf' in o.name.lower() and len(me.vertices)%5==0:
   for loop in me.loops:
    j,k=divmod(loop.vertex_index,5);uv.data[loop.index].uv=(j/8,k/4*.7)
 if not s.get('real_scale'):
  char=bpy.data.collections.new(r['id']+' | '+r['name']);s.collection.children.link(char);root=bpy.data.objects.new('CHARACTER | '+r['name'],None);char.objects.link(root)
  for o in list(s.objects):
   if o==root or o.name.startswith('STUDIO'):continue
   for col in list(o.users_collection):col.objects.unlink(o)
   char.objects.link(o);o.parent=root
  root.scale=(r['scale'],)*3;s['real_scale']=r['scale']
  for o in s.objects:
   if o.type=='LIGHT':o.location*=r['scale'];o.data.energy*=r['scale']**2
 s['scope']='Static reference-led dog sculpture. Named anatomy, separate fur, editable gear. No armature/animation.'
 s['scale_note']='Meters. Breed-specific size via CHARACTER root; apply root scale before rigging if needed.'
 d['save_export'](r)
 s['scale_note']='Meters. Breed-specific size via CHARACTER root; apply root scale before rigging if needed.'
 # save_export positions its camera in design space, so set the physical-scale camera explicitly.
 s.camera.location=Vector((4.1,-7,3))*r['scale'];s.camera.rotation_euler=(Vector((0,0,1))*r['scale']-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=(4.4 if r['id']=='10' else 3.2)*r['scale']
 bpy.ops.wm.save_as_mainfile(filepath=str(src),compress=True);print('FINISHED',r['id'],flush=True)
