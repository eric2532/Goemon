extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Play Goemon --script this file -- --venoa-undersea / --venoa-cave.

func check_venoa_undersea():
 game.tuning.invincible=true
 game.settings.forest_level_up_cards=false
 await open_area("south_lakes")
 check_undersea_surroundings("south_lakes")
 var source=Entrances.UNDERSEA_MOUTHS
 var frame=Tour.Regions.frame("south_lakes").inverse()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for key in source.VENOA_ROADS:
  var path:Array=source.VENOA_ROADS[key]
  var blocked=[]
  for i in range(1,path.size()):
   var from:Vector2=frame*(Vector2(path[i-1])*3.0)
   var to:Vector2=frame*(Vector2(path[i])*3.0)
   var pose:Transform3D=game.player.global_transform
   pose.origin=game.model.world_point(from,.32)
   if game.player.test_move(pose,game.model.world_point(to,.32)-pose.origin):blocked.append(path[i])
  check(blocked.is_empty(),"The complete source road has capsule clearance: "+key+" blocked="+str(blocked))
  print("VENOA_ROAD cells=",path.size()," blocked=",blocked.size()," route=",key)
 if DisplayServer.get_name()!="headless":
  var clutter=0
  var mask:Image=game.model.terrain.mask_texture().get_image()
  for chunk in game.world.find_children("Foliage_*","Node3D",true,false):
   for batch in chunk.get_children():
    if batch is not MultiMeshInstance3D:continue
    for i in batch.multimesh.instance_count:
     var point:Vector3=batch.multimesh.get_instance_transform(i).origin+chunk.position
     if not Tour.Frontier.east_scatter_clear(mask,game.model.terrain.mask_origin(),Vector2(point.x,point.z)):clutter+=1
  check(clutter==0,"Ambient scenery leaves the original southern roads clear")
  print("VENOA_ROAD ambient_road_clutter=",clutter)
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"Venoa Bear Road"))
  for cell:Vector2 in [Vector2(420,380),Vector2(370,420)]:
   var at:Vector3=game.model.world_point(frame*(cell*3.0))
   await shot("Venoa Bear Road/road-%d-%d"%[cell.x,cell.y],at+Vector3(30,30,36),at+Vector3.UP*2,64)
  var cell=Vector2i(343,497)
  var at:Vector3=game.model.world_point(frame*(Vector2(cell)*3.0))
  var back:Vector2=frame.basis_xform(Entrances.Archive.MOUTHS.south_lakes[cell]).normalized()
  await shot("Venoa Bear Road/road-343-497",at-Vector3(back.x,0,back.y)*20+Vector3(0,8,0),at+Vector3.UP*2.7,64)
 game.set_physics_process(true)
 game.player.set_physics_process(true)
 await super.check_venoa_undersea()

func check_venoa_floor(bears:int,npcs:int):
 await super.check_venoa_floor(bears,npcs)
 var pack:Array=game.model.enemies.values().filter(func(row):return row.get("skin")==Habaru.VENOA_BEAR_SKIN)
 check(pack.all(func(row):return game.army_runtime.handles.has(row.id)),"Every crowded cave bear uses the native runtime")
 var native_count=game.army_runtime.handles.size()
 for i in 5:game.model.waves.tick_venoa_bears(Tour.Regions.Sites.VENOA_BEARS.get(game.model.falan_floor,[]))
 check(game.army_runtime.handles.size()==native_count,"Repeated population ticks do not duplicate bears")
 if bears>0:
  var killed:Dictionary=pack.back()
  game.army_runtime.apply_hit(game.army_runtime.handles[killed.id],{"amount":killed.max_hp*2,"direction":Vector3.FORWARD})
  for i in 4:await physics_frame
  check(get_meta(Habaru.VENOA_SLAIN,{}).has(killed.venoa_bear_slot),"An added bear keeps the shared slain-slot persistence")
  # Restore this fixture's population so the inherited round-trip count checks remain useful.
  get_meta(Habaru.VENOA_SLAIN).erase(killed.venoa_bear_slot)
