extends "res://tests/forest-shrine/university_continuous_test.gd"
## Actual controller/F/dialogue inputs, one initial approach placement, no injected damage.
var branch_name="snow"
var battles_played=[]
var conversations=[]
var components={}
var fixture_items={}
var selected_branches=[]
var capture_index=0

func gameplay_capture(label_:String):
 if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":return
 var folder=REVIEW+"Gameplay/"+branch_name+"/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"%03d-%s-%d.png"%[capture_index,label_,game.model.falan_floor])
 capture_index+=1

func _initialize():
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--branch="):branch_name=argument.trim_prefix("--branch=")
  elif argument.begins_with("--branches="):selected_branches=Array(argument.trim_prefix("--branches=").split(","))
 super._initialize()

func run():
 if "--capture" in OS.get_cmdline_user_args():root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-university-%s-%d.cfg"%[branch_name,OS.get_process_id()]
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 root.gui_disable_input=false;game.run_seed=341;game.tuning.invincible="--invincible" in OS.get_cmdline_user_args()
 game.explorer_clock.hour=12.;game.explorer_clock.save_left=100000
 for selected_branch in ([branch_name] if selected_branches.is_empty() else selected_branches):
  branch_name=selected_branch;checks=0;failures=0;movement_frames=0;walked=0.;crossings=[];battles_played=[];conversations=[];capture_index=0
  for meta in [Region.ITEMS,Region.BATTLES,Region.SLAIN,"university_victory","university_drop_bags",Winter.SLAIN]:
   if has_meta(meta):remove_meta(meta)
  print("UNIVERSITY_BRANCH_BEGIN ",branch_name)
  if branch_name=="snow":await snow_route(false)
  elif branch_name=="permafrost":await snow_route(true)
  elif branch_name=="decree":await decree_route()
  elif branch_name=="beast":await beast_route()
  elif branch_name in ["doctor","abyss"]:await dark_route()
  elif branch_name=="ice_gate":await ice_gate_route()
  elif branch_name=="ice":await ice_route()
  elif branch_name=="campus":await campus_route()
  elif branch_name=="witch":await witch_route()
  elif branch_name=="shanti":await shanti_route()
  elif branch_name=="abyss_probe":await abyss_probe()
  elif branch_name=="azure_probe":await azure_probe()
  elif branch_name=="curse":await curse_route()
  elif branch_name=="curse_exits":await curse_exits_route()
  elif branch_name=="lizard_exchange":await lizard_exchange_route()
  elif branch_name=="astia":await astia_route()
  elif branch_name=="astia_denied":await astia_denied_route()
  elif branch_name in ["jenova_teleport","abanis_teleport","jenova_voucher","abanis_voucher"]:await teleport_route()
  elif branch_name in ["white_decline","black_decline"]:await messenger_decline_route()
  elif branch_name=="cabin_voucher":await cabin_voucher_route()
  elif branch_name=="curse_career":await curse_career_route()
  elif branch_name=="snow_alraune":await snow_alraune_route()
  elif branch_name in ["romance_hall","hall_default","hall_earring"]:await romance_hall_route()
  elif branch_name=="memory_gateway":await memory_gateway_route()
  elif branch_name=="tina_child":await tina_child_route()
  elif branch_name=="shanti_bonus":await shanti_route()
  else:check(false,"Unknown continuous regional branch")
  release_controls();save();await gameplay_capture("finished")
  print("UNIVERSITY_BRANCH_RESULT branch=",branch_name," checks=",checks," failures=",failures," crossings=",crossings.size()," movement_frames=",movement_frames)
  if failures>0:break
 quit(1 if failures else 0)

