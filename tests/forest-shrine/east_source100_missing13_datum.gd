extends SceneTree
## CPU source/mesh/field measurement only. No scene, render or published art change.
const Model=preload("res://scripts/forest/forest_model.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Trees=preload("res://scripts/forest/forest_east_native_trees.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const DEST="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Remote Views/"
func _initialize():run.call_deferred()
func number(v:float)->Variant:return "uncovered"if is_nan(v)else v
func run():
 var paths=["res://scripts/forest/forest_freyja_regions.gd","res://scripts/forest/forest_freyja_terrain.gd","res://scripts/forest/forest_east_road.gd","res://scripts/forest/forest_east_native_trees.gd","res://scripts/forest/forest_east_tree_families.gd","res://assets/maps/falan/east_region/native_trees/data.json",DEST+"source.json"];var hashes={}
 for path in paths:hashes[path]=FileAccess.get_sha256(path)
 var model=Model.new();model.reset(42,{},Regions.layout("east_gate"),false);Art.load_east();var input:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DEST+"source.json"));var frame=Regions.frame("east_gate");var turn=Basis(Vector3.UP,frame.get_rotation());var rows=[]
 for row:Dictionary in input.records:
  var serial=int(row.graphic);var at=frame.inverse()*(Vector2(row.cell[0],row.cell[1])*3.);var anchor=Vector3(at.x,model.surface_height(at.x,at.y),at.y);var sample=[];var bounds=AABB();var low=INF
  if Trees.owns(serial):
   var mesh:Mesh=Trees.mesh(serial,Art.data().graphics[str(serial)]);bounds=mesh.get_aabb();var wood:Array=mesh.get_meta("east_cpu_arrays")[0]
   for p:Vector3 in wood[Mesh.ARRAY_VERTEX]:low=minf(low,p.y)
   var unique={}
   for p:Vector3 in wood[Mesh.ARRAY_VERTEX]:
    if p.y>low+.20:continue
    var local=anchor+turn*p;var key=Vector3(local.x,local.y,local.z).snapped(Vector3.ONE*.001)
    if unique.has(key):continue
    unique[key]=true;sample.append(foot_sample(model,local,frame))
  else:
   var pose=Transform3D(Basis(Vector3.UP,float(serial)*.71-frame.get_rotation()).scaled(Vector3.ONE*float(row.source_row[4])),anchor);var first=true
   for part:Dictionary in Assets.source(str(row.source_row[3])):
    var local_bounds:AABB=(pose*part.transform)*part.mesh.get_aabb();bounds=local_bounds if first else bounds.merge(local_bounds);first=false
   low=bounds.position.y-anchor.y
   for dx in [0.,.5,1.]:
    for dz in [0.,.5,1.]:sample.append(foot_sample(model,Vector3(bounds.position.x+bounds.size.x*dx,bounds.position.y,bounds.position.z+bounds.size.z*dz),frame))
  var source=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/source.json"));var exact=source.records.filter(func(r):return int(r.native_graphic)==serial)[0]
  rows.append({"graphic":serial,"source_cell":row.cell,"source_ground":exact.ground,"source_anchor_open":exact.native_open_at_anchor,"anchor":var_to_str(anchor),"mesh_local_bottom":low,"mesh_bounds":var_to_str(bounds),"source_neighborhood":exact.source_neighborhood,"lowest_wood_or_boulder_samples":sample,"gate_connected":row.gate_connected})
 var changed=[]
 for path in hashes:
  if hashes[path]!=FileAccess.get_sha256(path):changed.append(path)
 var file=FileAccess.open(DEST+"datum.json",FileAccess.WRITE);file.store_string(JSON.stringify({"rows":rows,"source_hashes":hashes,"source_changed":changed,"scope":"CPU positions, original source neighborhood and current terrain field only. No renderer/camera, mesh, floor, collision, walk or route changed. Trees use retained lowest wood vertices; boulders use whole-master CPU bounds."},"  "));file.close();print("MISSING13_DATUM rows=",rows.size()," changed=",changed);quit(0 if changed.is_empty()else 1)
func foot_sample(model,p:Vector3,frame:Transform2D)->Dictionary:
 var cell=Vector2i((frame*Vector2(p.x,p.z)/3.).round());var grid:Vector2=model.terrain.coordinate(p.x,p.z);var x=floori(grid.x);var z=floori(grid.y);var vertices=[]
 for dz in 2:
  for dx in 2:
   var index=(z+dz)*model.terrain.width+x+dx
   if index<0 or index>=model.terrain.heights.size():continue
   vertices.append({"grid":[x+dx,z+dz],"covered":int(model.terrain.covered[index]),"height":model.terrain.heights[index]})
 var h:float=model.surface_height(p.x,p.z);var covered:float=model.terrain._covered_height(p.x,p.z)
 return {"position":var_to_str(p),"source_cell":[cell.x,cell.y],"current_visual_mesh_field_height":h,"current_covered_height":number(covered),"vertical_gap":p.y-h,"field_vertices":vertices}
