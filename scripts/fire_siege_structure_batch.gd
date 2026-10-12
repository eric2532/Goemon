extends RefCounted
## Render adapters preserve the supplied model, its pivots and its animation tracks.
static var cache: Dictionary={}
static func convert(tower: Node3D)->Array[MeshInstance3D]:
	var groups: Dictionary={}
	for part: MeshInstance3D in tower._model_meshes:
		# The nocked arrow has independent scale/visibility tracks during firing.
		if tower.embedded_arrow.is_ancestor_of(part):continue
		var pivot: Node3D=tower.visual_root
		if tower.recoil.is_ancestor_of(part):pivot=tower.recoil
		elif tower.launcher.is_ancestor_of(part):pivot=tower.launcher
		if not groups.has(pivot):groups[pivot]=[]
		groups[pivot].append(part)
	var result: Array[MeshInstance3D]=[]
	for pivot: Node3D in groups:
		var key="%d:%s" % [int(tower.position.y>2),String(pivot.name)]
		if not cache.has(key):cache[key]=merge(groups[pivot],pivot)
		var proxy=MeshInstance3D.new();proxy.name="CompletedMaterialBatch";proxy.mesh=cache[key]
		pivot.add_child(proxy);result.append(proxy)
		for part: MeshInstance3D in groups[pivot]:
			part.set_meta("render_batched",true);part.hide()
	return result
static func merge(parts: Array,pivot: Node3D)->ArrayMesh:
	var surfaces: Dictionary={}
	var inverse=pivot.global_transform.affine_inverse()
	for part: MeshInstance3D in parts:
		var transform=inverse*part.global_transform
		for surface in range(part.mesh.get_surface_count()):
			var material=part.get_active_material(surface)
			if not surfaces.has(material):
				var builder=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES);builder.set_material(material);surfaces[material]=builder
			surfaces[material].append_from(part.mesh,surface,transform)
	var mesh=ArrayMesh.new()
	for builder: SurfaceTool in surfaces.values():builder.commit(mesh)
	return mesh
