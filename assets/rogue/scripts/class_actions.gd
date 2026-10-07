extends RefCounted
## Native Rogue class kits, adapted only at collision, attribution, and world hooks.
## Timing, damage, utilities, skills, and authored visual styles retain Rogue values.

const PRIMARY = {
	"samurai": {"duration": 0.39, "contact": 0.1, "damage": 34, "reach": 3.3, "arc": 1.1, "style": "katana"},
	"ninja": {"duration": 0.21, "contact": 0.055, "damage": 18, "reach": 2.45, "arc": 0.95, "style": "ninja"},
	"mage": {"duration": 0.75, "contact": 0.22, "damage": 64, "reach": 4.0, "arc": 1.3, "style": "staff"},
	"knight": {"duration": 0.49, "contact": 0.14, "damage": 42, "reach": 3.2, "arc": 1.45, "style": "heavy"},
	"dragoon": {"duration": 0.36, "contact": 0.1, "damage": 37, "reach": 4.3, "arc": 0.35, "style": "thrust"},
	"magic-swordsman": {"duration": 0.48, "contact": 0.15, "damage": 42, "reach": 3.5, "arc": 1.25, "style": "claymore"},
	"ranger": {"duration": 0.62, "contact": 0.11, "damage": 67, "reach": 20.0, "arc": 0.0, "style": "bow"},
	"explorer": {"duration": 0.23, "contact": 0.055, "damage": 19, "reach": 2.65, "arc": 1.2, "style": "twin"},
	"master-thief": {"duration": 0.65, "contact": 0.22, "damage": 62, "reach": 3.4, "arc": 1.35, "style": "pipe"}
}
const HOOK_ANCHORS = [Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(-7, 0, 7), Vector3(7, 0, 7)]

static func facing(g) -> Vector3:
	g.player.angle = atan2(g.aim.x - g.player.pos.x, g.aim.z - g.player.pos.z)
	return g.front(g.player.angle)

static func begin_attack(g, config: Dictionary, index: int = 0, weapon: String = "cutlass") -> void:
	var p = g.player
	facing(g)
	var attack = {"index": index, "time": 0.0, "hit": false, "angle": p.angle, "stop": 0.045, "weapon": weapon, "color": g.tint(), "ticket": g.current_ticket()}
	attack.merge(config, true)
	attack.rangeScale = g.range_scale()
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
	var index = g.combo % 3 if g.combo_timer > 0 else 0
	g.combo = index + 1
	g.combo_timer = 1.05
	var config = PRIMARY[g.class_id].duplicate(true)
	if g.class_id not in ["mage", "ranger"] and index == 2:
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
	if g.class_id not in ["mage", "ranger"]:
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
	if a.style == "staff":
		var center = p.pos + dir * 1.8 * a.rangeScale
		g.fx.streak(p.pos + Vector3.UP * 1.7, center + Vector3.UP * 0.3, a.color, 0.15, 0.18)
		g.fx.spell_burst(center, a.angle, a.color, 2.3 * a.rangeScale)
		area(g, center, 2.3, a.damage, "cutlass", true, a.color, "staff", a.rangeScale)
		return
	if a.style == "bow":
		fire_projectile(g, {"angle": a.angle, "damage": a.damage, "speed": 36, "kind": "arrow", "weapon": "cutlass", "heavy": true, "width": 0.25})
		p.vel -= dir * 0.8
		return
	var slash_style = {"katana": "katana", "ninja": "dagger", "heavy": "cleave", "claymore": "magic", "twin": "dagger", "pipe": "cleave", "low-pipe": "spin", "iaijutsu": "katana"}.get(a.style, "sword")
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
	elif a.style == "bash":
		g.fx.muzzle(p.pos, a.angle, a.color, "shield")
		g.sound.play("shield")
	else:
		var heavy_pipe = g.class_id == "master-thief" and p.buffTime > 0
		var color = Color("ffa65f") if heavy_pipe else a.color
		var options = {"style": slash_style, "arc": a.arc * 2, "height": 0.35 if a.style == "low-pipe" else 1.05, "direction": -1 if a.index % 2 else 1}
		if a.style == "iaijutsu":
			options.tilt = 0.05
		g.fx.slash(p.pos, a.angle, a.index, color, a.reach, options)
		if a.style == "twin":
			g.fx.slash(p.pos, a.angle, a.index, Color("ffecd0"), a.reach * 0.88, {"style": "dagger", "arc": a.arc * 1.8, "height": 0.8, "direction": 1 if a.index % 2 else -1, "tilt": -0.36})
		if a.style == "iaijutsu":
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
		g.hit(e, roundi(damage), a.weapon, a.index == 2 or a.style in ["iaijutsu", "bash"], dir, "", a.style)
		if a.style == "bash":
			g.bash_enemy(e, dir)
		hits += 1
	if hits > 0:
		g.hit_stop = maxf(g.hit_stop, a.stop)

