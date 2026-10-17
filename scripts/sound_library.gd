class_name SoundLibrary
extends Node
signal changed
const SLOTS={"orb_ice":"Orb · ice burst", "orb_fire":"Orb · fire burst", "orb_magnet":"Orb · magnet", "enemy_reaction":"Enemy · reaction", "environment_hit":"Environment · impact", "swing":"Pipe · light swing", "heavy_swing":"Pipe · heavy swing", "hit":"Enemy · light impact", "heavy_hit":"Enemy · heavy impact", "throw":"Coin · throw", "coin_hit":"Coin · impact", "coin_heavy_hit":"Coin · heavy impact", "hurt":"Player · hurt", "jump":"Jump", "land":"Landing", "dash":"Evade", "step":"Footstep", "spark":"Pickup / energy", "goemon_dash":"Goemon · E dash", "goemon_dash_hit":"Goemon · E shove", "spin_swing":"Goemon · wind spin", "giant_toss":"Goemon · giant coin toss", "sky_leap":"Goemon · T leap", "sky_stomp":"Goemon · T impact", "chain_throw":"Chain pipe · piercing throw", "chain_sweep":"Chain pipe · fan swing", "chain_hit":"Chain pipe · impact", "chain_explosion":"Chain pipe · R explosion", "chain_fire_sweep":"Chain pipe · R fire swing", "edo_volley":"Edo · triple fireball", "edo_giant":"Edo · giant fireball", "fire_impact":"Edo · fireball impact", "edo_shield":"Edo · R shield activation", "edo_beam_start":"Edo · beam start", "edo_beam_loop":"Edo · sustained beam", "edo_meteor_cast":"Edo · T meteor summon", "edo_meteor_strike":"Edo · T ground strike", "edo_meteor_impact":"Edo · meteor explosion", "edo_dodge":"Edo · fire dodge", "edo_dodge_impact":"Edo · dodge explosion"}
const Roster=preload("res://scripts/rogue_roster.gd")
const COMMON_SLOTS=["jump","land","dash","step","hurt","hit","heavy_hit","enemy_reaction","environment_hit","spark","orb_ice","orb_fire","orb_magnet"]
const NATIVE_SLOTS={"native_blade":"Weapon · swing", "native_shot":"Flintlock · shot", "native_bow":"Bow · release", "native_shuriken":"Shuriken · throw", "native_cast":"Magic · cast / empower", "native_thrust":"Lance · thrust", "native_slam":"Weapon · ground slam", "native_shield":"Guard · counter", "native_drink":"Skill · activation", "native_fire":"Fire · burst / impact", "native_pierce":"Projectile · piercing impact", "native_claymore-sweep":"Claymore · swing", "native_claymore-wave":"Claymore · energy wave"}
const CLASS_EVENTS={
	3:["blade","shot","drink"], 4:["blade","bow","cast","pierce"],
	5:["blade","shuriken","drink"], 6:["cast","slam","drink"],
	7:["blade","shield","drink"], 8:["thrust","slam","drink","pierce","claymore-sweep"],
	9:["claymore-sweep","claymore-wave","cast","drink"], 10:["bow","cast","drink","pierce"],
	11:["blade","drink"], 12:["blade","shield"]
}
const LIMIT=8.0
var folder="user://recorded_sounds"
var config_path="user://sound_studio.cfg"
# The studio selection is independent of the active gameplay character.
var character_id=1
var _custom_profiles: Dictionary={}
var _gain_profiles: Dictionary={}
var _mute_profiles: Dictionary={}
var _restored_profiles: Dictionary={}
var custom: Dictionary={}
var gains: Dictionary={}
var mutes: Dictionary={}
var device="Default"
var recording=false
var elapsed=0.0
var level=0.0
var status="Choose a sound, then Record. Your microphone is off until you press Record."
var take: AudioStreamWAV
var frames=PackedVector2Array()
var capture: AudioEffectCapture
var mic: AudioStreamPlayer
var preview: AudioStreamPlayer
var preview_voice: AudioStreamPlayer
var bus_name="SoundStudioInput"
var game: Node
var music_was_paused=false
var take_slot=""
var active_slot=""
var discarded_before=0

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	var config=ConfigFile.new()
	if config.load(config_path)==OK:device=str(config.get_value("input","device","Default"))
	_load_profile(character_id)
	custom=_custom_profiles[character_id];gains=_gain_profiles[character_id];mutes=_mute_profiles[character_id]
	preview=AudioStreamPlayer.new();add_child(preview)
	preview_voice=AudioStreamPlayer.new();add_child(preview_voice)

