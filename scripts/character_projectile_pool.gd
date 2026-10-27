extends Node
## One cache for character projectiles; profiles retain their original visuals.
const BASE=preload("res://scripts/character_projectile.gd")
signal launched(projectile:Node3D)
var idle:Dictionary={}
var all:Dictionary={}
var owners:Dictionary={}
var created=0
var reused=0
var misses=0

static func service(game:Node)->Node:
	var pool=game.get_node_or_null("CharacterProjectiles")
	if pool==null:
		pool=load("res://scripts/character_projectile_pool.gd").new();pool.name="CharacterProjectiles";game.add_child(pool)
	return pool

func key_for(owner:Node,script:Script,profile:String)->String:
	return "%d:%s:%s"%[owner.get_instance_id(),script.resource_path,profile]

func warm(owner:Node,script:Script,profile:String,config:Dictionary,count:int):
	var key=key_for(owner,script,profile)
	if not owners.has(owner.get_instance_id()):
		owners[owner.get_instance_id()]=weakref(owner)
		owner.tree_exiting.connect(discard_owner.bind(owner.get_instance_id()))
	if not all.has(key):all[key]=[];idle[key]=[]
	all[key]=all[key].filter(is_instance_valid);idle[key]=idle[key].filter(is_instance_valid)
	while all[key].size()<count:
		var node=script.new();assert(node is BASE)
		node.game=owner.game;node.hero=owner
		configure(node,config);add_child(node)
		node.projectile_pool=self;node.pool_key=key
		# Snapshot only script state. Cached scene nodes/materials stay prepared.
		for property in node.get_property_list():
			var name:String=property.name
			if not property.usage&PROPERTY_USAGE_SCRIPT_VARIABLE or name.begins_with("pool_") or name in ["script","game","hero","visual_source","projectile_pool"]:continue
			var value=node.get(name)
			if value is Node:continue
			node.pool_defaults[name]=copy_state(value)
		for name in node.get_meta_list():node.pool_metadata[name]=copy_state(node.get_meta(name))
		node.pool_defaults.attack_ticket={}
		if node.pool_defaults.has("target"):node.pool_defaults.target=null
		node.pool_groups.assign(node.get_groups());all[key].append(node);created+=1
		node.pool_live=true;release(node)

func launch(owner:Node,script:Script,profile:String,config:Dictionary)->Node3D:
	var key=key_for(owner,script,profile)
	while idle.has(key) and not idle[key].is_empty() and not is_instance_valid(idle[key].back()):idle[key].pop_back()
	if not idle.has(key) or idle[key].is_empty():
		# Unexpected concurrency grows the cache rather than deleting a live shot.
		var setup={}
		for field in ["kind","source_character","bomb","shuriken","axe","heavy","hostile","combo_energy","cross_slash","visual_source","balance","coin_count","metadata"]:
			if config.has(field):setup[field]=config[field]
		misses+=1;warm(owner,script,profile,setup,(all[key].filter(is_instance_valid).size() if all.has(key) else 0)+1)
	var node=idle[key].pop_back();reused+=1
	for name in node.pool_defaults:node.set(name,copy_state(node.pool_defaults[name]))
	for name in node.get_meta_list():node.remove_meta(name)
	for name in node.pool_metadata:node.set_meta(name,copy_state(node.pool_metadata[name]))
	node.hero=owner;node.transform=Transform3D.IDENTITY
	configure(node,config);node.tune_launch();node.pool_live=true
	for group in node.pool_groups:node.add_to_group(group)
	node.process_mode=Node.PROCESS_MODE_PAUSABLE;node.set_physics_process(true);node.show();node.reset_visual_tuning();node.restart_visual();node.tune_visual()
	launched.emit(node)
	return node

func configure(node:Node,config:Dictionary):
	for name in config:
		if name=="metadata":
			for meta in config.metadata:node.set_meta(meta,config.metadata[meta])
		else:node.set(name,config[name])

func release(node:Node3D):
	if not node.pool_live:return
	node.pool_live=false;node.hide();node.process_mode=Node.PROCESS_MODE_DISABLED
	node.attack_ticket={};node.hero=null
	if node.get("visual_source")!=null:node.set("visual_source",null)
	if node.get("target")!=null:node.set("target",null)
	for field in ["hit_targets","hit_enemies","hit_buildings"]:
		if node.get(field) is Dictionary:node.get(field).clear()
	for group in node.pool_groups:node.remove_from_group(group)
	if idle.has(node.pool_key):idle[node.pool_key].append(node)

func release_owner(owner:Node):
	var prefix=str(owner.get_instance_id())+":"
	for key in all:
		if not str(key).begins_with(prefix):continue
		for node in all[key]:
			if is_instance_valid(node) and node.pool_live:release(node)

func discard_owner(id:int):
	for key in all.keys():
		if not str(key).begins_with(str(id)+":"):continue
		for node in all[key]:
			if is_instance_valid(node):node.pool_live=false;node.process_mode=Node.PROCESS_MODE_DISABLED;node.queue_free()
		all.erase(key);idle.erase(key)
	owners.erase(id)

static func copy_state(value):
	return value.duplicate(true) if value is Dictionary or value is Array else value

static func free_slot(slots:Array,state:String,kind:String="")->Dictionary:
	for slot in slots:
		if not slot[state] and (kind.is_empty() or slot.kind==kind):return slot
	return {}

static func clear_slot(slot:Dictionary,state:String,visual:Node3D):
	slot[state]=false;visual.hide()
	for field in ["ticket","hits"]:
		if slot.has(field):slot[field]={}
	if slot.has("target"):slot.target=null
	if slot.has("velocity"):slot.velocity=Vector3.ZERO

static func retire_visual(mesh:Node3D,lease:int=-1):
	if not is_instance_valid(mesh) or mesh.is_queued_for_deletion():return
	if lease>=0 and lease!=mesh.get_meta("army_projectile_generation",-1):return
	var owner_ref=mesh.get_meta("army_projectile_owner") if mesh.has_meta("army_projectile_owner") else null
	var owner=owner_ref.get_ref() if owner_ref is WeakRef else null
	if is_instance_valid(owner):owner.recycle_projectile(mesh)
	else:mesh.queue_free()
