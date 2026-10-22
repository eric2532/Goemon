extends Node
## One owner for native NPC state. The playable Hero never enters this runtime.
var native:Object
var game_ref:WeakRef
var capacity=4000
var shared_snapshot_enabled=false
var snapshot_view:Object
var snapshot_epoch=0
var navigation_revision=-1
var handles:Dictionary={}
var enemies:Dictionary={}
var allies:Dictionary={}
var query_actors:Dictionary={}
var query_padding=0.0
var query_kinds:Dictionary={}
var tickets:Dictionary={}
var ticket_serial=0
var last_event_serial=0
var dispatching=false
signal unit_died(event:Dictionary)
var pooled_presentation=false
var record_events=true
var compact_scene_events=true
var presentation_events:Array[Dictionary]=[]
var event_log:Array[Dictionary]=[]
var collect_stats=false
var observed_counts:Dictionary={}
var event_gaps=0
func configure(game:Node,maximum:int=4000)->void:
 game_ref=weakref(game) if game!=null else null
 if game!=null:preload("res://scripts/forest/forest_soldier_audio.gd").ensure(game)
 capacity=maximum
 navigation_revision=-1
 if not ClassDB.class_exists("GoemonCrowdRuntime"):
  GDExtensionManager.load_extension("res://native/terrain_math/terrain_math.gdextension")
 if not ClassDB.class_exists("GoemonCrowdRuntime"):
  push_error("Native crowd runtime is unavailable; 4000-unit support cannot be enabled")
  return
 if native==null:native=ClassDB.instantiate("GoemonCrowdRuntime")
 native.configure(capacity,2000)
func spawn(logical_id:int,team:int,kind:int,position:Vector3,hp:float,radius:float)->int:
 var h:int=native.spawn(logical_id,team,kind,position,hp,radius)
 if h!=0:handles[logical_id]=h
 return h
func despawn(handle:int)->void:
 var data:Dictionary=unit_state(handle)
 native.despawn(handle);query_actors.erase(handle)
 if not data.is_empty():
  var id:int=data.logical_id
  if is_instance_valid(enemies.get(id)):enemies[id].mark_dead()
  if is_instance_valid(allies.get(id)):allies[id].mark_dead()
  handles.erase(id)
  if data.team==0:_enemy_retired(id)
func _enemy_retired(_id:int)->void:pass
func valid(handle:int)->bool:return native.valid(handle)
func snapshot()->Dictionary:return native.snapshot()
func render_snapshot()->Dictionary:return native.render_snapshot()
func sync_helper_mirrors(defenders:Dictionary,posts:Dictionary)->int:return native.sync_helper_mirrors(defenders,posts)
func query_aabb(bounds:AABB,team:int)->PackedInt64Array:return native.query_aabb(bounds,team)
func clear()->void:
 snapshot_view=null;snapshot_epoch+=1
 if native!=null:native.clear()
 for actor in enemies.values()+allies.values():
  if is_instance_valid(actor):actor.queue_free()
 query_actors.clear();query_kinds.clear();query_padding=0.0
 handles.clear();enemies.clear();allies.clear();tickets.clear();event_log.clear();presentation_events.clear()
func set_navigation(revision:int,data:Dictionary)->void:
 if revision==navigation_revision:return
 native.set_navigation(data);navigation_revision=revision
func static_collision_faces(world:Node)->PackedVector3Array:return static_collision_data(world).faces
func static_collision_data(world:Node)->Dictionary:
 # Match the allies' layer-1 physics mask. Ground-nav footprints deliberately
 # have different heights and must never stand in for roofs, rails or walls.
 var result=PackedVector3Array();var owners=PackedInt64Array();var structures={}
 if world.get("structure_nodes") is Dictionary:
  for id in world.structure_nodes:
   if is_instance_valid(world.structure_nodes[id]):structures[world.structure_nodes[id].get_instance_id()]=id
 for node in world.find_children("*","CollisionShape3D",true,false):
  if node.disabled or node.shape==null:continue
  var pending=node;var retiring=false
  while pending!=null and pending!=world:
   if pending.is_queued_for_deletion():retiring=true;break
   pending=pending.get_parent()
  if retiring:continue
  var body=node.get_parent()
  if not body is StaticBody3D or not body.collision_layer&1:continue
  var faces=PackedVector3Array()
  if node.shape is BoxShape3D:
   var half:Vector3=node.shape.size*.5;var points=[]
   for x in [-1,1]:
    for y in [-1,1]:
     for z in [-1,1]:points.append(Vector3(x*half.x,y*half.y,z*half.z))
   for face in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
    for index in [0,1,2,0,2,3]:faces.append(points[face[index]])
  elif node.shape is ConcavePolygonShape3D:faces=node.shape.get_faces()
  elif node.shape is ConvexPolygonShape3D:
   var points:PackedVector3Array=node.shape.points
   # All current static convex hulls are eight-vertex rampart prisms. Retain
   # every supporting triangle; coplanar duplicates have identical contacts.
   for a in points.size():
    for b in range(a+1,points.size()):
     for c in range(b+1,points.size()):
      var normal=(points[b]-points[a]).cross(points[c]-points[a])
      if normal.length_squared()<.00000001:continue
      normal=normal.normalized();var positive=false;var negative=false
      for p in points:
       var side=normal.dot(p-points[a]);positive=positive or side>.0001;negative=negative or side<-.0001
       if positive and negative:break
      if not (positive and negative):faces.append_array(PackedVector3Array([points[a],points[b],points[c]]))
  else:
   push_error("Unexported static army collision shape: "+str(node.get_path()))
  var owner_id=-1;var ancestor=node.get_parent()
  while ancestor!=null and ancestor!=world:
   if structures.has(ancestor.get_instance_id()):owner_id=structures[ancestor.get_instance_id()];break
   ancestor=ancestor.get_parent()
  for point in faces:result.append(node.global_transform*point)
  for triangle in faces.size()/3:owners.append(owner_id)
 return {"faces":result,"owners":owners}
