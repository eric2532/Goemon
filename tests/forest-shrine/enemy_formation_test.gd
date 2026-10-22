extends SceneTree
# Regressions: each independent actor emits one body, with its own lifecycle.
const Crowd=preload("res://scripts/forest/forest_enemy_crowd.gd")
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
class Actor extends Node3D:
	var forest_id=0
	var variant=0
	var model=Node3D.new()
	var name_tag: Node3D
	var dead=false
	var distance_asleep=false
	var render_full=true
class CountingTerrain extends "res://scripts/forest/forest_ramparts.gd":
	var samples=0
	func height(x: float,z: float)->float:
		samples+=1
		return super.height(x,z)
class Model extends RefCounted:
	var enemies={}
	var navigation_revision=0
	var terrain=preload("res://scripts/forest/forest_ramparts.gd").new()
class Game extends Node3D:
	var playing=true
	var paused=false
	var transitioning=false
	var enemies=[]
	var model=Model.new()
	var hidden={}
	func forest_enemy_visible(actor):return not hidden.has(actor.forest_id)
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,label_: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func all_counts(crowd,kind: int,want: int)->bool:
	return crowd.primitive_batches[kind].all(func(slot):return slot.batch.multimesh.visible_instance_count==want)
func run():
	var game=Game.new();root.add_child(game)
	var crowd=Crowd.new();crowd.game=game;game.add_child(crowd);crowd.set_process(false)
	var batches=crowd.get_child_count()
	for kind in range(5):
		for index in range(2):
			var id=kind*10+index;var actor=Actor.new();actor.forest_id=id;actor.variant=kind;actor.position=Vector3(id*3,0,20)
			actor.add_child(actor.model);game.add_child(actor);game.enemies.append(actor)
			game.model.enemies[id]={"id":id,"variant":kind,"pos":actor.position,"facing":.3,"hp":100.0,"velocity":Vector3(1,0,2),"walk_phase":1.2,"frozen":0.0,"action":"walk"}
	crowd._process(.016)
	for kind in range(5):check(all_counts(crowd,kind,2),"Two independent actors render two bodies for role%d"%kind)
	for actor in game.enemies:
		var formation:Dictionary=crowd._formations[actor.forest_id]
		check(formation.roots.size()==1 and formation.parts.size()==1,"Each actor submits one body and one animation state")
		check(formation.roots[0].origin.distance_to(actor.position)<2,"The sole body follows its own actor")
	check(game.enemies.size()==10 and game.model.enemies.size()==10,"Batch rendering preserves ten independent simulation records")
	game.hidden[0]=true;crowd._process(.016)
	check(all_counts(crowd,0,1),"Fog hides exactly one actor's body")
	game.hidden.clear();var data:Dictionary=game.model.enemies[0];data.frozen_pose=data.duplicate();data.frozen=1
	crowd._process(.016)
	check(all_counts(crowd,0,2) and crowd._formations[0].frozen,"Freeze retains the actor's single body")
	var actor=game.enemies[0];actor.dead=true;game.model.enemies.erase(0);crowd._process(.2)
	check(all_counts(crowd,0,2) and crowd._death_age[0]>.19,"Death presentation retains exactly one departing figure")
	actor.free();crowd._process(.016)
	check(all_counts(crowd,0,1) and not crowd._formations.has(0),"Freeing an enemy removes exactly one rendered figure and its state")
	for id in range(100,172):
		var extra=Actor.new();extra.forest_id=id;extra.position=Vector3(id,0,20);extra.add_child(extra.model);game.add_child(extra);game.enemies.append(extra)
		game.model.enemies[id]={"id":id,"variant":0,"pos":extra.position,"facing":0.0,"hp":100.0}
	crowd._process(.016)
	check(all_counts(crowd,0,73),"Growing the batch draws one body per independent actor")
	check(crowd.primitive_batches[0].all(func(slot):return slot.batch.multimesh.instance_count>=73),"All compound-part batches grow together")
	check(crowd.get_child_count()==batches,"Independent enemies still share fixed rendering batches")
	crowd.clear()
	for kind in range(5):check(all_counts(crowd,kind,0),"Cleanup hides every role%d"%kind)
	check(crowd._poses.is_empty() and crowd._death_age.is_empty() and crowd._formations.is_empty(),"Cleanup drops per-actor presentation caches")
	game.queue_free();await process_frame
	print("ENEMY_FORMATION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
