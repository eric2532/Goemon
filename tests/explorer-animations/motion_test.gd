extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
var checks=0
var failures=0
var data: Dictionary
func _initialize():call_deferred("run")
func check(ok: bool,label_: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label_)
func unpack(v: Array)->Transform3D:
	return Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()).scaled(Vector3(v[7],v[8],v[9])),Vector3(v[0],v[1],v[2]))
func difference(a: Transform3D,b: Transform3D)->float:
	return maxf(a.origin.distance_to(b.origin),maxf((a.basis.x-b.basis.x).length(),maxf((a.basis.y-b.basis.y).length(),(a.basis.z-b.basis.z).length())))
func expected(actor,key: String,frame: int):
	var sk: Skeleton3D=actor.cosplay_rig.skeleton
	var sample: Dictionary=data.clips[key].frames[frame-1]
	var worst=0.0
	for i in data.bones.size():
		var index=sk.find_bone(data.bones[i]);var target=unpack(sample.bones[i])
		target.basis=target.basis*sk.get_bone_global_rest(index).basis
		worst=maxf(worst,difference(sk.get_bone_global_pose(index),target))
	check(worst<.001,"Approved %s body frame %d matches Blender (error %s)"%[key,frame,worst])
	for side in ["right","left"]:
		var weapon: Node3D=actor.joints["Weapon_Cutlass" if side=="right" else "Weapon_Pistol"].node
		var actual=sk.global_transform.affine_inverse()*weapon.global_transform
		check(difference(actual,unpack(sample.weapons[side]))<.001,"Approved %s %s blade frame %d matches Blender"%[key,side,frame])
	check(actor.model.position.length()<.001 and actor.model.quaternion.angle_to(Quaternion.IDENTITY)<.001,"Authored pose has no duplicate body offset")
func run():
	if "--packaged" in OS.get_cmdline_user_args():
		check(not FileAccess.file_exists("res://tools/export_explorer_animations.py") and FileAccess.file_exists("res://assets/animations/explorer_approved.json"),"Test reads the packaged resources, including Explorer's animation data")
	var actor=Actor.new();root.add_child(actor);actor.setup("explorer");actor.seed=0
	actor.animate_pose({"grounded":true,"motionSpeed":0},0,0)
	var motion=actor.cosplay_rig.get("explorer_motion")
	check(motion!=null,"Explorer uses his approved Blender movement controller")
	if motion==null:
		actor.free();print("EXPLORER_MOTION_RESULT checks=",checks," failures=",failures);quit(1);return
	check(motion.last_clip=="idle" and is_equal_approx(motion.last_frame,1.0),"Stationary Explorer starts at the approved idle")
	data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/explorer_approved.json"))
	for key in data.clips:
		for frame in range(1,data.clips[key].frames.size()+1):
			motion.sample(actor,key,frame,1.0);expected(actor,key,frame)
	actor.reset_motion()
	for i in 90:actor.animate_pose({"grounded":true,"motionSpeed":10.2,"localMotion":Vector3.BACK*10.2},1.0/60,i/60.0)
	check(motion.last_clip=="run","Moving Explorer uses his arms-behind run")
	actor.reset_motion()
	actor.animate_pose({"grounded":false,"vertical":15.55,"motionSpeed":0},1.0/60,0)
	actor.animate_pose({"grounded":false,"vertical":15.05,"motionSpeed":0},1.0/60,0)
	actor.animate_pose({"grounded":false,"vertical":14.45,"flip":0.0,"motionSpeed":0},1.0/60,0)
	check(motion.air_age==0 and motion.last_frame==1,"An immediate second jump restarts the approved launch even with a smaller vertical speed")
	actor.reset_motion()
	for i in 90:actor.animate_pose({"grounded":true,"motionSpeed":10.2,"localMotion":Vector3.BACK*10.2},1.0/60,i/60.0)
	var sk: Skeleton3D=actor.cosplay_rig.skeleton
	for direction in [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT]:
		for i in 41:
			actor.locomotion.phase=float(i)/40*TAU
			actor.animate_pose({"grounded":true,"motionSpeed":10.2,"localMotion":direction*10.2},0,0)
			expected(actor,"run",i+1)
	actor.reset_motion()
	actor.animate_pose({"grounded":true,"motionSpeed":0},0,0)
	var foot=sk.get_bone_global_pose(sk.find_bone("Foot_R"))
	var chest=sk.get_bone_global_pose(sk.find_bone("Chest")).origin
	for i in 54:actor.animate_pose({"grounded":true,"motionSpeed":0},1.0/60,i/60.0)
	check(difference(foot,sk.get_bone_global_pose(sk.find_bone("Foot_R")))<.001,"Approved idle keeps the feet planted")
	check(chest.distance_to(sk.get_bone_global_pose(sk.find_bone("Chest")).origin)>.003,"Approved idle still breathes")
	actor.animate_pose({"grounded":false,"vertical":10.7,"motionSpeed":10.2},1.0/60,2)
	check(motion.last_clip=="jump" and motion.last_frame<=7,"A real takeoff begins with the approved launch pose")
	for i in 24:actor.animate_pose({"grounded":false,"vertical":2.0,"motionSpeed":10.2},1.0/60,2+i/60.0)
	check(motion.last_clip=="jump" and motion.last_frame>=22 and motion.last_frame<=60,"Airborne Explorer holds the authored air pose")
	actor.animate_pose({"grounded":false,"vertical":9,"flip":.1,"motionSpeed":0},1.0/60,2.5)
	check(motion.last_frame<=7 and actor.model.quaternion.angle_to(Quaternion.IDENTITY)<.001,"Second jump uses the approved launch instead of the old somersault")
	for i in 180:actor.animate_pose({"grounded":false,"vertical":-30,"motionSpeed":0},1.0/60,3+i/60.0)
	check(motion.last_clip=="jump" and motion.last_frame==60,"Long falls retain the airborne pose until floor contact")
	actor.animate_pose({"grounded":true,"vertical":0.0,"landing":1.0,"motionSpeed":0},1.0/60,3)
	check(motion.last_clip=="jump" and motion.landing_age<.05,"Floor contact starts landing recovery")
	for i in 90:actor.animate_pose({"grounded":true,"motionSpeed":0},1.0/60,3+i/60.0)
	check(motion.last_clip=="idle","Landing settles into the approved idle")
	actor.animate_pose({"grounded":true,"attack":{"primary":true,"style":"twin","index":0,"time":.055,"contact":.055,"duration":.24}},1.0/60,5)
	check(motion.last_clip=="","Attacks retain Explorer's combat choreography")
	actor.animate_pose({"grounded":true,"roll":.2},1.0/60,5)
	check(motion.last_clip=="","Dodging retains the native action")
	for blocked in [{"blocking":true},{"chargeTime":1.0},{"guardTime":1.0},{"shot":.2},{"drinkGesture":.5},{"crouched":true},{"travel":{"kind":"dash"}},{"dive":{"time":.1}}]:
		var state={"grounded":true,"motionSpeed":0};state.merge(blocked,true)
		actor.animate_pose(state,1.0/60,5)
		check(motion.last_clip=="","Native action releases movement override: "+str(blocked))
	actor.reset_motion()
	check(motion.last_clip=="" and motion.landing_age>10,"Reset clears Explorer animation state")
	actor.free()
	print("EXPLORER_MOTION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
