import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[2]
source=R/'assets/blender/characters/kai.blend'
with bpy.data.libraries.load(str(source),link=False) as (src,dst):
 dst.objects=[n for n in src.objects if n in ['Skin','Hair_Normal']]
rows=[];points=[]
for o in dst.objects:
 if not o:continue
 coords=[o.matrix_world@Vector(v) for v in o.bound_box];points+=coords
 rows.append({'name':o.name,'bounds_min':[min(p[i] for p in coords) for i in range(3)],'bounds_max':[max(p[i] for p in coords) for i in range(3)],'vertices':len(o.data.vertices)})
report={'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'height':max(p.z for p in points)-min(p.z for p in points),'ground':min(p.z for p in points),'meshes':rows}
(R/'docs/enemy-concepts/3d-v01/goemon-reference.json').write_text(json.dumps(report,indent=2)+'\n')
print('GOEMON_REFERENCE',json.dumps(report))
