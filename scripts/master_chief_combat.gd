extends Node
## Camera-aimed weapons against fitted enemy volumes, with swept rockets and
## world-occluded splash. All transient presentation has a fixed pool size.
const Weapons=preload("res://scripts/master_chief_weapons.gd")
const HitZones=preload("res://scripts/master_chief_hit_zones.gd")
const ImpactMaterial=preload("res://scripts/halo_impact_material.gd")
signal world_shot(slot:int,from:Vector3,to:Vector3,contact:Dictionary,tracer:bool)
const ROCKET_POOL_SIZE=6
const ROCKET_SPEED=38.0
# Retail weapons\rocket launcher\explosion: falloff .5, cutoff 2 Halo units.
# Existing asset conversion: 3.048 m/unit; arena soldiers are ~3x Chief's height.
const HALO_METRES_PER_UNIT=3.048
const ARENA_BLAST_SCALE=3.0
const BLAST_FULL_DAMAGE_RADIUS=.5*HALO_METRES_PER_UNIT*ARENA_BLAST_SCALE
const BLAST_RADIUS=2.0*HALO_METRES_PER_UNIT*ARENA_BLAST_SCALE
const PELLETS=15
const SHOTGUN_ERROR_ANGLE=.1745329201221466
const RIFLE_ROUNDS_BETWEEN_TRACERS=3
const RIFLE_ACCELERATION_TIME=1.0
const RIFLE_DECELERATION_TIME=.1
const SWORD_WINDUP=.10
const SWORD_CONTACT_END=.32
const SWORD_SWEEP_ANGLE=.62
static var native_random_directions:PackedVector3Array=PackedVector3Array()
var hero:Hero
var game:Node
var active=false
var primary_held=false
var is_firing=false
var ammo_infinite=true
var weapon_slot=1
var hit_marker_timer=0.0
var headshot_marker_timer=0.0
var shots_fired=0
var cooldown=0.0
var last_hit_point=Vector3.ZERO
var native_fx:Node3D
var rifle_rate_of_fire=0.0
var rifle_non_tracer_rounds=0
var rifle_resting=true
var rockets:Array[Dictionary]=[]
var rocket_cursor=0
var weapon_cooldowns=[0.0,0.0,0.0,0.0,0.0]
var sword_swing:Dictionary={}

func _ready():
	native_fx=load("res://scripts/halo_weapon_effects.gd").new()
	native_fx.game=game;native_fx.hero=hero;add_child(native_fx)
	for i in ROCKET_POOL_SIZE:
		var visual=preload("res://assets/characters/master_chief/rocket_projectile.glb").instantiate()
		add_child(visual);visual.top_level=true;visual.hide()
		rockets.append({"id":i,"visual":visual,"live":false,"position":Vector3.ZERO,"direction":Vector3.FORWARD,"remaining":0.0,"ticket":{},"damage":0.0})
func _notification(what:int):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:cancel()
func input(event:InputEvent):
	release_input(event)
	if event.is_echo():return
	if event is InputEventKey and (event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed):return
	for slot in Weapons.SLOTS:
		if event.is_action_pressed(["weapon_pipe","weapon_coin","weapon_chain","scarf_toggle","gold_cloak"][slot-1]):select_slot(slot);return
	if available() and event.is_action_pressed("light_attack"):primary_held=true
func release_input(event:InputEvent):
	if event.is_action_released("light_attack"):primary_held=false;is_firing=false
func select_slot(slot:int):
	if not Weapons.SLOTS.has(slot) or not active or not hero.is_master_chief():return
	if weapon_slot==slot:return
	# Preserve each weapon's recovery time; quick switching cannot bypass cadence.
	weapon_cooldowns[weapon_slot-1]=maxf(0,cooldown)
	sword_swing.clear()
	primary_held=false;is_firing=false;weapon_slot=slot;cooldown=weapon_cooldowns[slot-1]
	native_fx.cancel_ejection()
	sync_viewmodel()
