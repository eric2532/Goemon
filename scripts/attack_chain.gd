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
const SkillBalance=preload("res://scripts/spells/skill_balance.gd")
var generation=0
var sequence=0
var hero_owner: WeakRef

# Goemon's three-hit pipe sequence is self-contained. Other fighters retain
# the shared hit-chain bonuses; tickets still carry ownership and audio for him.
func enabled()->bool:
	var hero=hero_owner.get_ref() if hero_owner!=null else null
	return not is_instance_valid(hero) or hero.character_id!=1

func make_ticket(action: String)->Dictionary:
	var hero=hero_owner.get_ref() if hero_owner!=null else null
	var chance: float=hero.combat_tuning("critical_chance") if is_instance_valid(hero) else 0.0
	var ticket={"allied":is_instance_valid(hero) and hero.ai_controlled,"source_hero":hero_owner,"action":action,"chain_enabled":enabled(),"generation":generation,"sequence":-1,"combo":enabled() and count>0,"bonus":false,"damage_multiplier":damage_multiplier(),"critical_chance":chance}
	if is_instance_valid(hero) and hero.spell_loadout!=null:hero.spell_loadout.decorate_ticket(ticket,action)
	if is_instance_valid(hero):SkillBalance.decorate(hero,ticket,action)
	return ticket

func begin(action: String,move_key: String="")->Dictionary:
	previous=last_hit_action;current=action
	active_ticket=make_ticket(action)
	var hero=hero_owner.get_ref() if hero_owner!=null else null
	if is_instance_valid(hero) and is_instance_valid(hero.game) and hero.game.get("move_audio")!=null:
		active_ticket["move_audio"]=hero.game.move_audio.begin(hero,action,move_key)
	return active_ticket

func bonus_ticket(source: Dictionary)->Dictionary:
	var ticket={"allied":source.get("allied",false),"source_hero":source.get("source_hero"),"action":"red_slash","chain_enabled":source.get("chain_enabled",enabled()),"generation":source.get("generation",-1),"sequence":-1,"combo":false,"bonus":true,"damage_multiplier":source.get("damage_multiplier",1.0),"critical_chance":source.get("critical_chance",0.0)}
	for key in ["skill_id","skill_size","skill_hit_area","skill_travel_speed","skill_damage"]:
		if source.has(key):ticket[key]=source[key]
	return ticket

func confirm(ticket: Dictionary):
	if not enabled() or not ticket.get("chain_enabled",true):return
	if ticket.is_empty() or ticket.get("generation",-1)!=generation:return
	# An attack/cast earns one link; its separate red follow-up earns another.
	# Repeated beam/shield contacts refresh grace without farming links per tick.
	if ticket.sequence!=sequence:
		ticket.sequence=sequence;count+=1
		if not ticket.bonus:last_hit_action=ticket.action
	milestone=100 if count>=100 else (50 if count>=50 else (25 if count>=25 else 0))
	remaining=GRACE

func tick(delta: float,attacking: bool=false):
	if not enabled():
		if count>0:
			# Clear live links without invalidating another fighter's released spells.
			count=0;remaining=0;milestone=0;announced_milestone=0;last_hit_action="";previous="";sequence+=1
		return
	if count==0:return
	# Finish a connected swing before counting the gap to the next hit.
	# Misses never qualify; held/persistent spells must keep making contact.
	if attacking and active_ticket.get("sequence",-1)==sequence and current not in ["beam","shield"]:return
	remaining=maxf(0,remaining-delta)
	if remaining<=0:
		count=0;milestone=0;announced_milestone=0;last_hit_action="";previous="";sequence+=1

func multiplier()->float:
	if not enabled():return 1.0
	return minf(MAX_MULTIPLIER,1.0+maxi(0,count-1)*SPEED_PER_LINK)

func damage_multiplier()->float:
	if not enabled():return 1.0
	return minf(MAX_DAMAGE_MULTIPLIER,1.0+count*DAMAGE_PER_LINK)

func damage_for(ticket: Dictionary)->float:
	# Snapshot per cast: every target, projectile and red follow-up gets the
	# same bonus, regardless of hit order. Old-run and unattributed hits stay normal.
	var skill=SkillBalance.factor(ticket,"damage")
	if not ticket.get("chain_enabled",enabled()) or ticket.get("generation",-1)!=generation:return skill
	return float(ticket.get("damage_multiplier",1.0))*skill

func unleashed()->bool:return enabled() and count>=UNLEASHED_LINKS

func energized()->bool:return enabled() and count>0 and active_ticket.get("combo",false)

func reset():
	count=0;milestone=0;announced_milestone=0;remaining=0;previous="";current="";last_hit_action="";active_ticket={};generation+=1;sequence+=1

static func enemy_candidates(game:Node,center:Vector3,radius:float)->Array:
	var army=game.get("army_runtime")
	if is_instance_valid(army) and game.get_tree().get_meta("forest_army_bounded_queries",true):return army.enemy_candidates(center,radius)
	return game.enemies

