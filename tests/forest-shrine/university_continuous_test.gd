extends "res://tests/forest-shrine/original_maps_test.gd"
## Reuses the held-input route method from south_kili_continuous_test; no placements after the approach.
const Region=preload("res://scripts/forest/forest_university_region.gd")
const REVIEW="res://build/Other Files/Asset Toolkit/University Region/"
var movement_frames=0
var walked=0.
var crossings=[]

func _initialize():
 create_timer(14400).timeout.connect(func():printerr("UNIVERSITY_CONTINUOUS_TIMEOUT");save();quit(1))
 run.call_deferred()

func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-university-continuous-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 root.gui_disable_input=false
 game.run_seed=341;game.tuning.invincible="--invincible" in OS.get_cmdline_user_args()
 # One initial approach placement. Every dungeon crossing below uses the player controller.
 var probe="--probe-arena" in OS.get_cmdline_user_args()
 var first=16520 if probe else Original.SHALENA_NORTH
 Tour.travel(game,Original.layout(first),{"arrival":Original.source_point(first,Vector2i(10,7) if probe else Vector2i(318,140)),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 var route=[16521]
 for n in range(1,11):route.append(Original.generated().floor_id("lizard",n))
 route.append(16520)
 if probe:route=[]
 for target:int in route:
  var before:int=game.model.falan_floor
  var gates=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==target)
  check(not gates.is_empty(),"Normal approach exposes the intended crossing %d → %d"%[before,target])
  if gates.is_empty():break
  print("UNIVERSITY_INPUT_WALK ",before," → ",target)
  await follow(gates[0].at,true)
  for i in 5:await physics_frame
  var passed=game.model.falan_floor==target
  check(passed,"Held movement crosses every original dungeon stair")
  crossings.append({"from":before,"to":game.model.falan_floor,"passed":passed,"movement_frames":movement_frames})
  save()
  if not passed:break
 if failures==0:
  var boss:Dictionary=Region.BOSSES.lizard
  if Region.active(self,16520).is_empty():await follow(Original.source_point(16520,boss.cell),false,10.)
  for i in 12:await physics_frame
  check(Region.active(self,16520)=="lizard","Walking into the original arena triggers the full encounter")
  for frame in (3600 if probe else 36000):
   if get_meta(Region.BATTLES,{}).get("lizard",{}).get("complete",false):break
   if game.player.hp<=0:check(false,"Character survives the source encounter");break
   var enemies:Array=game.model.enemies.values().filter(func(enemy):return enemy.get("university_battle","")=="lizard" and enemy.hp>0)
   if enemies.is_empty():await physics_frame;continue
   enemies.sort_custom(func(a,b):return a.pos.distance_squared_to(game.player.position)<b.pos.distance_squared_to(game.player.position))
   var toward:Vector3=enemies[0].pos-game.player.position;toward.y=0
   game.camera_rig.yaw=atan2(-toward.x,-toward.z)
   if toward.length()>15.*game.model.falan_scale:Input.action_press("move_forward")
   else:Input.action_release("move_forward")
   if not game.player.auto_attack_enabled:action("auto_attack_toggle")
   if frame%60==0 and game.player.active_ability.locked_primary_enemy()==null:action("assist")
   if frame%18==0:action("light_attack")
   await physics_frame
   if frame%600==0:
    print("UNIVERSITY_INPUT_BATTLE frames=",frame," alive=",enemies.size()," hp=",enemies.reduce(func(sum_,row):return sum_+row.hp,0.)," auto=",game.player.auto_attack_enabled," mode=",game.player.active_ability.mode," target=",game.player.active_ability.locked_primary_enemy()," actors=",game.enemies.size())
    save()
  Input.action_release("move_forward")
  check(get_meta(Region.BATTLES,{}).get("lizard",{}).get("complete",false),"Actual player attacks defeat the source boss and retinue")
  for i in 12:await physics_frame
  check(game.model.falan_floor==Original.SHALENA_NORTH,"Victory returns through the original reward/return flow")
 print("UNIVERSITY_CONTINUOUS_RESULT checks=",checks," failures=",failures," crossings=",crossings.size()," movement_frames=",movement_frames)
 save();quit(1 if failures else 0)

func action(name_:String):
 var event=InputEventAction.new();event.action=name_;event.pressed=true;Input.parse_input_event(event)
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event)

func position_2d()->Vector2:return Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale

func follow(target:Vector2,crossing:bool,stop_distance:float=.35):
 var model=game.model;var state=Original.state(model.falan_floor,model.seed_value)
 var grid=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,state.size);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
 for y in state.size.y:
  for x in state.size.x:grid.set_point_solid(Vector2i(x,y),not Original.open(state.bits,state.size,Vector2i(x,y)))
 var start=Vector2i(((position_2d()-state.origin)/3.).round());var end=Vector2i(((target-state.origin)/3.).round())
 # A corridor can contain several stairs to different chambers on the same floor.
 # Passing over another warp is a real crossing, so plan around its tile just as a player would.
 for link in Original.links(model.falan_floor,model.seed_value):
  var cell=Vector2i(((link.at-state.origin)/3.).round())
  if cell!=start and cell!=end and grid.is_in_boundsv(cell):grid.set_point_solid(cell,true)
 var path=grid.get_id_path(start,end)
 check(not path.is_empty(),"Source walk mask connects the actual arrival to the next gate")
 for cell in path:
  var at=target if cell==end else state.origin+Vector2(cell)*3.
  var reached=false
  for frame in 180:
   if game.model!=model:return
   if not crossing and not Region.active(self,model.falan_floor).is_empty():Input.action_release("move_forward");return
   if position_2d().distance_to(at)<(stop_distance if cell==end else .35):reached=true;break
   if game.player.hp<=0:check(false,"Player survives the held-input approach");return
   var toward=(at-position_2d()).normalized();game.camera_rig.yaw=atan2(-toward.x,-toward.y)
   Input.action_press("move_forward")
   var before=game.player.position
   await physics_frame;movement_frames+=1;walked+=before.distance_to(game.player.position)
  Input.action_release("move_forward")
  if not reached:
   print("UNIVERSITY_WALK_BLOCKED actual=",position_2d()," y=",game.player.position.y/model.falan_scale," target=",at," floor=",model.falan_floor," velocity=",game.player.velocity," hp=",game.player.hp)
   check(false,"Player controller is blocked at %s on floor %d"%[at,model.falan_floor]);return
 if crossing:
  # Continue across the trigger threshold; the map owner, not this fixture, chooses the arrival.
  for i in 30:
   if game.model!=model:return
   var toward=(target-position_2d()).normalized();game.camera_rig.yaw=atan2(-toward.x,-toward.y);Input.action_press("move_forward")
   await physics_frame;movement_frames+=1
  Input.action_release("move_forward")

func save():
 var file=FileAccess.open(REVIEW+("lizard-controller-probe.json" if "--probe-arena" in OS.get_cmdline_user_args() else "continuous-lizard.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"crossings":crossings,"movement_frames":movement_frames,"distance":walked,"placements_after_approach":0,"probe_only":"--probe-arena" in OS.get_cmdline_user_args(),"injected_hits":0,"invincible":game.tuning.invincible,"rendered":DisplayServer.get_name()!="headless","failures":failures,"floor":game.model.falan_floor},"  "));file.close()
