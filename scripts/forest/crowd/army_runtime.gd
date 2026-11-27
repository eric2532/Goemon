extends Node
const ContextRegions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
## One owner for native NPC state. The playable Hero never enters this runtime.
const NO_TICKET={}
const ZombieMoves=preload("res://scripts/forest/crowd/zombie_sprites.gd")
const Captain=preload("res://scripts/forest/crowd/captain_sprites.gd")
const Grave=preload("res://scripts/forest/crowd/grave_sprites.gd")
const Ruby=preload("res://scripts/forest/crowd/ruby_boss_sprites.gd")
const Freyja=preload("res://assets/maps/falan/freyja_destinations_data.gd")
const Habaru=preload("res://scripts/forest/crowd/habaru_sprites.gd")
const Undersea=preload("res://scripts/forest/crowd/undersea_sprites.gd")
static var il_source_caps:Script
var native:Object
var game_ref:WeakRef
var actor_root:Node3D
var capacity=4000
var shared_snapshot_enabled=false
var snapshot_view:Object
var snapshot_epoch=0
var ally_fields_epoch=-1
var navigation_revision=-1
var handles:Dictionary={}
var enemies:Dictionary={}
var allies:Dictionary={}
var query_actors:Dictionary={}
var enemy_size=1.0
var pet_geometry=PackedFloat32Array()
var query_padding=0.0
var query_kinds:Dictionary={}
var tickets:Dictionary={}
var ticket_serial=0
var last_event_serial=0
var dispatching=false
signal unit_died(event:Dictionary)
signal mirror_action(event:Dictionary)
signal mirrors_advanced(delta:float)
var pooled_presentation=false
var record_events=true
var compact_scene_events=true
var presentation_events:Array[Dictionary]=[]
var event_log:Array[Dictionary]=[]
var collect_stats=false
var observed_counts:Dictionary={}
var event_gaps=0
var static_collision_cache:Dictionary={}
func configure(game:Node,maximum:int=4000)->bool:
 game_ref=weakref(game) if game!=null else null
 if game!=null and (not is_instance_valid(actor_root) or actor_root.get_parent()!=game):
  # Keep NPC churn away from the HUD's sibling ordering and child cache.
  actor_root=Node3D.new();actor_root.name="ArmyActors";game.add_child(actor_root)
 if game!=null:preload("res://scripts/forest/forest_soldier_audio.gd").ensure(game)
 capacity=maximum
 navigation_revision=-1
 if not ClassDB.class_exists("GoemonCrowdRuntime"):
  GDExtensionManager.load_extension("res://native/terrain_math/terrain_math.gdextension")
 if not ClassDB.class_exists("GoemonCrowdRuntime"):
  push_error("Native crowd runtime is unavailable; 4000-unit support cannot be enabled")
  return false
 if native==null:native=ClassDB.instantiate("GoemonCrowdRuntime")
 native.configure(capacity,2000)
 return true
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
func record_pet_participation(_event:Dictionary):pass
func valid(handle:int)->bool:return native.valid(handle)
func snapshot()->Dictionary:return native.snapshot()
func render_snapshot()->Dictionary:return native.render_snapshot()
func sync_helper_mirrors(defenders:Dictionary,posts:Dictionary)->int:return native.sync_helper_mirrors(defenders,posts)
func query_aabb(bounds:AABB,team:int)->PackedInt64Array:return native.query_aabb(bounds,team)
func index_enemy_rows(rows:Array)->Dictionary:return native.index_enemy_rows(rows,handles,preload("res://scripts/forest/forest_thirstquencher_visual.gd").ROLE_TO_TYPE)
func clear()->void:
 static_collision_cache.clear()
 snapshot_view=null;snapshot_epoch+=1;ally_fields_epoch=-1
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
 var changing_faces=PackedVector3Array();var changing_owners=PackedInt64Array()
 var active={}
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
  var id=node.get_instance_id();active[id]=true
  var cached:Dictionary=static_collision_cache.get(id,{})
  var faces=PackedVector3Array()
  if node.shape is BoxShape3D and cached.get("box_size",Vector3.INF)==node.shape.size:faces=cached.local_faces
  elif node.shape is BoxShape3D:
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
   if ancestor.has_meta("army_collision_owner"):owner_id=int(ancestor.get_meta("army_collision_owner"));break
   ancestor=ancestor.get_parent()
  var transform_:Transform3D=node.global_transform
  if cached.is_empty() or cached.node.get_ref()!=node or cached.local_faces!=faces or cached.transform!=transform_ or cached.owner!=owner_id:
   var transformed=faces if transform_==Transform3D.IDENTITY else transform_*faces
   var owner_rows=PackedInt64Array();owner_rows.resize(faces.size()/3);owner_rows.fill(owner_id)
   cached={"node":weakref(node),"local_faces":faces,"transform":transform_,"owner":owner_id,"faces":transformed,"owners":owner_rows}
   if node.shape is BoxShape3D:cached.box_size=node.shape.size
   static_collision_cache[id]=cached
  # Native collision preserves the unowned prefix across building destruction.
  if owner_id>=0:changing_faces.append_array(cached.faces);changing_owners.append_array(cached.owners)
  else:result.append_array(cached.faces);owners.append_array(cached.owners)
 for id in static_collision_cache.keys():
  if not active.has(id):static_collision_cache.erase(id)
 result.append_array(changing_faces);owners.append_array(changing_owners)
 return {"faces":result,"owners":owners}
