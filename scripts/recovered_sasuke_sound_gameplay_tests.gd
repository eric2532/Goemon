extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Catches disconnected Studio move controls and duplicate native entry voices.
func quiet():
	for voice in game.voices:voice.stop()
	game.move_audio.stop()
func active_kind(kind:String)->Array:
	return game.voices.filter(func(voice):return voice.playing and voice.get_meta("kind","")==kind)
func run():
	await setup_fixture()
	var p=game.player;p.select_character(16);game.settings.volume=1
	var lib=game.sound_library;lib.select_character(16)
	var combat=p.active_ability
	p.position=Vector3(0,-.01,60);p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO
	for entry in [["light_attack","move_primary_1_weapon","sasuke_kunai_1"],["heavy_attack","move_secondary_weapon","sasuke_bomb"],["surge","move_skill_weapon","sasuke_super_jump"]]:
		combat.cancel();quiet();lib.set_muted(entry[1],false);tap(entry[0]);await step(20)
		check(not active_kind(entry[2]).is_empty(),"Unmuted named %s plays its actual source weapon"%entry[1])
		combat.cancel();quiet();lib.set_muted(entry[1],true);tap(entry[0]);await step(20)
		check(active_kind(entry[2]).is_empty(),"Muting named %s silences its actual source weapon"%entry[1])
		lib.set_muted(entry[1],false)
	combat.cancel();quiet();tap("light_attack")
	check(game.move_audio.voices.filter(func(voice):return voice.playing).size()==1,"The first kunai voice starts once at native action entry")
	await step(7)
	check(game.move_audio.voices.filter(func(voice):return voice.playing).size()==1,"The later weapon cue does not duplicate the kunai entry voice")
	combat.cancel();quiet();tap("surge")
	check(not active_kind("sasuke_super_jump").is_empty(),"Jetpack has an owned source weapon voice")
	combat.cancel()
	check(active_kind("sasuke_super_jump").is_empty(),"Cancelling Super Jump stops the finite jetpack weapon voice")
	check(game.move_audio.voices.filter(func(voice):return voice.playing).size()==1,"Cancelling the jetpack leaves its separate original voice tail intact")
	game.queue_free();paused=false;await frames();await create_timer(.15).timeout
	print("SASUKE_SOUND_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
