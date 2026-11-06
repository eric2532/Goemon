extends SceneTree
const OUT="res://build/Other Files/Asset Toolkit/Musashi Leaping Strike/"
const SKILL="musashi/leaping-strike"
var game
var p
var driver
var origin:Vector3
var enemy
var mirrors
var checks=0
var failures=0
var samples=[]
var frame_intervals=[]
var last_frame=0
var cfg="user://musashi-leaping-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func tap(action:String,body=null):
 if body==null:body=p
 var e=InputEventAction.new();e.action=action;e.pressed=true
 if body.ai_controlled:body.spell_loadout.input(e)
 else:body._unhandled_input(e)
 e.pressed=false;body.spell_loadout.release_input(e);body._input(e)
func advance(count:int):
 await driver.advance(count,func(delta):
  var start=Time.get_ticks_usec();p._physics_process(delta)
  if mirrors!=null:mirrors.tick(delta)
  samples.append((Time.get_ticks_usec()-start)/1000.0)
  if DisplayServer.get_name()!="headless":
   if last_frame:frame_intervals.append((start-last_frame)/1000.0)
   last_frame=start)
func plant(id:int):
 p.spell_loadout.cancel()
 if p.active_ability!=null:p.active_ability.cancel()
 p.select_character(id);p.set_physics_process(false);p.set_auto_attack(false)
 p.attack_chain.reset();p.impact_pause=0;p.position=origin;p.velocity=Vector3.ZERO
 p.smoke_mode=true;p.smoke_move=Vector2.ZERO;p.facing=Vector3.FORWARD;p.invuln=0
 if id==13:p.active_ability.locomotion.reset()
 for i in 4:p.velocity=Vector3.DOWN*20;p.move_and_slide()
 p.velocity=Vector3.ZERO
func airborne(height:float=5):
 p.position.y+=height;p.velocity=Vector3.UP;p.move_and_slide();p.jumps_used=2
 if p.character_id==13:
  p.active_ability.locomotion.airborne=true;p.active_ability.locomotion.jumps_used=2