func step(delta:float,context:Dictionary)->void:
 if context.get("paused",false):return
 if context.has("goal_handles"):
  native.set_goals(context.goal_handles,context.goal_positions,context.goal_speeds)
 if context.has("targets"):native.set_targets(context.targets)
 native.step(delta)
 if mirrors_advanced.has_connections():dispatch_events();mirrors_advanced.emit(delta)
func configure_kits(data:Dictionary)->void:
 assert(native.configure_kits(data),"Invalid NPC combat profile data")
 if enemy_size!=float(data.get("enemy_size",1.0)):query_kinds.clear();query_padding=0.0
 enemy_size=float(data.get("enemy_size",1.0))
 pet_geometry=data.get("pet_geometry",PackedFloat32Array())
func unit_state(handle:int)->Dictionary:return native.unit_state(handle)
func set_pose(handle:int,point:Vector3,yaw:float)->void:native.set_pose(handle,point,yaw)
func enemy_target(id:int)->Ninja:
 if is_instance_valid(enemies.get(id)):
  if enemies[id].dead and enemies[id].sequence_users>0:return null
  if enemies[id].handle==handles.get(id,0):return enemies[id]
  query_actors.erase(enemies[id].handle);enemies[id].mark_dead();enemies[id].queue_free();enemies.erase(id)
 var h:int=handles.get(id,0);var data:Dictionary=unit_state(h)
 var game:Node=game_ref.get_ref() if game_ref!=null else null
 if data.is_empty() or data.team!=0 or game==null:return null
 var actor=load("res://scripts/forest/crowd/army_enemy_target.gd").new();actor.runtime=self;actor.game=game;actor.handle=h;actor.forest_id=id;actor.variant=data.kind
 var row:Dictionary=game.model.enemies.get(id,{})
 if row.has("habaru_slot"):
  actor.body_override=Habaru.CHAMBER_BODY
  actor.body_override.size.y=float(Habaru.motions().variants[row.skin].standing_height)
 elif row.has("habaru_slime_slot"):
  actor.body_override=Habaru.SLIME_BODY
 elif row.has("venoa_bear_slot"):
  actor.body_override=Habaru.VENOA_BOSS_BODY if row.get("skin")==Habaru.VENOA_BOSS_SKIN else Habaru.BODY
 elif row.has("zombie_slot"):
  actor.body_override=ZombieMoves.BODY
 elif row.has("captain_slot"):
  actor.body_override=Captain.BODY
 elif row.has("grave_slot"):
  actor.body_override=Grave.FINAL_BODY if row.skin==2 else Grave.BODY
 elif row.has("black_prayer_slot"):
  actor.body_override=Ruby.ESCORT_BODY
 elif row.has("ruby_slot"):
  actor.body_override=Ruby.BODY if row.ruby_slot==0 else Ruby.ESCORT_BODY
 elif row.has("undersea_slot"):
  actor.body_override=Undersea.BOSS_BODY if row.undersea_slot==0 else Undersea.BODY
 elif row.has("frontier_patrol"):
  var patrols=game.model.waves.patrol_source
  actor.body_override=patrols.TREE_BODY if patrols.tree(row.skin) else patrols.BODY
 if not pet_geometry.is_empty() and actor.variant in [19,20,21]:
  actor.body_override=preload("res://scripts/forest/crowd/pet_dimensions.gd").bounds(pet_geometry,actor.variant,int(data.pose_row))
 if row.has("body_scale"):
  actor.body_override=AABB(actor.body_override.position*row.body_scale,actor.body_override.size*row.body_scale)
 actor_root.add_child(actor);actor.sync(data);enemies[id]=actor;register_actor_facade(actor,row);return actor
