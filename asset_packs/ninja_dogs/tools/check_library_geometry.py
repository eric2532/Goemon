import bpy,json
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[1];bpy.ops.wm.open_mainfile(filepath=str(P/'Ninja_Dogs_Collection.blend'));s=bpy.context.scene;expected=json.loads((P/'validation.json').read_text())['checks'];report=json.loads((P/'library_validation.json').read_text());checked=[]
for r in expected:
 col=bpy.data.collections[r['id']+' | '+r['name']]
 for lc in bpy.context.view_layer.layer_collection.children:
  if lc.name[:2].isdigit():lc.exclude=lc.name!=col.name
 bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();points=[]
 for o in col.all_objects:
  if o.type not in ['MESH','CURVE']:continue
  eo=o.evaluated_get(deps);me=eo.to_mesh();pts=[o.matrix_world@v.co for v in me.vertices]
  if pts:points.extend([Vector(tuple(min(p[k] for p in pts) for k in range(3))),Vector(tuple(max(p[k] for p in pts) for k in range(3)))])
  eo.to_mesh_clear()
 b=[[min(p[k] for p in points) for k in range(3)],[max(p[k] for p in points) for k in range(3)]];err=max(abs(b[i][k]-r['source_bounds_m'][i][k]) for i in range(2) for k in range(3));assert err<.0001,(r['id'],err);assert sum(o.type=='MESH' for o in col.all_objects)==r['source_meshes'];assert sum(o.type=='CURVE' for o in col.all_objects)==r['source_curves'];checked.append({'id':r['id'],'bounds_max_error_m':err,'mesh_and_curve_counts_match':True})
report['source_geometry_checks']=checked;(P/'library_validation.json').write_text(json.dumps(report,indent=2));print('All ten combined-library geometry checks passed')
