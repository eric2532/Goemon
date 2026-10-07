extends "res://scripts/rogue_siege_tests.gd"

func aim_world(point: Vector3):
 var d=point-game.player.position
 game.camera_rig.yaw=atan2(-d.x,-d.z)
 if game.player.is_rogue_character():game.player.active_ability._update_aim()

func fresh_class(index: int):
 press("light_attack",false);press("heavy_attack",false)
 if game.paused:game.resume()
 var p=game.player
 p.smoke_move=Vector2.ZERO;p.cancel_charge();p.clear_powerups()
 p.buildings_broken=0;p.scale=Vector3.ONE;p.run_upgrades={"damage":0,"vitality":0,"tempo":0}
 p.select_character(index+3)
 if not p.is_rogue_character():return
 p.active_ability.reset_run()
 await clear_enemies()
 game.reset_player_at(TEST_ORIGIN);p.hp=p.max_hp;p.invuln=0
 aim_world(p.position+Vector3(8,0,0));await frames(12);native_projectiles.clear()

func run():
 visual="--fire-siege-controls-visual" in OS.get_cmdline_user_args()
 output_dir="user://tests/fire-siege-controls"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
 Input.use_accumulated_input=false
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
 game.start_mode("defense");pause_fixture_director();await frames(3)
 check(game.rogue_roster_mode,"Fire Siege enables all playable heroes")
 check(not game.rogue_battle_mode and not game.rogue_view.enabled and game.camera_rig.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Fire Siege keeps the original camera and disables cursor aiming")
 if not game.rogue_roster_mode:
  print("FIRE_SIEGE_CONTROLS_RESULT checks=",checks," failures=",failures)
  get_tree().quit(1);return
 game.encounters.choose_card("supply_cache");await frames(2)
 await primary_rules()
 # No enemy or mouse location influences a ranged shot heading.
 await fresh_class(3)
 var a=game.player.active_ability
 game.camera_rig.yaw=PI;tap("heavy_attack")
 check(not a.projectiles.is_empty() and a.projectiles[0].vel.z>0 and absf(a.projectiles[0].vel.x)<.01,"Mage bolt follows camera heading even when old cursor aim points elsewhere")
 # The committed melee remains captured while the camera turns.
 await fresh_class(0);var target=fixture(Vector3(2.2,0,0));tap("light_attack")
 game.camera_rig.yaw=PI;await frames(25)
 check(target.hp<10000,"Turning the camera cannot redirect a committed pipe/sword contact")
 for i in range(10):
  await fresh_class(i);a=game.player.active_ability
  var before=game.player.position;tap("dodge");await frames(5)
  check(game.player.position.distance_to(before)>.05,"%s C always evades" % CLASS_IDS[i])
  check(not a.player.crouched and (a.player.travel==null or a.player.travel.kind!="hook"),"%s C does not trigger a stance or hook" % CLASS_IDS[i])
  await fresh_class(i);a=game.player.active_ability;tap("surge")
  check(a.player.cooldowns.drink>0,"%s R preserves signature skill" % CLASS_IDS[i])
 await fresh_class(9);a=game.player.active_ability;tap("equip")
 check(a.player.crouched,"Master Thief E preserves Get Down")
 await fresh_class(8);a=game.player.active_ability
 var forward=fixture(Vector3(10,0,0));tap("equip")
 check(a.player.travel!=null and a.player.travel.kind=="hook" and a.player.travel.target.x>game.player.position.x,"Explorer E hooks forward without cursor aiming")
 await fresh_class(0);a=game.player.active_ability;tap("equip")
 check(a.player.roll<=0,"Pirate does not gain a duplicate E evade")
 game.show_rogue_roster();await frames(2)
 check(game.menu.find_child("RogueFighter_edo",true,false)!=null,"Fighter picker preserves Edo")
 game.choose_rogue_character(2);await frames(2)
 check(game.player.character_id==2 and not game.paused,"Edo can be selected through the shared roster")
 await extended_rules()
 game.show_main_menu();await frames(2)
 check(game.menu.find_child("RogueBattleButton",true,false)==null and game.menu.find_child("RogueSiegeButton",true,false)==null,"Retired cursor modes are absent from the player menu")
 print("FIRE_SIEGE_CONTROLS_RESULT checks=",checks," failures=",failures)
 game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 await frames(18)
 get_tree().quit(1 if failures else 0)

func extended_rules():
 await camera_edge_rules()
 var p=game.player
 p.select_character(1);p.cancel_charge();p.clear_powerups()
 await clear_enemies();game.reset_player_at(TEST_ORIGIN);game.camera_rig.yaw=0
 p.facing=Vector3.FORWARD;p.soft_target=false;await frames(3)
 var normal=fixture(Vector3(0,0,-2.4));tap("light_attack");await frames(115)
 check(is_equal_approx(10000-normal.hp,132.4),"Goemon keeps original automatic triplet and damage")
 await knight_defense_rules();await utility_cover_rules();await impact_and_muzzle_rules()
 for index in [0,1,2,3,4,6,7,8,9]:
  await fresh_class(index);var a=p.active_ability
  var victim=fixture(Vector3(2.2,0,0));tap("heavy_attack")
  if index==9:
   press("heavy_attack");await frames(3)
   check(a.player.blocking,"Master Thief retains hold-to-block")
   press("heavy_attack",false);continue
  await settle_attack()
  check(victim.hp<10000,"%s secondary reaches enemies ahead" % CLASS_IDS[index])
  if index in [1,2,3,6,7]:
   check(native_projectiles.size()==(5 if index==2 else (4 if index==7 else 1)),"%s keeps its original projectile count" % CLASS_IDS[index])
 await fresh_class(5)
 var a=p.active_ability
 var landing_enemy=fixture(Vector3(7.5,0,0));tap("heavy_attack")
 check(a.player.travel!=null and absf(a.player.travel.target.x-p.position.x-7.5)<.01,"Dragoon leap uses its original maximum forward range")
 await frames(60)
 check(landing_enemy.hp<10000,"Forward Dragoon leap preserves landing damage")
 await fresh_class(8);a=p.active_ability
 check(not a.hook_ahead(p.position+Vector3(-3,0,0)),"Hook cannot select a point behind the camera heading")
 tap("dodge");var cd=a.evade_cooldown;tap("dodge")
 check(cd>0 and is_equal_approx(a.evade_cooldown,cd),"Repeated C presses cannot reset or bypass the universal evade cooldown")
 await frames(20);game.show_rogue_roster();game.choose_rogue_character(7);await frames(2)
 press("heavy_attack");await frames(30);game.show_rogue_roster()
 press("heavy_attack",false);game.choose_rogue_character(3);game.show_rogue_roster();game.choose_rogue_character(7);await frames(2)
 check(not p.active_ability.secondary_held and not p.active_ability.player.blocking,"Menu and hero switching clear held blocking input")
 game.restart_area();pause_fixture_director();await frames(3)
 check(game.rogue_roster_mode and not game.rogue_battle_mode and game.camera_rig.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Restart stays in original Fire Siege with camera-facing roster")
 check(game.encounters.phase=="draft" and game.encounters.cannons.size()==24,"Restart preserves the original defense setup and opening cards")
 game.show_main_menu();await frames(2)
 game.menu.find_child("TowerDefenseButton",true,false).pressed.emit();await frames(2)
 button_with_prefix("HARD").pressed.emit();await frames(2)
 check(game.menu.find_children("RogueFighter_*","Button",true,false).size()==12,"Fire Siege difficulty flow offers all twelve heroes")
 game.menu.find_child("RogueFighter_edo",true,false).pressed.emit();pause_fixture_director();await frames(2)
 check(p.character_id==2 and not game.rogue_battle_mode and game.encounters.hard_mode and game.encounters.cannons.size()==4 and game.encounters.money==650,"Hard Fire Siege starts with selected Edo and original economy")
 await capture("hard-opening-draft")

func camera_edge_rules():
 var p=game.player
 p.select_character(2);p.cancel_charge();await clear_enemies()
 game.reset_player_at(TEST_ORIGIN);game.camera_rig.yaw=0;await frames(3)
 fixture(Vector3(4,0,-10));p.buildings_broken=1;p.soft_target=false
 p.musashi.large_cast=true;p.musashi.launch()
 var balls=get_tree().get_nodes_in_group("edo_fireballs")
 check(not balls.is_empty() and balls.back().velocity.normalized().is_equal_approx(Vector3.FORWARD),"Grown Edo cannot auto-target an off-axis enemy in camera-facing Fire Siege")
 for ball in balls:ball.queue_free()
 p.cancel_charge();p.buildings_broken=0;p.select_character(1);p.smoke_move=Vector2.ZERO
 game.reset_player_at(TEST_ORIGIN+Vector3.UP*10);await frames(3)
 p.jumps_used=2;p.smoke_move=Vector2.RIGHT;p.start_attack(true)
 await frames(3)
 check(p.attack_left>0 and p.facing.is_equal_approx(Vector3.FORWARD),"Goemon keeps committed airborne attack direction while strafing")
 p.smoke_move=Vector2.ZERO;p.cancel_charge()
