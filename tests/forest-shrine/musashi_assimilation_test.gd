extends "res://scripts/recovered_goemon_gameplay_tests.gd"
var skill
var c
func verify_motion_library():
	var doc=GLTFDocument.new();var state=GLTFState.new()
	check(doc.append_from_file(ProjectSettings.globalize_path("res://build/Other Files/Asset Toolkit/Musashi Assimilation/motion.glb"),state)==OK,"Original recovery motion candidate imports")
	var original=doc.generate_scene(state,30,false,false);root.add_child(original)
	var player=original.find_child("AnimationPlayer",true,false);player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeleton=original.find_child("Skeleton3D",true,false)
	var actual=game.player.model.animation_player;var actual_skeleton=game.player.model.skeleton
	for name in skill.source.clips:
		var same=true
		for frame in int(skill.source.clips[name].ticks)+1:
			player.play("Assimilation_"+name);player.seek(frame/30.0,true);skeleton.force_update_all_bone_transforms()
			actual.play("assimilation/"+name);actual.seek(frame/30.0,true);actual_skeleton.force_update_all_bone_transforms()
			for bone in skeleton.get_bone_count():same=same and skeleton.get_bone_global_pose(bone).is_equal_approx(actual_skeleton.get_bone_global_pose(bone))
		check(same,"Every imported source frame matches the optimized gameplay rig: "+name)
	original.free();game.player.model.current_clip=""
func plant():
	c.cancel();game.player.position=ORIGIN
	for i in 3:game.player.velocity=Vector3.DOWN*20;game.player.move_and_slide()
	game.player.velocity=Vector3.ZERO
	game.player.facing=Vector3.FORWARD
	game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
func advance(count:int):
	for i in count:
		c.tick(1.0/30);skill.set_physics_process(false);skill._physics_process(1.0/30)
		game.player.model.animate(0,0,true,0,0,false,0,false)
