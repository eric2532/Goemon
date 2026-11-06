extends SceneTree
## Freeze the saved rigid model into one stone surface; never edit the boss source.
const SOURCE="res://assets/models/enemies/skullpion.glb"
const OUTPUT="res://assets/models/forest/skullpion_stone_statue.res"
const CLIP="Castle_Cling"
func _initialize():run.call_deferred()
func run():
	var hash_=FileAccess.get_sha256(SOURCE)
	var source=load(SOURCE).instantiate();root.add_child(source)
	var player:AnimationPlayer=source.find_child("AnimationPlayer",true,false)
	assert(player.has_animation(CLIP));player.play(CLIP);player.seek(0,true);player.pause()
	var parts=source.find_children("*","MeshInstance3D",true,false)
	assert(parts.size()==22)
	var bounds=AABB();var first=true;var surfaces=[];var cell=Vector2i.ONE;var pages={};var textures=[]
	for part:MeshInstance3D in parts:
		assert(part.skin==null)
		var box=part.global_transform*part.mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
		for slot in part.mesh.get_surface_count():
			var material:StandardMaterial3D=part.get_active_material(slot)
			var pixels:Image
			if material.albedo_texture!=null:
				pixels=material.albedo_texture.get_image()
				if pixels.is_compressed():assert(pixels.decompress()==OK)
				pixels.convert(Image.FORMAT_RGBA8)
			else:
				pixels=Image.create(1,1,false,Image.FORMAT_RGBA8);pixels.fill(material.albedo_color)
			cell=cell.max(pixels.get_size()+Vector2i(2,2))
			var key=pixels.get_data()
			if not pages.has(key):pages[key]=textures.size();textures.append(pixels)
			surfaces.append({"part":part,"slot":slot,"tile":pages[key]})
	var columns=ceili(sqrt(textures.size()));var dimensions=cell*Vector2i(columns,ceili(float(textures.size())/columns))
	var atlas=Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8);atlas.fill(Color.WHITE)
	for i in textures.size():atlas.blit_rect(textures[i],Rect2i(Vector2i.ZERO,textures[i].get_size()),Vector2i(i%columns,i/columns)*cell+Vector2i.ONE)
	var scale_=28.0/bounds.size.x
	var fit=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_),-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*scale_)
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles=0;var part_boxes:Array[AABB]=[]
	for part:MeshInstance3D in parts:part_boxes.append(fit*part.global_transform*part.mesh.get_aabb())
	for i in surfaces.size():
		var entry:Dictionary=surfaces[i];var part:MeshInstance3D=entry.part;var pixels:Image=textures[entry.tile]
		var at=Vector2i(entry.tile%columns,entry.tile/columns)*cell+Vector2i.ONE
		var arrays=part.mesh.surface_get_arrays(entry.slot);var transform_=fit*part.global_transform
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];assert(indices.size()%3==0);triangles+=indices.size()/3
		for index in indices:
			var uv=Vector2(.5,.5) if arrays[Mesh.ARRAY_TEX_UV]==null else arrays[Mesh.ARRAY_TEX_UV][index]
			surface.set_uv((Vector2(at)+uv*Vector2(pixels.get_size()))/Vector2(dimensions))
			surface.set_normal((transform_.basis.inverse().transposed()*arrays[Mesh.ARRAY_NORMAL][index]).normalized())
			surface.add_vertex(transform_*arrays[Mesh.ARRAY_VERTEX][index])
	var mesh=surface.commit();assert(mesh.get_surface_count()==1 and mesh.surface_get_array_len(0)==triangles*3)
	var stone=preload("res://scripts/forest/forest_stone_fort.gd").material(Color("a9a394"),false).duplicate()
	stone.set_shader_parameter("carved_detail",true);stone.set_shader_parameter("detail_texture",ImageTexture.create_from_image(atlas))
	mesh.surface_set_material(0,stone)
	mesh.set_meta("source_model",SOURCE);mesh.set_meta("source_sha256",hash_);mesh.set_meta("source_clip",CLIP)
	mesh.set_meta("source_triangles",triangles);mesh.set_meta("source_fit",fit);mesh.set_meta("part_boxes",part_boxes)
	mesh.set_meta("source_surfaces",surfaces.size());mesh.set_meta("texture_pages",textures.size())
	assert(FileAccess.get_sha256(SOURCE)==hash_)
	assert(ResourceSaver.save(mesh,OUTPUT,ResourceSaver.FLAG_COMPRESS)==OK)
	print("SKULLPION_STATUE_BAKED parts=",parts.size()," triangles=",triangles," surfaces=1 bounds=",mesh.get_aabb()," atlas=",dimensions)
	source.free();quit()
