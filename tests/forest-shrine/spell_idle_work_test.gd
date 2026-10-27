extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Trail=preload("res://scripts/recovered_leader_trail.gd")

func run():
 await setup_fixture()
 var p=game.player;p.select_character(20);fresh()
 p.ai_controlled=true;p.ai_target=game.training_dummy;p.auto_attack_enabled=true
 var loadout=p.spell_loadout
 for pair in [["equip","kojiro/wave"],["surge","kojiro/homing"],["sky_strike","kojiro/wind"]]:loadout.equip(20,pair[0],pair[1])
 check(p.auto_attack_running(),"Fixture has a live automatic attack target")
 for i in 10:loadout.tick(1.0/60)
 check(loadout.instances.values().all(func(instance):return not instance.controller.is_attacking()),"Equipped Kojiro donors stay idle during the wearer's automatic primary")
 loadout.cancel();p.ai_controlled=false;p.auto_attack_enabled=false;tap("equip")
 check(loadout.current!=null and loadout.current.busy(),"An explicit borrowed Kojiro spell still starts")
 p.select_character(28);p.ai_controlled=true;p.auto_attack_enabled=true;p.active_ability.tick(1.0/60)
 check(p.active_ability.is_attacking(),"Playable Kojiro still starts his own automatic primary")
 var trail=Trail.new();root.add_child(trail)
 for i in 5:trail.advance(1.0/60,PackedVector3Array([Vector3(i,0,0),Vector3(i,1,0)]),true,false)
 check(trail.mesh!=null and trail.samples.size()>1,"Visible blade motion produces its ribbon")
 trail.layers=0
 var before=Time.get_ticks_usec()
 for i in 1000:trail.advance(1.0/60,PackedVector3Array([Vector3(i,0,0),Vector3(i,1,0)]),true,false)
 print("HIDDEN_TRAIL_1000_USEC ",Time.get_ticks_usec()-before)
 check(trail.mesh==null and trail.samples.is_empty(),"Hidden donor trails clear history and allocate no invisible ribbon")
 trail.layers=1
 for i in 3:trail.advance(1.0/60,PackedVector3Array([Vector3(i,0,0),Vector3(i,1,0)]),true,false)
 check(trail.mesh!=null and trail.samples.size()==3,"Revealed trails restart without stale distant points")
 trail.queue_free();game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SPELL_IDLE_WORK_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
