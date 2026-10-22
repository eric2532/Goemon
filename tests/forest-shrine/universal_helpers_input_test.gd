extends SceneTree
## Real keyboard and pointer events protect the shared helper/hero input boundary.
var game
var checks=0
var failures=0
var cfg="user://universal-helpers-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: universal helpers timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func frames(n=3):
 for i in n:await process_frame
func key(code:int,down:bool=true,echo_:bool=false):
 var e=InputEventKey.new();e.physical_keycode=code;e.pressed=down;e.echo=echo_;root.push_input(e,true)
func tap(code:int):key(code);key(code,false)
func mouse(button:int,down:bool):
 var e=InputEventMouseButton.new();e.position=root.get_visible_rect().get_center();e.button_index=button;e.pressed=down;root.push_input(e,true)
func freeze_helpers():
 for unit in game.explorer_helpers.pool:unit.set_physics_process(false)
func fresh(id:int):
 var p=game.player
 p.cancel_charge();p.quick_attacks.cancel();p.attack_left=0;p.attack_motion_pending=false;p.impact_pause=0;p.dodge_time=0;p.dodge_cooldown=0;p.jump_buffer=0;p.jump_windup=0;p.attack_chain.reset();p.reset_auto_attack()
 p.select_character(id);p.position=Vector3(0,.15,60);p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.jumps_used=0;p.coyote=.13;p.hp=p.max_hp
 if p.is_rogue_character():p.active_ability.reset_run()
 game.model.update_vision(p.position)
 return p
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 for unit in game.gate_defenders.units.values():unit.set_physics_process(false)
 var foe=game.model.waves.spawn_enemy(0,Vector3(0,0,52));foe.hp=100000;foe.max_hp=100000
 game.sync_enemies();await frames()
 for enemy in game.actors.values():enemy.set_physics_process(false);enemy._sync_fitted_pose()
 var h=game.explorer_helpers
 for id in range(1,13):
  var p=fresh(id);h.clear();game.forest_ui.sync()
  check(game.forest_ui.helper_portraits.all(func(portrait):return portrait.visible and portrait.texture!=null),"Character %d sees all five helper portraits"%id)
  var outfit=[p.scarf_equipped,p.gold_cloak,p.weapon_slot]
  for slot in 5:
   var others=h.active_units().filter(func(unit):return unit.slot!=slot)
   var ages=others.map(func(unit):return unit.age)
   tap(KEY_1+slot);freeze_helpers()
   var group=h.active_units(slot)
   check(group.size()==[1,3,5,1,2][slot],"Character %d key %d summons the assigned helper group"%[id,slot+1])
   check(others.map(func(unit):return unit.age)==ages and others.all(func(unit):return unit.state in ["appearing","acting"]),"Character %d key %d preserves the other helper groups"%[id,slot+1])
   check(not p.has_offensive_action() and not p.quick_attacks.coins_enabled and [p.scarf_equipped,p.gold_cloak,p.weapon_slot]==outfit,"Character %d key %d consumes the legacy number shortcut"%[id,slot+1])
   if p.is_rogue_character():check(not p.active_ability.secondary_held,"Character %d key %d never holds the human secondary attack"%[id,slot+1])
   for unit in group:unit.age=.6
   key(KEY_1+slot,true,true);key(KEY_1+slot,false)
   check(group.all(func(unit):return is_equal_approx(unit.age,.6)),"Character %d held/released key %d cannot repeat its helpers"%[id,slot+1])
   tap(KEY_1+slot);freeze_helpers()
   check(h.active_units(slot).size()==[2,6,10,2,4][slot] and group.all(func(unit):return is_equal_approx(unit.age,.6)),"Character %d fresh key %d adds another group immediately without cooldown"%[id,slot+1])
  # Number helpers stay independent of real native mouse attacks and movement.
  mouse(MOUSE_BUTTON_LEFT,true)
  check(p.has_offensive_action(),"Character %d left mouse still begins its native primary"%id)
  var own_attack_left=p.attack_left;var own_ticket=p.attack_chain.active_ticket
  for slot in 5:tap(KEY_1+slot);freeze_helpers()
  check(p.has_offensive_action() and p.attack_left==own_attack_left and p.attack_chain.active_ticket==own_ticket,"Character %d all five helper keys preserve the ongoing primary"%id)
  var prior=h.active_units().duplicate();var prior_ages=prior.map(func(unit):return unit.age)
  tap(KEY_SPACE)
  check(p.jump_buffer>0,"Character %d Space still requests a jump"%id)
  check(p.has_offensive_action(),"Character %d jump preserves the native primary"%id)
  tap(KEY_C)
  check(p.active_ability.player.roll>0 or p.active_ability.player.invuln>0 if p.is_rogue_character() else p.dodge_time>0,"Character %d C still begins its native evade"%id)
  mouse(MOUSE_BUTTON_LEFT,false)
  check(prior==h.active_units() and prior.map(func(unit):return unit.age)==prior_ages,"Character %d Space/C preserve all active helper groups"%id)
  p=fresh(id);mouse(MOUSE_BUTTON_RIGHT,true)
  if p.is_rogue_character():
   check(p.active_ability.secondary_held,"Character %d right mouse still starts its native secondary"%id)
   tap(KEY_3);freeze_helpers()
   check(p.active_ability.secondary_held and p.active_ability.secondary_sources.has("mouse"),"Character %d helper key 3 release preserves a held right mouse"%id)
  else:check(p.attack_left>0,"Character %d right mouse still starts its native heavy attack"%id)
  mouse(MOUSE_BUTTON_RIGHT,false)
  if p.is_rogue_character():check(not p.active_ability.secondary_held,"Character %d right mouse release still releases its secondary"%id)
 # Edo's legacy digit casts activate only when unleashed, so test that path too.
 var edo=fresh(2);h.clear();edo.attack_chain.count=100;edo.attack_chain.remaining=1.75
 for slot in 5:
  tap(KEY_1+slot);freeze_helpers()
  check(h.active_units(slot).size()==[1,3,5,1,2][slot] and edo.attack_left==0 and edo.musashi.state==0 and edo.attack_chain.active_ticket.is_empty(),"Unleashed Edo key %d summons helpers without casting native number spells"%(slot+1))
 # A live group must survive switching through every shared-loadout fighter.
 fresh(11);h.clear();tap(KEY_2);freeze_helpers()
 var rangers=h.active_units(1).duplicate()
 for id in range(1,13):
  game.player.select_character(id);h._process(0)
  for unit in rangers:unit._physics_process(1.0/60);unit.set_physics_process(false)
  check(h.active_units(1)==rangers and rangers.all(func(unit):return unit.state in ["appearing","acting"]),"Active Rangers persist through switch to character %d"%id)
 game.show_rogue_roster();h._process(0)
 check(h.active_units(1)==rangers,"The live character chooser pauses and preserves active helpers")
 game.choose_rogue_character(2);h._process(0);freeze_helpers()
 check(game.player.character_id==2 and h.active_units(1)==rangers,"Choosing Edo through the real roster resumes the same helper group")
 # No-target input is consumed, rather than falling back to Goemon's coins.
 h.clear();fresh(1);foe.hp=0;game.actors[foe.id].hp=0;game.actors[foe.id].dead=true
 tap(KEY_2);freeze_helpers();check(h.active_units(1).size()==3 and not game.player.quick_attacks.coins_enabled,"No-target helper press summons allies without Goemon's old number action")
 tap(KEY_4);freeze_helpers();check(h.active_units(3).size()==1,"Any fighter can summon Knight without a visible target")
 game.show_title()
 check(h.pool.all(func(unit):return unit.state=="idle") and h.smoke.items.is_empty(),"Returning to title clears every helper and smoke burst")
 await finish()
func finish():
 game.sound_library.cancel();game.music.stop()
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120)
 game.queue_free();paused=false;await frames();await create_timer(.2).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("UNIVERSAL_HELPERS_INPUT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
