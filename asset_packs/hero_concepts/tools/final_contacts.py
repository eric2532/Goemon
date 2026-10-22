"""Fit Gaku's headband over the final scalp rather than through its temples."""
import bpy,math
from pathlib import Path
R=Path(__file__).resolve().parents[1];bpy.ops.wm.open_mainfile(filepath=str(R/'blend'/'gaku.blend'))
C=next(c for c in bpy.data.collections if 'editable character' in c.name);o=next(o for o in C.objects if 'Broad_woven_headband' in o.name)
for i,v in enumerate(o.data.vertices):
 a=2*math.pi*(i%96)/96;c=math.cos(a);v.co.x=.55*math.sin(a)*1.07;v.co.y=(-.025+.437*math.copysign(abs(c)**.6,c))*1.07
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blend'/'gaku.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for o in C.objects:o.select_set(True)
bpy.context.view_layer.objects.active=next(o for o in C.objects if o.type=='MESH');bpy.ops.object.convert(target='MESH')
bpy.ops.export_scene.gltf(filepath=str(R/'glb'/'gaku.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
