extends "res://scripts/character_projectile.gd"
## A piercing spirit: prepared motion, shared leases and native swept contacts.
const MODEL=preload("res://assets/vfx/knight_lion/energy_lion.glb")
const ENERGY=preload("res://assets/vfx/knight_lion/energy.gdshader")
const SPEED=60.0
const LIFETIME=5.0
const DAMAGE=360.0
const PUSH=22.0
var direction=Vector3.FORWARD
var damage=DAMAGE
var size=1.0
var age=0.0
var hit_targets:Dictionary={}
var ornament:Node3D
var animator:AnimationPlayer
var material:ShaderMaterial

func _ready():
	add_to_group("knight_lions")
	ornament=MODEL.instantiate();add_child(ornament)
	material=ShaderMaterial.new();material.shader=ENERGY
	for mesh in ornament.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in ornament.find_children("*","AnimationPlayer",true,false):animator=node;break
	assert(animator!=null and animator.has_animation("run"))
	animator.get_animation("run").loop_mode=Animation.LOOP_LINEAR

func restart_visual():
	rotation.y=atan2(-direction.x,-direction.z)
	ornament.scale=Vector3.ONE*1.65*size
	material.set_shader_parameter("flow_time",0.0);material.set_shader_parameter("opacity",1.0)
	animator.play("run",0,2.2);animator.seek(0,true)

func _physics_process(delta:float):
	if not pool_live:return
	if not is_instance_valid(game) or not is_instance_valid(hero) or not game.playing or hero.hp<=0:retire();return
	if game.paused or game.transitioning:return
	var remaining=minf(maxf(0,delta),LIFETIME-age)
	# Short terrain segments follow hills/bridge decks and cannot skip thin victims on a hitch.
	while remaining>.000001:
		var step=minf(remaining,2.0/(SPEED*skill_factor("travel_speed")))
		var from=global_position
		var to=from+direction*SPEED*skill_factor("travel_speed")*step
		var ground=AttackChain.world_ray(self,to+Vector3.UP*5.0,to+Vector3.DOWN*24.0)
		if not ground.is_empty():to.y=ground.position.y+.06
		var height=Vector3.UP*1.35*size
		var wall=AttackChain.world_ray(self,from+height,to+height)
		var end:Vector3=to+height if wall.is_empty() else wall.position
		for enemy in AttackChain.segment_enemy_candidates(game,from+height,end,1.35*size*skill_factor("hit_area")):
			if not is_instance_valid(enemy) or enemy.dead or hit_targets.has(enemy.get_instance_id()):continue
			var contact=AttackChain.segment_contact(enemy,from+height,end,1.35*size*skill_factor("hit_area"))
			if contact.is_empty():continue
			var center=(from+height).lerp(end,float(contact.t))
			if not AttackChain.clear_line(self,center,AttackChain.aim_point(enemy,center)):continue
			hit_targets[enemy.get_instance_id()]=true
			enemy.take_hit(damage,direction,true,attack_ticket)
			if enemy.has_method("combat_knockback"):enemy.combat_knockback(direction,PUSH,.65)
			# Native hit flash/numbers already sell contact; avoid rebuilding impact geometry per victim.
			if hero.ai_controlled:game.confirm_ally_impact(enemy,contact.point,direction,2,true,7,false)
			else:game.confirm_impact(enemy,contact.point,direction,2,true,7,false)
		global_position=end-height
		age+=step;remaining-=step
		if not wall.is_empty():retire();return
	material.set_shader_parameter("flow_time",age)
	material.set_shader_parameter("opacity",clampf((LIFETIME-age)/.3,0,1))
	if age>=LIFETIME-.000001:retire()
