extends RefCounted
var owner: Node
var collected: Dictionary={}
var check_left=0.0
var discovered: Dictionary={}
func configure(run: Node)->void:
	owner=run;reset()
func reset()->void:
	collected.clear();discovered.clear();check_left=0
	if not is_instance_valid(owner) or not is_instance_valid(owner.game):return
	for cache in owner.game.world.exploration_caches+owner.game.world.exploration_discoveries:
		if is_instance_valid(cache.visual):cache.visual.show()
func collected_count()->int:return collected.size()
func discovery_count()->int:return discovered.size()
func tick(delta: float)->void:
	if not is_instance_valid(owner) or not owner._running() or owner.phase!="setup" or not owner._living_hero():return
	check_left-=maxf(0,delta)
	if check_left>0:return
	check_left=.2
	var hero=owner.game.player
	for cache in owner.game.world.exploration_caches:
		if collected.has(cache.id) or hero.position.distance_squared_to(cache.position)>6.25:continue
		var query=PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP,cache.position+Vector3.UP,1)
		query.exclude=[hero.get_rid()]
		if not owner.game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
		collected[cache.id]=true;owner.money+=3
		if is_instance_valid(cache.visual):cache.visual.hide()
		owner._banner("SUPPLY CACHE · +3 GOLD · %d / 3 DISCOVERED" % collected.size(),3)

	for item in owner.game.world.exploration_discoveries:
		if discovered.has(item.id) or hero.position.distance_squared_to(item.position)>6.25:continue
		var query=PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP,item.position+Vector3.UP,1)
		query.exclude=[hero.get_rid()]
		if not owner.game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
		discovered[item.id]=true;owner.money+=item.reward
		if is_instance_valid(item.visual):item.visual.hide()
		owner._banner(item.message,6)
