extends SceneTree
## Render gallery portraits directly from the same prepared gameplay models.
const Roster=preload("res://scripts/rogue_roster.gd")
const Model=preload("res://scripts/recovered_enemy_model.gd")
class Stage extends Node3D:
 var game:Node
func _initialize():run.call_deferred()
func run():
 var view=SubViewport.new();view.size=Vector2i(320,384);view.transparent_bg=true;view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var stage=Stage.new();stage.game=Node.new();stage.add_child(stage.game);view.add_child(stage)
 var world=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color.TRANSPARENT
 world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.8;stage.add_child(world)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.2;stage.add_child(light)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera);camera.current=true
 DirAccess.make_dir_recursive_absolute("res://assets/characters/playable_enemies")
 for id in Roster.ENEMIES.keys()+Roster.WARCRAFT.keys():
  if not OS.get_cmdline_user_args().is_empty() and str(id) not in OS.get_cmdline_user_args():continue
  if not OS.get_cmdline_user_args().is_empty() and str(id) not in OS.get_cmdline_user_args():continue
  var model=load("res://scripts/warcraft_model.gd").new() if Roster.WARCRAFT.has(id) else Model.new()
  if Roster.WARCRAFT.has(id):model.character=id
  else:model.role=Roster.ENEMIES[id].role
  stage.add_child(model)
  model.rotation.y=PI+.25
  var height=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT if Roster.WARCRAFT.has(id) else maxf(model.bounds().size.y,1.5)
  camera.size=20.0 if id==29 else height*1.35 if id!=27 else 50.0
  if id==32:camera.size*=1.45 # Illidan's wings extend beyond the humanoid portrait framing.
  camera.position=Vector3(height*.5,height*.8,height*2.5);camera.look_at(Vector3.UP*height*.5)
  for i in 5:await process_frame
  await RenderingServer.frame_post_draw
  var error=view.get_texture().get_image().save_png(Roster.selection_portrait_path(id))
  assert(error==OK);print("ENEMY_PORTRAIT ",id)
  model.free()
 view.queue_free();await process_frame;quit()
