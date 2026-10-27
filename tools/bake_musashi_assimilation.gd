extends SceneTree
## Import only the added clips; no duplicate body meshes ship with the library.
func _initialize():
	var document=GLTFDocument.new();var state=GLTFState.new()
	var error=document.append_from_file(ProjectSettings.globalize_path("res://build/Other Files/Asset Toolkit/Musashi Assimilation/motion.glb"),state)
	assert(error==OK)
	var scene=document.generate_scene(state,30,false,false)
	var player=scene.find_child("AnimationPlayer",true,false)
	assert(player!=null)
	var library=AnimationLibrary.new()
	for name in player.get_animation_list():
		if str(name).begins_with("Assimilation_"):
			var animation=player.get_animation(name)
			animation.loop_mode=Animation.LOOP_NONE
			library.add_animation(str(name).trim_prefix("Assimilation_"),animation)
	assert(library.get_animation_list().size()==6)
	assert(ResourceSaver.save(library,"res://assets/characters/recovered_musashi/assimilation/motions.res",ResourceSaver.FLAG_BUNDLE_RESOURCES)==OK)
	scene.free()
	print("Baked six original Musashi ability streams into a shared AnimationLibrary")
	quit()
