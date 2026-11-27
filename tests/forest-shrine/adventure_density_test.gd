extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Play Goemon --script this file -- --frontier-patrols

func check_frontier_patrols():
 game.tuning.invincible=true
 for area in ["east_gate","east_coast","north_coast"]:
  var venture:Dictionary=get_meta("falan_venture")
  if area=="east_gate":Tour.travel(game,Tour.outdoor_layout(venture,area),{"arrival":Vector2(3,246),"yaw":PI})
  else:await open_area(area)
  for i in 8:await physics_frame
  game.paused=true
  var runtime=game.army_runtime
  runtime.finish_integration()
  var waves=game.model.waves
  var original:int=waves.PatrolData.POSTS[area].size()
  check(waves.patrol_posts.size()>=original*2.5,"The route prepares about three times as many separated patrol posts")
  for i in waves.patrol_posts.size()+1:waves.tick(.25,game.model.world_point(Vector2(3,246)))
  runtime.import_arrivals()
  var count:int=game.model.enemies.size()
  check(count>=original*1.8 and count<=waves.ACTIVE_CAP,"Denser patrols actually populate clear land within the native cap")
  check(runtime.handles.size()==count,"Every route monster is owned by the existing native runtime")
  if area=="east_gate":check(game.model.enemies.values().all(func(row):return row.pos.z>Tour.Frontier.COMBAT_EDGE*game.model.falan_scale),"Larger packs preserve the existing safe gate approach")
  var ids=game.model.enemies.keys().slice(0,6)
  for id in ids:runtime.damage_enemy(id,100000)
  runtime.dispatch_events()
  game.paused=false
  for i in 300:await physics_frame
  check(ids.all(func(id):return not runtime.handles.has(id)),"Every defeated patrol retires its old native handle")
  check(game.model.enemies.size()>=count,"Defeated patrol posts refill through the existing native arrival queue at the slower swarm rate")
  print("ADVENTURE_DENSITY ",area," original_posts=",original," prepared=",waves.patrol_posts.size()," live=",count)
  if DisplayServer.get_name()!="headless" and area=="north_coast":
   var s:float=game.model.falan_scale
   await shot("Habaru Combat Fix/north-coast-patrols",Vector3(65,65,80)*s,Vector3(0,6,0)*s,65,true)
 var timings=[]
 for i in 180:
  var start=Time.get_ticks_usec()
  await physics_frame
  timings.append(float(Time.get_ticks_usec()-start)/1000.0)
 timings.sort()
 print("ADVENTURE_FRAME_SAMPLE units=",game.model.enemies.size()," physics_interval_p95_ms=",timings[int(timings.size()*.95)]," max_ms=",timings[-1])
 print("ADVENTURE_DENSITY_RESULT failures=",errors)
