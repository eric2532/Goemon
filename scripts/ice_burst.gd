extends Node3D
var game: Node
var age=0.0
var shards: Array[Node3D]=[]
func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE;add_to_group("elemental_vfx")
	var material=Geo.mat("9eeeff",.35,1.5)
	for i in range(16):
		var shard=Geo.spike(self,Vector3.ZERO,Vector3(0,1.8,0),.32,material)
		shard.rotation.z=.4*sin(float(i));shards.append(shard)
func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning:return
	age+=delta
	for i in range(shards.size()):
		var angle=TAU*i/shards.size()
		var distance=lerpf(.7,7,1-exp(-age*7))
		shards[i].position=Vector3(cos(angle)*distance,.3,sin(angle)*distance)
		shards[i].scale=Vector3.ONE*maxf(.01,sin(clampf(age/.65,0,1)*PI))
	if age>=.65:queue_free()