func step(delta:float,context:Dictionary)->void:
 if context.get("paused",false):return
 if context.has("goal_handles"):
  native.set_goals(context.goal_handles,context.goal_positions,context.goal_speeds)
 if context.has("targets"):native.set_targets(context.targets)
 native.step(delta)
func configure_kits(data:Dictionary)->void:
 assert(native.configure_kits(data),"Invalid NPC combat profile data")
func unit_state(handle:int)->Dictionary:return native.unit_state(handle)
func set_pose(handle:int,point:Vector3,yaw:float)->void:native.set_pose(handle,point,yaw)
func enemy_target(id:int)->Ninja:
 if is_instance_valid(enemies.get(id)):
  if enemies[id].handle==handles.get(id,0):return enemies[id]
  enemies[id].mark_dead();enemies[id].queue_free();enemies.erase(id)
 var h:int=handles.get(id,0);var data:Dictionary=unit_state(h)
 var game:Node=game_ref.get_ref() if game_ref!=null else null
 if data.is_empty() or data.team!=0 or game==null:return null
 var actor=load("res://scripts/forest/crowd/army_enemy_target.gd").new();actor.runtime=self;actor.game=game;actor.handle=h;actor.forest_id=id;actor.variant=data.kind
 game.add_child(actor);actor.sync(data);enemies[id]=actor;register_actor_facade(actor,game.model.enemies.get(id,{}));return actor
func ally_target(id:int)->Node3D:
 if is_instance_valid(allies.get(id)):
  if allies[id].handle==handles.get(id,0):return allies[id]
  allies[id].mark_dead();allies[id].queue_free();allies.erase(id)
 var h:int=handles.get(id,0);var data:Dictionary=unit_state(h)
 var game:Node=game_ref.get_ref() if game_ref!=null else null
 if data.is_empty() or data.team!=1 or game==null:return null
 var actor=load("res://scripts/forest/crowd/army_ally_target.gd").new();actor.runtime=self;actor.handle=h;actor.gate_id=id;actor.character_id=data.kind
 game.add_child(actor);actor.sync(data);allies[id]=actor;register_actor_facade(actor);return actor
# Re-register if an owned facade or its backing model dictionary is replaced.
# Scripts on these NPC adapters are fixed for their lifetime.
func register_actor_facade(actor:Node3D,row:Dictionary={})->bool:
 if actor is Ninja:
  query_actors[actor.handle]=actor
  if not query_kinds.has(actor.variant):
   query_kinds[actor.variant]=true
   for item in preload("res://scripts/forest/forest_enemy_contact.gd").shapes(actor.variant):
    var box:AABB=item.bounds
    for x in [box.position.x,box.end.x]:
     for z in [box.position.z,box.end.z]:query_padding=maxf(query_padding,Vector2(x,z).length()+maxf(0,actor.body_radius))
 return native.register_facade(actor.handle,row,actor)
