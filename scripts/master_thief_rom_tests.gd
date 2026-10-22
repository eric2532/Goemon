extends SceneTree
## Verify the actual playable Actor, visible source parts and weapon contacts.
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const Pose=preload("res://scripts/recovered_goemon_pose.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;push_error(label_)
func run():
	var actor=Actor.new();root.add_child(actor);actor.setup("master-thief")
	var visual=actor.get("rom_thief")
	check(visual!=null,"Master Thief selects the approved ROM Blender base in the real Actor")
	if visual==null:
		actor.free();quit(1);return
	check(visual.parts.size()==13,"Master Thief displays all thirteen original body parts")
	check(visual.contact_axis.length()>1.0,"The exported pipe retains its nonzero grip-to-tip contact vector")
	check(visual.costume.scene_file_path=="res://assets/models/characters/rom_goemon_base/master_thief_equipment.glb","Equipment comes from the approved Blender pilot")
	var idle:Dictionary=visual.sampler.sample_source(0,0)
	for key in visual.parts:
		check(visual.parts[key].transform.is_equal_approx(visual.normalized(idle[key])),"Initial source part is preserved: "+key)
	actor.animate_pose({"grounded":true,"motionSpeed":7.0},.1,.1,1)
	check(visual.source_action==15,"Running uses the recovered ROM Run action")
	check(actor.model.transform.is_equal_approx(Transform3D.IDENTITY),"Native run does not inherit an additional legacy root bob or turn")
	var moving:Dictionary=visual.sampler.sample_source(15,visual.source_time)
	for key in visual.parts:
		check(visual.parts[key].transform.is_equal_approx(visual.normalized(moving[key])),"Run part follows its native matrix: "+key)
	for index in 3:
		var attack={"primary":true,"style":"pipe","index":index,"duration":.38,"contact":.105,"time":.105}
		actor.animate_pose({"grounded":true,"attack":attack},0,.2,0)
		check(visual.source_action==104+index,"Combo uses the corresponding source strike")
		var weapon:Node3D=actor.joints.Weapon_Cutlass.node
		check(weapon.to_global(actor.WEAPON_AXES[actor.id]).distance_to(visual.weapon.to_global(visual.contact_axis))<.001,"Damage/trail tip follows the visible pipe at contact")
	actor.animate_pose({"grounded":false,"vertical":8.0},.03,.3,0)
	check(visual.source_action==24,"Jump uses the recovered ROM jump")
	actor.animate_pose({"grounded":false,"vertical":4.0},.5,.8,0)
	actor.animate_pose({"grounded":false,"vertical":-2.0},.03,.4,0)
	check(visual.source_action==25,"Falling uses the recovered ROM fall")
	check(is_zero_approx(visual.source_time),"A full jump starts Fall at its first frame when passing the apex")
	actor.animate_pose({"grounded":true},.03,.5,0)
	check(visual.source_action==26,"Landing uses the recovered ROM landing")
	for state in [{"grounded":true,"blocking":true,"guardStyle":"thief"},{"grounded":true,"crouched":true},{"grounded":true,"buffTime":3.0}]:
		actor.animate_pose(state,.016,.6,0)
		for part in visual.parts.values():check(part.transform.is_finite(),"Class-specific poses remain finite")
		var proxy:Node3D=actor.joints.Weapon_Cutlass.node
		check(proxy.to_global(actor.WEAPON_AXES[actor.id]).distance_to(visual.weapon.to_global(visual.contact_axis))<.001,"Special pose contact remains attached to the visible weapon")
	for state in [{"grounded":true,"blocking":true,"guardStyle":"thief"},{"grounded":true,"crouched":true,"attack":{"primary":true,"style":"low-pipe","index":0,"duration":.3,"contact":.08,"time":.08}}]:
		actor.rom_thief=null;actor.animate_pose(state,.016,.6,0)
		var intended:Vector3=(actor.joints.Weapon_Cutlass.node.global_basis*actor.WEAPON_AXES[actor.id]).normalized()
		actor.rom_thief=visual;visual.update(state,0,.6)
		var hold_axis:Array=visual.weapon.get_meta("extras")["rom_hold_axis"]
		var visible:Vector3=(visual.weapon.global_basis*Vector3(hold_axis[0],hold_axis[1],hold_axis[2])).normalized()
		check(intended.dot(visible)>.9999,"Guard and crouched cuts retain their authored weapon aim at the new wrist")
	actor.reset_motion();actor.animate_pose({"grounded":true},0,0,0)
	check(visual.source_action==0,"Reset clears the new animation state")
	actor.free()
	print("MASTER_THIEF_ROM_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
