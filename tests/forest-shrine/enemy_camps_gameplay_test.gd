extends "res://scripts/recovered_leaders_tests.gd"
func run():
	set_meta("forest_custom_layout",preload("res://scripts/forest/forest_camp_prototype.gd").layout())
	game=load("res://scenes/forest_shrine.tscn").instantiate()
	game.settings_path="user://camps-test-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(5)
	check(game.model.enemy_camps_prototype and game.enemy_objectives.size()==4,"Playable scene creates three camps and an enemy statue")
	check(game.world.portal_nodes.is_empty() and game.world.find_children("*Teleporter*","",true,false).is_empty(),"Prototype renders no Halo portals")
	check(game.enemies.size()==4 and game.model.enemies.is_empty(),"Structures are hittable without consuming the enemy cap")
	check(game.world.playable_bounds.has_point(Vector2(0,198)),"Enemy castle is inside player movement bounds")
	check(game.forest_ui.start_wave_button.text=="START","Prototype retains the current preparation start control")
	check(game.preparation_map_frame().overview and game.preparation_size==380,"Prototype opens with the complete camp layout in view")
	game.forest_ui.preparation_tools_open=true;game.forest_ui.sync()
	if "--capture" in OS.get_cmdline_user_args():await shot("overview")
	game.start_wave();game.model.waves.spawn_clock=10000;game.set_physics_process(false);game.player.set_physics_process(false);game.army_runtime.set_physics_process(false)
	game.tuning.critical_chance=0;game.character_tuning={}
	var target=game.enemy_objectives[0];var p=game.player
	p.position=target.position+Vector3(0,.1,10);p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
	game.model.update_vision(p.position);await frames(3)
	var hp=target.hp
	p.set_auto_attack(false);p.start_attack(false,1)
	for tick in 200:p._physics_process(1.0/60.0)
	check(target.hp<hp,"Goemon's actual pipe swing damages the camp through existing contact queries")
	p.cancel_charge(true);p.select_character(p.RogueRoster.MASTER_CHIEF_ID)
	var from=target.position+Vector3(0,2,30);var to=target.position+Vector3.UP*2
	var contact=p.master_chief_combat.trace(from,to)
	check(contact.target==target,"Chief's fitted bullet trace hits the camp ahead of physical masonry")
	hp=target.hp
	p.master_chief_combat.fire_bullets(from,Vector3.FORWARD,from,{"impact":false},p.attack_chain.begin("chief"),10,{"range":100.0},false)
	check(target.hp<hp,"Chief's actual bullet path damages the camp")
	check(game.army_runtime.enemy_candidates(target.position,20).has(target),"Bounded army queries include the static target")
	var row=game.model.waves.spawn_enemy(0,Vector3(0,0,80));game.sync_enemies();game.army_runtime.integration_tick(.01)
	check(game.army_runtime.enemies.size()==1,"Native runtime owns spawned soldiers alongside the four static structures")
	var nav=game.army_runtime.navigation_data(game.model)
	check(nav.obstacle_min.has(target.position+Vector3(-8.5,0,-8.5)),"Native movement sees live camp collision")
	target.take_hit(10000,Vector3.FORWARD,true,{"tower":true});await frames(2)
	check(target.dead and not game.enemies.has(target) and target.collision_layer==0 and not target.visual.visible and target.ruins.visible,"Destruction removes combat and movement collision and shows rubble")
	check(game.model.enemies.has(row.id),"Destroying a camp preserves its living soldiers")
	check(not game.army_runtime.navigation_data(game.model).obstacle_min.has(target.position+Vector3(-8.5,0,-8.5)),"Destroyed camp no longer blocks native movement")
	p.position=Vector3(0,.1,120);game.model.update_vision(p.position)
	game.camera_rig.set_process(false);game.camera_rig.camera.position=Vector3(75,90,75);game.camera_rig.camera.look_at(Vector3(0,0,155))
	if "--capture" in OS.get_cmdline_user_args():await shot("castle")
	for index in [1,2,3]:game.enemy_objectives[index].take_hit(10000,Vector3.FORWARD,true,{"tower":true})
	game.set_phase_view()
	check(game.model.phase=="victory" and game.won,"Real target destruction produces the castle victory screen")
	check(game.forest_ui.overlay!=null,"Victory UI opens")
	if "--capture" in OS.get_cmdline_user_args():await shot("victory")
	game.model.reset(42,{}, {},false);game.world.reload_map();game.army_runtime.reset_world();game.set_phase_view()
	check(game.enemy_objectives.is_empty() and game.enemies.is_empty() and game.model.waves.active_cap()==240,"Returning to a normal map clears prototype actors and restores normal wave policy")
	var config_path=game.settings_path
	stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();paused=false;await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("ENEMY_CAMPS_GAMEPLAY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
func shot(label_:String):
	await process_frame;await RenderingServer.frame_post_draw
	var folder="res://build/Other Files/Enemy Camps Prototype"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.get_texture().get_image().save_png(folder+"/"+label_+".png")
