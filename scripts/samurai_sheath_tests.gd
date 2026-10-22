extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label_: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",label_)
func hand(actor,side: String)->Vector3:
	var sk=actor.cosplay_rig.skeleton
	return sk.global_transform*sk.get_bone_global_pose(sk.find_bone("Hand_"+side)).origin
func run():
	var actor=Actor.new();root.add_child(actor);actor.setup("samurai");actor.seed=0
	var weapon: Node3D=actor.joints.Weapon_Cutlass.node
	for mode in ["idle","run","sprint","jump","fall","flip"]:
		var state={"grounded":mode in ["idle","run","sprint"],"motionSpeed":18.0 if mode=="sprint" else (10.2 if mode=="run" else 0.0),"vertical":8.0 if mode=="jump" else -8.0}
		if mode=="flip":state.flip=.4
		actor.reset_motion()
		var right_error=0.0;var left_error=0.0;var seated_error=0.0;var sheath_left=true
		for frame in 90:
			actor.animate_pose(state,1.0/60,frame/60.0,1)
			var sheath=actor.model.find_child("SamuraiRedScabbard",true,false)
			if sheath==null:continue
			var axis=(weapon.global_basis*actor.WEAPON_AXES.samurai).normalized()
			right_error=maxf(right_error,hand(actor,"R").distance_to(weapon.global_position))
			left_error=maxf(left_error,hand(actor,"L").distance_to(sheath.global_position+axis*.22))
			seated_error=maxf(seated_error,weapon.global_position.distance_to(sheath.global_position))
			var sk=actor.cosplay_rig.skeleton
			var hip=actor.cosplay_rig.pose("Pelvis")*actor.cosplay_rig.rest.Pelvis.affine_inverse()
			sheath_left=sheath_left and (hip.affine_inverse()*(sk.global_transform.affine_inverse()*sheath.global_position)).x<-.1
		var sheath=actor.model.find_child("SamuraiRedScabbard",true,false)
		check(sheath!=null,"Red left-hip scabbard exists during "+mode)
		if sheath==null:continue
		check(right_error<.045 and left_error<.045,"Both hands keep their hilt/sheath grip during "+mode)
		check(seated_error<.015 and sheath_left,"Katana stays seated on anatomical left during "+mode)
		var shell=sheath.find_child("Shell",true,false)
		check(shell!=null and shell.material_override.albedo_color.r>shell.material_override.albedo_color.g*3,"Scabbard has a visible red shell during "+mode)
	for stage in 5:
		var a: Dictionary=Actions.PRIMARY.samurai.duplicate();a.merge(Actions.SAMURAI_CUTS[stage],true);a.index=stage;a.primary=true;a.style="samurai-cut"
		for t in [0.0,a.duration*.98]:
			a.time=t;actor.animate_pose({"grounded":true,"attack":a},0,0,0)
			var sheath=actor.model.find_child("SamuraiRedScabbard",true,false)
			check(sheath!=null and weapon.global_position.distance_to(sheath.global_position)<.015,"Cut %d is fully sheathed at %.0f%% of its clock"%[stage+1,t/a.duration*100])
		a.time=a.contact;actor.animate_pose({"grounded":true,"attack":a},0,0,0)
		var sheath=actor.model.find_child("SamuraiRedScabbard",true,false)
		check(sheath!=null and weapon.global_position.distance_to(sheath.global_position)>.3 and (weapon.global_basis*actor.WEAPON_AXES.samurai).normalized().dot(actor.global_basis*Vector3.BACK)>.6,"Cut %d draws a forward striking blade before its contact"%(stage+1))
		check(hand(actor,"R").distance_to(weapon.global_position)<.045,"Cut %d keeps the sword in the right hand"%(stage+1))
		# Returning geometry must not inherit the previous probe's transforms.
		var before=weapon.global_transform
		for repeat in 4:actor.animate_pose({"grounded":true,"attack":a},0,0,0)
		check(before.origin.distance_to(weapon.global_position)<.0001,"Cut %d contact probes remain deterministic"%(stage+1))
		for fraction in [.1,.5,1.0]:
			a.time=a.contact*.35*fraction;actor.animate_pose({"grounded":true,"attack":a},0,0,0)
			check(aligned(actor,sheath),"Cut %d draws straight from the fitted sheath at %.0f%%"%[stage+1,fraction*100])
		for t in [.76,.80,.86,.91]:
			a.time=a.duration*t;actor.animate_pose({"grounded":true,"attack":a},0,0,0)
			check(aligned(actor,sheath),"Cut %d returns along the actual sheath axis at %.0f%%"%[stage+1,t*100])
			var axis=(sheath.global_basis*actor.WEAPON_AXES.samurai).normalized()
			check(hand(actor,"L").distance_to(sheath.global_position+axis*.22)<.045,"Cut %d support hand holds the moving sheath at %.0f%%"%[stage+1,t*100])
		for accelerated in [5.0,30.0]:
			var fast=a.duplicate();fast.duration/=accelerated;fast.contact/=accelerated;fast.time=fast.duration*.86
			actor.animate_pose({"grounded":true,"attack":fast},0,0,0)
			check(aligned(actor,sheath),"Cut %d keeps insertion alignment at %.0fx attack speed"%[stage+1,accelerated])
		for t in [.78,.85,.90]:
			a.time=a.duration*t;actor.animate_pose({"grounded":true,"attack":a},0,0,0)
			check(contained(actor,sheath),"Cut %d keeps the curved blade inside the actual red sleeve during %.0f%% recovery"%[stage+1,t*100])
		for t in [0.0,.08,.16,.30,.45,.60,.76,.85,.98]:
			a.time=a.duration*t;actor.animate_pose({"grounded":true,"attack":a},0,0,0)
			var axis=(sheath.global_basis*actor.WEAPON_AXES.samurai).normalized()
			check(axis.dot((actor.global_basis*Vector3.FORWARD).normalized())>.99,"Cut %d keeps the sheath's closed tip facing backward at %.0f%%"%[stage+1,t*100])
	# An interruption restores the ready grip immediately.
	actor.animate_pose({"grounded":false,"vertical":8.0},1.0/60,0,0)
	var sheath=actor.model.find_child("SamuraiRedScabbard",true,false)
	check(sheath!=null and weapon.global_position.distance_to(sheath.global_position)<.015,"Interrupted slash returns the blade into its sheath in the air")
	for shot in [.2,.15,.05]:
		actor.animate_pose({"grounded":true,"shot":shot},1.0/60,0,0)
		check(weapon.global_position.distance_to(sheath.global_position)<.015 and aligned(actor,sheath),"Bow shot %.2f keeps katana inside the red scabbard after equipment overrides"%shot)
	for growth in [.5,2.0]:
		actor.scale=Vector3.ONE*growth
		for stage in 5:
			var a: Dictionary=Actions.PRIMARY.samurai.duplicate();a.merge(Actions.SAMURAI_CUTS[stage],true);a.index=stage;a.primary=true
			for t in [a.contact*.35,a.duration*.76,a.duration*.86,a.duration*.98]:
				a.time=t;actor.animate_pose({"grounded":true,"attack":a},0,0,0)
				check(aligned(actor,sheath),"Cut %d keeps fitted insertion alignment with %.1fx avatar growth at %.0f%%"%[stage+1,growth,t/a.duration*100])
	actor.free();await create_timer(.2).timeout
	print("SAMURAI_SHEATH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func aligned(actor,sheath)->bool:
	var weapon: Node3D=actor.joints.Weapon_Cutlass.node
	var axis=(sheath.global_basis*actor.WEAPON_AXES.samurai).normalized()
	var blade=(weapon.global_basis*actor.WEAPON_AXES.samurai).normalized()
	var gap=weapon.global_position-sheath.global_position
	return blade.dot(axis)>.999 and (gap-axis*gap.dot(axis)).length()<.015
func contained(actor,sheath)->bool:
	var weapon: Node3D=actor.joints.Weapon_Cutlass.node
	var frame=Basis(Quaternion(Vector3.UP,actor.WEAPON_AXES.samurai.normalized())).inverse()
	var shell=sheath.find_child("Shell",true,false)
	var sections={}
	for v in shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var p=frame*v;var level=roundf(p.y*10000)/10000.0
		if not sections.has(level):sections[level]=[Vector2.INF,-Vector2.INF]
		sections[level][0]=sections[level][0].min(Vector2(p.x,p.z));sections[level][1]=sections[level][1].max(Vector2(p.x,p.z))
	var levels=sections.keys();levels.sort()
	var vertices: Array[Vector3]=[]
	actor.cosplay_rig.samurai_scabbard.collect_vertices(weapon,Transform3D.IDENTITY,Basis.IDENTITY,vertices)
	for v in vertices:
		var p=frame*sheath.to_local(weapon.to_global(v))
		if p.y<levels[0] or p.y>levels[-1]:continue
		var index=0
		while index<levels.size()-2 and levels[index+1]<p.y:index+=1
		var a=levels[index];var b=levels[index+1];var u=inverse_lerp(a,b,p.y)
		var lo: Vector2=sections[a][0].lerp(sections[b][0],u);var hi: Vector2=sections[a][1].lerp(sections[b][1],u)
		var center=(lo+hi)*.5;var radius=(hi-lo)*.5
		var offset=(Vector2(p.x,p.z)-center)/radius
		if offset.length_squared()>1.04:return false
	return true
