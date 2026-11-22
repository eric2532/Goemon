extends "res://tests/forest-shrine/shared_hit_feedback_review.gd"
## Render every selectable fighter's native hotbar against real native hurtboxes.
const REVIEW="res://build/Other Files/Asset Toolkit/Whole Roster Impact Review/"
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
var cases=[]
var case_hits=0
var duplicate_contacts=0
var case_duplicates=0
var max_effects=0
var last_frame=0
var sample_frames=[]
var case_cpu=[]
var case_focus=0

func input_action(action:String,down:bool):
 var event=InputEventAction.new();event.action=action;event.pressed=down
 if down:game.player._unhandled_input(event)
 else:game.player._input(event)

func advance(count:int):
 await driver.advance(count,func(dt):
  var started=Time.get_ticks_usec()
  game.player._physics_process(dt)
  runtime.step(dt,{});runtime.dispatch_events();runtime.sync_compatibility()
  var victims={}
  for event in runtime.presentation_events:
   if event.kind!="damage" or int(event.get("team",0))!=0:continue
   case_hits+=1
   var victim=int(event.target_id)
   if victims.has(victim):case_duplicates+=1
   victims[victim]=true
  runtime.presentation_delta+=dt;runtime.presentation_dirty=true;runtime.flush_presentation()
  if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(dt)
  max_effects=maxi(max_effects,game.crowd.army.presentation.effects.size())
  case_cpu.append((Time.get_ticks_usec()-started)/1000.0)
  if DisplayServer.get_name()!="headless" and DisplayServer.window_is_focused():case_focus+=1
  var now=Time.get_ticks_usec()
  if last_frame>0:sample_frames.append((now-last_frame)/1000.0)
  last_frame=now)

func distribution(values:Array)->Dictionary:
 if values.is_empty():return {}
 values.sort()
 return {"p95":values[floori(values.size()*.95)],"max":values[-1]}

func prepare_case(id:int):
 var p=game.player
 p.cancel_charge();Pool.service(game).release_owner(p)
 runtime.clear();runtime.set_navigation(8000+cases.size(),{"width":0})
 game.actors.clear();game.enemies.clear();game.model.enemies.clear();game.crowd.army.presentation.clear()
 p.select_character(1 if id!=1 else 5);p.select_character(id);fresh()
 if p.active_ability!=null:
  p.active_ability.cancel();p.active_ability.clear_cooldowns()
  if p.active_ability.has_method("reset_run"):p.active_ability.reset_run()
 p.spell_loadout.retired_cooldowns.clear();p.hp=p.max_hp;p.invuln=0
 var distance=18.0 if id in [27,29] else 3.0
 for i in 12:
  var x=0.0 if i==0 else (i%4-1.5)*1.4
  var row=game.model.waves.spawn_enemy(4 if i==11 and id in [27,29] else 0,ORIGIN+Vector3(x,0,-distance-floori(i/4)*4))
  row.hp=1000000;row.max_hp=row.hp;row.stun=100
 runtime.import_arrivals();runtime.sync_targets();game.model.update_vision(ORIGIN)
 var camera=game.camera_rig.camera
 if id==18:
  game.camera_rig.yaw=0;game.camera_rig.pitch=0;game.camera_rig.update_camera(0)
 else:
  var large=id in [27,29]
  camera.position=ORIGIN+(Vector3(28,22,38) if large else Vector3(5,5,10))
  camera.look_at(ORIGIN+Vector3(0,4 if large else 1.2,-distance))
 await advance(3)

