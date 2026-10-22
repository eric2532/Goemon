extends Node
## Paid mercenaries keep preparation positions and hunt across the battlefield.
const Unit=preload("res://scripts/forest/explorer_helper_unit.gd")
const KITS=[8,10,5,7,11]
const COUNTS=[1,1,1,1,1]
const COSTS=[120,60,60,150,80]
const GUARD_RADIUS=18.0
const NAMES=["Dragoon","Ranger","Ninja","Knight","Explorer"]
const HEALTH=[200,100,100,500,200]
const LABELS=["Dragoon · 200 HP · Spear combat","Ranger · 100 HP · Rapid shots","Ninja · 100 HP · Shadow Cut","Knight · 500 HP · Shield counters","Explorer · 200 HP · Blade combos"]
var game
var pool:Array=[]
var actors:Dictionary={}
var next_actor_id=-1000
var summon_serial=0
var smoke:Node3D
var rigid_renderer:Node3D
var target_rows:Array=[]
var target_frame=Vector2i(-1,-1)
var target_model
var target_population=-1
var target_generation=0
var living_count=0
var selected_slot=-1
var moving_actor=0
var placement_hint=""
var guard_preview:MeshInstance3D
var preview_material:StandardMaterial3D
var preview_position=Vector3.INF
var placement_shape:CapsuleShape3D
const QUERY_CELL=4.0
var melee_grid:Dictionary={}
var projectile_grid:Dictionary={}
var melee_overflow:Array=[]
var projectile_overflow:Array=[]
var melee_rows:Array=[]
var projectile_actors:Array=[]
var projectile_centers=PackedVector3Array()
var projectile_radii=PackedFloat64Array()
var projectile_bounds:Array[AABB]=[]
var projectile_minimum=Vector3.INF
var projectile_maximum=-Vector3.INF
var native_filter:Object
var melee_lows=PackedVector3Array()
var melee_highs=PackedVector3Array()
var projectile_lows=PackedVector3Array()
var projectile_highs=PackedVector3Array()
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 smoke=preload("res://assets/rogue/scripts/effects.gd").new();smoke.name="HelperSmoke";smoke.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(smoke);smoke.apply_quality(0);smoke.effect_budget=108
 rigid_renderer=preload("res://scripts/forest/ally_rigid_renderer.gd").new();add_child(rigid_renderer)
 placement_shape=CapsuleShape3D.new();placement_shape.radius=.4;placement_shape.height=1.85
 guard_preview=MeshInstance3D.new();guard_preview.name="GuardAreaPreview";guard_preview.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 preview_material=StandardMaterial3D.new();preview_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;preview_material.no_depth_test=true
 guard_preview.material_override=preview_material;game.add_child(guard_preview);guard_preview.hide()
 for slot in KITS.size():
  for i in COUNTS[slot]:make_unit(slot)
func make_unit(slot:int):
 var unit=preload("res://scripts/forest/crowd/army_helper_unit.gd").new() if is_instance_valid(game.army_runtime) else Unit.new()
 if is_instance_valid(game.army_runtime):unit.runtime=game.army_runtime
 unit.name="Ally_%d"%absi(next_actor_id);unit.game=game;unit.director=self;unit.kit_id=KITS[slot];unit.slot=slot;unit.gate_id=next_actor_id;next_actor_id-=1
 unit.process_mode=Node.PROCESS_MODE_PAUSABLE;game.add_child(unit);pool.append(unit);actors[unit.gate_id]=unit
 if not is_instance_valid(game.army_runtime):rigid_renderer.register_actor(unit.model.actor)
 return unit
func valid_target(enemy)->bool:
 return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.dead and enemy.hp>0 and not enemy.training_dummy and game.forest_enemy_visible(enemy)
func closest_target(origin:Vector3,max_distance:float=INF):
 refresh_targets()
 # Any contact closer than this local square is necessarily indexed in it.
 # Preserve the exact native nearest-contact refinement and tie order; fall
 # back to the full snapshot when no nearby target can prove the result.
 var near_distance=minf(8.0,absf(max_distance))
 var near=_closest_from_rows(melee_candidates(origin,near_distance),origin,near_distance)
 if near!=null or absf(max_distance)<=near_distance:return near
 return _closest_from_rows(target_rows,origin,max_distance)
