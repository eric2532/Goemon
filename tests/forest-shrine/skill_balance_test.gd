extends "res://tests/forest-shrine/modular_spells_test.gd"
const Skills=preload("res://scripts/spells/skill_balance.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Bolt=preload("res://scripts/warcraft_projectile.gd")
const YaeShot=preload("res://scripts/recovered_yae_projectile.gd")
const OUT="res://build/Other Files/Asset Toolkit/Skill Balance/"
var released=[]
var total_releases=0
func run():
 create_timer(180).timeout.connect(func():printerr("SKILL_BALANCE_TIMEOUT");quit(1))
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

 cfg="user://modular-spells-%d.cfg"%OS.get_process_id()
 DirAccess.make_dir_recursive_absolute(OUT)
 var settings_before=game.settings.duplicate(true)
 check(Skills.sanitized(null).is_empty(),"Malformed saved profiles are ignored")
 check(Skills.sanitized({"missing":{"size":2},"edo/volley":{"size":NAN,"damage":INF,"hit_area":"2","travel_speed":-1}})=={"edo/volley":{"travel_speed":.1}},"Unknown/nonfinite/nonnumeric fields are rejected and ranges clamp")
 for id in Skills.all():
  game.update_skill_balance(id,"size",1.5)
  game.update_skill_balance(id,"hit_area",2.0)
  game.update_skill_balance(id,"travel_speed",1.25)
  game.update_skill_balance(id,"damage",2.5)
  for row in Skills.ROWS:
   check(Skills.value(game,id,row[0])==({"size":1.5,"hit_area":2.0,"travel_speed":1.25,"damage":2.5}[row[0]] if Skills.supports(id,row[0]) else 1.0),"Saved supported field %s/%s"%[id,row[0]])
 game.load_settings()
 check(Skills.value(game,"edo/volley","damage")==2.5,"Automatic save survives a config reload")
 check(game.settings.spell_loadouts==settings_before.spell_loadouts,"Saving tuning preserves equipment")
 game.reset_skill_balance("edo/volley")
 check(Skills.value(game,"edo/volley","damage")==1 and Skills.value(game,"yae/bazooka","damage")==2.5,"Reset affects just the selected skill")
 # Native mapping and damage use the same ticket snapshot after changing fighter/settings.
 p.select_character(32);clear_instances();p.active_ability.demon=true
 var ticket=p.attack_chain.begin("warcraft_attack")
 check(ticket.skill_id=="demon-hunter/bolt" and ticket.skill_damage==2.5,"Original transformed attack selects its own bolt profile")
 var factor=p.attack_chain.damage_for(ticket)
 game.reset_skill_balance("demon-hunter/bolt");p.select_character(1)
 check(is_equal_approx(p.attack_chain.damage_for(ticket),2.5),"Released damage retains its snapshot across reset and fighter change")
 check(p.attack_chain.make_ticket("pipe").get("skill_damage",1)==1,"Normal melee does not inherit the previous skill")
 var pool=Pool.service(game)
 p.select_character(17);clear_instances()
 var launch={"position":ORIGIN+Vector3(0,8,0),"velocity":Vector3.FORWARD*10,"speed":10.0,"hit_radius":.2,"blast_radius":1.0,"attack_ticket":p.attack_chain.begin("yae_bazooka")}
 var shot=pool.launch(p,YaeShot,"yae/bazooka",launch)
 check(is_equal_approx(shot.velocity.length(),12.5) and shot.hit_radius==.4 and shot.blast_radius==2,"Projectile travel and contact tuning apply once")
 check(shot.ornament.scale.is_equal_approx(Vector3.ONE*1.5),"Visual size is independent of hit radius")
 var created=pool.created;var misses=pool.misses
 for i in 20:
  shot.retire();shot=pool.launch(p,YaeShot,"yae/bazooka",launch)
  check(shot.hit_radius==.4 and shot.ornament.scale.is_equal_approx(Vector3.ONE*1.5),"Reused lease does not compound tuning")
 shot.retire()
 check(pool.created==created and pool.misses==misses,"Repeated tuning reuses prepared projectiles")
 game.reset_skill_balance("yae/bazooka");launch.attack_ticket=p.attack_chain.begin("yae_bazooka")
 shot=pool.launch(p,YaeShot,"yae/bazooka",launch)
 check(shot.velocity.length()==10 and shot.hit_radius==.2 and shot.ornament.scale.is_equal_approx(Vector3.ONE),"Reset restores projectile defaults on reuse")
 shot.retire()
 # A fast projectile still sweeps the target; cover clips that same segment.
 var dummy_target=game.training_dummy
 dummy_target.position=ORIGIN+Vector3(0,0,-2);dummy_target.home=dummy_target.position;dummy_target.recoil_age=1
 var fast_launch={"position":ORIGIN+Vector3(0,1.5,6),"velocity":Vector3.FORWARD*1000,"speed":1000.0,"hit_radius":.2,"attack_ticket":p.attack_chain.begin("yae_bazooka")}
 shot=pool.launch(p,YaeShot,"yae/bazooka",fast_launch);shot._physics_process(.02)
 check(shot.resolved and dummy_target.recoil_age==0,"Fast flight sweeps through a thin target between frames")
 var wall=StaticBody3D.new();wall.collision_layer=1
 var wall_shape=CollisionShape3D.new();wall_shape.shape=BoxShape3D.new();wall_shape.shape.size=Vector3(4,5,.3);wall.add_child(wall_shape);game.add_child(wall);wall.position=ORIGIN+Vector3(0,2.5,2)
 await physics_frame
 dummy_target.recoil_age=1
 shot=pool.launch(p,YaeShot,"yae/bazooka",fast_launch);shot._physics_process(.02)
 check(shot.resolved and dummy_target.recoil_age==1,"Fast flight stops at cover before reaching the target")
 wall.free()
 # Check real native contact and HP, not just stored setting values.
 p.select_character(32);clear_instances();p.attack_chain.reset()
 var c=p.active_ability
 game.model.update_vision(ORIGIN)
 var base_radius=c.Kit.IMMOLATION_RADIUS*p.contact_size_multiplier()*p.pickup_multiplier("range")
 var dummy=game.training_dummy
 dummy.position=ORIGIN+Vector3(base_radius+.9,0,0);dummy.home=dummy.position;dummy.recoil_age=1
 game.reset_skill_balance("demon-hunter/immolation")
 c.burn_ticket=p.attack_chain.begin("warcraft_immolation");c.burn()
 check(dummy.recoil_age==1,"Original aura misses outside its contact radius")
 game.update_skill_balance("demon-hunter/immolation","hit_area",2)
 c.burn_ticket=p.attack_chain.begin("warcraft_immolation");c.burn()
 check(dummy.recoil_age==0,"Larger hit area reaches the same distant target")
 var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-7));row.hp=10000;row.max_hp=10000
 game.army_runtime.import_arrivals()
 var victim=game.army_runtime.enemy_target(row.id)
 p.attack_chain.reset();var plain=p.attack_chain.begin("pipe")
 plain.critical_chance=0
 var before=game.army_runtime.unit_state(victim.handle).hp
 victim.take_hit(10,Vector3.FORWARD,false,plain)
 var normal=before-game.army_runtime.unit_state(victim.handle).hp
 p.attack_chain.reset();game.update_skill_balance("demon-hunter/immolation","damage",2.5)
 var tuned=p.attack_chain.begin("warcraft_immolation")
 tuned.critical_chance=0
 before=game.army_runtime.unit_state(victim.handle).hp
 victim.take_hit(10,Vector3.FORWARD,false,tuned)
 var modified=before-game.army_runtime.unit_state(victim.handle).hp
 check(normal>0 and is_equal_approx(modified,normal*2.5),"Native enemy HP receives the skill damage multiplier exactly once")
 game.army_runtime.despawn(victim.handle)
 # Twelve simultaneous bolts reuse the same owned visuals and reset all four values.
 game.update_skill_balance("demon-hunter/bolt","size",1.5)
 game.update_skill_balance("demon-hunter/bolt","travel_speed",1.25)
 c.demon=true;var bolt_ticket=p.attack_chain.begin("warcraft_attack")
 var baseline_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 created=pool.created;misses=pool.misses
 for cycle in 5:
  var shots=[]
  for i in 12:
   var bolt=pool.launch(p,Bolt,"demon",{"position":ORIGIN+Vector3((i%4-1.5)*3,2+(i/4)*2,-8),"velocity":Vector3.FORWARD*28,"attack_ticket":bolt_ticket})
   bolt.set_physics_process(false);shots.append(bolt)
  check(shots.all(func(bolt):return bolt.visual.scale.is_equal_approx(Vector3.ONE*1.5) and is_equal_approx(bolt.velocity.length(),35)),"Simultaneous bolts apply size and speed without compounding")
  for bolt in shots:bolt.retire()
 check(pool.created==created and pool.misses==misses,"Five simultaneous bursts keep warmed pool size stable")
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==baseline_resources,"Repeated simultaneous bursts retain no extra resources")
 # Five simultaneous native-owned allies read the same saved skill profile.
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
 check(mirrors.cast(),"Native army accepts five prepared character copies")
 var allied_shots=[]
 var collect_allies=func(projectile):
  if is_instance_valid(projectile.hero) and projectile.hero.mirror_copy:
   projectile.set_physics_process(false);allied_shots.append(projectile)
 pool.launched.connect(collect_allies)
 for body in mirrors.bodies:
  body.active_ability.ticket=body.attack_chain.begin("warcraft_attack")
  body.active_ability.launch()
 check(allied_shots.size()==5 and allied_shots.all(func(projectile):return projectile.attack_ticket.allied and projectile.attack_ticket.skill_id=="demon-hunter/bolt" and projectile.visual.scale.is_equal_approx(Vector3.ONE*1.5) and is_equal_approx(projectile.velocity.length(),35)),"All five allies share the skill tuning through the original projectile owner")
 pool.launched.disconnect(collect_allies);mirrors.dispose();await process_frame
 pool.launched.connect(func(projectile):
  projectile.set_physics_process(false)
  if not projectile.attack_ticket.is_empty():released.append(projectile.attack_ticket.duplicate());total_releases+=1)
 # Original shortcuts share the same IDs, including spells owned by the loadout.
 for id in Catalog.all():
  var spec=Catalog.all()[id]
  p.select_character(spec.source);p.cancel_charge(false);clear_instances();pool.release_owner(p)
  game.settings.spell_loadouts={};p.spell_loadout.prepare();p.attack_chain.reset()
  p.velocity=Vector3.ZERO;step(3)
  var original=p.active_ability
  match spec.method:
   "dash":p.forward_dash.start()
   "sky":p.sky_strike.request()
   "surge":p.activate_surge()
   "flight":continue
   "teleport":original.teleport.start()
   "beam":original.activate_shield();original.start_beam("equip")
   "charge":original.begin_cast("primary");original.Actions.begin_charge(original)
   "start_cast","start_charge":
    var action=Catalog.defaults(spec.source).find_key(id)
    if action==null:p.spell_loadout._instance(id).cast()
    else:input(action,true);input(action,false)
   "input":original.input(p.spell_loadout.Instance.event(spec.args[0],true))
   "action":original.action(spec.args[0])
   _:original.callv(spec.method,spec.args)
  var native_ticket=p.attack_chain.active_ticket.duplicate()
  if not native_ticket.is_empty() and Skills.supports(id,"damage"):
   check(native_ticket.get("skill_id","")==id,"Original cast maps to skill tuning: "+id+" -> "+str(native_ticket.get("skill_id","")))
  if spec.method=="input":original.input(p.spell_loadout.Instance.event(spec.args[0],false))
  p.cancel_charge(false);clear_instances();await process_frame
 p.select_character(13);p.cancel_charge(false);clear_instances();step(3)
 p.active_ability.charge=p.active_ability.Profile.CHARGE_LIMIT;p.active_ability.special_held=true
 p.active_ability.release_input(p.spell_loadout.Instance.event("equip",false))
 check(p.attack_chain.active_ticket.get("skill_id","")=="musashi/charge","Original charged release keeps its separate skill profile")
 p.cancel_charge(false)
 # Every transferable skill runs through its real existing owner at non-default tuning.
 for id in Catalog.all():
  p.select_character(1 if int(Catalog.all()[id].source)!=1 else 16)
  clear_instances();pool.release_owner(p);game.settings.spell_loadouts={};p.spell_loadout.retired_cooldowns.clear()
  p.attack_chain.reset();released.clear()
  p.spell_loadout.equip(p.character_id,"equip",id)
  input("equip",true);step(35);input("equip",false);step(35)
  check(p.spell_loadout.casting_id.is_empty(),"Borrowed context clears: "+id)
  for cast in released:
   check(cast.get("skill_id","")==id,"Released projectile keeps borrowed skill identity: "+id)
  clear_instances();await process_frame
 game.settings.spell_loadouts={};pool.release_owner(p)
 p.select_character(1);game.show_settings(true)
 var button=game.menu.find_child("SkillBalanceButton",true,false)
 check(button!=null,"Settings exposes Skill Balance")
 button.pressed.emit()
 var editor=game.menu.find_child("SkillBalance",true,false)
 check(editor!=null,"Settings opens skill editor")
 game.show_skill_balance(true,"edo/volley");editor=game.menu.find_child("SkillBalance",true,false)
 editor.find_child("Skill_size",true,false).value=1.75
 check(Skills.value(game,"edo/volley","size")==1.75,"UI automatically saves edits")
 if DisplayServer.get_name()!="headless":
  root.title="Goemon · Skill Balance";Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OUT+"settings.png")
 editor.find_child("SkillBalanceReset",true,false).pressed.emit()
 check(Skills.value(game,"edo/volley","size")==1,"UI reset restores selected skill")
 game.load_settings();check(Skills.value(game,"edo/volley","size")==1,"Reset persists after reload")
 print("SKILL_BALANCE_RESULT checks=",checks," failures=",failures," releases=",total_releases)
 paused=false;game.paused=false
 game.queue_free();await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