func initial(id:int,cell:Vector2i,items:Dictionary={}):
 fixture_items=items.duplicate(true);set_meta(Region.ITEMS,items.duplicate(true));game.model.gold=100000
 id=Original.runtime_id(id)
 var state=Original.state(id,341);var safe=Original.safe_cell(id,cell-Original.crop(id).position,341)
 Tour.travel(game,Original.layout(id),{"arrival":Original.point(id,safe,341),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 check(game.model.falan_floor==id,"Initial recorded approach loads")

func release_controls():
 Input.action_release("move_forward")
 if game.player.auto_attack_enabled:action("auto_attack_toggle")

func key(code:int):
 var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event)

func speak(id:String,answer:String="yes")->bool:
 game.explorer_npcs.prepare()
 var choices=game.explorer_npcs.actors.filter(func(actor):return actor.record.id=="source:"+id)
 check(choices.size()==1,"Exactly one source interaction exists "+id)
 if choices.size()!=1:return false
 var actor:Dictionary=choices[0];var record:Dictionary=actor.node.get_meta("npc_record");var floor_:int=game.model.falan_floor
 var state=Original.state(floor_,341);var candidates=[]
 for z in range(-2,3):
  for x in range(-2,3):
   var cell=Vector2i(record.cell[0]+x,record.cell[1]+z)-Original.crop(floor_).position
   if not Original.open(state.bits,state.size,cell):continue
   var at=Original.point(floor_,cell,341)
   if connected(floor_,position_2d(),at,341):candidates.append(at)
 candidates.sort_custom(func(a,b):return a.distance_squared_to(position_2d())<b.distance_squared_to(position_2d()))
 for at:Vector2 in candidates:
  await follow(at,false)
  if failures>0:return false
  for i in 10:await physics_frame
  game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
  if game.explorer_npcs.nearest.get("node")!=actor.node:
   # Source candles can stand across an invisible seal; approach its boundary with the controller.
   for i in 45:
    var toward:Vector3=actor.node.global_position-game.player.position;toward.y=0
    game.camera_rig.yaw=atan2(-toward.x,-toward.z);Input.action_press("move_forward")
    await physics_frame;movement_frames+=1
    game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
    if game.explorer_npcs.nearest.get("node")==actor.node:break
   Input.action_release("move_forward")
  if id=="6735":
   var eye=game.player.position+Vector3.UP*2.5;var sight=(actor.node.global_position+Vector3.UP*2.5).move_toward(eye,1.6*game.model.falan_scale)
   var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,sight,1))
   print("AZURE_F_APPROACH requested=",at," actual=",position_2d()," distance=",game.player.position.distance_to(actor.node.global_position)/game.model.falan_scale," nearest=",game.explorer_npcs.nearest.get("record",{}).get("id")," blocked=",actor.get("source_cell_blocked")," ray=",hit)
  if game.explorer_npcs.nearest.get("node")!=actor.node:continue
  key(KEY_F)
  for i in 2:await physics_frame
  var opened=is_instance_valid(game.dialogue) and game.explorer_npcs.selected.get("id")=="source:"+id
  check(opened,"Actual F input opens "+id)
  if not opened:return false
  var first=game.dialogue
  for i in 12:
   if not is_instance_valid(game.dialogue) or game.dialogue!=first:break
   key(KEY_SPACE)
   for j in 2:await physics_frame
  if is_instance_valid(game.dialogue):
   key(KEY_SPACE)
   for i in 3:await physics_frame
   check(game.dialogue.options.visible,"Source confirmation is visible "+id)
   if answer=="no":key(KEY_RIGHT)
   key(KEY_ENTER)
  for i in 8:await physics_frame
  conversations.append({"actor":id,"from":floor_,"to":game.model.falan_floor,"answer":answer});save()
  await gameplay_capture("F-"+id)
  return true
 print("UNIVERSITY_NPC_UNREACHABLE actor=",id," player=",position_2d()," npc=",actor.node.global_position/game.model.falan_scale)
 check(false,"Held movement reaches an unobstructed F range "+id);return false

func cross_to(target:int,chosen:Dictionary={})->bool:
 target=Original.runtime_id(target)
 var before:int=game.model.falan_floor;var gates=[chosen] if not chosen.is_empty() else game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==target and connected(before,position_2d(),link.at,341))
 check(not gates.is_empty(),"Connected source crossing %d → %d"%[before,target])
 if gates.is_empty():return false
 print("UNIVERSITY_BRANCH_WALK ",branch_name," ",before," → ",target)
 if position_2d().distance_to(gates[0].at)<1.4:
  # Fixed source rooms can land directly on their return stair. Step off, then re-enter normally.
  var state=Original.state(before,341);var cell=Vector2i(((gates[0].at-state.origin)/3.).round())
  for direction in [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT]:
   if Original.open(state.bits,state.size,cell+direction):
    await follow(Original.point(before,cell+direction,341),false);break
 # This approach permits the terminal tunnel encounter to trigger before the sealed stair.
 await follow(gates[0].at,false,3.)
 if failures>0:return false
 var active=Region.active(self,game.model.falan_floor)
 if not active.is_empty():await fight(func():return get_meta(Region.BATTLES,{})[active].complete,func(enemy):return enemy.get("university_battle","")==active)
 if game.model.falan_floor==before:await follow(gates[0].at,true)
 for i in 5:await physics_frame
 target=game.explorer_clock.phase_floor(target)
 if gates[0].get("region_hall_variant",false) and Region.romance_eligible(self):target=32269
 var actual_component=component(game.model.falan_floor,position_2d());var expected_component=component(target,gates[0].arrival)
 var passed=game.model.falan_floor==target and actual_component==expected_component
 check(passed,"Player controller crosses the original gate")
 crossings.append({"from":before,"to":game.model.falan_floor,"passed":passed,"movement_frames":movement_frames,"gate":[gates[0].at.x,gates[0].at.y],"expected_arrival":[gates[0].arrival.x,gates[0].arrival.y],"actual":[position_2d().x,position_2d().y],"expected_component":expected_component,"actual_component":actual_component});save()
 await gameplay_capture("crossed")
 return passed