func _closest_from_rows(rows:Array,origin:Vector3,max_distance:float):
 var best=null;var distance=max_distance*max_distance
 var first=null;var lower=distance
 # Fit the closest box first so input order cannot make every successive
 # enemy trigger another expensive narrow contact query.
 for row in rows:
  var enemy=row.enemy
  if not is_instance_valid(enemy) or enemy.dead or enemy.hp<=0 or enemy.training_dummy:continue
  var box:AABB=row.bounds
  var gap=origin.distance_squared_to(origin.clamp(box.position,box.end))
  if gap<lower:first=enemy;lower=gap
 if first!=null and valid_target(first):
  var gap=origin.distance_squared_to(AttackChain.aim_point(first,origin+Vector3.UP))
  if gap<distance:best=first;distance=gap
 for row in rows:
  var enemy=row.enemy
  if enemy==first or not is_instance_valid(enemy) or enemy.dead or enemy.hp<=0 or enemy.training_dummy:continue
  # Bounds give a safe lower distance before paying for a fitted contact hull.
  var box:AABB=row.bounds
  if origin.distance_squared_to(origin.clamp(box.position,box.end))>=distance:continue
  if not valid_target(enemy):continue
  var gap=origin.distance_squared_to(AttackChain.aim_point(enemy,origin+Vector3.UP))
  if gap<distance:best=enemy;distance=gap
 return best
func refresh_targets():
 var frame=Vector2i(Engine.get_physics_frames(),Engine.get_process_frames())
 if target_frame==frame and target_model==game.model and target_population==game.model.next_id:return
 native_filter=game.get("army_runtime").native if is_instance_valid(game.get("army_runtime")) else null
 melee_lows=PackedVector3Array();melee_highs=PackedVector3Array();projectile_lows=PackedVector3Array();projectile_highs=PackedVector3Array()
 target_generation+=1
 target_frame=frame;target_model=game.model;target_population=game.model.next_id;target_rows.clear()
 # Active ally projectile queries retain these packed arrays by reference.
 # Replace the buffers so a nested refresh cannot mutate captured geometry.
 projectile_actors.clear();projectile_centers=PackedVector3Array();projectile_radii=PackedFloat64Array();projectile_bounds.clear();projectile_minimum=Vector3.INF;projectile_maximum=-Vector3.INF
 melee_grid.clear();projectile_grid.clear();melee_overflow.clear();projectile_overflow.clear();melee_rows.clear()
 for enemy in game.enemies:
  if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.dead or enemy.hp<=0 or not game.forest_enemy_visible(enemy):continue
  var has_bounds=enemy.has_method("combat_bounds")
  var box:AABB=enemy.combat_bounds() if has_bounds else AABB(enemy.global_position-Vector3.ONE*enemy.body_radius,Vector3.ONE*enemy.body_radius*2)
  var row={"enemy":enemy,"bounds":box}
  if not enemy.training_dummy:target_rows.append(row)
  var melee_box=box.grow(maxf(0,enemy.body_radius))
  if native_filter!=null:melee_lows.append(melee_box.position);melee_highs.append(melee_box.end)
  else:_index_bounds(melee_grid,melee_overflow,melee_box,melee_rows.size())
  melee_rows.append(row)
  var center:Vector3=box.get_center() if has_bounds else AttackChain.aim_point(enemy)
  var radius:float=box.size.length()*.5 if has_bounds else enemy.body_radius
  # Only box contacts have a bounded local-axis padding. Detailed convex
  # hulls retain the original enclosing sphere used by native projectiles.
  var tight=has_bounds and enemy.has_method("_uses_block_contacts") and enemy._uses_block_contacts()
  var projectile_box:AABB=box if tight else AABB(center-Vector3.ONE*radius,Vector3.ONE*radius*2)
  if native_filter!=null:projectile_lows.append(projectile_box.position);projectile_highs.append(projectile_box.end)
  else:_index_bounds(projectile_grid,projectile_overflow,projectile_box,projectile_actors.size())
  projectile_bounds.append(projectile_box)
  projectile_actors.append(enemy);projectile_centers.append(center);projectile_radii.append(radius)
  projectile_minimum=projectile_minimum.min(center-Vector3.ONE*radius);projectile_maximum=projectile_maximum.max(center+Vector3.ONE*radius)
