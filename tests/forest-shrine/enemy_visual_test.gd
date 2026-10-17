extends SceneTree
var failures=0
var checks=0
class TestActor extends Node3D:
	var forest_id=0
	var variant=0
	var model=Node3D.new()
	var dead=false
	var death_timer=.65
	var hp=100
	var distance_asleep=false
	var render_full=true
	var name_tag: Node3D
class TestModel extends RefCounted:
	var enemies={}
class TestGame extends Node3D:
	var playing=true
	var paused=false
	var transitioning=false
	var enemies=[]
	var model=TestModel.new()
	var reveal=true
	func forest_enemy_visible(_actor):return reveal
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func run():
	var script=load("res://scripts/forest/forest_enemy_crowd.gd")
	if script==null:
		check(false,"Dedicated Forest renderer exists");finish();return
	var game=TestGame.new();root.add_child(game)
	var crowd=script.new();crowd.game=game;crowd.low_fidelity=false;game.add_child(crowd);crowd.set_process(false)
	check(crowd.batches.size()==4,"Only four shared MultiMeshes are allocated")
	var heights=[4.62,4.455,23.10,5.115]
	var surface_count=0;var textured=0
	for kind in range(4):
		var mesh=crowd.batches[kind].multimesh.mesh
		check(abs(mesh.get_aabb().size.y-heights[kind])<.025,"Approved height preserved for species %d"%kind)
		for slot in range(mesh.get_surface_count()):
			surface_count+=1
			var material=mesh.surface_get_material(slot)
			check(material is ShaderMaterial,"Original material is represented by an animated shader")
			if material.get_shader_parameter("has_albedo_texture"):
				textured+=1
				check(material.get_shader_parameter("albedo_texture") is Texture2D,"Painted artwork retains its original texture")
			var arrays=mesh.surface_get_arrays(slot)
			check(arrays[Mesh.ARRAY_NORMAL].size()==arrays[Mesh.ARRAY_VERTEX].size(),"Smooth source normals retained")
			check(arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"Original artwork UVs retained")
	check(surface_count<=44,"Draw batches remain bounded by the approved original materials")
	check(textured>=7,"All seven approved painted material surfaces are preserved")
	var actors=[]
	for id in range(80):
		var actor=TestActor.new();actor.forest_id=id;actor.variant=id%4;actor.add_child(actor.model);game.add_child(actor);actors.append(actor);game.enemies.append(actor)
		actor.model.scale=Vector3.ONE*.01 # Legacy proxy scale must have no effect.
		game.model.enemies[id]={"pos":Vector3(id*2,0,0),"facing":.4,"velocity":Vector3(0,0,-.75),"walk_phase":.7,"attack_progress":.6,"attack_point":Vector3(id*2+1,2,-10),"frozen":0.0,"action":"walk"}
	crowd._process(.1)
	check(crowd.batches[2].multimesh.visible_instance_count==20,"Shared giant batch contains twenty actors")
	check(script.presentation_transform(actors[2],game.model.enemies[2]).basis.get_scale().is_equal_approx(Vector3.ONE),"Old HeroModel proxy scale cannot shrink approved assets")
	check(not actors[0].model.visible,"Legacy proxy model stays hidden")
	check(crowd.get_child_count()==4,"Actor count does not allocate imported mesh scene trees")
	var before: Dictionary=crowd._poses[0].duplicate()
	game.paused=true;game.model.enemies[0].walk_phase=8;crowd._process(1)
	check(crowd._poses[0].walk_phase==before.walk_phase,"Paused simulation preserves the rendered pose")
	game.paused=false;game.model.enemies[0]=before.duplicate()
	game.model.enemies[0].frozen_pose=before.duplicate()
	game.model.enemies[0].frozen=2;game.model.enemies[0].velocity=Vector3.ZERO;crowd._process(1)
	var frozen: Dictionary=crowd._poses[0].frozen_pose
	check(frozen.walk_phase==before.walk_phase and frozen.velocity==before.velocity and frozen.attack_progress==before.attack_progress,"Freeze preserves phase, feet and windup pose")
	game.reveal=false;crowd._process(.1)
	check(not actors[0].visible and actors[0].distance_asleep,"Fog hides actor presentation and marks it asleep")
	check(crowd.batches[2].multimesh.visible_instance_count==0,"Fog removes giant mesh instances")
	game.reveal=true;crowd._process(.1);crowd.clear()
	check(crowd.batches[0].multimesh.visible_instance_count==0,"Wave cleanup clears shared models")
	# During each stance half-cycle, the local foot retreats exactly as root advances.
	var phase=.3;var traveled=.2;var stride=3.0
	var first=script.walking_foot_offset(phase,stride,.7)
	var second=script.walking_foot_offset(phase+TAU*traveled/stride,stride,.7)
	check(abs((second.z-first.z)-traveled)<.0001,"Daruma stance foot remains planted at .75 m/s")
	check(script.walking_foot_offset(PI*1.5,stride,.7).y>.6,"Alternating Daruma swing visibly lifts the other foot")
	var hit_data={"variant":2,"action":"windup","attack_progress":1.0,"attack_point":Vector3(6,3,-11),"facing":.4,"pos":Vector3.ZERO}
	var contact=Vector3(10.637,6.0,-4.20)
	var posed=script.part_pose("fist_r",hit_data)*contact
	check((Basis(Vector3.UP,.4)*posed).distance_to(hit_data.attack_point)<.0001,"Giant visible fist reaches the authoritative strike point")
	game.reveal=true;game.model.enemies[0].frozen=0;crowd._process(.1)
	var pose_image=crowd.pose_images[0]
	var sampled=pose_image.get_pixel(3,0)
	var expected_pose=script.part_pose("foot_l",game.model.enemies[0])
	check(abs(sampled.a-expected_pose.origin.x)<.0001,"Pose texture stores the same contact transform as the CPU helper")
	check(abs(pose_image.get_pixel(5,0).a-expected_pose.origin.z)<.0001,"Renderer and fitted combat use identical planted foot displacement")
	var archer_pose=script.part_pose("fist_r",{"variant":1,"action":"windup","attack_progress":1.0,"attack_point":Vector3(0,2,-24),"pos":Vector3.ZERO,"velocity":Vector3.ZERO})
	check(archer_pose.origin.length()<2.5,"Archer draws its own bow without extending an arm to its ranged target")
	var stopped=script.part_pose("foot_l",{"variant":2,"action":"walk","walk_phase":PI*1.5,"velocity":Vector3.ZERO})
	check(stopped.origin.is_equal_approx(Vector3.ZERO),"Stopped giant settles both feet on the ground")
	game.reveal=false;game.model.enemies[0].walk_phase=1.2;game.model.enemies[0].velocity=Vector3(0,0,-6);crowd._process(.1)
	game.model.enemies[0].frozen=2;game.reveal=true;crowd._process(.1)
	check(abs(crowd._poses[0].walk_phase-1.2)<.0001,"An enemy revealed during freeze retains the last simulated pose")
	actors[2].dead=true;crowd._process(.2)
	check(script.presentation_transform(actors[2],crowd._poses[2],crowd._death_age[2]).basis.get_scale().x<1,"Dead giant presentation collapses before actor cleanup")
	var grounded_strike=script.part_pose("fist_r",{"variant":2,"action":"windup","attack_progress":1.0,"attack_point":Vector3(0,3,-10),"pos":Vector3.ZERO})
	check((grounded_strike*Vector3(10.637,3.35,-1)).y>=0,"Giant striking fist stays above terrain at a low building contact")
	actors[2].dead=false;actors[2].global_position=Vector3(0,0,70);crowd._process(.1)
	check(crowd.batches[2].multimesh.custom_aabb.has_point(Vector3(0,12,70)),"Batch culling bounds include visible giant instances away from world origin")
	game.queue_free();await process_frame;finish()
func finish():
	print("FOREST_ENEMY_VISUAL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
