extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Timed Dodge/Shadow Counter/"
const DT=1.0/60
var driver
var home=Vector3(-120,0,125)
var elapsed:Array[int]=[]
var hits=0
var shots:Array=[]

func click_attack():
 var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e,true)
 e.pressed=false;root.push_input(e,true)

func reward_case(id:int):
 var p=game.player;var kit=p.active_ability;var army=game.army_runtime
 var source:int=p.timed_dodge.counter_source
 var anchor:Vector3=p.timed_dodge.counter_origin
 var target=army.enemy_target(source)
 check(source>0 and is_instance_valid(target),"Successful Space banks its real attacker for %d"%id)
 var at:Vector3=home+Vector3.RIGHT*1.6;at.y=game.model.surface_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(0,at);row.hp=10000000;row.max_hp=row.hp
 army.import_arrivals();army.sync_targets()
 var other=army.enemy_target(row.id);var other_hp:float=other.hp
 var crowd=[]
 for i in 4:
  var point:Vector3=home+Vector3(2.0+i*.5,0,1.0);point.y=game.model.surface_height(point.x,point.z)
  var extra=game.model.waves.spawn_enemy(0,point);extra.hp=10000000;extra.max_hp=extra.hp;crowd.append(extra)
 army.import_arrivals();army.sync_targets()
 var key_=preload("res://scripts/character_balance.gd").key_for(id)
 game.character_tuning[key_].critical_chance=0.0;game.character_tuning[key_].counter_chance=0.0
 game.paused=true;click_attack();game.paused=false
 check(p.timed_dodge.counter_source==source and kit.shin_counter.is_empty(),"Paused clicks preserve the counter for %d"%id)
 tap("heavy_attack")
 check(p.timed_dodge.counter_source==source and kit.is_attacking(),"Right click preserves the counter for %d"%id)
 click_attack()
 check(p.timed_dodge.counter_source==source,"A rejected busy click preserves the counter for %d"%id)
 kit.cancel(true);kit.start_attack()
 check(p.timed_dodge.counter_source==source and kit.shin_counter.is_empty(),"Automatic attacks cannot spend the counter for %d"%id)
 kit.cancel(true);p.attack_chain.reset();p.impact_pause=0;p.velocity=Vector3.ZERO
 # Deliberately aim away and show a different warning in a crowd.
 p.facing=Vector3.BACK;p.timed_dodge.threat={"seconds":.1,"source_id":row.id,"origin":other.global_position}
 hits=0;shots.clear();var before:float=target.hp
 var rate:float=p.attack_speed_multiplier()
 var body_before:Vector3=p.global_position
 click_attack()
 check(p.timed_dodge.counter_source==0 and not kit.shin_counter.is_empty() and kit.shin_counter.source==source and kit.shin_counter.target==target,"Left click counters the dodged attacker, never the newer threat, for %d"%id)
 check(not kit.is_attacking() and kit.shin_counter.basic and kit.shin_counter.get("after_dodge",false),"The click uses the existing independent regular counter for %d"%id)
 check(kit.shin_counter.origin.is_equal_approx(anchor) and anchor.distance_to(body_before)>.1,"The earned shadow attacks from the pre-dodge anchor for %d"%id)
 var expected:float=preload("res://scripts/spells/skill_balance.gd").basic_damage(p.model.normal_attack_pattern())*p.damage_multiplier()
 kit.tick_shin_counter(DT)
 check(is_equal_approx(kit.shin_counter.elapsed,DT*rate),"The counter uses ordinary speed for %d"%id)
 for i in 240:
  kit.tick_shin_counter(DT)
  for shot in shots:
   if shot.pool_live:shot._physics_process(DT)
  if id==p.RogueRoster.KAZI_ID and i in [1,8,16]:await capture("counter-%02d"%i)
 check(is_equal_approx(before-float(target.hp),expected) and hits==1 and other.hp==other_hp,"One normal-damage counter reaches only its native attacker for %d: %.1f / %.1f, hits %d"%[id,before-float(target.hp),expected,hits])
 check(crowd.all(func(extra):return army.enemy_target(extra.id).hp==10000000) and kit.shin_counter.is_empty() and kit.shin_counter_pending.is_empty() and not p.model.stat_counter_shadow.visible,"The crowd cannot leave queued counters for %d"%id)
 check(p.global_position.is_equal_approx(body_before),"The counter leaves the real fighter at the dodge endpoint for %d"%id)
 click_attack()
 check(kit.is_attacking() and kit.shin_counter.is_empty() and not kit.ticket.has("dodge_attack_speed"),"The next click is an ordinary attack for %d"%id)
 kit.cancel(true)
 for shot in shots:
  if shot.pool_live:shot.retire()

