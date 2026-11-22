extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
const Progression=preload("res://scripts/forest/cave_progression.gd")
const CAPTURE="res://build/Other Files/Cave Progression/"
# skin: [level, HP, damage]; expected values are independent of the production table.
const CASES={
 11003:{2:[12,3600,63]},11005:{2:[16,4800,75]},
 11004:{0:[25,30000,200],1:[20,10000,87]},
 11000:{4:[18,9000,81]},11001:{3:[25,30000,200],4:[20,10000,87]},11002:{4:[22,11000,93]},
 15003:{0:[40,48000,320],1:[20,9000,87],2:[20,8000,87]},
 15593:{1:[26,11700,105],2:[26,10400,105]},
 15505:{0:[35,42000,280],1:[24,10800,99],2:[23,9200,96],3:[20,7000,87]},
 16503:{0:[20,24000,160],1:[15,4500,72],2:[15,6000,72]},
 16508:{0:[50,60000,400],1:[30,12000,117],2:[30,9000,117]},
 47017:{0:[80,96000,640],1:[70,35000,237],2:[90,108000,720],3:[60,18000,207]},
}
const COUNTS={11003:42,11005:42,11004:10,11000:32,11001:41,11002:32,15003:45,15593:48,15505:13,16503:5,16508:10,47017:3}
var checks=0

func _initialize():
 create_timer(360).timeout.connect(func():printerr("CAVE_PROGRESSION_TIMEOUT");quit(1))
 run.call_deferred()

func check(ok:bool,message:String):
 checks+=1
 super.check(ok,message)

func run():
 DirAccess.make_dir_recursive_absolute(CAPTURE)
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/goemon-cave-progression-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.equipment_hub.enter_button.pressed.emit()
 check(game.playing and game.model.phase=="wave","Enter Map starts the live exploration run")
 game.set_physics_process(false);game.player.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 game.player.set_auto_attack(false);game.tuning.invincible=true
 game.settings.forest_level_up_cards=false
 for floor_:int in CASES:
  await visit(floor_)
  var runtime=game.army_runtime
  var units:Array=game.model.enemies.values()
  check(units.size()==COUNTS[floor_],"Original encounter count: %d (%d)"%[floor_,units.size()])
  if units.is_empty():continue
  await verify_units(floor_,units)
  if floor_==47017:
   game.paused=false
   for row in units:runtime.apply_hit(runtime.handles[row.id],{"amount":row.max_hp*2,"magical":true})
   game.model.waves.tick_grave(0,Vector3(3,0,-15))
   runtime.import_arrivals();runtime.sync_compatibility()
   units=game.model.enemies.values().filter(func(row):return row.hp>0)
   check(units.size()==3,"Defeating the first party starts the stronger second phase")
   await verify_units(floor_,units)
   var rebel=units.filter(func(row):return row.skin==3)[0]
   var old:int=rebel.id
   runtime.apply_hit(runtime.handles[old],{"amount":rebel.max_hp*2,"magical":true})
   game.model.waves.tick_grave(8,Vector3(3,0,-15));runtime.import_arrivals()
   var replacements=game.model.enemies.values().filter(func(row):return row.skin==3 and row.hp>0 and row.id!=old)
   check(replacements.size()==2 and replacements.all(func(row):return row.level==60 and row.max_hp==18000),"Reinforcements keep their level without accumulating scaling")
  var row:Dictionary=units[0]
  var rewards=game.model.team_progression
  rewards.reset();rewards.cards_enabled=false
  var expected=load("res://scripts/forest/team_progression.gd").new()
  expected.cards_enabled=false;expected.award_enemy(row.xp_reward_tenths)
  game.paused=false
  runtime.apply_hit(runtime.handles[row.id],{"amount":row.max_hp*2,"magical":true})
  check(rewards.level==expected.level and is_equal_approx(rewards.experience(),expected.experience()),"Native cave death awards scaled XP")
  runtime.damage_enemy(row.id,row.max_hp*2)
  check(rewards.level==expected.level and is_equal_approx(rewards.experience(),expected.experience()),"Dead cave unit cannot award twice")
  game.forest_ui._physics_process(0)
  check(not game.forest_ui.patrol_target.visible or game.crosshair_ray_hit().get("collider")!=runtime.enemies.get(row.id),"Death clears the defeated target; another living target may appear behind it")
  print("CAVE_PROGRESSION_FLOOR ",floor_," checked=",units.size())
 # The retained partial-floor resources also have rising levels.
 for level in [18,20,22]:
  var row={}
  Progression.apply(row,Progression.HABARU[4],Habaru.STATS,level)
  check(row.level==level and row.hp==500*level,"Bear-cave depth grows health: "+str(level))
 print("CAVE_PROGRESSION_RESULT checks=",checks," failures=",errors)
 await finish()

