extends Node
## Event-only preparation feedback. Clips and voices are ready before placement.
const CLIPS={
 "tower":[preload("res://assets/audio/building_placement/tower-1.wav"),preload("res://assets/audio/building_placement/tower-2.wav"),preload("res://assets/audio/building_placement/tower-3.wav")],
 "barracks":[preload("res://assets/audio/building_placement/bunker-1.wav"),preload("res://assets/audio/building_placement/bunker-2.wav"),preload("res://assets/audio/building_placement/bunker-3.wav")],
}
const MAX_VOICES=4
var game:Node
var voices:Array[AudioStreamPlayer]=[]
var voice_cursor=0
var next_variant={"tower":0,"barracks":0}
func _ready():
 name="PlacementAudio"
 # Preparing deliberately pauses the simulation, but building feedback is live.
 process_mode=Node.PROCESS_MODE_ALWAYS
 for i in MAX_VOICES:
  var voice=AudioStreamPlayer.new();voice.max_polyphony=1
  voice.bus=&"SFX" if AudioServer.get_bus_index("SFX")>=0 else &"Master"
  add_child(voice);voices.append(voice)
func play_placement(kind:String)->bool:
 if not CLIPS.has(kind) or voices.is_empty() or not is_instance_valid(game):return false
 if not game.playing or game.model==null or game.model.phase!="preparing":return false
 if game.ordinary_pause or game.settings_open or game.rogue_roster_open or game.transitioning:return false
 if game.sound_library.recording or float(game.settings.get("volume",.65))<=0:return false
 var voice=voices[voice_cursor%MAX_VOICES];voice_cursor+=1
 voice.stop();voice.stream=CLIPS[kind][next_variant[kind]]
 next_variant[kind]=(int(next_variant[kind])+1)%CLIPS[kind].size()
 # Master volume already applies to this bus; do not multiply it a second time.
 voice.pitch_scale=1;voice.volume_db=0;voice.play()
 return true
