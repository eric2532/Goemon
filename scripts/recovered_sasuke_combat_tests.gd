extends SceneTree
## Real swept-contact and input lifecycle regression tests for the recovered kit.
var checks=0
var failures=0
var Profile
var Combat
var Projectile
var arena
var caster

class Arena:
	extends Node3D
	var paused=false
	var transitioning=false
	var playing=true
	var player
	var enemies=[]
	var sounds=[]
	var confirmations=[]
	var chain=0
	var chain_timer=0.0
	func sound(kind: String,_volume: float=1.0,_enemy: bool=false,_ticket: Dictionary={},id: int=0):sounds.append([kind,id])
	func burst(_point: Vector3,_color: Color,_count: int,_scale: float=1.0):pass
	func confirm_impact(victim: Ninja,_point: Vector3,_direction: Vector3,_strength: int,_projectile: bool,_id: int=0):confirmations.append(victim)
	func confirm_ally_impact(victim: Ninja,_point: Vector3,_direction: Vector3,_strength: int,_projectile: bool,_id: int=0):confirmations.append(victim)

class Caster:
	extends Hero
	func _ready():pass
	func _physics_process(_delta):pass
	func attack_speed_multiplier()->float:return 1.0
	func damage_multiplier()->float:return 1.0
	func growth_multiplier()->float:return 1.0
	func combat_attack_direction()->Vector3:return Vector3.FORWARD
	func auto_attack_running()->bool:return false

class Victim:
	extends Ninja
	const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
	var fitted: Dictionary
	var received_ticket={}
	var freezes=[]
	func _ready():
		hp=100;max_hp=100;body_radius=.4
		var capsule=CapsuleShape3D.new();capsule.radius=.4;capsule.height=1.0
		fitted={"shape":capsule,"center":Vector3.ZERO}
	func _physics_process(_delta):pass
	func combat_aim_point(from: Vector3)->Vector3:return combat_contact_point(from)
	func combat_contact_point(point: Vector3)->Vector3:return global_position+Contact._capsule_contact(fitted,point-global_position)
	func combat_segment_contact(from: Vector3,to: Vector3,radius: float)->Dictionary:
		var t=Contact._capsule_segment(fitted,from-global_position,to-global_position,radius)
		return {"point":combat_contact_point(from.lerp(to,t)),"t":t} if t>=0 else {}
	func take_hit(amount: float,_direction: Vector3,_heavy: bool,ticket: Dictionary={}):hp-=amount;received_ticket=ticket
	func freeze_for(seconds: float):freezes.append(seconds)

func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func target(at: Vector3)->Victim:
	var enemy=Victim.new();enemy.position=at;arena.add_child(enemy);arena.enemies.append(enemy);return enemy
func shot(at: Vector3,velocity_: Vector3,kind: String="ice"):
	var p=Projectile.new();p.game=arena;p.hero=caster;p.kind=kind;p.position=at;p.velocity=velocity_
	p.attack_ticket={"source_hero":weakref(caster),"action":"sasuke_test","chain_enabled":false}
	arena.add_child(p);p.set_physics_process(false);return p
func wall(at: Vector3,size: Vector3)->StaticBody3D:
	var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;body.position=at
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size;collision.shape=box;body.add_child(collision);arena.add_child(body);return body
func clear_targets():
	for enemy in arena.enemies:enemy.free()
	arena.enemies.clear();arena.confirmations.clear()
func key(action: String,pressed: bool)->InputEventAction:
	var event=InputEventAction.new();event.action=action;event.pressed=pressed;return event
