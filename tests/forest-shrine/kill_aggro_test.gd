extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const OUT="res://build/Other Files/Asset Toolkit/Kill Aggro/"
const DT=1.0/60
var army
var home:Vector3
var guards=[]

func tick(count_:int):
 for i in count_:
  army.step(DT,{"targets":army.external_targets()})
  army.dispatch_events();army.sync_compatibility();army.presentation_delta+=DT;army.presentation_dirty=true;army.flush_presentation()
  if i%6==0:await frames(1)

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.crowd.present_army(army.render_snapshot(),[]);game.forest_ui.sync()
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Captured "+name_)

func run():
 create_timer(150).timeout.connect(func():printerr("KILL_AGGRO_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.player.select_character(preload("res://scripts/rogue_roster.gd").KAZI_ID)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.explorer_helpers.clear();game.settings.forest_pet_loadout=[];root.gui_disable_input=true
 game.model.waves.crossgate_pet_test=true;game.model.team_progression.cards_enabled=false
 army=game.army_runtime;army.clear();army.refresh_navigation(0)
 game.crowd.army.meshes[Roles.SLIME]=preload("res://scripts/forest/crowd/slime_sprites.gd").make_mesh()
 army.refresh_kits()
 home=Vector3(-120,0,125);home.y=game.model.surface_height(home.x,home.z)
 game.player.position=home;game.player.smoke_mode=false;game.tuning.invincible=true
 game.camera_rig.camera.global_position=home+Vector3(0,65,70);game.camera_rig.camera.look_at(home)
 var original_kills:int=game.kills
 check(game.model.aggro_kills==0 and army.external_targets().player_aggro_kills==0,"A fresh map has no kill awareness")
 for offset in [Vector3(-35,0,0),Vector3(0,0,-35),Vector3(35,0,0)]:
  var point:Vector3=home+offset;point.y=game.model.surface_height(point.x,point.z)
  check(army.native.can_reach(point,home,1.0),"The surrounding patrol has a real native route to the player")
  var h:int=army.spawn(97000+guards.size(),0,Roles.SLIME,point,100000,1.0)
  army.set_guard(h,point,20);guards.append(h)
 await tick(1)
 check(guards.all(func(h):return army.unit_state(h).external_kind<0),"Surrounding patrols at 35 meters remain idle before kills")
 await capture("before-kills")
 var began=Time.get_ticks_usec()
 for i in 12:
  var h:int=army.spawn(98000+i,0,0,home+Vector3(0,0,8),100,1.0)
  army.apply_hit(h,{"amount":1.0,"source_id":0})
  check(game.model.aggro_kills==i,"Nonlethal damage adds no awareness")
  army.apply_hit(h,{"amount":1000000.0,"source_id":0})
  army.dispatch_events();army.dispatch_events()
  check(game.model.aggro_kills==i+1 and army.external_targets().player_aggro_kills==i+1,"Each native death reaches the target snapshot exactly once")
 check(game.kills==original_kills+12,"The existing run kill total remains compatible")
 await tick(30)
 check(guards.all(func(h):return army.unit_state(h).external_kind==0),"Twelve kills alert all three surrounding patrols")
 var distances=[]
 for h in guards:distances.append(army.unit_state(h).position.distance_to(home))
 await tick(180)
 for i in guards.size():check(army.unit_state(guards[i]).position.distance_to(home)<distances[i]-1,"An alerted patrol actually moves toward the player")
 await capture("after-twelve-kills")
 var nodes:int=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources:int=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 3:
  game.respawn_left=1;await tick(20)
  check(guards.all(func(h):return army.unit_state(h).external_kind<0),"Untargetable player releases alerted patrols, cycle %d"%i)
  game.respawn_left=0;await tick(20)
  check(guards.all(func(h):return army.unit_state(h).external_kind==0),"Visible player reacquires nearby patrols, cycle %d"%i)
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated alert/release reuses warmed nodes and resources")
 var ally:int=army.spawn(-99000,1,11,home+Vector3(0,0,8),100,1.0)
 army.apply_hit(ally,{"amount":1000000.0});army.dispatch_events()
 var removed:int=army.spawn(99000,0,0,home+Vector3(0,0,8),100,1.0);army.despawn(removed)
 check(game.model.aggro_kills==12,"Allied deaths and cleanup despawns do not add awareness")
 var previous=game.model
 game.model=Model.new()
 check(army.external_targets().player_aggro_kills==0,"A newly loaded map does not inherit awareness from the previous visit")
 game.model=previous
 var reset_model=Model.new();reset_model.aggro_kills=12
 reset_model.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false)
 check(reset_model.aggro_kills==0,"Resetting an existing map clears its awareness")
 print("KILL_AGGRO_DIAGNOSTICS elapsed_ms=",(Time.get_ticks_usec()-began)/1000.0)
 army.clear();game.queue_free();current_scene=null;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("KILL_AGGRO_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
