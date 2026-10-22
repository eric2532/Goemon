extends "res://scripts/forest/crowd/army_runtime.gd"
## One physics owner; the slower world tick handles economy and wave lifecycle.
const Snapshot=preload("res://scripts/forest/crowd/army_snapshot.gd")
var game:Node
var simulation_steps=0
var simulation_seconds=0.0
var profile_enabled=false
var profile_totals:Dictionary={}
var registered_facade_updates=0
var registered_facade_fallbacks=0
var worker_enabled=true
var integration_pending=false
var worker_pending=false
var worker_jobs=0
var helper_overlap_calls=0
var pending_helpers:Dictionary={}
var pending_delta=0.0
var pending_clock=0
var configured_model
var configured_tuning=0
var configured_helpers=false
var latest:Dictionary={}
var presentation_delta=0.0
var presentation_dirty=false
var presentation_frames=0
var import_rows_visited=0
var arrival_rows:Array[Dictionary]=[]
var arrival_ids:Dictionary={}
var pending_retirements:Dictionary={}
var retirement_rows_visited=0
var retirement_reconcile=false
func setup(owner_:Node):
 game=owner_;shared_snapshot_enabled=game.get_tree().get_meta("forest_army_shared_snapshots",true) if game.get_tree()!=null else true;worker_enabled=game.get_tree().get_meta("forest_army_worker",true) if game.get_tree()!=null else true;configure(game);record_events=false;pooled_presentation=true;game.model.army_runtime=self;configured_model=game.model
 native.set_parallel_movement(game.get_tree().get_meta("forest_army_parallel_movement",true))
 for row:Dictionary in game.model.enemies.values():queue_enemy_arrival(row)
 refresh_kits();game.crowd.configure_army(game)
func refresh_kits():
 var data=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game)
 data.ranger[27]=1 if game.crosshair_aim_enabled() else 0
 configure_kits(data)
 configured_helpers=is_instance_valid(game.explorer_helpers)
 if is_instance_valid(game.crowd.army):game.crowd.army.configure_profiles(data)
 configured_tuning=hash([game.character_tuning,game.tuning,game.model.balance])
func blocked()->bool:
 return not game.playing or game.paused or game.model.phase!="wave" or game.ordinary_pause or game.settings_open or game.rogue_roster_open or game.transitioning or (is_instance_valid(game.map_editor) and game.map_editor.active)
func profile_mark(label_:String,started:int)->int:
 if not profile_enabled:return 0
 var now=Time.get_ticks_usec();profile_totals[label_]=float(profile_totals.get(label_,0))+(now-started)/1000.0;return now
func can_overlap()->bool:
 # Keep navigation/world refresh in its original phase when topology changes.
 return worker_enabled and not integration_pending and not blocked() and configured_model==game.model and navigation_revision==game.model.navigation_revision and configured_helpers and configured_tuning==hash([game.character_tuning,game.tuning,game.model.balance])
func integration_tick(delta:float):
 if begin_integration(delta,false):finish_integration()
func begin_integration(delta:float,overlap:bool=true)->bool:
 if integration_pending:finish_integration()
 if blocked() or (overlap and not can_overlap()):return false
 var clock=Time.get_ticks_usec() if profile_enabled else 0
 if configured_model!=game.model:
  clear();configured_model=game.model;game.model.army_runtime=self;navigation_revision=-1;refresh_kits()
  for row:Dictionary in game.model.enemies.values():queue_enemy_arrival(row)
 if navigation_revision!=game.model.navigation_revision:
  game.world.sync(0)
  var nav=navigation_data(game.model)
  var collision=static_collision_data(game.world);nav.air_faces=collision.faces;nav.air_owner=collision.owners
  nav.ray_min=PackedVector3Array();nav.ray_max=PackedVector3Array();nav.ray_owner=PackedInt64Array()
  set_navigation(game.model.navigation_revision,nav)
 if not configured_helpers or configured_tuning!=hash([game.character_tuning,game.tuning,game.model.balance]):refresh_kits()
 clock=profile_mark("navigation_tuning",clock)
 import_arrivals();clock=profile_mark("arrivals",clock)
 var targets=external_targets();clock=profile_mark("external_targets",clock)
 pending_delta=delta
 if overlap:
  pending_helpers=native.capture_helper_snapshot();clock=profile_mark("helper_capture",clock)
  pending_clock=clock
  native.set_targets(targets)
  if not native.begin_step(delta):return false
  worker_jobs+=1
 else:
  pending_clock=clock;step(delta,{"targets":targets})
 integration_pending=true;worker_pending=overlap;return true
