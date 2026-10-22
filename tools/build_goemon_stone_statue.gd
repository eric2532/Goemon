extends SceneTree
## Bake the existing Goemon gameplay idle into static scenery; master stays read-only.
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
var result:Node3D
func _initialize():run.call_deferred()
func run():
	if DisplayServer.get_name()=="headless":printerr("Statue bake requires the native renderer");quit(1);return
	var source=HeroModel.new();root.add_child(source);source.ronin_scarf.hide()
	var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(4,4,-8);camera.look_at(Vector3.UP*1.4);camera.current=true
	for i in 60:source.animate(1.0/60,0,true,0,0,false,0,false);source.sync_skeleton()
	source.set_process(false)
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	result=Node3D.new();result.name="GoemonStoneStatue";root.add_child(result)
	var first=true;var box=AABB();var vertices=0
	for part in source.find_children("*","MeshInstance3D",true,false):
		if not part.is_visible_in_tree() or part.mesh==null:continue
		var mesh:Mesh=part.bake_mesh_from_current_skeleton_pose() if part.skin!=null else part.mesh.duplicate()
		var node=MeshInstance3D.new();node.name=part.name;node.mesh=mesh
		node.transform=source.global_transform.affine_inverse()*part.global_transform;result.add_child(node);node.owner=result
		var material=Fort.material(Color("a0a59a"),false).duplicate()
		for slot in mesh.get_surface_count():
			vertices+=mesh.surface_get_array_len(slot)
			var old=part.get_active_material(slot)
			var stone=material.duplicate()
			if old is StandardMaterial3D and old.albedo_texture!=null:
				stone.set_shader_parameter("carved_detail",true);stone.set_shader_parameter("detail_texture",old.albedo_texture)
			node.set_surface_override_material(slot,stone)
		node.material_override=material if mesh.get_surface_count()==1 and part.get_active_material(0).albedo_texture==null else null
		var bounds=node.transform*mesh.get_aabb();box=bounds if first else box.merge(bounds);first=false
	var scale_=Profile.STATUE_HEIGHT/box.size.y
	# Scale static vertex data via node transforms, preserving the exact native mesh and UVs.
	for node in result.get_children():
		node.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_),Vector3(0,-box.position.y*scale_,0))*node.transform
	result.set_meta("source_model","res://assets/models/characters/kai.glb");result.set_meta("source_sha256",FileAccess.get_sha256("res://assets/models/characters/kai.glb"))
	result.set_meta("idle_seconds",1.0);result.set_meta("source_vertices",vertices)
	var packed=PackedScene.new();var error=packed.pack(result);assert(error==OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models/forest"))
	error=ResourceSaver.save(packed,"res://assets/models/forest/goemon_stone_statue.scn",ResourceSaver.FLAG_COMPRESS);assert(error==OK)
	print("GOEMON_STATUE_BAKED static_meshes=%d vertices=%d height=%.1f"%[result.get_child_count(),vertices,Profile.STATUE_HEIGHT])
	quit()
