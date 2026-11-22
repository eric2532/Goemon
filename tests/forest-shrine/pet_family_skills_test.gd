extends "res://tests/forest-shrine/pet_attack_skills_test.gd"
func simultaneous_skins()->Array:
 var result=[];var groups=[]
 for i in range(82,Pets.COUNT):
  if Pets.category(i) not in groups:groups.append(Pets.category(i));result.append(i)
  if result.size()==5:break
 return result
func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 var directory="res://build/Other Files/Asset Toolkit/Cross Gate Pet Expansion/Skills/"
 DirAccess.make_dir_recursive_absolute(directory)
 game.army_runtime.flush_presentation();game.forest_ui.sync();await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(directory+name_+".png")==OK,"Captured "+name_)
