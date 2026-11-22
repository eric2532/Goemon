extends "res://tests/forest-shrine/sokia_fruit_relief_test.gd"
const CROWN_REVIEW="res://build/Other Files/Asset Toolkit/Sokia Crown Shapes/"
func shot(label_:String,eye:Vector3,target:Vector3,fov:float,_refresh:bool=false):
 if DisplayServer.get_name()=="headless":return
 var before=paused;paused=true;game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for frame in 3:await process_frame
 RenderingServer.force_draw()
 var folder=CROWN_REVIEW+("before/" if "--shape-before" in OS.get_cmdline_user_args() else "after/")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 check(root.get_texture().get_image().save_png(folder+label_+".png")==OK,"Captured "+label_)
 game.set_process(true);game.ui.show();paused=before
func check_east_il_road():
 await super.check_east_il_road()
 if not "--shape-before" in OS.get_cmdline_user_args():
  check(Sokia.Details.Data.CLIFF_CROWNS[12557].size()==9,"Every solid crag receives its original-art crown sample")
  check(Sokia.Details.Data.CLIFF_CROWNS[12557].max()-Sokia.Details.Data.CLIFF_CROWNS[12557].min()>.1,"The original stepped cliff crown replaces repeated random heights")
  for shape in Sokia.Details.Data.FRUIT_SHAPES[11204]:
   check(shape.size()>4 and shape.all(func(p):return p.z>0.0),"Native fruit row profiles produce closed curved lobes")
 print("SOKIA_CROWN_RESULT checks=",checks," failures=",errors)
func open_area(area:String):
 await super.open_area(area)
 if area=="kili" and not "--shape-before" in OS.get_cmdline_user_args():
  preload("res://scripts/forest/forest_wind_meadow_art.gd").refresh_foliage(game.world,{Vector2i.ZERO:true})
  check(game.world.find_child("FreyjaFoliage",true,false)==null and game.world.find_children("Foliage_*","Node3D",true,false).is_empty(),"Kili no longer adds or refreshes the old meadow scenery")
