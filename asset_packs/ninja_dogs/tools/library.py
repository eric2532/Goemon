import bpy,json,runpy
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[1];d=runpy.run_path(str(P/'tools/build_dogs.py'));rows=d['DOGS'];bpy.ops.wm.read_factory_settings(use_empty=True);s=d['studio'](rows[0]);scale=rows[0]['scale']
for o in s.objects:
 if o.type=='LIGHT':o.location*=scale;o.data.energy*=scale*scale
s.camera.location=Vector((4.1,-7,3))*scale;s.camera.rotation_euler=(Vector((0,0,1))*scale-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=3.2*scale
for r in rows:
 col=bpy.data.collections.new(r['id']+' | '+r['name']);s.collection.children.link(col)
 with bpy.data.libraries.load(str(P/'sources'/f"{r['id']}_{r['name']}.blend"),link=False) as (a,b):b.objects=[n for n in a.objects if not n.startswith('STUDIO')]
 for o in b.objects:
  if o:col.objects.link(o)
 col.asset_mark();col.asset_data.description=r['name']+' — '+r['role']+'. Static reference-led dog with editable fur and gear.';col['design_id']=r['id']
 with bpy.context.temp_override(id=col):bpy.ops.ed.lib_id_load_custom_preview(filepath=str(P/'renders'/f"{r['id']}_threequarter.png"))
 bpy.context.view_layer.layer_collection.children[col.name].exclude=r['id']!='01';print('LIBRARY',r['id'],flush=True)
t=bpy.data.texts.new('START HERE');t.write('Ten static dog collection assets. Only Kogane is visible initially. Enable one numbered collection at a time in the Outliner, or choose Current File in the Asset Browser. All textures are packed. No armatures or animations. Individual .blend sources are in sources/.\n')
bpy.ops.outliner.orphans_purge(do_recursive=True);bpy.ops.wm.save_as_mainfile(filepath=str(P/'Ninja_Dogs_Collection.blend'),compress=True);bpy.ops.wm.open_mainfile(filepath=str(P/'Ninja_Dogs_Collection.blend'));assets=[c for c in bpy.data.collections if c.asset_data];assert len(assets)==10 and not bpy.data.libraries
report={'collections':10,'thumbnails':sum(c.preview.image_size[0]>0 for c in assets),'external_libraries':0,'packed_file_images':sum(i.source=='FILE' and bool(i.packed_file) for i in bpy.data.images),'bytes':(P/'Ninja_Dogs_Collection.blend').stat().st_size};assert report['thumbnails']==10 and report['bytes']<100_000_000
(P/'library_validation.json').write_text(json.dumps(report,indent=2));print(report)