func fight(done:Callable,eligible:Callable):
 var first_floor:int=game.model.falan_floor;var frames=0;var damage_seen=0.;var health={}
 var state=Original.state(first_floor,341);var grid=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,state.size);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
 for y in state.size.y:
  for x in state.size.x:grid.set_point_solid(Vector2i(x,y),not Original.open(state.bits,state.size,Vector2i(x,y)))
 for link in Original.links(first_floor,341):
  var cell=Vector2i(((link.at-state.origin)/3.).round())
  if grid.is_in_boundsv(cell):grid.set_point_solid(cell,true)
 var waypoint=Vector2.INF
 for frame in 72000:
  frames=frame
  if done.call():break
  if game.player.hp<=0:check(false,"Character remains alive during actual combat");break
  var enemies:Array=game.model.enemies.values().filter(func(enemy):return enemy.hp>0 and eligible.call(enemy))
  if enemies.is_empty():
   if frame%120==0:
    print("UNIVERSITY_BATTLE_WAIT floor=",first_floor," frames=",frame," state=",get_meta(Region.BATTLES,{})," items=",get_meta(Region.ITEMS,{})," spawned=",game.model.waves.spawned," at=",position_2d());save()
   if frame>=600:check(false,"Native encounter produces reachable live actors");break
   if frame>=12 and frame<60:
    # A normal player backs away from the mural after activating it.
    var away=position_2d()-Original.source_point(first_floor,Region.BOSSES.abyss.cell) if first_floor==15539 else Vector2.ZERO
    if away.length_squared()>0:game.camera_rig.yaw=atan2(-away.x,-away.y);Input.action_press("move_forward")
   else:Input.action_release("move_forward")
   await physics_frame;continue
  enemies.sort_custom(func(a,b):return a.pos.distance_squared_to(game.player.position)<b.pos.distance_squared_to(game.player.position))
  for enemy in enemies:
   if health.has(enemy.id):damage_seen+=maxf(0,float(health[enemy.id])-float(enemy.hp))
   health[enemy.id]=enemy.hp
  var direct:Vector3=enemies[0].pos-game.player.position;direct.y=0
  var sight=game._ryo_clear_path(game.player.position+Vector3.UP*2.5*game.model.falan_scale,enemies[0].pos+Vector3.UP*2.5*game.model.falan_scale)
  if frame%20==0 or not waypoint.is_finite() or position_2d().distance_to(waypoint)<.4:
   var start=Vector2i(((position_2d()-state.origin)/3.).round());var end=Vector2i(((Vector2(enemies[0].pos.x,enemies[0].pos.z)/game.model.falan_scale-state.origin)/3.).round())
   var path=grid.get_id_path(start,end)
   waypoint=state.origin+Vector2(path[1])*3. if path.size()>1 else Vector2(enemies[0].pos.x,enemies[0].pos.z)/game.model.falan_scale
  var toward=Vector3(waypoint.x*game.model.falan_scale,game.player.position.y,waypoint.y*game.model.falan_scale)-game.player.position
  if sight:toward=direct
  game.camera_rig.yaw=atan2(-toward.x,-toward.z)
  if direct.length()>15.*game.model.falan_scale or not sight:Input.action_press("move_forward")
  else:Input.action_release("move_forward")
  if not game.player.auto_attack_enabled:action("auto_attack_toggle")
  var locked=game.player.active_ability.locked_primary_enemy()
  var locked_row:Dictionary=game.model.enemies.get(int(locked.get("forest_id")),{}) if locked!=null else {}
  if frame%60==0 and (locked_row.is_empty() or not eligible.call(locked_row)):action("assist")
  if frame%18==0:action("light_attack")
  await physics_frame
  if frame==180:await gameplay_capture("combat")
  if frame%1800==0:print("UNIVERSITY_BRANCH_COMBAT ",branch_name," floor=",first_floor," frames=",frame," targets=",enemies.size()," damage=",damage_seen)
 release_controls()
 # Native defeat and the source victory transfer run on successive physics ticks.
 for i in 12:await physics_frame
 check(done.call(),"Actual player attacks complete the required encounter")
 battles_played.append({"floor":first_floor,"frames":frames,"observed_damage":damage_seen,"complete":done.call()});save()
 await gameplay_capture("victory")

func snow_route(permafrost:bool):
 var prerequisites={"dragon_trial":true,"world_heart":true} if permafrost else {}
 await initial(402,Vector2i(84,196),prerequisites)
 for n in range(1,Original.generated().count("mountain",341)+1):
  if not await cross_to(Original.generated().floor_id("mountain",n)):return
 if not await cross_to(15522):return
 if not await cross_to(15523):return
 if not permafrost:
  if not await speak("5202"):return
  check(game.model.falan_floor==Original.SHALENA_NORTH,"Cabin's paid return reaches the original road");return
 if not await cross_to(15522) or not await cross_to(15536) or not await speak("5268"):return
 for n in range(1,37):
  if not await cross_to(Original.generated().floor_id("permafrost",n)):return
 if not await cross_to(15537) or not await speak("5266"):return
 check(Region.has_item(self,"white_memory") and game.model.falan_floor==1530,"White altar's reward returns through the original summon room")

func snow_alraune_route():
 await initial(402,Vector2i(84,196))
 for n in range(1,Original.generated().count("mountain",341)+1):
  if not await cross_to(Original.generated().floor_id("mountain",n)):return
 if not await cross_to(15522):return
 var seen=false
 for round_ in 300:
  if Region.has_item(self,"snow_alraune_victory"):break
  var enemies:Array=game.model.enemies.values().filter(func(enemy):return enemy.hp>0)
  if not enemies.is_empty():
   var trial=enemies.filter(func(enemy):return enemy.has("snow_quest_drop"))
   if not trial.is_empty():
    check(trial.filter(func(enemy):return enemy.snow_quest_drop=="snow_alraune").size()==1 and trial.filter(func(enemy):return enemy.snow_quest_drop=="snow_mutant").size()==3,"Walked summit encounter retains the source one-plant/three-slime formation")
    seen=true;print("UNIVERSITY_SNOW_FORMATION ",trial.map(func(enemy):return [enemy.enemy_name,enemy.level,enemy.snow_quest_drop]))
   var ids=enemies.map(func(enemy):return enemy.id)
   await fight(func():return ids.all(func(id):return not game.model.enemies.has(id) or game.model.enemies[id].hp<=0),func(enemy):return enemy.id in ids)
   if failures>0:return
  var cell=Original.safe_cell(15522,Vector2i(12,30) if round_%2==0 else Vector2i(18,30),341)
  await follow(Original.point(15522,cell,341),false)
  if failures>0:return
 check(seen and Region.has_item(self,"snow_alraune_victory") and Region.has_item(self,"source_item_18567"),"Normal random encounter and real attacks award the source perfume reward")
 if failures>0:return
 if not await cross_to(15523) or not await speak("5202"):return
 check(game.model.falan_floor==Original.SHALENA_NORTH,"Snow quest returns through the ordinary cabin guide")

