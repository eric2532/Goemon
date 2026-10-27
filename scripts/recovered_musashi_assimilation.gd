extends Node3D
## Retail MAIN32/33/38/39/40 body events and30Hz projectile travel.
## Terrain, local targeting and damage use the host game's fitted combat system.
const SKILL_SCALE=preload("res://scripts/weapon_proportions.gd").RECOVERED_SKILL_SCALE
const ASSETS="res://assets/characters/recovered_musashi/assimilation/"
const MODELS={"three_way":preload(ASSETS+"three_way.glb"),"homing":preload(ASSETS+"homing.glb"),"grenade":preload(ASSETS+"grenade.glb"),"dkick":preload(ASSETS+"dkick.glb")}
const NAMES={3:"dkick",4:"fence",5:"homing",6:"grenade",7:"three_way"}
const DAMAGE={"dkick":26.0,"fence":30.0,"homing":42.0,"grenade":60.0,"three_way":12.0}
const SOUNDS={"fence":"musashi_fence","homing":"musashi_homing","grenade":"musashi_grenade","three_way":"musashi_three_way"}
static var source:Dictionary={}
var combat
var hero:Hero
var game:Node
var held=false
var phase=""
var ticks=0
var clock=0.0
var projectile_clock=0.0
var kick_vertical=-12
var shots:Array=[]
var ghosts:Array[Node3D]=[]
var ghost_index=0
var releases=0
var impacts=0
var peak_active=0

func _ready():
	set_physics_process(false)
	top_level=true;global_transform=Transform3D.IDENTITY
	if source.is_empty():source=JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"sources.json"))
	# Full held-fire occupancy:3 shots every4 ticks, alive16 ticks. Six rockets
	# matches the original limiter; other pools cover every legal cast overlap.
	for kind in ["fence","homing","grenade","three_way"]:
		for i in {"fence":8,"homing":6,"grenade":12,"three_way":18}[kind]:
			var node=Node3D.new();add_child(node)
			var visual:Node3D
			if kind=="fence":
				var quad=QuadMesh.new();quad.size=Vector2(62,30)
				var mat=StandardMaterial3D.new();mat.albedo_texture=preload(ASSETS+"fence.png");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
				quad.material=mat;visual=MeshInstance3D.new();visual.mesh=quad
			else:visual=MODELS[kind].instantiate()
			node.add_child(visual)
			var puff=MeshInstance3D.new();var puff_mesh=QuadMesh.new();puff_mesh.size=Vector2(32,32)
			var puff_mat=StandardMaterial3D.new();puff_mat.albedo_texture=preload(ASSETS+"explosion.png");puff_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			puff_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;puff_mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;puff_mat.cull_mode=BaseMaterial3D.CULL_DISABLED;puff_mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
			puff_mat.uv1_scale=Vector3(1,.1,1);puff_mesh.material=puff_mat;puff.mesh=puff_mesh;node.add_child(puff);puff.hide();node.hide()
			var plumes=[]
			if kind in ["homing","grenade"]:
				for plume in (4 if kind=="homing" else 6):
					var instance=MeshInstance3D.new();instance.mesh=puff_mesh;puff.add_child(instance);plumes.append(instance)
			var trails=[]
			if kind=="homing":
				for trail in 6:
					var instance=MeshInstance3D.new();instance.mesh=puff_mesh
					var material=puff_mat.duplicate();material.albedo_texture=preload(ASSETS+"rocket_trail.png");instance.material_override=material
					node.add_child(instance);instance.top_level=true;instance.hide();trails.append({"node":instance,"age":-1})
			shots.append({"kind":kind,"node":node,"visual":visual,"puff":puff,"puff_material":puff_mat,"plumes":plumes,"trails":trails,"active":false,"target":null,"ticket":{},"hits":{},"age":0,"blast":-1,"velocity":Vector3.ZERO,"unit":1.0,"effect_unit":1.0,"damage":0.0,"bounces":2})
	for i in 4:
		var ghost=MODELS.dkick.instantiate();add_child(ghost);ghost.hide();ghosts.append(ghost)
	# Resolve audio resources at selection/setup, before a shot can release.
	for slot in SOUNDS.values()+["musashi_dkick_hit","musashi_fence_hit","musashi_homing_hit","musashi_grenade_hit"]:
		preload("res://scripts/recovered_musashi_audio.gd").stream_for(slot)

