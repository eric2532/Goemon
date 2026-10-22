extends Node

var game: Node
var voices: Array[AudioStreamPlayer] = []
var cache: Dictionary = {}
var last_events: Dictionary = {}
var ambience: AudioStreamPlayer
# Sonic owns its environment music; only opt in when used as a standalone preview.
var ambience_enabled: bool = false
var volume: float = 0.55
var paused: bool = false
var cursor: int = 0
var clock: float = 0.0

func _ready() -> void:
	for i in 28:
		var voice = AudioStreamPlayer.new()
		voice.bus = "Master"
		add_child(voice)
		voices.append(voice)
	if not ambience_enabled:
		return
	ambience = AudioStreamPlayer.new()
	var stream = load("res://assets/rogue/audio/ambience.wav") as AudioStreamWAV
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size()/4
		ambience.stream = stream
		ambience.volume_db = linear_to_db(volume * 0.7)
		add_child(ambience)
		ambience.play()

func play(event: String, options: Dictionary = {}) -> void:
	if is_instance_valid(game) and game.sound_library.recording:return
	if volume <= 0.001 or voices.is_empty():
		return
	if paused and event not in ["click","hover","reward","victory","defeat"]:
		return
	var limits = {"hit":0.025,"heavy":0.035,"pierce":0.035,"claymore-impact":0.065,"shuriken":0.065,"fire":0.1,"ice":0.1,"lightning":0.085,"hover":0.06,"spawn":0.25}
	var now = Time.get_ticks_msec()/1000.0
	if now-float(last_events.get(event,-100.0)) < float(limits.get(event,0.015)):
		return
	last_events[event] = now
	var file = event_file(event, options)
	if not cache.has(file):
		var path = "res://assets/rogue/audio/"+file+".wav"
		if not ResourceLoader.exists(path):
			return
		cache[file] = load(path)
	var recorded: AudioStream
	var gain=1.0
	var playback={}
	if is_instance_valid(game):
		var id=int(options.get("character_id",game.sound_character_id()))
		var slot=game.sound_library.native_slot(id,event,options)
		var ticket: Dictionary=options.get("ticket",{})
		if not options.has("ticket") and is_instance_valid(game.player):ticket=game.player.attack_chain.active_ticket
		playback=game.move_audio.weapon(game,id,slot,cache[file],ticket)
		if playback.muted:return
		recorded=playback.stream if playback.recorded else null
		gain=playback.gain
	var voice = voices[cursor]
	cursor = (cursor+1)%voices.size()
	voice.stop()
	voice.stream = playback.stream if not playback.is_empty() else cache[file]
	voice.volume_db = linear_to_db(volume*float(options.get("volume",options.get("gain",1.0)))*gain)
	voice.pitch_scale = 1.0 if recorded else clampf(float(options.get("pitch",1.0))*randf_range(0.97,1.03),0.3,2.8)
	voice.play()

func set_volume(value: float) -> void:
	volume = clampf(value,0,1)
	if ambience:
		ambience.volume_db = linear_to_db(maxf(0.0001,volume*(0.25 if paused else 0.7)))

func set_paused(value: bool) -> void:
	paused = value
	set_volume(volume)

static func event_file(event: String, options: Dictionary = {})->String:
	var file = event
	if event == "blade":
		var style = str(options.get("style","pirate"))
		if style not in ["pirate","samurai","ninja","knight","magic-swordsman","explorer","master-thief"]:
			style = "pirate"
		var variation = "special" if style in ["ninja","explorer"] and options.get("special",false) else str(clampi(int(options.get("combo",0)),0,2))
		file += "-"+style+"-"+variation
	elif event == "slam" and options.get("style","")=="dragoon":
		file = "landing-strike-dragoon"
	elif event == "thrust" and options.get("style","")=="dragoon":
		file = "thrust-dragoon-"+str(clampi(int(options.get("combo",0)),0,2))
	elif event == "claymore-sweep":
		file = "sweep-dragoon" if options.get("style","")=="dragoon" else file+"-"+str(clampi(int(options.get("combo",0)),0,2))
	elif event == "claymore-impact":
		file += "-"+("heavy" if options.get("heavy",false) else "light")
	elif event == "bow":
		var style=str(options.get("style",""))
		if style=="tower":file="bow-tower-"+str(posmod(int(options.get("variation",0)),2))
		elif options.get("ranger",false) or style=="ranger":
			file="bow-ranger-power" if style=="power" else "bow-ranger-rapid-"+str(posmod(int(options.get("variation",options.get("combo",0))),2))
		else:file += "-"+("power" if style=="power" else "rapid")
	elif event == "cast":
		file += "-"+("magic-swordsman" if options.get("style","") == "magic-swordsman" else "mage")
	return file

func _exit_tree() -> void:
	for voice in voices:
		if is_instance_valid(voice):voice.stop();voice.stream=null
	if is_instance_valid(ambience):ambience.stop();ambience.stream=null
	cache.clear()
