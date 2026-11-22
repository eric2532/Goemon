extends RefCounted
## Chance is snapshotted by the caster and checked at each enemy contact.
const DAMAGE_MULTIPLIER=2.0
static func roll(ticket: Dictionary)->bool:
	if ticket.get("tower",false):return false
	if ticket.get("guard_reply",false):return true
	var chance=clampf(float(ticket.get("critical_chance",0)),0,100)
	if chance<=0:return false
	return chance>=100 or randf()*100<chance