static func segment_enemy_candidates(game:Node,from:Vector3,to:Vector3,radius:float)->Array:
	if game.enemies.is_empty():return []
	# Fitted boxes expand along local axes; rotation can project that padding.
	return enemy_candidates(game,from.lerp(to,.5),from.distance_to(to)*.5+maxf(0,radius)*1.732051)

static func world_ray(context:Node3D,from:Vector3,to:Vector3,mask:int=1,exclude:Array[RID]=[],inside:bool=true)->Dictionary:
	var query=PhysicsRayQueryParameters3D.create(from,to,mask,exclude)
	query.hit_from_inside=inside
	return context.get_world_3d().direct_space_state.intersect_ray(query)

static func clear_line(context:Node3D,from:Vector3,to:Vector3,exclude:Array[RID]=[],inside:bool=true)->bool:
	return from.distance_squared_to(to)<.000001 or world_ray(context,from,to,1,exclude,inside).is_empty()

static func nearest_contact(game:Node,context:Node3D,from:Vector3,to:Vector3,radius:float,hits:Dictionary={})->Dictionary:
	var nearest:Dictionary={};var first=INF
	for enemy in segment_enemy_candidates(game,from,to,radius):
		if not is_instance_valid(enemy) or enemy.dead or hits.has(enemy.get_instance_id()):continue
		var contact=segment_contact(enemy,from,to,radius)
		if contact.is_empty() or float(contact.t)>=first:continue
		var center=from.lerp(to,float(contact.t))
		if not clear_line(context,center,aim_point(enemy,center)):continue
		first=float(contact.t);nearest={"enemy":enemy,"point":contact.point,"center":center,"t":first}
		if first==0:return nearest # Source order already wins ties at the segment start.
	return nearest

static func contact_point(enemy: Ninja,from: Vector3,fallback: Vector3)->Vector3:
	return enemy.combat_contact_point(from) if enemy.has_method("combat_contact_point") else fallback

static func segment_contact(enemy: Ninja,from: Vector3,to: Vector3,radius: float,legacy_center: Vector3=Vector3.INF)->Dictionary:
	if enemy.has_method("combat_segment_contact"):return enemy.combat_segment_contact(from,to,radius)
	var center=aim_point(enemy) if legacy_center==Vector3.INF else legacy_center
	var nearest=Geometry3D.get_closest_point_to_segment(center,from,to)
	if nearest.distance_to(center)>radius+enemy.body_radius:return {}
	var length=from.distance_to(to)
	return {"point":nearest,"t":from.distance_to(nearest)/length if length>.0001 else 0.0}

static func aim_point(enemy: Ninja,from: Vector3=Vector3.INF)->Vector3:
	if enemy.has_method("combat_aim_point"):
		if from==Vector3.INF:from=enemy.game.player.global_position+Vector3.UP*1.1
		return enemy.combat_aim_point(from)
	return enemy.global_position+Vector3.UP*(5.0 if enemy.ground_giant else (1.65 if enemy.boss else (1.1*Ninja.ELITE_SIZE if enemy.island_elite else 1.1)))

static func screen_target(hero: Hero,origin: Vector3,max_distance: float,camera_sight: bool=false)->Ninja:
	var camera=hero.game.camera_rig.camera
	var best: Ninja=null
	var closest=max_distance*max_distance
	for enemy in enemy_candidates(hero.game,origin,max_distance):
		if not is_instance_valid(enemy) or enemy.dead:continue
		if hero.game.has_method("forest_enemy_visible") and not hero.game.forest_enemy_visible(enemy):continue
		var point=aim_point(enemy,origin)
		var distance=origin.distance_squared_to(point)
		if distance>closest or not camera.is_position_in_frustum(point):continue
		if camera_sight:
			var sight=PhysicsRayQueryParameters3D.create(camera.global_position,point,1)
			if not hero.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():continue
		var ray=PhysicsRayQueryParameters3D.create(origin,point,1)
		if not hero.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		closest=distance;best=enemy
	return best

static func beam_pulse(context:Node3D,caster:Hero,origin:Vector3,end:Vector3,radius:float,query_radius:float,amount:float,ticket:Dictionary,source:int):
	var direction=(end-origin).normalized()
	var reach=origin.distance_to(end)
	if reach<=.001:return
	BreakableBuilding.hit_segment(caster.game,origin,end+direction*.01,amount,ticket)
	var struck:Dictionary={}
	for enemy in segment_enemy_candidates(caster.game,origin,end,query_radius):
		if not is_instance_valid(enemy) or enemy.dead or struck.has(enemy.get_instance_id()):continue
		struck[enemy.get_instance_id()]=true
		var contact=segment_contact(enemy,origin,end,radius)
		if contact.is_empty():continue
		# Fitted end caps must not extend damage beyond the beam's end plane.
		var along:float=(contact.point-origin).dot(direction)
		if along<0 or along>reach or not clear_line(context,origin,contact.point,[caster.get_rid()]):continue
		enemy.take_hit(amount,direction,false,ticket)
		if caster.ai_controlled:caster.game.confirm_ally_impact(enemy,contact.point,direction,1,true,source,false)
		else:caster.game.confirm_impact(enemy,contact.point,direction,1,true,source,false)
