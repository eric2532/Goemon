extends "res://scripts/recovered_goemon_gameplay_tests.gd"

class SpeedBuff extends Node:
 var dispatching=false
 func attack_multiplier()->float:return 5.0

func run():
 create_timer(180).timeout.connect(func():quit(1))
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player;var state=game.model.team_progression
 var settings_before=FileAccess.get_sha256(game.settings_path)
 for id in p.RogueRoster.CROSSGATE:
  p.select_character(id);fresh();p.clear_food_buffs();state.reset()
  check(is_equal_approx(p.attack_speed_multiplier(),1.0),"Unboosted Cross Gate fighter retains 1x: %d"%id)
  var baseline_crit=p.combat_tuning("critical_chance")
  state.award_kills(1000000)
  check(state.level==99 and state.stat_points==98 and is_equal_approx(p.attack_speed_multiplier(),1.0) and p.combat_tuning("critical_chance")==baseline_crit,"Unspent levels add neither speed nor critical chance: %d"%id)
  check(p.apply_food_buff("attack_speed") and is_equal_approx(p.attack_speed_multiplier(),1.2),"Food still grants speed at maximum level: %d"%id)
  p.tick_food_buffs(p.FOOD_BUFF_SECONDS)
  check(is_equal_approx(p.attack_speed_multiplier(),1.0),"Expired food leaves no level-based speed: %d"%id)
  check(state.spend_stat("attack_speed") and state.spend_stat("critical_chance") and is_equal_approx(p.attack_speed_multiplier(),1.1) and p.combat_tuning("critical_chance")==baseline_crit+1,"Earned points still buy speed and critical chance: %d"%id)
  state.reset()
  state.stat_ranks.attack_speed=5
  check(is_equal_approx(p.attack_speed_multiplier(),1.5),"Bonuses below the cap retain their exact rate: %d"%id)
  p.attack_chain.count=20
  check(is_equal_approx(p.attack_speed_multiplier(),2.25),"Hit chain multiplies before the final cap: %d"%id)
  p.powerups.attack_speed=20;p.attack_speed_stacks=1
  check(is_equal_approx(p.attack_speed_multiplier(),3.0),"Combined bonuses crossing 3x are capped: %d"%id)
  p.progression.level=99;state.level=99;state.stat_ranks.attack_speed=98
  state.ranks.character_speed=20;p.run_upgrades.tempo=10
  p.attack_speed_stacks=4
  for i in 10:p.apply_food_buff("attack_speed")
  check(p.base_attack_speed_multiplier()>100 and is_equal_approx(p.attack_speed_multiplier(),3.0),"All accumulated speed bonuses still stop at 3x: %d"%id)
  var loadout=p.spell_loadout;var buff=SpeedBuff.new();p.spell_loadout=buff
  check(is_equal_approx(p.attack_speed_multiplier(),3.0),"A spell buff cannot bypass the final cap: %d"%id)
  buff.dispatching=true
  check(is_equal_approx(p.attack_speed_multiplier(),3.0),"Dispatching a skill cannot bypass the cap: %d"%id)
  p.spell_loadout=loadout;buff.free()
  var combat=p.active_ability
  combat.cancel();combat.start_attack()
  check(combat.is_attacking(),"Regular attack starts with maximum bonuses: %d"%id)
  var elapsed_before=float(combat.elapsed)
  combat.advance_attack(1.0/60)
  check(is_equal_approx(float(combat.elapsed)-elapsed_before,3.0/60),"Real regular attack advances at exactly 3x: %d"%id)
  game.show_status_panel();await frames()
  check(game.status_panel.values[4].text=="x3.00","Stats shows the capped effective speed: %d"%id)
  game.close_status_panel();await frames()
  combat.cancel();fresh();p.clear_food_buffs();state.reset()
  check(is_equal_approx(p.attack_speed_multiplier(),1.0),"Clearing bonuses restores normal speed: %d"%id)
 check(FileAccess.get_sha256(game.settings_path)==settings_before,"Speed checks preserve saved settings")
 print("ATTACK_SPEED_CAP_RESULT ",checks," checks, ",failures," failures")
 paused=false;game.queue_free();await frames(5)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
