extends SceneTree
## Independent source attachment/direction checks for the visible custom pipe.
const Actor=preload("res://assets/rogue/scripts/actor.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;push_error(label_)
func verify_mount(actor,expected:Transform3D,label_:String):
	var v=actor.rom_thief
	var actual_grip:Vector3=v.to_local(v.weapon.global_position)
	var actual_axis:Vector3=(v.global_basis.inverse()*v.weapon.global_basis*v.hold_axis).normalized()
	check(actual_grip.distance_to(v.normalized(expected).origin)<.001,label_+" uses the ROM pipe grip, on its source weapon hand")
	check(actual_axis.dot(expected.basis.z.normalized())>.9999,label_+" preserves the ROM grip frame with the bowl facing outward")
	var proxy:Node3D=actor.joints.Weapon_Cutlass.node
	check(proxy.to_global(actor.WEAPON_AXES[actor.id]).distance_to(v.weapon.to_global(v.contact_axis))<.001,label_+" keeps combat/trail contact on the visible tip")
func run():
	var actor=Actor.new();root.add_child(actor);actor.setup("master-thief")
	var v=actor.rom_thief
	var bounds:AABB=v.weapon.mesh.get_aabb()
	check(bounds.end.y>absf(bounds.position.y)*2,"The bowl extends outward and the short mouthpiece trails behind the unchanged wrist")
	var near_hand=AABB();var first=true
	for surface in v.weapon.mesh.get_surface_count():
		for vertex:Vector3 in v.weapon.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			if absf(vertex.y)>.18:continue
			if first:near_hand=AABB(vertex,Vector3.ZERO);first=false
			else:near_hand=near_hand.expand(vertex)
	check(not first and maxf(near_hand.size.x,near_hand.size.z)<.25,"The wrist holds the narrow stem instead of the bowl")
	var lowest=INF
	for surface in v.weapon.mesh.get_surface_count():
		for vertex:Vector3 in v.weapon.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			lowest=minf(lowest,v.to_local(v.weapon.to_global(vertex)).y)
	check(lowest>=-.01,"The fitted bowl clears the standing foot plane")
	var ready:Dictionary=v.sampler.sample_source(104,0)
	var mount:Transform3D=ready["0x9005868"].affine_inverse()*ready["0x9002518"]
	for speed in [0.0,7.0]:
		actor.reset_motion()
		for i in 5:
			actor.animate_pose({"grounded":true,"motionSpeed":speed},.075,i*.075,1 if speed>0 else 0)
			var source:Dictionary=v.sampler.sample_source(v.source_action,v.source_time)
			verify_mount(actor,source["0x9005868"]*mount,"Idle/run %s/%s"%[speed,i])
	for stage in 3:
		for t in [0.0,.04,.105,.2,.37]:
			actor.animate_pose({"grounded":true,"attack":{"primary":true,"style":"pipe","index":stage,"duration":.38,"contact":.105,"time":t}},0,t,0)
			var source:Dictionary=v.sampler.sample_source(104+stage,v.source_time)
			verify_mount(actor,source["0x9002518"],"Combo %s/%s"%[stage,t])
	actor.animate_pose({"grounded":true,"blocking":true,"guardStyle":"thief"},.016,.3,0)
	var old=actor.cosplay_rig
	var space:Transform3D=v.global_transform.affine_inverse()*old.skeleton.global_transform
	var native_name="Forearm_L";var legacy_index:int=old.skeleton.find_bone("Forearm_R")
	var reference:Transform3D=v.reference[v.Pose.PTR[native_name]]
	check(reference.origin.x*(space*old.bone_rest[legacy_index]).origin.x>0,"ROM weapon arm and legacy primary arm occupy the same anatomical side")
	var delta:Transform3D=space*old.skeleton.get_bone_global_pose(legacy_index)*old.bone_rest[legacy_index].affine_inverse()*space.affine_inverse()
	check(v.parts[v.Pose.PTR[native_name]].transform.is_equal_approx(delta*reference),"Guard drives the actual ROM weapon arm from the class primary arm")
	actor.free()
	print("MASTER_THIEF_ROM_GRIP_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