func sync_viewmodel():
	var rig=game.camera_rig
	if is_instance_valid(rig.first_person_viewmodel):rig.first_person_viewmodel.select_slot(weapon_slot)
func available()->bool:
	if not active or not is_instance_valid(hero) or not hero.is_master_chief():return false
	if not game.playing or game.paused or game.transitioning or hero.hp<=0 or get_tree().paused:return false
	if game.has_method("forest_enemy_visible") and (game.model.phase!="wave" or not game.camera_focused):return false
	return true
func tick_timers(delta:float):
	# Native trigger rate accelerates over 1s and decelerates over .1s. The
	# zero-rate state forces a tracer on the next projectile, even after input
	# returns before this frame's shot. Releasing alone does not reset the count.
	if primary_held and weapon_slot==4:
		rifle_rate_of_fire=minf(1.0,rifle_rate_of_fire+delta/RIFLE_ACCELERATION_TIME)
	else:
		rifle_rate_of_fire=maxf(0.0,rifle_rate_of_fire-delta/RIFLE_DECELERATION_TIME)
		if rifle_rate_of_fire<=.000001:rifle_resting=true
	var interval:float=Weapons.data(weapon_slot).interval
	cooldown=maxf(-interval if primary_held else 0.0,cooldown-delta)
	for i in weapon_cooldowns.size():weapon_cooldowns[i]=maxf(0,weapon_cooldowns[i]-delta)
	hit_marker_timer=maxf(0,hit_marker_timer-delta)
	headshot_marker_timer=maxf(0,headshot_marker_timer-delta)
func tick(delta:float,_after_pose:bool=false):
	if not available():cancel();return
	advance_projectiles(delta)
	advance_sword(delta)
	is_firing=primary_held or not sword_swing.is_empty()
	if primary_held and cooldown<=.000001:fire_shot()
func fire_shot():
	if not available() or cooldown>.000001:return
	var spec=Weapons.data(weapon_slot)
	cooldown+=spec.interval;weapon_cooldowns[weapon_slot-1]=cooldown;shots_fired+=1
	var rig=game.camera_rig;rig.update_camera(0);sync_viewmodel()
	var camera:Camera3D=rig.camera
	var origin=camera.global_position;var direction=-camera.global_basis.z
	var ticket=hero.attack_chain.begin(spec.key,Weapons.audio_key(weapon_slot));hero.attack_ticket=ticket
	var damage:float=spec.damage*hero.damage_multiplier()
	if weapon_slot==5:
		sword_swing={"age":0.0,"ticket":ticket.duplicate(true),"damage":damage,"hit":false}
	else:
		var muzzle=origin+camera.global_basis*Vector3(.16,-.14,-.45)
		if is_instance_valid(rig.first_person_viewmodel):muzzle=rig.first_person_viewmodel.muzzle_position()
		# The overlay can put a barrel beyond nearby geometry. Sweep from the
		# eyes before emitting anything so the muzzle cannot bypass that cover.
		var precise=weapon_slot in [2,4]
		var obstruction=trace(origin,muzzle,0,precise)
		if weapon_slot==1:
			var aim_contact=trace(origin,origin+direction*spec.range)
			var flight=(aim_contact.point-muzzle).normalized()
			if flight.is_zero_approx():flight=direction
			if obstruction.impact:
				rocket_impact(obstruction,{"direction":flight,"ticket":ticket.duplicate(true),"damage":damage})
			else:launch_rocket(muzzle,flight,ticket,damage,spec.range)
		else:fire_bullets(origin,direction,muzzle,obstruction,ticket,damage,spec,precise)
	if weapon_slot!=5 and is_instance_valid(rig.first_person_viewmodel):
		var view=rig.first_person_viewmodel
		native_fx.fire_ejection(weapon_slot,view.marker_transform("primary trigger",true),view.marker_transform("primary ejection",true),view.marker_transform.bind(true))
	rig.fire_first_person_shot();rig.add_first_person_recoil(spec.recoil)
