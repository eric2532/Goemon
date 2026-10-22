extends SceneTree
## Real costume rigs and combat: catches rigid elbows, one-piece torso posing,
## and melee damage extending far beyond the visible weapon.
const Actor = preload("res://assets/rogue/scripts/actor.gd")
const Roster = preload("res://scripts/rogue_roster.gd")
var checks=0
var failures=0
var game
func _initialize():call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func point(sk: Skeleton3D,bone: String)->Vector3:
	return sk.global_transform*sk.get_bone_global_pose(sk.find_bone(bone)).origin
func run():
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://attack-alignment-test-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	for i in range(5):await process_frame
	game.begin_forest()
	game.choose_rogue_character(1)
	game.tuning.invincible=true
	game.character_tuning={}
	game.tuning.critical_chance=0.0
	game.tuning.pipe_range=3.5
	game.player.buildings_broken=0
	game.player.scale=Vector3.ONE
	for id in range(3,13):
		game.player.select_character(id)
		var combat=game.player.active_ability
		combat.reset_run()
		var actor=game.player.model.actor
		var name_=Roster.class_id(id)
		if name_ in ["mage","ranger"]:continue
		combat.aim=combat.player.pos+Vector3.BACK*20
		combat.attack()
		var a: Dictionary=combat.player.attack
		a.time=a.contact
		actor.animate_pose(combat.player,0,0,0)
		var sk: Skeleton3D=actor.cosplay_rig.skeleton
		var shoulder=point(sk,"Arm_R")
		var elbow=point(sk,"Forearm_R")
		var hand=point(sk,"Hand_R")
		var bend=(elbow-shoulder).normalized().angle_to((hand-elbow).normalized())
		check(bend>.12,name_+" bends the actual Goemon elbow at contact")
		var pelvis=sk.get_bone_global_pose(sk.find_bone("Pelvis")).basis
		var chest=sk.get_bone_global_pose(sk.find_bone("Chest")).basis
		var relative=(pelvis.inverse()*chest).get_euler().y
		check(absf(relative)>.025,name_+" turns the chest independently from the hips")
		var weapon: Node3D=actor.joints.Weapon_Cutlass.node
		var tip=weapon.to_global(actor.WEAPON_AXES[name_])
		var visible_reach=maxf(Vector2(tip.x-combat.player.pos.x,tip.z-combat.player.pos.z).length(),Vector2(weapon.global_position.x-combat.player.pos.x,weapon.global_position.z-combat.player.pos.z).length())
		print("ATTACK_ALIGNMENT ",name_," reach=",a.reach," visible=",visible_reach," bend=",bend," twist=",relative)
		check(a.reach<=visible_reach+.40,name_+" melee reach stays within the visible stroke")
		check(weapon.global_position.distance_to(hand)<.22,name_+" weapon remains held by the animated hand")
		if name_=="samurai":
			a.index=4
			a.duration=.52;a.contact=.23;a.time=.23
			actor.animate_pose(combat.player,0,0,0)
			var blade=(weapon.to_global(actor.WEAPON_AXES[name_])-weapon.global_position).normalized()
			check(blade.dot(actor.global_basis*Vector3.BACK)>.65,"Samurai's fifth cut still points through its forward damage sector")
	for id in range(3,13):
		game.player.select_character(id)
		game.player.active_ability.reset_run()
		var actor=game.player.model.actor
		var sk: Skeleton3D=actor.cosplay_rig.skeleton
		var shoulder_min=10.0;var shoulder_max=-10.0
		var hip_min=10.0;var hip_max=-10.0;var heel_lift=0.0;var grip_error=0.0
		for frame in range(150):
			actor.animate_pose({"grounded":true,"motionSpeed":10.2,"localMotion":Vector3.BACK*10.2},1.0/60,frame/60.0,1)
			if frame<30:continue
			var shoulder_line=sk.global_basis.inverse()*(point(sk,"Arm_R")-point(sk,"Arm_L"))
			var hip_line=sk.global_basis.inverse()*(point(sk,"Leg_R")-point(sk,"Leg_L"))
			var shoulder_yaw=atan2(-shoulder_line.z,shoulder_line.x)
			var hip_yaw=atan2(-hip_line.z,hip_line.x)
			shoulder_min=minf(shoulder_min,shoulder_yaw);shoulder_max=maxf(shoulder_max,shoulder_yaw)
			hip_min=minf(hip_min,hip_yaw);hip_max=maxf(hip_max,hip_yaw)
			heel_lift=maxf(heel_lift,absf(point(sk,"Foot_R").y-point(sk,"Foot_L").y))
			grip_error=maxf(grip_error,actor.joints.Weapon_Cutlass.node.global_position.distance_to(point(sk,"Hand_R")))
		if Roster.class_id(id)=="ranger":
			check(shoulder_max-shoulder_min<.01,"Ranger holds the bow without running shoulder swing")
			check(hip_max-hip_min<.01,"Ranger keeps a steady waist while stepping")
		elif Roster.class_id(id) in ["samurai","magic-swordsman"]:
			check(shoulder_max-shoulder_min>.06 and shoulder_max-shoulder_min<.20,Roster.class_id(id)+" keeps running shoulders steady with a small natural turn")
			check(hip_max-hip_min>.03 and hip_max-hip_min<.12,Roster.class_id(id)+" keeps restrained waist motion while stepping")
		else:
			check(shoulder_max-shoulder_min>.45,Roster.class_id(id)+" running shoulders visibly turn each stride")
			check(hip_max-hip_min>.25,Roster.class_id(id)+" running hips turn with the stepping legs")
		check(heel_lift>.25,Roster.class_id(id)+" running knees lift the trailing heel")
		check(grip_error<.22,Roster.class_id(id)+" running weapon stays attached to the wrist")
	game.player.select_character(1)
	game.player.attack_heavy=false;game.player.attack_charged=false;game.player.wide_swing=false
	check(game.player.attack_reach_multiplier()<=1.01,"Goemon basic attack has no invisible threefold reach boost")
	game.player.facing=Vector3.FORWARD
	game.player.model.rotation=Vector3.ZERO
	game.start_wave();paused=true
	game.model.waves.spawn_one()
	var target=game.model.enemies.values().back()
	target.pos=game.player.global_position+Vector3.FORWARD*3.0
	target.hp=1000;target.max_hp=1000;target.stun=100
	game.model.update_vision(game.player.position);game.sync_enemies()
	var victim=game.actors[target.id]
	game.player.start_attack(false,1)
	game.player.attack_left=game.player.attack_duration-0.15
	game.player.strike()
	check(victim.hp==1000,"Goemon cannot damage a target a metre beyond the visible pipe")
	for id in [6,10]:
		game.player.select_character(id)
		var combat=game.player.active_ability
		combat.reset_run();combat.aim=combat.player.pos+Vector3.BACK*20
		combat.attack()
		if id==6:combat.Actions.release_charge(combat)
		else:
			combat.player.attack.time=combat.player.attack.contact
			combat.tick(0,false)
		combat._animate(0,0)
		var sk: Skeleton3D=game.player.model.actor.cosplay_rig.skeleton
		var hand=point(sk,"Hand_L" if id==6 else "Hand_R")
		check(not combat.projectiles.is_empty() and combat.projectiles.back().mesh.global_position.distance_to(hand)<.20,("Mage" if id==6 else "Ranger")+" primary leaves the visible casting hand/bow")
	game.queue_free();current_scene=null;paused=false
	await create_timer(.35).timeout
	print("GOEMON_ATTACK_ALIGNMENT_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