func start(number:int):
	if not NAMES.has(number):return
	if not hero.is_on_floor() and number!=3:return
	if number==5 and active_count("homing")>=6:return
	held=number==7;combat.mode="assimilation";combat.action_key=NAMES[number]
	combat.guard_held=false;combat.special_held=false;combat.charge=0;combat.charge_clock=0
	combat.queued_primary=false;combat.queued_heavy=false;combat.contact_time=0;combat.contact_end=0
	hero.facing=hero.combat_attack_direction();combat.cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
	hero.attack_heavy=false;hero.attack_charged=false;hero.struck_targets.clear()
	hero.attack_ticket=hero.attack_chain.begin("musashi_"+combat.action_key)
	kick_vertical=-12;clock=0
	_set_phase("three_raise" if number==7 else ("throw" if number in [5,6] else NAMES[number]))
	if number==3:combat.locomotion.discard_jump_input()

func _set_phase(value:String):
	phase=value;ticks=0;combat.elapsed=0;combat.clip="assimilation/"+phase
	hero.attack_duration=float(source.clips[phase].ticks)/30.0;hero.attack_left=hero.attack_duration

func tick(delta:float):
	if combat.action_key=="dkick":return # Locomotion owns its source clock.
	clock+=delta*30
	while clock+.000001>=1 and combat.mode=="assimilation":
		clock-=1;_body_tick()

func _body_tick():
	ticks+=1;combat.elapsed=ticks/30.0;hero.attack_left=maxf(.000001,hero.attack_duration-combat.elapsed)
	if phase=="three_fire":
		hero.facing=hero.combat_attack_direction();combat.cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
	if ticks==2 and phase in ["fence","three_fire"]:release_shot(combat.action_key)
	if ticks==5 and phase=="throw":release_shot(combat.action_key)
	if ticks<int(source.clips[phase].ticks):return
	if phase=="three_raise":_set_phase("three_fire")
	elif phase=="three_fire":_set_phase("three_fire" if held else "three_lower")
	else:finish()

func motion_tick()->Vector3:
	ticks+=1;combat.elapsed=ticks/30.0;hero.attack_left=.001
	if kick_vertical<31:kick_vertical+=2
	var unit=combat.locomotion.source_world_scale()
	var effect_unit=combat.cast_model().rig_visual.global_basis.get_scale().x*.01*SKILL_SCALE*hero.skill_factor(hero.attack_ticket,"hit_area")
	var from=hero.global_position+Vector3.UP*24*effect_unit/SKILL_SCALE
	var to=from+hero.facing*18*effect_unit
	for enemy in AttackChain.segment_enemy_candidates(game,from,to,16*effect_unit):
		if ticks%4==3:continue # Source opcode20 closes contact on the fourth pose.
		if not is_instance_valid(enemy) or enemy.dead or hero.struck_targets.has(enemy.get_instance_id()):continue
		var hit=AttackChain.segment_contact(enemy,from,to,16*effect_unit)
		if hit.is_empty() or not _clear(from,hit.point):continue
		hero.struck_targets[enemy.get_instance_id()]=true
		_hit(enemy,hit.point,hero.facing,DAMAGE.dkick*hero.damage_multiplier(),hero.attack_ticket)
		game.sound("musashi_dkick_hit",.7,false,hero.attack_ticket,13)
	if ticks%2==0:
		var ghost=ghosts[ghost_index];ghost_index=(ghost_index+1)%ghosts.size()
		ghost.global_transform=Transform3D(Basis(Vector3.UP,atan2(-hero.facing.x,-hero.facing.z)).scaled(Vector3.ONE*effect_unit),hero.global_position)
		ghost.set_meta("ticks",4);ghost.show()
		set_physics_process(true)
	return (hero.facing*18+Vector3.UP*(-kick_vertical))*unit*30*hero.skill_factor(hero.attack_ticket,"travel_speed")

