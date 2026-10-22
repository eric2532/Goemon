extends RefCounted
# Reuse Edo Ember V01's actual material resources on the V05 rest geometry.
# Material-only partitioning preserves vertex positions, indices, normals and skin weights.
static var palette={}
static var meshes={}
static func key(name: String)->String:return name.replace("_"," ").to_lower()
static func materials()->Dictionary:
	if not palette.is_empty():return palette
	var reference=load("res://assets/characters/musashi/preview/edo_ember_v01.glb").instantiate()
	for mesh in reference.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var material=mesh.mesh.surface_get_material(i)
			palette[key(material.resource_name)]=material
	reference.free()
	return palette
static func region(name: String,p: Vector3)->String:
	if name.contains("pelvis"):
		if p.y<.075:return "rubber charcoal soles"
		if p.y<.19:return "indigo shoe uppers"
		if p.y<.39:return "ivory linen wraps"
		return "oxblood jacket"
	if p.y<.81:return "vermilion tailored edges"
	if absf(p.x)<.17 and p.z<-.055 and p.y>.86:
		if absf(p.x)>.145:return "vermilion tailored edges"
		return "charcoal vest"
	if p.y>1.31 and absf(p.x)<.135:return "charcoal vest"
	if absf(p.x)>.27 and p.z<-.035 and p.y>.88 and p.y<1.12:
		return "ember orange applique"
	return "oxblood jacket"
static func partition(source: Mesh,name: String)->ArrayMesh:
	var cache_key=str(source.get_instance_id())+name
	if meshes.has(cache_key):return meshes[cache_key]
	var result=ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays=source.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size():indices.append(i)
		var groups={}
		for i in range(0,indices.size(),3):
			var center=(vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3
			var material=region(name,center)
			if not groups.has(material):groups[material]=PackedInt32Array()
			for j in 3:groups[material].append(indices[i+j])
		for material in groups:
			var split=arrays.duplicate();split[Mesh.ARRAY_INDEX]=groups[material]
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,split)
			result.surface_set_material(result.get_surface_count()-1,materials()[material])
	result.set_meta("v05_source_mesh",source)
	meshes[cache_key]=result
	return result
static func apply(root: Node3D):
	var colors=materials()
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		var name=key(mesh.name)
		if name.contains("pelvis") or name.contains("jacket"):
			mesh.mesh=partition(mesh.mesh,name)
			continue
		var material="face warm planes"
		if name.contains("hair") or name.contains("crest") or name.contains("brow"):material="ink black hair"
		elif name.contains("socket") or name.contains("mouth"):material="charcoal vest"
		elif name.contains("pupil"):material="amber iris"
		elif name.contains("eye plane"):material="eye ivory"
		elif name.contains("hand"):material="warm copper skin"
		mesh.material_override=colors[material]
