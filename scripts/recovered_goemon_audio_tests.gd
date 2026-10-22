extends "res://scripts/character_sound_tests.gd"
const Original=preload("res://scripts/recovered_goemon_audio.gd")
func stop_game_audio():
	for voice in game.voices:voice.stop()
func source_contact_count()->int:
	var result=0
	for voice in game.voices:
		if voice.playing and voice.stream==Original.stream_for("hit"):result+=1
	return result
func run():
	lib=new_library()
	for slot in Original.FILES:
		var stream=lib.original_for(1,slot)
		check(stream!=null,"Goemon source event loads: "+slot)
		if stream is AudioStreamWAV:check(stream.get_length()>0 and stream.mix_rate==44100,"Source PCM is playable at its rendered rate: "+slot)
		elif stream is AudioStreamRandomizer:
			check(stream.random_pitch==1.0 and stream.random_volume_offset_db==0,"Source variation preserves original pitch and volume: "+slot)
			for index in stream.streams_count:check(stream.get_stream(index)!=null,"Source random-table entry loads: "+slot)
	var jump=lib.original_for(1,"jump") as AudioStreamRandomizer
	check(jump.streams_count==3 and jump.get_stream(1)==jump.get_stream(2),"Jump preserves the original table's 1:2 voice weighting")
	for slot in ["move_primary_2_voice","environment_hit"]:
		check(lib.original_for(1,slot)==null,"Unverified environment sounds and source-silent pipe voices receive no invented original: "+slot)
	for id in range(2,16):
		check(lib.original_for(id,"goemon_transform")==null,"Transformation stays isolated from character "+str(id))
	var fallback=fixture()
	var play=lib.playback_for(1,"move_primary_1_weapon",fallback)
	check(play.original and not play.recorded,"Goemon defaults use the verified original event")
	play=lib.playback_for(1,"move_primary_1_weapon",fallback,"",false)
	check(play.stream==fallback and not play.original,"Enemy/non-original routes cannot borrow Goemon audio")
	lib.select_character(1);save("swing",fixture(22050));lib.set_gain("swing",.4);lib.set_muted("swing",true)
	play=lib.playback_for(1,"move_primary_1_weapon",fallback)
	check(play.original and not play.recorded and play.stream==Original.stream_for("move_primary_1_weapon") and is_equal_approx(play.gain,.4) and play.muted,"Goemon ignores legacy recorded takes while retaining slot gain and mute controls")
	lib.set_muted("swing",false);save("move_primary_1_weapon",fixture(16000));lib.set_gain("move_primary_1_weapon",.7)
	play=lib.playback_for(1,"move_primary_1_weapon",fallback)
	check(play.original and not play.recorded and play.stream==Original.stream_for("move_primary_1_weapon") and is_equal_approx(play.gain,.28),"Goemon original playback also ignores dedicated move takes without changing stored gain settings")
	save("move_primary_1_voice",fixture(16000))
	check(lib.custom_for(1,"move_primary_1_voice")!=null,"Saved voice takes remain preserved while original combat voices are selected")
	lib.free()
	# Exercise the actual Game.sound/MoveAudio dispatcher with an empty profile.
	lib=new_library();lib.folder=sandbox+"/runtime-recordings";lib.config_path=sandbox+"/runtime-studio.cfg"
	lib._custom_profiles.clear();lib._gain_profiles.clear();lib._mute_profiles.clear();lib._restored_profiles.clear()
	game=AudioGame.new();root.add_child(game);game.setup_audio()
	game.player=Hero.new();game.player.game=game;game.player.character_id=1
	game.sound_library=lib;lib.game=game
	lib.select_character(1);save("move_primary_1_voice",fixture(16000));save("jump",fixture(16000))
	check(lib.stream_for(1,"jump",fixture())==Original.stream_for("jump") and lib.custom_for(1,"jump")!=null,"Goemon original-only preference preserves recordings while bypassing them in direct playback")
	game.camera_rig=ActionCamera.new();game.camera_rig.game=game;game.add_child(game.camera_rig);game.camera_rig.set_process(false)
	for index in 3:
		var ticket={"move_audio":{"character_id":1,"move_key":"primary_%d"%(index+1),"voiced":false}}
		var before=game.move_audio.cursor
		game.move_audio.release(game,ticket)
		check(game.move_audio.cursor==before+(0 if index==1 else 1),"Pipe action entry releases its verified grunt group once: "+str(index+1))
		game.sound("heavy_swing" if index==2 else "swing",1,false,ticket,1)
		check(game.move_audio.cursor==before+(0 if index==1 else 1),"Later pipe swoosh cannot duplicate the entry grunt: "+str(index+1))
		check(game.last_sound_voice.stream==Original.stream_for("move_primary_%d_weapon"%(index+1)),"Game dispatch plays source pipe combo "+str(index+1))
		check(game.last_sound_voice.pitch_scale==1.0,"Game dispatch keeps the source pipe pitch "+str(index+1))
	check(game.move_audio.voices[0].stream==Original.stream_for("move_primary_1_voice") and game.move_audio.voices[1].stream==Original.stream_for("move_primary_3_voice"),"Actual first/finisher grunts use native random groups despite saved voice takes")
	game.sound("hit",1,false,{},1)
	check(game.last_sound_voice.stream==Original.stream_for("hit") and game.last_sound_voice.pitch_scale==1.0,"Confirmed contact dispatch uses original victim event 24F at its source pitch")
	game.sound("heavy_hit",1,false,{},1)
	check(game.last_sound_voice.stream==Original.stream_for("hit"),"Pipe tiers retain the same original contact sound without an invented heavy variant")
	var victim=Ninja.new()
	stop_game_audio();game.confirm_impact(victim,Vector3.ZERO,Vector3.FORWARD,0,false)
	check(source_contact_count()==1 and victim.impact_pause>0,"Real confirmed melee damage dispatches event 24F once")
	stop_game_audio();game.confirm_impact(victim,Vector3.ZERO,Vector3.FORWARD,2,false)
	check(source_contact_count()==1,"Real confirmed heavy melee contact shares the source event")
	stop_game_audio();game.confirm_impact(victim,Vector3.ZERO,Vector3.FORWARD,0,true,1)
	check(source_contact_count()==1,"Real confirmed coin contact dispatches verified source event 24F once")
	stop_game_audio();game.confirm_impact(victim,Vector3.ZERO,Vector3.FORWARD,2,true,1)
	check(source_contact_count()==1,"Real confirmed heavy coin contact uses the same verified source policy")
	stop_game_audio();game.confirm_impact(victim,Vector3.ZERO,Vector3.FORWARD,0,true)
	check(source_contact_count()==0,"An unowned projectile cannot borrow Goemon originals merely because he is selected")
	stop_game_audio();game.sound("chain_hit",1,false,{},1)
	check(source_contact_count()==1 and game.last_sound_voice.pitch_scale==1.0,"Actual chain contact dispatches verified event 24F at source pitch")
	game.player.character_id=2;stop_game_audio();game.confirm_impact(victim,Vector3.ZERO,Vector3.FORWARD,0,false)
	check(source_contact_count()==0,"Another hero's actual confirmed damage never borrows Goemon contact audio")
	game.player.character_id=2;stop_game_audio();game.confirm_impact(victim,Vector3.ZERO,Vector3.FORWARD,0,true)
	check(source_contact_count()==0,"Another hero's projectile contact keeps its own defaults")
	stop_game_audio();game.confirm_impact(victim,Vector3.ZERO,Vector3.FORWARD,0,true,1)
	check(source_contact_count()==1,"A Goemon coin keeps original contact audio after switching to another hero")
	game.player.character_id=1;victim.free()
	var heavy={"move_audio":{"character_id":1,"move_key":"heavy","voiced":false}}
	game.sound("heavy_swing",1,false,heavy,1)
	check(game.last_sound_voice.stream==Original.stream_for("move_heavy_weapon"),"RMB dispatch uses the original third pipe strike and its dedicated recording slot")
	game.sound("jump",1,false,{},1)
	check(game.last_sound_voice.stream==Original.stream_for("jump") and game.last_sound_voice.pitch_scale==1.0,"Actual jump dispatch uses the original weighted voice/effect pair")
	var coin={"move_audio":{"character_id":1,"move_key":"coin","voiced":false}}
	game.sound("move_coin_weapon",1,false,coin,1)
	check(game.last_sound_voice.stream==Original.stream_for("move_coin_weapon") and not coin.move_audio.voiced,"Coin entry dispatch plays preparation without releasing its voice early")
	var coin_cursor=game.move_audio.cursor
	game.move_audio.release(game,coin)
	check(coin.move_audio.voiced and game.move_audio.cursor==coin_cursor+1,"Coin release dispatch begins one original coin voice")
	game.move_audio.release(game,coin)
	check(game.move_audio.cursor==coin_cursor+1,"Repeated projectile feedback cannot release a second coin voice")
	var charge_cursor=game.move_audio.cursor
	game.sound("goemon_coin_charge",1,false,{},1)
	check(game.last_sound_voice.stream==Original.stream_for("goemon_coin_charge") and game.move_audio.cursor==charge_cursor,"Native coin charge cue plays independently without an invented charge voice")
	var charged={"move_audio":{"character_id":1,"move_key":"coin_charged","voiced":false}}
	game.sound("throw",1,false,charged,1)
	check(game.last_sound_voice.stream==Original.stream_for("move_coin_charged_weapon") and game.move_audio.cursor==charge_cursor+1,"Charged release dispatch uses original15A and one group6 voice")
	game.move_audio.release(game,charged)
	check(game.move_audio.cursor==charge_cursor+1,"Charged projectile feedback cannot repeat its release voice")
	var native_coin=GoldCoin.new();native_coin.game=game
	native_coin.set_meta("original_goemon_coin",true);native_coin.set_meta("original_goemon_charged_coin",true)
	stop_game_audio();Original.charged_coin_contact(native_coin)
	check(game.last_sound_voice.stream==Original.stream_for("goemon_coin_charged_burst") and game.last_sound_voice.pitch_scale==1.0,"Confirmed charged coin adds original projectile event29A at source pitch")
	var burst_count=0
	for v in game.voices:
		if v.playing and v.stream==Original.stream_for("goemon_coin_charged_burst"):burst_count+=1
	Original.charged_coin_contact(native_coin)
	var repeated_count=0
	for v in game.voices:
		if v.playing and v.stream==Original.stream_for("goemon_coin_charged_burst"):repeated_count+=1
	check(burst_count==1 and repeated_count==1,"Charged projectile burst cannot repeat across feedback calls")
	stop_game_audio();native_coin.set_meta("original_goemon_coin",false);native_coin.remove_meta("original_goemon_charged_burst_played");Original.charged_coin_contact(native_coin)
	var foreign_burst=false
	for v in game.voices:
		if v.playing and v.stream==Original.stream_for("goemon_coin_charged_burst"):foreign_burst=true
	check(not foreign_burst,"Foreign projectiles cannot borrow the charged Goemon burst")
	native_coin.free()
	var surge={"move_audio":{"character_id":1,"move_key":"surge","voiced":false}}
	game.sound("spark",1,false,surge,1)
	check(game.last_sound_voice.stream==Original.stream_for("move_surge_weapon"),"R dispatch uses the original transformation effects")
	var voice=game.move_audio.voices[(game.move_audio.cursor-1)%game.move_audio.voices.size()]
	check(voice.stream==Original.stream_for("move_surge_voice") and voice.pitch_scale==1.0,"R dispatch independently releases the original transformation voice")
	var golden=voice.stream as AudioStreamWAV
	var first_sample=-1
	for index in golden.data.size()/2:
		if absi(golden.data.decode_s16(index*2))>16:first_sample=index;break
	var first_time=float(first_sample)/(golden.mix_rate*2)
	check(first_time>=.55 and first_time<.56,"The golden voice has one source delay of 0.55 seconds baked from its trigger")
	game.sound("heavy_swing",1,true,{},1)
	check(game.last_sound_voice.stream!=Original.stream_for("heavy_swing"),"Actual enemy-source dispatch keeps the shared fallback")
	game.move_audio.stop()
	game.player.free();game.player=null;lib.game=null
	game.queue_free();await process_frame;await process_frame;game=null
	lib.free();lib=null
	await create_timer(.2).timeout
	print("GOEMON_AUDIO_RESULT checks=",checks," failures=",failures)
	finish()
