extends "res://tests/forest-shrine/mountain_king_test.gd"
const REVIEW="res://build/Other Files/Mountain King Slam/"
var input_steps=[]
func press_two():
 var event=InputEventKey.new();event.physical_keycode=KEY_2;event.pressed=true
 var started=Time.get_ticks_usec()
 game.player._unhandled_input(event);game.player.spell_loadout.number_input(2,false)
 input_steps.append((Time.get_ticks_usec()-started)/1000.0)
func capture_slam(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();game.camera_rig.camera.global_position=home+Vector3(15,42,-48);game.camera_rig.camera.look_at(home+Vector3(6,0,0))
 var kit=game.player.active_ability
 game.player.model.pose(kit.clip,kit.elapsed);RenderingServer.force_draw();await process_frame
 check(root.get_texture().get_image().save_png(REVIEW+label_+".png")==OK,"Captured "+label_+" in painterly gameplay")
func run():
 create_timer(180).timeout.connect(func():printerr("MOUNTAIN_SLAM_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(REVIEW)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data);game.tuning.invincible=true;game.set_process(false)
 game.camera_rig.set_process_unhandled_input(false)
 var p=game.player;var owner=game.army_runtime;var pool=Pool.service(game)
 # Certify open, level ground so terrain/cover cannot masquerade as a radius failure.
 var found=false
 for point in [Vector3(-150,0,150),Vector3(-150,0,-100),Vector3(130,0,130),Vector3(130,0,-130)]:
  point.y=game.model.surface_height(point.x,point.z)+.1
  var clear=true
  for distance in [18,20.5,25,29.5,35.5,38]:
   var other=point+Vector3(distance,0,0)
   clear=clear and absf(game.model.surface_height(other.x,other.z)+.1-point.y)<.2 and AttackChain.clear_line(p,point+Vector3.UP*.2,other+Vector3.UP*.2)
  if clear:home=point;found=true;break
 check(found,"Radius fixture uses unobstructed level Wind Meadow ground")
 if not found:game.queue_free();await frames(3);quit(1);return
 p.select_character(33);fresh();await advance(6)
 var kit=p.active_ability
 game.training_dummy.home=home+Vector3(0,0,100);game.training_dummy.position=game.training_dummy.home
 var victims=[]
 for distance in [18,38]:
  var row=game.model.waves.spawn_enemy(0,home+Vector3(distance,0,0));row.hp=10000;row.max_hp=10000
  victims.append(row.id)
 owner.import_arrivals();owner.sync_targets()
 var inside=game.actors[victims[0]];var outside=game.actors[victims[1]]
 for level in [1,3,5]:
  p.team_progression.level=level;kit.cancel();kit.clear_cooldowns()
  var radius=[22.5,27.0,31.5][kit.rank()-1]
  owner.set_pose(inside.handle,home+Vector3(radius-2,0,0),0)
  owner.set_pose(outside.handle,home+Vector3(radius+4,0,0),0);owner.sync_targets()
  var hp=inside.hp;var untouched=outside.hp
  kit.start_attack();kit.queued=true;press_two()
  check(kit.mode=="clap" and kit.released and kit.elapsed==kit.contact and is_equal_approx(p.attack_left,kit.duration-kit.contact),"Key 2 interrupts queued melee and skips directly to impact at rank "+str(kit.rank()))
  check(inside.hp<hp and outside.hp==untouched,"Exact native contact uses the tripled radius "+str(radius))
  check(owner.unit_state(inside.handle).slow_factor==.5,"Immediate slam preserves native slow")
  check(kit.clap_fx.scale.is_equal_approx(Vector3.ONE*.09),"Ground effect is three times its former scale")
  hp=inside.hp;press_two()
  check(inside.hp==hp and kit.clap_cooldown==6,"Busy repeat obeys the existing six-second cooldown")
  await advance(20)
  if level==5:await capture_slam("normal-slam")
  await advance(10)
  check(inside.hp==hp,"The former cast point never delivers a duplicate hit")
  kit.cancel(true);await advance(60)
  check(inside.hp==hp,"Cancelled melee and queued swing never land after the slam")
 kit.cancel();kit.clear_cooldowns()
 owner.set_pose(inside.handle,home+Vector3(18,5,0),0);owner.sync_targets()
 var airborne_hp=inside.hp;press_two()
 check(inside.hp==airborne_hp,"Enlarged ground slam excludes airborne enemies")
 kit.cancel();kit.clear_cooldowns();owner.set_pose(inside.handle,home+Vector3(18,0,0),0);owner.sync_targets()
 var wall=StaticBody3D.new();wall.collision_layer=1
 var collider=CollisionShape3D.new();collider.shape=BoxShape3D.new();collider.shape.size=Vector3(.2,10,12)
 wall.add_child(collider);game.add_child(wall);wall.position=home+Vector3(10,4,0)
 await physics_frame;await physics_frame
 var covered_hp=inside.hp;press_two()
 check(inside.hp==covered_hp,"Enlarged slam cannot damage enemies through solid cover")
 wall.free()
 # Active casts can be interrupted too; an unreleased hammer must never launch later.
 kit.cancel();kit.clear_cooldowns();kit.start_bolt();press_two()
 check(kit.mode=="clap" and kit.target==null,"Slam cancels a pending Storm Bolt and clears its target")
 await advance(90)
 check(pool.all[pool.key_for(p,Shot,"bolt")].all(func(shot):return not shot.pool_live),"Interrupted Storm Bolt never launches")
 kit.cancel();kit.clear_cooldowns();kit.start_avatar();kit.start_attack();press_two()
 check(kit.mode=="clap" and kit.clip=="Alternate Spell Slam" and kit.demon,"Avatar slam interrupts melee without losing Avatar")
 await advance(6)
 await capture_slam("avatar-slam-start");await advance(14);await capture_slam("avatar-slam")
 kit.cancel();kit.clear_cooldowns();p.set_auto_attack(true);await advance(1);press_two();p.set_auto_attack(false)
 check(kit.mode=="clap","Slam interrupts automatic melee")
 # Borrowed casts share the immediate damage path and permit their own active cast to restart.
 p.select_character(1);fresh();await advance(6)
 game.training_dummy.home=home+Vector3(0,0,100);game.training_dummy.position=game.training_dummy.home
 p.spell_loadout.equip(1,"equip","mountain-king/thunder-clap")
 var borrowed=p.spell_loadout.instances["1:mountain-king/thunder-clap"]
 var hp=inside.hp;tap("light_attack");tap("equip")
 check(borrowed.controller.released and inside.hp<hp,"Borrowed slam interrupts the receiving fighter and hits on input")
 borrowed.controller.clear_cooldowns();hp=inside.hp;tap("equip")
 check(borrowed.controller.elapsed==borrowed.controller.contact and inside.hp<hp,"Borrowed slam can interrupt its own animation when cooldowns permit")
 p.spell_loadout.equip(1,"equip","")
 p.select_character(33);fresh();await advance(6);kit=p.active_ability
 for id in victims:owner.despawn(owner.handles[id])
 owner.integration_tick(1.0/60)
 # Warm shared native mirrors once, then measure repeated and simultaneous use.
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
 check(mirrors.cast(),"Five native-owned allies reuse the slam controller")
 await physics_frame;await physics_frame
 for body in mirrors.bodies:
  body.position=home;body.velocity=Vector3.DOWN*20
  for i in 3:body.move_and_slide()
  body.set_auto_attack(false);body.active_ability.start_attack();body.press("surge");body.release()
  check(body.active_ability.mode=="clap" and body.active_ability.released,"Allied slam immediately interrupts its pending melee")
 mirrors.clear();mirrors.dispose();await advance(120)
 kit.cancel();kit.clear_cooldowns();kit.start_attack();press_two();await advance(120)
 await create_timer(1.5).timeout
 var created=pool.created;var misses=pool.misses;var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 12:
  kit.cancel();kit.clear_cooldowns();kit.start_attack();press_two();await advance(120)
 await create_timer(1.5).timeout
 check(pool.created==created and pool.misses==misses,"Repeated slams require no extra projectile allocations")
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated slams retain no additional nodes/resources (nodes=%s→%s, resources=%s→%s)"%[nodes,get_node_count(),resources,Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
 kit.cancel();kit.clear_cooldowns();p.position=home+Vector3.UP*8;p.velocity=Vector3.UP;p.move_and_slide();press_two()
 check(kit.mode.is_empty(),"Ground slam retains its grounded requirement")
 steps.sort();input_steps.sort()
 var report={"checks":checks,"failures":failures,"manual_step_p95_ms":steps[int(steps.size()*.95)],"manual_step_max_ms":steps[-1],"input_p95_ms":input_steps[int(input_steps.size()*.95)],"input_max_ms":input_steps[-1],"pool_misses":pool.misses}
 FileAccess.open(REVIEW+"slam-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MOUNTAIN_SLAM_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
