class_name EdoFireExplosion
extends Node3D
# Blender-authored flame lobes and smoke billows: flash outward, then cool/rise.
var game: Node
var arrival=true
var sound_slot="fire_impact"
var age=0.0
var flames: Array[Node3D]=[]
var smoke: Array[MeshInstance3D]=[]
var directions: Array[Vector3]=[]
var light: OmniLight3D
static var fire_meshes: Array[Mesh]=[]

static func warmup():
	if not fire_meshes.is_empty():return
	var source=GameAssets.instantiate_model("vfx/edo_fire_burst")
	for mesh in source.find_children("*","MeshInstance3D",true,false):fire_meshes.append(mesh.mesh)
	source.free();SkySmoke.warmup()

func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE;add_to_group("edo_explosions")
	warmup()
	scale=Vector3.ONE*(1.0 if arrival else .85)
	for i in range(12):
		var angle=i*2.399963
		directions.append(Vector3(cos(angle),.28+float(i%3)*.12,sin(angle)))
		var flame=Node3D.new();add_child(flame);flames.append(flame)
		flame.rotation=Vector3(sin(angle)*.6,angle,cos(angle)*.6)
		for mesh in fire_meshes:
			var part=MeshInstance3D.new();part.mesh=mesh
			part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;flame.add_child(part)
		flame.scale=Vector3.ONE*.01
		var puff=MeshInstance3D.new();puff.mesh=SkySmoke.meshes[i%3]
		puff.material_override=Geo.mat("4b4140")
		puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.rotation=Vector3(i*.7,angle,i*.4);puff.scale=Vector3.ONE*.01
		add_child(puff);smoke.append(puff)
	light=OmniLight3D.new();light.light_color=Color("ff9a35");light.omni_range=9
	light.light_energy=4;light.position.y=1;add_child(light)
	game.sound(sound_slot,.45)

func _physics_process(delta):
	if not game.playing or game.paused or game.transitioning:return
	age+=delta
	var flash=smoothstep(0,.09,age)*(1.0-smoothstep(.18,.55,age))
	for i in range(flames.size()):
		var travel=1-exp(-age*8)
		flames[i].position=directions[i]*travel*3.0+Vector3.UP*.35
		flames[i].scale=Vector3.ONE*maxf(.01,flash*(.8+float(i%3)*.16))
		for part in flames[i].get_children():part.transparency=smoothstep(.12,.55,age)
		var t=maxf(0,age-.08-float(i%3)*.02)
		smoke[i].position=directions[i]*(1-exp(-t*4))*3.7+Vector3.UP*(.25+t*1.6)
		smoke[i].scale=Vector3.ONE*maxf(.01,smoothstep(0,.22,t)*(1+t*.4))
		smoke[i].transparency=smoothstep(.36,1.15,t)
		smoke[i].rotation.y+=delta*(.4+i*.03)
	light.light_energy=4*flash
	if age>1.35:queue_free()

static func emit(game_node: Node,point: Vector3,is_arrival: bool=true,audio_slot: String="fire_impact"):
	var effect=EdoFireExplosion.new();effect.game=game_node
	effect.sound_slot=audio_slot
	effect.position=point;effect.arrival=is_arrival;game_node.add_child(effect)
