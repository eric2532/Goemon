extends Ninja
var forest_id=-1
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var fitted_shapes: Array=[]
var fitted_pose: Dictionary={}
func _ready():
	super._ready()
	for child in get_children():
		if child is CollisionShape3D:remove_child(child);child.queue_free()
	for item in Contact.shapes(variant):
		var collision=CollisionShape3D.new();collision.shape=item.shape
		if item.group=="capsule":collision.position=item.center
		add_child(collision);fitted_shapes.append({"node":collision,"item":item})
	body_radius=0.0 # Fitted queries already include the full body extent.
	max_hp=Roles.stats(variant).hp;hp=max_hp
	if game.model.enemies.has(forest_id):max_hp=game.model.enemies[forest_id].max_hp;hp=game.model.enemies[forest_id].hp
	bar.mesh=bar.mesh.duplicate()
	bar.mesh.size=Vector3(4.5,.24,.08) if variant==2 else Vector3(1.8,.12,.08)
	bar.material_override=bar.material_override.duplicate()
	bar.material_override.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	bar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if is_instance_valid(name_tag):name_tag.hide()
	_sync_fitted_pose()
func _combat_data()->Dictionary:
	if not fitted_pose.is_empty():return fitted_pose
	return {"variant":variant,"pos":global_position,"facing":rotation.y}
func _sync_fitted_pose():
	var data: Dictionary=game.model.enemies.get(forest_id,{})
	if data.is_empty():return
	fitted_pose=data.duplicate()
	fitted_pose.pos=global_position;fitted_pose.facing=data.get("facing",0.0)
	rotation.y=fitted_pose.facing;model.rotation.y=0
	for entry in fitted_shapes:
		var item: Dictionary=entry.item
		entry.node.transform=Contact.part_pose(item.group,fitted_pose)
		if item.group=="capsule":entry.node.transform=entry.node.transform*Transform3D(Basis.IDENTITY,item.center)
	bar.hide()
func combat_aim_point(from: Vector3)->Vector3:return combat_contact_point(from)
func combat_contact_point(point: Vector3)->Vector3:return Contact.contact(_combat_data(),point)
func combat_segment_contact(from: Vector3,to: Vector3,radius: float)->Dictionary:return Contact.segment_contact(_combat_data(),from,to,radius)
func combat_segment_hit(from: Vector3,to: Vector3,radius: float)->bool:return not combat_segment_contact(from,to,radius).is_empty()
func combat_bounds()->AABB:return Contact.bounds(_combat_data())
func combat_knockback(direction: Vector3,strength: float,flinch: float):
	if dead or not game.model.enemies.has(forest_id):return
	var data: Dictionary=game.model.enemies[forest_id]
	data.knockback=Vector3(direction.x,0,direction.z)*strength*(.1 if variant==2 else 1.0)
	if variant!=2:data.stun=maxf(data.stun,flinch)

func _physics_process(delta):
	if game.paused:return
	if dead:
		death_timer-=delta
		if death_timer<=0:queue_free()
		return
	if not game.model.enemies.has(forest_id):queue_free();return
	var data: Dictionary=game.model.enemies[forest_id]
	global_position=data.pos;velocity=data.velocity
	_sync_fitted_pose()
	stun=data.stun;frozen_left=data.get("frozen",0.0)
	if frozen_left<=0 and is_instance_valid(frozen_visual):frozen_visual.hide()
	impact_pause=maxf(0,impact_pause-delta);recoil_age+=delta;pulse+=delta
	state=str(data.get("action","windup" if data.attack else "chase"));timer=float(data.get("action_left",.22 if data.attack else 0.0))
	if not data.has("facing") and velocity.length_squared()>.01:model.rotation.y=atan2(velocity.x,velocity.z)
	if data.hp<hp:
		var direction: Vector3=data.get("tower_direction",Vector3.UP)
		take_hit(hp-data.hp,direction,false,{"tower":true,"tower_feedback":game.model.visible_at(data.pos),"authoritative_sync":true})
		data.erase("tower_direction")
		data.stun=maxf(data.stun,stun)
		data.knockback=Vector3(velocity.x,0,velocity.z)
	bar.scale.x=maxf(.01,hp/max_hp)
func take_hit(damage: float,dir: Vector3,heavy: bool,ticket: Dictionary={}):
	if dead or damage<=0:return
	# Tower HP is already authoritative; direct hero hits first inherit that HP.
	if not ticket.get("authoritative_sync",false) and game.model.enemies.has(forest_id):hp=game.model.enemies[forest_id].hp
	var prior_state=state;var prior_timer=timer
	super.take_hit(damage,dir,heavy,ticket)
	if variant==2:
		velocity=Vector3(velocity.x,0,velocity.z)*.1
		stun=0;impact_pause=0;recoil_strength=0
		state=prior_state;timer=prior_timer
	if game.model.enemies.has(forest_id):
		game.model.enemies[forest_id].hp=hp
		var data: Dictionary=game.model.enemies[forest_id]
		if variant!=2 and not dead:
			# Cancel the simulation-owned windup too: changing the proxy's state
			# alone would resume its old worker/building strike after the flinch.
			data.action="walk";data.action_left=0.0;data.attack=false;data.attack_progress=0.0
			data.strike_kind="";data.strike_id=-1;data.clock=0.0
			stun=maxf(stun,.28)
			if not ticket.get("tower",false):
				data.retaliation=4.0;data.route_obstacle=-1
				data.path=[];data.nav=-1
				if game.model.waves.valid_target("hero",0,game.player.global_position):
					game.model.waves.set_target(data,"hero",0)
				# Keep even combo finishers nearby; explicit bash/dash abilities
				# retain their separate authored impulses.
				var push=Vector3(dir.x,0,dir.z).normalized()
				velocity=push*(3.0 if heavy else 1.2)
			data.hit_recoil=.28;data.hit_direction=Vector3(dir.x,0,dir.z).normalized()
			data.hit_heavy=heavy
		data.stun=maxf(data.stun,maxf(stun,impact_pause))
		data.knockback=Vector3(velocity.x,0,velocity.z)

func apply_rogue_bash(direction: Vector3):
	if dead or not game.model.enemies.has(forest_id):return
	var data: Dictionary=game.model.enemies[forest_id]
	data.knockback=data.get("knockback",Vector3.ZERO)+Vector3(direction.x,0,direction.z)*(0.7 if variant==2 else 7.0)
	if variant!=2:data.clock=maxf(data.clock,1.2);data.stun=maxf(data.stun,.2)
func freeze_for(seconds: float):
	if not dead and game.model.enemies.has(forest_id):
		var data: Dictionary=game.model.enemies[forest_id]
		if data.get("frozen",0.0)<=0 or not data.has("frozen_pose"):
			var snapshot: Dictionary=data.duplicate();snapshot.erase("frozen_pose")
			data.frozen_pose=snapshot
	super.freeze_for(seconds)
	if not dead and game.model.enemies.has(forest_id):
		var data: Dictionary=game.model.enemies[forest_id]
		data.frozen=maxf(data.get("frozen",0.0),seconds);data.knockback=Vector3.ZERO
func apply_defense_slow(factor: float,seconds: float):
	if dead or not game.model.enemies.has(forest_id):return
	var data: Dictionary=game.model.enemies[forest_id]
	data.slow=minf(data.get("slow",1.0),clampf(factor,.1,1));data.slow_left=maxf(data.get("slow_left",0.0),seconds)
