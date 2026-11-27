extends "res://tests/forest-shrine/east_nature_actual_review.gd"
## Original alternate instances; guards/production camera remain unchanged.
const Volume=preload("res://scripts/forest/forest_east_cactus_volume_prototype.gd")
var installed_cactus=false
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Focused Actual Recheck/"
func sites()->Array:return [
 [31956,11152,Vector2i(68,62),"wispy-tree-clearer-instance",Vector2i(74,62),Vector2i(70,69)],
 [31956,11178,Vector2i(11,83),"cactus-source-face-and-back",Vector2i(8,84),Vector2i(14,82)],
 [51002,1233051,Vector2i(84,94),"flowerbed-courtyard-instance",Vector2i(80,99),Vector2i(90,99)],
 [33292,11660,Vector2i(14,3),"reed-room-closer-stands",Vector2i(11,6),Vector2i(16,5)],
]
func site_mesh(source:int,serial:int,g:Dictionary)->Mesh:
 if serial==11178:return Volume.solid_mesh(serial,g)
 return super.site_mesh(source,serial,g)
func review_source_paths()->Array:return super.review_source_paths()+["scripts/forest/forest_east_cactus_volume_prototype.gd",Volume.ROOT+"data.json"]
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if current_serial==11178 and not installed_cactus:
  var count=0
  for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
   if int(node.get_meta("source_graphic",-1))==11178:
    var mesh=Volume.solid_mesh(11178,Nature.Base.Art.data().graphics["11178"]);mesh.set_meta("east_nature_kind","rounded_native_contour");node.multimesh.mesh=mesh;count+=node.multimesh.instance_count
  check(count>0,"Private cactus keeps exact source batch instance transforms");installed_cactus=true
 return await super.camera_view(id,wanted,center,height,second,target_bounds)
