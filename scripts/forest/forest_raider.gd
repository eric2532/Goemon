extends Ninja
var forest_id=-1
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const SoldierCombat=preload("res://scripts/forest/forest_thirstquencher_combat.gd")
const SoldierAudio=preload("res://scripts/forest/forest_soldier_audio.gd")
var soldier_corpse_velocity=Vector3.ZERO
var soldier_corpse_pitch=0.0
var fitted_shapes: Array=[]
var fitted_pose: Dictionary={}
var fitted_contact: Dictionary={}
var fitted_block_contacts=false
var fitted_tick_serial: Variant=null
var fitted_pose_dirty=true
var fitted_physics_frame=-1
var last_physics_frame=-1
var formation_step=0.0
var boss_health_display: Node3D
var boss_health_text: Label3D
func _ready():
	# The shared base has four legacy visual variants. The fifth Forest role
	# uses its own fitted block, and must not index the base's four-entry arrays.
	var forest_variant=variant
	if forest_variant==Roles.BOSS:variant=0
	super._ready()
	# The model owns navigation and wall contacts. Keep layer 4 for native hit
	# queries without generating unused kinematic-versus-scenery contact pairs.
	collision_mask=0
	variant=forest_variant
	if Soldier.supports(variant):SoldierAudio.ensure(game)
	for child in get_children():
		if child is CollisionShape3D:remove_child(child);child.queue_free()
	_refresh_fitted_shapes(_uses_block_contacts())
	body_radius=0.0 # Fitted queries already include the full body extent.
	max_hp=Roles.stats(variant).hp;hp=max_hp
	if game.model.enemies.has(forest_id):max_hp=game.model.enemies[forest_id].max_hp;hp=game.model.enemies[forest_id].hp
	bar.mesh=bar.mesh.duplicate()
	bar.mesh.size=Vector3(4.5,.24,.08) if variant==2 else Vector3(1.8,.12,.08)
	bar.material_override=bar.material_override.duplicate()
	bar.material_override.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	bar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if variant==Roles.BOSS:_create_boss_health_bar()
	if is_instance_valid(name_tag):name_tag.hide()
	_sync_fitted_pose()
func _combat_data()->Dictionary:
	if not fitted_pose.is_empty():return fitted_pose
	return {"variant":variant,"pos":global_position,"facing":rotation.y,"block_contacts":_uses_block_contacts()}
func _uses_block_contacts()->bool:
	return is_instance_valid(game.crowd) and game.crowd.low_fidelity
func _refresh_fitted_shapes(blocks: bool,items: Array=[]):
	if items.is_empty():items=Contact.shapes(variant,blocks)
	if blocks==fitted_block_contacts and fitted_shapes.size()==items.size():return
	for entry in fitted_shapes:
		remove_child(entry.node);entry.node.queue_free()
	fitted_shapes.clear();fitted_block_contacts=blocks
	for item in items:
		var collision=CollisionShape3D.new();collision.shape=item.shape
		collision.set_meta("fitted_contact_index",fitted_shapes.size())
		add_child(collision);fitted_shapes.append({"node":collision,"item":item})
func _fitted_pose_needs_sync()->bool:
	var serial=_simulation_snapshot_serial()
	return serial==null or fitted_pose_dirty or fitted_tick_serial!=serial or fitted_block_contacts!=_uses_block_contacts()
func _simulation_snapshot_serial()->Variant:
	var serial=game.get("model_tick_serial")
	if serial==null:return null
	var data:Dictionary=game.model.enemies.get(forest_id,{})
	# A global revision still serves legacy/synchronous callers. Sliced updates
	# invalidate only their own actors, keeping the rest of the crowd's contacts.
	if data.has("simulation_revision"):return Vector2i(1,int(data.simulation_revision))
	return Vector2i(0,int(serial))
func _sync_fitted_pose():
	var data: Dictionary=game.model.enemies.get(forest_id,{})
	if data.is_empty():return
	var elapsed=formation_step;formation_step=0.0
	# Physics owns the live formation; rendering consumes this same snapshot.
	data.block_contacts=_uses_block_contacts()
	data.erase("shared_contacts")
	fitted_pose=data.duplicate()
	fitted_pose.pos=global_position;fitted_pose.facing=data.get("facing",0.0)
	rotation.y=fitted_pose.facing;model.rotation.y=0
	if data.block_contacts and game.forest_enemy_visible(self):
		game.crowd.primitive_formation(self,data,elapsed,0.0)
		return
	fitted_contact=Contact.prepare(fitted_pose)
	_apply_fitted_contact(data.block_contacts)

