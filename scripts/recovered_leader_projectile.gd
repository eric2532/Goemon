class_name RecoveredLeaderProjectile
extends Node3D
## Original Ben bomb sprite and star mesh, with source trajectories and collision.
## Bomb danger palettes and terminal effect23 sprites retain source animation.
## Ed's fireball meshes and nonbomb impact bursts remain runtime adaptations.
var game: Node
var hero: Hero
var attack_ticket: Dictionary={}
var source_character: int=14
var bomb: bool=false
var shuriken=false
var axe=false
var bomb_target=Vector3.INF
var bomb_origin=Vector3.INF
var bomb_arrived=false
var velocity: Vector3=Vector3.ZERO
var damage: float=28.0
var hit_radius: float=.4
var blast_radius: float=2.5
var lifetime: float=2.5
var flight_age=0.0
var floor_bounces=0
var resolved=false
var hit_enemies: Dictionary={}
var ornament: Node3D
var trail: MeshInstance3D
var fuse_light: MeshInstance3D
var bomb_effect: Node3D
var attack_scale=1.0

func _ready():
	add_to_group("leader_projectiles");add_to_group("projectiles")
	process_mode=Node.PROCESS_MODE_PAUSABLE
	ornament=Node3D.new();add_child(ornament)
	if source_character==15:
		attack_scale=preload("res://scripts/character_proportions.gd").BEN_MODEL_SCALE*hero.growth_multiplier()
		ornament.scale=Vector3.ONE*attack_scale
		hit_radius*=attack_scale
	if bomb:
		var sprite=Sprite3D.new();sprite.name="SourceBombSprite"
		sprite.texture=preload("res://assets/characters/recovered_leaders/ben/bomb.png")
		sprite.pixel_size=.012;sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		ornament.add_child(sprite);sprite.material_override=_palette(sprite.texture)
		sprite.material_override.set_shader_parameter("billboard",true)
	elif shuriken or axe:
		var star=(preload("res://assets/characters/recovered_leaders/ben/axe.glb") if axe else preload("res://assets/characters/recovered_leaders/ben/projectile.glb")).instantiate()
		star.name="SourceAxe" if axe else "SourceShuriken";ornament.add_child(star);star.scale=Vector3.ONE*.01
		for mesh in star.find_children("*","MeshInstance3D",true,false):
			# The recovered star has one surface. Whole-instance override also
			# survives destruction before the deferred renderer material update.
			var original=mesh.get_active_material(0) as BaseMaterial3D
			var material=_palette(original.albedo_texture if original else null)
			if original:material.set_shader_parameter("tint_color",original.albedo_color)
			mesh.material_override=material
	else:
		Geo.sphere(ornament,Vector3.ZERO,Vector3.ONE*.65,Geo.mat("f46a26",0,1.4))
		Geo.sphere(ornament,Vector3(0,0,-.05),Vector3.ONE*.42,Geo.mat("ffe9a5",0,2))
		trail=Geo.spike(ornament,Vector3(0,0,.95),Vector3.ZERO,.23,Geo.mat("d93b27",0,.65))
	for mesh in ornament.get_children():
		if mesh is GeometryInstance3D:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update_visual(0)

func _palette(texture: Texture2D)->ShaderMaterial:
	var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/recovered_leaders/source_palette.gdshader")
	material.set_shader_parameter("textured",texture!=null)
	if texture:material.set_shader_parameter("albedo_texture",texture)
	var environment=get_world_3d().environment
	if environment:
		material.set_shader_parameter("compensate_filmic",environment.tonemap_mode==Environment.TONE_MAPPER_FILMIC)
		material.set_shader_parameter("scene_exposure",environment.tonemap_exposure)
		material.set_shader_parameter("scene_white",environment.tonemap_white)
	return material

