extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Illidan/"
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Shot=preload("res://scripts/warcraft_projectile.gd")
var times=[]
var intervals=[]
var live=false
var footsteps=[]

func aim_meta_at(point:Vector3):
	var rig=game.camera_rig;rig.update_camera(0)
	var direction=(point-rig.camera.global_position).normalized()
	rig.yaw=atan2(-direction.x,-direction.z);rig.pitch=-asin(direction.y);rig.update_camera(0)

func advance(count:int,delta:float=1.0/60):
	for i in count:
		var start=Time.get_ticks_usec()
		var sound_order=game.voice_idx
		game.player._physics_process(delta)
		for voice in game.voices:
			if voice.get_meta("order",-1)>sound_order and voice.get_meta("kind","")=="step":footsteps.append(voice.stream)
		for nodes in Pool.service(game).all.values():
			for shot in nodes:
				if shot.pool_live and shot.get_script()==Shot:shot._physics_process(delta)
		times.append((Time.get_ticks_usec()-start)/1000.0)
		if live and DisplayServer.get_name()!="headless":
			await physics_frame;intervals.append((Time.get_ticks_usec()-start)/1000.0)
		elif i%30==0:await process_frame

func capture(label_:String):
	if DisplayServer.get_name()=="headless":return
	game.forest_ui.sync();RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT+label_+".png")