func _index_bounds(grid:Dictionary,overflow:Array,box:AABB,index:int):
 if not box.position.is_finite() or not box.size.is_finite():overflow.append(index);return
 var first=Vector2i(floori(box.position.x/QUERY_CELL),floori(box.position.z/QUERY_CELL))
 var last=Vector2i(floori(box.end.x/QUERY_CELL),floori(box.end.z/QUERY_CELL))
 # Unusual/custom geometry remains queryable without filling an enormous grid.
 if (last.x-first.x+1)*(last.y-first.y+1)>256:overflow.append(index);return
 for x in range(first.x,last.x+1):
  for z in range(first.y,last.y+1):
   var key=Vector2i(x,z)
   if not grid.has(key):grid[key]=[]
   grid[key].append(index)
func _query_grid(grid:Dictionary,overflow:Array,minimum:Vector3,maximum:Vector3,count:int)->Array:
 if not minimum.is_finite() or not maximum.is_finite():return range(count)
 var first=Vector2i(floori(minimum.x/QUERY_CELL),floori(minimum.z/QUERY_CELL))
 var last=Vector2i(floori(maximum.x/QUERY_CELL),floori(maximum.z/QUERY_CELL))
 if (last.x-first.x+1)*(last.y-first.y+1)>256:return range(count)
 var seen={}
 for index in overflow:seen[index]=true
 for x in range(first.x,last.x+1):
  for z in range(first.y,last.y+1):
   for index in grid.get(Vector2i(x,z),[]):seen[index]=true
 var indices=seen.keys();indices.sort() # Preserve native enemy/hit order.
 return indices
func melee_candidates(center:Vector3,radius:float)->Array:
 refresh_targets()
 if not center.is_finite() or radius<0 or radius>=INF:return melee_rows
 var pad=Vector3.ONE*radius
 var result=[]
 var indices=Array(native_filter.filter_boxes(melee_lows,melee_highs,Vector3(center.x-radius,-INF,center.z-radius),Vector3(center.x+radius,INF,center.z+radius))) if native_filter!=null else _query_grid(melee_grid,melee_overflow,center-pad,center+pad,melee_rows.size())
 for index in indices:result.append(melee_rows[index])
 return result
func projectile_candidates(minimum:Vector3,maximum:Vector3)->Array:
 # The native filter reads these owned packed bounds, never live/newer units.
 if native_filter!=null:return Array(native_filter.filter_boxes(projectile_lows,projectile_highs,minimum,maximum))
 # Called inside the owner's synchronous projectile snapshot.
 var result=[]
 for index in _query_grid(projectile_grid,projectile_overflow,minimum,maximum,projectile_actors.size()):
  var box:AABB=projectile_bounds[index]
  if box.position.is_finite() and box.size.is_finite() and (box.end.x<minimum.x or box.position.x>maximum.x or box.end.y<minimum.y or box.position.y>maximum.y or box.end.z<minimum.z or box.position.z>maximum.z):continue
  result.append(index)
 return result
func active_units(slot:int=-1)->Array:
 return pool.filter(func(u):return u.state in Unit.LIVE_STATES and u.hp>0 and (slot<0 or u.slot==slot))
func allies_can_remain()->bool:
 # A dead player with a pending respawn still owns a living battlefield.
 return game.playing and game.model.phase in ["wave","preparing"] and (game.player.hp>0 or game.respawn_left>0)
func available()->bool:
 var editor=is_instance_valid(game.map_editor) and game.map_editor.active
 var panel=game.forest_ui.get_node_or_null("GateDefenderPanel")
 return game.playing and game.model.phase=="preparing" and game.player.hp>0 and not editor and not is_instance_valid(panel) and not game.transitioning and not game.ordinary_pause and not game.settings_open and not game.rogue_roster_open and not game.won
func placement_active()->bool:return selected_slot>=0 or moving_actor!=0
func cancel_placement(close_shop:bool=true):
 selected_slot=-1;moving_actor=0;placement_hint="";preview_position=Vector3.INF
 if is_instance_valid(guard_preview):guard_preview.hide()
 if close_shop and is_instance_valid(game.forest_ui):game.forest_ui.close_guard_shop()