func _physics_process(delta: float):
	if is_queued_for_deletion():return
	if not is_instance_valid(game) or not is_instance_valid(hero) or not game.playing:
		queue_free();return
	if game.paused:return
	if resolved:
		if is_instance_valid(bomb_effect):
			var complete=bomb_effect.advance(delta)
			if complete:queue_free()
		return
	var source_bomb=bomb and bomb_target!=Vector3.INF
	var fuse=1.0
	var step=minf(delta,maxf(0,lifetime))
	if bomb:step=minf(step,maxf(0,fuse-flight_age))
	lifetime-=delta;flight_age+=step
	if bomb and bomb_arrived:
		if flight_age>=fuse or lifetime<=0:_explode(global_position)
		else:_update_visual(step)
		return
	var from=global_position
	var next: Vector3
	if source_bomb:
		if bomb_origin==Vector3.INF:bomb_origin=from
		var u=clampf(flight_age/.4,0,1)
		next=bomb_origin.lerp(bomb_target,u)+Vector3.UP*1.28*sin(PI*u)
		if step>0:velocity=(next-from)/step
	else:
		var gravity=Vector3.ZERO if shuriken or axe else Vector3.DOWN*(18.0 if bomb else 3.0)
		next=from+velocity*step+gravity*step*step*.5
		velocity+=gravity*step
	var query=PhysicsRayQueryParameters3D.create(from,next,1)
	query.hit_from_inside=true
	var wall=get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3=next if wall.is_empty() else wall.position
	var nearest: Ninja=null
	var contact_point=Vector3.ZERO
	var nearest_t=INF
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or hit_enemies.has(enemy.get_instance_id()):continue
		var contact=AttackChain.segment_contact(enemy,from,end,hit_radius)
		if contact.is_empty() or float(contact.t)>=nearest_t:continue
		# An enlarged sphere may overlap a victim beyond the clipped wall ray.
		# Keep the projectile center on its swept path and test cover from there.
		var center=from.lerp(end,float(contact.t))
		var aim=AttackChain.aim_point(enemy,center)
		if not _clear_line(center,aim):continue
		nearest=enemy;nearest_t=float(contact.t);contact_point=center if bomb else contact.point
	if nearest!=null:
		global_position=contact_point
		if bomb:
			bomb_arrived=true;velocity=Vector3.ZERO
			if flight_age>=fuse:_explode(contact_point)
		else:
			_damage_enemy(nearest,contact_point,velocity.normalized())
			_finish(contact_point)
		if not bomb:return
	if not bomb_arrived and not wall.is_empty():
		global_position=wall.position+wall.normal*.035
		if not bomb and not shuriken and not axe and wall.normal.y>.65 and floor_bounces<2 and velocity.y<0:
			floor_bounces+=1;velocity=velocity.bounce(wall.normal);velocity.y=maxf(2.8,velocity.y*.7)
		else:
			if bomb:
				bomb_arrived=true;velocity=Vector3.ZERO
				if flight_age>=fuse:_explode(global_position)
			else:_finish(global_position)
			if not bomb:return
	elif not bomb_arrived:global_position=next
	if source_bomb and not bomb_arrived and flight_age>=.4:
		bomb_arrived=true
	if bomb and flight_age>=fuse:_explode(global_position);return
	if lifetime<=0:
		if bomb:_explode(global_position)
		else:queue_free()
		return
	_update_visual(step)

func _clear_line(from: Vector3,to: Vector3)->bool:
	if from.distance_squared_to(to)<.000001:return true
	var ray=PhysicsRayQueryParameters3D.create(from,to,1)
	ray.hit_from_inside=true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _damage_enemy(enemy: Ninja,point: Vector3,direction: Vector3):
	var id=enemy.get_instance_id()
	if hit_enemies.has(id):return
	hit_enemies[id]=true
	enemy.take_hit(damage,direction,bomb,attack_ticket)
	var local=not attack_ticket.get("allied",false) and game.player==hero and hero.character_id==source_character
	if local:game.confirm_impact(enemy,point,direction,2 if bomb else 0,true,source_character)
	else:game.confirm_ally_impact(enemy,point,direction,2 if bomb else 0,true,source_character)

func _explode(point: Vector3):
	if resolved:return
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or hit_enemies.has(enemy.get_instance_id()):continue
		# A zero-length swept sphere tests the fitted hurt volumes, including large rigs.
		if AttackChain.segment_contact(enemy,point,point,blast_radius).is_empty():continue
		var contact=AttackChain.contact_point(enemy,point,enemy.global_position+Vector3.UP)
		if not _clear_line(point,contact):continue
		var direction=(contact-point).normalized()
		if direction.length_squared()<.001:direction=Vector3.UP
		_damage_enemy(enemy,contact,direction)
	_finish(point)

func _finish(point: Vector3):
	if resolved:return
	resolved=true
	if bomb:
		bomb_effect=preload("res://scripts/ben_bomb_explosion.gd").new()
		bomb_effect.body=ornament.get_node("SourceBombSprite")
		bomb_effect.name="SourceBombExplosionEffect"
		# Four overlapping source clouds fill the actual blast diameter.
		bomb_effect.scale=Vector3.ONE*blast_radius*.5;add_child(bomb_effect)
		# The warning palette runs during the one-second fuse. Damage and the
		# terminal burst now coincide instead of adding a second visual delay.
		bomb_effect.age=1.0;bomb_effect.advance(0)
		game.sound("ben_bomb_explosion",.6,false,attack_ticket,source_character)
		return
	game.burst(point,Color("ff9c32"),20 if bomb else 9,1.2 if bomb else .65)
	if not shuriken and not axe:game.sound("fire_impact",.6 if bomb else .42,false,attack_ticket,source_character)
	queue_free()

func _update_visual(delta: float):
	if shuriken or axe:ornament.rotation.y+=delta*30.0*67.5*PI/180.0
	elif bomb:
		if flight_age>=.4:
			var sprite=ornament.get_node("SourceBombSprite") as Sprite3D
			sprite.texture=preload("res://assets/characters/recovered_leaders/ben/bomb_danger_atlas.png")
			sprite.hframes=10;sprite.frame=posmod(30-floori(flight_age*30),10)
			sprite.material_override.set_shader_parameter("albedo_texture",sprite.texture)
	elif velocity.length_squared()>.001:
		ornament.quaternion=Quaternion(Vector3.FORWARD,velocity.normalized())
		if is_instance_valid(trail):trail.scale=Vector3.ONE*(1.0+.13*sin(flight_age*40))
