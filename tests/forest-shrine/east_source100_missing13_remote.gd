extends "res://tests/forest-shrine/east_landmark_review.gd"
const Candidate=preload("res://tests/forest-shrine/east_source100_missing13_candidate.gd")
const DEST=Candidate.ROOT+"Remote Views/"
var staged:Node3D
var remote_rows:Dictionary
func local_point(cell:Array)->Vector2:return Tour.Regions.frame("east_gate").inverse()*(Vector2(cell[0],cell[1])*3.)
func run():
 var paths=review_source_paths()+["scripts/forest/forest_freyja_regions.gd","scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_falan_frontier.gd","scripts/forest/forest_east_region.gd","scripts/forest/crowd/army_runtime.gd","scripts/forest/forest_east_native_trees.gd","scripts/forest/forest_east_nature.gd","assets/maps/falan/east_region/native_trees/data.json","assets/maps/falan/east_region/nature/data.json","tests/forest-shrine/east_source100_missing13_candidate.gd",DEST+"source.json",Candidate.ROOT+"source.json",Candidate.ROOT+"diagnosis.json"]
 var hashes=Sources.snapshot(paths);remote_rows=JSON.parse_string(FileAccess.get_file_as_string(DEST+"source.json"))
 phase="Source100 Missing13 Remote";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase));root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east13-remote-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID);game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false);await open_area("east_gate")
 var nav=var_to_bytes(game.army_runtime.navigation_data(game.model,true));var links=var_to_bytes(game.model.get_meta("falan_links",[]));staged=Candidate.build(game.world.map_features,game.model)
 for record:Dictionary in remote_rows.records:await subject(record)
 check(nav==var_to_bytes(game.army_runtime.navigation_data(game.model,true)),"All six visual studies leave Native navigation byte-identical")
 check(links==var_to_bytes(game.model.get_meta("falan_links",[])),"All original routes remain unchanged")
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Remote view snapshot remains source-current")
 var file=FileAccess.open(DEST+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"source_hashes":hashes,"source_changed":changed,"scope":"PRIVATE unchanged Native/source routes. Five subjects use Gate-connected original stands;10069is an isolated-source study and is held from East-reachable publication. Direct spawns do not establish a route."},"  "));file.close();print("EAST13_REMOTE checks=",checks," failures=",errors);await finish()
func subject(record:Dictionary):
 var serial=int(record.graphic);var cell=Vector2i(record.cell[0],record.cell[1]);var holder=staged.get_node("Native_%d_%d_%d"%[serial,cell.x,cell.y]);var bounds=AABB();var first=true
 for node:GeometryInstance3D in holder.find_children("*","GeometryInstance3D",true,false):
  var local_box=(node.global_transform*node.get_aabb()) if node is MeshInstance3D else node.global_transform*node.multimesh.get_aabb()
  bounds=local_box if first else bounds.merge(local_box);first=false
 check(not first,"Source subject has visible geometry "+str(serial))
 collect_camera_canopies(serial)
 for node:MeshInstance3D in staged.find_children("*","MeshInstance3D",true,false):
  if int(node.get_meta("source_graphic",-1))!=serial and node.mesh.get_meta("east_native_tree_fit",false):camera_canopies.append(node.global_transform*node.get_aabb())
 var center3=bounds.get_center();var center=Vector2(center3.x,center3.z)/game.model.falan_scale;var origin=local_point(record.cell);var previous=Vector2.ZERO
 for angle in 2:
  var choices=record.candidate_stands.duplicate();var direction=Vector2(-1,1)if angle==0 else Vector2(1,-1)
  choices.sort_custom(func(a,b):
   var x=Vector2(a[0]-cell.x,a[1]-cell.y);var y=Vector2(b[0]-cell.x,b[1]-cell.y)
   return absf(x.length()-4.)+(1.-x.normalized().dot(direction))*5.<absf(y.length()-4.)+(1.-y.normalized().dot(direction))*5.)
  var found={};var attempts=0
  for stand:Array in choices:
   var at=local_point(stand)
   if at.distance_to(origin)<4.5 or at.distance_to(origin)>27.:continue
   if angle==1 and (at-origin).normalized().dot((previous-origin).normalized())>.35:continue
   if not game.model.terrain.disk_clear(Vector3(at.x,0,at.y),.55):continue
   if game.model.get_meta("falan_links",[]).any(func(link):return at.distance_squared_to(link.at)<20.25):continue
   var triggers=load("res://scripts/forest/forest_east_region.gd").data().automatic
   if triggers.any(func(row):return int(row.source)==100 and Rect2i(row.bounds[0],row.bounds[1],row.bounds[2]-row.bounds[0]+1,row.bounds[3]-row.bounds[1]+1).grow(1).has_point(Vector2i(stand[0],stand[1]))):continue
   attempts+=1
   for pitch in ([.32,.65]if angle==1 else[.32]):
    await position_at(at);var facing=(center-at).normalized();game.camera_rig.yaw=atan2(-facing.x,-facing.y);game.camera_rig.pitch=pitch;game.camera_rig.reset_follow()
    for i in 18:await physics_frame;game.camera_rig.update_camera(1./60.)
    var camera=game.camera_rig.camera
    if angle==1:camera.look_at(center3);camera.reset_physics_interpolation()
    var ray=PhysicsRayQueryParameters3D.create(camera.global_position,center3,1);ray.exclude=game.camera_rig.water_camera.probe.exclude;var hit=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
    var clear=hit.is_empty()or bounds.grow(.25).has_point(hit.position)
    clear=clear and not bounds.grow(.35).has_point(camera.global_position)and not camera_canopies.any(func(box):return box.grow(2.5).has_point(camera.global_position)or box.intersects_segment(camera.global_position,center3))
    var framed=camera.is_position_in_frustum(center3);var distance_ok=game.camera_rig.current_distance>game.camera_rig.unobstructed_distance*.8
    if clear and framed and distance_ok:
     found={"stand":stand,"pitch":pitch,"distance":game.camera_rig.current_distance,"desired":game.camera_rig.unobstructed_distance,"clear":clear,"framed":framed,"gate_connected":record.gate_connected,"source_component_cells":record.component_cells};break
   if not found.is_empty()or attempts>=70:break
  check(not found.is_empty(),"Original-open clear ordinary camera "+str(serial)+" angle"+str(angle))
  if found.is_empty():observations.append({"subject":serial,"angle":angle,"attempts":attempts,"view":"unfinished; no accepted candidate"});continue
  previous=local_point(found.stand);observations.append({"subject":serial,"source_cell":record.cell,"angle":angle,"view":found,"scope":record.scope})
  var label="source100-%d-%d-%d-%s"%[serial,cell.x,cell.y,"normal"if angle==0 else"second"]
  var camera=game.camera_rig.camera;await fixed_capture(label,camera.global_position,camera.global_position-camera.global_basis.z*10.,("default.32normal camera"if angle==0 else"second reachable ordinary eye; pitch"+str(found.pitch))+"; "+record.scope)
