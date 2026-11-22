extends SceneTree
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Stone=preload("res://scripts/forest/forest_stone_fort.gd")
const Layout=preload("res://scripts/forest/forest_wind_meadow_layout.gd")
const OUT="res://build/Other Files/Asset Toolkit/Fort Stone/"
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func run():
 create_timer(150).timeout.connect(func():printerr("FORT_STONE_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.title="Goemon · Castle stone fort"
 set_meta("forest_painterly_preview",true)
 var wall_texture:Texture2D=Meadow.source("buildings/wall_section")[0].mesh.surface_get_material(0).albedo_texture
 for size_ in ["standard","large"]:
  var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow_large.json" if size_=="large" else "res://assets/maps/forest_wind_meadow.json"))
  layout.raised_castle=true
  set_meta("forest_custom_layout",layout)
  var game=load("res://scenes/forest_shrine.tscn").instantiate()
  var cfg="user://fort-stone-%d.cfg"%OS.get_process_id();game.settings_path=cfg
  root.add_child(game);current_scene=game
  for i in 5:await process_frame
  for node in [game,game.player,game.camera_rig,game.army_runtime]:node.set_process(false);node.set_physics_process(false)
  game.music.stop();game.set_process_input(false);game.set_process_unhandled_input(false)
  var ground:ShaderMaterial=game.world.attack_materials[0];var stairs:ShaderMaterial=game.world.attack_materials[1]
  check(ground.get_shader_parameter("castle_stone_texture")==wall_texture,size_+" fort reuses the imported castle wall texture")
  check(stairs.get_shader_parameter("castle_stone_texture")==wall_texture and stairs.get_shader_parameter("use_castle_stone"),size_+" stairs reuse that same atlas")
  check(is_equal_approx(ground.get_shader_parameter("castle_half_size"),Layout.CASTLE_HALF_SIZE),size_+" stone is limited to the raised central fort")
  check(not Stone.material(Color("92998c"),false).get_shader_parameter("use_castle_stone"),size_+" shared statues and other stone keep their existing materials")
  check(is_equal_approx(game.model.surface_height(0,18),Layout.CASTLE_HEIGHT) and game.army_runtime.native!=null,size_+" courtyard elevation and native army owner remain intact")
  var collision=game.world.map_features.find_child("ValleyTerrainCollision",true,false)
  check(collision!=null and collision.get_child(0).shape==game.model.terrain.collision(),size_+" physics retains the prepared shared terrain")
  if DisplayServer.get_name()!="headless":
   DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
   game.ui.hide();game.forest_ui.hide()
   var camera:Camera3D=game.camera_rig.camera;camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=330
   camera.global_position=Vector3(180,230,260);camera.look_at(Vector3(0,12,0))
   await shot(size_+"-fort")
   camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=58
   camera.global_position=Vector3(85,70,125);camera.look_at(Vector3(30,25,62))
   await shot(size_+"-stone-close")
   # Matched original-material capture makes the visual change reviewable.
   ground.set_shader_parameter("castle_half_size",0.0);stairs.set_shader_parameter("use_castle_stone",false)
   await shot(size_+"-before")
   ground.set_shader_parameter("castle_half_size",Layout.CASTLE_HALF_SIZE);stairs.set_shader_parameter("use_castle_stone",true)
  game.queue_free()
  for i in 4:await process_frame
  if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("FORT_STONE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func shot(file:String):
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+file+".png")==OK,"Rendered "+file)
