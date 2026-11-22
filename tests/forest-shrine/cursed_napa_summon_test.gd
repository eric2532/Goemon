extends "res://tests/forest-shrine/cursed_original_effects_test.gd"
const NAPA_REVIEW=REVIEW+"Napa Recovery/"

func run():
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NAPA_REVIEW))
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/cursed-napa-summon.cfg";root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 set_meta(Winter.SLAIN,{})
 var id=Decree.GUARDIAN_FLOORS[0]
 var entry=Original.links(Decree.floor_id(9)).filter(func(l):return l.get("floor")==id)[0]
 Tour.travel(game,Original.layout(id),{"arrival":entry.arrival,"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 8:await physics_frame
 game.paused=true;game.tuning.invincible=true
 var runtime=game.army_runtime
 runtime.set_process(false);runtime.set_physics_process(false);runtime.native.set_targets({})
 runtime.record_events=true
 var p=game.crowd.army.presentation
 var boss:Dictionary=game.model.enemies.values().filter(func(row):return row.get("boss",false))[0]
 check(boss.enemy_name=="納帕","Actual source Napa chamber is loaded")
 var children=p.get_child_count()
 for cycle in 3:
  p.effects.clear()
  var attendants=game.model.enemies.values().filter(func(row):return not row.get("boss",false))
  var slain=[]
  for row in attendants.slice(0,2):
   slain.append(row.frostpass_slot);runtime.damage_enemy(row.id,row.max_hp*20)
  runtime.dispatch_events();runtime.sync_compatibility()
  var before=game.model.enemies.keys()
  game.model.waves.reinforce_decree(boss.id);runtime.import_arrivals();runtime.dispatch_events()
  var arrivals=game.model.enemies.values().filter(func(row):return row.id not in before)
  check(arrivals.size()==2,"Napa restores two fallen stable roster slots")
  var count_=game.model.enemies.size();game.model.waves.reinforce_decree(boss.id)
  check(game.model.enemies.size()==count_,"Repeated summon cannot duplicate living attendants")
  for row in arrivals:
   check(row.frostpass_slot in slain,"Reinforcement keeps its exact original encounter slot")
   check(runtime.unit_state(runtime.handles[row.id]).action==Spells.ARRIVAL,"Summoned creature enters through the existing native lifecycle")
  paint_arrivals()
  var bodies=p.effects.filter(func(e):return str(e.kind).begins_with("guardian-arrival-"))
  var lights=p.effects.filter(func(e):return e.kind=="ruby-native-110096")
  check(bodies.size()==2 and lights.size()==2,"Each reinforcement receives one prepared body and source light")
  check(lights.all(func(e):return e.loop and is_equal_approx(e.life,51.0/60) and is_equal_approx(e.opacity,128.0/255)),"Original 400ms light repeats for the recovered 51-update reveal with source alpha")
  if arrivals.is_empty():continue
  var target:Dictionary=arrivals[0]
  var at:Vector3=target.pos
  game.player.position=at+Vector3(3,0,2);game.model.update_vision(at/game.model.falan_scale)
  for tick in range(1,52):
   runtime.native.step(1.0/60);runtime.dispatch_events();paint_arrivals()
   game.paused=false;p.tick(1.0/60);game.paused=true
   if tick<51:check(runtime.unit_state(runtime.handles[target.id]).action==Spells.ARRIVAL,"Original reveal remains active until source update 51")
   if tick in [10,25,50] and DisplayServer.get_name()!="headless":
    var batch:MultiMeshInstance3D=p.batches["guardian-arrival-"+str(target.variant)]
    check(batch.multimesh.visible_instance_count==2,"Both growing bodies reach their existing pooled draw")
    check(is_equal_approx(batch.multimesh.get_instance_transform(0).basis.get_scale().x,Spells.manifest.summon.scales[tick]),"Rendered growth matches the emulated client step")
   if cycle==0 and tick in [10,25,50,51]:await capture_napa(tick,at)
  check(p.effects.all(func(e):return not str(e.kind).begins_with("guardian-arrival-") and e.kind!="ruby-native-110096"),"Original reveal releases both effects when the native unit becomes ready")
  check(runtime.unit_state(runtime.handles[target.id]).action!=Spells.ARRIVAL,"Full-sized reinforcement resumes its ordinary native controller")
  check(p.get_child_count()==children and p.effects.size()<=p.MAX_EFFECTS,"Repeated two-creature summons reuse bounded batches")
  print("NAPA_SUMMON_CYCLE ",cycle," live=",game.model.enemies.size())
 var snapshot:Dictionary=runtime.render_snapshot().duplicate(true)
 var row:int=p.undersea_row(boss.id)
 snapshot.render_actions[row]=Spells.CAST;snapshot.render_time[row]=.7
 var packed:Dictionary=runtime.native.instance_buffers(snapshot,game.crowd.army.native_profiles)
 var cast=packed.batches.filter(func(batch):return batch.key.x==Roles.SLIME)[0]
 check(int(cast.buffer[13])%8==7 and is_equal_approx(cast.buffer[14],.7),"Native packing preserves the complete original guardian casting clip and clock")
 var arriving:Dictionary=game.model.enemies.values().filter(func(enemy):return not enemy.get("boss",false))[0]
 runtime.native.begin_enemy_arrival(runtime.handles[arriving.id]);runtime.dispatch_events();paint_arrivals()
 Tour.travel(game,Original.layout(Decree.floor_id(9)),{"arrival":Vector2.ZERO,"yaw":0.0,"velocity":Vector3.ZERO})
 game.paused=true
 check(game.crowd.army.presentation.effects.is_empty(),"Leaving the maze clears an unfinished summon without stale handles")
 print("NAPA_SUMMON_RESULT checks=",checks," failures=",failures)
 await finish()

func paint_arrivals():
 var runtime=game.army_runtime
 runtime.sync_compatibility()
 game.crowd.present_army(runtime.render_snapshot(),runtime.presentation_events)
 runtime.presentation_events.clear()

func capture_napa(tick:int,at:Vector3):
 if DisplayServer.get_name()=="headless":return
 await capture_effect("napa-step-%02d"%tick,at+Vector3.UP*2)
 var source=ProjectSettings.globalize_path(REVIEW+"Effects Recovery/napa-step-%02d.png"%tick)
 DirAccess.rename_absolute(source,ProjectSettings.globalize_path(NAPA_REVIEW+"step-%02d.png"%tick))
