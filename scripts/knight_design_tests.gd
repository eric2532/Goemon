extends SceneTree
## Exercise the imported Knight, real skeleton, real combat reach and cloth.
const Actor=preload("res://assets/rogue/scripts/actor.gd")
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label_: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",label_)
func pose(sk: Skeleton3D,name_: String)->Transform3D:
	return sk.get_bone_global_pose(sk.find_bone(name_))
func shield_floor(shield: Node3D)->float:
	var mesh=shield.find_child("Weapon_Pistol_Geometry",true,false);var bounds: AABB=mesh.get_aabb();var low=INF
	for i in 8:low=minf(low,mesh.to_global(bounds.get_endpoint(i)).y)
	return low
func run():
	var actor=Actor.new();root.add_child(actor);actor.setup("knight");actor.seed=0
	var sk: Skeleton3D=actor.cosplay_rig.skeleton
	actor.animate_pose({"grounded":true},0,0,0)
	var sword: Node3D=actor.joints.Weapon_Cutlass.node
	var shield: Node3D=actor.joints.Weapon_Pistol.node
	check(actor.WEAPON_AXES.knight.is_equal_approx(Vector3(0,2.44,0)),"Contact uses the approved claymore's actual tip")
	check((actor.global_basis.inverse()*sword.global_basis.y).normalized().y>.8,"Resting claymore points up naturally")
	check(absf((actor.global_basis.inverse()*sword.global_basis.z).normalized().z)<.15,"Resting blade presents its edge forward, broad faces left/right")
	var shield_mesh=shield.find_child("Weapon_Pistol_Geometry",true,false)
	check(shield_mesh!=null and shield_mesh.get_aabb().size.y>2.4,"Approved wall shield is imported at the accepted size")
	if shield_mesh!=null:
		var size_=shield_mesh.get_aabb().size*shield.global_basis.get_scale()
		check(absf(size_.x-1.422537)<.001 and absf(size_.y-2.459493)<.001,"Live shield retains the final approved dimensions without a second enlargement")
	if shield_mesh!=null:
		var bounds=shield_mesh.get_aabb()
		check(absf(bounds.get_center().x)<.001 and absf(bounds.get_center().y)<.001,"Rear grip sits at the shield face center")
	var cape=actor.model.find_child("Knight_Long_Dark_Navy_Cape",true,false)
	check(cape!=null and cape.mesh.get_blend_shape_count()==4,"Long navy cape includes four authored cloth morphs")
	for direction in [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3(1,0,1).normalized()]:
		actor.reset_motion();var low=Vector3.INF;var high=-Vector3.INF
		var hands_low=[Vector3.INF,Vector3.INF];var hands_high=[-Vector3.INF,-Vector3.INF]
		var foot_low=Vector3.INF;var foot_high=-Vector3.INF;var grip_error=0.0
		var cloth_low=Vector4(INF,INF,INF,INF);var cloth_high=-cloth_low
		for frame in 180:
			actor.animate_pose({"grounded":true,"motionSpeed":10.2,"localMotion":direction*10.2},1.0/60,frame/60.0,1)
			if frame<60:continue
			var chest=pose(sk,"Chest");var angles=(chest.basis*sk.get_bone_global_rest(sk.find_bone("Chest")).basis.inverse()).get_euler()
			low=low.min(angles);high=high.max(angles)
			for i in 2:
				var side=["R","L"][i];var hand=pose(sk,"Hand_"+side)
				var h=chest.affine_inverse()*hand.origin
				hands_low[i]=hands_low[i].min(h);hands_high[i]=hands_high[i].max(h)
				var held=sword if i==0 else shield
				# glTF preserves bone-local +Y along the actual palm/tail.
				var palm=sk.global_transform*(hand*Vector3(0,.135,0))
				grip_error=maxf(grip_error,held.global_position.distance_to(palm))
			var foot=pose(sk,"Foot_R").origin;foot_low=foot_low.min(foot);foot_high=foot_high.max(foot)
			if cape!=null:
				for i in 4:
					cloth_low[i]=minf(cloth_low[i],cape.get_blend_shape_value(i));cloth_high[i]=maxf(cloth_high[i],cape.get_blend_shape_value(i))
		var label_="Knight running %s"%direction
		check((high-low).length()<.01,label_+" keeps the torso steady")
		check((hands_high[0]-hands_low[0]).length()<.025 and (hands_high[1]-hands_low[1]).length()<.025,label_+" holds both arms instead of pumping")
		check(grip_error<.005,label_+" keeps both palms on the actual centered grips")
		check((actor.global_basis.inverse()*shield.global_basis.z).normalized().x>.95,label_+" turns the shield face to his left side")
		check((foot_high-foot_low).length()>.15,label_+" retains moving legs")
		if cape!=null:check((cloth_high-cloth_low).length()>.2,label_+" flutters the cape independently")
	actor.reset_motion();actor.animate_pose({"grounded":true,"blocking":true},1.0/60,4,0)
	check((actor.global_basis.inverse()*shield.global_basis.z).normalized().z>.95,"Blocking faces the shield forward")
	actor.animate_pose({"grounded":true},1.0/60,4,0)
	check((actor.global_basis.inverse()*sword.global_basis.y).normalized().y>.8,"Returning from guard restores the upward ready sword")
	for size_ in [1.0,2.0]:
		actor.scale=Vector3.ONE*size_
		for state in [{"grounded":true,"crouched":true},{"grounded":true,"blocking":true},{"grounded":true,"attack":{"style":"shield-bash","index":0,"time":.12,"duration":.38,"contact":.12}}]:
			actor.reset_motion()
			for frame in 60:actor.animate_pose(state,1.0/60,frame/60.0,0)
			check(shield_floor(shield)>-.01,"Shield clears the ground during crouch/guard/bash at scale %.1f: %s"%[size_,state])
			var error=0.0
			for i in 2:
				var held=sword if i==0 else shield;var side=["R","L"][i]
				error=maxf(error,held.global_position.distance_to(sk.global_transform*(pose(sk,"Hand_"+side)*Vector3(0,.135,0))))
			check(error<.005,"Action grips follow the real palms at scale %.1f"%size_)
	actor.free()
	await combat_reach()
	await create_timer(.3).timeout
	print("KNIGHT_DESIGN_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func combat_reach():
	var game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	for i in 3:await physics_frame
	game.tuning.invincible=true;game.start_wave();game.set_physics_process(false);game.model.waves.spawn_clock=10000
	game.player.select_character(7);game.player.set_physics_process(false)
	var combat=game.player.active_ability;combat.reset_run();combat.player.pos=game.player.global_position
	combat.aim=combat.player.pos+Vector3.FORWARD*30;combat.attack()
	var attack: Dictionary=combat.player.attack
	attack.time=attack.contact;game.player.model.actor.animate_pose(combat.player,0,0,0)
	var actor=game.player.model.actor;var weapon: Node3D=actor.joints.Weapon_Cutlass.node
	var tip=weapon.to_global(Vector3(0,2.44,0));var origin=game.player.global_position
	var actual=Vector2(tip.x-origin.x,tip.z-origin.z).length()+.12*game.player.growth_multiplier()
	check(absf(attack.reach-actual*1.12)<.02,"Live Knight hit range includes twelve percent tolerance beyond the visible claymore tip")
	check(attack.reach>2.5,"Large claymore extends the real single-strike reach")
	check(attack.damage==42 and attack.style=="heavy","Knight retains the existing heavy strike damage and timing")
	game.queue_free();paused=false
	for i in 3:await process_frame