func run():
	create_timer(90).timeout.connect(func():printerr("FAIL: Musashi skills timed out");quit(1))
	await setup_fixture()
	game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
	game.player.select_character(13);game.player.set_physics_process(false)
	c=game.player.active_ability;skill=c.assimilation;skill.set_physics_process(false)
	plant();check(game.player.is_on_floor(),"Skill fixture is physically grounded")
	for name in skill.source.clips:
		var clip="assimilation/"+name
		check(game.player.model.animation_player.has_animation(clip),"Original body stream imported: "+name)
		var animation=game.player.model.animation_player.get_animation(clip)
		check(animation.get_track_count()==93,"All31 body parts retain position, rotation and visibility: "+name)
		var resolved=true
		var animation_root=game.player.model.animation_player.get_node(game.player.model.animation_player.root_node)
		for track in animation.get_track_count():
			resolved=resolved and animation_root.get_node_or_null(NodePath(animation.track_get_path(track).get_concatenated_names()))!=null
		check(resolved,"Animation tracks resolve on the existing rigid rig: "+name)
	verify_motion_library()
	for slot in skill.SOUNDS.values()+["musashi_dkick_hit","musashi_fence_hit","musashi_homing_hit","musashi_grenade_hit"]:
		var sound=game.sound_preview(13,slot)
		check(sound!=null and sound.resource_path.begins_with("res://assets/audio/recovered_musashi/"),"Original audio resolves: "+slot)
	# Fence releases only at the original body event, once per cast.
	plant();var before=skill.releases;c.select_number(4);advance(1)
	check(skill.releases==before,"Fence windup cannot release early")
	advance(1);check(skill.releases==before+1,"Fence releases at source tick2")
	check(game.voices.any(func(v):return v.stream!=null and v.stream.resource_path.ends_with("fence_launch.wav")),"Fence launch plays the original0x8EF sample")
	advance(10);check(not c.is_attacking(),"Fence returns to ordinary movement after12ticks")
	check(skill.impacts>0,"A swept crescent hits the fitted practice target")
	# Throwing skills share the original12-pose body and tick5 release.
	for number in [5,6]:
		plant();before=skill.releases;c.select_number(number);advance(4)
		check(skill.releases==before,"Throw windup waits for tick5 (%d)"%number)
		advance(1);check(skill.releases==before+1,"Throw releases exactly once (%d)"%number)
		advance(7);check(not c.is_attacking(),"Throw completes (%d)"%number)
	advance(130)
	check(skill.active_count()==0,"Expired projectiles and explosion animations return to the pool")
	# Real native enemy damage, not a launch counter or a synthetic hit callback.
	game.training_dummy.position=ORIGIN+Vector3(20,0,0)
	var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-8));row.hp=10000;row.max_hp=10000
	game.sync_enemies()
	var enemy=game.actors[row.id];var hp=enemy.hp
	plant();c.select_number(5);advance(35)
	check(enemy.hp<hp,"Homing acquires and damages a real native army target")
	check(skill.shots.filter(func(s):return s.kind=="homing" and s.active).all(func(s):return s.target==null or is_instance_valid(s.target.get_ref())),"Rocket target references remain valid through impact")
	advance(40)
	# Floor contacts preserve both source bounces and the third-contact blast.
	plant();skill.release_shot("grenade")
	var bomb=skill.shots.filter(func(s):return s.kind=="grenade" and s.active)[0]
	for contact in 3:
		bomb.node.position=ORIGIN+Vector3(8,1,0);bomb.velocity=Vector3(0,-2,0)
		skill._shot_tick(bomb)
		check(bomb.bounces==maxi(0,1-contact),"Grenade consumes the original floor bounce allowance")
		check((bomb.blast<0 and bomb.velocity.y>0) if contact<2 else bomb.blast==0,"Grenade bounces twice, then detonates on floor contactthree")
	advance(20)
	# Moving a target after launch bends the already-live rocket's direction.
	plant();skill.release_shot("homing")
	var rocket=skill.shots.filter(func(s):return s.kind=="homing" and s.active)[0]
	var original:Vector3=rocket.velocity
	game.army_runtime.set_pose(enemy.handle,ORIGIN+Vector3(6,0,-8),0);enemy.sync(game.army_runtime.unit_state(enemy.handle))
	skill._shot_tick(rocket)
	check(rocket.velocity.x>original.x,"A live rocket steers toward its moving native target")
	for shot in skill.shots:if shot.active:skill._retire(shot)
	# Clear the native target before the sustained empty-range occupancy test.
	game.army_runtime.set_pose(enemy.handle,ORIGIN+Vector3(100,0,0),0);enemy.sync(game.army_runtime.unit_state(enemy.handle))
	# A real world collider blocks swept shots and prevents damage through walls.
	var wall=StaticBody3D.new();wall.collision_layer=1
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,8,1);collision.shape=box;wall.add_child(collision);game.add_child(wall);wall.position=ORIGIN+Vector3(0,3,-4)
	game.army_runtime.set_pose(enemy.handle,ORIGIN+Vector3(0,0,-8),0);enemy.sync(game.army_runtime.unit_state(enemy.handle))
	await physics_frame
	plant();hp=enemy.hp;c.select_number(7);advance(6);skill.held=false;advance(24)
	check(enemy.hp==hp and skill.active_count("three_way")==0,"Swept gunfire stops at the wall without damaging the enemy behind it")
	wall.free();game.army_runtime.set_pose(enemy.handle,ORIGIN+Vector3(100,0,0),0);enemy.sync(game.army_runtime.unit_state(enemy.handle))
	plant();c.select_number(6)
	var primary=InputEventAction.new();primary.action="light_attack";primary.pressed=true;c.input(primary)
	advance(12);check(c.mode=="fusion" and not c.queued_primary,"A queued sword cut follows the throwing animation without stale input")
	primary.pressed=false;c.release_input(primary);advance(40)
	plant()
	for i in 6:skill.release_shot("homing")
	c.select_number(5)
	check(skill.active_count("homing")==6 and not c.is_attacking(),"The original six-rocket limit rejects another cast without consuming its animation")
	for shot in skill.shots:if shot.active:skill._retire(shot)
	game.army_runtime.set_pose(enemy.handle,ORIGIN+Vector3(0,0,-8),0);enemy.sync(game.army_runtime.unit_state(enemy.handle))
	plant();hp=enemy.hp;c.select_number(5);advance(5)
	game.player.select_character(1);advance(30)
	check(enemy.hp<hp,"A released rocket retains damage after switching fighters")
	check(game.voices.any(func(v):return v.stream!=null and v.stream.resource_path.ends_with("homing_impact.wav")),"The in-flight rocket retains Musashi's original impact sound after switching fighters")
	game.player.select_character(13);game.army_runtime.set_pose(enemy.handle,ORIGIN+Vector3(100,0,0),0);enemy.sync(game.army_runtime.unit_state(enemy.handle))
	for shot in skill.shots:if shot.active:skill._retire(shot)
	# True held fire, not a single burst relabelled3-Way.
	game.training_dummy.position=ORIGIN+Vector3(20,0,0)
	plant();before=skill.releases;c.select_number(7);advance(6)
	check(skill.releases==before+3,"3-Way raises for4ticks then emits exactlythree shots")
	var spread=[]
	for shot in skill.shots:
		if shot.active and shot.kind=="three_way":spread.append(shot.velocity.normalized())
	check(spread.size()==3 and absf(spread[0].angle_to(spread[2])-2*0xAA*TAU/4096.0)<.0001,"Original±0xAA spread angles survive")
	advance(80);check(skill.releases>before+50,"Holding7 repeats the original firing loop")
	var release=InputEventKey.new();release.physical_keycode=KEY_7;release.pressed=false;c.release_input(release)
	advance(8);check(not c.is_attacking() and not skill.held,"Key release lowers the weapon and stops firing")
	advance(30);check(skill.active_count()==0,"Held-fire shots expire cleanly")
	# Repeated use cannot reconstruct nodes/materials or retain targets/tickets.
	var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for repeat in 8:
		plant();c.select_number(7);advance(45);skill.held=false;advance(35)
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes,"Repeated3-Way fire creates no extra scene nodes")
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated3-Way fire creates no extra resources")
	check(skill.shots.all(func(s):return not s.active and s.target==null and s.ticket.is_empty() and s.hits.is_empty()),"Pool reset clears targets, tickets and prior victims")
	# Movement follows the original upward kick arc and ends on floor contact.
	plant();c.select_number(3)
	check(c.controls_motion(),"D-Kick owns source motion")
	var rise=c.source_motion_tick();check(rise.y>0 and rise.dot(Vector3.FORWARD)>0,"D-Kick moves forward and upward")
	for i in 8:c.source_motion_tick()
	check(skill.kick_vertical>0,"Original gravity turns the kick downward")
	c.after_source_motion(true,false);check(not c.is_attacking(),"D-Kick lands without leaving movement locked")
	# Five-slot routing keeps Grenade and held 3-Way in reach.
	plant();var press=InputEventKey.new();press.physical_keycode=KEY_4;press.pressed=true;game.forest_ui._input(press)
	check(c.action_key=="grenade","Forest HUD routes key4 to Grenade")
	c.cancel();press.physical_keycode=KEY_5;game.forest_ui._input(press)
	check(skill.held and c.action_key=="three_way","Forest HUD routes key5 to held3-Way")
	press.pressed=false;game.forest_ui._input(press);check(not skill.held,"Forest HUD also routes key5 release")
	c.cancel();game.player.select_character(1);game.forest_ui.sync()
	check(game.forest_ui.loadout_buttons.size()==5,"Other fighters retain their existing five-slot layout")
	game.player.select_character(13);game.forest_ui.sync()
	check(game.forest_ui.loadout_buttons.all(func(b):return b.visible and not b.disabled),"All five Musashi actions are visible and selectable")
	check(game.forest_ui.cape_buttons[1].position.x>=336,"Five action tiles leave the existing gold cape control clear")
	game.queue_free();paused=false;await frames();await create_timer(.15).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("MUSASHI_ASSIMILATION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