func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 var focus=p.position+Vector3(0,1,0)
 game.camera_rig.camera.global_position=focus+Vector3(9,5,10);game.camera_rig.camera.look_at(focus)
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Rendered "+name_)
func run():
 create_timer(180,true,false,true).timeout.connect(func():printerr("LEAP_TIMEOUT");quit(1))
 if DisplayServer.get_name()!="headless":root.set_flag(Window.FLAG_NO_FOCUS,true)
 set_meta("forest_painterly_preview",true)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
 root.add_child(game);current_scene=game
 for i in 6:await process_frame
 game.start_wave();game.tuning.freeze_ai=true;game.tuning.invincible=true;game.tuning.critical_chance=0;game.character_tuning={}
 game.set_process(false);game.set_physics_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.camera_rig.process_mode=Node.PROCESS_MODE_DISABLED;game.music.stop()
 p=game.player;p.set_physics_process(false)
 origin=Vector3(0,game.model.surface_height(0,18)+.05,18)
 driver=preload("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 var row=game.model.waves.spawn_enemy(0,Vector3(0,origin.y,16));row.hp=100000;row.max_hp=100000
 game.model.update_vision(origin);game.sync_enemies();enemy=game.actors[row.id];enemy.set_physics_process(false)
 plant(13);await advance(4)
 check(p.is_on_floor(),"Fixture uses physical Wind Meadow ground")
 var nodes_before=p.spell_loadout.instances.size()
 check(p.spell_loadout.equip(13,"special_5",SKILL),"Leaping Strike is an equippable catalog skill")
 check(p.spell_loadout.instances.size()==nodes_before,"Native Musashi uses his existing visible controller")
 p.spell_loadout.number_input(5,true);p.spell_loadout.number_input(5,false)
 check(not p.active_ability.is_attacking(),"Aerial skill key cannot cast from the ground")
 tap("light_attack");check(p.active_ability.mode=="fusion","Equipped skill preserves ground attack")
 plant(13);tap("jump");await advance(12)
 check(not p.is_on_floor() and p.jumps_used==1,"First jump remains manual")
 tap("jump");await advance(5)
 check(p.jumps_used==2,"Second jump remains manual")
 var hp=enemy.hp;tap("light_attack")
 var c=p.active_ability
 check(c.combo_skill=="leaping-strike" and c.finisher_phase=="hover","Airborne attack starts recovered apex phase")
 check(enemy.hp==hp,"No damage on input")
 check(p.attack_ticket.get("skill_id","")==SKILL,"Native strike keeps skill damage tuning")
 tap("heavy_attack");await advance(4)
 check(c.finisher_phase=="hover" and p.jumps_used==2,"Attack spam cannot restart or refill jumps")
 await advance(12);await capture("musashi-downstroke")
 check(p.model.current_clip==c.clip,"Visible Musashi plays the recovered strike")
 await advance(110)
 check(p.is_on_floor() and not c.is_attacking() and c.combo_skill.is_empty(),"Physical landing and recovery return control")
 check(enemy.hp<hp,"The strike damages a native army enemy")
 var after=enemy.hp;await advance(15);check(enemy.hp==after,"Completed strike cannot leave stale hits")
 plant(13);tap("jump");await advance(10);tap("light_attack")
 check(c.combo_skill=="leaping-strike" and p.jumps_used==1,"Equipped skill also works after the first jump")
 plant(13);airborne();tap("heavy_attack")
 check(c.combo_skill=="leaping-strike","Heavy attack also triggers the equipped aerial skill")
 c.hit();await advance(2);check(not c.is_attacking(),"Hit interruption clears the dive")
 plant(13);airborne();p.spell_loadout.number_input(5,true);p.spell_loadout.number_input(5,false)
 check(c.combo_skill=="leaping-strike","Assigned skill key also works while airborne")
 p.spell_loadout.equip(13,"special_5","")
 check(not c.is_attacking(),"Unequipping cancels the native dive")
 tap("light_attack")
 check(c.action_key in ["air_fusion","moving_air_fusion"],"Unequipping restores normal aerial attacks")
 plant(1);p.spell_loadout.equip(1,"special_4",SKILL);p.jump_style.equip(1,"musashi");await advance(4)
 tap("jump");await advance(12);tap("jump");await advance(5)
 check(not p.is_on_floor() and p.jumps_used==2,"Another fighter can use the same double-jump style")
 hp=enemy.hp;tap("light_attack");var donor=p.spell_loadout.current
 check(donor!=null and donor.controller.combo_skill=="leaping-strike","Air attack routes through prepared reusable spell owner")
 var prepared=donor.get_instance_id();await advance(16);await capture("goemon-downstroke")
 check(p.jumps_used==2 and donor.hero_state.attack_ticket.get("skill_id","")==SKILL,"Borrowed dive preserves jump budget and tuning")
 await advance(130)
 check(p.spell_loadout.current==null and p.is_on_floor() and enemy.hp<hp,"Borrowed strike hits and returns movement on landing")
 await advance(4)
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 samples.clear();frame_intervals.clear();last_frame=0
 for i in 12:
  plant(1);airborne();tap("light_attack")
  check(p.spell_loadout.current==donor and donor.get_instance_id()==prepared,"Repeated use reuses prepared owner %d"%i)
  await advance(120)
 await advance(30)
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes,"Repeated use retains no nodes")
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated use retains no resources")
 var retained_nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes
 var retained_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 samples.sort();print("LEAP_PROFILE step_p95_ms=",samples[int(samples.size()*.95)]," max_ms=",samples.back()," retained_nodes=",retained_nodes," retained_resources=",retained_resources)
 if not frame_intervals.is_empty():
  frame_intervals.sort();print("LEAP_PHYSICS_INTERVAL p95_ms=",frame_intervals[int(frame_intervals.size()*.95)]," max_ms=",frame_intervals.back())
 for interruption in ["unequip","pause","focus","switch"]:
  plant(1);p.spell_loadout.equip(1,"special_4",SKILL);airborne();tap("light_attack");await advance(4)
  if interruption=="unequip":p.spell_loadout.equip(1,"special_4","")
  elif interruption=="pause":game.paused=true;p.spell_loadout.tick(.1);game.paused=false
  elif interruption=="focus":p.spell_loadout.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
  else:p.select_character(13)
  await advance(2)
  check(p.spell_loadout.current==null,"Borrowed skill cancels on "+interruption)
 plant(9);p.spell_loadout.equip(9,"special_5",SKILL);airborne();tap("heavy_attack")
 check(p.spell_loadout.current!=null,"Rogue fighter can borrow the same aerial strike")
 await advance(16);await capture("swordsman-downstroke")
 check(p.active_ability.player.attack==null and p.active_ability.player.dive==null,"Borrowed pose does not start a second combat controller")
 await advance(120);check(p.is_on_floor() and p.spell_loadout.current==null,"Rogue borrower recovers after the dive")
 plant(13);p.spell_loadout.equip(13,"special_5",SKILL)
 mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
 for i in 5:
  check(mirrors.reinforce(13,origin+Vector3((i-2)*5,5,12)),"Native owner leases aerial ally")
 for body in mirrors.bodies:
  body.velocity=Vector3.UP;body.move_and_slide();body.jumps_used=2
  tap("light_attack",body)
 check(mirrors.bodies.all(func(body):return body.active_ability.combo_skill=="leaping-strike"),"Five allies share the equipped attack routing")
 await advance(150)
 check(mirrors.bodies.all(func(body):return not body.active_ability.is_attacking()),"Simultaneous allies finish their dive")
 mirrors.clear();mirrors.dispose();mirrors=null
 game.sound_library.cancel();game.queue_free();driver.queue_free();current_scene=null
 for i in 4:await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MUSASHI_LEAP_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
