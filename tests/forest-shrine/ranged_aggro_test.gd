extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Gear=preload("res://scripts/forest/equipment.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const OUT="res://build/Other Files/Asset Toolkit/Ranged Aggro/"
const DT=1.0/60
var shots=[]
var army
var home=Vector3(-120,0,125)

func tick(count_:int):
 for i in count_:
  army.step(DT,{"targets":army.external_targets()})
  army.dispatch_events();army.sync_compatibility()
  army.presentation_delta+=DT;army.presentation_dirty=true;army.flush_presentation()
  if i%6==0:await frames(1)

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.camera.top_level=true
 game.camera_rig.camera.global_position=home+Vector3(25,42,35)
 game.camera_rig.camera.look_at(home+Vector3(0,0,-22));game.camera_rig.camera.make_current()
 game.crowd.present_army(army.render_snapshot(),[])
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Capture "+stem)

func run():
 create_timer(240).timeout.connect(func():printerr("RANGED_AGGRO_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 for node in [game,game.player,game.camera_rig,game.army_runtime]:node.set_process(false);node.set_physics_process(false)
 game.settings.forest_pet_loadout=[];game.explorer_helpers.clear();game.model.waves.patrol_posts.clear()
 game.model.waves.crossgate_pet_test=true;game.model.team_progression.cards_enabled=false
 game.training_dummy.position=Vector3(0,-1000,0);game.tuning.invincible=true;game.music.stop()
 army=game.army_runtime;var p=game.player;var pool=Pool.service(game)
 pool.launched.connect(func(shot):shot.set_physics_process(false);shots.append(shot))
 home.y=game.model.surface_height(home.x,home.z)+.05
 game.camera_rig.camera.global_position=home+Vector3(15,65,70);game.camera_rig.camera.look_at(home+Vector3(0,0,-20))
 for route in [[37,"bow","crossgate_arrow"],[37,"kunai","water_dragon_dagger"],[37,"boomerang","crossgate_boomerang"],[36,"kunai","maze_dagger"]]:
  army.clear();game.model.enemies.clear();await frames(2)
  if route[0]==36:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE
  p.select_character(route[0])
  if route[0]==37:game.select_shin_skin(37,900050)
  check(game.save_equipment_loadouts({Gear.character_key(route[0]):{"1":"weapon:"+route[1]}},{},{}),"Equip "+route[2])
  p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.smoke_mode=false;p.attack_chain.reset()
  game.model.update_vision(home)
  p.active_ability.cancel(true);p.active_ability.clear_shin_counter()
  game.model.balance.enemy_profiles={str(Roles.SLIME):{"dodge_chance":0.0}};army.refresh_kits()
  # Remove defensive randomness so this checks a connected hit on every route.
  var point=home+Vector3(0,0,-45);point.y=game.model.surface_height(point.x,point.z)
  var row=game.model.waves.spawn_enemy(Roles.SLIME,point);row.hp=1000000;row.max_hp=row.hp
  army.import_arrivals();var enemy=army.enemy_target(row.id);army.set_guard(enemy.handle,point,30)
  army.native.set_boss_reactions(enemy.handle,0,0)
  check(army.native.can_reach(point,home,enemy.body_radius),"Real route to player "+route[2])
  await tick(1)
  check(army.unit_state(enemy.handle).external_kind<0,"Distant patrol starts unaware "+route[2])
  army.sync_targets();await physics_frame;await physics_frame
  shots.clear();var hp=enemy.hp
  p.active_ability.start_basic_attack(Vector3.FORWARD,enemy)
  p.active_ability.tick(float(p.model.normal_attack_pattern().duration)/p.attack_speed_multiplier()+.02)
  var count=int(p.model.fighter.get("kunai_count",1)) if p.model.daggers else 1
  check(shots.size()==count and shots.all(func(shot):return shot.kind==route[2]),"Actual attack releases "+route[2])
  if shots.is_empty():continue
  check(shots.all(func(shot):return shot.attack_ticket.get("projectile",false)),"Native hit is marked ranged "+route[2])
  for i in 240:
   for shot in shots:
    if shot.pool_live:shot._physics_process(DT)
  check(enemy.hp<hp,"Actual flight connects "+route[2])
  await capture(route[2]+"-hit")
  var start=enemy.global_position.distance_to(home)
  await tick(180)
  check(army.unit_state(enemy.handle).external_kind==0,"Hit enemy targets player "+route[2])
  check(enemy.global_position.distance_to(home)<start-2,"Hit enemy moves toward player "+route[2])
  print("RANGED_CHASE kind=",route[2]," before=",start," after=",enemy.global_position.distance_to(home))
  await capture(route[2]+"-chase")
  var created=pool.created;var misses=pool.misses
  for reuse in 3:
   p.active_ability.cancel(true);p.attack_chain.reset();shots.clear()
   p.active_ability.start_basic_attack(Vector3.FORWARD,enemy)
   p.active_ability.tick(float(p.model.normal_attack_pattern().duration)/p.attack_speed_multiplier()+.02)
   check(shots.size()==count and shots.all(func(shot):return shot.attack_ticket.get("projectile",false)),"Reused flight retains ranged attribution "+route[2])
   pool.release_owner(p)
  check(pool.created==created and pool.misses==misses,"Repeated attacks reuse prepared projectiles "+route[2])
  game.respawn_left=1;await tick(30)
  check(army.unit_state(enemy.handle).external_kind<0,"Untargetable player releases pursuit "+route[2]);game.respawn_left=0
 print("RANGED_AGGRO_RESULT checks=",checks," failures=",failures)
 army.clear();game.queue_free();current_scene=null;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
