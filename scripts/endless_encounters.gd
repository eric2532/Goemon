class_name EndlessEncounters
extends Node
# One recyclable slot per regular encounter: unlimited replacements, bounded live population.
var game: Node
var slots: Dictionary={}
var enabled=true
var respawn_count=0
func configure(spots: Array):
	slots.clear()
	var existing={}
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.boss and not enemy.practice:existing[enemy.encounter_id]=weakref(enemy)
	for i in range(spots.size()):
		var p: Vector2=spots[i];var id=str(i)
		slots[id]={"home":Vector3(p.x,game.world.height_at(p.x,p.y)+.15,p.y),"actor":existing.get(id),"remaining":float(game.tuning.respawn_delay)}
func living(slot: Dictionary)->Node:
	if slot.actor==null:return null
	var actor=slot.actor.get_ref()
	return actor if is_instance_valid(actor) and not actor.dead else null
func safe_spawn(home: Vector3):
	var shape=CapsuleShape3D.new();shape.radius=.7;shape.height=1.85
	var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=7
	for i in range(80):
		var pos=home
		if i>0:pos+=Vector3(cos(i*2.399963),0,sin(i*2.399963))*(2+floorf(i/12.0)*2)
		if not game.world.playable_bounds.grow(-3).has_point(Vector2(pos.x,pos.z)):continue
		pos.y=game.world.height_at(pos.x,pos.z)+.15
		if pos.y<0 or pos.distance_to(game.player.position)<game.tuning.respawn_safe_distance:continue
		var clear=true
		for gate in game.gates:
			if is_instance_valid(gate) and pos.distance_to(gate.position)<7:clear=false;break
		if not clear:continue
		query.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*1.1)
		if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
		return pos
	return null
func tick(delta: float):
	if not enabled or not game.playing or game.paused or game.transitioning:return
	# Cleared corpses must not accumulate stale references over an endless session.
	for i in range(game.enemies.size()-1,-1,-1):
		if not is_instance_valid(game.enemies[i]):game.enemies.remove_at(i)
	var budget=mini(int(game.tuning.respawn_batch),game.enemy_spawn_capacity())
	for id in slots:
		var slot: Dictionary=slots[id]
		if living(slot)!=null:
			slot.remaining=float(game.tuning.respawn_delay);continue
		slot.remaining-=delta
		if slot.remaining>0 or budget<=0:continue
		var pos=safe_spawn(slot.home)
		if pos==null:slot.remaining=1.0;continue
		var enemy=Ninja.new();enemy.game=game;enemy.encounter_id=id;enemy.variant=int(id)%4;enemy.position=pos
		enemy.process_mode=Node.PROCESS_MODE_PAUSABLE
		game.add_child(enemy);game.enemies.append(enemy);slot.actor=weakref(enemy)
		slot.remaining=float(game.tuning.respawn_delay);respawn_count+=1;budget-=1
		if game.area_states.has(game.area_index):game.area_states[game.area_index].enemies.erase(id)
		game.burst(pos+Vector3.UP,Color("ffb56a"),10,.7)
func _physics_process(delta):tick(delta)
