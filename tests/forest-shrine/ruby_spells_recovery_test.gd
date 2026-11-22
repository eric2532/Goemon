extends "res://tests/forest-shrine/black_prayer_recovery_test.gd"
const RUBY_SPELL_REVIEW="res://build/Other Files/Asset Toolkit/Ruby Spells/"
var seen_spells:Dictionary={}
var resolved_spells:Dictionary={}
var healing_seen=false
var process_samples:PackedFloat64Array=[]
func review_folder()->String:return RUBY_SPELL_REVIEW

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var saved=JSON.stringify(get_meta("falan_venture"))
 await approach_black_prayer()
 await room(Tour.Prayer.ENTRY)
 for id:int in Tour.Prayer.FLOORS:await room(id)
 await room(Ruby.ROOM)
 await check_ruby_furniture()
 var original_hp:float=game.player.hp
 var original_max:float=game.player.max_hp
 game.tuning.invincible=true
 await position_at(Vector2(-3,-6))
 for frame in 8:await physics_frame
 var runtime=game.army_runtime
 var party:Array=game.model.enemies.values()
 check(party.size()==10,"The source ten-person Ruby party is intact")
 var boss_rows=party.filter(func(row):return row.get("ruby_slot",-1)==0)
 if boss_rows.is_empty():return
 var boss:Dictionary=boss_rows[0]
 for row in party:
  if row.id!=boss.id:runtime.apply_hit(runtime.handles[row.id],{"element":"ice","status_seconds":180.0})
  runtime.damage_enemy(row.id,row.max_hp*.20)
 runtime.record_events=true
 for tick in 3000:
  await physics_frame
  await observe_ruby(boss.id)
  if Ruby.SPELL_NAMES.keys().filter(func(action):return not Ruby.magic_attack(action)).all(func(action):return seen_spells.has(action)) and resolved_spells.has(Ruby.HOLY_SHIELD):break
 check(seen_spells.size()==11,"Ruby uses all eleven original support and defense spells before the low-Blade phase")
 check(healing_seen,"Healing and recovery restore actual native HP")
 var presentation=game.crowd.army.presentation
 check(presentation.batches.has("ruby-native-110026") and presentation.batches.has("ruby-native-110087"),"The boss reuses original Ice and Heal sheets through pooled batches")
 var materials={}
 for ref in Ruby.spell_art.clips:materials[ref]=presentation.batches["ruby-native-"+ref].multimesh.mesh.material
 var batch_count:int=presentation.get_child_count()
 var blades=party.filter(func(row):return row.skin==1)
 for row in blades.slice(0,3):runtime.damage_enemy(row.id,row.max_hp*2)
 for tick in 1500:
  await physics_frame
  await observe_ruby(boss.id)
  if [Ruby.FROST,Ruby.METEOR,Ruby.CONFUSION].all(func(action):return seen_spells.has(action)) and game.player.confusion_left>0:break
 print("RUBY_LATE_STATE phase=",game.model.phase," hp=",game.player.hp," paused=",paused," enemies=",game.model.enemies.size())
 check([Ruby.FROST,Ruby.METEOR,Ruby.CONFUSION].all(func(action):return seen_spells.has(action)),"Two surviving Blades unlock original Ice, Meteor and Confusion")
 check(game.player.confusion_left>0,"Original Confusion applies a real timed player control effect")
 runtime.apply_hit(runtime.handles[boss.id],{"element":"ice","status_seconds":20.0})
 game.tuning.invincible=true
 await check_confused_movement()
 check(presentation.get_child_count()==batch_count,"Repeated spells reuse prepared batches without new presentation nodes")
 for ref in materials:check(presentation.batches["ruby-native-"+ref].multimesh.mesh.material==materials[ref],"Repeated spells preserve shared original sheet materials")
 check(presentation.effects.size()<=presentation.MAX_EFFECTS,"Spell presentation stays within the existing bounded pool")
 for tick in 360:await physics_frame
 for row in game.model.enemies.values().duplicate():
  for attempt in 3:
   if not game.model.enemies.has(row.id):break
   runtime.damage_enemy(row.id,row.max_hp*3)
   for frame in 3:await physics_frame
 for tick in 300:await physics_frame
 check(game.model.enemies.is_empty() and get_meta(Ruby.SLAIN,{}).size()==10,"All spell states retire through the shared death and reward ledger")
 check(not presentation.effects.any(func(e):return str(e.kind).begins_with("ruby-")),"Original spell effects expire after their owners retire")
 game.player.hp=original_hp;game.player.max_hp=original_max
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Spell/scenery recovery preserves the saved adventure")
 process_samples.sort()
 var p95=process_samples[int(process_samples.size()*.95)] if not process_samples.is_empty() else 0.0
 print("RUBY_SPELL_FRAME_SAMPLE p95_ms=",p95," max_ms=",process_samples[-1] if not process_samples.is_empty() else 0," samples=",process_samples.size())
 print("RUBY_SPELL_RECOVERY_RESULT spells=",seen_spells.size()," checks=",checks," failures=",errors)

