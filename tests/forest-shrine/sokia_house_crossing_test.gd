extends "res://tests/forest-shrine/original_maps_test.gd"
const HOUSE_OUT="res://build/Other Files/Asset Toolkit/Sokia Region Reconstruction/House5003/"
func _initialize():
 create_timer(900).timeout.connect(func():printerr("SOKIA_HOUSE_TIMEOUT");quit(1))
 run.call_deferred()
func walk_gate(at:Vector2,direction:Vector2):
 var previous=game.model
 game.player.position=game.model.world_point(at-direction*3.8,.15);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
 for i in 4:await physics_frame
 game.camera_rig.yaw=atan2(-direction.x,-direction.y)
 Input.action_press("move_forward")
 for i in 80:
  await physics_frame
  if game.model!=previous:break
 Input.action_release("move_forward")
 for i in 4:await physics_frame
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-sokia-house-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.run_seed=41829558;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"))
 var outside=Tour.Regions.frame("sokia_coast").inverse()*(Vector2(148,199)*3.)
 Tour.travel(game,Tour.Regions.layout("sokia_coast"),{"arrival":outside-Vector2(8,0),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 var source_link=game.model.get_meta("falan_links",[]).filter(func(l):return l.get("site")==5003)
 check(source_link.size()==1 and source_link[0].at==outside,"One original outdoor house port at 148,199")
 await walk_gate(outside,Vector2.RIGHT)
 check(game.model.falan_area=="interior" and game.model.falan_floor==5003,"Normal forward movement enters the original house")
 if game.model.falan_floor!=5003:quit(1);return
 check(Original.state(5003).raw==Original.Art.raw_map("BlueCrossgate/map/0/5003.dat"),"Every original house map byte is retained")
 check(game.world.map_features.get_meta("recovered_source_map")==5003,"The existing solid map renderer owns the room")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HOUSE_OUT))
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 game.explorer_npcs.prepare()
 check(game.explorer_npcs.actors.size()==3,"Three original house actors, without duplicates")
 var talked=[]
 game.set_physics_process(false);game.player.set_physics_process(false)
 for actor in game.explorer_npcs.actors:
  var record:Dictionary=actor.node.get_meta("npc_record");var success=false
  for dy in range(-1,2):
   for dx in range(-1,2):
    if dx==0 and dy==0:continue
    var spot=Vector2(actor.node.position.x,actor.node.position.z)+Vector2(dx,dy)*3.
    if not game.model.terrain.disk_clear(Vector3(spot.x,game.model.surface_height(spot.x,spot.y)+.5,spot.y),.4):continue
    game.player.position=game.model.world_point(spot,.15);game.player.reset_physics_interpolation()
    game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
    if game.explorer_npcs.nearest.get("node")!=actor.node:continue
    var key=InputEventKey.new();key.physical_keycode=KEY_F;key.pressed=true;game._input(key)
    success=is_instance_valid(game.dialogue) and game.explorer_npcs.selected.get("id","")=="source:"+record.id
    if success:game.explorer_npcs.finish();talked.append(record.id);break
   if success:break
  check(success,"Normal F input reaches house source actor "+record.id)
 var stats={"area":game.model.falan_area,"floor":game.model.falan_floor,"talked":talked,"links":var_to_str(game.model.get_meta("falan_links",[]))}
 var file=FileAccess.open(HOUSE_OUT+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(stats,"  "));file.close()
 if DisplayServer.get_name()!="headless":
  for child in game.get_children():
   if child is CanvasLayer:child.hide()
  var camera:Camera3D=game.camera_rig.camera
  var focus=game.model.world_point(Vector2.ZERO)
  camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=90*game.model.falan_scale;camera.global_position=focus+Vector3(-1,1.60356745,1)*200*game.model.falan_scale;camera.look_at(focus)
  var roof=game.world.find_children("*Ceiling*","MeshInstance3D",true,false)
  for node in roof:node.hide()
  game.camera_rig.set_process(false)
  for i in 4:await process_frame
  RenderingServer.force_draw();root.get_texture().get_image().save_png(HOUSE_OUT+"current-isometric.png")
 game.set_physics_process(true);game.player.set_physics_process(true)
 var exit=Original.source_point(5003,Vector2i(2,10))
 await walk_gate(exit,Vector2.LEFT)
 check(game.model.falan_area=="sokia_coast","Normal forward movement returns to the original coast")
 check(JSON.stringify(get_meta("falan_venture"))==saved,"The original adventure data is preserved")
 print("SOKIA_HOUSE_CROSSING_RESULT checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
