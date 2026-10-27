extends SceneTree
const Jumps=preload("res://scripts/jump_style.gd")
const OUT="res://build/Other Files/Jump Styles/"
var game
var hero:Hero
var checks=0
var failures=0
var cfg="user://jump-styles-%d.cfg"%OS.get_process_id()
var origin=Vector3(0,.1,110)
var measurements={}
var driver:Node
var last_cpu_ms=0.0

func _initialize():
	create_timer(180).timeout.connect(func():printerr("FAIL: jump styles timeout");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1;print("PASS: " if ok else "FAIL: ",message)
	if not ok:
		failures+=1
		if failures<=2 and is_instance_valid(hero):print("JUMP_DIAGNOSTIC ",{"playing":game.playing,"paused":game.paused,"tree_paused":paused,"hp":hero.hp,"position":hero.position,"velocity":hero.velocity,"floor":hero.is_on_floor(),"buffer":hero.jump_buffer,"style":hero.jump_style.selected,"held":Input.is_action_pressed("jump"),"focus":root.has_focus(),"dt":hero.get_physics_process_delta_time()})
func step(count:int=1):
	await driver.advance(1,func(dt):
		var start=Time.get_ticks_usec()
		for i in count:hero._physics_process(dt)
		last_cpu_ms=(Time.get_ticks_usec()-start)/1000.0)
func press(action:String,down:bool=true):
	if down:Input.action_press(action)
	else:Input.action_release(action)
	var event=InputEventAction.new();event.action=action;event.pressed=down
	if down:hero._unhandled_input(event)
	else:hero._input(event)
func fresh(character:int,style:String):
	press("jump",false);Input.action_release("sprint")
	hero.select_character(character);hero.cancel_charge();hero.set_auto_attack(false)
	hero.position=origin;hero.velocity=Vector3.ZERO;hero.smoke_mode=true;hero.smoke_move=Vector2.ZERO
	hero.set_scarf_equipped(false);hero.gold_cloak=false
	hero.jump_style.equip(character,style)
	await step(16)
func apex(character:int,style:String,hold:int)->float:
	await fresh(character,style)
	var baseline=hero.position.y
	var highest=[baseline]
	press("jump")
	await driver.advance(1,func(dt):
		for i in 260:
			if i==hold:press("jump",false)
			hero._physics_process(dt);highest[0]=maxf(highest[0],hero.position.y))
	press("jump",false)
	return highest[0]-baseline

func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
	root.add_child(game);current_scene=game
	await process_frame;await process_frame
	game.start_wave();game.model.waves.spawn_clock=100000;game.tuning.invincible=true
	# Scripted input owns this fixture; another desktop task must not pause it.
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
	root.title="Goemon Jump Style Verification"
	root.grab_focus()
	game.set_physics_process(false);game.camera_rig.set_process(false)
	hero=game.player;hero.set_physics_process(false);game.settings.spell_loadouts={};game.settings.jump_styles={}
	driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();driver.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(driver)
	origin.y=game.world.height_at(origin.x,origin.z)+.1
	var floor_body=StaticBody3D.new();floor_body.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(200,1,200)
	floor_body.add_child(shape);game.add_child(floor_body);floor_body.position=origin-Vector3.UP*.6
	game.camera_rig.yaw=0;game.camera_rig.pitch=.36
	await physics_frame;await physics_frame
	check(Jumps.valid_assignments({"bad":"sonic","01":"ben","1":"sonic","2":42,"3":"missing","999":"ben"})=={"1":"sonic"},"Saved jumps reject invalid fighters, IDs and value types")
	check(Jumps.valid_assignments([]).is_empty(),"Malformed saved jump settings restore Original")
	check(not hero.jump_style.equip(999,"sonic") and not hero.jump_style.equip(1,"missing"),"Equipment validates both fighter and style")
	for id in Jumps.Roster.PLAYABLE_IDS:
		check(hero.jump_style.assignment(id).is_empty(),"Fighter %d defaults to Original"%id)
	await kojiro_double_jump()
	# Exercise every movement path and body through real input and terrain collision.
	for id in Jumps.Roster.PLAYABLE_IDS:
		for style in Jumps.STYLES:
			await fresh(id,style)
			var height=hero.position.y
			press("jump");await step(12)
			check(hero.position.y>height+.1,"%d can use %s"%[id,style])
			check(hero.spell_loadout.current==null,"%d / %s does not cast a spell"%[id,style])
			press("jump",false)
		await process_frame
	# Same donor body: borrowed arcs must track the existing source movement.
	for row in [[19,"sonic",1],[19,"sonic",45],[13,"musashi",1],[13,"musashi",45],[8,"dragoon",1],[10,"ranger",1]]:
		var original=await apex(row[0],"",row[2])
		var borrowed=await apex(row[0],row[1],row[2])
		measurements["%s_%d"%[row[1],row[2]]]={"original":original,"borrowed":borrowed}
		check(absf(original-borrowed)<.15,"%s held %d frames matches original apex (%.3f / %.3f)"%[row[1],row[2],original,borrowed])
	var short_hop=await apex(1,"sonic",1);var high_hop=await apex(1,"sonic",45)
	check(high_hop>short_hop*1.4,"Borrowed Sonic jump retains hold-dependent height")
	await fresh(1,"double");press("jump");await step(10);press("jump",false);press("jump");await step(2)
	check(hero.jumps_used==2 and hero.velocity.y>10,"Goemon style grants a real second jump")
	press("jump",false);press("jump");await step(2)
	check(hero.jumps_used==2,"Repeated presses cannot add a third jump")
	hero.jump_style.equip(1,"ranger");press("jump",false);press("jump");await step(2)
	check(hero.jumps_used==2,"Switching styles in midair does not refill jumps")
	await fresh(13,"double");press("jump");await step(10);press("jump",false);press("jump");await step(5)
	press("jump",false);press("jump");await step(160);press("jump",false)
	check(hero.is_on_floor() and hero.jump_buffer==0,"Musashi's exhausted borrowed jump expires instead of auto-jumping on landing")
	await fresh(1,"dragoon");press("jump");await step(100)
	var hover_height=hero.position.y;await step(30)
	check(hero.jump_style.hovering and absf(hero.position.y-hover_height)<.01,"Borrowed Dragoon hovers while Space is held")
	press("jump",false);await step(10);check(hero.velocity.y<0,"Releasing hover restores falling")
	await fresh(1,"ranger");press("jump");await step(65)
	var glide_speed=hero.velocity.y
	check(hero.jump_style.gliding and glide_speed<0,"Borrowed Ranger glides on descent")
	press("jump",false);await step()
	check(hero.velocity.y<glide_speed*2.5,"Releasing glide restores accumulated fall speed")
	for id in [1,5,13,19]:
		await fresh(id,"ben");press("jump");await step(30)
		check(is_equal_approx(hero.velocity.y,hero.BEN_FLIGHT_ASCENT_SPEED),"%d uses Ben's ascent speed"%id)
		Input.action_press("sprint");await step(20)
		check(is_equal_approx(hero.velocity.y,hero.BEN_FLIGHT_BOOST_ASCENT_SPEED),"%d uses Ben's boost speed"%id)
		press("jump",false);await step()
		check(is_equal_approx(hero.velocity.y,-hero.BEN_DESCENT_SPEED),"%d uses Ben's release descent"%id)
		await step(150);check(hero.is_on_floor(),"%d flight lands on shared terrain"%id)
	# Space is movement; Sonic's separate combat controls remain available.
	await fresh(19,"sonic");press("jump");await step(5);press("jump",false);press("jump");await step(5)
	check(hero.active_ability.mode=="idle" and not hero.active_ability.homing_used,"Borrowed Sonic Space never triggers homing")
	check(hero.model.ball.visible,"Sonic's own body keeps its existing jump-ball presentation")
	press("surge");await step();press("surge",false)
	check(hero.active_ability.mode=="homing","Sonic's separate R homing attack still works")
	await fresh(15,"double");check(not hero.can_fly(),"Ben can replace his innate flight with another jump")
	await fresh(15,"");check(hero.can_fly(),"Original restores Ben's propeller flight")
	# Movement alone never delivers Sonic's contact damage to native victims.
	var enemy=game.model.waves.spawn_enemy(0,origin+Vector3.UP);enemy.hp=10000;enemy.max_hp=10000;enemy.stun=100
	game.sync_enemies();game.model.update_vision(origin)
	var enemy_hp:float=enemy.hp
	for id in [1,19]:
		await fresh(id,"sonic");press("jump");await step(8);press("jump",false)
		check(is_equal_approx(enemy.hp,enemy_hp),"%d borrowed Sonic jump has no contact attack"%id)
	# Flight uses the same body collision instead of moving through ceilings.
	await fresh(1,"ben")
	var ceiling=StaticBody3D.new();ceiling.collision_layer=1
	var ceiling_shape=CollisionShape3D.new();ceiling_shape.shape=BoxShape3D.new();ceiling_shape.shape.size=Vector3(10,.5,10)
	ceiling.add_child(ceiling_shape);game.add_child(ceiling);ceiling.position=origin+Vector3.UP*8
	await physics_frame
	press("jump");await step(120)
	check(hero.is_on_ceiling() and hero.position.y<origin.y+6.2,"Ben flight respects ceiling collision")
	press("jump",false);await step(120);check(hero.is_on_floor(),"Flight recovers and lands after hitting a ceiling")
	ceiling.queue_free();await physics_frame
	await fresh(1,"double")
	var wall=StaticBody3D.new();wall.collision_layer=1
	var wall_shape=CollisionShape3D.new();wall_shape.shape=BoxShape3D.new();wall_shape.shape.size=Vector3(.5,40,12)
	wall.add_child(wall_shape);game.add_child(wall);wall.position=origin+Vector3(4,19,0)
	await physics_frame
	hero.smoke_move=Vector2.RIGHT;press("jump")
	for i in 60:
		await step()
		if hero.wall_jump_grace>0:break
	press("jump",false)
	check(hero.wall_jump_grace>0,"Assigned jump still detects a real wall contact")
	press("jump");await step()
	check(hero.velocity.x<0 and hero.velocity.y>0 and hero.wall_jump_recovery>0,"Assigned jump retains the shared wall hop")
	press("jump",false);wall.queue_free();await physics_frame
	await fresh(1,"double");press("jump");game.show_pause()
	var paused_position=hero.position;await step(5)
	check(hero.position==paused_position and hero.jump_buffer==0,"Pause freezes movement and clears a queued jump")
	press("jump",false);game.resume()
	await fresh(1,"single");hero.set_scarf_equipped(true)
	check(hero.maximum_jumps()==4,"Existing cape jump bonus survives an assigned style")
	hero.set_gold_cloak(true);check(hero.can_fly(),"Existing gold-cape flight remains available")
	hero.set_scarf_equipped(false);hero.gold_cloak=false
	# Saved selection remains separate from the three attack slots.
	hero.spell_loadout.equip(1,"surge","sonic/homing")
	hero.jump_style.equip(1,"sonic");hero.jump_style.equip(5,"ben")
	var saved=ConfigFile.new();check(saved.load(cfg)==OK,"Assignments are written to the normal settings file")
	check(saved.get_value("settings","jump_styles",{}).get("1")=="sonic" and saved.get_value("settings","jump_styles",{}).get("5")=="ben","Jump choices save independently per fighter")
	check(hero.spell_loadout.spell_for(1,"surge")=="sonic/homing","Jump equipment preserves the attack loadout")
	game.load_settings();hero.select_character(1)
	check(hero.jump_style.selected=="sonic","Jump assignment survives settings reload")
	hero.jump_style.equip(1,"")
	check(not hero.jump_style.active() and hero.jump_style.assignment(5)=="ben","Original clears only the selected fighter's override")
	hero.spell_loadout.equip(1,"surge","")
	# Reuse does not construct another controller, model, material or effect.
	await fresh(1,"sonic")
	for i in 20:
		press("jump");await step(8);press("jump",false);await step(140)
	await create_timer(.6).timeout
	var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 20:
		press("jump");await step(8);press("jump",false);await step(140)
	# Existing landing sparks retire asynchronously; measure after they finish.
	await create_timer(.6).timeout
	measurements.reuse={"nodes_before":nodes,"nodes_after":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources_before":resources,"resources_after":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes,"Repeated jumps do not grow node count")
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated jumps do not grow resources")
	var picker=load("res://scripts/spells/spell_picker.gd").new();picker.game=game;game.ui.add_child(picker)
	check(picker.choices.size()==picker.Catalog.SLOTS.size() and picker.jump_choice.item_count==Jumps.STYLES.size()+1,"Equipment exposes one Jump Style slot alongside the configured attack slots")
	picker.jump_choice.item_selected.emit(7)
	check(hero.jump_style.selected=="ben" and picker.jump_choice.get_selected_metadata()=="ben","Jump dropdown applies and reflects its selected style")
	picker.jump_choice.item_selected.emit(0)
	check(not hero.jump_style.active(),"Original dropdown restores the native character jump")
	await process_frame;await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"picker.png")
	picker.queue_free();await process_frame
	if "--visual" in OS.get_cmdline_user_args():await visual_checks()
	if "--profile" in OS.get_cmdline_user_args():await profile()
	var file=FileAccess.open(OUT+("measurements-headless.json" if DisplayServer.get_name()=="headless" else "measurements-desktop.json"),FileAccess.WRITE);file.store_string(JSON.stringify(measurements,"\t"))
	print("JUMP_STYLES_RESULT checks=%d failures=%d"%[checks,failures])
	for action in ["jump","sprint","surge"]:Input.action_release(action)
	driver.queue_free();game.queue_free();paused=false;await process_frame;await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	quit(1 if failures else 0)

func kojiro_double_jump():
	var output="res://build/Other Files/Asset Toolkit/Kojiro/Double Jump/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var short_hop=await apex(28,"",1)
	var held_hop=await apex(28,"",45)
	var donor_hop=await apex(13,"",45)
	check(held_hop>short_hop*1.4,"Kojiro's default jump retains Musashi's release-to-shorten behavior")
	check(absf(held_hop-donor_hop)<.15,"Kojiro's default jump matches Musashi's held apex")
	await fresh(28,"")
	check(hero.jump_style.selected=="musashi" and hero.jump_style.assignment(28).is_empty(),"Kojiro's Original jump reuses Musashi without writing a saved override")
	var model=hero.model
	var animation_player=model.animation_player
	var spin_clip=model.data().semantics.air_spin
	var samples=[]
	for cycle in 24:
		press("jump");await step(8)
		check(hero.jumps_used==1 and model.current_clip!=spin_clip,"Kojiro's first jump stays upright (%d)"%cycle)
		press("jump",false);await step(2);press("jump");await step(2)
		check(hero.jumps_used==2 and hero.velocity.y>0 and model.current_clip==spin_clip,"Kojiro's second jump lifts and somersaults (%d)"%cycle)
		check(not hero.active_ability.is_attacking() and not hero.active_ability.blade_active(),"Jump animation alone never starts a sword attack (%d)"%cycle)
		if cycle==0:
			for phase in 4:
				if DisplayServer.get_name()!="headless":
					game.camera_rig.camera.global_position=hero.position+Vector3(6,3,8)
					game.camera_rig.camera.look_at(hero.position+Vector3.UP*1.5)
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output+"spin-%d.png"%phase)
				await step(4)
		press("jump",false);press("jump");await step(20);press("jump",false)
		check(hero.jumps_used==2 and model.current_clip!=spin_clip,"Third press adds no jump and the spin finishes (%d)"%cycle)
		await step(150)
		check(hero.is_on_floor() and hero.jumps_used==0 and hero.jump_buffer==0,"Landing clears Kojiro's jump and spin state (%d)"%cycle)
		if cycle==3 or cycle==23:
			await create_timer(.6).timeout
			samples.append({"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
	check(samples[0]==samples[1] and model.animation_player==animation_player,"Twenty repeated Kojiro double jumps reuse animation, nodes and resources")
	measurements.kojiro={"short_apex":short_hop,"held_apex":held_hop,"musashi_apex":donor_hop,"reuse":samples}
	await fresh(28,"single");press("jump");await step(8);press("jump",false);press("jump");await step(2)
	check(hero.jumps_used==1 and model.current_clip!=spin_clip,"Kojiro respects an explicitly equipped single jump")
	await fresh(28,"");press("jump");await step(8);press("jump",false);press("jump");await step(2)
	hero.active_ability.start_attack();await step()
	check(model.current_clip==model.data().semantics.air_cut,"Air attacks take priority over the double-jump pose")
	hero.active_ability.cancel();await step(20)
	check(model.current_clip!=spin_clip,"Finishing an interrupted jump does not replay its spin")
	press("jump",false);await step(150)
	hero.select_character(1);hero.select_character(28);await step(8)
	check(hero.jump_style.selected=="musashi" and model.current_clip!=spin_clip,"Reselecting Kojiro restores his default without a stale spin")
	if DisplayServer.get_name()!="headless":
		var cpu=[];var intervals=[];var previous=[Time.get_ticks_usec()];var frame=[0];var focused=[0]
		await driver.advance(360,func(dt):
			var now=Time.get_ticks_usec()
			if frame[0]>0:intervals.append((now-previous[0])/1000.0)
			previous[0]=now
			if frame[0]%90 in [0,12]:press("jump")
			if frame[0]%90 in [4,24]:press("jump",false)
			hero._physics_process(dt);cpu.append((Time.get_ticks_usec()-now)/1000.0)
			if root.has_focus():focused[0]+=1
			frame[0]+=1)
		press("jump",false);cpu.sort();intervals.sort()
		measurements.kojiro.desktop={"scope":"Isolated Hero steps on the rendered fixture; not a full-army benchmark", "frames":frame[0],"focused":focused[0],"hero_cpu_p95_ms":cpu[int(cpu.size()*.95)],"frame_p95_ms":intervals[int(intervals.size()*.95)],"frame_max_ms":intervals.back()}

func visual_checks():
	for row in [[1,"sonic"],[5,"ben"],[13,"ranger"],[19,"sonic"]]:
		await fresh(row[0],row[1]);press("jump");await step(12)
		game.camera_rig.follow=hero.position+Vector3.UP*1.4;game.camera_rig.travel_follow.reset(game.camera_rig.follow)
		game.camera_rig.update_camera(0)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"%d-%s.png"%[row[0],row[1]]);press("jump",false)

func profile():
	var samples=[]
	for style in ["","sonic","ben",""]:
		await fresh(1,style);game.camera_rig.reset_follow()
		for i in 60:await process_frame
		var frames=[];var cpu=[];var focused=0;var last=Time.get_ticks_usec()
		var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		press("jump")
		for i in 180:
			await process_frame
			var now=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
			if i==30:press("jump",false)
			if i==110:press("jump")
			if i==125:press("jump",false)
			await step();cpu.append(last_cpu_ms)
			game.camera_rig.update_camera(1.0/60)
			if root.has_focus():focused+=1
		press("jump",false);frames.sort();cpu.sort()
		samples.append({"style":"original" if style.is_empty() else style,"focused":focused,"frames":180,"frame_p95_ms":frames[171],"frame_max_ms":frames.back(),"hero_cpu_p95_ms":cpu[171],"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources})
	measurements.profile={"scope":"Same frozen battlefield and hero; Hero step in the physics callback per rendered frame. Not a full-army benchmark.","samples":samples}
