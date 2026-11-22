extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const OUT="res://build/Other Files/Asset Toolkit/Pet HUD/"
func key(code:int):
 var e=InputEventKey.new();e.physical_keycode=code;e.pressed=true;game._input(e)
func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Captured "+name_)
func verify_stance(index:int):
 var ui=game.forest_ui
 check(ui.hound_dock.is_visible_in_tree() and ui.hound_stance==index,"HUD shows the selected pet command")
 for i in 3:
  check(ui.hound_stance_icons[i].texture==ui.PET_STANCES[i][1 if i==index else 0],"Only the current stance uses its original highlighted artwork")
  check(ui.hound_stance_labels[i].text.begins_with("› ")==(i==index),"Current stance also has a text marker, independent of color")
  check(ui.hound_dock.get_global_rect().encloses(ui.hound_stance_labels[i].get_global_rect()),"Stance label fits its pet panel")
  check(ui.hound_stance_labels[i].get_combined_minimum_size().x<=70,"Stance shortcut remains readable without clipping")
func run():
 create_timer(180).timeout.connect(func():quit(1));DirAccess.make_dir_recursive_absolute(OUT)
 var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/crossgate/pet_stances/provenance.json"))
 for sprite in provenance.sprites:
  var image=load("res://assets/ui/crossgate/pet_stances/"+sprite.file).get_image();image.convert(Image.FORMAT_RGBA8)
  var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
  check(hash.finish().hex_encode()==sprite.rgba_sha256,"Imported command pixels match the original Cross Gate recovery: "+sprite.file)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.player.select_character(game.forest_ui.Roster.KAZI_ID)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var army=game.army_runtime;var ui=game.forest_ui
 for food in [3,3,4,5,5,5,6,6,7,7,7,8,8]:game.exploration_loot.eat(food)
 ui.sync();check(not ui.hound_dock.visible,"No pet status panel is shown before summoning")
 game.player.position=Vector3(-120,0,125);game.player.position.y=game.model.surface_height(-120,125)
 game.settings.forest_pet_loadout=Pets.sanitized([Pets.key(0),Pets.key(21),Pets.key(41),Pets.key(61),Pets.key(81)])
 key(KEY_P)
 for i in 90:army.integration_tick(1.0/60);army.flush_presentation()
 ui.sync();verify_stance(2)
 var handles=game.settings.forest_pet_loadout.map(func(k):return army.handles[army.HOUND_ID-Pets.skin(k)])
 var hp=handles.map(func(h):return army.unit_state(h).hp)
 var nodes=ui.hound_stance_icons.map(func(icon):return icon.get_instance_id())
 var camera=game.camera_rig.camera;camera.global_position=game.player.position+Vector3(-4,20,32);camera.look_at(game.player.position+Vector3.UP)
 game.crowd.present_army(army.render_snapshot(),[])
 await capture("following-default")
 for row in [[MOUSE_BUTTON_RIGHT,0,"attacking"],[KEY_F,1,"defending-in-place"],[KEY_Z,2,"back"]]:
  if row[0]==MOUSE_BUTTON_RIGHT:tap("heavy_attack")
  else:key(row[0])
  await frames(2);verify_stance(row[1]);await capture(row[2])
 check(handles.map(func(h):return army.unit_state(h).hp)==hp,"Changing stance indication preserves pet health")
 army.apply_hit(handles[1],{"amount":hp[1]*.5});army.integration_tick(1.0/60);ui.sync()
 check(is_equal_approx(ui.hound_health_bars[1].value,.5),"Damage halves only the affected pet's health bar")
 for i in handles.size():
  check(is_equal_approx(ui.hound_health_bars[i].value,army.hound_health_fraction(Pets.skin(game.settings.forest_pet_loadout[i]))),"Each compact pet bar follows its own native health")
  check(ui.hound_health_bars[i].get_global_rect().position.y>=ui.hound_heads[i].get_global_rect().end.y,"Pet health sits below its matching portrait")
 for viewport in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=viewport;await frames()
  for factor in [.8,1.0,1.3]:
   game.settings.forest_hud_scale=factor;ui.sync();await frames()
   check(root.get_visible_rect().encloses(ui.hound_dock.get_global_rect()),"Pet indicators fit viewport at HUD scale "+str(factor))
   check(ui.hound_dock.get_global_rect().position.y>=ui.loadout_slots.get_global_rect().end.y,"Stance row stays below the integrated skills")
   check(ui.hound_dock.get_global_rect().position.y>=ui.hero_portrait.get_global_rect().end.y and ui.hound_dock.position.y==128,"Compact pet health follows directly below the player HUD")
   check(is_equal_approx(ui.food_effects.get_global_rect().get_center().x,root.get_visible_rect().get_center().x),"Food icons stay centered horizontally")
   check(is_equal_approx(ui.food_effects.get_global_rect().end.y,root.get_visible_rect().end.y-16),"Food icons stay at the bottom edge")
   check(ui.food_effects.get_global_rect().position.y>root.size.y*.5,"Food stays in the bottom half")
   check(not ui.hound_dock.get_global_rect().intersects(ui.food_effects.get_global_rect()),"Food and pet health do not overlap")
   check(root.get_visible_rect().encloses(ui.food_effects.get_global_rect()),"Food icons fit the viewport at HUD scale "+str(factor))
 game.settings.forest_hud_scale=1.0;ui.sync();await capture("small-window")
 root.size=Vector2i(1280,800);game.player.select_character(ui.Roster.SHIN_ID);ui.sync();await frames()
 check(ui.hound_dock.get_parent()==ui.hero_dock and ui.food_effects.get_parent()==ui,"Switching Cross Gate characters keeps pet health below the hero and food independent")
 key(KEY_F);await frames(2);verify_stance(1)
 await capture("crossgate-defending")
 game.player.select_character(ui.Roster.KAZI_ID);ui.sync();await frames()
 game.paused=true;tap("heavy_attack");game.paused=false;ui.sync();verify_stance(1)
 var before_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var before_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT));var times=[]
 for i in 90:
  if i%3==1:tap("heavy_attack")
  else:key(KEY_F if i%3==0 else KEY_Z)
  var started=Time.get_ticks_usec();ui.sync_hound_health();times.append((Time.get_ticks_usec()-started)/1000.0)
 check(ui.hound_stance_icons.map(func(icon):return icon.get_instance_id())==nodes,"Ninety switches reuse the same three indicator controls")
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==before_nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))==before_resources,"Repeated updates allocate no retained nodes or resources")
 times.sort();print("PET_STANCE_HUD_SYNC p95_ms=",times[85]," max_ms=",times[-1])
 for i in 24:army.integration_tick(1.0/60)
 for h in handles:army.apply_hit(h,{"amount":1000000.0})
 army.integration_tick(1.0/60);ui.sync();check(not ui.hound_dock.visible,"The stance panel hides when the last pet dies")
 check(ui.hound_health_bars.all(func(bar):return not bar.visible),"Fallen pets leave no stale health bars")
 army.clear();key(KEY_P)
 for i in 90:army.integration_tick(1.0/60);army.flush_presentation()
 ui.sync();verify_stance(2)
 check(ui.hound_stance_icons.map(func(icon):return icon.get_instance_id())==nodes,"Reset and summon reuse the HUD and restore Follow")
 game.queue_free();current_scene=null;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_STANCE_HUD_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