static func fire_projectile(g, options: Dictionary = {}) -> void:
	var angle = options.get("angle", g.player.angle)
	var damage = options.get("damage", 30)
	var speed = options.get("speed", 20.0)
	var kind = options.get("kind", "arrow")
	var heavy = options.get("heavy", false)
	var color = g.tint()
	var mesh = g.fx.create_projectile(kind, color)
	var scale = g.range_scale()
	var origin = g.player.pos + Vector3.UP * (1.65 if kind == "wave" else 1.05) * g.hero.growth_multiplier()
	var dir = g.projectile_direction(angle, origin)
	g.add_projectile_mesh(mesh)
	mesh.position = origin + dir * 0.9 * g.hero.growth_multiplier()
	mesh.quaternion = Quaternion(Vector3.BACK, dir)
	mesh.scale = Vector3(1.4, 1.25, 1.15) * scale if kind == "wave" else Vector3.ONE * scale
	var obstructed = g.place_projectile(mesh, options.get("width", 0.25) * scale, origin)
	g.projectiles.append({"mesh": mesh, "vel": dir * speed, "life": 0.0 if obstructed else options.get("range", 20.0) * scale / speed,
		"owner": "player", "kind": kind, "damage": damage, "weapon": options.get("weapon", "flintlock"),
		"heavy": heavy, "width": options.get("width", 0.25) * scale, "rangeScale": scale, "pierce": options.get("pierce", false), "hits": [], "trailTimer": 0.0, "ticket": g.current_ticket()})
	g.player.shot = 0.2
	g.fx.muzzle(g.player.pos, angle, color, "spell" if kind == "bolt" else ("bow" if kind == "arrow" else kind))
	if kind == "wave":
		g.sound.play("claymore-wave", {"volume": 0.64})
	else:
		g.sound.play("cast" if kind == "bolt" else ("bow" if kind == "arrow" else "shuriken"),
			{"style": ("power" if heavy else "rapid") if kind == "arrow" else g.class_id, "volume": 0.55 if kind == "star" else 0.75})
	if heavy:
		g.fx.shake = maxf(g.fx.shake, 0.07)

static func travel(g, target: Vector3, duration: float, height: float, kind: String, impact: bool = false) -> void:
	var p = g.player
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