static func character_key(id: int)->String:
	return "goemon" if id==1 else ("edo" if id==2 else Roster.class_id(id))

static func character_name(id: int)->String:
	return "Goemon" if id==1 else ("Edo" if id==2 else Roster.name_for(id))

static func slots_for(id: int)->Dictionary:
	var result={}
	if id==1:
		for key in SLOTS:
			if not key.begins_with("edo_") and key!="fire_impact":result[key]=SLOTS[key]
	elif id==2:
		for key in SLOTS:
			if key.begins_with("edo_") or key=="fire_impact":result[key]=SLOTS[key]
	elif CLASS_EVENTS.has(id):
		for event in CLASS_EVENTS[id]+["fire"]:result["native_"+event]=NATIVE_SLOTS["native_"+event]
	for key in COMMON_SLOTS:result[key]=SLOTS[key]
	for move in moves_for(id).values():
		result[move.weapon]=move.label+" · Weapon"
		result[move.voice]=move.label+" · Voice"
	return result

static func _move(key: String,label: String,legacy: String,options: Dictionary={})->Dictionary:
	return {"label":label,"weapon":"move_"+key+"_weapon","voice":"move_"+key+"_voice","legacy":legacy,"options":options}

static func moves_for(id: int)->Dictionary:
	var result={}
	if id==1:
		var entries={"primary_1":["Pipe · first cut","swing"],"primary_2":["Pipe · second cut","swing"],"primary_3":["Pipe · finisher","heavy_swing"],"heavy":["Heavy pipe","heavy_swing"],"wide":["Wide pipe sweep","heavy_swing"],"spin":["Wind spin","spin_swing"],"coin":["Coin volley","throw"],"coin_heavy":["Heavy coin volley","throw"],"giant_toss":["Giant coin toss","giant_toss"],"dash":["E · dash","goemon_dash"],"chain_throw":["Chain pipe · throw","chain_throw"],"chain_sweep":["Chain pipe · sweep","chain_sweep"],"chain_fire":["Chain pipe · fire sweep","chain_fire_sweep"],"sky_strike":["T · sky strike","sky_leap"],"evade":["Evade","dash"]}
		for key in entries:result[key]=_move(key,entries[key][0],entries[key][1])
		result.surge=_move("surge","R · Golden Surge","spark")
		for index in 3:result["primary_%d"%(index+1)].options={"preview_event":"blade","style":"magic-swordsman","combo":index}
	elif id==2:
		var entries={"volley":["Triple fireball","edo_volley"],"giant":["Giant fireball","edo_giant"],"shield":["R · fire shield","edo_shield"],"beam":["Sustained beam","edo_beam_start"],"meteor":["T · meteor summon","edo_meteor_cast"],"dodge":["Fire dodge","edo_dodge"]}
		for key in entries:result[key]=_move(key,entries[key][0],entries[key][1])
	elif id>=3 and id<=12:
		var abilities: Dictionary=Roster.data(id).abilities
		var primary="native_thrust" if id==8 else ("native_claymore-sweep" if id==9 else ("native_bow" if id==10 else ("native_cast" if id==6 else "native_blade")))
		for index in range(5 if id==4 else (1 if id==6 else 3)):
			var key="primary_%d"%(index+1)
			result[key]=_move(key,str(abilities.cutlass.name)+" · "+str(index+1),primary,{"combo":index,"ranger":id==10,"style":"power" if id==10 and index==2 else Roster.class_id(id)})
		var secondary={3:"native_shot",4:"native_bow",5:"native_blade",6:"native_cast",7:"native_shield",8:"native_slam",9:"native_claymore-wave",10:"native_bow",11:"native_blade",12:"native_shield"}
		var utility="native_bow" if id==4 else ("native_shuriken" if id==5 else "dash")
		var skill="native_cast" if id==4 else ("native_fire" if id==12 else "native_drink")
		for entry in [["secondary","flintlock",secondary[id]],["utility","roll",utility],["skill","drink",skill]]:
			var options={"ranger":id==10,"style":"power" if id==4 and entry[0] in ["secondary","utility"] else Roster.class_id(id),"special":entry[0]=="secondary"}
			result[entry[0]]=_move(entry[0],str(abilities[entry[1]].name),entry[2],options)
		result.evade=_move("evade","Evade","dash")
		if id==8:
			result.secondary.label="Dragon Leap (airborne)"
			result.sweep=_move("sweep","Azure Lance Sweep","native_claymore-sweep",{"combo":2,"style":"dragoon"})
		if id==9:result.dive=_move("dive","Aerial ground strike","native_claymore-sweep",{"pitch":.75})
	return result

