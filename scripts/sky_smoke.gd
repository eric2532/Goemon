class_name SkySmoke
extends Node3D
# Geometry is authored in Blender; this adapter animates cached meshes in gameplay.
var game: Node
var stomp=false
var age=0.0
var puffs: Array[MeshInstance3D]=[]
var directions: Array[Vector3]=[]
var sizes: Array[float]=[]
var delays: Array[float]=[]
static var meshes: Array[Mesh]=[]
static func warmup():
	if not meshes.is_empty():return
	for i in range(3):
		var source=GameAssets.instantiate_model("vfx/smoke_billow_"+str(i))
		meshes.append(source.find_children("*","MeshInstance3D",true,false)[0].mesh)
		source.free()
func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE;add_to_group("sky_smoke")
	warmup()
	var count=18 if stomp else 12
	for i in range(count):
		var a=i*2.399963
		var puff=MeshInstance3D.new();puff.mesh=meshes[i%meshes.size()]
		puff.material_override=Geo.mat("a6a29a" if stomp else "c6d6df")
		puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.rotation=Vector3(i*.8,a,i*.3);add_child(puff);puffs.append(puff)
		directions.append(Vector3(cos(a),.20+float(i%4)*.15,sin(a)))
		sizes.append(.6+float(i%5)*.17);delays.append(float(i%3)*.025)
		puff.scale=Vector3.ONE*.01
func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning:return
	age+=delta
	for i in range(puffs.size()):
		var t=maxf(0,age-delays[i]);var end=.85 if stomp else .65
		var travel=1-exp(-t*(5 if stomp else 4))
		puffs[i].position=directions[i]*travel*(3.6 if stomp else 1.3)
		puffs[i].position.y+=.25+t*(.9 if stomp else 2.6)
		var size=(.12+smoothstep(0,.16,t))*(1+t*.5)*sizes[i]*(1.1 if stomp else .85)
		puffs[i].scale=Vector3.ONE*size
		puffs[i].rotation.y+=delta*(.5+i*.04)
		puffs[i].transparency=smoothstep(.25,end,t)
	if age>1.0:queue_free()
static func emit(game_node: Node,point: Vector3,is_stomp: bool):
	# At maximum rapid-fire cadence the short lifetime keeps the total bounded.
	var effect=SkySmoke.new();effect.game=game_node;effect.stomp=is_stomp;effect.position=point
	game_node.add_child(effect)
