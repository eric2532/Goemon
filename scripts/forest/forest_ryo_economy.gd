extends RefCounted
## The playable game credits enemy bounties at death. Ground-loot helpers remain
## available for archived scenarios and isolated asset tests.
const BOUNTIES=[12,12,60,12,250]
const MAGNET_RADIUS=10.0
const COLLECTION_RADIUS=1.3
const PICKUP_HEIGHT=1.0
const REST_HEIGHT=.85
const LAUNCH_SECONDS=.42
const MAGNET_DELAY=.16
const MERGE_RADIUS=1.25
const MERGE_CELL=2.0
const DROP_LIFETIME=10.0
var reference:WeakRef
var m:
	get:return reference.get_ref()
var drops:Dictionary={}
var collected_events:Array=[]
var claimed_enemies:Dictionary={}
var pending_bounty_total=0
var next_id=1
var merge_buckets:Dictionary={}
var clear_query:Callable
var elapsed=0.0
var moving_drops:Dictionary={}
var resting_buckets:Dictionary={}
var expiry_events:Array=[]
var expiry_head=0
var native_query:Object
var collector_points=PackedVector3Array()
var collector_ids:Array=[]

func _init(model):reference=weakref(model)

func reset():
	drops.clear();claimed_enemies.clear();merge_buckets.clear();collected_events.clear()
	moving_drops.clear();resting_buckets.clear();elapsed=0.0
	expiry_events.clear();expiry_head=0
	pending_bounty_total=0
	next_id=1;clear_query=Callable();native_query=null;collector_points=PackedVector3Array();collector_ids=[]

func award_enemy_bounty(enemy:Dictionary)->int:
	var enemy_id=int(enemy.get("id",-1))
	var health=float(enemy.get("hp",1))
	if m==null or enemy_id<0 or not is_finite(health) or health>0 or claimed_enemies.has(enemy_id):return 0
	var value:int=BOUNTIES[clampi(int(enemy.get("variant",0)),0,BOUNTIES.size()-1)]
	claimed_enemies[enemy_id]=true
	m.gold+=value
	pending_bounty_total+=value
	return value

func take_bounty_total()->int:
	var total=pending_bounty_total
	pending_bounty_total=0
	return total

func spawn_enemy_drop(enemy:Dictionary)->int:
	var enemy_id=int(enemy.get("id",-1))
	if enemy_id<0 or float(enemy.get("hp",1))>0 or claimed_enemies.has(enemy_id):return -1
	var point:Vector3=enemy.get("pos",Vector3.ZERO)
	if not point.is_finite():return -1
	var value:int=BOUNTIES[clampi(int(enemy.get("variant",0)),0,BOUNTIES.size()-1)]
	claimed_enemies[enemy_id]=true
	var floor_y:float=m.surface_height(point.x,point.z)
	point.y=maxf(point.y,floor_y)+REST_HEIGHT
	var cell=_merge_cell(point)
	for x in range(-1,2):
		for z in range(-1,2):
			for id in merge_buckets.get(cell+Vector2i(x,z),[]):
				if not drops.has(id):continue
				var previous:Dictionary=drops[id]
				# Never teleport an in-flight bounty to a new death location.
				if previous.target_id!="" or previous.origin.distance_squared_to(point)>MERGE_RADIUS*MERGE_RADIUS:continue
				if previous.pos.distance_squared_to(point)>MERGE_RADIUS*MERGE_RADIUS:continue
				if not _clear(previous.pos,point):continue
				previous.value+=value
				_schedule_expiry(id,previous)
				return id
	var id=next_id;next_id+=1
	drops[id]={"id":id,"value":value,"pos":point,"origin":point,"floor_y":floor_y,
		"age":0.0,"speed":8.0,"target_id":"","merged_cell":cell}
	moving_drops[id]=true
	if not merge_buckets.has(cell):merge_buckets[cell]=[]
	merge_buckets[cell].append(id)
	_schedule_expiry(id,drops[id])
	return id