func beast_route():
 var city=Original.runtime_id(4000);var entry=Original.links(Original.SHALENA_SOUTH,341).filter(func(link):return link.get("floor",-1)==city)[0]
 var cell=Vector2i(((entry.arrival-Original.state(city,341).origin)/3.).round())+Original.crop(city).position
 await initial(city,cell,{"opener":true,"job_rank":1,"job_id":62})
 for id in [4010,4011]:
  if not await cross_to(id):return
 if not await speak("6330"):return
 for id in [4010,4000,400]:
  if not await cross_to(id):return
 if not await speak("6331"):return
 for n in range(1,13):
  if not await cross_to(51200+n):return
  if not Region.has_item(self,"beast_scale"):
   var candidates=game.model.enemies.values().filter(func(enemy):return enemy.get("beast_scale_drop",false) and enemy.hp>0)
   if not candidates.is_empty():await fight(func():return Region.has_item(self,"beast_scale") or not game.model.enemies.values().any(func(enemy):return enemy.get("beast_scale_drop",false) and enemy.hp>0),func(enemy):return enemy.get("beast_scale_drop",false))
 if not await cross_to(16511):return
 check(Region.has_item(self,"beast_scale"),"Native dragon defeats actually produced the required scale")
 if not await speak("6334"):return
 var boss=game.model.enemies.values().filter(func(enemy):return enemy.get("boss",false))
 check(boss.size()==1,"One native beast guards the sealed passage")
 if boss.is_empty():return
 var at=Vector2(boss[0].pos.x,boss[0].pos.z)/game.model.falan_scale
 await follow(at,false,12.)
 await fight(func():return get_meta(Winter.SLAIN,{}).has(Vector2i(16511,0)),func(enemy):return enemy.get("boss",false))
 if not await cross_to(16512):return
 if not await speak("6345") or not await cross_to(16512):return
 if not await speak("6342"):return
 check(game.model.falan_floor==16512,"Unrelated profession cannot bypass the witch's gate")
 if not await cross_to(16513) or not await cross_to(400):return
 check(game.model.falan_floor==Original.SHALENA_SOUTH,"Beast's original return stone reaches the approach road")

func component(id:int,at:Vector2)->int:
 if not components.has(id):
  var state=Original.state(id,341);var seen={};var index=0
  for y in state.size.y:
   for x in state.size.x:
    var cell=Vector2i(x,y)
    if seen.has(cell) or not Original.open(state.bits,state.size,cell):continue
    var queue=[cell];seen[cell]=index
    for here:Vector2i in queue:
     for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
      var next=here+direction
      if not seen.has(next) and Original.open(state.bits,state.size,next):seen[next]=index;queue.append(next)
    index+=1
  components[id]=seen
 var state=Original.state(id,341);return components[id].get(Vector2i(((at-state.origin)/3.).round()),-1)

func component_route(target:int,at:Vector2,allowed:Callable)->Array:
 var first=Vector2i(game.model.falan_floor,component(game.model.falan_floor,position_2d()));var last=Vector2i(target,component(target,at))
 var queue=[first];var parents={first:first};var stairs={}
 for here:Vector2i in queue:
  if here==last:break
  for link in Original.links(here.x,341):
   var id:int=link.get("floor",-1)
   if not allowed.call(id) or component(here.x,link.at)!=here.y:continue
   var next=Vector2i(id,component(id,link.arrival))
   if next.y<0 or parents.has(next):continue
   parents[next]=here;stairs[next]=link;queue.append(next)
 check(parents.has(last),"The original component graph connects the next required chamber")
 var result=[]
 if not parents.has(last):return result
 var cursor=last
 while cursor!=first:result.push_front(stairs[cursor]);cursor=parents[cursor]
 return result

func decree_route():
 var decree=Winter.Decree
 await initial(402,Vector2i(184,164),{"opener":true,"job_rank":2})
 if not await cross_to(4300):return
 if not await cross_to(4320) or not await speak("6392") or not await speak("6399"):return
 if not await speak("6397") or not await speak("6394"):return
 for id in [4333,4334]:
  if not await cross_to(id):return
 if not await speak("6407"):return
 for id in [4320,4300,402,24008,decree.floor_id(1)]:
  if not await cross_to(id):return
 var final_id=decree.floor_id(60);var seal=Original.links(final_id,341).filter(func(link):return link.get("decree_guardians",false))[0]
 var route=component_route(final_id,seal.at,func(id):return decree.floor_number(id)>0 or id in range(24069,24075))
 route.append(seal)
 for link:Dictionary in route:
  if link.get("decree_guardians",false):
   var id:int=game.model.falan_floor
   var bosses=game.model.enemies.values().filter(func(enemy):return enemy.get("boss",false))
   check(bosses.size()==(2 if id==final_id else 1),"Every guardian including both Twin Kings is present")
   if bosses.is_empty():return
   await follow(Vector2(bosses[0].pos.x,bosses[0].pos.z)/game.model.falan_scale,false,12.)
   await fight(func():return decree.cleared(get_meta(Winter.SLAIN,{}),id,341),func(enemy):return enemy.get("boss",false))
  if not await cross_to(int(link.floor),link):return
 if not await speak("6933") or not await speak("6934"):return
 if not await speak("6450"):return
 check(game.model.falan_floor==Original.SHALENA_NORTH and get_meta(decree.COMPLETE,false),"All sixty floors, guardians, kings and priest return complete with actual inputs")

