extends Node
## Small local squad. Target/path decisions are staggered at five Hz; kits tick normally.
const Unit=preload("res://scripts/forest/forest_gate_defender.gd")
const Roster=preload("res://scripts/rogue_roster.gd")
const LEASH=36.0
const ACQUIRE=30.0
var game
var units: Dictionary={}
var assignments: Dictionary={}
var settings_path="user://gate_defenders.cfg"
var clock=0.0
var map_ref
var signature=""
var mirrored_defender_model
var mirrored_gate_ids:Array=[]
func _ready():
 process_mode=Node.PROCESS_MODE_PAUSABLE
 load_assignments()
func gate_key(b: Dictionary)->String:return "%d,%d,%d"%[b.cell.x,b.cell.y,b.rotation]
func gates()->Array:
 var result=[]
 for b in game.model.buildings.values():
  if b.kind=="gate":result.append(b)
 result.sort_custom(func(a,b):return gate_key(a)<gate_key(b))
 return result
func gate_name(b: Dictionary)->String:
 var p=game.model.center(b)
 var side=("East" if p.x>0 else "West") if absf(p.x)>absf(p.z) else ("South" if p.z>0 else "North")
 return "%s gate (%d, %d)"%[side,b.cell.x,b.cell.y]
func load_assignments():
 var config=ConfigFile.new()
 if config.load(settings_path)!=OK:return
 var saved=config.get_value("defenders","assignments",{})
 if saved is Dictionary:
  for key in saved:
   if saved[key] is int and Roster.supports_gate_defender(saved[key]):assignments[str(key)]=saved[key]
func save_assignments():
 var config=ConfigFile.new();config.set_value("defenders","assignments",assignments)
 if config.save(settings_path)!=OK:game.toast("Could not save gate defenders")
func post_for(b: Dictionary)->Vector3:
 var p: Vector3=game.model.center(b)
 var outward=Vector3(0,0,1).rotated(Vector3.UP,b.rotation*PI*.5)
 # Gate rotations encode its entrance, including custom maps.
 p+=outward*9.0
 var cell=game.model.nearest_open(game.model.cell_of(p))
 if cell.x!=-999:p=game.model.point(cell)
 p.y=game.model.surface_height(p.x,p.z)
 return p
func retire(unit):
 if not is_instance_valid(unit):return
 if unit.active_ability!=null:unit.active_ability.cancel()
 unit.set_physics_process(false);unit.hide();unit.queue_free()
func reconcile(reset: bool=false):
 if is_instance_valid(game.map_editor) and game.map_editor.active:
  for unit in units.values():unit.hide()
  return
 var new_signature=""
 for b in gates():new_signature+=gate_key(b)+";"
 if map_ref!=game.model:
  for unit in units.values():retire(unit)
  units.clear();map_ref=game.model;signature=""
 if not reset and new_signature==signature:return
 var valid={};var index=0
 for b in gates():
  valid[b.id]=true
  var key=gate_key(b)
  var fallback=[7,10,5,6][index%4]
  var selected=int(assignments.get(key,fallback));index+=1
  if not Roster.supports_gate_defender(selected):selected=fallback
  assignments[key]=selected
  if not units.has(b.id) or units[b.id].character_id!=selected:
   if units.has(b.id):retire(units[b.id])
   var unit=Unit.new();unit.process_mode=Node.PROCESS_MODE_PAUSABLE;unit.game=game;unit.gate_id=b.id;unit.post=post_for(b);unit.position=unit.post+Vector3.UP*.15
   game.add_child(unit);unit.select_character(selected);unit.refresh_max_health();unit.hp=unit.max_hp
   unit.set_defender_label(gate_name(b));units[b.id]=unit
  if reset:units[b.id].restore_at_post()
 for id in units.keys():
  if not valid.has(id):retire(units[id]);units.erase(id)
 signature=new_signature;sync_model()
