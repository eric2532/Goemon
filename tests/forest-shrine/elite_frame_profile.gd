extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Rendered diagnostic: protected health retains all 240 enemies and five pets.
class Field extends "res://scripts/forest/forest_game.gd":
 func _sync_camera_mouse(_force:bool=false)->bool:return false
class FrameClock extends Node:
 var physics_end=0
 var engine_physics_us=0
 var idle_started=0
 var idle_us=0
 var render_started=0
 var render_us=0
 var started=0
 var first_physics_delay_us=0
 func _ready():
  process_priority=1000000;process_physics_priority=1000000
  get_tree().physics_frame.connect(physics_begin)
  get_tree().process_frame.connect(idle_begin)
  RenderingServer.frame_pre_draw.connect(func():render_started=Time.get_ticks_usec())
  RenderingServer.frame_post_draw.connect(func():render_us=Time.get_ticks_usec()-render_started)
 func physics_begin():
  var now=Time.get_ticks_usec()
  if physics_end>0:engine_physics_us+=now-physics_end
  if first_physics_delay_us==0:first_physics_delay_us=now-started
 func _physics_process(_delta):physics_end=Time.get_ticks_usec()
 func idle_begin():
  idle_started=Time.get_ticks_usec()
  if physics_end>0:engine_physics_us+=idle_started-physics_end;physics_end=0
 func _process(_delta):idle_us=Time.get_ticks_usec()-idle_started
const Metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const OUT="res://build/Other Files/Asset Toolkit/Elite Performance/"