func dark_route():
 await initial(400,Vector2i(281,375),{"wind_tower":true,"god_eye":true})
 await follow(Original.source_point(Original.SHALENA_SOUTH,Region.BOSSES.zombie.cell),false,10.)
 await fight(func():return get_meta(Region.BATTLES,{}).get("zombie",{}).get("complete",false),func(enemy):return enemy.get("university_battle","")=="zombie")
 if not await speak("5245"):return
 for n in range(1,Original.generated().count("tunnel",341)+1):
  if not await cross_to(Original.generated().floor_id("tunnel",n)):return
 if not await cross_to(15531):return
 if not await speak("5247"):return
 if branch_name=="abyss":
  if not await speak("5272") or not await cross_to(15538):return
  for n in range(1,37):
   if not await cross_to(Original.generated().floor_id("abyss",n)):return
  if not await cross_to(15539) or not await speak("5269"):return
  check(game.model.enemies.values().any(func(enemy):return enemy.get("university_battle","")=="abyss"),"The actual mural interaction immediately spawns the native encounter")
  await fight(func():return get_meta(Region.BATTLES,{}).get("abyss",{}).get("complete",false),func(enemy):return enemy.get("university_battle","")=="abyss")
  if not await speak("5267"):return
  check(Region.has_item(self,"world_heart") and Region.has_item(self,"black_memory") and game.model.falan_floor==1530,"Abyss boss reward and original return complete")
 else:
  for id in [15532,15533,15535]:
   if not await cross_to(id):return
  if not await speak("5251"):return
  await fight(func():return get_meta(Region.BATTLES,{}).get("doctor",{}).get("complete",false),func(enemy):return enemy.get("university_battle","")=="doctor")
  if not await speak("5252"):return
  for n in range(Original.generated().count("tunnel",341),0,-1):
   if not await cross_to(Original.generated().floor_id("tunnel",n)):return
  if not await cross_to(400):return
  check(game.model.falan_floor==Original.SHALENA_SOUTH,"Dark doctor's prison bars and full tunnel backtracking return to the original road")

func ice_gate_route():
 await initial(20501,Vector2i(10,51))
 if not await speak("6582") or not await speak("6583"):return
 if not await cross_to(20514) or not await speak("6594"):return
 check(game.model.falan_floor==20501 and Region.has_item(self,"torch") and not Region.has_item(self,"blue_torch"),"First original candle consumes blue flame and opens the main first-floor chamber")
 if not await cross_to(20502):return

func azure_probe():
 await initial(4403,Vector2i(24,49))
 if not await speak("6735"):return
 check(component(4403,position_2d())==component(4403,Original.source_point(4403,Vector2i(31,38))),"Original weak wall crosses to its exact other component")

func abyss_probe():
 var entry:Array=Original.generated().SPECS.abyss.end
 await initial(15539,Vector2i(entry[1],entry[2]),{"god_eye":true})
 if not await speak("5269"):return
 check(game.model.enemies.values().any(func(enemy):return enemy.get("university_battle","")=="abyss"),"Mural immediately spawns without moving away")
 await fight(func():return get_meta(Region.BATTLES,{}).get("abyss",{}).get("complete",false),func(enemy):return enemy.get("university_battle","")=="abyss")
 if failures==0:await speak("5267")

func witch_route():
 await initial(16512,Vector2i(26,26),{"job_id":132})
 if not await speak("6342"):return
 check(game.model.falan_floor==16515,"Qualified witch enters her original profession room")
 if not await speak("6343"):return
 check(game.model.falan_floor==16512,"Gina returns to the exact post-Beast chamber")
 if not await cross_to(16513) or not await cross_to(400):return

func shanti_route():
 await initial(5014,Vector2i(8,6))
 var before:int=game.model.gold
 if not await speak("807220" if branch_name=="shanti_bonus" else "6920"):return
 check(game.model.gold==before-1000,"Shanti consumes exactly the original1000G")
 var rewards:Dictionary=get_meta("university_shanti_rewards",{})
 check(rewards.values().reduce(func(total,n):return total+int(n),0)==1,"One source-weighted modification drawing is awarded")
 check(game.model.falan_floor==Original.SHALENA_NORTH,"Shanti's purchase returns to the original road")

func curse_route():
 # Purple beads are the externally acquired mansion-quest item; no local recommendation is injected.
 await initial(15000,Vector2i(22,32),{"source_item_18378":true})
 if not await regular_go(15001,Vector2i(31,22)) or not await speak("6154"):return
 check(game.model.falan_floor==15006,"Spoken source password opens the original undersea hideout approach")
 for id in [15007,15008,15009,15010,15008]:
  if not await regular_go(id):return
 if not await speak("6159"):return
 check(game.model.falan_floor==15011,"Unqualified visitor enters the original public master-room state")
 if not await cross_to(15008) or not await regular_go(15007) or not await speak("6152"):return
 check(Region.has_item(self,"source_item_18108") and not Region.has_item(self,"source_item_18378"),"Local exchange consumes purple beads and awards the original recommendation")
 if not await regular_go(15008) or not await speak("6159"):return
 check(game.model.falan_floor==15012 and Region.has_item(self,"source_item_18108"),"Recommendation opens the qualified master room without consumption")
 if not await cross_to(15008) or not await regular_go(15000):return

