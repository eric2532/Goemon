class_name SoundLibrary
extends Node
signal changed
const SLOTS={"orb_ice":"Orb · ice burst", "orb_fire":"Orb · fire burst", "orb_magnet":"Orb · magnet", "enemy_reaction":"Enemy · reaction", "environment_hit":"Environment · impact", "swing":"Pipe · light swing", "heavy_swing":"Pipe · heavy swing", "hit":"Enemy · light impact", "heavy_hit":"Enemy · heavy impact", "throw":"Coin · throw", "coin_hit":"Coin · impact", "coin_heavy_hit":"Coin · heavy impact", "hurt":"Player · hurt", "jump":"Jump", "land":"Landing", "dash":"Evade", "step":"Footstep", "spark":"Pickup / energy", "goemon_dash":"Goemon · E dash", "goemon_dash_hit":"Goemon · E shove", "spin_swing":"Goemon · wind spin", "giant_toss":"Goemon · giant coin toss", "sky_leap":"Goemon · T leap", "sky_stomp":"Goemon · T impact", "chain_throw":"Chain pipe · piercing throw", "chain_sweep":"Chain pipe · fan swing", "chain_hit":"Chain pipe · impact", "chain_explosion":"Chain pipe · R explosion", "chain_fire_sweep":"Chain pipe · R fire swing", "edo_volley":"Edo · triple fireball", "edo_giant":"Edo · giant fireball", "fire_impact":"Edo · fireball impact", "edo_shield":"Edo · R shield activation", "edo_beam_start":"Edo · beam start", "edo_beam_loop":"Edo · sustained beam", "edo_meteor_cast":"Edo · T meteor summon", "edo_meteor_strike":"Edo · T ground strike", "edo_meteor_impact":"Edo · meteor explosion", "edo_dodge":"Edo · fire dodge", "edo_dodge_impact":"Edo · dodge explosion"}
const LIMIT=8.0
var folder="user://recorded_sounds"
var custom: Dictionary={}
var gains: Dictionary={}
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
var bus_name="SoundStudioInput"
var game: Node
var music_was_paused=false
var take_slot=""
var active_slot=""
var discarded_before=0

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(folder)
	var config=ConfigFile.new()
	if config.load("user://sound_studio.cfg")==OK:
		device=str(config.get_value("input","device","Default"))
		for slot in SLOTS:gains[slot]=clampf(float(config.get_value("gain",slot,1.0)),0,2)
	for slot in SLOTS:
		var path=folder+"/"+slot+".wav"
		if FileAccess.file_exists(path):
			var audio=AudioStreamWAV.load_from_file(path)
			if audio and audio.get_length()>0:custom[slot]=audio
	preview=AudioStreamPlayer.new();add_child(preview)

func devices()->PackedStringArray:
	return AudioServer.get_input_device_list()

func configure_capture():
	if mic:return
	AudioServer.add_bus()
	var index=AudioServer.bus_count-1
	AudioServer.set_bus_name(index,bus_name)
	capture=AudioEffectCapture.new();capture.buffer_length=2.0
	AudioServer.add_bus_effect(index,capture)
	# Effects receive the samples, but microphone audio is never sent to speakers.
	AudioServer.set_bus_mute(index,true)
	mic=AudioStreamPlayer.new();mic.bus=bus_name;mic.stream=AudioStreamMicrophone.new();add_child(mic)

func begin(slot: String)->bool:
	if recording or not SLOTS.has(slot):return false
	cancel()
	if devices().is_empty():status="No microphone found. Connect one and press Refresh.";changed.emit();return false
	if not device in devices():device="Default"
	AudioServer.input_device=device
	configure_capture()
	capture.clear_buffer();discarded_before=capture.get_discarded_frames();frames.clear();take=null;take_slot="";active_slot=slot
	elapsed=0;level=0;recording=true
	if is_instance_valid(game):
		music_was_paused=game.music.stream_paused;game.music.stream_paused=true
		for voice in game.voices:voice.stop()
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
	if capture:capture.clear_buffer()
	frames.clear()

func discard():
	cancel();take=null;take_slot="";status="Take discarded. Saved sounds are unchanged.";changed.emit()

func save_take()->bool:
	if recording or not take or not SLOTS.has(take_slot):return false
	var temporary=folder+"/"+take_slot+".pending.wav"
	var result=take.save_to_wav(temporary)
	if result==OK:result=DirAccess.rename_absolute(temporary,folder+"/"+take_slot+".wav")
	if result!=OK:status="Could not save recording (error %s). Your previous sound is unchanged."%result;changed.emit();return false
	custom[take_slot]=take;status="Saved · "+SLOTS[take_slot]+". Previous take replaced. This recording is now used in gameplay."
	take=null;take_slot="";changed.emit();return true

func reset_slot(slot: String):
	cancel()
	var path=folder+"/"+slot+".wav"
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK:
		status="Could not remove the recording.";changed.emit();return
	custom.erase(slot);gains.erase(slot);persist();status="Restored the built-in sound.";changed.emit()

func persist():
	var config=ConfigFile.new();config.set_value("input","device",device)
	for slot in gains:config.set_value("gain",slot,gains[slot])
	config.save("user://sound_studio.cfg")

func listen(stream: AudioStream,slot: String):
	if recording or not stream:return
	preview.stop();preview.stream=stream;preview.pitch_scale=1;preview.volume_db=linear_to_db(0.55*float(gains.get(slot,1)));preview.play()
