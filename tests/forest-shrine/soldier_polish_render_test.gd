extends SceneTree
## Review the approved geometry through the real native buffers and painterly world.
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const OUT="res://build/Other Files/Asset Toolkit/Soldier Polish/Gameplay/"
func _initialize():run.call_deferred()
func run():
 if RenderingServer.get_rendering_device()==null:printerr("Requires rendered GPU validation");quit(1);return
 root.size=Vector2i(1280,800)
 set_meta("forest_painterly_preview",true);set_meta("forest_fighter",11)
 var game=load("res://scripts/forest/forest_game.gd").new()
 game.settings_path="user://soldier-polish-%d.cfg"%OS.get_process_id();root.add_child(game)
 for i in 3:await process_frame
 game.process_mode=Node.PROCESS_MODE_DISABLED
 game.ui.hide();game.player.hide();game.crowd.hide()
 for helper in game.explorer_helpers.pool:helper.hide()
 if is_instance_valid(game.training_dummy):game.training_dummy.hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 var renderer=load("res://scripts/forest/crowd/army_renderer.gd").new();root.add_child(renderer)
 renderer.configure(game);renderer.use_native_buffers(runtime.native)
 renderer.configure_profiles(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model))
 var point=Vector3(0,0,65);point.y=game.model.surface_height(point.x,point.z)
 for index in 3:
  var position_=point+Vector3((index-1)*3.2,0,0);position_.y=game.model.surface_height(position_.x,position_.z)
  runtime.spawn(index+1,0,[0,1,3][index],position_,100,.4)
 var snapshot=runtime.render_snapshot()
 var camera=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=42
 camera.position=point+Vector3(0,3.2,9);camera.look_at(point+Vector3.UP)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for clip in ["idle","run","attack"]:
  for tick in [0,13,20]:
   for index in 3:
    var resource=Soldier.data([0,1,3][index]);var semantic:Dictionary=resource.get_meta("semantics")
    var key:String=semantic.attack[0] if clip=="attack" else semantic[clip]
    var rows:PackedInt32Array=resource.get_meta("clips")[key].rows
    snapshot.pose_rows[index]=rows[mini(tick,rows.size()-1)]
   for angle in [0,45,90,180]:
    for index in 3:snapshot.yaw[index]=PI+deg_to_rad(angle)
    renderer.present(snapshot,[]);renderer.health.hide()
    await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
    var image=root.get_texture().get_image()
    assert(image!=null and not image.is_empty())
    assert(image.save_png(OUT+"%s_%02d_%03d.png"%[clip,tick,angle])==OK)
 game.sound_library.cancel();game.music.stop()
 var cfg:String=game.settings_path
 runtime.clear();runtime.free();renderer.queue_free();game.queue_free()
 for i in 4:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SOLDIER_POLISH_RENDER_RESULT captures=36 native_buffers=true painterly=true");quit()