func finish_integration():
 if not integration_pending:return
 # Clear the flags before callbacks: reentrant hits must not finish twice.
 integration_pending=false;worker_pending=false
 var waiting=Time.get_ticks_usec() if profile_enabled else 0
 native.finish_step();pending_helpers={};profile_mark("native_wait",waiting)
 var delta=pending_delta;var clock=profile_mark("native_step",pending_clock)
 simulation_steps+=1;simulation_seconds+=delta
 dispatch_events();clock=profile_mark("event_dispatch",clock)
 sync_compatibility();profile_mark("compatibility",clock)
 presentation_delta+=delta;presentation_dirty=true
func sync_helper_mirrors(defenders:Dictionary,posts:Dictionary)->int:
 if worker_pending:
  var count:int=native.sync_helper_snapshot(pending_helpers,defenders,posts)
  assert(count>=0,"Invalid captured helper state")
  helper_overlap_calls+=1;return count
 return super.sync_helper_mirrors(defenders,posts)
func enemy_candidates(center:Vector3,radius:float)->Array:
 finish_integration();return super.enemy_candidates(center,radius)
func apply_hit(handle:int,hit:Dictionary)->Dictionary:
 finish_integration();return super.apply_hit(handle,hit)
func despawn(handle:int)->void:
 finish_integration();super.despawn(handle)
func dispatch_events()->void:
 if integration_pending:finish_integration();return
 super.dispatch_events()
func queue_enemy_arrival(row:Dictionary):arrival_rows.append(row);arrival_ids[row.id]=true
func import_arrivals():
 var pending=arrival_rows;arrival_rows=[];arrival_ids.clear()
 for row:Dictionary in pending:
  import_rows_visited+=1
  if not is_same(game.model.enemies.get(row.id,{}),row):continue
  if row.hp<=0:_enemy_retired(row.id);continue
  if handles.has(row.id):continue
  var handle:int=spawn(row.id,0,row.variant,row.pos,row.hp,preload("res://scripts/forest/forest_enemy_roles.gd").footprint_radius(row.variant))
  if handle==0:queue_enemy_arrival(row);continue # Retry a live capacity-limited arrival.
  var actor=enemy_target(row.id)
  if actor!=null:game.actors[row.id]=actor;game.enemies.append(actor)
func sync_compatibility():
 var clock=Time.get_ticks_usec() if profile_enabled else 0
 latest=render_snapshot();clock=profile_mark("compatibility_snapshot",clock)
 latest.plain_fields=get_tree().get_meta("forest_army_plain_fields",true)
 latest.profile_facades=profile_enabled and get_tree().get_meta("forest_army_profile_facades",false)
 snapshot_epoch+=1;snapshot_view=Snapshot.new(latest);latest.shared_facades=shared_snapshot_enabled;latest.guard_poses=get_tree().get_meta("forest_army_guard_poses",true);clock=profile_mark("compatibility_view",clock)
 var transferred=-1
 if shared_snapshot_enabled and latest.plain_fields and not latest.profile_facades and get_tree().get_meta("forest_army_registered_facades",true):transferred=native.sync_registered_facades(latest)
 if transferred<0:
  native.sync_facades(latest,game.model.enemies,enemies,allies,snapshot_view)
  if profile_enabled:registered_facade_fallbacks+=1
 elif profile_enabled:registered_facade_updates+=transferred
 clock=profile_mark("compatibility_facades",clock)
 # An explicit clear can invalidate every model row at once. Reconcile once,
 # after new arrivals have been imported, rather than on every normal tick.
 if retirement_reconcile:
  for id in game.model.enemies:pending_retirements[id]=true
  retirement_reconcile=false
 # Death/despawn already identify removals. Do not rescan every living row.
 var retiring=pending_retirements;pending_retirements={}
 for id in retiring:
  retirement_rows_visited+=1
  if arrival_ids.has(id):pending_retirements[id]=true;continue
  if not handles.has(id):
   game.model.enemies.erase(id)
   var actor=game.actors.get(id)
   if is_instance_valid(actor):game.enemies.erase(actor);actor.queue_free()
   game.actors.erase(id);enemies.erase(id)
 profile_mark("compatibility_cleanup",clock)
func _enemy_retired(id:int)->void:pending_retirements[id]=true
func set_guard(handle:int,point:Vector3,radius:float):native.set_guard(handle,point,radius)
func target_actor(id:int)->Node3D:return ally_target(id) if id<0 else enemy_target(id)
func summon(slot:int)->bool:return game.explorer_helpers.request(slot)
func rest():
 native.rest_allies();navigation_revision=-1;presentation_events.clear()
 sync_targets()