func enemy_candidates(center:Vector3,radius:float)->Array:
 var game=game_ref.get_ref() if game_ref!=null else null
 if game==null:return []
 if not center.is_finite() or not is_finite(radius) or radius<0:return game.enemies
 # Unknown/custom actors retain the legacy scan. Owned proxies have fixed fitted
 # geometry; exact tests, visibility, HP and source hit order stay with callers.
 var dummy=game.get("training_dummy")
 var extra=1 if is_instance_valid(dummy) and game.enemies.has(dummy) else 0
 if query_actors.size()!=enemies.size() or game.enemies.size()!=enemies.size()+extra:return game.enemies
 var reach=radius+query_padding+.001
 if not is_finite(reach) or reach>=1e8:return game.enemies
 var handles_=query_aabb(AABB(Vector3(center.x-reach,-1e8,center.z-reach),Vector3(reach*2,2e8,reach*2)),0)
 var result=[]
 for handle_ in handles_:
  var actor=query_actors.get(handle_)
  if is_instance_valid(actor) and not actor.is_queued_for_deletion():result.append(actor)
 if extra:result.append(dummy)
 # Preserve arbitrary source ordering, including the preparation dummy. Only
 # local candidates cross into GDScript; Array.find runs in the engine.
 if result.size()>64:
  var selected={}
  for actor in result:selected[actor]=true
  return game.enemies.filter(func(actor):return selected.has(actor))
 result.sort_custom(func(a,b):return game.enemies.find(a)<game.enemies.find(b))
 return result
func sync_targets()->void:
 for id in enemies:
  if is_instance_valid(enemies[id]) and valid(enemies[id].handle):enemies[id].sync(unit_state(enemies[id].handle))
 for id in allies:
  if is_instance_valid(allies[id]) and valid(allies[id].handle):allies[id].sync(unit_state(allies[id].handle))
func apply_hit(handle:int,hit:Dictionary)->Dictionary:
 var before:Dictionary=unit_state(handle)
 var result:Dictionary=native.apply_hit(handle,hit)
 if not before.is_empty():
  var table:Dictionary=enemies if before.team==0 else allies
  var actor=table.get(before.logical_id)
  if is_instance_valid(actor):
   actor.hp=result.hp
   if result.dead:actor.mark_dead()
 if game_ref!=null:dispatch_events()
 return result
func hit_target(handle:int,hit:Dictionary,ticket:Dictionary)->Dictionary:
 ticket_serial+=1;tickets[ticket_serial]=ticket;hit.ticket_id=ticket_serial
 var result=apply_hit(handle,hit);return result
func damage_enemy(id:int,amount:float)->void:
 var actor=enemy_target(id)
 if is_instance_valid(actor):actor.take_hit(amount,Vector3.UP,false,{"tower":true})
func dispatch_events()->void:
 var game:Node=game_ref.get_ref() if game_ref!=null else null
 if game==null or dispatching:return
 dispatching=true
 var events=_take_scene_events()
 # Drain before callbacks. A kill callback may spawn or damage another unit.
 while not events.is_empty():
  for event in events:
   if event.serial<=last_event_serial:continue
   if collect_stats:
    event_gaps+=maxi(0,event.serial-last_event_serial-1);observed_counts[event.kind]=int(observed_counts.get(event.kind,0))+1
   last_event_serial=event.serial
   var gameplay=event.kind=="damage" or event.kind=="death"
   var actor=(enemies.get(event.target_id) if event.team==0 else allies.get(event.target_id)) if gameplay else null
   if event.kind=="death" and is_instance_valid(actor):query_actors.erase(actor.handle)
   var ticket:Dictionary=tickets.get(event.ticket_id,{}) if gameplay else {}
   match event.kind:
    "damage":
     if is_instance_valid(actor):
      var data=unit_state(actor.handle)
      if data.is_empty():actor.hp=event.hp
      else:actor.sync(data)
     if game.model.enemies.has(event.target_id) and event.team==0:game.model.enemies[event.target_id].hp=event.hp
     if not pooled_presentation and event.team==0 and event.source_id>=0 and (not ticket.get("tower",false) or ticket.get("tower_feedback",false)):
      game.damage_number(event.position,int(event.amount),event.heavy,ticket.get("critical",false))
    "death":
     if is_instance_valid(actor):actor.mark_dead()
     handles.erase(event.target_id)
     if event.team==0:
      _enemy_retired(event.target_id)
      preload("res://scripts/forest/forest_soldier_audio.gd").soldier_died(game,event.position,event.unit_kind)
      game.kills+=1
      var row:Dictionary=game.model.enemies.get(event.target_id,{"id":event.target_id,"pos":event.position,"variant":event.unit_kind})
      row.hp=event.hp;game.model.ryo.award_enemy_bounty(row)
      if is_instance_valid(actor):game.remember_defeat(actor)
      if event.source_id==0 and not ticket.get("tower",false) and not ticket.get("allied",false):
       game.player.award_kill()
       if game.player.hp>0:game.player.hp=minf(game.player.max_hp,game.player.hp+9)
    "external_damage":
     match int(event.external_kind):
      0:game.player.take_hit(event.amount,(game.player.position-event.position).normalized(),event.projectile)
      1:game.model.damage_worker(event.target_id,event.amount)
      2:game.model.damage_building(event.target_id,event.amount)
      3:
       var defender=game.gate_defenders.units.get(event.target_id)
       if is_instance_valid(defender):defender.take_hit(event.amount,(defender.position-event.position).normalized(),event.projectile)
   presentation_events.append(event)
   if record_events:event_log.append(event)
   if event.kind=="death":unit_died.emit(event)
  events=_take_scene_events()
 dispatching=false;tickets.clear()
 if presentation_events.size()>8192:presentation_events=presentation_events.slice(presentation_events.size()-8192)
 # Presentation consumes events later; bound retained development diagnostics.
 if event_log.size()>8192:event_log=event_log.slice(event_log.size()-4096)
