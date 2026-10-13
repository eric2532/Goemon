extends SceneTree
var game
var checks=0
var failures=0
class QueryProbe:
	extends "res://scripts/rogue_roster_combat.gd"
	var queries=0
	var resolved=[]
	var blocked=Vector3.INF
	func clear_line(_from: Vector3,to: Vector3)->bool:
		queries+=1;return not to.is_equal_approx(blocked)
	func _terrain_hit(_from: Vector3,_to: Vector3,_radius: float=0.0,_sphere: bool=false)->Dictionary:return {}
	func hit(e: Dictionary={},_amount: float=0,_weapon: String="cutlass",_heavy: bool=false,_direction: Vector3=Vector3.ZERO,_element: String="",_presentation: String="")->void:
		resolved.append(e.uid)
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if ok:print("PASS: ",message)
	else:failures+=1;push_error(message)
func run():
	game=load("res://scenes/main.tscn").instantiate();game.smoke_test=true;root.add_child(game)
	game.tuning.freeze_ai=true;game.tuning.invincible=true;game.start_mode("defense")
	game.encounters.set_physics_process(false);game.kennel.set_physics_process(false);game.barracks.set_physics_process(false)
	game.player.smoke_mode=true
	for e in game.enemies:
		if is_instance_valid(e):e.queue_free()
	game.enemies.clear()
	var targets=[]
	for i in range(3):
		var e=Ninja.new();e.game=game;e.training_dummy=true;e.practice=true
		e.position=Vector3(0,.1,200-i*2);game.add_child(e);e.set_physics_process(false)
		e.hp=10000;e.max_hp=10000;game.enemies.append(e);targets.append(e)
	var probe=QueryProbe.new();probe.game=game;probe.hero=game.player;game.add_child(probe)
	var mesh=Node3D.new();game.add_child(mesh)
	var from=Vector3(0,1.2,202);var to=Vector3(0,1.2,192)
	var ids=[]
	for e in targets:ids.append(e.get_instance_id())
	var pr={"width":.5,"hits":[ids[0],ids[2]],"pierce":true,"ticket":{},"damage":64,"weapon":"cutlass","heavy":true,"kind":"probe","vel":Vector3.FORWARD,"mesh":mesh,"life":1.0}
	probe.resolve_projectile_segment(pr,from,to)
	check(probe.resolved==[ids[1]],"Piercing sweep resolves only the previously unhit victim")
	check(probe.queries==1,"Previously hit victims are rejected before cover ray queries")
	probe.queries=0;probe.resolved.clear();probe.resolve_projectile_segment(pr,from,to)
	check(probe.queries==0 and probe.resolved.is_empty(),"A repeated swept segment performs no victim rays or duplicate damage")
	probe.blocked=AttackChain.aim_point(targets[1]);probe.queries=0;pr.hits=[ids[0],ids[2]]
	probe.resolve_projectile_segment(pr,from,to)
	check(probe.resolved.is_empty() and not pr.hits.has(ids[1]),"An unhit victim behind cover remains excluded from contact")
	probe.blocked=Vector3.INF;probe.queries=0;probe.resolved.clear();pr.hits=[];pr.pierce=false
	probe.resolve_projectile_segment(pr,from,to)
	check(probe.resolved==[ids[0]] and pr.life==0,"Nonpiercing shots still stop at the first ordered victim")
	probe.resolved.clear();pr.hits=[];pr.pierce=true;targets[1].dead=true
	probe.resolve_projectile_segment(pr,from,to)
	check(not probe.resolved.has(ids[1]),"Dead victims do not enter swept projectile resolution")
	targets[1].dead=false
	check(probe.has_method("_nearby_targets"),"Elemental areas reject distant targets before building contact snapshots")
	if probe.has_method("_nearby_targets"):
		var near=probe._nearby_targets(targets[0].global_position,3.0,ids[0])
		check(near.size()==1 and near[0].uid==ids[1],"Elemental neighborhoods preserve radius and source exclusion")
		near=probe._nearby_targets(targets[0].global_position,2.0,ids[0])
		check(near.is_empty(),"Elemental radius boundary remains strictly inside the radius")
	game.sound_library.cancel();game.music.stop();game.queue_free()
	for i in range(4):await process_frame
	print("PROJECTILE_QUERY_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
