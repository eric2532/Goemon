extends RefCounted
## Five reusable character bodies backed by the one native army owner.
const Kit=preload("res://scripts/warcraft_kit.gd")
var hero:Hero
var handles:Array[int]=[]
var bodies:Array=[]
var left=0.0
var shape=CapsuleShape3D.new()
var runtime:Node
func _init(caster:Hero,count:int=Kit.MIRROR_COUNT):
 hero=caster;shape.radius=.4;shape.height=2.6
 runtime=hero.game.get("army_runtime")
 if not is_instance_valid(runtime):return
 for i in count:make_body(hero.character_id)
func make_body(character:int):
 var body=load("res://scripts/forest/crowd/mirror_body.gd").new()
 body.game=hero.game;body.character_id=character
 runtime.actor_root.add_child(body);body.hide();bodies.append(body)
 return body
func reinforce(character:int,point:Vector3)->bool:
 runtime.finish_integration()
 var body=null
 for candidate in bodies:
  if not candidate.leased and candidate.character_id==character:body=candidate;break
 if body==null:body=make_body(character)
 body.team_progression=hero.game.model.team_progression;body.clear_powerups()
 if character==32:body.active_ability.demon=false
 body.activate()
 body.global_position=point;body.facing=Vector3.FORWARD;body.ai_aim=point+Vector3.FORWARD*50
 var handle:int=runtime.spawn(-int(body.get_instance_id())*8-1,1,100+character,point,body.max_hp,.4)
 var reach=Kit.MELEE_REACH if character in [31,32,33] else 3.0
 if handle==0 or not runtime.native.set_mirror(handle,body.actions.size(),body.combat_tuning("walk_speed")*body.movement_multiplier(),reach*body.contact_size_multiplier()*body.melee_reach_setting(),Vector3.FORWARD):
  if handle!=0:runtime.despawn(handle)
  body.retire();return false
 body.native_handle=handle
 # Permanent card recruits share the castle defense area and return post.
 runtime.native.set_guard(handle,point,hero.game.explorer_helpers.guard_radius())
 handles.resize(bodies.size());handles[bodies.find(body)]=handle;left=INF
 if not runtime.mirror_action.is_connected(_action):runtime.mirror_action.connect(_action)
 if not runtime.mirrors_advanced.is_connected(tick):runtime.mirrors_advanced.connect(tick)
 return true
func prepare_loadout():
 for body in bodies:body.prepare_loadout()
func point_clear(point:Vector3)->bool:
 if not hero.game.model.navigation_region.has_point(hero.game.model.cell_of(point)):return false
 var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
 query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*1.31)
 return hero.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func clear_point(desired:Vector3,used:Array[Vector3],separation:float)->Vector3:
 for ring in range(5):
  for sector in (1 if ring==0 else 12):
   var point=desired+Vector3(sin(sector*TAU/12),0,cos(sector*TAU/12))*float(ring)*1.5
   point.y=hero.game.model.surface_height(point.x,point.z)+.12
   if used.any(func(other):return other.distance_to(point)<separation):continue
   if point_clear(point):return point
 return Vector3.INF
func cast()->bool:
 if not is_instance_valid(runtime) or bodies.size()!=Kit.MIRROR_COUNT:return false
 runtime.finish_integration()
 var direction=hero.combat_attack_direction();direction.y=0;direction=direction.normalized()
 if direction.is_zero_approx():direction=hero.facing
 var spread=clampf(hero.model.scale.x*1.25,4.0,8.0)
 var points:Array[Vector3]=[]
 for i in Kit.MIRROR_COUNT:
  var radial=direction.rotated(Vector3.UP,TAU*i/Kit.MIRROR_COUNT)
  var point=clear_point(hero.global_position+radial*spread,points,spread*.65)
  if not point.is_finite():point=clear_point(hero.global_position+radial*1.5,points,1.4)
  if not point.is_finite():return false
  points.append(point)
 clear()
 for i in Kit.MIRROR_COUNT:
  var id=-int(hero.get_instance_id())*8-i-1
  var health=hero.max_hp-(500 if hero.character_id==33 and hero.active_ability.demon else 0)
  var handle:int=runtime.spawn(id,1,100+hero.character_id,points[i],health,.4)
  if handle==0:clear();return false
  handles.append(handle)
  var body=bodies[i];body.copy_from(hero);body.native_handle=handle;body.global_position=points[i];body.facing=direction;body.ai_aim=points[i]+direction*50
  body.velocity=Vector3.DOWN;body.move_and_slide()
  var speed=hero.combat_tuning("walk_speed")*hero.movement_multiplier()
  var approach=direction.rotated(Vector3.UP,TAU*i/Kit.MIRROR_COUNT)
  var reach=Kit.MELEE_REACH if hero.character_id in [31,32,33] else 3.0
  if not runtime.native.set_mirror(handle,body.actions.size(),speed,reach*body.contact_size_multiplier()*body.melee_reach_setting(),approach):clear();return false
 left=Kit.MIRROR_TIME
 runtime.mirror_action.connect(_action);runtime.mirrors_advanced.connect(tick)
 return true
func _action(event:Dictionary):
 for i in handles.size():
  if int(event.get("ticket_id",0))==handles[i] and runtime.valid(handles[i]):
   bodies[i].global_position=runtime.unit_state(handles[i]).position
   bodies[i].perform(int(event.action_index)-400,event.position)
   runtime.native.set_mirror_busy(handles[i],bodies[i].has_offensive_action())
   return
func tick(delta:float):
 if left<=0:return
 left=maxf(0,left-delta)
 if left<=0:clear();return
 var living=false
 for i in handles.size():
  if handles[i]==0:continue
  var state:Dictionary=runtime.unit_state(handles[i])
  if state.is_empty() or state.hp<=0:bodies[i].retire();handles[i]=0;continue
  living=true
  if state.frozen>0 or state.stun>0:continue
  var body=bodies[i];body.step(delta,state)
  if body.global_position!=state.position:runtime.native.set_pose(handles[i],body.global_position,atan2(body.facing.x,body.facing.z))
  runtime.native.set_mirror_busy(handles[i],body.has_offensive_action())
 if not living:clear()
func clear():
 if is_instance_valid(runtime):
  if runtime.mirror_action.is_connected(_action):runtime.mirror_action.disconnect(_action)
  if runtime.mirrors_advanced.is_connected(tick):runtime.mirrors_advanced.disconnect(tick)
  for handle in handles:
   if runtime.valid(handle):runtime.despawn(handle)
 handles.clear();left=0
 for body in bodies:
  if is_instance_valid(body):body.retire()
func dispose():
 clear()
 for body in bodies:
  if is_instance_valid(body):body.queue_free()
 bodies.clear()
