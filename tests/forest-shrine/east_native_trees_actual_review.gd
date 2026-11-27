extends "res://tests/forest-shrine/east_tree_dense_review.gd"
const NativeTrees=preload("res://scripts/forest/forest_east_native_trees.gd")
var counted_maps={}
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Tree Families/Typed27/Actual Maps Final/"
func site_owned(_source:int,serial:int)->bool:return NativeTrees.owns(serial)
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return NativeTrees.mesh(serial,g)
func site_visible(serial:int,_g:Dictionary)->Array:return NativeTrees.data().graphics[str(serial)].visible
func review_source_paths()->Array:return super.review_source_paths()+["scripts/forest/forest_east_native_trees.gd","assets/maps/falan/east_region/native_trees/data.json"]
func sites()->Array:return [
 [32468,10069,Vector2i(13,23),"native-blue-tier-conifer",Vector2i(13,21),Vector2i(17,21)],
 [32468,10089,Vector2i(24,14),"native-silver-open-branches",Vector2i(20,18),Vector2i(25,10)],
 [31913,10074,Vector2i(29,26),"native-green-broadleaf",Vector2i(29,30),Vector2i(25,30)],
]
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if not second:return await super.camera_view(id,wanted,center,height,second,target_bounds)
 var state:Dictionary=Maps.state(id);var cell=Vector2i(((center-state.origin)/3.).round());var seeds=[wanted]
 for radius in [2,4,6,8]:
  for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:seeds.append(cell+direction*radius)
 var attempts=[];var best={};var score=-INF
 for seed:Vector2i in seeds:
  var view:Dictionary=await super.camera_view(id,seed,center,height,true,target_bounds)
  if view.is_empty():continue
  var away=Maps.point(id,view.cell).distance_to(center)
  attempts.append({"seed":[seed.x,seed.y],"cell":[view.cell.x,view.cell.y],"clear":view.clear,"framed":view.framed,"distance_ok":view.distance_ok,"stand_distance":away})
  if view.clear and view.framed and view.distance_ok and away<=maxf(20.,target_bounds.size.y/game.model.falan_scale*2.):
   observations.append({"native27_second_stand_sweep":attempts});return view
  var candidate=(30. if view.clear and view.framed else 0.)+(20. if view.distance_ok else 0.)-away*.1
  if candidate>score:score=candidate;best=view
 observations.append({"native27_second_stand_sweep":attempts,"no_clear_full_distance_second":true})
 check(false,"Native tree needs another clear original second stand "+str(id))
 return {} if best.is_empty() else await super.camera_view(id,best.cell,center,height,true,target_bounds)
func landmark(row:Array):
 await super.landmark(row)
 var source=int(row[0]);if counted_maps.has(source):return
 counted_maps[source]=true
 var state:Dictionary=Maps.state(Maps.runtime_id(source));var n=state.size.x*state.size.y;var expected={};var actual={}
 for index in n:
  var serial=state.raw.decode_u16(20+(n+index)*2)
  if not NativeTrees.owns(serial):continue
  var key=str(serial)+":"+str(index%state.size.x)+","+str(index/state.size.x)
  expected[key]=int(expected.get(key,0))+1
 for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
  if not node.multimesh.mesh.get_meta("east_native_tree_fit",false):continue
  var serial=int(node.get_meta("source_graphic",-1))
  for index in node.multimesh.instance_count:
   var at=node.position+node.multimesh.get_instance_transform(index).origin
   var cell=Vector2i(((Vector2(at.x,at.z)-state.origin)/3.).round())
   var key=str(serial)+":"+str(cell.x)+","+str(cell.y)
   actual[key]=int(actual.get(key,0))+1
 check(actual==expected,"Every native-tree mesh instance retains exact source ID/cell/count "+str(source))
 observations.append({"native27_actual_map":source,"expected":expected.size(),"actual":actual.size(),"placements_equal":actual==expected})
