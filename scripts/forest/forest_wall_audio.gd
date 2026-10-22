extends Node3D
## Original Musashi event0x493, adapted as positional masonry damage feedback.
const CRACK=preload("res://assets/audio/recovered_musashi_wall/wall_crack.wav")
const MAX_VOICES=6
const WALL_INTERVAL=.30
const MIX_INTERVAL=.25 # Six voices can finish the selected1.35s impact tail.
const AUDIBLE_DISTANCE=65.0
var game
var voices:Array[AudioStreamPlayer3D]=[]
var voice_cursor=0
var clock=0.0
var mix_ready=0.0
var cooldowns:Dictionary={}
func _ready():
	name="WallCrackingAudio";process_mode=Node.PROCESS_MODE_PAUSABLE
	for i in MAX_VOICES:
		var voice=AudioStreamPlayer3D.new();voice.stream=CRACK
		voice.max_distance=AUDIBLE_DISTANCE;voice.unit_size=12.0;voice.max_polyphony=1
		add_child(voice);voices.append(voice)
func _process(delta:float):
	clock+=maxf(0,delta)
	for id in cooldowns.keys():
		if cooldowns[id]<=clock:cooldowns.erase(id)
func reset():
	for voice in voices:voice.stop()
	voice_cursor=0;clock=0.0;mix_ready=0.0;cooldowns.clear()
func impact(event:Dictionary)->bool:
	if not is_instance_valid(game) or game.model==null or game.model.phase!="wave" or not game.playing or game.paused or game.transitioning:return false
	if not is_instance_valid(game.player) or game.sound_library.recording:return false
	var volume=clampf(float(game.settings.get("volume",.65)),0,1)
	if volume<=0 or voices.is_empty():return false
	var point:Vector3=event.get("point",Vector3.INF)
	if not point.is_finite() or point.distance_squared_to(game.player.global_position)>AUDIBLE_DISTANCE*AUDIBLE_DISTANCE:return false
	var destroyed=bool(event.get("destroyed",false));var id=int(event.get("id",-1))
	if not destroyed and (clock<mix_ready or clock<float(cooldowns.get(id,0.0))):return false
	# Breakage can interrupt an earlier crack so its final impact is never lost.
	var voice=voices[voice_cursor%MAX_VOICES];voice_cursor+=1
	voice.global_position=point;voice.pitch_scale=1.0
	var severity=clampf(float(event.get("damage",0))/maxf(1,float(event.get("max_hp",1)))*20.0,0,1)
	voice.volume_db=linear_to_db(.85 if destroyed else lerpf(.35,.65,severity))
	voice.play();cooldowns[id]=clock+WALL_INTERVAL;mix_ready=clock+MIX_INTERVAL
	return true
