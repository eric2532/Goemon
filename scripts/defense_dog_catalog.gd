class_name DefenseDogCatalog
extends RefCounted
## The ten reference-led castle companions share one explicit combat contract.

const DOGS=[
	{"id":"kogane","name":"Kogane","role":"SHADOW SCOUT","description":"A quick, dependable front-line scout.","cost":150,"hp":260.0,"damage":58.0,"speed":8.2,"attack_interval":1.10,"color":"edba66"},
	{"id":"daigo","name":"Daigo","role":"IRON GUARDIAN","description":"Heavy armor absorbs 35% of damage.","cost":300,"hp":750.0,"damage":76.0,"speed":5.4,"attack_interval":1.45,"armor":0.35,"color":"d9a274"},
	{"id":"kage","name":"Kage","role":"BRAMBLE AMBUSHER","description":"Precise bites pierce armor and shields.","cost":260,"hp":300.0,"damage":100.0,"speed":7.8,"attack_interval":1.35,"piercing":true,"color":"9dc68b"},
	{"id":"arashi","name":"Arashi","role":"STORM TRACKER","description":"Storm bites slow enemies by 30%.","cost":260,"hp":360.0,"damage":60.0,"speed":8.0,"attack_interval":1.10,"slow_factor":0.7,"slow_duration":1.4,"color":"79d8df"},
	{"id":"haku","name":"Haku","role":"BLADE GUARD","description":"Sweeping attacks strike three raiders.","cost":320,"hp":430.0,"damage":85.0,"speed":6.8,"attack_interval":1.25,"cleave":3,"cleave_radius":3.5,"color":"dceaf0"},
	{"id":"suzu","name":"Suzu","role":"WARD KEEPER","description":"Heals nearby dogs: 12 HP every 3s.","cost":300,"hp":330.0,"damage":40.0,"speed":6.3,"attack_interval":1.25,"heal_amount":12.0,"heal_interval":3.0,"heal_radius":10.0,"color":"f2c58b"},
	{"id":"maboro","name":"Maboro","role":"MIRAGE WEAVER","description":"Mirage bites slow enemies by 40%.","cost":280,"hp":300.0,"damage":60.0,"speed":8.2,"attack_interval":1.20,"armor":0.20,"slow_factor":0.6,"slow_duration":1.8,"color":"b9a1e8"},
	{"id":"iwa","name":"Iwa","role":"SHIELD BREAKER","description":"A tough guardian with piercing bites.","cost":400,"hp":900.0,"damage":135.0,"speed":5.0,"attack_interval":1.70,"piercing":true,"armor":0.20,"color":"cba77e"},
	{"id":"mine","name":"Mine","role":"CLIFF RUNNER","description":"A swift fighter with light armor.","cost":230,"hp":360.0,"damage":68.0,"speed":9.0,"attack_interval":1.05,"armor":0.10,"color":"8dc6d9"},
	{"id":"hayate","name":"Hayate","role":"WIND STRIKER","description":"Fastest runner; rapid sweeping strikes.","cost":280,"hp":280.0,"damage":52.0,"speed":9.6,"attack_interval":1.0,"cleave":2,"cleave_radius":2.8,"color":"a1c9ef"},
]

static func definitions()->Array:
	var result: Array=[]
	for data in DOGS:result.append(_complete(data))
	return result

static func get_dog(id: String)->Dictionary:
	for data in DOGS:
		if data.id==id:return _complete(data)
	return {}

static func _complete(data: Dictionary)->Dictionary:
	var result=data.duplicate(true)
	result.asset="res://assets/models/dogs/%s.glb" % data.id
	result.portrait="res://assets/ui/dogs/%s.png" % data.id
	result.reach=1.55
	result.attack_duration=1.0
	result.hit_time=.38
	return result