static func class_action(g, slot: String, buffered = null) -> void:
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
			p.ultimatePulse = 0.85
			begin_attack(g, {"duration": 0.66, "contact": 0.22, "damage": 115, "reach": 5.3, "arc": 1.65, "style": "iaijutsu", "stop": 0.1}, 2)
			p.invuln = maxf(p.invuln, 0.28)
			g.toast("Iaijutsu · Full-power draw-cut")
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
		if id == "master-thief":
			p.crouched = not p.crouched
			p.blocking = false
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
			travel(g, p.pos + g.movement_direction() * 4.5, 0.36, 1.6, "fast-leap")
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
	if id == "master-thief" and p.crouched:
		p.secondaryBuffer = null
		return
	var attack_locked = p.attack != null and not (p.attack.weapon == "cutlass" and p.attack.hit)
	if p.cooldowns.flintlock > 0 or p.roll > 0 or p.travel != null or attack_locked or p.burst != null:
		if buffered == null:
			p.secondaryBuffer = {"remaining": 0.24, "fireReady": p.blockMeter >= 100}
		return
	g.begin_cast("secondary")
	if p.attack != null:
		p.attack = null
	p.secondaryBuffer = null
	var dir = facing(g)
	if id == "master-thief":
		if p.blockMeter >= 100 and (buffered == null or buffered.fireReady):
			p.blockMeter = 0
			p.cooldowns.flintlock = c.cooldowns.flintlock
			begin_attack(g, {"duration": 0.65, "contact": 0.16, "damage": 120, "reach": 4.8, "arc": PI, "style": "fireburst", "color": Color("ff9956")}, 2, "flintlock")
		else:
			p.blocking = g.secondary_held
		return
	p.cooldowns.flintlock = c.cooldowns.flintlock
	p.shot = 0.28
	if id == "samurai":
		fire_projectile(g, {"damage": 59, "speed": 32, "kind": "arrow", "heavy": true})
	elif id == "ninja":
		for i in range(-2, 3):
			fire_projectile(g, {"angle": p.angle + i * 0.13, "damage": 20, "speed": 23, "kind": "star", "width": 0.25})
	elif id == "mage":
		if p.buffTime > 0:
			p.cooldowns.flintlock = 0.18
		fire_projectile(g, {"damage": 34, "speed": 14, "kind": "bolt", "width": 0.38})
	elif id == "knight":
		begin_attack(g, {"duration": 0.32, "contact": 0.07, "damage": 31, "reach": 2.6, "arc": 1.1, "style": "bash"}, 0, "flintlock")
		p.vel += dir * 3.5
	elif id == "dragoon":
		if p.buffTime > 0:
			p.cooldowns.flintlock = 0
		var delta = g.aim - p.pos
		delta.y = 0
		delta = delta.limit_length(7.5)
		var target = p.pos + delta
		g.fx.ring(g.clamp_arena(target), g.tint(), 2.7, 0.7)
		travel(g, target, 0.72, 4.8, "lance-leap", true)
	elif id == "magic-swordsman":
		p.cooldowns.flintlock = 0.42 if p.buffTime > 0 else c.cooldowns.flintlock
		fire_projectile(g, {"damage": 79, "speed": 13, "kind": "wave", "width": 1.75, "pierce": true, "heavy": true, "range": 24})
		p.vel -= dir * 1.6
		g.fx.slash(p.pos, p.angle, 2, g.tint(), 3.5, {"style": "magic", "arc": 2.5, "height": 1.2, "tilt": 0.5})
	elif id == "ranger":
		p.cooldowns.flintlock = 0.55 if p.buffTime > 0 else c.cooldowns.flintlock
		p.burst = {"remaining": 4, "timer": 0.0, "ticket": g.current_ticket()}
	elif id == "explorer":
		begin_attack(g, {"duration": 0.45, "contact": 0.1, "damage": 53, "reach": 3.6, "arc": PI, "style": "spin"}, 2, "flintlock")
		p.vel += dir * 1.5

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
	var can_block = g.secondary_held and not p.crouched and p.travel == null and p.roll <= 0 and p.attack == null
	p.blocking = can_block and g.class_id in ["knight", "master-thief"]
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
	if g.secondary_held and g.class_id in ["ranger", "mage", "magic-swordsman"] and p.buffTime > 0 and p.cooldowns.flintlock <= 0:
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
	if not p.blocking or (g.class_id == "knight" and not projectile):
		return false
	# Incoming travels from attacker to defender: only the front half blocks.
	if incoming.dot(g.front(p.angle)) > -0.05:
		return false
	if g.class_id == "master-thief":
		p.blockMeter = minf(100, p.blockMeter + (34 if projectile else 40))
	if g.class_id == "knight" and p.buffTime > 0:
		p.riposte = 1
	g.fx.ring(p.pos, g.tint(), 1.5, 0.22)
	g.fx.particles(p.pos, Color("ffe6b3"), 12, 0.65)
	g.fx.damage(p.pos, "FIRE READY" if p.blockMeter >= 100 else "BLOCK", "fire" if p.blockMeter >= 100 else "ice")
	g.sound.play("shield", {"pitch": 1.5, "volume": 0.7})
	g.hit_stop = maxf(g.hit_stop, 0.035)
	return true

static func update_projectile(g, pr: Dictionary, dt: float) -> void:
	if pr.life <= 0:
		return
	var previous = pr.mesh.position
	pr.life -= dt
	pr.mesh.position += pr.vel * dt
	if pr.kind == "star":
		pr.mesh.rotate_object_local(Vector3.UP, dt * 30)
	elif pr.kind == "bolt":
		pr.mesh.rotate_object_local(Vector3.FORWARD, dt * 6)
	pr.trailTimer -= dt
	if pr.trailTimer <= 0:
		var direction = pr.vel.normalized()
		var tail = pr.mesh.position - direction * (1.1 if pr.kind == "wave" else 0.9) * pr.rangeScale
		var color = g.tint()
		if pr.kind == "wave":
			var side = Vector3(direction.z, 0, -direction.x)
			for offset in [-0.85, 0, 0.85]:
				var head = pr.mesh.position + side * offset * pr.rangeScale
				g.fx.streak(head - direction * 1.15 * pr.rangeScale, head, color, 0.025 * pr.rangeScale, 0.16)
		else:
			g.fx.streak(tail, pr.mesh.position, color, (0.075 if pr.kind == "bolt" else 0.022) * pr.rangeScale, 0.13)
		pr.trailTimer = 0.055
	g.resolve_projectile_segment(pr, previous, pr.mesh.position)
