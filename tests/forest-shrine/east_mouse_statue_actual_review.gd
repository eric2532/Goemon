extends "res://tests/forest-shrine/east_landmark_review.gd"
## Live33608owner. Original map, actors, warps and walk bits remain authoritative.
const Statue=preload("res://scripts/forest/forest_east_mouse_statue.gd")
func sites()->Array:return [[33608]]
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Statue/Actual Maps/"
func review_source_paths()->Array:
 var paths=super.review_source_paths()+["scripts/forest/forest_east_mouse_statue.gd","scripts/forest/forest_falan_interior.gd",Statue.ROOT+"data.json"]
 for name in DirAccess.get_files_at(Statue.ROOT):
  if name.ends_with(".png"):paths.append(Statue.ROOT+name)
 return paths
func landmark(_row:Array):
 var source=33608;var id=Maps.runtime_id(source);var state:Dictionary=Maps.state(id)
 var raw_before=state.raw.duplicate();var bits_before=state.bits.duplicate();var links_before=JSON.stringify(Maps.links(id))
 var first=walk_cell(id,Vector2i(218,63));use_camera_component(id,first)
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Maps.point(id,first),"yaw":0.,"velocity":Vector3.ZERO})
 for frame in 30:await physics_frame
 check(game.model.falan_floor==id,"Original33608room is entered")
 check(game.model.Dungeons.roofed(id),"Room stays indoors; no inferred open sky")
 var mesh=Statue.mesh();var bounds:AABB=mesh.get_meta("statue_bounds");var anchor=Maps.point(id,Vector2i(224,55))
 var owner=game.world.map_features.find_child("RecoveredSourceMouseStatue",true,false) as MeshInstance3D
 check(owner!=null and owner.mesh==mesh,"Default map owner builds the recovered sculpture")
 if owner==null:return
 check(owner.global_position.distance_to(game.model.world_point(anchor))<.001,"Statue retains exact source224,55anchor")
 check(int(owner.get_meta("replaced_unique_bg_tuples",0))==186,"Default map owner replaces only186uniqueBGtuples")
 var minimum_roof=bounds.end.y+1.5
 check(is_equal_approx(Maps.ceiling_height(id),minimum_roof),"Live indoor headroom follows source-sized sculpture")
 var roof_mesh=game.world.map_features.find_child("SolidCaveCeiling",true,false) as MeshInstance3D
 check(roof_mesh!=null and roof_mesh.mesh.get_aabb().position.y>=minimum_roof-.001,"Existing live indoor roof does not cut the sculpture")
 check(game.world.map_features.find_child("SolidCaveCeilingCollision",true,false)!=null,"Indoor physical roof remains present")
 var center=anchor+Vector2(bounds.get_center().x,bounds.get_center().z)
 var world_bounds=AABB(game.model.world_point(anchor)+bounds.position*game.model.falan_scale,bounds.size*game.model.falan_scale)
 for angle in 2:
  var wanted=Vector2i(180,60) if angle==0 else Vector2i(225,63)
  var view:Dictionary=await camera_view(id,wanted,center,(bounds.position.y+bounds.size.y*(.65 if angle==1 else .5))*game.model.falan_scale,angle==1,world_bounds)
  check(not view.is_empty(),"Found original-walk camera "+str(angle))
  if view.is_empty():continue
  check(game.model.falan_floor==id,"Camera remains in33608 "+str(angle))
  check(camera_component.has(view.cell) and game.model.terrain.disk_clear(Vector3(view.at.x,0,view.at.y),.55),"View shares original reachable walk component "+str(angle))
  check(view.clear and view.framed,"Live statue has clear framed sightline "+str(angle))
  check(view.distance_ok,"Camera retains80percent ordinary distance "+str(angle))
  if angle==0:
   var full_frame=true
   for x in 2:
    for y in 2:
     for z in 2:full_frame=full_frame and game.camera_rig.camera.is_position_in_frustum(world_bounds.position+world_bounds.size*Vector3(x,y,z))
   check(full_frame,"Normal view contains the complete source-sized statue bounds")
  observations.append({"angle":angle,"source_cell":[view.cell.x,view.cell.y],"target_bounds":view.target_bounds,"ray_hit":view.ray_hit,"distance_ok":view.distance_ok,"normal_camera_distance":game.camera_rig.current_distance,"desired_camera_distance":view.desired_camera_distance,"orbit_pitch":game.camera_rig.pitch,"physics_sightline_clear":view.clear,"landmark_midpoint_in_frustum":view.framed})
  await capture("mouse-statue-"+("normal" if angle==0 else "second"),source,view.cell,"Live source-sized sculpture; reachable original floor and original indoor roof with separately inferred minimum headroom. Only186unique original BGtuples replaced.")
 var camera:Camera3D=game.camera_rig.camera;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=bounds.size.length()*game.model.falan_scale*1.15
 var target=game.model.world_point(anchor)+bounds.get_center()*game.model.falan_scale
 camera.global_position=target+Statue.EYE.normalized()*maxf(120.,camera.size*4.);camera.look_at(target);camera.reset_physics_interpolation()
 var roof=game.world.map_features.find_child("SolidCaveCeiling",true,false) as Node3D
 var roof_visible=roof.visible;roof.visible=false
 await capture("mouse-statue-native-axis",source,first,"Fixed source-axis cutaway composition study; ceiling hidden only for this diagnostic, not a reachable gameplay camera")
 roof.visible=roof_visible
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 check(state.raw==raw_before and state.bits==bits_before,"Original raw planes and walk bits remain byte-identical")
 check(JSON.stringify(Maps.links(id))==links_before,"All original room connections remain unchanged")
 observations.append({"private_fixture_only":false,"source":source,"original_walk_component_cells":camera_component.size(),"inferred_minimum_indoor_roof_m":minimum_roof,"unique_original_sculpture_bg_removed":186,"exact_bg_replacement_tuples":186,"ordinary_paving_untouched":true,"quest_actor":306355,"quest_behavior":"Original actor and event state retained; F selector is tested separately below"})
 var actor_at=Maps.source_point(id,Vector2i(221,60));var found=false
 for step in[Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT,Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
  var stand=actor_at+step*3.
  if not game.model.terrain.disk_clear(Vector3(stand.x,0,stand.y),.55):continue
  await position_at(stand);var toward=(actor_at-stand).normalized();game.camera_rig.yaw=atan2(-toward.x,-toward.y)
  for frame in 18:await physics_frame
  if game.explorer_npcs.nearest.get("record",{}).get("id","")=="source:306355":found=true;break
 check(found,"Normal F selector reaches original statue actor306355")
 if found:
  var key=InputEventKey.new();key.physical_keycode=KEY_F;key.keycode=KEY_F;key.pressed=true;Input.parse_input_event(key);Input.flush_buffered_events();await process_frame
  key=key.duplicate();key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events();await process_frame
  check(is_instance_valid(game.dialogue),"F opens original statue actor dialogue without qualifying quest flags")
  observations.append({"source_actor":306355,"f_selector":true,"dialogue_opened":is_instance_valid(game.dialogue),"quest_completion":"Not claimed; no choices or original gate flags supplied"})

func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 var view:Dictionary=await super.camera_view(id,wanted,center,height,second,target_bounds)
 if str(view.get("ray_hit",{}).get("collider","")).contains("Ceiling"):view.clear=false
 return view
