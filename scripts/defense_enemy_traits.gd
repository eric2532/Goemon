class_name DefenseEnemyTraits
extends RefCounted

# Defense-only modifiers and a self-contained boss attack. They never use the
# campaign boss flag, spawn helpers, or trigger a global victory.
const WINDUP=1.25
const IMPACT=.25
const RECOVERY=1.8
const SHIELD_BREAK=1.6
static var accent_box: BoxMesh
static var accent_orb: SphereMesh
static var status_ring: TorusMesh
static var danger_ring: TorusMesh
static var danger_disc: CylinderMesh
var enemy: Node
var slow_left=0.0
var slow_factor=1.0
var shield_broken_left=0.0
var phase="march"
var elapsed=0.0
var slam_cooldown=2.5
var slam_origin=Vector3.ZERO
var radius=9.0
var accents: Node3D
var shield: MeshInstance3D
var shield_trim: MeshInstance3D
var slow_visual: MeshInstance3D
var weak_point: MeshInstance3D
var tell: Node3D
var tell_ring: MeshInstance3D
var tell_fill: MeshInstance3D
var tell_label: Label3D
var boss_label: Label3D

func _init(actor: Node):enemy=actor

func is_boss()->bool:return enemy.defense_role=="boss" or enemy.defense_boss_tier>0

func apply_stats():
	match enemy.defense_role:
		"runner":enemy.defense_health_multiplier*=.7;enemy.defense_speed_multiplier*=1.45
		"brute":enemy.defense_health_multiplier*=1.8;enemy.defense_speed_multiplier*=.78
		"shield":enemy.defense_health_multiplier*=1.2;enemy.defense_speed_multiplier*=.9
		"boss":
			enemy.defense_health_multiplier*=40.0 if enemy.defense_boss_tier>=2 else 25.0
			enemy.defense_speed_multiplier*=.65 if enemy.defense_boss_tier>=2 else .72
			radius=12.0 if enemy.defense_boss_tier>=2 else 9.0

static func warm_meshes():
	if accent_box!=null:return
	accent_box=BoxMesh.new();accent_box.size=Vector3.ONE
	accent_orb=SphereMesh.new();accent_orb.radius=.5;accent_orb.height=1
	accent_orb.radial_segments=12;accent_orb.rings=6
	status_ring=TorusMesh.new();status_ring.inner_radius=.5;status_ring.outer_radius=.63
	status_ring.rings=16;status_ring.ring_segments=4
	danger_ring=TorusMesh.new();danger_ring.inner_radius=.974;danger_ring.outer_radius=1
	danger_ring.rings=48;danger_ring.ring_segments=4
	danger_disc=CylinderMesh.new();danger_disc.top_radius=1;danger_disc.bottom_radius=1
	danger_disc.height=.025;danger_disc.radial_segments=48

func accent(mesh: Mesh,position: Vector3,size: Vector3,color: String,glow: float=0)->MeshInstance3D:
	var visual=Geo.mesh(accents,mesh,position,Geo.mat(color,.2,glow))
	visual.scale=size;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visibility_range_end=180 if is_boss() else 70
	return visual

func setup_visuals():
	warm_meshes()
	if enemy.defense_role.is_empty():return
	accents=Node3D.new();accents.name="DefenseRoleAccents";enemy.add_child(accents)
	accents.scale=Vector3.ONE*enemy.defense_scale
	match enemy.defense_role:
		"runner":
			for side in [-1,1]:
				var fin=accent(accent_box,Vector3(side*.37,1.62,.15),Vector3(.15,.16,.9),"f3d966",.18)
				fin.rotation.x=-.25;fin.rotation.z=side*.4
		"brute":
			accent(accent_box,Vector3(0,1.35,-.25),Vector3(1.22,.8,.24),"90515a")
			accent(accent_box,Vector3(0,1.79,0),Vector3(1.55,.24,.72),"d48f63")
		"shield":
			shield=accent(accent_box,Vector3(0,1.05,-.57),Vector3(.95,1.6,.18),"66c9d1",.12)
			shield_trim=accent(accent_box,Vector3(0,1.05,-.68),Vector3(.14,1.24,.06),"e5f4eb",.2)
		"boss":
			accent(accent_box,Vector3(0,1.64,.05),Vector3(1.65,.35,.9),"6b3649")
			for side in [-1,1]:
				var horn=accent(accent_box,Vector3(side*.43,2.35,0),Vector3(.15,.65,.2),"e3b566",.1)
				horn.rotation.z=side*-.32
			weak_point=accent(accent_orb,Vector3(0,1.17,-.62),Vector3.ONE*.45,"ffcf6c",1.1)
			weak_point.hide()
			boss_label=Label3D.new();enemy.add_child(boss_label)
			boss_label.text="INFERNO WARLORD" if enemy.defense_boss_tier>=2 else "SHRINEBREAKER"
			boss_label.position.y=2.8*enemy.defense_scale;boss_label.font_size=42;boss_label.pixel_size=.026
			boss_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;boss_label.modulate=Color("f3c98b")
			boss_label.visibility_range_end=150

