"""Read the existing editable palm's nine curved fronds without changing its master."""
import hashlib,json
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[1]
master=ROOT/'assets/blender/environments/palm.blend'
bpy.ops.wm.open_mainfile(filepath=str(master))
canopy=bpy.data.objects['Canopy']
assert len(canopy.data.vertices)==324 and len(canopy.data.polygons)==306
fronds=[]
for start in range(0,324,36):
 path=[]
 for i in range(6):
  left,center,right=[canopy.data.vertices[start+i*3+j].co for j in range(3)]
  path.append([round(center.x,7),round(center.z,7),round(-center.y,7),round((right-left).length*.5,7)])
 fronds.append(path)
protected=[master,ROOT/'assets/models/environments/palm.glb']
data={'protected':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected},'fronds':fronds}
(ROOT/'assets/maps/falan/sokia/fronds.json').write_text(json.dumps(data,indent=2)+'\n')
print('SOKIA_FRONDS: reused nine complete palm curves; master unchanged')
