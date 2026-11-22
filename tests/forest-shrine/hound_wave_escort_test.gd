extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Battle=preload("res://tests/forest-shrine/large_army_benchmark.gd").Battle
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUT="res://build/Other Files/Asset Toolkit/Cross Gate Hounds/Fast Return/"
var army
var peak_enemies=0
var sampled_frames:Array[float]=[]
var native_start:int
var order_frames:Array[float]=[]
var previous_order_frame:int
var focused_order_frames:int

func run():
 var large="--large" in OS.get_cmdline_user_args()
 var orders="--orders" in OS.get_cmdline_user_args()
 var layout=load("res://scripts/forest/forest_map_document.gd").new()
 if large:layout.load_wind_meadow_large()
 else:layout.load_wind_meadow()
 set_meta("forest_custom_layout",layout.data)
 set_meta("forest_fighter",1)
 game=Battle.new();game.settings_path=cfg;root.add_child(game);current_scene=game
 await frames(4)
 if "--mantises" in OS.get_cmdline_user_args():game.settings.forest_pet_loadout=Pets.sanitized([Pets.key(29),Pets.key(31),Pets.key(32),Pets.key(33),Pets.key(36)])
 army=game.army_runtime;army.record_events=true
 game.tuning.invincible=true
 game.player.set_auto_attack(false)
 game.player.smoke_mode=true
 game.camera_rig.yaw=0
 game.camera_rig.set_process(false)
 game.start_wave()
 var start=Vector3(-150,0,127)
 start.y=game.model.surface_height(start.x,start.z)+.15
 game.player.position=start
 send_key(KEY_P)
 await observe(300)
 army.native.simulation_profile(true)
 army.native.query_stats(true)
 native_start=Time.get_ticks_usec()
 check(pack().size()==5 and game.model.waves.spawned>0,"P summons five selected pets while the ordinary wave spawns")
 var before:Vector3=game.player.position
 Input.action_press("sprint")
 game.player.smoke_move=Vector2.RIGHT
 await observe(168)
 report("sprint")
 check(flat(game.player.position-before).length()>30 and covered(18,4,3) and spread(24).x==5,"The full pack keeps up at sprint speed and spreads across the available ground")
 await capture("Sprint")
 game.player.smoke_move=Vector2.UP
 await observe(72)
 var midpoint=spread(18)
 print("HOUND_TURN midpoint=",midpoint)
 if large:check(midpoint.x>=4 and midpoint.y>=3,"Large sprint turn keeps hounds on several sides while changing direction")
 await observe(72)
 report("turn")
 check(covered(18,4,3),"Keep a spread around the player after a sprint turn")
 Input.action_release("sprint")
 game.player.smoke_move=Vector2.ZERO
 await capture("Sprint turn")
 var target=closest_enemy()
 var hunt_seconds=0.0
 if orders:
  var hunt_start:Vector3=game.player.position
  army.order_hounds(army.HoundOrder.ATTACK)
  for i in 150:
   if hits()>0:break
   await observe(6)
   hunt_seconds+=.1
  check(flat(game.player.position-hunt_start).length()<3,"The pack hunts while Goemon stays in place")
 else:
  for i in 600:
   if i%12==0:target=closest_enemy()
   if target==Vector3.INF or hits()>0:break
   game.player.smoke_move=flat(target-game.player.position).normalized() if flat(target-game.player.position).length()>8 else Vector2.ZERO
   await physics_frame
  game.player.smoke_move=Vector2.ZERO
  if hits()==0 and target!=Vector3.INF:
   # Stage the player beside a live wave group if the direct run hit terrain.
   for i in 8:
    var angle=TAU*i/8
    var point=target+Vector3(cos(angle),0,sin(angle))*9
    point.y=game.model.surface_height(point.x,point.z)+.15
    if not game.model.waves.navigation.move_clear(point,1):continue
    game.player.position=point;game.player.velocity=Vector3.ZERO
    print("HOUND_WAVE staged encounter at ",point)
    for tick in 540:
     if hits()>0:break
     await physics_frame
    break
 var fight_target=first_hound_hit()
 report("fight")
 if orders:
  var claimed={}
  for skin in Pets.COUNT:
   var row:Dictionary=army.unit_state(army.handles.get(army.HOUND_ID-skin,0))
   var foe:int=row.get("target_id",0)
   if foe>0:claimed[foe]=claimed.get(foe,0)+1
  print("HOUND_WAVE_ORDER_TARGETS ",claimed)
 await capture("Fight")
 if not orders:
  var retreat=Vector2.UP if target==Vector3.INF else flat(game.player.position-target).normalized()
  Input.action_press("sprint")
  game.player.smoke_move=retreat
  await observe(210)
  Input.action_release("sprint")
  game.player.smoke_move=Vector2.ZERO
 check(fight_target>0,"The pack hits an enemy spawned by the wave")
 var fight_alive:bool=army.valid(army.handles.get(fight_target,0))
 check(fight_target>0 and (not fight_alive or chasing(fight_target)),"Hounds stay committed to a living target before recall" if orders else "A living wave target keeps its guards when Goemon leaves")
 var foes={}
 for skin in Pets.COUNT:
  var row:Dictionary=army.unit_state(army.handles.get(army.HOUND_ID-skin,0))
  var foe:int=row.get("target_id",0)
  if foe>0:foes[foe]=true
 # Finish any long fights after checking retention, so recall has a measured start.
 if orders:
  send_key(KEY_Z)
  check(army.hound_order==army.HoundOrder.RETURN,"Z sends the full pack a return order during the live wave")
 else:
  if not foes.is_empty():print("HOUND_WAVE staged finishing blows=",foes.size())
  for foe in foes:
   army.apply_hit(army.handles.get(foe,0),{"amount":1000000.0})
 var regroup_seconds=-1.0
 var near_seconds=-1.0
 for i in (150 if orders else 90):
  await observe(6)
  if near_seconds<0 and spread(18).x==5:near_seconds=(i+1)*.1
  if i in [7,19]:
   report("recall %.1f"%((i+1)*.1))
  if fight_target>0 and not chasing(fight_target) and spread(18).x==5 and covered(16,5,3):
   regroup_seconds=(i+1)*.1
   break
 report("regroup")
 check(fight_target>0 and not chasing(fight_target),"The pack releases its original wave target")
 check(regroup_seconds>0 and regroup_seconds<=(11.0 if orders else 3.5),"All hounds return within 18 m and spread around the player")
 await capture("Regroup")
 if orders and "--repeat-orders" in OS.get_cmdline_user_args():await repeat_orders()
 sampled_frames.sort()
 print("HOUND_WAVE_FRAME samples=",sampled_frames.size()," p95_ms=",sampled_frames[floori((sampled_frames.size()-1)*.95)]," max_ms=",sampled_frames[-1])
 var blinks=army.event_log.filter(func(e):return e.kind=="status" and e.unit_kind==Roles.GATEKEEPER_HOUND and e.action_index==499).size()/2
 if orders:check(blinks==0,"A commanded return uses running throughout")
 var profile:Dictionary=army.native.simulation_profile(false)
 var queries:Dictionary=army.native.query_stats(false)
 print("HOUND_WAVE_NATIVE steps=",profile.steps," total_ms_per_step=",profile.total_ms/maxi(1,profile.steps)," decisions_ms_per_step=",profile.decisions_ms/maxi(1,profile.steps)," movement_ms_per_step=",profile.movement_ms/maxi(1,profile.steps)," flow_builds=",profile.nav_flow_builds," enemy_queries=",queries.enemy_queries," candidates=",queries.enemy_candidates," wall_ms=",(Time.get_ticks_usec()-native_start)/1000.0)
 print("HOUND_WAVE_RESULT checks=",checks," failures=",failures," peak_enemies=",peak_enemies," wave_spawns=",game.model.waves.spawned," hound_hits=",hits()," hound_kills=",dog_events("death")," blinks=",blinks," hunt_seconds=",hunt_seconds," near_seconds=",near_seconds," regroup_seconds=",regroup_seconds)
 game.queue_free();await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

