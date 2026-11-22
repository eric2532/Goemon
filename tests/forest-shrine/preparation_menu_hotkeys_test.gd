extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Build/hire menus are retired from the map; M retains the combat minimap.
func key(code:int):
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;game._input(event)
 event.pressed=false;game._input(event)
func run():
 create_timer(120).timeout.connect(func():printerr("PREPARATION_HOTKEY_TIMEOUT");quit(1))
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.player.select_character(game.player.RogueRoster.KAZI_ID)
 game.model.phase="preparing";game.set_phase_view();game.forest_ui.sync()
 var ui=game.forest_ui;var gold=game.model.gold;var buildings=game.model.buildings.size()
 var helpers=game.explorer_helpers.active_units().size()
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=dimensions;await frames(3)
  check(ui.find_child("PreparationBuilds",true,false)==null and ui.find_child("PreparationHireGuards",true,false)==null,"Build and Mercenaries are absent at "+str(dimensions))
  for code in [KEY_B,KEY_M]:
   key(code)
   check(ui.preparation_mode.is_empty() and not ui.build_menu_expanded and not ui.guard_shop_open(),"Retired B/M shortcuts cannot reopen construction or hiring")
  check(ui.start_wave_button.is_visible_in_tree() and root.get_visible_rect().encloses(ui.start_wave_button.get_global_rect()),"Direct preparation fixtures retain an accessible Start button")
 check(game.build_kind.is_empty() and game.model.gold==gold and game.model.buildings.size()==buildings and game.explorer_helpers.active_units().size()==helpers,"Retired menu keys cannot spend money, build or recruit")
 game.start_wave();game.forest_ui.sync()
 key(KEY_B);key(KEY_M)
 check(not ui.guard_shop_open() and not ui.build_menu_expanded and game.model.phase=="wave","Combat B/M input cannot open retired menus")
 for voice in game.voices:voice.stop()
 game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PREPARATION_MENU_HOTKEYS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
