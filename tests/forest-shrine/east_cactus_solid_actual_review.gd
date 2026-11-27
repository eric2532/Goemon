extends "res://tests/forest-shrine/east_nature_actual_review.gd"
const Volume=preload("res://scripts/forest/forest_east_cactus_volume_prototype.gd")
var installed=false
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Cactus Solid Actual/"
func sites()->Array:return [[31956,11178,Vector2i(11,83),"source-grounded-cactus",Vector2i(10,82),Vector2i(6,78)]]
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Volume.solid_mesh(serial,g)
func review_source_paths()->Array:return super.review_source_paths()+["scripts/forest/forest_east_cactus_volume_prototype.gd",Volume.ROOT+"data.json"]
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if not installed:
  var count=0
  for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
   if int(node.get_meta("source_graphic",-1))==11178:
    var mesh:Mesh=Volume.solid_mesh(11178,Nature.Base.Art.data().graphics["11178"]);mesh.set_meta("east_nature_kind","rounded_native_contour");node.multimesh.mesh=mesh;count+=node.multimesh.instance_count
  check(count>0,"Private source-grounded cactus uses exact existing instance transforms")
  var g:Dictionary=Nature.Base.Art.data().graphics["11178"];var spec:Dictionary=Volume.data().graphics["11178"];var foot=BaseFoot(g,spec)
  check(absf(foot.y)<.0001,"Measured colored source stem, rather than residual shadow, meets native ground")
  installed=true
 return await super.camera_view(id,wanted,center,height,second,target_bounds)
func BaseFoot(g:Dictionary,spec:Dictionary)->Vector3:return Nature.Base.projected(Vector2(27,132),g,0.,spec.ground_offset)*Vector3(1.,Nature.Base.OWNER_Y_SCALE,1.)
