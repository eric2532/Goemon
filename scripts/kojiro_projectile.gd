extends "res://scripts/character_projectile.gd"
## Original effect pages and wind geometry on the shared projectile lease.
const ROOT="res://assets/characters/recovered_kojiro/effects/"
const SPELL_SCALE=3.0
# The authored idle body is 84 source units tall; portable effects need the same fitted scale.
const SOURCE_UNIT=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT*preload("res://scripts/character_proportions.gd").KOJIRO_SIZE/84.0
var kind="homing"
var velocity=Vector3.ZERO
var damage=32.0
var unit=.04
var size_factor=1.0
var contact_scale=1.0
var target:Node3D
var age=0.0
var lifetime=3.0
var trail_tick=0
var hit_targets={}
var visual:MeshInstance3D
var effect_material:ShaderMaterial
static var wind_mesh:Mesh
static var quad_meshes={}

func _ready():
	visual=MeshInstance3D.new();add_child(visual)
	if kind=="wind":
		if wind_mesh==null:
			var source=load(ROOT+"wind.glb").instantiate()
			var mesh=source.find_children("*","MeshInstance3D",true,false)[0].mesh
			var arrays=mesh.surface_get_arrays(0)
			var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			for i in uv.size():uv[i]=(uv[i]-Vector2(.25,.25))*4
			arrays[Mesh.ARRAY_TEX_UV]=uv
			wind_mesh=ArrayMesh.new();wind_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);source.free()
		visual.mesh=wind_mesh
	else:
		if not quad_meshes.has(kind):
			var quad=QuadMesh.new();quad.size=Vector2(80,64) if kind=="wave" else Vector2.ONE*(16 if kind=="spark" else 32)
			if kind=="wave":quad.center_offset.y=32 # Grow above the flight plane instead of burying the enlarged bird.
			quad_meshes[kind]=quad
		visual.mesh=quad_meshes[kind]
	effect_material=ShaderMaterial.new();effect_material.shader=preload("res://assets/characters/recovered_skullpion/effects/volley.gdshader")
	effect_material.set_shader_parameter("atlas",load("res://assets/characters/recovered_musashi/assimilation/rocket_trail.png" if kind=="dust" else ROOT+kind+".png"))
	effect_material.set_shader_parameter("frames",8 if kind=="wave" else 2 if kind=="wind" else 10 if kind=="dust" else 1)
	effect_material.set_shader_parameter("billboard",kind not in ["wind","wave"])
	# The frontal phoenix art faces along flight; camera roll made forward casts look sideways.
	effect_material.set_shader_parameter("directional_billboard",kind=="homing")
	if kind=="homing":effect_material.set_shader_parameter("sprite_forward",Vector2(1,-1).normalized())
	visual.material_override=effect_material;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func restart_visual():
	age=0;trail_tick=0;lifetime=10.0/30 if kind=="dust" else 1.0 if kind=="spark" else 3.0
	if kind=="wind":rotation.y=atan2(velocity.x,velocity.z)
	elif kind=="wave" and velocity.length_squared()>.001:
		rotation=Vector3(-atan2(velocity.y,Vector2(velocity.x,velocity.z).length()),atan2(velocity.x,velocity.z),0)
	elif kind=="homing" and velocity.length_squared()>.001:quaternion=Quaternion(Vector3.BACK,velocity.normalized())
	update_visual()

func update_visual():
	var growth=minf(4,1+age*30/16) if kind=="wave" else 1+age*30/32 if kind=="wind" else 2 if kind=="spark" else 3 if kind=="dust" else 1
	# Preserve hit growth while the phoenix opens more slowly from a smaller launch.
	contact_scale=unit*size_factor*growth*SPELL_SCALE
	if kind=="wave":growth=lerpf(.5,4,minf(age/2.0,1))
	visual.scale=Vector3.ONE*unit*size_factor*growth*SPELL_SCALE*skill_factor("size")
	effect_material.set_shader_parameter("frame",posmod(floori(age*30),8 if kind=="wave" else 2 if kind=="wind" else 10 if kind=="dust" else 1))

func _physics_process(delta:float):
	if not is_instance_valid(hero) or not game.playing:retire();return
	if game.paused or game.transitioning:return
	age+=delta
	if age>=lifetime:retire();return
	update_visual()
	if kind in ["spark","dust"]:global_position+=velocity*delta;return
	if kind=="homing":
		if is_instance_valid(target) and not target.dead:
			var aim=AttackChain.aim_point(target,global_position)-global_position
			if aim.length_squared()>.001:velocity=velocity.normalized().slerp(aim.normalized(),minf(1,delta*3))*velocity.length()
		if velocity.length_squared()>.001:quaternion=Quaternion(Vector3.BACK,velocity.normalized())
		var tick=floori(age*30/4)
		if tick>trail_tick:trail_tick=tick;spark(global_position,Vector3.ZERO)
	if kind=="wind" and floori(age*30)>trail_tick:
		trail_tick=floori(age*30)
		projectile_pool.launch(hero,get_script(),"dust",{"kind":"dust","position":global_position,"unit":unit,"velocity":velocity.normalized().rotated(Vector3.UP,PI*.5)*16*30*unit,"damage":0.0})
	var from=global_position;var next=from+velocity*delta
	var wall=AttackChain.world_ray(self,from,next)
	var end:Vector3=next if wall.is_empty() else wall.position
	var radius=unit*(16 if kind=="homing" else 48)*contact_scale/maxf(unit,.001)*skill_factor("hit_area")
	for enemy in AttackChain.segment_enemy_candidates(game,from,end,radius):
		if not is_instance_valid(enemy) or enemy.dead or hit_targets.has(enemy.get_instance_id()):continue
		if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
		var contact=AttackChain.segment_contact(enemy,from,end,radius)
		if contact.is_empty() or not AttackChain.clear_line(self,from,contact.point):continue
		hit_targets[enemy.get_instance_id()]=true
		enemy.take_hit(damage,velocity.normalized(),false,attack_ticket)
		if hero.ai_controlled:game.confirm_ally_impact(enemy,contact.point,velocity.normalized(),0,true,28,false)
		else:game.confirm_impact(enemy,contact.point,velocity.normalized(),0,true,28,false)
		if kind=="homing":
			for i in 5:spark(contact.point,Vector3(sin(i*TAU/5),.5,cos(i*TAU/5))*unit*60)
			if enemy==target:target=null
	if not wall.is_empty():retire();return
	global_position=next

func spark(point:Vector3,motion:Vector3):
	projectile_pool.launch(hero,get_script(),"spark",{"kind":"spark","position":point,"velocity":motion,"unit":unit,"damage":0.0})

func tune_visual():pass # Animated growth owns visual scaling.