func key(down:bool=true,echo_:bool=false):
 var e=InputEventKey.new();e.physical_keycode=KEY_SPACE;e.pressed=down;e.echo=echo_;root.push_input(e,true)

func finish_counter():
 for i in 240:
  game.player.active_ability.tick_shin_counter(DT)
  for shot in shots:
   if shot.pool_live:shot._physics_process(DT)

func dodge_edges():
 var p=game.player
 for rate in [20,30,60]:
  await settle(p.RogueRoster.KAZI_ID);spawn();check(await wait_warning(),"A native warning opens the %d Hz dodge fixture"%rate)
  var start:Vector3=p.position;key();key(false)
  var expected:Vector3=p.model.kagerou_step*p.model.KAGEROU_BACK_TICKS
  game.paused=true
  await driver.advance(1,func(_dt):advance(10,false))
  check(p.position.is_equal_approx(start) and p.timed_dodge.step_ticks==0,"Pause freezes the real outward step")
  game.paused=false
  await driver.advance(1,func(_dt):
   for i in rate:p._physics_process(1.0/rate))
  check(Vector3(p.position.x-start.x,0,p.position.z-start.z).distance_to(expected)<.1 and not p.timed_dodge.reacting,"The real dodge distance stays fixed at %d Hz"%rate)
 await settle(p.RogueRoster.KAZI_ID);spawn();check(await wait_warning(),"A native warning opens the wall fixture")
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(5,4,.25);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.global_position=home+Vector3(0,1,.85)
 await physics_frame;await physics_frame
 key();key(false)
 await driver.advance(1,func(_dt):advance(30,false))
 check(p.position.z>=home.z and p.position.z<home.z+.7 and not p.timed_dodge.reacting,"An outward dodge stops before the wall instead of passing through")
 var stopped:Vector3=p.position;p.timed_dodge.reset()
 check(p.position.is_equal_approx(stopped) and not p.model.stat_counter_shadow.visible,"Cancelling the bank clears its shadow without restoring the old body position")
 wall.queue_free();await physics_frame;await physics_frame
 await settle(p.RogueRoster.KAZI_ID);spawn();check(await wait_warning(),"A native warning opens the repeated shadow fixture")
 var nodes=0;var resources=0.0;var completed=0
 for i in 38:
  if i==8:
   nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  p.timed_dodge.reset();p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0
  p.timed_dodge.shadow_counter_enabled=true
  key();key(false)
  await driver.advance(1,func(_dt):advance(15,false))
  var endpoint:Vector3=p.position
  click_attack()
  if i>=8 and not p.active_ability.shin_counter.is_empty() and p.active_ability.shin_counter.origin.distance_to(home)<.1:completed+=1
  finish_counter()
  if i>=8:check(p.position.is_equal_approx(endpoint),"Repeated shadow counters leave the body at its endpoint")
 # Let the existing 25-link milestone burst finish before checking retention.
 await create_timer(.6).timeout;await frames(2)
 var node_delta=get_node_count()-nodes;var resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 check(completed==30 and node_delta<=0 and resource_delta<=0,"Thirty warmed real steps and anchored counters: completed %d, nodes %+d, resources %+.0f"%[completed,node_delta,resource_delta])

