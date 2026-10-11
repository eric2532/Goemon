extends RefCounted
## A bounded objective controller; ordinary player combat owns separate timings.
const Clock=preload("res://scripts/shrine_attack_clock.gd")
var owner: Node
var generation=-1
var wave=-1
var slots: Array[Dictionary]=[]
var waiting_points: Array[Vector3]=[]
var records: Dictionary={}
var queue: Array[String]=[]
var refresh_left=0.0
var clearance=SphereShape3D.new()
func configure(run: Node)->void:
	clear();owner=run;generation=run.generation;wave=run.wave;clearance.radius=.9
	var center: Vector3=owner.game.world.base_position
	for i in range(48):
		var angle=TAU*float(i)/48
		var point=center+Vector3(cos(angle)*5.5,0,sin(angle)*5.5)
		if slots.size()<12 and legal(point):
			var separated=true
			for slot in slots:
				if slot.position.distance_squared_to(point)<2.4*2.4:separated=false;break
			if separated:slots.append({"position":point,"id":"","clock":Clock.new()})
		if i%2==0:
			var wait=center+Vector3(cos(angle)*10.5,0,sin(angle)*10.5)
			if legal(wait):waiting_points.append(wait)
func legal(point: Vector3)->bool:
	if not owner.game.world.playable_bounds.grow(-1.2).has_point(Vector2(point.x,point.z)):return false
	var q=PhysicsShapeQueryParameters3D.new();q.shape=clearance;q.collision_mask=1;q.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*1.2)
	return owner.game.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()
func valid(enemy: Ninja)->bool:
	return is_instance_valid(owner) and owner.generation==generation and owner.wave==wave and is_instance_valid(enemy) and not enemy.dead and owner.owns(enemy)
func handles(enemy: Ninja)->bool:
	return valid(enemy) and records.has(enemy.encounter_id) and records[enemy.encounter_id].actor.get_ref()==enemy
func admit(enemy: Ninja)->bool:
	if not valid(enemy):return false
	var id=enemy.encounter_id
	if records.has(id):
		if records[id].actor.get_ref()==enemy:return true
		release_id(id)
	var point: Vector3=waiting_points[queue.size()%waiting_points.size()] if not waiting_points.is_empty() else enemy.position
	records[id]={"actor":weakref(enemy),"slot":-1,"arrived":false,"waiting":point};queue.append(id)
	return true
func release(enemy: Ninja)->void:
	if is_instance_valid(enemy) and records.has(enemy.encounter_id) and records[enemy.encounter_id].actor.get_ref()==enemy:release_id(enemy.encounter_id)
func release_id(id: String)->void:
	if not records.has(id):return
	var index: int=records[id].slot
	if index>=0:slots[index].id="";slots[index].clock.reset()
	records.erase(id);queue.erase(id)
func unseat(id: String)->void:
	var record: Dictionary=records[id]
	var slot: Dictionary=slots[record.slot]
	slot.id="";slot.clock.reset();record.slot=-1;record.arrived=false
	if not waiting_points.is_empty():record.waiting=waiting_points[queue.size()%waiting_points.size()]
	queue.append(id)
func refresh()->void:
	for id in records.keys():
		if not valid(records[id].actor.get_ref()):release_id(id)
	for i in range(slots.size()):
		if not slots[i].id.is_empty() or queue.is_empty():continue
		var id=queue.pop_front()
		slots[i].id=id;slots[i].clock.reset();records[id].slot=i
func tick(delta: float)->void:
	if not is_instance_valid(owner):return
	if owner.generation!=generation or owner.wave!=wave:clear();return
	if not owner._running() or owner.phase not in ["spawning","clearance"]:return
	var dt=maxf(0,delta);refresh_left-=dt
	if refresh_left<=0:refresh_left=.2;refresh()
	for slot in slots:
		if slot.id.is_empty():continue
		var enemy=records[slot.id].actor.get_ref()
		if not valid(enemy):release_id(slot.id);continue
		var close=enemy.position.distance_squared_to(slot.position)<1.25*1.25
		var record: Dictionary=records[slot.id]
		if record.arrived and not close:unseat(slot.id);continue
		if close:record.arrived=true
		var eligible=close and enemy.stun<=0 and enemy.frozen_left<=0 and enemy.impact_pause<=0
		if not slot.clock.advance(dt,eligible,false):continue
		var ray=PhysicsRayQueryParameters3D.create(enemy.global_position+Vector3.UP,owner.game.world.base_position+Vector3.UP,1)
		if not owner.game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():slot.clock.reset();continue
		if owner.call("apply_shrine_contact",enemy)!=true:slot.clock.reset()
func assignment(enemy: Ninja)->Dictionary:
	if not handles(enemy):return {}
	var record: Dictionary=records[enemy.encounter_id]
	if record.slot<0:return {"position":record.waiting,"attacking":false,"pose":&"chase"}
	var slot: Dictionary=slots[record.slot]
	return {"position":slot.position,"attacking":true,"pose":slot.clock.pose() if record.arrived else &"chase"}
func attackers()->int:
	var count=0
	for slot in slots:
		if not slot.id.is_empty() and records[slot.id].arrived:count+=1
	return count
func waiting_count()->int:return queue.size()
func clear()->void:
	slots.clear();waiting_points.clear();records.clear();queue.clear();refresh_left=0
