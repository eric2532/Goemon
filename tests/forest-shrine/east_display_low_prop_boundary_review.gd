extends "res://tests/forest-shrine/east_display_maps_review.gd"
## Private31900experiment: original full-height player barrier stays intact;
## camera tests only its measured visible furniture height.
var installed=false
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Display Furniture/Private Low Prop Boundary/"
func source_census_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Display Furniture/Actual Maps/native-placements.json"
func fixture_scope()->String:return "Private source31900boundary59diagnosis only: split its exact8.5mcollision union at the actual stamp/chair mesh height; exclude only the upper invisible portion from camera queries. Source walk/player barriers, ordinary camera distance and full sightline guards remain. No production camera or map change."
func fixture_sites()->Array:return [[31900,16825,Vector2i(25,3),"native-card-drawers-low-prop-trial",Vector2i(24,6),Vector2i(23,4)]]
func review_source_paths()->Array:return super.review_source_paths()+["scripts/forest/forest_original_water_camera.gd","scripts/forest/forest_art.gd","scripts/forest/crowd/army_runtime.gd"]
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if not installed:
  var root_=game.world.map_features;var body=root_.find_child("RecoveredShalenaBoundary_59",true,false) as CollisionObject3D
  check(body!=null,"Read-only trace identifies the exact original boundary59")
  if body==null:return {}
  var shape=body.get_child(0) as CollisionShape3D;var extent:Vector3=shape.shape.size;var midpoint:Vector3=shape.position
  check(extent.is_equal_approx(Vector3(.04,8.5,9.)),"Boundary has the source24x3..5footprint and original8.5mheight")
  var visible_height=0.;var found={}
  for node:MultiMeshInstance3D in root_.find_children("*","MultiMeshInstance3D",true,false):
   var serial=int(node.get_meta("source_graphic",-1))
   if serial not in[16824,17537]:continue
   visible_height=maxf(visible_height,node.multimesh.mesh.get_aabb().end.y);found[serial]=true
  check(found.size()==2 and visible_height>0. and visible_height<8.5,"Measured both actual visible low-prop owners")
  if found.size()!=2 or visible_height<=0. or visible_height>=8.5:return {}
  var row:Dictionary=Maps.state(id);var cells:int=row.size.x*row.size.y
  var source_bits=row.bits.duplicate();var before_nav:Dictionary=game.army_runtime.navigation_data(game.model,true)
  var closed_at=Maps.point(id,Vector2i(24,4));var before_terrain_clear=game.model.terrain.disk_clear(Vector3(closed_at.x,0,closed_at.y),.55)
  for y in range(3,6):
   var cell=Vector2i(24,y);var serial=row.raw.decode_u16(20+(cells+y*row.size.x+24)*2)
   check(not Maps.open(row.bits,row.size,cell) and serial in[16824,0,17537],"Exact traced low-prop/closed-floor source cell "+str(cell))
  var prior=AABB(midpoint-extent*.5,extent);var bottom=prior.position.y;var split=visible_height+.03
  var low_extent=extent;low_extent.y=split-bottom
  var high_extent=extent;high_extent.y=prior.end.y-split
  var low_center=midpoint;low_center.y=(bottom+split)*.5
  var high_center=midpoint;high_center.y=(split+prior.end.y)*.5
  var layer=body.collision_layer
  var lower=Maps.Solids.solid(root_,low_center,low_extent,layer,"stone")
  var upper=Maps.Solids.solid(root_,high_center,high_extent,layer,"stone")
  lower.name="PrivateLowFurniturePlayerBarrier";upper.name="PrivateUpperNavigationBarrier"
  var union=AABB(low_center-low_extent*.5,low_extent).merge(AABB(high_center-high_extent*.5,high_extent))
  check(union.position.is_equal_approx(prior.position) and union.size.is_equal_approx(prior.size),"Replacement player collision union equals the full original barrier")
  body.collision_layer=0
  # Use the existing camera owner's setup cache only in this diagnostic scene.
  var exclusions:Array[RID]=[];exclusions.assign(root_.get_meta(Maps.WaterCamera.ROOT_RIDS,[]));exclusions.append(upper.get_rid());root_.set_meta(Maps.WaterCamera.ROOT_RIDS,exclusions)
  game.camera_rig.water_camera=Maps.WaterCamera.new()
  for frame in 3:await physics_frame
  var at=Maps.point(id,Vector2i(24,4))
  var after_nav:Dictionary=game.army_runtime.navigation_data(game.model,true)
  check(row.bits==source_bits and before_nav.friendly_obstacle_min==after_nav.friendly_obstacle_min and before_nav.friendly_obstacle_max==after_nav.friendly_obstacle_max,"Original source walk bits and complete friendly obstacle arrays remain unchanged")
  check(game.model.terrain.disk_clear(Vector3(at.x,0,at.y),.55)==before_terrain_clear,"Terrain-only clearance remains unchanged; original native obstacles retain their separate owner")
  var from_=game.model.world_point(Maps.point(id,Vector2i(23,4)),1.);var to_=game.model.world_point(at,1.)
  var hit=game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from_,to_,1))
  check(not hit.is_empty(),"Player-height collision still blocks the original closed side")
  observations.append({"private_low_prop_boundary":59,"visible_prop_height_local":visible_height,"camera_split_local":split,"original_full_collision_union_retained":true,"source_cells":[[24,3],[24,4],[24,5]],"upper_camera_only_rid":str(upper.get_rid()),"source_walk_cell_closed":true,"friendly_navigation_obstacles_unchanged":true})
  installed=true
 return await super.camera_view(id,wanted,center,height,second,target_bounds)
