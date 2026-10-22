extends SceneTree
## Regression: released leader attacks retain caster identity, sweep cover and stop with the wave.
var checks=0
var failures=0
var arena
var caster: Hero
var projectile_script

class Arena:
	extends Node3D
	var paused=false
	var playing=true
	var player: Hero
	var enemies=[]
	var confirmations=[]
	var sounds=[]
	func burst(_point: Vector3,_color: Color,_count: int,_scale: float=1.0):pass
	func confirm_impact(victim: Ninja,_point: Vector3,_direction: Vector3,_strength: int,_projectile: bool,_source_character: int=0):confirmations.append([victim,0])
	func confirm_ally_impact(victim: Ninja,_point: Vector3,_direction: Vector3,_strength: int,_projectile: bool,id: int=0):confirmations.append([victim,id])
	func sound(kind: String,_volume: float=1.0,_enemy: bool=false,_ticket: Dictionary={},id: int=0):sounds.append([kind,id])

class Victim:
	extends Ninja
	const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
	var fitted: Dictionary
	var received_ticket={}
	func _ready():
		hp=100;max_hp=100;body_radius=.5
		var capsule=CapsuleShape3D.new();capsule.radius=.5;capsule.height=1
		fitted={"shape":capsule,"center":Vector3.ZERO}
	func _physics_process(_delta):pass
	func combat_aim_point(from: Vector3)->Vector3:return combat_contact_point(from)
	func combat_contact_point(point: Vector3)->Vector3:
		return global_position+Contact._capsule_contact(fitted,point-global_position)
	func combat_segment_contact(from: Vector3,to: Vector3,radius: float)->Dictionary:
		var t=Contact._capsule_segment(fitted,from-global_position,to-global_position,radius)
		return {"point":combat_contact_point(from.lerp(to,t)),"t":t} if t>=0 else {}
	func take_hit(amount: float,_direction: Vector3,_heavy: bool,ticket: Dictionary={}):hp-=amount;received_ticket=ticket

func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func target(at: Vector3)->Victim:
	var enemy=Victim.new();enemy.position=at;arena.add_child(enemy);arena.enemies.append(enemy);return enemy
func shot(at: Vector3,velocity: Vector3,bomb: bool=false):
	var p=projectile_script.new();p.game=arena;p.hero=caster;p.source_character=15 if bomb else 14;p.bomb=bomb
	p.position=at;p.velocity=velocity;p.attack_ticket={"source_hero":weakref(caster),"action":"leader_test","chain_enabled":false}
	arena.add_child(p);p.set_physics_process(false);return p
func wall(at: Vector3,size: Vector3)->StaticBody3D:
	var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;body.position=at
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape);arena.add_child(body);return body
func clear_targets():
	for enemy in arena.enemies:enemy.free()
	arena.enemies.clear();arena.confirmations.clear();arena.sounds.clear()
func run():
	check(ResourceLoader.exists("res://scripts/recovered_leader_projectile.gd"),"Leader projectile implementation exists")
	if failures:quit(1);return
	projectile_script=load("res://scripts/recovered_leader_projectile.gd")
	arena=Arena.new();root.add_child(arena)
	caster=Hero.new();caster.character_id=14;arena.player=caster
	var far=target(Vector3(5,3,0));var near=target(Vector3(2,3,0))
	var p=shot(Vector3(0,3,0),Vector3(100,0,0));p._physics_process(.1)
	check(near.hp==72 and far.hp==100,"Fast fireball sweeps the nearest enemy regardless of enemy list order")
	check(near.received_ticket==p.attack_ticket,"Damage carries the original attack ticket")
	check(arena.confirmations.size()==1 and arena.confirmations[0][1]==0,"Matching local caster confirms local impact")
	check(arena.sounds.has(["fire_impact",14]),"Impact sound explicitly retains Ed's source identity")
	await process_frame;clear_targets()
	var barrier=wall(Vector3(2,3,0),Vector3(.3,5,6));await physics_frame;await physics_frame
	var covered=target(Vector3(4,3,0));p=shot(Vector3(0,3,0),Vector3(100,0,0));p._physics_process(.1)
	check(covered.hp==100 and p.is_queued_for_deletion(),"Solid world cover blocks fast fireballs before enemy contact")
	await process_frame;barrier.free();clear_targets()
	p=shot(Vector3(0,3,0),Vector3(2,1,0));arena.paused=true;var before=p.position;var life=p.lifetime;p._physics_process(.2)
	check(p.position==before and p.lifetime==life,"Pause freezes position, fuse and lifetime")
	arena.paused=false;arena.playing=false;p._physics_process(.1)
	check(p.is_queued_for_deletion(),"Wave end removes released projectiles")
	await process_frame;arena.playing=true
	var victim=target(Vector3(1,3,0));caster.character_id=2
	p=shot(Vector3(0,3,0),Vector3(20,0,0));p._physics_process(.1)
	check(victim.hp==72 and arena.confirmations[0][1]==14,"Roster switch preserves released Ed damage and attribution")
	await process_frame;clear_targets();caster.character_id=15
	var exposed=target(Vector3(0,3,1));covered=target(Vector3(2,3,0))
	barrier=wall(Vector3(1,3,0),Vector3(.2,5,1));await physics_frame;await physics_frame
	p=shot(Vector3(0,3,0),Vector3(0,9.9,0),true);p._physics_process(1.11)
	check(exposed.hp==72 and covered.hp==100,"Bomb fuse explodes against fitted hurt volumes while respecting cover")
	p._physics_process(.1)
	check(exposed.hp==72,"An exploding bomb cannot damage a victim twice")
	check(arena.sounds.has(["ben_bomb_explosion",15]),"Bomb impact sound retains Ben's source identity")
	await process_frame;barrier.free();clear_targets()
	var floor_body=wall(Vector3(0,-.1,0),Vector3(20,.2,20));await physics_frame;await physics_frame
	p=shot(Vector3(0,.3,0),Vector3(1,-5,0));p._physics_process(.1)
	check(not p.is_queued_for_deletion() and p.velocity.y>0,"Ed fireball bounces from a real floor collision")
	p.queue_free();await process_frame;floor_body.free()
	p=shot(Vector3(0,3,0),Vector3.ZERO);caster.free();p._physics_process(.1)
	check(p.is_queued_for_deletion(),"Invalid caster removes its projectile without hitting a replacement hero")
	await process_frame;arena.free()
	print("RECOVERED_LEADER_PROJECTILE_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
