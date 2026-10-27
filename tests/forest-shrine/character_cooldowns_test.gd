extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Character Cooldowns/"

func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 if label_!="settings":
  var p=game.player;p.clear_character_cooldowns()
  game.camera_rig.camera.global_position=p.global_position+Vector3(9,6,12)
  game.camera_rig.camera.look_at(p.global_position+Vector3(0,1,-4))
 game.forest_ui.sync();await frames(2);RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Rendered %s capture saved"%label_)

func run():
 create_timer(150).timeout.connect(func():printerr("CHARACTER_COOLDOWNS_TIMEOUT");quit(1))
 await setup_fixture();game.set_process(false)
 var p=game.player
 check(not game.settings.disable_character_cooldowns,"Cooldowns remain enabled by default")
 var config=ConfigFile.new();config.set_value("settings","volume",.37);config.save(cfg)
 game.load_settings()
 check(not game.settings.disable_character_cooldowns and game.settings.volume==.37,"Older saves retain preferences and normal cooldowns")
 config.set_value("settings","disable_character_cooldowns","bad");config.save(cfg);game.load_settings()
 check(not game.settings.disable_character_cooldowns,"Malformed cooldown preference defaults off")
 game.show_settings(false);await frames()
 var toggle=game.menu.find_child("DisableCharacterCooldownsToggle",true,false)
 check(toggle is CheckButton and not toggle.button_pressed,"Settings exposes the cooldown toggle")
 toggle.button_pressed=true;game.load_settings()
 check(game.settings.disable_character_cooldowns,"Enabling the toggle saves across reload")
 if DisplayServer.get_name()!="headless":
  root.grab_focus();DisplayServer.window_move_to_foreground()
  await capture("settings")
 game.resume();game.model.phase="wave";await frames(2)
 for id in p.RogueRoster.PLAYABLE_IDS:
  p.select_character(id);fresh();p.dodge_cooldown=7
  var attack_left=p.attack_left;var hp=p.hp
  p.clear_character_cooldowns()
  check(p.dodge_cooldown==0 and p.attack_left==attack_left and p.hp==hp,"Fighter %d clears waits without changing combat state"%id)
 p.select_character(3);fresh()
 var rogue=p.active_ability
 for key in rogue.player.cooldowns:rogue.player.cooldowns[key]=10.0
 rogue.evade_cooldown=3;rogue.player.buffTime=4;rogue.player.drink=1
 p.clear_character_cooldowns()
 check(rogue.player.cooldowns.values().all(func(v):return v==0) and rogue.evade_cooldown==0,"All Rogue slots and evade clear")
 check(rogue.player.buffTime==4 and rogue.player.drink==1,"Buff and gesture durations stay intact")
 tap("surge");rogue.player.drink=1;tap("surge")
 check(rogue.player.drink==5,"Actual Rogue skill input can immediately repeat")
 rogue.player.cooldowns.drink=5;p.ai_controlled=true;p.dodge_cooldown=2;p.clear_character_cooldowns()
 check(rogue.player.cooldowns.drink==5 and p.dodge_cooldown==2,"AI-controlled characters retain cooldowns")
 p.ai_controlled=false
 game.settings.disable_character_cooldowns=false;p.clear_character_cooldowns()
 check(rogue.player.cooldowns.drink==5 and p.dodge_cooldown==2,"Turning the setting off leaves normal cooldowns authoritative")
 game.settings.disable_character_cooldowns=true
 p.select_character(1);fresh();p.dodge_cooldown=10;tap("dodge")
 check(p.dodge_time>0 and p.dodge_cooldown<10,"Actual dodge input bypasses an existing cooldown")
 p.forward_dash.cancel();p.dodge_time=0
 # Exercise the borrowed-controller path as well as the native fighter.
 p.spell_loadout.equip(1,"surge","pirate/drink")
 var borrowed=p.spell_loadout.instances["1:pirate/drink"].controller
 borrowed.player.cooldowns.drink=12;borrowed.evade_cooldown=3
 p.spell_loadout.retired_cooldowns={"1:knight/lion":{"lion":12.0}}
 p.clear_character_cooldowns()
 check(borrowed.player.cooldowns.drink==0 and borrowed.evade_cooldown==0 and p.spell_loadout.retired_cooldowns.is_empty(),"Borrowed skills and unequipped cooldowns clear")
 p.select_character(2);fresh();p.musashi.shield_left=2;p.musashi.shield_cooldown=20
 p._physics_process(1.0/60)
 check(p.musashi.shield_cooldown==0 and p.musashi.shield_left>1.9,"Edo clears cooldown without expiring his active shield")
 p.select_character(7);fresh()
 var instance=p.spell_loadout.instances["7:knight/lion"];var lion=instance.controller
 var pool=lion.Pool.service(game)
 var counts=[]
 for cycle in 3:
  lion.cooldown=12;tap("sky_strike")
  check(lion.is_attacking() and is_equal_approx(lion.charge_left,lion.CHARGE),"Repeated lion %d retains full preparation"%cycle)
  if cycle==0:await capture("lion-charge")
  for i in 49:p._physics_process(1.0/60)
  check(not lion.is_attacking() and lion.shots.size()>0,"Repeated lion %d completes and releases"%cycle)
  if cycle==0:await capture("lion-release")
  p.clear_character_cooldowns()
  check(instance.can_cast(),"Repeated lion %d is immediately ready after its animation"%cycle)
  lion.cancel();counts.append(pool.all[pool.key_for(p,lion.Projectile,"knight-lion")].size())
 check(counts==[2,2,2],"Repeated lions reuse their two prepared projectiles")
 game.settings.disable_character_cooldowns=false;lion.cooldown=12
 check(not instance.can_cast(),"Normal lion cooldown blocks recasting when the toggle is off")
 game.settings.disable_character_cooldowns=true
 p.select_character(18);fresh();game.camera_focused=true
 var chief=p.active_ability;chief.select_slot(5);chief.cooldown=10;chief.weapon_cooldowns.fill(10.0)
 p.clear_character_cooldowns();chief.fire_shot()
 check(chief.cooldown>0 and not chief.sword_swing.is_empty(),"Chief sword starts through the normal controller")
 var shots=chief.shots_fired
 p.clear_character_cooldowns();chief.advance_sword(.05);chief.fire_shot()
 check(chief.shots_fired==shots and chief.sword_swing.age>=.05,"No cooldown does not restart a sword before its contact")
 chief.advance_sword(chief.SWORD_CONTACT_END);p.clear_character_cooldowns();chief.fire_shot()
 check(chief.shots_fired==shots+1,"Chief sword can repeat as soon as its contact finishes")
 chief.select_slot(2);p.clear_character_cooldowns()
 check(chief.cooldown==0 and chief.weapon_cooldowns.all(func(v):return v==0),"All Chief weapon cooldowns clear across selection")
 game.show_settings(true);await frames()
 toggle=game.menu.find_child("DisableCharacterCooldownsToggle",true,false)
 check(toggle.button_pressed and game.paused,"Paused Settings shows the same saved toggle")
 toggle.button_pressed=false;game.load_settings()
 check(not game.settings.disable_character_cooldowns,"Disabling the toggle persists too")
 game.queue_free();game=null;paused=false;await frames(3)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("CHARACTER_COOLDOWNS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
