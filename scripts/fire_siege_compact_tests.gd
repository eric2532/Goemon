extends "res://scripts/fire_siege_controls_tests.gd"

func run():
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director()
 game.encounters.choose_card("supply_cache");await frames(3)
 var world=game.world
 var stations={}
 for site in world.cannon_sites:stations[site.position.z]=true
 check(stations.size()==2 and game.encounters.tower_count()==8,"Fire Siege builds only two four-mount defense walls")
 check(world.base_position.distance_to(world.lanes[1][0])<=220,"Enemy entrance is within 220 metres of the base")
 check(world.playable_bounds.has_point(Vector2(world.spawn_point.x,world.spawn_point.z)),"Player spawns inside the shortened battlefield")
 game.drop_powerup(Vector3(0,.1,150));await frames(2)
 check(get_tree().get_nodes_in_group("energy_pickups").is_empty(),"Fire Siege creates no enemy collectible drops")
 game.orb_system.magnet_clock=0;await frames(2)
 check(get_tree().get_nodes_in_group("orb_magnets").is_empty(),"Drop-free Fire Siege does not spawn empty pickup magnets")
 var siege=game.encounters;siege.prep_left=0;siege.tick(0)
 var enemy=game.enemies.filter(func(e):return is_instance_valid(e) and not e.dead)[0]
 var money=siege.money;var kills=game.kills
 enemy.take_hit(1000000,Vector3.FORWARD,true)
 check(siege.money==money+12 and game.kills==kills+1 and get_tree().get_nodes_in_group("energy_pickups").is_empty(),"A real enemy defeat still grants gold and kill credit without loot")
 await clear_enemies()
 var p=game.player;p.select_character(9);p.active_ability.reset_run()
 game.reset_player_at(Vector3(0,.1,100));game.camera_rig.yaw=PI
 var victims=[]
 for i in range(18):victims.append(fixture(Vector3(0,0,4+i)))
 await frames(75) # Let startup cost leave Godot's one-second performance sample.
 var a=p.active_ability
 tap("heavy_attack");await frames(1)
 check(a.projectiles.size()==1 and a.projectiles[0].damage==79 and a.projectiles[0].pierce,"Magic wave retains native piercing damage")
 p.smoke_move=Vector2(1,0)
 var stopped=0;var cpu_peak=0.0
 for frame in range(132):
  await frames(1)
  if a.hit_stop>0:stopped+=1
  cpu_peak=maxf(cpu_peak,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
 p.smoke_move=Vector2.ZERO
 var damaged=victims.filter(func(e):return e.hp<10000).size()
 print("WAVE_METRICS stalled_frames=",stopped," remaining_projectiles=",a.projectiles.size()," targets_hit=",damaged," physics_peak_ms=",cpu_peak*1000)
 check(damaged==18,"One magic wave hits all eighteen enemies along its path")
 check(stopped==0,"Distant projectile contacts never freeze the caster's movement or animation")
 check(a.projectiles.is_empty(),"Crowd impacts do not extend a wave beyond its native travel lifetime")
 # Melee still has contact weight; do not remove hit-stop from all attacks.
 await fresh_class(6);fixture(Vector3(2,0,0));tap("light_attack")
 var melee_stop=false
 for frame in range(20):
  await frames(1)
  melee_stop=melee_stop or p.active_ability.hit_stop>0
 check(melee_stop,"Direct sword contact keeps its authored hit-stop")
 game.show_main_menu();game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 await frames(20)
 print("FIRE_SIEGE_COMPACT_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