func apply_slow(factor: float,seconds: float):
	if enemy.dead or seconds<=0 or factor>=1:return
	var amount=clampf(factor,.25,1)
	var duration=clampf(seconds,0,6)
	if is_boss():amount=maxf(.75,1-(1-amount)*.35);duration=minf(3,duration*.5)
	slow_factor=minf(slow_factor,amount) if slow_left>0 else amount
	slow_left=maxf(slow_left,duration)
	if not is_instance_valid(slow_visual):
		warm_meshes()
		slow_visual=Geo.mesh(enemy,status_ring,Vector3(0,.10,0),Geo.mat("89dfff",.1,.3))
		slow_visual.scale=Vector3(enemy.defense_scale*1.15,1,enemy.defense_scale*1.15)
		slow_visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slow_visual.visibility_range_end=65
	slow_visual.show()

func tick_status(delta: float):
	if enemy.dead or not enemy.game.playing or enemy.game.paused or enemy.game.transitioning:return
	slow_left=maxf(0,slow_left-delta)
	if slow_left<=0:
		slow_factor=1
		if is_instance_valid(slow_visual):slow_visual.hide()
	shield_broken_left=maxf(0,shield_broken_left-delta)
	if is_instance_valid(shield):shield.visible=shield_broken_left<=0
	if is_instance_valid(shield_trim):shield_trim.visible=shield_broken_left<=0
	if is_instance_valid(accents):accents.rotation.y=enemy.model.rotation.y
	if enemy.frozen_left>0 and phase!="march":cancel_attack()

func hit_multiplier(direction: Vector3,ticket: Dictionary,heavy: bool)->float:
	if is_boss():return 2.0 if phase=="recovery" else 1.0
	if ticket.get("armor_piercing",false):return 1.0
	if enemy.defense_role=="brute":return .6
	if enemy.defense_role!="shield" or shield_broken_left>0:return 1.0
	# Attack vectors point from attacker to victim. A frontal attack therefore
	# arrives from the opposite direction to the vector passed to take_hit.
	var incoming=Vector3(-direction.x,0,-direction.z)
	if incoming.length_squared()<.0001:return 1.0
	var forward=-enemy.model.global_basis.z;forward.y=0
	if forward.normalized().dot(incoming.normalized())<=.25:return 1.0
	if heavy:
		shield_broken_left=SHIELD_BREAK
		if is_instance_valid(shield):shield.hide()
		if is_instance_valid(shield_trim):shield_trim.hide()
		return 1.0
	return .3

func adjust_hit_response(heavy: bool):
	if is_boss():
		enemy.velocity*=.12;enemy.velocity.y=0
		enemy.stun=minf(enemy.stun,.055)
	elif enemy.defense_role=="brute":
		enemy.velocity*=.65;enemy.stun*=.75
	elif enemy.defense_role=="shield" and heavy and shield_broken_left>0:
		enemy.stun=maxf(enemy.stun,.65)

func clear_sight(from: Vector3,to: Vector3)->bool:
	return enemy.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1)).is_empty()

func ensure_tell():
	if is_instance_valid(tell):return
	warm_meshes()
	tell=Node3D.new();tell.name="DefenseBossSlamTell";enemy.add_child(tell);tell.set_as_top_level(true)
	tell_ring=Geo.mesh(tell,danger_ring,Vector3(0,.10,0),Geo.mat("f4a665",0,.45))
	tell_ring.scale=Vector3(radius,1,radius)
	var tint=StandardMaterial3D.new();tint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	tint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;tint.albedo_color=Color(1,.21,.12,.22)
	tell_fill=Geo.mesh(tell,danger_disc,Vector3(0,.075,0),tint)
	for visual in [tell_ring,tell_fill]:visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tell_label=Label3D.new();tell.add_child(tell_label);tell_label.position=Vector3(0,.65,-radius*.45)
	tell_label.text="SLAM · JUMP / DODGE";tell_label.font_size=42;tell_label.pixel_size=.027
	tell_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;tell_label.modulate=Color("ffcc94")

