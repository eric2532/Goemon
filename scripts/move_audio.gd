extends RefCounted
## A cast owns one pair. Only its launch/swing sound may release the voice;
## impact events and repeated projectile feedback never begin another voice.
var voices: Array[AudioStreamPlayer]=[]
var cursor=0

func begin(hero,action: String,explicit_key: String="")->Dictionary:
	var character_id: int=hero.character_id
	var move_key=explicit_key
	if not move_key.is_empty():return {"character_id":character_id,"move_key":move_key,"voiced":false}
	if character_id>=3:
		var kind=action.trim_prefix("rogue_"+SoundLibrary.character_key(character_id)+"_")
		if kind=="primary":
			var combat=hero.active_ability
			var index: int=int(combat.combo)%(5 if character_id==4 else 3) if combat.combo_timer>0 else 0
			move_key="primary_%d"%(index+1) if character_id!=6 else "primary_1"
			if character_id==9 and hero.jumps_used>=2 and not hero.is_on_floor():move_key="dive"
		else:move_key=kind
	elif character_id==2:
		move_key={"fireball":"volley","giant_fireball":"giant","meteors":"meteor","beam":"beam","shield":"shield","teleport":"dodge"}.get(action,"")
	else:
		move_key={"pipe":"primary_1","heavy":"heavy","coin":"coin","wide":"wide","spin":"spin","dash":"dash","sky_strike":"sky_strike","evade":"evade","chain_throw":"chain_throw","chain_sweep":"chain_fire" if hero.surge_left>0 else "chain_sweep"}.get(action,"")
	return {"character_id":character_id,"move_key":move_key,"voiced":false}

func weapon(game,id: int,legacy: String,fallback: AudioStream,ticket: Dictionary={},route_move: bool=true)->Dictionary:
	var lib=game.sound_library
	var result: Dictionary=lib.playback_for(id,legacy,fallback)
	if not route_move:return result
	var context: Dictionary=ticket.get("move_audio",{})
	if id!=int(context.get("character_id",-1)):return result
	var move: Dictionary=SoundLibrary.moves_for(id).get(context.get("move_key",""),{})
	if move.is_empty() or move.legacy!=legacy:return result
	release(game,ticket)
	return lib.playback_for(id,move.weapon,fallback)

func release(game,ticket: Dictionary):
	var context: Dictionary=ticket.get("move_audio",{})
	if context.is_empty() or context.voiced:return
	var id: int=int(context.character_id)
	var move: Dictionary=SoundLibrary.moves_for(id).get(context.move_key,{})
	if move.is_empty() or game.sound_character_id()!=id:return
	context.voiced=true
	play_voice(game,id,move.voice)

func play_voice(game,id: int,slot: String):
	var lib=game.sound_library
	if lib.recording or lib.is_muted_for(id,slot):return
	var stream: AudioStream=lib.custom_for(id,slot)
	if stream==null or game.settings.volume<=.001:return
	if voices.is_empty():
		for i in 8:
			var voice=AudioStreamPlayer.new();voice.name="MoveVoice%d"%i;game.add_child(voice);voices.append(voice)
	var voice=voices[cursor];cursor=(cursor+1)%voices.size()
	voice.stop();voice.stream=stream;voice.pitch_scale=1
	# The Master bus applies the user's game volume, as it does for previews.
	voice.volume_db=linear_to_db(.55*lib.gain_for(id,slot));voice.play()

func stop():
	for voice in voices:
		if is_instance_valid(voice):voice.stop()
