extends SceneTree
## Real preparation input must summon allies, never build or recruit twice.
var game
var checks=0
var failures=0
var cfg="user://preparation-allies-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(120).timeout.connect(func():printerr("FAIL: preparation allies input timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func frames(n=3):
 for i in n:await process_frame
func key(code:int,down:bool=true,echo_:bool=false,modifier:String=""):
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=down;event.echo=echo_
 event.shift_pressed=modifier in ["shift","shift_ctrl"];event.ctrl_pressed=modifier in ["ctrl","shift_ctrl"];event.alt_pressed=modifier=="alt";event.meta_pressed=modifier=="meta"
 if code>=KEY_1 and code<=KEY_5:event.unicode=code
 root.push_input(event,true)
func tap(code:int,modifier:String=""):
 key(code,true,false,modifier);key(code,false,false,modifier)
func freeze_helpers():
 for unit in game.explorer_helpers.pool:unit.set_physics_process(false)
func click_button(button:Button):
 var position_=button.get_global_rect().get_center()
 var motion=InputEventMouseMotion.new();motion.position=position_;root.push_input(motion,true)
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.position=position_;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
 await frames(1);freeze_helpers()
func blocked_inputs(label_:String):
 var h=game.explorer_helpers;var allies=h.active_units().duplicate();var workers=game.model.workers.size();var gold=game.model.gold;var building=game.build_kind
 var health=allies.map(func(unit):return unit.hp)
 for slot in 5:
  tap(KEY_1+slot);tap(KEY_1+slot,"shift");game.forest_ui.loadout_buttons[slot].pressed.emit()
 check(h.active_units()==allies and allies.map(func(unit):return unit.hp)==health,label_+" preserves the army and blocks number keys/hotbar signals")
 check(game.model.workers.size()==workers and game.model.gold==gold and game.build_kind==building,label_+" blocks construction shortcuts")
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 for unit in game.gate_defenders.units.values():unit.set_physics_process(false)
 var h=game.explorer_helpers;var ui=game.forest_ui
 check(game.model.phase=="preparing" and game.paused and paused,"Preparation intentionally pauses simulation")
 for id in range(1,13):
  game.player.select_character(id);h.clear();game.build_kind="";ui.sync()
  var workers=game.model.workers.size();var gold=game.model.gold
  for slot in 5:
   tap(KEY_1+slot);freeze_helpers()
   var group=h.active_units(slot)
   check(group.size()==[1,3,5,1,2][slot],"Preparation character %d key %d adds its assigned group"%[id,slot+1])
   check(group.all(func(unit):return unit.hp==[200,100,100,500,200][slot] and unit.max_hp==[200,100,100,500,200][slot]),"Preparation character %d key %d has mortal ally HP"%[id,slot+1])
   key(KEY_1+slot,true,true);key(KEY_1+slot,false)
   check(h.active_units(slot)==group,"Preparation character %d held/released key %d cannot repeat"%[id,slot+1])
  check(game.build_kind.is_empty() and game.model.workers.size()==workers and game.model.gold==gold,"Preparation character %d bare digits cannot build, recruit or spend gold"%id)
  var first=h.active_units(1).duplicate();tap(KEY_2);freeze_helpers()
  check(h.active_units(1).size()==6 and first.all(func(unit):return h.active_units(1).has(unit)),"Preparation character %d fresh presses add without replacing its army"%id)
 # Shift retains the legacy preparation actions and cannot add an ally group.
 h.clear();game.build_kind=""
 for slot in 4:
  tap(KEY_1+slot,"shift")
  check(game.build_kind==["mine","tower","wall","gate"][slot] and h.active_units().is_empty(),"Shift+%d selects its building without summoning"%(slot+1))
 game.build_kind="";var workers=game.model.workers.size();var gold=game.model.gold
 tap(KEY_5,"shift")
 check(game.model.workers.size()==workers+1 and game.model.gold==gold-50 and h.active_units().is_empty(),"Shift+5 recruits exactly one worker for 50 gold")
 key(KEY_5,true,true,"shift");key(KEY_5,false,false,"shift")
 check(game.model.workers.size()==workers+1 and game.model.gold==gold-50,"A held Shift+5 cannot repeat recruitment")
 workers=game.model.workers.size();gold=game.model.gold
 for modifier in ["ctrl","alt","meta","shift_ctrl"]:
  for slot in 5:tap(KEY_1+slot,modifier)
  check(h.active_units().is_empty() and game.build_kind.is_empty() and game.model.workers.size()==workers and game.model.gold==gold,"%s+digits cannot summon, build or recruit"%modifier)
 # Pointer clicks use the real button connection in the building view.
 ui.sync();await frames()
 for slot in 5:
  await click_button(ui.loadout_buttons[slot])
  check(h.active_units(slot).size()==[1,3,5,1,2][slot],"Preparation hotbar click %d adds its assigned group"%(slot+1))
 check(game.build_kind.is_empty() and game.model.workers.size()==workers and game.model.gold==gold,"Hotbar clicks do not reach battlefield building input")
 if h.active_units(4).size()==2:h.active_units(4)[0].hp=20
 # Real menus preserve the prepared army before it enters its first wave.
 game.show_pause();blocked_inputs("Pause overlay");game.resume();await frames()
 game.show_view_settings(true);blocked_inputs("View settings with visible HUD");game.resume();await frames()
 game.show_settings(true);blocked_inputs("Settings menu");game.resume();await frames()
 game.show_rogue_roster();blocked_inputs("Character roster");game.close_rogue_roster();await frames()
 game.show_gate_defenders();blocked_inputs("Gate Defender panel");game.forest_ui.get_node("GateDefenderPanel").close();await frames()
 var survivors=h.active_units().duplicate()
 if survivors.size()==12:
  var wounded=h.active_units(4)[0]
  var positions=survivors.map(func(unit):return unit.global_position)
  for i in 60:
   for unit in survivors:unit._physics_process(1.0/60)
  check(h.active_units()==survivors and survivors.map(func(unit):return unit.global_position)==positions and survivors.all(func(unit):return not unit.has_offensive_action()),"Prepared army waits without moving or attacking")
  ui.build_bar.get_node("StartWave").pressed.emit();game.model.waves.pending=999;game.model.waves.spawn_clock=100000;freeze_helpers()
  check(game.model.phase=="wave" and h.active_units()==survivors and wounded.hp==20,"Starting a real wave preserves all prepared allies and 20 HP")
  tap(KEY_5);freeze_helpers()
  check(h.active_units(4).size()==4 and wounded.hp==20,"Combat digits add to the prepared army without healing survivors")
  game.model.phase="preparing";game.set_phase_view();freeze_helpers()
  check(h.active_units().size()==14 and wounded.hp==20,"Returning to preparation preserves army count and remaining health")
 else:check(false,"Pointer-summoned army exists for the wave transfer checks")
 # Map editing retains its normal digit typing and starts with a fresh model.
 game.open_map_editor();await frames();blocked_inputs("Map editor")
 var editor=game.map_editor;editor.name_field.text="";editor.name_field.grab_focus()
 for slot in 5:tap(KEY_1+slot)
 check(editor.name_field.text=="12345" and h.active_units().is_empty(),"Map name typing retains all five digits without summoning")
 editor.name_field.release_focus();editor.close_discard();await frames()
 game.show_title();blocked_inputs("Title screen")
 await finish()
func finish():
 game.sound_library.cancel();game.music.stop()
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120);game.queue_free();paused=false;await frames();await create_timer(.2).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PREPARATION_HELPERS_INPUT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
