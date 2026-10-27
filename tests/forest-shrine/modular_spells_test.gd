extends SceneTree
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
var game
var checks=0
var failures=0
var cfg="user://modular-spells-%d.cfg"%OS.get_process_id()
const ORIGIN=Vector3(0,.1,60)
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 print("PASS: " if ok else "FAIL: ",message)
 if not ok:failures+=1
func input(action:String,pressed:bool):
 var event=InputEventAction.new();event.action=action;event.pressed=pressed
 if pressed:game.player._unhandled_input(event)
 else:game.player._input(event)
func step(n:int):
 for i in n:game.player._physics_process(1.0/60)
func clear_instances():
 var loadout=game.player.spell_loadout
 loadout.cancel()
 for instance in loadout.instances.values():instance.free()
 loadout.instances.clear();game.player.attack_left=0;game.player.impact_pause=0;game.player.dodge_time=0;game.player.dodge_cooldown=0
 game.player.position=ORIGIN;game.player.velocity=Vector3.ZERO
func run():
 var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 await process_frame;await process_frame
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 var p=game.player;p.select_character(1);p.set_auto_attack(false);p.smoke_mode=true;p.smoke_move=Vector2.ZERO;p.position=ORIGIN
 game.tuning.critical_chance=0;game.character_tuning={}
 game.model.update_vision(ORIGIN)
 preload("res://tests/forest-shrine/training_dummy_fixture.gd").install(game)
 game.training_dummy.home=ORIGIN+Vector3(0,0,-2);game.training_dummy.position=game.training_dummy.home;game.training_dummy.set_physics_process(false)
 game.camera_rig.yaw=0;game.camera_rig.camera.position=ORIGIN+Vector3(0,2.4,10);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1,-20))
 check(Catalog.all().size()>=60,"Catalog covers every special ability family")
 check(Catalog.valid_loadouts({"bad":{"equip":"edo/meteors"},"1":{"equip":"missing","surge":4},"18":{"sky_strike":"edo/meteors"}})=={"18":{"sky_strike":"edo/meteors"}},"Saved assignments reject invalid fighters, slots and spells")
 var loadout=p.spell_loadout
 check(not loadout.equip(1,"light_attack","edo/meteors") and not loadout.equip(99,"equip","edo/meteors"),"Spell equipment cannot replace weapon controls or target an unknown fighter")
 for character in Catalog.Roster.PLAYABLE_IDS:
  for id in Catalog.all():
   check(loadout.equip(character,"equip",id),"%d accepts %s"%[character,id])
  loadout.equip(character,"equip","")
 game.settings.spell_loadouts={}
 # Exercise every implementation on a foreign body, including charge/release and movement.
 for id in Catalog.all():
  p.select_character(1 if int(Catalog.all()[id].source)!=1 else 16)
  clear_instances();p.weapon_slot=2
  check(loadout.equip(p.character_id,"equip",id),"Equip "+id)
  input("equip",true)
  check(loadout.instances.size()==1,"Cast creates one independent runtime for "+id)
  var instance=loadout.instances.values()[0]
  check(instance.hero==p and instance.source_id==Catalog.all()[id].source,"Foreign spell retains receiving caster and source mechanics: "+id)
  step(30)
  if id=="yae/shield":
   check(is_zero_approx(loadout.filter_damage(100,Vector3.BACK,true)) and is_equal_approx(loadout.filter_damage(100,Vector3.BACK,false),100),"Transferred Sword Shield preserves ranged-only protection")
  input("equip",false);step(35)
  if id in ["sasuke/bomb","sasuke/hail","yae/lock-on"]:
   var group="yae_projectiles" if id.begins_with("yae") else "sasuke_projectiles"
   var visible_shots=get_nodes_in_group(group).filter(func(shot):return shot.hero==p and is_instance_valid(shot.ornament))
   check(not visible_shots.is_empty(),"Transferred projectile keeps its original visible asset: "+id)
  check(p.weapon_slot==2,"Spell preserves normal weapon selection: "+id)
  clear_instances();game.settings.spell_loadouts={}
  await process_frame
 # Exercise the same magical, physical, charged and held spells on every receiving body.
 for character in Catalog.Roster.PLAYABLE_IDS:
  p.select_character(character)
  for id in ["edo/volley","ed/beam","sasuke/hail","yae/shield","ben/bombs","magic-swordsman/flintlock"]:
   clear_instances();game.settings.spell_loadouts={};loadout.retired_cooldowns.clear()
   loadout.equip(character,"equip",id);input("equip",true);step(35);input("equip",false);step(35)
   var key="%d:%s"%[character,id]
   check(loadout.instances.has(key) and loadout.instances[key].hero==p,"Cross-character cast: %s on %d"%[id,character])
   clear_instances();await process_frame
 p.select_character(1);game.settings.spell_loadouts={};loadout.retired_cooldowns.clear()
 var base_attack=p.attack_speed_multiplier();var base_damage=p.damage_multiplier();var base_reach=p.melee_reach_setting()
 for entry in [["samurai/drink","speed",5.0],["mage/drink","speed",2.5],["explorer/drink","damage",2.0],["master-thief/drink","reach",1.8]]:
  clear_instances();game.settings.spell_loadouts={};loadout.retired_cooldowns.clear()
  loadout.equip(1,"surge",entry[0]);input("surge",true);input("surge",false)
  var value=p.attack_speed_multiplier()/base_attack if entry[1]=="speed" else p.damage_multiplier()/base_damage if entry[1]=="damage" else p.melee_reach_setting()/base_reach
  check(is_equal_approx(value,entry[2]),"Transferred buff affects the wearer's "+entry[1]+": "+entry[0])
  var spell=loadout.instances.values()[0];spell.controller.player.buffTime=0
  check(is_equal_approx(p.attack_speed_multiplier(),base_attack) and is_equal_approx(p.damage_multiplier(),base_damage) and is_equal_approx(p.melee_reach_setting(),base_reach),"Expired buff restores the wearer's stats")
 clear_instances();game.settings.spell_loadouts={};loadout.retired_cooldowns.clear()
 loadout.equip(1,"surge","ninja/drink");input("surge",true);input("surge",false)
 var buffed_ticket=p.attack_chain.make_ticket("pipe")
 check(buffed_ticket.get("spell_anbu",false),"Anbu Dance follows the wearer's attack tickets")
 p.select_character(17)
 check(buffed_ticket.get("spell_anbu",false),"Released attacks keep their buff snapshot after a character switch")
 p.select_character(1);clear_instances();game.settings.spell_loadouts={};loadout.retired_cooldowns.clear()
 loadout.equip(1,"equip","knight/drink");input("equip",true);input("equip",false)
 check(is_equal_approx(loadout.filter_damage(100,Vector3.FORWARD,false),50),"Knight's Code gives a foreign wearer its 50% resilience")
 clear_instances();game.settings.spell_loadouts={};loadout.retired_cooldowns.clear()
 loadout.equip(1,"equip","ninja/roll");input("equip",true);input("equip",false)
 var cooldown=float(loadout.instances.values()[0].controller.player.cooldowns.roll)
 loadout.equip(1,"equip","edo/meteors");loadout.equip(1,"equip","ninja/roll");input("equip",true)
 check(loadout.instances.values()[0].controller.projectiles.is_empty() and is_equal_approx(loadout.instances.values()[0].controller.player.cooldowns.roll,cooldown),"Unequipping and re-equipping cannot reset a spell cooldown")
 clear_instances();game.settings.spell_loadouts={};loadout.retired_cooldowns.clear()
 loadout.equip(1,"equip","ben/flight");input("equip",true);input("equip",false)
 check(p.can_fly(),"Propeller Flight equips on a foreign fighter")
 input("equip",true);input("equip",false)
 check(not p.can_fly(),"Propeller Flight toggles off with the equipped key")
 clear_instances();game.settings.spell_loadouts={};loadout.retired_cooldowns.clear()
 # Pause preserves timed powers, while dodge retires only unfinished offense.
 loadout.equip(1,"surge","explorer/drink");input("surge",true);input("surge",false)
 var power=loadout.buff(11);p.cancel_charge(true)
 check(is_equal_approx(loadout.buff(11),power),"Opening a menu preserves a transferred timed buff")
 clear_instances();game.settings.spell_loadouts={};loadout.retired_cooldowns.clear()
 loadout.equip(1,"equip","magic-swordsman/flintlock");input("equip",true);input("equip",false);step(12)
 var wave=loadout.instances.values()[0]
 check(not wave.controller.projectiles.is_empty(),"Transferred Energy Wave releases its travelling blade")
 loadout.interrupt()
 check(not wave.controller.projectiles.is_empty(),"Dodging after release preserves the travelling spell")
 clear_instances();game.settings.spell_loadouts={};loadout.retired_cooldowns.clear()
 loadout.equip(1,"surge","knight/drink");loadout.equip(1,"equip","knight/flintlock")
 input("surge",true);input("surge",false);input("equip",true);step(1)
 check(is_zero_approx(loadout.filter_damage(100,Vector3.BACK,false)),"Transferred Navy Counter blocks a frontal hit")
 var riposte=p.attack_chain.make_ticket("pipe")
 check(riposte.get("spell_riposte",false) and is_equal_approx(loadout.damage_for_hit(game.training_dummy,100,riposte),180),"A foreign Knight's Code block empowers the next melee attack")
 input("equip",false)
 clear_instances();game.settings.spell_loadouts={};loadout.retired_cooldowns.clear()
 # The normal army proxy applies spell snapshots through native HP and hit ownership.
 var saved_runtime=game.army_runtime
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();game.add_child(runtime);runtime.configure(game)
 runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model));game.army_runtime=runtime
 var first_handle=runtime.spawn(900001,0,0,ORIGIN+Vector3.RIGHT*6,200,.4)
 var second_handle=runtime.spawn(900002,0,0,ORIGIN+Vector3.RIGHT*7,200,.4)
 var first=runtime.enemy_target(900001);var second=runtime.enemy_target(900002)
 game.enemies.append(first);game.enemies.append(second)
 game.model.visible_cells[game.model.cell_of(first.position)]=true;game.model.visible_cells[game.model.cell_of(second.position)]=true
 var fire_ticket=p.attack_chain.make_ticket("pipe");fire_ticket.spell_fire=true
 first.take_hit(40,Vector3.RIGHT,false,fire_ticket)
 check(is_equal_approx(runtime.unit_state(first_handle).hp,160),"Native army receives the transferred attack's original damage")
 check(is_equal_approx(runtime.unit_state(second_handle).hp,190),"Grand Smoke splash reaches a nearby native soldier exactly once")
 var strike_ticket=p.attack_chain.make_ticket("pipe");strike_ticket.spell_riposte=true
 first.take_hit(20,Vector3.RIGHT,false,strike_ticket)
 check(is_equal_approx(runtime.unit_state(first_handle).hp,124),"Transferred riposte damage reaches native HP without changing the army backend")
 game.enemies.erase(first);game.enemies.erase(second);runtime.clear();runtime.queue_free();game.army_runtime=saved_runtime
 await process_frame
 # Two different keys sharing one spell do not release another held source.
 p.select_character(1);clear_instances();loadout.retired_cooldowns.clear()
 loadout.equip(1,"equip","yae/shield");loadout.equip(1,"surge","yae/shield")
 input("equip",true);step(30);input("surge",true);input("equip",false)
 check(loadout.current!=null and loadout.current.held,"A shared held spell remains held by its second key")
 input("surge",false);step(60)
 check(loadout.current==null,"Last release finishes the transferred shield")
 clear_instances();game.settings.spell_loadouts={}
 loadout.equip(1,"equip","ninja/roll");input("equip",true);input("equip",false)
 var ninja=loadout.instances.values()[0]
 check(ninja.controller.projectiles.size()==5,"Transferred Wide Shuriken releases its complete five-shot fan")
 var remaining=float(ninja.controller.player.cooldowns.roll)
 input("equip",true);input("equip",false)
 check(ninja.controller.projectiles.size()==5 and is_equal_approx(remaining,ninja.controller.player.cooldowns.roll),"Repeated presses cannot bypass an equipped spell's cooldown")
 p.select_character(17)
 check(loadout.current==null and loadout.held_slots.is_empty(),"Switching characters clears held spell state")
 p.select_character(1)
 check(loadout.spell_for(1,"equip")=="ninja/roll","Switching retains per-fighter spell assignments")
 clear_instances();loadout.equip(1,"equip","")
 check(loadout.assignments(1).is_empty() and loadout.spell_for(1,"equip")=="goemon/dash","Reset restores the original character ability")
 var picker=load("res://scripts/spells/spell_picker.gd").new();picker.game=game;game.ui.add_child(picker)
 check(picker.choices.size()==5,"Fighter menu exposes all five numbered spell slots")
 check(picker.fighter.item_count==Catalog.Roster.selection_ids().size(),"Spell equipment follows the gallery's visible fighter roster")
 if "--visual" in OS.get_cmdline_user_args():
  loadout.equip(1,"equip","ninja/roll");loadout.equip(1,"surge","yae/shield");loadout.equip(1,"sky_strike","edo/meteors");picker.refresh()
  await process_frame;await process_frame;RenderingServer.force_draw()
  root.get_texture().get_image().save_png("res://build/Other Files/Spell Modularity/spell-picker.png")
 picker.queue_free()
 var renderer=root.get_meta(&"ed_native_beam_renderer",null)
 if is_instance_valid(renderer):renderer.queue_free();root.remove_meta(&"ed_native_beam_renderer")
 game.queue_free();paused=false;await process_frame;await process_frame
 Catalog.Roster._portraits.clear();Catalog.Roster._selection_portraits.clear()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MODULAR_SPELLS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