func request(slot:int)->bool:
 # Retain the command entry point, but it only selects paid map placement.
 return begin_placement(slot)
func begin_placement(slot:int)->bool:
 if slot<0 or slot>=KITS.size() or not available():return false
 if game.model.gold<COSTS[slot]:game.toast("Need %d ryo to hire a %s"%[COSTS[slot],NAMES[slot]]);return false
 if not game.model.can_recruit(2):game.toast("Need 2 food · Build a barracks");return false
 if is_instance_valid(game.army_runtime) and active_units().size()>=2000:game.toast("Ally limit reached");return false
 cancel_placement(false);selected_slot=slot
 game.build_kind="";game.world.preview.hide();game.forest_ui.selected_id=-1
 game.toast("%s · %d ryo · Click clear ground to assign a guard post"%[NAMES[slot],COSTS[slot]])
 return true
func stand_point(point:Vector3)->Vector3:
 return Vector3(point.x,game.model.surface_height(point.x,point.z)+.12,point.z)
func placement_error(slot:int,point:Vector3,exclude:int=0)->String:
 if slot<0 or slot>=KITS.size():return "Choose an ally"
 if not available():return "Assign guards during preparation"
 if not point.is_finite():return "Choose clear ground"
 if exclude==0:
  if game.model.gold<COSTS[slot]:return "Not enough ryo"
  if not game.model.can_recruit(2):return "Need 2 food · Build a barracks"
  if is_instance_valid(game.army_runtime) and active_units().size()>=2000:return "Ally limit reached"
 var m=game.model;var cell=m.cell_of(point)
 if not m.ALLIED_REGION.has_point(cell):return "Beyond the settlement boundary"
 if not m.explored.has(cell):return "Unexplored terrain"
 if m.allied_grid.is_point_solid(cell):return "Choose walkable ground"
 if m.occupancy.has(cell) and m.buildings[m.occupancy[cell]].kind!="gate":return "A building occupies this spot"
 if cell==m.TRAINING_DUMMY_CELL:return "Keep the training dummy clear"
 for portal in m.portals:
  if cell in m.portal_cells(portal):return "Keep the spawn portal clear"
 var stand=stand_point(point)
 for unit in active_units():
  if unit.gate_id==exclude:continue
  if unit.global_position.distance_to(stand)<1.4 or unit.guard_post.distance_to(stand)<1.4:return "Another ally guards this spot"
 for unit in game.gate_defenders.units.values():
  if is_instance_valid(unit) and unit.position.distance_to(stand)<1.4:return "A gate defender occupies this spot"
 var query=PhysicsShapeQueryParameters3D.new();query.shape=placement_shape;query.collision_mask=1
 query.transform=Transform3D(Basis.IDENTITY,stand+Vector3.UP*.95)
 if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return "A wall or obstacle blocks this spot"
 return ""
func purchase(slot:int,point:Vector3)->bool:
 var reason=placement_error(slot,point)
 if not reason.is_empty():game.toast(reason);return false
 var ready=pool.filter(func(unit):return unit.slot==slot and unit.state=="idle")
 var unit=ready[0] if not ready.is_empty() else make_unit(slot)
 unit.summon(null,stand_point(point),0.0)
 if is_instance_valid(game.army_runtime) and unit.handle==0:game.toast("Ally limit reached");return false
 game.model.gold-=COSTS[slot];summon_serial+=1
 cancel_placement(false);sync_targets();game.forest_ui.sync()
 game.toast("%s hired · %d ryo · Guard post assigned"%[NAMES[slot],COSTS[slot]])
 return true
func relocate(actor_id:int,point:Vector3)->bool:
 var unit=target_actor(actor_id)
 if unit==null or not available():return false
 var reason=placement_error(unit.slot,point,actor_id)
 if not reason.is_empty():game.toast(reason);return false
 unit.assign_guard_post(stand_point(point));cancel_placement(false);sync_targets()
 game.toast("Guard post moved · No charge")
 return true
func guard_target_allowed(_unit,enemy)->bool:
 return valid_target(enemy)
