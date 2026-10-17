extends SceneTree
## Actual sword-tip paths on the shared Goemon skeleton and real combo sequencing.
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const Actions=preload("res://assets/rogue/scripts/class_actions.gd")
var checks=0
var failures=0
var game
func _initialize():call_deferred("run")
func check(ok: bool,text_: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",text_)
func tip(actor)->Vector3:
	return actor.cosplay_rig.skeleton.global_transform.affine_inverse()*actor.joints.Weapon_Cutlass.node.to_global(actor.WEAPON_AXES[actor.id])
func run():
	var actor=Actor.new();root.add_child(actor);actor.setup("magic-swordsman")
	for speed in [2.0,3.0,5.1,10.2,18.0]:
		actor.reset_motion();var lo=Vector3.INF;var hi=-Vector3.INF;var minimum_right=INF;var forward_min=INF;var forward_max=-INF;var support_error=0.0
		for frame in 150:
			actor.animate_pose({"grounded":true,"motionSpeed":speed,"localMotion":Vector3.BACK*speed},1.0/60,frame/60.0,1)
			if frame<45:continue
			var p=tip(actor);lo=lo.min(p);hi=hi.max(p)
			var sk=actor.cosplay_rig.skeleton
			var hand=sk.get_bone_global_pose(sk.find_bone("Hand_R")).origin
			minimum_right=minf(minimum_right,hand.x);forward_min=minf(forward_min,hand.z);forward_max=maxf(forward_max,hand.z)
			var left_hand=sk.get_bone_global_pose(sk.find_bone("Hand_L")).origin
			var weapon: Node3D=actor.joints.Weapon_Cutlass.node
			var axis=(weapon.global_basis*actor.WEAPON_AXES[actor.id]).normalized()
			var support=sk.global_transform.affine_inverse()*(weapon.global_position-axis*.18)
			support_error=maxf(support_error,support.distance_to(left_hand))
		check(lo.x>.75 and lo.z>.9,"Magic Swordsman trails the blade behind his anatomical right side at speed %.1f"%speed)
		check(lo.y>-.08 and hi.y<.35,"Dragging sword stays near ground without sinking through it at speed %.1f"%speed)
		check(minimum_right>.05 and forward_max-forward_min<.2,"Sword hand remains low and steady instead of pumping with the stride at speed %.1f"%speed)
		check(support_error<.045,"Both hands keep their actual grip on the trailing sword throughout running at speed %.1f"%speed)
		print("CARRY_GRIP speed=",speed," forward=",forward_min,"..",forward_max," support_error=",support_error)
		check(forward_max<0,"Two-handed hilt stays in front of the torso so the support arm crosses outside the body")
	actor.free()
	actor=Actor.new();root.add_child(actor);actor.setup("samurai")
	var strokes=[]
	for stage in 5:
		var a: Dictionary=Actions.PRIMARY.samurai.duplicate();a.merge(Actions.SAMURAI_CUTS[stage],true)
		a.index=stage;a.primary=true;a.style="samurai-cut"
		var points=[]
		# Measure the cut itself; the later recovery now aligns into the sheath.
		for t in [a.contact*.52,a.contact,a.contact+minf(a.duration*.16,(a.duration-a.contact)*.26)]:
			a.time=t;actor.animate_pose({"grounded":true,"attack":a},0,0,0);points.append(tip(actor))
		strokes.append(points)
		if stage==4:check(absf(actor.model.rotation.y)>2.0,"Samurai fifth cut retains its distinct finishing half-turn")
	for i in 5:
		for j in range(i+1,5):
			var distance=0.0
			for k in 3:distance+=strokes[i][k].distance_to(strokes[j][k])
			check(distance>.3,"Samurai strokes %d and %d have distinct visible sword paths"%[i+1,j+1])
	var fourth: Vector3=strokes[3][2]-strokes[3][0]
	check(absf(fourth.y)>absf(fourth.x)*2,"Samurai fourth cut is visibly vertical")
	actor.free()
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://class-identity-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	for i in 3:await process_frame
	game.tuning.critical_chance=0.0;game.character_tuning={};game.tuning.invincible=true
	game.start_wave();game.model.waves.spawn_clock=10000;game.set_physics_process(false);game.player.set_physics_process(false)
	for id in [4,9]:
		game.player.select_character(id);var c=game.player.active_ability;c.reset_run()
		var count=5 if id==4 else 3;var indices=[];var damage=[]
		for swing in count+1:
			c.player.pos=game.player.global_position;c.aim=c.player.pos+Vector3.FORWARD*20
			c.attack();var a: Dictionary=c.player.attack
			indices.append(a.index);damage.append(a.damage)
			c.tick(a.duration+.001);c.player.vel=Vector3.ZERO
		check(indices==([0,1,2,3,4,0] if id==4 else [0,1,2,0]),"%s retains its complete combo before restarting"%c.class_id)
		check(damage[count-1]>damage.slice(0,count-1).max(),"%s final combo strike has the strongest base damage"%c.class_id)
	game.queue_free();paused=false;await process_frame;await create_timer(.3).timeout
	print("CLASS_IDENTITY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