func fire_bullets(origin:Vector3,direction:Vector3,muzzle:Vector3,obstruction:Dictionary,ticket:Dictionary,damage:float,spec:Dictionary,precise:bool):
	# Accumulate pellets per actor so one blast produces one impact/critical.
	var hits={};var head_hits={};var hit_directions={}
	var tracer=rifle_tracer() if weapon_slot==4 else true
	for i in (PELLETS if weapon_slot==3 else 1):
		var aim=direction
		if weapon_slot==3:
			aim=pellet_direction(direction)
		var contact=obstruction
		var emission=muzzle
		if obstruction.impact:emission=obstruction.point
		else:
			# Camera chooses the intended surface. The actual barrel ray owns
			# damage and effects, including off-centre cover and close targets.
			var aim_contact=trace(origin,origin+aim*spec.range,0,precise)
			var flight:Vector3=(aim_contact.point-muzzle).normalized()
			contact=trace(muzzle,aim_contact.point+flight*.02,0,precise)
		last_hit_point=contact.point
		var target=contact.target
		if is_instance_valid(target):
			var falloff=clampf(1.0-origin.distance_to(contact.point)/spec.range,.15,1.0) if weapon_slot==3 else 1.0
			hits[target]=float(hits.get(target,0.0))+damage*falloff
			hit_directions[target]=(contact.point-origin).normalized() if obstruction.impact else (contact.point-muzzle).normalized()
			if contact.headshot:head_hits[target]=true
		native_fx.fire_world(weapon_slot,emission,contact.point,contact,tracer)
		world_shot.emit(weapon_slot,emission,contact.point,contact,tracer)
	for target in hits:
		if not is_instance_valid(target) or target.dead:continue
		var hit_ticket=ticket.duplicate(true)
		var amount:float=hits[target]
		if head_hits.has(target):
			hit_ticket["headshot"]=true;headshot_marker_timer=.2
			if weapon_slot==2:hit_ticket["lethal_headshot"]=true
			elif weapon_slot==4:amount*=2.0
		target.take_hit(amount,hit_directions[target],false,hit_ticket);hit_marker_timer=.14
func advance_sword(delta:float):
	if sword_swing.is_empty():return
	var previous=float(sword_swing.age);var current=previous+maxf(0,delta)
	sword_swing.age=current
	if not sword_swing.hit and current>=SWORD_WINDUP and previous<SWORD_CONTACT_END:
		var start=maxf(previous,SWORD_WINDUP);var end=minf(current,SWORD_CONTACT_END)
		# Sample the swept arc between physics frames, including a long frame
		# that crosses the entire contact window. The first contact wins.
		var steps=maxi(1,ceili((end-start)/.015))
		var camera:Camera3D=game.camera_rig.camera
		for i in steps+1:
			var phase=(lerpf(start,end,float(i)/steps)-SWORD_WINDUP)/(SWORD_CONTACT_END-SWORD_WINDUP)
			var direction=(-camera.global_basis.z).rotated(camera.global_basis.y,lerpf(-SWORD_SWEEP_ANGLE,SWORD_SWEEP_ANGLE,phase))
			var contact=trace(camera.global_position,camera.global_position+direction*Weapons.data(5).range,.25)
			if not is_instance_valid(contact.target):continue
			# Broad blade contact expands the victim, not the wall. Verify the
			# actual fitted surface so expansion cannot reach through thin cover.
			var surface=AttackChain.contact_point(contact.target,contact.point,contact.point)
			var blocked=hero.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,surface,1,[hero.get_rid()]))
			if not blocked.is_empty():continue
			contact.target.take_hit(float(sword_swing.damage),direction,false,sword_swing.ticket)
			sword_swing.hit=true;hit_marker_timer=.16;last_hit_point=surface
			break
	if current>=SWORD_CONTACT_END:sword_swing.clear()
