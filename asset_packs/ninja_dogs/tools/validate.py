import bpy,json,math,hashlib,struct,runpy
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[1];d=runpy.run_path(str(P/'tools/build_dogs.py'));checks=[]
def bounds(objects):
 points=[];deps=bpy.context.evaluated_depsgraph_get()
 for o in objects:
  if o.type not in ['MESH','CURVE']:continue
  eo=o.evaluated_get(deps);me=eo.to_mesh()
  if me:
   pts=[o.matrix_world@v.co for v in me.vertices]
   if pts:points.extend([Vector(tuple(min(p[k] for p in pts) for k in range(3))),Vector(tuple(max(p[k] for p in pts) for k in range(3)))])
   eo.to_mesh_clear()
 return [[min(p[k] for p in points) for k in range(3)],[max(p[k] for p in points) for k in range(3)]]
for r in d['DOGS']:
 src=P/'sources'/f"{r['id']}_{r['name']}.blend";glb=P/'exports'/f"{r['id']}_{r['name']}.glb";bpy.ops.wm.open_mainfile(filepath=str(src));obs=[o for o in bpy.context.scene.objects if not o.name.startswith('STUDIO')];meshobs=[o for o in obs if o.type=='MESH'];curves=sum(o.type=='CURVE' for o in obs);rigs=sum(o.type=='ARMATURE' for o in obs);finite=all(math.isfinite(c) for o in meshobs for v in o.data.vertices for c in v.co);missing=[im.name for im in bpy.data.images if im.source=='FILE' and not im.packed_file];images=sum(im.source=='FILE' and bool(im.packed_file) for im in bpy.data.images);bb=bounds(obs);sig=hashlib.sha256()
 for o in sorted(meshobs,key=lambda o:o.name):
  for v in o.data.vertices:sig.update(struct.pack('fff',*v.co))
 assert finite and rigs==0 and not missing and len(bpy.data.libraries)==0 and images>=1
 raw=glb.read_bytes();magic,version,size=struct.unpack_from('<4sII',raw,0);assert magic==b'glTF' and version==2 and size==len(raw);length,kind=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+length]);assert not doc.get('animations');assert all('bufferView' in im for im in doc.get('images',[]));colors=sum('COLOR_0' in pr['attributes'] for me in doc['meshes'] for pr in me['primitives']);assert colors>0
 count=len(meshobs)+curves;bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(glb));imports=[o for o in bpy.context.scene.objects if o.type=='MESH'];ib=bounds(imports);err=max(abs(bb[i][k]-ib[i][k]) for i in range(2) for k in range(3));assert len(imports)>=len(meshobs) and err<.02,(r['id'],err)
 checks.append(dict(id=r['id'],name=r['name'],source_meshes=len(meshobs),source_curves=curves,glb_meshes=len(imports),finite_geometry=finite,armatures=rigs,packed_images=images,missing_images=missing,source_bounds_m=bb,glb_bounds_m=ib,bounds_max_error_m=err,geometry_sha256=sig.hexdigest(),source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),glb_sha256=hashlib.sha256(raw).hexdigest(),embedded_glb_images=len(doc.get('images',[])),vertex_color_primitives=colors))
 print('VALIDATED',r['id'],flush=True)
assert len({x['geometry_sha256'] for x in checks})==10
(P/'validation.json').write_text(json.dumps({'models':10,'scope':'Static source reopen, export reimport, geometry, scale and material dependency checks; these do not certify visual fidelity or animation readiness.','checks':checks},indent=2))
