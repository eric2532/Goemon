extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUT="res://build/Other Files/Asset Toolkit/Crowd Attack Pressure/"
const DT=1.0/60
var army
var home=Vector3(0,0,60)
var supporters=[]
var fixed_positions=[]
var elapsed=0.0
var hits=[]
var times=[]

func targets()->Dictionary:
 return {"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([home]),"hp":PackedFloat32Array([100000])}
func spawn_at(id:int,offset:Vector3)->int:
 var point=home+offset;point.y=game.model.world_height(point.x,point.z)
 return army.spawn(id,0,Roles.SLIME,point,100000,Roles.SLIME_RADIUS)
func tick(count_:int):
 for i in count_:
  # Keep the comparison's supporting enemies at the same distance, without freezing their clocks.
  for j in supporters.size():army.set_pose(supporters[j],fixed_positions[j],0)
  var start=Time.get_ticks_usec();army.step(DT,{"targets":targets()});elapsed+=DT
  army.dispatch_events()
  for event in army.event_log:
   if event.kind=="external_damage" and event.source_id==98000 and event.external_kind==0:hits.append([elapsed,float(event.amount)])
  army.event_log.clear()
  army.latest=army.render_snapshot();army.presentation_delta+=DT;army.presentation_dirty=true;army.flush_presentation()
  times.append(Time.get_ticks_usec()-start)
  if i%6==0:await frames(1)
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.camera.global_position=home+Vector3(28,55,45);game.camera_rig.camera.look_at(home)
 game.crowd.present_army(army.render_snapshot(),[])
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Capture "+stem)
func encounter(count_:int):
 army.clear();supporters.clear();fixed_positions.clear();hits.clear();elapsed=0
 var attacker=spawn_at(98000,Vector3(0,0,36))
 for i in count_-1:
  var angle=TAU*i/maxi(1,count_-1);var handle=spawn_at(98001+i,Vector3(cos(angle)*10,0,sin(angle)*10))
  supporters.append(handle);fixed_positions.append(army.unit_state(handle).position)
 # Let new arrivals acquire the player before measuring their first committed swing.
 await tick(1);army.set_pose(attacker,home+Vector3(0,0,4),0);hits.clear();elapsed=0

func run():
 create_timer(240).timeout.connect(func():printerr("CROWD_ATTACK_PRESSURE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.settings.forest_pet_loadout=[]
 game.begin_arena();game.choose_rogue_character(preload("res://scripts/rogue_roster.gd").KAZI_ID);await frames(3)
 game.equipment_hub.enter_button.pressed.emit();await frames(3)
 game.clear_menu();game.forest_ui.hide();game.playing=true;game.paused=false;paused=false
 for node in [game,game.player,game.camera_rig,game.army_runtime]:node.set_process(false);node.set_physics_process(false)
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;game.tuning.invincible=true;game.music.stop()
 army=game.army_runtime;army.clear();army.record_events=true;army.refresh_kits()
 check(game.model.terrain_detail==game.model.Arena.ID,"Uses the playable Falan Arena")
 home.y=game.model.world_height(home.x,home.z);game.player.position=home;game.player.smoke_mode=false
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.camera.top_level=true;game.camera_rig.camera.global_position=home+Vector3(23,34,30)
 game.camera_rig.camera.look_at(home);game.camera_rig.camera.make_current();game.model.update_vision(home)
 var damage:float=game.model.waves.role_stats(Roles.SLIME).damage
 var base_interval=0.0;var base_contact=0.0
 for count_ in [1,3,4,6,8,14]:
  await encounter(count_);await tick(480)
  check(hits.size()>=3,"Repeated real native contacts with %d enemies"%count_)
  if hits.size()<3:continue
  var pressure=clampf(float(count_-3)/5,0,1);var interval=float(hits[2][0]-hits[1][0])
  var extra_pause=0.0 if count_<=3 else 1.0+.25*mini(count_-4,4)
  if count_==1:base_interval=interval;base_contact=hits[0][0]
  check(hits.all(func(hit):return absf(hit[1]-damage*(1+.5*pressure))<.001),"Exact crowd damage with %d enemies"%count_)
  check(absf(interval-base_interval-extra_pause)<DT*3,"Added recovery with %d enemies"%count_)
  check(absf(hits[0][0]-base_contact)<DT*2,"Original first-contact timing with %d enemies"%count_)
  print("CROWD_ATTACK_SAMPLE enemies=",count_," damage=",hits.map(func(hit):return hit[1])," interval=",interval," first_contact=",hits[0][0])
  if count_==8:
   await capture("eight-enemy-pressure")
   for handle in supporters:army.despawn(handle)
   supporters.clear();fixed_positions.clear();hits.clear();await tick(300)
   check(hits.size()>=3 and absf(hits[-1][1]-damage)<.001,"Clearing the crowd restores base damage")
   check(hits.size()>=3 and absf(hits[-1][0]-hits[-2][0]-base_interval)<DT*3,"Clearing the crowd restores base cadence")
 # Warm presentation before checking repeated simultaneous crowd combat.
 await encounter(8);supporters.clear();fixed_positions.clear();await tick(240)
 var presentation=game.crowd.army.presentation
 var nodes=presentation.get_child_count();var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for repeat_ in 4:await tick(240)
 check(presentation.get_child_count()==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources+2,"Simultaneous repeated combat retains prepared presentation nodes/resources")
 await capture("simultaneous-crowd-combat")
 times.sort();print("CROWD_ATTACK_STEP_US p95=",times[int(times.size()*.95)]," max=",times[-1]," samples=",times.size())
 print("CROWD_ATTACK_PRESSURE_RESULT checks=",checks," failures=",failures)
 army.clear();game.queue_free();current_scene=null;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