func pellet_direction(axis:Vector3)->Vector3:
	# Native random_math.c chooses a direction from the 16-segment geosphere,
	# crosses it with the aim axis, then samples angle uniformly (not disk area).
	if native_random_directions.is_empty():
		var vertices=[Vector3(0,0,1),Vector3(0,1,0),Vector3(1,0,0),Vector3(0,-1,0),Vector3(-1,0,0),Vector3(0,0,-1)]
		var triangles=[[0,1,2],[0,2,3],[0,3,4],[0,4,1],[5,1,4],[5,4,3],[5,3,2],[5,2,1]]
		var seen={}
		for triangle in triangles:
			var a:Vector3=vertices[triangle[0]];var b:Vector3=vertices[triangle[1]];var c:Vector3=vertices[triangle[2]]
			for row in 17:
				var left=a.lerp(c,float(row)/16).normalized();var right=a.lerp(b,float(row)/16).normalized()
				for column in row+1:
					var native=left.lerp(right,float(column)/row if row>0 else 0.0).normalized()
					var key=Vector3i(roundi(native.x*1000000),roundi(native.y*1000000),roundi(native.z*1000000))
					if seen.has(key):continue
					seen[key]=true
					native_random_directions.append(Vector3(-native.y,native.z,-native.x))
	var sample:Vector3=native_random_directions[randi_range(0,native_random_directions.size()-1)]
	var rotation_axis=axis.cross(sample)
	if rotation_axis.is_zero_approx():return axis
	return axis.rotated(rotation_axis.normalized(),randf_range(0.0,SHOTGUN_ERROR_ANGLE)).normalized()
func rifle_tracer()->bool:
	# Native C: rate==0 || sequential_non_tracer_rounds++ >= 3. It therefore
	# emits T,F,F,F,T during a held burst, rather than every third round.
	var tracer=rifle_resting or rifle_non_tracer_rounds>=RIFLE_ROUNDS_BETWEEN_TRACERS
	if tracer:rifle_non_tracer_rounds=0
	else:rifle_non_tracer_rounds+=1
	rifle_resting=false
	# The native firing tick then advances rate by its 30Hz acceleration step.
	rifle_rate_of_fire=maxf(rifle_rate_of_fire,1.0/30.0)
	return tracer
func head_contact(enemy:Ninja,from:Vector3,to:Vector3)->Dictionary:return HitZones.contact(enemy,from,to)
func trace(origin:Vector3,endpoint:Vector3,radius:float=0.0,detect_head:bool=false)->Dictionary:
	var wall=hero.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,endpoint,1,[hero.get_rid()]))
	var end:Vector3=wall.position if not wall.is_empty() else endpoint
	var target:Ninja=null;var closest=1.0;var headshot=false;var head_point=Vector3.ZERO
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
		if enemy.has_method("combat_bounds"):
			var bounds:AABB=enemy.combat_bounds().grow(radius)
			if detect_head:bounds=bounds.merge(HitZones.broad_bounds(enemy))
			if not bounds.has_point(origin) and not bounds.intersects_segment(origin,end):continue
		var contact=AttackChain.segment_contact(enemy,origin,end,radius)
		var head=head_contact(enemy,origin,end) if detect_head else {}
		if HitZones.separate_head(enemy) and not head.is_empty() and (contact.is_empty() or head.t<contact.t):contact=head
		if contact.is_empty() or contact.t>=closest:continue
		closest=contact.t;target=enemy;headshot=not head.is_empty()
		if headshot:head_point=head.point
	var hit=wall.duplicate() if target==null else {"collider":target,"rid":target.get_rid()}
	hit["point"]=head_point if headshot else (origin.lerp(end,closest) if target!=null else end)
	hit["position"]=hit.point
	hit["target"]=target;hit["headshot"]=headshot
	hit["impact"]=target!=null or not wall.is_empty()
	hit["normal"]=wall.get("normal",Vector3.ZERO) if target==null else (origin-end).normalized()
	hit["material"]=ImpactMaterial.resolve(hit,target)
	return hit
