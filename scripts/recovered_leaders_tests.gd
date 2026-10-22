extends SceneTree
## Real Forest controls and contacts, including cancellation at roster/focus boundaries.
var checks=0
var failures=0
var game
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func frames(n: int):
	for i in n:await physics_frame
func poses(model)->Array:
	var result=[]
	for i in model.skeleton.get_bone_count():result.append(model.skeleton.get_bone_pose(i))
	return result
func stop_audio(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
	for child in node.get_children():stop_audio(child)
func run():
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://leaders-test-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(5)
	check(game.player.ROSTER.has(14) and game.player.ROSTER.has(15),"Ed and Ben are separate selectable fighters")
	if failures:game.queue_free();await frames(2);quit(1);return
	game.begin_forest()
	check(game.find_child("RogueFighter_ed",true,false)!=null and game.find_child("RogueFighter_ben",true,false)!=null,"Gallery offers both original characters with controls")
	game.choose_rogue_character(14);game.start_wave();game.tuning.invincible=true;game.tuning.freeze_ai=true;game.tuning.critical_chance=0
	game.character_tuning={};await frames(15)
	var p=game.player;p.smoke_mode=true
	for id in [14,15]:
		p.select_character(id);p.hp=p.max_hp*.5
		check(p.character_id==id and game.selected_rogue_id==id,"Selecting fighter%d equips and remembers that fighter"%id)
		check(p.model.skeleton.get_bone_count()>=11 and p.model.animation_player.get_animation_list().size()>=6,"Fighter%d retains an animated original part rig"%id)
		var before=p.position;var rest=poses(p.model)
		p.smoke_move=Vector2(1,0);await frames(25)
		check(p.position.distance_to(before)>.5 and poses(p.model)!=rest,"Fighter%d runs with an animated body under real movement"%id)
		p.smoke_move=Vector2.ZERO;await frames(25)
		if id==14:
			rest=poses(p.model);p.jump_buffer=.15;await frames(8)
			check(p.jumps_used==1 and p.velocity.y>0 and poses(p.model)!=rest,"Fighter%d has a visible jump pose matching the physics impulse"%id)
			p.jump_buffer=.15;await frames(8)
			check(p.jumps_used==2,"Fighter%d retains responsive double jump"%id)
			await frames(65)
			check(p.is_on_floor() and not p.active_ability.is_attacking(),"Fighter%d returns to ground locomotion after landing"%id)
		if id==15:
			check(p.can_fly(),"Ben can use his original propeller without equipping a cloak")
			var height=p.position.y;Input.action_press("jump");await frames(20)
			check(p.flying and p.position.y>height+.5 and p.velocity.y>0,"Holding Space flies Ben upward with real collision physics")
			check(p.model.state=="fly","Ben flight displays a deployed propeller motion")
			Input.action_release("jump");await frames(20)
			check(p.velocity.y<0,"Releasing Space makes Ben descend")
			await frames(90)
			check(p.is_on_floor() and not p.flying,"Ben lands and retracts flight state on floor contact")
		p.set_physics_process(false);p.position=Vector3(0,.05,18);p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO
		p.facing=Vector3.FORWARD;p.model.rotation=Vector3.ZERO
		# Fit a known ordinary target; portal queues can now yield a huge boss
		# whose body encloses this deliberately close attack fixture.
		var target=game.model.waves.spawn_enemy(0,p.position+Vector3.FORWARD*1.5)
		target.pos=p.position+Vector3.FORWARD*1.5;target.hp=1000;target.max_hp=1000;target.stun=100
		game.model.update_vision(p.position);game.sync_enemies();var enemy=game.actors[target.id]
		var combat=p.active_ability;combat.cancel();combat.start_attack(false)
		check(combat.is_attacking() and enemy.hp==1000,"Fighter%d attack starts in windup before damage"%id)
		combat.tick(.01 if id==15 else .04);check(enemy.hp==1000,"Fighter%d cannot damage before its first native contact update"%id)
		combat.tick(.65)
		check(enemy.hp<1000,"Fighter%d primary attack damages a real fitted enemy at contact"%id)
		combat.cancel();combat.start_attack(true);combat.tick(1.8 if id==15 else .65)
		check(get_nodes_in_group("leader_projectiles").size()>0,"Fighter%d secondary releases a visible original-style projectile"%id)
		combat.cancel();var event=InputEventAction.new();event.action="light_attack";event.pressed=true;p._unhandled_input(event)
		check(combat.primary_held,"Fighter%d accepts held primary input"%id)
		combat._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(not combat.primary_held and not combat.is_attacking(),"Fighter%d focus loss clears held attacks"%id)
		var health_fraction=p.hp/p.max_hp
		combat.start_attack(false);p.select_character(1)
		check(not combat.active and not combat.primary_held and not combat.is_attacking(),"Fighter%d switching cancels pending attack and held input"%id)
		check(absf(p.hp/p.max_hp-health_fraction)<.001,"Switching from fighter%d preserves health percentage"%id)
		p.set_physics_process(true)
	check(p.character_models.has(2) and p.character_models.has(13),"Edo and Musashi remain separate original roster entries")
	var ally=load("res://scripts/forest/forest_gate_defender.gd").new();ally.game=game;game.add_child(ally)
	for id in [14,15]:
		ally.select_character(id);check(game.gate_defenders.primary_range(ally)>1.0,"Fighter%d also supports the gate-defender roster"%id)
	ally.queue_free();stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();await frames(3);game=null
	await create_timer(.35).timeout
	print("RECOVERED_LEADERS_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
