extends "res://tools/render_goemon_weapon_icons.gd"
## Bake the current gameplay buildings once; the build grid uses only PNGs.
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Castle=preload("res://scripts/forest/forest_enemy_castle.gd")
const BUILDING_OUTPUT="res://assets/ui/forest/buildings/"

func _initialize():
	root.set_flag(Window.FLAG_NO_FOCUS,true);super._initialize()

func bounds_in_view(model:Node3D)->AABB:
	var bounds=super.bounds_in_view(model)
	for batch:MultiMeshInstance3D in model.find_children("*","MultiMeshInstance3D",true,false):
		for i in batch.multimesh.instance_count:
			bounds=bounds.merge(batch.global_transform*batch.multimesh.get_instance_transform(i)*batch.multimesh.mesh.get_aabb())
	if model.get_child(0).name in ["tower","cannon_tower"]:
		# Frame the recognizable roof and lookout instead of shrinking the tall column.
		bounds.position.y+=bounds.size.y*.25;bounds.size.y*=.55
	return bounds

func run():
	if DisplayServer.get_name()=="headless":
		printerr("Building portraits require the native Godot renderer");quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BUILDING_OUTPUT))
	var sources={}
	sources["res://assets/models/forest/skullpion_stone_statue.res"]=FileAccess.get_sha256("res://assets/models/forest/skullpion_stone_statue.res")
	for file in ["watchtower","cannon_tower","barracks","wall_section","gate_frame"]:
		var path=Meadow.DIR+"buildings/"+file+".glb";sources[path]=FileAccess.get_sha256(path)
	for kind in ["tower","barracks","enemy_castle","cannon_tower"]:
		var pose=Basis(Vector3.RIGHT,deg_to_rad(40 if kind=="enemy_castle" else 25))*Basis(Vector3.UP,deg_to_rad(-35))
		var model=Node3D.new();model.name=kind
		if kind=="enemy_castle":
			Castle.build(model,{"rotation":2});Castle.build_statue(model,{"rotation":2})
		else:Meadow.building(model,"watchtower" if kind=="tower" else "cannon_tower" if kind=="cannon_tower" else "barracks")
		await render_icon(kind,model,pose,BUILDING_OUTPUT)
		var image=Image.load_from_file(ProjectSettings.globalize_path(BUILDING_OUTPUT+kind+".png"))
		assert(image.get_size()==Vector2i(256,256) and image.get_used_rect().size.x>0)
	for path in sources:assert(FileAccess.get_sha256(path)==sources[path],"Building source changed during icon bake: "+path)
	var report="res://build/Other Files/Asset Toolkit/Building Icons/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report))
	var file=FileAccess.open(report+"sources.json",FileAccess.WRITE);assert(file!=null)
	file.store_string(JSON.stringify(sources,"  "));file.close()
	Meadow.parts.clear();Meadow.building_style.materials.clear();Meadow.building_style.cull_shaders.clear();Castle.pieces.clear()
	Geo.mats.clear();preload("res://scripts/forest/forest_stone_fort.gd").materials.clear()
	for i in 4:await process_frame
	print("BUILDING_ICONS_RESULT count=4 source_models_preserved=true");quit()
