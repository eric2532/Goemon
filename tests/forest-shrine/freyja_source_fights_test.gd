extends "res://tests/forest-shrine/south_kili_population_test.gd"
## Valid source parties at their actual source zones, with direct native contacts.
const FIGHTS="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja source encounters/"
const East=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const ArmyNav=preload("res://scripts/forest/crowd/army_runtime.gd")
var fights=[]
var cameras=[]
const VIEW_GROUPS=["1000","1014","1027","1031","1007"]
func _initialize():
 create_timer(900).timeout.connect(func():printerr("FREYJA_FIGHTS_TIMEOUT");quit(1))
 run.call_deferred()
func maximum_party(zone:Dictionary,gid:String,eastern:bool)->Array:
 var raw:Dictionary=Population.freyja_data().groups[gid];var counts=[];var party=[]
 for member in raw.source_members:counts.append(1)
 var more=true
 while more and counts.reduce(func(a,b):return a+b,0)<int(zone.maximum):
  more=false
  for i in counts.size():
   if counts.reduce(func(a,b):return a+b,0)>=int(zone.maximum):break
   if counts[i]<int(raw.source_members[i].count[1]):counts[i]+=1;more=true
 for i in counts.size():
  var row:Array=raw.members[i];var index=int(row[0]);var level=int(row[1] if i%2==0 else row[2])
  if eastern:index=int(Population.freyja_data().east_member_indices[str(index)])
  for j in counts[i]:party.append([index,level,raw.source_members[i].enemy_id,gid])
 return party