static func move_for_slot(id: int,slot: String)->Dictionary:
	for move in moves_for(id).values():
		if slot==move.weapon or slot==move.voice:return move
	return {}

static func native_slot(id: int,event: String,options: Dictionary={})->String:
	if event in ["hit","heavy"]:return "heavy_hit" if event=="heavy" else "hit"
	if event=="claymore-impact":return "heavy_hit" if options.get("heavy",false) else "hit"
	if event=="roll":return "dash"
	if id==1 and event=="blade":return "heavy_swing" if int(options.get("combo",0))==2 else "swing"
	return "native_"+event

func _profile_folder(id: int)->String:
	return folder+"/"+character_key(id)

func _load_profile(id: int):
	if _custom_profiles.has(id):return
	var recordings={};var volumes={};var restored={};var muted={}
	var config=ConfigFile.new();config.load(config_path)
	var key=character_key(id)
	for slot in slots_for(id):
		if bool(config.get_value("mute:"+key,slot,false)):muted[slot]=true
		var reset=bool(config.get_value("defaults:"+key,slot,false))
		if reset:restored[slot]=true
		# The old studio was Goemon's hub plus Edo's named spells. Never let a
		# legacy global override silently replace every new character's audio.
		var legacy_owner=2 if slot.begins_with("edo_") or slot=="fire_impact" else 1
		var fallback=id==legacy_owner and not reset
		var gain=config.get_value("gain:"+key,slot,config.get_value("gain",slot,1.0) if fallback else 1.0)
		if (gain is int or gain is float) and is_finite(float(gain)):
			volumes[slot]=clampf(float(gain),0,2)
		var path=_profile_folder(id)+"/"+slot+".wav"
		if not FileAccess.file_exists(path) and fallback:path=folder+"/"+slot+".wav"
		if FileAccess.file_exists(path):
			var audio=AudioStreamWAV.load_from_file(path)
			if audio and audio.get_length()>0:recordings[slot]=audio
	_custom_profiles[id]=recordings;_gain_profiles[id]=volumes;_restored_profiles[id]=restored;_mute_profiles[id]=muted

func select_character(id: int):
	if id<1 or id>12 or recording:return
	cancel();take=null;take_slot=""
	character_id=id;_load_profile(id)
	custom=_custom_profiles[id];gains=_gain_profiles[id];mutes=_mute_profiles[id]
	status=character_name(id)+" recording hub. Choose a sound, then Record. Microphone is off."
	changed.emit()

func custom_for(id: int,slot: String)->AudioStream:
	if id<1 or id>12:return null
	_load_profile(id)
	return _custom_profiles[id].get(slot)

func gain_for(id: int,slot: String)->float:
	if id<1 or id>12:return 1.0
	_load_profile(id)
	return float(_gain_profiles[id].get(slot,1.0))

func set_gain(slot: String,value: float):
	if not slots_for(character_id).has(slot) or not is_finite(value):return
	gains[slot]=clampf(value,0,2);persist();changed.emit()

func is_muted_for(id: int,slot: String)->bool:
	if id<1 or id>12:return false
	_load_profile(id)
	return bool(_mute_profiles[id].get(slot,false))

func set_muted(slot: String,value: bool):
	if not slots_for(character_id).has(slot):return
	if value:mutes[slot]=true
	else:mutes.erase(slot)
	persist();changed.emit()

func stream_for(id: int,slot: String,fallback: AudioStream)->AudioStream:
	var recorded=custom_for(id,slot)
	return recorded if recorded else fallback