func astia_denied_route():
 await initial(400,Vector2i(260,362))
 if not await speak("6378"):return
 check(game.model.falan_floor==Original.SHALENA_SOUTH,"Astia priest preserves the Beast-story prerequisite")

func curse_exits_route():
 await initial(15001,Vector2i(31,25))
 if not await speak("6154") or not await cross_to(15002):return
 if not await regular_go(15001,Vector2i(31,22)) or not await speak("6154") or not await cross_to(15000):return
 check(game.model.falan_floor==51001,"Both original hideout exits remain usable after repeated password entry")

func lizard_exchange_route():
 # Local reward handoff only; the separate ten-floor Lizard run proves how the hammer is earned.
 await initial(4300,Vector2i(36,49),{"casbar_letter":true,"lizard_reward":true})
 if not await regular_go(4310) or not await speak("5408"):return
 check(Region.has_item(self,"captain_letter") and not Region.has_item(self,"casbar_letter") and not Region.has_item(self,"lizard_reward"),"Hospital handoff consumes the external recommendation and earned hammer")
 if not await regular_go(402):return

func messenger_decline_route():
 var white=branch_name=="white_decline"
 await initial(15537 if white else 15539,Vector2i(20,15),{"world_heart":true})
 if not await speak("5266" if white else "5267","no"):return
 check(game.model.falan_floor==(15522 if white else 15531),"Declining the memory takes the documented local return")
 check(not Region.has_item(self,"white_memory") and not Region.has_item(self,"black_memory"),"Declining does not award a conflicting memory")

func cabin_voucher_route():
 await initial(15522,Vector2i(23,22),{"source_item_18448":true})
 if not await cross_to(15523) or not await speak("5202"):return
 check(game.model.falan_floor==Original.SHALENA_NORTH and game.model.gold==100000 and not Region.has_item(self,"source_item_18448"),"Cabin consumes the source voucher without a gold charge")

func curse_career_route():
 await initial(15007,Vector2i(10,15),{"job_id":80})
 if not await regular_go(15008) or not await speak("6159"):return
 check(game.model.falan_floor==15012 and not Region.has_item(self,"source_item_18108"),"Source curse profession qualifies independently of a recommendation")
 if not await cross_to(15008):return

func astia_route():
 # The separate full Beast run proves approach, twelve floors, scale, battle and arrival in this room.
 await initial(16513,Vector2i(14,9),{"job_id":62})
 if not await speak("6335"):return
 check(Region.has_item(self,"beast_story"),"Qualified post-Beast conversation awards source EndEvent92")
 if not await cross_to(400) or not await speak("6378"):return
 check(game.model.falan_floor==14010,"Recognized traveller enters the original Sando landing")
 for id in [14011,14012,14013,14014,14015,14016,4100,14016,14015,14014,14013,14012,14011,14010,400]:
  if not await cross_to(id):return
 check(game.model.falan_floor==Original.SHALENA_SOUTH,"All seven Sando floors and boundary gateway return to the regional road")

func teleport_route():
 var jenova=branch_name.begins_with("jenova");var voucher=branch_name.ends_with("voucher");var source=4099 if jenova else 4399;var actor="6339" if jenova else "6562"
 var items={}
 if voucher:items["source_item_18660" if jenova else "source_item_18448"]=true
 await initial(4000 if jenova else 4300,Vector2i(43,40) if jenova else Vector2i(36,49),items)
 if not await regular_go(source) or not await speak(actor):return
 check(game.model.falan_floor==source and Region.has_item(self,("jenova" if jenova else "abanis")+"_teleport_registered"),"First visit registers this town without travelling")
 var before:int=game.model.gold
 if not await speak(actor):return
 check(game.model.falan_floor==1522 and game.model.gold==before-(0 if voucher else 375),"Registered teleport preserves the original gold/voucher charge")
 if voucher:check(Region.has_item(self,"source_item_18660") if jenova else not Region.has_item(self,"source_item_18448"),"Permanent and consumed vouchers retain distinct ownership")
 var at=Tour.Indoor.Data.FLOORS[1522][1]+Vector2(15,4)*3. if jenova else Tour.Indoor.Data.FLOORS[1522][1]+Vector2(37,4)*3.
 check(position_2d().distance_to(at)<5.,"Town-specific original teleport arrival is retained")

func regular_allowed(id:int)->bool:
 var source=Original.source_id(id)
 return source in [400,402,15000,15001,15002,15006,15007,15008,15009,15010,15011,15012,14000,14001,14002,4000,4001,4002,4008,4009,4010,4011,4012,4013,4020,4021,4022,4099,4300,4308,4309,4310,4312,4313,4320,4321,4322,4333,4334,4399,4400,4401,4402,4410,4411,4412,4413,4416,4417,4418,4419,4420,4422,4423,4424,4430,4431,4432,4451,4403,4404,4405,4406,4407,4408,4409,59752] or Original.generated().branch(id)=="scientist"