func ally_target(id:int)->Node3D:
 if is_instance_valid(allies.get(id)):
  if allies[id].handle==handles.get(id,0):return allies[id]
  allies[id].mark_dead();allies[id].queue_free();allies.erase(id)
 var h:int=handles.get(id,0);var data:Dictionary=unit_state(h)
 var game:Node=game_ref.get_ref() if game_ref!=null else null
 if data.is_empty() or data.team!=1 or game==null:return null
 var actor=load("res://scripts/forest/crowd/army_ally_target.gd").new();actor.runtime=self;actor.handle=h;actor.gate_id=id;actor.character_id=data.kind
 actor_root.add_child(actor);actor.sync(data);allies[id]=actor;register_actor_facade(actor);return actor
# Re-register if an owned facade or its backing model dictionary is replaced.
# Scripts on these NPC adapters are fixed for their lifetime.
func register_actor_facade(actor:Node3D,row:Dictionary={})->bool:
 if actor is Ninja:
  query_actors[actor.handle]=actor
  if actor.body_override.has_volume():
   var box:AABB=actor.body_override
   for x in [box.position.x,box.end.x]:
    for z in [box.position.z,box.end.z]:query_padding=maxf(query_padding,Vector2(x,z).length())
  if not query_kinds.has(actor.variant):
   query_kinds[actor.variant]=true
   for item in preload("res://scripts/forest/forest_enemy_contact.gd").shapes(actor.variant,false,enemy_size):
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
 var extras=[]
 if is_instance_valid(dummy) and game.enemies.has(dummy):extras.append(dummy)
 var objectives=game.get("enemy_objectives")
 var extra=extras.size()
 if objectives is Array:
  extra+=game.enemy_objective_targets.size()
  for target in objectives:
   if is_instance_valid(target) and not target.dead:extras.append_array(target.combat_candidates(center,radius+query_padding+.001))
 if query_actors.size()!=enemies.size() or game.enemies.size()!=enemies.size()+extra:return game.enemies
 var reach=radius+query_padding+.001
 if not is_finite(reach) or reach>=1e8:return game.enemies
 # Native marshalling keeps the current source order without per-shot script scans.
 return native.ordered_enemy_candidates(AABB(Vector3(center.x-reach,-1e8,center.z-reach),Vector3(reach*2,2e8,reach*2)),query_actors,game.enemies,extras)
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
   if result.dead:actor.mark_dead(true) if actor.has_method("retain_sequence") else actor.mark_dead()
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
   var kind:String=event.kind
   if event.serial<=last_event_serial:continue
   if collect_stats:
    event_gaps+=maxi(0,event.serial-last_event_serial-1);observed_counts[kind]=int(observed_counts.get(kind,0))+1
   last_event_serial=event.serial
   if kind=="status" and int(event.get("action_index",0)) in [6010,6011]:
    var moving_id=int(event.source_id) if event.action_index==6010 else int(event.target_id)
    if moving_id==0:
     if event.action_index==6010:game.player.timed_dodge.begin_rescue(event)
     else:
      game.player.move_and_collide(event.direction-game.player.global_position)
    elif event.action_index==6010:
     var pet_owner=get("pet_skills")
     if pet_owner!=null:
      for caster in pet_owner.casters.values():
       if caster.gate_id!=moving_id:continue
       caster.finish_cast()
       for controller in caster.controllers.values():controller.cancel()
   if kind=="attack_started":game.model.waves.enemy_started_attack(int(event.source_id))
   if kind=="status" and int(event.get("action_index",0)) in range(790,796) and event.get("external_kind",-1)==0:game.player.apply_cursed_affliction(int(event.action_index)-790,float(event.amount),int(event.source_id))
   if kind=="status" and event.get("action_index")==782:game.model.waves.reinforce_decree(event.source_id)
   if kind=="status" and event.get("action_index")==775:game.model.waves.reinforce_falken(event.source_id,int(event.amount))
   if kind=="status" and int(event.get("unit_kind",-1))==17 and int(event.get("action_index",0))==210 and game.player.combat_hold_source==int(event.source_id):game.player.combat_hold_left=maxf(game.player.combat_hold_left,float(event.amount))
   if kind=="status" and int(event.get("action_index",0))>=400 and int(event.get("action_index",0))!=6000 and int(event.get("action_index",0)) not in range(790,796) and int(event.get("unit_kind",0))>=101:mirror_action.emit(event)
   if kind=="status" and event.get("unit_kind") in [ZombieMoves.ROLE,19] and event.get("action_index")==ZombieMoves.HEAL and event.get("amount",0)>0:
    var healed=enemies.get(event.source_id)
    if is_instance_valid(healed):healed.hp=event.hp
    if game.model.enemies.has(event.source_id):game.model.enemies[event.source_id].hp=event.hp
   if kind=="status" and event.get("unit_kind")==ZombieMoves.ROLE and event.get("action_index")==Grave.MAGIC_SEAL:
    game.player.spell_loadout.seal_for(event.amount)
    game.toast("魔封攻擊" if game.model.falan_floor==51030 else "Parukes's Ghost · Magic Seal")
   if kind=="status" and event.get("unit_kind")==ZombieMoves.ROLE and event.get("action_index")==Ruby.CONFUSED and event.get("external_kind",-1)==0:
    if game.player.hp<=0 or game.player.invuln>0 or game.player.crossgate_combo_protected():continue
    if game.player.character_id==33 and game.player.active_ability.spell_immune():continue
    game.player.confusion_left=maxf(game.player.confusion_left,event.amount)
   if kind in ["pet_skill_started","pet_skill_contact","pet_skill_move"]:
    var pet_owner=get("pet_skills")
    if pet_owner!=null:pet_owner.receive(event)
    if record_events:event_log.append(event)
    continue
   # Most events only feed pooled visuals/audio; they need no actor or ticket.
   if kind!="damage" and kind!="death" and kind!="external_damage":
    presentation_events.append(event)
    if record_events:event_log.append(event)
    continue
   var gameplay=kind=="damage" or kind=="death"
   var actor=(enemies.get(event.target_id) if event.team==0 else allies.get(event.target_id)) if gameplay else null
   var ticket:Dictionary=tickets.get(event.ticket_id,NO_TICKET) if gameplay else NO_TICKET
   var quiet_contact:bool=ticket.get("quiet_contact",false)
   if quiet_contact:event.quiet_contact=true
   match kind:
    "damage":
     record_pet_participation(event)
     event.critical=event.get("critical",false) or ticket.get("critical",false)
     if ticket.has("impact_scale"):event.impact_scale=ticket.impact_scale
     if ticket.get("shin_area_impact",false):event.shin_area_impact=true
     if ticket.has("impact_point"):event.impact_point=ticket.impact_point
     if ticket.has("sure_strike_effect"):event.sure_strike_effect=ticket.sure_strike_effect
     if ticket.has("combo_hit_effect"):event.combo_hit_effect=ticket.combo_hit_effect
     if ticket.get("guard_break_ex",false):event.guard_break_ex=true
     if ticket.has("guard_break_scale"):event.guard_break_scale=ticket.guard_break_scale
     if event.team==0 and is_instance_valid(actor):actor.set_enemy_kind(int(event.unit_kind))
     if is_instance_valid(actor):
      var data=unit_state(actor.handle)
      if data.is_empty():actor.hp=event.hp
      else:actor.sync(data)
      if event.team==0 and event.get("action_index",0)==722:
       event.guard_break_head=actor.combat_head()
       event.guard_break_target=weakref(actor)
     if game.model.enemies.has(event.target_id) and event.team==0:game.model.enemies[event.target_id].hp=event.hp;game.model.enemies[event.target_id].variant=event.unit_kind
     if not quiet_contact and not pooled_presentation and event.team==0 and event.source_id>=0 and (not ticket.get("tower",false) or ticket.get("tower_feedback",false)):
      game.damage_number(event.position,int(event.amount),event.heavy,event.critical)
    "death":
     var pet_owner=get("pet_skills")
     if event.team==1 and pet_owner!=null:pet_owner.retire(int(handles.get(event.target_id,0)))
     if is_instance_valid(actor):actor.mark_dead(true) if actor.has_method("retain_sequence") else actor.mark_dead()
     if is_instance_valid(actor) and actor.get("sequence_users")!=null and actor.sequence_users>0:event.overkill_target=weakref(actor)
     handles.erase(event.target_id)
     if event.team==0:
      _enemy_retired(event.target_id)
      var row:Dictionary=game.model.enemies.get(event.target_id,{"id":event.target_id,"pos":event.position,"variant":event.unit_kind})
      game.model.waves.enemy_defeated(row)
      preload("res://scripts/forest/forest_soldier_audio.gd").soldier_died(game,event.position,event.unit_kind)
      game.kills+=1
      game.model.aggro_kills+=1
      if row.has("habaru_slot"):
       var tree:SceneTree=game.get_tree()
       var slain:Dictionary=tree.get_meta("habaru_slain",{})
       slain[row.habaru_slot]=true
       tree.set_meta("habaru_slain",slain)
       if slain.size()==10:game.toast("Habaru Cave cleared")
      if row.has("habaru_slime_slot"):
       var tree:SceneTree=game.get_tree()
       var slain:Dictionary=tree.get_meta(Habaru.SLIME_SLAIN,{})
       slain[row.habaru_slime_slot]=true
       tree.set_meta(Habaru.SLIME_SLAIN,slain)
      if row.has("venoa_bear_slot"):
       var tree:SceneTree=game.get_tree()
       var slain:Dictionary=tree.get_meta(Habaru.VENOA_SLAIN,{})
       slain[row.venoa_bear_slot]=true
       tree.set_meta(Habaru.VENOA_SLAIN,slain)
       if row.skin==Habaru.VENOA_BOSS_SKIN:game.toast(Habaru.VENOA_BOSS_NAME+" defeated")
      if row.has("undersea_slot"):
       var tree:SceneTree=game.get_tree()
       var slain:Dictionary=tree.get_meta(Undersea.SLAIN,{})
       slain[row.undersea_slot]=true
       tree.set_meta(Undersea.SLAIN,slain)
       if row.undersea_slot==0:game.toast(Undersea.BOSS_NAME+" defeated")
      if row.has("frostpass_slot"):
       var route=preload("res://scripts/forest/forest_frostpass.gd")
       var slain:Dictionary=get_tree().get_meta(route.SLAIN,{})
       slain[row.frostpass_slot]=true
       get_tree().set_meta(route.SLAIN,slain)
      if row.has("university_battle"):
       preload("res://scripts/forest/forest_university_region.gd").defeated(get_tree(),row)
      if row.has("elsa_battle"):
       load("res://scripts/forest/forest_elsa_route.gd").defeated(get_tree(),row)
      if row.has("falken_slot"):
       var route=preload("res://scripts/forest/forest_falken_route.gd")
       var slain:Dictionary=get_tree().get_meta(route.SLAIN,{})
       slain[row.falken_slot]=true
       get_tree().set_meta(route.SLAIN,slain)
       if row.skin==0:game.toast("法爾肯已擊敗 · 可沿原路返回索奇亞")
      if row.has("map_patrol_slot"):
       var tree:SceneTree=game.get_tree()
       var slain:Dictionary=tree.get_meta("map_patrol_slain",{})
       slain[row.map_patrol_slot]=true
       tree.set_meta("map_patrol_slain",slain)
      if row.has("zombie_slot"):
       var tree:SceneTree=game.get_tree()
       var slain:Dictionary=tree.get_meta("zombie_slain",{})
       slain[row.zombie_slot]=true
       tree.set_meta("zombie_slain",slain)
       if row.zombie_slot==0:game.toast("Modified Zombie defeated · Exit open")
      if row.has("captain_slot"):
       var tree:SceneTree=game.get_tree()
       var slain:Dictionary=tree.get_meta(Captain.SLAIN,{})
       slain[row.captain_slot]=true
       tree.set_meta(Captain.SLAIN,slain)
       if slain.size()==Freyja.CAPTAIN_FORMATION.size():game.toast("Crew defeated · Memorial open")
      if row.get("grave_slot",-1)>=0:
       var tree=game.get_tree()
       var slain:Dictionary=tree.get_meta(Grave.SLAIN,{})
       slain[row.grave_slot]=true
       tree.set_meta(Grave.SLAIN,slain)
       if row.grave_slot==3:game.toast("Parukes defeated · Return to Ghana")
      if row.has("black_prayer_slot"):
       var tree=game.get_tree()
       var slain:Dictionary=tree.get_meta(Prayer.SLAIN,{})
       slain[row.black_prayer_slot]=true
       tree.set_meta(Prayer.SLAIN,slain)
      if row.has("ruby_slot"):
       var tree=game.get_tree()
       var slain:Dictionary=tree.get_meta(Ruby.SLAIN,{})
       slain[row.ruby_slot]=true
       tree.set_meta(Ruby.SLAIN,slain)
       if slain.size()==Freyja.RUBY_FORMATION.size():game.toast("Black Prayer cleared · Way to Fengnu's House open")
      row.hp=event.hp;game.model.ryo.award_enemy_bounty(row)
      if is_instance_valid(actor):game.remember_defeat(actor)
      if game.has_method("award_team_kill"):
       event.xp_reward_tenths=int(row.get("xp_reward_tenths",10))
       game.award_team_kill(event.xp_reward_tenths,int(event.source_id),int(event.target_id))
      if event.source_id==0 and not ticket.get("tower",false) and not ticket.get("allied",false):
       if not game.has_method("award_team_kill"):game.player.award_kill()
       if game.player.hp>0:game.player.hp=minf(game.player.max_hp,game.player.hp+9)
    "external_damage":
     match int(event.external_kind):
      0:
       var before:float=game.player.hp
       if int(event.get("unit_kind",-1))==18 and int(event.get("action_index",0))==301 and event.amount<=0 and game.player.invuln<=0 and before>0 and not game.tuning.invincible and not game.player.crossgate_combo_protected():
        if not (Hero.RogueRoster.has_crossgate_throws(game.player.character_id) and game.player.active_ability.assassinating()) and not game.player.try_kagerou_dodge(event.direction):
         game.player.velocity+=event.direction*24
         if game.player.is_rogue_character():game.player.active_ability.receive_knockback(event.direction,24)
       var magical=event.get("magical",false) or int(event.get("unit_kind",-1))==18 or (int(event.get("unit_kind",-1))==17 and event.projectile) or (int(event.get("unit_kind",-1))==4 and int(event.get("action_index",0)) in [103,105]) or (int(event.get("unit_kind",-1))==ZombieMoves.ROLE and (Ruby.magic_attack(int(event.get("action_index",0))) or int(event.get("action_index",0)) in [770,771,780,783]))
       if magical and game.player.character_id==33 and game.player.active_ability.spell_immune():continue
       var action:int=event.get("action_index",0)
       if event.get("intercepted",false) and game.player.timed_dodge.rescue_left>0:game.player.timed_dodge.tick_rescue(game.player.timed_dodge.rescue_left)
       game.player.take_hit_from(event.amount,event.direction if int(event.get("unit_kind",-1))==18 and action==301 else (game.player.position-event.position).normalized(),event.projectile,int(event.source_id),action==718 or event.get("intercepted",false),action==722,magical,action==783,event.get("intercepted",false))
       if action==722:
        if game.player.hp>=before:continue
        event.position=game.player.global_position+Vector3.UP*game.player.model.standing_height()*.55
       if event.unit_kind==ZombieMoves.ROLE and event.action_index in [ZombieMoves.DRAIN,770] and game.player.hp<before:
        native.confirm_zombie_drain(event.ticket_id,before-game.player.hp)
       if int(event.get("unit_kind",-1))==18 and int(event.get("action_index",0))==301 and game.player.hp<before:
        game.player.velocity+=event.direction*17
        if game.player.is_rogue_character():game.player.active_ability.receive_knockback(event.direction,17)
       if int(event.get("unit_kind",-1))==17 and int(event.get("action_index",0))==1 and game.player.hp<before:
        game.player.combat_hold_source=int(event.source_id);game.player.combat_hold_left=.15;game.player.cancel_charge()
       if int(event.get("unit_kind",-1))==4 and int(event.get("action_index",0))==105 and game.player.hp<before:game.player.skullpion_poison_left=4.0
      1:game.model.damage_worker(event.target_id,event.amount)
      2:game.model.damage_building(event.target_id,event.amount)
   presentation_events.append(event)
   if record_events:event_log.append(event)
   if kind=="death":unit_died.emit(event)
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
 if model.get("falan_area") in["il_village","east_gate"]:
  if il_source_caps==null:il_source_caps=load("res://scripts/forest/forest_east_il_source_completion.gd")
  il_source_caps.install(model)
 var region:Rect2i=model.navigation_region
 var data={"width":0,"spacing":3.0,"origin":Vector3(-240,0,-240),"bounds_min":Vector3(-243,0,-243),"bounds_max":Vector3(237,0,237),"heights":PackedFloat32Array(),"covered":PackedByteArray(),"obstacle_min":PackedVector3Array(),"obstacle_max":PackedVector3Array(),"layer_min":PackedVector3Array(),"layer_max":PackedVector3Array(),"pieces":PackedFloat32Array(),"ray_min":PackedVector3Array(),"ray_max":PackedVector3Array(),"ray_owner":PackedInt64Array()}
 data.bounds_min=Vector3(region.position.x*6-3,0,region.position.y*6-3)
 data.bounds_max=Vector3(region.end.x*6-3,0,region.end.y*6-3)
 if terrain.has_method("contains"):
  data.width=terrain.width;data.spacing=terrain.spacing;data.heights=terrain.heights;data.covered=terrain.covered
  if terrain.has_method("native_diagonal_flips"):
   var flips:PackedByteArray=terrain.native_diagonal_flips()
   if not flips.is_empty():data.diagonal_flips=flips
  var origin:Vector2=-terrain.coordinate(0,0)*terrain.spacing
  data.origin=Vector3(origin.x,0,origin.y)
 var recovery=preload("res://scripts/forest/forest_original_maps.gd")
 if model.get("falan_area")=="interior" and (recovery.owns(model.falan_floor) or model.falan_floor==13001):
  # Great Wind exceeds the native flat-terrain fallback after map scaling.
  var floor_=preload("res://scripts/forest/forest_falan_interior.gd").floor_info(model.falan_floor,model.seed_value)
  data.width=maxi(floor_[0].x,floor_[0].y)+1
  data.origin=Vector3(floor_[1].x,0,floor_[1].y);data.spacing=3.0;data.route_spacing=3.0
  data.heights.resize(data.width*data.width);data.covered.resize(data.width*data.width);data.covered.fill(1)
 if model.get("falan_area")=="interior" and (model.falan_floor in model.CellarArt.RAISED_FLOORS or model.falan_floor==1511 or model.falan_floor in model.CivicExterior.Mansion.STAGES or model.falan_floor in model.CivicExterior.Arena.RAISED):
  # The player already stands on these raised floors; native queries need the same surface.
  var floor_=preload("res://scripts/forest/forest_falan_interior.gd").floor_info(model.falan_floor,model.seed_value)
  data.width=maxi(floor_[0].x,floor_[0].y)*2+1;data.spacing=1.5;data.route_spacing=1.5
  data.origin=Vector3(floor_[1].x,0,floor_[1].y)
  data.heights.resize(data.width*data.width);data.covered.resize(data.width*data.width);data.covered.fill(1)
  for z in data.width:
   for x in data.width:data.heights[z*data.width+x]=model.surface_height(data.origin.x+x*data.spacing,data.origin.z+z*data.spacing)
 if model.get("falan_area")=="interior" and model.get("falan_floor")==43700:
  preload("res://scripts/forest/forest_east_lektal_annexes.gd").add_navigation(data)
 if model.get("falan_area")=="interior" and model.get("falan_floor")==model.FalkenArt.Route.ROOM:
  preload("res://scripts/forest/forest_falken_dais.gd").add_navigation(data)
 if model.get("falan_area")=="interior" and preload("res://scripts/forest/forest_elsa_hall_steps.gd").owns(model.get("falan_floor")):
  preload("res://scripts/forest/forest_elsa_hall_steps.gd").add_navigation(data,model.falan_floor)
 # Preserve authored rampart formulae instead of rasterizing decks/ramp edges.
 for piece in terrain.pieces:
  data.pieces.append_array(PackedFloat32Array([piece.a.x,piece.a.y,piece.along.x,piece.along.y,piece.half,piece.length,piece.start,piece.end,piece.h0,piece.h1]))
 data.friendly_navigation=true;data.friendly_obstacle_min=PackedVector3Array();data.friendly_obstacle_max=PackedVector3Array()
 if include_obstacles:
  # Enemy-only source city/village boundaries preserve friendly navigation.
  for box:AABB in model.FalanFrontier.enemy_barriers(model):
   data.obstacle_min.append(box.position);data.obstacle_max.append(box.end)
  if model.has_meta("cave_combat_walls"):
   for box:AABB in model.get_meta("cave_combat_walls"):
    data.obstacle_min.append(box.position);data.obstacle_max.append(box.end)
    data.friendly_obstacle_min.append(box.position);data.friendly_obstacle_max.append(box.end)
    data.ray_min.append(box.position);data.ray_max.append(box.end);data.ray_owner.append(-1)
  var profile=preload("res://scripts/forest/forest_structure_profile.gd")
  for building in model.buildings.values():
   if building.hp<=0:continue
   var size:Vector2i=model.dimensions(building.kind,building.rotation,building.get("span",0))
   var first:Vector3=model.point(building.cell)-Vector3(3,0,3)
   first.y=model.center(building).y
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
  if model.get("enemy_camps_prototype")==true or model.get("terrain_source")=="wind_meadow":
   for box:AABB in preload("res://scripts/forest/forest_camp_prototype.gd").obstacles(model):
    data.obstacle_min.append(box.position);data.obstacle_max.append(box.end)
    data.friendly_obstacle_min.append(box.position);data.friendly_obstacle_max.append(box.end)
    data.ray_min.append(box.position);data.ray_max.append(box.end);data.ray_owner.append(-1)
  for cell in model.trees:
   if model.tree_rotations.has(cell):continue
   var center:Vector3=model.scenery_point(cell)
   data.ray_min.append(center+Vector3(-1.5,0,-1.5));data.ray_max.append(center+Vector3(1.5,12,1.5));data.ray_owner.append(-1)
   # Ground routing uses the same trunk footprint as existing navigation.
   data.obstacle_min.append(center+Vector3(-1.25,0,-1.25));data.obstacle_max.append(center+Vector3(1.25,1000,1.25))
   data.friendly_obstacle_min.append(center+Vector3(-1.25,0,-1.25));data.friendly_obstacle_max.append(center+Vector3(1.25,1000,1.25))
  for cell in model.scenery_obstacles:
   if model.trees.has(cell) and not model.tree_rotations.has(cell):continue
   var box:AABB=model.scenery_obstacles[cell]
   data.ray_min.append(box.position);data.ray_max.append(box.end);data.ray_owner.append(-1)
   data.obstacle_min.append(box.position);data.obstacle_max.append(box.end)
   data.friendly_obstacle_min.append(box.position);data.friendly_obstacle_max.append(box.end)
 var context=ContextRegions.private_source_context
 if context!=null:context.add_navigation(data,model)
 var scale_value=model.get("falan_scale")
 var map_scale:float=1.0 if scale_value==null else scale_value
 if map_scale!=1.0:
  data.spacing*=map_scale
  if data.has("route_spacing"):data.route_spacing*=map_scale
  data.origin*=map_scale
  data.bounds_min*=map_scale
  data.bounds_max*=map_scale
  var heights:PackedFloat32Array=data.heights.duplicate()
  for i in heights.size():heights[i]*=map_scale
  data.heights=heights
  for i in range(0,data.pieces.size(),10):
   for j in [0,1,4,5,6,7,8,9]:data.pieces[i+j]*=map_scale
  var transform_=Transform3D(Basis.from_scale(Vector3.ONE*map_scale),Vector3.ZERO)
  for key in ["obstacle_min","obstacle_max","friendly_obstacle_min","friendly_obstacle_max","layer_min","layer_max","ray_min","ray_max"]:
   data[key]=transform_*data[key]
 return data
