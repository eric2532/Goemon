extends SceneTree
const GuardFixture=preload("res://tests/forest-shrine/guard_combat_fixture.gd")
## Protect persistence, additive summoning, actual combat ownership and mortal allies.
var game
var checks=0
var failures=0
var physics_driver
var cfg="user://persistent-allies-%d.cfg"%OS.get_process_id()
func _initialize():
 set_meta("forest_army_backend","legacy")
 Engine.physics_ticks_per_second=600;Engine.time_scale=10
 create_timer(120).timeout.connect(func():printerr("FAIL: persistent allies timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func frames(n=3):
 for i in n:await process_frame
func freeze():
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 for unit in game.gate_defenders.units.values():unit.set_physics_process(false)
 for unit in game.explorer_helpers.pool:unit.set_physics_process(false)
 for enemy in game.actors.values():enemy.set_physics_process(false)
func step(n:int):
 if physics_driver==null:
  physics_driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(physics_driver)
 await physics_driver.advance(n,func(delta):
  for unit in game.explorer_helpers.pool:
   unit.set_physics_process(false)
   if unit.state!="idle":unit._physics_process(delta);unit.active_ability.fx.tick(delta)
  game.explorer_helpers.sync_targets();game.explorer_helpers._process(delta)
  game.model.update_vision(game.player.position)
 )
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 var h=game.explorer_helpers
 game.player.select_character(11)
 check(GuardFixture.deploy(h,0) and h.active_units(0).size()==1,"Preparation can summon a waiting Dragoon");h.clear()
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000;freeze()
 game.player.select_character(11);game.player.position=Vector3(0,.15,60);game.model.update_vision(game.player.position)
 var foe=game.model.waves.spawn_enemy(0,Vector3(0,0,52));foe.hp=1000000000;foe.max_hp=1000000000
 game.sync_enemies();await frames();freeze()
 for enemy in game.actors.values():enemy._sync_fitted_pose()
 # Ninja's native Shadow Art can execute normal foes regardless of HP. This
 # enduring fixture uses boss resistance while retaining the small contact hull.
 game.actors[foe.id].boss=true
 for slot in 5:
  h.clear();check(GuardFixture.deploy(h,slot),"Kit %d deploys an individual combat fixture"%(slot+1));freeze()
  var first=h.active_units(slot).duplicate();var want=1;var health=[200,100,100,500,200][slot]
  check(first.size()==want,"Kit %d has the requested number of allies"%(slot+1))
  check(first.all(func(u):return u.hp==health and u.max_hp==health),"Kit %d starts each ally with the requested HP"%(slot+1))
  check(GuardFixture.deploy(h,slot),"Kit %d supports a second independent deployment"%(slot+1));freeze()
  var all=h.active_units(slot)
  check(all.size()==want*2 and first.all(func(u):return all.has(u)),"Recasting kit %d adds an ally without replacing survivors"%(slot+1))
  var ids={}
  for unit in all:ids[unit.gate_id]=true
  check(all.size()==ids.size(),"Every ally has a unique enemy target identity")
  h.clear();GuardFixture.deploy(h,slot);freeze();var units=h.active_units(slot).duplicate();var before=foe.hp
  await step(100)
  check(foe.hp<before,"Kit %d deals real native damage"%(slot+1)) if slot!=3 else check(units[0].active_ability.player.buffTime>0,"Knight opens with native Knight's Code")
  if slot==0:check(units[0].active_ability.player.travel==null,"Dragoon completes his opening sky thrust")
  if slot==2:check(units.all(func(u):return u.active_ability.player.dashAttack==null),"Ninjas complete their opening piercing slashes")
  var after_opening=foe.hp
  await step(620)
  check(units.all(func(u):return u.visible and u.state=="acting"),"Kit %d survives beyond the former duration"%(slot+1))
  if slot!=3:check(foe.hp<after_opening,"Kit %d keeps fighting after its opening attack"%(slot+1))
  h.sync_targets()
  check(units.all(func(u):return game.model.waves.valid_target("defender",u.gate_id,game.player.position)),"Enemies can target every living kit %d ally"%(slot+1))
  if slot==4:
   var nearby=game.model.waves.spawn_enemy(0,units[0].global_position+Vector3(0,0,.2))
   game.model.waves.choose_target(nearby,game.player.position)
   check(nearby.target_kind=="defender" and nearby.target_id==units[0].gate_id,"A nearby enemy acquires a summon through normal proximity")
   var ally=units[0];ally.active_ability.cancel();ally.invuln=0
   var before_hit=ally.hp;var player_before_hit=game.player.hp
   game.model.events.clear();game.model.waves.start_attack(nearby,"defender",ally.gate_id,game.player.position)
   game.model.waves.attack_tick(nearby,1.0,game.player.position)
   check(game.model.events.any(func(event):return event.kind=="defender_hit" and event.id==ally.gate_id),"A completed enemy melee strike emits the summon damage event")
   game._physics_process(0);freeze()
   check(ally.hp<before_hit and game.player.hp==player_before_hit,"The real Forest event loop delivers enemy melee to the correct summon")
  var victim=units[0];victim.invuln=0;victim.active_ability.cancel();var old_hp=victim.hp;var hero_hp=game.player.hp
  victim.take_hit(10,Vector3.BACK,true)
  check(victim.hp==old_hp-10 and game.player.hp==hero_hp,"An enemy projectile damages the kit %d ally rather than the player"%(slot+1))
  check(victim.get_node_or_null("AllyHealthDisplay")!=null,"Living allies display their health")
  victim.invuln=0;victim.take_hit(10000,Vector3.BACK);h.sync_targets()
  check(not h.active_units(slot).has(victim) and not game.model.defenders.has(victim.gate_id),"Dead kit %d ally disappears and immediately releases its target"%(slot+1))
  check(units.slice(1).all(func(u):return u.state=="acting"),"One ally's death preserves its surviving group")
 h.clear();GuardFixture.deploy(h,3);await step(140);var guard=h.active_units(3)[0]
 foe.action="windup";foe.target_kind="defender";foe.target_id=guard.gate_id
 guard.think()
 check(guard.active_ability.player.blocking and guard.active_ability.secondary_held,"Knight interrupts a combo to guard an incoming enemy strike")
 foe.action="walk";guard.active_ability.cancel();guard.active_ability.player.cooldowns.drink=.1
 await step(90)
 check(guard.active_ability.player.buffTime>0,"Continuous melee leaves a boundary for Knight to reuse Code")
 h.clear();GuardFixture.deploy(h,4);await step(20);var survivors=h.active_units(4).duplicate()
 survivors[0].hp=123
 game.model.phase="preparing";game.set_phase_view();h._process(.1)
 check(h.active_units(4)==survivors and survivors[0].hp==123,"Survivors and remaining health persist between waves")
 game.model.phase="wave";game.set_phase_view();freeze();await step(20)
 check(h.active_units(4)==survivors,"The next wave resumes the same living allies")
 var held=InputEventKey.new();held.physical_keycode=KEY_5;held.pressed=true;held.echo=true
 root.push_input(held,true);check(h.active_units(4)==survivors,"Held-key echoes do not flood the battlefield")
 game.show_pause();check(not h.request(1),"Pause blocks new summons");game.resume();freeze()
 game.player.select_character(1);h._process(0)
 check(h.active_units(4)==survivors,"Changing the human character preserves allies")
 game.show_title();check(h.active_units().is_empty() and game.model.defenders.keys().all(func(id):return id>=0),"Title clears allies, attacks and enemy target registrations")
 await finish()
func finish():
 game.sound_library.cancel();game.music.stop()
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120);game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PERSISTENT_HELPERS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
