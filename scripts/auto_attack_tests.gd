extends "res://scripts/rogue_equipment_combat_tests.gd"
var automatic_melee_contacts=0
func observe_auto_contact(_victim,_strength,_duration):
 if game.player.character_id==1:automatic_melee_contacts+=1
func run():
 game.smoke_test=true;Input.use_accumulated_input=false
 game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director();await frames(3)
 check(InputMap.has_action("auto_attack_toggle"),"A free hotkey toggles normal auto attack")
 if not game.player.has_method("auto_attack_running"):check(false,"Hero supports optional automatic normal attacks");finish();return
 var p=game.player
 check(not p.auto_attack_enabled,"Auto attack starts OFF")
 # Every hero must damage a real target without synthesizing LMB input.
 for id in range(1,13):
  if id>=3:await fresh_class(id-3)
  else:
   await fresh_goemon();p.select_character(id);game.camera_rig.yaw=-PI/2;await frames(5)
  p.auto_attack_enabled=false;p.attack_chain.reset()
  var target=fixture(Vector3(3,0,0));tap("auto_attack_toggle")
  check(p.auto_attack_enabled and not Input.is_action_pressed("light_attack"),"Hero %d enables auto attack without holding mouse" % id)
  await frames(110)
  check(target.hp<10000,"Hero %d automatic primary damages a real enemy" % id)
  tap("auto_attack_toggle");await frames(120);var settled=target.hp
  await frames(40);check(target.hp==settled and not p.auto_attack_enabled,"Hero %d stops repeating after toggle OFF" % id)
 # UNLEASHED intentionally skips manual recovery; repeating automation must
 # still wait between bursts instead of depending on the physics frame rate.
 await fresh_goemon();p.attack_chain.count=100;p.attack_chain.remaining=10
 game.camera_rig.yaw=-PI/2;fixture(Vector3(3,0,0))
 game.impact_confirmed.connect(observe_auto_contact)
 tap("auto_attack_toggle");await frames(3);var contacts=automatic_melee_contacts
 await frames(4);check(contacts>0 and automatic_melee_contacts==contacts,"Unleashed Goemon waits between automatic three-strike bursts")
 await frames(40);check(automatic_melee_contacts>contacts,"Unleashed Goemon resumes after its normal repeat interval")
 p.set_auto_attack(false);game.impact_confirmed.disconnect(observe_auto_contact)
 await fresh_goemon();p.select_character(2);p.attack_chain.count=100;p.attack_chain.remaining=10
 tap("auto_attack_toggle");await frames(3);var balls=get_tree().get_nodes_in_group("musashi_projectiles").size()
 await frames(4);check(balls==3 and get_tree().get_nodes_in_group("musashi_projectiles").size()==balls,"Unleashed Edo waits between automatic three-fireball volleys")
 await frames(40);check(get_tree().get_nodes_in_group("musashi_projectiles").size()>balls,"Unleashed Edo resumes after its normal repeat interval")
 p.set_auto_attack(false)
 await fresh_class(7);tap("auto_attack_toggle");await frames(45)
 var a=p.active_ability
 check(a.player.rangerShots>=3 and native_projectiles.values().any(func(pr):return pr.damage==101),"Ranger auto fire retains every-third green power shot")
 var shots=a.player.rangerShots;game.show_pause();await frames(25)
 check(a.player.rangerShots==shots and p.auto_attack_enabled and not p.auto_attack_running(),"Pause suspends auto fire while keeping toggle state")
 game.resume();pause_fixture_director();await frames(25)
 check(a.player.rangerShots>shots,"Resume continues automatic normal attacks")
 game.reset_player_at(game.world.cannon_sites[4].build_position);await frames(20);shots=a.player.rangerShots
 game.encounters.update_build_input(.5);await frames(25)
 check(a.player.rangerShots<=shots+1 and not p.auto_attack_running(),"Nearby automatic construction stops new automatic attacks")
 game.reset_player_at(TEST_ORIGIN);await frames(25);check(a.player.rangerShots>0,"Leaving construction range resumes auto fire")
 p.auto_attack_enabled=false;p.cancel_charge();a.reset_run();p.position+=Vector3.UP*20;await frames(2);p.velocity=Vector3(0,-5,0);p.jumps_used=2;p.coyote=0;p.jump_buffer=0
 press("jump");tap("auto_attack_toggle");await frames(35)
 check(a.player.rangerShots>=2 and a.projectiles.size()>=5 and a.projectiles.any(func(pr):return pr.vel.y<0),"Double-jump glide automatically fires downward fans")
 press("jump",false);p.auto_attack_enabled=false
 await fresh_class(3);a=p.active_ability;tap("auto_attack_toggle");await frames(8);press("light_attack");await frames(90)
 check(a.player.charging and a.player.chargeTime>.9,"Mage can manually hold charge while auto attack is enabled")
 press("light_attack",false);await frames(2);check(not a.player.charging and a.projectiles.any(func(pr):return pr.damage>=70),"Manual Mage release keeps working with charged damage")
 p.auto_attack_enabled=false
 await fresh_goemon();p.select_character(2);tap("surge");tap("auto_attack_toggle");await frames(24)
 check(p.musashi.beam_held and is_instance_valid(p.musashi.beam),"Edo empowered auto primary sustains its native beam")
 tap("auto_attack_toggle");await frames(2);check(not p.musashi.beam_held,"Toggle OFF releases an automatic beam")
 await fresh_class(7);tap("auto_attack_toggle");p.select_character(3);check(not p.auto_attack_enabled,"Hero switching resets auto attack OFF")
 tap("auto_attack_toggle");game.restart_area();await frames(3);check(not p.auto_attack_enabled,"New run resets auto attack OFF")
 pause_fixture_director();tap("auto_attack_toggle");game.encounters.hero_died();check(not p.auto_attack_enabled,"Death clears auto attack before revival")
 game.encounters.runtime.revive_left=0;game.encounters.revive_now();p.hp=p.max_hp
 game.open_map_editor();await frames(3);check(not p.auto_attack_enabled and not p.auto_attack_running(),"Map editor cannot inherit automatic attacks")
 game.map_editor.close_editor();tap("auto_attack_toggle");check(not p.auto_attack_enabled,"Main menu ignores the auto attack key")
 finish()
func finish():
 game.show_main_menu();game.sound_library.cancel();game.music.stop();stop_audio(game);await frames(3)
 print("AUTO_ATTACK_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
