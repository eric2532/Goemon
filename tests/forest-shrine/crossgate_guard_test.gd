extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const OUT="res://build/Other Files/Cross Gate Guard/"
const DT=1.0/60
var driver
var home=Vector3(-120,0,125)
var samples:Array[int]=[]

func key(pressed:bool):
 var event=InputEventKey.new();event.physical_keycode=KEY_X;event.pressed=pressed
 if pressed:game.player._unhandled_input(event)
 else:game.player._input(event)

func advance(count:int):
 for i in count:
  var started=Time.get_ticks_usec()
  game.player._physics_process(DT)
  game.crowd.army.presentation.tick(DT)
  samples.append(Time.get_ticks_usec()-started)

func settle():
 var p=game.player
 p.cancel_charge();p.attack_chain.reset();p.set_auto_attack(false);p.clear_character_cooldowns()
 p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.invuln=0;p.dodge_time=0;p.impact_pause=0
 p.jump_buffer=0;p.jump_windup=0
 p.smoke_mode=true;p.smoke_move=Vector2.ZERO;p.hp=p.max_hp
 p.active_ability.kagerou_enabled=false
 await driver.advance(1,func(_delta):advance(60))
 check(p.is_on_floor(),"Guard fixture stands on the actual arena")

func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Captured "+label_)

func check_art():
 var p=game.player;var model=p.model
 for d in 8:
  p.facing=Vector3.FORWARD.rotated(Vector3.UP,d*TAU/8)
  model.animate(DT,0,true,0,0,false,0,false)
  check(model.current_clip.begins_with("9:") and model.sprite.texture!=null and model.sprite.region_rect.has_area(),"Original guard art for %d facing %d"%[p.character_id,d])
 p.facing=Vector3.FORWARD
 model.animate(DT,0,true,0,0,false,0,false)

func check_appearances():
 var p=game.player;var model=p.model;var profile:Dictionary=p.RogueRoster.CROSSGATE[p.character_id]
 if p.RogueRoster.is_shin(p.character_id):
  var original:int=model.shin_skin
  var stance:int=model.shin_weapon_index
  for skin in p.RogueRoster.ShinSkins.catalog(p.character_id==p.RogueRoster.SHIN_SPECIAL_ID):
   model.set_shin_skin(skin)
   for weapon in model.appearance.get("weapons",[]).size()+1:
    model.select_stance(weapon);model.current_clip="";check_art()
  model.set_shin_skin(original);model.select_stance(stance)
 elif profile.has("skins"):
  var original:int=model.variant_skin
  for skin in profile.skins:
   model.set_variant_skin(skin);check_art()
  model.set_variant_skin(original)
 elif p.character_id==p.RogueRoster.KAZI_ID:
  var original:int=model.kaz_skin
  for skin in model.Skins.CATALOG:
   model.set_kaz_skin(skin);check_art()
  model.set_kaz_skin(original)
 if p.RogueRoster.has_crossgate_throws(p.character_id):
  var original:int=model.maze_weapon
  for weapon in p.RogueRoster.MazeWeapon.values():
   model.set_maze_weapon(weapon);model.current_clip="";check_art()
  model.set_maze_weapon(original)
 model.current_clip="";check_art()