func sync_formation_contacts(formation:Dictionary,data:Dictionary):
	if dead or not _uses_block_contacts():return
	formation_step=0.0
	fitted_pose=data.duplicate();fitted_pose.erase("shared_contacts")
	fitted_pose.pos=global_position;fitted_pose.facing=data.get("facing",0.0)
	rotation.y=fitted_pose.facing;model.rotation.y=0
	fitted_contact=Contact.prepare(fitted_pose,formation)
	fitted_contact.formation_contacts=true
	formation.contact_poses=fitted_contact.render_poses
	data.shared_contacts=fitted_contact
	fitted_pose.shared_contacts=fitted_contact
	_apply_fitted_contact(true)

func clear_formation_contacts():
	var data:Dictionary=game.model.enemies.get(forest_id,{})
	if not data.has("shared_contacts"):return
	data.erase("shared_contacts");fitted_pose_dirty=true
	_sync_fitted_pose()

func _apply_fitted_contact(blocks:bool):
	_refresh_fitted_shapes(blocks,fitted_contact.shapes)
	fitted_tick_serial=_simulation_snapshot_serial();fitted_pose_dirty=false
	fitted_physics_frame=Engine.get_physics_frames()
	for i in range(fitted_shapes.size()):
		var entry: Dictionary=fitted_shapes[i]
		entry.member=fitted_contact.members[i]
		var item: Dictionary=entry.item
		var pose:Transform3D=fitted_contact.local_poses[i]
		if item.get("box",false) or item.group=="capsule":pose=pose*Transform3D(Basis.IDENTITY,item.center)
		entry.node.transform=pose
	_update_health_bar()
func can_reuse_formation()->bool:
	var frame=Engine.get_physics_frames()
	return is_physics_processing() and has_shared_combat_contacts() and (fitted_physics_frame==frame or last_physics_frame==frame) and not _fitted_pose_needs_sync()
func _create_boss_health_bar():
	boss_health_display=Node3D.new();boss_health_display.name="BossHealthDisplay";add_child(boss_health_display)
	boss_health_display.position.y=Roles.height(variant)+1.1
	bar.reparent(boss_health_display,false);bar.position=Vector3.ZERO;bar.mesh.size=Vector3(8,.36,.08)
	bar.material_override.billboard_mode=BaseMaterial3D.BILLBOARD_DISABLED
	bar.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	bar.material_override.albedo_color=Color("f2cf75");bar.material_override.emission_enabled=false
	var backing=MeshInstance3D.new();backing.name="BossHealthBacking";backing.mesh=BoxMesh.new();backing.mesh.size=Vector3(8.4,.65,.08);backing.position.z=-.1
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("142b2b");backing.material_override=material
	backing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;boss_health_display.add_child(backing)
	boss_health_text=Label3D.new();boss_health_text.name="BossHealthText";boss_health_text.position=Vector3(0,.7,.03)
	boss_health_text.font_size=40;boss_health_text.pixel_size=.012;boss_health_text.outline_size=7;boss_health_text.modulate=Color("fff0c7");boss_health_text.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	boss_health_display.add_child(boss_health_text)
func _update_health_bar():
	if variant!=Roles.BOSS:bar.hide();return
	var shown=not dead and hp>0 and game.playing and game.model.phase=="wave"
	bar.visible=shown;boss_health_display.visible=shown;boss_health_text.visible=shown
	if not shown:return
	# Face the whole display once, so its fill stays anchored on the left when
	# either the boss or camera turns. Ordinary enemies never run this work.
	if is_instance_valid(game.camera_rig):boss_health_display.global_basis=game.camera_rig.camera.global_basis.orthonormalized()
	var fraction=clampf(hp/maxf(1,max_hp),0,1)
	bar.scale.x=maxf(.001,fraction);bar.position.x=-4*(1-fraction)
	boss_health_text.text="BOSS  %d / %d"%[ceili(hp),ceili(max_hp)]
