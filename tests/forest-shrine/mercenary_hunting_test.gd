extends "res://tests/forest-shrine/persistent_helpers_test.gd"
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000;freeze();game.set_process(false)
 var h=game.explorer_helpers;var unit=h.pool.filter(func(u):return u.kit_id==11)[0]
 var post=Vector3(-60,.12,60);unit.summon(null,post,0);unit.state="acting";unit.opening=false;freeze()
 var data=game.model.waves.spawn_enemy(0,Vector3(0,0,60));data.hp=1000000;data.max_hp=data.hp
 game.sync_enemies();await frames();freeze();var target=game.actors[data.id];target._sync_fitted_pose();target.boss=true
 check(h.closest_guard_target(unit)==target,"A mercenary finds an enemy beyond its old post radius")
 check(h.guard_target_allowed(unit,target),"A distant live enemy remains eligible during pursuit")
 unit.position=Vector3(-36,.12,60);unit.active_ability.player.pos=unit.position;unit.think()
 check(unit.ai_target==target and unit.ai_move.x>0,"Pursuit continues toward the enemy after leaving the old guard area")
 var before=unit.global_position
 await step(40)
 check(unit.global_position.x>before.x+.5,"The real movement controller follows the map-wide target")
 unit.state="returning";unit.shelter.tick(.1)
 check(unit.state=="acting","A healed mercenary resumes hunting without detouring to its old post")
 var next=game.model.waves.spawn_enemy(0,Vector3(24,0,60));game.sync_enemies();await frames();freeze()
 target.dead=true;target.hp=0;unit.think()
 check(unit.ai_target==game.actors[next.id],"A defeated target is replaced by another live enemy")
 game.model.phase="preparing";unit.rest_between_waves()
 check(unit.state=="prepared" and unit.guard_post==post and unit.position==post,"Preparation still returns survivors to their placement positions")
 await finish()
