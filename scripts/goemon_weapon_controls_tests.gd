extends "res://scripts/recovered_goemon_gameplay_tests.gd"
func raw_key(code:int,down:bool=true,echo_:bool=false):
 var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;event.echo=echo_
 root.push_input(event,true);await frames(1)
func mouse_event(down:bool,right:bool=false):
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT;event.pressed=down
 root.push_input(event,true);await frames(1)
func run():
 await setup_fixture()
 var p=game.player;fresh();p.select_weapon(1)
 var serial=game.explorer_helpers.summon_serial
 for pair in [[4,2],[5,3]]:
  var number=pair[0]
  await raw_key(KEY_1+number-1);await raw_key(KEY_1+number-1,false)
  check(p.weapon_slot==pair[1] and p.attack_left>0,"Raw Goemon key%d immediately uses its original weapon"%number)
  check(not p.quick_attacks.coins_enabled,"A direct weapon key never enables background coins")
  await step(160)
 for key in [KEY_4,KEY_5]:await raw_key(key);await raw_key(key,false)
 check(game.explorer_helpers.summon_serial==serial and game.explorer_helpers.active_units().is_empty(),"Goemon's bare1–5 never summon helpers")
 check(not game.explorer_helpers.request(0),"Goemon cannot summon through a clicked helper slot")
 for golden in [false,true]:
  for right in [false,true]:
   fresh(golden);p.select_weapon(2);await mouse_event(true,right)
   check(p.attack_left>0 and not p.weapon_controls.charging,"Ryo begins immediately on mouse press, golden=%s RMB=%s"%[golden,right])
   check(p.attack_charged==golden,"Only golden ryo selects the flaming projectile")
   var shot=p.attack_ticket
   await mouse_event(false,right)
   check(p.attack_ticket==shot,"Mouse release never duplicates the ryo throw")
   await step(35)
 fresh(true);p.select_weapon(1);await raw_key(KEY_4)
 check(p.weapon_slot==2 and p.attack_charged and p.quick_attacks.active,"Golden key4 immediately throws flaming ryo from the pipe")
 var shot=p.attack_ticket
 await raw_key(KEY_4,true,true);await raw_key(KEY_4,false)
 check(p.attack_ticket==shot,"Holding/releasing4 cannot queue another flaming ryo")
 await step(45)
 check(p.weapon_slot==1 and not p.quick_attacks.active,"Golden ryo restores the previous weapon")
 fresh(true);p.select_weapon(2);await mouse_event(true);p.end_surge();await mouse_event(false);await step(35)
 fresh();p.select_weapon(2);await mouse_event(true)
 check(not p.attack_charged,"Ending the transformation restores ordinary ryo")
 await mouse_event(false);await step(35)
 fresh(true);p.select_weapon(2);await mouse_event(true);p.select_character(2)
 check(not p.weapon_controls.charging and not p.quick_attacks.active,"Character switching clears Goemon's temporary attack state")
 await mouse_event(false)
 game.explorer_helpers.clear();serial=game.explorer_helpers.summon_serial
 await raw_key(KEY_4);await raw_key(KEY_4,false)
 check(game.explorer_helpers.summon_serial==serial,"Other fighters cannot summon through bare numbers")
 game.forest_ui.sync()
 check(not game.forest_ui.helper_portraits[1].visible,"Other fighters leave unused slots empty")
 p.select_character(1);game.forest_ui.sync()
 check(game.forest_ui.loadout_buttons[3].tooltip_text.contains("Coins") and not game.forest_ui.loadout_buttons[3].tooltip_text.contains("allies"),"Goemon HUD describes original weapons and immediate golden ryo")
 game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOEMON_WEAPON_CONTROLS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
