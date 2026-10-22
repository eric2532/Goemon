extends SceneTree
var game
var checks=0
var failures=0
var cfg="user://boss-bars-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func frames(n=3):
	for i in n:await process_frame
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
	game.start_wave();game.set_physics_process(false);game.player.set_physics_process(false);game.model.waves.spawn_clock=100000
	for kind in 5:game.model.waves.spawn_enemy(kind,Vector3((kind-2)*18,0,90))
	game.sync_enemies()
	for actor in game.actors.values():
		actor.set_physics_process(false);actor._physics_process(0)
		check(actor.bar.visible==(actor.variant==4),"Only the boss starts with a visible health bar (role %d)"%actor.variant)
	var boss=game.actors.values().filter(func(a):return a.variant==4)[0]
	check(boss.bar.global_position.y-boss.global_position.y>11 and boss.bar.mesh.size.x>=7,"The boss bar sits clearly above the large block")
	boss.take_hit(18000,Vector3.RIGHT,false,{"tower":true,"tower_feedback":false})
	check(boss.bar.visible and is_equal_approx(boss.bar.scale.x,.75),"Direct damage immediately updates the visible bar to75 percent")
	var label_=boss.find_child("BossHealthText",true,false)
	check(label_!=null,"The boss bar also shows numeric health")
	if label_!=null:check("54000" in label_.text.replace(",","") and "72000" in label_.text.replace(",",""),"Numeric health shows current and maximum HP")
	var data=game.model.enemies[boss.forest_id];data.hp=36000;boss._physics_process(0)
	check(is_equal_approx(boss.bar.scale.x,.5) and boss.hp==36000,"Authoritative tower damage updates the same bar without double subtraction")
	for actor in game.actors.values():
		if actor.variant==4:continue
		actor.take_hit(1,Vector3.RIGHT,false,{"tower":true,"tower_feedback":false});actor._physics_process(0)
		check(not actor.bar.visible and actor.find_child("BossHealthText",true,false)==null,"Damaging an ordinary enemy never reveals a bar or HP text")
	game.model.visible_cells.clear();game.crowd._process(.016)
	check(not boss.bar.is_visible_in_tree(),"Boss health cannot reveal a fog-hidden boss")
	game.model.visible_cells[game.model.cell_of(boss.position)]=true;game.crowd._process(.016)
	check(boss.bar.is_visible_in_tree(),"Revealing the boss restores its current bar")
	boss.take_hit(40000,Vector3.RIGHT,true,{"tower":true,"tower_feedback":false})
	check(boss.dead and not boss.bar.visible and (label_==null or not label_.visible),"Defeat immediately hides the boss bar and numeric health")
	game.sound_library.cancel();game.music.stop()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
		for voice in game.find_children("*",kind,true,false):voice.stop()
	OS.delay_msec(120);game.queue_free();paused=false;await frames()
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("BOSS_HEALTH_BAR_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
