extends "res://tests/forest-shrine/venoa_bear_road_test.gd"
const RECOVERY="res://build/Other Files/Asset Toolkit/Falan Road Recovery/"
var review_checks=0

func check(ok:bool,message:String):
 review_checks+=1
 super.check(ok,message)

func position_at(p:Vector2):
 await super.position_at(p)
 for i in 4:await physics_frame

func shot(name_:String,eye:Vector3,target:Vector3,fov:float,refresh_army:bool=false):
 if DisplayServer.get_name()=="headless":return
 var stage="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
 var file=RECOVERY+stage+"/"+name_.replace("/","-")+".png"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECOVERY+stage))
 game.ui.hide();game.set_process(false)
 root.grab_focus()
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov
 camera.reset_physics_interpolation()
 if refresh_army:game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(file)==OK,"Captured "+name_)
 game.set_process(true);game.ui.show()

func check_venoa_undersea():
 game.tuning.invincible=true
 game.settings.forest_level_up_cards=false
 var saved=JSON.stringify(get_meta("falan_venture"))
 var scale_:float=game.model.falan_scale
 await shot("falan-office",Vector3(-220,18,-78)*scale_,Vector3(-252,8,-116)*scale_,65)
 await shot("falan-gardens",Vector3(-330,23,55)*scale_,Vector3(-350,5.5,34)*scale_,62)
 if "--baseline" not in OS.get_cmdline_user_args():check_tree_batches()
 await super.check_venoa_undersea()
 if "--baseline" not in OS.get_cmdline_user_args():
  await open_area("south_lakes")
  check_tree_batches()
  check(game.world.find_children("Foliage_*","Node3D",true,false).is_empty(),"The source road has no generic Goemon ambient dressing")
  check(game.world.find_children("terraced_mountain_*","MultiMeshInstance3D",true,false).is_empty(),"The source road has no old mountain ring")
  for id in [11000,11001,11002]:
   Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Vector2.ZERO,"yaw":0.0,"velocity":Vector3.ZERO})
   for i in 6:await physics_frame
   var expected:int=Tour.Regions.Sites.VENOA_BEARS[id].size()
   check(game.model.enemies.values().filter(func(row):return row.get("skin")==Habaru.VENOA_BEAR_SKIN and game.army_runtime.handles.has(row.id)).size()==expected,"Recovered scenery preserves every native bear on "+str(id))
  check(JSON.stringify(get_meta("falan_venture"))==saved,"Recovery preserves the saved adventure")
 print("FALAN_ROAD_SCENERY_RESULT checks=",review_checks," failures=",errors)

func check_tree_batches():
 var count=0
 for batch in game.world.find_children("*","MultiMeshInstance3D",true,false):
  if not batch.has_meta("crossgate_tree_part"):continue
  count+=batch.multimesh.instance_count
  if batch.get_meta("crossgate_tree_part")=="Canopy":
   check(batch.material_override is ShaderMaterial and batch.material_override.get_shader_parameter("use_source_paint")==true,"Recovered canopies keep shared wind and native paint")
   check(batch.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3==5980,"Every original leaf triangle is retained")
 print("CROSSGATE_TREE_INSTANCES area=",game.model.falan_area," instances=",count)
 check(count>100,"Original-style 3D trees replace generic tree batches: "+game.model.falan_area+" count="+str(count))
