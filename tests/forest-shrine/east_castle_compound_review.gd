extends "res://tests/forest-shrine/east_landmark_review.gd"
const Compound=preload("res://scripts/forest/forest_east_castle_compound.gd")
const FrameProof=preload("res://tests/forest-shrine/east_castle_roof_asset_review.gd")
const CASTLE_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Classic Architecture/Castle Compound/"
func review_path()->String:return CASTLE_OUT

func run():
 root.size=Vector2i(1440,900);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CASTLE_OUT))
 var before=Sources.snapshot(review_source_paths()+["scripts/forest/forest_east_castle_compound.gd","scripts/forest/forest_east_castle_roof.gd","tests/forest-shrine/east_castle_roof_asset_review.gd","assets/maps/falan/east_region/classic_architecture/castle_roof/data.json","assets/maps/original_crossgate/beast-castle.png","assets/maps/original_crossgate/beast-castle-sculpture-surfaces.png","scripts/forest/forest_beast_castle.gd","scripts/forest/forest_original_map_art.gd","assets/maps/falan/east_region/classic_architecture/castle_compound/data.json","assets/maps/original_crossgate/catalog.json"])
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-castle-compound-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false
 game.tuning.invincible=true;game.player.set_auto_attack(false);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 var id=Maps.runtime_id(31954);var initial=walk_cell(id,Vector2i(760,82));use_camera_component(id,initial)
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Maps.point(id,initial),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 20:await process_frame
 check(game.model.falan_floor==id,"Actual castle remains on original31954")
 var nodes=game.world.map_features.find_children("NativeEastBeastCastleCompound","MeshInstance3D",true,false)
 check(nodes.size()==1,"The exact71piece native compound has one existing whole castle owner")
 if nodes.is_empty():await finish();return
 var node:MeshInstance3D=nodes[0];var spec=Compound.data();var mesh=Compound.mesh();var state=Maps.state(id)
 check(node.mesh==mesh and mesh==Compound.mesh(),"The immutable complete castle uses its isolated canonical East derivative")
 var frame=FrameProof.frame_proof(mesh,Compound.Castle.mesh())
 for row:Array in frame.checks:check(row[0],row[1])
 observations.append({"canonical_frame":frame})
 check(node.get_meta("source_anchor")==Vector2i(760,58) and node.get_meta("native_constituents")==71,"The complete castle retains its translated original source anchor")
 var anchor=Maps.source_point(id,Vector2i(760,58));check(Vector2(node.position.x,node.position.z).distance_to(anchor)<.001 and node.scale==Vector3.ONE,"No extra source origin offset or caller height conversion is applied")
 var count=0
 for row:Array in spec.pieces:
  var cell=Vector2i(row[1],row[2]);var index=int(row[0])*state.size.x*state.size.y+cell.y*state.size.x+cell.x
  var serial=state.raw.decode_u16(20+index*2)
  check(serial==int(row[3]) and Compound.skip(31954,int(row[0]),cell,serial),"Exact original compound tuple retained "+str(row));count+=1
 check(count==71 and not Compound.skip(31954,1,Vector2i(755,58),10011) and not Compound.skip(400,1,Vector2i(756,58),10011),"Skip ownership is bounded to the71proven East tuples")
 var bounds=mesh.get_aabb();var center=anchor+Vector2(bounds.get_center().x,bounds.get_center().z)
 var world_bounds:AABB=node.global_transform*bounds;castle_canopies()
 for row in [["normal-lower-facade-detail",false,[Vector2i(760,70),Vector2i(751,70),Vector2i(767,67),Vector2i(751,59),Vector2i(765,60),Vector2i(760,84),Vector2i(754,82)]],["whole-front",true,[Vector2i(754,82),Vector2i(760,84),Vector2i(767,78)]],["whole-second",true,[Vector2i(747,46),Vector2i(748,43),Vector2i(774,46),Vector2i(750,70),Vector2i(770,75)]]]:
  var label:String=row[0];var aimed:bool=row[1];var framing=world_bounds
  if not aimed:
   var native:Dictionary=Maps.Art.data().beast_castle
   var door=Compound.Castle.native_floor(Vector2(387.5,512),0.,native);var foot:Vector3=node.global_transform*door;var scale_:float=game.model.falan_scale
   framing=AABB(foot+Vector3(-6,0,-4)*scale_,Vector3(12,6,8)*scale_)
  var view=await castle_view(id,row[2],framing,aimed)
  check(not view.is_empty(),"A source-connected castle gameplay view exists "+label)
  if view.is_empty():continue
  check(camera_component.has(view.cell) and view.clear and view.framed,"Castle view uses the same original walk component and fully framed intended bounds "+label)
  observations.append({"view":label,"detail_only":not aimed,"source_cell":[view.cell.x,view.cell.y],"source_walk_component_cells":camera_component.size(),"direct_spawn_on_original_islet":true,"clear":view.clear,"framed":view.framed,"framed_bounds":var_to_str(framing),"world_bounds":var_to_str(world_bounds),"camera_distance":view.camera_distance,"desired_camera_distance":view.desired_camera_distance,"distance_ok":view.distance_ok})
  await capture("native-beast-castle-"+label,31954,view.cell,"Ordinary camera lower-doorway/facade detail; the entire tower is intentionally outside this detail frame. Compression, if any, is recorded." if not aimed else "Complete castle from a gameplay eye in the same original697cell islet walk component; aimed upward, no new route or landing")
 var changed=Sources.changed(before);check(changed.is_empty(),"Loaded compound source owners remain current through actual capture")
 var file=FileAccess.open(CASTLE_OUT+"review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"source_hashes":before,"source_changed_during_run":changed,"source_tuple_count":71,"scope":"Actual31954exact71tuple compound reuse and normal/reachable-second views. Original source bytes/walk/warps unchanged. Images require independent visual judgment."},"  "));file.close()
 print("EAST_CASTLE_COMPOUND_RESULT checks=",checks," failures=",errors," captures=",captures.size())
 await finish()

func castle_canopies():
 camera_canopies.clear()
 for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
  var serial=int(node.get_meta("source_graphic",-1));var native:Dictionary=Maps.Art.data().graphics.get(str(serial),{})
  var tree=not str(node.get_meta("crossgate_tree_part","")).is_empty() or node.get_meta("wind_meadow_canopy",false) or serial in range(11188,11209)
  if not native.is_empty():tree=tree or Maps.Forms.kind(serial,false,native)=="tree"
  if not tree:continue
  for index in node.multimesh.instance_count:camera_canopies.append((node.global_transform*node.multimesh.get_instance_transform(index))*node.multimesh.mesh.get_aabb())

func castle_framed(camera:Camera3D,bounds:AABB)->bool:
 var safe=Rect2(Vector2(16,16),Vector2(root.size)-Vector2(32,32))
 for index in 8:
  var p=bounds.get_endpoint(index)
  if not camera.is_position_in_frustum(p) or not safe.has_point(camera.unproject_position(p)):return false
 return true

func castle_view(id:int,wanted:Array,bounds:AABB,aimed:bool)->Dictionary:
 var target=bounds.get_center();var center=Vector2(target.x,target.z)/game.model.falan_scale
 for desired:Vector2i in wanted:
  var stand=walk_cell(id,desired);var at=Maps.point(id,stand)
  if not camera_component.has(stand):continue
  await position_at(at)
  if game.model.falan_floor!=id:continue
  for pitch in ([.14,.65] if aimed else [.32]):
   var toward=(center-at).normalized();game.camera_rig.yaw=atan2(-toward.x,-toward.y);game.camera_rig.pitch=pitch;game.camera_rig.reset_follow()
   for i in 18:await physics_frame;game.camera_rig.update_camera(1./60.)
   var camera:Camera3D=game.camera_rig.camera
   if bounds.grow(.2).has_point(camera.global_position) or camera_canopies.any(func(box:AABB):return box.grow(.4).has_point(camera.global_position)):continue
   if aimed:camera.look_at(target);camera.reset_physics_interpolation()
   var ray=PhysicsRayQueryParameters3D.create(camera.global_position,target,1);ray.exclude=game.camera_rig.water_camera.probe.exclude
   var hit=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
   var distance_ok=game.camera_rig.current_distance>game.camera_rig.combat_distance()*.8
   var clear=(hit.is_empty() or bounds.grow(.25).has_point(hit.position)) and not camera_canopies.any(func(box:AABB):return box.intersects_segment(camera.global_position,target))
   var framed=castle_framed(camera,bounds)
   if clear and framed and (distance_ok or not aimed):return {"cell":stand,"clear":clear,"framed":framed,"camera_distance":game.camera_rig.current_distance,"desired_camera_distance":game.camera_rig.combat_distance(),"distance_ok":distance_ok}
 return {}