func run():
	for action in ["light_attack","heavy_attack","equip","sky_strike","surge","sprint"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	for path in ["recovered_sasuke_combat.gd","recovered_sasuke_projectile.gd","recovered_sasuke_combat_profile.gd"]:
		check(ResourceLoader.exists("res://scripts/"+path),"Sasuke implementation exists: "+path)
	if failures:quit(1);return
	Profile=load("res://scripts/recovered_sasuke_combat_profile.gd");Combat=load("res://scripts/recovered_sasuke_combat.gd");Projectile=load("res://scripts/recovered_sasuke_projectile.gd")
	check(Profile.combo_actions()==[0x68,0x69,0x6a],"Unlocked gold tier selects Sasuke source tier 3 actions")
	check(is_equal_approx(Profile.duration(0x68),8.0/30.0) and is_equal_approx(Profile.duration(0x6d),17.0/30.0),"Native action clocks end at frame count minus one with source rate")
	check(is_equal_approx(Profile.release_time("bomb"),4.0/30.0) and is_equal_approx(Profile.release_time("ice"),8.0/30.0),"Bomb and ice use decoded source handler release thresholds")
	arena=Arena.new();root.add_child(arena)
	caster=Caster.new();caster.character_id=16;caster.game=arena;arena.player=caster;arena.add_child(caster)
	var far=target(Vector3(5,3,0));var near=target(Vector3(2,3,0))
	var p=shot(Vector3(0,3,0),Vector3(100,0,0));p._physics_process(.1)
	check(near.hp<100 and far.hp==100,"Fast ice kunai sweeps the nearest fitted target")
	check(near.freezes.size()==1 and near.freezes[0]>0,"Ice contact calls real freeze lifecycle")
	check(near.received_ticket==p.attack_ticket,"Projectile preserves attack ticket")
	p._physics_process(.1);check(near.freezes.size()==1,"Resolved projectile freezes a target once")
	await process_frame;clear_targets()
	var barrier=wall(Vector3(2,3,0),Vector3(.3,5,6));await physics_frame;await physics_frame
	var covered=target(Vector3(4,3,0));p=shot(Vector3(0,3,0),Vector3(100,0,0));p._physics_process(.1)
	check(covered.hp==100 and covered.freezes.is_empty(),"World cover blocks ice damage and freezing")
	await process_frame;barrier.free();clear_targets()
	p=shot(Vector3(0,3,0),Vector3(1,2,0),"bomb");arena.paused=true;var before=p.position;var life=p.lifetime;p._physics_process(.2)
	check(p.position==before and p.lifetime==life,"Pause stops bomb fuse and motion")
	arena.paused=false;arena.playing=false;p._physics_process(.1)
	check(p.is_queued_for_deletion(),"Wave end removes live Sasuke projectiles")
	await process_frame;arena.playing=true
	var victim=target(Vector3(1,3,0));p=shot(Vector3(0,3,0),Vector3(20,0,0));p.damage_scale=2.0;caster.character_id=2;p._physics_process(.1)
	check(victim.hp==44 and victim.freezes.size()==1,"Roster switch preserves released projectile ownership and its damage snapshot")
	await process_frame;caster.character_id=16;clear_targets()
	var exposed=target(Vector3(0,3,1));covered=target(Vector3(2,3,0));barrier=wall(Vector3(1,3,0),Vector3(.2,5,1));await physics_frame;await physics_frame
	p=shot(Vector3(0,3,0),Vector3.ZERO,"bomb");p.explode(Vector3(0,3,0));var damaged_hp=exposed.hp;p.explode(Vector3(0,3,0))
	check(damaged_hp<100 and exposed.hp==damaged_hp and covered.hp==100,"Bomb splash uses fitted targets, cover and one damage per target")
	await process_frame;barrier.free();clear_targets()
	var combat=Combat.new();combat.hero=caster;combat.game=arena;caster.add_child(combat);combat.active=true
	combat.input(key("equip",true));combat.tick(.3)
	check(combat.mode=="ice_charge" and combat.is_attacking(),"Holding E enters original ice charge")
	combat.release_input(key("equip",false));check(combat.mode=="ice","Early E release selects one ice kunai")
	combat.cancel();combat.input(key("equip",true));combat.tick(2.1);combat.release_input(key("equip",false))
	check(combat.mode=="hail","Full E charge selects three ice kunai")
	combat.tick(8.0/30.0)
	var shots=get_nodes_in_group("sasuke_projectiles").filter(func(projectile):return projectile.kind=="hail" and not projectile.is_queued_for_deletion())
	check(shots.size()==3,"Charged native release creates exactly three live ice projectiles")
	if shots.size()==3:
		var angle=absf(shots[0].velocity.normalized().signed_angle_to(shots[1].velocity.normalized(),Vector3.UP))
		check(is_equal_approx(angle,PI/8.0),"Original1024-unit trigonometry produces22.5-degree Hail Beam spread")
	combat.hit();check(combat.mode=="hurt" and combat.action_id==0x1d and not combat.is_attacking(),"Damage interrupts offense with source-proven ordinary hit action1D")
	combat.tick(10.0);check(not combat.pose_active(),"Native hurt reaction returns to locomotion")
	combat.die();check(combat.action_id==0x2d and combat.pose_active() and not combat.is_attacking(),"Fatal reaction retains the original source-proven2D pose")
	combat.cancel();check(not combat.is_attacking() and not combat.primary_held and not combat.ice_held,"Cancel clears charge, held input and action")
	combat.input(key("equip",true));combat._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not combat.is_attacking() and not combat.ice_held,"Focus loss cancels charge")
	combat.input(key("equip",true));arena.paused=true;combat.tick(.2)
	check(not combat.is_attacking() and not combat.ice_held,"Pause cancels pending charge before release")
	arena.paused=false
	caster.model=load("res://scripts/recovered_sasuke_model.gd").new();caster.add_child(caster.model);caster.model.combat=combat
	var binding=InputEventKey.new();binding.physical_keycode=KEY_T
	InputMap.action_add_event("sky_strike",binding)
	var t_event=InputEventKey.new();t_event.physical_keycode=KEY_T;t_event.keycode=KEY_T;t_event.pressed=true
	combat.input(t_event);check(combat.mode=="hair_up" and combat.action_id==0x9a,"Physical T chooses the native upward hair action")
	combat.cancel();t_event.shift_pressed=true;combat.input(t_event)
	check(combat.mode=="hair_forward" and combat.action_id==0x6f,"Physical Shift+T chooses the native forward hair action")
	clear_targets()
	var hair_forward=target(Vector3(0,.8,-4.2))
	combat.start_hair(true)
	for frame in 16:combat.tick(1.0/30.0);combat.tick(1.0/30.0,true)
	check(hair_forward.hp==66,"Original forward hair collision curve reaches a real target4.2m ahead once")
	clear_targets()
	var hair_up=target(Vector3(0,5.1,0))
	combat.start_hair(false)
	for frame in 16:combat.tick(1.0/30.0);combat.tick(1.0/30.0,true)
	check(hair_up.hp==66,"Original upward hair collision curve hits a real elevated target once")
	clear_targets();hair_forward=target(Vector3(0,.8,-4.2))
	combat.start_hair(true);combat.hit()
	for frame in 16:combat.tick(1.0/30.0);combat.tick(1.0/30.0,true)
	check(hair_forward.hp==100,"Hurt interruption cancels pending native hair contact")
	arena.free()
	print("RECOVERED_SASUKE_COMBAT_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
