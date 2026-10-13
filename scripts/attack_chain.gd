class_name AttackChain
extends RefCounted

const GRACE=1.75
const UNLEASHED_LINKS=100
const SPEED_PER_LINK=.05
const MAX_MULTIPLIER=1.5
const DAMAGE_PER_LINK=.05
const MAX_DAMAGE_MULTIPLIER=1.5
var milestone=0
var announced_milestone=0
var count=0
var remaining=0.0
var previous=""
var current=""
var last_hit_action=""
var active_ticket: Dictionary={}
var generation=0
var sequence=0

func make_ticket(action: String)->Dictionary:
	return {"action":action,"generation":generation,"sequence":-1,"combo":count>0,"bonus":false,"damage_multiplier":damage_multiplier()}

func begin(action: String)->Dictionary:
	previous=last_hit_action;current=action
	active_ticket=make_ticket(action)
	return active_ticket

func bonus_ticket(source: Dictionary)->Dictionary:
	return {"action":"red_slash","generation":source.get("generation",-1),"sequence":-1,"combo":false,"bonus":true,"damage_multiplier":source.get("damage_multiplier",1.0)}

func confirm(ticket: Dictionary):
	if ticket.is_empty() or ticket.get("generation",-1)!=generation:return
	# An attack/cast earns one link; its separate red follow-up earns another.
	# Repeated beam/shield contacts refresh grace without farming links per tick.
	if ticket.sequence!=sequence:
		ticket.sequence=sequence;count+=1
		if not ticket.bonus:last_hit_action=ticket.action
	milestone=100 if count>=100 else (50 if count>=50 else (25 if count>=25 else 0))
	remaining=GRACE

func tick(delta: float,attacking: bool=false):
	if count==0:return
	# Finish a connected swing before counting the gap to the next hit.
	# Misses never qualify; held/persistent spells must keep making contact.
	if attacking and active_ticket.get("sequence",-1)==sequence and current not in ["beam","shield"]:return
	remaining=maxf(0,remaining-delta)
	if remaining<=0:
		count=0;milestone=0;announced_milestone=0;last_hit_action="";previous="";sequence+=1

func multiplier()->float:
	return minf(MAX_MULTIPLIER,1.0+maxi(0,count-1)*SPEED_PER_LINK)

func damage_multiplier()->float:
	return minf(MAX_DAMAGE_MULTIPLIER,1.0+count*DAMAGE_PER_LINK)

func damage_for(ticket: Dictionary)->float:
	# Snapshot per cast: every target, projectile and red follow-up gets the
	# same bonus, regardless of hit order. Old-run and unattributed hits stay normal.
	if ticket.get("generation",-1)!=generation:return 1.0
	return float(ticket.get("damage_multiplier",1.0))

func unleashed()->bool:return count>=UNLEASHED_LINKS

func energized()->bool:return count>0 and active_ticket.get("combo",false)

func reset():
	count=0;milestone=0;announced_milestone=0;remaining=0;previous="";current="";last_hit_action="";active_ticket={};generation+=1;sequence+=1

static func aim_point(enemy: Ninja)->Vector3:
	return enemy.global_position+Vector3.UP*(5.0 if enemy.ground_giant else (1.65 if enemy.boss else (1.1*Ninja.ELITE_SIZE if enemy.island_elite else 1.1)))

static func screen_target(hero: Hero,origin: Vector3,max_distance: float)->Ninja:
	var camera=hero.game.camera_rig.camera
	var best: Ninja=null
	var closest=max_distance*max_distance
	for enemy in hero.game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		if hero.game.has_method("forest_enemy_visible") and not hero.game.forest_enemy_visible(enemy):continue
		var point=aim_point(enemy)
		var distance=origin.distance_squared_to(point)
		if distance>closest or not camera.is_position_in_frustum(point):continue
		var ray=PhysicsRayQueryParameters3D.create(origin,point,1)
		if not hero.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		closest=distance;best=enemy
	return best
