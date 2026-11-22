extends "res://tests/forest-shrine/venoa_bear_road_test.gd"
const REVIEW="res://build/Other Files/Asset Toolkit/Venoa Scenery Recovery/"
var review_checks=0

func check(ok:bool,message:String):
 review_checks+=1
 super.check(ok,message)

func shot(name_:String,eye:Vector3,target:Vector3,fov:float,refresh_army:bool=false):
 if DisplayServer.get_name()=="headless":return
 await super.shot(name_,eye,target,fov,refresh_army)
 var stage="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+stage))
 check(DirAccess.copy_absolute(ProjectSettings.globalize_path(OUT+name_+".png"),
  ProjectSettings.globalize_path(REVIEW+stage+"/"+name_.replace("/","-")+".png"))==OK,"Saved matched scenery view")

func check_venoa_undersea():
 if "--baseline" not in OS.get_cmdline_user_args():check_crag_clearance()
 await super.check_venoa_undersea()
 Tour.travel(game,Tour.Indoor.layout(11001),{"arrival":Vector2(-51,-12),"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 8:await physics_frame
 game.tuning.invincible=true
 game.player.set_physics_process(false)
 game.set_physics_process(false)
 game.army_runtime.set_physics_process(false)
 game.army_runtime.set_process(false)
 var scale_:float=game.model.falan_scale
 await shot("Venoa Bear Road/cave-stones",Vector3(-43,5,-5)*scale_,Vector3(-55,3,-18)*scale_,65,true)
 await shot("Venoa Bear Road/cave-pool",Vector3(-50,7,-22)*scale_,Vector3(-42,1,14)*scale_,68,true)
 var rock=game.world.find_child("ArchivedCaveRockWalls",true,false)
 check(rock!=null,"The original cave shell remains present")
 if "--baseline" not in OS.get_cmdline_user_args():check_backing_clearance()
 if "--baseline" not in OS.get_cmdline_user_args():
  var crags=game.world.find_child("VenoaStoneCrags",true,false)
  check(crags is MeshInstance3D and crags.mesh.get_surface_count()==1,"Jagged stone clusters use one static surface")
  if crags is MeshInstance3D:
   var arrays=crags.mesh.surface_get_arrays(0)
   print("VENOA_STONE_TRIANGLES ",arrays[Mesh.ARRAY_INDEX].size()/3," vertices=",arrays[Mesh.ARRAY_VERTEX].size())
 check(game.model.enemies.values().filter(func(row):return row.get("skin")==Habaru.VENOA_BEAR_SKIN).size()==40,"B2 keeps all forty ordinary native bears")
 game.set_physics_process(true)
 game.player.set_physics_process(true)
 game.army_runtime.set_physics_process(true)
 game.army_runtime.set_process(true)
 if "--baseline" not in OS.get_cmdline_user_args():await check_venoa_cave()
 print("VENOA_SCENERY_REVIEW checks=",review_checks," failures=",errors," nodes=",root.get_tree().get_node_count()," resources=",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))

func check_crag_clearance():
 for along_x in [true,false]:
  for open_before in [true,false]:
   var mesh=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
   Entrances.cave_crags(mesh,Vector2.ZERO,along_x,open_before,3)
   var stone=mesh.commit()
   var inward=(Vector2.UP if along_x else Vector2.LEFT)*(1.0 if open_before else -1.0)
   var tangent=Vector2.RIGHT if along_x else Vector2.DOWN
   var clear=true
   for point:Vector3 in stone.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
    var p=Vector2(point.x,point.z)
    if not point.is_finite() or p.dot(inward)>.001 or p.dot(tangent)<-.001 or p.dot(tangent)>3.001 or point.y>=Tour.Indoor.CEILING_HEIGHT:clear=false
   check(clear,"Stone geometry stays behind the original wall and below the roof in every direction")

func check_venoa_floor(bears:int,npcs:int):
 await super.check_venoa_floor(bears,npcs)
 check_backing_clearance()

func check_backing_clearance():
 var rock=game.world.find_child("ArchivedCaveRockWalls",true,false)
 var info=Tour.Indoor.floor_info(game.model.falan_floor)
 var bits:PackedByteArray=info[2].hex_decode()
 var pools=Tour.Indoor.RoomArt.pool_tiles(game.model.falan_floor,info[0])
 var arrays=rock.mesh.surface_get_arrays(0)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var clear=true
 for i in range(0,points.size(),3):
  if uvs[i]!=Vector2.ZERO or uvs[i+1]!=Vector2.ZERO or uvs[i+2]!=Vector2.ZERO:continue
  var center=(points[i]+points[i+1]+points[i+2])/3.0
  var cell=Vector2i(((Vector2(center.x,center.z)-info[1])/3.0).round())
  if Tour.Indoor.open_cell(bits,info[0],cell.x,cell.y) or Tour.Indoor.RoomArt.is_pool(pools,info[0],cell):clear=false
 check(clear,"Recessed cave backing closes corners without crossing original floor or water")
