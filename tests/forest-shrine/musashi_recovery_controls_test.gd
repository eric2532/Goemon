extends SceneTree
## Wrong Lumina entry/window, ignored E, sticky guard and invented default voices.
var checks=0
var failures=0
var game
var settings_file="user://musashi-recovery-controls-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func frames(n:int=3):
	for i in n:await physics_frame
func action(name_:String,pressed:bool=true):
	var event=InputEventAction.new();event.action=name_;event.pressed=pressed
	game.player._input(event)
	if pressed:game.player._unhandled_input(event)
func ground_player(p):
	p.position=Vector3(0,.05,18)
	for i in 3:p.velocity=Vector3.DOWN*20;p.move_and_slide()
	p.velocity=Vector3.ZERO
func run():
	set_meta("forest_army_backend","legacy")
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=settings_file
	root.add_child(game);current_scene=game;await frames()
	game.begin_forest();game.choose_rogue_character(13);game.start_wave()
	game.tuning.freeze_ai=true;game.tuning.invincible=false;game.tuning.critical_chance=0;game.character_tuning={}
	await frames(8)
	var p=game.player;var c=p.active_ability;var m=p.model
	p.set_physics_process(false);ground_player(p)
	c.cancel();action("heavy_attack")
	check(c.clip=="Extra__800d4f14","RMB selects the original standing Lumina entry")
	check(is_equal_approx(c.contact_time,8.0/30.0),"Standing Lumina contact opens at source tick 8")
	check(is_equal_approx(p.attack_duration,21.0/30.0),"Standing Lumina retains its 21 source ticks")
	c.tick(8.0/30.0)
	check(c.contact_done and c.trail_active(),"Exactly eight source ticks open Lumina contact without a floating-point frame delay")
	c.cancel();p.position.y+=5;p.velocity=Vector3(6,8,0);p.move_and_slide();action("heavy_attack")
	check(c.clip=="Extra__800d4f8c" and is_equal_approx(c.contact_time,4.0/30.0),"Airborne RMB selects the original 17-tick Lumina strike with tick-4 contact")
	c.cancel();ground_player(p)
	check(p.is_on_floor(),"The fixture has returned from the airborne strike to actual ground contact")
	check(c.has_method("guarding"),"Musashi owns a separate guard and charge state")
	if not c.has_method("guarding"):await finish();return
	action("equip");c.tick(.2);action("equip",false)
	check(not c.is_attacking() and not c.guarding(),"A short E press cannot release a partially charged special")
	action("equip");c.tick(43.0/30.0);action("equip",false)
	check(c.mode=="rotation" and c.clip=="Extra__800d5360","Holding E and releasing the full charge activates the recovered Lumina Rotation")
	check(is_equal_approx(c.contact_time,8.0/30.0),"Rotation waits through the eight original windup ticks")
	c.cancel();action("surge")
	check(c.guarding(),"R holds the original guard state")
	m.animate(0,0,true,0,0,false,0,false)
	check(m.current_clip=="Table_29__800d5734","Guard displays the source defensive stance")
	p.facing=Vector3.FORWARD;p.invuln=0;var hp=p.hp
	p.take_hit(5,Vector3.BACK)
	check(p.hp==hp,"Frontal guard blocks damage approaching from in front")
	p.take_hit(5,Vector3.FORWARD)
	check(p.hp<hp and not c.guarding(),"A rear hit damages Musashi and interrupts guarding")
	p.invuln=0;c.cancel();action("surge");action("surge",false)
	check(not c.guarding(),"Releasing R ends guarding immediately")
	c.cancel();action("equip");c.tick(.2);c.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not c.guarding() and c.charge==0 and not c.is_attacking(),"Focus loss clears charge and pending special intent")
	c.cancel();action("equip");c.tick(.2);p.select_character(1);action("equip",false);p.select_character(13)
	check(not c.guarding() and c.charge==0 and not c.is_attacking(),"Switching fighters cannot replay an unfinished E special")
	action("equip");c.tick(43.0/30.0);p.position.y+=5;p.velocity=Vector3.UP;p.move_and_slide();action("equip",false)
	check(c.charge==0 and not c.is_attacking(),"Releasing a charged E in midair cancels it without leaving a hidden ready attack")
	ground_player(p);action("heavy_attack")
	check(c.mode=="lumina","The next ordinary RMB after a rejected aerial special stays an ordinary attack")
	c.cancel();var old_roster=game.rogue_roster_mode;game.rogue_roster_mode=false;action("character_toggle")
	check(p.character_id!=13,"Q still switches fighters in the general game mode")
	game.rogue_roster_mode=old_roster;p.select_character(13)
	action("dodge")
	check(p.dodge_time==0,"Musashi no longer inherits Goemon's added evade move")
	check(game.sound_preview(13,"move_primary_1_voice")==null and game.sound_preview(13,"jump")==null,"Unconfirmed jump and inactive retail sword grunts have silent defaults")
	check(game.sound_preview(13,"musashi_spin").resource_path.ends_with("lumina_spin.wav"),"The E special uses its recovered retail sound")
	for clip in ["Recovered__800d4d88","Recovered__800d4da8","Recovered__800d4db4","Recovered__800d4dd4","Recovered__800d4df4","Recovered__800d4e6c","Recovered__800d52a8","Recovered__800d52e8","Recovered__800d533c","Recovered__800d5c6c"]:
		check(m.animation_player.has_animation(clip),"Recovered body entry is available: "+clip)
	check(game.has_method("select_musashi_equipment"),"Equipment selection uses the game's saved appearance preferences")
	if game.has_method("select_musashi_equipment"):
		game.select_musashi_equipment(31)
		var saved=ConfigFile.new();saved.load(settings_file)
		check(m.outfit_mask==31 and saved.get_value("settings","musashi_equipment_mask",0)==31,"Choosing recovered equipment applies and saves all five pieces")
		m.set_outfit_mask(0);game.load_settings()
		check(m.outfit_mask==31,"Reloading settings restores Musashi's chosen equipment pixels")
	await finish()
func finish():
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
	if FileAccess.file_exists(settings_file):DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_file))
	print("MUSASHI_RECOVERY_CONTROLS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
