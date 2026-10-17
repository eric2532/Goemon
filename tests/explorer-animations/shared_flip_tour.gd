extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
var actors=[]
func _initialize():call_deferred("run")
func run():
	var stage=Node3D.new();root.add_child(stage)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("28323f");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;stage.add_child(env)
	var light=DirectionalLight3D.new();stage.add_child(light);light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=1.5
	var camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9;camera.position=Vector3(5,3,10);camera.look_at(Vector3(0,1.1,0));camera.current=true
	for i in 3:
		var actor=Actor.new();stage.add_child(actor);actor.setup(["ninja","ranger","explorer"][i]);actor.position.x=(i-1)*3;actor.seed=0
		actor.animate_pose({"grounded":false,"vertical":8.0},.1,0)
		actor.animate_pose({"grounded":false,"vertical":7.0,"flip":0.0},1.0/60,0);actors.append(actor)
	var poses={}
	for frame in range(1,50):
		if frame>1:
			for actor in actors:actor.animate_pose({"grounded":false,"vertical":4.0,"flip":float(frame-1)/60/.48 if frame<30 else -1.0},1.0/60,0)
		if frame in [1,9,16,22,28,39,49]:
			for actor in actors:
				var sk: Skeleton3D=actor.cosplay_rig.skeleton
				if not poses.has(actor.id):poses[actor.id]={}
				var bones={};var weapons={}
				for i in sk.get_bone_count():bones[sk.get_bone_name(i)]=pack(sk.get_bone_global_pose(i))
				for name_ in ["Weapon_Cutlass","Weapon_Pistol"]:
					if actor.joints.has(name_):weapons[name_]=pack(sk.global_transform.affine_inverse()*actor.joints[name_].node.global_transform)
				poses[actor.id][str(frame)]={"bones":bones,"weapons":weapons}
			if DisplayServer.get_name()!="headless":
				await process_frame;await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://tests/explorer-animations/shared-flip-%02d.png"%frame)
	var file=FileAccess.open("res://tests/explorer-animations/shared-flip-poses.json",FileAccess.WRITE);file.store_string(JSON.stringify(poses,"\t"));file.close()
	stage.free();quit()
func pack(t: Transform3D)->Array:
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]
