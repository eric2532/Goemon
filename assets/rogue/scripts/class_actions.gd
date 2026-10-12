extends RefCounted
## Native Rogue class kits, adapted only at collision, attribution, and world hooks.
## Timing, damage, utilities, skills, and authored visual styles retain Rogue values.

const PRIMARY = {
	"samurai": {"duration": 0.39, "contact": 0.1, "damage": 34, "reach": 3.3, "arc": 1.1, "style": "katana"},
	"ninja": {"duration": 0.21, "contact": 0.055, "damage": 18, "reach": 2.45, "arc": 0.95, "style": "ninja"},
	"mage": {"duration": 0.75, "contact": 0.22, "damage": 64, "reach": 4.0, "arc": 1.3, "style": "staff"},
	"knight": {"duration": 0.49, "contact": 0.14, "damage": 42, "reach": 4.8, "arc": 1.45, "style": "heavy"},
	"dragoon": {"duration": 0.36, "contact": 0.1, "damage": 37, "reach": 6.2, "arc": 0.58, "style": "thrust"},
	"magic-swordsman": {"duration": 0.48, "contact": 0.15, "damage": 42, "reach": 3.5, "arc": 1.25, "style": "claymore"},
	"ranger": {"duration": 0.62 / 3.0, "contact": 0.11 / 3.0, "damage": 67, "reach": 20.0, "arc": 0.0, "style": "bow"},
	"explorer": {"duration": 0.23, "contact": 0.055, "damage": 19, "reach": 2.65, "arc": 1.2, "style": "evasive-slash"},
	"master-thief": {"duration": 0.38, "contact": 0.105, "damage": 62, "reach": 4.8, "arc": 1.65, "style": "pipe"}
}
const SAMURAI_CUTS = [
 {"duration": .34, "contact": .11, "arc": 1.1, "swingSide": 1, "tilt": 0.0},
 {"duration": .34, "contact": .11, "arc": 1.1, "swingSide": -1, "tilt": 0.0},
 {"duration": .40, "contact": .14, "arc": .85, "swingSide": 1, "tilt": -.55},
 {"duration": .38, "contact": .14, "arc": .45, "swingSide": 1, "plane": PI / 2},
 {"duration": .52, "contact": .23, "arc": PI / 2, "swingSide": 1, "tilt": 0.0, "damage": 49, "stop": .065}
]
const HOOK_ANCHORS = [Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(-7, 0, 7), Vector3(7, 0, 7)]
const RangerFlight = preload("res://assets/rogue/scripts/ranger_arrow_flight.gd")
const RANGER_FAN_STEP = 0.24
const RANGER_POWER_COLOR = Color("55ff87")

static func facing(g) -> Vector3:
	g.player.angle = atan2(g.aim.x - g.player.pos.x, g.aim.z - g.player.pos.z)
	return g.front(g.player.angle)

static func begin_attack(g, config: Dictionary, index: int = 0, weapon: String = "cutlass") -> void:
	var p = g.player
	facing(g)
	var attack = {"index": index, "time": 0.0, "hit": false, "angle": p.angle, "stop": 0.045, "weapon": weapon, "color": g.tint(), "ticket": g.current_ticket()}
	attack.merge(config, true)
	attack.rangeScale = g.primary_range_scale() if config.get("primary", false) else g.range_scale()
	attack.reach *= attack.rangeScale
	p.attack = attack
	if weapon == "cutlass":
		p.cooldowns.cutlass = config.duration
	g.attack_buffer = 0
	p.blocking = false

static func begin_primary(g) -> void:
	var p = g.player
	if p.travel != null or (p.blocking and g.secondary_held) or not PRIMARY.has(g.class_id):
		return
	if g.class_id == "mage":
		begin_charge(g)
		return
	var index = g.combo % (5 if g.class_id == "samurai" else 3) if g.combo_timer > 0 else 0
	g.combo = index + 1
	g.combo_timer = 1.05
	var config = PRIMARY[g.class_id].duplicate(true)
	if g.class_id == "samurai":
		config.merge(SAMURAI_CUTS[index], true)
		config.style = "samurai-cut"
		config.color = Color("ff2848")
		if p.buffTime > 0:
			config.duration /= 5.0
			config.contact /= 5.0
			config.stop = float(config.get("stop", .045)) / 5.0
	if g.class_id == "ranger":
		config.power = int(p.get("rangerShots", 0)) % 3 == 2
	if g.class_id == "ranger" and g.hero.jumps_used >= 2 and not g.hero.is_on_floor():
		facing(g)
		config.style = "bow-fan"
		config.downward = true
		config.aimPoint = g.ranger_ground_target(p.angle)
		g.flip_time = -1.0
	config.primary = true
	if g.class_id == "explorer":
		config.swingSide = p.bladeSide
		p.bladeSide *= -1
	if g.class_id not in ["mage", "ranger", "samurai"] and index == 2:
		config.damage = roundi(config.damage * 1.45)
		config.duration *= 1.2
		config.stop = 0.07
	if g.class_id == "mage" and p.buffTime > 0:
		config.duration *= 0.4
		config.contact *= 0.4
	if g.class_id == "master-thief":
		if p.crouched:
			config.style = "low-pipe"
			config.arc = PI
			config.damage *= 0.82
			config.duration *= 0.8
		if p.buffTime > 0:
			config.reach *= 1.8
	if g.class_id == "knight" and p.riposte > 0:
		config.damage *= 1.8
		config.stop = 0.09
		p.riposte = 0
		g.fx.damage(p.pos, "RIPOSTE", "crit")
	begin_attack(g, config, index)
	if g.class_id == "explorer":
		p.invuln = maxf(p.invuln, 0.14)
		var side = Vector3(cos(p.angle), 0, -sin(p.angle))
		p.vel += side * 3.8 * config.swingSide + g.front(p.angle) * 0.8
	elif g.class_id not in ["mage", "ranger"]:
		p.vel += g.front(p.angle) * (2.5 if index == 2 else 1.25)

