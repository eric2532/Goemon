extends "res://tests/forest-shrine/pet_attack_skills_test.gd"
func simultaneous_skins()->Array:
 return ["joy-ex:963","ex:1081","puk2:500","ch1:71","puk2:783"].map(func(key):return Pets.skin(key))
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 var directory="res://build/Other Files/Asset Toolkit/Sponsor Pets/Skills/"
 DirAccess.make_dir_recursive_absolute(directory)
 game.army_runtime.flush_presentation();game.forest_ui.sync();await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(directory+stem+".png")==OK,"Captured "+stem)
