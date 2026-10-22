extends SceneTree
var game
var checks=0
var failures=0
var contacts=[]
var contact_bonuses=[]
var captured=false
var cfg="user://goemon-three-hit-%d.cfg"%OS.get_process_id()
const ORIGIN=Vector3(0,.1,60)
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 print("PASS: " if ok else "FAIL: ",label_)
 if not ok:failures+=1
func frames(n:int=2):
 for i in n:await process_frame
func tap(action:String):
 var event=InputEventAction.new();event.action=action;event.pressed=true;game.player._unhandled_input(event)
 event.pressed=false;game.player._input(event)
func step(n:int):
 var p=game.player
 for i in n:
  p._physics_process(1.0/60)
  # Keep this isolated contact fixture planted; movement itself has its own suite.
  p.position=ORIGIN;p.velocity=Vector3.ZERO
  if "--visual" in OS.get_cmdline_user_args():
   await physics_frame
   if not captured and p.combo==2 and p.hit_done:
    p.rogue_pipe_combo._process(0)
    RenderingServer.force_draw()
    var directory=OS.get_environment("GOEMON_THREE_HIT_CAPTURE_DIR")
    if directory.is_empty():directory="/tmp"
    var path=directory.path_join("original-three-hit.png")
    check(root.get_texture().get_image().save_png(path)==OK,"Capture shows original three-hit pose and weapon")
    captured=true
  elif i%40==0:await process_frame
func fresh(surge:bool=false):
 var p=game.player;p.cancel_charge();p.quick_attacks.cancel();p.attack_left=0;p.impact_pause=0;p.attack_chain.reset();p.end_surge()
 p.position=ORIGIN;p.velocity=Vector3.ZERO;p.smoke_mode=true;p.smoke_move=Vector2.ZERO;p.facing=Vector3.FORWARD;p.invuln=0
 p.progression.reset(false);p.run_upgrades={"damage":0,"vitality":0,"tempo":0};p.clear_powerups()
 contacts.clear();contact_bonuses.clear()
 if surge:p.activate_surge()
func setup_fixture():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.sound_library.free();game.sound_library=SoundLibrary.new()
 game.sound_library.game=game;game.sound_library.folder="user://goemon-rom-test-%d/recordings"%OS.get_process_id();game.sound_library.config_path="user://goemon-rom-test-%d/audio.cfg"%OS.get_process_id();game.add_child(game.sound_library)
 var floor_=StaticBody3D.new();floor_.collision_layer=1
 var floor_shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(30,1,30);floor_shape.shape=box;floor_.add_child(floor_shape);game.add_child(floor_);floor_.position=Vector3(0,-.5,60)
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 await physics_frame;await physics_frame
 var p=game.player;p.select_character(1);p.set_auto_attack(false);game.tuning.critical_chance=0;game.character_tuning={}
 var dummy=game.training_dummy;dummy.home=ORIGIN+Vector3(0,0,-2);dummy.position=dummy.home;dummy.set_physics_process(false)
 game.model.update_vision(ORIGIN)
 game.camera_rig.yaw=0;game.camera_rig.camera.position=ORIGIN+Vector3(0,2.4,10);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1,-20))
 game.impact_confirmed.connect(func(victim,_strength,_duration):
  if victim==dummy:
   contacts.append(p.combo)
   contact_bonuses.append([p.attack_chain.count,p.attack_chain.multiplier(),p.attack_ticket.get("damage_multiplier",1.0)]))
