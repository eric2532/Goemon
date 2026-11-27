extends SceneTree
const RootTree=preload("res://scripts/forest/forest_east_root_compounds.gd")
const Cactus=preload("res://scripts/forest/forest_east_round_cactus.gd")
const Shrine=preload("res://scripts/forest/forest_east_living_paint_prototype.gd")
var failures=[]
var checks=0
func check(okay:bool,label:String):
 checks+=1
 if not okay:failures.append(label)
func shape(label:String,mesh:Mesh):
 check(mesh!=null and mesh.get_surface_count()>0,label+" has surfaces")
 check(mesh.get_aabb().position.is_finite() and mesh.get_aabb().size.is_finite(),label+" has finite bounds")
 var count=0
 for arrays:Array in mesh.get_meta("east_cpu_arrays"):
  for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
   count+=1
   if not point.is_finite():failures.append(label+" nonfinite vertex");break
 return {"name":label,"bounds":var_to_str(mesh.get_aabb()),"vertices":count,"surfaces":mesh.get_surface_count()}
func ground_up(label:String,mesh:Mesh):
 var points:PackedVector3Array=mesh.get_meta("east_cpu_arrays")[-1][Mesh.ARRAY_VERTEX]
 check((points[1]-points[0]).cross(points[2]-points[0]).y>0.,label+" ground winding faces upward")
func _initialize():run.call_deferred()
func run():
 RootTree.Base.Art.load_east();var rows=[]
 var tree:Mesh=RootTree.mesh();rows.append(shape("ancient_root",tree));ground_up("ancient_root",tree)
 check(tree.get_aabb().size.y>15. and tree.get_aabb().size.y<25.,"Native umbrella footprint is not reinterpreted as a29mvertical card")
 var info:Dictionary=RootTree.data();var crown_g={"origin":info.crown.native_origin,"rect":[0,0,info.crown.native_size[0],info.crown.native_size[1]],"footprint":[1,1]}
 var junction:Vector3=RootTree.Nature.dome_point(Vector2(437,511),crown_g,RootTree.crown_spec(),false)
 var body_top=RootTree.Base.point(Vector2(385,0),327./RootTree.Base.Fit.VERTICAL,RootTree.body_graphic())*Vector3(1.,RootTree.Base.OWNER_Y_SCALE,1.)
 check(junction.distance_to(body_top)<.001,"Closed native umbrella joins the measured trunk-top source point")
 check(tree.get_meta("east_root_canopy_owner","")=="source_leaf_dome","Complete root uses the prepared closed umbrella")
 for token in Cactus.data().graphics:
  var mesh:Mesh=Cactus.mesh(int(token),RootTree.Base.Art.data().graphics[token]);rows.append(shape(token,mesh));ground_up(token,mesh)
  check(mesh.get_aabb().size.y>.4,"Round source cactus has volume "+token)
 rows.append(shape("shrine_paint_private",Shrine.mesh()))
 var report={"checks":checks,"failures":failures,"meshes":rows,"scope":"CPU construction/winding/volume only; no rendered visual acceptance."}
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/private-nature-meshes.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("EAST_PRIVATE_NATURE_MESHES checks=",checks," failures=",failures.size())
 for failure in failures:push_error(failure)
 quit(failures.size())
