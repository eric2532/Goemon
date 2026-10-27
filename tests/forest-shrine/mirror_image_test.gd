extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Mirrors=preload("res://scripts/warcraft_mirrors.gd")
const OUT="res://build/Other Files/Asset Toolkit/Warcraft/Mirror Image/"
var costs=[]
func advance_army(count:int):
 for i in count:
  var start=Time.get_ticks_usec()
  game.army_runtime.step(1.0/60,{"targets":[]})
  costs.append((Time.get_ticks_usec()-start)/1000.0)
  await physics_frame
func run():
 create_timer(240).timeout.connect(func():printerr("MIRROR_IMAGE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 await setup_fixture();game.tuning.invincible=true
 var p=game.player;var army=game.army_runtime
 army.set_navigation(9933,{"width":0});army.record_events=false
 var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-4));row.hp=1000000;row.max_hp=1000000
 army.import_arrivals();army.sync_targets();var enemy=game.actors[row.id]
 army.apply_hit(enemy.handle,{"element":"ice","status_seconds":1000.0})
 for id in range(1,33):
  p.select_character(id);fresh();game.hit_stop=0
  game.update_character_tuning(id,"model_scale",1.7)
  var mirrors=Mirrors.new(p)
  check(mirrors.cast(),"Caster %d summons five native images"%id)
  check(mirrors.bodies.all(func(body):return body.character_id==id and body.model.get_script()==p.model.get_script() and body.model.scale==p.model.scale),"Caster %d preserves its model and scale"%id)
  check(mirrors.handles.all(func(h):return army.unit_state(h).kind==100+id),"Caster %d remains under native ownership"%id)
  check(mirrors.bodies.all(func(body):return body.actions.all(func(slot):return not (slot.size()==2 and body.spell_loadout.spell_for(id,slot[1])=="blademaster/mirror-image"))),"Caster %d cannot recursively summon"%id)
  await advance_army(80)
  var body=mirrors.bodies[0]
  for action in body.actions.size():
   body.interrupt_attack_for_movement();body.active_ability.clear_cooldowns() if body.active_ability!=null else p.clear_character_cooldowns()
   body.perform(action,enemy.global_position+Vector3.UP)
   await advance_army(36)
   check(body.global_position.is_finite(),"Caster %d action %d keeps a valid pose"%[id,action])
   if id==13 and action==6:check(not body.active_ability.assimilation.held,"Direct numbered attacks release their held input")
  check(p.impact_pause==0 and game.hit_stop==0,"Caster %d is not paused by image impacts"%id)
  check(not body.attack_chain.current.is_empty(),"Caster %d starts its original attacks"%id)
  mirrors.dispose();game.reset_character_tuning(id);await frames(2)
 # An equipped offensive spell is copied, while Mirror Image itself is excluded.
 p.select_character(1);fresh()
 p.spell_loadout.equip(1,"sky_strike","blademaster/mirror-image");p.spell_loadout.equip(1,"equip","blademaster/spin")
 var borrowed=p.spell_loadout.instances["1:blademaster/mirror-image"].controller.mirrors
 check(borrowed.cast(),"Borrowed summon uses the prepared shared skill")
 var copy=borrowed.bodies[0]
 check(not copy.spell_loadout.instances.has("1:blademaster/mirror-image"),"Copies never prepare a recursive summon controller")
 var spin_index=-1
 for i in copy.actions.size():
  if copy.actions[i][1]=="equip":spin_index=i
 check(spin_index>=0,"Equipped offensive skill participates in random choices")
 copy.perform(spin_index,enemy.global_position)
 check(copy.spell_loadout.current!=null and copy.spell_loadout.current.spec.id=="blademaster/spin","Goemon image casts its equipped Bladestorm while retaining Goemon's body")
 borrowed.clear()
 p.spell_loadout.equip(1,"equip","");p.spell_loadout.equip(1,"sky_strike","")
 # No target: images wait independently of the caster instead of marching away.
 army.despawn(enemy.handle);army.sync_compatibility()
 p.select_character(31);fresh();var mirrors=p.active_ability.mirrors
 check(mirrors.cast(),"Idle mirror cast succeeds")
 var start=mirrors.bodies.map(func(body):return body.global_position)
 p.global_position+=Vector3.RIGHT*50;p.facing=Vector3.BACK
 await advance_army(180)
 var stayed=true
 for i in 5:
  var offset=mirrors.bodies[i].global_position-start[i];offset.y=0
  stayed=stayed and offset.length()<.5
 check(stayed,"All five wait for enemies while the caster moves away")
 var separated=true
 for i in 5:
  for j in range(i+1,5):separated=separated and mirrors.bodies[i].global_position.distance_to(mirrors.bodies[j].global_position)>1.0
 check(separated,"Waiting images retain separate spawn positions")
 var leases=mirrors.handles.duplicate();await advance_army(721)
 check(mirrors.handles.is_empty() and leases.all(func(h):return not army.valid(h)),"Native clock expires every image after fifteen seconds")
 fresh();check(mirrors.cast(),"Worker-backed mirror cast succeeds")
 mirrors._action({"source_id":-int(p.get_instance_id())*8-1,"ticket_id":leases[0],"action_index":400,"position":ORIGIN})
 check(mirrors.bodies[0].action_history.is_empty(),"Retired generation cannot command a reused copy")
 army.integration_tick(1.0/60)
 var before_worker=mirrors.left
 check(army.begin_integration(1.0/60,true),"Normal native worker accepts the mirror step")
 army.finish_integration()
 check(is_equal_approx(before_worker-mirrors.left,1.0/60),"Worker completion advances copy lifetime exactly once")
 var fallen=mirrors.handles[0]
 army.apply_hit(fallen,{"amount":1000000.0,"direction":Vector3.ZERO})
 army.integration_tick(1.0/60)
 check(not army.valid(fallen) and not mirrors.bodies[0].leased,"Native death retires the pooled character body")
 mirrors.clear();costs.sort()
 var report={"checks":checks,"failures":failures,"army_and_copies_p95_ms":costs[int(costs.size()*.95)],"army_and_copies_max_ms":costs[-1]}
 FileAccess.open(OUT+"universal-headless.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MIRROR_IMAGE_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
