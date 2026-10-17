extends "res://scripts/fire_siege_controls_tests.gd"
# Integration assertions exercise real input, collision bodies and enemy damage.
# Reverting each corresponding kit upgrade must fail its named assertion.
func run():
 visual="--rogue-combat-upgrade-visual" in OS.get_cmdline_user_args()
 output_dir="user://tests/rogue-combat-upgrade"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director();game.encounters.choose_card("supply_cache")
 await frames(3)
 if not "--posture-only" in OS.get_cmdline_user_args():
  await aliases_and_alternates()
  await dash_and_melee_rules()
  await mage_rules()
  await guard_rules()
  await leap_rules()
  await edge_rules()
  await signature_rules()
 await posture_transition_rules()
 game.show_main_menu();game.sound_library.cancel();game.music.stop()
 await frames(3)
 stop_audio(game)
 var shared_audio=game.get_node_or_null("RogueSharedClassAudio")
 if is_instance_valid(shared_audio):shared_audio.cache.clear()
 await frames(30)
 print("ROGUE_COMBAT_UPGRADE_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)

func stop_audio(node: Node):
 if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
  node.stop();node.stream=null
 for child in node.get_children():stop_audio(child)

func aliases_and_alternates():
 for index in range(10):
  await fresh_class(index)
  var a=game.player.active_ability
  press("weapon_chain")
  check(a.secondary_held and a.player.cooldowns.flintlock>0,"%s key 3 starts and holds the secondary" % CLASS_IDS[index])
  press("weapon_chain",false)
  check(not a.secondary_held,"%s key 3 release clears held secondary" % CLASS_IDS[index])
 for index in [1,2]:
  await fresh_class(index);var a=game.player.active_ability
  tap("equip")
  check(a.projectiles.size()==(1 if index==1 else 5),"%s E preserves its alternate ranged attack" % CLASS_IDS[index])
  if index==2 and not a.projectiles.is_empty():
   check(a.projectiles[0].width>=.45 and a.projectiles[0].life*a.projectiles[0].vel.length()>=26,"Ninja shuriken gain size and range")

func dash_and_melee_rules():
 await fresh_class(2);var a=game.player.active_ability
 var near=fixture(Vector3(2,0,0));var far=fixture(Vector3(8,0,0));var side=fixture(Vector3(5,0,3))
 var origin=game.player.position
 tap("heavy_attack");game.camera_rig.yaw=PI
 await frames(55)
 check(near.hp<10000 and far.hp<10000 and side.hp==10000,"Ninja dash cuts the entire committed path while excluding wide side targets")
 check(game.player.position.x-origin.x>8,"Ninja secondary travels a long forward dash")
 await fresh_class(1);a=game.player.active_ability
 far=fixture(Vector3(6.4,0,0));tap("heavy_attack")
 check(a.projectiles.size()==1 and a.projectiles[0].kind=="crimson-arrow" and a.projectiles[0].color.r>.8 and a.projectiles[0].color.g<.3,"Samurai launches a huge red energy arrow")
 await frames(35)
 check(10000-far.hp>=140,"Samurai arrow deals powerful long-range damage")
 await fresh_class(8);a=game.player.active_ability
 tap("light_attack")
 check(a.player.attack!=null and a.player.attack.get("style","")=="evasive-slash" and a.player.invuln>0,"Explorer primary combines an evasive window with underhand blades")
 await fresh_class(8);a=game.player.active_ability
 far=fixture(Vector3(4.5,0,0));tap("heavy_attack");await frames(40)
 check(far.hp<10000 and game.player.position.x-TEST_ORIGIN.x>4,"Explorer secondary dashes forward and lands the cross slash")
 for index in [4,5,9]:
  await fresh_class(index);a=game.player.active_ability
  near=fixture(Vector3(2.6 if index==5 else 1.9,0,0))
  far=fixture(Vector3(4.0 if index!=5 else 5.4,0,0));tap("light_attack");await frames(40)
  check(near.hp<10000,"%s primary damages a target inside the visible weapon stroke" % CLASS_IDS[index])
  check(far.hp==10000,"%s primary has no invisible reach beyond the weapon stroke" % CLASS_IDS[index])

func mage_rules():
 var damages=[];var widths=[]
 for tier in range(4):
  await fresh_class(3);var a=game.player.active_ability
  press("light_attack")
  if tier>0:a.tick_timers(float(tier)+.02)
  check(a.projectiles.is_empty(),"Mage does not release a fireball before primary release at tier %d" % tier)
  press("light_attack",false)
  check(a.projectiles.size()==1 and a.projectiles[0].kind=="fireball","Mage tap/charge release creates one fireball at tier %d" % tier)
  if not a.projectiles.is_empty():
   damages.append(a.projectiles[0].damage);widths.append(a.projectiles[0].width)
 check(damages.size()==4 and damages[0]<damages[1] and damages[1]<damages[2] and damages[2]<damages[3],"Mage 1/2/3 second charge tiers increase fireball damage")
 check(widths.size()==4 and widths[0]<widths[1] and widths[1]<widths[2] and widths[2]<widths[3],"Mage charge tiers increase fireball collision size")
 await fresh_class(3);var a=game.player.active_ability
 press("light_attack");a.tick_timers(4.2)
 check(is_equal_approx(a.player.get("chargeTime",0),3),"Mage charge is capped at three seconds")
 var before=a.player.get("chargeTime",0);game.paused=true;a.physics_step(.5)
 check(a.player.get("chargeTime",0)==before,"Pause freezes a held fireball charge")
 game.paused=false;a.cancel();press("light_attack",false)
 check(a.projectiles.is_empty() and a.player.get("chargeTime",0)==0,"Cancel discards the charged spell without a phantom projectile")
 await fresh_class(3);a=game.player.active_ability
 var near=fixture(Vector3(6.5,0,0));var far=fixture(Vector3(11,0,0))
 tap("heavy_attack")
 check(near.hp==10000 and near.frozen_left>=2.99 and far.frozen_left==0,"Frost nova freezes its wide radius for three seconds and deals no damage")
 await capture("mage-frost-nova")

func guard_rules():
 await fresh_class(9);var a=game.player.active_ability
 press("weapon_chain");var origin=game.player.position
 game.player.smoke_move=Vector2.RIGHT;await frames(12)
 check(a.player.blocking and game.player.position.distance_to(origin)<.03,"Held Master Thief guard prevents movement")
 var hp=game.player.hp
 check(a.filter_damage(30,Vector3.LEFT,false)==0,"Master Thief guard blocks incoming damage")
 a.tick_timers(3.1)
 check(not a.player.blocking and a.player.cooldowns.flintlock>0,"Thief guard ends after three seconds with bounded cooldown")
 a.tick_timers(.2)
 check(not a.player.blocking,"Holding guard past expiry cannot instantly retrigger it")
 press("weapon_chain",false)
 await fresh_class(9);a=game.player.active_ability
 press("heavy_attack");press("weapon_chain");press("heavy_attack",false)
 check(a.secondary_held and a.player.blocking,"Releasing RMB keeps guard held while key 3 is still down")
 press("weapon_chain",false)
 check(not a.player.blocking,"Last secondary input release ends Thief guard")
 await fresh_class(4);a=game.player.active_ability
 var target=fixture(Vector3(4.5,0,0));tap("heavy_attack")
 check(a.player.blocking and target.hp==10000,"Knight opens a two-second defensive window without an immediate bash")
 var blocked=a.filter_damage(30,Vector3.LEFT,false)==0
 await frames(24)
 check(blocked and 10000-target.hp>=150,"A real incoming melee hit triggers Knight's massive shield counter")
 await fresh_class(4);a=game.player.active_ability
 tap("heavy_attack");a.tick_timers(2.1)
 check(not a.player.blocking and a.filter_damage(30,Vector3.LEFT,false)>0,"Knight guard expires after its two-second window")

func leap_rules():
 await fresh_class(5);var a=game.player.active_ability
 var target=fixture(Vector3(7.5,0,2.5));tap("heavy_attack")
 await frames(115)
 check(is_equal_approx(10000-target.hp,192),"Dragoon landing sends exactly three 64-damage blue shockwaves")
 check(a.player.get("pulses",[]).is_empty(),"Dragoon pending pulses cleanly finish")
 await fresh_class(5);a=game.player.active_ability
 tap("heavy_attack");await frames(45);a.cancel()
 check(a.player.get("pulses",[]).is_empty() and a.player.travel==null,"Cancel clears leap and pending landing pulses")

func edge_rules():
 # A quick released press during cooldown must not become a never-released channel.
 await fresh_class(3);var a=game.player.active_ability
 press("light_attack");press("light_attack",false);await frames(2)
 a.fx.tick(.01)
 var valid_effects=true
 for effect in a.fx.items:valid_effects=valid_effects and is_instance_valid(effect.node)
 check(valid_effects,"Released charge orb is removed before the effects updater reads it")
 await fresh_class(3);a=game.player.active_ability
 tap("light_attack");await frames(22);tap("light_attack");await frames(20)
 check(not a.player.get("charging",false),"Mage cooldown taps cannot leave an orphan charge after release")
 await fresh_class(9);a=game.player.active_ability
 game.player.run_upgrades.tempo=100
 press("heavy_attack");a.tick_timers(3.1)
 check(not a.player.blocking and a.player.cooldowns.flintlock>=1.8,"Attack-speed growth cannot remove Thief guard recovery")
 press("heavy_attack",false)
 # Continuous hand changes are independent of the three-stage damage combo.
 await fresh_class(8);a=game.player.active_ability
 var sides=[]
 for i in range(4):
  tap("light_attack")
  sides.append(a.player.attack.get("swingSide",0) if a.player.attack!=null else 0)
  await frames(18)
 check(sides==[1,-1,1,-1],"Explorer alternates right-left through the fourth strike")
 await fresh_class(9);a=game.player.active_ability
 var event=InputEventKey.new();event.physical_keycode=KEY_3;event.pressed=true
 Input.parse_input_event(event);Input.flush_buffered_events()
 check(a.player.blocking and a.secondary_held,"Physical keyboard 3 enters held guard through the real input map")
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events()
 check(not a.player.blocking,"Physical keyboard 3 release ends held guard")
 await fresh_class(9);a=game.player.active_ability
 press("heavy_attack")
 check(a.filter_damage(20,Vector3.RIGHT,true)==0 and a.filter_damage(20,Vector3.BACK,false)==0,"Master Thief timed defense covers projectile and melee from every side")
 a.cancel();press("heavy_attack",false)
 await fresh_class(9);a=game.player.active_ability
 var small=fixture(Vector3(3.5,0,0));tap("light_attack");await frames(35)
 check(small.hp==10000,"Ungrown pipe cannot hit outside its actual reach")
 await fresh_class(9);a=game.player.active_ability
 game.player.buildings_broken=20;game.player.scale=Vector3.ONE*game.player.growth_multiplier()
 var large=fixture(Vector3(3.5,0,0));var distant=fixture(Vector3(16.0,0,0));tap("light_attack");await frames(35)
 check(large.hp<10000,"The visibly grown pipe reaches a target outside its ungrown stroke")
 check(distant.hp==10000,"Growing the pipe does not restore its former invisible reach")
 await fresh_class(2);a=game.player.active_ability
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.5,7,7);shape.shape=box;wall.add_child(shape)
 game.add_child(wall);wall.global_position=game.player.global_position+Vector3(3,2,0)
 var hidden=fixture(Vector3(5,0,0));await frames(2);tap("heavy_attack");await frames(55)
 check(game.player.position.x<TEST_ORIGIN.x+3 and hidden.hp==10000,"Ninja dash stops at real cover and cannot damage through it")
 wall.queue_free();await frames(2)
 await fresh_class(3);a=game.player.active_ability
 wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 shape=CollisionShape3D.new();box=BoxShape3D.new();box.size=Vector3(.5,7,7);shape.shape=box;wall.add_child(shape)
 game.add_child(wall);wall.global_position=game.player.global_position+Vector3(3,2,0)
 hidden=fixture(Vector3(5,0,0));await frames(2);tap("heavy_attack")
 check(hidden.frozen_left==0,"Frost nova respects cover line of sight")
 wall.queue_free();await frames(2)