func begin_slam():
	if not is_boss() or enemy.dead:return
	ensure_tell();phase="warning";elapsed=0
	slam_origin=enemy.global_position;slam_origin.y=enemy.game.world.height_at(slam_origin.x,slam_origin.z)+.02
	tell.global_position=slam_origin;tell.show();tell_label.text="SLAM · JUMP / DODGE"
	tell_ring.scale=Vector3(radius,1,radius);tell_fill.scale=Vector3(.02,1,.02)
	if is_instance_valid(weak_point):weak_point.hide()
	enemy.state="windup";enemy.timer=WINDUP;enemy.velocity.x=0;enemy.velocity.z=0;enemy.walk_clock=0

func slam_contact():
	if enemy.dead or not enemy.game.playing or enemy.game.paused or enemy.game.transitioning:return
	var hero=enemy.game.player
	var offset=hero.global_position-slam_origin
	var grounded_height=hero.global_position.y-enemy.game.world.height_at(hero.global_position.x,hero.global_position.z)
	if Vector2(offset.x,offset.z).length()<=radius+.35 and grounded_height<1.6 and absf(offset.y)<2.0:
		if clear_sight(slam_origin+Vector3.UP*.8,hero.global_position+Vector3.UP*.8):
			var direction=Vector3(offset.x,0,offset.z).normalized()
			hero.take_hit((38 if enemy.defense_boss_tier>=2 else 28)*enemy.defense_damage_multiplier,direction)
	if enemy.position.distance_squared_to(hero.position)<120*120:
		enemy.game.sound("heavy_swing",.65,true)
		enemy.game.burst(slam_origin+Vector3.UP*.2,Color("edaa6e"),12,2.2)

func tick_attack(delta: float)->bool:
	if not is_boss() or enemy.dead or not enemy.game.playing or enemy.game.paused or enemy.game.transitioning or enemy.game.tuning.freeze_ai:return false
	if phase=="march":
		slam_cooldown=maxf(0,slam_cooldown-delta)
		if enemy.game.player.rogue_untargetable():return false
		var offset=enemy.game.player.global_position-enemy.global_position
		if slam_cooldown>0 or enemy.game.player.hp<=0 or absf(offset.y)>8 or Vector2(offset.x,offset.z).length()>radius+3:return false
		begin_slam()
	elapsed+=delta;enemy.velocity.x=0;enemy.velocity.z=0;enemy.stun=0
	if phase=="warning":
		enemy.state="windup";enemy.timer=maxf(0,WINDUP-elapsed)
		var fraction=clampf(elapsed/WINDUP,.02,1)
		tell_fill.scale=Vector3(radius*fraction,1,radius*fraction)
		if elapsed>=WINDUP:
			phase="impact";elapsed=0;enemy.state="strike";enemy.timer=IMPACT
			tell_label.text="SLAM";slam_contact()
	elif phase=="impact":
		enemy.state="strike";enemy.timer=maxf(0,IMPACT-elapsed)
		var expansion=radius*(1+elapsed*.2);tell_ring.scale=Vector3(expansion,1,expansion)
		if elapsed>=IMPACT:
			phase="recovery";elapsed=0;tell.hide()
			if is_instance_valid(weak_point):weak_point.show()
			if is_instance_valid(boss_label):boss_label.text="WEAK POINT OPEN · 2× DAMAGE"
	elif phase=="recovery":
		enemy.state="recover";enemy.timer=maxf(0,RECOVERY-elapsed)
		if is_instance_valid(weak_point):weak_point.scale=Vector3.ONE*(.48+.04*sin(elapsed*10))
		if elapsed>=RECOVERY:cancel_attack();slam_cooldown=5.0
	return true

func cancel_attack():
	phase="march";elapsed=0;slam_cooldown=maxf(2,slam_cooldown)
	if is_instance_valid(tell):tell.hide()
	if is_instance_valid(weak_point):weak_point.hide()
	if is_instance_valid(boss_label):boss_label.text="INFERNO WARLORD" if enemy.defense_boss_tier>=2 else "SHRINEBREAKER"

func cancel():
	cancel_attack();slow_left=0;slow_factor=1
	if is_instance_valid(slow_visual):slow_visual.hide()
	if is_instance_valid(accents):accents.hide()
	if is_instance_valid(boss_label):boss_label.hide()
