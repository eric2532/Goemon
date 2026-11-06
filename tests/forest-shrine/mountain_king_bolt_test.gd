extends "res://tests/forest-shrine/mountain_king_test.gd"
const REVIEW="res://build/Other Files/Asset Toolkit/Mountain King/Storm Bolt Auto Target/"
var phase="after"
func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 game.player.model.pose(game.player.active_ability.clip,game.player.active_ability.elapsed)
 RenderingServer.force_draw();await process_frame
 root.get_texture().get_image().save_png(REVIEW+phase+"-"+label_+".png")
func run():
 create_timer(180).timeout.connect(func():printerr("MOUNTAIN_BOLT_TIMEOUT");quit(1))
 if "--before" in OS.get_cmdline_user_args():phase="before"
 DirAccess.make_dir_recursive_absolute(REVIEW)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data);game.tuning.invincible=true
 home.y=game.model.surface_height(home.x,home.z)+.1
 game.camera_rig.set_process_unhandled_input(false)
 var p=game.player;var pool=Pool.service(game)
 pool.launched.connect(func(shot):
  if shot.get_script()==Shot:shot.set_physics_process(false))
 p.select_character(33);fresh();await advance(6)
 var kit=p.active_ability
 game.training_dummy.position=home+Vector3(0,0,100);game.training_dummy.home=game.training_dummy.position
 aim_at(home+Vector3(0,4,-30))
 kit.start_bolt();await advance(12)
 game.camera_rig.camera.global_position=home+Vector3(22,16,28)
 game.camera_rig.camera.look_at(home+Vector3(0,7,0))
 await capture("throw-windup");await advance(11)
 check(pool.all[pool.key_for(p,Shot,"bolt")].all(func(s):return not s.pool_live),"Throw retains .4-second release point")
 await advance(2)
 var shot=pool.all[pool.key_for(p,Shot,"bolt")].filter(func(s):return s.pool_live)[0]
 check(shot.target==null,"Open-ground throw has no homing target")
 check(is_equal_approx(shot.global_position.y-p.global_position.y,1.6),"Release restores original 1.6-metre height")
 check(is_zero_approx(shot.velocity.y),"Empty throw has no artificial upward tilt")
 check(is_equal_approx(shot.velocity.length(),30),"Throw keeps original speed")
 await capture("throw-release")
 # Inspect the solid team patch, separately from the additive blue spell glow.
 var team_surfaces=0
 for frame_ in shot.visual.clips.Birth.frames:
  for surface in frame_.get_surface_count():
   var mat=frame_.surface_get_material(surface)
   if mat.blend_mode==BaseMaterial3D.BLEND_MODE_ADD:continue
   var texture=mat.albedo_texture.get_image()
   if texture.is_compressed():texture.decompress()
   var pixel=texture.get_pixel(texture.get_width()/2,texture.get_height()/2)*mat.albedo_color
   if texture.get_width()<=8:
    team_surfaces+=1;check(pixel.b>pixel.r*2,"Solid hammer team layer is blue")
 check(team_surfaces>0,"Recovered hammer team layer remains visible")
 pool.release_owner(p);kit.cancel();kit.clear_cooldowns()
 var row=game.model.waves.spawn_enemy(0,home+Vector3(0,0,8));row.hp=10000;row.max_hp=10000
 var further=game.model.waves.spawn_enemy(0,home+Vector3(0,0,-20));further.hp=10000;further.max_hp=10000
 var owner=game.army_runtime;owner.import_arrivals();owner.sync_targets()
 var victim=game.actors[row.id];var hp=victim.hp
 aim_at(home+Vector3(0,4,-30))
 kit.start_bolt()
 check(kit.target==victim,"Closest enemy behind player beats farther enemy under aim")
 check(p.facing.z>.99,"Throw animation faces automatically selected enemy")
 kit.cancel();kit.clear_cooldowns()
 # A closer enemy behind solid cover must not steal the automatic lock.
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(8,8,.3)
 wall.add_child(shape);game.add_child(wall);wall.position=home+Vector3(0,3,4)
 await physics_frame;await physics_frame
 kit.start_bolt();check(kit.target==game.actors[further.id],"Auto lock skips closer enemy behind solid cover")
 kit.cancel();kit.clear_cooldowns();wall.free();await physics_frame
 kit.start_bolt();await advance(30)
 shot=pool.all[pool.key_for(p,Shot,"bolt")].filter(func(s):return s.pool_live)[0]
 check(shot.target==victim,"Released hammer homes behind player without manual aim")
 game.camera_rig.camera.global_position=shot.position+Vector3(5,3,7);game.camera_rig.camera.look_at(shot.position)
 await capture("hammer-flight")
 await advance(65);check(victim.hp<hp,"Homing still reaches exact native contact")
 check(owner.unit_state(victim.handle).stun>4,"Homing retains stun delivery")
 var created=pool.created;var misses=pool.misses
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 12:
  kit.cancel();kit.clear_cooldowns();kit.start_bolt();await advance(100)
 check(pool.created==created and pool.misses==misses,"Repeated throws reuse prepared leases")
 var node_delta=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes
 var resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 check(node_delta<=0 and resource_delta<=0,"Repeated throws retain no extra nodes or resources")
 # Concurrent native-owned allies use the same automatic selection and homing.
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
 check(mirrors.cast(),"Five native allies prepare existing Mountain King kit")
 created=pool.created;misses=pool.misses;hp=victim.hp
 for body in mirrors.bodies:
  body.position=home;body.ai_aim=victim.position;body.active_ability.start_bolt()
 for i in 100:
  mirrors.tick(1.0/60)
  await advance(1)
 check(victim.hp<hp,"Concurrent allied Storm Bolts damage native targets")
 check(pool.created==created and pool.misses==misses,"Concurrent allies keep prepared pool stable")
 mirrors.clear();mirrors.dispose()
 p.select_character(1);fresh();await advance(6)
 game.training_dummy.position=home+Vector3(0,0,100);game.training_dummy.home=game.training_dummy.position
 p.spell_loadout.equip(1,"equip","mountain-king/storm-bolt")
 aim_at(home+Vector3(0,4,-30));hp=victim.hp
 tap("equip");await advance(100)
 check(victim.hp<hp,"Borrowed Storm Bolt also finds nearest enemy behind player")
 p.spell_loadout.equip(1,"equip","")
 steps.sort()
 var report={"checks":checks,"failures":failures,"pool_created":pool.created,"pool_misses":pool.misses,"repeat_node_delta":node_delta,"repeat_resource_delta":resource_delta,"manual_step_p95_ms":steps[int(steps.size()*.95)],"manual_step_max_ms":steps[-1]}
 FileAccess.open(REVIEW+phase+"-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MOUNTAIN_BOLT_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