func launch_rocket(origin:Vector3,direction:Vector3,ticket:Dictionary,damage:float,distance:float):
	var item=rockets[rocket_cursor];rocket_cursor=(rocket_cursor+1)%rockets.size()
	if item.live:retire_rocket(item)
	item.live=true;item.position=origin;item.direction=direction;item.remaining=distance
	item.ticket=ticket.duplicate(true);item.damage=damage
	item.visual.global_position=origin;item.visual.look_at(origin+direction,Vector3.RIGHT if absf(direction.y)>.98 else Vector3.UP);item.visual.show()
	native_fx.rocket_start(item.id,origin,direction)
func live_rocket_count()->int:
	var count=0
	for item in rockets:
		if item.live:count+=1
	return count
func advance_projectiles(delta:float):
	for item in rockets:
		if not item.live:continue
		var distance=minf(ROCKET_SPEED*delta,item.remaining)
		var start:Vector3=item.position;var end:Vector3=start+item.direction*distance
		var contact=trace(start,end,.08)
		item.remaining-=distance;item.position=contact.point
		native_fx.rocket_move(item.id,contact.point,item.direction,delta)
		if contact.impact:
			rocket_impact(contact,item)
			retire_rocket(item)
		elif item.remaining<=0:retire_rocket(item)
		else:
			item.visual.global_position=end
func rocket_impact(contact:Dictionary,item:Dictionary):
	# Start splash on the visible side of the surface, including an obstructed
	# launch. Reuse the same response for launch clearance and in-flight sweeps.
	var center:Vector3=contact.point+contact.normal*.06-item.direction*.03
	explode(center,contact.target,item,contact.normal,contact.material)
func retire_rocket(item:Dictionary):
	item.live=false;item.ticket={};item.visual.hide()
	native_fx.rocket_stop(item.id)
func explode(center:Vector3,direct:Node,item:Dictionary,normal:Vector3=Vector3.UP,material:String="stone"):
	last_hit_point=center
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
		var bounds:AABB=enemy.combat_bounds()
		var nearest=center.clamp(bounds.position,bounds.end)
		var distance=center.distance_to(nearest)
		if enemy!=direct and distance>BLAST_RADIUS:continue
		var aim=bounds.get_center()
		var blocked=hero.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center,aim,1,[hero.get_rid()]))
		if enemy!=direct and not blocked.is_empty():continue
		var falloff=1.0 if enemy==direct else clampf((BLAST_RADIUS-distance)/(BLAST_RADIUS-BLAST_FULL_DAMAGE_RADIUS),0,1)
		if falloff<=0:continue
		var direction=(aim-center).normalized()
		if direction.is_zero_approx():direction=item.direction
		enemy.take_hit(item.damage*falloff,direction,true,item.ticket);hit_marker_timer=.2
	native_fx.explosion(center,normal,material,ARENA_BLAST_SCALE)
func primary_attack():
	if available():fire_shot()
func is_attacking()->bool:return is_firing
func blocks_movement()->bool:return false
func protects_player()->bool:return false
func cancel(_preserve_power:bool=false):
	sword_swing.clear()
	primary_held=false;is_firing=false;hit_marker_timer=0;headshot_marker_timer=0
	# Keep recovery clocks when focus/menu interruption cancels input.
	for item in rockets:retire_rocket(item)
	if is_instance_valid(native_fx):native_fx.clear()
	var rig=game.get("camera_rig") if is_instance_valid(game) else null
	if is_instance_valid(rig) and is_instance_valid(rig.first_person_viewmodel):rig.first_person_viewmodel.stop()
func hit():
	if not available():cancel()
func interrupt_for_dodge():cancel()
