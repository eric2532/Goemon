extends SceneTree
const GuardFixture=preload("res://tests/forest-shrine/guard_combat_fixture.gd")
var game
var checks=0
var failures=0
var cfg="user://helper-extensions-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: helper extensions timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",label_)
 if not ok:failures+=1
func frames(n=3):
 for i in n:await process_frame
func step(n:int):
 for i in n:
  for u in game.explorer_helpers.pool:
   u.set_physics_process(false)
   if u.state!="idle":u._physics_process(1.0/60);u.active_ability.fx.tick(1.0/60)
  game.explorer_helpers._process(1.0/60)
  if i%30==0:await process_frame
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 var h=game.explorer_helpers
 check(h.pool.size()==5,"Five helper slots use a five-character starting pool")
 if h.pool.size()!=5:await finish();return
 game.player.select_character(11);game.start_wave();game.model.waves.spawn_clock=100000;game.model.waves.pending=999
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 for u in game.gate_defenders.units.values():u.set_physics_process(false)
 game.player.position=Vector3(0,.15,60);game.model.update_vision(game.player.position)
 check(GuardFixture.deploy(h,3),"Knight can be called before an enemy is visible")
 await step(12);var knight=h.active_units(3)[0]
 check(knight.character_id==7 and knight.active_ability.player.buffTime>7,"Knight casts native Knight's Code")
 check(game.model.waves.valid_target("defender",knight.gate_id,game.player.position),"The taunting Knight is an actual enemy target")
 var foes=[]
 for kind in 4:
  var e=game.model.waves.spawn_enemy(kind,Vector3(-24+kind*16,0,96));foes.append(e)
  game.model.waves.choose_target(e,game.player.position)
 check(foes.all(func(e):return e.target_kind=="defender" and e.target_id==knight.gate_id),"Taunt attracts every enemy role, including giants and archers outside sight")
 var more=game.model.waves.spawn_enemy(0,Vector3(0,0,180));game.model.waves.choose_target(more,game.player.position)
 check(more.target_id==knight.gate_id,"New arrivals are also taunted while Knight is present")
 foes[1].road_path=[Vector2i(-2,16),Vector2i(-2,0)]
 check(not game.model.waves.routes.following(foes[1],game.player.position),"A distant taunted enemy pursues Knight instead of continuing a shrine road")
 var hp=knight.hp;var hero_hp=game.player.hp;knight.take_hit(20,Vector3.BACK)
 check(knight.hp==hp-10 and game.player.hp==hero_hp,"Knight's Code halves damage to the helper without hurting Explorer")
 await step(6)
 check(knight.invuln>.29,"Knight retains native hit immunity instead of decrementing it twice")
 game.gate_defenders.sync_model();h.sync_targets()
 check(game.model.waves.valid_target("defender",knight.gate_id,game.player.position),"Gate defender synchronization preserves the helper taunt target")
 game.model.waves.start_attack(foes[0],"hero",0,game.player.position)
 check(GuardFixture.deploy(h,3) and h.active_units(3).size()==2 and knight.hp==hp-10,"Recasting Knight adds another fighter without healing the first")
 await step(12)
 check(foes[0].action=="walk" and foes[0].strike_kind=="","Taunt interrupts an unreleased attack aimed at Explorer")
 await step(12);knight.invuln=0;knight.take_hit(10000,Vector3.BACK)
 check(h.active_units(3).size()==1 and not game.model.defenders.has(knight.gate_id),"A defeated Knight disappears and releases the taunt")
 h.clear()
 for e in foes:game.model.waves.choose_target(e,game.player.position)
 check(foes.all(func(e):return e.target_id!=knight.gate_id or e.target_kind!="defender"),"Enemies return to normal targets after taunt ends")
 game.model.enemies.clear()
 var near=game.model.waves.spawn_enemy(0,Vector3(0,0,52));near.hp=100000;near.max_hp=100000
 game.sync_enemies();await frames()
 for enemy in game.actors.values():enemy.set_physics_process(false);enemy._sync_fitted_pose()
 game.model.update_vision(game.player.position)
 check(GuardFixture.deploy(h,4) and h.active_units(4).size()==1,"Fixture deploys one Explorer")
 var ally=h.active_units(4)[0];await step(120)
 check(near.hp<100000 and ally.state=="acting" and ally.character_id==11,"Explorer helper pursues and deals regular blade damage")
 check(ally.active_ability.player.dashAttack==null and ally.active_ability.player.cooldowns.flintlock==0,"Explorer helper uses regular attacks without casting Cross Dash")
 await step(270)
 check(ally.state=="acting" and ally.visible,"Explorer is still present before seven seconds")
 check(GuardFixture.deploy(h,4) and h.active_units(4).size()==2 and ally.age>6,"Deploying adds another Explorer and preserves survivors")
 await step(435)
 check(h.active_units(4).size()==2 and ally.visible,"Explorers remain after seven seconds")
 check(GuardFixture.deploy(h,3),"Knight can be reused immediately after finishing")
 await step(12);await step(500)
 check(h.active_units(3).size()==1,"Knight stays alive after his initial eight-second Code expires")
 var key=InputEventKey.new();key.physical_keycode=KEY_4;key.pressed=true
 root.push_input(key,true);await frames(1);key.pressed=false;root.push_input(key,true)
 check(h.active_units(3).size()==1,"Explorer key 4 cannot summon another Knight")
 key.physical_keycode=KEY_5;key.pressed=true;root.push_input(key,true);await frames(1);key.pressed=false;root.push_input(key,true)
 check(h.active_units(4).size()==2,"Explorer key 5 cannot summon attacking Explorers")
 game.forest_ui.sync()
 check(not game.forest_ui.helper_portraits[3].visible and not game.forest_ui.helper_portraits[4].visible,"Unassigned slots have no helper portraits")
 await step(12);h.clear()
 check(not game.model.defenders.has(knight.gate_id),"Full helper cleanup removes the taunt target")
 await finish()
func finish():
 game.sound_library.cancel();game.music.stop()
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120)
 game.queue_free();paused=false;await frames();await create_timer(.2).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("EXPLORER_HELPER_EXTENSIONS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
