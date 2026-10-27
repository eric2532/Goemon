extends SceneTree
var checks=0
var failures=0
var game
var cfg="user://sonic-test-%d.cfg"%OS.get_process_id()
var home_point=Vector3(0,.1,110)
func _initialize():
	create_timer(240).timeout.connect(func():printerr("FAIL: Sonic gameplay timeout");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func frames(count:int=3):
	for i in count:await physics_frame
func capture(name:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Sonic/Movement/"+name+".png")
func press(action:String,down:bool=true):
	var event=InputEventAction.new();event.action=action;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
	root.add_child(game);current_scene=game;await frames()
	home_point.y=game.world.height_at(home_point.x,home_point.z)+.1
	var hero:Hero=game.player;hero.select_character(19)
	check(hero.character_id==19,"Sonic is selectable through the shared roster")
	game.start_wave();game.model.waves.spawn_clock=10000;game.tuning.invincible=true
	game.set_physics_process(false);hero.set_auto_attack(false)
	game.settings.spell_loadouts={}
	var platform=StaticBody3D.new();platform.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(80,1,80)
	platform.add_child(shape);game.add_child(platform);platform.position=home_point-Vector3.UP*.6
	hero.position=home_point;hero.velocity=Vector3.ZERO
	game.camera_rig.yaw=0;game.camera_rig.pitch=.36;game.camera_rig.reset_follow()
	await frames(8)
	var combat=hero.active_ability
	check(hero.is_on_floor(),"Sonic uses the shared CharacterBody floor collision")
	check(hero.model.animations.has_animation("Sonic Run"),"Retail motion survived the editable Blender export")
	check(is_equal_approx(hero.model.animations.get_animation("Sonic Run").length,32.0/60),"A source 32-tick loop keeps its full cycle duration")
	check(hero.model.ROOT=="res://assets/models/characters/sonic/" and hero.model.skeleton!=null,"Gameplay loads the scaled, welded Blender master export")
	check(not game.camera_rig.first_person_active(),"Sonic retains the existing third-person camera")
	await movement_checks(hero,combat)
	press("move_right");await frames(18);press("move_right",false)
	check(hero.position.x>home_point.x+1,"Source acceleration moves Sonic with ordinary controls")
	await frames(35)
	check(Vector2(hero.velocity.x,hero.velocity.z).length()<.05,"Releasing movement brakes to rest")
	press("jump");await frames(5)
	check(hero.position.y>home_point.y+.5 and hero.model.ball.visible,"Jump uses the original spin-ball model")
	check(not hero.model.animations.active and hero.model.ball_animation.active,"Only the visible Sonic model evaluates animation")
	await capture("jump")
	press("jump",false);await frames(70)
	check(hero.is_on_floor(),"Jump returns to the same floor")
	var nodes=combat.get_child_count();var resources_before=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for i in 8:
		hero.position=home_point;hero.velocity=Vector3.ZERO;await frames(3)
		press("heavy_attack");await frames(4)
		check(combat.mode=="charge","Spin Dash charges without rebuilding a character")
		if i==0:check(combat.blue_effect.aura.visible,"Charge displays the recovered blue effect")
		if i==0:await capture("charge")
		press("heavy_attack",false);await frames(2)
		check(combat.mode=="roll" and hero.velocity.length()>30,"Release launches Spin Dash")
		if i==0:await capture("spin-dash")
		press("dodge");press("dodge",false);await frames(2)
	check(combat.get_child_count()==nodes,"Repeated skills keep the same audio/effect nodes")
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<resources_before+12,"Repeated skills do not grow resource ownership")
	hero.position=home_point;hero.velocity=Vector3.ZERO;await frames(4)
	press("heavy_attack");await frames(3);combat.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(combat.mode=="idle" and not combat.charge_voice.playing,"Focus loss cancels held charge and sound")
	check(not combat.blue_effect.aura.visible and combat.blue_effect.trails.all(func(t):return not t.visible),"Focus loss clears every reused blue effect")
	press("heavy_attack",false)
	var data=game.model.waves.spawn_enemy(0,home_point+Vector3(0,0,-9));data.hp=10000;data.max_hp=10000;data.stun=100
	game.sync_enemies();game.model.update_vision(home_point);await frames(3)
	hero.facing=Vector3.FORWARD;game.camera_rig.update_camera(0)
	var before=data.hp
	press("jump");await frames(4);press("jump",false);press("jump");await frames(22);press("jump",false)
	check(data.hp<before,"Homing Attack damages the existing native army target")
	check(combat.hits.size()<=1,"One homing contact does not repeat damage every frame")
	hero.position=home_point;hero.velocity=Vector3.ZERO;combat.cancel();await frames(6)
	var wall=StaticBody3D.new();wall.collision_layer=1
	var wall_shape=CollisionShape3D.new();wall_shape.shape=BoxShape3D.new();wall_shape.shape.size=Vector3(12,12,.5)
	wall.add_child(wall_shape);game.add_child(wall);wall.position=home_point+Vector3(0,4,-4)
	await frames();before=data.hp
	hero.facing=Vector3.FORWARD;press("jump");await frames(4);press("jump",false);press("jump");await frames(24);press("jump",false)
	check(is_equal_approx(data.hp,before),"A wall blocks homing target selection and swept damage")
	wall.queue_free();combat.cancel()
	var castle=game.enemy_objectives[0]
	var basis_=preload("res://scripts/forest/forest_enemy_castle.gd").basis(castle.data())
	hero.position=castle.global_position+basis_*Vector3(-55,.2,0);hero.velocity=Vector3.ZERO;hero.facing=basis_*Vector3.RIGHT
	game.model.update_vision(hero.position);await frames(8)
	before=castle.hp;press("heavy_attack");await frames(8);press("heavy_attack",false);await frames(16)
	check(castle.hp==before and castle.sections.any(func(p):return p.hp<p.max_hp),"Spin Dash damages enemy wall panels through shared contacts while leaving the keep intact")
	combat.cancel();hero.select_character(1)
	hero.position=home_point;hero.velocity=Vector3.ZERO;await frames(8)
	var weapon=hero.weapon_slot
	hero.spell_loadout.equip(1,"equip","sonic/spin-dash")
	press("equip");await frames(5);press("equip",false);await frames(4)
	check(hero.spell_loadout.current!=null and hero.velocity.length()>30,"Goemon can equip and release Sonic's Spin Dash")
	check(hero.weapon_slot==weapon and hero.character_id==1,"Transferred skill preserves the wearer's weapon and character")
	check(hero.spell_loadout.current.controller.blue_effect.aura.visible,"Borrowed Spin Dash also carries the original blue effect")
	game.show_pause();await frames(2)
	check(hero.spell_loadout.current==null,"Pause cancels a transferred movement skill")
	game.resume();hero.spell_loadout.cancel()
	hero.spell_loadout.equip(1,"surge","sonic/homing")
	for i in 2:
		hero.position=home_point;hero.velocity=Vector3.ZERO;hero.facing=Vector3.FORWARD;await frames(6)
		press("jump");await frames(5);press("jump",false);press("surge");await frames(2);press("surge",false)
		check(hero.spell_loadout.current!=null and hero.spell_loadout.current.controller.mode=="homing","A borrowed Homing Attack rearms after landing")
		hero.spell_loadout.cancel();await frames(3)
	hero.select_character(19);await frames(3)
	check(not combat.is_attacking(),"Reselection never resumes an old charge or homing target")
	await borrowed_homing_checks(hero,combat)
	if DisplayServer.get_name()!="headless":
		hero.position=Vector3(0,game.world.height_at(0,70)+.2,70);hero.velocity=Vector3.ZERO;game.camera_rig.yaw=.4;game.camera_rig.pitch=.36
		game.camera_rig.follow=hero.position+Vector3.UP*1.4;game.camera_rig.travel_follow.reset(game.camera_rig.follow)
		await frames(60);await process_frame
		root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Sonic/gameplay.png")
		if "--profile" in OS.get_cmdline_user_args():await profile()
		if "--motion-profile" in OS.get_cmdline_user_args():await motion_profile()
	print("SONIC_GAMEPLAY_RESULT checks=%d failures=%d resources_before=%d after=%d"%[checks,failures,resources_before,Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	for action in ["move_right","jump","heavy_attack","equip","dodge"]:Input.action_release(action)
	game.queue_free();paused=false;await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	quit(1 if failures else 0)

func movement_checks(hero:Hero,combat):
	var motion=Vector3.ZERO
	hero.facing=Vector3.FORWARD
	for i in 60:motion=combat.accelerate(motion,Vector3.FORWARD,true,1)
	check(absf(motion.length()-36)<.001,"Retail acceleration reaches the 3-unit soft threshold in 60 ticks")
	for i in 540:motion=combat.accelerate(motion,Vector3.FORWARD,true,1)
	check(absf(motion.length()-53.635)<.04,"Running continues above the soft threshold with retail overspeed drag")
	var turning=combat.accelerate(Vector3.FORWARD*24,Vector3.RIGHT,true,1)
	check(absf(hero.facing.angle_to(Vector3.FORWARD)-PI/16)<.0001 and turning.z<0,"Fast turns are bounded to the source 0x800 angular step")
	hero.facing=Vector3.FORWARD
	var braking=combat.accelerate(Vector3.FORWARD*24,Vector3.BACK,true,1)
	check(combat.braking and absf(braking.length()-21.84)<.001,"Reversing input skids with the original brake force")
	hero.velocity=Vector3.UP
	var air=combat.accelerate(Vector3.FORWARD*72,Vector3.FORWARD,false,1)
	check(absf(air.length()-70.356)<.001,"An airborne Spin Dash keeps overspeed instead of snapping toward the running cap")
	hero.velocity=Vector3.ZERO;combat.cancel()
	var short_height=await jump_height(hero,2)
	var long_height=await jump_height(hero,60)
	check(long_height>short_height*1.8,"Holding jump adds the source lift; releasing creates a shorter arc without a velocity cut")
	print("SONIC_JUMP_HEIGHT short=",short_height," held=",long_height)
	hero.position=home_point;hero.velocity=Vector3.ZERO;await frames(6)
	press("heavy_attack");await frames(21)
	check(is_equal_approx(combat.charge,10),"Spin Dash reaches full retail charge in about 20 ticks")
	press("heavy_attack",false)
	check(absf(Vector2(hero.velocity.x,hero.velocity.z).length()-120)<.01,"Full charge releases at 10 source units per tick")
	await frames(2);press("jump");await frames(2);press("jump",false)
	check(hero.velocity.length()>100 and combat.mode=="jump","Jumping from Spin Dash preserves its momentum")
	combat.cancel();hero.position=home_point;hero.velocity=Vector3.ZERO;await frames(6)
	hero.facing=Vector3.BACK
	press("jump");await frames(3);press("jump",false);press("surge");press("surge",false)
	check(combat.target==null,"An empty forward cone produces the retail air dash")
	await frames(8)
	check(combat.mode=="fall" and not combat.spinning(),"A missed Homing Attack slows down and uncurls after six ticks")
	combat.cancel();hero.position=home_point;hero.velocity=Vector3.ZERO;await frames(8)

func jump_height(hero:Hero,hold:int)->float:
	hero.position=home_point;hero.velocity=Vector3.ZERO;await frames(6)
	press("jump")
	var peak=home_point.y
	for i in 180:
		await frames(1)
		peak=maxf(peak,hero.position.y)
		if i==hold:press("jump",false)
		if i>4 and hero.is_on_floor():break
	press("jump",false)
	return peak-home_point.y

func borrowed_homing_checks(hero:Hero,combat):
	hero.spell_loadout.equip(19,"surge","sonic/homing")
	hero.position=home_point;hero.velocity=Vector3.ZERO;hero.facing=Vector3.BACK;await frames(8)
	press("jump");await frames(3);press("jump",false)
	press("surge");press("surge",false);await frames(2)
	check(hero.spell_loadout.current!=null and not combat.blue_effect.aura.visible,"Equipped Homing Attack clears Sonic's previous jump effect")
	var borrowed=hero.spell_loadout.instances["19:sonic/homing"].controller
	await frames(18)
	check(not borrowed.blue_effect.aura.visible and borrowed.blue_effect.trails.all(func(t):return not t.visible),"A completed borrowed Homing Attack retires every blue trail")
	press("jump");press("jump",false)
	check(combat.mode!="homing" and combat.homing_used,"Native input cannot repeat an equipped Homing Attack before landing")
	hero.position=home_point;hero.velocity=Vector3.ZERO;combat.cancel();await frames(8)
	press("jump");await frames(3);press("jump",false);press("jump");press("jump",false);await frames(8)
	press("surge");press("surge",false)
	check(hero.spell_loadout.current==null and combat.homing_used,"Equipped input cannot repeat a native Homing Attack before landing")
	hero.spell_loadout.equip(19,"surge","")
	combat.cancel();hero.position=home_point;hero.velocity=Vector3.ZERO;await frames(8)

func profile():
	# Same static battlefield and camera; this is a character cost check, not an army stress test.
	var results=[]
	for id in [1,19,1,19]:
		var hero:Hero=game.player;hero.select_character(id);hero.position=Vector3(0,game.world.height_at(0,70)+.2,70);hero.velocity=Vector3.ZERO
		await frames(120)
		var samples=[];var cpu=[];var physics=[];var hero_cpu=[];var focused=0
		var last=Time.get_ticks_usec();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		hero.set_physics_process(false)
		for i in 180:
			await process_frame
			var now=Time.get_ticks_usec();samples.append((now-last)/1000.0);last=now
			var started=Time.get_ticks_usec();hero._physics_process(1.0/60);hero_cpu.append((Time.get_ticks_usec()-started)/1000.0)
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
			if root.has_focus():focused+=1
		hero.set_physics_process(true)
		samples.sort();cpu.sort();physics.sort();hero_cpu.sort()
		results.append({"character":id,"frames":samples.size(),"focused":focused,"frame_median_ms":samples[90],"frame_p95_ms":samples[171],"frame_max_ms":samples.back(),"hero_cpu_p95_ms":hero_cpu[171],"process_p95_ms":cpu[171],"physics_p95_ms":physics[171],"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources})
	var file=FileAccess.open("res://build/Other Files/Asset Toolkit/Sonic/profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"resolution":root.size,"scope":"Idle character cost, same paused world simulation. One manually timed Hero physics step per rendered frame; excludes AnimationPlayer/render CPU. No army performance claim.","samples":results},"\t"))

func motion_profile():
	var hero:Hero=game.player
	var kit=hero.active_ability
	var cpu=[];var frame_ms=[];var focused=0
	hero.set_physics_process(false)
	var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var started=Time.get_ticks_usec()
	for i in 480:
		await process_frame
		var now=Time.get_ticks_usec();frame_ms.append((now-started)/1000.0);started=now
		if i%60==0:kit.cancel();hero.position=home_point;hero.velocity=Vector3.ZERO;hero.facing=Vector3.FORWARD
		if i%60==4:kit.start_spin()
		if i%60==25:kit.release_spin()
		var begin=Time.get_ticks_usec()
		hero._physics_process(1.0/60)
		cpu.append((Time.get_ticks_usec()-begin)/1000.0)
		if root.has_focus():focused+=1
	kit.cancel();hero.set_physics_process(true)
	cpu.sort();frame_ms.sort()
	var result={"scope":"480 rendered frames of repeated full Spin Dash with blue effects; static test battlefield. One explicit Hero step per render. Background load is uncontrolled; no full-army claim.","focused":focused,"hero_cpu_p95_ms":cpu[456],"frame_median_ms":frame_ms[240],"frame_p95_ms":frame_ms[456],"frame_max_ms":frame_ms.back(),"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"effect_nodes":kit.blue_effect.get_child_count(),"renderer":RenderingServer.get_video_adapter_name()}
	FileAccess.open("res://build/Other Files/Asset Toolkit/Sonic/Movement/profile.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SONIC_MOTION_PROFILE ",JSON.stringify(result))
