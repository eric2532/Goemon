extends "res://tests/forest-shrine/sokia_server_npcs_review.gd"
## Review flags change only in memory; source gates and user adventure stay intact.
const East=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const TRIAL_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Trial caves/"
var trial_report={"maps":[],"groups":[],"ports":[],"goal_complete":false}
var party_views_only=false
var mixed_views_only=false
var review_hp=10000.
func _initialize():
 create_timer(1200).timeout.connect(func():printerr("FREYJA_TRIAL_TIMEOUT");quit(1))
 run.call_deferred()
func take_view(label_:String,cell:Vector2i,yaw:float=0.,screen_offset:float=0.):
 await super.take_view(label_,cell,yaw,screen_offset)
 if DisplayServer.get_name()=="headless":return
 var old=SERVER_OUT+label_+".png";var target=TRIAL_OUT+label_.replace("NPCs and gates/","")+".png"
 check(DirAccess.rename_absolute(ProjectSettings.globalize_path(old),ProjectSettings.globalize_path(target))==OK,"Fixed gameplay view saved: "+label_)
 server_report.captures[-1]["image"]=target
func maximum_party(zone:Dictionary,key:String)->Array:
 var source:Dictionary=East.data().groups[key];var counts=[];var party=[]
 for member in source.source_members:counts.append(maxi(1,int(member.count[0])))
 var more=true
 while more and counts.reduce(func(a,b):return a+b,0)<int(zone.maximum):
  more=false
  for i in counts.size():
   if counts.reduce(func(a,b):return a+b,0)>=int(zone.maximum):break
   if counts[i]<int(source.source_members[i].count[1]):counts[i]+=1;more=true
 for i in counts.size():
  var row:Array=source.members[i]
  for j in counts[i]:party.append([int(row[0]),int(row[1]if i%2==0 else row[2]),source.source_members[i].enemy_id,key])
 return party
