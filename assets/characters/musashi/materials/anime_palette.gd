extends RefCounted

static var jacket: ShaderMaterial
static var trousers: ShaderMaterial

static func apply(root: Node3D):
	if jacket==null:
		jacket=ShaderMaterial.new()
		jacket.shader=load("res://assets/characters/musashi/materials/anime_garment.gdshader")
		trousers=jacket.duplicate()
		trousers.set_shader_parameter("trousers",true)
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		var name=String(mesh.name).to_lower()
		if name.contains("jacket"):mesh.material_override=jacket
		elif name.contains("pelvis"):mesh.material_override=trousers
