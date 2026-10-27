extends "res://tests/forest-shrine/dark_lumina_3_test.gd"
const EVIDENCE=OUT+"Controls/"
const WaveShot=preload("res://scripts/kojiro_projectile.gd")
var visual=false
var launches=[]
var step_times=[]
var frame_times=[]
func key(number:int):
 var event=InputEventKey.new();event.physical_keycode=KEY_1+number-1;event.keycode=event.physical_keycode;event.pressed=true
 Input.parse_input_event(event);Input.flush_buffered_events()
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events()
func click(button:int=MOUSE_BUTTON_LEFT):
 var event=InputEventMouseButton.new();event.button_index=button;event.position=root.get_visible_rect().size*.5;event.global_position=event.position;event.pressed=true
 Input.parse_input_event(event);Input.flush_buffered_events()
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events()
func advance(count:int):
 var previous=Time.get_ticks_usec()
 for i in count:
  var start=Time.get_ticks_usec();game.player._physics_process(1.0/60);game.crowd.army.presentation.tick(1.0/60)
  for nodes in Pool.service(game).all.values():
   for shot in nodes:
    if shot.pool_live and shot.get_script() in [preload("res://scripts/dark_lumina_3_projectile.gd"),WaveShot]:shot._physics_process(1.0/60)
  step_times.append((Time.get_ticks_usec()-start)/1000.0)
  if visual:
   await physics_frame
   var now=Time.get_ticks_usec();frame_times.append((now-previous)/1000.0);previous=now
  elif i%30==0:await process_frame
func capture(name_:String):
 if not visual:return
 game.forest_ui.sync();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(EVIDENCE+name_+".png")
