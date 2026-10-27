extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Shot=preload("res://scripts/recovered_enemy_projectile.gd")
const OUT="res://build/Other Files/Asset Toolkit/Dark Lumina 2/Fire Breath/"
var released=0
var casting=true
var samples=[]
var intervals=[]
var previous=0
var focused=0
var stepped=0
func advance(count:int):
 for i in count:
  var start=Time.get_ticks_usec()
  game.player._physics_process(1.0/60)
  for nodes in Pool.service(game).all.values():
   for shot in nodes:
    if shot.pool_live and shot.get_script()==Shot:shot._physics_process(1.0/60)
  game.crowd.army.presentation.tick(1.0/60)
  samples.append((Time.get_ticks_usec()-start)/1000.0)
  stepped+=1
  if root.has_focus():focused+=1
  await physics_frame
  var now=Time.get_ticks_usec()
  if previous>0:intervals.append((now-previous)/1000.0)
  previous=now
func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Rendered "+label_)
 previous=0
func run():
 create_timer(120).timeout.connect(func():printerr("FIRE_BREATH_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var map=preload("res://scripts/forest/forest_map_document.gd").new();map.load_wind_meadow();await setup_fixture(map.data)
 game.set_process(false);game.army_runtime.set_physics_process(false)
 game.tuning.invincible=true
 if DisplayServer.get_name()!="headless":
  root.title="Goemon · Dark Lumina 2 fire breath";root.set_flag(Window.FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
 var p=game.player;p.select_character(Dark.PLAYER);fresh()
 var home=Vector3(0,game.model.surface_height(0,140)+.1,140);p.position=home
 game.training_dummy.position=home+Vector3(0,0,-90);game.training_dummy.home=game.training_dummy.position
 game.ui.hide();game.forest_ui.hide();p.model.show()
 game.camera_rig.camera.global_position=home+Vector3(45,28,-54);game.camera_rig.camera.look_at(home+Vector3(0,7,-20))
 var fx=game.crowd.army.presentation;var pool=Pool.service(game)
 var atlas=Dark.meshes.ember.material.get_shader_parameter("atlas")
 check(atlas==Dark.meshes.fire.material.get_shader_parameter("atlas") and Dark.meshes.ember.size==Dark.meshes.fire.size,"Charge reuses the intact round flame strip and its aspect ratio")
 var pixels:Image=atlas.get_image()
 for frame in 16:
  var transparent=0
  for y in 32:
   for x in 32:
    if pixels.get_pixel(x,frame*32+y).a<.01:transparent+=1
  check(transparent>32*32*.35,"Charge frame %d has a transparent flame silhouette"%frame)
 check(is_equal_approx(rad_to_deg(Dark.FIRE_SPREAD),35.15625) and is_equal_approx(Dark.native()[10],Dark.FIRE_SPREAD),"Player and native enemies share the wider 70.3125-degree fan")
 for yaw in [0.0,PI/2]:
  fx.clear();fx.dark_cue(home,1,yaw,0,1,1,false)
  check(fx.effects.size()==1 and fx.effects[0].position.is_equal_approx(home+Basis(Vector3.UP,yaw)*Dark.MOUTH),"Charge sits at the mouth for facing "+str(yaw))
 fx.clear()
 pool.launched.connect(func(shot):
  if shot.get("kind")!="dark_lumina":return
  shot.set_physics_process(false)
  if not casting:return
  released+=1
  var direction:Vector3=(shot.aim-shot.position).normalized()
  var heading:Vector3=shot.velocity.normalized()
  check(is_equal_approx(Vector2(direction.x,direction.z).angle_to(Vector2(heading.x,heading.z))**2,Dark.FIRE_SPREAD**2),"Release retains the widened symmetric fan")
  check(is_equal_approx(shot.velocity.length(),51.84) and is_equal_approx(shot.lifetime,3.5) and is_equal_approx(shot.visual.mesh.size.x,20.7),"Release preserves speed, lifetime and full sprite size"))
 var created=pool.created;var misses=pool.misses
 var resource_samples=[]
 var nodes=fx.get_child_count()
 for cast in 3:
  p.active_ability.start_dark_attack(Dark.FIRE)
  await advance(10)
  if cast==0:await capture("charge")
  await advance(65)
  if cast==0:await capture("outward-fire")
  await advance(225)
  resource_samples.append(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
  check(released==(cast+1)*12,"Repeated cast %d emits all six pairs"%cast)
 check(pool.created==created and pool.misses==misses,"Repeated fire reuses the prepared projectile pool")
 check(fx.get_child_count()==nodes and resource_samples[0]==resource_samples[1] and resource_samples[1]==resource_samples[2],"Repeated fire retains prepared presentation nodes and resources after the first cast: "+str(resource_samples))
 p.select_character(1);fresh();p.position=home
 check(p.spell_loadout.equip(1,"equip","dark-lumina-2/fireballs"),"Another fighter equips the same fire breath")
 tap("equip");await advance(300)
 check(released==48 and p.character_id==1 and p.spell_loadout.current==null,"Borrowed fire completes twelve releases and restores its owner")
 check(pool.all.values().all(func(leases):return leases.all(func(shot):return not shot.pool_live and shot.get("target")==null)),"All leases retire and clear targets")
 contacts.clear();casting=false
 var point=preload("res://scripts/attack_chain.gd").aim_point(game.training_dummy,home)
 var hit_shot=pool.launch(p,Shot,"dark_lumina",{"kind":"dark_lumina","position":point+Vector3.BACK*10,"velocity":Vector3.FORWARD*Dark.FIRE_SPEED,"aim":point,"lifetime":Dark.FIRE_LIFE,"damage":1.0,"attack_ticket":p.attack_chain.begin("fireball")})
 # This direct contact has no scatter; its launch is outside the cast-angle assertion.
 await advance(30)
 check(not hit_shot.pool_live and contacts.size()==1,"Fire hits a real target exactly once and retires")
 await capture("impact")
 # Exercise real native releases from twelve bosses without adding another simulation.
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 check(runtime.native.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model)),"Native army accepts the shared fire tuning")
 runtime.set_navigation(20,{"width":0})
 for i in 12:
  var at=home+Vector3((i%4-1.5)*60,0,-floori(i/4.0)*60)
  runtime.spawn(100+i,0,Dark.ROLE,at,5000,12.096)
  runtime.spawn(200+i,1,12,at+Vector3(0,0,-25),100000,.4)
 var native_releases=0;var peak=0;var checked_sources={}
 for frame in 210:
  runtime.step(1.0/60,{})
  var events=runtime.take_events();fx.present(events)
  for event in events:
   if event.kind=="status" and event.unit_kind==Dark.ROLE and event.action_index==207:native_releases+=1
  var snapshot=runtime.snapshot();peak=maxi(peak,snapshot.projectile_ids.size());fx.present_snapshot(snapshot)
  for index in range(1,snapshot.projectile_ids.size()):
   var source_id:int=snapshot.projectile_sources[index]
   if checked_sources.has(source_id) or snapshot.projectile_sources[index-1]!=source_id:continue
   var a:Vector3=snapshot.projectile_directions[index-1];var b:Vector3=snapshot.projectile_directions[index]
   check(absf(absf(Vector2(a.x,a.z).angle_to(Vector2(b.x,b.z)))-2*Dark.FIRE_SPREAD)<.001,"Native pair shares the player's wider fan")
   checked_sources[source_id]=true
  fx.tick(1.0/60)
  if frame==70:await capture("native-simultaneous")
  await physics_frame
 check(native_releases==72 and peak>=24,"Twelve native bosses each release six pairs simultaneously")
 check(checked_sources.size()==12,"Wider pair directions verified for all twelve native casters")
 check(fx.get_child_count()==nodes,"Simultaneous native fire retains the prepared presentation nodes")
 runtime.clear();runtime.free();fx.clear()
 samples.sort();intervals.sort()
 var report={"checks":checks,"failures":failures,"shots":released,"native_release_pairs":native_releases,"native_projectile_peak":peak,"pool_created":pool.created,"pool_misses":pool.misses,"resource_samples_after_casts":resource_samples,"focused_frames":focused,"stepped_frames":stepped,"cpu_step_p95_ms":samples[int(samples.size()*.95)],"frame_interval_p95_ms":intervals[int(intervals.size()*.95)],"frame_interval_max_ms":intervals.back(),"note":"Focused manual player/native correctness and rendered review; not a full-world FPS benchmark or long-session soak"}
 FileAccess.open(OUT+"results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("FIRE_BREATH_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(4);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