func finish():
	combat.clip="";combat.mode="";combat.action_key="";hero.attack_left=0;held=false;phase="";clock=0
	for ghost in ghosts:ghost.hide()
	if combat.queued_heavy:combat.queued_heavy=false;combat.start_attack(true)
	elif combat.queued_primary or (combat.spell_owner==null and hero.auto_attack_running()):combat.queued_primary=false;combat.primary_attack()

func cancel():
	held=false;phase="";ticks=0;clock=0
	for ghost in ghosts:ghost.hide()

func active_count(kind:String="")->int:
	var count=0
	for shot in shots:
		if shot.active and (kind.is_empty() or shot.kind==kind):count+=1
	return count

func release_shot(kind:String):
	set_physics_process(true)
	var variants=[-1,0,1] if kind=="three_way" else [0]
	for variant in variants:
		var shot=preload("res://scripts/character_projectile_pool.gd").free_slot(shots,"active",kind)
		assert(not shot.is_empty(),"Musashi source occupancy exceeded its prepared projectile pool")
		if shot.is_empty():continue
		var unit=combat.locomotion.source_world_scale()*hero.growth_multiplier()
		var direction=hero.facing.rotated(Vector3.UP,float(variant)*0xAA*TAU/4096.0)
		shot.active=true;shot.age=0;shot.blast=-1;shot.target=null;shot.hits.clear();shot.ticket=hero.attack_ticket.duplicate();shot.unit=unit;shot.effect_unit=combat.cast_model().rig_visual.global_basis.get_scale().x*.01*SKILL_SCALE;shot.bounces=2
		for plume in shot.plumes:plume.position=Vector3.ZERO
		for trail in shot.trails:trail.age=-1;trail.node.hide()
		shot.damage=DAMAGE[kind]*hero.damage_multiplier()
		shot.velocity=direction*(64 if kind=="three_way" else 16)*unit*hero.skill_factor(shot.ticket,"travel_speed")
		if kind=="grenade":shot.velocity.y=12*unit
		shot.node.global_transform=Transform3D.IDENTITY
		shot.node.global_position=hero.global_position+Vector3.UP*(24 if kind in ["fence","three_way"] else 64)*unit
		if kind=="three_way":shot.node.position+=hero.facing*15*unit
		shot.visual.show();shot.puff.hide();shot.visual.scale=Vector3.ONE*shot.effect_unit*hero.skill_factor(shot.ticket,"size");shot.node.show()
		if kind=="homing":
			shot.target=_target(shot.node.position,hero.facing,unit)
			if shot.target!=null:
				var aim=AttackChain.aim_point(shot.target.get_ref(),shot.node.position)-shot.node.position
				if not aim.is_zero_approx():shot.velocity=aim.normalized()*16*unit*hero.skill_factor(shot.ticket,"travel_speed")
		_pose(shot);releases+=1
	game.sound(SOUNDS[kind],.7,false,hero.attack_ticket,13)
	peak_active=maxi(peak_active,active_count())

func _physics_process(delta:float):
	if not is_instance_valid(game) or not is_instance_valid(hero):return
	if active_count()==0 and not ghosts.any(func(g):return g.visible):set_physics_process(false);return
	if not game.playing or hero.hp<=0:
		for shot in shots:if shot.active:_retire(shot)
		return
	if game.paused or game.transitioning:return
	projectile_clock+=delta*30
	while projectile_clock+.000001>=1:
		projectile_clock-=1
		for shot in shots:if shot.active:_shot_tick(shot)
		for ghost in ghosts:
			if not ghost.visible:continue
			var remaining=int(ghost.get_meta("ticks",0))-1;ghost.set_meta("ticks",remaining);ghost.visible=remaining>0