func combat_aim_point(from: Vector3)->Vector3:return combat_contact_point(from)
func combat_contact_point(point: Vector3)->Vector3:return Contact.contact(_combat_data(),point,fitted_contact)
func has_shared_combat_contacts()->bool:return fitted_contact.get("formation_contacts",false)
func combat_contact_candidates(point:Vector3)->PackedVector3Array:
	var result=PackedVector3Array()
	if not has_shared_combat_contacts():return result
	for index in range(fitted_contact.shapes.size()):result.append(Contact.contact(_combat_data(),point,fitted_contact,index))
	return result
func combat_physics_contact(shape_id:int,point:Vector3)->Vector3:
	var owner=shape_owner_get_owner(shape_find_owner(shape_id))
	var index=int(owner.get_meta("fitted_contact_index",-1)) if is_instance_valid(owner) else -1
	return Contact.contact(_combat_data(),point,fitted_contact,index)
func combat_segment_contact(from: Vector3,to: Vector3,radius: float)->Dictionary:return Contact.segment_contact(_combat_data(),from,to,radius,fitted_contact)
func combat_segment_hit(from: Vector3,to: Vector3,radius: float)->bool:return not combat_segment_contact(from,to,radius).is_empty()
func combat_bounds()->AABB:return Contact.bounds(_combat_data(),fitted_contact)
func combat_knockback(direction: Vector3,strength: float,flinch: float):
	if dead or not game.model.enemies.has(forest_id):return
	fitted_pose_dirty=true
	var data: Dictionary=game.model.enemies[forest_id]
	if variant==Roles.BOSS:data.knockback=Vector3.ZERO;return
	data.knockback=Vector3(direction.x,0,direction.z)*strength*(.1 if variant in [2,Roles.BOSS] else 1.0)
	if variant not in [2,Roles.BOSS]:data.stun=maxf(data.stun,flinch)

func _physics_process(delta):
	if game.paused:return
	if dead:
		if Soldier.supports(variant):_soldier_corpse_step(delta)
		death_timer-=delta
		if death_timer<=0:queue_free()
		return
	if not game.model.enemies.has(forest_id):queue_free();return
	var data: Dictionary=game.model.enemies[forest_id]
	last_physics_frame=Engine.get_physics_frames();formation_step+=delta
	# Heavy crowds already advance the shared world at a reduced rate. Keep its enemy
	# presentation on that cadence rather than rebuilding unchanged contacts
	# between steps; input, native ally attacks and projectiles still run at 60Hz.
	var animate_formation=game.world_update_interval()<=0 and _uses_block_contacts() and game.forest_enemy_visible(self) and fitted_physics_frame!=last_physics_frame
	if _fitted_pose_needs_sync() or animate_formation:
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
	_update_health_bar()
func take_hit(damage: float,dir: Vector3,heavy: bool,ticket: Dictionary={}):
	if dead or damage<=0:return
	fitted_pose_dirty=true
	# Tower HP is already authoritative; direct hero hits first inherit that HP.
	if not ticket.get("authoritative_sync",false) and game.model.enemies.has(forest_id):hp=game.model.enemies[forest_id].hp
	var prior_state=state;var prior_timer=timer
	super.take_hit(damage,dir,heavy,ticket)
	if variant in [2,Roles.BOSS]:
		# Movement impulses short-circuit the authoritative attack tick. Bosses
		# therefore need zero impulse, not a tiny push refreshed by every arrow.
		velocity=Vector3.ZERO if variant==Roles.BOSS else Vector3(velocity.x,0,velocity.z)*.1
		stun=0;impact_pause=0;recoil_strength=0
		state=prior_state;timer=prior_timer
	if game.model.enemies.has(forest_id):
		game.model.enemies[forest_id].hp=hp
		var data: Dictionary=game.model.enemies[forest_id]
		if hp<=0:game.model.ryo.award_enemy_bounty(data)
		if Soldier.supports(variant):
			SoldierCombat.cancel(data)
			if not dead:
				data.soldier_hurt_clip="Source__801b02a8";data.soldier_hurt_tick=0.0;data.soldier_hurt_left=16.0/30
				stun=maxf(stun,data.soldier_hurt_left)
			else:
				SoldierAudio.soldier_died(game,global_position,variant)
				global_position.y+=36*.01*Soldier.SCALE
				soldier_corpse_velocity=(Vector3.UP*4.8+Basis(Vector3.UP,float(data.facing))*Vector3.BACK*2.4)*Soldier.SCALE
				soldier_corpse_pitch=deg_to_rad(67.5);death_timer=.8
		if variant not in [2,Roles.BOSS] and not dead:
			# Cancel the simulation-owned windup too: changing the proxy's state
			# alone would resume its old worker/building strike after the flinch.
			data.action="walk";data.action_left=0.0;data.attack=false;data.attack_progress=0.0
			data.strike_kind="";data.strike_id=-1;data.clock=0.0
			stun=maxf(stun,.28)
			if not ticket.get("tower",false):
				data.retaliation=4.0;data.route_obstacle=-1
				data.path=[];data.nav=-1
				var source_ref=ticket.get("source_hero")
				var source=source_ref.get_ref() if source_ref is WeakRef else null
				if is_instance_valid(source) and source.ai_controlled and game.model.defenders.has(source.get("gate_id")):
					data.retaliation_defender=source.gate_id
					game.model.waves.set_target(data,"defender",source.gate_id)
				else:
					data.erase("retaliation_defender")
					if game.model.waves.valid_target("hero",0,game.player.global_position):game.model.waves.set_target(data,"hero",0)
				# Keep even combo finishers nearby; explicit bash/dash abilities
				# retain their separate authored impulses.
				var push=Vector3(dir.x,0,dir.z).normalized()
				velocity=push*(3.0 if heavy else 1.2)
			data.hit_recoil=.28;data.hit_direction=Vector3(dir.x,0,dir.z).normalized()
			data.hit_heavy=heavy
		data.stun=maxf(data.stun,maxf(stun,impact_pause))
		data.knockback=Vector3(velocity.x,0,velocity.z)
	_update_health_bar()

