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
 for number in [2,3,1]:
  await raw_key(KEY_1+number-1);await raw_key(KEY_1+number-1,false)
  check(p.weapon_slot==number and p.attack_left>0,"Raw Goemon key %d immediately uses its original weapon"%number)
  check(not p.quick_attacks.coins_enabled,"A direct weapon key never starts automatic coins")
  await step(160)
 for key in [KEY_4,KEY_5]:await raw_key(key);await raw_key(key,false)
 check(game.explorer_helpers.summon_serial==serial and game.explorer_helpers.active_units().is_empty(),"Goemon's bare 1–5 never summon helpers")
 check(not game.explorer_helpers.request(0),"Goemon cannot summon through a clicked or programmatic helper slot")
 var controls=p.get("weapon_controls")
 check(controls!=null,"Goemon owns a separate original-weapons input controller")
 if controls==null:
  game.queue_free();await frames();quit(1);return
 fresh();p.select_weapon(2)
 await mouse_event(true);check(p.attack_left>0 and not controls.charging,"Ordinary Goemon coin fires from its source windup without holding")
 await mouse_event(false);await step(35)
 fresh(true);p.select_weapon(2)
 await mouse_event(true)
 check(controls.charging and p.attack_left<=0,"Super Goemon holds the coin without releasing a projectile on press")
 check(is_instance_valid(controls.charge_visual) and not controls.charge_visual.visible,"Native charge particles are owned by the held coin and hidden before its cue")
 await step(29)
 check(not controls.cue_played,"Original charge cue waits until native tick 15")
 await step(2)
 check(controls.cue_played and controls.charging,"Original charge cue fires once at 15 ticks / 0.5 seconds")
 check(controls.charge_visual.visible,"Native charge particles become visible at the original cue")
 await mouse_event(false)
 check(not controls.charging and p.attack_left>0 and not p.attack_charged,"Release before native tick 60 performs a normal coin throw")
 check(controls.charge_visual==null,"Release removes the original charging particles")
 await step(35);fresh(true);p.select_weapon(2)
 await mouse_event(true);await step(121)
 check(controls.charging and p.attack_left<=0,"Full native charge remains held until button release")
 check(controls.sustain_index==1 and game.voices.any(func(voice):return voice.get_meta("kind","")=="goemon_coin_charge_a"),"Held charge emits its first original sustain cue after 1.5 seconds")
 await step(30)
 check(controls.sustain_index==2 and game.voices.any(func(voice):return voice.get_meta("kind","")=="goemon_coin_charge_b"),"Held charge alternates to the second original sustain cue after 2.5 seconds")
 await mouse_event(false)
 check(not controls.charging and p.attack_charged and p.original_coin_action in [0x7F,0x80,0x81],"Full release chooses original charged standing/moving/aerial coin action")
 var attack_before=p.attack_ticket
 await mouse_event(false)
 check(p.attack_ticket==attack_before,"A duplicate release cannot cast a second charged coin")
 await step(10)
 var charged_coins=get_nodes_in_group("projectiles").filter(func(coin):return coin.get_meta("original_goemon_charged_coin",false))
 check(charged_coins.size()==1,"Native charged release creates one coin costing three, without an invented projectile fan (count=%d, time=%f)"%[charged_coins.size(),p.attack_duration-p.attack_left])
 if charged_coins.size()==1:
  check(is_equal_approx(charged_coins[0].visual_size,HeroModel.WeaponProportions.SCALE),"Native charged coin keeps the ordinary source sprite size")
  check(not charged_coins[0].piercing,"Native charged coin stops on its first collision")
  var coin=charged_coins[0];coin.set_physics_process(false)
  var target=AttackChain.aim_point(game.training_dummy,game.training_dummy.global_position+Vector3.UP)
  coin.global_position=target-Vector3.FORWARD;coin.velocity=Vector3.FORWARD*20
  coin._physics_process(.1)
  check(coin.hit_enemies.has(game.training_dummy.get_instance_id()) and coin.is_queued_for_deletion(),"A real charged coin contact damages the victim and ends flight")
  check(coin.get_meta("original_goemon_charged_burst_played",false) and game.get_children().any(func(child):return child.name.begins_with("OriginalChargedCoinImpact")),"Confirmed charged contact emits the native burst sound and original impact sprite")
 await step(35);fresh(true);p.select_weapon(2)
 await mouse_event(true);await step(15);p.dodge_cooldown=0
 await raw_key(KEY_C);await raw_key(KEY_C,false)
 check(not controls.charging and p.attack_left<=0,"A real evade cancels the held coin without firing")
 await mouse_event(false);await step(30);fresh(true);p.select_weapon(2)
 await mouse_event(true);await step(15);await raw_key(KEY_1);await raw_key(KEY_1,false)
 check(not controls.charging and p.weapon_slot==1 and p.attack_left>0 and p.combo==1,"The pipe action cancels the held coin and starts its combo")
 await mouse_event(false)
 fresh(true);p.select_weapon(2);await mouse_event(true);game.paused=true
 await mouse_event(false)
 check(not controls.charging and p.attack_left<=0,"Release consumed by a pause menu cancels charging without a delayed cast")
 game.paused=false;fresh(true);p.select_weapon(2)
 await mouse_event(true);p.end_surge()
 check(not controls.charging,"Golden buff expiry cancels an unfinished charged coin")
 await mouse_event(false)
 fresh(true);p.select_weapon(2);await mouse_event(true);p.select_character(2)
 check(not controls.charging,"Changing fighters cancels Goemon's held charge")
 await mouse_event(false)
 game.explorer_helpers.clear();serial=game.explorer_helpers.summon_serial
 await raw_key(KEY_2);await raw_key(KEY_2,false)
 check(game.explorer_helpers.summon_serial==serial,"Other fighters cannot summon through bare numbers")
 game.forest_ui.sync()
 check(not game.forest_ui.helper_portraits[1].visible,"Other fighters leave unused slots empty")
 p.select_character(1);game.forest_ui.sync()
 check(game.forest_ui.loadout_buttons[1].tooltip_text.contains("coin") and not game.forest_ui.loadout_buttons[1].tooltip_text.contains("allies"),"Goemon HUD describes selected weapons and charged coins")
 game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOEMON_WEAPON_CONTROLS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
