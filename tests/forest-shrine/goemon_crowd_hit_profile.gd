extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Isolated native contacts: real physics clocks, unchanged hit rules and art.
## Frozen targets isolate contact; rendered samples are not a moving full battle.
class TracedGame extends "res://scripts/forest/forest_game.gd":
 var single_pause=false
 var feedback_us=0
 var sound_us=0
 func confirm_impact(victim:Ninja,point:Vector3,direction:Vector3,strength:int,projectile:bool,source_character:int=0,spawn_visuals:bool=true,impact_sample:AudioStream=null,primary_feedback:bool=true,impact_cue:String=""):
  var begin=Time.get_ticks_usec()
  var previous_pause=player.impact_pause
  var repeated=player.attack_ticket.get("trace_pause_seen",false)
  super.confirm_impact(victim,point,direction,strength,projectile,source_character,spawn_visuals,impact_sample,primary_feedback,impact_cue)
  if single_pause:
   if repeated:player.impact_pause=previous_pause
   else:player.attack_ticket.trace_pause_seen=true
  feedback_us+=Time.get_ticks_usec()-begin
 func sound(kind:String,volume:float=1.0,enemy_source:bool=false,ticket:Dictionary={},source_id:int=0,original_override:AudioStream=null):
  var begin=Time.get_ticks_usec()
  super.sound(kind,volume,enemy_source,ticket,source_id,original_override)
  sound_us+=Time.get_ticks_usec()-begin
class TracedPipe extends "res://scripts/recovered_goemon_pipe_combat.gd":
 var total_us=0
 var pose_us=0
 var clear_us=0
 func tick(from:float,until:float):
  var begin=Time.get_ticks_usec()
  super.tick(from,until)
  total_us+=Time.get_ticks_usec()-begin
 func _pose(action:int,time_:float,root_:Transform3D,scale_:float)->Transform3D:
  var begin=Time.get_ticks_usec()
  var result=super._pose(action,time_,root_,scale_)
  pose_us+=Time.get_ticks_usec()-begin
  return result
 func _clear(point:Vector3,building:BreakableBuilding=null)->bool:
  var begin=Time.get_ticks_usec()
  var result=super._clear(point,building)
  clear_us+=Time.get_ticks_usec()-begin
  return result
class TracedTarget extends "res://scripts/forest/crowd/army_enemy_target.gd":
 var damage_us=0
 func take_hit(amount:float,direction:Vector3,heavy:bool,ticket:Dictionary={}):
  var begin=Time.get_ticks_usec()
  super.take_hit(amount,direction,heavy,ticket)
  damage_us+=Time.get_ticks_usec()-begin
var driver
var runtime
var tick_index=0
var impacts=[]
var results=[]
var start_hashes={}
var render_sampling=false
var render_previous=0
var render_frames=[]
var render_focus=0
func _process(_delta:float)->bool:
 if render_sampling and DisplayServer.get_name()!="headless":
  var now=Time.get_ticks_usec()
  if render_previous>0:
   render_frames.append((now-render_previous)/1000.0)
   if DisplayServer.window_is_focused():render_focus+=1
  render_previous=now
 return false
func await_focus():
 if DisplayServer.get_name()=="headless":return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
 DisplayServer.window_move_to_foreground();root.grab_focus()
 var begin=Time.get_ticks_msec();var since=begin
 while Time.get_ticks_msec()-since<1500:
  if not DisplayServer.window_is_focused():since=Time.get_ticks_msec()
  if Time.get_ticks_msec()-begin>30000:
   check(false,"Foreground test acquires focus");quit(2);return
  await process_frame
func source_hashes()->Dictionary:
 var hashes={}
 for path in ["scripts/player.gd","scripts/game.gd","scripts/forest/forest_game.gd","scripts/recovered_goemon_pipe_combat.gd","scripts/recovered_goemon_vfx.gd","tests/forest-shrine/goemon_crowd_hit_profile.gd"]:hashes[path]=FileAccess.get_sha256("res://"+path)
 return hashes