static func area(g, center: Vector3, radius: float, amount: float, weapon: String = "cutlass", heavy: bool = true, color: Color = Color.WHITE, style: String = "slam", scale_override: float = -1.0) -> int:
	radius *= g.range_scale() if scale_override < 0 else scale_override
	g.fx.ring(center, color, radius, 0.38)
	g.fx.particles(center, color, 24 if heavy else 12, 1.05 if heavy else 0.65)
	var hits = 0
	for e in g.living():
		if e.pos.distance_to(center) <= radius + (0.4 if e.type == "warden" else 0):
			g.hit(e, roundi(amount), weapon, heavy, (e.pos - center).normalized(), "", style)
			hits += 1
	if heavy:
		g.fx.shake = maxf(g.fx.shake, 0.16)
		g.sound.play("cast" if style == "staff" else "slam", {"style": g.class_id, "pitch": 0.9, "volume": 0.65})
		if hits > 0:
			g.hit_stop = maxf(g.hit_stop, 0.065)
	return hits

static func resolve_attack(g, a: Dictionary) -> void:
	var p = g.player
	var dir = g.front(a.angle)
	if a.style == "bow-fan":
		fire_ranger_fan(g, a.angle, true, a.weapon, a.aimPoint, a.get("power", false) or p.buffTime > 0)
		p.rangerShots = int(p.get("rangerShots", 0)) + 1
		p.vel -= dir * 0.8
		return
	if a.style == "staff":
		var center = p.pos + dir * 1.8 * a.rangeScale
		g.fx.streak(p.pos + Vector3.UP * 1.7, center + Vector3.UP * 0.3, a.color, 0.15, 0.18)
		g.fx.spell_burst(center, a.angle, a.color, 2.3 * a.rangeScale)
		area(g, center, 2.3, a.damage, "cutlass", true, a.color, "staff", a.rangeScale)
		return
	if a.style == "bow":
		var power: bool = a.get("power", false) or p.buffTime > 0
		fire_projectile(g, {"angle": a.angle, "damage": roundi(a.damage * 1.5) if power else a.damage, "speed": 36, "kind": "arrow", "weapon": "cutlass", "heavy": true, "width": 0.25, "primary": true, "power": power})
		p.rangerShots = int(p.get("rangerShots", 0)) + 1
		p.vel -= dir * 0.8
		return
	var slash_style = {"katana": "katana", "ninja": "dagger", "heavy": "cleave", "claymore": "magic", "twin": "dagger", "pipe": "cleave", "low-pipe": "spin", "iaijutsu": "katana", "power-slash": "magic", "evasive-slash": "dagger", "shield-bash": "cleave"}.get(a.style, "sword")
	if a.style in ["spin", "fireburst"]:
		area(g, p.pos, a.reach, a.damage, a.weapon, true, a.color, a.style, 1.0)
		g.fx.slash(p.pos, a.angle, 2, a.color, a.reach, {"style": "spin", "arc": TAU, "height": 0.75 if a.style == "fireburst" else 1.05})
		if a.style == "fireburst":
			g.fx.spell_burst(p.pos, a.angle, Color("ff9956"), a.reach)
			g.fx.smoke(p.pos, 14, Color("857469"))
			g.sound.play("fire")
		else:
			g.sound.play("blade", {"style": "explorer", "combo": 2})
		return
	if a.style == "thrust":
		g.fx.thrust(p.pos, a.angle, a.reach, a.color, a.index)
		g.sound.play("thrust", {"combo": a.index})
	elif a.style == "shield-bash":
		g.fx.energy_shield(p.pos, a.angle, a.reach)
		g.sound.play("shield")
	elif a.style == "bash":
		g.fx.muzzle(p.pos, a.angle, a.color, "shield")
		g.sound.play("shield")
	else:
		var heavy_pipe = g.class_id == "master-thief" and p.buffTime > 0
		var color = Color("ffa65f") if heavy_pipe else a.color
		var options = {"style": "katana" if a.style == "samurai-cut" else slash_style, "arc": a.arc * 2, "height": 0.35 if a.style == "low-pipe" else (0.65 if a.style == "evasive-slash" else 1.05), "direction": a.get("swingSide", -1 if a.index % 2 else 1)}
		if a.style == "samurai-cut":
			options.tilt = a.get("tilt", 0.0)
			options.plane = a.get("plane", 0.0)
			options.life = .11 if p.buffTime > 0 else .29
		if a.style == "iaijutsu":
			options.tilt = 0.05
		if a.style == "power-slash":
			g.fx.power_slash(p.pos, a.angle, a.reach)
		elif not (a.style=="samurai-cut" or (g.class_id=="magic-swordsman" and a.style=="claymore")):
			g.fx.slash(p.pos, a.angle, a.index, color, a.reach, options)
		if a.style in ["twin", "evasive-slash"]:
			g.fx.slash(p.pos, a.angle, a.index, Color("ffecd0"), a.reach * 0.88, {"style": "dagger", "arc": a.arc * 1.8, "height": 0.8, "direction": -a.get("swingSide", -1 if a.index % 2 else 1), "tilt": -0.36})
		if a.style in ["iaijutsu", "power-slash"]:
			g.fx.ring(p.pos, a.color, a.reach, 0.35)
			g.fx.shake = maxf(g.fx.shake, 0.24)
		if not a.get("sweepSound", false):
			g.sound.play("blade", {"style": g.class_id, "combo": a.index, "pitch": 0.8 if a.style == "iaijutsu" else 1.0})
	var hits = 0
	for e in g.living():
		if not g.in_arc(p.pos, e.pos, a.angle, a.reach + (0.4 if e.type == "warden" else 0), a.arc):
			continue
		var damage = a.damage
		if g.class_id == "ninja" and a.weapon == "cutlass" and p.buffTime > 0 and randf() < 0.25:
			damage = damage + 45 if e.type == "warden" else maxf(damage, e.hp)
			g.fx.damage(e.pos, "ANBU STRIKE" if e.type == "warden" else "EXECUTE", "crit")
			g.fx.lightning(p.pos, e.pos)
		g.hit(e, roundi(damage), a.weapon, (a.index == 4 if a.style == "samurai-cut" else a.index == 2) or a.style in ["iaijutsu", "bash", "power-slash", "shield-bash"], dir, "", a.style)
		if a.style in ["bash", "shield-bash"]:
			g.bash_enemy(e, dir)
		hits += 1
	if hits > 0:
		g.hit_stop = maxf(g.hit_stop, a.stop)

