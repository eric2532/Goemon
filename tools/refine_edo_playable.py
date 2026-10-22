"""Refine the playable derivative; leave the approved visual master untouched."""
import bpy, math, os, json, hashlib
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER=ROOT+'/assets/blender/enemies/musashi/Final/Musashi_Final.blend'
master_hash=hashlib.sha256(open(MASTER,'rb').read()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=ROOT+'/assets/blender/enemies/musashi/Musashi_Playable.blend')
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
obj=next(o for o in bpy.data.objects if o.type=='MESH')
# Straighten the authored staggered display stance for a balanced game-ready stance.
# Apply identical smooth offsets to bone rest positions and weighted surface vertices.
old={b.name:b.head_local.copy() for b in rig.data.bones}
offsets={}
for side,sign in [('L',-1),('R',1)]:
 for segment,x in [('Leg',.16),('Shin',.17),('Foot',.19)]:
  name=segment+'_'+side;p=old[name]
  offsets[name]=Vector((sign*x-p.x,-.055-p.y,0))
def proportional(p):
 # Compact body, broader shoulders, and a larger expressive head, like Goemon.
 z=p.z
 head_t=max(0,min(1,(z-1.50)/.16))
 width=1.23*(1-head_t)+1.10*head_t
 new_z=z*.85 if z<1.64 else 1.64*.85+(z-1.64)*1.10
 return Vector(((p.x+.024)*width,p.y*1.08,new_z))
for v in obj.data.vertices:
 delta=Vector()
 for g in v.groups:delta+=offsets.get(obj.vertex_groups[g.group].name,Vector())*g.weight
 v.co=proportional(v.co+delta)
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for b in rig.data.edit_bones:
 delta=offsets.get(b.name,Vector())
 b.head=proportional(b.head+delta);b.tail=proportional(b.tail+delta)
bpy.ops.object.mode_set(mode='OBJECT')
# Painted texture stays intact; smooth the organic surfaces with the original normals.
obj.name='Edo_Refined_Playable_Surface'
for m in obj.data.materials:
 if m.use_nodes:
  bs=m.node_tree.nodes.get('Principled BSDF')
  if bs:bs.inputs['Roughness'].default_value=.87
for o in bpy.data.objects:o.select_set(o in [obj,rig])
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/blender/enemies/musashi/Edo_Playable_Refined.blend')
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/characters/musashi/model/edo_refined.glb',export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_yup=True)
json.dump({'source':'Musashi_Playable.blend','master_unchanged':master_hash==hashlib.sha256(open(MASTER,'rb').read()).hexdigest(),'vertices':len(obj.data.vertices),'bones':len(rig.data.bones),'refinements':['balanced feet and knee alignment','compact body proportions','broader torso','larger head relative to body'],'master_sha256':master_hash},open(ROOT+'/tests/combat-expansion/edo-model.json','w'),indent=2)
