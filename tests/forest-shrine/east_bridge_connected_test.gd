extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"

func check_east_il_road():
 game.tuning.invincible=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"Connected East Road"))
 var frame=Tour.Regions.frame("east_gate")
 var start:Vector2=frame.inverse()*(Vector2(552,233)*3.0)
 Tour.travel(game,Tour.outdoor_layout(get_meta("falan_venture"),"east_gate"),{"arrival":start,"yaw":PI,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 var model_before=game.model
 var map_before=game.world.map_features
 var army_before=game.army_runtime
 var bridge=game.world.find_child("IlRiverBridge",true,false)
 check(bridge!=null,"The original canal bridge is retained")
 check(game.model.terrain.width==459,"A single prepared field covers the gate and the Il countryside")
 for column in range(550,565):
  var at:Vector2=frame.inverse()*(Vector2(column,233)*3.0)
  check(game.model.terrain.disk_clear(Vector3(at.x,0,at.y),.55),"The native field has continuous access across both banks")
 game.camera_rig.yaw=PI
 Input.action_press("move_forward")
 var low=INF
 for i in 260:
  await physics_frame
  check(game.model==model_before and game.world.map_features==map_before and game.army_runtime==army_before,"Crossing the bridge never reloads the world or army")
  var source:Vector2=frame*map_position()/3.0
  if source.x>553 and source.x<560:low=minf(low,game.player.position.y/game.model.falan_scale)
  if source.x>562:break
 Input.action_release("move_forward")
 check((frame*map_position()/3.0).x>561 and low>4,"Walking reaches the Il bank above the water")
 check(game.world.find_child("IlRiverBridge",true,false)==bridge,"The same bridge node stays alive")
 check(is_equal_approx(game.camera_rig.yaw,PI),"The bridge never rotates or resets the camera")
 var count=game.model.enemies.size()
 var handles=game.army_runtime.handles.duplicate()
 game.camera_rig.yaw=0
 Input.action_press("move_forward")
 for i in 260:
  await physics_frame
  if (frame*map_position()/3.0).x<552:break
 Input.action_release("move_forward")
 check((frame*map_position()/3.0).x<553,"Walking back crosses the same connected bridge")
 check(game.model==model_before and game.world.map_features==map_before,"The return crossing also preserves the world")
 check(count>0 and handles.keys().all(func(id):return game.army_runtime.handles.get(id)==handles[id]),"Existing native monster handles survive both sides of the crossing")
 var mouth=Tour.Regions.site_links("east_gate").filter(func(link):return link.site==11003)
 check(mouth.size()==1,"The joined map includes the original Habaru entrance")
 check(game.world.find_child("Connected_il_village",true,false)!=null,"The same map keeps Il village reachable")
 if DisplayServer.get_name()!="headless":
  var center:Vector3=game.model.world_point(frame.inverse()*(Vector2(556,233)*3.0))
  await shot("Connected East Road/canal-bridge",center+Vector3(0,18,-45),center+Vector3.UP*2,64,true)
  var samples=[]
  var previous=Time.get_ticks_usec()
  for i in 90:
   await process_frame
   var now=Time.get_ticks_usec()
   samples.append((now-previous)/1000.0);previous=now
  samples.sort()
  print("CONNECTED_BRIDGE_FRAME_SAMPLE units=",game.model.enemies.size()," p95_ms=",samples[85]," max_ms=",samples.back())
 print("EAST_BRIDGE_CONNECTED_RESULT failures=",errors)
