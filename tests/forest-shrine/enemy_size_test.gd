extends SceneTree
const Balance=preload("res://scripts/forest/core_balance.gd")
const Kits=preload("res://scripts/forest/crowd/army_kit_data.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var checks=0
var failures=0
var cfg="user://enemy-size-test-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func settle():
 for i in 4:await process_frame
func run():
 check(Balance.sanitized({}).enemy_size_mult==1.0,"Old saves retain the current enemy size")
 check(Balance.sanitized({"enemy_size_mult":NAN}).enemy_size_mult==1.0,"Nonfinite size settings use the default")
 check(Balance.sanitized({"enemy_size_mult":-2}).enemy_size_mult==.25 and Balance.sanitized({"enemy_size_mult":999}).enemy_size_mult==3,"Size stays within supported limits")
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await settle()
 game.show_core_balance(false)
 var control=game.menu.find_child("Core_enemy_size_mult",true,false)
 check(control is SpinBox,"Core Game Balance exposes the enemy size control")
 control.value=2.5;game.load_settings()
 check(game.core_balance.enemy_size_mult==2.5 and game.model.balance.enemy_size_mult==1.0,"Size saves to disk without changing the current run")
 game.show_title();game.begin_forest();game.choose_rogue_character(1)
 check(game.model.balance.enemy_size_mult==2.5 and game.army_runtime.enemy_size==2.5,"A new run applies the saved size")
 check(is_equal_approx(game.crowd.army.meshes[0].surface_get_material(0).get_shader_parameter("enemy_size"),2.5),"Renderer starts with the saved size")
 game.update_core_balance("enemy_size_mult",.5)
 var revision=game.model.navigation_revision
 game.start_wave();game.army_runtime.refresh_kits()
 check(game.model.balance.enemy_size_mult==.5 and game.model.navigation_revision>revision,"The next wave applies the edited size and invalidates old routes")
 game.update_core_balance("enemy_size_mult",1.0)
 check(game.model.balance.enemy_size_mult==.5,"Editing during a wave preserves all live enemy sizes")
 game.set_physics_process(false);game.army_runtime.set_process(false)
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 for size in [.25,1.0,3.0]:
  game.model.balance.enemy_size_mult=size
  var data=Kits.from_model(game.model)
  runtime.clear();runtime.set_navigation(int(size*100),{"width":0});runtime.configure_kits(data);game.crowd.army.configure_profiles(data)
  check(is_equal_approx(game.crowd.army.presentation.enemy_size,size),"Death effects follow size %.2f"%size)
  for kind in [0,1,3]:
   var profile=game.model.waves.role_stats(kind);var base=Roles.stats(kind)
   var row=game.model.waves.spawn_enemy(kind,Vector3.ZERO)
   check(Roles.hurt_point(row,Vector3.UP*10).is_equal_approx(Vector3.UP*2.016*size),"Kind%d model-owned tower contacts follow size %.2f"%[kind,size])
   check(is_equal_approx(profile.range,base.range*(1 if kind==1 else size)) and is_equal_approx(profile.stride,base.stride*size),"Kind%d scales its reach and gait at %.2f"%[kind,size])
   var handle:int=runtime.spawn(kind+1,0,kind,Vector3(kind*20,0,0),100,Roles.footprint_radius(kind,size))
   var actor=load("res://scripts/forest/crowd/army_enemy_target.gd").new();actor.runtime=runtime;actor.handle=handle;actor.variant=kind;root.add_child(actor);actor.sync(runtime.unit_state(handle))
   check(actor.combat_bounds().size.is_equal_approx(Vector3(1.152,2.016,2.304)*size),"Kind%d query bounds match size %.2f"%[kind,size])
   check(actor.get_child(0).shape.size.is_equal_approx(actor.combat_bounds().size),"Kind%d physics hitbox matches combat bounds"%kind)
   var top=actor.global_position+Vector3.UP*2.016*size
   check(actor.combat_contact_point(top+Vector3.UP).is_equal_approx(top),"Kind%d fitted contacts use the scaled body"%kind)
   check(is_equal_approx(game.crowd.army.meshes[kind].surface_get_material(0).get_shader_parameter("enemy_size"),size),"Kind%d rendered poses use size %.2f"%[kind,size])
   check(actor.combat_segment_hit(actor.global_position+Vector3(0,size,-10),actor.global_position+Vector3(0,size,10),0),"Kind%d scaled body accepts an intersecting attack"%kind)
   check(not actor.combat_segment_hit(top+Vector3(0,.01,-10),top+Vector3(0,.01,10),0),"Kind%d scaled body rejects attacks above its head"%kind)
   actor.free()
  check(Roles.height(2,size)==23.1 and Roles.height(4,size)==25,"Special enemies retain their own size")
  runtime.clear();var gun:int=runtime.spawn(1,0,1,Vector3.ZERO,100,1.3*size)
  var targets={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,0,-10)]),"hp":PackedFloat32Array([500])}
  runtime.step(.8,{"targets":targets})
  var bullets=runtime.take_events().filter(func(e):return e.kind=="bullet")
  check(not bullets.is_empty() and is_equal_approx(bullets[0].position.y,1.44*size),"Gun muzzle follows size %.2f"%size)
  var snapshot=runtime.render_snapshot()
  check(snapshot.projectile_scales.size()>0 and is_equal_approx(snapshot.projectile_scales[0],size),"Native bullet presentation follows size %.2f"%size)
 var invalid=Kits.from_model(game.model);invalid.enemy_size=NAN
 check(not runtime.native.configure_kits(invalid),"Native profile validation rejects nonfinite sizes")
 runtime.free()
 game.show_pause();game.show_settings(true);game.show_core_balance(true);await settle()
 if "--capture" in OS.get_cmdline_user_args() and RenderingServer.get_rendering_device()!=null:
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/enemy-size-control.png")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await settle()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("ENEMY_SIZE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
