extends SceneTree
## Regression cases for wrong landing-in-air selection, skipped run frames,
## missing double-jump reset, and mismatched sword/impact timing.
var checks=0
var failures=0
var game
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",label)
func frames(n: int):
	for i in n:await physics_frame
func run():
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://musashi-motion-test-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	await frames(5)
	game.begin_forest();game.choose_rogue_character(13);game.start_wave()
	game.tuning.freeze_ai=true;game.tuning.invincible=true
	await frames(10)
	var p=game.player
	p.set_physics_process(false)
	var m=p.model
	var c=p.active_ability
	# Below, explicit speed/ground flags inspect the imported body independent
	# of the source physics clock; native gait selection is checked separately.
	m.native_motion=false
	c.cancel();p.jumps_used=0
	m.animate(0,0,true,0,0,false,0,false)
	m.animate(12.17,0,true,0,0,false,0,false)
	m.animate(0,7,true,0,0,false,0,false)
	check(is_zero_approx(m.animation_player.current_animation_position),"Starting a run after idling begins at its first pose")
	var shoe=m.skeleton.find_bone("Part_11_shoe_a")
	var first=m.skeleton.get_bone_global_pose(shoe)
	m.animate(.13,7,true,0,0,false,0,false)
	check(not first.is_equal_approx(m.skeleton.get_bone_global_pose(shoe)),"Running actually moves the recovered feet")
	check("Table_07" in m.current_clip,"Normal movement uses the original run cycle")
	m.animate(0,2,true,0,0,false,0,false)
	check("Table_06" in m.current_clip,"Slow movement uses the original slow cycle")
	m.animate(0,14,true,0,0,false,0,false)
	check("Table_08" in m.current_clip,"Fast movement uses the original sprint cycle")
	m.animate(0,0,true,0,0,false,0,false)
	p.jumps_used=1;m.animate(.05,0,false,10,0,false,0,false)
	check("Table_13" in m.current_clip,"Stationary takeoff selects the standing jump")
	m.animate(.35,0,false,2,0,false,0,false)
	check("Table_13" in m.current_clip,"Rising jump holds its source pause pose instead of landing in midair")
	m.animate(.02,0,false,-1,0,false,0,false)
	check(m.current_clip=="Source__800d4ad4" and m.animation_player.current_animation_position<.04,"Descent begins with recovered post-pause motion")
	check(m.skeleton.get_bone_pose_scale(m.skeleton.find_bone("Part_25_weapon_attachment")).length()<.001 and m.skeleton.get_bone_pose_scale(m.skeleton.find_bone("Part_24_lumina_guard")).length()>1,"Resumed jump retains the source weapon visibility flags")
	m.animate(.24,0,false,-8,0,false,0,false)
	var falling=m.skeleton.get_bone_global_pose(shoe)
	p.jumps_used=2;m.animate(.01,7,false,11,0,false,0,false)
	check("800d4be0" in m.current_clip and not falling.is_equal_approx(m.skeleton.get_bone_global_pose(shoe)),"Double jump restarts with the original flip")
	m.animate(.30,7,false,4,0,false,0,false)
	check("Table_15" in m.current_clip,"After the flip the moving jump holds its airborne pose")
	m.animate(.01,7,false,-1,0,false,0,false)
	check(m.current_clip=="Source__800d4b70","Moving descent uses its own recovered continuation")
	p.jumps_used=0;m.animate(.01,0,true,0,0,false,0,false)
	check("Table_16" in m.current_clip and m.animation_player.current_animation_position<.04,"Moving jump landing starts only after floor contact")
	m.animate(.4,0,true,0,0,false,0,false)
	check("Table_00" in m.current_clip,"Landing recovery returns to idle")
	p.jumps_used=1;m.animate(.01,7,false,9,0,false,0,false)
	check("Table_15" in m.current_clip,"Running takeoff uses the moving jump")
	m.animate(.01,7,true,0,0,false,0,false)
	c.cancel()
	var expected=["Extra__800d4c94","Source__800d4ce4","Source__800d4d38"]
	var actual=[]
	for i in 3:
		c.primary_attack();actual.append(c.clip)
		if i>0:
			check(m.skeleton.get_bone_pose_scale(m.skeleton.find_bone("Part_25_weapon_attachment")).length()<.001 and m.skeleton.get_bone_pose_scale(m.skeleton.find_bone("Part_24_lumina_guard")).length()>1,"Fusion cut %d retains the sheathed Lumina geometry"%(i+1))
		c.tick(p.attack_duration+.01)
	check(actual==expected,"Ground sword combo retains the first three original Fusion cuts")
	c.cancel();c.start_attack(true)
	check(c.clip=="Extra__800d4f14","Ground Lumina selects the original sword initializer's clip")
	check(is_equal_approx(p.attack_duration,21.0/30.0),"Ground Lumina keeps its original 21-tick duration")
	c.cancel();p.position.y+=5;p.velocity=Vector3(7,8,0);p.move_and_slide()
	p.jumps_used=1;m.animate(.01,7,false,8,0,false,0,false)
	c.start_attack(false)
	check(c.clip=="Table_12__800d4ed4","Airborne light attack uses the moving air slash")
	c.cancel();c.start_attack(true)
	check(c.clip=="Extra__800d4f8c","Airborne Lumina uses its own original source entry")
	c.cancel()
	m.native_motion=true;c.locomotion.source_speed=-0x80000;m.animate(0,4.32,true,0,0,false,0,false)
	m.animate(.5,4.32,true,0,0,false,0,false) # Finish the preceding airborne test's landing.
	check(m.current_clip==m.RUN,"Native eight-unit run selects original table 7")
	c.locomotion.source_speed=-0xA0000;m.animate(.03,5.4,true,0,0,false,0,false)
	check(m.current_clip==m.SPRINT,"Native speed above 9.25 units selects original table 8 without Shift")
	c.locomotion.source_speed=-0x40000;m.animate(.03,2.16,true,0,0,false,0,false)
	check(m.current_clip==m.WALK,"Native cautious speed selects original table 6")
	print("MUSASHI_MOTION_RESULT checks=",checks," failures=",failures)
	paused=false;current_scene=null;game.queue_free();await process_frame;await process_frame
	await create_timer(.35).timeout
	quit(1 if failures else 0)
