extends "res://tests/forest-shrine/pet_family_skills_test.gd"

func simultaneous_skins()->Array:
 return [Pets.skin("original:2976"),Pets.skin("ex:772"),Pets.skin("original:2853"),Pets.skin("ch1:886"),61]
func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 var directory="res://build/Other Files/Asset Toolkit/Pet Size Adjustments/"
 DirAccess.make_dir_recursive_absolute(directory)
 game.army_runtime.flush_presentation();game.forest_ui.sync();await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(directory+name_+".png")==OK,"Captured "+name_)