func regular_go(target:int,cell:Vector2i=Vector2i(-1,-1))->bool:
 target=game.explorer_clock.phase_floor(Original.runtime_id(target))
 var desired=actor_components(target,cell) if cell.x>=0 else []
 var first=Vector2i(game.model.falan_floor,component(game.model.falan_floor,position_2d()))
 var queue=[first];var parents={first:first};var stairs={};var last=Vector2i(-1,-1)
 for here:Vector2i in queue:
  if here.x==target and (desired.is_empty() or here.y in desired):last=here;break
  for link in Original.links(here.x,341):
   var id:int=game.explorer_clock.phase_floor(int(link.get("floor",-1)))
   if not regular_allowed(id) or component(here.x,link.at)!=here.y:continue
   var next=Vector2i(id,component(id,link.arrival))
   if next.y<0 or parents.has(next):continue
   parents[next]=here;stairs[next]=link;queue.append(next)
 check(last.x>=0,"Ordinary source component graph reaches "+str(target))
 if last.x<0:return false
 var route=[];var cursor=last
 while cursor!=first:route.push_front(stairs[cursor]);cursor=parents[cursor]
 for link:Dictionary in route:
  if not await cross_to(int(link.floor),link):return false
 return true

func campus_route():
 await initial(15000,Vector2i(22,32),{"signed_stamps":5})
 for id in [15001,15002,4000,4001,4002,4008,4009,4010,4011,4012,4013,4020,4021,4022,4099,14000,14001,14002,4300,4308,4309,4310,4312,4313,4320,4321,4322,4399,4400,4410,4411,4412,4413,4416,4417,4418,4419,4420,4422,4423,4424,4451]:
  if id==4417:game.explorer_clock.hour=12.
  if not await regular_go(id):return
  if id==4417:check(game.model.falan_floor==4417,"Daytime music room uses its distinct original state")
 if not await regular_go(4419) or not await cross_to(59752):return
 if not await speak("808112"):return
 check(Region.active(self,59752).is_empty(),"Missing mounted Sylph phase withholds the full fight without consuming the five stamps")
 if not await cross_to(4419):return
 game.explorer_clock.hour=21.
 if not await regular_go(4431) or not await speak("6740"):return
 check(game.model.falan_floor==4432,"Original night ghost enters the distinct secret music state")
 if not await regular_go(4401) or not await speak("6736"):return
 for n in range(1,6):
  if not await cross_to(Original.generated().floor_id("scientist",n)):return
 if not await cross_to(4430):return
 check(game.model.falan_floor==4430,"All five scientist floors return to the alternate laboratory")
 if not await regular_go(4400) or not await regular_go(4403,Vector2i(28,38)) or not await speak("6735"):return
 for id in [4404,4405]:
  if not await regular_go(id):return
 if not await regular_go(4403,Vector2i(34,14)) or not await speak("1102642"):return
 for id in [4406,4407,4408,4409]:
  if not await regular_go(id):return
 if not await speak("1102643"):return
 check(Region.active(self,4409).is_empty() and Region.has_item(self,"azure_medicine"),"Missing Azure reward layout withholds battle and preserves the medicine")
 if not await regular_go(402):return

func romance_hall_route():
 var items={} if branch_name=="hall_default" else {"source_item_40808":true} if branch_name=="hall_earring" else {"source_item_40804":true,"source_item_40806":true}
 await initial(4410,Vector2i(35,20),items)
 var hall=32269 if Region.romance_eligible(self) else 51019
 if not await cross_to(4418):return
 check(game.model.falan_floor==hall,"Original quest items choose the alternate auditorium; ordinary visits retain4418")
 if hall==32269:
  game.explorer_npcs.prepare()
  check(not game.explorer_npcs.actors.any(func(actor):return actor.record.id=="source:1102305"),"Unavailable source231008 is recorded as a blocker, not substituted with a fabricated Ami")
 for id in [4419,4420,4400]:
  if not await cross_to(id) or not await cross_to(4418):return
 if not await cross_to(4410):return
 check(game.model.falan_floor==51014,"Allfour auditorium door pairs preserve their normal returns")

func memory_gateway_route():
 await initial(400,Vector2i(553,252),{"source_item_41146":true,"source_item_41149":true,"source_item_41151":true,"source_item_41153":true})
 if not await speak("1102658"):return
 check(game.model.falan_floor==32183 and Region.has_item(self,"four_beast_memory_access"),"Allfour original sacred-beast gifts open the memory gateway")
 check(["source_item_41146","source_item_41149","source_item_41151","source_item_41153"].all(func(key_):return not Region.has_item(self,key_)) and int(get_meta(Region.ITEMS,{}).get("source_item_41217",0))==3,"First access consumes four gifts and awards exactly three source tokens")
 if not await speak("1102660") or not await cross_to(32181):return
 check(Region.has_item(self,"four_beast_memory_access"),"Gateway leads to the existing independent other-world hub; regional reconstruction ends here")

func tina_child_route():
 await initial(400,Vector2i(576,270),{"source_item_41174":true})
 if not await speak("1102730"):return
 check(game.model.falan_floor==game.explorer_clock.phase_floor(51005) and Region.has_item(self,"source_item_41178") and not Region.has_item(self,"source_item_41174"),"The child's source handoff consumes the outside-quest letter, grants the gift and reaches the existing Tina hub")

func actor_components(id:int,cell:Vector2i)->Array:
 var result=[]
 for step in [Vector2i.ZERO,Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT]:
  var label_=component(id,Original.point(id,cell+step,341))
  if label_>=0 and label_ not in result:result.append(label_)
 return result

