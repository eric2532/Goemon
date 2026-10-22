extends RefCounted
## Goemon's active Gold Pipe swing sweeps the rendered vertices through the same
## native poses and world transform as the model. No fixed range/cone is involved.
const Profile=preload("res://scripts/recovered_goemon_combat_profile.gd")
const PADDING_AXES=[Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]
var hero:Hero
var vertices=PackedVector3Array()
var previous_root=Transform3D.IDENTITY
var previous_scale=1.15
var environment_done=false
var shape=ConvexPolygonShape3D.new()
var query=PhysicsShapeQueryParameters3D.new()
func _init(owner_:Hero):
 hero=owner_;shape.margin=.005;query.shape=shape;query.margin=.005
func begin():
 previous_root=hero.model.rig_visual.global_transform
 previous_scale=hero.model.pipe_visual_scale;environment_done=false
 if vertices.is_empty():
  var mesh:MeshInstance3D=hero.model.pipe.get_node("GoldPipe")
  var unique={}
  for surface in mesh.mesh.get_surface_count():
   for point in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:unique[mesh.transform*point]=true
  var original=PackedVector3Array(unique.keys())
  var source_hull=ConvexPolygonShape3D.new();source_hull.points=original
  # Interior mesh vertices do not change a convex sweep. Keep its exact outer
  # hull once, instead of expanding and rebuilding redundant points each step.
  var hull_points={};var boundary={}
  for point in source_hull.get_debug_mesh().get_faces():hull_points[point]=true
  # Debug hull reconstruction rounds coordinates slightly. Select the source
  # vertex at each corner so the original collision boundary stays exact.
  for corner in hull_points:
   var nearest=original[0];var distance=INF
   for point in original:
    var gap=point.distance_squared_to(corner)
    if gap<distance:distance=gap;nearest=point
   boundary[nearest]=true
  vertices=PackedVector3Array(boundary.keys())
func _pose(action:int,time_:float,root_:Transform3D,scale_:float)->Transform3D:
 return root_*hero.model.pipe_pose(action,time_,scale_)
func _points(pose_:Transform3D)->PackedVector3Array:
 var result=PackedVector3Array()
 for point in vertices:result.append(pose_*point)
 return result
func tick(from:float,until:float):
 var current_root:Transform3D=hero.model.rig_visual.global_transform
 var current_scale:float=hero.model.pipe_visual_scale
 # A small skin around the swept mesh catches near-edge contacts without
 # replacing its shape or granting the old radial/cone reach.
 var padding=.18*hero.growth_multiplier()
 var stage=3 if hero.attack_heavy else hero.combo
 var action:int=Profile.COMBO_ACTIONS[clampi(stage-1,0,2)]
 var cue=Profile.cue_time(action,Profile.COMBO_CUE_FRAMES[clampi(stage-1,0,2)])
 var start=maxf(from,0.0)
 var finish=minf(until,Profile.action_duration(action))
 if vertices.is_empty():begin()
 if finish>=start and hero.model.equipped and not hero.model.chain_selected:
  var interval=maxf(.000001,until-from)
  var initial_weight=clampf((start-from)/interval,0,1) if until>from else 1.0
  var old_pose=_pose(action,start,previous_root.interpolate_with(current_root,initial_weight),lerpf(previous_scale,current_scale,initial_weight))
  var end_pose=_pose(action,finish,current_root,current_scale)
  var travel=0.0
  for vertex in vertices:travel=maxf(travel,(old_pose*vertex).distance_to(end_pose*vertex))
  var steps=clampi(ceili(maxf((finish-start)*Profile.source_fps(action)*4.0,travel/.18)),1,128)
  var old_points=_points(old_pose)
  var any_hit=false
  if not hero.hit_done and finish>=cue:_first_contact()
  for step in range(steps+1):
   var t=float(step)/steps
   var time_=lerpf(start,finish,t)
   var weight=clampf((time_-from)/interval,0,1) if until>from else 1.0
   var pose_=_pose(action,time_,previous_root.interpolate_with(current_root,weight),lerpf(previous_scale,current_scale,weight))
   var points=_points(pose_)
   var origin=old_pose.origin.lerp(pose_.origin,.5)
   var hull=PackedVector3Array()
   # Expand the hull itself: intersect_shape does not honor convex query
   # margins consistently across physics backends.
   for sample_points in [old_points,points]:
    for point in sample_points:
     for axis in PADDING_AXES:hull.append(point-origin+axis*padding)
   shape.points=hull;query.transform=Transform3D(Basis.IDENTITY,origin);query.exclude=[hero.get_rid()]
   query.collision_mask=4
   var space=hero.get_world_3d().direct_space_state
   for hit in space.intersect_shape(query,maxi(256,hero.game.enemies.size()*25)):
    var enemy=hit.collider
    if not enemy is Ninja or enemy.dead or hero.struck_targets.has(enemy.get_instance_id()):continue
    var point:Vector3=enemy.combat_physics_contact(int(hit.shape),origin) if enemy.has_method("combat_physics_contact") else AttackChain.contact_point(enemy,origin,enemy.global_position+Vector3.UP)
    if not _clear(point):continue
    _first_contact()
    hero.struck_targets[enemy.get_instance_id()]=true
    var direction=(point-hero.global_position).normalized()
    var amount=(48 if hero.attack_heavy else (30 if stage==3 else 22))*hero.damage_multiplier()
    enemy.take_hit(amount,direction,hero.attack_heavy or stage==3,hero.attack_ticket)
    if hero.ai_controlled:hero.game.confirm_ally_impact(enemy,point,direction,2 if hero.attack_heavy or stage==3 else (1 if stage==2 else 0),false,1)
    else:hero.game.confirm_impact(enemy,point,direction,2 if hero.attack_heavy or stage==3 else (1 if stage==2 else 0),false)
    any_hit=true
   query.collision_mask=1
   for hit in space.intersect_shape(query,256):
    var part=BreakableBuilding.from_collider(hit.collider)
    if part==null or part.destroyed or hero.struck_targets.has(part.get_instance_id()):continue
    var point=part.nearest(origin)
    if not _clear(point,part):continue
    hero.struck_targets[part.get_instance_id()]=true
    part.take_hit((48 if hero.attack_heavy else (30 if stage==3 else 22))*hero.damage_multiplier(),hero.attack_ticket,point)
   if not environment_done and not any_hit:
    var contact=space.get_rest_info(query)
    if not contact.is_empty():
     environment_done=true;hero.game.impact_effect(contact.point,contact.normal,0);hero.play_sound("environment_hit",.35)
   old_points=points;old_pose=pose_
  if any_hit and not hero.ai_controlled:hero.game.chain+=1;hero.game.chain_timer=3.0
 previous_root=current_root;previous_scale=current_scale
func _first_contact():
 if hero.hit_done:return
 hero.hit_done=true;hero.melee_assist.contact();hero.emit_robe_coins()
func _clear(point:Vector3,building:BreakableBuilding=null)->bool:
 var ray=PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP*1.1*hero.growth_multiplier(),point,1)
 ray.exclude=[hero.get_rid()]
 var hit=hero.get_world_3d().direct_space_state.intersect_ray(ray)
 return hit.is_empty() or (building!=null and BreakableBuilding.from_collider(hit.collider)==building)