func direct_group(id:int,cell:Vector2i,key:String,zone:Dictionary):
 var source:Dictionary=East.data().groups[key];var party=maximum_party(zone,key)
 check(party.size()<=int(zone.maximum),"Source cap retains every distinct identity "+key)
 var record={"map":id,"zone":zone.id,"key":key,"party":party,"generations":[]}
 for generation in (1 if party_views_only else 2):
  clear_enemies();game.model.waves.snow_group_ids.clear();game.army_runtime.presentation_events.clear();game.crowd.army.presentation.clear()
  game.player.clear_food_buffs();game.player.max_hp=review_hp;game.player.hp=review_hp;game.tuning.invincible=true
  var spawned=false;var station=cell;var baseline=game.army_runtime.handles.size()
  var stations=candidate_cells(id)
  # Source-mask9x9 openness:11008(33,11)=80/81;11009(7,21)=80/81.
  var wide_stations={11008:Vector2i(33,11),11009:Vector2i(7,21)}
  if party_views_only and wide_stations.has(id):
   stations.erase(wide_stations[id]);stations.push_front(wide_stations[id])
  for candidate in stations:
   if int(East.zone_at(id,candidate).get("id",-1))!=int(zone.id):continue
   var at=game.model.world_point(Original.source_point(id,candidate),.15)
   if not game.army_runtime.native.can_reach(at,at,.5):continue
   game.player.position=at;game.player.velocity=Vector3.ZERO;game.model.hero_position=at;game.player.reset_physics_interpolation()
   game.model.waves.snow_last=at/game.model.falan_scale;game.model.waves.snow_distance=0.;game.model.waves.snow_pending=party.duplicate(true);game.model.waves.spawn_clock=0
   game.model.waves.tick(0.,at)
   if game.model.enemies.size()==party.size():spawned=true;station=candidate;break
   clear_enemies();game.model.waves.snow_group_ids.clear()
  check(spawned,"Whole party fits actual source zone through normal dispatch "+key)
  if not spawned:record.generations.append({"generation":generation,"unverified":"No whole-party native station"});continue
  game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
  var handles=[];var ids=game.model.enemies.keys();var exact=true;var expected_counts={};var actual_counts={}
  for member in party:
   var tag="%s:%d:%d"%[member[2],int(member[1]),int(East.data().species[int(member[0])].skin)]
   expected_counts[tag]=int(expected_counts.get(tag,0))+1
  for enemy in game.model.enemies.values():
   var handle=int(game.army_runtime.handles.get(enemy.id,0));handles.append(handle)
   var member=party.filter(func(row):return str(row[2])==str(enemy.get("source_enemy",""))and int(row[1])==int(enemy.level))
   var original=source.source_members.filter(func(row):return str(row.enemy_id)==str(enemy.get("source_enemy","")))
   exact=exact and handle!=0 and int(enemy.get("snow_encounter",-1))==int(zone.id) and enemy.get("source_group","")==key and not member.is_empty() and not original.is_empty()
   if not member.is_empty()and not original.is_empty():exact=exact and int(enemy.level)==int(member[0][1]) and enemy.enemy_name==original[0].name and int(enemy.skin)==int(East.data().species[member[0][0]].skin)
   var tag="%s:%d:%d"%[str(enemy.get("source_enemy","")),int(enemy.level),int(enemy.skin)]
   actual_counts[tag]=int(actual_counts.get(tag,0))+1
  exact=exact and actual_counts==expected_counts
  check(exact,"Native handles preserve contextual names, IDs, levels and existing atlas rows "+key)
  if party_views_only:
   await capture_party_views(id,key,station)
   clear_enemies();record.generations.append({"generation":generation,"station":str(station),"camera_only":true});continue
  if generation==0:await take_view("group-"+key.replace(":","-"),station,PI*.5)
  var hp_after_camera=game.player.hp
  # Deferred XP from the prior cleanup can restore ordinary stats during capture frames.
  game.player.max_hp=review_hp;game.player.hp=review_hp
  game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear()
  game.tuning.invincible=false;game.player.invuln=0.;game.player.model.clear_kagerou_dodge()
  for tick in 900:
   game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);game.army_runtime.integration_tick(1./60.)
  var contacts=game.army_runtime.event_log.filter(func(event):return event.kind=="external_damage"and event.external_kind==0 and event.source_id in ids)
  check(ids.all(func(enemy_id):return contacts.any(func(event):return event.source_id==enemy_id)),"Every member delivers native combat contact "+key)
  check(game.player.hp<review_hp,"Live hero receives native damage "+key)
  for tick in 180:
   for handle in handles:
    if game.army_runtime.valid(handle):game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
   if handles.all(func(handle):return not game.army_runtime.valid(handle)):break
   game.army_runtime.integration_tick(1./60.)
  game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
  check(game.model.enemies.is_empty()and handles.all(func(h):return not game.army_runtime.valid(h)),"Death retires every native handle "+key)
  check(game.army_runtime.handles.size()==baseline,"Pooled reuse returns to baseline "+key)
  record.generations.append({"generation":generation,"station":str(station),"contacts":contacts.size(),"members":ids.size(),"player_damaged":game.player.hp<review_hp,"hp_after_camera":hp_after_camera,"hero_hp_after":game.player.hp,"phase_after":game.model.phase,"building_1_after":game.model.buildings.get(1,{}).duplicate(true)})
 trial_report.groups.append(record)