func playback_for(id: int,slot: String,fallback: AudioStream,legacy_override: String="")->Dictionary:
	var recorded: AudioStream=custom_for(id,slot)
	var gain=gain_for(id,slot)
	var muted=is_muted_for(id,slot)
	if recorded==null and slot.begins_with("move_") and slot.ends_with("_weapon"):
		var move: Dictionary=move_for_slot(id,slot)
		if not move.is_empty():
			var legacy: String=move.legacy if legacy_override.is_empty() else legacy_override
			recorded=custom_for(id,legacy)
			gain*=gain_for(id,legacy)
			muted=muted or is_muted_for(id,legacy)
	return {"stream":recorded if recorded else fallback,"recorded":recorded!=null,"gain":gain,"muted":muted}

func devices()->PackedStringArray:
	return AudioServer.get_input_device_list()

func configure_capture():
	if mic:return
	bus_name="SoundStudioInput_%s" % get_instance_id()
	AudioServer.add_bus()
	var index=AudioServer.bus_count-1
	AudioServer.set_bus_name(index,bus_name)
	capture=AudioEffectCapture.new();capture.buffer_length=2.0
	AudioServer.add_bus_effect(index,capture)
	# Effects receive the samples, but microphone audio is never sent to speakers.
	AudioServer.set_bus_mute(index,true)
	mic=AudioStreamPlayer.new();mic.bus=bus_name;mic.stream=AudioStreamMicrophone.new();add_child(mic)

func begin(slot: String)->bool:
	if recording or not slots_for(character_id).has(slot):return false
	cancel()
	if devices().is_empty():status="No microphone found. Connect one and press Refresh.";changed.emit();return false
	if not device in devices():device="Default"
	AudioServer.input_device=device
	configure_capture()
	capture.clear_buffer();discarded_before=capture.get_discarded_frames();frames.clear();take=null;take_slot="";active_slot=slot
	elapsed=0;level=0;recording=true
	if is_instance_valid(game):
		music_was_paused=game.music.stream_paused;game.music.stream_paused=true
		game.move_audio.stop()
		for voice in game.voices:voice.stop()
		var native=game.get_node_or_null("RogueSharedClassAudio")
		if native:
			for voice in native.voices:voice.stop()
		for beam in get_tree().get_nodes_in_group("edo_beams"):
			if game.is_ancestor_of(beam) and is_instance_valid(beam.loop):beam.loop.stop()
	mic.play()
	status="Recording… allow microphone access if macOS asks. Stops after 8 seconds."
	changed.emit();return true

func _process(delta):
	if not recording:return
	elapsed+=delta
	if capture.get_frames_available()>0:
		var chunk=capture.get_buffer(capture.get_frames_available())
		level=0
		for sample in chunk:level=maxf(level,maxf(absf(sample.x),absf(sample.y)))
		frames.append_array(chunk)
	else:level=move_toward(level,0,delta*2)
	if elapsed>=LIMIT:finish()

func stop_input():
	if mic:mic.stop()
	if recording and is_instance_valid(game):game.music.stream_paused=music_was_paused
	recording=false;level=0

func finish():
	if not recording:return
	if capture.get_frames_available()>0:frames.append_array(capture.get_buffer(capture.get_frames_available()))
	stop_input()
	if capture.get_discarded_frames()>discarded_before:
		frames.clear();take=null;status="Recording was interrupted. Please try another take.";changed.emit();return
	take=make_take(frames,int(AudioServer.get_mix_rate()))
	frames.clear();take_slot=active_slot if take else ""
	status="Take ready · %.2f seconds. Listen, then Save to use it in the game."%take.get_length() if take else "No usable sound captured. Check your selected input and macOS Settings → Privacy & Security → Microphone."
	changed.emit()