func repeat_orders():
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
  DisplayServer.window_move_to_foreground()
  root.grab_focus()
  var focus_deadline=Time.get_ticks_msec()+3000
  while not DisplayServer.window_is_focused() and Time.get_ticks_msec()<focus_deadline:await process_frame
 var presentation=game.crowd.army.presentation
 var initial_nodes:int=presentation.get_child_count()
 var initial_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for cycle in range(1,4):
  await order_window("hold-%d"%cycle,-1,60)
  await order_window("hunt-%d"%cycle,army.HoundOrder.ATTACK,30)
  await observe(150)
  var targets={}
  for skin in Pets.COUNT:
   var row:Dictionary=army.unit_state(army.handles.get(army.HOUND_ID-skin,0))
   if row.get("target_id",0)>0:targets[row.target_id]=true
  check(targets.size()>=2,"Hunt %d spreads across multiple live targets"%cycle)
  if cycle==3:
   await order_window("Z-interrupt",army.HoundOrder.RETURN,30)
   await order_window("hunt-resume",army.HoundOrder.ATTACK,30)
  await order_window("Z-%d"%cycle,army.HoundOrder.RETURN,30)
  var elapsed=.5
  while elapsed<9 and (spread(18).x!=5 or not covered(16,5,3)):
   await observe(6)
   elapsed+=.1
  await observe(72)
  var parked=parked_pack()
  for i in 12:
   if parked.x>=11 and parked.y>2.5:break
   await observe(12)
   parked=parked_pack()
  var coverage=spread(18)
  print("HOUND_REPEAT cycle=",cycle," targets=",targets.size()," regroup_s=",elapsed," within_18=",coverage.x," sectors=",coverage.y," parked=",parked.x," parked_gap=",parked.y," enemies=",game.model.enemies.size())
  check(coverage.x==5 and coverage.y>=3 and parked.x>=3 and parked.y>2.5,"Return %d spreads the full pack and keeps settled hounds apart"%cycle)
  await capture("Repeated return %d"%cycle)
 print("HOUND_REPEAT_POOL nodes=",initial_nodes,"->",presentation.get_child_count()," resources=",initial_resources,"->",int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
 check(presentation.get_child_count()==initial_nodes,"Repeated orders reuse the presentation pool")

func parked_pack()->Vector2:
 var parked:Array[Vector2]=[]
 var gap=INF
 for skin in Pets.COUNT:
  var state:Dictionary=army.unit_state(army.handles.get(army.HOUND_ID-skin,0))
  if state.is_empty() or flat(state.velocity).length_squared()>.35*.35:continue
  var point=flat(state.position)
  for other in parked:gap=minf(gap,point.distance_to(other))
  parked.append(point)
 return Vector2(parked.size(),gap)

func order_window(label_:String,order:int,ticks:int):
 var before:Dictionary=army.native.simulation_profile(false)
 var before_queries:Dictionary=army.native.query_stats(false)
 order_frames.clear()
 focused_order_frames=0
 previous_order_frame=Time.get_ticks_usec()
 process_frame.connect(sample_order_frame)
 if order>=0:army.order_hounds(order)
 await observe(ticks)
 process_frame.disconnect(sample_order_frame)
 var after:Dictionary=army.native.simulation_profile(false)
 var queries:Dictionary=army.native.query_stats(false)
 order_frames.sort()
 var steps=maxi(1,after.steps-before.steps)
 print("HOUND_ORDER_WINDOW ",label_," samples=",order_frames.size()," focused=",focused_order_frames," p95_ms=",order_frames[floori((order_frames.size()-1)*.95)] if not order_frames.is_empty() else 0," max_ms=",order_frames.back() if not order_frames.is_empty() else 0," native_avg_ms=",(after.total_ms-before.total_ms)/steps," decisions_ms=",(after.decisions_ms-before.decisions_ms)/steps," ally_queries=",queries.ally_queries-before_queries.ally_queries," route_ms=",after.nav_route_ms-before.nav_route_ms," flow_builds=",after.nav_flow_builds-before.nav_flow_builds)

func sample_order_frame():
 var now=Time.get_ticks_usec()
 if DisplayServer.window_is_focused():focused_order_frames+=1
 order_frames.append((now-previous_order_frame)/1000.0)
 previous_order_frame=now

func send_key(code:int):
 var key=InputEventKey.new();key.physical_keycode=code;key.pressed=true
 game._input(key)

func first_hound_hit()->int:
 for event in army.event_log:
  if event.kind=="damage" and event.source_id<=army.HOUND_ID and event.team==0:return event.target_id
 return 0

func observe(ticks:int):
 var previous=Time.get_ticks_usec()
 for i in ticks:
  await physics_frame
  if i%12==0:
   peak_enemies=maxi(peak_enemies,game.model.enemies.size())
   aim()
  var now=Time.get_ticks_usec()
  if i>0 and Engine.get_process_frames()!=get_meta("last_sample_frame",-1):
   sampled_frames.append((now-previous)/1000.0)
   set_meta("last_sample_frame",Engine.get_process_frames())
  previous=now

func aim():
 var center:Vector3=game.player.position
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=center+Vector3(0,19,30);camera.look_at(center+Vector3.UP)

func flat(v:Vector3)->Vector2:return Vector2(v.x,v.z)

func pack()->Array[Vector2]:
 var points:Array[Vector2]=[]
 var snapshot:Dictionary=army.latest
 for i in snapshot.kinds.size():
  if snapshot.kinds[i]==Roles.GATEKEEPER_HOUND and snapshot.teams[i]==1:points.append(flat(snapshot.positions[i]-game.player.position))
 return points

func spread(radius:float)->Vector2i:
 var near_count=0;var sectors={}
 for offset in pack():
  if offset.length()>radius:continue
  near_count+=1
  sectors[posmod(floori((offset.angle()+PI/8)*8/TAU),8)]=true
 return Vector2i(near_count,sectors.size())

func covered(radius:float,count:int,sectors:int)->bool:
 var summary=spread(radius)
 return summary.x>=count and summary.y>=sectors

func report(label_:String):
 var distances=pack().map(func(p):return snappedf(p.length(),.1))
 distances.sort()
 print("HOUND_WAVE ",label_," player=",game.player.position," enemies=",game.model.enemies.size()," near_and_sectors=",spread(18)," distances=",distances)
 for skin in Pets.COUNT:
  var row:Dictionary=army.unit_state(army.handles.get(army.HOUND_ID-skin,0))
  if not row.is_empty() and flat(row.position-game.player.position).length()>18:
   print("HOUND_WAVE_TRAIL skin=",skin," pos=",row.position," velocity=",row.velocity," target=",row.get("target_id",0))

func hits()->int:
 return dog_events("damage")

func dog_events(kind:String)->int:
 return army.event_log.filter(func(e):return e.kind==kind and e.source_id<=army.HOUND_ID and e.team==0).size()

func chasing(target:int)->bool:
 for skin in Pets.COUNT:
  var row:Dictionary=army.unit_state(army.handles.get(army.HOUND_ID-skin,0))
  if row.get("target_id",0)==target:return true
 return false

func closest_enemy()->Vector3:
 var center:Vector3=game.player.position
 var snapshot:Dictionary=army.render_snapshot()
 var nearest=Vector3.INF;var gap=INF
 for i in snapshot.teams.size():
  if snapshot.teams[i]!=0 or snapshot.kinds[i]==Roles.BOSS:continue
  var point:Vector3=snapshot.positions[i]
  var distance=flat(point-center).length()
  if distance<gap and absf(point.y-center.y)<4:
   nearest=point;gap=distance
 return nearest

func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 aim()
 await process_frame;RenderingServer.force_draw();await RenderingServer.frame_post_draw
 var folder="res://build/Other Files/Asset Toolkit/Cross Gate Hounds/Sprint Turns/" if "--repeat-orders" in OS.get_cmdline_user_args() else OUT
 DirAccess.make_dir_recursive_absolute(folder)
 root.get_texture().get_image().save_png(folder+label_+(" large" if "--large" in OS.get_cmdline_user_args() else "")+".png")
