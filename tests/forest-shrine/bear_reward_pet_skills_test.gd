extends "res://tests/forest-shrine/pet_attack_skills_test.gd"
func simultaneous_skins()->Array:
 return ["puk2:1318","puk3:48","ch1:331","ch1:528","puk3:54"].map(func(key):return Pets.skin(key))
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 var directory="res://build/Other Files/Asset Toolkit/Bear Challenge Pets/A Rank Recheck/Skills/"
 DirAccess.make_dir_recursive_absolute(directory)
 game.army_runtime.flush_presentation();game.forest_ui.sync();await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(directory+stem+".png")==OK,"Captured "+stem)
