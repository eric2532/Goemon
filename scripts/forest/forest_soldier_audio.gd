extends Node3D
## User-confirmed retail6AA scream, including the original two-stage pitch bend.
const SCREAM=preload("res://assets/characters/thirstquencher/audio/death_scream.wav")
const MAX_VOICES=6
const MIX_INTERVAL=.07
const AUDIBLE_DISTANCE=65.0
var game:Node
var voices:Array[AudioStreamPlayer3D]=[]
var clock=0.0
var next_start=0.0
var plays_started=0
var active=false
static func ensure(owner_:Node)->Node3D:
 var existing=owner_.get_node_or_null("SoldierDeathAudio")
 if existing!=null:return existing
 var pool=load("res://scripts/forest/forest_soldier_audio.gd").new();pool.name="SoldierDeathAudio";pool.game=owner_;owner_.add_child(pool);return pool
static func soldier_died(owner_:Node,point:Vector3,kind:int)->bool:
 return ensure(owner_).death(point,kind)
func _ready():
 process_mode=Node.PROCESS_MODE_PAUSABLE
 for i in MAX_VOICES:
  var voice=AudioStreamPlayer3D.new();voice.stream=SCREAM;voice.max_distance=AUDIBLE_DISTANCE;voice.unit_size=12;voice.max_polyphony=1
  voice.volume_db=linear_to_db(.7);add_child(voice);voices.append(voice)
func _process(delta:float):
 # Keep the last death's short release tail through a normal wave transition.
 if not is_instance_valid(game) or not game.playing or game.paused or game.transitioning or game.sound_library.recording:
  if active:reset()
  return
 clock+=maxf(0,delta)
func _can_play()->bool:
 return is_instance_valid(game) and game.playing and not game.paused and not game.transitioning and game.model.phase=="wave" and not game.sound_library.recording
func death(point:Vector3,kind:int)->bool:
 if kind not in [0,1,3] or not point.is_finite() or not _can_play():return false
 if float(game.settings.get("volume",.65))<=0 or not is_instance_valid(game.player):return false
 if point.distance_squared_to(game.player.global_position)>AUDIBLE_DISTANCE*AUDIBLE_DISTANCE or clock<next_start:return false
 for voice in voices:
  if voice.playing:continue
  voice.global_position=point;voice.pitch_scale=1.0;voice.play();plays_started+=1;next_start=clock+MIX_INTERVAL;active=true;return true
 return false
func reset():
 for voice in voices:voice.stop()
 clock=0;next_start=0;active=false
