extends SceneTree
## Read the original Goemon's bind geometry and UVs; split rigid joint groups.
## This bake never edits or saves the hero GLB/Blender master or loads HeroModel.
const SOURCE="res://assets/models/characters/kai.glb"
const OUTPUT="res://assets/models/forest/goemon_worker_body.scn"
const BODY_SCALE=1.0
func _initialize():run.call_deferred()
func group(bone:String)->String:
	if bone in ["Head","Neck"]:return "Head"
	for side in ["L","R"]:
		if bone in ["Arm_"+side,"Forearm_"+side,"Hand_"+side]:return "Arm"+side
		if bone in ["Leg_"+side,"Shin_"+side,"Foot_"+side]:return "Leg"+side
	return "Torso"
func run():
	var source=load(SOURCE).instantiate();root.add_child(source)
	var skin:MeshInstance3D=source.find_child("Skin",true,false)
	var skeleton:Skeleton3D=source.find_child("Skeleton3D",true,false)
	var result=Node3D.new();result.name="GoemonBody"
	result.set_meta("source_model",SOURCE);result.set_meta("source_sha256",FileAccess.get_sha256(SOURCE))
	var parts={};var pivots={"Torso":Vector3.ZERO,"Head":skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin}
	for side in ["L","R"]:
		pivots["Arm"+side]=skeleton.get_bone_global_rest(skeleton.find_bone("Arm_"+side)).origin
		pivots["Leg"+side]=skeleton.get_bone_global_rest(skeleton.find_bone("Leg_"+side)).origin
	for name_ in pivots:
		var pivot=Node3D.new();pivot.name=name_;pivot.position=pivots[name_]*BODY_SCALE
		result.add_child(pivot);pivot.owner=result;parts[name_]=pivot
	var counts={};var triangles=0
	for surface in skin.mesh.get_surface_count():
		var arrays=skin.mesh.surface_get_arrays(surface)
		var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var uv=arrays[Mesh.ARRAY_TEX_UV]
		var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS];var indices=arrays[Mesh.ARRAY_INDEX]
		var groups={}
		for name_ in pivots:groups[name_]=[PackedVector3Array(),PackedVector3Array(),PackedVector2Array()]
		for triangle in range(indices.size()/3):
			var votes={}
			for corner in 3:
				var index=indices[triangle*3+corner]
				for influence in 4:
					var weight=weights[index*4+influence]
					if weight<=0:continue
					var name_=group(skin.skin.get_bind_name(bones[index*4+influence]))
					votes[name_]=votes.get(name_,0.0)+weight
			var dominant="Torso";var strongest=-1.0
			for name_ in votes:
				if votes[name_]>strongest:dominant=name_;strongest=votes[name_]
			var data=groups[dominant];var rest=Basis.IDENTITY
			if dominant.begins_with("Arm"):rest=Basis(Vector3.BACK,PI*.5 if dominant=="ArmL" else -PI*.5)
			for corner in 3:
				var index=indices[triangle*3+corner]
				data[0].append(rest*(vertices[index]-pivots[dominant])*BODY_SCALE)
				data[1].append(rest*normals[index]);data[2].append(uv[index])
			triangles+=1
		for name_ in groups:
			var data=groups[name_]
			if data[0].is_empty():continue
			var out=[];out.resize(Mesh.ARRAY_MAX)
			out[Mesh.ARRAY_VERTEX]=data[0];out[Mesh.ARRAY_NORMAL]=data[1];out[Mesh.ARRAY_TEX_UV]=data[2]
			var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,out)
			mesh.surface_set_material(0,skin.get_active_material(surface))
			var node=MeshInstance3D.new();node.name="Goemon"+name_;node.mesh=mesh;parts[name_].add_child(node);node.owner=result
			counts[name_]=counts.get(name_,0)+data[0].size()/3
	# Keep the native normal spiky hair; workers are Goemon wearing a hat.
	var hair:MeshInstance3D=source.find_child("Hair_Normal",true,false)
	for surface in hair.mesh.get_surface_count():
		var arrays=hair.mesh.surface_get_arrays(surface)
		triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
		var hair_vertices=arrays[Mesh.ARRAY_VERTEX]
		for i in hair_vertices.size():hair_vertices[i]=(hair_vertices[i]-pivots.Head)*BODY_SCALE
		arrays[Mesh.ARRAY_VERTEX]=hair_vertices
		arrays[Mesh.ARRAY_BONES]=null;arrays[Mesh.ARRAY_WEIGHTS]=null
		var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,hair.get_active_material(surface))
		var node=MeshInstance3D.new();node.name="GoemonHairNormal";node.mesh=mesh;parts.Head.add_child(node);node.owner=result
	result.set_meta("source_triangles",triangles)
	var packed=PackedScene.new();assert(packed.pack(result)==OK)
	assert(ResourceSaver.save(packed,OUTPUT,ResourceSaver.FLAG_COMPRESS)==OK)
	print("GOEMON_WORKER_BAKED triangles=%d groups=%s skeletons=0"%[triangles,counts])
	source.free();result.free();quit()
