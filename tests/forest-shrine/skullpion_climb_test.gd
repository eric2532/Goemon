extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
var checks=0
var failures=0
var game
var capture=false
var out="res://build/Other Files/Asset Toolkit/Skullpion/Blender Review/"
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func shot(label_:String,snapshot:Dictionary,point:Vector3,outward:Vector3):
 game.crowd.army.present(snapshot,[])
 var view=game.crowd.army.skullpions[snapshot.logical_ids[0]];view.show();view.set_process(false)
 var camera=Camera3D.new();root.add_child(camera)
 camera.global_position=point+outward*85+outward.cross(Vector3.UP)*60+Vector3.UP*52
 camera.look_at(point+Vector3.UP*16);camera.current=true;camera.fov=48
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+label_+".png")
 camera.queue_free()
func run():
 var args=OS.get_cmdline_user_args();capture=args.has("--capture") and DisplayServer.get_name()!="headless"
 var doc=preload("res://tests/forest-shrine/reference/map_document.gd").new()
 if args.has("--blood-gulch"):doc.load_blood_gulch()
 else:doc.load_kai_highway()
 set_meta("forest_custom_layout",doc.data);set_meta("forest_painterly_preview",true)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://skullpion-climb-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 5:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_helpers.set_process(false);game.army_runtime.set_process(false);game.camera_rig.set_process(false)
 game.start_wave();game.model.waves.spawn_clock=100000;game.model.waves.pending=999;game.ui.hide();AudioServer.set_bus_mute(0,true)
 var runtime=game.army_runtime;runtime.clear();runtime.refresh_kits();game.world.sync(0)
 var nav=Runtime.navigation_data(game.model)
 var collision=runtime.static_collision_data(game.world);nav.air_faces=collision.faces;nav.air_owner=collision.owners
 runtime.set_navigation(999999,nav)
 var sides=[[Vector2i(-8,8),Vector3.BACK],[Vector2i(-8,-8),Vector3.LEFT],[Vector2i(3,-8),Vector3.FORWARD],[Vector2i(8,3),Vector3.RIGHT]]
 for side in sides.size():
  var wall:Dictionary={}
  for b in game.model.buildings.values():
   if b.kind=="wall" and b.cell==sides[side][0]:wall=b;break
  check(not wall.is_empty(),"Castle has wall fixture on side %d"%side)
  if wall.is_empty():continue
  check(collision.owners.has(wall.id),"Physical wall has an owner even though combat targets exclude walls")
  var outward:Vector3=sides[side][1];var center:Vector3=game.model.center(wall)
  var start:Vector3=center+outward*30;start.y=game.model.surface_height(start.x,start.z)
  var id=70000+side;var handle:int=runtime.spawn(id,0,4,start,30000,18)
  var aim:Vector3=center-outward*45;aim.y=game.model.surface_height(aim.x,aim.z)
  var context={"targets":runtime.external_targets()}
  context.targets.positions[0]=aim;context.targets.hp[0]=1000000
  var seen={};var captured={};var previous=start;var highest=start.y;var smooth=true;var stayed_outside=true
  var landed=false;var attacking=false;var cycles=0;var ordered=true;var landed_at=Vector3.ZERO;var premature_damage=false
  for tick in 2400:
   runtime.step(.02,context)
   var snapshot=runtime.render_snapshot();var phase:int=snapshot.air_phase[0];var action:int=snapshot.actions[0];var position:Vector3=snapshot.positions[0]
   for event in runtime.native.take_events():
    if event.kind=="external_damage" and event.get("action_index",0)==106:premature_damage=true
   var label_=""
   if action==106:
    seen[phase]=true;highest=maxf(highest,position.y)
    smooth=smooth and position.distance_to(previous)<1.5
    stayed_outside=stayed_outside and (position-center).dot(outward)>14.8
    if phase==2 and position.y>center.y+7:label_="ascending"
    if phase==3:label_="crest"
    if phase==5 and position.y>center.y+15.8:label_="jump_down"
   elif action==100 and attacking:
    cycles+=1;attacking=false
   elif action==100 and seen.has(5):
    if not landed:
     landed=true;landed_at=position
     ordered=ordered and absf(snapshot.velocities[0].y)<.05 and position.y>=game.model.surface_height(position.x,position.z)-.01
     ordered=ordered and (position-center).dot(outward)>28
     label_="landed"
   elif action>=101 and action<=108 and action!=107:
    if landed:
     attacking=true;landed=false;seen.clear();label_="attack"
    elif not attacking:ordered=false
   if capture and side==0 and not label_.is_empty() and not captured.has(label_):
    captured[label_]=true;await shot(label_,snapshot,center,outward)
   if cycles>=3:break
   previous=position
  print("CASTLE_PATTERN_SIDE map=",game.model.terrain_source," side=",side," cycles=",cycles," peak=",highest," landed=",landed_at)
  check(cycles==3,"Three full-health climb/jump/attack cycles finish on side %d"%side)
  check(highest>center.y+15.8,"Boss visibly jumps outward from the real castle crest on side %d"%side)
  check(ordered and not premature_damage,"Attacks start only after landing, with no crest damage on side %d"%side)
  check(smooth and stayed_outside,"Climb and jump follow the exterior with bounded motion on side %d"%side)
  runtime.despawn(handle);game.crowd.army.clear()
 game.sound_library.cancel();game.music.stop();game.move_audio.stop();game.queue_free();current_scene=null;paused=false
 for i in 3:await process_frame
 print("SKULLPION_PATTERN_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
