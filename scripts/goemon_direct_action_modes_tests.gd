extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Number 1 owns its complete native triplet, including in Rogue Battle.
## The previous weapon is restored only after every native strike has finished.
func run():
 await setup_fixture()
 var p=game.player
 for battle in [false,true]:
  game.rogue_battle_mode=battle
  for previous_slot in [2,3]:
   fresh();p.select_weapon(previous_slot)
   tap("weapon_pipe")
   check(p.weapon_slot==1 and p.attack_left>0 and p.combo==1 and p.quick_attacks.active,"Direct pipe action begins from weapon %d in Rogue Battle=%s"%[previous_slot,battle])
   await step(200)
   check(p.combo==3 and p.attack_left<=0,"Direct pipe action completes all three native stages from weapon %d in Rogue Battle=%s"%[previous_slot,battle])
   check(not p.quick_attacks.active and p.weapon_slot==previous_slot,"Completed direct pipe action restores weapon %d in Rogue Battle=%s"%[previous_slot,battle])
   check(p.weapon_controls.available(),"Direct pipe action leaves controls available from weapon %d in Rogue Battle=%s"%[previous_slot,battle])
 # Ordinary Rogue Battle primary retains its existing held-combo controller.
 fresh();p.select_weapon(1);tap("light_attack");await step(100)
 check(p.combo==1 and p.attack_left<=0 and not p.quick_attacks.active,"A tapped Rogue Battle primary remains one stage rather than a direct-action triplet")
 game.rogue_battle_mode=false
 game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOEMON_DIRECT_ACTION_MODES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
