extends RefCounted
## Forest melee responsiveness. Keep damage, full swing lengths and choreography;
## move the articulated contact earlier and shorten only the attacker's hit pause.
const CLASSES=["pirate","samurai","ninja","knight","dragoon","magic-swordsman","master-thief"]
static func applies(game,id: String)->bool:
	return game.has_method("forest_enemy_visible") and id in CLASSES
static func contact_time(original: float)->float:
	return minf(original,clampf(original*.62,.05,.12))
static func tune(attack: Dictionary):
	attack.contact=minf(contact_time(attack.contact),attack.duration*.45)
	attack.stop=minf(float(attack.get("stop",.045)),.045 if int(attack.get("index",0))>=2 else .025)
	attack.responsiveMelee=true
static func contact_guard(time: float,contact: float)->bool:
	return time>=contact-minf(.04,contact*.6) and time<contact+minf(.035,contact*.5)
