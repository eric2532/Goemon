extends "res://tests/forest-shrine/original_maps_test.gd"
## Camera-only art study outside land bounds; no movement or fight assertion.
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja union audit/Art gaps/"
var captures=[]
var evidence=[]
func _initialize():
 create_timer(360).timeout.connect(func():printerr("VENOA_WATER_FLOWERS_TIMEOUT");quit(1))
 run.call_deferred()
func local_source(cell:Vector2)->Vector2:return Tour.Regions.frame("south_lakes").inverse()*(cell*3.)
func capture_art(label:String,cell:Vector2,yaw:float):
 var at=local_source(cell)
 # The disabled, hidden hero is only the existing camera's study anchor.
 # Water support and ordinary navigation are not extended for this view.
 game.player.position=Vector3(at.x,game.model.terrain.WATER_HEIGHT,at.y)*game.model.falan_scale
 game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH
 game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.camera.fov=63.;game.camera_rig.reset_follow()
 game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 var camera:Camera3D=game.camera_rig.camera;camera.reset_physics_interpolation()
 check(is_equal_approx(camera.fov,63.) and is_equal_approx(game.camera_rig.distance,12.),"Normal camera settings retained: "+label)
 var projected=[]
 for row in evidence:
  var center=Vector3(row.world[0],row.world[1],row.world[2])+Vector3.UP*.5
  projected.append({"serial":row.serial,"pixel":str(camera.unproject_position(center)),"behind":camera.is_position_behind(center)})
 for i in 4:await process_frame
 if DisplayServer.get_name()!="headless":RenderingServer.force_draw();root.get_texture().get_image().save_png(REVIEW+label+".png")
 captures.append({"name":label,"camera_only_test_backdrop":true,"source_anchor":[cell.x,cell.y],"fov":camera.fov,"distance_setting":game.camera_rig.distance,
  "eye":str(camera.global_position),"rotation":str(camera.global_rotation),"projected_prop_centers":projected})
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-water-flowers-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 var saved=JSON.stringify(get_meta("falan_venture"))
 Tour.travel(game,Tour.Regions.layout("south_lakes"),{"arrival":local_source(Vector2(230,420)),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.player.model.hide();game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 var source=load("res://scripts/forest/forest_venoa_southwest_scenery.gd")
 var art=game.world.find_child("VenoaSouthwestSourceScenery",true,false)
 check(art!=null,"Existing Southwest scenery owner is present")
 if art==null:quit(1);return
 check(art.get_meta("venoa_southwest_anchors").size()==80 and source.tree_blocks(game.model).size()==22,"Original strip and native trunk contracts retain 80/22")
 var flowers=art.get_node("OriginalWaterFlowers")
 var wanted=[]
 for x in range(20,25):wanted.append([x,7,12175+x-20])
 var keys=[]
 for row in flowers.get_meta("source_anchors"):keys.append([int(row[0]),int(row[1]),int(row[2])])
 check(keys==wanted and flowers.get_child_count()==5,"Five exact source identities have one renderer station each")
 check(flowers.find_children("*","CollisionObject3D",true,false).is_empty(),"Water flowers have no physics or support owner")
 for part in flowers.get_children():
  var row=source.catalog().offshore_placements[int(part.get_meta("source_serial"))-12175]
  var at=local_source(Vector2(row.cell[0],row.cell[1]));var pose:Transform3D=part.multimesh.get_instance_transform(0)
  check(pose.origin.is_equal_approx(Vector3(at.x,game.model.terrain.WATER_HEIGHT,at.y)),"Source anchor and existing water level: "+str(row.serial))
  check(not game.model.terrain.mask_bounds().has_point(at) and not game.world.playable_bounds.has_point(at*game.model.falan_scale),"No local terrain/bounds expansion: "+str(row.serial))
  var world=part.global_transform*pose.origin
  check(is_nan(game.world.water_support_height(world)),"No offshore water-walking support: "+str(row.serial))
  check(part.multimesh.mesh.get_aabb().size.y>.05,"Existing fitted flower mesh has visible height: "+str(row.serial))
  evidence.append({"cell":row.cell,"serial":row.serial,"ground":row.ground,"flags":row.flags,"world":[world.x,world.y,world.z],"mesh_bounds":str(part.multimesh.mesh.get_aabb())})
 await capture_art("offshore-flowers-normal",Vector2(22,7),0.)
 await capture_art("offshore-flowers-reverse-normal",Vector2(22,7),PI)
 await capture_art("offshore-flowers-side-normal",Vector2(22,7),PI*.5)
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Saved adventure data remains unchanged")
 var path=REVIEW+("offshore-headless.json"if DisplayServer.get_name()=="headless"else"offshore-rendered.json")
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"props":evidence,"captures":captures,
  "scope":"Five original prop anchors on existing source water; camera-only art views beyond land bounds. No movement, safe-zone, navigation or encounter completion claim."},"  ")+"\n");file.close()
 print("VENOA_WATER_FLOWERS_RESULT checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
