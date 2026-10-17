extends Ninja
## A lightweight combat target, deliberately outside the wave simulation.
const Critical=preload("res://scripts/critical_hits.gd")
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
var target_material: StandardMaterial3D
var contact_shape: Dictionary
func _ready():
	training_dummy=true;practice=true;home=position
	collision_layer=4;collision_mask=0;body_radius=0 # Combat queries include the capsule's radius.
	# Keep combat snapshots finite. Immortality comes from never subtracting HP.
	max_hp=100;hp=max_hp
	var collision=CollisionShape3D.new();var capsule=CapsuleShape3D.new()
	capsule.radius=.7;capsule.height=3.0;collision.shape=capsule;collision.position.y=1.5;add_child(collision)
	contact_shape={"shape":capsule,"center":collision.position}
	model=HeroModel.new(true);model.crowd_proxy=true;add_child(model)
	var wood=Geo.mat("a77a4e");var dark=Geo.mat("65472e");var rope=Geo.mat("ddc693")
	target_material=Geo.mat("bd6048").duplicate()
	Geo.box(model,Vector3(0,.08,0),Vector3(2.5,.16,1.6),dark)
	Geo.box(model,Vector3(0,1.25,-.14),Vector3(.28,2.5,.28),dark)
	Geo.box(model,Vector3(0,1.55,0),Vector3(1.35,1.5,.7),wood)
	Geo.box(model,Vector3(0,2.0,0),Vector3(2.7,.3,.35),wood)
	Geo.box(model,Vector3(0,2.7,0),Vector3(.72,.72,.7),wood)
	for height in [1.05,2.12]:Geo.box(model,Vector3(0,height,0),Vector3(1.4,.12,.76),rope)
	for i in range(3):
		var disk=CylinderMesh.new();disk.radial_segments=16;disk.rings=1;disk.top_radius=[.46,.31,.13][i];disk.bottom_radius=disk.top_radius;disk.height=.025
		var target=Geo.mesh(model,disk,Vector3(0,1.6,.37+i*.03),rope if i==1 else target_material);target.rotation.x=PI*.5
	for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	name_tag=Label3D.new();name_tag.name="DummyLabel";name_tag.text="TRAINING DUMMY\n∞ HP";name_tag.position.y=3.5
	name_tag.font_size=32;name_tag.pixel_size=.012;name_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.modulate=Color("f4e1ab");name_tag.outline_modulate=Color("182923");name_tag.outline_size=6;add_child(name_tag)
func combat_aim_point(from: Vector3)->Vector3:return combat_contact_point(from)
func combat_contact_point(point: Vector3)->Vector3:
	return global_position+Contact._capsule_contact(contact_shape,point-global_position)
func combat_bounds()->AABB:
	return AABB(global_position+Vector3(-.7,0,-.7),Vector3(1.4,3,1.4))
func combat_segment_contact(from: Vector3,to: Vector3,radius: float)->Dictionary:
	var t=Contact._capsule_segment(contact_shape,from-global_position,to-global_position,radius)
	return {"t":t,"point":combat_contact_point(from.lerp(to,t))} if t>=0 else {}
func combat_segment_hit(from: Vector3,to: Vector3,radius: float)->bool:
	return not combat_segment_contact(from,to,radius).is_empty()
func take_hit(damage: float,dir: Vector3,heavy: bool,ticket: Dictionary={}):
	if damage<=0 or not is_finite(damage):return
	# Preserve ordinary hit attribution, critical numbers and combo progression,
	# while bypassing all death, kill rewards, loot and health arithmetic.
	var critical=Critical.roll(ticket)
	if not ticket.get("tower",false):
		damage*=game.player.attack_chain.damage_for(ticket)
		game.player.attack_chain.confirm(ticket)
		if critical:damage*=Critical.DAMAGE_MULTIPLIER
	recoil_age=0;recoil_direction=dir.normalized();recoil_strength=.16 if heavy else .08
	velocity=Vector3.ZERO
	game.damage_number(global_position+Vector3.UP*2.5,int(damage),heavy,critical)
func _physics_process(delta):
	if not game.playing or game.paused:return
	position=home;velocity=Vector3.ZERO
	visible=game.forest_enemy_visible(self)
	impact_pause=maxf(0,impact_pause-delta)
	if frozen_left>0:
		frozen_left=maxf(0,frozen_left-delta)
		if frozen_left<=0 and is_instance_valid(frozen_visual):frozen_visual.hide()
		return
	recoil_age+=delta
	var response=exp(-recoil_age*10)*sin(recoil_age*24)*recoil_strength
	model.rotation=Vector3(recoil_direction.z*response,0,-recoil_direction.x*response)
	target_material.albedo_color=Color("bd6048").lerp(Color("ffe7a3"),maxf(0,1-recoil_age/.12))
func combat_knockback(_direction: Vector3,_strength: float,_flinch: float):pass
func apply_rogue_bash(_direction: Vector3):pass
func reset_pose():
	position=home;velocity=Vector3.ZERO;recoil_age=1;impact_pause=0;frozen_left=0
	model.rotation=Vector3.ZERO;target_material.albedo_color=Color("bd6048")
	if is_instance_valid(frozen_visual):frozen_visual.hide()