func assign(gate: int,character: int):
 if game.model.phase!="preparing" or not Roster.supports_gate_defender(character) or not game.model.buildings.has(gate):return
 assignments[gate_key(game.model.buildings[gate])]=character
 # Same geometry can have a new selection, so force the roster check.
 reconcile(true);save_assignments()
func sync_model():
 var active:Array=[];var gate_ids:Array=[]
 for unit in units.values():
  if not is_instance_valid(unit) or unit.is_queued_for_deletion():continue
  active.append(unit);gate_ids.append(unit.gate_id)
 var native=is_instance_valid(game.army_runtime)
 # The army mirror owns paid allies in this same table. Clearing it on every
 # guard tick destroys thousands of otherwise reusable ally rows. Rebuild only
 # when the map/gate roster changes, retaining the original gate-first order.
 if not native or mirrored_defender_model!=game.model or mirrored_gate_ids!=gate_ids:
  game.model.defenders.clear()
 mirrored_defender_model=game.model if native else null
 mirrored_gate_ids=gate_ids if native else []
 for unit in active:
  game.model.defenders[unit.gate_id]={"id":unit.gate_id,"pos":unit.position,"hp":unit.hp,"targetable":unit.hp>0 and not unit.rogue_untargetable()}
 if game.model.phase=="preparing" and is_instance_valid(game.explorer_helpers):game.explorer_helpers.sync_targets()
func tick(delta: float):
 for unit in units.values():
  if unit.hp<=0:
   unit.recovery_left=maxf(0,unit.recovery_left-delta)
   if unit.recovery_left<=0:unit.restore_at_post()
 clock-=delta
 if clock<=0:
  reconcile()
  clock=.2
  for unit in units.values():
   if unit.hp>0:think(unit)
 sync_model()
func primary_range(unit)->float:
 if unit.character_id==2:return 22.0
 if unit.character_id==14:return preload("res://scripts/recovered_ed_beam.gd").maximum_length(unit)*.9
 if unit.character_id in [1,13,15,16,17]:return unit.melee_strike_reach()*.8
 var combat=unit.active_ability
 if combat.class_id in ["ranger","mage"]:return 22.0
 if combat.player.attack!=null and combat.player.attack.get("weapon","")=="cutlass":return maxf(1.0,float(combat.player.attack.reach)*.8)
 return maxf(1.3,float(combat.Actions.PRIMARY.get(combat.class_id,{"reach":2.85}).reach)*unit.melee_reach_setting()*.72)
func think(unit):
 var best=null;var score=INF
 var origin: Vector3=unit.position+Vector3.UP
 for enemy in game.enemies:
  if not is_instance_valid(enemy) or enemy.dead or enemy.hp<=0 or enemy.training_dummy:continue
  if Vector2(enemy.position.x-unit.post.x,enemy.position.z-unit.post.z).length()>LEASH+12:continue
  # Cheap bounds reject distant giants before exact articulated contacts.
  var box: AABB=enemy.combat_bounds() if enemy.has_method("combat_bounds") else AABB(enemy.position,Vector3.ONE)
  var nearest=Vector3(clampf(origin.x,box.position.x,box.end.x),clampf(origin.y,box.position.y,box.end.y),clampf(origin.z,box.position.z,box.end.z))
  if nearest.distance_squared_to(origin)>ACQUIRE*ACQUIRE:continue
  var point: Vector3=AttackChain.aim_point(enemy,origin)
  if absf(point.y-origin.y)>5.0 and unit.character_id not in [2,6,10]:continue
  var distance=point.distance_to(origin)
  var data: Dictionary=game.model.enemies.get(enemy.forest_id,{})
  var urgency=7.0 if data.get("target_kind","")=="building" and data.get("target_id",-1)==unit.gate_id else 0.0
  var candidate=distance+point.distance_to(unit.post)*.12+enemy.hp/maxf(1,enemy.max_hp)*2.0-urgency
  if enemy==unit.ai_target:candidate-=2.5
  if candidate>=score:continue
  var ray=PhysicsRayQueryParameters3D.create(origin,point,1)
  ray.exclude=[unit.get_rid()]
  if not unit.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
  best=enemy;score=candidate
 unit.ai_target=best;unit.auto_attack_enabled=false
 var destination: Vector3=unit.post
 if best!=null:
  unit.ai_aim=AttackChain.aim_point(best,origin)
  var offset: Vector3=unit.ai_aim-unit.position;offset.y=0
  var range_=primary_range(unit)
  var gap=offset.length()
  unit.auto_attack_enabled=gap<=range_+1.5 and absf(unit.ai_aim.y-origin.y)<(12 if unit.character_id in [2,6,10] else 3)
  if unit.character_id in [2,6,10]:
   if gap>18:destination=unit.position+offset.normalized()*(gap-16)
   elif gap<6:destination=unit.position-offset.normalized()*4
   else:destination=unit.position
  else:destination=unit.position+offset.normalized()*maxf(0,gap-range_*.85)
  use_special(unit,gap)
 if Vector2(destination.x-unit.post.x,destination.z-unit.post.z).length()>LEASH:
  var displacement=destination-unit.post;displacement.y=0;destination=unit.post+displacement.limit_length(LEASH)
 set_destination(unit,destination)
