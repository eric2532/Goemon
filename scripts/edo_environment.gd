class_name EdoEnvironment
extends RefCounted
## Environment-only materials. Never mutate Geo's shared actor/effect materials.
static var materials: Dictionary={}
const SURFACES={
	"wood":["634638","724634","735344","a55235","923c2c","88342a"],
	"red":["bf4532","ad3d30","d84a32","d64732","e5663b"],
	"plaster":["eee0bc"],
	"sand":["d6c599","d0bd92","c7b48b","d1bda6","c8a073","c7b38a","d5c296"],
	"stone":["8b9992","a4afa0","99ab91","859980","819586"],
	"jade":["809e9e","99b2a2"],
	"crag":["647d76","627870","61786c","536d68","405d68"],
	"rock":["927c59","a58a5b","847553","987247","bb9359"],
	"ochre":["946d4f","ab7351","e1b45f"],
	"leaf":["3e8f55","548954","6a8165"]
}
static func material(hex: String, metallic: float=0.0, glow: float=0.0)->StandardMaterial3D:
	var kind=""
	for key in SURFACES:
		if hex in SURFACES[key]:kind=key;break
	if kind.is_empty():return Geo.mat(hex,metallic,glow)
	return surface(kind)

static func surface(kind: String)->StandardMaterial3D:
	if materials.has(kind):return materials[kind]
	var m=StandardMaterial3D.new()
	m.albedo_texture=load("res://assets/textures/edo/"+kind+".png")
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar=true
	m.uv1_world_triplanar=true
	m.uv1_scale=Vector3.ONE*(.35 if kind in ["sand","grass"] else .65)
	m.roughness=1.0
	materials[kind]=m
	return m

static func ground(area: int)->ShaderMaterial:
	var m=ShaderMaterial.new()
	m.shader=load("res://scripts/edo_ground.gdshader")
	m.set_shader_parameter("grass_tex",load("res://assets/textures/edo/"+["grass","jade","grass","sand"][area]+".png"))
	m.set_shader_parameter("sand_tex",load("res://assets/textures/edo/sand.png"))
	m.set_shader_parameter("coastal",area==0)
	return m

static func temple_details(world: Node3D,x: float,z: float,ly: float,w: float,d: float):
	# Dress only the existing solid side-wall faces; keep all doorways open.
	for side in [-1,1]:
		var panel=GameAssets.place(world,"edo/shoji",Vector3(x+side*(w*.49+.11),ly+.1,z),Vector3(d*.64,2.6,1))
		panel.rotation.y=side*PI/2
	var curtain=GameAssets.place(world,"edo/noren",Vector3(x,ly+3.05,z+d/2-.27),Vector3(w*.24,1,1))
	curtain.name="OverheadNoren"
