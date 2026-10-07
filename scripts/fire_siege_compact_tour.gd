extends "res://scripts/fire_siege_controls_tests.gd"

func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.player.smoke_mode=true
 game.selected_rogue_id=9;game.start_mode("defense");await frames(4)
 game.encounters.choose_card("supply_cache")
 game.camera_rig.set_process(false)
 var camera=game.camera_rig.camera
 camera.global_position=Vector3(120,170,345);camera.look_at(Vector3(0,0,215))
 game.toast("COMPACT FIRE SIEGE · Two walls · No enemy drops")
 await frames(360)
 game.camera_rig.set_process(true)
 game.reset_player_at(Vector3(0,.1,155));game.camera_rig.yaw=0
 game.camera_rig.pitch=.38;game.camera_rig.distance=12;game.camera_rig.reset_follow()
 await frames(100)
 press("heavy_attack")
 var blocked=0;var cpu_samples=[]
 for frame in range(840):
  game.player.smoke_move=Vector2(.25 if (frame/120)%2==0 else -.25,0)
  if frame==300:tap("surge")
  await frames(1)
  if game.player.active_ability.hit_stop>0:blocked+=1
  if frame>120:cpu_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
 press("heavy_attack",false);game.player.smoke_move=Vector2.ZERO
 cpu_samples.sort()
 print("COMPACT_TOUR live_enemies=",game.active_enemy_count()," kills=",game.kills," caster_stop_frames=",blocked," physics_p95_ms=",cpu_samples[int(cpu_samples.size()*.95)]," pickups=",get_tree().get_nodes_in_group("energy_pickups").size())
 game.camera_rig.yaw=PI;await frames(150)
 game.show_pause();await frames(90)
 get_tree().quit()