func ice_allowed(id:int)->bool:
 return Original.owns(id) and (id in [401,15400,15402,20414,20428] or id>=20501 and id<=20530)

func ice_go(target:int,cell:Vector2i=Vector2i(-1,-1))->bool:
 var events=preload("res://assets/maps/falan/university_region/ice_events.gd").EVENTS
 var desired=actor_components(target,cell) if cell.x>=0 else []
 var torch_=2 if Region.has_item(self,"blue_torch") else 1 if Region.has_item(self,"torch") else 0
 var first=Vector3i(game.model.falan_floor,component(game.model.falan_floor,position_2d()),torch_)
 var queue=[first];var parents={first:first};var actions={};var last=Vector3i(-1,-1,-1)
 for here:Vector3i in queue:
  if here.x==target and (desired.is_empty() or here.y in desired):last=here;break
  var choices=[]
  for link in Original.links(here.x,341):
   var id:int=link.get("floor",-1)
   if not ice_allowed(id) or component(here.x,link.at)!=here.y:continue
   choices.append({"next":Vector3i(id,component(id,link.arrival),here.z),"link":link})
  for key_:String in events:
   var event:Dictionary=events[key_]
   if int(event.source)!=here.x or here.y not in actor_components(here.x,Vector2i(event.cell[0],event.cell[1])):continue
   if event.kind=="torch" and here.z==0:choices.append({"next":Vector3i(here.x,here.y,1),"actor":key_})
   elif event.kind=="flame" and here.z==1:choices.append({"next":Vector3i(here.x,here.y,2),"actor":key_})
   elif event.kind=="candle" and here.z==2:
    var id=int(event.target[0]);var arrival=Original.source_point(id,Vector2i(event.target[1],event.target[2]))
    choices.append({"next":Vector3i(id,component(id,arrival),1),"actor":key_})
  for choice:Dictionary in choices:
   var next:Vector3i=choice.next
   if next.y<0 or parents.has(next):continue
   parents[next]=here;actions[next]=choice;queue.append(next)
 check(last.x>=0,"Original torch/component graph reaches %d %s"%[target,cell])
 if last.x<0:return false
 var route=[];var cursor=last
 while cursor!=first:route.push_front(actions[cursor]);cursor=parents[cursor]
 for step:Dictionary in route:
  if step.has("actor"):
   if not await speak(step.actor):return false
   check(game.model.falan_floor==step.next.x and component(step.next.x,position_2d())==step.next.y,"Candle reaches its exact original walk component "+step.actor)
  elif not await cross_to(step.next.x,step.link):return false
  if failures>0:return false
 return true

func ice_route():
 await initial(400,Vector2i(528,212),{"opener":true,"job_rank":2})
 if not await speak("6453"):return
 for id in [14004,14005,14006,14007,402,4500]:
  if not await cross_to(id):return
 if not await speak("6455") or not await cross_to(402) or not await cross_to(4501):return
 if not await speak("6457"):return
 await fight(func():return get_meta(Region.BATTLES,{}).get("altar",{}).get("complete",false),func(enemy):return enemy.get("university_battle","")=="altar")
 check(game.model.falan_floor==4502,"Both altar formations transfer to the source post-fight room")
 if not await speak("6458"):return
 if not await ice_go(15402) or not await ice_go(20501,Vector2i(17,46)):return
 if not await speak("6582"):return
 for variant in [20515,20516,20517,20518,20524]:
  if not await ice_go(variant):return
 if not await ice_go(20527,Vector2i(46,47)) or not await speak("6464"):return
 await fight(func():return get_meta(Region.BATTLES,{}).get("ruby",{}).get("complete",false),func(enemy):return enemy.get("university_battle","")=="ruby")
 if not await speak("6470"):return
 for variant in [20519,20525,20520,20521,20522,20526]:
  if not await ice_go(variant):return
 if not await ice_go(20414,Vector2i(27,11)) or not await speak("6465"):return
 await fight(func():return get_meta(Region.BATTLES,{}).get("fribo",{}).get("complete",false),func(enemy):return enemy.get("university_battle","")=="fribo")
 if not await speak("6466") or not await speak("6467"):return
 check(game.model.falan_floor==1530 and Region.has_item(self,"dragon_trial"),"Altar, thirteen ice floors, Ruby, Fribo and Brumel return complete")
 var visited={}
 for row:Dictionary in crossings+conversations:visited[int(row.from)]=true;visited[int(row.to)]=true
 for id in [401,15400,15402,20414,20428,20001,20530]+range(20501,20523)+range(20524,20528):check(visited.has(id),"Actual original stairs/candles cover every ice floor and alternate state "+str(id))

func save():
 if not is_instance_valid(game) or game.model==null:return
 var file=FileAccess.open(REVIEW+"continuous-"+branch_name+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"branch":branch_name,"crossings":crossings,"conversations":conversations,"battles":battles_played,"movement_frames":movement_frames,"placements_after_approach":0,"injected_hits":0,"fixture_prerequisites":fixture_items,"final_items":get_meta(Region.ITEMS,{}),"battle_state":get_meta(Region.BATTLES,{}),"player_local":[position_2d().x,position_2d().y],"waves_spawned":game.model.waves.spawned,"fixture_starting_gold":100000,"invincible":game.tuning.invincible,"rendered":DisplayServer.get_name()!="headless","failures":failures,"floor":game.model.falan_floor},"  "));file.close()
