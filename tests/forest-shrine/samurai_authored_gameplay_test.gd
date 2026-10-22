extends "res://tests/forest-shrine/ninja_authored_gameplay_test.gd"
## Real Forest damage, authored contacts, fast trails, bow and cancellation.
func run():
 output="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Samurai integration"
 var map_doc=load("res://scripts/forest/forest_map_document.gd").new();map_doc.load_original();set_meta("forest_custom_layout",map_doc.data)
 config_path="user://samurai-authored-gameplay-%d.cfg"%OS.get_process_id()
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
 await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.tuning.invincible=true;game.tuning.critical_chance=0;game.character_tuning={}
 for stage in 5:
  await prepare(4)
  var c=game.player.active_ability;var e=target(Vector3(0,0,-2.4))
  if stage==0:c._animate(0,0);await shot("idle")
  c.combo=stage;c.combo_timer=1;c.action("cutlass");c.primary_held=false
  var attack: Dictionary=c.player.attack
  check(attack.index==stage,"Native combat selects katana strike %d"%[stage+1])
  c.tick(attack.contact-.001,false)
  check(e.hp==10000,"Strike %d does not damage before contact"%[stage+1])
  c.tick(.002,false);c._animate(.002,0)
  check(e.hp<10000,"Strike %d damages a real enemy at contact"%[stage+1])
  var motion=c.visual_actor.cosplay_rig.samurai_motion
  check(motion.last_clip=="combo" and absf(motion.last_frame-[12,30,48,66,87][stage])<.5,"Strike %d visible contact matches its Blender marker"%[stage+1])
  await shot("strike-%d"%[stage+1])
  for i in 120:c.tick(.005,false);c._animate(.005,0)
  check(c.player.attack==null,"One click finishes one strike without a backlog")
 await prepare(4)
 var c=game.player.active_ability
 c.action("flintlock");c.tick(.35,false)
 check(not c.projectiles.is_empty(),"Crimson energy arrow still fires after the katana redesign")
 await prepare(4);c=game.player.active_ability;c.action("cutlass");c.primary_held=false
 c.request_utility(true)
 check(c.player.attack==null and (c.player.roll>0 or c.player.invuln>0),"Dodge immediately cancels the authored katana attack")
 for quality in [0,1]:
  await prepare(4);c=game.player.active_ability;c.fx.apply_quality(quality)
  for i in 4:game.player.collect_powerup("attack_speed")
  c.action("drink");c.primary_held=true;c.action("cutlass")
  var visible={}
  for i in 100:
   c.tick(1.0/60);c._animate(1.0/60,0)
   for item in c.fx.items:
    if item.kind=="magic-brush" and is_instance_valid(item.node) and item.node.mesh.get_surface_count()>0:
     visible[item.get("cut_index",-1)]=true
  c.primary_held=false
  check(visible.size()==5,"All five accelerated strikes retain visible sword effects at quality %d"%quality)
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(3);await create_timer(.35).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("SAMURAI_AUTHORED_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
