extends SceneTree
const OUT="res://build/Other Files/Asset Toolkit/Musashi Techniques/"
const Profile=preload("res://scripts/recovered_musashi_action_profile.gd")
var game
var p
var c
var driver
var origin:Vector3
var enemy
var mirrors
var checks=0
var failures=0
var times=[]
var frame_times=[]
var last_frame=0
var cfg="user://musashi-techniques-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func tap(action:String):
 var e=InputEventAction.new();e.action=action;e.pressed=true;p._unhandled_input(e)
 e.pressed=false;p._input(e)
func wait_mode(expected:String):
 for i in 60:
  if c.mode==expected:return
  await advance(1)
func advance(count:int):
 await driver.advance(count,func(delta):
  var start=Time.get_ticks_usec()
  p._physics_process(delta)
  if mirrors!=null:mirrors.tick(delta)
  times.append((Time.get_ticks_usec()-start)/1000.0)
  if DisplayServer.get_name()!="headless":
   if last_frame:frame_times.append((start-last_frame)/1000.0)
   last_frame=start
 )
func plant():
 c.cancel();c.locomotion.reset();p.attack_chain.reset();p.impact_pause=0;p.position=origin;p.velocity=Vector3.ZERO
 p.smoke_mode=true;p.smoke_move=Vector2.ZERO;p.facing=Vector3.FORWARD;p.invuln=0
 p.set_auto_attack(false)
 for i in 4:p.velocity=Vector3.DOWN*20;p.move_and_slide()
 p.velocity=Vector3.ZERO
func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 var previous=game.camera_rig.camera.global_transform
 var focus=p.global_position+Vector3(0,2,-1)
 if name_=="simultaneous-allies":focus=origin+Vector3(0,2,10)
 game.camera_rig.camera.global_position=focus+Vector3(12,8,8)*(2.0 if name_=="simultaneous-allies" else 1.0)
 game.camera_rig.camera.look_at(focus)
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Rendered "+name_)
 print("MUSASHI_TECHNIQUES_CAPTURE ",name_," mode=",c.mode," tick=",c.elapsed*30," position=",p.global_position)
 game.camera_rig.camera.global_transform=previous
