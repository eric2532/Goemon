extends "res://tests/forest-shrine/pet_defense_test.gd"
const COMBINED_OUT="res://build/Other Files/Asset Toolkit/Combined Formation/"
const CLOSE_POSTS=[Vector3(-2.4,0,1.2),Vector3(2.4,0,1.2),Vector3(0,0,-2.4),Vector3(-2.4,0,-1.2),Vector3(2.4,0,-1.2)]
const DT=1.0/60
var army
var pets:Array[int]=[]
var home=Vector3(-120,0,125)
var samples:Array[float]=[]
var motion_review="--motion-review" in OS.get_cmdline_user_args()
var driver
var combo_review_frame=0

func combo_frame():
 if not motion_review or DisplayServer.get_name()=="headless":return
 game.crowd.present_army(army.render_snapshot(),[]);game.forest_ui.sync()
 await frames(1);RenderingServer.force_draw()
 root.get_texture().get_image().save_png(COMBINED_OUT+"combo-attack-%03d.png"%combo_review_frame);combo_review_frame+=1

func tick(count:int=1):
 for i in count:
  var started=Time.get_ticks_usec()
  army.integration_tick(DT);army.flush_presentation()
  game.crowd.army.presentation.tick(DT)
  samples.append((Time.get_ticks_usec()-started)/1000.0)

func formation_matches()->bool:
 var forward:Vector3=game.player.facing
 var right=Vector3(-forward.z,0,forward.x)
 for i in pets.size():
  var row:Dictionary=army.unit_state(pets[i])
  if row.is_empty():continue
  var expected:Vector3=game.player.position+right*CLOSE_POSTS[i].x+forward*CLOSE_POSTS[i].z
  if Vector2(row.position.x-expected.x,row.position.z-expected.z).length()>.1:
   print("COMBINED_POST slot=",i," actual=",row.position," expected=",expected)
   return false
 return true

func shot(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.camera.global_position=game.player.position+Vector3(9,17,21)
 game.camera_rig.camera.look_at(game.player.position+Vector3.UP)
 game.crowd.present_army(army.render_snapshot(),[]);game.forest_ui.sync()
 await frames(3);RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(COMBINED_OUT+stem+".png")==OK,"Captured "+stem)

func mouse(pressed:bool):
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
 event.position=Vector2(root.size)*.5;event.pressed=pressed
 # Exercise combat input after focus; a background review window can consume its initial focus click.
 if pressed:game.player._unhandled_input(event)
 else:game.player._input(event)

func enemy_at(offset:Vector3):
 var point=home+offset;point.y=game.model.surface_height(point.x,point.z)
 var row:Dictionary=game.model.waves.spawn_enemy(Roles.SLIME,point)
 row.hp=10000000;row.max_hp=10000000
 army.import_arrivals();army.sync_targets()
 var handle:int=army.handles[row.id]
 army.apply_hit(handle,{"element":"stun","status_seconds":300.0,"provoke":false})
 var actor=army.enemy_target(row.id)
 actor.sync(army.unit_state(handle))
 return actor