func make_take(samples: PackedVector2Array,rate: int)->AudioStreamWAV:
	if rate<=0 or samples.size()<int(rate*0.04):return null
	var first=-1;var last=-1;var peak=0.0
	for i in range(mini(samples.size(),int(rate*LIMIT))):
		var amplitude=absf((samples[i].x+samples[i].y)*0.5)
		peak=maxf(peak,amplitude)
		if amplitude>0.006:
			if first<0:first=i
			last=i
	if first<0 or peak<0.008:return null
	first=maxi(0,first-int(rate*0.015));last=mini(mini(samples.size(),int(rate*LIMIT))-1,last+int(rate*0.04))
	var bytes=PackedByteArray();bytes.resize((last-first+1)*2)
	var gain=minf(8.0,0.85/peak)
	var fade=maxi(1,int(rate*0.003))
	for i in range(first,last+1):
		var edge=minf(1.0,minf(float(i-first)/fade,float(last-i)/fade))
		var value=clampf((samples[i].x+samples[i].y)*0.5*gain*edge,-1,1)
		bytes.encode_s16((i-first)*2,int(value*32767))
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=rate;wav.stereo=false;wav.data=bytes
	return wav

func cancel():
	stop_input()
	if preview:preview.stop()
	if preview_voice:preview_voice.stop()
	if capture:capture.clear_buffer()
	frames.clear()

func discard():
	cancel();take=null;take_slot="";status="Take discarded. Saved sounds are unchanged.";changed.emit()

func save_take()->bool:
	if recording or not take or not slots_for(character_id).has(take_slot):return false
	var destination=_profile_folder(character_id)
	DirAccess.make_dir_recursive_absolute(destination)
	var temporary=destination+"/"+take_slot+".pending.wav"
	var result=take.save_to_wav(temporary)
	if result==OK:result=DirAccess.rename_absolute(temporary,destination+"/"+take_slot+".wav")
	if result!=OK:status="Could not save recording (error %s). Your previous sound is unchanged."%result;changed.emit();return false
	custom[take_slot]=take;status="Saved for "+character_name(character_id)+" · "+slots_for(character_id)[take_slot]+". This recording is now used in gameplay."
	take=null;take_slot="";changed.emit();return true

func reset_slot(slot: String):
	if not slots_for(character_id).has(slot) or recording:return
	cancel();take=null;take_slot=""
	var path=_profile_folder(character_id)+"/"+slot+".wav"
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK:
		status="Could not remove the recording.";changed.emit();return
	custom.erase(slot);gains.erase(slot);mutes.erase(slot);_restored_profiles[character_id][slot]=true
	if persist():status="Restored "+character_name(character_id)+"'s built-in sound and volume."
	changed.emit()

func persist()->bool:
	var config=ConfigFile.new();config.load(config_path)
	config.set_value("input","device",device)
	for id in _gain_profiles:
		var key=character_key(id)
		if config.has_section("gain:"+key):config.erase_section("gain:"+key)
		for slot in _gain_profiles[id]:config.set_value("gain:"+key,slot,_gain_profiles[id][slot])
		if config.has_section("mute:"+key):config.erase_section("mute:"+key)
		for slot in _mute_profiles[id]:config.set_value("mute:"+key,slot,true)
		for slot in _restored_profiles[id]:config.set_value("defaults:"+key,slot,true)
	var result=config.save(config_path)
	if result!=OK:status="Could not save sound settings (error %s)." % result;return false
	return true

func listen(stream: AudioStream,slot: String):
	if recording:return
	preview.stop();preview_voice.stop()
	var playback=playback_for(character_id,slot,stream)
	if stream==take and take_slot==slot:
		playback.gain=gain_for(character_id,slot);playback.muted=is_muted_for(character_id,slot)
	if not stream or playback.muted:return
	preview.stream=stream;preview.pitch_scale=1;preview.volume_db=linear_to_db(0.55*playback.gain);preview.play()

func listen_pair(id: int,move_key: String):
	if recording or not is_instance_valid(game):return
	var move: Dictionary=moves_for(id).get(move_key,{})
	if move.is_empty():return
	preview.stop();preview_voice.stop()
	for pair in [[preview,move.weapon],[preview_voice,move.voice]]:
		var slot: String=pair[1]
		var stream: AudioStream=game.sound_preview(id,slot)
		var playback=playback_for(id,slot,stream)
		if playback.stream==null or playback.muted:continue
		pair[0].stream=playback.stream;pair[0].pitch_scale=1;pair[0].volume_db=linear_to_db(.55*playback.gain);pair[0].play()

func _exit_tree():
	cancel()
	if capture:
		var index=AudioServer.get_bus_index(bus_name)
		if index>=0:AudioServer.remove_bus(index)