static func fire_ranger_fan(g, angle: float, downward: bool = false, weapon: String = "flintlock", target: Vector3 = Vector3.ZERO, power: bool = false) -> void:
	if g.game.crosshair_aim_enabled():downward=false
	var origin: Vector3 = g.player.pos + Vector3.UP * 1.05 * g.hero.growth_multiplier()
	var direction: Vector3 = g.projectile_direction(angle, origin)
	var impact: Vector3 = target + Vector3.UP * 1.1
	var side: Vector3 = g.front(angle).cross(Vector3.UP).normalized()
	var spread_distance: float = maxf(4.0 * g.hero.growth_multiplier(), Vector2(impact.x - origin.x, impact.z - origin.z).length())
	if downward:
		impact.y = minf(impact.y, origin.y - 0.6)
	for i in range(-2, 3):
		var ray: Vector3 = (impact + side * spread_distance * tan(i * RANGER_FAN_STEP) - origin).normalized() if downward else direction.rotated(Vector3.UP, i * RANGER_FAN_STEP)
		fire_projectile(g, {"angle": angle + i * RANGER_FAN_STEP, "direction": ray,
			"damage": 38 if power else 25, "speed": 34, "kind": "arrow", "weapon": weapon, "primary": weapon == "cutlass", "feedback": i == 0, "power": power})
	g.player.shotDownward = downward

