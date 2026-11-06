extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Run contact feedback inside real physics so pause duration and rendered
## diagnostics describe the same three-hit sequence as desktop play.
const OUT="res://build/Other Files/Asset Toolkit/Goemon Hit Responsiveness/"
var driver:Node
var timings=[]
var frame_times=[]
var focused=0
var sampled=0

func cosmetics(dt:float):
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(dt)

func sequence(connects:bool)->Dictionary:
 var p=game.player
 fresh();p.select_weapon(1)
 game.training_dummy.home=ORIGIN+Vector3(0,0,-2 if connects else -20)
 game.training_dummy.position=game.training_dummy.home
 await driver.advance(2,cosmetics)
 var pauses=[0.0,0.0,0.0];var ticks=0;var stopped=0
 tap("light_attack")
 while (p.attack_left>0 or p.quick_attacks.active) and ticks<240:
  await driver.advance(1,func(dt):
   var started=Time.get_ticks_usec()
   p._physics_process(dt)
   timings.append((Time.get_ticks_usec()-started)/1000.0)
   p.position=ORIGIN;p.velocity=Vector3.ZERO;cosmetics(dt))
  ticks+=1
  if p.impact_pause>0:stopped+=1
  pauses[clampi(p.combo-1,0,2)]=maxf(pauses[clampi(p.combo-1,0,2)],p.impact_pause)
  if DisplayServer.get_name()!="headless":
   sampled+=1
   if DisplayServer.window_is_focused():focused+=1
   frame_times.append(root.get_process_delta_time()*1000)
   if connects and not captured and p.combo==2 and p.impact_pause>0:
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(OUT+"pipe-contact.png")==OK,"Capture the recovered pipe contact on Wind Meadow")
    captured=true
 check(ticks<240,"Pipe sequence finishes without becoming stuck")
 check(contacts==([1,2,3] if connects else []),"Every connected stage hits once; a miss stays a miss")
 check(p.quick_attacks.pending.is_empty(),"Contact leaves no delayed attack backlog")
 return {"connected":connects,"ticks":ticks,"seconds":ticks/60.0,"paused_ticks":stopped,"max_pause":pauses}

func run():
 create_timer(120).timeout.connect(func():printerr("GOEMON_HIT_RESPONSE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var document=load("res://scripts/forest/forest_map_document.gd").new()
 check(document.load_wind_meadow()=="","Use the bundled Wind Meadow map")
 await setup_fixture(document.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.explorer_helpers.set_process(false)
 for node in [game,game.player,game.camera_rig]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 game.camera_focused=false;game._sync_camera_mouse();game.music.stop()
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 var miss=await sequence(false)
 var hit=await sequence(true)
 for stage in 3:
  check(hit.max_pause[stage]<=(.045 if stage==2 else .025)+.00001,"Recovered pipe stage %d retains the short responsive contact pause (%.3fs)"%[stage+1,hit.max_pause[stage]])
 check(hit.ticks-miss.ticks<=7,"Three contacts add at most seven 60 Hz pause ticks")
 await driver.advance(60,cosmetics)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var repeat_hit=await sequence(true)
 check(repeat_hit.ticks==hit.ticks and repeat_hit.max_pause==hit.max_pause,"Repeated hits keep the same pause and sequence duration")
 await driver.advance(60,cosmetics)
 var node_delta=get_node_count()-nodes;var resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 check(node_delta<=0 and resource_delta<=0,"Repeated sequence retains no additional nodes or resources (%d nodes, %d resources)"%[node_delta,resource_delta])
 var p=game.player;var dummy=game.training_dummy
 fresh();p.start_attack(true);dummy.impact_pause=0
 game.confirm_impact(dummy,dummy.position,Vector3.FORWARD,2,false)
 check(is_equal_approx(p.impact_pause,.045) and is_equal_approx(dummy.impact_pause,.095),"Heavy pipe keeps short player feedback and full victim recoil")
 for i in 24:game.confirm_impact(dummy,dummy.position,Vector3.FORWARD,2,false)
 check(is_equal_approx(p.impact_pause,.045),"Simultaneous crowd contacts cannot add their pause durations")
 p.impact_pause=0;game.confirm_ally_impact(dummy,dummy.position,Vector3.FORWARD,2,false,1)
 check(p.impact_pause==0 and is_equal_approx(dummy.impact_pause,.095),"Allied hits retain victim feedback without pausing the player")
 p.impact_pause=0;game.confirm_impact(dummy,dummy.position,Vector3.FORWARD,2,true,1)
 check(p.impact_pause==0,"Goemon coins cannot pause the caster")
 p.select_character(2);p.impact_pause=0;game.confirm_impact(dummy,dummy.position,Vector3.FORWARD,2,false)
 check(is_equal_approx(p.impact_pause,.095),"Other fighters retain their existing contact pause")
 p.select_character(1);fresh();p.start_attack(false,3);p.impact_pause=.12
 game.confirm_impact(dummy,dummy.position,Vector3.FORWARD,2,false)
 check(is_equal_approx(p.impact_pause,.12),"A pipe hit cannot shorten an existing incoming-hit pause")
 timings.sort();frame_times.sort()
 var label="after"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
 var report={"checks":checks,"failures":failures,"miss":miss,"hit":hit,"repeat":repeat_hit,"node_delta":node_delta,"resource_delta":resource_delta,"step_p95_ms":timings[int(timings.size()*.95)],"step_max_ms":timings[-1],"frames":sampled,"focused":focused}
 if not frame_times.is_empty():report.merge({"frame_p95_ms":frame_times[int(frame_times.size()*.95)],"frame_max_ms":frame_times[-1]})
 FileAccess.open(OUT+label+"-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("GOEMON_HIT_RESPONSE_RESULT ",JSON.stringify(report))
 game.queue_free();current_scene=null;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