func capture_party_views(id:int,key:String,cell:Vector2i):
 game.world.sync(0.);game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 var rig=game.camera_rig;var camera:Camera3D=rig.camera;var choices=[]
 rig.impulse=0.;rig.kick_strength=0.;rig.kick_age=100.;rig.character_screen_offset=0.;rig.combat_camera_angle=0;rig.distance=game.ViewPreferences.CAMERA_MAX
 for step in 8:
  for pitch_ in [game.COMBAT_CAMERA_PITCH,.65,1.05]:
   rig.yaw=step*TAU/8.;rig.pitch=pitch_;camera.fov=63.;rig.reset_follow();rig.current_distance=rig.combat_distance();rig.update_camera(0.,true)
   var framed=0;var clear=0;var visible_members=[]
   for enemy in game.model.enemies.values():
    var visible_points=0
    for point in [enemy.pos+Vector3.UP*.15,enemy.pos+Vector3.UP*3.]:
     if not camera.is_position_behind(point)and Rect2(64,48,1152,704).has_point(camera.unproject_position(point)):framed+=1;visible_points+=1
    if visible_points==2:visible_members.append(enemy.id)
    var ray=PhysicsRayQueryParameters3D.create(camera.global_position,enemy.pos+Vector3.UP*1.5,1);ray.exclude=[game.player.get_rid()]
    if game.player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():clear+=1
   choices.append({"yaw":rig.yaw,"pitch":pitch_,"framed_points":framed,"visible_members":visible_members,"clear_rays":clear,"score":framed*1000.+clear*100.+rig.current_distance})
 choices.sort_custom(func(a,b):return a.score>b.score)
 var selected=[];var covered={}
 for index in 3:
  choices.sort_custom(func(a,b):return a.visible_members.filter(func(unit):return not covered.has(unit)).size()*100000.+a.score>b.visible_members.filter(func(unit):return not covered.has(unit)).size()*100000.+b.score)
  var choice:Dictionary=choices.pop_front();selected.append(choice)
  for unit in choice.visible_members:covered[unit]=true
 check(covered.size()==game.model.enemies.size(),"Three legal gameplay views cover every native party member "+key)
 if not trial_report.has("party_cameras"):trial_report.party_cameras=[]
 for index in 3:
  var choice:Dictionary=selected[index];rig.yaw=choice.yaw;rig.pitch=choice.pitch;camera.fov=63.;rig.reset_follow();rig.current_distance=rig.combat_distance();rig.update_camera(0.,true)
  rig.reset_physics_interpolation();camera.reset_physics_interpolation();await physics_frame
  for i in 4:await process_frame
  var path=TRIAL_OUT+"party-view-"+key.replace(":","-")+"-%d.png"%index
  RenderingServer.force_draw();check(root.get_texture().get_image().save_png(path)==OK,"Party gameplay view saved "+key)
  trial_report.party_cameras.append({"map":id,"group":key,"source_cell":str(cell),"image":path,"sha256":FileAccess.get_sha256(path),"selection":choice,"eye":str(camera.global_position),"rotation":str(camera.global_rotation),"fov":camera.fov,"distance_setting":rig.distance,"actual_distance":rig.current_distance,"members":game.model.enemies.values().map(func(e):return {"source_id":e.source_enemy,"position":str(e.pos),"skin":e.skin}),"qualification":"Legal camera orbit/zoom; projection and physics rays alone are not visual approval."})
func trial_ports():
 var outside=Tour.Regions.frame("freyja").inverse()*(Vector2(351,145)*3.)
 Tour.travel(game,Tour.outdoor_layout(get_meta("falan_venture"),"freyja"),{"arrival":outside,"yaw":0.,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 freeze()
 var entrances=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("site",-1))==11013)
 check(entrances.size()==1,"Existing No.24 Mine marker has one source entrance")
 if entrances.size()==1:
  var entrance:Dictionary=entrances[0]
  check(entrance.at.distance_squared_to(outside)<.01,"Mine entrance preserves original100(351,145)")
  check(entrance.arrival.distance_squared_to(Original.source_point(11013,Vector2i(12,29)))<.01,"Mine marker preserves original11013(12,29) landing")
  game.falan_crossing_position=entrance.at+Vector2(4,0)
  game.player.position=game.model.world_point(entrance.at,.15);game.model.hero_position=game.player.position
  check(Tour.cross_on_foot(game),"Ordinary on-foot crossing enters source Mine")
  for i in 6:await physics_frame
  freeze()
  check(game.model.falan_floor==11013,"Normal entrance reaches complete source11013")
 for values in Original.Art.data().warps:
  var id=int(values[0]);var target=int(values[3])
  if id not in Original.Art.FREYJA_TRIAL_IDS:continue
  var cell=Vector2i(values[1],values[2]);var landing=Vector2i(values[4],values[5])
  var links=Original.links(id).filter(func(link):return link.at.distance_squared_to(Original.source_point(id,cell))<.01 and (int(link.get("floor",-1))==target or target==100 and link.get("area","")=="freyja"))
  check(links.size()==1,"Exactly one source port "+str(values))
  if links.size()!=1:continue
  var expected=Original.source_point(target,landing)if target!=100 else Tour.Regions.frame("freyja").inverse()*(Vector2(landing)*3.)
  check(links[0].arrival.distance_squared_to(expected)<.01,"Exact source landing "+str(values))
  await visit(id);Tour.enter_link(game,"interior",links[0],links[0].at)
  for i in 6:await physics_frame
  freeze()
  check(game.model.falan_floor==target if target!=100 else Tour.area(game.model)=="freyja","Existing travel realizes source port "+str(values))
  trial_report.ports.append({"source":values,"arrival":str(links[0].arrival),"runtime_floor":game.model.falan_floor,"runtime_area":Tour.area(game.model)})