func use_special(unit,gap: float):
 if not unit.is_rogue_character():return
 var c=unit.active_ability;var p=c.player
 if p.travel!=null or p.attack!=null or p.roll>0:return
 c.secondary_held=false
 if p.blocking:
  p.blocking=false;p.guardTime=0.0
 if p.cooldowns.drink<=0 and p.buffTime<=0 and gap<22:c.action("drink")
 match c.class_id:
  "knight":
   # Hold the actual counter shield against a committed incoming strike.
   var threat=false
   for e in game.model.enemies.values():
    if e.action=="windup" and e.get("target_kind","")=="defender" and e.get("target_id",-1)==unit.gate_id:threat=true;break
   if threat and gap<8:c.secondary_held=true;c.action("flintlock")
  "master-thief":
   if unit.hp<unit.max_hp*.35 and gap<6 and p.cooldowns.flintlock<=0:c.secondary_held=true;c.action("flintlock")
  "ninja","explorer":
   if gap>4 and gap<12 and p.cooldowns.flintlock<=0:c.action("flintlock")
  "dragoon":
   if gap<7 and p.cooldowns.flintlock<=0:c.action("flintlock")
  "mage":
   if gap<7 and p.cooldowns.flintlock<=0:c.action("flintlock")
  "pirate","ranger","samurai","magic-swordsman":
   if gap<25 and p.cooldowns.flintlock<=0:c.action("flintlock")
 if c.class_id in ["ninja","samurai"] and gap>5 and gap<25 and p.cooldowns.roll<=0:c.action("roll")
func set_destination(unit,destination: Vector3):
 unit.ai_move=Vector3.ZERO
 if unit.position.distance_to(destination)<.65:return
 var m=game.model
 var start=m.nearest_open(m.cell_of(unit.position));var goal=m.nearest_open(m.cell_of(destination))
 if start.x==-999 or goal.x==-999:return
 if goal!=m.cell_of(destination):destination=m.point(goal)
 if unit.route_goal!=goal or unit.route_revision!=m.navigation_revision or unit.route.is_empty():
  unit.route=m.route(start,goal);unit.route_goal=goal;unit.route_revision=m.navigation_revision
 if unit.route.is_empty():return
 while unit.route.size()>1 and Vector2(unit.position.x-m.point(unit.route[0]).x,unit.position.z-m.point(unit.route[0]).z).length()<1.3:unit.route.pop_front()
 var point: Vector3=m.point(unit.route[0]) if unit.route.size()>1 else destination
 var direction=point-unit.position;direction.y=0
 if direction.length()>.5:unit.ai_move=direction.normalized()