static func fire_projectile(g, options: Dictionary = {}) -> void:
	var angle = options.get("angle", g.player.angle)
	var damage = options.get("damage", 30)
	var speed = options.get("speed", 20.0)
	var kind = options.get("kind", "arrow")
	var heavy = options.get("heavy", false)
	var color = options.get("color", g.tint())
	var ranger_arrow: bool = g.class_id == "ranger" and kind == "arrow"
	var power: bool = ranger_arrow and options.get("power", false)
	if ranger_arrow: color = RANGER_POWER_COLOR if power else Color("d4be8a")
	var mesh = g.fx.create_projectile(("ranger-power-arrow" if power else "ranger-arrow") if ranger_arrow else kind, color)
	var scale = g.range_scale()
	var visual_scale = options.get("visualScale", 1.0)
	if ranger_arrow:
		visual_scale *= 2.4 * (1.35 if power else 1.0)
	var travel_scale = g.primary_range_scale() if options.get("primary", false) else scale
	var origin = g.player.pos + Vector3.UP * options.get("height", 1.65 if kind == "wave" else 1.05) * g.hero.growth_multiplier()
	var dir: Vector3 = options.get("direction", g.projectile_direction(angle, origin))
	var aim_direction: Vector3 = dir
	if ranger_arrow: dir = RangerFlight.launch_direction(dir, power)
	g.add_projectile_mesh(mesh)
	mesh.position = origin + dir * 0.9 * g.hero.growth_multiplier()
	mesh.quaternion = Quaternion(Vector3.BACK, dir)
	mesh.scale = Vector3(2.0, 1.5, 1.35) * scale if kind == "wave" else Vector3.ONE * scale * visual_scale
	var sphere_collision = kind == "bullet"
	var obstructed = g.place_projectile(mesh, options.get("width", 0.25) * scale, origin, sphere_collision)
	g.projectiles.append({"mesh": mesh, "vel": dir * speed, "life": 0.0 if obstructed else options.get("range", 20.0) * travel_scale / speed,
		"owner": "player", "kind": kind, "damage": damage, "color": color, "visualScale": visual_scale, "weapon": options.get("weapon", "flintlock"),
		"heavy": heavy, "width": options.get("width", 0.25) * scale, "rangeScale": scale, "sphereCollision": sphere_collision, "pierce": options.get("pierce", false), "hits": [], "trailTimer": 0.0, "ticket": g.current_ticket()})
	if ranger_arrow:
		var projectile: Dictionary = g.projectiles.back()
		projectile.power = power
		projectile.aimDirection = aim_direction
		RangerFlight.attach(projectile, int(g.player.get("rangerFlightSerial", 0)), scale, g.game.crosshair_aim_enabled())
		g.player.rangerFlightSerial = int(g.player.get("rangerFlightSerial", 0)) + 1
		if power and options.get("feedback", true):
			g.fx.ring(origin, RANGER_POWER_COLOR, .75 * scale, .22)
			g.sound.play("cast", {"pitch": 1.15, "volume": .5})
	g.player.shot = 0.2
	g.player.shotDownward = false
	if not options.get("feedback", true):
		return
	g.fx.muzzle(g.player.pos, angle, color, "spell" if kind in ["bolt", "fireball"] else ("bow" if kind in ["arrow", "crimson-arrow"] else ("gun" if kind == "bullet" else kind)))
	if kind == "wave":
		g.sound.play("claymore-wave", {"volume": 0.64})
	elif kind != "bullet":
		g.sound.play("cast" if kind in ["bolt", "fireball"] else ("bow" if kind in ["arrow", "crimson-arrow"] else "shuriken"),
			{"style": ("power" if heavy else "rapid") if kind in ["arrow", "crimson-arrow"] else g.class_id, "volume": 0.55 if kind == "star" else 0.75})
	if heavy:
		g.fx.shake = maxf(g.fx.shake, 0.07)

static func travel(g, target: Vector3, duration: float, height: float, kind: String, impact: bool = false) -> void:
	var p = g.player
	cancel_charge(g)
	p.guardTime = 0.0
	p.attack = null
	p.roll = 0
	p.blocking = false
	p.vel = Vector3.ZERO
	p.travel = {"start": p.pos, "target": g.clamp_arena(target), "time": 0.0, "duration": duration, "height": height, "kind": kind, "impact": impact, "ticket": g.current_ticket(), "rangeScale": g.range_scale()}
	p.invuln = maxf(p.invuln, duration)
	g.attack_buffer = 0
	g.sound.play("roll", {"pitch": 1.4 if kind == "hook" else 1.0})

static func dash(g, dir: Vector3, duration: float, speed: float, kind: String) -> void:
	var p = g.player
	cancel_charge(g)
	p.guardTime = 0.0
	p.attack = null
	p.blocking = false
	p.rollDir = dir.normalized()
	p.roll = duration
	p.rollDuration = duration
	p.rollSpeed = speed
	p.rollStyle = kind
	p.rollTicket = g.current_ticket()
	p.invuln = duration
	if g.class_id == "samurai":
		p.untargetable = duration
	g.attack_buffer = 0
	g.sound.play("roll")
	g.fx.smoke(p.pos, 7, g.tint())