func observe_ruby(boss_id:int):
 process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
 var events:Array=game.army_runtime.event_log.duplicate()
 game.army_runtime.event_log.clear()
 for event in events:
  if event.kind!="status":continue
  var action=int(event.get("action_index",0))
  if action==Zombie.HEAL and event.get("amount",0)>0:healing_seen=true
  if action==Ruby.WARD_ACTIVE and event.source_id==boss_id:
   resolved_spells[int(event.amount)]=true
   if DisplayServer.get_name()!="headless" and int(event.amount) in [Ruby.PHYSICAL_ABSORB,Ruby.MAGIC_REFLECT,Ruby.HOLY_SHIELD]:await spell_shot("ward-"+str(int(event.amount)),boss_id)
  if event.get("source_id")!=boss_id or not Ruby.spell_action(action) or event.get("source_tick")!=30:continue
  if action==Ruby.CONFUSION:
   await position_at(Vector2(event.position.x,event.position.z)/game.model.falan_scale)
   game.player.invuln=0
  if not seen_spells.has(action):
   seen_spells[action]=true
   print("RUBY_ORIGINAL_SPELL ",action," ",Ruby.SPELL_NAMES[action])
   if DisplayServer.get_name()!="headless" and action in [Ruby.MEND,Ruby.RECOVER,Ruby.FROST,Ruby.METEOR,Ruby.CONFUSION]:
    for frame in (50 if Ruby.magic_attack(action) else 32):await physics_frame
    await spell_shot("spell-"+str(action),boss_id,event.position if Ruby.magic_attack(action) else Vector3.INF)

func spell_shot(label_:String,boss_id:int,focus:Vector3=Vector3.INF):
 var point:Vector3=game.army_runtime.unit_state(game.army_runtime.handles[boss_id]).position/game.model.falan_scale
 if focus!=Vector3.INF:point=focus/game.model.falan_scale
 var eye=Vector2(point.x+6.0,point.z+8.0)
 var target=Vector2(point.x,point.z)
 await shot(label_,game.model.world_point(eye,6.3),game.model.world_point(target,2.3),70)

func check_confused_movement():
 var hero=game.player
 var home=Tour.Indoor.safe_point(Ruby.ROOM,Vector2(-3,-6),game.model.seed_value)
 await position_at(home)
 game.camera_rig.yaw=0;hero.velocity=Vector3.ZERO;hero.confusion_left=2
 Input.action_press("move_forward")
 var before:Vector3=hero.position
 for tick in 10:await physics_frame
 Input.action_release("move_forward")
 check(hero.position.z>before.z+.03,"Confusion reverses actual forward input")
 hero.confusion_left=0;hero.velocity=Vector3.ZERO
 await position_at(home)
 before=hero.position
 Input.action_press("move_forward")
 for tick in 10:await physics_frame
 Input.action_release("move_forward")
 check(hero.position.z<before.z-.03,"Normal controls resume when Confusion ends")

func check_ruby_furniture():
 var root_=game.world.find_child("ArchivedRubyProps",true,false)
 var shelves=root_.get_children().filter(func(n):return n.get_meta("blue_cg_serial",0) in [16079,16080,16143])
 check(shelves.size()==10 and shelves.all(func(n):return n is MeshInstance3D),"Ten original bookcases use solid 3D cases and source-painted book fronts")
 var shared={}
 for shelf in shelves:
  var serial=int(shelf.get_meta("blue_cg_serial"))
  if shared.has(serial):check(shelf.mesh==shared[serial],"Repeated source bookcases reuse one mesh")
  shared[serial]=shelf.mesh
  var bounds:AABB=shelf.mesh.get_aabb()
  check(bounds.size.x<=12.01 and bounds.size.z<=3.0 and bounds.end.y<=8.5,"Shelf depth and trim stay inside the archived footprint and ceiling")
 var pedestals=root_.get_children().filter(func(n):return n.get_meta("blue_cg_serial",0)==16100)
 check(pedestals.size()==1 and pedestals[0] is MeshInstance3D and pedestals[0].find_child("OriginalBlueOrnament",true,false)!=null,"The original pedestal has a solid stem and preserved blue ornament pixels")
 if DisplayServer.get_name()!="headless":
  var shelf=shelves.filter(func(n):return n.get_meta("blue_cg_serial")==16080)[0]
  await shot("palace-library",shelf.to_global(Vector3(0,5.0,9)),shelf.to_global(Vector3(0,4,0)),70)