func run():
 await setup_fixture()
 var p=game.player
 for surge in [false,true]:
  fresh(surge);tap("light_attack")
  check(is_equal_approx(p.attack_duration,RecoveredGoemonCombatProfile.duration(1)),"Primary uses native ROM timing")
  check(p.attack_left>0 and not p.hit_done,"Primary keeps its windup (surge=%s)"%surge)
  for i in 100:tap("light_attack")
  await step(200)
  check(contacts==[1,2,3],"One click gives exactly three ordered contacts without bonus hits (surge=%s, got=%s)"%[surge,str(contacts)])
  check(contact_bonuses.all(func(b):return b==[0,1.0,1.0]),"Every contact stays free of chain speed/damage bonuses (surge=%s)"%surge)
  check(p.quick_attacks.pending.is_empty() and p.attack_left<=0,"Busy clicks leave no delayed combo (surge=%s)"%surge)
  check(get_nodes_in_group("combo_bonus_attacks").is_empty(),"Goemon creates no red bonus attack (surge=%s)"%surge)
  check(p.attack_chain.count==0 and p.attack_chain.multiplier()==1.0 and p.attack_chain.damage_multiplier()==1.0,"Goemon does not gain hidden hit-chain speed or damage (surge=%s)"%surge)
  contacts.clear();tap("light_attack");await step(200)
  check(contacts==[1,2,3],"A later click starts another three-hit combo (surge=%s)"%surge)
 fresh();tap("light_attack");await step(1);tap("jump");await step(100)
 var jump_contacts=contacts.duplicate();jump_contacts.sort()
 check(p.combo==3 and p.attack_left<=0 and contacts==jump_contacts and contacts.all(func(stage):return stage in [1,2,3] and contacts.count(stage)==1),"Jump preserves all three stages without duplicate contacts; a pipe above the grounded target may miss")
 fresh();tap("light_attack");await step(1);p.dodge_cooldown=0;tap("dodge");await step(100)
 check(contacts.is_empty() and p.attack_left<=0,"Dodge cancels the triplet before contact")
 fresh();var expected_surge=p.combat_tuning("surge_duration")
 p.activate_surge()
 check(is_equal_approx(p.surge_left,expected_surge),"R applies the existing buff duration immediately")
 check(p.model.golden_requested and not p.model.hair_gold.visible,"R starts original transformation before golden frame 10")
 await step(60)
 check(p.model.hair_gold.visible and p.surge_left>0,"Original transformation reaches golden appearance while buff stays active")
 p.select_character(2)
 check(not p.character_models[1].golden_requested and p.character_models[1].transform_age<0,"Changing fighters clears Goemon transformation presentation")
 p.select_character(1);fresh()
 p.position=Vector3(0,-.01,60);p.velocity=Vector3.DOWN*5;p.move_and_slide()
 check(p.is_on_floor(),"Standing coin timing fixture is physically grounded")
 p.weapon_slot=2;p.set_weapon_visual(2);p.start_attack(false)
 check(is_equal_approx(p.attack_duration,RecoveredGoemonCombatProfile.action_duration(0x7c)),"Coin attack keeps original action duration")
 check(not p.attack_ticket.move_audio.voiced,"Coin preparation leaves the original voice queued until release")
 await step(20)
 check(p.attack_ticket.move_audio.voiced,"Coin release consumes its paired voice exactly once")
 p.attack_left=0;p.position=Vector3(0,-.01,60);p.velocity=Vector3.DOWN*5;p.move_and_slide()
 check(p.is_on_floor(),"Moving-throw fixture is physically grounded")
 p.velocity=Vector3(4,0,0);p.start_attack(false)
 p.model.animate(.01,4,true,0,1,false,1,false);p.model.sync_skeleton()
 check(p.model.locomotion.source_action==0x7C,"Moving grounded coin throw uses original standing action")
 p.attack_left=0;p.position=ORIGIN+Vector3.UP*8;p.velocity=Vector3.UP;p.move_and_slide();p.start_attack(false)
 p.model.animate(.01,0,false,1,1,false,1,false);p.model.sync_skeleton()
 check(p.model.locomotion.source_action==0x7D,"Airborne coin throw uses original aerial action")
 p.select_weapon(1);fresh()
 p.position=ORIGIN+Vector3.UP*8;p.velocity=Vector3.UP;p.move_and_slide();p.coyote=0;p.jumps_used=1
 tap("jump");p._physics_process(1.0/60)
 check(p.jumps_used==2 and p.air_turn>0,"A real second jump retains the existing turning timer")
 check(p.model.body.rotation.length()>.01 and p.model.locomotion.reference_jump_flip>=0,"Original aerial pose composes with the actual double-jump body turn")
 check(game.last_sound_voice.stream==game.sound_library.original_for(1,"jump"),"Actual double jump dispatches the recovered original jump sound")
 fresh()
 fresh();p.select_weapon(1)
 var before_coins=get_nodes_in_group("projectiles").size();tap("weapon_coin")
 check(p.weapon_slot==2 and not p.quick_attacks.coins_enabled,"Key 2 uses original coins without enabling automatic fire")
 check(get_nodes_in_group("projectiles").size()==before_coins and p.attack_left>0,"Key 2 begins the original windup before releasing its coin")
 check(p.quick_attacks.active,"A number-key coin is a temporary action rather than a weapon swap")
 await step(20)
 check(p.attack_ticket.move_audio.voiced,"Manual coin releases its original voice at the source cue")
 fresh(true);p.select_weapon(2)
 var held=InputEventAction.new();held.action="light_attack";held.pressed=true;p._unhandled_input(held)
 check(p.weapon_controls.charging and p.attack_left<=0,"Super Goemon begins holding a charged coin")
 await step(121)
 held.pressed=false;p._input(held)
 check(not p.weapon_controls.charging and p.attack_charged and p.original_coin_action in [0x7F,0x80,0x81],"Native full-charge release uses the source charged coin action")
 await step(35)
 fresh(true);p.select_weapon(2);held.pressed=true;p._unhandled_input(held);p.select_character(2)
 check(not p.weapon_controls.charging,"Switching fighters cancels an unfinished coin charge")
 held.pressed=false;p._input(held)
 p.select_character(1);p.select_weapon(1);fresh()
 # Stale state from another character cannot enable Goemon's retired bonuses.
 p.attack_chain.count=100;p.attack_chain.active_ticket={"combo":true}
 check(not p.attack_chain.unleashed() and not p.attack_chain.energized(),"Goemon cannot enter red-energy or instant-attack states")
 p.attack_chain.reset();var goemon_ticket=p.attack_chain.make_ticket("coin");p.select_character(2)
 p.attack_chain.confirm(goemon_ticket)
 check(p.attack_chain.count==0,"A Goemon coin fired before switching cannot seed another fighter's chain")
 for i in 3:p.attack_chain.confirm(p.attack_chain.begin("fireball"))
 check(p.attack_chain.count==3 and p.attack_chain.multiplier()>1.0,"Other characters retain their existing chain rules")
 var edo_ticket=p.attack_chain.make_ticket("fireball");var edo_damage=p.attack_chain.damage_for(edo_ticket)
 p.select_character(1);p.attack_chain.tick(.01)
 check(is_equal_approx(p.attack_chain.damage_for(edo_ticket),edo_damage),"Switching to Goemon preserves an already-fired Edo spell's damage snapshot")
 game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOEMON_ORIGINAL_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
