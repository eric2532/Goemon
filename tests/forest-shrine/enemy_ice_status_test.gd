extends "res://tests/forest-shrine/slime_ice_preview.gd"
const Visual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const STATUS_OUT="res://build/Other Files/Asset Toolkit/Enemy Element Status/"
const FAMILIES=["slime","zombie","grave","captain","ruby_boss","falan_frontier","habaru","undersea"]
var heading:Label
var summaries:Array=[]
var render_samples:Array[float]=[]
var misrouted_thaws=0

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STATUS_OUT))
 await setup_stage()
 var layer=CanvasLayer.new();root.add_child(layer);heading=Label.new();heading.position=Vector2(22,18);heading.add_theme_font_size_override("font_size",23);layer.add_child(heading)
 for kind in Roles.RIGID_TYPES+[Roles.SLIME,Roles.CAVE_BEAR,Roles.GATEKEEPER_HOUND,Roles.BOSS]:
  await check_kind(kind,str(kind))
 var appearances=0
 for family in FAMILIES:
  var sprites=load("res://scripts/forest/crowd/"+family+"_sprites.gd")
  var data:Dictionary=sprites.motions()
  var table=FileAccess.get_file_as_bytes(sprites.ROOT+"frames.bin")
  var hurt_slot:int=PackedInt32Array(data.actions).find(8)
  for skin in data.variants.size():
   var valid=hurt_slot>=0
   for facing in 8:
    var at=((skin*data.actions.size()+hurt_slot)*8+facing)*16
    valid=valid and table.decode_float(at+4)>0 and table.decode_float(at+8)>0
   check(valid,family+" retains eight original get-hit directions")
  appearances+=data.variants.size()
  var visual_kit:Dictionary=Kits.from_model(game.model,1.0,game);visual_kit.cave_sprites=sprites
  game.crowd.army.configure_profiles(visual_kit)
  await check_kind(Roles.SLIME,family)
 game.crowd.army.configure_profiles(Kits.from_model(game.model,1.0,game))
 await check_reuse()
 runtime.clear();runtime.mirror_action.connect(check_thaw_route)
 var mirror:int=runtime.spawn(900,1,133,origin,700,1.0)
 check(runtime.apply_hit(mirror,{"element":"ice","status_seconds":.01}).accepted,"An allied mirror can receive the shared native freeze")
 runtime.step(.02,{});runtime.dispatch_events()
 check(misrouted_thaws==0,"Cosmetic thaw cues never enter mirror combat dispatch")
 runtime.mirror_action.disconnect(check_thaw_route)
 var report={"checks":checks,"failures":failures,"cases":summaries,"crossgate_appearances":appearances,"rendered":DisplayServer.get_name()!="headless","trigger_added":false,"fire_or_lightning_damage_added":false}
 FileAccess.open(STATUS_OUT+"ice-rollout-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("ENEMY_ICE_STATUS_RESULT ",JSON.stringify(report))
 await finish()

func check_thaw_route(event:Dictionary):
 if event.get("action_index",0)==6000:misrouted_thaws+=1

func show_native(dt:float=0.0):
 if dt>0:runtime.step(dt,{})
 runtime.dispatch_events()
 var events:Array=runtime.presentation_events.duplicate();runtime.presentation_events.clear()
 game.crowd.army.presentation.tick(dt)
 game.crowd.army.present(runtime.render_snapshot(),events)

func shot(name_:String):
 if DisplayServer.get_name()=="headless":return
 await process_frame;RenderingServer.force_draw();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(STATUS_OUT+name_+".png")==OK,"Captured "+name_)

