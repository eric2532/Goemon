extends RefCounted
# An elite alternates a locked ground blast and a sustained, locked beam.
# The tell and the damaging area share the same origin, radius and direction.
const BLAST_RADIUS=4.5
const BEAM_LENGTH=23.0
const BEAM_HALF_WIDTH=.85
const WINDUP=1.2
const CHANNEL_TIME=1.8
var enemy: Ninja
var active=false
var kind="blast"
var next_kind="blast"
var phase=""
var elapsed=0.0
var recovery=1.6
var pulse_clock=0.0
var target=Vector3.ZERO
var direction=Vector3.FORWARD
var beam_length=BEAM_LENGTH
var tell: Node3D
var fill: MeshInstance3D
var core: MeshInstance3D
var label: Label3D

func _init(actor: Ninja):enemy=actor

func tint(hex: String,alpha: float)->StandardMaterial3D:
	var material=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=Color(hex);material.albedo_color.a=alpha
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.no_depth_test=false
	return material

func cancel():
	if is_instance_valid(tell):tell.queue_free()
	tell=null;active=false;phase="";recovery=2.0

func can_start()->bool:
	var hero=enemy.game.player
	var delta=hero.position-enemy.position
	return hero.hp>0 and absf(delta.y)<6 and Vector2(delta.x,delta.z).length()<21 and clear_sight(enemy.position+Vector3.UP*1.2,hero.position+Vector3.UP)

func clear_sight(a: Vector3,b: Vector3)->bool:
	return enemy.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()

func begin(attack: String):
	cancel();kind=attack;active=true;phase="warning";elapsed=0;pulse_clock=0
	target=enemy.game.player.position
	target.y=enemy.position.y
	direction=target-enemy.position;direction.y=0;direction=direction.normalized()
	if direction.is_zero_approx():direction=Vector3.FORWARD
	tell=Node3D.new();tell.top_level=true;enemy.add_child(tell);tell.add_to_group("elite_telegraphs")
	if kind=="blast":
		tell.global_position=target+Vector3.UP*.08
		fill=Geo.cylinder(tell,Vector3.ZERO,BLAST_RADIUS,.035,tint("ed5746",.22))
		Geo.torus(tell,Vector3.UP*.035,BLAST_RADIUS-.13,BLAST_RADIUS,tint("ffbe78",.95))
		core=Geo.cylinder(tell,Vector3.UP*.055,BLAST_RADIUS,.04,tint("ff8d57",.5));core.scale=Vector3(.04,1,.04)
	else:
		tell.global_position=enemy.position+Vector3.UP*.1
		fill=Geo.box(tell,Vector3.ZERO,Vector3(BEAM_HALF_WIDTH*2,.04,1),tint("ffae59",.42))
		core=Geo.box(tell,Vector3.ZERO,Vector3(BEAM_HALF_WIDTH*2,1.9,1),tint("ff7059",.8));core.hide()
		update_beam()
	label=Label3D.new();tell.add_child(label);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=36;label.pixel_size=.012;label.position.y=2.2
	label.modulate=Color("ffe3b0");label.text="BLAST · MOVE" if kind=="blast" else "BEAM · AIMING"
	for mesh in tell.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	enemy.state="windup";enemy.timer=WINDUP

func update_beam():
	var origin=enemy.position+Vector3.UP*1.05
	var hit=enemy.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*BEAM_LENGTH,1))
	beam_length=BEAM_LENGTH if hit.is_empty() else origin.distance_to(hit.position)
	tell.global_position=enemy.position+Vector3.UP*.1
	tell.rotation.y=atan2(-direction.x,-direction.z)
	fill.scale.z=beam_length;fill.position.z=-beam_length*.5
	core.scale.z=beam_length;core.position=Vector3(0,.95,-beam_length*.5)
	enemy.model.rotation.y=tell.rotation.y

func blast_contact():
	var hero=enemy.game.player
	var offset=hero.position-target
	if absf(offset.y)<2.4 and Vector2(offset.x,offset.z).length()<BLAST_RADIUS+.35 and clear_sight(target+Vector3.UP,hero.position+Vector3.UP):
		hero.take_hit(28,(hero.position-enemy.position).normalized())
	enemy.game.sound("heavy_swing",.6,true)
	enemy.game.burst(target+Vector3.UP*.3,Color("ff9b5f"),18,1.5)

func beam_contact():
	var hero=enemy.game.player
	var origin=enemy.position+Vector3.UP*1.05
	var point=hero.position+Vector3.UP*.95
	var nearest=Geometry3D.get_closest_point_to_segment(point,origin,origin+direction*beam_length)
	if point.distance_to(nearest)<BEAM_HALF_WIDTH+.38 and clear_sight(origin,point):hero.take_hit(12,direction)

func tick(delta: float)->bool:
	if enemy.dead or enemy.frozen_left>0:
		if active:cancel()
		return false
	if not active:
		recovery-=delta
		if recovery>0 or not can_start():return false
		begin(next_kind);next_kind="beam" if kind=="blast" else "blast"
	var offset=enemy.game.player.position-enemy.position
	if absf(offset.y)>18 or offset.length()>48:
		cancel();return false
	elapsed+=delta;enemy.velocity.x=0;enemy.velocity.z=0
	if phase=="warning":
		enemy.state="windup";enemy.timer=maxf(0,WINDUP-elapsed)
		if kind=="blast":
			core.scale=Vector3.ONE;var fraction=clampf(elapsed/WINDUP,.04,1)
			core.scale=Vector3(fraction,1,fraction)
		else:
			# Track only for the first .65 s; the final .55 s gives a clear dodge.
			if elapsed<.65:
				direction=enemy.game.player.position-enemy.position;direction.y=0;direction=direction.normalized()
			label.text="BEAM · LOCKED" if elapsed>=.65 else "BEAM · AIMING"
			update_beam()
		if elapsed>=WINDUP:
			phase="impact";elapsed=0;label.text="BLAST" if kind=="blast" else "CHANNEL · DODGE"
			if kind=="blast":blast_contact()
			else:core.show();enemy.game.sound("heavy_swing",.5,true)
	else:
		enemy.state="strike";enemy.timer=.2
		if kind=="beam":
			update_beam();pulse_clock-=delta
			if pulse_clock<=0:beam_contact();pulse_clock=.3
		else:core.scale=Vector3(1,1+elapsed*35,1)
		if elapsed>=(CHANNEL_TIME if kind=="beam" else .28):
			cancel();enemy.state="recover";enemy.timer=.65;enemy.cooldown=1.0
	return true