static func class_action(g, slot: String, buffered = null, manual: bool = false) -> void:
	var p = g.player
	var c = g.class_data()
	var id = g.class_id
	if slot == "drink":
		if p.cooldowns.drink > 0 or p.travel != null:
			return
		g.begin_cast("skill")
		p.cooldowns.drink = c.cooldowns.drink
		if id == "samurai":
			if p.roll > 0:
				p.cooldowns.drink = 0
				return
			p.buffName = c.abilities.drink.name
			p.buffTime = 10.0
			p.buffDuration = 10.0
			# Speed the committed katana pose as well as subsequent combo cuts.
			if p.attack != null and p.attack.get("primary", false):
				for key in ["duration", "contact", "time", "stop"]: p.attack[key] /= 5.0
				p.cooldowns.cutlass /= 5.0
			g.fx.ring(p.pos, Color("ff1834"), 3.0, .45)
			g.fx.particles(p.pos, Color("ff1834"), 20, .8)
			g.sound.play("cast", {"pitch": .8, "volume": .65})
			g.toast("Crimson Overdrive · 5× katana speed · 10 seconds")
			return
		p.buffName = c.abilities.drink.name
		p.buffTime = 8.0 if id in ["knight", "explorer"] else 10.0
		p.buffDuration = p.buffTime
		if id == "dragoon":
			p.cooldowns.flintlock = 0
			p.cooldowns.roll = 0
		if id in ["magic-swordsman", "ranger", "mage"]:
			p.cooldowns.flintlock = 0
		if id == "mage":
			p.cooldowns.cutlass = minf(p.cooldowns.cutlass, 0.1)
		g.fx.ring(p.pos, g.tint(), 3, 0.55)
		g.fx.particles(p.pos, g.tint(), 20, 0.8)
		g.fx.damage(p.pos, str(c.abilities.drink.name).to_upper(), "crit" if id == "explorer" else "ice")
		g.sound.play("fire" if id == "master-thief" else "drink")
		g.toast("%s · %d seconds" % [p.buffName, p.buffTime])
		return
	if slot == "roll":
		if p.cooldowns.roll > 0 or p.travel != null or p.roll > 0:
			return
		g.begin_cast("utility")
		cancel_charge(g)
		if id in ["samurai", "ninja"]:
			p.cooldowns.roll = c.cooldowns.roll
			facing(g)
			if id == "samurai":
				fire_projectile(g, {"damage": 59, "speed": 32, "kind": "arrow", "heavy": true})
			else:
				for i in range(-2, 3):
					fire_projectile(g, {"angle": p.angle + i * 0.19, "damage": 25, "speed": 25, "kind": "star", "width": 0.5, "visualScale": 1.8, "range": 28})
			return
		if id == "master-thief":
			p.crouched = not p.crouched
			p.blocking = false
			p.guardTime = 0.0
			p.guardStyle = ""
			p.attack = null
			p.cooldowns.roll = 0.15
			g.fx.smoke(p.pos, 6, Color("d2b298"))
			g.sound.play("roll", {"pitch": 0.65, "volume": 0.5})
			return
		p.cooldowns.roll = 0 if id == "dragoon" and p.buffTime > 0 else c.cooldowns.roll
		if id == "mage":
			var start = p.pos
			g.blink_to(p.pos + g.movement_direction() * 5.2)
			p.attack = null
			p.invuln = 0.24
			p.vel = Vector3.ZERO
			g.fx.ring(start, g.tint(), 1.3, 0.25)
			g.fx.smoke(start, 14, g.tint())
			g.fx.streak(start + Vector3.UP, p.pos + Vector3.UP, g.tint(), 0.16, 0.2)
			g.fx.ring(p.pos, g.tint(), 1.4, 0.35)
			g.sound.play("roll", {"pitch": 1.5})
		elif id == "ranger":
			var dir: Vector3 = g.ranger_roll_direction()
			p.angle = atan2(dir.x, dir.z)
			dash(g, dir, 0.15, 46.0, "roll")
		elif id == "explorer":
			facing(g)
			var candidates: Array = []
			for e in g.living():
				candidates.append({"pos": e.pos, "enemy": true})
			for point in g.hook_points():
				candidates.append({"pos": point, "enemy": false})
			candidates = candidates.filter(func(target): return target.pos.distance_to(p.pos) > 1.25 and target.pos.distance_to(p.pos) <= 15 and g.hook_ahead(target.pos) and g.clear_line(p.pos + Vector3.UP, target.pos + Vector3.UP))
			candidates.sort_custom(func(a, b): return a.pos.distance_to(g.aim) < b.pos.distance_to(g.aim))
			if candidates.is_empty():
				p.cooldowns.roll = 0
				g.toast("Hook Shot · Face a nearby enemy or gold anchor")
				g.fx.ring(p.pos, g.tint(), 0.8, 0.18)
				return
			var target = candidates[0]
			var dir = (target.pos - p.pos).normalized()
			var destination = target.pos - dir * (1.3 if target.enemy else 0.55)
			g.fx.streak(p.pos + Vector3.UP, target.pos + Vector3.UP * (1.0 if target.enemy else 0.6), Color("ffce82"), 0.06, 0.42)
			travel(g, destination, maxf(0.18, destination.distance_to(p.pos) / 24), 0.35, "hook")
		else:
			var backflip = id == "dragoon"
			var dir = -g.front(p.angle) if backflip else g.movement_direction()
			var duration = 0.18 if id == "knight" else (0.4 if backflip else (0.32 if id == "magic-swordsman" else 0.25))
			var speed = 9 if id == "knight" else (21 if id == "ninja" else (20 if id == "magic-swordsman" else (14 if backflip else 13)))
			dash(g, dir, duration, speed, "backflip" if backflip else ("dash-strike" if id == "magic-swordsman" else "dash"))
		return
	if slot != "flintlock":
		return
	# A press made before the bar filled cannot spend a future credit merely
	# because its ordinary input buffer overlaps the final light's recovery.
	var free_heavy = g.energy_ready() and (manual or (buffered != null and buffered.get("freeHeavy", false)))
	var attack_locked = p.attack != null and not (p.attack.weapon == "cutlass" and p.attack.hit)
	if (p.cooldowns.flintlock > 0 and not free_heavy) or p.roll > 0 or p.travel != null or p.get("dive") != null or attack_locked or p.burst != null or p.guardTime > 0:
		if buffered == null and id not in ["master-thief", "knight"]:
			p.secondaryBuffer = {"remaining": 0.24, "freeHeavy": free_heavy}
		return
	g.begin_cast("secondary")
	cancel_charge(g)
	p.attack = null
	p.secondaryBuffer = null
	var dir = facing(g)
	if free_heavy:
		p.energy = 0
	else:
		p.cooldowns.flintlock = c.cooldowns.flintlock
	p.shot = 0.28
	if id in ["master-thief", "knight"]:
		p.crouched = false
		p.shot = 0
		p.guardTime = 3.0 if id == "master-thief" else 2.0
		p.guardStyle = "thief" if id == "master-thief" else "knight"
		p.guardTicket = g.current_ticket()
		p.blocking = true
		p.vel = Vector3.ZERO
		g.fx.ring(p.pos, Color("ff3c3c") if id == "master-thief" else Color("244cab"), 1.6, 0.3)
	elif id == "samurai":
		fire_projectile(g, {"damage": 150, "speed": 36, "kind": "crimson-arrow", "heavy": true,
			"color": Color("ff1834"), "width": .68, "visualScale": 3.0, "range": 28.0, "pierce": true})
		g.fx.ring(p.pos, Color("ff1834"), 1.8, .22)
	elif id in ["ninja", "explorer"]:
		var ninja = id == "ninja"
		dash(g, dir, 0.42 if ninja else 0.30, 27.0 if ninja else 20.0, "dash-cut" if ninja else "cross-slash")
		p.dashAttack = {"angle": p.angle, "damage": 76 if ninja else 78, "width": (0.85 if ninja else 1.45) * g.range_scale(), "hits": [], "ticket": g.current_ticket(), "style": "dash-cut" if ninja else "cross-slash", "fxTime": 0.0}
	elif id == "mage":
		var radius = 8.0 * g.range_scale()
		g.fx.frost_nova(p.pos, radius)
		for e in g.living():
			if e.pos.distance_to(p.pos) <= radius and g.clear_line(p.pos + Vector3.UP, e.pos + Vector3.UP):
				e.node.freeze_for(3.0)
				# This class spell promises a full three seconds, including bosses.
				e.node.frozen_left = maxf(e.node.frozen_left, 3.0)
		g.sound.play("cast", {"pitch": 0.72, "volume": 0.9})
	elif id == "dragoon":
		if p.buffTime > 0:
			p.cooldowns.flintlock = 0
		var airborne = not g.hero.is_on_floor()
		var delta = g.aim - p.pos
		delta.y = 0
		delta = delta.limit_length(7.5)
		var target = p.pos if airborne else p.pos + delta
		if not airborne:
			g.fx.lance_wave(g.clamp_arena(target), 4.2 * g.range_scale(), -1)
		travel(g, target, 0.72, 4.8, "lance-leap", true)
		p.travel.phase = "drop" if airborne else "arc"
		g.hero.jump_buffer = 0.0
		g.hero.coyote = 0.0
		if airborne:
			g.hero.velocity = Vector3.DOWN * 38.0
	elif id == "magic-swordsman":
		p.cooldowns.flintlock = 0.42 if p.buffTime > 0 else c.cooldowns.flintlock
		var wave_origin: Vector3 = p.pos + Vector3.UP * 1.65 * g.hero.growth_multiplier()
		var wave_direction: Vector3 = g.projectile_direction(p.angle, wave_origin)
		if g.hero.is_on_floor():
			# A ground wave keeps the reticle/lock heading but must not dive
			# into the floor immediately after piercing a nearby low target.
			wave_direction.y = 0
			wave_direction = wave_direction.normalized() if wave_direction.length_squared() > 0.001 else dir
		fire_projectile(g, {"damage": 100, "speed": 22, "kind": "wave", "width": 2.5, "pierce": true, "heavy": true, "range": 40, "direction": wave_direction})
		p.vel -= dir * 1.6
		g.fx.slash(p.pos, p.angle, 2, g.tint(), 3.5, {"style": "magic", "arc": 2.5, "height": 1.2, "tilt": 0.5})
	elif id == "ranger":
		p.cooldowns.flintlock = 0.55 if p.buffTime > 0 else c.cooldowns.flintlock
		var downward: bool = g.hero.jumps_used >= 2 and not g.hero.is_on_floor()
		if downward: g.flip_time = -1.0
		fire_ranger_fan(g, p.angle, downward, "flintlock", g.ranger_ground_target(p.angle) if downward else g.aim, p.buffTime > 0)

