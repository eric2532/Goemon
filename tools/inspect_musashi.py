import bpy
from mathutils import Vector
for o in bpy.data.objects:
 if o.type=='MESH':
  vs=[o.matrix_world@v.co for v in o.data.vertices]
  print(o.name, len(vs), [tuple(round(f(v[i] for v in vs),2) for i in range(3)) for f in (min,max)])
