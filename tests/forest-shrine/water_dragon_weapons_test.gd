extends "res://tests/forest-shrine/dodge_counter_stats_test.gd"
## Projectile behavior only; blade orientation is reviewed with images.
const WATER_EVIDENCE="res://build/Other Files/Asset Toolkit/Shin Water Dragon/All Weapons/Gameplay/"
const WEAPONS=["sword","axe","polearm","bow","staff","kunai","boomerang"]

func water_capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(2);RenderingServer.force_draw()
 root.get_texture().get_image().save_png(WATER_EVIDENCE+stem+".png")

func equip_water(weapon:String):
 game.player.active_ability.cancel(true);game.player.active_ability.clear_shin_counter()
 var item="weapon:water-dragon-boomerang" if weapon=="boomerang" else "weapon:"+weapon
 check(game.save_equipment_loadouts({Gear.character_key(37):{"1":item}},{},{}),"Equip Water Dragon "+weapon)

func run():
 create_timer(240).timeout.connect(func():printerr("WATER_WEAPONS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(WATER_EVIDENCE);root.size=Vector2i(1100,760);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.gear_loadouts={};game.settings.skill_item_loadouts={};game.settings.forest_pet_loadout=[]
 game.begin_arena();game.choose_rogue_character(37);game.select_shin_skin(37,900050);await frames(2);game.equipment_hub.enter_map();await frames(3)
 game.clear_menu();game.playing=true;game.paused=false;paused=false;game.forest_ui.hide();game.music.stop()
 game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear()
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.camera.global_position=home+Vector3(4,15,24);game.camera_rig.camera.look_at(home+Vector3(0,1,-8));game.camera_rig.camera.make_current()
 var p=game.player;var model=p.model;var kit=p.active_ability;var pool=Pool.service(game)
 game.update_character_tuning(37,"critical_chance",0)
 game.update_character_tuning(37,"accuracy",100)
 pool.launched.connect(func(shot):shot.set_physics_process(false);shots.append(shot))
 check(WEAPONS.all(func(weapon):return Gear.allowed(37,game.settings).has(weapon)) and Gear.allowed(37,game.settings).has("three-weapon"),"All seven Water Dragon routes and the separate combo item are available")
 for weapon in WEAPONS:
  equip_water(weapon);planted()
  check(model.current_weapon()==weapon and model.shin_skin==900050,"Gear preserves Water Dragon appearance "+weapon)
  var pattern:Dictionary=model.normal_attack_pattern()
  check(not pattern.contacts.is_empty() and pattern.duration>0,"Gear supplies a valid contact clock "+weapon)
  var attack:Dictionary=pattern.attack
  model.show_shin_counter(p.global_position,attack,true)
  model.pose_shin_counter(attack,float(attack.duration)*.8);model.show_pose(int(pattern.pose),float(attack.duration)*.8,false)
  check(model.stat_counter_shadow.texture==model.sprite.texture and model.stat_counter_shadow.region_rect==model.sprite.region_rect,"Counter shares equipped attack atlas and frames "+weapon)
  model.stat_counter_shadow.hide()
  check(model.single_strike_sound(attack)!=null and model.shin_counter_fx.texture.resource_path.ends_with("/counter-blue.png"),"Equipped impact and counter burst use the ice theme "+weapon)
  if weapon=="polearm":
   kit.shin_counter_equipped=true
   check(kit.counter_after_hit(Vector3.BACK,0,false),"Special spear counter starts with selected water art")
   kit.tick_shin_counter(.12);await water_capture("special-counter-blue");kit.clear_shin_counter()
 equip_water("boomerang");planted();game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.refresh_kits()
 var victim=spawn(Vector3.FORWARD*18);game.army_runtime.flush_presentation();var before:float=victim.target.hp
 kit.start_attack();var pattern:Dictionary=model.normal_attack_pattern();var rate=p.attack_speed_multiplier()
 kit.tick((float(pattern.contacts[0])-.001)/rate)
 check(shots.is_empty(),"Boomerang waits for native release")
 kit.tick(.002/rate)
 check(shots.size()==1 and shots[0].kind=="water_dragon_boomerang","Release launches one curved boomerang")
 if shots.is_empty():quit(1);return
 var shot=shots[0];var start:Vector3=shot.global_position;var duration:float=shot.boomerang_duration
 check(shot.boomerang_point(0,start).is_equal_approx(start),"Curve starts at the throw hand")
 var a:Vector3=shot.boomerang_point(.25,start)-start;var b:Vector3=shot.boomerang_point(.75,start)-start
 check(a.dot(shot.boomerang_side)>1 and b.dot(shot.boomerang_side)<-1,"Outward and return legs curve to opposite sides")
 var moving_home=start+Vector3(5,0,2)
 check(shot.boomerang_point(1,moving_home).distance_to(moving_home)<.001,"Return catches a moving owner")
 var trace=[];var checkpoints=[.2,.4,.6,.8];var capture_index=0
 for i in ceili(duration/DT)+3:
  if not shot.pool_live:break
  shot._physics_process(DT);trace.append([shot.global_position.x,shot.global_position.y,shot.global_position.z])
  kit.tick(DT);game.crowd.army.presentation.tick(DT)
  if i%2==0:await water_capture("flight-%02d"%i)
  if capture_index<checkpoints.size() and float(shot.age)>=duration*checkpoints[capture_index]:
   model.show_pose(0,0,true);await water_capture("boomerang-%d"%capture_index);capture_index+=1
 check(not shot.pool_live,"Boomerang retires after return")
 check(victim.target.hp<before,"Curved flight hits the intended enemy")
 check(is_equal_approx(before-float(victim.target.hp),Skills.basic_damage(pattern)*p.damage_multiplier()),"Each enemy takes damage once across both legs")
 var crowd=[]
 for z in range(20,27):
  for x in [-1.8,0.0,1.8]:crowd.append(spawn(Vector3(x,0,-z)).target)
 var crowd_hp=crowd.map(func(enemy):return enemy.hp)
 var before_combo:int=kit.primary_combo_hits
 var sweep_ticket=p.attack_chain.begin("crossgate_throw");sweep_ticket.damage_multiplier=1.0
 kit.prepare_primary_combo(sweep_ticket)
 var sweep=pool.launch(p,kit.Shot,"water_dragon_boomerang",{"kind":"water_dragon_boomerang","position":start,"velocity":Vector3.FORWARD*72,"boomerang_reach":18.0,"attack_ticket":sweep_ticket.duplicate(),"damage":10.0})
 var old_hits={};var sweep_times=[]
 for tick in ceili(sweep.boomerang_duration/DT)+2:
  if not sweep.pool_live:break
  var from:Vector3=sweep.global_position
  var to:Vector3=sweep.boomerang_point((sweep.age+DT)/sweep.boomerang_duration,p.auto_aim_origin())
  for enemy in crowd:
   if not AttackChain.segment_contact(enemy,from,to,sweep.dagger_sprite.pixel_size*26).is_empty():old_hits[enemy.get_instance_id()]=true
  var clock=Time.get_ticks_usec();sweep._physics_process(DT);sweep_times.append(Time.get_ticks_usec()-clock)
 var new_hits=0
 for i in crowd.size():
  if crowd[i].hp<crowd_hp[i]:new_hits+=1
  check(is_equal_approx(crowd_hp[i]-crowd[i].hp,10.0) or crowd_hp[i]==crowd[i].hp,"Crowd enemy %d takes at most one normal hit (damage %.1f)"%[i,crowd_hp[i]-crowd[i].hp])
 check(new_hits>old_hits.size(),"Broad sweep catches more enemies than the previous narrow contact area")
 check(new_hits>1 and kit.primary_combo_hits==before_combo+1,"One throw through a crowd earns exactly one combo step")
 sweep_times.sort();print("BOOMERANG_CROWD old_hits=",old_hits.size()," new_hits=",new_hits," projectile_step_p95_us=",sweep_times[int(sweep_times.size()*.95)])
 await water_capture("boomerang-crowd")
 var created=pool.created;var cached_texture=shot.dagger_sprite.texture;var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 8:
  var lease_origin:Vector3=p.auto_aim_origin()+Vector3.RIGHT*repeat*.25
  var again=pool.launch(p,kit.Shot,"water_dragon_boomerang",{"kind":"water_dragon_boomerang","position":lease_origin,"velocity":Vector3.FORWARD*72,"boomerang_reach":18.0,"attack_ticket":{},"damage":1.0})
  again.set_physics_process(false)
  check(again.age==0 and again.hit_targets.is_empty() and again.dagger_sprite.texture==cached_texture and again.boomerang_origin.is_equal_approx(lease_origin),"Pool clears flight/hits and shares artwork")
  again.retire()
 check(pool.created==created and get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated throws keep node, resource and prepared projectile counts stable")
 kit.cancel(true);kit.clear_shin_counter();shots.clear();planted();chance(100,100)
 p.take_hit_from(2,Vector3.BACK,false,victim.id)
 check(not kit.shin_counter.is_empty(),"Boomerang can counter")
 if not kit.shin_counter.is_empty():
  kit.tick_shin_counter(float(kit.shin_counter.contact)/rate+.001)
  check(shots.size()==1 and shots[0].kind=="water_dragon_boomerang","Counter launches the same curved projectile")
  if not shots.is_empty():
   var counter_shot=shots[0]
   check(counter_shot.impact_sound==model.single_strike_sound(kit.shin_counter.attack),"Counter projectile carries the same prepared ice impact")
   for tick in ceili(counter_shot.boomerang_duration/DT)+2:
    if counter_shot.pool_live:counter_shot._physics_process(DT)
 pool.release_owner(p);kit.clear_shin_counter()
 equip_water("kunai");planted();shots.clear();kit.start_attack();kit.tick(float(model.normal_attack_pattern().duration)+.01)
 check(shots.size()==1 and shots[0].kind=="water_dragon_dagger","Knife uses its recovered projectile artwork")
 pool.release_owner(p)
 equip_water("boomerang");planted();shots.clear()
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 4:
  check(mirrors.reinforce(37,home+Vector3((i-1.5)*2,0,1)),"Native companion uses the shared runtime")
 var prepared_count=pool.created
 for body in mirrors.bodies:
  check(body.model.current_weapon()=="boomerang" and body.model.atlases[0]==model.atlases[0],"Native copy shares selected weapon textures")
  check(body.perform(0,victim.target.global_position),"Native copy starts the equipped throw")
  body.active_ability.tick(float(body.model.normal_attack_pattern().contacts[0])/body.attack_speed_multiplier()+.002)
 check(shots.size()==4 and shots.all(func(item):return item.kind=="water_dragon_boomerang" and item.dagger_sprite.texture==cached_texture),"Four simultaneous copies share curved projectile artwork")
 check(pool.created==prepared_count,"Simultaneous copy throws use warmed leases")
 await water_capture("four-native-boomerangs");mirrors.dispose();await frames(2)
 equip_water("axe");planted();p.set_physics_process(true);p.set_auto_attack(false)
 var move=InputEventAction.new();move.action="move_left";move.pressed=true;Input.parse_input_event(move)
 await create_timer(.35).timeout;await water_capture("controls-walk")
 var movement={"walk":p.model.current_clip}
 var shift=InputEventKey.new();shift.physical_keycode=KEY_SHIFT;shift.pressed=true;shift.shift_pressed=true;Input.parse_input_event(shift)
 await create_timer(.35).timeout;await water_capture("controls-run");movement.run=p.model.current_clip
 shift=InputEventKey.new();shift.physical_keycode=KEY_SHIFT;shift.pressed=false;Input.parse_input_event(shift)
 await create_timer(.25).timeout;await water_capture("controls-shift-release");movement.shift_release=p.model.current_clip
 move=InputEventAction.new();move.action="move_left";move.pressed=false;Input.parse_input_event(move);p.set_physics_process(false)
 var file=FileAccess.open(WATER_EVIDENCE+"boomerang-trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace));file.close()
 game.select_shin_skin(37,100050)
 check(model.shin_counter_fx.texture.resource_path.ends_with("/shin/counter.png"),"Original Shin keeps his original counter effect")
 print("WATER_WEAPONS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"trace_points":trace.size(),"controls":movement}))
 game.queue_free();current_scene=null;await frames(3);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