static func update_class(g, dt: float) -> void:
	var p = g.player
	p.buffTime = maxf(0, p.buffTime - dt)
	p.untargetable = maxf(0, p.untargetable - dt)
	if p.secondaryBuffer != null:
		var buffered = p.secondaryBuffer
		buffered.remaining -= dt
		if buffered.remaining <= 0:
			p.secondaryBuffer = null
		else:
			class_action(g, "flintlock", buffered)
	if p.buffTime <= 0:
		p.buffName = ""
	update_guard(g, dt)
	if p.charging:
		p.chargeTime = minf(3.0, p.chargeTime + dt)
		if is_instance_valid(p.chargeOrb):
			p.chargeOrb.position = p.pos + Vector3.UP * 1.6 * g.hero.growth_multiplier() + g.front(p.chargeAngle) * 0.8
			p.chargeOrb.scale = Vector3.ONE * (0.8 + p.chargeTime * 0.67) * g.hero.growth_multiplier()
			p.chargeOrb.rotate_y(dt * 1.4)
	for i in range(p.pulses.size() - 1, -1, -1):
		var pulse = p.pulses[i]
		pulse.time -= dt
		if pulse.time <= 0:
			g.resolve_area_pulse(pulse)
			p.pulses.remove_at(i)
	if p.burst != null:
		p.burst.timer -= dt
		if p.burst.timer <= 0:
			g.use_ticket(p.burst.ticket)
			facing(g)
			fire_projectile(g, {"damage": 25, "speed": 34, "kind": "arrow", "heavy": false})
			p.burst.remaining -= 1
			p.burst.timer += 0.12
			if p.burst.remaining <= 0:
				p.burst = null
	if g.secondary_held and g.class_id in ["ranger", "magic-swordsman"] and p.buffTime > 0 and p.cooldowns.flintlock <= 0:
		class_action(g, "flintlock")
	if p.buffTime > 0 and randf() < dt * 9:
		g.fx.particles(p.pos, g.tint(), 1, 0.2)

