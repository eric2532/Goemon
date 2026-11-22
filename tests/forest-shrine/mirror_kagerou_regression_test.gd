extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const MIRROR="blademaster/mirror-image"
const KAGEROU="kazi/kagerou"
const OUT="res://build/Other Files/Mirror Kagerou Fix/"

func run():
 create_timer(150).timeout.connect(func():printerr("MIRROR_KAGEROU_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 doc.read_file("res://tests/forest-shrine/reference/maps/forest_freyja_east_gate.json")
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.camera_rig.set_physics_process(false)
 game.settings.disable_character_cooldowns=false
 var p=game.player;var loadout=p.spell_loadout;var army=game.army_runtime
 var home=game.model.world_point(Vector2(3,246),.05)
 game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*100
 game.camera_rig.camera.global_position=home+Vector3(0,14,25)
 game.camera_rig.camera.look_at(home+Vector3.UP)
 for character in Catalog.Roster.selection_ids():
  p.select_character(character);fresh();p.position=home
  check(loadout.equip(character,"special_5",MIRROR),"Mirror Image equips for %d"%character)
  var mirrors=loadout.instances["%d:%s"%[character,MIRROR]].controller.mirrors
  var region:Rect2i=game.model.navigation_region
  game.model.navigation_region=Rect2i(game.model.cell_of(home/game.model.falan_scale)-Vector2i(2,2),Vector2i(5,5))
  check(mirrors.point_clear(home),"Placement checks scaled map bounds for %d"%character)
  game.model.navigation_region=region
  loadout.number_input(5,true);loadout.number_input(5,false)
  for i in 100:p._physics_process(1.0/60)
  check(mirrors.handles.size()==5,"Numbered cast summons five images on scaled Freyja ground for %d"%character)
  check(mirrors.handles.size()==5 and mirrors.bodies.all(func(body):return absf(body.position.y-game.model.world_height(body.position.x,body.position.z))<.5),"All copies stand on the actual world surface for %d"%character)
  var handles=mirrors.handles.duplicate()
  loadout.number_input(5,true);loadout.number_input(5,false)
  check(mirrors.handles==handles and loadout.cooldown_for("special_5")>19,"Immediate recast preserves the group and cooldown")
  if DisplayServer.get_name()!="headless" and character==36:
   game.crowd.present_army(army.render_snapshot(),army.presentation_events)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+"mirrors.png")
  await frames(2)
  var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  var bodies=mirrors.bodies.duplicate();var costs=[]
  for cycle in 8:
   var started=Time.get_ticks_usec()
   check(mirrors.cast(),"Repeated five-copy cast succeeds")
   for i in 12:army.step(1.0/60,{"targets":army.external_targets()})
   costs.append((Time.get_ticks_usec()-started)/1000.0)
   army.presentation_events.clear()
  check(mirrors.bodies==bodies and get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated native summons reuse bodies without retained resources")
  print("MIRROR_RECAST character=",character," eight_cast_max_ms=",costs.max())
  handles=mirrors.handles.duplicate();mirrors.tick(31)
  check(mirrors.handles.is_empty() and handles.all(func(handle):return not army.valid(handle)),"All five native images retire at expiry")
  check(loadout.equip(character,"special_5",KAGEROU),"Kagerou is selectable for %d"%character)
  if loadout.spell_for(character,"special_5")!=KAGEROU:continue
  loadout.number_input(5,true);loadout.number_input(5,false)
  game.forest_ui.sync()
  check(p.active_ability.kagerou_enabled and game.forest_ui.loadout_cooldowns[4].text=="ON","Selected Kagerou toggles on with matching HUD")
  var hp=p.hp;p.invuln=0;p.take_hit(20,Vector3.RIGHT)
  p.model.tick_kagerou_dodge(1.0/60)
  check(p.hp==hp and p.model.kagerou_shadows.any(func(shadow):return shadow.visible),"Borrowed Kagerou avoids damage with the wearer's afterimage")
  check(game.last_sound_voice.stream==SoundLibrary.KAZ_KAGEROU_DODGE,"Borrowed dodge uses the prepared original sound")
  var shadows=p.model.kagerou_shadows.duplicate()
  nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  for i in 30:
   p.model.tick_kagerou_dodge(1);p.take_hit(20,Vector3.RIGHT);p.model.tick_kagerou_dodge(.1)
  check(p.model.kagerou_shadows==shadows and get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Thirty dodges reuse the same six sprites")
  if DisplayServer.get_name()!="headless" and character==43:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+"borrowed-kagerou.png")
  loadout.number_input(5,true);loadout.number_input(5,false)
  check(not p.active_ability.kagerou_enabled,"Selected Kagerou toggles off")
  loadout.number_input(5,true);loadout.number_input(5,false)
  loadout.equip(character,"special_5",MIRROR)
  check(not p.active_ability.kagerou_enabled,"Unequipping Kagerou clears protection")
 game.show_rogue_roster()
 var picker=load("res://scripts/spells/spell_picker.gd").new();picker.game=game;game.menu.add_child(picker);await frames()
 var option:OptionButton=picker.choices.special_5
 var selected=-1
 for i in option.item_count:
  if option.get_item_metadata(i)==KAGEROU:selected=i
 check(selected>=0,"Loadout contains the named Kagerou choice")
 if selected>=0:
  option.item_selected.emit(selected)
  game.save_settings();game.load_settings()
  check(loadout.spell_for(p.character_id,"special_5")==KAGEROU,"Selecting Kagerou through Loadout survives a settings reload")
  if DisplayServer.get_name()!="headless":
   option.get_popup().popup();await frames(3);await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+"loadout.png")
 var path=game.settings_path;game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("MIRROR_KAGEROU_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
