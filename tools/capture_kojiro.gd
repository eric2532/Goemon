extends SceneTree
## Portraits come from the same exported model and palette used in play.
class Stage extends Node3D:
	var game:Node
func _initialize():run.call_deferred()
func run():
	var view=SubViewport.new();view.size=Vector2i(384,448);view.transparent_bg=true;view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var stage=Stage.new();stage.game=Node.new();stage.add_child(stage.game);view.add_child(stage)
	var world=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color.TRANSPARENT;stage.add_child(world)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;stage.add_child(camera)
	var model=load("res://scripts/kojiro_model.gd").new();stage.add_child(model);model.rotation.y=PI
	for portrait in ["portrait","hud_portrait"]:
		camera.size=4.6 if portrait=="portrait" else 1.6
		camera.position=Vector3(1,2.5,8);camera.look_at(Vector3(0,1.65 if portrait=="portrait" else 2.65,0))
		for i in 4:await process_frame
		await RenderingServer.frame_post_draw
		assert(view.get_texture().get_image().save_png("res://assets/characters/recovered_kojiro/"+portrait+".png")==OK)
	view.queue_free();await process_frame;quit()