func counter_edges():
 await settle(game.player.RogueRoster.SHIN_ID)
 var p=game.player;var kit=p.active_ability;var army=game.army_runtime
 var gear=preload("res://scripts/forest/equipment.gd")
 check(game.save_equipment_loadouts({gear.character_key(p.character_id):{"1":"weapon:unarmed"}},game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Equip the shortest-range native fist")
 var at:Vector3=home+Vector3.FORWARD*5.2;at.y=game.model.surface_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(0,at);row.hp=10000000;row.max_hp=row.hp
 army.import_arrivals();army.sync_targets()
 var target=army.enemy_target(row.id);var hp_before:float=target.hp
 game.update_character_tuning(p.character_id,"counter_chance",100)
 game.update_character_tuning(p.character_id,"critical_chance",0)
 kit.counter_after_hit(Vector3.BACK,row.id,true);finish_counter()
 check(target.hp==hp_before,"The reach fixture lies outside an ordinary fist counter")
 p.timed_dodge.counter_source=row.id;p.facing=Vector3.BACK;click_attack()
 check(kit.shin_counter.target==target and is_equal_approx(kit.shin_counter.reach,kit.SHIN_PUNCH_REACH*1.5),"The earned counter aims behind the camera with 50% extra melee reach")
 finish_counter()
 check(target.hp<hp_before,"The earned fist counter actually reaches that native attacker")
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4,4,.3);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.global_position=home+Vector3(0,1,-1.6)
 await physics_frame;await physics_frame
 hp_before=target.hp;p.timed_dodge.counter_source=row.id;click_attack();finish_counter()
 check(target.hp==hp_before,"Extra counter reach cannot hit through a wall")
 wall.queue_free();await physics_frame;await physics_frame
 var far_at:Vector3=home+Vector3.FORWARD*12;far_at.y=game.model.surface_height(far_at.x,far_at.z)
 var far_row=game.model.waves.spawn_enemy(0,far_at);far_row.hp=10000000;far_row.max_hp=far_row.hp
 army.import_arrivals();army.sync_targets()
 var far_target=army.enemy_target(far_row.id);hp_before=far_target.hp
 p.timed_dodge.counter_source=far_row.id;click_attack();finish_counter()
 check(far_target.hp==hp_before,"The targeted fist counter keeps a bounded reach")
 var camera:Camera3D=game.camera_rig.camera
 var original_view=camera.global_transform
 camera.look_at(home+Vector3(10,2,0))
 await physics_frame
 p.timed_dodge.counter_source=2147483647;click_attack()
 check(kit.shin_counter.is_empty() and p.timed_dodge.counter_source==0 and not kit.is_attacking(),"An invalid original attacker clears its counter without starting an unselected attack")
 camera.global_transform=original_view
 kit.cancel(true)
 for i in 4:p.timed_dodge.counter_source=row.id;click_attack();finish_counter()
 await frames(2)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 30:p.timed_dodge.counter_source=row.id;click_attack();finish_counter()
 await frames(2)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Thirty earned counters reuse their existing prepared shadow and resources")

func advance(count:int,native:bool=true):
 for i in count:
  var started=Time.get_ticks_usec()
  game.player._physics_process(DT)
  if native:game.army_runtime.integration_tick(DT)
  game.crowd.army.presentation.tick(DT)
  elapsed.append(Time.get_ticks_usec()-started)

func settle(id:int):
 var p=game.player;var army=game.army_runtime
 army.clear();game.model.enemies.clear();army.refresh_kits()
 p.select_character(id);p.active_ability.cancel(true);p.active_ability.clear_shin_counter();p.active_ability.kagerou_enabled=false
 for stat in ["dodge_chance","counter_chance","critical_chance"]:game.update_character_tuning(id,stat,0)
 p.model.clear_kagerou_dodge();p.timed_dodge.reset();p.spell_loadout.interrupt();p.cancel_charge();p.attack_chain.reset()
 p.timed_dodge.shadow_counter_enabled=true
 p.attack_left=0;p.impact_pause=0;p.dodge_time=0;p.dodge_cooldown=0;p.invuln=0;p.defend_held=false
 p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.smoke_mode=true;p.smoke_move=Vector2.ZERO;p.hp=p.max_hp
 await driver.advance(1,func(_dt):advance(60,false))
 check(p.is_on_floor(),"Fighter %d is grounded"%id)
 hits=0

func spawn(kind:int=0):
 var p=game.player;var at=home+Vector3.FORWARD*2.5;at.y=game.model.surface_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(kind,at);row.hp=10000000;row.max_hp=row.hp
 game.army_runtime.import_arrivals();game.army_runtime.sync_targets()
 return row

func wait_warning(limit:float=.55)->bool:
 for i in 240:
  await driver.advance(1,func(_dt):advance(1))
  var t=float(game.army_runtime.native.hero_dodge_threat().seconds)
  if t>0 and t<=limit:return true
 return false

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation()
 game.forest_ui.sync();game.player.timed_dodge._process(0)
 await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(300).timeout.connect(func():printerr("TIMED_DODGE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.music.stop();game.settings.forest_pet_loadout=[];game.tuning.invincible=false;game.tuning.enemy_damage=1
 game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear()
 game.training_dummy.position=home+Vector3.DOWN*1000
 root.gui_release_focus()
 game.set_process_input(false);game.set_process_unhandled_input(false)
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.camera_rig.camera.global_position=home+Vector3(5,6,13);game.camera_rig.camera.look_at(home+Vector3(0,1.8,0))
 var p=game.player;var army=game.army_runtime
 army.record_events=true
 preload("res://scripts/character_projectile_pool.gd").service(game).launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(_target,_strength,_duration):hits+=1)
 var jump_key=InputEventKey.new();jump_key.physical_keycode=KEY_SPACE;jump_key.shift_pressed=true
 check(InputMap.event_is_action(jump_key,"jump",true) and not InputMap.event_is_action(jump_key,"timed_dodge",true),"Shift + Space jumps without triggering the plain Space dodge")
 for id in p.RogueRoster.CROSSGATE:
  await settle(id)
  key();key(true,true)
  await driver.advance(1,func(_dt):advance(20,false));key(false)
  check(p.jump_buffer==0 and p.jump_windup==0 and p.is_on_floor() and not p.flying,"Space and hold/echo cannot jump for %d"%id)
  check(p.invuln==0 and p.model.kagerou_tick<0,"An unprompted Space grants no protection for %d"%id)
  check(p.timed_dodge.counter_source==0,"An unprompted Space grants no counter reward for %d"%id)
  if id==p.RogueRoster.KAZI_ID:
   for seconds in [.55,.01,.5501,0.0,-1.0]:
    p.timed_dodge.threat={"seconds":seconds}
    check(p.timed_dodge.ready_to_dodge()==(seconds>0 and seconds<=.55),"Timing boundary %.4f"%seconds)
  p.timed_dodge.reset();p.timed_dodge.shadow_counter_enabled=true;spawn()
  check(await wait_warning(),"Native incoming strike opens the timing window for %d"%id)
  check(float(army.native.hero_dodge_threat().seconds)>.22,"The former early window now accepts Space for %d"%id)
  p.timed_dodge._process(0)
  check(p.timed_dodge.mark.is_visible_in_tree() and p.timed_dodge.get_child_count()==1,"Only the original ! icon appears for %d"%id)
  if id==p.RogueRoster.KAZI_ID:await capture("ready")
  var hp:float=p.hp;var position:Vector3=p.position
  tap("light_attack")
  key();key(false)
  check(p.timed_dodge.reacting and p.model.kagerou_tick==0 and p.invuln>0,"Correct Space starts the shared dodge for %d"%id)
  check(not p.active_ability.is_attacking(),"Successful dodge cancels the unfinished primary for %d"%id)
  check(p.timed_dodge.counter_source>0,"Successful dodge prepares exactly one counterattack for %d"%id)
  var travel:Vector3=p.model.kagerou_step*p.model.KAGEROU_BACK_TICKS
  var shadow_at:Vector3=p.model.stat_counter_shadow.global_position
  check(p.model.stat_counter_shadow.visible and p.timed_dodge.counter_origin.is_equal_approx(position),"Space leaves a prepared shadow at the starting point for %d"%id)
  var protection:float=p.invuln
  key();key(false)
  check(p.invuln==protection and p.model.kagerou_tick==0,"Recovery prevents another press from extending protection")
  p.timed_dodge._process(0)
  check(not p.timed_dodge.visible,"Recovery hides the icon without a text popup")
  key(true,true);key(false)
  check(p.model.kagerou_tick==0,"Key repeat cannot restart the reaction")
  await driver.advance(1,func(_dt):advance(35))
  var endpoint:Vector3=p.position
  var flat=Vector3(endpoint.x-position.x,0,endpoint.z-position.z)
  check(p.hp==hp and flat.distance_to(travel)<.1 and p.is_on_floor(),"Timed dodge moves the real body outward and avoids damage for %d"%id)
  check(p.model.kagerou_tick<0 and p.model.sprite.position.is_zero_approx(),"The outward step ends without a visual return for %d"%id)
  check(p.model.stat_counter_shadow.visible and p.model.stat_counter_shadow.global_position.is_equal_approx(shadow_at),"The shadow stays at the starting point while the real fighter moves for %d"%id)
  if id==p.RogueRoster.KAZI_ID:
   await capture("dodge")
   var camera=game.camera_rig.camera;var view:Transform3D=camera.global_transform
   camera.global_position=home+Vector3(8,4,0);camera.look_at(home+Vector3.UP*1.2)
   await capture("shadow-side")
   camera.global_transform=view
   print("SHADOW_DODGE_SAMPLE ",JSON.stringify({"start":position,"end":endpoint,"shadow":shadow_at,"travel":travel}))
  await driver.advance(1,func(_dt):advance(2,false))
  check(p.position.distance_to(endpoint)<.1 and p.invuln<=0,"The fighter stays at the dodge endpoint as protection expires for %d"%id)
  p.take_hit(2,Vector3.BACK)
  check(p.hp<hp,"The waiting shadow cannot extend timed invulnerability for %d"%id)
  p.velocity=Vector3.ZERO
  await driver.advance(1,func(_dt):advance(50,false))
  check(not p.timed_dodge.reacting and p.model.kagerou_tick<0 and p.model.sprite.position.is_zero_approx() and p.position.distance_to(endpoint)<.1,"Idle time never returns the fighter home for %d"%id)
  p.invuln=0;var health:float=p.hp;p.take_hit(2,Vector3.BACK)
  check(p.hp<health,"Ordinary damage resumes for %d"%id)
  await reward_case(id)

 await counter_edges()
 await dodge_edges()

 await settle(p.RogueRoster.KAZI_ID)
 tap("light_attack");var attacking:bool=p.active_ability.is_attacking()
 key();key(false)
 check(p.invuln==0 and not p.timed_dodge.reacting and p.active_ability.is_attacking()==attacking,"Unprompted Space preserves the attack and gives no protection")
 check(p.timed_dodge.cooldown==0,"An unprompted press does not lock out the next dodge")
 p.timed_dodge._process(0);check(not p.timed_dodge.visible,"An unprompted press creates no hint")
 p.active_ability.cancel(true)
 spawn();check(await wait_warning(),"A threat immediately after an empty press opens the window")
 key();key(false)
 check(p.timed_dodge.reacting,"An empty press cannot block the next valid dodge")

 await settle(p.RogueRoster.KAZI_ID);spawn()
 check(await wait_warning(.1),"The late part of the window remains reachable")
 var health:float=p.hp;key();key(false)
 var start:Vector3=p.position;var travel:Vector3=p.model.kagerou_step*p.model.KAGEROU_BACK_TICKS
 await driver.advance(1,func(_dt):advance(10))
 check(p.timed_dodge.reacting and p.hp==health,"A late Space still avoids the real strike")
 click_attack()
 check(not p.active_ability.shin_counter.is_empty() and p.active_ability.shin_counter.get("after_dodge",false) and p.timed_dodge.reacting and p.active_ability.shin_counter.origin.is_equal_approx(start),"An early left click starts the anchored shadow without cutting the real dodge short")
 await driver.advance(1,func(_dt):advance(10,false))
 check(not p.timed_dodge.reacting and Vector3(p.position.x-start.x,0,p.position.z-start.z).distance_to(travel)<.1,"The full outward dodge completes while its shadow counter attacks")

 await settle(p.RogueRoster.KAZI_ID);spawn(20)
 check(await wait_warning(.22),"Recovered Cross Gate enemy contact opens the same window")
 game.paused=true;key();key(false)
 check(not p.timed_dodge.reacting and p.timed_dodge.cooldown==0,"Paused Space cannot dodge")
 p.timed_dodge._process(0);check(not p.timed_dodge.visible,"Pause hides the warning")
 game.paused=false;key();key(false)
 check(p.timed_dodge.reacting,"Cross Gate attack uses the same successful dodge")
 p.select_character(p.RogueRoster.SHIN_ID)
 check(not p.timed_dodge.reacting and not p.timed_dodge.visible,"Changing fighter clears the old reaction/cue")
 check(p.timed_dodge.counter_source==0,"Changing fighter clears the banked counter reward")
 p.timed_dodge.counter_source=1;p.active_ability.die()
 check(p.timed_dodge.counter_source==0,"Death clears the banked counter reward")

 await settle(p.RogueRoster.KAZI_ID)
 var before=game.settings.jump_styles.duplicate(true)
 p.jump_style.selected="ben";p.jump_style.character=p.character_id
 check(not p.jump_style.active() and not p.can_fly(),"Saved jump/flight styles remain dormant with the standard jump restored")
 check(game.settings.jump_styles==before,"Saved jump assignments remain intact")
 p.jump_style.prepare()
 tap("dodge");check(p.dodge_time==0,"C is inactive for Cross Gate fighters")
 check(p.timed_dodge.counter_source==0,"C does not grant the Space reward")
 await driver.advance(1,func(_dt):advance(90,false));p.invuln=0
 for i in 5:p.timed_dodge.reset();p.timed_dodge._process(0)
 await frames(2)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 100:
  p.timed_dodge.reset();key();key(false);p.timed_dodge.tick(1);p.timed_dodge._process(0)
 await frames(2)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated cues and presses retain no extra nodes/resources")
 root.size=Vector2i(960,640);spawn();check(await wait_warning(),"Small-window cue is reachable");await capture("ready-960")
 elapsed.sort()
 var report={"checks":checks,"failures":failures,"manual_step_p95_us":elapsed[int(elapsed.size()*.95)],"manual_step_max_us":elapsed.back(),"node_delta":get_node_count()-nodes}
 FileAccess.open(OUT+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("TIMED_DODGE_RESULT ",JSON.stringify(report))
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