func run():
 create_timer(300).timeout.connect(func():printerr("COMBINED_FORMATION_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(COMBINED_OUT);root.size=Vector2i(1280,800)
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 for node in [game,game.player,game.camera_rig,game.army_runtime]:node.set_process(false);node.set_physics_process(false)
 game.exploration_loot.set_process(false);game.model.waves.patrol_posts.clear()
 game.model.waves.crossgate_pet_test=true;game.model.team_progression.cards_enabled=false
 game.model.balance.enemy_profiles[str(Roles.SLIME)]={"dodge_chance":0.0}
 game.training_dummy.position=Vector3(0,-1000,0);game.training_dummy.home=game.training_dummy.position
 army=game.army_runtime;army.clear();game.model.enemies.clear();army.refresh_kits();army.record_events=true
 var p=game.player;p.select_character(p.RogueRoster.KAZI_ID);p.set_auto_attack(false)
 home.y=game.model.surface_height(home.x,home.z)+.05
 # The inherited fixture's physics floor is at its original origin, not this open formation review area.
 var floor_=StaticBody3D.new();floor_.collision_layer=1
 var floor_shape=CollisionShape3D.new();var floor_box=BoxShape3D.new();floor_box.size=Vector3(40,1,40)
 floor_shape.shape=floor_box;floor_.add_child(floor_shape);game.add_child(floor_);floor_.position=home-Vector3(0,.55,0)
 await physics_frame;await physics_frame
 p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.hp=100000;p.max_hp=100000
 p.dodge_time=0;p.impact_pause=0;game.model.update_vision(home)
 for i in 8:p.velocity=Vector3(0,-3,0);p.move_and_slide()
 p.velocity=Vector3.ZERO;home=p.position
 game.camera_rig.yaw=0;game.camera_rig.camera.top_level=true
 game.camera_rig.camera.global_position=home+Vector3(9,17,21);game.camera_rig.camera.look_at(home+Vector3.UP)
 var skins=[0,21,41,61,62]
 game.settings.forest_pet_loadout=Pets.sanitized(skins.map(func(s):return Pets.key(s)))
 game.settings.forest_pet_skills={Pets.key(skins[0]):[Pets.Spells.COMBO]}
 army.queue_hounds();tick(120)
 for skin in skins:
  var handle:int=army.handles.get(army.HOUND_ID-skin,0)
  check(handle!=0,"Selected pet %d is summoned"%skin)
  if handle==0:quit(1);return
  pets.append(handle)
 check(InputMap.action_get_events("surge").is_empty(),"R no longer triggers its former character ability")
 pet_key(KEY_R);pet_key(KEY_R,false);tick(2)
 check(army.hound_order==army.HoundOrder.COMBINED,"Physical R enables combined formation")
 var serial:int=army.hound_order_serial
 pet_key(KEY_R,true,true);pet_key(KEY_R,false)
 check(army.hound_order_serial==serial,"Held R does not repeatedly toggle")
 check(formation_matches(),"Two close pets on each side and one behind use saved slot order")
 await shot("close-five-pet-formation")
 for direction in [Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3.FORWARD]:
  p.facing=direction
  for i in 30:
   p.position+=direction*12*DT;p.velocity=direction*12;tick()
  check(formation_matches(),"Combined pets match sprint movement and turn: %s"%direction)
 for sprinting in [false,true]:
  p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.smoke_mode=false
  for i in 8:p.velocity=Vector3(0,-3,0);p.move_and_slide()
  p.velocity=Vector3.ZERO;tick(2)
  var movement=InputEventKey.new();movement.physical_keycode=KEY_W;movement.keycode=KEY_W;movement.pressed=true
  Input.parse_input_event(movement)
  var sprint_key=InputEventKey.new();sprint_key.physical_keycode=KEY_SHIFT;sprint_key.pressed=sprinting
  Input.parse_input_event(sprint_key)
  await frames(1)
  print("COMBINED_W_INPUT vector=",Input.get_vector("move_left","move_right","move_forward","move_back")," sprint=",Input.is_action_pressed("sprint"))
  var movement_state={"locked":true};var started_at:Vector3=p.position
  await driver.advance(30,func(dt):
   Input.action_press("move_forward")
   if sprinting:Input.action_press("sprint")
   p._physics_process(dt);tick()
   movement_state.locked=movement_state.locked and formation_matches())
  movement=movement.duplicate();movement.pressed=false;Input.parse_input_event(movement)
  sprint_key=sprint_key.duplicate();sprint_key.pressed=false;Input.parse_input_event(sprint_key)
  Input.action_release("move_forward");Input.action_release("sprint")
  var traveled=Vector2(p.position.x-started_at.x,p.position.z-started_at.z).length()
  print("COMBINED_W_RESULT distance=",traveled," locked=",movement_state.locked," grounded=",p.is_on_floor()," velocity=",p.velocity)
  check(traveled>1 and p.is_on_floor() and movement_state.locked,"Actual W%s movement keeps every pet attached without falling behind"%(" + Shift" if sprinting else ""))
  if not sprinting:await shot("combined-walking-in-sync")
 p.position=home;p.facing=Vector3.FORWARD;p.velocity=Vector3.ZERO;tick(2)
 game.camera_rig.camera.global_position=home+Vector3(9,17,21);game.camera_rig.camera.look_at(home+Vector3.UP)
 var enemy=enemy_at(Vector3(0,0,-4));var hp:float=enemy.hp;tick(60)
 check(enemy.hp==hp and pets.all(func(h):return army.unit_state(h).target_id==0),"Power formation waits for a normal attack instead of hunting or casting")
 game.update_character_tuning(p.character_id,"critical_chance",0)
 game.update_character_tuning(p.character_id,"accuracy",100)
 army.apply_hit(pets[2],{"element":"slow","slow_factor":1.0,"attack_slow_factor":.5,"status_seconds":8.0,"provoke":false})
 p.active_ability.primary_tab_target=weakref(enemy)
 p.attack_chain.reset();p.active_ability.reset_primary_combo()
 var first:int=army.event_log.size()
 mouse(true);mouse(false)
 check(army.combined_committed and p.active_ability.is_attacking(),"LMB starts the power combo")
 check(p.active_ability.elapsed==0 and pets.all(func(h):return army.unit_state(h).action==1 and army.unit_state(h).action_time==0),"Player and all five pets start together")
 var posts=pets.map(func(h):return army.unit_state(h).position)
 check(posts[0].x<enemy.position.x and posts[1].x>enemy.position.x and posts[3].x<enemy.position.x and posts[4].x>enemy.position.x and posts[2].z<enemy.position.z,"Two pets on each side and one behind surround the target")
 var order_serial:int=army.hound_order_serial
 pet_key(KEY_R);pet_key(KEY_R,false);pet_key(KEY_F);pet_key(KEY_F,false)
 check(army.hound_order_serial==order_serial,"Formation commands cannot interrupt windup")
 p._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 game.show_pause();game.show_settings(true);game.show_view_settings(true);game.show_pause();game.resume()
 check(p.active_ability.is_attacking() and army.combined_committed,"Focus changes and pause/settings/resume preserve windup")
 var observation={"impact":false,"waited":false,"frames":0,"windup_quiet":true,"slow_max":0.0}
 var origin:Vector3=p.position
 for i in 360:
  await driver.advance(1,func(dt):
   p._physics_process(dt);tick();observation.frames+=1
   observation.slow_max=maxf(observation.slow_max,army.unit_state(pets[2]).action_time)
   observation.waited=observation.waited or p.active_ability.mode=="combined_wait"
   if not army.combined_contacted and army.combined_committed:
    observation.windup_quiet=observation.windup_quiet and not army.event_log.slice(first).any(func(e):return e.kind=="damage" and e.source_id<0))
  if army.combined_contacted and not observation.impact:
   observation.impact=true
   var sources={}
   for event in army.event_log.slice(first):
    if event.kind=="damage" and event.target_id==enemy.forest_id:sources[event.source_id]=true
   check(sources.size()==6,"All six units land in the player's first impact step")
   check(p.active_ability.primary_combo_hits==6 and p.attack_chain.count==6,"Each connected unit adds one link to the existing combo systems")
   await shot("combo-six-links-at-impact")
  var done=not army.combined_committed
  if i%4==0 or done:await combo_frame()
  if done:break
 print("COMBINED_COMBO_IDLE ",observation)
 check(observation.impact and observation.windup_quiet,"Pets cannot hit before the shared impact or again during recovery")
 check(observation.waited and observation.slow_max>.9 and not army.combined_committed,"Standing still lets the deliberately slow pet finish its full original recovery")
 check(formation_matches() and p.position.distance_to(origin)<.1,"Idle completion returns the whole party together")
 # One slot buffers repeated clicks; the next strike uses the player's ready time.
 p.active_ability.primary_tab_target=weakref(enemy);p.attack_chain.reset();p.active_ability.reset_primary_combo()
 var queue_first:int=army.event_log.size()
 mouse(true);mouse(false)
 var first_ticket:Dictionary=p.active_ability.ticket
 for i in 12:mouse(true);mouse(false)
 check(p.active_ability.combined_queued and is_same(first_ticket,p.active_ability.ticket),"Rapid clicks fill one follow-up slot without restarting windup")
 var chained=false;var second_impact=false;var strokes=1;var current_ticket=first_ticket
 for i in 240:
  await driver.advance(1,func(dt):p._physics_process(dt);tick())
  if not is_same(current_ticket,p.active_ability.ticket):
   current_ticket=p.active_ability.ticket
   if p.active_ability.mode=="attack":strokes+=1
  if not chained and strokes==2:
   chained=true
   var begun=army.event_log.slice(queue_first).filter(func(e):return e.kind=="attack_started" and e.source_id<0)
   check(not p.active_ability.combined_queued and p.active_ability.elapsed==0 and begun.size()==10 and i+1<observation.frames,"The queued strike starts player and pets together before slow recovery completes")
  if chained and army.combined_contacted:
   second_impact=true
   check(p.active_ability.primary_combo_hits==12 and p.attack_chain.count==12,"Two six-unit strikes produce twelve connected combo links")
   await shot("combo-twelve-links")
   break
  if i%2==0:await combo_frame()
 check(chained and second_impact and strokes==2,"Click spam produces exactly one queued follow-up")
 var break_from:Vector3=p.position
 await driver.advance(12,func(dt):Input.action_press("move_forward");Input.action_press("sprint");p._physics_process(dt);tick())
 Input.action_release("move_forward");Input.action_release("sprint")
 await combo_frame()
 check(not army.combined_committed and not p.active_ability.combined_queued and p.position.distance_to(break_from)>.4 and formation_matches(),"Movement after impact cancels group recovery and immediately resumes attached movement")
 var after_break:float=enemy.hp;tick(90)
 check(enemy.hp==after_break,"Cancelled pet recovery cannot deliver delayed damage")
 # Held movement wins over a buffered attack as soon as impact is complete.
 p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.active_ability.primary_tab_target=weakref(enemy);tick(2)
 p.attack_chain.reset();p.active_ability.reset_primary_combo();mouse(true);mouse(false);mouse(true);mouse(false)
 first_ticket=p.active_ability.ticket;var windup_stationary=true;var released_at=0
 for i in 180:
  await driver.advance(1,func(dt):Input.action_press("move_forward");p._physics_process(dt);tick())
  if not army.combined_committed:released_at=i+1;break
  windup_stationary=windup_stationary and Vector2(p.position.x-home.x,p.position.z-home.z).length()<.01
 Input.action_release("move_forward")
 check(windup_stationary and released_at>0 and released_at<40 and not p.active_ability.combined_queued and is_same(first_ticket,p.active_ability.ticket),"Held movement commits through impact then clears the buffered strike")
 # Misses earn no links, including the five pet contacts.
 p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
 game.model.balance.enemy_profiles[str(Roles.SLIME)]={"dodge_chance":100.0};army.refresh_kits()
 game.update_character_tuning(p.character_id,"accuracy",0);p.attack_chain.reset();p.active_ability.reset_primary_combo()
 p.active_ability.start_selected_primary(Vector3.FORWARD,enemy)
 for i in 240:
  await driver.advance(1,func(dt):p._physics_process(dt);tick())
  if not army.combined_committed:break
 check(p.active_ability.primary_combo_hits==0 and p.attack_chain.count==0,"Whiffed player and pet hits cannot farm combo links")
 game.model.balance.enemy_profiles[str(Roles.SLIME)]={"dodge_chance":0.0};army.refresh_kits()
 game.update_character_tuning(p.character_id,"accuracy",100)
 var distant=enemy_at(Vector3(0,0,-18))
 p.position=home;p.facing=Vector3.FORWARD;p.active_ability.start_selected_primary(Vector3.FORWARD,enemy)
 p.active_ability.primary_tab_target=weakref(distant);mouse(true);mouse(false)
 for i in 180:
  await driver.advance(1,func(dt):p._physics_process(dt);tick())
  if not army.combined_committed:break
 check(not army.combined_committed and p.active_ability.mode=="primary_approach","Queuing a distant target resumes the existing approach before starting another group stroke")
 p.cancel_charge(true);army.despawn(distant.handle)
 p.position=home;p.facing=Vector3.FORWARD;p.active_ability.start_selected_primary(Vector3.FORWARD,enemy)
 mouse(true);mouse(false);var interrupted_hp:float=enemy.hp
 p.active_ability.hit()
 await driver.advance(1,func(dt):p._physics_process(dt);tick())
 check(not army.combined_committed and not p.active_ability.combined_queued and p.active_ability.mode=="hurt" and enemy.hp==interrupted_hp,"Interrupted windup clears the party and queued input without cancelling the player's hit reaction or inventing hits")
 p.cancel_charge(true)
 # Hold through three real group strokes, then release; all current Cross Gate normal weapons share the path.
 for character in p.RogueRoster.CROSSGATE:
  p.select_character(character);p.position=home;p.facing=Vector3.FORWARD;p.velocity=Vector3.ZERO
  p.impact_pause=0;p.attack_motion_pending=false;p.primary_down=false
  p.active_ability.primary_tab_target=weakref(enemy);tick(2)
  var hold_serial:int=p.crossgate_attack_serial
  mouse(true)
  check(army.combined_committed and pets.all(func(h):return army.unit_state(h).action_time==0),"Cross Gate fighter %d starts the group together"%character)
  for i in 360:
   await driver.advance(1,func(dt):p._physics_process(dt);tick())
   if p.crossgate_attack_serial>=hold_serial+3:break
  check(p.crossgate_attack_serial>=hold_serial+3 and army.combined_committed,"Holding LMB chains three synchronized strokes for fighter %d"%character)
  mouse(false);hold_serial=p.crossgate_attack_serial
  for i in 240:
   await driver.advance(1,func(dt):p._physics_process(dt);tick())
   if not army.combined_committed:break
  check(not army.combined_committed and formation_matches() and p.crossgate_attack_serial==hold_serial,"Releasing LMB stops fighter %d after its current group stroke"%character)
 for character in [p.RogueRoster.MAZE_ID,p.RogueRoster.SAIZO_ID]:
  p.select_character(character);p.model.set_maze_weapon(p.RogueRoster.MazeWeapon.KUNAI)
  p.position=home;p.facing=Vector3.FORWARD;p.velocity=Vector3.ZERO
  p.active_ability.primary_tab_target=weakref(enemy)
  var hold_serial:int=p.crossgate_attack_serial;mouse(true)
  check(army.combined_committed and p.active_ability.clip=="7","Fighter %d dagger normal attack also starts the group"%character)
  for i in 360:
   await driver.advance(1,func(dt):p._physics_process(dt);tick())
   if p.crossgate_attack_serial>=hold_serial+3:break
  check(p.crossgate_attack_serial>=hold_serial+3 and army.combined_committed,"Holding LMB chains the dagger group for fighter %d"%character)
  mouse(false);hold_serial=p.crossgate_attack_serial
  for i in 240:
   await driver.advance(1,func(dt):p._physics_process(dt);tick())
   if not army.combined_committed:break
  check(not army.combined_committed and formation_matches() and p.crossgate_attack_serial==hold_serial,"Releasing LMB stops the dagger group for fighter %d"%character)
 # A held button must not immediately restart the group after movement breaks recovery.
 p.select_character(p.RogueRoster.KAZI_ID);p.position=home;p.facing=Vector3.FORWARD;p.velocity=Vector3.ZERO
 p.active_ability.primary_tab_target=weakref(enemy);tick(2);mouse(true)
 for i in 180:
  await driver.advance(1,func(dt):p._physics_process(dt);tick())
  if army.combined_contacted:break
 var moving_serial:int=p.crossgate_attack_serial
 await driver.advance(30,func(dt):Input.action_press("move_forward");p._physics_process(dt);tick())
 Input.action_release("move_forward")
 check(not army.combined_committed and p.active_ability.primary_hold_target==null and p.crossgate_attack_serial==moving_serial,"Movement cancels held continuation without re-rooting the player")
 mouse(false)
 p.position=home;p.facing=Vector3.FORWARD;p.velocity=Vector3.ZERO;p.active_ability.primary_tab_target=weakref(enemy);tick(2);mouse(true)
 moving_serial=p.crossgate_attack_serial;p._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 for i in 240:
  await driver.advance(1,func(dt):p._physics_process(dt);tick())
  if not army.combined_committed:break
 check(not army.combined_committed and p.crossgate_attack_serial==moving_serial,"Focus loss clears held continuation while the current attack finishes")
 mouse(false)
 # Victory/preparation may be requested by the last hit; finish the animation before pausing.
 p.select_character(p.RogueRoster.KAZI_ID);p.position=home;p.facing=Vector3.FORWARD
 p.active_ability.start_selected_primary(Vector3.FORWARD,enemy)
 mouse(true);mouse(false)
 game.model.phase="victory";game.set_phase_view()
 check(game.combined_power_pending_phase() and not game.paused and not paused,"Victory waits for the committed party instead of cancelling its animation")
 for i in 240:
  await driver.advance(1,func(dt):p._physics_process(dt);game._physics_process(dt);army.flush_presentation())
  if not army.combined_committed:break
 check(not army.combined_committed and not p.active_ability.combined_queued,"Pending victory finishes recovery and clears an extra queued stroke")
 game.model.phase="wave"
 # A dead target cannot strand the completion barrier or create delayed damage.
 var doomed=enemy_at(Vector3(3,0,-4));p.active_ability.start_selected_primary(Vector3.FORWARD,doomed)
 army.apply_hit(doomed.handle,{"amount":20000000.0,"provoke":false})
 check(doomed.dead or doomed.hp<=0,"Death fixture actually kills its committed target")
 for i in 240:
  await driver.advance(1,func(dt):p._physics_process(dt);tick())
  if not army.combined_committed:break
 check(not army.combined_committed and formation_matches(),"An enemy dying mid-swing still lets the whole party finish and return")
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for cycle in 8:
  p.position=home;p.facing=Vector3.FORWARD;p.active_ability.start_selected_primary(Vector3.FORWARD,enemy)
  for i in 240:
   await driver.advance(1,func(dt):p._physics_process(dt);tick())
   if not army.combined_committed:break
  check(not army.combined_committed,"Repeated power attack %d releases its barrier"%cycle)
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=nodes+2 and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources+2,"Warmed power attacks retain no additional nodes or resources")
 for order in [army.HoundOrder.HOLD,army.HoundOrder.RETURN,army.HoundOrder.ATTACK]:
  army.order_hounds(order);tick(2)
  check(army.hound_order==order,"Existing explicit order %d releases combined mode"%order)
  pet_key(KEY_R,true,false,true);pet_key(KEY_R,false);tick(2)
  check(army.hound_order==army.HoundOrder.COMBINED,"R re-enters combined mode after explicit order")
 pet_key(KEY_R);pet_key(KEY_R,false);tick(2)
 check(army.hound_order==army.HoundOrder.DEFEND,"Second R restores independent defense")
 check(army.pet_skills.casters.values().all(func(c):return c.native_handle!=0),"Leaving combined mode restores the existing equipped skill adapters")
 game.model.phase="preparing";game.build_kind="tower";game.build_rotation=0
 var rotate=InputEventKey.new();rotate.physical_keycode=KEY_T;rotate.pressed=true
 game._unhandled_input(rotate)
 check(game.build_rotation==1,"T preserves preparation placement rotation after R is reassigned")
 rotate.physical_keycode=KEY_R;game._unhandled_input(rotate)
 check(game.build_rotation==1,"R no longer rotates a preparation placement")
 samples.sort();print("COMBINED_FORMATION_STEP_MS p95=",samples[int(samples.size()*.95)]," max=",samples[-1])
 game.queue_free();current_scene=null;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("COMBINED_FORMATION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
