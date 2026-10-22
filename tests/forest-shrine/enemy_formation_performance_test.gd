extends SceneTree
const Crowd=preload("res://scripts/forest/forest_enemy_crowd.gd")
class Actor extends Node3D:
	var forest_id=0
	var variant=0
	var model: Node3D
	var name_tag: Node3D
	var dead=false
	var distance_asleep=false
	var render_full=true
class CountedTerrain extends "res://scripts/forest/forest_ramparts.gd":
	var samples=0
	var disks=0
	func height(x: float,z: float)->float:
		samples+=1
		return super.height(x,z)
	func disk_clear(point: Vector3,radius: float)->bool:
		disks+=1
		return super.disk_clear(point,radius)
class Model extends RefCounted:
	var enemies={}
	var terrain=CountedTerrain.new()
	var navigation_revision=0
class Game extends Node3D:
	var playing=true
	var paused=false
	var transitioning=false
	var enemies=[]
	var model=Model.new()
	func forest_enemy_visible(_actor):return true
var checks=0
var failures=0
func check(ok: bool,label_: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func _initialize():run.call_deferred()
func run():
	var game=Game.new();root.add_child(game)
	# A real raised wall elsewhere prevents an empty-terrain shortcut.
	game.model.terrain.configure([{"ax":-20,"az":-20,"bx":20,"bz":-20,"width":3,"h0":12.0,"h1":12.0}])
	var crowd=Crowd.new();crowd.game=game;game.add_child(crowd);crowd.set_process(false)
	for id in range(104):
		var actor=Actor.new();actor.forest_id=id;actor.variant=4 if id>=96 else id%4
		actor.position=Vector3((id%12)*8-40,0,(id/12)*9+20)
		game.add_child(actor);game.enemies.append(actor)
		game.model.enemies[id]={"id":id,"variant":actor.variant,"pos":actor.position,"facing":.3,"velocity":Vector3(0,0,-2),"walk_phase":.7,"frozen":0.0,"action":"walk"}
	crowd._process(.016)
	var before=game.model.terrain.samples;var disks_before=game.model.terrain.disks
	var start=Time.get_ticks_usec()
	for tick in range(24):
		for actor in game.enemies:
			actor.position.x+=.03;game.model.enemies[actor.forest_id].pos=actor.position
			game.model.enemies[actor.forest_id].walk_phase+=.03
		crowd._process(.016)
	var duration=Time.get_ticks_usec()-start
	var queries=game.model.terrain.samples-before;var disks=game.model.terrain.disks-disks_before
	print("FORMATION_HEADLESS_PROFILE actors=104 frames=24 frame_ms=%.3f height_queries=%d disk_queries=%d"%[duration/24000.0,queries,disks])
	check(queries==0 and disks==0,"Single-body rendering moves without redundant terrain placement queries")
	start=Time.get_ticks_usec()
	for tick in range(24):
		for actor_ in game.enemies:crowd.primitive_formation(actor_,game.model.enemies[actor_.forest_id],.016,0)
	print("FORMATION_HEADLESS_COMPONENT formation_ms=%.3f"%[(Time.get_ticks_usec()-start)/24000.0])
	for actor in game.enemies:
		var formation:Dictionary=crowd._formations[actor.forest_id]
		check(formation.roots.size()==1,"A crowd actor allocates only one body")
		check(formation.roots[0].origin.distance_to(actor.position)<2,"Single-body presentation follows the authoritative actor")
	# Placement is owned by authoritative navigation, including elevations;
	# the renderer must not rerun companion disk/path searches.
	var actor=game.enemies[0];var data:Dictionary=game.model.enemies[actor.forest_id]
	for position in [Vector3(0,12,0),Vector3(0,9,84),Vector3(0,20,84)]:
		actor.position=position;data.pos=position
		var formation:Dictionary=crowd.primitive_formation(actor,data,.016,0)
		check(formation.roots.size()==1 and absf(formation.roots[0].origin.y-position.y)<.001,"Rendered root preserves the authoritative elevated surface")
	check(game.model.terrain.samples==before and game.model.terrain.disks==disks_before,"Rendering independent bodies performs no terrain support queries")
	game.queue_free();await process_frame
	print("ENEMY_FORMATION_PERFORMANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
