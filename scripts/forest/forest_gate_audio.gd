extends Node
## Keep one bounded voice pool, while routing each ally's own weapon sounds.
var game
var hero: Hero
var shared: Node
func play(event: String,options: Dictionary={}):
 var own=options.duplicate();own.character_id=hero.character_id
 if not own.has("ticket"):own.ticket=hero.active_ability._ticket if hero.is_rogue_character() else hero.attack_chain.active_ticket
 own.volume=float(own.get("volume",own.get("gain",1.0)))*.5
 shared.play(event,own)
func set_volume(value: float):shared.set_volume(value)
