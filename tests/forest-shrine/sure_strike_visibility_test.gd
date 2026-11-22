extends "res://tests/forest-shrine/crossgate_bog_test.gd"

const VIS_OUT="res://build/Other Files/Sure Strike Visibility/"

func run():
 create_timer(100).timeout.connect(func():printerr("SURE_STRIKE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(VIS_OUT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 var p=game.player
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 var home=Vector3(-120,0,125)
 home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 var camera=game.camera_rig.camera
 var fx=game.crowd.army.presentation
 for character in [Roster.SHIN_ID,Roster.BOG_ID]:
  p.select_character(character);fresh();settle(home)
  var height:float=p.model.standing_height()
  # The burst extends into the viewport even though its origin is just outside it.
  var viewport_size=camera.get_viewport().get_visible_rect().size
  var at=camera.project_position(Vector2(viewport_size.x+12,viewport_size.y*.5),12)
  check(game.model.visible_at(at) and not camera.is_position_in_frustum(at),"Edge fixture is revealed but its effect origin is offscreen")
  for polearm in [false,true]:
   fx.clear()
   fx.sure_strike_burst(at,height,polearm)
   var kind="shin_double_edge" if polearm else "shin_sure_strike"
   check(fx.effects.size()==1 and fx.effects[0].kind==kind,"Large burst survives a camera-edge origin: %d / %s"%[character,kind])
   fx.tick(.2)
   if DisplayServer.get_name()!="headless":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(VIS_OUT+"edge-%d-%s.png"%[character,kind])
   camera.look_at(at)
   fx.draw_effects()
   check(fx.batches[kind].multimesh.visible_instance_count==1,"Panning toward a live burst keeps its animation")
   settle(home)
   fx.tick(1)
   check(fx.effects.is_empty(),"Burst expires through its existing pool")
  fx.clear()
  var hidden=Vector3(900,0,900)
  fx.sure_strike_burst(hidden,height,false)
  check(fx.effects.is_empty(),"Unrevealed terrain still suppresses the burst")
  var on_screen=home+Vector3.UP*height
  for i in fx.effect_capacity:fx.add_effect("spark",on_screen,1,.1)
  fx.sure_strike_burst(on_screen,height,false)
  check(fx.effects.size()==fx.effect_capacity,"Crowd effect capacity remains bounded")
  print("SURE_STRIKE_CAPACITY_DIAGNOSTIC character=%d burst=%s"%[character,fx.effects.any(func(row):return row.kind=="shin_sure_strike")])
  fx.clear()
  game.training_dummy.position=home+Vector3.FORWARD*2.3
  game.training_dummy.home=game.training_dummy.position
  var resources=0
  var nodes=fx.get_child_count()
  for repetition in 3:
   p.attack_chain.reset();p.active_ability.clear_cooldowns();settle(home)
   contacts.clear();press(KEY_1)
   check(p.model.combo_glow.visible,"Real numbered input starts the charge")
   for i in 150:
    step_player(1)
    if not contacts.is_empty():break
   check(contacts.size()==1 and fx.effects.any(func(row):return row.kind=="shin_sure_strike"),"Repeated real cast damages once and emits its red burst")
   step_player(6)
   if repetition==0 and DisplayServer.get_name()!="headless":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(VIS_OUT+"cast-%d.png"%character)
   step_player(120)
   check(not p.active_ability.is_attacking() and not fx.effects.any(func(row):return row.kind=="shin_sure_strike"),"Real cast completes and retires its burst")
   check(fx.get_child_count()==nodes,"Repeated casts reuse existing presentation nodes")
   var current_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
   if repetition==0:resources=current_resources
   else:check(current_resources<=resources,"Repeated casts retain no extra resources after warmup")
  p.attack_chain.reset();p.active_ability.clear_cooldowns();settle(home)
  contacts.clear();press(KEY_1);p.invuln=0;p.take_hit(1,Vector3.BACK)
  step_player(150)
  check(contacts.is_empty() and not p.model.combo_glow.visible and not fx.effects.any(func(row):return row.kind=="shin_sure_strike"),"A hit during charging still cancels damage and burst")
 game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SURE_STRIKE_VISIBILITY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