func run():
 visual=DisplayServer.get_name()!="headless"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
 create_timer(150).timeout.connect(func():printerr("DARK_LUMINA_3_CONTROLS_TIMEOUT");quit(1))
 await setup_fixture()
 root.title="Goemon · Dark Lumina 3 controls"
 root.set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.set_process(false);game.model.phase="wave"
 var p=game.player;p.select_character(30);fresh();var c=p.active_ability
 game.ui.show();game.forest_ui.show();game.forest_ui.sync()
 check(game.ui.visible and game.forest_ui.is_visible_in_tree(),"The real gameplay HUD is visible during input verification")
 game.camera_rig.camera.position=ORIGIN+Vector3(18,14,28);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,4,-10))
 var pool=Pool.service(game);var prepared=pool.created;var misses=pool.misses
 root.focus_exited.connect(func():print("CONTROLS_FOCUS_EXIT mode=",c.mode," combo=",c.combo))
 pool.launched.connect(func(shot):
  if shot.get_script()==preload("res://scripts/dark_lumina_3_projectile.gd"):
   shot.set_physics_process(false);launches.append({"kind":shot.kind,"secondary":shot.secondary,"cross":shot.cross_slash,"roll":shot.slash_yaw,"point":shot.position,"damage":shot.damage,"wave":false,"piercing":shot.piercing})
  elif shot.get_script()==WaveShot:
   shot.set_physics_process(false)
   if shot.kind=="wind":launches.append({"kind":0,"secondary":false,"cross":false,"roll":0.0,"point":shot.position,"damage":shot.damage,"wave":true,"piercing":true}))
 for number in range(1,6):
  c.cancel();launches.clear();key(number)
  check(c.mode=="attack" and c.move==number,"Real key %d reaches its spell through the HUD"%number)
  game.forest_ui.sync()
  var button=game.forest_ui.loadout_buttons[number-1]
  check(not button.disabled and button.tooltip_text.contains(Finale.NAMES[number]),"Spell %d is visible and named in the hotbar"%number)
  check(is_equal_approx(p.attack_duration,Finale.moves[number].size()/30.0/c.CAST_RATE),"Spell %d uses the faster cast window"%number)
  await advance(104 if number==5 else 67)
  await capture("spell-%d-%s"%[number,Finale.NAMES[number].to_lower()])
  await advance(ceil(Finale.moves[number].size()*2/c.CAST_RATE)+90)
  check(not c.is_attacking() and p.model.body.visible,"Fast spell %d finishes and restores control"%number)
  var primary=launches.filter(func(s):return s.kind==number and not s.secondary).size()
  check(primary==[0,22*Finale.WIND_FAN+1,6,32,0,5][number],"Fast spell %d preserves its projectile releases"%number)
 check(pool.created==prepared and pool.misses==misses,"Faster spells stay within prepared projectile leases")
 fresh();p.position=ORIGIN;p.facing=Vector3.FORWARD
 check(game.forest_ui.primary_icon.tooltip_text.contains("LMB · Kojiro’s Wind wave") and not game.forest_ui.spell_summary.text.contains("RMB"),"HUD shows the energy sequence as the only default attack")
 click(MOUSE_BUTTON_RIGHT);check(not c.is_attacking() and not c.queued_cut,"RMB while idle does not attack")
 launches.clear()
 var dummy=game.training_dummy;dummy.home=ORIGIN+Vector3(0,0,-5);dummy.position=dummy.home
 p.ai_controlled=true;p.ai_aim=dummy.position+Vector3.UP
 c.start_attack();c.tick(c.SWORD_SECTIONS[0].contact/30.0/c.CAST_RATE+.001);p.ai_controlled=false
 check(contacts==[1],"Default energy cut connects once (contacts=%s)"%str(contacts))
 check(launches.size()==1 and is_equal_approx(launches[0].damage,65*Finale.DAMAGE[0]),"Default energy cut keeps the former RMB projectile damage (launches=%s)"%str(launches))
 c.cancel()
 for nodes in pool.all.values():
  for shot in nodes:
   if shot.pool_live:shot.retire()
 fresh();dummy.position=ORIGIN+Vector3(50,0,0);dummy.home=dummy.position;launches.clear()
 var prior_effects=game.crowd.army.presentation.effects.size()
 game.crowd.army.presentation.finale_cue(p.position,11,p.facing,c.get_instance_id(),88)
 check(game.crowd.army.presentation.effects.size()==prior_effects,"Energy release has no duplicate stationary slash")
 for section in 3:
  click()
  check(c.mode=="combo" and c.combo==section,"LMB click requests energy cut %d only"%(section+1))
  check(p.attack_duration<=.45,"Energy cut %d keeps its responsive timing"%(section+1))
  click(MOUSE_BUTTON_RIGHT)
  check(c.combo==section and not c.queued_cut,"RMB does not interrupt or buffer energy cut %d"%(section+1))
  var release_frames=ceili(c.SWORD_SECTIONS[section].contact*2/c.CAST_RATE)+1
  await advance(release_frames)
  check(launches.size()==section+1,"LMB cut %d releases exactly one energy projectile"%(section+1))
  if launches.size()>section:
   var shot=launches[section]
   check(shot.wave==(section==0) and shot.cross==(section>0) and shot.piercing,"Energy cut %d selects Kojiro’s wave / piercing energy blade"%(section+1))
   check(is_zero_approx(shot.roll),"Energy cut %d faces straight along its flight path"%(section+1))
   check(is_equal_approx(shot.point.y-p.position.y,0.08 if section==0 else 1.3*Finale.SCALE),"Kojiro’s Wind wave hugs the ground and the energy blades stay raised")
  await advance(4);await capture("energy-cut-%d"%(section+1))
  await advance(ceili(c.SWORD_SECTIONS[section].ticks*2/c.CAST_RATE)-release_frames+8)
  check(not c.is_attacking() and launches.size()==section+1,"One LMB click never plays the remaining cuts automatically")
 click();check(c.combo==0,"Fourth click wraps the energy sequence");c.cancel()
 click();await advance(100);click();check(c.combo==0,"An expired energy sequence restarts at the ground wave");c.cancel()
 launches.clear();click();click();check(c.queued_cut,"An early second LMB click buffers one energy continuation")
 await advance(90)
 check(not c.is_attacking() and launches.size()==2,"Buffered LMB stops after the two requested releases")
 c.cancel();click();key(2);check(c.mode=="attack" and c.move==2,"A spell key interrupts an energy cut")
 click(MOUSE_BUTTON_RIGHT);check(c.mode=="attack" and c.move==2,"RMB leaves the current spell alone")
 click();check(c.mode=="combo" and c.combo==0 and p.model.body.visible,"LMB immediately returns from a spell to the ground wave")
 click();c.interrupt_for_dodge();check(c.combo==-1 and not c.queued_cut,"Evade resets the energy sequence and buffer")
 c.start_attack();check(c.combo==0,"The automatic/default attack entry starts the energy sequence");c.cancel()
 var reused=pool.launch(p,preload("res://scripts/dark_lumina_3_projectile.gd"),"finale0",{"kind":0,"cross_slash":true,"slash_yaw":-Finale.SWORD_CROSS_ANGLE});reused.set_physics_process(false)
 var start_yaw=reused.visual.rotation.y;reused._physics_process(1.0/60)
 check(is_equal_approx(reused.visual.rotation.y,start_yaw) and is_zero_approx(reused.visual.rotation.z),"Flying crescent keeps its launch angle without spinning or tilting edge-on");reused.retire()
 reused=pool.launch(p,preload("res://scripts/dark_lumina_3_projectile.gd"),"finale0",{"kind":0});reused.set_physics_process(false)
 check(not reused.cross_slash and is_zero_approx(reused.visual.rotation.y),"Reusing a cross projectile restores the ground wave mesh and rotation");reused.retire()
 for repeat in 4:
  c.start_move(3);await advance(150)
 check(pool.created==prepared and pool.misses==misses,"Four consecutive fast 32-flame casts reuse the prepared pool")
 # Allow the full falling lifetime plus lingering ground fire after the final cast.
 await advance(480)
 check(not pool.all.values().any(func(nodes):return nodes.any(func(s):return s.pool_live and s.get_script()==preload("res://scripts/dark_lumina_3_projectile.gd"))),"Repeated fast hazards fully retire")
 p.select_character(1);game.forest_ui.sync();check(game.forest_ui.loadout_buttons[0].text=="1","Switching fighters restores ordinary slot labels")
 step_times.sort();frame_times.sort()
 var report={"checks":checks,"failures":failures,"prepared":prepared,"pool_after":pool.created,"misses":pool.misses-misses,"manual_step_ms_p95":step_times[floori(step_times.size()*.95)]}
 if visual:report.frame_median_ms=frame_times[frame_times.size()/2];report.frame_p95_ms=frame_times[floori(frame_times.size()*.95)];report.frame_max_ms=frame_times[-1]
 FileAccess.open(EVIDENCE+("rendered-results.json" if visual else "headless-results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("DARK_LUMINA_3_CONTROLS_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