func run():
 var duration=25.0;var label_="rendered"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--seconds="):duration=float(arg.trim_prefix("--seconds="))
  if arg.begins_with("--label="):label_=arg.trim_prefix("--label=")
 assert(duration>=25 and duration<=900 and label_.is_valid_filename())
 create_timer(duration+180).timeout.connect(func():printerr("ELITE_FRAME_TIMEOUT");quit(1))
 if DisplayServer.get_name()=="headless":printerr("Requires desktop rendering");quit(2);return
 root.size=Vector2i(1280,800);root.title="Cross Gate · Elite group frame profile"
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
 DisplayServer.window_move_to_foreground();root.grab_focus()
 set_meta("forest_custom_layout",Tour.Regions.layout("north_coast"))
 set_meta("forest_fighter",34);set_meta("forest_painterly_preview",true)
 if "--inline" in OS.get_cmdline_user_args():set_meta("forest_army_worker",false)
 game=Field.new();game.settings_path=cfg;root.add_child(game);current_scene=game
 game.set_physics_process(false);game.player.set_physics_process(false)
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 game.camera_rig.set_process(false);root.gui_disable_input=true
 var army=game.army_runtime;army.profile_enabled=true
 army.native.simulation_profile(true)
 if not game.combat_warmup.complete:await game.combat_warmup.finished
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true
 game.settings.forest_pet_loadout=Pets.sanitized([Pets.key(0),Pets.key(21),Pets.key(41),Pets.key(61),Pets.key(81)])
 var started=Time.get_ticks_usec();game.start_wave()
 var waves=game.model.waves;waves.spawn_clock=0
 for i in waves.patrol_posts.size()+1:waves.tick_outer_road(1,Vector3(0,0,10000))
 var elites=game.model.enemies.values().filter(func(row):return row.get("elite",false))
 check(game.model.enemies.size()==240 and elites.size()>0,"Full outdoor population includes complete elite parties")
 if elites.is_empty():quit(1);return
 for row:Dictionary in game.model.enemies.values():row.hp=1000000;row.max_hp=row.hp
 army.import_arrivals();army.sync_compatibility()
 var leader:Dictionary=elites[0];var center:Vector3=leader.pos
 var clear_patch=false
 for x in range(-240,241,24):
  for z in range(-240,241,24):
   var point=game.model.world_point(Vector2(x,z))
   if army.native.ally_ground_clear(point,24):center=point;clear_patch=true;break
  if clear_patch:break
 check(clear_patch,"The elite party fights in an actual open part of the map")
 army.set_pose(army.handles[leader.id],center,PI);army.native.set_guard(army.handles[leader.id],center,14)
 var spacing=maxf(1.0,(leader.footprint*army.pet_geometry[preload("res://scripts/forest/crowd/pet_dimensions.gd").offset(20,leader.skin)+6]*3.0+1.0)/7.0)
 for row:Dictionary in game.model.enemies.values():
  if row.get("elite_leader",0)!=leader.id:continue
  var offset:Vector3=waves.Formation.POSTS[row.escort_slot]
  var point=center+Vector3(-offset.x,0,offset.z)*spacing
  point.y=game.model.world_height(point.x,point.z);army.set_pose(army.handles[row.id],point,PI)
 game.player.position=center+Vector3.BACK*20
 game.player.position.y=game.model.world_height(game.player.position.x,game.player.position.z)+.05
 game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
 army.queue_hounds()
 for i in 3:army.import_hounds()
 var pet_count=0
 for pet in game.settings.forest_pet_loadout:
  var handle:int=army.handles.get(army.HOUND_ID-Pets.skin(pet),0)
  if handle!=0:pet_count+=1;check(army.native.set_pet_growth(handle,1000000,0),"Protect the diagnostic pet population")
 check(pet_count==5,"Five selected pet families are present")
 army.order_hounds(army.HoundOrder.ATTACK,army.handles[leader.id])
 army.record_events=true
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=center+Vector3(12,16,30);camera.look_at(center+Vector3.UP*2);camera.reset_physics_interpolation()
 var setup_ms=(Time.get_ticks_usec()-started)*.001
 var preparation:Dictionary=army.native.simulation_profile(true)
 army.profile_totals.clear()
 var viewport=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(viewport,true)
 var samples=[];var intervals=[];var steady=[];var focused_frames=0
 var steady_cpu={}
 var resources=[];var minimum=240;var minimum_pets=5;var next_resource=0.0
 var native={};var contacts=0;var replies=0;var pet_hits={};var activity=[];var bucket_pets=0;var bucket_enemies=0
 var focus_holds=[];var focus_wait_us=0
 var pipeline_monitors={}
 for name_ in ClassDB.class_get_integer_constant_list("Performance"):
  if "PIPELINE_COMPILATIONS" in name_:pipeline_monitors[name_]=ClassDB.class_get_integer_constant("Performance",name_)
 var initial_sim:float=army.simulation_seconds
 var frame_clock=FrameClock.new();root.add_child(frame_clock)
 game.set_physics_process(true);game.player.set_physics_process(true)
 started=Time.get_ticks_usec();var previous=started
 frame_clock.started=started
 while true:
  army.profile_totals.clear();await process_frame
  var now=Time.get_ticks_usec();var seconds=(now-started)*.000001
  if not DisplayServer.window_is_focused():
   var hold_at=previous;var ready_at=0
   game.paused=true;paused=true
   DisplayServer.window_move_to_foreground();root.grab_focus()
   while true:
    await process_frame;now=Time.get_ticks_usec()
    if not DisplayServer.window_is_focused():ready_at=0
    elif ready_at==0:ready_at=now
    if ready_at>0 and now-ready_at>=3000000:break
    if now-hold_at>120000000:printerr("ELITE_FRAME_FOCUS_TIMEOUT");quit(2);return
   var held=now-hold_at;focus_wait_us+=held;focus_holds.append(held*.000001)
   started+=held;previous=now;frame_clock.engine_physics_us=0
   army.native.simulation_profile(true);game.paused=false;paused=false
   print("ELITE_FRAME_FOCUS_RESUME wait_seconds=",held*.000001)
   continue
  minimum=mini(minimum,game.model.enemies.size())
  var kernel:Dictionary=army.native.simulation_profile(true)
  for key in kernel:
   if key!="enabled":native[key]=native.get(key,0)+kernel[key]
  var ms=(now-previous)*.001
  var focused=DisplayServer.window_is_focused();focused_frames+=int(focused)
  intervals.append(ms)
  if seconds>=5:
   steady.append(ms)
   for phase in ["game_army_total","compatibility_facades","presentation","presentation_tick","renderer_projectiles","renderer_uploads"]:
    steady_cpu[phase]=float(steady_cpu.get(phase,0.0))+float(army.profile_totals.get(phase,0.0))
  if ms>=25 or seconds<1:
   var sample={"seconds":seconds,"ms":ms,"focused":focused}
   sample.merge({"phases":army.profile_totals.duplicate(),"native":kernel,"idle_ms":frame_clock.idle_us*.001,"engine_physics_ms":frame_clock.engine_physics_us*.001,"render_submit_ms":frame_clock.render_us*.001,"first_physics_delay_ms":frame_clock.first_physics_delay_us*.001,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"render_setup_ms":RenderingServer.get_frame_setup_time_cpu(),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport)})
   sample.pipelines={}
   for key in pipeline_monitors:sample.pipelines[key]=Performance.get_monitor(pipeline_monitors[key])
   samples.append(sample)
  for event:Dictionary in army.event_log:
   if event.kind=="damage":
    if event.source_id<0:contacts+=1;bucket_pets+=1;pet_hits[event.source_id]=int(pet_hits.get(event.source_id,0))+1
    else:replies+=1;bucket_enemies+=1
  army.event_log.clear()
  previous=now
  frame_clock.engine_physics_us=0
  if seconds>=next_resource:
   var living_pets=0
   for pet in game.settings.forest_pet_loadout:
    if army.valid(army.handles.get(army.HOUND_ID-Pets.skin(pet),0)):living_pets+=1
   minimum_pets=mini(minimum_pets,living_pets)
   var pipelines={}
   for key in pipeline_monitors:pipelines[key]=Performance.get_monitor(pipeline_monitors[key])
   resources.append([seconds,get_node_count(),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),OS.get_static_memory_usage(),pipelines])
   activity.append({"seconds":seconds,"pet_contacts":bucket_pets,"enemy_contacts":bucket_enemies});bucket_pets=0;bucket_enemies=0;next_resource+=5
   if int(next_resource)%30==5:print("ELITE_FRAME_PROGRESS seconds=",snappedf(seconds,.1)," enemies=",minimum," pets=",minimum_pets," contacts=",contacts," replies=",replies," memory=",OS.get_static_memory_usage())
  if seconds>=duration:break
 game.set_physics_process(false);game.player.set_physics_process(false)
 check(minimum==240,"All 240 enemies remain active throughout the rendered diagnostic")
 check(minimum_pets==5 and pet_hits.size()==5,"All five pets stay alive and contribute actual contacts")
 check(contacts>0 and replies>0,"Pets and world enemies exchange real contacts")
 check(native.nav_topology_builds==0,"Rendered elite combat needs no cold routing grids")
 check(resources.back()[4].PIPELINE_COMPILATIONS_DRAW==resources.front()[4].PIPELINE_COMPILATIONS_DRAW,"Combat needs no first-use 3D draw pipeline builds")
 var report={"seed":game.model.seed_value,"enemies":minimum,"elites":elites.size(),"pets":minimum_pets,"diagnostic_health":true,"worker":army.worker_enabled,"worker_jobs":army.worker_jobs,"setup_ms":setup_ms,"preparation":preparation,"cold":Metrics.summary(intervals),"steady":Metrics.summary(steady),"native":native,"simulation_seconds":army.simulation_seconds-initial_sim,"measurement_seconds":(previous-started)*.000001,"focus_wait_seconds":focus_wait_us*.000001,"focus_holds":focus_holds,"pet_contacts":contacts,"enemy_contacts":replies,"pet_hits":pet_hits,"activity":activity,"resources":resources,"frame_ms":intervals,"focus_fraction":float(focused_frames)/maxi(1,intervals.size()),"samples":samples}
 check(focused_frames==intervals.size(),"The rendered profile stays in the foreground")
 for phase in steady_cpu:steady_cpu[phase]/=maxi(1,steady.size())
 report.steady_cpu_ms_per_frame=steady_cpu
 check(report.steady.p95_ms<=25 and report.steady.p99_ms<=50 and 1000.0/report.steady.mean_ms>=55,"Sustained frames meet the existing 55 FPS / 25 ms p95 / 50 ms p99 budget")
 if duration>=120:
  var settled=resources.filter(func(row):return row[0]>=60)
  for column in [1,2,3]:
   var values=settled.map(func(row):return row[column])
   check(values.max()-values.min()<=[32,4,33554432][column-1],"Post-warmup nodes/resources/memory remain bounded: %d"%column)
  for first in range(1,activity.size(),6):
   var pet_sum=0;var enemy_sum=0
   for bucket in activity.slice(first,mini(first+6,activity.size())):pet_sum+=bucket.pet_contacts;enemy_sum+=bucket.enemy_contacts
   check(pet_sum>0 and enemy_sum>0,"Every measured combat interval contains pet hits and enemy retaliation")
 var loot=game.exploration_loot
 var chests_before=loot.slots.filter(func(slot):return slot.active and slot.chest).size()
 var draw_before=Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
 var reward_frames=[];var reward_started=Time.get_ticks_usec();var reward_previous=reward_started
 army.apply_hit(army.handles[leader.id],{"amount":2000000.0,"magical":true,"source_id":army.HOUND_ID})
 for i in 90:
  await process_frame
  var now=Time.get_ticks_usec();reward_frames.append((now-reward_previous)*.001);reward_previous=now
 report.elite_reward={"frames":Metrics.summary(reward_frames),"draw_pipeline_builds":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)-draw_before}
 check(loot.slots.filter(func(slot):return slot.active and slot.chest).size()==chests_before+1,"The real elite kill still guarantees its chest")
 DirAccess.make_dir_recursive_absolute(OUT)
 FileAccess.open(OUT+label_+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Captured the rendered five-pet elite fight")
 check(game.save_pet_loadout([Pets.key(82)]),"Changing the pet selection prepares its routes before summoning")
 var body=preload("res://scripts/forest/crowd/pet_dimensions.gd").companion_body(82)
 army.native.simulation_profile(true)
 check(army.native.prepare_routes(PackedFloat32Array([Vector2(body.size.x,body.size.z).length()*.5]),1),"The new pet uses its exact body radius")
 check(army.native.simulation_profile(false).nav_topology_builds==0,"The pet picker already prepared the new companion grid")
 print("ELITE_FRAME_RESULT failures=",failures," cold=",report.cold," steady=",report.steady," topology_builds=",native.nav_topology_builds," pet_contacts=",contacts," enemy_contacts=",replies)
 frame_clock.queue_free();game.queue_free();current_scene=null;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
