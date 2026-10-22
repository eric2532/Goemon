class_name BossWave
extends Node3D
var game: Node
var radius=0.5
var struck=false
var ring: MeshInstance3D

func _ready():
	add_to_group("boss_waves")
	process_mode=Node.PROCESS_MODE_PAUSABLE
	ring=Geo.torus(self,Vector3(0,0.10,0),0.94,1.04,Geo.mat("f2a475",0,0.7))

func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning: return
	radius+=delta*10
	ring.scale=Vector3(radius,1,radius)
	var p=game.player.position
	var distance=Vector2(p.x-position.x,p.z-position.z).length()
	var above_floor=p.y-game.world.height_at(p.x,p.z)
	if not struck and absf(distance-radius)<0.95 and above_floor<1.05:
		struck=true
		game.player.take_hit(18,(p-position).normalized())
	if radius>18: queue_free()