func visit(floor_:int):
 game.paused=false
 Tour.travel(game,Tour.Indoor.layout(floor_),{"arrival":Vector2.ZERO,"yaw":0.0})
 game.set_physics_process(false);game.player.set_physics_process(false)
 game.model.team_progression.cards_enabled=false
 var runtime=game.army_runtime
 runtime.finish_integration();runtime.refresh_navigation(0)
 var waves=game.model.waves
 game.habaru_dialogue_seen=true
 match floor_:
  11004:waves.tick_habaru(Vector3.ZERO)
  11003,11005:waves.tick_habaru_slimes()
  11000,11001,11002:waves.tick_venoa_bears(Tour.Regions.Sites.VENOA_BEARS[floor_])
  15003,15593:waves.tick_undersea(Vector3(24,0,12))
  15505:waves.tick_zombie_cave(Vector3.ZERO,Tour.Regions.Sites.ZOMBIE_FORMATIONS[floor_]+game.model.Dungeons.ZOMBIE_PATROLS)
  16503:
   var at:Vector2=Tour.Regions.Sites.CAPTAIN_FORMATION[0][0]
   waves.tick_captain(Vector3(at.x,0,at.y))
  16508:waves.tick_ruby(Vector3(-3,0,-42))
  47017:waves.tick_grave(0,Vector3(3,0,-15))
 runtime.import_arrivals();runtime.sync_compatibility()
 game.paused=true
 for i in 2:await physics_frame

func verify_units(floor_:int,units:Array):
 var runtime=game.army_runtime
 var seen={}
 for row:Dictionary in units:
  var want:Array=CASES[floor_][row.skin]
  var handle:int=runtime.handles.get(row.id,0)
  var state:Dictionary=runtime.unit_state(handle)
  check(row.level==want[0] and row.hp==want[1] and state.get("max_hp")==want[1],"Native level/HP: %d skin %d"%[floor_,row.skin])
  var boss:bool=row.get("boss",false) or row.get("undersea_slot",-1)==0
  check(row.has("enemy_name") and row.xp_reward_tenths==10*want[0]*(5 if boss else 1),"Cave XP uses monster level with a fivefold boss reward")
  if seen.has(row.skin):continue
  var point:Vector3=state.position
  var target=point
  for radius in [.8,1.2,1.8,2.4]:
   for angle in 8:
    var candidate=point+Vector3(sin(angle*PI/4),0,cos(angle*PI/4))*radius
    candidate.y=game.model.world_height(candidate.x,candidate.z)
    if runtime.native.can_reach(point,candidate,.55):target=candidate;break
   if target!=point:break
  if target==point:continue
  seen[row.skin]=true
  var targets:Dictionary=runtime.external_targets()
  targets.positions[0]=target;targets.targetable[0]=1
  runtime.native.set_targets(targets);runtime.take_events()
  var hits=[]
  for i in 360:
   runtime.native.step(1.0/30)
   hits.append_array(runtime.take_events().filter(func(event):return event.kind=="external_damage" and event.source_id==row.id))
   if hits.size()>=2:break
  check(hits.size()>=2 and hits.all(func(hit):return is_equal_approx(hit.amount,want[2]*(2 if hit.action_index==Habaru.DOUBLE_EDGE else 1))),"Repeated scaled native attacks: %d/%d"%[floor_,row.skin])
 for skin in units.map(func(row):return row.skin):
  check(seen.has(skin),"Repeated native contact tested for skin %d on floor %d"%[skin,floor_])
 runtime.native.set_targets(runtime.external_targets());runtime.sync_compatibility()
 var row:Dictionary=units[0]
 var actor=runtime.enemy_target(row.id)
 var aim:Vector3=actor.combat_bounds().get_center()
 var camera:Camera3D=game.camera_rig.camera
 game.paused=false
 for angle in 8:
  var direction=Vector3(sin(angle*PI/4),0,cos(angle*PI/4))
  game.player.position=actor.position+direction*3
  game.model.update_vision(game.player.position)
  camera.global_position=aim+direction*6;camera.look_at(aim);camera.reset_physics_interpolation()
  await physics_frame
  if game.crosshair_ray_hit().get("collider")==actor:break
 game.forest_ui._physics_process(0)
 check(game.forest_ui.patrol_target.visible and game.forest_ui.patrol_target.text=="%s · Lv.%d"%[row.enemy_name,row.level],"Only cave monster name and level are displayed")
 var count=game.forest_ui.get_child_count()
 for i in 30:game.forest_ui._physics_process(0)
 check(game.forest_ui.get_child_count()==count,"Repeated cave targeting reuses the HUD")
 if DisplayServer.get_name()!="headless":
  game.crowd.present_army(runtime.render_snapshot(),[])
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(CAPTURE+"%d-%d.png"%[floor_,row.skin])==OK,"Capture cave progression")
