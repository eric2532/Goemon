extends SceneTree
const Flight=preload("res://assets/rogue/scripts/dragoon_dragon_flight.gd")
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Renderer=preload("res://scripts/forest/crowd/army_renderer.gd")
var out="res://build/Other Files/Asset Toolkit/Dragoon Hunt"
var checks=0
var failures=0
var game
var visual=false
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func run():
 visual="--visual" in OS.get_cmdline_user_args()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
 var mesh=preload("res://assets/rogue/effects/dragoon_energy_dragon.res")
 check(mesh.get_surface_count()==1 and mesh.get_aabb().size.x>18,"Armored winged dragon remains one shared mesh surface")
 var colors:PackedColorArray=mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
 check(Array(colors).any(func(c):return c.r>.8 and c.g<.15),"The baked dragon has red eyes")
 var arrays=mesh.surface_get_arrays(0)
 check(arrays[Mesh.ARRAY_INDEX].size()/3<16000,"The dragon stays within its single-mesh geometry budget")
 check(Array(arrays[Mesh.ARRAY_VERTEX]).all(func(p):return p.is_finite()),"Baked dragon positions are finite")
 check(Array(colors).any(func(c):return c.a<.5) and Array(colors).any(func(c):return c.a>.5),"Only wing geometry uses the flap channel")
 check(Array(arrays[Mesh.ARRAY_NORMAL]).all(func(n):return n.is_finite() and absf(n.length()-1)<.01),"Baked normals remain finite and normalized")
 var flight=Basis(Vector3(1,0,0),Vector3(0,.573576,.819152),Vector3(0,-.819152,.573576))
 var inside=true
 for i in arrays[Mesh.ARRAY_VERTEX].size():
  var point:Vector3=flight*(arrays[Mesh.ARRAY_VERTEX][i]-Vector3(0,7,0))+Vector3(0,2.5,-3)
  for angle in [-.16,.16]:
   var posed=point
   if colors[i].a<.5:
    var hinge=Vector3(signf(point.x)*1.35,2.7,point.z)
    posed=hinge+(point-hinge).rotated(Vector3.BACK,angle*signf(point.x))
   inside=inside and mesh.custom_aabb.has_point(posed) and mesh.custom_aabb.has_point(flight.inverse()*(posed-Vector3(0,2.5,-3))+Vector3(0,7,0))
 check(inside,"Culling bounds contain both flight and attached poses at both wing extremes")
 if "--design-only" in OS.get_cmdline_user_args():
  await design_preview();quit();return
 await native_hunt()
 await player_hunt()
 print("DRAGOON_HUNT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func native_hunt():
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 var data=load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model)
 data.ally_profiles[data.ally_kinds.find(8)*5+4]=0.0
 var r=Runtime.new();r.configure(null);r.configure_kits(data);r.set_navigation(1,{"width":0})
 var renderer=Renderer.new();root.add_child(renderer);renderer.configure(null);renderer.configure_profiles(data)
 var node_count=renderer.presentation.get_child_count()
 var camera:Camera3D
 var timings=[];var frame_times=[];var focus=0;var previous=Time.get_ticks_usec()
 if visual:
  camera=Camera3D.new();root.add_child(camera);camera.current=true;camera.position=Vector3(0,80,135);camera.look_at(Vector3(0,3,0))
  DisplayServer.window_move_to_foreground()
  if "--await-focus" in OS.get_cmdline_user_args():
   var deadline=Time.get_ticks_msec()+30000
   while not DisplayServer.window_is_focused() and Time.get_ticks_msec()<deadline:await process_frame
   check(DisplayServer.window_is_focused(),"Desktop measurement starts in the foreground")
  previous=Time.get_ticks_usec()
 var resources_before=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var positions=[];var hits=[];var source=0
 for cycle in 3:
  r.clear();renderer.clear()
  for i in 8:
   var x=(i%4-1.5)*45
   var z=floori(i/4.0)*50-25
   for j in 3:
    var target=r.spawn(i*10+j+1,0,0,Vector3(x+(j-1)*8,0,z),100000,3.9)
    r.apply_hit(target,{"element":"ice","status_seconds":100})
   r.spawn(-i-1,1,8,Vector3(x,12.12,z),200,.4)
  var first=-1;var last=-1;var max_dragons=0;hits=[];positions=[]
  for frame in 210:
   var started=Time.get_ticks_usec()
   r.step(1.0/60,{})
   timings.append((Time.get_ticks_usec()-started)/1000.0)
   var events=r.take_events();var s=r.render_snapshot()
   for e in events:
    if e.kind=="damage" and e.heavy and e.source_id==-1:hits.append([frame,e.target_id,e.amount])
   var ids=[]
   for i in s.projectile_kinds.size():
    if s.projectile_kinds[i]==8:
     ids.append(i)
     if s.projectile_sources[i]==-1:positions.append(s.projectile_positions[i])
   if not ids.is_empty():
    if first<0:first=frame
    last=frame
   max_dragons=maxi(max_dragons,ids.size())
   renderer.present(s,events)
   if visual:
    await process_frame
    var now=Time.get_ticks_usec()
    if frame>20:frame_times.append((now-previous)/1000.0);focus+=int(DisplayServer.window_is_focused())
    previous=now
    if frame==55 and cycle==0:await capture("native-eight")
   if frame==55:
    check(renderer.presentation.projectile_batches.dragon.multimesh.visible_instance_count==8,"Eight simultaneous native dragons use their shared projectile batch")
   if frame==35:
    # Released casts survive owner retirement, with no stale slot ownership.
    source=r.render_snapshot().logical_ids.find(-1)
    var handle=r.render_snapshot().handles[source];r.despawn(handle);r.spawn(-99,1,11,Vector3(900,0,0),100,.4)
  print("NATIVE_HUNT_CYCLE ",cycle," first=",first," last=",last," max=",max_dragons," hits=",hits)
  check(max_dragons==8 and last-first>=177 and last-first<=180,"Native dragons last three seconds after landing, cycle %d"%cycle)
  check(hits.size()>=3 and hits.all(func(h):return is_equal_approx(h[2],Flight.DAMAGE*data.ally_profiles[data.ally_kinds.find(8)*5+2])),"Native dash hits retain their landing damage snapshot")
  var unique={}
  for h in hits:unique[h[1]]=true
  check(unique.size()>=2,"Native dragon changes targets and keeps hunting after caster retirement")
  var safe=true
  for i in hits.size():
   for j in range(i):
    if hits[i][1]==hits[j][1] and floori((hits[i][0]-first)/21.0)==floori((hits[j][0]-first)/21.0):safe=false
  check(safe,"A native dragon cannot apply damage every frame to the same victim")
  check(positions.size()>100 and positions[0].distance_to(positions[50])>2,"Dragon travels across the battlefield")
  check(renderer.presentation.get_child_count()==node_count and renderer.presentation.projectile_batches.dragon.multimesh.visible_instance_count==0,"Native expiry reuses the same presentation nodes")
 # A solid separating the landing from a victim blocks the hunt and its damage.
 r.clear();r.set_navigation(2,{"width":0,"obstacle_min":PackedVector3Array([Vector3(-50,0,3)]),"obstacle_max":PackedVector3Array([Vector3(50,40,4)])})
 var close=r.spawn(1,0,0,Vector3.ZERO,100000,3.9);r.apply_hit(close,{"element":"ice","status_seconds":100})
 var covered=r.spawn(2,0,0,Vector3(0,0,9),100000,3.9);r.apply_hit(covered,{"element":"ice","status_seconds":100})
 r.spawn(-1,1,8,Vector3(0,12.12,0),200,.4);r.step(3.6,{})
 check(r.unit_state(covered).hp==100000,"Native hunting and shockwaves cannot damage through a wall")
 r.clear();renderer.clear();check(r.render_snapshot().projectile_ids.is_empty(),"Native reset removes all released dragons")
 var report={"checks":checks,"failures":failures,"simultaneous_dragons":8,"cycles":3,"native_step_ms":summary(timings),"rendered_frame_ms":summary(frame_times),"focus_frames":focus,"measured_frames":frame_times.size(),"resources_before":resources_before,"resources_after":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"presentation_nodes":node_count}
 var file=FileAccess.open(out+"/"+("native-desktop-profile.json" if visual else "native-headless-profile.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
 if camera!=null:camera.free()
 renderer.free();r.free();await process_frame
func player_hunt():
 var doc=load("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data);set_meta("forest_painterly_preview",true)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://dragoon-hunt-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 3:await process_frame
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false);game.army_runtime.set_process(false)
 game.tuning.critical_chance=0;game.player.select_character(8);game.player.set_auto_attack(false)
 var c=game.player.active_ability;c.set_process(false);c.cancel();c.reset_run()
 game.player.position=Vector3(0,.1,70);game.player.velocity=Vector3.ZERO;game.player.facing=Vector3.FORWARD
 for i in 30:c._move_body(1.0/120)
 c.player.pos=game.player.position;c.player.angle=PI
 game.model.update_vision(game.player.position)
 var foes=[]
 for offset in [Vector3(-8,0,-6),Vector3(8,0,-6),Vector3(0,0,5)]:
  var row=game.model.waves.spawn_enemy(0,game.player.position+offset);row.hp=100000;row.max_hp=100000;foes.append(row.id)
 game.army_runtime.integration_tick(1.0/60)
 for id in foes:game.army_runtime.apply_hit(game.army_runtime.handles[id],{"element":"ice","status_seconds":100})
 game.army_runtime.flush_presentation()
 c.begin_cast("secondary");var ticket=c.current_ticket()
 c.Actions.lance_impact(c,{"ticket":ticket,"rangeScale":c.range_scale()})
 check(c.projectiles.size()==1 and c.projectiles[0].kind=="dragon" and c.player.pulses.size()==2,"Real landing releases one hunting dragon plus the existing three shockwaves")
 var shot=c.projectiles[0];var node=shot.mesh
 var dive=c.fx.dragon_descent(game.player,c.player.angle,c.range_scale(),true)
 check(is_equal_approx(node.scale.x,dive.global_basis.get_scale().x),"The hunting dragon matches the diving dragon's full size")
 c.fx.finish_dragon_descent(dive)
 var hp=[]
 for id in foes:hp.append(game.army_runtime.unit_state(game.army_runtime.handles[id]).hp)
 for frame in 170:
  c.tick(1.0/60,false);c.fx.tick(1.0/60)
  if visual and frame in [12,48,128]:
   game.army_runtime.flush_presentation()
   var camera=game.camera_rig.camera;camera.global_position=game.player.position+Vector3(20,18,27);camera.look_at(game.player.position+Vector3(0,4,-2));camera.current=true
   game.ui.hide();await capture("hunt-%d"%frame)
 check(c.projectiles.size()==1,"Dragon is still active after 2.8 seconds")
 var damaged=0
 for i in foes.size():
  if game.army_runtime.unit_state(game.army_runtime.handles[foes[i]]).hp<hp[i]:damaged+=1
 check(damaged>=2,"Player dragon deals additional heavy damage to multiple native enemies")
 for frame in 12:c.tick(1.0/60,false);c.fx.tick(1.0/60)
 check(c.projectiles.is_empty() and is_instance_valid(node) and node.get_meta("army_projectile_parked",false),"Three-second expiry returns the dragon to the existing projectile cache")
 for id in foes:game.army_runtime.despawn(game.army_runtime.handles[id])
 c.fx.clear();await process_frame
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for cycle in 10:
  Flight.launch(c,{"ticket":ticket,"rangeScale":1.0});var reused=c.projectiles.back()
  check(reused.mesh==node and reused.hits.is_empty() and reused.age==0 and reused.lastTarget==0,"Reuse resets target, hit history, clock and presentation")
  c.tick(3.1,false)
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+2,"Repeated dragon casts do not create new meshes or materials")
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(80,40,1);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=game.player.position+Vector3(0,19,4)
 var covered=game.model.waves.spawn_enemy(0,game.player.position+Vector3(0,0,10));covered.hp=100000;covered.max_hp=100000
 game.army_runtime.integration_tick(1.0/60)
 var covered_handle=game.army_runtime.handles[covered.id];game.army_runtime.apply_hit(covered_handle,{"element":"ice","status_seconds":100})
 await physics_frame
 Flight.launch(c,{"ticket":ticket,"rangeScale":1.0});c.tick(3.1,false)
 check(game.army_runtime.unit_state(covered_handle).hp==100000,"Player dragon cannot target or damage through physical cover, including a long frame")
 wall.free()
 Flight.launch(c,{"ticket":ticket,"rangeScale":1.0});game.player.select_character(11)
 check(c.projectiles.is_empty() and node.get_meta("army_projectile_parked",false),"Changing character cancels the released dragon and clears its lease")
 if visual:
  var display=c.fx._dragon_mesh("DragonDesignReview",1.0);game.add_child(display);display.position=game.player.position;display.material_override.set_shader_parameter("hunting",true);display.material_override.set_shader_parameter("flow_time",.3)
  var camera=game.camera_rig.camera;camera.global_position=display.position+Vector3(22,13,25);camera.look_at(display.position+Vector3(0,2,-3));await capture("design");display.free()
 game.sound_library.cancel();game.music.stop();var cfg=game.settings_path;game.free();paused=false;await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
func capture(label_:String):
 await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+label_+".png")

func design_preview():
 var world=Node3D.new();root.add_child(world)
 var environment=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("b1ada7");environment.environment=env;world.add_child(environment)
 var fx=load("res://assets/rogue/scripts/effects.gd").new();world.add_child(fx)
 var dragon=fx._dragon_mesh("Design",1.0);world.add_child(dragon);dragon.material_override.set_shader_parameter("hunting",true);dragon.material_override.set_shader_parameter("flow_time",.3)
 var camera=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=32
 for view in [["design-studio",Vector3(17,10,20)],["side",Vector3(29,7,-2)],["front",Vector3(0,7,32)],["back",Vector3(19,12,-28)]]:
  camera.position=view[1];camera.look_at(Vector3(0,2,-3));await capture(view[0])
 world.free()

func summary(values:Array)->Dictionary:
 if values.is_empty():return {}
 var sorted=values.duplicate();sorted.sort()
 return {"median":sorted[sorted.size()/2],"p95":sorted[mini(sorted.size()-1,floori(sorted.size()*.95))],"p99":sorted[mini(sorted.size()-1,floori(sorted.size()*.99))],"max":sorted[-1]}
