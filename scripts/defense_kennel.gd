class_name DefenseKennel
extends Node

# Friendly companions own a separate, small population. They never enter the
# enemy roster or take a slot from the wave director's spawn budget.
const MAX_DOGS=8
const SUMMON_COOLDOWN=3.0
const TARGET_INTERVAL=.28
const CATALOG_PATH="res://scripts/defense_dog_catalog.gd"
const Dog=preload("res://scripts/defense_dog.gd")
var game: Node
var active=false
var menu_open=false
var generation=0
var cooldown_left=0.0
var dogs: Array=[]
var total_summoned=0
var total_lost=0
var last_error=""
var elapsed=0.0

func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE

func reset():
	active=false;menu_open=false;generation+=1;cooldown_left=0;elapsed=0
	for dog in dogs:
		if is_instance_valid(dog):dog.retire()
	dogs.clear();total_summoned=0;total_lost=0;last_error=""

func begin():
	reset()
	active=game.tower_defense_mode and game.encounters.get("beta_mode")==true

func definitions()->Array:
	if not ResourceLoader.exists(CATALOG_PATH):return []
	return load(CATALOG_PATH).definitions()

func get_profile(id: String)->Dictionary:
	if not ResourceLoader.exists(CATALOG_PATH):return {}
	return load(CATALOG_PATH).get_dog(id)

func capacity()->int:return MAX_DOGS
func make_actor():return Dog.new()
func full_message()->String:return "Your pack is full · 8 companions."

func living_count()->int:
	var count=0
	for dog in dogs:
		if is_instance_valid(dog) and not dog.dead and dog.generation==generation:count+=1
	return count

func reason(id: String)->String:
	if not active or not game.tower_defense_mode or game.encounters.get("beta_mode")!=true:return "Companions are available in Fire Siege."
	if not game.playing or game.won or game.transitioning or game.player.hp<=0 or game.encounters.base_hp<=0:return "Start a living Fire Siege run first."
	if game.encounters.phase in ["draft","complete"]:return "Finish the wave choice first."
	if game.paused and not menu_open:return "Resume the siege first."
	var data=get_profile(id)
	if data.is_empty():return "Choose a companion."
	if not ResourceLoader.exists(String(data.get("asset",""))):return "This companion's model is unavailable."
	if living_count()>=capacity():return full_message()
	if cooldown_left>0:return "Next summon in %.1f seconds." % cooldown_left
	if game.encounters.money<int(data.get("cost",0)):return "Need %d more gold." % (int(data.get("cost",0))-game.encounters.money)
	return ""

func can_summon(id: String)->bool:return reason(id).is_empty()

func summon(id: String)->bool:
	last_error=reason(id)
	if not last_error.is_empty():return false
	var data=get_profile(id).duplicate(true)
	var slot=0
	while slot<capacity():
		var taken=false
		for existing in dogs:
			if is_instance_valid(existing) and not existing.dead and existing.formation_index==slot:taken=true;break
		if not taken:break
		slot+=1
	var dog=make_actor();dog.game=game;dog.kennel=self;dog.profile=data
	dog.profile_id=id;dog.generation=generation;dog.formation_index=slot
	dog.position=spawn_position(slot)
	game.encounters.money-=int(data.get("cost",0))
	cooldown_left=SUMMON_COOLDOWN;total_summoned+=1
	add_child(dog);dogs.append(dog)
	return true

func spawn_position(index: int)->Vector3:
	var origin=Vector3(0,.15,195)
	var authored=game.world.get("dog_spawn_position")
	if authored is Vector3:origin=authored
	else:
		var wall=game.world.get_node_or_null("MainCastleWall")
		if wall!=null:origin=wall.global_position+Vector3(0,.15,15)
	return origin+Vector3((float(index%4)-1.5)*1.8,0,float(index/4)*2.7)

func owns(dog)->bool:
	return active and is_instance_valid(dog) and dog.kennel==self and dog.generation==generation and dogs.has(dog)

func running()->bool:
	return active and game.playing and not game.paused and not game.transitioning and not game.won and (game.player.hp>0 or game.is_fire_siege()) and game.encounters.base_hp>0

func tick(delta: float):
	if not running():return
	elapsed+=delta;cooldown_left=maxf(0,cooldown_left-delta)
	for index in range(dogs.size()-1,-1,-1):
		if not is_instance_valid(dogs[index]):dogs.remove_at(index)

func _physics_process(delta):tick(delta)

func record_loss(dog):
	if owns(dog):total_lost+=1

func valid_enemy(enemy)->bool:
	return is_instance_valid(enemy) and not enemy.dead and enemy.defense_lane>=0 and game.encounters.owns(enemy)

func enemy_target(enemy):
	if game.is_fire_siege():return null
	if not running() or not valid_enemy(enemy):return null
	# A close hero keeps the existing combat priority. Once a dog retaliation
	# starts, Ninja holds that exact target through its windup and contact.
	var best=12.0*12.0 if game.player.rogue_untargetable() else minf(12.0*12.0,enemy.position.distance_squared_to(game.player.position)*.8)
	var chosen=null
	for dog in dogs:
		if not owns(dog) or dog.dead:continue
		var distance=enemy.position.distance_squared_to(dog.position)
		if distance<best:
			var ray=PhysicsRayQueryParameters3D.create(enemy.position+Vector3.UP,dog.position+Vector3.UP*.7,1)
			if not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
			best=distance;chosen=dog
	return chosen

func boss_slam(enemy,origin: Vector3,radius: float,damage: float):
	if game.is_fire_siege():return
	if not running() or not valid_enemy(enemy):return
	for dog in dogs:
		if not owns(dog) or dog.dead:continue
		var offset=dog.global_position-origin
		if Vector2(offset.x,offset.z).length()>radius+.35 or absf(offset.y)>1.6:continue
		var ray=PhysicsRayQueryParameters3D.create(origin+Vector3.UP*.8,dog.global_position+Vector3.UP*.7,1)
		if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():dog.take_hit(damage,Vector3(offset.x,0,offset.z).normalized())