static func step_travel(g, dt: float) -> void:
	g.step_travel(dt)

static func finish_dash(g) -> void:
	if g.class_id == "magic-swordsman" and g.player.rollStyle == "dash-strike":
		begin_attack(g, {"duration": 0.3, "contact": 0.045, "damage": 45, "reach": 3.7, "arc": 1.4, "style": "claymore", "stop": 0.065}, 2)

static func block_attack(g, incoming: Vector3, projectile: bool = false) -> bool:
	var p = g.player
	if projectile and g.class_id == "master-thief" and p.crouched:
		return true
	if not p.blocking or p.guardTime <= 0:
		return false
	if g.class_id == "knight":
		if p.buffTime > 0: p.riposte = 1
		p.blocking = false
		p.guardTime = 0
		g.use_ticket(p.guardTicket)
		begin_attack(g, {"duration": 0.5, "contact": 0.07, "damage": 160, "reach": 6.7, "arc": 1.3, "style": "shield-bash", "color": Color("153778"), "stop": 0.09}, 2, "flintlock")
	else:
		g.fx.ring(p.pos, Color("ff3544"), 1.5, 0.22)
		g.fx.particles(p.pos, Color("ff6359"), 8, 0.5)
	g.fx.damage(p.pos, "COUNTER" if g.class_id == "knight" else "GUARD", "ice")
	g.sound.play("shield", {"pitch": 1.1, "volume": 0.7})
	return true

