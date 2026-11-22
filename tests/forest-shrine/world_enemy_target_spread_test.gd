extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUT="res://build/Other Files/World Enemy Target Spread/"
const DT=1.0/60

func run():
 create_timer(150).timeout.connect(func():printerr("WORLD_TARGET_SPREAD_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.player.select_character(preload("res://scripts/rogue_roster.gd").KAZI_ID)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.camera_rig.set_process(false);root.gui_disable_input=true
 var army=game.army_runtime;army.clear()
 game.model.waves.crossgate_pet_test=true
 game.crowd.army.meshes[Roles.SLIME]=preload("res://scripts/forest/crowd/slime_sprites.gd").make_mesh()
 army.refresh_kits()
 var home=Vector3(-120,0,125);home.y=game.model.surface_height(home.x,home.z)
 game.player.position=home+Vector3(80,0,0);game.player.position.y=game.model.surface_height(game.player.position.x,game.player.position.z)
 game.player.smoke_mode=true
 var enemies=[];var previous=[];var times=[];var nodes=0;var resources=0
 for i in 5:
  var point=home+Vector3((i-2)*8,0,7);point.y=game.model.surface_height(point.x,point.z)
  enemies.append(army.spawn(96000+i,0,Roles.SLIME,point,1000000,Roles.SLIME_RADIUS))
 for cycle in 3:
  var victims=[]
  for i in 5:
   var point=home+Vector3((i-2)*8,0,-3);point.y=game.model.surface_height(point.x,point.z)
   var h:int=army.spawn(-96000-cycle*5-i,1,Roles.GATEKEEPER_HOUND,point,1000000,Roles.footprint_radius(Roles.GATEKEEPER_HOUND))
   army.native.set_pet_skin(h,[0,21,41,61,81][i]);army.native.set_guard(h,point,0)
   victims.append(h)
  for h in previous:army.despawn(h)
  # Let an already committed strike finish before checking its replacement.
  for tick in 120:
   army.integration_tick(DT)
   if enemies.all(func(h):return army.unit_state(h).target_id<0):break
  var chosen={};var committed=[]
  for h in enemies:
   var id:int=army.unit_state(h).target_id;chosen[id]=true;committed.append(id)
  check(not chosen.has(0) and chosen.keys().all(func(id):return id<0) and chosen.size()>=3,"World slimes spread across nearby defenders after finishing their strikes, cycle %d"%cycle)
  for tick in 420:
   var start=Time.get_ticks_usec();army.integration_tick(DT);army.flush_presentation();times.append(Time.get_ticks_usec()-start)
   if tick%6==0:await frames(1)
  check(victims.filter(func(h):return army.unit_state(h).hp<1000000).size()>=3,"World enemies land real damage on different defenders, cycle %d"%cycle)
  check(range(enemies.size()).all(func(i):return army.unit_state(enemies[i]).target_id==committed[i]),"World enemies keep their living pursuits stable, cycle %d"%cycle)
  if cycle==0:
   nodes=game.crowd.army.presentation.get_child_count();resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
  previous=victims
 check(game.crowd.army.presentation.get_child_count()==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources+2,"Repeated world retargeting retains prepared nodes and resources")
 game.camera_rig.camera.global_position=home+Vector3(20,26,32);game.camera_rig.camera.look_at(home)
 game.crowd.present_army(army.render_snapshot(),[]);game.forest_ui.sync()
 if DisplayServer.get_name()!="headless":
  await frames(3);await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(OUT+"world-slimes-scattered-targets.png")==OK,"Captured world enemies attacking separate defenders")
 times.sort();print("WORLD_TARGET_SPREAD_STEP_US p95=",times[int(times.size()*.95)]," max=",times[-1]," samples=",times.size())
 army.clear();game.queue_free();current_scene=null;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("WORLD_TARGET_SPREAD_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
