extends "res://scripts/recovered_leaders_tests.gd"
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Habaru=preload("res://scripts/forest/crowd/habaru_sprites.gd")
const OUT="res://build/Other Files/Asset Toolkit/Habaru Counter/"
const DT=1.0/60
var army
var handle:int
var boss_id:int
var costs:Array[int]=[]
var caption:Label
var review_cuts=false
var review_ticks=0
func state()->Dictionary:return army.unit_state(handle)
func advance(hit:bool=false):
 var start=Time.get_ticks_usec()
 if hit:army.apply_hit(handle,{"amount":1.0,"source_id":0})
 army.integration_tick(DT);army.flush_presentation()
 costs.append(Time.get_ticks_usec()-start)
 review_ticks+=1
 if DisplayServer.get_name()!="headless" and (review_ticks<=330 or review_cuts):await physics_frame
func wait_brace():
 for i in 240:
  await advance(true)
  if state().action==Habaru.BRACE:return
 check(false,"Sustained hits reach the defense warning")
func picture(stem:String,text:String):
 if DisplayServer.get_name()=="headless":return
 caption.text=text;game.forest_ui.hide()
 var at:Vector3=state().position
 game.camera_rig.camera.global_position=at+Vector3(12,10,19)
 game.camera_rig.camera.look_at(at+Vector3.UP*2.2)
 game.model.update_vision(at)
 army.presentation_dirty=true;army.flush_presentation()
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)
func run():
 create_timer(180).timeout.connect(func():printerr("HABARU_COUNTER_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 set_meta("forest_custom_layout",Tour.Indoor.layout(11004))
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://habaru-counter-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;await frames(5)
 var p=game.player;p.select_character(34);p.auto_attack_enabled=false
 p.position=game.model.world_point(Tour.Regions.Sites.HABARU_FORMATION[0]+Vector2(0,7),.15)
 game.checkpoint=p.position;game.start_wave();game.habaru_dialogue_seen=true
 if is_instance_valid(game.habaru_waiting):game.habaru_waiting.hide()
 if is_instance_valid(game.habaru_talk_hint):game.habaru_talk_hint.hide()
 game.model.waves.tick_habaru(p.position);await frames(5)
 army=game.army_runtime;army.record_events=true;game.tuning.invincible=true
 game.set_physics_process(false);game.set_process(false);p.set_physics_process(false)
 army.set_process(false);game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 for node in [game,p,game.camera_rig]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 for row in game.model.enemies.values():
  if row.habaru_slot==0:boss_id=row.id
 handle=army.handles[boss_id]
 var overlay=CanvasLayer.new();root.add_child(overlay);caption=Label.new();caption.position=Vector2(24,25);caption.add_theme_font_size_override("font_size",24);overlay.add_child(caption)
 check(game.model.enemies.size()==10,"The native encounter retains the boss and nine bears")
 check(state().max_hp==30000,"Boss HP remains 30,000")
 check(Habaru.motions().actions.map(func(value):return int(value))==[0,3,5,8,10,1,9],"The prepared bank includes original defense action 9")
 # Isolate the boss without changing the game's encounter, saved settings or assets.
 for row in game.model.enemies.values():
  if row.id!=boss_id:army.despawn(army.handles[row.id]);game.model.enemies.erase(row.id)
 var at:Vector3=state().position;p.position=at+Vector3(0,.05,2.8);p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
 army.set_pose(handle,at,0);army.native.set_guard(handle,at,14*game.model.falan_scale)
 for i in 90:await advance(true)
 check(state().action==6 and state().stun>0,"The first 1.5 seconds retain satisfying flinch and attack interruption")
 await picture("01-combo","Combo opening · normal hit reactions")
 var fx=game.crowd.army.presentation
 fx.label_ages.fill(.65);fx.label_capacity=0
 await wait_brace()
 check(fx.labels.any(func(label):return label.visible and label.text=="!"),"The warning can reclaim a pooled label even with damage labels disabled or full")
 fx.label_capacity=fx.MAX_LABELS
 check(state().action==Habaru.BRACE and state().blocking and state().stun==0,"Sustained pressure enters the native defense state")
 check(game.crowd.army.presentation.effects.any(func(e):return e.kind=="zombie-warning" and e.owner_id==boss_id),"An orange ground warning accompanies defense")
 var before:float=state().hp
 var incoming=Vector3(sin(state().yaw),0,cos(state().yaw))
 army.apply_hit(handle,{"amount":100.0,"direction":incoming})
 check(is_equal_approx(before-state().hp,25.0),"Defending reduces frontal damage through the existing guard rule")
 before=state().hp;army.apply_hit(handle,{"amount":100.0,"direction":-incoming})
 check(is_equal_approx(before-state().hp,100.0) and state().action==Habaru.BRACE,"Rear hits retain full damage without erasing the warning")
 for i in 30:await advance()
 await picture("02-defense-warning","Defense warning · move behind him or get clear")
 var yaw:float=state().yaw;army.event_log.clear()
 for i in 120:
  await advance(true)
  if state().action==Habaru.COUNTER:break
 check(state().action==Habaru.COUNTER and not state().blocking,"Defense releases into his original counterattack")
 for i in 28:await advance()
 await picture("03-counter-windup","Counterattack · normal hits deal damage but cannot interrupt")
 for i in 120:
  await advance(true)
  if i%12==0:await picture("motion-%02d"%i,"Counterattack · original two-contact sequence")
  if state().action!=Habaru.COUNTER:break
 var contacts=army.event_log.filter(func(e):return e.kind=="external_damage" and e.source_id==boss_id)
 check(contacts.size()==2 and contacts.all(func(e):return e.amount==200),"Both original counter contacts retain 200 damage")
 check(is_equal_approx(state().yaw,yaw),"The committed counter cannot turn to track the player")
 army.event_log.clear()
 for i in 30:await advance()
 check(army.event_log.all(func(e):return e.kind!="external_damage" or e.source_id!=boss_id),"Counter recovery cannot immediately attack again")
 await picture("04-recovery","Recovery opening · resume your combo")
 for i in 50:await advance(true)
 await wait_brace();yaw=state().yaw
 p.position=state().position+Vector3(sin(yaw),.02,cos(yaw))*2.8
 army.event_log.clear()
 for i in 30:await advance()
 await picture("05-move-behind","Move behind his defense · the committed counter can miss")
 for i in 180:
  await advance()
  if state().action not in [Habaru.BRACE,Habaru.COUNTER]:break
 check(army.event_log.all(func(e):return e.kind!="external_damage" or e.source_id!=boss_id),"Moving behind the real cave boss avoids both committed contacts")
 for i in 80:await advance()
 await wait_brace();army.apply_hit(handle,{"element":"stun","status_seconds":2.0})
 check(state().stun==2.0 and not state().blocking,"A dedicated stun breaks defense")
 army.flush_presentation()
 check(not game.crowd.army.presentation.effects.any(func(e):return e.kind=="zombie-warning" and e.owner_id==boss_id),"Interrupting defense removes its warning immediately")
 for i in 150:await advance()
 await wait_brace();army.apply_hit(handle,{"element":"ice","status_seconds":1.0})
 check(state().frozen==1.0 and not state().blocking,"Freeze also interrupts defense")
 for i in 90:await advance()
 # Actual Kaz contacts at the existing 3x cap can still combo, but cannot lock him forever.
 p.powerups.attack_speed=20;p.attack_speed_stacks=4
 var kit=p.active_ability;var saw_counter=false;before=state().hp;review_cuts=true
 for i in 420:
  p.position=state().position+Vector3(0,.05,2.8);p.facing=Vector3.FORWARD
  p.auto_lock_target=army.enemy_target(boss_id);p.auto_lock_refresh=100;p.auto_attack_enabled=true
  if not kit.is_attacking():kit.start_attack()
  kit.tick(DT);await advance()
  if state().action==Habaru.COUNTER:saw_counter=true
 p.auto_attack_enabled=false;kit.cancel();review_cuts=false
 check(state().hp<before and saw_counter,"Real repeated Kaz cuts retain damage and allow the boss to counter")
 # Repeated warmed cycles reuse presentation resources.
 for i in 240:await advance(true)
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var sample_start=costs.size()
 for i in 1200:await advance(true)
 await frames(3)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated counter cycles retain no extra nodes or resources")
 var samples=costs.slice(sample_start);samples.sort()
 var report={"checks":checks,"failures":failures,"manual_step_p95_ms":samples[int(samples.size()*.95)]/1000.0,"manual_step_max_ms":samples[-1]/1000.0,"display":DisplayServer.get_name(),"frame_time_measurement":false}
 var file=FileAccess.open(OUT+"%s-results.json"%DisplayServer.get_name(),FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close()
 var path=game.settings_path;stop_audio(game);game.queue_free();overlay.queue_free();current_scene=null;paused=false;await frames(5)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("HABARU_COUNTER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
