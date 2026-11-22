extends SceneTree
## Real menu clicks/keys recruit paid native defenders directly at the castle.
var game
var checks=0
var failures=0
var cfg="user://guard-hiring-%d.cfg"%OS.get_process_id()
func _initialize():
 set_meta("forest_painterly_preview",true)
 create_timer(90).timeout.connect(func():printerr("FAIL: guard hiring timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func settle():
 for i in 3:await process_frame
func capture(label_:String):
 if "--visual" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":return
 RenderingServer.force_draw();await process_frame
 root.get_texture().get_image().save_png("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Mercenary Base Hiring/"+("wind-" if "--wind" in OS.get_cmdline_user_args() else "original-")+label_+".png")
func tap(code:int,echo:bool=false):
 var key=InputEventKey.new();key.physical_keycode=code;key.pressed=true;key.echo=echo;root.push_input(key,true)
 key=key.duplicate();key.pressed=false;root.push_input(key,true)
func click(button:Button):
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=button.get_global_rect().get_center()
 root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true)
 await settle()
func run():
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
 var doc=load("res://tests/forest-shrine/reference/map_document.gd").new()
 if "--wind" in OS.get_cmdline_user_args():doc.load_wind_meadow()
 else:doc.load_original()
 set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 await settle();AudioServer.set_bus_mute(0,true)
 game.set_physics_process(false);game.player.set_physics_process(false)
 var h=game.explorer_helpers;var ui=game.forest_ui;var army=game.army_runtime
 game.model.gold=5000;game.model.starting_food=100;game.player.select_character(18);ui.sync()
 var shrine:Vector3=game.model.center(game.model.shrine())
 game.player.position=shrine+Vector3(80,0,80)
 tap(KEY_M);await settle()
 check(ui.guard_shop_open(),"M opens mercenaries")
 for size_ in [Vector2i(1280,800),Vector2i(800,600)]:
  root.size=size_;await settle()
  var gold=game.model.gold;var food=game.model.food_used()
  for index in 5:
   var slot=ui.MERCENARY_SHORTCUTS[index];var button=ui.guard_shop.buttons[slot]
   check(button.text.begins_with("%d · "%[index+1]) and not button.disabled,"All five cards show a numbered clickable recruit")
   check(ui.guard_shop.panel.get_global_rect().encloses(button.get_global_rect()),"Every card including Knight fits inside the tray")
   var before=h.active_units(slot).size()
   await click(button)
   check(h.active_units(slot).size()==before+1,"Actual pointer click hires exactly one "+h.NAMES[slot])
   check(not h.placement_active() and ui.guard_shop_open() and game.build_kind.is_empty(),"Recruitment keeps the tray open without map placement")
  check(game.model.gold==gold-470 and game.model.food_used()==food+10,"Five clicks deduct exactly the displayed prices and food")
  check(ui.hint.size.x>=300 and ui.hint.size.y<=96,"Hiring feedback remains readable in the current window")
  if size_.x==800:await capture("small-window")
 root.size=Vector2i(1280,800);await settle()
 var gold=game.model.gold;var food=game.model.food_used()
 for index in 5:
  var slot=ui.MERCENARY_SHORTCUTS[index];var before=h.active_units(slot).size()
  tap(KEY_1+index);await settle()
  check(h.active_units(slot).size()==before+1,"Key %d immediately hires %s"%[index+1,h.NAMES[slot]])
  tap(KEY_1+index,true);await settle()
  check(h.active_units(slot).size()==before+1,"Held key cannot repeatedly charge or spawn")
 check(game.model.gold==gold-470 and game.model.food_used()==food+10,"Five keys deduct prices and food once each")
 check(game.player.master_chief_combat.weapon_slot==1,"Mercenary keys never switch the player's weapons")
 var units=h.active_units()
 check(units.size()==15 and units.all(func(u):return army.valid(u.handle) and u.hp==h.HEALTH[u.slot]),"All fifteen recruits own living native units with their original HP")
 check(units.all(func(u):return Vector2(u.guard_post.x-shrine.x,u.guard_post.z-shrine.z).length()<43),"All recruits spawn near the castle despite the distant player and pointer")
 var nearest_post_gap=INF
 for i in units.size():
  for j in i:
   var offset:Vector3=units[i].guard_post-units[j].guard_post
   nearest_post_gap=minf(nearest_post_gap,Vector2(offset.x,offset.z).length())
 check(nearest_post_gap>=7.9,"Automatic rest posts visibly spread out the recruits (closest pair %.2f m apart)"%nearest_post_gap)
 await capture("all-five-recruited")
 gold=game.model.gold;var count=units.size()
 game.model.gold=0;tap(KEY_5);await settle()
 check(h.active_units().size()==count and game.model.gold==0,"No funds creates no Knight and charges nothing")
 game.model.gold=gold;game.model.starting_food=0
 check(not h.request(3) and game.model.gold==gold,"Full food capacity blocks automatic hiring transactionally")
 game.model.starting_food=100
 game.show_pause();check(not h.request(3),"Pause blocks hiring");game.resume()
 game.show_settings(true);check(not h.request(3),"Settings block hiring");game.resume()
 check(not h.request(-1) and not h.request(5),"Invalid slots cannot recruit")
 check(not h.purchase(1,Vector3.INF) and not h.purchase(1,shrine),"The shared purchase path retains nonfinite and building validation")
 var occupancy=game.model.occupancy.duplicate();var home=game.model.cell_of(shrine)
 for x in range(-6,7):
  for z in range(-6,7):game.model.occupancy[home+Vector2i(x,z)]=game.model.shrine().id
 check(not h.request(3) and game.model.gold==gold and h.active_units().size()==count and not h.placement_active(),"A blocked base charges nothing and leaves no placement mode")
 game.model.occupancy=occupancy
 var retired=units[0];var old_handle=retired.handle;var pool_size=h.pool.size()
 army.apply_hit(old_handle,{"amount":1000000.0,"direction":Vector3.ZERO})
 check(h.request(retired.slot) and retired.handle!=old_handle and not army.valid(old_handle) and h.pool.size()==pool_size,"Recruiting after a death reuses the prepared facade without stale native identity or pool growth")
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.set_process(false);game.player.set_physics_process(false)
 check(not h.request(3) and h.active_units().size()==count,"Wave transition preserves recruits and closes preparation hiring")
 army.import_arrivals()
 for id in game.model.enemies.keys():army.despawn(army.handles[id])
 var posts=units.map(func(u):return u.guard_post)
 for i in 60:army.integration_tick(1.0/60)
 check(units.all(func(u):return u.position.distance_to(u.guard_post)<.25),"With no enemies all defenders wait at the castle")
 await capture("castle-defenders")
 # Isolate native targeting/combat from real-map obstacles, preserving the prepared kits.
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game))
 runtime.set_navigation(1,{"width":0})
 for slot in 5:
  runtime.clear();runtime.set_navigation(slot+2,{"width":0})
  var guard=runtime.spawn(-1,1,h.KITS[slot],Vector3.ZERO,h.HEALTH[slot],.4);runtime.native.set_guard(guard,Vector3.ZERO,h.GUARD_RADIUS)
  var enemy=runtime.spawn(1,0,0,Vector3(h.GUARD_RADIUS+10,0,0),1000000000,1.3)
  runtime.apply_hit(enemy,{"element":"ice","status_seconds":100})
  for i in 90:runtime.step(1.0/60,{})
  check(runtime.unit_state(guard).target_id!=1 and runtime.unit_state(guard).position.length()<.25,h.NAMES[slot]+" waits for enemies to enter its defensive area")
  runtime.set_pose(enemy,Vector3(6,0,0),0)
  for i in 900:
   runtime.step(1.0/60,{})
   if runtime.unit_state(enemy).get("hp",0)<1000000000:break
  check(runtime.unit_state(enemy).get("hp",0)<1000000000,h.NAMES[slot]+" automatically attacks an approaching enemy")
  runtime.despawn(enemy)
  enemy=runtime.spawn(2,0,4,Vector3(h.GUARD_RADIUS+30,0,0),1000000000,1.3)
  runtime.apply_hit(enemy,{"element":"ice","status_seconds":100})
  for i in 1200:runtime.step(1.0/60,{})
  check(runtime.unit_state(guard).target_id!=2 and runtime.unit_state(guard).position.distance_to(Vector3.ZERO)<1,h.NAMES[slot]+" releases distant enemies and returns home")
  runtime.despawn(enemy)
  for i in 1200:runtime.step(1.0/60,{})
  check(runtime.unit_state(guard).position.distance_to(Vector3.ZERO)<1,h.NAMES[slot]+" returns home when no enemies remain")
 runtime.free()
 game.model.phase="preparing";h.rest()
 check(units.map(func(u):return u.guard_post)==posts and units.all(func(u):return u.position==u.guard_post),"Surviving defenders return to their scattered posts next preparation")
 await finish()
func finish():
 if is_instance_valid(game):game.sound_library.cancel();game.music.stop();game.queue_free()
 paused=false;await settle()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GUARD_HIRING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
