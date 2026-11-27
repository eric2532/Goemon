extends "res://tests/forest-shrine/east_landmark_review.gd"
## Root-only review: private shrine work is not a dependency of this scene.
const RootTree=preload("res://scripts/forest/forest_east_root_compounds.gd")
var installed=false
func sites()->Array:return [[11031,11699,Vector2i(19,13),"ancient-root-complete",Vector2i(7,22),Vector2i(7,7)]]
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Ancient Root Final/"
func site_owned(_source:int,serial:int)->bool:return serial==11699
func site_mesh(_source:int,_serial:int,_g:Dictionary)->Mesh:return RootTree.mesh()
func site_visible(_serial:int,_g:Dictionary)->Array:return [0,0,936,1062]
func review_source_paths()->Array:
 var paths=super.review_source_paths()+["scripts/forest/forest_east_root_compounds.gd",RootTree.ROOT+"data.json","scripts/forest/forest_east_nature.gd","assets/maps/falan/east_region/nature/data.json","assets/maps/falan/east_region/nature/11699-front.png"]
 for name in DirAccess.get_files_at(RootTree.ROOT):
  if name.ends_with(".png"):paths.append(RootTree.ROOT+name)
 return paths
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if not installed:
  check(not game.model.Dungeons.roofed(id),"Declared ancient-tree roofless inference is honored")
  check(game.world.map_features.find_child("SolidCaveCeilingCollision",true,false)==null,"No synthetic cave ceiling cuts the original giant tree")
  for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
   if int(node.get_meta("source_graphic",-1))==11699:node.visible=false
  var owner=MeshInstance3D.new();owner.name="PrivateExactAncientRoot";owner.mesh=RootTree.mesh();var at=Maps.point(id,Vector2i(19,13));owner.position=Vector3(at.x,0,at.y);game.world.map_features.add_child(owner)
  check(owner.global_position.distance_to(game.model.world_point(at))<.001,"Complete private root uses the exact original source anchor")
  installed=true
 var view:Dictionary=await super.camera_view(id,wanted,center,height if second else 5.*game.model.falan_scale,second,target_bounds)
 if str(view.get("ray_hit",{}).get("collider","")).contains("Ceiling"):view.clear=false
 return view
func landmark(row:Array):
 await super.landmark(row)
 for item:Dictionary in observations:
  if item.get("viewpoint","")=="ancient-root-complete" and int(item.get("angle",-1))==0:
   item["lower_trunk_hollow_in_frustum"]=item.get("landmark_midpoint_in_frustum",false);item.erase("landmark_midpoint_in_frustum");item["whole_canopy_framing"]="Not claimed by the default.32lower-trunk view; full source-sized umbrella remains unchanged."
