extends SceneTree
const GuardFixture=preload("res://tests/forest-shrine/guard_combat_fixture.gd")
var game
var checks=0
var failures=0
var cfg="user://boss-combat-%d.cfg"%OS.get_process_id()
var evidence="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/boss-shared-roster-20261018"
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):evidence=arg.trim_prefix("--capture-dir=")
	create_timer(90).timeout.connect(func():printerr("FAIL: boss combat timed out");quit(1))
	run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func frames(n=3):
	for i in n:await process_frame
func step_helpers(n:int):
	for i in n:
		for unit in game.explorer_helpers.pool:
			unit.set_physics_process(false)
			if unit.state!="idle":unit._physics_process(1.0/60);unit.active_ability.fx.tick(1.0/60)
		game.explorer_helpers._process(1.0/60)
		if i%30==0:await physics_frame
func capture(label_:String):
	if DisplayServer.get_name()=="headless":return
	for actor in game.actors.values():actor._sync_fitted_pose()
	RenderingServer.force_draw();await process_frame
	root.get_texture().get_image().save_png(evidence.path_join(label_+".png"))
func run():
	set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_four_gates.json")))
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
	AudioServer.set_bus_mute(0,true)
	game.start_wave();game.model.waves.spawn_clock=100000
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	for unit in game.gate_defenders.units.values():unit.set_physics_process(false)
	var m=game.model
	check(m.portals.size()==8 and m.waves.boss_pending.size()==8,"The real four-gate scene schedules all eight portal bosses")
	check(m.waves.spawn_one(),"The first portal releases a live boss")
	var boss=m.enemies.values()[0];game.sync_enemies();await frames()
	var actor=game.actors[boss.id];actor.set_physics_process(false);actor._physics_process(0)
	check(actor.variant==4 and actor.hp==72000 and actor.max_hp==72000,"The fifth role initializes a real actor with its full boss health")
	check(actor.model.get_child_count()==0 and not actor.boss,"The boss avoids both per-enemy artwork and the legacy single-boss victory shortcut")
	check(actor.fitted_shapes.size()==1 and actor.bar.visible,"One fitted boss block has its own visible health bar")
	var portal=m.portals[boss.portal_index];var forward=m.waves.routes.direction(portal)
	game.player.position=boss.pos+forward*6+Vector3.UP*.15
	game.player.max_hp=1000;game.player.hp=1000;game.player.invuln=0
	m.hero_position=game.player.position;m.update_vision(game.player.position)
	for x in range(-40,40):
		for z in range(-40,40):m.visible_cells[Vector2i(x,z)]=true
	var normal=m.waves.spawn_enemy(0,boss.pos+Vector3(-forward.z,0,forward.x)*11)
	game.sync_enemies()
	for a in game.actors.values():a.set_physics_process(false);a._physics_process(0)
	game.crowd._process(.016)
	check(game.crowd.primitive_batches[4].size()==1 and game.crowd.batches[4].multimesh.visible_instance_count==5,"The visible boss uses one shared box batch for its five cosmetic members")
	check(game.crowd.batches[4].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Bosses add no shadow cascades")
	game.camera_rig.camera.global_position=boss.pos+forward*30+Vector3.UP*21
	game.camera_rig.camera.look_at(boss.pos+Vector3.UP*4)
	game.forest_ui.sync();game.world.update_fog();await frames(5);await capture("boss-portal-and-raider")
	m.waves.choose_target(boss,game.player.position)
	check(boss.target_kind=="hero" and m.waves.in_reach(boss,"hero",0,game.player.position),"A nearby boss recognizes and reaches the player on its wall")
	m.waves.start_attack(boss,"hero",0,game.player.position)
	actor.take_hit(100,Vector3.RIGHT,true,{"tower":true,"tower_feedback":false})
	check(boss.hp==71900 and boss.stun==0 and boss.action=="windup" and boss.knockback==Vector3.ZERO,"A damaging heavy hit cannot repeatedly cancel a boss's committed strike")
	actor.combat_knockback(Vector3.RIGHT,20,.8);actor.apply_rogue_bash(Vector3.RIGHT)
	check(boss.knockback==Vector3.ZERO and boss.stun==0,"Explicit dash and bash impulses also respect boss poise")
	boss.action_left=.01;normal.stun=100;m.events.clear();game._physics_process(.02)
	check(game.player.hp==820 and boss.action=="recover","A real completed boss strike deals 180 damage through the live game event dispatcher")
	var helper=game.explorer_helpers
	check(GuardFixture.deploy(helper,3),"Goemon can summon the Knight helper against the boss")
	await step_helpers(15);m.waves.choose_target(boss,game.player.position)
	check(boss.target_kind=="defender" and boss.target_id==helper.active_units(3)[0].gate_id,"Knight's native Code taunts the boss using that ally's unique target identity")
	helper.clear();game.player.invuln=0
	var before:float=boss.hp
	var key=InputEventKey.new();key.physical_keycode=KEY_2;key.pressed=true;root.push_input(key,true);await frames(1)
	key.pressed=false;root.push_input(key,true)
	check(helper.active_units(1).size()==3,"A real2 key press from Goemon summons all three Rangers")
	await step_helpers(150)
	check(boss.hp<before and boss.hp>0,"Native helper arrows intersect and damage the large boss block")
	await capture("boss-with-shared-rangers")
	print("BOSS_COMBAT_METRICS ",JSON.stringify({"renderer":DisplayServer.get_name(),"boss_hp_after_rangers":boss.hp,"ranger_damage":before-boss.hp,"live_actors":game.actors.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
	helper.clear();actor.take_hit(boss.hp+1,Vector3.RIGHT,true,{"tower":true,"tower_feedback":false})
	m.waves.tick(.001,game.player.position)
	check(actor.dead and not m.enemies.has(boss.id) and m.phase=="wave" and not game.won,"Defeating one boss removes it without ending a wave that still has other enemies")
	await finish()
func finish():
	game.sound_library.cancel();game.music.stop()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
		for voice in game.find_children("*",kind,true,false):voice.stop()
	OS.delay_msec(120)
	game.queue_free();paused=false;await frames();await create_timer(.2).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("BOSS_COMBAT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
