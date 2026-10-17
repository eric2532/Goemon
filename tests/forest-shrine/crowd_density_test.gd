extends SceneTree
const VisualTest=preload("res://tests/forest-shrine/enemy_visual_test.gd")
class CountingCrowd extends "res://scripts/forest/forest_enemy_crowd.gd":
	var pose_writes=0
	func _write_pose(image: Image,index: int,group: int,pose: Transform3D):
		pose_writes+=1;super._write_pose(image,index,group,pose)
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func run():
	var game=VisualTest.TestGame.new();root.add_child(game)
	var crowd=CountingCrowd.new();crowd.game=game;crowd.low_fidelity=false;game.add_child(crowd);crowd.set_process(false)
	var actors=[]
	for id in range(40):
		var actor=VisualTest.TestActor.new();actor.forest_id=id;actor.variant=0;actor.add_child(actor.model);game.add_child(actor);actors.append(actor);game.enemies.append(actor)
		game.model.enemies[id]={"variant":0,"pos":Vector3(id*3,0,0),"facing":0.0,"velocity":Vector3(0,0,-6),"walk_phase":.5,"action":"walk","attack_progress":0.0,"frozen":0.0}
	game.reveal=false;crowd._process(.1)
	check(crowd._poses.is_empty(),"Fog-only actors allocate no presentation snapshots")
	game.reveal=true;crowd._process(.1)
	check(crowd.batches[0].multimesh.visible_instance_count==40,"The expanded shared batch draws every visible actor")
	var image=crowd.pose_images[0];var texture=crowd.pose_textures[0];var capacity=image.get_height()
	crowd.pose_writes=0;crowd._process(.1)
	check(crowd.pose_writes==0,"Unchanged visible poses perform no part-pose row writes")
	check(is_same(image,crowd.pose_images[0]) and is_same(texture,crowd.pose_textures[0]),"Steady frames reuse both pose image and GPU texture")
	game.model.enemies[0].walk_phase=.8;crowd._process(.1)
	check(crowd.pose_writes==7,"One changed pose rewrites only its seven parts")
	check(is_same(image,crowd.pose_images[0]),"Changed poses update the existing image buffer")
	game.model.enemies[0].frozen_pose=game.model.enemies[0].duplicate();game.model.enemies[0].frozen=2;crowd._process(.1)
	game.model.enemies[0].frozen=1.5;crowd.pose_writes=0;crowd._process(.1)
	check(crowd.pose_writes==0,"A frozen countdown preserves the same uploaded pose")
	var alive_data=game.model.enemies[0];actors[0].dead=true;game.model.enemies.erase(0);crowd._process(.1)
	check(image.get_pixel(21,0).r==0,"Removing a frozen actor from simulation clears its rendered frost tint during death")
	actors[0].dead=false;game.model.enemies[0]=alive_data
	game.model.enemies[0].frozen=0;game.model.enemies[0].erase("frozen_pose");crowd._process(.1)
	var previous=crowd._poses[0];game.reveal=false;game.model.enemies[0].walk_phase=1.3;crowd.pose_writes=0;crowd._process(.1)
	check(is_same(previous,crowd._poses[0]) and crowd.pose_writes==0,"Fogged actors neither resnapshot nor rebuild poses")
	game.reveal=true;crowd._process(.1)
	check(crowd._poses[0].walk_phase==1.3,"Revealed actors immediately use their latest simulated pose")
	game.enemies=game.enemies.slice(0,1);crowd._process(.1)
	check(is_same(image,crowd.pose_images[0]) and crowd.pose_images[0].get_height()==capacity,"A smaller visible crowd retains capacity without reallocating")
	var deform=Transform3D(Basis(Vector3.UP,.4).scaled(Vector3(1,2,3)),Vector3.ZERO)
	crowd._write_pose(image,0,6,deform)
	if image.get_width()>=43:
		var col_x=image.get_pixel(40,0);var col_y=image.get_pixel(41,0);var col_z=image.get_pixel(42,0)
		var normal=Basis(Vector3(col_x.r,col_x.g,col_x.b),Vector3(col_y.r,col_y.g,col_y.b),Vector3(col_z.r,col_z.g,col_z.b))
		var expected=deform.basis.inverse().transposed()*Vector3(1,1,1)
		check((normal*Vector3(1,1,1)).is_equal_approx(expected),"Uploaded normals preserve inverse-transpose behavior for stretched giant arms")
	else:check(false,"Pose rows include precomputed normal transforms")
	for kind in range(4):
		check(crowd.batches[kind].cast_shadow==(GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind==2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"Only the rare giant retains full crowd shadows")
	for material in crowd.materials:
		if material.get_shader_parameter("has_albedo_texture"):
			var artwork=material.get_shader_parameter("albedo_texture")
			check(maxi(artwork.get_width(),artwork.get_height())<=1024,"Crowd artwork has a bounded texture footprint")
	var outsider=Node3D.new();game.add_child(outsider);game.enemies.append(outsider);crowd._process(.1)
	check(crowd.batches[0].multimesh.visible_instance_count==1,"Mixed non-Forest actors do not enter a Forest render batch")
	crowd.clear();crowd.pose_writes=0;crowd._process(.1)
	check(crowd.pose_writes==7,"Clearing the wave invalidates cached rows before reused ids arrive")
	game.queue_free();await process_frame
	print("FOREST_CROWD_DENSITY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