static func update_projectile(g, pr: Dictionary, dt: float) -> void:
	if pr.life <= 0:
		return
	var previous = pr.mesh.position
	pr.life -= dt
	if pr.kind=="wave":
		pr.inkClock=float(pr.get("inkClock",0.0))+dt
		for material in pr.mesh.get_meta("ink_materials",[]):material.set_shader_parameter("brush_clock",pr.inkClock)
	if pr.has("rangerFlight"):
		RangerFlight.advance(pr, dt)
	else:
		pr.mesh.position += pr.vel * dt
	if pr.kind == "star":
		pr.mesh.rotate_object_local(Vector3.UP, dt * 30)
	elif pr.kind in ["bolt", "fireball"]:
		pr.mesh.rotate_object_local(Vector3.FORWARD, dt * 6)
	pr.trailTimer -= dt
	if pr.trailTimer <= 0 and not pr.has("rangerFlight"):
		var direction = pr.vel.normalized()
		var tail = pr.mesh.position - direction * (1.1 if pr.kind == "wave" else 0.9) * pr.rangeScale
		var color = pr.get("color", g.tint())
		if pr.kind == "wave":
			var side = Vector3(direction.z, 0, -direction.x)
			for offset in [-0.85, 0, 0.85]:
				var head = pr.mesh.position + side * offset * pr.rangeScale
				g.fx.streak(head - direction * 1.15 * pr.rangeScale, head, color, 0.025 * pr.rangeScale, 0.16)
		elif pr.kind == "crimson-arrow":
			g.fx.streak(pr.mesh.position - direction * 4.0 * pr.rangeScale, pr.mesh.position, color, .16 * pr.rangeScale, .16)
		else:
			g.fx.streak(tail, pr.mesh.position, color, (0.13 * pr.get("visualScale", 1.0) if pr.kind == "fireball" else (0.055 * pr.get("visualScale", 1.0) if pr.kind == "bullet" else (0.075 if pr.kind == "bolt" else 0.022))) * pr.rangeScale, 0.13)
		pr.trailTimer = 0.055
	g.resolve_projectile_segment(pr, previous, pr.mesh.position)
	if pr.has("rangerFlight"):
		# End the straight trail at the same contact point as native collision.
		g.fx.ranger_trail(pr, previous, pr.mesh.position)

static func begin_charge(g) -> void:
	var p = g.player
	facing(g)
	p.charging = true
	p.chargeTime = 0.0
	p.chargeAngle = p.angle
	p.chargeTicket = g.current_ticket()
	p.chargeOrb = g.fx.charge_orb(p.pos + Vector3.UP * 1.6 + g.front(p.angle) * 0.8)
	g.attack_buffer = 0

static func cancel_charge(g) -> void:
	var p = g.player
	if is_instance_valid(p.get("chargeOrb")):
		p.chargeOrb.queue_free()
	p.chargeOrb = null
	p.charging = false
	p.chargeTime = 0.0

static func release_charge(g) -> void:
	var p = g.player
	if not p.charging:
		return
	var tier = mini(3, floori(p.chargeTime + 0.001))
	var angle = p.chargeAngle
	g.use_ticket(p.chargeTicket)
	cancel_charge(g)
	fire_projectile(g, {"angle": angle, "damage": [36, 70, 120, 190][tier], "speed": 21.0 - tier, "kind": "fireball", "weapon": "cutlass", "width": 0.45 + tier * 0.35, "visualScale": 1.0 + tier * 0.6, "heavy": tier > 0, "color": Color("ff7135"), "range": 28.0, "pierce": true, "primary": true})
	p.cooldowns.cutlass = 0.18 if p.buffTime > 0 else 0.48
	g.attack_buffer = 0

static func update_guard(g, dt: float) -> void:
	var p = g.player
	if p.guardTime > 0:
		p.guardTime = maxf(0, p.guardTime - dt)
		if p.guardTime <= 0 or (g.class_id == "master-thief" and not g.secondary_held):
			p.guardTime = 0.0
			p.blocking = false
			p.guardStyle = ""

static func resolve_dash_segment(g, from: Vector3, to: Vector3) -> void:
	var p = g.player
	var a = p.dashAttack
	if a == null:
		return
	g.use_ticket(a.ticket)
	g._resolution_ticket = a.ticket
	for e in g.living():
		if a.hits.has(e.uid) or absf(e.pos.y - to.y) > 3.0:
			continue
		var point = e.pos
		point.y = to.y
		var distance = g.segment_distance(point, from, to)
		if distance.distance <= a.width + e.radius and g.clear_line(to + Vector3.UP, e.pos + Vector3.UP):
			a.hits.append(e.uid)
			g.hit(e, a.damage, "flintlock", true, g.front(a.angle), "", a.style)
	if from.distance_squared_to(to) > 0.01:
		g.fx.streak(from + Vector3.UP, to + Vector3.UP, Color("bb9dff") if a.style == "dash-cut" else Color("ffe6af"), 0.16, 0.25)
		a.fxTime += from.distance_to(to)
		if a.fxTime >= 1.6 or p.roll <= 0:
			a.fxTime = 0
			if a.style == "cross-slash":
				g.fx.cross_slash(to, a.angle, 2.4 * g.range_scale())
			else:
				g.fx.slash(to, a.angle, 0, Color("bc99ff"), 2.2 * g.range_scale(), {"style": "katana", "arc": 0.65, "tilt": 0.5})
	if p.roll <= 0:
		p.dashAttack = null

static func lance_impact(g, t: Dictionary) -> void:
	var p = g.player
	for index in range(3):
		var pulse = {"time": index * 0.26, "pos": p.pos, "radius": 4.2 + index * 1.2, "damage": 64, "ticket": t.ticket, "rangeScale": t.rangeScale, "index": index}
		if index == 0:
			g.resolve_area_pulse(pulse)
		else:
			p.pulses.append(pulse)
	g.sound.play("slam", {"pitch": 0.75, "volume": 0.85})
