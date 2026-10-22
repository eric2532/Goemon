"""Replace only Hair_Gold with supplied Sudden Impact hair. Preserve the current rig/actions.
Blender --background assets/blender/characters/kai.blend --python tools/import_surge_hair.py
"""
import bpy, bmesh, shutil
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/references/goemon_sudden_impact/SI_Goe'
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
bones=[(b.name,b.matrix_local.copy()) for b in rig.data.bones]
actions=list(bpy.data.actions)
old=bpy.data.objects.get('Hair_Gold')
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.obj_import(filepath=str(SOURCE/'SI_goe.obj'),forward_axis='NEGATIVE_Z',up_axis='Y')
gold=bpy.context.object
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
# Shared body coordinates match the normal model exactly. Use its existing scale,
# not the taller transformed hair height, so the scalp lines up without redesign.
scale=3.3/194.7548
for v in gold.data.vertices:
 p=v.co.copy();v.co=Vector((-p.x,-p.y,p.z+.2312))*scale
adj={v.index:set() for v in gold.data.vertices}
for face in gold.data.polygons:
 for i in face.vertices:adj[i].update(face.vertices)
seen=set();hair_ids=set()
for i in adj:
 if i in seen:continue
 queue=[i];seen.add(i);island=[]
 while queue:
  j=queue.pop();island.append(j)
  for k in adj[j]-seen:seen.add(k);queue.append(k)
 if min(gold.data.vertices[j].co.z/scale-.2312 for j in island)>120:hair_ids.update(island)
assert len(hair_ids)==110, 'Unexpected source islands; inspect before replacing'
bm=bmesh.new();bm.from_mesh(gold.data);bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in hair_ids],context='VERTS')
bm.to_mesh(gold.data);bm.free();gold.data.update()
assert len(gold.data.polygons)==190
texture=ROOT/'assets/textures/characters/goemon_sudden_impact.png'
shutil.copy2(SOURCE/'si_goe128.png',texture)
mat=gold.data.materials[0];mat.name='Goemon_Sudden_Impact_Hair_Atlas'
bsdf=mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value=1
bsdf.inputs['Specular IOR Level'].default_value=0
for node in mat.node_tree.nodes:
 if node.type=='TEX_IMAGE':
  node.image.filepath=str(texture);node.interpolation='Closest';node.image.pack()
gold.vertex_groups.clear();group=gold.vertex_groups.new(name='Head');group.add(list(range(len(gold.data.vertices))),1,'REPLACE')
gold['source_weight_regions']=['Head']*len(gold.data.vertices)
gold['source_asset']='SI_Goe/SI_goe.obj: three connected hair islands; original UVs and uniform scale'
gold.parent=rig
modifier=gold.modifiers.new('Reference_Rig','ARMATURE');modifier.object=rig
if old:bpy.data.objects.remove(old,do_unlink=True)
gold.name='Hair_Gold';gold.data.name='Sudden_Impact_Hair'
gold.hide_set(True);gold.hide_render=True
assert list(bpy.data.actions)==actions
assert all(b.name==name and b.matrix_local==matrix for b,(name,matrix) in zip(rig.data.bones,bones))
bpy.context.scene['geometry_policy']='Normal model unchanged. Hair_Gold uses the supplied Sudden Impact hair islands, original UVs/atlas, same uniform scale.'
bpy.context.scene['surge_hair_source']='User supplied Goemon (Sudden Impact) (1).zip / SI_Goe'
bpy.ops.object.select_all(action='DESELECT');bpy.data.objects['Skin'].select_set(True);bpy.context.view_layer.objects.active=bpy.data.objects['Skin']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/blender/characters/kai.blend'))
print('SUPPLIED_GOLD_HAIR_IMPORTED: 110 vertices, 190 triangles; existing skeleton and 24 animations preserved')