func apply_rogue_bash(direction: Vector3):
	if dead or not game.model.enemies.has(forest_id):return
	fitted_pose_dirty=true
	var data: Dictionary=game.model.enemies[forest_id]
	if variant==Roles.BOSS:data.knockback=Vector3.ZERO;return
	data.knockback=data.get("knockback",Vector3.ZERO)+Vector3(direction.x,0,direction.z)*(0.7 if variant in [2,Roles.BOSS] else 7.0)
	if variant not in [2,Roles.BOSS]:data.clock=maxf(data.clock,1.2);data.stun=maxf(data.stun,.2)
func freeze_for(seconds: float):
	if not dead and game.model.enemies.has(forest_id):
		fitted_pose_dirty=true
		var data: Dictionary=game.model.enemies[forest_id]
		if data.get("frozen",0.0)<=0 or not data.has("frozen_pose"):
			var snapshot: Dictionary=data.duplicate();snapshot.erase("frozen_pose");snapshot.erase("shared_contacts")
			data.frozen_pose=snapshot
	super.freeze_for(seconds)
	if not dead and game.model.enemies.has(forest_id):
		var data: Dictionary=game.model.enemies[forest_id]
		data.frozen=maxf(data.get("frozen",0.0),seconds);data.knockback=Vector3.ZERO
func apply_defense_slow(factor: float,seconds: float):
	if dead or not game.model.enemies.has(forest_id):return
	fitted_pose_dirty=true
	var data: Dictionary=game.model.enemies[forest_id]
	data.slow=minf(data.get("slow",1.0),clampf(factor,.1,1));data.slow_left=maxf(data.get("slow_left",0.0),seconds)

func _soldier_corpse_step(delta:float):
	# Source root dynamics accompany the recovered twelve-frame death pose.
	# The world remains the movement authority; corpses cannot cross walls or
	# appear below the native hill/bridge surface while tumbling backward.
	var before=global_position;var next=before+soldier_corpse_velocity*delta
	var nav=game.model.waves.navigation
	if not nav.move_clear(Vector3(next.x,game.model.surface_height(next.x,next.z),next.z),Roles.footprint_radius(variant)):
		next.x=before.x;next.z=before.z;soldier_corpse_velocity.x=0;soldier_corpse_velocity.z=0
	soldier_corpse_velocity.y-=13.5*Soldier.SCALE*delta
	var floor_y:float=game.model.surface_height(next.x,next.z)
	if next.y<floor_y:next.y=floor_y;soldier_corpse_velocity=Vector3.ZERO
	global_position=next;soldier_corpse_pitch-=deg_to_rad(22.5)*30*delta
