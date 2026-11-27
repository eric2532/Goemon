extends "res://tests/forest-shrine/original_maps_test.gd"
const BOUNDARY_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja union audit/"
func _initialize():
 create_timer(300).timeout.connect(func():printerr("VENOA_BOUNDARY_TIMEOUT");quit(1))
 run.call_deferred()
func local_source(cell:Vector2)->Vector2:return Tour.Regions.frame("south_lakes").inverse()*(cell*3.)
func source_player()->Vector2:return Tour.Regions.frame("south_lakes")*(Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale)/3.
func run():
 var before="--before" in OS.get_cmdline_user_args()
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-venoa-boundary-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true
 Tour.travel(game,Tour.Regions.layout("south_lakes"),{"arrival":local_source(Vector2(230,420)),"yaw":PI*.5,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 var native_bounds:Rect2=game.model.terrain.mask_bounds()
 var world_native=Rect2(native_bounds.position*game.model.falan_scale,native_bounds.size*game.model.falan_scale)
 check(game.world.playable_bounds.is_equal_approx(world_native),"Player bounds use the actual native mask rectangle")
 var observations=[]
 for route in [["west",Vector2(202,420),PI*.5],["east",Vector2(546,420),-PI*.5],["north",Vector2(330,304),0.],["south",Vector2(330,622),PI]]:
  game.player.position=game.model.world_point(local_source(route[1]),.15);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
  game.camera_rig.yaw=route[2]
  game.set_physics_process(true);game.player.set_physics_process(true)
  var outside_frames=0
  Input.action_press("move_forward")
  for i in 120:
   if not Input.is_action_pressed("move_forward"):Input.action_press("move_forward")
   await physics_frame
   if not world_native.has_point(Vector2(game.player.position.x,game.player.position.z)):outside_frames+=1
  Input.action_release("move_forward")
  game.set_physics_process(false);game.player.set_physics_process(false)
  var end=source_player()
  observations.append({"edge":route[0],"start_source":str(route[1]),"end_source":str(end),"outside_native_frames":outside_frames,"area":game.model.falan_area})
  check(outside_frames==0 and game.model.falan_area=="south_lakes","Normal player movement stays within native "+route[0]+" boundary")
 var file=FileAccess.open(BOUNDARY_OUT+("boundary-before.json" if before else "boundary-after.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"native_bounds":str(world_native),"player_bounds":str(game.world.playable_bounds),"observations":observations,"input_replay":"Normal move_forward action held for120physics frames at each edge; no movement teleport after setup."},"  ")+"\n");file.close()
 print("VENOA_BOUNDARY_RESULT before=",before," checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