func _shot_tick(shot:Dictionary):
	shot.age+=1
	for trail in shot.trails:
		if trail.age<0:continue
		trail.age+=1
		if trail.age>=10:trail.age=-1;trail.node.hide();continue
		trail.node.scale=Vector3.ONE*shot.effect_unit*(2+trail.age*.25)
		trail.node.material_override.uv1_offset=Vector3(0,trail.age*.1,0)
		trail.node.material_override.albedo_color=Color(maxf(.5,1-trail.age*.125),minf(.5,trail.age*.125),minf(.5,trail.age*.125))
	if shot.blast>=0:
		shot.blast+=1
		if shot.blast>=10:_retire(shot);return
		shot.puff_material.uv1_offset=Vector3(0,shot.blast*.1,0)
		shot.puff.scale=Vector3.ONE*shot.effect_unit*(2+shot.blast*.2)
		for i in shot.plumes.size():
			var angle=i*TAU/shot.plumes.size()
			shot.plumes[i].position=Vector3(cos(angle),sin(angle*.5),sin(angle))*shot.blast*1.5
		return
	var kind:String=shot.kind;var unit:float=shot.unit;var from:Vector3=shot.node.position
	if kind=="homing" and shot.age%2==0:
		for trail in shot.trails:
			if trail.age>=0:continue
			trail.age=0;trail.node.global_position=from;trail.node.scale=Vector3.ONE*shot.effect_unit*2;trail.node.material_override.uv1_offset=Vector3.ZERO;trail.node.show();break
	if kind=="homing":
		var target=shot.target.get_ref() if shot.target!=null else null
		if not is_instance_valid(target) or target.dead:
			shot.target=_target(from,shot.velocity.normalized(),unit);target=shot.target.get_ref() if shot.target!=null else null
		if is_instance_valid(target):
			var desired=(AttackChain.aim_point(target,from)-from).normalized()
			if not desired.is_zero_approx():shot.velocity=shot.velocity.normalized().slerp(desired,1.0/16.0).normalized()*16*unit*hero.skill_factor(shot.ticket,"travel_speed")
	if kind=="fence" and hero.character_id==13:
		var desired=hero.facing
		shot.velocity=shot.velocity.normalized().slerp(desired,1.0/16.0).normalized()*16*unit*hero.skill_factor(shot.ticket,"travel_speed")
	if kind=="grenade":shot.velocity.y-=2*unit
	var next:Vector3=from+shot.velocity
	var wall=AttackChain.world_ray(self,from,next)
	var end:Vector3=next if wall.is_empty() else wall.position
	var radius=4*shot.effect_unit*hero.skill_factor(shot.ticket,"hit_area")
	var width=64*shot.effect_unit*hero.skill_factor(shot.ticket,"hit_area")*minf(2,.25+shot.age/16.0) if kind=="fence" else 0.0
	var side=shot.velocity.normalized().cross(Vector3.UP)*width
	var nearest:Ninja=null;var nearest_t=INF;var point=Vector3.ZERO
	for enemy in AttackChain.segment_enemy_candidates(game,from,end,radius+width):
		if not is_instance_valid(enemy) or enemy.dead or shot.hits.has(enemy.get_instance_id()):continue
		# Fence's source CB8CC samples three lanes at localX0/-64/+64.
		for lane in ([-1,0,1] if kind=="fence" else [0]):
			var contact=AttackChain.segment_contact(enemy,from+side*lane,end+side*lane,radius)
			if contact.is_empty() or float(contact.t)>=nearest_t or not _clear(from+side*lane,contact.point):continue
			nearest=enemy;nearest_t=float(contact.t);point=contact.point
	if nearest!=null:
		shot.node.position=from.lerp(end,nearest_t)
		if kind in ["homing","grenade"]:_explode(shot)
		else:
			shot.hits[nearest.get_instance_id()]=true;_hit(nearest,point,shot.velocity.normalized(),shot.damage,shot.ticket)
			if kind=="fence":game.sound("musashi_fence_hit",.65,false,shot.ticket,13)
			_retire(shot)
		return
	if not wall.is_empty():
		shot.node.position=wall.position+wall.normal*.03
		if kind=="grenade" and wall.normal.y>.5 and shot.bounces>0:
			shot.velocity=shot.velocity.bounce(wall.normal);shot.velocity.y*=.5;shot.bounces-=1
		elif kind in ["grenade","homing"]:_explode(shot);return
		else:_retire(shot);return
	else:shot.node.position=next
	var limit:int={"fence":60,"homing":40,"grenade":100,"three_way":16}[kind]
	if shot.age>=limit:
		if kind in ["homing","grenade"]:_explode(shot)
		else:_retire(shot)
		return
	_pose(shot)

