extends Node
## Shared construction feedback; original samples and four voices are prepared once.
const CLIPS=[preload("res://assets/characters/warcraft/peasant/audio/PeonRepair1.wav"),preload("res://assets/characters/warcraft/peasant/audio/PeonRepair2.wav"),preload("res://assets/characters/warcraft/peasant/audio/PeonRepair3.wav")]
const PLACEMENT=preload("res://assets/audio/warcraft_building/BuildingPlacement.wav")
const CANNON={
 "select":preload("res://assets/audio/warcraft_cannon/CannonTowerWhat1.wav"),
 "complete":preload("res://assets/audio/warcraft_cannon/PeasantBuildingComplete1.wav"),
 "death":preload("res://assets/audio/warcraft_cannon/BuildingDeathSmallHuman.wav"),
 "cancel":preload("res://assets/audio/warcraft_cannon/HCancelBuilding.wav")}
const MAX_VOICES=4
var game:Node
var voices:Array[AudioStreamPlayer]=[]
var voice_cursor=0
var next_variant=0
var next_work=0.0
func _ready():
 name="PlacementAudio"
 # Preparing deliberately pauses the simulation, but building feedback is live.
 process_mode=Node.PROCESS_MODE_ALWAYS
 for i in MAX_VOICES:
  var voice=AudioStreamPlayer.new();voice.max_polyphony=1
  voice.bus=&"SFX" if AudioServer.get_bus_index("SFX")>=0 else &"Master"
  add_child(voice);voices.append(voice)
func play_placement(kind:String)->bool:
 if kind not in ["tower","cannon_tower","barracks","mine","wall","gate","shrine","enemy_castle"] or not available():return false
 if not game.playing or game.model==null or game.model.phase!="preparing":return false
 play_clip(PLACEMENT)
 play_clip(CANNON.complete)
 return true
func available()->bool:
 if voices.is_empty() or not is_instance_valid(game):return false
 if not game.playing or game.model==null or game.model.phase not in ["preparing","wave"]:return false
 if game.ordinary_pause or game.settings_open or game.rogue_roster_open or game.transitioning:return false
 if game.sound_library.recording or float(game.settings.get("volume",.65))<=0:return false
 return true
func play_work(point:Vector3)->bool:
 if not available() or not point.is_finite() or not is_instance_valid(game.player):return false
 if not game.model.visible_at(point) or point.distance_squared_to(game.player.global_position)>65.0*65.0:return false
 var now=Time.get_ticks_msec()/1000.0
 if now<next_work:return false
 next_work=now+.075;play_hammer();return true
func play_hammer():
 play_clip(CLIPS[next_variant]);next_variant=(next_variant+1)%CLIPS.size()
func play_clip(clip:AudioStream):
 var voice=voices[voice_cursor%MAX_VOICES];voice_cursor+=1
 voice.stop();voice.stream=clip
 # Master volume already applies to this bus; do not multiply it a second time.
 voice.pitch_scale=1;voice.volume_db=linear_to_db(.55);voice.play()
func _process(_delta:float):
 if available():return
 for voice in voices:
  if voice.playing:voice.stop()
 next_work=0.0

func play_cannon(event:String,point:Vector3=Vector3.INF)->bool:
 if not CANNON.has(event) or not available():return false
 if point!=Vector3.INF and not game.model.visible_at(point):return false
 play_clip(CANNON[event]);return true
