from pathlib import Path
import bpy,json
from mathutils import Vector
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(root/'assets/blender/characters/goemon_cosplay/samurai.blend'))
rows=[]
for o in bpy.data.objects:
 row={'name':o.name,'type':o.type,'parent':o.parent.name if o.parent else None,'parent_type':o.parent_type,'parent_bone':o.parent_bone,'location':list(o.location),'rotation':list(o.rotation_euler),'scale':list(o.scale),'world':list(o.matrix_world.translation)}
 if o.type=='MESH':
  row.update({'vertices':len(o.data.vertices),'polygons':len(o.data.polygons),'materials':[m.name for m in o.data.materials if m],'modifiers':[{'type':m.type,'object':getattr(getattr(m,'object',None),'name',None)} for m in o.modifiers], 'bounds':[list(Vector(c)) for c in o.bound_box]})
 if o.type=='ARMATURE':row['bones']=[{'name':b.name,'parent':b.parent.name if b.parent else None,'head':list(b.head_local),'tail':list(b.tail_local)} for b in o.data.bones]
 rows.append(row)
(out/'source-inspection.json').write_text(json.dumps({'objects':rows,'actions':[a.name for a in bpy.data.actions],'active':bpy.context.view_layer.objects.active.name if bpy.context.view_layer.objects.active else None},indent=2))
print('SOURCE_INSPECTION',[(o.name,o.type) for o in bpy.data.objects]);print('INSPECTION_OK')