func run():
 root.size=Vector2i(1280,800)
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIGHTS+"native-station-plan.json"))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-freyja-fights-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"));var group_ids={};var appearances={}
 var views_only="--views-only" in OS.get_cmdline_user_args()
 var wasps_only=views_only and "--wasps-only" in OS.get_cmdline_user_args()
 var wanted=["1031"] if wasps_only else VIEW_GROUPS
 for section in plan.suggested_area_order:
  if views_only and not section.groups.any(func(gid):return gid in wanted):continue
  var area:String=section.area
  Tour.travel(game,Tour.Regions.layout(area),{"arrival":Vector2.ZERO,"yaw":0.,"velocity":Vector3.ZERO})
  for i in 4:await physics_frame
  game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
  game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting();clear_enemies()
  check(game.model.waves.patrol_posts.is_empty(),"Source zones replace the generic fixed patrol pool "+area)
  var baseline=game.army_runtime.handles.size();var eastern=East.owns_model(game.model)
  var tree_boxes=review_canopies() if views_only and DisplayServer.get_name()!="headless" else []
  if views_only and DisplayServer.get_name()!="headless":
   var navigation:Dictionary=ArmyNav.navigation_data(game.model)
   for index in navigation.friendly_obstacle_min.size():
    tree_boxes.append(AABB(navigation.friendly_obstacle_min[index],navigation.friendly_obstacle_max[index]-navigation.friendly_obstacle_min[index]))
  for gid in section.groups:
   if views_only and gid not in wanted:continue
   clear_enemies();game.model.waves.snow_group_ids.clear();game.army_runtime.presentation_events.clear();game.crowd.army.presentation.clear()
   if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.clear()
   game.player.clear_food_buffs();game.player.max_hp=10000.;game.player.hp=10000.;game.tuning.invincible=true
   var spawned_party=false;var center=Vector2.ZERO;var party=[];var zone={};var source_cell=[]
   var stations:Array=plan.groups[gid][area].duplicate(true)
   if not tree_boxes.is_empty():
    for station in stations:
     var world=game.model.world_point(Vector2(station.point[0],station.point[1]))
     var clearance=10000.
     for box:AABB in tree_boxes:
      var middle=box.get_center()
      clearance=minf(clearance,Vector2(maxf(absf(world.x-middle.x)-box.size.x*.5,0.),maxf(absf(world.z-middle.z)-box.size.z*.5,0.)).length())
     station["review_clearance"]=clearance
    stations.sort_custom(func(a,b):return a.review_clearance>b.review_clearance)
   for station in stations:
    center=Vector2(station.point[0],station.point[1]);var cell=Vector2i(station.cell[0],station.cell[1])
    zone=East.zone_at(game.model.falan_floor,cell)if eastern else Population.zone_at(100,cell)
    if int(zone.get("id",-1))!=int(station.zone) or not zone.groups.any(func(choice):return choice[0]==gid):continue
    if not Population.encounter_scope(game.model,center):continue
    var world=game.model.world_point(center,.15)
    if not game.army_runtime.native.can_reach(world,world,.5):continue
    party=maximum_party(zone,gid,eastern)
    game.player.position=world;game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation();game.model.hero_position=world
    game.model.waves.snow_last=world/game.model.falan_scale;game.model.waves.snow_pending=party.duplicate(true);game.model.waves.spawn_clock=0
    game.model.waves.tick(0.,world)
    if game.model.enemies.size()==party.size():spawned_party=true;source_cell=station.cell;break
    clear_enemies();game.model.waves.snow_group_ids.clear()
   check(spawned_party,"Complete source party fits its actual zone through native placement "+gid)
   if not spawned_party:fights.append({"group":gid,"area":area,"unverified":"No native-supported complete-party candidate found; source/mask station inventory is not placement proof."});continue
   game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
   var handles=[];var living=game.model.enemies.keys();var exact=true
   for enemy in game.model.enemies.values():
    var handle=int(game.army_runtime.handles.get(enemy.id,0));handles.append(handle)
    var member=party.filter(func(row):return row[2]==enemy.get("source_enemy",""))
    exact=exact and handle!=0 and enemy.get("source_group","")==gid and not member.is_empty() and int(enemy.level)==int(member[0][1])
    var species:Dictionary=East.data().species[int(member[0][0])]if eastern and not member.is_empty()else Population.data().species[int(member[0][0])]if not member.is_empty()else {}
    if not species.is_empty():appearances[str(int(species.id))]=true
   check(exact,"Native members preserve source IDs, levels, bank indices and one handle each "+gid)
   check(game.army_runtime.external_targets().targetable[0]==1,"Player is targetable on original outdoor encounter ground "+gid)
   if DisplayServer.get_name()!="headless"and gid in VIEW_GROUPS:await capture_party(area,gid,center,source_cell,views_only)
   game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear()
   game.tuning.invincible=false;game.player.invuln=0.;game.player.model.clear_kagerou_dodge()
   for tick in (0 if views_only else 900):
    game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);game.army_runtime.integration_tick(1./60.)
   var contacts=game.army_runtime.event_log.filter(func(event):return event.kind=="external_damage"and event.external_kind==0 and event.source_id in living)
   var missing=living.filter(func(id):return not contacts.any(func(event):return event.source_id==id))
   if not views_only:
    check(missing.is_empty(),"Every native source member produces a combat contact "+gid)
    check(game.player.hp<10000.,"Actual native source party damages the player "+gid)
   fights.append({"group":gid,"area":area,"source_zone":zone.id,"source_cell":source_cell,"party":party,"contacts":contacts.size(),"missing_contact_ids":missing})
   for tick in 180:
    for handle in handles:
     if game.army_runtime.valid(handle):game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
    if handles.all(func(handle):return not game.army_runtime.valid(handle)):break
    game.army_runtime.integration_tick(1./60.)
   game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
   check(game.model.enemies.is_empty()and handles.all(func(handle):return not game.army_runtime.valid(handle)),"Death/pooled cleanup retires every source handle "+gid)
   check(game.army_runtime.handles.size()==baseline,"Repeated source groups preserve handle count "+gid)
   group_ids[gid]=true
  clear_enemies()
 check(group_ids.size()==(wanted.size() if views_only else 32),"Every requested source group is directly exercised")
 if not views_only:check(appearances.size()==13,"All13 source appearances use the existing native owners")
 if views_only and DisplayServer.get_name()!="headless":
  check(cameras.size()==wanted.size()*3,"Requested parties retain three fixed gameplay views each")
 check(JSON.stringify(get_meta("falan_venture"))==saved,"User adventure data stays unchanged")
 var report={"checks":checks,"failures":errors,"goal_complete":false,"groups":fights,"appearances":appearances.keys(),"cameras":cameras,"qualification":"Direct maximum-valid source parties at real source zones, no rare-spawn grinding. Data weights/count caps are separate selection proof; original server probability/AI/formation parity remains qualified."}
 report["camera_review_only"]=views_only
 report["fixture_sha256"]=FileAccess.get_sha256(get_script().resource_path)
 if views_only:report["qualification"]="Camera-only retry at valid source stations; contacts are not repeated here. Original32-group native/rendered combat logs remain separate. Projection and physics rays select candidate views; images require visual review."
 var file=FileAccess.open(FIGHTS+(("wasp-"if wasps_only else "")+("camera-review-headless.json"if DisplayServer.get_name()=="headless"else"camera-review.json")if views_only else "native-fights.json"if DisplayServer.get_name()=="headless"else"rendered-fights.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
 game.queue_free();await process_frame
 print("FREYJA_SOURCE_FIGHTS ",checks," checks ",errors," failures groups=",group_ids.size());quit(1 if errors else 0)
func capture_party(area:String,gid:String,center:Vector2,cell:Array,scout:bool=false):
 # The fixture freezes the game loop; retain its ordinary hero/canopy synchronization.
 game.world.sync(0.)
 game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 var canopies=review_canopies()
 var aim=Vector3.ZERO
 for enemy in game.model.enemies.values():aim+=enemy.pos
 aim/=game.model.enemies.size();var facing=atan2(-(aim-game.player.position).x,-(aim-game.player.position).z)
 game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT;game.camera_rig.character_screen_offset=0;game.camera_rig.combat_camera_angle=0
 var candidates=[]
 for step in (8 if scout else 1):
  for pitch_ in ([.14,.65,1.05,1.15] if scout else [game.COMBAT_CAMERA_PITCH]):
   game.camera_rig.distance=game.ViewPreferences.CAMERA_MAX if scout else game.ViewPreferences.CAMERA_DEFAULT
   game.camera_rig.yaw=facing+step*TAU/8.;game.camera_rig.pitch=pitch_;set_review_camera()
   var score=game.camera_rig.current_distance;var visible=0;var clear=0;var canopy_rays=0
   var camera:Camera3D=game.camera_rig.camera
   for enemy in game.model.enemies.values():
    var head:Vector3=enemy.pos+Vector3.UP*2.
    for point in [enemy.pos+Vector3.UP*.15,head+Vector3.UP]:
     var screen=camera.unproject_position(point)
     if not camera.is_position_behind(point) and Rect2(64,48,1152,704).has_point(screen):visible+=1
    var ray=PhysicsRayQueryParameters3D.create(camera.global_position,head,1)
    if game.player.get_rid().is_valid():ray.exclude=[game.player.get_rid()]
    if game.player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():clear+=1
    if canopies.any(func(box:AABB):return box.intersects_segment(camera.global_position,head)):canopy_rays+=1
   score+=visible*100.+clear*300.-canopy_rays*100.
   candidates.append({"yaw":game.camera_rig.yaw,"pitch":pitch_,"distance_setting":game.camera_rig.distance,"score":score,"framed_points":visible,"clear_rays":clear,"canopy_rays":canopy_rays})
 candidates.sort_custom(func(a,b):return a.score>b.score)
 if scout:check(candidates[0].framed_points==game.model.enemies.size()*2,"Best legal gameplay orbit frames every party member "+gid)
 for index in mini(3 if scout else 1,candidates.size()):
  var choice:Dictionary=candidates[index];game.camera_rig.yaw=choice.yaw;game.camera_rig.pitch=choice.pitch;set_review_camera()
  game.camera_rig.reset_physics_interpolation();game.camera_rig.camera.reset_physics_interpolation()
  await physics_frame
  for i in 4:await process_frame
  var suffix="-wasp-review-%d"%index if "--wasps-only"in OS.get_cmdline_user_args() else "-review-%d"%index
  RenderingServer.force_draw();var path=FIGHTS+area+"-"+gid+(suffix if scout else "-normal")+".png"
  check(root.get_texture().get_image().save_png(path)==OK,"Fixed gameplay view is saved "+gid+" "+str(index))
  cameras.append({"area":area,"group":gid,"source_cell":cell,"player":str(game.player.position),"eye":str(game.camera_rig.camera.global_position),"rotation":str(game.camera_rig.camera.global_rotation),"fov":63.,"camera_distance":game.camera_rig.current_distance,"desired_camera_distance":game.camera_rig.unobstructed_distance,"selection":choice,"actors":game.model.enemies.size(),"sha256":FileAccess.get_sha256(path),"image":path,"visual_acceptance":"Requires image review; framing and physics rays do not prove foliage visibility."})
func set_review_camera():
 game.camera_rig.camera.fov=63.;game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
func review_canopies()->Array[AABB]:
 var boxes:Array[AABB]=[]
 for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
  if node.get_meta("crossgate_tree_part","")!="Canopy" and not node.get_meta("wind_meadow_canopy",false) and not node.multimesh.mesh.get_meta("east_native_tree_fit",false):continue
  for index in node.multimesh.instance_count:boxes.append((node.global_transform*node.multimesh.get_instance_transform(index))*node.multimesh.mesh.get_aabb())
 return boxes
