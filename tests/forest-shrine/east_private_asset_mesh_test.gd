extends SceneTree
## Candidate construction smoke check; visual acceptance and map hooks are separate.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Casework=preload("res://scripts/forest/forest_east_room_casework.gd")
const Counters=preload("res://scripts/forest/forest_east_room_counters.gd")
const Mounted=preload("res://scripts/forest/forest_east_mounted_details.gd")
const Hours=preload("res://scripts/forest/forest_east_hourglasses.gd")
const Dragon=preload("res://scripts/forest/forest_east_dragon_hourglass.gd")
const Roof=preload("res://scripts/forest/forest_east_lektal_roof.gd")
const Wheel=preload("res://scripts/forest/forest_east_waterwheel.gd")
const Sources=preload("res://tests/forest-shrine/east_review_sources.gd")
var checks=0
var failures=0
var observations=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func inspect_mesh(mesh:Mesh,label:String):
 check(mesh!=null and mesh.get_surface_count()>0,"Constructed "+label)
 var vertices=0;var triangles=0;var valid=true
 for slot in mesh.get_surface_count():
  var arrays:Array=mesh.get_meta("east_cpu_arrays")[slot] if mesh.has_meta("east_cpu_arrays") else mesh.surface_get_arrays(slot)
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];vertices+=points.size()
  for p:Vector3 in points:valid=valid and p.is_finite()
  var indices:Variant=arrays[Mesh.ARRAY_INDEX]
  if indices is PackedInt32Array and not indices.is_empty():
   triangles+=indices.size()/3
   for i:int in indices:valid=valid and i>=0 and i<points.size()
  else:triangles+=points.size()/3;valid=valid and points.size()%3==0
  check(mesh.surface_get_material(slot)!=null,"Owned material "+label+":"+str(slot))
 check(valid and vertices>0 and triangles>0,"Finite referenced triangles "+label)
 check(mesh.get_aabb().size.length()>0.,"Nonempty bounded geometry "+label)
 observations.append({"asset":label,"surfaces":mesh.get_surface_count(),"vertices":vertices,"triangles":triangles,"bounds":var_to_str(mesh.get_aabb())})
func run():
 var paths=[get_script().resource_path,"scripts/forest/forest_original_map_art.gd","scripts/forest/forest_east_region_art.gd","scripts/forest/forest_coastal_mesh.gd","scripts/forest/forest_falan_interior_furniture.gd","scripts/forest/forest_falan_building_shapes.gd","scripts/forest/forest_falan_lamps.gd","assets/maps/original_crossgate/east/catalog.json","assets/maps/falan/east_region/landmarks/profiles.json"]
 for name_ in ["room_furniture","room_casework","room_counters","mounted_details","hourglasses","dragon_hourglass","lektal_roof","waterwheel"]:
  paths.append("scripts/forest/forest_east_"+name_+".gd")
  if name_!="room_counters":paths.append("assets/maps/falan/east_region/"+name_+"/data.json")
 var hashes=Sources.snapshot(paths)
 Art.load_east()
 for helper in [Casework,Counters,Mounted,Hours]:
  for serial in helper.IDS:
   var mesh:Mesh=helper.mesh(serial,Art.data().graphics[str(serial)])
   inspect_mesh(mesh,str(serial));check(helper.mesh(serial,Art.data().graphics[str(serial)])==mesh,"Cached immutable candidate "+str(serial))
 for source in [58000,58001]:inspect_mesh(Dragon.mesh(source),"dragon-"+str(source))
 inspect_mesh(Roof.mesh(1233255,Art.data().graphics["1233255"]),"roof-1233255")
 inspect_mesh(Wheel.mesh(1238504,Art.data().graphics["1238504"]),"waterwheel-1238504")
 var rim=SurfaceTool.new();rim.begin(Mesh.PRIMITIVE_TRIANGLES);Wheel.ring(rim,0.,4.2,12)
 var ring_arrays=rim.commit_to_arrays();var ring_points:PackedVector3Array=ring_arrays[Mesh.ARRAY_VERTEX];var ring_normals:PackedVector3Array=ring_arrays[Mesh.ARRAY_NORMAL]
 var outward=true
 for i in range(0,ring_points.size(),3):
  var p=(ring_points[i]+ring_points[i+1]+ring_points[i+2])/3.;var n=ring_normals[i];var radial=Vector3(0,p.y,p.z).normalized()
  if absf(n.x)>.9:outward=outward and signf(n.x)==signf(p.x)
  elif absf(n.dot(radial))>.9:outward=outward and n.dot(radial)*(1. if Vector2(p.y,p.z).length()>4.05 else -1.)>.9
 check(outward,"Closed polygonal wheel rims face outside on both sides and inner/outer circumference")
 check(Roof.roof_proof.size()==5,"One chimney and four hatch corners measured on reused roof")
 for row in Roof.roof_proof:
  if row.part=="hatch":check(row.physical_depth>0.,"Hatch closed to roof "+str(row.native_pixel))
 var out="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/private-asset-meshes.json"
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Loaded candidate construction inputs stay current")
 var file=FileAccess.open(out,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"assets":observations,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Headless candidate mesh construction only; no rendered quality, activated map or navigation claim."},"  "));file.close()
 print("EAST_PRIVATE_ASSET_MESH_RESULT checks=",checks," failures=",failures," meshes=",observations.size());quit(failures)