func _target(origin:Vector3,direction:Vector3,unit:float)->WeakRef:
	var best:Ninja=null;var distance=320*unit
	for enemy in AttackChain.enemy_candidates(game,origin,distance):
		if not is_instance_valid(enemy) or enemy.dead:continue
		var point=AttackChain.aim_point(enemy,origin);var offset=point-origin
		if offset.length()>=distance or offset.normalized().dot(direction)<.15 or not _clear(origin,point):continue
		distance=offset.length();best=enemy
	return weakref(best) if best!=null else null

func _clear(from:Vector3,to:Vector3)->bool:
	return AttackChain.clear_line(self,from,to)

func _explode(shot:Dictionary):
	shot.blast=0;shot.visual.hide();shot.puff.show();shot.puff_material.uv1_offset=Vector3.ZERO
	shot.puff.scale=Vector3.ONE*shot.effect_unit*2
	var origin:Vector3=shot.node.position
	for enemy in AttackChain.enemy_candidates(game,origin,48*shot.effect_unit*hero.skill_factor(shot.ticket,"hit_area")):
		if not is_instance_valid(enemy) or enemy.dead or shot.hits.has(enemy.get_instance_id()):continue
		var contact=AttackChain.segment_contact(enemy,origin,origin,48*shot.effect_unit*hero.skill_factor(shot.ticket,"hit_area"))
		if contact.is_empty() or not _clear(origin,contact.point):continue
		shot.hits[enemy.get_instance_id()]=true
		_hit(enemy,contact.point,(AttackChain.aim_point(enemy,origin)-origin).normalized(),shot.damage,shot.ticket)
	game.sound("musashi_grenade_hit" if shot.kind=="grenade" else "musashi_homing_hit",.8,false,shot.ticket,13)
	shot.target=null

func _hit(enemy:Ninja,point:Vector3,direction:Vector3,damage:float,ticket:Dictionary):
	enemy.take_hit(damage,direction,true,ticket);impacts+=1
	# Native impact feedback supplies damage numbers/chain credit. Projectile
	# events use their dedicated source audio instead of the sword default.
	if game.player==hero and not hero.ai_controlled:game.confirm_impact(enemy,point,direction,2,true,13,false)
	else:game.confirm_ally_impact(enemy,point,direction,2,true,13,false)

func _pose(shot:Dictionary):
	if shot.velocity.length_squared()>.00001:shot.visual.quaternion=Quaternion(Vector3.FORWARD,shot.velocity.normalized())
	if shot.kind=="three_way":shot.visual.rotate_object_local(Vector3.FORWARD,float(shot.age)*0x200*TAU/4096.0)
	if shot.kind=="grenade":shot.visual.rotate_object_local(Vector3.RIGHT,float(shot.age)*.35)
	if shot.kind=="fence":shot.visual.scale=Vector3.ONE*shot.effect_unit*hero.skill_factor(shot.ticket,"size")*minf(2,.25+shot.age/16.0)

func _retire(shot:Dictionary):
	preload("res://scripts/character_projectile_pool.gd").clear_slot(shot,"active",shot.node);shot.blast=-1
	for trail in shot.trails:trail.age=-1;trail.node.hide()
