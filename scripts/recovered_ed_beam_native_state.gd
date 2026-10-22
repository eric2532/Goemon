extends RefCounted
## The ROM creates its effect actors once; their phases survive successive casts.
const META=&"ed_native_beam_phase"
const ROTMATRIX=preload("res://assets/characters/recovered_leaders/ed/beam/rotmatrix.tres")
var main_updates=0
var shield_updates=0
var wall_glow_color=Vector3(128,128,128)

class GameplayClock extends Node:
	var game: Node
	var ticks=0
	var fraction=0.0
	func _ready():
		process_mode=Node.PROCESS_MODE_ALWAYS
		# SC06 advances D800B99DA after actor processing, at80128888.
		process_physics_priority=1000
	func _physics_process(delta: float):advance(delta)
	func advance(delta: float):
		if not game.playing or game.paused or game.transitioning or get_tree().paused:return
		fraction+=maxf(0,delta)*30.0
		var complete=floori(fraction+.000001)
		fraction-=complete;ticks=posmod(ticks+complete,65536)

static func world_clock(game: Node)->Node:
	var clock=game.get_node_or_null("EdNativeGameplayClock")
	if clock==null:
		clock=GameplayClock.new();clock.name="EdNativeGameplayClock";clock.game=game;game.add_child(clock)
	return clock

static func sin_cos(angle: int)->Vector2i:
	var packed: int=ROTMATRIX.get_meta("sin_cos")[posmod(angle,4096)]
	var sine=packed&65535
	return Vector2i(sine-65536 if sine>=32768 else sine,packed>>16)

static func rotation_q12(angle: int)->Basis:
	var pair=sin_cos(angle)
	return Basis(Vector3(pair.y,pair.x,0),Vector3(-pair.x,pair.y,0),Vector3(0,0,4096))

static func entry_center(angle: int)->Vector3:
	var pair=sin_cos(angle)
	# Source GTE shifts signed source coordinates before conversion (-x,-y,z).
	return Vector3(-((32*pair.x)>>12),-((-32*pair.y)>>12),-128)

func roll_angle()->int:return posmod(main_updates*120,4096)
func roll_basis_q12()->Basis:return rotation_q12(roll_angle())
func main_palette_row()->int:return posmod(main_updates-1,16)
func shield_phase()->int:return posmod(-199*shield_updates,1536)
