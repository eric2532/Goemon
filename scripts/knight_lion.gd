extends "res://scripts/character_combat.gd"
## Player spell controller; the lion itself uses the shared projectile cache.
const Projectile=preload("res://scripts/knight_lion_projectile.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const CHARGE=.8
const COOLDOWN=14.0
var cooldown=0.0
var charge_left=0.0
var direction=Vector3.FORWARD
var ticket:Dictionary={}
var charge_fx:Node3D
var charge_material:ShaderMaterial
var shots:Array=[]

func _ready():
	Pool.service(game).warm(hero,Projectile,"knight-lion",{},2)
	charge_fx=Node3D.new();charge_fx.name="KnightLionCharge";hero.add_child(charge_fx)
	charge_material=ShaderMaterial.new();charge_material.shader=Projectile.ENERGY
	var mesh=TorusMesh.new();mesh.inner_radius=.90;mesh.outer_radius=1.0;mesh.rings=32;mesh.ring_segments=8
	for i in 3:
		var ring=MeshInstance3D.new();ring.mesh=mesh;ring.material_override=charge_material
		ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.rotation=Vector3(i*PI/3,0,i*PI/3);charge_fx.add_child(ring)
	charge_fx.hide()

func can_cast()->bool:return charge_left<=0 and cooldown<=0 and hero.hp>0
func clear_cooldowns():cooldown=0.0
func is_attacking()->bool:return charge_left>0

func start_charge():
	if not can_cast():return
	direction=hero.combat_attack_direction();direction.y=0
	if direction.length_squared()<.001:direction=hero.facing
	direction=direction.normalized();hero.facing=direction
	charge_left=CHARGE;cooldown=COOLDOWN
	ticket=hero.attack_chain.begin("knight/lion");ticket.projectile=true
	charge_fx.show();animate_cast(0)
	var sound=game.get_node_or_null("RogueSharedClassAudio")
	if sound!=null:sound.play("shield")

func tick(delta:float):
	cooldown=maxf(0,cooldown-delta)
	if charge_left<=0:return
	charge_left=maxf(0,charge_left-delta)
	if charge_left>0:return
	charge_fx.hide()
	var scale_=hero.range_multiplier()
	shots=shots.filter(func(shot):return is_instance_valid(shot) and shot.pool_live)
	shots.append(Pool.service(game).launch(hero,Projectile,"knight-lion",{
		"position":hero.global_position+Vector3.UP*.06,"direction":direction,
		"damage":Projectile.DAMAGE*hero.damage_multiplier(),"size":scale_,"attack_ticket":ticket}))
	ticket={}
	var sound=game.get_node_or_null("RogueSharedClassAudio")
	if sound!=null:sound.play("claymore-wave",{"pitch":.65,"volume":.8})

func animate_cast(delta:float):
	if not is_attacking():return
	var progress=1.0-charge_left/CHARGE
	charge_fx.position=Vector3.UP*1.4
	charge_fx.scale=Vector3.ONE*(2.1-progress*.85)*hero.growth_multiplier()
	charge_fx.rotation=Vector3(progress*3,progress*5,progress*2)
	charge_material.set_shader_parameter("flow_time",progress)
	hero.facing=direction
	if hero.is_rogue_character():
		# Reuse the fitted shield-bracing pose without granting a gameplay block.
		var pose:Dictionary=hero.active_ability.player.duplicate()
		pose.blocking=true;pose.guardTime=1.0;pose.attack=null
		hero.model.actor.animate_pose(pose,delta,progress,0)

func interrupt_for_dodge():
	charge_left=0;ticket={};charge_fx.hide()

func cancel(_preserve_power:bool=false):
	interrupt_for_dodge()
	for shot in shots:
		if is_instance_valid(shot) and shot.pool_live:shot.retire()
	shots.clear()

func _exit_tree():
	for shot in shots:
		if is_instance_valid(shot) and shot.pool_live:shot.retire()
	if is_instance_valid(charge_fx):charge_fx.queue_free()