func closest_guard_target(unit):
 # Share the spatial snapshot and refine only competitive native contacts.
 # Preparation posts no longer limit combat acquisition or pursuit.
 return closest_target(unit.global_position)
func ally_at(point:Vector3):
 var best=null;var distance=3.0*3.0
 for unit in active_units():
  var gap=Vector2(point.x-unit.guard_post.x,point.z-unit.guard_post.z).length_squared()
  if gap<distance:distance=gap;best=unit
 return best
func handle_global_input(event:InputEvent)->bool:
 if event.is_action_pressed("pause") and not event.is_echo() and (placement_active() or game.forest_ui.guard_shop_open()):
  cancel_placement();return true
 return false
func handle_map_input(event:InputEvent)->bool:
 if not available() or not event is InputEventMouseButton or not event.pressed:return false
 if event.button_index==MOUSE_BUTTON_RIGHT and placement_active():cancel_placement(false);return true
 if event.button_index!=MOUSE_BUTTON_LEFT:return false
 var point=game.ground_at(event.position)
 if selected_slot>=0:purchase(selected_slot,point);return true
 if moving_actor!=0:relocate(moving_actor,point);return true
 if not game.build_kind.is_empty():return false
 var unit=ally_at(point)
 if unit==null:return false
 cancel_placement(false);moving_actor=unit.gate_id;game.forest_ui.selected_id=-1
 game.toast("Move %s · Click a new guard post · Right-click cancels"%NAMES[unit.slot])
 return true
func update_placement_preview():
 if not available():
  if placement_active() or game.forest_ui.guard_shop_open():cancel_placement()
  guard_preview.hide();return
 if not game.build_kind.is_empty():guard_preview.hide();return
 var point=game.ground_at(game.get_viewport().get_mouse_position())
 var slot=selected_slot;var exclude=moving_actor
 if moving_actor!=0:
  var unit=target_actor(moving_actor)
  if unit==null:cancel_placement();return
  slot=unit.slot
 if slot<0:
  var hovered=ally_at(point)
  if hovered==null:guard_preview.hide();return
  point=hovered.guard_post;slot=hovered.slot;exclude=hovered.gate_id
 var error=placement_error(slot,point,exclude)
 placement_hint=(NAMES[slot]+" · "+("%d ryo · "%COSTS[slot] if selected_slot>=0 else "Move post · ")+"Click to assign · Right-click / Esc cancel") if error.is_empty() else error
 show_guard_area(point,error.is_empty())
func show_guard_area(point:Vector3,valid:bool):
 preview_material.albedo_color=Color("83d9ac") if valid else Color("eb775f")
 if not point.is_equal_approx(preview_position):
  preview_position=point
  var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
  for i in 64:
   for angle in [TAU*i/64.0,TAU*(i+1)/64.0]:
    var offset=Vector3(cos(angle),0,sin(angle))*GUARD_RADIUS
    offset.y=game.model.surface_height(point.x+offset.x,point.z+offset.z)-game.model.surface_height(point.x,point.z)+.2
    mesh.surface_add_vertex(offset)
  mesh.surface_end();guard_preview.mesh=mesh
 guard_preview.global_position=stand_point(point);guard_preview.show()
func target_actor(id:int):
 var unit=actors.get(id)
 return unit if is_instance_valid(unit) and unit.state in Unit.LIVE_STATES and unit.state!="sheltered" and unit.hp>0 else null
