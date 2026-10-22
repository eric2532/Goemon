extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Catches named Sound Studio controls disconnected from real Yae inputs.
func quiet():
	for voice in game.voices:voice.stop()
	game.move_audio.stop()
func active_kind(kind:String)->Array:
	return game.voices.filter(func(voice):return voice.playing and voice.get_meta("kind","")==kind)
func press(action:String,pressed:bool):
	var event=InputEventAction.new();event.action=action;event.pressed=pressed
	if pressed:game.player._unhandled_input(event)
	else:game.player._input(event)
func play_move(action:String,charged:bool=false):
	if charged:
		press(action,true);await step(130);press(action,false);await step(30)
	elif action=="equip":
		press(action,true);await step(30)
	else:
		tap(action);await step(30)
func run():
	await setup_fixture()
	var p=game.player
	check(p.ROSTER.has(17),"Yae's actual sound gameplay can be selected")
	if not p.ROSTER.has(17):
		game.queue_free();paused=false;await frames();quit(1);return
	p.select_character(17);game.settings.volume=1
	var lib=game.sound_library;lib.select_character(17)
	var combat=p.active_ability
	p.position=Vector3(0,-.01,60);p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO
	for entry in [["light_attack","move_primary_1_weapon","yae_katana_1",false],["heavy_attack","move_secondary_weapon","yae_bazooka",false],["heavy_attack","move_charged_weapon","yae_lock_on",true],["equip","move_utility_weapon","yae_shield",false]]:
		combat.cancel();quiet();lib.set_muted(entry[1],false);await play_move(entry[0],entry[3])
		check(not active_kind(entry[2]).is_empty(),"Unmuted named %s plays its actual source weapon"%entry[1])
		combat.cancel();quiet();lib.set_muted(entry[1],true);await play_move(entry[0],entry[3])
		check(active_kind(entry[2]).is_empty(),"Muting named %s silences its actual source weapon"%entry[1])
		lib.set_muted(entry[1],false);press(entry[0],false)
	combat.cancel();quiet();lib.set_muted("move_primary_3_weapon",true)
	press("light_attack",true)
	for i in 180:
		p._physics_process(1.0/60)
		if combat.mode=="primary" and combat.combo==2:break
	await step(30);press("light_attack",false)
	check(active_kind("yae_katana_3_follow").is_empty(),"Muting the katana finisher also silences its second native weapon cue")
	lib.set_muted("move_primary_3_weapon",false)
	combat.cancel();quiet();lib.set_muted("move_utility_weapon",true)
	press("equip",true);await step(40);quiet();p.invuln=0;p.take_hit(1,Vector3.BACK,true)
	check(active_kind("yae_shield_block").is_empty(),"Muting Sword Shield also silences its original projectile deflection cue")
	lib.set_muted("move_utility_weapon",false);quiet();p.invuln=0;p.take_hit(1,Vector3.BACK,true)
	check(not active_kind("yae_shield_block").is_empty(),"Unmuted Sword Shield plays the native deflection cue on a real hit")
	press("equip",false)
	combat.cancel();quiet()
	var before=lib.original_for(16,"move_primary_1_weapon")
	lib.set_muted("move_primary_1_weapon",true)
	check(not lib.is_muted_for(16,"move_primary_1_weapon") and lib.original_for(16,"move_primary_1_weapon")==before,"Yae's Studio settings do not change Sasuke's profile")
	lib.set_muted("move_primary_1_weapon",false)
	game.queue_free();paused=false;await frames();await create_timer(.15).timeout
	print("YAE_SOUND_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
