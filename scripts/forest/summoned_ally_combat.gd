extends "res://scripts/rogue_roster_combat.gd"
## Native ally combat keeps full simulation; only repeated pose work is reduced.
var reach_cache:Dictionary={}
var visual_left=0.0
var visual_elapsed=0.0
var visual_frame=-1
var pending_brush_attack:Variant=null
var support_left=0.0
var support_position=Vector3.INF
var support_revision=-1
var projectile_generation=-1
var _npc_physics_from=Vector3.INF
func physics_step(delta:float)->void:
 _npc_physics_from=hero.global_position
 super.physics_step(delta)
 _npc_physics_from=Vector3.INF
func _move_body(delta:float)->void:
 # Unchanged static ground needs no repeated CharacterBody shape casts.
 # Moving, jumping, attack impulses and changed construction use the complete
 # native controller immediately. Revalidate support at least five times/sec.
 if support_left>0 and support_position==hero.global_position and support_revision==game.model.navigation_revision and hero.is_on_floor() and hero.velocity==Vector3.ZERO and move_input==Vector3.ZERO and locomotion_velocity==Vector3.ZERO and player.vel==Vector3.ZERO and player.roll<=0 and hero.jump_buffer<=0 and not hero.can_fly() and _completed_hit_drift==Vector3.ZERO and (player.attack==null or not player.attack.get("hitDriftPending",false)) and not game.model.occupancy.has(game.model.cell_of(hero.global_position)) and absf(hero.global_position.y-game.model.surface_height(hero.global_position.x,hero.global_position.z))<.05:
  support_left-=delta
  player.dragoonHovering=false;_restore_ranger_fall();hero.coyote=.13;hero.jumps_used=0;flip_time=-1
  return
 super._move_body(delta)
 support_position=hero.global_position;support_revision=game.model.navigation_revision;support_left=.2
func fit_primary_reach(a:Dictionary)->void:
 var key=str([a.get("style",""),a.get("index",0),a.get("swingSide",1),range_scale(),melee_reach_scale(),hero.growth_multiplier(),player.buffTime>0])
 if reach_cache.has(key):
  a.merge(reach_cache[key],true);return
 super.fit_primary_reach(a)
 var fitted={}
 for field in ["reach","weaponContact","meleeVisualScale","meleeWeaponScale"]:
  if a.has(field):fitted[field]=a[field]
 reach_cache[key]=fitted
func _animate(delta:float,movement:float)->void:
 # Explicit zero-time samples reset poses and locate real projectile muzzles.
 # They are gameplay requests, so the cosmetic animation clock cannot skip them.
 if delta<=0:
  pending_brush_attack=null
  visual_left=0;visual_elapsed=0;super._animate(delta,movement);return
 if _completed_brush_attack!=null:pending_brush_attack=_completed_brush_attack
 visual_elapsed+=delta
 visual_left-=delta/maxf(.01,hero.attack_speed_multiplier())
 if visual_left>0 or visual_frame==Engine.get_process_frames():return
 visual_frame=Engine.get_process_frames()
 var center=hero.global_position+Vector3.UP*1.5
 var camera=game.camera_rig.camera
 var distance=camera.global_position.distance_squared_to(center)
 var shown=camera.is_position_in_frustum(center)
 var population=hero.director.living_count
 visual_left=.25 if not shown else (.1 if distance>3600 else (1.0/15 if population>24 or distance>900 else 1.0/30))
 if pending_brush_attack!=null:_completed_brush_attack=pending_brush_attack;pending_brush_attack=null
 var elapsed=visual_elapsed;visual_elapsed=0
 super._animate(elapsed,movement)
func _update_leap_preview()->void:pass
func _update_hooks()->void:pass
func _begin_projectile_queries()->void:
 var director=hero.director
 director.refresh_targets()
 projectile_generation=director.target_generation
 # Own the mutable Array; the director replaces packed geometry on refresh.
 _projectile_targets=director.projectile_actors.duplicate()
 _projectile_centers=director.projectile_centers;_projectile_radii=director.projectile_radii
 _projectile_minimum=director.projectile_minimum;_projectile_maximum=director.projectile_maximum
 _projectile_query_active=true
func _clear_projectiles()->void:
 # Cancel/park releases this owner's snapshot without clearing another ally's.
 _projectile_centers=PackedVector3Array();_projectile_radii=PackedFloat64Array()
 super._clear_projectiles()
func living(center:Vector3=Vector3.INF,radius:float=INF)->Array:
 # The shared playable action stays unchanged. Only this autonomous adapter
 # knows the sweep being resolved during its own physics step.
 var dash=player.get("dashAttack")
 if not center.is_finite() and _npc_physics_from.is_finite() and class_id=="explorer" and dash is Dictionary and is_same(_resolution_ticket,dash.ticket):
  center=(_npc_physics_from+player.pos)*.5;radius=_npc_physics_from.distance_to(player.pos)*.5+dash.width
 var result=[]
 var bounded=center.is_finite() and radius>=0 and radius<INF
 for row in hero.director.melee_candidates(center,radius):
  var enemy=row.enemy
  if not is_instance_valid(enemy) or enemy.dead or enemy.hp<=0 or not game.forest_enemy_visible(enemy):continue
  if bounded:
   var reach=radius+maxf(0,enemy.body_radius)
   var box:AABB=row.bounds
   var nearest=Vector2(clampf(center.x,box.position.x,box.end.x),clampf(center.z,box.position.z,box.end.z))
   if box.position.is_finite() and box.size.is_finite() and nearest.distance_squared_to(Vector2(center.x,center.z))>reach*reach:continue
  var shared=enemy.has_method("has_shared_combat_contacts") and enemy.has_shared_combat_contacts()
  # Body contact is sampled at striking height. A grounded capsule may sit
  # slightly below y=0; its nearest foot-level point would end the cover ray
  # in the floor and incorrectly reject visible melee/landing damage.
  result.append(_target_snapshot(enemy,center+Vector3.UP if bounded and shared else Vector3.INF))
 return result
func target_in_area(target:Dictionary,center:Vector3,radius:float)->bool:
 var enemy=target.get("node")
 if is_instance_valid(enemy) and enemy.has_method("has_shared_combat_contacts") and enemy.has_shared_combat_contacts():
  var origin:Vector3=_damage_origin if _projectile_damage else player.pos+Vector3.UP
  for point in enemy.combat_contact_candidates(center+Vector3.UP):
   if not _projectile_damage and absf(point.y-player.pos.y)>3.5:continue
   if point.distance_to(center)<=radius and clear_line(origin,point):
    target.pos=point;target.shared_contact_validated=true;return true
 return super.target_in_area(target,center,radius)
func _nearby_targets(center:Vector3,radius:float,excluded_uid:int=-1)->Array:
 var result=[]
 for row in hero.director.melee_candidates(center,radius):
  var enemy=row.enemy
  if not is_instance_valid(enemy) or enemy.dead or enemy.hp<=0 or enemy.get_instance_id()==excluded_uid or not game.forest_enemy_visible(enemy):continue
  if AttackChain.contact_point(enemy,center,enemy.global_position).distance_to(center)<radius:result.append(_target_snapshot(enemy,center))
 return result
func _projectile_candidate_indices(minimum:Vector3,maximum:Vector3)->Array:
 # A nested hit can spawn targets or clear the army during this owner's loop.
 # Its captured geometry must never use indices from a newer spatial grid.
 if projectile_generation!=hero.director.target_generation:return super._projectile_candidate_indices(minimum,maximum)
 return hero.director.projectile_candidates(minimum,maximum)