func enemy_guard():
 var p=game.player;var army=game.army_runtime
 p.select_character(p.RogueRoster.KAZI_ID);await settle();army.clear();army.refresh_kits();army.refresh_navigation(Time.get_ticks_usec())
 var native=army.native
 var guard_handle=0
 var guard_at=home+Vector3.FORWARD*9
 guard_at.y=game.model.surface_height(guard_at.x,guard_at.z)
 # Isolate contact tests from crowd separation and ordinary autonomous attacks.
 for attempt in 40:
  army.clear();army.refresh_kits()
  var h=army.spawn(9000+attempt,0,20,guard_at,1000,3.9)
  native.set_pose(h,guard_at,PI)
  var targets=army.external_targets()
  targets.player_attack_serial=100+attempt;targets.player_attack_facing=Vector3.FORWARD;targets.player_attack_reach=8.0
  native.set_targets(targets)
  var early=false
  for frame in 28:
   native.step(DT)
   var state=native.unit_state(h)
   if state.blocking:
    if frame<5:early=true
    guard_handle=h;break
  check(not early,"Enemy never guards before the reaction delay")
  if guard_handle!=0:break
 check(guard_handle!=0,"Real native enemy chooses a delayed guard")
 if guard_handle==0:return
 var state=native.unit_state(guard_handle)
 var snapshot=army.render_snapshot()
 var pose:Color=game.crowd.army.pose_sample(snapshot,0)
 check(int(pose.g)%8==6,"Compatibility presentation uses the guard sprite slot")
 check(state.action==13 and (state.status&16)!=0,"Guard action and native status agree")
 var result=army.apply_hit(guard_handle,{"amount":100.0,"direction":Vector3.FORWARD,"knockback":Vector3.FORWARD*8,"flinch":.2})
 check(result.accepted and is_equal_approx(result.hp,975),"Native frontal guard takes 25% damage")
 check(native.unit_state(guard_handle).stun==0,"Native block suppresses ordinary flinch")
 game.camera_rig.camera.global_position=guard_at+Vector3(6,5,11)
 game.camera_rig.camera.look_at(guard_at+Vector3.UP*2.7)
 army.flush_presentation()
 check(game.crowd.army.presentation.effects.any(func(effect):return effect.kind=="spark"),"Native blocked contact reaches the pooled spark feedback")
 await capture("enemy-guard")
 army.apply_hit(guard_handle,{"amount":100.0,"direction":Vector3.BACK})
 check(is_equal_approx(native.unit_state(guard_handle).hp,875) and not native.unit_state(guard_handle).blocking,"Rear hit deals full damage and interrupts enemy guard")
 army.clear()

