extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
var output="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Samurai integration"
var view: SubViewport
var stage: Node3D
var actor: Node3D
func _initialize():run.call_deferred()
func run():
 DirAccess.make_dir_recursive_absolute(output)
 view=SubViewport.new();view.size=Vector2i(800,900);view.own_world_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_4X;root.add_child(view)
 stage=Node3D.new();view.add_child(stage)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0,0,0,0);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("cfdfeb");env.environment.ambient_light_energy=.6;stage.add_child(env)
 for entry in [[Vector3(-4,6,-6),1.0,Color("ffe2bd")],[Vector3(4,3,-4),.4,Color("c4e6ed")],[Vector3(1,5,4),.75,Color("f1d6a7")]]:
  var light=DirectionalLight3D.new();stage.add_child(light);light.position=entry[0];light.look_at(Vector3(0,1.5,0));light.light_energy=entry[1];light.light_color=entry[2]
 var camera=Camera3D.new();stage.add_child(camera);camera.position=Vector3(3.85,2.92,-10);camera.look_at(Vector3(.25,1.65,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.8;camera.current=true
 actor=Actor.new();stage.add_child(actor);actor.rotation.y=PI;actor.setup("samurai");actor.seed=0
 actor.animate_pose({"grounded":true},0,0,0);await shot("idle")
 # The selection image uses exactly the same one-second gameplay idle.
 actor.reset_motion()
 for f in 60:actor.animate_pose({"grounded":true},1.0/60,(f+1)/60.0,0)
 view.size=Vector2i(640,720);camera.size=5.35
 await shot("selection")
 view.size=Vector2i(800,900);camera.size=5.8
 actor.locomotion.stride_speed=6;actor.locomotion.phase=TAU*.25
 actor.animate_pose({"grounded":true,"motionSpeed":6,"localMotion":Vector3.BACK*6},0,0,1);await shot("run")
 for i in 5:
  actor.animate_pose({"grounded":true,"attack":{"primary":true,"style":"samurai-cut","index":i,"time":.075,"contact":.075,"duration":.4}},0,0,0)
  await shot("hit-%d"%[i+1])
 actor.animate_pose({"grounded":true,"shot":.2},0,0,0);await shot("bow")
 actor.free();quit()
func shot(name_: String):
 for f in 4:await process_frame
 await RenderingServer.frame_post_draw
 var result=view.get_texture().get_image().save_png(output.path_join(name_+".png"));assert(result==OK)
 print("SAMURAI_RENDERED ",name_)