func run():
 create_timer(180,true,false,true).timeout.connect(func():printerr("MUSASHI_TECHNIQUES_TIMEOUT");quit(1))
 if DisplayServer.get_name()!="headless":root.set_flag(Window.FLAG_NO_FOCUS,true)
 set_meta("forest_painterly_preview",true)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
 root.add_child(game);current_scene=game
 for i in 6:await process_frame
 game.start_wave();game.tuning.freeze_ai=true;game.tuning.invincible=true;game.tuning.critical_chance=0;game.character_tuning={}
 game.set_process(false);game.set_physics_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.camera_rig.process_mode=Node.PROCESS_MODE_DISABLED;game.music.stop()
 p=game.player;p.select_character(13);p.set_physics_process(false);c=p.active_ability
 origin=Vector3(0,game.model.surface_height(0,18)+.05,18)
 driver=preload("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 var row=game.model.waves.spawn_enemy(0,Vector3(0,origin.y,15));row.hp=100000;row.max_hp=100000
 game.model.update_vision(origin);game.sync_enemies();enemy=game.actors[row.id];enemy.set_physics_process(false)
 game.camera_rig.camera.global_position=origin+Vector3(8,7,13);game.camera_rig.camera.look_at(origin+Vector3(0,2,-2))
 await advance(3);plant();await advance(3)
 check(p.is_on_floor(),"Actual Wind Meadow collision grounds the technique fixture")
 check(game.army_runtime!=null and enemy.handle!=0,"Contacts use the native army owner")
 for key in ["crosswise","tenderize","tenderize_end","desperado","desperado_dual","desperado_end"]:
  check(p.model.animation_player.has_animation(Profile.action(key).clip),"Recovered body entry: "+key)
 check(Profile.action("tenderize_end").clip=="Recovered__800d524c","Continuation uses prepared drawn-Lumina context")
 # Input buffering must not create a Crosswise hit on a missed/blocked Fusion.
 plant();tap("light_attack");p.facing=Vector3.BACK;await advance(8);tap("heavy_attack");await advance(65)
 check(c.mode!="crosswise" and p.model.crosswise_effect.cursor==0,"A missed opener cannot invent X Slash contact")
 plant();var hp=enemy.hp
 tap("light_attack");await advance(8);var before_press=enemy.hp;tap("heavy_attack")
 check(c.mode=="fusion" and enemy.hp==before_press,"Buffered heavy cannot add a hit on press")
 await wait_mode("crosswise")
 check(c.mode=="crosswise" and enemy.hp<hp,"Fusion recovery consumes buffered heavy into Crosswise after contact: %s %.3f %s %.3f"%[c.mode,c.elapsed,c.buffered_action,c.buffer_left])
 # Contact follows the falling blade at ticks 10–11, after its raised tick-8 pose.
 var after=enemy.hp;await advance(24)
 check(enemy.hp<after and c.crosswise_impact_done,"Crosswise has its own native damage and original hit sprite")
 check(p.model.crosswise_effect.cursor==1,"One Crosswise action emits exactly one impact")
 after=enemy.hp;await advance(8);check(enemy.hp==after,"Repeated active samples cannot hit the same victim twice")
 await capture("crosswise-contact")
 # Extend the same chain into its original two-sword sequence.
 var before_desperado=enemy.hp
 tap("light_attack");await wait_mode("desperado")
 check(c.mode=="desperado","Crosswise then light enters Desperado's Fusion entry")
 await advance(12);tap("heavy_attack");await wait_mode("desperado_dual")
 check(c.mode=="desperado_dual" and c.controls_motion(),"Next heavy enters the original dual-sword motion")
 for i in 40:
  if c.technique_ticks>=9:break
  await advance(1)
 await capture("desperado-dual")
 check(p.model.dual_sword_trail.action=="desperado_fusion","Both original weapon ribbons are live during Desperado")
 await advance(80)
 check(not c.is_attacking() and p.is_on_floor(),"Desperado lands, recovers and returns control")
 check(enemy.hp<before_desperado,"Desperado's recovered blade contacts damage the native target")
 # Two Fusion clicks followed by heavy must select the distinct two-hit lift.
 plant();tap("light_attack");await advance(8);tap("light_attack")
 for i in 50:
  if c.mode=="fusion" and c.combo==1:break
  await advance(1)
 check(c.mode=="fusion" and c.combo==1,"Second light click enters Fusion2")
 await advance(14);tap("heavy_attack");await wait_mode("tenderize")
 check(c.mode=="tenderize","Fusion2 then heavy selects Tenderize after its final contact")
 var before_tenderize=enemy.hp
 var start_y=p.position.y;var peak=start_y
 for i in 120:
  await advance(1);peak=maxf(peak,p.position.y)
  if not c.is_attacking() and p.is_on_floor():break
 check(peak>start_y+.5,"Tenderize source event8 drives a real upward move")
 check(not c.is_attacking() and p.is_on_floor(),"Both Tenderize phases finish on physical ground")
 check(enemy.hp<before_tenderize,"Tenderize's recovered blade contacts damage the native target")
 plant();c.start_technique("tenderize");tap("heavy_attack");await advance(135)
 check(not c.queued_heavy and c.buffered_action.is_empty() and not c.is_attacking(),"An early follow-up expires across both Tenderize phases")
 # Native hotbar skills play the whole sequence, including their Fusion openers.
 for number in [1,2,3]:
  plant();var before_skill=enemy.hp;var seen=[];var tuning_matches=true;var posed=true
  p.spell_loadout.number_input(number,true);p.spell_loadout.number_input(number,false)
  check(c.mode=="fusion" and enemy.hp==before_skill,"One-press skill starts with Fusion windup: %d"%number)
  for i in 240:
   if not c.is_attacking():break
   var phase=c.mode+str(c.combo) if c.mode=="fusion" else c.mode
   if not seen.has(phase):seen.append(phase)
   tuning_matches=tuning_matches and p.attack_ticket.get("skill_id","")=="musashi/"+["crosswise","tenderize","desperado"][number-1]
   posed=posed and p.model.current_clip==c.clip
   await advance(1)
  var required=[["fusion0","crosswise"],["fusion0","fusion1","tenderize","tenderize_end"],["fusion0","crosswise","desperado","desperado_dual","desperado_end"]][number-1]
  check(seen==required,"One press plays every ordered phase: %s got %s"%[number,str(seen)])
  check(tuning_matches,"Every combo phase retains its skill tuning")
  check(posed,"Every automatic phase animates Musashi's visible body")
  check(not c.is_attacking() and c.combo_skill.is_empty() and enemy.hp<before_skill,"One-press skill damages once per phase and finishes: %d"%number)
  await advance(8)
 plant();var instance_count=p.spell_loadout.instances.size()
 check(p.spell_loadout.equip(13,"special_4","musashi/desperado"),"Combo can be reassigned through Skills & Jump")
 p.spell_loadout.number_input(4,true);p.spell_loadout.number_input(4,false)
 check(c.combo_skill=="desperado" and p.spell_loadout.instances.size()==instance_count,"Reassigned Musashi combo reuses the native animated owner")
 c.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT);await advance(10)
 check(c.combo_skill.is_empty() and not c.is_attacking(),"Focus loss cannot resume an automated combo")
 p.spell_loadout.equip(13,"special_4","")
 plant();tap("surge");c.start_combo("desperado");c.hit();await advance(30)
 check(c.combo_skill.is_empty() and not c.is_attacking(),"A hit discards the entire automatic sequence")
 plant();p.position.y+=5;p.velocity=Vector3.UP;p.move_and_slide();c.start_combo("crosswise")
 check(not c.is_attacking(),"One-press ground combos cannot start in midair")
 p.select_character(1);p.position=origin;p.velocity=Vector3.ZERO
 for i in 4:p.velocity=Vector3.DOWN*20;p.move_and_slide()
 p.velocity=Vector3.ZERO
 p.spell_loadout.equip(1,"special_4","musashi/desperado")
 p.spell_loadout.number_input(4,true);p.spell_loadout.number_input(4,false)
 var borrowed=p.spell_loadout.current
 check(borrowed!=null and borrowed.controller.combo_skill=="desperado","The catalog combo can use the existing borrowed-skill owner")
 await advance(240)
 check(p.spell_loadout.current==null and borrowed.controller.combo_skill.is_empty(),"Borrowed combo finishes and releases movement")
 p.spell_loadout.equip(1,"special_4","");p.select_character(13);plant()
 # Focus, pause and selection must discard pending combo and pooled presentation.
 for kind in ["focus","pause","switch"]:
  plant();c.start_technique("desperado_dual");await advance(18)
  if kind=="focus":c.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
  elif kind=="pause":game.paused=true;c.tick(.1);game.paused=false
  else:p.select_character(1);p.select_character(13)
  check(not c.is_attacking() and not c.queued_heavy and not c.queued_primary,"Interruption clears motion and queued input: "+kind)
  check(p.model.crosswise_effect.flashes.all(func(f):return f.phase<0) and p.model.dual_sword_trail.action.is_empty(),"Interruption clears prepared effects: "+kind)
 # Repeated casts retain their prepared slots and exercise real native contacts.
 plant();await advance(5)
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 times.clear();frame_times.clear();last_frame=0
 for i in 12:
  plant();p.spell_loadout.number_input(1,true);p.spell_loadout.number_input(1,false);await advance(90)
  check(c.crosswise_impact_done,"Repeated Crosswise contact %d"%i)
 await advance(60);c.cancel();await process_frame;await process_frame
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes,"Repeated techniques retain no nodes")
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated techniques retain no resources")
 check(p.model.crosswise_effect.misses==0,"Prepared impact slots cover repeated use")
 var retained_nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes
 var retained_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 var repeated_times=times.duplicate();var repeated_frames=frame_times.duplicate()
 # Simultaneous allies reuse the real native mirror owner and prepared bodies.
 mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p);var targets=[];var seen_allies=[[],[],[],[],[]]
 for i in 5:
  var point=origin+Vector3((i-2)*6,0,12)
  check(mirrors.reinforce(13,point),"Native owner leases Musashi ally %d"%i)
  var target=game.model.waves.spawn_enemy(0,point+Vector3.FORWARD*3);target.hp=10000;target.max_hp=10000
  targets.append(target.id)
 game.sync_enemies()
 await advance(4)
 for i in mirrors.bodies.size():
  var body=mirrors.bodies[i];body.perform(2+i%3,body.global_position+Vector3.FORWARD*3)
 for tick in 210:
  for i in mirrors.bodies.size():
   var state=mirrors.bodies[i].active_ability.mode
   if not seen_allies[i].has(state):seen_allies[i].append(state)
  await advance(1)
  if tick==65:await capture("simultaneous-allies")
 for i in mirrors.bodies.size():
  check(seen_allies[i].has(["crosswise","tenderize","desperado_dual"][i%3]) and not mirrors.bodies[i].active_ability.is_attacking(),"Native ally completes its one-press combo")
  check(game.actors[targets[i]].hp<10000,"Simultaneous combo damages its native target")
 mirrors.clear()
 check(mirrors.bodies.all(func(body):return not body.leased and body.model.crosswise_effect.flashes.all(func(f):return f.phase<0)),"Native retirement clears every ally's prepared impacts")
 mirrors.dispose();mirrors=null;await process_frame;await process_frame
 plant();c.start_technique("tenderize")
 for i in 60:
  if c.technique_ticks>=12:break
  await advance(1)
 await capture("tenderize-lift");await advance(90)
 await capture("wind-meadow-ready")
 plant();game.army_runtime.damage_enemy(row.id,enemy.hp-1);c.start_technique("crosswise");await advance(40)
 check(enemy.dead and p.model.crosswise_effect.cursor==1,"A lethal Crosswise contact still emits its recovered impact")
 repeated_times.sort();repeated_frames.sort()
 print("MUSASHI_TECHNIQUES_PROFILE step_p95_ms=",repeated_times[int(repeated_times.size()*.95)]," step_max_ms=",repeated_times.back()," retained_nodes=",retained_nodes," retained_resources=",retained_resources)
 if not repeated_frames.is_empty():print("MUSASHI_TECHNIQUES_PHYSICS_INTERVAL p95_ms=",repeated_frames[int(repeated_frames.size()*.95)]," max_ms=",repeated_frames.back())
 game.sound_library.cancel();game.queue_free();driver.queue_free();current_scene=null
 for i in 4:await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MUSASHI_TECHNIQUES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