func _schedule_expiry(id:int,drop:Dictionary):
	# A fresh kill gives a merged pile a full pickup window. Deadlines are
	# chronological, so distant sleeping loot needs no per-frame age scan.
	drop.expires_at=elapsed+DROP_LIFETIME
	expiry_events.append({"id":id,"at":drop.expires_at})

func _expire_drops():
	while expiry_head<expiry_events.size():
		var event:Dictionary=expiry_events[expiry_head]
		if float(event.at)>elapsed+.000001:break
		expiry_head+=1
		if not drops.has(event.id):continue
		var drop:Dictionary=drops[event.id]
		# Collection and subsequent merges may have made this event obsolete.
		if float(drop.expires_at)<=elapsed+.000001:_remove_drop(int(event.id),drop)
	if expiry_head==expiry_events.size():
		expiry_events.clear();expiry_head=0
	elif expiry_head>=1024 and expiry_head*2>=expiry_events.size():
		expiry_events=expiry_events.slice(expiry_head);expiry_head=0

func tick(delta:float,collectors:Array,paused:bool=false,clear_path:Callable=Callable(),packed:Dictionary={}):
	if paused or delta<=0 or m==null or m.phase not in ["wave","preparing","victory"]:return
	clear_query=clear_path;elapsed+=delta
	_expire_drops()
	# Keep time and expiry live, but there is nothing to attract without loot.
	if drops.is_empty():
		native_query=null;collector_points=PackedVector3Array();collector_ids=[]
		return
	var buckets:Dictionary={}
	var nearby_cells:Dictionary={}
	var runtime=m.get("army_runtime")
	native_query=runtime.native if is_instance_valid(runtime) else null
	collector_points=PackedVector3Array();collector_ids=[]
	if native_query!=null and packed.get("valid",false):
		collector_points=packed.positions;collector_ids=packed.ids;buckets=packed.cells
	else:
		for collector:Dictionary in collectors:
			if float(collector.get("hp",0))<=0 or collector.get("dead",false) or not collector.get("active",true) or collector.get("state","")=="wounded":continue
			var foot:Vector3=collector.get("pos",Vector3.ZERO)
			if not foot.is_finite():continue
			var point=foot+Vector3.UP*PICKUP_HEIGHT
			var cell=_collector_cell(point)
			if native_query!=null:
				collector_points.append(point);collector_ids.append(str(collector.get("id","")));buckets[cell]=true
			else:
				var row={"id":str(collector.get("id","")),"pos":point}
				if not buckets.has(cell):buckets[cell]=[]
				buckets[cell].append(row)
	# Expanding one shared collector cell once preserves insertion order while
	# avoiding nine identical wake-cell writes for every overlapping ally.
	for cell in buckets:
		for x in range(-1,2):
			for z in range(-1,2):nearby_cells[cell+Vector2i(x,z)]=true
	# Distant settled loot sleeps until expiry or until a collector approaches.
	# Collector movement wakes nearby coins on this same tick.
	var active=moving_drops.duplicate()
	for cell in nearby_cells:
		for id in resting_buckets.get(cell,{}):active[id]=true
	for id in active:
		var drop:Dictionary=drops[id]
		if drop.has("resting_cell"):
			drop.age=age_of(drop);drop.resting_at=elapsed
		else:drop.age+=delta
		var nearest:Dictionary={}
		if drop.age>=MAGNET_DELAY:nearest=_nearest(drop.pos,buckets)
		if nearest.is_empty():
			drop.target_id="";drop.speed=8.0
			# The initial upward arc settles at the death location. A released
			# magnet flight falls where its collector was lost.
			var floor_y:float=drop.floor_y if drop.has("resting_cell") else m.surface_height(drop.pos.x,drop.pos.z)
			drop.floor_y=floor_y
			var rest_y=floor_y+REST_HEIGHT
			if drop.age<LAUNCH_SECONDS:
				drop.pos.y=drop.origin.y+sin(drop.age/LAUNCH_SECONDS*PI)*1.25
			else:drop.pos.y=move_toward(float(drop.pos.y),rest_y,delta*7.0)
			if drop.age>=LAUNCH_SECONDS and is_equal_approx(float(drop.pos.y),rest_y):_rest_drop(id,drop)
			continue
		_wake_drop(id,drop)
		drop.target_id=nearest.id
		drop.speed=minf(28.0,float(drop.speed)+delta*42.0)
		var target:Vector3=nearest.pos
		drop.pos=drop.pos.move_toward(target,drop.speed*delta)
		if drop.pos.distance_squared_to(target)<=COLLECTION_RADIUS*COLLECTION_RADIUS:
			m.gold+=int(drop.value)
			_record_collection(drop,nearest)
			_remove_drop(id,drop)