func check_kind(kind:int,label_:String):
 runtime.clear();game.crowd.army.clear();handles.clear()
 var body_bounds=Visual.hurt_bounds(kind)
 var height=body_bounds.size.y
 if kind==Roles.BOSS:height=25.0
 var width=maxf(height,body_bounds.size.x)
 var spacing=maxf(3,width*1.15)
 for i in 3:
  var p=origin+Vector3((i-1)*spacing,0,0)
  handles.append(runtime.spawn(i+1,0,kind,p,10000,Roles.footprint_radius(kind)))
  runtime.set_pose(handles[-1],p,PI)
 game.model.update_vision(origin)
 camera.size=maxf(10,maxf(height*3.1,(spacing*2+width)*.72));camera.global_position=origin+Vector3(0,height*1.2,height*4+10);camera.look_at(origin+Vector3.UP*height*.45)
 heading.text=label_+" · LEFT: original   CENTER: chilled   RIGHT: frozen"
 var baseline:Dictionary=runtime.render_snapshot()
 check(baseline.ice_visual==PackedFloat32Array([0,0,0]),label_+" starts without a coating")
 check(runtime.apply_hit(handles[1],{"element":"chill","slow_factor":.4,"status_seconds":3.0}).accepted,label_+" accepts native chill")
 check(runtime.apply_hit(handles[2],{"element":"ice","status_seconds":3.0}).accepted,label_+" accepts native freeze")
 var active:Dictionary=runtime.render_snapshot()
 check(is_equal_approx(active.ice_visual[1],.42) and active.ice_visual[2]==1 and active.ice_visual[0]==0,label_+" keeps cold intensity isolated per unit")
 if kind in Roles.RIGID_TYPES:
  var kit:Dictionary=Kits.from_model(game.model,1.0,game);var row:int=kit.soldier_kinds.find(kind)
  var start:int=kit.soldier_pose_meta[row*16+14]
  check(active.pose_rows[2]==kit.soldier_pose_rows[start],label_+" immediately selects its original get-hit pose")
 if kind in [Roles.SLIME,Roles.CAVE_BEAR,Roles.GATEKEEPER_HOUND]:
  var pose:Color=game.crowd.army.pose_sample(active,2)
  var packed:Dictionary=runtime.native.instance_buffers(active,game.crowd.army.native_profiles)
  check(int(pose.g)%8==3 and pose.b==0,label_+" freezes into its own get-hit sprite clip")
  check(packed.valid,label_+" native buffers accept cold status fields")
 show_native(.2);await shot("ice-"+label_+"-reaction")
 show_native(2.0)
 var held:Dictionary=runtime.render_snapshot();show_native(.2)
 var after:Dictionary=runtime.render_snapshot()
 check(held.positions[2]==after.positions[2] and held.pose_time[2]==after.pose_time[2],label_+" native movement and combat pose clock stay frozen")
 if kind in Roles.RIGID_TYPES:check(held.pose_rows[2]==after.pose_rows[2],label_+" holds the completed get-hit pose")
 await shot("ice-"+label_+"-held")
 show_native(.7)
 var thawed:Dictionary=runtime.render_snapshot()
 check(thawed.ice_visual[1]<0 and thawed.ice_visual[2]<0,label_+" exports native thawing for chill and freeze")
 check(game.crowd.army.presentation.effects.any(func(e):return e.kind=="ice-thaw"),label_+" uses the existing bounded thaw-flake pool")
 show_native(.4);await shot("ice-"+label_+"-thaw")
 show_native(2.1)
 var clean:Dictionary=runtime.render_snapshot()
 check(clean.ice_visual==PackedFloat32Array([0,0,0]) and clean.hp==baseline.hp,label_+" clears all coating without changing HP")
 check(not game.crowd.army.presentation.effects.any(func(e):return e.kind=="ice-thaw"),label_+" clears spent thaw flakes")
 runtime.apply_hit(handles[1],{"element":"slow","slow_factor":.5,"status_seconds":1.0})
 check(runtime.render_snapshot().ice_visual[1]==0,label_+" ordinary non-ice slow keeps its original appearance")
 runtime.despawn(handles[2]);var fresh:int=runtime.spawn(500,0,kind,origin,10000,Roles.footprint_radius(kind))
 var reused:Dictionary=runtime.render_snapshot();check(reused.ice_visual[reused.handles.find(fresh)]==0,label_+" recycled slots inherit no ice")
 summaries.append({"kind":kind,"family":label_,"coating":true,"hurt_pose":true,"thaw":true})

func check_reuse():
 runtime.clear();game.crowd.army.clear();handles.clear()
 camera.size=180;camera.global_position=origin+Vector3(0,140,130);camera.look_at(origin+Vector3(0,0,-25))
 for i in 240:
  var kind:int=Roles.RIGID_TYPES[i%Roles.RIGID_TYPES.size()]
  handles.append(runtime.spawn(i+1,0,kind,origin+Vector3((i%20-10)*5,0,-floori(i/20)*5),10000,Roles.footprint_radius(kind)))
 show_native(.02);await frames(3)
 var nodes=get_node_count();var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 var inactive:Array[float]=[];var active:Array[float]=[]
 var frame_times:Array[float]=[];var focused_frames=0
 for cycle in 3:
  for i in handles.size():runtime.apply_hit(handles[i],{"element":"chill" if i%2 else "ice","slow_factor":.4,"status_seconds":.4})
  for frame in 24:
   var started=Time.get_ticks_usec();show_native(1.0/60);active.append((Time.get_ticks_usec()-started)*.001)
   if DisplayServer.get_name()!="headless":
    await process_frame;frame_times.append(root.get_process_delta_time()*1000)
    if DisplayServer.window_is_focused():focused_frames+=1
   if cycle==0 and frame==12:await shot("ice-240-simultaneous")
  show_native(2.2)
  check(Array(runtime.render_snapshot().ice_visual).all(func(value):return value==0),"Inactive comparison has no remaining cold or thaw coating")
  for frame in 24:
   var started=Time.get_ticks_usec();show_native(1.0/60);inactive.append((Time.get_ticks_usec()-started)*.001)
   if DisplayServer.get_name()!="headless":
    await process_frame;frame_times.append(root.get_process_delta_time()*1000)
    if DisplayServer.window_is_focused():focused_frames+=1
  show_native(2.2)
 check(runtime.render_snapshot().handles.size()==240,"All 240 native enemies remain in the repeated-use workload")
 check(get_node_count()<=nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources,"Repeated simultaneous cold/thaw cycles retain no additional nodes or resources")
 check(game.crowd.army.presentation.effects.size()<=game.crowd.army.presentation.effect_capacity,"Simultaneous thaw effects respect the existing cosmetic capacity")
 frame_times.sort()
 FileAccess.open(STATUS_OUT+"ice-cost-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify({"enemies":240,"cycles":3,"active_native_submission_mean_ms":mean(active),"inactive_native_submission_mean_ms":mean(inactive),"render_frame_p95_ms":frame_times[int(frame_times.size()*.95)] if not frame_times.is_empty() else 0,"render_frame_max_ms":frame_times[-1] if not frame_times.is_empty() else 0,"focused_frames":focused_frames,"node_delta":get_node_count()-nodes,"resource_delta":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))-resources,"note":"CPU step/submission and capture-run frame intervals, not pure GPU time or steady FPS"},"  "))
