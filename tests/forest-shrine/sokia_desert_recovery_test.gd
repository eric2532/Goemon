extends "res://tests/forest-shrine/kili_recovery_test.gd"
const Sokia=preload("res://scripts/forest/forest_sokia_scenery.gd")
const SOKIA_REVIEW="res://build/Other Files/Asset Toolkit/Sokia Desert Recovery/"
func review_folder()->String:return SOKIA_REVIEW
func shot(label_:String,eye:Vector3,target:Vector3,fov:float,_refresh:bool=false):
 if DisplayServer.get_name()=="headless":return
 var before=paused;paused=true
 game.ui.hide();game.set_process(false)
 if label_ in ["great-wind-cave-road","great-wind-cave-east"]:
  eye*=game.model.falan_scale;target*=game.model.falan_scale
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for frame in 3:await process_frame
 RenderingServer.force_draw()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOKIA_REVIEW+"after"))
 check(root.get_texture().get_image().save_png(SOKIA_REVIEW+"after/"+label_.replace("/","-")+".png")==OK,"Captured "+label_)
 game.set_process(true);game.ui.show();paused=before

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var saved=JSON.stringify(get_meta("falan_venture"))
 for area in Sokia.MASKS:
  await open_area(area)
  var terrain=game.model.terrain
  check(terrain.mask_texture()==Sokia.MASKS[area] and not terrain.uses_baked_apron(),"Native Sokia masks replace the meadow and its apron in "+area)
  preload("res://scripts/forest/forest_wind_meadow_art.gd").refresh_foliage(game.world,{Vector2i.ZERO:true})
  check(game.world.find_children("Foliage_*","Node3D",true,false).is_empty(),"Construction refreshes cannot reinsert meadow plants in "+area)
  check(game.world.find_child("FreyjaFoliage",true,false)==null,"No meadow scatter or terraced mountain backdrop is added to "+area)
  var expected=0
  for row in Sokia.Data.SCENERY[area]:
   if Sokia.Data.GRAPHICS.has(row[1]) and not Sokia.solid_building(area,row[1],row[0]):expected+=1
  var instances=0
  for batch in game.world.find_children("SokiaNativeProp_*","MultiMeshInstance3D",true,false):
   instances+=batch.multimesh.instance_count
   check(batch.material_override==Sokia.material,"Native props share one source-art shader")
  check(instances==expected,"Every original native-art prop is present in "+area)
  var solid_buildings=game.world.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.get_meta("sokia_source_solid",false))
  var source_buildings=Sokia.Data.SCENERY[area].filter(func(r):return Sokia.solid_building(area,r[1],r[0]))
  check(solid_buildings.size()==source_buildings.size(),"Source houses use the existing solid building kit rather than duplicate image cards in "+area)
  check(game.model.falan_frontier_plan.filter(func(row):return row[0]=="sokia_source_collision").size()==Sokia.Data.BLOCKS[area].size(),"Original blocked tile rectangles reach the native model in "+area)
  check(game.world.find_children("*","StaticBody3D",true,false).filter(func(body):return body.get_meta("sokia_source_collision",false)).size()==Sokia.Data.BLOCKS[area].size(),"Original blocked rectangles also reach player physics in "+area)
  var cliff=game.world.find_child("ArchivedCliffForms",true,false)
  if cliff!=null:
   check(not cliff.material_override.get_shader_parameter("cliff_crags"),"Sokia cliffs retain sandy source paint rather than Venoa moss")
   check(cliff.material_override.get_shader_parameter("entrance_cut_count")==Entrances.Archive.MOUTHS.get(area,{}).size(),"Restored cliffs leave every original cave mouth visible in "+area)
  print("SOKIA_REGION ",area," anchors=",Sokia.Data.SCENERY[area].size()," native_art=",instances," collision_rectangles=",Sokia.Data.BLOCKS[area].size())
  if area in ["sokia_coast","sokia_desert"]:
   var cell=Vector2(285,315) if area=="sokia_coast" else Vector2(414,298)
   var local:Vector2=Tour.Regions.frame(area).inverse()*(cell*3)
   var point=game.model.world_point(local)
   await shot(area,point+Vector3(55,68,70),point,62)
 await check_kili_coast_road()
 if errors:return
 await check_great_wind_road()
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Sokia scenery recovery preserves the saved adventure")
 print("SOKIA_DESERT_RESULT checks=",checks," failures=",errors)