func begin_wave():
 for unit in game.explorer_helpers.active_units():unit.state="acting";unit.age=0
func external_targets()->Dictionary:
 var rows={"ids":PackedInt64Array(),"kinds":PackedInt32Array(),"positions":PackedVector3Array(),"hp":PackedFloat32Array(),"targetable":PackedByteArray(),"taunting":PackedByteArray(),"minimum":PackedVector3Array(),"maximum":PackedVector3Array(),"ignore_building":PackedInt64Array(),"shelter_ids":PackedInt64Array(),"shelter_damage":PackedInt64Array(),"shelter_entrances":PackedVector3Array(),"shelter_centers":PackedVector3Array()}
 append_target(rows,0,0,game.player.position,game.player.hp,not game.player.rogue_untargetable() and game.respawn_left<=0)
 for w:Dictionary in game.model.workers.values():
  if not game.model.worker_targetable(w.id):continue
  var deck:float=preload("res://scripts/forest/forest_structure_profile.gd").TOWER_DECK_HEIGHT if w.state=="garrison" else w.get("deck_height",0.0)
  append_target(rows,w.id,1,w.pos+Vector3.UP*deck,w.hp)
 for b:Dictionary in game.model.buildings.values():
  if b.hp<=0 or b.kind=="wall" or b.get("breached",false):continue
  if b.kind=="barracks":rows.shelter_ids.append(b.id);rows.shelter_damage.append(b.get("damage_serial",0));rows.shelter_entrances.append(game.model.point(game.model.entry(b)));rows.shelter_centers.append(game.model.center(b))
  var size:Vector2i=game.model.dimensions(b.kind,b.rotation,b.get("span",0));var low:Vector3=game.model.point(b.cell)-Vector3(3,0,3)
  append_target(rows,b.id,2,game.model.center(b),b.hp,true,false,low,low+Vector3(size.x*6,preload("res://scripts/forest/forest_structure_profile.gd").height(b.kind),size.y*6),b.id)
 for unit in game.gate_defenders.units.values():
  if is_instance_valid(unit) and unit.hp>0:append_target(rows,unit.gate_id,3,unit.position,unit.hp,not unit.rogue_untargetable(),unit.character_id==7 and unit.active_ability.player.buffTime>0)
 return rows
func append_target(rows:Dictionary,id:int,kind:int,point:Vector3,hp:float,targetable_:bool=true,taunt:bool=false,low:Vector3=Vector3.ZERO,high:Vector3=Vector3.ZERO,ignore:int=-1):
 rows.ids.append(id);rows.kinds.append(kind);rows.positions.append(point);rows.hp.append(hp);rows.targetable.append(1 if targetable_ else 0);rows.taunting.append(1 if taunt else 0);rows.minimum.append(low);rows.maximum.append(high);rows.ignore_building.append(ignore)

func clear():
 finish_integration()
 # Paid guard facade nodes belong to the hiring UI pool across resets.
 for unit in allies.values():
  if is_instance_valid(unit) and unit.get("director")!=null:unit.handle=0;unit.hp=0;unit.state="idle";unit.dead=false;unit.targetable=false
 allies.clear()
 super.clear()
 latest={};arrival_rows.clear();arrival_ids.clear();pending_retirements.clear();retirement_reconcile=true;presentation_delta=0;presentation_dirty=false

func preparation_tick(delta:float):
 if not game.playing or game.model.phase!="preparing" or game.ordinary_pause or game.settings_open or game.rogue_roster_open or game.transitioning or (is_instance_valid(game.map_editor) and game.map_editor.active):return
 if not configured_helpers or configured_tuning!=hash([game.character_tuning,game.tuning,game.model.balance]):refresh_kits()
 native.set_targets(external_targets());native.rest_tick(delta);sync_compatibility()
 presentation_dirty=true

func flush_presentation():
 if not presentation_dirty:return
 var clock=Time.get_ticks_usec() if profile_enabled else 0
 game.crowd.army.presentation.tick(presentation_delta)
 clock=profile_mark("presentation_tick",clock)
 game.crowd.present_army(latest,presentation_events)
 presentation_events=[];presentation_delta=0;presentation_dirty=false;presentation_frames+=1
 profile_mark("presentation",clock)

func _process(_delta:float):
 if not is_instance_valid(game) or not is_instance_valid(game.crowd) or not is_instance_valid(game.crowd.army):return
 flush_presentation()
 if blocked() or game.sound_library.recording or float(game.settings.get("volume",.65))<=0:game.crowd.army.presentation.suspend_audio()