func run():
 create_timer(240).timeout.connect(func():printerr("CROSSGATE_GUARD_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 check(game.model.waves.crossgate_pet_test,"Run the guard fixture with --crossgate-pet-test")
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 for node in [game,game.player,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 game.camera_rig.camera.global_position=home+Vector3(5,6,13)
 game.camera_rig.camera.look_at(home+Vector3(0,1.8,0))
 var p=game.player
 game.tuning.enemy_damage=1.0;game.tuning.invincible=false
 game.training_dummy.position=home+Vector3(30,0,0)
 check(InputMap.action_get_events("defend").any(func(event):return event is InputEventKey and event.physical_keycode==KEY_X),"X is bound to defense")
 check(p.RogueRoster.selection_ids().size()==9,"All nine selectable Cross Gate fighters are covered")
 for id in p.RogueRoster.selection_ids():
  p.select_character(id);await settle();key(true)
  check(p.crossgate_guarding(),"Hold X enters guard for %d"%id)
  check_art();check_appearances()
  var before:float=p.hp
  var multiplier:float=p.team_progression.stat_incoming_multiplier()
  p.invuln=0;p.take_hit_from(100,Vector3.BACK,false,42)
  check(is_equal_approx(before-p.hp,25*multiplier),"Frontal melee reduced by 75%% for %d"%id)
  check(p.velocity.is_zero_approx() and p.crossgate_guarding(),"Block keeps stance without knockback for %d"%id)
  p.invuln=0;before=p.hp;p.take_hit_from(100,Vector3.BACK,true,42)
  check(is_equal_approx(before-p.hp,25*multiplier),"Frontal projectile reduced for %d"%id)
  p.set_auto_attack(true)
  check(not p.auto_attack_running(),"Guard suspends auto-attack for %d"%id)
  tap("light_attack");p.spell_loadout.number_input(1,true)
  check(not p.active_ability.is_attacking() and p.spell_loadout.current==null,"Attack and numbered cast blocked for %d"%id)
  p.set_auto_attack(false)
  await capture("guard-%d"%id)
  key(false);check(not p.crossgate_guarding(),"Release X ends guard for %d"%id)
  key(true);p.hp=1000
  for projectile in [false,true]:
   for d in 8:
    var direction=Vector3.FORWARD.rotated(Vector3.UP,d*TAU/8)
    p.facing=direction;p.invuln=0;before=p.hp
    p.take_hit_from(20,direction+Vector3.UP*.3,projectile,42)
    check(is_equal_approx(before-p.hp,5*multiplier) and p.facing.is_equal_approx(-direction) and p.crossgate_guarding(),"Guard turns and reduces hit for %d direction %d projectile %s"%[id,d,str(projectile)])
    p.model.animate(DT,0,true,0,0,false,0,false)
    check(p.model.current_clip=="9:%d"%p.model.direction_for(-direction),"Guard sprite follows incoming hit for %d direction %d"%[id,d])
  for direction in [Vector3.ZERO,Vector3.UP]:
   var facing:Vector3=p.facing
   p.invuln=0;before=p.hp;p.take_hit_from(20,direction,false,42)
   check(is_equal_approx(before-p.hp,5*multiplier) and p.facing.is_equal_approx(facing),"Directionless guard keeps facing for %d"%id)
  var guarded_facing:Vector3=p.facing
  before=p.hp;p.take_hit_from(20,guarded_facing,false,42)
  check(p.hp==before and p.facing.is_equal_approx(guarded_facing),"Recovery ignores hits without turning for %d"%id)
  await capture("guard-auto-turn-%d"%id)
  key(false);p.invuln=0;before=p.hp;p.take_hit_from(20,guarded_facing,false,42)
  check(is_equal_approx(before-p.hp,20*multiplier) and p.active_ability.mode=="hurt" and p.facing.is_equal_approx(guarded_facing),"Released guard takes ordinary rear damage for %d"%id)
  await settle()
  p.active_ability.start_attack();var duration:float=p.attack_left
  var telegraph:Dictionary=game.army_runtime.external_targets()
  check(telegraph.player_attack_serial==p.crossgate_attack_serial and telegraph.player_attack_serial>0,"Native snapshot observes real attack windup for %d"%id)
  key(true)
  check(not p.crossgate_guarding() and p.active_ability.is_attacking() and p.attack_left==duration,"Guard waits for committed attack for %d"%id)
  await driver.advance(1,func(_delta):advance(180))
  check(p.crossgate_guarding(),"Held guard starts after attack recovery for %d"%id)
  check(game.army_runtime.external_targets().player_attack_serial==0,"Completed attack stops advertising a threat for %d"%id)
  key(false)
 p.select_character(p.RogueRoster.SHIN_ID);await settle()
 p.model.select_stance(2)
 p.spell_loadout.equip(p.character_id,"surge","shin/counter");key(true);p.invuln=0
 p.take_hit_from(20,Vector3.BACK,false,42)
 check(p.active_ability.shin_counter_chain==1,"Blocked chip damage keeps Shin's existing on-hit counter")
 p.active_ability.clear_shin_counter()
 p.team_progression.stat_ranks.defense=10;p.invuln=0
 var before:float=p.hp;p.take_hit_from(24,Vector3.BACK,false,42)
 check(is_equal_approx(before-p.hp,6.0*p.team_progression.stat_incoming_multiplier()),"Defense stat applies after guard reduction")
 p.team_progression.stat_ranks.defense=0
 p.select_character(p.RogueRoster.KAZI_ID);await settle();key(true)
 var facing:Vector3=p.facing;p.smoke_move=Vector2(0,1)
 await driver.advance(1,func(_delta):advance(30))
 check(p.facing.is_equal_approx(facing) and Vector2(p.velocity.x,p.velocity.z).length()<=2.21,"Guard backs away slowly without turning")
 p.smoke_move=Vector2.ZERO;tap("dodge")
 check(not p.defend_held and p.dodge_time>0,"Dodge cancels guard")
 await settle();key(true);tap("jump")
 check(not p.defend_held,"Jump cancels guard")
 await settle();key(true);p._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not p.defend_held,"Focus loss releases guard")
 key(true);p.select_character(p.RogueRoster.BOG_ID)
 check(not p.defend_held,"Character switch releases guard")
 await settle();key(true);game.paused=true
 check(not p.crossgate_guarding(),"Pause disables protection")
 key(false);game.paused=false
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 100:
  key(true);p.invuln=0;p.take_hit_from(1,Vector3.FORWARD.rotated(Vector3.UP,i*TAU/8),i%2==0,1);key(false)
  game.crowd.army.presentation.tick(1)
 await frames(3)
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=nodes,"Repeated blocks retain no new nodes")
 check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources,"Repeated blocks retain no new resources")
 await enemy_guard()
 samples.sort()
 print("CROSSGATE_GUARD_PROFILE player_us_p95=%d max=%d"%[samples[int(samples.size()*.95)],samples[-1]])
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("CROSSGATE_GUARD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
