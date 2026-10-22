extends SceneTree
## Catches swapped native airborne/crouch selectors and source-space reversal
## leaking from the rigid N64 model into the existing game-facing garment.
const Profile=preload("res://scripts/recovered_goemon_combat_profile.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",label_)
func run():
	var model=load("res://scripts/recovered_goemon_model.gd").new();root.add_child(model)
	await process_frame;model.set_process(false)
	for moving in [false,true]:
		check(Profile.coin_action(true,moving)==0x7C,"Grounded coin throw uses native standing action even while moving=%s"%moving)
		for charged in [false,true]:
			var action=Profile.coin_action(false,moving)+(3 if charged else 0)
			model.begin_original_coin(action)
			model.animate(.05,4 if moving else 0,false,6,0,false,1,false);model.sync_skeleton()
			check(model.locomotion.source_action==(0x80 if charged else 0x7D),"Airborne coin selects original jump throw, charged=%s moving=%s"%[charged,moving])
			var pelvis=model.skeleton.get_bone_global_pose(model.skeleton.find_bone("Pelvis")).origin
			check(pelvis.y>.9,"Airborne ryo throw keeps the source upright pelvis instead of the crouch clip, charged=%s moving=%s"%[charged,moving])
			model.cancel_original_coin()
	model.rotation.y=.6;model.body.position=Vector3(.2,.4,-.1);model.body.rotation=Vector3(-.15,.4,0)
	for gold in [false,true]:
		model.apply_native_pose(0,0);model.set_cloak(true,gold)
		model.ronin_scarf._process(0)
		var robe=model.ronin_scarf
		check(robe.global_basis.is_equal_approx(model.body.global_basis),"%s robe faces the same direction as Goemon at rest"%("Gold" if gold else "Red"))
		check(robe.global_position.distance_to(model.body.global_position)<.0001,"Robe neutral attachment stays at the game model origin")
		model.locomotion_velocity=model.global_basis*Vector3(0,0,-8)
		model.locomotion.grounded=true
		# Remove body tilt to inspect the garment's local back direction.
		model.body.rotation=Vector3.ZERO;robe._process(2)
		var wind:Vector2=robe.cloth.get_shader_parameter("wind_direction")
		check(wind.y>.99,"%s robe streams behind forward travel"%("Gold" if gold else "Red"))
		check(robe.cloth.get_shader_parameter("gold_cloak")==gold,"Robe retains the selected red/gold material")
		model.body.rotation=Vector3(-.15,.4,0)
		var chest=model.skeleton.find_bone("Chest")
		var rest_anchor:Vector3=model.rig_visual.transform*model.skeleton.get_bone_global_rest(chest).origin
		for action in [0x18,0x7D,0x68,0x82]:
			model.apply_native_pose(action,.1);robe._process(0)
			var chest_world:Vector3=model.skeleton.to_global(model.skeleton.get_bone_global_pose(chest).origin)
			check(robe.to_global(rest_anchor).distance_to(chest_world)<.0001,"%s robe follows the native torso anchor during action %02X"%[("Gold" if gold else "Red"),action])
	model.set_cloak(false,false)
	# The garment adapter must not change a single original rigid part matrix.
	model.apply_native_pose(0x7D,.1)
	var native:Transform3D=model.sampler.sample_source(0x7D,.1)["0x9004f48"]
	var displayed:Transform3D=model.native_parts["0x9004f48"].transform
	check(displayed.origin.distance_to(native.origin*model.source_scale+model.source_offset)<.00001 and displayed.basis.is_equal_approx(native.basis.scaled(Vector3.ONE*model.source_scale)),"Robe correction preserves native body matrices and uniform scale")
	var other=HeroModel.new();root.add_child(other);await process_frame;other.set_process(false)
	check(other.cape_skeleton()==other.skeleton,"Other characters retain the shared cape skeleton convention")
	other.queue_free();model.queue_free();await process_frame
	print("RECOVERED_GOEMON_AERIAL_ROBE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
