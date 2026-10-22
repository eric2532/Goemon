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
    var path=directory.path_join("gold-three-hit.png")
    check(root.get_texture().get_image().save_png(path)==OK,"Capture preserves gold energy without red bonus slashes")
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
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
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
 check(contacts==[1,2,3] and p.attack_left<=0,"Jump preserves all three contacts of the triplet")
 fresh();tap("light_attack");await step(1);p.dodge_cooldown=0;tap("dodge");await step(100)
 check(contacts.is_empty() and p.attack_left<=0,"Dodge cancels the triplet before contact")
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
 print("GOEMON_THREE_HIT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
