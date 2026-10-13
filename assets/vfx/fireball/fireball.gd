class_name MusashiFireball
extends GoldCoin
var balance: MusashiBalance
var owner_character=2
func _ready():
	process_mode=Node.PROCESS_MODE_PAUSABLE
	add_to_group("edo_fireballs");add_to_group("projectiles");add_to_group("musashi_projectiles")
	ornament=FireEnergy.new();ornament.charged=heavy;add_child(ornament);ornament.scale=Vector3.ONE*(3.2 if heavy else 1.2)*game.player.growth_multiplier()
	ornament.quaternion=Quaternion(Vector3.FORWARD,velocity.normalized()) if velocity.length_squared()>.001 else Quaternion.IDENTITY
func update_visual(delta: float):
	trail_clock-=delta
	if trail_clock<=0:
		trail_clock=.045
		game.burst(global_position,Color("ff7827"),2 if heavy else 1,.45)
func impact(point: Vector3):
	game.burst(point,Color("ff732c"),24 if heavy else 10,1.2 if heavy else .7)
	if not heavy and (not game.has_method("forest_point_visible") or game.forest_point_visible(point)):game.sound("fire_impact",.7)
	if heavy:
		EdoFireExplosion.emit(game,point,true)
		BreakableBuilding.hit_area(game,point,balance.explosion_radius*game.player.growth_multiplier(),damage,attack_ticket,Vector3.ZERO,-1,hit_buildings)
		for e in game.enemies:
			if not is_instance_valid(e) or e.dead or hit_enemies.has(e.get_instance_id()):continue
			var center=e.global_position+Vector3.UP
			if center.distance_to(point)>balance.explosion_radius*game.player.growth_multiplier()+e.body_radius:continue
			var ray=PhysicsRayQueryParameters3D.create(point,center,1)
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
			e.take_hit(damage,(center-point).normalized(),true,attack_ticket)
			game.confirm_impact(e,center,(center-point).normalized(),2,true)