func age_of(drop:Dictionary)->float:
	# Rendering keeps the original animation phase even while a coin sleeps.
	return float(drop.age)+(elapsed-float(drop.resting_at) if drop.has("resting_cell") else 0.0)

func _rest_drop(id:int,drop:Dictionary):
	moving_drops.erase(id)
	if drop.has("resting_cell"):return
	var cell=_collector_cell(drop.pos)
	drop.resting_cell=cell;drop.resting_at=elapsed
	if not resting_buckets.has(cell):resting_buckets[cell]={}
	resting_buckets[cell][id]=true

func _wake_drop(id:int,drop:Dictionary):
	if drop.has("resting_cell"):
		var cell:Vector2i=drop.resting_cell
		resting_buckets[cell].erase(id)
		if resting_buckets[cell].is_empty():resting_buckets.erase(cell)
		drop.erase("resting_cell");drop.erase("resting_at")
	moving_drops[id]=true

func _nearest(point:Vector3,buckets:Dictionary)->Dictionary:
	if native_query!=null:
		for index in native_query.nearby_points(collector_points,point,MAGNET_RADIUS):
			if _clear(point,collector_points[index]):return {"id":collector_ids[index],"pos":collector_points[index]}
		return {}
	var best:Dictionary={}
	var distance=MAGNET_RADIUS*MAGNET_RADIUS
	var cell=_collector_cell(point)
	for x in range(-1,2):
		for z in range(-1,2):
			for candidate:Dictionary in buckets.get(cell+Vector2i(x,z),[]):
				var next_distance=point.distance_squared_to(candidate.pos)
				if next_distance==distance and not best.is_empty():continue
				if next_distance>distance or not _clear(point,candidate.pos):continue
				best=candidate;distance=next_distance
	return best

func _clear(from:Vector3,to:Vector3)->bool:
	return not clear_query.is_valid() or bool(clear_query.call(from,to))

func _collector_cell(point:Vector3)->Vector2i:
	return Vector2i(floori(point.x/MAGNET_RADIUS),floori(point.z/MAGNET_RADIUS))

func _merge_cell(point:Vector3)->Vector2i:
	return Vector2i(floori(point.x/MERGE_CELL),floori(point.z/MERGE_CELL))

func _remove_drop(id:int,drop:Dictionary):
	_wake_drop(id,drop);moving_drops.erase(id)
	drops.erase(id)
	var cell:Vector2i=drop.merged_cell
	var entries:Array=merge_buckets.get(cell,[])
	entries.erase(id)
	if entries.is_empty():merge_buckets.erase(cell)

func _record_collection(drop:Dictionary,collector:Dictionary):
	for event:Dictionary in collected_events:
		if event.collector_id==collector.id:
			event.value+=int(drop.value);event.pos=collector.pos
			return
	collected_events.append({"value":int(drop.value),"collector_id":collector.id,"pos":collector.pos})

func take_collected_events()->Array:
	var result=collected_events
	collected_events=[]
	return result

func uncollected_value()->int:
	var total=0
	for drop:Dictionary in drops.values():total+=int(drop.value)
	return total
