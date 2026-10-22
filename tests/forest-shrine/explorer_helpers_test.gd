extends SceneTree
const GuardFixture=preload("res://tests/forest-shrine/guard_combat_fixture.gd")
var game
var checks=0
var failures=0
var physics_driver
var cfg="user://explorer-helpers-%d.cfg"%OS.get_process_id()
func _initialize():
 set_meta("forest_army_backend","legacy")
 Engine.physics_ticks_per_second=600;Engine.time_scale=10
 create_timer(90).timeout.connect(func():printerr("FAIL: helpers timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",label_)
 if not ok:failures+=1
func frames(n=3):
 for i in n:await process_frame
func step(n:int):
 if physics_driver==null:
  physics_driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(physics_driver)
 await physics_driver.advance(n,func(delta):
  for u in game.explorer_helpers.pool:
   u.set_physics_process(false)
   if u.state!="idle":u._physics_process(delta);u.active_ability.fx.tick(delta)
  game.explorer_helpers._process(delta)
 )
func run():
 var elevated="--rampart-test" in OS.get_cmdline_user_args()
 var center=Vector3(0,18,138) if elevated else Vector3(0,0,52)
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 if elevated:doc.load_four_gates()
 else:doc.load_original()
 set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 var helpers=game.get_node_or_null("ExplorerHelpers")
 check(helpers!=null,"Forest has shared helper skills")
 if helpers==null:await finish();return
 game.player.select_character(11)
 check(helpers.pool.size()==5 and helpers.pool.all(func(u):return u.character_models.size()==1 and u.character_abilities.size()==1),"Five pooled helpers load only their own kits")
 check(GuardFixture.deploy(helpers,0),"Preparation can summon an ally");helpers.clear()
 game.start_wave();game.model.waves.spawn_clock=100000;game.model.waves.pending=999;game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 for u in game.gate_defenders.units.values():u.set_physics_process(false)
 game.player.position=center+Vector3(0,.15,8);game.model.update_vision(game.player.position)
 check(GuardFixture.deploy(helpers,0),"A Dragoon can be summoned before enemies appear")
 helpers.clear()
 var far=game.model.waves.spawn_enemy(0,center+Vector3(0,0,-10));far.hp=1000000000;far.max_hp=1000000000
 var near=game.model.waves.spawn_enemy(0,center);near.hp=1000000000;near.max_hp=1000000000
 game.sync_enemies();await frames()
 for e in game.actors.values():e.set_physics_process(false);e.boss=true
 game.model.update_vision(game.player.position)
 check(helpers.closest_target(game.player.position)==game.actors[near.id],"Helpers pick the closest live visible enemy, excluding the dummy")
 game.player.active_ability.action("cutlass");var own_attack=game.player.active_ability.player.attack
 check(GuardFixture.deploy(helpers,0),"Explorer can call Dragoon")
 check(own_attack!=null and game.player.active_ability.player.attack==own_attack,"Summoning does not interrupt Explorer's own swing")
 check(helpers.active_units(0).size()==1,"One Dragoon appears")
 check(helpers.smoke.items.size()==6,"Helpers appear in a bounded smoke burst")
 check(GuardFixture.deploy(helpers,0) and helpers.active_units(0).size()==2,"A fresh press adds another Dragoon without replacing the first")
 check(GuardFixture.deploy(helpers,1) and helpers.active_units(1).size()==1,"Slot 2 summons one Ranger")
 check(GuardFixture.deploy(helpers,2) and helpers.active_units(2).size()==1,"Slot 3 summons one Ninja")
 check(game.player.character_id==11 and game.selected_rogue_id==11,"Summons preserve the human fighter")
 var original_rangers=helpers.active_units(1).duplicate();var dragoon_before=helpers.active_units(0)[0]
 await step(45)
 var old_arrows=[]
 for u in original_rangers:
  for projectile in u.active_ability.projectiles:old_arrows.append(projectile.mesh)
 var dragoon_age=dragoon_before.age
 check(not old_arrows.is_empty(),"Rangers have released arrows before adding another group")
 var old_puffs=helpers.smoke.items.map(func(p):return p.node)
 check(GuardFixture.deploy(helpers,1),"A fresh press adds another Ranger group")
 check(helpers.active_units(1).size()==2 and original_rangers.all(func(u):return u.age>0 and u.state=="acting"),"Adding Rangers preserves the original fighter")
 check(old_arrows.all(func(a):return is_instance_valid(a) and not a.is_queued_for_deletion()),"New summons preserve the first group's released arrows")
 check(dragoon_before.age==dragoon_age,"Adding Rangers does not interrupt Dragoon")
 check(helpers.smoke.items.filter(func(p):return not old_puffs.has(p.node)).size()>=6,"An additional Ranger arrive in smoke")
 helpers.clear()
 check(helpers.active_units().is_empty(),"Clearing retires all helper groups")
 # Real native damage and retirement, with each slot isolated.
 var before=near.hp;check(GuardFixture.deploy(helpers,0),"Dragoon can be reused after a reset")
 var dragoon=helpers.active_units(0)[0]
 await step(12)
 check(dragoon.active_ability.player.travel!=null and dragoon.active_ability.player.travel.kind=="lance-leap","Dragoon uses its real airborne jump thrust")
 check(dragoon.active_ability.player.travel!=null and dragoon.active_ability.player.travel.target.distance_to(center)<1.0,"AI Dragoon lands on its target rather than the human crosshair")
 await step(100)
 check(near.hp<before and dragoon.active_ability.player.travel==null,"Dragoon lands and deals native area damage")
 check(helpers.active_units(0).size()==1,"Dragoon stays after its landing pulses")
 helpers.clear();before=near.hp
 check(GuardFixture.deploy(helpers,2),"Ninja group can be summoned")
 var ninjas=helpers.active_units(2).duplicate()
 await step(20)
 check(ninjas.all(func(u):return u.cast_started),"All five Ninjas start one native right-click")
 await step(65)
 check(near.hp<before and helpers.active_units(2).size()==1,"Ninja slashes damage the target and all five stay")
 check(ninjas.all(func(u):return u.active_ability.player.dashAttack==null),"Ninja finishing hits have all retired")
 helpers.clear();before=near.hp
 check(GuardFixture.deploy(helpers,1),"Ranger group can be summoned")
 var rangers=helpers.active_units(1).duplicate()
 await step(120)
 check(near.hp<before and rangers.all(func(u):return u.visible and u.state=="acting"),"Three Rangers shoot actual arrows and remain for five seconds")
 var shots=rangers[0].active_ability.player.rangerShots
 near.hp=0;game.actors[near.id].hp=0;game.actors[near.id].dead=true
 await step(30)
 check(rangers.all(func(u):return u.ai_target==game.actors[far.id]),"Rangers retarget the next closest living enemy")
 game.show_pause();var age=rangers[0].age;await frames()
 check(rangers[0].age==age,"Pause freezes summon duration")
 game.resume();game.set_physics_process(false)
 await step(170)
 check(helpers.active_units(1).size()==1 and rangers.all(func(u):return u.visible),"Rangers keep firing beyond the former five-second window")
 check(shots>3,"Each Ranger fires repeated rapid shots")
 check(game.player.attack_chain.count==0,"Helpers never seed the human player's attack chain")
 helpers.clear()
 var event=InputEventKey.new();event.physical_keycode=KEY_3;event.pressed=true
 root.push_input(event,true);await frames(1)
 event.pressed=false;root.push_input(event,true)
 check(helpers.active_units(2).is_empty(),"Explorer key 3 cannot summon an unpaid Ninja")
 check(GuardFixture.deploy(helpers,2),"Combat fixture creates an individual Ninja")
 var ninja_age=helpers.active_units(2)[0].age;event.pressed=true;event.echo=true;root.push_input(event,true)
 check(helpers.active_units(2).size()==1 and helpers.active_units(2)[0].age==ninja_age,"Holding a number key does not repeatedly replace its helpers")
 check(game.player.active_ability.player.roll<=0 and game.player.active_ability.player.dashAttack==null,"Helper key 3 does not also dash the human Explorer")
 game.forest_ui.sync()
 check(not game.forest_ui.helper_portraits[2].visible,"Unused Explorer slots have no ally portrait")
 game.show_pause()
 check(not helpers.request(0),"Pause blocks helper replacement")
 game.resume();game.set_physics_process(false)
 var live_helpers=helpers.active_units().duplicate();var smoke_count=helpers.smoke.items.size()
 game.player.select_character(5);helpers._process(0)
 check(not live_helpers.is_empty() and helpers.active_units()==live_helpers,"Switching fighter preserves the shared active helpers")
 check(GuardFixture.deploy(helpers,0),"Another character can cast the same shared helpers")
 check(smoke_count>0 and helpers.smoke.items.size()>=smoke_count,"Switching fighter preserves helper smoke")
 helpers.clear();helpers.smoke_at(game.player.position);game.player.hp=0;helpers._process(0)
 check(helpers.smoke.items.is_empty(),"Player death clears leftover smoke even after every unit has parked")
 game.player.hp=game.player.max_hp
 game.player.select_character(11);helpers.clear();GuardFixture.deploy(helpers,1);await step(10)
 game.player.hp=0;helpers._process(0)
 check(helpers.pool.all(func(u):return u.state=="idle" and u.active_ability.projectiles.is_empty()),"Player death clears helpers and released damage")
 game.player.hp=game.player.max_hp;helpers.clear();GuardFixture.deploy(helpers,1);await step(10)
 game.model.phase="preparing";game.set_phase_view()
 check(helpers.active_units(1).size()==1,"Preparation preserves surviving allies")
 await finish()
func finish():
 game.sound_library.cancel();game.music.stop()
 # Fixed-fps simulation can outrun the audio thread; stop voices before teardown.
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120)
 game.queue_free();paused=false;await frames();await create_timer(.2).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("EXPLORER_HELPERS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
