extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://gate-defenders-test-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func frames(n:int=3):
 for i in n:await process_frame
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await frames()
 var defenders=game.get("gate_defenders")
 check(is_instance_valid(defenders),"Forest creates the gate defender roster")
 if not is_instance_valid(defenders):
  game.queue_free();paused=false;await frames();await create_timer(.15).timeout;print("GATE_DEFENDERS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1);return
 game.set_physics_process(false);game.player.set_physics_process(false)
 defenders.settings_path=config_path+"-defenders";defenders.assignments.clear();defenders.reconcile(true)
 check(defenders.units.size()==4,"Exactly one defender belongs to each of four gates")
 var gate_ids=defenders.units.keys()
 var a=defenders.units[gate_ids[0]];var b=defenders.units[gate_ids[1]]
 defenders.assign(gate_ids[0],5);defenders.assign(gate_ids[1],5)
 a=defenders.units[gate_ids[0]];b=defenders.units[gate_ids[1]]
 check(a.character_id==5 and b.character_id==5 and a!=b,"Duplicate Ninjas can defend separate gates")
 check(a.active_ability.player!=b.active_ability.player and a.attack_chain!=b.attack_chain,"Duplicate defenders own separate combat state")
 game.player.select_character(2)
 var pool=a.active_ability.sound.shared;pool.last_events.erase("hit");var cursor=pool.cursor
 a.active_ability.sound.play("hit")
 check(pool.cursor!=cursor,"Ally audio works while human plays Edo")
 game.player.select_character(1)
 var chosen=game.selected_rogue_id
 check(game.player.character_id==chosen,"Assigning defenders preserves the selected player")
 game.show_gate_defenders();await frames()
 check(game.ordinary_pause and game.forest_ui.find_child("GateDefenderPanel",true,false)!=null,"Building button opens a paused defender selection panel")
 var toggle=InputEventAction.new();toggle.action="character_toggle";toggle.pressed=true;game._input(toggle)
 check(not game.rogue_roster_open,"Character hotkey cannot open a second menu over defender assignments")
 var escape=InputEventAction.new();escape.action="pause";escape.pressed=true;game._input(escape);await frames()
 check(game.forest_ui.get_node_or_null("GateDefenderPanel")==null,"Escape closes the defender panel")
 check(not game.ordinary_pause and game.model.phase=="preparing","Closing assignments returns to building view")
 game.model.phase="wave";game.set_phase_view();await frames()
 for unit in defenders.units.values():unit.set_physics_process(false)
 a=defenders.units[gate_ids[0]]
 var hero_position=game.player.position
 var p=a.post+Vector3(0,0,2)
 var e=game.model.waves.spawn_enemy(0,p);game.sync_enemies();await frames()
 defenders.think(a)
 check(a.ai_target==game.actors[e.id],"Defender acquires a nearby foe")
 var start_hp=game.player.hp;var start_links=game.player.attack_chain.count
 var ticket=a.attack_chain.begin("test")
 game.actors[e.id].take_hit(1,Vector3.FORWARD,false,ticket)
 check(game.player.attack_chain.count==start_links and a.attack_chain.count==1,"Ally hit credit belongs to its own combo")
 check(e.get("retaliation_defender",-1)==a.gate_id,"A struck enemy retaliates against its actual defender")
 a.take_hit(10000,Vector3.FORWARD)
 check(a.hp<=0 and game.model.phase=="wave" and game.player.hp==start_hp,"Downed ally does not defeat or hurt the player")
 defenders.tick(15.1)
 check(a.hp==a.max_hp and a.visible,"Downed ally recovers at its post")
 check(game.player.position==hero_position,"AI movement and recovery preserve the human player position")
 defenders.save_assignments();defenders.assignments.clear();defenders.load_assignments()
 check(defenders.assignments.get(defenders.gate_key(game.model.buildings[a.gate_id]),0)==5,"Gate assignments persist by gate location")
 # A duplicated Edo owns its casts and cannot cancel another defender's shots.
 game.model.phase="preparing";defenders.assign(gate_ids[0],2);defenders.assign(gate_ids[1],2);await frames()
 a=defenders.units[gate_ids[0]];b=defenders.units[gate_ids[1]]
 a.set_physics_process(false);b.set_physics_process(false)
 a.ai_aim=a.post+Vector3(0,1,10);b.ai_aim=b.post+Vector3(0,1,10)
 a.musashi.cast_fireball();a.musashi.launch();b.musashi.cast_fireball();b.musashi.launch()
 var b_shots=get_nodes_in_group("musashi_projectiles").filter(func(ball):return ball.attack_ticket.source_hero.get_ref()==b)
 a.musashi.cancel();await frames()
 check(b_shots.size()==3 and b_shots.all(func(ball):return is_instance_valid(ball) and not ball.is_queued_for_deletion()),"Duplicate Edo cancellation preserves the other defender's fireballs")
 for ball in get_nodes_in_group("musashi_projectiles"):ball.queue_free()
 # Every playable kit must land real damage using AI aim and its native attack.
 game.set_process(false)
 for unit in defenders.units.values():unit.set_physics_process(false)
 for id in range(1,13):
  if id==4:continue # Samurai is retired from gate assignments.
  game.model.phase="preparing";defenders.assign(gate_ids[0],id);await frames()
  a=defenders.units[gate_ids[0]];a.set_physics_process(false)
  check(is_equal_approx(a.max_hp,game.balance_value(id,"max_hp")),"Character %d keeps its own base health profile"%id)
  var own_speed=a.combat_tuning("walk_speed")
  game.player.select_character(10 if id!=10 else 7)
  check(is_equal_approx(own_speed,a.combat_tuning("walk_speed")),"Character %d tuning ignores human character changes"%id)
  game.player.select_character(chosen)
  a.post=Vector3(0,0,24);a.restore_at_post()
  game.model.phase="wave";game.paused=false;paused=false
  for old in game.actors.values():
   if is_instance_valid(old):old.queue_free()
  game.actors.clear();game.enemies.clear();game.model.enemies.clear()
  var foe=game.model.waves.spawn_enemy(0,Vector3(0,0,28));game.sync_enemies();await frames()
  var target=game.actors[foe.id];target.set_physics_process(false);target._physics_process(0)
  defenders.sync_model();game.model.update_vision(game.player.position)
  game.chain=0;game.player.impact_pause=0;game.camera_rig.impulse=0
  for step in range(240):
   if step%12==0:defenders.think(a)
   a._physics_process(1.0/60)
   target._physics_process(1.0/60)
   await physics_frame
   if foe.hp<foe.max_hp:break
  print("AI_KIT id=%d enemy_hp=%.1f pos=%s target=%s attack=%s"%[id,foe.hp,a.position,str(a.ai_target!=null),str(a.attack_left)])
  check(foe.hp<foe.max_hp,"Character %d lands its native attack with AI control"%id)
  check(game.chain==0 and game.player.impact_pause==0 and game.camera_rig.impulse==0,"Character %d preserves human combo, hit stop and camera"%id)
  game.paused=true;paused=true
 game.model.phase="preparing";game.paused=true;paused=true
 game.open_map_editor();await frames()
 var kept=defenders.units.values().duplicate()
 game.map_editor.load_original();await frames()
 check(defenders.units.values()==kept and kept.all(func(u):return not u.visible),"Editing map previews hides and preserves the current squad")
 game.map_editor.close_discard();await frames()
 check(defenders.units.size()==4 and defenders.units.values().all(func(u):return u.visible),"Leaving the map editor restores gate defenders")
 # Gate destruction must not change any surviving unconfigured character.
 game.model.phase="wave";defenders.assignments.clear()
 for gate in defenders.gates():defenders.assignments[defenders.gate_key(gate)]=defenders.units[gate.id].character_id
 var original={}
 for gate in defenders.gates():original[gate.id]=defenders.units[gate.id]
 var removed=int(original.keys()[0]);game.model.buildings.erase(removed);defenders.clock=0;defenders.tick(.2)
 check(not defenders.units.has(removed) and defenders.units.size()==3,"Destroyed gate retires its defender during the wave")
 check(defenders.units.keys().all(func(g):return defenders.units[g]==original[g]),"Removing one gate preserves other defenders and their health")
 game.sound_library.cancel();game.music.stop()
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120);game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path));DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path+"-defenders"))
 print("GATE_DEFENDERS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