func run():
	create_timer(180).timeout.connect(func():printerr("WARCRAFT_TIMEOUT");quit(1))
	var document=load("res://scripts/forest/forest_map_document.gd").new();document.load_wind_meadow()
	await setup_fixture(document.data);game.tuning.invincible=true
	game.camera_rig.set_process_unhandled_input(false)
	var p=game.player;var pool=Pool.service(game)
	pool.launched.connect(func(shot):
		if shot.get_script()==Shot:shot.set_physics_process(false))
	game.show_rogue_roster();await frames(2)
	for key in ["blademaster","demon-hunter"]:check(game.menu.find_child("RogueFighter_"+key,true,false)!=null,"Fighter gallery card "+key)
	game.menu.find_child("RogueFighter_demon-hunter",true,false).grab_focus();await frames(2);await capture("roster")
	game.close_rogue_roster();await frames(2)
	game.camera_rig.camera.position=ORIGIN+Vector3(25,20,45);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,9.6,0))
	for id in [31,32]:
		p.select_character(id);fresh();await advance(12)
		var model=p.model;var combat=p.active_ability
		check(model.scale.is_equal_approx(Vector3.ONE*6),"Requested sixfold model scale %d"%id)
		check(is_equal_approx(p.base_attack_speed_multiplier(),3.0),"Requested triple base attack speed %d"%id)
		# Compare the same original clip with no contact bonus changing its clock.
		var dummy_home=game.training_dummy.home
		game.training_dummy.home=ORIGIN+Vector3.FORWARD*100;game.training_dummy.position=game.training_dummy.home
		for rate in [1.0,3.0]:
			game.update_character_tuning(id,"attack_speed",rate);fresh();tap("light_attack")
			combat.tick(.01)
			check(is_equal_approx(combat.elapsed,.01*rate),"Original attack clock follows balance speed %d / %.0fx"%[id,rate])
			model.animate(0,0,true,0,0,false,0,false)
			check(is_equal_approx(model.animation_player.current_animation_position,combat.elapsed),"Attack animation stays aligned with contact clock %d / %.0fx"%[id,rate])
			combat.tick(combat.duration/rate-.011)
			check(combat.is_attacking(),"Attack retains full scaled recovery %d / %.0fx"%[id,rate])
			combat.tick(.002)
			check(not combat.is_attacking(),"Attack completes at original duration divided by speed %d / %.0fx"%[id,rate])
		game.training_dummy.home=dummy_home;game.training_dummy.position=dummy_home
		fresh()
		check(p.RogueRoster.selection_ids().has(id),"Roster exposes %d"%id)
		game.forest_ui.sync()
		check(game.forest_ui.hero_name.text==p.RogueRoster.name_for(id),"HUD identity %d"%id)
		check(model.motion.clips.size()==(14 if id==31 else 24),"Full recovered animation library %d"%id)
		check(model.skeleton.get_bone_count()==(84 if id==31 else 302),"Complete original rig %d"%id)
		if id==31:
			check(model.motion.team_color==0,"Blademaster uses Warcraft's original red team slot")
			for index in [0,2,5]:
				var texture:Image=model.meshes[index].mesh.surface_get_material(0).albedo_texture.get_image()
				if texture.is_compressed():texture.decompress()
				var red_pixels=0
				for y in texture.get_height():
					for x in texture.get_width():
						var pixel=texture.get_pixel(x,y)
						if pixel.r>.2 and pixel.g<.1 and pixel.b<.1 and pixel.a>.1:red_pixels+=1
				# Native TeamGlow00 peaks at 127/255; charcoal peaks at only 20/255.
				check(red_pixels>(1000 if index==2 else 20),"Original red clothing / hero glow texture %d"%index)
		if id==32:
			check(p.RogueRoster.name_for(id)=="Illidan" and p.ROSTER[id].name=="Illidan","Slot 32 is Illidan in the gallery and player")
			check(model.motion.source.ends_with("/Illidan/Illidan.blend"),"Illidan uses the saved editable master")
			for name_ in ["Attack","Attack 2"]:check(is_equal_approx(model.animation_player.get_animation(name_).length,.9),"Model replacement preserves attack recovery "+name_)
		for name_ in model.motion.clips:
			check(model.animation_player.has_animation(name_),"Imported "+name_)
			for fraction in [0,.25,.5,.75,.999]:
				model.pose(name_,model.animation_player.get_animation(name_).length*fraction)
				check(model.meshes.any(func(m):return m.visible) or name_.begins_with("Dissipate"),"Authored visibility "+name_+" "+str(fraction))
		model.pose("Stand",0);await capture("%d-idle"%id)
		for slot in preload("res://scripts/warcraft_audio.gd").FILES[id]:
			check(SoundLibrary.original_for(id,slot)!=null,"Prepared original audio "+slot)
		var goemon_step=game.sound_default(1,"step")
		check(goemon_step!=null and game.sound_preview(id,"step")==goemon_step,"Walking preview shares Goemon's footstep %d"%id)
		live=true;fresh();footsteps.clear();p.smoke_move=Vector2.RIGHT
		var first_step=p.model.locomotion.step_events
		Input.action_press("walk_modifier");await advance(120);Input.action_release("walk_modifier")
		var expected_steps=ceili(p.model.locomotion.step_events/2.0)-ceili(first_step/2.0)
		check(expected_steps>0 and footsteps.size()==expected_steps and footsteps.all(func(sound):return sound==goemon_step),"Repeated real walking keeps Goemon's sample and existing every-other-step cadence %d"%id)
		check(game.last_sound_voice.pitch_scale==1.0,"Walking keeps Goemon's recovered source pitch %d"%id)
		p.smoke_move=Vector2.ZERO;await advance(30);footsteps.clear();await advance(30)
		check(footsteps.is_empty(),"Standing still stops footsteps %d"%id)
		live=false;fresh();await advance(12)
		for n in (3 if id==31 else 2):
			contacts.clear();tap("light_attack");await advance(1)
			check(combat.is_attacking() and contacts.is_empty(),"Click retains windup %d/%d"%[id,n])
			check(p.combo==n+1,"Faster clicks retain original combo order %d/%d"%[id,n])
			await advance(6);await capture("%d-attack-%d"%[id,n]);await advance(ceili(combat.duration/p.base_attack_speed_multiplier()*60)+2)
			check(contacts.size()==1,"One native contact per click %d/%d (%d)"%[id,n,contacts.size()])
		fresh();tap("light_attack");combat.interrupt_for_dodge();await advance(90)
		check(contacts.is_empty(),"Cancellation prevents stale contact %d"%id)
		var before=p.position;tap("jump");await advance(4)
		check(p.position.y>before.y,"Shared jump works %d"%id)
		fresh();await advance(10)
		p.spell_loadout.number_input(1,true);p.spell_loadout.number_input(1,false)
		if id==31:
			check(combat.mode=="spin","Number 1 starts Bladestorm")
			await advance(30);await capture("31-spin");await advance(260)
			check(contacts.size()==12,"Spin delivers twelve bounded native pulses (%d)"%contacts.size())
		else:
			check(combat.mode=="morph","Number 1 starts Metamorphosis")
			await advance(25);await capture("32-morph");await advance(80)
			check(combat.demon and model.clip=="Stand Alternate","Morph changes to original alternate body")
			await capture("32-demon")
			aim_meta_at(game.training_dummy.position+Vector3.UP*1.5)
			contacts.clear();tap("light_attack");await advance(90)
			check(contacts.size()==1,"Demon bolt hits once (%d)"%contacts.size())
			combat.cooldown=0;tap("heavy_attack");await advance(100)
			check(not combat.demon and model.clip=="Stand","Reverse morph restores normal body")
			check(model.live_particles.is_empty(),"Morph and attack particles reset")
		p.select_character(1)
		check(not combat.active and not combat.is_attacking() and not combat.demon,"Selection clears previous kit %d"%id)
	# A borrowed storm uses the existing source adapter without changing the wearer.
	p.spell_loadout.equip(1,"equip","blademaster/spin");fresh();await advance(5)
	tap("equip");await advance(190)
	check(p.character_id==1 and contacts.size()==12,"Goemon can equip Bladestorm through the shared skill system")
	p.spell_loadout.equip(1,"equip","")
	p.select_character(32);fresh();await advance(5)
	var created=pool.created;var misses=pool.misses
	for i in 100:
		var shot=pool.launch(p,Shot,"demon",{"position":ORIGIN,"velocity":Vector3.FORWARD*20,"damage":1.0,"attack_ticket":{"old":true}})
		shot.age=2;shot.retire();shot=pool.launch(p,Shot,"demon",{})
		check(shot.age==0 and shot.velocity==Vector3.ZERO and shot.attack_ticket.is_empty() and shot.damage==64,"Projectile lease resets every use")
		shot.retire()
	check(pool.created==created and pool.misses==misses,"Repeated bolts do not grow the shared pool")
	# Damage/respawn owns the same form and cancellation boundary as real play.
	game.tuning.invincible=false;p.active_ability.demon=true;p.invuln=0;p.hp=1
	p.take_hit(100,Vector3.BACK)
	check(p.hp<=0 and p.active_ability.mode=="dead" and p.active_ability.clip=="Death Alternate","Actual defeat retains transformed death")
	var death_time=p.active_ability.elapsed;p.model._process(.2)
	check(p.active_ability.elapsed>death_time and p.model.clip=="Death Alternate","Death animation advances while player movement is stopped")
	game._respawn_player()
	check(p.hp>0 and not p.active_ability.demon and p.active_ability.mode.is_empty(),"Respawn clears form and attack state")
	game.tuning.invincible=true
	# Real army proxies receive shared contacts; cover still blocks both weapons.
	game.training_dummy.home=ORIGIN+Vector3(0,0,-100);game.training_dummy.position=game.training_dummy.home
	var owner=game.army_runtime;owner.set_navigation(9931,{"width":0})
	for id in [31,32]:
		p.select_character(id);fresh();await advance(8)
		var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-3));row.hp=1000;row.max_hp=1000
		owner.import_arrivals();owner.sync_targets()
		var actor=game.actors[row.id];var hp=actor.hp
		if id==32:p.active_ability.demon=true;aim_meta_at(AttackChain.aim_point(actor))
		tap("light_attack");await advance(100)
		check(actor.hp<hp,"Original attack damages native army target %d"%id)
		var wall=StaticBody3D.new();wall.collision_layer=1
		var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(10,8,.2);wall.add_child(shape);game.add_child(wall);wall.position=ORIGIN+Vector3(0,3,-1.25)
		await physics_frame;await physics_frame;fresh();await advance(4)
		if id==32:p.active_ability.demon=true;aim_meta_at(AttackChain.aim_point(actor))
		hp=actor.hp
		tap("light_attack");await advance(100)
		check(actor.hp==hp,"Solid cover blocks native damage %d"%id)
		wall.free();owner.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
	preload("res://tests/forest-shrine/training_dummy_fixture.gd").install(game)
	game.training_dummy.home=ORIGIN+Vector3(0,0,-2);game.training_dummy.position=game.training_dummy.home
	game.sync_training_dummy()
	# Keep the graphical segment real-time; report its limits separately from CPU steps.
	live=true
	for id in [31,32]:
		p.select_character(id);fresh();await advance(5)
		var count=p.model.get_child_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		p.active_ability.demon=id==32
		game.camera_rig.camera.look_at(game.training_dummy.global_position+Vector3.UP*1.5)
		if id==32:
			aim_meta_at(game.training_dummy.position+Vector3.UP*1.5)
		for i in 10:tap("light_attack");await advance(30)
		check(contacts.size()==10,"Repeated triple-speed attacks each deliver one contact %d (%d)"%[id,contacts.size()])
		game.camera_rig.camera.position=ORIGIN+Vector3(0,12,18)
		game.camera_rig.camera.look_at(ORIGIN+Vector3(0,9.6,0))
		fresh()
		for i in 3:
			p.active_ability.cooldown=0;tap("equip");await advance(190)
		check(p.model.get_child_count()==count,"Repeated special keeps model nodes stable %d"%id)
		print("WARCRAFT_RESOURCE_DELTA ",id," ",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources)
	await capture("final")
	times.sort();intervals.sort()
	var report={"checks":checks,"failures":failures,"pool_created":pool.created,"pool_misses":pool.misses,"player_step_p95_ms":times[int(times.size()*.95)],"player_step_max_ms":times[-1],"rendered_frame_p95_ms":intervals[int(intervals.size()*.95)] if not intervals.is_empty() else null,"rendered_frame_max_ms":intervals[-1] if not intervals.is_empty() else null}
	FileAccess.open(OUT+"gameplay-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WARCRAFT_RESULT ",JSON.stringify(report));game.queue_free();await frames(3)
	DirAccess.remove_absolute(cfg)
	quit(1 if failures else 0)