func run():
 party_views_only="--party-views"in OS.get_cmdline_user_args()
 mixed_views_only=party_views_only and "--mixed-only"in OS.get_cmdline_user_args()
 root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TRIAL_OUT))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SERVER_OUT+"NPCs and gates/"))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-trial-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.player.set_auto_attack(false);freeze()
 var saved=JSON.stringify(get_meta("falan_venture"));Original.Art.load_freyja_trial();var flags={};var groups={}
 for id in Original.Art.FREYJA_TRIAL_IDS:
  var source:Dictionary=Original.Art.data().maps[Original.path_for(id)]
  flags[id]=source.sokia_visual_only;check(source.sokia_visual_only and not Original.owns(id)and not East.owns(id),"Unreviewed map stays gated in normal dispatch "+str(id));source.sokia_visual_only=false
 for id in Original.Art.FREYJA_TRIAL_IDS:
  if mixed_views_only and id not in [11008,11009]:continue
  if party_views_only and id not in [11006,11008,11009,11500]:continue
  print("FREYJA_TRIAL_VISIT ",id)
  await visit(id)
  check(East.owns_model(game.model),"One existing East native owner "+str(id))
  check(game.model.waves.patrol_posts.is_empty(),"No generic regional patrol pool "+str(id))
  var actors=Population.server_events(id).actors.values().filter(func(actor):return int(actor.source)==id)
  var enrolled=game.explorer_npcs.actors.filter(func(entry):return entry.record.id.begins_with("source:"))
  check(enrolled.size()==actors.size(),"Exact single-owner original NPC roster "+str(id))
  if not party_views_only:
   for actor in actors:await interact_source(actor.id)
  var cell=clear_cell(id,candidate_cells(id))
  if not party_views_only:await take_view("map-"+str(id),cell)
  var zones=East.data().zones.filter(func(zone):return int(zone.map)==id)
  for zone in zones:
   for choice in zone.groups:
    if mixed_views_only and choice[0]not in ["trial:5001","trial:5002"]:continue
    if groups.has(choice[0]):continue
    groups[choice[0]]=true;await direct_group(id,cell,choice[0],zone)
  trial_report.maps.append({"id":id,"npcs":actors.map(func(a):return a.id),"zones":zones.map(func(z):return z.id)})
 if not party_views_only:await trial_ports()
 for id in flags:Original.Art.data().maps[Original.path_for(id)].sokia_visual_only=flags[id]
 check(JSON.stringify(get_meta("falan_venture"))==saved,"User adventure is preserved")
 check(groups.size()==(2 if mixed_views_only else 4),"Every requested source group directly exercised")
 trial_report.checks=checks;trial_report.failures=errors;trial_report.actors=npc_report.actors;trial_report.captures=server_report.captures
 trial_report.qualification="Review-only temporary fixture access; source rates, formation, AI and gated job/item rules are separate. No natural rare-spawn grinding or item grants. Images require visual judgment."
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var file=FileAccess.open(TRIAL_OUT+("mixed-camera-review.json"if mixed_views_only else"party-camera-review.json"if party_views_only else"integration-"+mode+".json"),FileAccess.WRITE);file.store_string(JSON.stringify(trial_report,"  ")+"\n");file.close()
 print("FREYJA_TRIAL_RESULT checks=",checks," failures=",errors," groups=",groups.size()," ports=",trial_report.ports.size()," actors=",npc_report.actors.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