var output=""
const OUTPUT="res://build/Other Files/Asset Toolkit/Goemon Crowd Hit Trace/"
func run():
 output=OUTPUT
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=").trim_suffix("/")+"/"
 start_hashes=source_hashes()
 Engine.time_scale=1;Engine.physics_ticks_per_second=60;OS.low_processor_usage_mode=false
 create_timer(120).timeout.connect(func():printerr("CROWD_HIT_TRACE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 check(doc.load_wind_meadow()=="","Use current Wind Meadow")
 set_meta("forest_custom_layout",doc.data);set_meta("forest_painterly_preview",true)
 game=TracedGame.new();game.single_pause="--single-pause" in OS.get_cmdline_user_args();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 var floor_=StaticBody3D.new();floor_.collision_layer=1
 var floor_shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(30,1,30);floor_shape.shape=box;floor_.add_child(floor_shape);game.add_child(floor_);floor_.position=Vector3(0,-.5,60)
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.player.select_character(1);game.player.set_auto_attack(false);game.tuning.critical_chance=0;game.character_tuning={}
 game.player.original_pipe_combat=TracedPipe.new(game.player)
 preload("res://tests/forest-shrine/training_dummy_fixture.gd").install(game)
 game.training_dummy.set_physics_process(false)
 game.model.update_vision(ORIGIN)
 game.camera_rig.camera.global_position=ORIGIN+Vector3(0,6,10);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1,-2))
 root.size=Vector2i(1280,800)
 root.title="Goemon · Pipe Crowd Hit Trace"
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 await physics_frame;await physics_frame
 game.set_process(false);game.army_runtime.set_physics_process(false);game.explorer_helpers.set_process(false)
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 game.camera_focused=false;game._sync_camera_mouse();game.music.stop()
 runtime=game.army_runtime
 game.training_dummy.collision_layer=0;game.training_dummy.hide();game.training_dummy.position=Vector3(0,-100,0)
 game.impact_confirmed.connect(func(victim,strength,_duration):
  if victim!=game.training_dummy:impacts.append({"tick":tick_index,"stage":game.player.combo,"id":victim.forest_id,"strength":strength}))
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 for count in [0,1,24,80]:
  runtime.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
  fresh();game.player.select_weapon(1)
  for i in count:
   var angle=0.0 if count==1 else lerpf(-1.5,1.5,float(i%20)/19)
   var point=ORIGIN+Vector3(sin(angle),0,-cos(angle))*(2.0+float(i/20)*1.5)
   var row=game.model.waves.spawn_enemy(0,point);row.hp=10000;row.max_hp=10000
   var handle:int=runtime.spawn(row.id,0,0,point,10000,3.9)
   var actor=TracedTarget.new();actor.runtime=runtime;actor.game=game;actor.handle=handle;actor.forest_id=row.id;actor.variant=0
   runtime.actor_root.add_child(actor);actor.sync(runtime.unit_state(handle))
   runtime.enemies[row.id]=actor;runtime.register_actor_facade(actor,row)
   game.actors[row.id]=actor;game.enemies.append(actor)
  runtime.arrival_rows.clear();runtime.arrival_ids.clear()
  runtime.latest=runtime.render_snapshot();runtime.presentation_dirty=true
  runtime.flush_presentation()
  await await_focus()
  await driver.advance(2,func(_dt):pass)
  # Warmup is preserved separately from the second connected sequence.
  for repeat_index in 2:
   await driver.advance(30,func(dt):
    if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(dt))
   fresh();impacts.clear();tick_index=0
   var health_before={}
   for actor in game.enemies:actor.damage_us=0;health_before[actor.forest_id]=actor.hp
   var steps=[];var intervals=[];var paused_ticks=0;var clock={"previous":Time.get_ticks_usec()}
   game.feedback_us=0;game.sound_us=0
   var pipe=game.player.original_pipe_combat;pipe.total_us=0;pipe.pose_us=0;pipe.clear_us=0
   await await_focus();clock.previous=Time.get_ticks_usec()
   render_sampling=true;render_previous=0;render_frames.clear();render_focus=0
   tap("light_attack")
   while (game.player.attack_left>0 or game.player.quick_attacks.active) and tick_index<600:
    await driver.advance(1,func(dt):
     var begin=Time.get_ticks_usec()
     intervals.append((begin-clock.previous)/1000.0);clock.previous=begin
     game.player._physics_process(dt)
     steps.append((Time.get_ticks_usec()-begin)/1000.0)
     game.player.position=ORIGIN;game.player.velocity=Vector3.ZERO
     if DisplayServer.get_name()!="headless":
      runtime.presentation_delta+=dt;runtime.presentation_dirty=true)
    if game.player.impact_pause>0:paused_ticks+=1
    tick_index+=1
   render_sampling=false
   check(tick_index<600,"Crowd sequence completes")
   var unique={};var damage_us=0;var damages={}
   for hit in impacts:
    var key=str(hit.id)+":"+str(hit.stage)
    if unique.has(key):check(false,"No duplicate damage per victim/stage")
    unique[key]=true
   check(unique.size()==impacts.size(),"No duplicate damage per victim/stage")
   for actor in game.enemies:
    damage_us+=actor.damage_us;damages[actor.forest_id]=health_before[actor.forest_id]-actor.hp
   if game.single_pause:check(tick_index<=85,"A single feedback pause per stage bounds connected sequence to 85 ticks")
   var per_stage={}
   for hit in impacts:
    if not per_stage.has(hit.stage):per_stage[hit.stage]=[]
    if not per_stage[hit.stage].has(hit.tick):per_stage[hit.stage].append(hit.tick)
   var cpu_sum=0.0
   for value in steps:cpu_sum+=value
   steps.sort();intervals.sort()
   var result={"targets":count,"repeat":repeat_index,"damages":damages,"single_pause":game.single_pause,"ticks":tick_index,"paused_ticks":paused_ticks,"hits":impacts.size(),"contact_ticks":per_stage,"player_total_ms":cpu_sum,"damage_total_ms":damage_us/1000.0,"feedback_total_ms":game.feedback_us/1000.0,"sound_total_ms":game.sound_us/1000.0,"pipe_total_ms":pipe.total_us/1000.0,"pipe_pose_total_ms":pipe.pose_us/1000.0,"cover_rays_total_ms":pipe.clear_us/1000.0,"player_p95_ms":steps[int(steps.size()*.95)],"player_max_ms":steps[-1],"physics_interval_p95_ms":intervals[int(intervals.size()*.95)],"physics_interval_max_ms":intervals[-1],"focused":DisplayServer.window_is_focused(),"display":DisplayServer.get_name(),"impacts":impacts.duplicate(true)}
   if not render_frames.is_empty():
    render_frames.sort()
    result.merge({"render_frames":render_frames.size(),"focused_render_frames":render_focus,"render_frame_p95_ms":render_frames[int(render_frames.size()*.95)],"render_frame_p99_ms":render_frames[int(render_frames.size()*.99)],"render_frame_max_ms":render_frames[-1]})
    check(render_focus==render_frames.size(),"Every measured rendered frame has foreground focus")
   results.append(result)
   if DisplayServer.get_name()!="headless" and repeat_index==1:
    await RenderingServer.frame_post_draw
    var label=("single-pause-" if game.single_pause else "baseline-")+str(count)
    check(root.get_texture().get_image().save_png(output+label+".png")==OK,"Save rendered crowd evidence")
   print("GOEMON_CROWD_HIT_SAMPLE ",JSON.stringify(result))
 var report={"checks":checks,"failures":failures,"samples":results,"note":"Frozen native soldiers, unchanged exact swept pipe and feedback; physics intervals include unrelated rendering and machine load. Not a full battle benchmark.","hashes":start_hashes,"end_hashes":source_hashes()}
 check(report.hashes==report.end_hashes,"Profiled source stays unchanged during measurement")
 report.checks=checks;report.failures=failures
 FileAccess.open(output+("single-pause-" if game.single_pause else "trace-")+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 game.queue_free();current_scene=null;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOEMON_CROWD_HIT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
