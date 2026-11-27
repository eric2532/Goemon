extends "res://tests/forest-shrine/east_landmark_review.gd"
## Fixture-only replacement; source raw planes, existing physics and events stay live.
const RootTree=preload("res://scripts/forest/forest_east_root_compounds.gd")
const Shrine=preload("res://scripts/forest/forest_east_living_paint_prototype.gd")
var installed={}
var current_row=[]
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Private Compounds Actual/"
func sites()->Array:return [
 [11031,11699,Vector2i(19,13),"ancient-root-source-compound",Vector2i(7,22),Vector2i(7,7)],
 [33200,1230040,Vector2i(178,100),"shrine-layered-paint",Vector2i(182,107),Vector2i(176,101)],
]
func site_owned(_source:int,serial:int)->bool:return serial in [11699,1230040]
func site_mesh(_source:int,serial:int,_g:Dictionary)->Mesh:return RootTree.mesh() if serial==11699 else Shrine.mesh()
func site_visible(serial:int,g:Dictionary)->Array:return [0,0,936,1062] if serial==11699 else [0,0,g.rect[2],g.rect[3]]
func review_source_paths()->Array:return super.review_source_paths()+[
 "scripts/forest/forest_east_root_compounds.gd",RootTree.ROOT+"data.json",
 "scripts/forest/forest_east_living_paint_prototype.gd",Shrine.ROOT+"data.json",
]
func landmark(row:Array):
 current_row=row
 await super.landmark(row)
 if int(row[1])==11699:
  for observation:Dictionary in observations:
   if observation.get("viewpoint","")==str(row[3]) and int(observation.get("angle",-1))==0:
    observation["lower_trunk_hollow_in_frustum"]=observation.get("landmark_midpoint_in_frustum",false);observation.erase("landmark_midpoint_in_frustum")
    observation["normal_target_height_native_m"]=5.;observation["whole_canopy_framing"]="Not claimed: the source-sized giant canopy extends beyond the ordinary lower-trunk view."
  for shot:Dictionary in captures:
   if shot.name==str(row[3])+"-normal":shot.method+="; explicit lower trunk/hollow framing, with source-sized canopy cropping retained"
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 var source=int(current_row[0]);var serial=int(current_row[1])
 if not installed.has(source):
  if serial==11699:check(not game.model.Dungeons.roofed(id),"Declared source-root roofless inference is honored by runtime (a giant target AABB cannot accept a cave ceiling)")
  var hidden=0
  for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
   if int(node.get_meta("source_graphic",-1))==serial:node.visible=false;hidden+=node.multimesh.instance_count
  var mesh=MeshInstance3D.new();mesh.name="PrivateSourceCompound";mesh.mesh=site_mesh(source,serial,{})
  var at=Maps.point(id,current_row[2]);mesh.position=Vector3(at.x,0,at.y);game.world.map_features.add_child(mesh)
  check(mesh.global_position.distance_to(game.model.world_point(at))<.001,"Private compound uses the exact source/world anchor "+str(source))
  installed[source]=true;observations.append({"private_fixture_only":source,"hidden_original_instances":hidden,"raw_walk_and_events":"unchanged; no live dispatch published"})
 var focus_height=5.*game.model.falan_scale if serial==11699 and not second else height
 var view:Dictionary=await super.camera_view(id,wanted,center,focus_height,second,target_bounds)
 if serial==11699 and not view.get("ray_hit",{}).is_empty() and str(view.ray_hit.get("collider","")).contains("Ceiling"):
  view.clear=false
 return view
