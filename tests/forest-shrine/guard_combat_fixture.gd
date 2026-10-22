extends RefCounted
## Combat-only fixtures create a single native ally without exercising the shop.
## Paid preparation placement and forbidden wave hiring live in guard_hiring_test.
static func deploy(director,slot:int)->bool:
 var game=director.game
 if slot<0 or slot>=director.KITS.size() or not game.playing or game.player.hp<=0 or game.ordinary_pause or game.settings_open or game.rogue_roster_open or game.model.phase not in ["preparing","wave"] or (game.paused and game.model.phase=="wave"):return false
 var target=director.closest_target(game.player.global_position) if game.model.phase=="wave" else null
 var center=target.global_position if target!=null else game.player.global_position
 var point=Vector3.INF
 for attempt in 48:
  var angle=attempt*TAU/16.0+director.summon_serial*.61
  var gap=(12.0 if slot==1 else 4.0)+float(attempt/16)*2.0
  var candidate=center+Vector3(sin(angle),0,cos(angle))*gap
  var cell=game.model.cell_of(candidate)
  if not game.model.ALLIED_REGION.has_point(cell) or game.model.allied_grid.is_point_solid(cell):continue
  candidate.y=game.model.surface_height(candidate.x,candidate.z)+.12
  if director.active_units().any(func(unit):return unit.global_position.distance_to(candidate)<1.1):continue
  var query=PhysicsShapeQueryParameters3D.new();query.shape=director.placement_shape;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,candidate+Vector3.UP*.95)
  if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
  point=candidate;break
 if not point.is_finite():return false
 if slot==0 and target!=null:point=center+Vector3.UP*12
 var ready=director.pool.filter(func(unit):return unit.slot==slot and unit.state=="idle")
 var ally=ready[0] if not ready.is_empty() else director.make_unit(slot)
 ally.summon(target,point,.12)
 director.summon_serial+=1;director.sync_targets()
 return true