func review_case(id:int,number:int):
 await prepare_case(id)
 var p=game.player
 var slot=Catalog.hotbar(id)[number-1] if number else ["Primary","light_attack"]
 if id==19 and number==2:
  tap("jump");await advance(20)
 case_hits=0;case_duplicates=0;case_cpu.clear();sample_frames.clear();case_focus=0;last_frame=0
 var photographed=false;var first_hit=-1
 if number:p.spell_loadout.number_input(number,true)
 else:input_action("light_attack",true)
 if id==18 and number:input_action("light_attack",true)
 var duration=300 if id==30 or (id==29 and number==1) else 240 if id==16 and number==1 else 150
 for tick in duration:
  if tick==15 and (id in [5,7,9,10,11,31,32] and number in [2,3] or id==13 and number==2):
   if id==7 and number==3:pass
   elif id==13 and number==2:
    game.tuning.invincible=false;p.invuln=0;p.take_hit(1,Vector3.BACK);game.tuning.invincible=true
   else:tap("light_attack")
  if tick==15 and id==7 and number==4:
   game.tuning.invincible=false;p.invuln=0;p.take_hit(1,Vector3.BACK);game.tuning.invincible=true
  if id==8 and number==2:
   if tick==15:tap("jump")
   if tick==35:tap("heavy_attack")
  if tick==(130 if id==16 and number==1 else 60):
   if number:p.spell_loadout.number_input(number,false)
   input_action("light_attack",false)
  await advance(1)
  if first_hit<0 and case_hits>0:first_hit=tick
  if not photographed and (tick==duration-2 or (first_hit>=0 and tick>=first_hit+2)) and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(REVIEW+"Captures/fighter-%02d-slot-%d.png"%[id,number]);photographed=true;last_frame=0
 var row={"fighter":id,"slot":number,"name":slot[0],"damage_events":case_hits,"same_tick_extra_contacts":case_duplicates,"frames":duration,"focused":case_focus,"step_ms":distribution(case_cpu),"frame_ms":distribution(sample_frames)}
 cases.append(row);duplicate_contacts+=case_duplicates
 check(Pool.service(game).misses==0,"Prepared projectiles cover fighter %d slot %d"%[id,number])
 print("ROSTER_IMPACT_CASE ",JSON.stringify(row))

func run():
 create_timer(600).timeout.connect(func():printerr("ROSTER_IMPACT_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+"Captures"))
 var document=load("res://scripts/forest/forest_map_document.gd").new();document.load_wind_meadow()
 await setup_fixture(document.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.explorer_helpers.set_process(false)
 for node in [game,game.player,game.camera_rig]:node.set_process_input(false);node.set_process_unhandled_input(false)
 game.camera_focused=false;game._sync_camera_mouse();game.camera_focused=true;game.music.stop();game.ui.hide()
 game.training_dummy.collision_layer=0;game.training_dummy.hide();game.enemies.erase(game.training_dummy)
 game.settings.spell_loadouts={};game.settings.disable_character_cooldowns=false;game.tuning.invincible=true
 runtime=game.army_runtime
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 if DisplayServer.get_name()!="headless":
  root.title="Goemon · Whole roster impact review";root.set_flag(Window.FLAG_ALWAYS_ON_TOP,true)
  DisplayServer.window_move_to_foreground();root.grab_focus()
 var selected=Catalog.Roster.selection_ids()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--fighters="):selected=Array(arg.trim_prefix("--fighters=").split(",")).map(func(id):return int(id))
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
 for id in selected:
  await review_case(id,0)
  for number in range(1,6):
   if not Catalog.hotbar(id)[number-1].is_empty():await review_case(id,number)
 var report={"checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"cases":cases,"extra_contacts":duplicate_contacts,"max_effects":max_effects,"capacity":game.crowd.army.presentation.effect_capacity,"pool_misses":Pool.service(game).misses,"note":"Native primary and hotbar input; no-hit support/context cases are reported, not asserted as impact coverage. Isolated step timings are not full battle FPS."}
 FileAccess.open(REVIEW+"rendered-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("ROSTER_IMPACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"cases":cases.size(),"extra_contacts":duplicate_contacts,"max_effects":max_effects}))
 game.queue_free();current_scene=null;paused=false;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