func _take_scene_events()->Array:
 return native.take_events() if record_events or not compact_scene_events else native.take_scene_events()
func take_events()->Array[Dictionary]:
 var result:Array[Dictionary]=[];result.assign(native.take_events());return result
static func navigation_data(model:RefCounted,include_obstacles:bool=true)->Dictionary:
 var terrain=model.terrain
 var region:Rect2i=model.navigation_region
 var data={"width":0,"spacing":3.0,"origin":Vector3(-240,0,-240),"bounds_min":Vector3(-243,0,-243),"bounds_max":Vector3(237,0,237),"heights":PackedFloat32Array(),"covered":PackedByteArray(),"obstacle_min":PackedVector3Array(),"obstacle_max":PackedVector3Array(),"layer_min":PackedVector3Array(),"layer_max":PackedVector3Array(),"pieces":PackedFloat32Array(),"ray_min":PackedVector3Array(),"ray_max":PackedVector3Array(),"ray_owner":PackedInt64Array()}
 data.bounds_min=Vector3(region.position.x*6-3,0,region.position.y*6-3)
 data.bounds_max=Vector3(region.end.x*6-3,0,region.end.y*6-3)
 if terrain.has_method("contains"):
  data.width=terrain.width;data.spacing=terrain.spacing;data.heights=terrain.heights;data.covered=terrain.covered
  var origin:Vector2=-terrain.coordinate(0,0)*terrain.spacing
  data.origin=Vector3(origin.x,0,origin.y)
 # Preserve authored rampart formulae instead of rasterizing decks/ramp edges.
 for piece in terrain.pieces:
  data.pieces.append_array(PackedFloat32Array([piece.a.x,piece.a.y,piece.along.x,piece.along.y,piece.half,piece.length,piece.start,piece.end,piece.h0,piece.h1]))
 data.friendly_navigation=true;data.friendly_obstacle_min=PackedVector3Array();data.friendly_obstacle_max=PackedVector3Array()
 if include_obstacles:
  var profile=preload("res://scripts/forest/forest_structure_profile.gd")
  for building in model.buildings.values():
   if building.hp<=0:continue
   var size:Vector2i=model.dimensions(building.kind,building.rotation,building.get("span",0))
   var first:Vector3=model.point(building.cell)-Vector3(3,0,3)
   data.ray_min.append(first);data.ray_max.append(first+Vector3(size.x*6,profile.height(building.kind),size.y*6));data.ray_owner.append(building.id)
   if building.kind!="gate" or not building.get("breached",false):
    data.obstacle_min.append(first);data.obstacle_max.append(first+Vector3(size.x*6,profile.height(building.kind),size.y*6))
   if building.kind=="gate":
    var transform_=Transform3D(Basis(Vector3.UP,building.rotation*PI*.5),model.center(building))
    for side in [-1,1]:
     var box=transform_*AABB(Vector3(side*profile.GATE_PILLAR_X-profile.GATE_PILLAR_WIDTH*.5,0,-profile.GATE_FRAME_DEPTH*.5),Vector3(profile.GATE_PILLAR_WIDTH,profile.GATE_HEIGHT,profile.GATE_FRAME_DEPTH))
     data.friendly_obstacle_min.append(box.position);data.friendly_obstacle_max.append(box.end)
   else:
    data.friendly_obstacle_min.append(first);data.friendly_obstacle_max.append(first+Vector3(size.x*6,profile.height(building.kind),size.y*6))
  for cell in model.trees:
   var center:Vector3=model.point(cell)
   data.ray_min.append(center+Vector3(-1.5,0,-1.5));data.ray_max.append(center+Vector3(1.5,12,1.5));data.ray_owner.append(-1)
   # Ground routing uses the same trunk footprint as existing navigation.
   data.obstacle_min.append(center+Vector3(-1.25,0,-1.25));data.obstacle_max.append(center+Vector3(1.25,1000,1.25))
   data.friendly_obstacle_min.append(center+Vector3(-1.25,0,-1.25));data.friendly_obstacle_max.append(center+Vector3(1.25,1000,1.25))
 return data
