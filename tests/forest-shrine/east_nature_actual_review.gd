extends "res://tests/forest-shrine/east_landmark_review.gd"
const Nature=preload("res://scripts/forest/forest_east_nature.gd")
var current_serial=-1
var checked_owner={}
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Nature/Actual Maps/"
func site_owned(_source:int,serial:int)->bool:return Nature.owns(serial)
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Nature.mesh(serial,g)
func site_visible(serial:int,_g:Dictionary)->Array:return Nature.data().graphics[str(serial)].visible
func native_pixel_height(serial:int)->float:return float(Nature.data().graphics[str(serial)].get("profile",{}).get("pixel_height",.045))
func review_source_paths()->Array:return super.review_source_paths()+["scripts/forest/forest_east_nature.gd","assets/maps/falan/east_region/nature/data.json"]
func landmark(row:Array):
 current_serial=int(row[1]);await super.landmark(row)
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if not checked_owner.has(Vector2i(id,current_serial)):
  var count=0
  for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
   if int(node.get_meta("source_graphic",-1))!=current_serial:continue
   check(node.multimesh.mesh.has_meta("east_nature_kind"),"Actual source placement uses Nature owner, rather than reviewing the previous fallback "+str(current_serial))
   if node.multimesh.mesh.has_meta("east_nature_kind"):count+=node.multimesh.instance_count
  check(count>0,"At least one exact live Nature instance exists "+str(current_serial))
  if count==0:return {}
  checked_owner[Vector2i(id,current_serial)]=count
 return await super.camera_view(id,wanted,center,height,second,target_bounds)
func sites()->Array:return [
 [31956,11152,Vector2i(40,30),"native-wispy-tree",Vector2i(36,35),Vector2i(45,28)],
 [31956,11178,Vector2i(11,83),"rounded-native-cactus",Vector2i(15,79),Vector2i(6,78)],
 [31956,11218,Vector2i(6,19),"source-skeletal-remains",Vector2i(12,23),Vector2i(5,25)],
 [34016,1230041,Vector2i(19,11),"blue-basin-tree",Vector2i(13,18),Vector2i(25,10)],
 [43200,1233051,Vector2i(33,33),"raised-source-flowerbed",Vector2i(29,39),Vector2i(40,30)],
 [33510,12164,Vector2i(9,14),"native-cut-stump",Vector2i(5,19),Vector2i(15,12)],
 [33292,11660,Vector2i(14,3),"native-reeds",Vector2i(9,8),Vector2i(17,8)],
 [33297,10024,Vector2i(18,7),"source-potted-shrub",Vector2i(13,12),Vector2i(23,12)],
]