func signature_rules():
 await fresh_class(3);var a=game.player.active_ability
 tap("surge");tap("light_attack")
 check(a.player.buffTime>0 and a.player.cooldowns.cutlass<=.2,"Mage Overflow still accelerates repeated fireball casting")
 await fresh_class(4);a=game.player.active_ability
 tap("surge");tap("heavy_attack");a.filter_damage(20,Vector3.LEFT,true)
 check(a.player.riposte>0,"Knight Code still earns an empowered next sword strike from blocking")
 await frames(45)
 var target=fixture(Vector3(1.9,0,0));var distant=fixture(Vector3(3.8,0,0));tap("light_attack");await frames(35)
 check(is_equal_approx(10000-target.hp,76),"Knight Code empowered primary preserves its 1.8x damage")
 check(distant.hp==10000,"Knight Code increases damage without adding invisible sword reach")


func posture_transition_rules():
 await fresh_class(1)
 var a=game.player.active_ability
 tap("heavy_attack")
 check(a.player.shot>0 and a.player.attack==null,"Samurai energy arrow enters the bow-shot equipment state")
 a._animate(0,0)
 var actor=game.player.model.actor
 check(actor.joints.Body.node.to_local(actor.joints.Weapon_Pistol.node.global_position).z>.25,"Samurai brings the actual bow into firing position")
 var sheath=actor.model.find_child("SamuraiRedScabbard",true,false)
 check(sheath!=null and actor.joints.Weapon_Cutlass.node.global_position.distance_to(sheath.global_position)<.015,"Samurai keeps his katana seated in the red scabbard while releasing the energy arrow")
 await fresh_class(9);a=game.player.active_ability
 press("heavy_attack");tap("equip")
 check(a.player.crouched and not a.player.blocking and a.player.guardTime==0 and a.player.guardStyle.is_empty(),"Crouching cancels Thief guard timer and pose with its protection")
 press("heavy_attack",false)
