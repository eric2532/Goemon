class_name DefenseHeroCatalog
extends RefCounted
## First-pass allies share Goemon's combat; their imported designs stay distinct.
const HEROES=[
	{"id":"sen","name":"Sen","role":"SKY RONIN","color":"95c7e2"},
	{"id":"raku","name":"Raku","role":"EMBER BRAWLER","color":"f2a077"},
	{"id":"izumi","name":"Izumi","role":"FROST SCOUT","color":"b3dfef"},
	{"id":"gaku","name":"Gaku","role":"IRON PILGRIM","color":"dab879"},
	{"id":"shiro","name":"Shiro","role":"MOON DUELIST","color":"c4b0ed"},
	{"id":"banji","name":"Banji","role":"CLOCKWORK RUNNER","color":"dcb66e"},
	{"id":"touma","name":"Touma","role":"REED WANDERER","color":"9dc88f"},
	{"id":"roan","name":"Roan","role":"MOUNTAIN STRIKER","color":"e3b08c"},
	{"id":"nagi","name":"Nagi","role":"TIDE COURIER","color":"96ddd5"},
	{"id":"kuren","name":"Kuren","role":"FESTIVAL GUARD","color":"e0a7c6"},
]

static func definitions()->Array:
	var result: Array=[]
	for data in HEROES:result.append(_complete(data))
	return result

static func get_hero(id: String)->Dictionary:
	for data in HEROES:
		if data.id==id:return _complete(data)
	return {}

static func _complete(data: Dictionary)->Dictionary:
	var result=data.duplicate(true)
	result.description="Goemon's three-hit pipe combo."
	result.asset="res://assets/models/defense_heroes/%s.glb" % data.id
	result.portrait="res://assets/ui/defense_heroes/%s.png" % data.id
	result.cost=300
	result.hp=500.0
	result.damage=50.0
	result.speed=7.0
	result.reach=1.65
	result.attack_interval=1.95
	result.attack_duration=PipeCombo.DURATIONS[0]+PipeCombo.DURATIONS[1]+PipeCombo.DURATIONS[2]
	result.hit_time=PipeCombo.DURATIONS[0]*PipeCombo.CONTACT[0]
	return result
