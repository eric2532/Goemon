extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const OUT="res://build/Other Files/Player Crowd Approach/"
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const DT=1.0/60
var army
var home=Vector3(0,0,60)
var times=[]

func targets()->Dictionary:
 return {"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([home]),"hp":PackedFloat32Array([100000])}
func spawn_at(id:int,offset:Vector3)->int:
 var point=home+offset;point.y=game.model.world_height(point.x,point.z)
 return army.spawn(id,0,Roles.SLIME,point,100000,Roles.SLIME_RADIUS)
func pace(handle:int)->float:
 var v:Vector3=army.unit_state(handle).velocity
 return Vector2(v.x,v.z).length()
func tick(n:int):
 for i in n:
  var start=Time.get_ticks_usec();army.step(DT,{"targets":targets()});army.dispatch_events()
  game.crowd.army.presentation.tick(DT);game.crowd.present_army(army.render_snapshot(),army.presentation_events);army.presentation_events.clear();times.append(Time.get_ticks_usec()-start)
  if i%6==0:await frames(1)
func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.crowd.present_army(army.render_snapshot(),[])
 await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Captured "+label_)
func run():
 create_timer(180).timeout.connect(func():printerr("PLAYER_CROWD_APPROACH_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.settings.forest_pet_loadout=[]
 game.begin_arena();game.choose_rogue_character(preload("res://scripts/rogue_roster.gd").KAZI_ID);await frames(3)
 game.equipment_hub.enter_button.pressed.emit();await frames(3)
 game.clear_menu();game.forest_ui.hide();game.playing=true;game.paused=false;paused=false
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false);root.gui_disable_input=true
 army=game.army_runtime;army.clear();army.record_events=true
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;army.refresh_kits()
 check(game.model.terrain_detail==game.model.Arena.ID,"Fixture enters the playable Falan Arena")
 game.crowd.army.meshes[Roles.SLIME]=preload("res://scripts/forest/crowd/slime_sprites.gd").make_mesh()
 home.y=game.model.world_height(home.x,home.z)
 game.player.position=home;game.player.smoke_mode=true
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.camera.global_position=home+Vector3(40,72,80);game.camera_rig.camera.look_at(home+Vector3(0,0,-25))
 for cycle in 3:
  army.clear()
  var incoming=spawn_at(97000,Vector3(0,0,-125))
  await tick(2)
  var fast:float=pace(incoming)
  check(absf(fast-9)<.06,"Empty approach moves at 3x speed, cycle %d"%cycle)
  # A distant pursuit alone does not count as close pressure.
  var close=[]
  for i in 10:
   var angle=TAU*i/10;close.append(spawn_at(97001+i,Vector3(cos(angle)*22,0,sin(angle)*22)))
  await tick(3)
  check(absf(pace(incoming)-9)<.06,"Distant arrival stays fast with a close crowd")
  var normal=spawn_at(97100,Vector3(0,0,-36))
  await tick(3)
  var crowded:float=pace(normal)
  check(crowded>.9 and crowded<1.2,"New arrival slows to 35% near ten close pursuers")
  if cycle==0:await capture("crowded-slow-approach")
  for h in close:army.despawn(h)
  await tick(2)
  check(absf(pace(normal)-3)<.06,"Clearing close pursuers immediately restores the nearby pace")
  if cycle==0:await capture("cleared-faster-approach")
  # Actual enemy contact still delivers its prepared damage once the approach ends.
  army.clear();var attacker=spawn_at(97200,Vector3(0,0,4));army.set_pose(attacker,home+Vector3(0,0,4),0)
  await tick(150)
  var events=army.event_log.filter(func(e):return e.kind=="external_damage" and e.external_kind==0)
  var damage:float=game.model.waves.role_stats(Roles.SLIME).damage
  check(not events.is_empty() and events.all(func(e):return is_equal_approx(e.amount,damage)),"Nearby enemies still deliver exact native attack damage")
 var nodes=game.crowd.army.presentation.get_child_count();var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 10:await tick(60)
 check(game.crowd.army.presentation.get_child_count()==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources+2,"Repeated attacks retain prepared presentation nodes/resources")
 times.sort();print("PLAYER_CROWD_APPROACH_STEP_US p95=",times[int(times.size()*.95)]," max=",times[-1]," samples=",times.size())
 army.clear();game.queue_free();current_scene=null;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PLAYER_CROWD_APPROACH_GODOT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