func sync_targets():
 if is_instance_valid(game.army_runtime) and game.army_runtime.has_method("sync_helper_mirrors"):
  living_count=game.army_runtime.sync_helper_mirrors(game.model.defenders,game.model.fighter_posts)
  game.model.fighter_count=living_count
  return
 if is_instance_valid(game.army_runtime):
  living_count=0;game.model.fighter_posts.clear()
  for unit in pool:
   var live=unit.state in Unit.LIVE_STATES and unit.hp>0
   if live:living_count+=1;game.model.fighter_posts[unit.gate_id]=unit.guard_post
   if not live or unit.state=="sheltered":game.model.defenders.erase(unit.gate_id);continue
   if not game.model.defenders.has(unit.gate_id):game.model.defenders[unit.gate_id]={"id":unit.gate_id}
   var row:Dictionary=game.model.defenders[unit.gate_id]
   row.pos=unit.global_position;row.hp=unit.hp;row.targetable=not unit.rogue_untargetable();row.taunting=unit.taunting
  game.model.fighter_count=living_count
  return
 var living=active_units()
 living_count=living.size();game.model.fighter_count=living_count
 game.model.fighter_posts.clear()
 for unit in living:game.model.fighter_posts[unit.gate_id]=unit.guard_post
 for unit in pool:
  if target_actor(unit.gate_id)==null:game.model.defenders.erase(unit.gate_id);continue
  game.model.defenders[unit.gate_id]={"id":unit.gate_id,"pos":unit.global_position,"hp":unit.hp,"targetable":not unit.rogue_untargetable(),"taunting":unit.taunting if is_instance_valid(game.army_runtime) else (unit.kit_id==7 and unit.active_ability.player.buffTime>0)}
 # Particle/ribbon capacity is shared across the army; attacks and projectiles
 # have independent lifetimes and never depend on this cosmetic budget.
 var budget=mini(16,maxi(4,240/maxi(1,living_count)))
 if not is_instance_valid(game.army_runtime):
  for unit in pool:unit.active_ability.fx.effect_budget=budget
func activate_taunt(unit):
 sync_targets()
 for enemy in game.model.enemies.values():
  if enemy.hp<=0:continue
  game.model.waves.set_target(enemy,"defender",unit.gate_id)
  enemy.action="walk";enemy.action_left=0.0;enemy.attack=false;enemy.attack_progress=0.0
  enemy.strike_kind="";enemy.strike_id=-1;enemy.route_obstacle=-1;enemy.turn_escape=[]
  var actor=game.actors.get(enemy.id)
  if is_instance_valid(actor):actor.fitted_pose_dirty=true
func remove_taunt(unit):game.model.defenders.erase(unit.gate_id)
func smoke_at(point:Vector3):smoke.smoke(point,6,Color("b8b0d4"))
func rest():
 cancel_placement()
 if is_instance_valid(game.army_runtime):game.army_runtime.rest()
 for unit in pool:
  if unit.state=="draining":unit.park()
  elif unit.state=="sheltered":unit.set_physics_process(false)
  elif unit.state in Unit.LIVE_STATES:unit.rest_between_waves()
 if is_instance_valid(smoke):smoke.clear()
 sync_targets()
func begin_wave():
 cancel_placement()
 if is_instance_valid(game.army_runtime):game.army_runtime.begin_wave()
 for unit in active_units():unit.set_physics_process(true)
func clear():
 cancel_placement()
 target_generation+=1
 for unit in pool:unit.park()
 if is_instance_valid(smoke):smoke.clear()
 living_count=0;game.model.fighter_count=0;game.model.fighter_posts.clear();target_frame=Vector2i(-1,-1);target_rows.clear();target_model=null
 melee_grid.clear();projectile_grid.clear();melee_overflow.clear();projectile_overflow.clear();melee_rows.clear()
 projectile_actors.clear();projectile_centers=PackedVector3Array();projectile_radii=PackedFloat64Array();projectile_bounds.clear()
func prune_pool():
 var reserved=[0,0,0,0,0]
 for unit in pool.duplicate():
  if unit.state!="idle":continue
  reserved[unit.slot]+=1
  if reserved[unit.slot]<=COUNTS[unit.slot]:continue
  pool.erase(unit);actors.erase(unit.gate_id);unit.queue_free()
func _process(delta):
 update_placement_preview()
 if game.model.phase=="preparing":
  if is_instance_valid(game.army_runtime):game.army_runtime.preparation_tick(delta)
  for unit in active_units():
   if unit.state=="sheltered" and not is_instance_valid(game.army_runtime):unit.shelter.tick(delta)
   unit.update_health_display()
 if not allies_can_remain():
  if not smoke.items.is_empty() or pool.any(func(u):return u.state!="idle"):clear()
  return
 if (game.model.phase=="preparing" or not game.paused) and not game.ordinary_pause and not game.settings_open and not game.rogue_roster_open and not game.transitioning:smoke.tick(delta)
 prune_pool()
