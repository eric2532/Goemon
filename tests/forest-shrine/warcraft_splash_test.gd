extends SceneTree
const Shot=preload("res://scripts/warcraft_projectile.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Victim=preload("res://scripts/recovered_leader_projectile_tests.gd").Victim
class Arena extends Node3D:
	var playing=true
	var paused=false
	var transitioning=false
	var enemies=[]
	var confirmations=[]
	var sounds=[]
	func confirm_impact(enemy:Ninja,_point:Vector3,_direction:Vector3,_strength:int,_projectile:bool,source:int,_visuals:bool=true):confirmations.append([enemy,source,false])
	func confirm_ally_impact(enemy:Ninja,_point:Vector3,_direction:Vector3,_strength:int,_projectile:bool,source:int,_visuals:bool=true):confirmations.append([enemy,source,true])
	func sound(slot:String,_volume:float,_enemy:bool,_ticket:Dictionary,source:int):sounds.append([slot,source])
var arena:Arena
var hero:Hero
var pool:Node
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1;print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func target(at:Vector3)->Ninja:
	var enemy=Victim.new();enemy.position=at;arena.add_child(enemy);arena.enemies.append(enemy);return enemy
func clear():
	for enemy in arena.get_children():
		if enemy is Ninja:enemy.free()
	arena.enemies.clear();arena.confirmations.clear();arena.sounds.clear();pool.release_owner(hero)
func launch(at:Vector3=Vector3(0,3,0),velocity:Vector3=Vector3.ZERO):
	return pool.launch(hero,Shot,"demon",{"position":at,"velocity":velocity,"attack_ticket":{"action":"splash_test","source_hero":weakref(hero)}})
func run():
	arena=Arena.new();root.add_child(arena);hero=Hero.new();hero.game=arena;hero.character_id=32
	pool=Pool.service(arena);pool.warm(hero,Shot,"demon",{},24)
	pool.launched.connect(func(shot):shot.set_physics_process(false))
	var point=Vector3(0,3,0)
	var full=target(point+Vector3(1.5,0,0));var half=target(point+Vector3(3.5,0,0));var quarter=target(point+Vector3(5.5,0,0));var outside=target(point+Vector3(5.51,0,0))
	var upper=target(point+Vector3(0,2,0));var dead=target(point);dead.dead=true
	arena.enemies.append(full)
	var shot=launch();shot.explode(point)
	check(full.hp==36 and half.hp==68 and quarter.hp==84,"Fitted sphere boundaries deliver 64 / 32 / 16 splash damage exactly once")
	check(outside.hp==100 and dead.hp==100,"Outside and defeated targets receive no splash damage")
	check(upper.hp==68,"Splash reaches airborne fitted bodies")
	check(arena.confirmations.size()==4 and arena.confirmations.all(func(row):return row[1]==32),"Each damaged target receives one Illidan confirmation")
	check(full.received_ticket.action=="splash_test","Splash retains its launch ticket")
	check(shot.resolved and not shot.visual.visible and not shot.rock.visible and not shot.particles[2].emitting,"Impact hides rock and glow and replaces flight with its prepared burst")
	check(not shot.core_flames.visible and not shot.core_flames.emitting,"Impact removes the covering flame shroud")
	check(shot.particles[0].emitting and shot.particles[1].emitting,"Both recovered one-shot impact emitters start on contact")
	shot.explode(point);shot._physics_process(.3)
	check(full.hp==36 and shot.pool_live,"Impact playback is cosmetic and cannot repeat damage")
	shot._physics_process(.4);check(not shot.pool_live,"Completed impact returns the projectile lease")
	clear()
	var wall=StaticBody3D.new();wall.position=point+Vector3(1,0,0);wall.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(.2,6,6);wall.add_child(shape);arena.add_child(wall)
	await physics_frame;await physics_frame
	var covered=target(point+Vector3(2,0,0));var exposed=target(point+Vector3(0,0,2))
	shot=launch();shot.explode(point)
	check(covered.hp==100 and exposed.hp==68,"Splash respects world cover while damaging exposed neighbors")
	clear();covered=target(point+Vector3(2,0,0));shot=launch(point,Vector3(100,0,0));shot._physics_process(.1)
	check(covered.hp==100 and shot.resolved and shot.position.x<1,"Fast bolts explode on the near side of a wall")
	check(arena.sounds==[["wc_missile_hit",32]],"A wall impact plays its prepared hit cue without a victim")
	wall.free();clear();await physics_frame
	var near=target(point+Vector3(2,0,1.2));var far=target(point+Vector3(8,0,0));arena.enemies.reverse()
	shot=launch(point,Vector3(100,0,0));shot._physics_process(.1)
	check(near.hp==36 and far.hp==100 and shot.resolved,"Wider swept contact catches an off-axis target before a farther target")
	clear();shot=launch(point,Vector3.RIGHT*28);shot._physics_process(2.6)
	check(shot.pool_live and is_equal_approx(shot.position.x,72.8),"Bolt survives the old 2.5-second lifetime")
	check(shot.rock.quaternion.angle_to(Quaternion.IDENTITY)>.1,"Original rock spins during flight")
	check(shot.rock.mesh.get_aabb().size.length()>5 and shot.rock.mesh.get_aabb().size.length()<6,"Rock core is a substantial roughly 3.4-meter stone")
	check(shot.rock.mesh.surface_get_material(0) is ShaderMaterial and shot.rock.mesh.surface_get_material(0).get_shader_parameter("flame_texture")==Shot.Effects.energy_texture(load("res://assets/characters/warcraft/demon-hunter/missile/flame.png")),"Core displays purple flame texture instead of exposed stone")
	var rotation=shot.rock.quaternion
	arena.paused=true;var before=shot.position;shot._physics_process(.5)
	check(shot.position==before and is_equal_approx(shot.age,2.6),"Pause freezes travel and lifetime")
	check(shot.rock.quaternion.is_equal_approx(rotation),"Pause freezes the original rock spin")
	check(is_equal_approx(shot.rock.get_instance_shader_parameter("playback_age"),2.6),"Pause freezes the flame cover")
	arena.paused=false;shot._physics_process(1.5)
	check(not shot.pool_live and is_equal_approx(shot.position.x,112),"Misses sweep exactly four seconds and retire without exploding")
	clear();var last=target(point+Vector3(111.5,0,0));shot=launch(point,Vector3.RIGHT*28);shot._physics_process(3.9);shot._physics_process(.2)
	check(last.hp==36 and shot.resolved,"The final lifetime segment still detects an impact")
	clear();hero.ai_controlled=true;full=target(point);shot=launch();shot.explode(point)
	check(arena.confirmations.size()==1 and arena.confirmations[0][2],"Allied bolts preserve allied impact ownership")
	hero.ai_controlled=false;clear();shot=launch();arena.playing=false;shot._physics_process(.1)
	check(not shot.pool_live,"Ending play retires an active bolt")
	arena.playing=true
	var created=pool.created;var misses=pool.misses;var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for cycle in 5:
		var shots=[]
		for i in 24:
			shot=launch(point+Vector3(i*12,0,0));shots.append(shot)
			check(not shot.resolved and shot.impact_age==0 and shot.age==0 and shot.visual.visible and shot.particles[2].emitting,"Lease resets travel, impact and particle state")
			check(shot.rock.visible and shot.rock.quaternion.angle_to(Quaternion.IDENTITY)<.001,"Lease restores the rock and resets its spin")
			check(shot.rock.get_instance_shader_parameter("playback_age")==0.0,"Lease resets the purple flame cover")
			check(shot.core_flames.visible and shot.core_flames.emitting,"Lease restarts the covering purple flames")
		for bolt in shots:bolt.explode(bolt.position);bolt._physics_process(.7)
	check(pool.created==created and pool.misses==misses,"Five simultaneous volleys reuse all 24 prepared projectiles")
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated impacts create no resources")
	check(Shot.particle_meshes.size()==3 and pool.all.values()[0][0].particles[0].mesh==pool.all.values()[0][1].particles[0].mesh,"All leases share the three immutable native particle meshes")
	check(pool.all.values()[0][0].rock.mesh==pool.all.values()[0][1].rock.mesh,"All leases share one original rock mesh and material")
	clear();pool.discard_owner(hero.get_instance_id());hero.free();arena.queue_free();await process_frame
	print("WARCRAFT_SPLASH_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
