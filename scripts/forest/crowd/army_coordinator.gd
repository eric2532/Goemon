extends "res://scripts/forest/crowd/army_runtime.gd"
## One physics owner; the slower world tick handles economy and wave lifecycle.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const HOUND_ID=-1000000
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Winter=preload("res://scripts/forest/forest_frostpass.gd")
const CAVE_BEAR_ID=-2000000
const HOUND_GUARD_RADIUS=18.0
const BEAST_PET_RECALL_DELAY=.35
const BEAST_PET_SPAWN_TIMEOUT=2.0
# Same party-slot offsets as native hound_guard; Z and fresh summons share the layout.
const PET_FORMATION_POSTS=preload("res://scripts/forest/party_formation.gd").POSTS
enum HoundOrder { DEFEND, ATTACK, RETURN, HOLD, COMBINED }
const Snapshot=preload("res://scripts/forest/crowd/army_snapshot.gd")
var pet_skills:Node
var game:Node
var simulation_steps=0
var simulation_seconds=0.0
var profile_enabled=false
var profile_totals:Dictionary={}
var model_rows_epoch=-1
var model_rows_seen:Dictionary={}
var model_rows_publications=0
var model_rows_written=0
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
var reaction_dirty=false
var presentation_frames=0
var import_rows_visited=0
var arrival_rows:Array[Dictionary]=[]
var arrival_ids:Dictionary={}
var boss_handles:Dictionary={}
var pending_hounds:Array[int]=[]
var beast_pet_orders:Dictionary={}
var recalled_pet_mana:Dictionary={}
var pet_participants:Dictionary={}
var pending_cave_bears:Array[int]=[]
var cave_bear_serial=0
var hound_order:int=HoundOrder.DEFEND
var hound_order_serial:int=0
var combined_committed=false
var combined_contacted=false
var combined_origin=Vector3.ZERO
var combined_facing=Vector3.FORWARD
var hound_focus_target:int=0
var hound_attack_move=Vector3(INF,0,0)
var hound_focus_actor:Ninja
var pending_retirements:Dictionary={}
var retirement_rows_visited=0
var retirement_reconcile=false
func setup(owner_:Node)->bool:
 game=owner_;shared_snapshot_enabled=game.get_tree().get_meta("forest_army_shared_snapshots",true) if game.get_tree()!=null else true;worker_enabled=game.get_tree().get_meta("forest_army_worker",true) if game.get_tree()!=null else true
 if not configure(game):return false
 pet_skills=load("res://scripts/forest/pet_skill_runtime.gd").new();pet_skills.runtime=self;add_child(pet_skills)
 record_events=false;pooled_presentation=true;game.model.army_runtime=self;configured_model=game.model
 native.set_parallel_movement(game.get_tree().get_meta("forest_army_parallel_movement",true))
 for row:Dictionary in game.model.enemies.values():queue_enemy_arrival(row)
 game.crowd.configure_army(game);refresh_kits()
 return true
func reset_world():
 clear();configured_model=game.model;game.model.army_runtime=self;navigation_revision=-1;refresh_kits()
 if not game.model.waves.patrol_posts.is_empty():refresh_navigation(Time.get_ticks_usec() if profile_enabled else 0)
 for row:Dictionary in game.model.enemies.values():queue_enemy_arrival(row)
func refresh_kits():
 var data=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model,game.tuning.enemy_damage,game)
 data.ranger[27]=1 if game.crosshair_aim_enabled() else 0
 configure_kits(data)
 configured_helpers=is_instance_valid(game.explorer_helpers)
 if is_instance_valid(game.crowd.army):game.crowd.army.configure_profiles(data)
 configured_tuning=hash([game.character_tuning,game.tuning,game.model.balance])
func blocked()->bool:
 return not game.playing or game.paused or (game.model.phase!="wave" and not combined_committed) or game.ordinary_pause or game.settings_open or game.rogue_roster_open or game.transitioning or (is_instance_valid(game.map_editor) and game.map_editor.active)
func profile_mark(label_:String,started:int)->int:
 if not profile_enabled:return 0
 var now=Time.get_ticks_usec();profile_totals[label_]=float(profile_totals.get(label_,0))+(now-started)/1000.0;return now
func can_overlap()->bool:
 # Keep navigation/world refresh in its original phase when topology changes.
 return worker_enabled and not integration_pending and not blocked() and configured_model==game.model and navigation_revision==game.model.navigation_revision and configured_helpers and configured_tuning==hash([game.character_tuning,game.tuning,game.model.balance])
func integration_tick(delta:float):
 if begin_integration(delta,false):finish_integration()
func prepare_navigation():
 if configured_model==game.model and game.playing and game.model.phase=="preparing" and not game.transitioning:
  if not configured_helpers or configured_tuning!=hash([game.character_tuning,game.tuning,game.model.balance]):refresh_kits()
  refresh_navigation(Time.get_ticks_usec() if profile_enabled else 0)
func refresh_navigation(clock:int):
 if navigation_revision==game.model.navigation_revision:return
 game.world.sync(0)
 clock=profile_mark("navigation_world",clock)
 var nav=navigation_data(game.model)
 clock=profile_mark("navigation_data",clock)
 var collision=static_collision_data(game.world);nav.air_faces=collision.faces;nav.air_owner=collision.owners
 clock=profile_mark("navigation_collision",clock)
 nav.ray_min=PackedVector3Array();nav.ray_max=PackedVector3Array();nav.ray_owner=PackedInt64Array()
 set_navigation(game.model.navigation_revision,nav)
 if not game.model.waves.patrol_posts.is_empty():
  var radii={};var patrols=game.model.waves.patrol_source
  for slot in game.model.waves.patrol_posts.size():
   var skin:int=game.model.waves.patrol_posts[slot].z
   var footprint=patrols.TREE_FOOTPRINT if patrols.tree(skin) else patrols.FOOTPRINT
   var radius:float=footprint*pet_geometry[preload("res://scripts/forest/crowd/pet_dimensions.gd").offset(Roles.SLIME,skin)+6]
   radii[radius]=true
   if game.model.waves.elite_posts.has(slot):radii[radius*2.0]=true
  # Prepare exact body-size routes while loading, before any patrol needs a detour.
  var prepared:bool=native.prepare_routes(PackedFloat32Array(radii.keys()),0)
  assert(prepared,"Invalid outdoor patrol routing preparation")
  prepare_pet_navigation()
 profile_mark("navigation_native",clock)
func prepare_pet_navigation():
 if navigation_revision!=game.model.navigation_revision or game.model.waves.patrol_posts.is_empty():return
 var radii={.5:true} # Native right-click focus also checks reachability with the player's radius.
 for key in Pets.sanitized(game.settings.forest_pet_loadout):
  var body=preload("res://scripts/forest/crowd/pet_dimensions.gd").companion_body(Pets.skin(key))
  radii[Vector2(body.size.x,body.size.z).length()*.5]=true
 var prepared:bool=native.prepare_routes(PackedFloat32Array(radii.keys()),1)
 assert(prepared,"Invalid companion routing preparation")
func begin_integration(delta:float,overlap:bool=true)->bool:
 if integration_pending:finish_integration()
 if overlap:
  if not can_overlap():return false
 elif blocked():return false
 if not beast_pet_orders.is_empty() and (not game.player.spell_loadout.beast_master_equipped() or game.player.hp<=0):recall_beast_pets()
 var clock=Time.get_ticks_usec() if profile_enabled else 0
 if not overlap:
  if configured_model!=game.model:
   clear();configured_model=game.model;game.model.army_runtime=self;navigation_revision=-1;refresh_kits()
   for row:Dictionary in game.model.enemies.values():queue_enemy_arrival(row)
  refresh_navigation(clock)
  if not configured_helpers or configured_tuning!=hash([game.character_tuning,game.tuning,game.model.balance]):refresh_kits()
 clock=profile_mark("navigation_tuning",clock)
 import_arrivals();import_hounds();import_guards(pending_cave_bears,Roles.CAVE_BEAR);clock=profile_mark("arrivals",clock)
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
 var advanced_by_worker=worker_pending
 integration_pending=false;worker_pending=false
 var waiting=Time.get_ticks_usec() if profile_enabled else 0
 native.finish_step();pending_helpers={};profile_mark("native_wait",waiting)
 if hound_focus_target!=0 and native.hound_focus_target()==0:
  hound_focus_target=0;hound_focus_actor=null;hound_order=HoundOrder.DEFEND
 var delta=pending_delta;var clock=profile_mark("native_step",pending_clock)
 simulation_steps+=1;simulation_seconds+=delta
 dispatch_events()
 clock=profile_mark("event_dispatch",clock)
 if advanced_by_worker:
  mirrors_advanced.emit(delta)
  clock=profile_mark("mirror_controllers",clock)
 if pet_skills!=null:pet_skills.step(delta)
 if not beast_pet_orders.is_empty():advance_beast_pets(delta)
 if combined_committed:
  var ability=game.player.active_ability
  if not ability.combined_normal_swing() and ability.mode!="combined_wait":finish_combined_power(false,false)
  elif native.combined_power_ready() and not ability.is_attacking():finish_combined_power()
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
 finish_integration()
 var result=super.apply_hit(handle,hit)
 if result.accepted or not presentation_events.is_empty():reaction_dirty=true;presentation_dirty=true
 return result
func despawn(handle:int)->void:
 finish_integration()
 if pet_skills!=null:pet_skills.retire(handle)
 var row=unit_state(handle)
 if not row.is_empty() and row.team==0:pet_participants.erase(row.logical_id)
 super.despawn(handle)
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
  var radius:float=row.get("footprint",Roles.footprint_radius(row.variant,game.model.balance.enemy_size_mult))
  if not pet_geometry.is_empty() and row.variant in [19,20,21]:radius*=pet_geometry[preload("res://scripts/forest/crowd/pet_dimensions.gd").offset(row.variant,int(row.get("skin",0)))+6]
  var handle:int=spawn(row.id,0,row.variant,row.pos,row.hp,radius)
  if handle==0:queue_enemy_arrival(row);continue # Retry a live capacity-limited arrival.
  if row.has("body_scale"):
   var scaled:bool=native.set_body_scale(handle,float(row.body_scale))
   assert(scaled,"Invalid elite body scale")
  if row.has("skin") and row.variant in [Roles.GATEKEEPER_HOUND,Roles.SLIME,Roles.CAVE_BEAR]:
   var assigned:bool=native.set_pet_skin(handle,int(row.skin))
   assert(assigned,"Invalid Cross Gate enemy appearance")
   native.set_pose(handle,row.pos,row.facing)
  if row.has("patrol_radius"):native.set_guard(handle,row.pos,row.patrol_radius)
  native.set_enemy_scaling(handle,float(row.get("health_scale",1.0)),float(row.get("damage_scale",1.0)))
  if row.get("cursed_arrival",false):
   var appearing:bool=native.begin_enemy_arrival(handle)
   assert(appearing,"Invalid Cursed Maze reinforcement")
  if row.get("boss",false):
   boss_handles[row.id]=handle
   var configured:bool=native.set_boss_reactions(handle,0.0 if row.has("frostpass_slot") else .05,0.0 if row.has("frostpass_slot") else .75)
   assert(configured,"Invalid boss reaction chances")
  elif row.get("patrol_radius",0.0)>0:
   var configured:bool=native.set_patrol_counter(handle)
   assert(configured,"Invalid world patrol counter setup")
  if row.has("elite_leader"):
   var assigned:bool=native.set_enemy_escort(handle,int(handles.get(row.elite_leader,0)),int(row.escort_slot))
   assert(assigned,"Invalid elite escort assignment")
  var actor=enemy_target(row.id)
  if actor!=null:game.actors[row.id]=actor;game.enemies.append(actor)
func reconcile_pet_loadout():
 finish_integration()
 var selected:Array[String]=Pets.sanitized(game.settings.forest_pet_loadout)
 for skin in beast_pet_orders.keys():
  if Pets.key(skin) not in selected:beast_pet_orders.erase(skin)
 pending_hounds.assign(pending_hounds.filter(func(skin):return Pets.key(skin) in selected))
 for skin in Pets.COUNT:
  if Pets.key(skin) not in selected and handles.has(HOUND_ID-skin):recall_pet(skin)
 if is_instance_valid(game.crowd.army):Pets.prepare(selected+Winter.creature_keys(game.model.falan_floor)+game.model.get_meta("east_enemy_pet_keys",[]),game.crowd.army.presentation.corpses)
 if pet_skills!=null:pet_skills.reconcile()
func queue_hounds()->int:
 reconcile_pet_loadout()
 var summoned=false
 for key in Pets.sanitized(game.settings.forest_pet_loadout):
  var skin=Pets.skin(key)
  if handles.has(HOUND_ID-skin):summoned=true
  elif skin not in pending_hounds:pending_hounds.append(skin)
 if not summoned and not pending_hounds.is_empty():
  hound_order=HoundOrder.DEFEND;hound_focus_target=0;hound_focus_actor=null
 return pending_hounds.size()

func recall_hounds()->bool:
 finish_integration()
 var recalled=not pending_hounds.is_empty()
 pending_hounds.clear()
 beast_pet_orders.clear()
 for skin in Pets.COUNT:
  if handles.has(HOUND_ID-skin):
   recall_pet(skin);recalled=true
 if recalled:
  if hound_focus_target!=0:hound_focus_target=0;hound_focus_actor=null;hound_order=HoundOrder.DEFEND
  presentation_events.append({"kind":"hound_recall","position":game.player.position})
  sync_compatibility();presentation_dirty=true
 return recalled

func recall_pet(skin:int):
 var handle:int=handles[HOUND_ID-skin]
 var row=unit_state(handle)
 if not row.is_empty():recalled_pet_mana[skin]=row.mana
 despawn(handle)

func queue_beast_pet_attacks(number:int)->bool:
 finish_integration()
 if blocked() or combined_committed or game.player.hp<=0 or not game.player.spell_loadout.beast_master_equipped():return false
 var selected:Array[String]=Pets.sanitized(game.settings.forest_pet_loadout)
 var requested=selected if number==Pets.MAX_ACTIVE+1 else selected.slice(number-1,number)
 var accepted=false
 for key in requested:
  var skin=Pets.skin(key)
  var handle:int=handles.get(HOUND_ID-skin,0)
  if handle!=0:
   if not native.queue_beast_pet_attacks(handle,1):continue
   if not beast_pet_orders.has(skin):
    if pet_skills!=null:pet_skills.retire(handle)
    beast_pet_orders[skin]={"waiting":0,"left":BEAST_PET_RECALL_DELAY}
  else:
   var order:Dictionary=beast_pet_orders.get_or_add(skin,{"waiting":0,"left":BEAST_PET_SPAWN_TIMEOUT})
   order.waiting+=1
   order.left=BEAST_PET_SPAWN_TIMEOUT
   if skin not in pending_hounds:pending_hounds.append(skin)
  accepted=true
 return accepted

func advance_beast_pets(delta:float):
 for skin in beast_pet_orders.keys():
  var order:Dictionary=beast_pet_orders[skin]
  var handle:int=handles.get(HOUND_ID-skin,0)
  if handle==0 and order.waiting==0:
   beast_pet_orders.erase(skin)
   continue
  var busy:bool=handle!=0 and native.beast_pet_busy(handle)
  if order.erase("arriving"):
   var row=unit_state(handle) if busy else {}
   if row.get("target_id",0)==0 and not row.get("beast_pet_active",false):
    recall_beast_pet(skin,false)
    continue
   presentation_events.append({"kind":"hound_summon","position":row.position})
  if busy:
   order.left=BEAST_PET_RECALL_DELAY
   continue
  order.left-=delta
  if order.left<=0:recall_beast_pet(skin)

func recall_beast_pet(skin:int,play_sound:bool=true):
 beast_pet_orders.erase(skin)
 pending_hounds.erase(skin)
 var handle:int=handles.get(HOUND_ID-skin,0)
 if handle==0:return
 var point:Vector3=unit_state(handle).get("position",game.player.global_position) if play_sound else Vector3.ZERO
 recall_pet(skin)
 if play_sound:presentation_events.append({"kind":"hound_recall","position":point})

func recall_beast_pets():
 if beast_pet_orders.is_empty():return
 finish_integration()
 for skin in beast_pet_orders.keys():recall_beast_pet(skin)
 sync_compatibility();presentation_dirty=true

func hound_health_fraction(skin:int)->float:
 var handle:int=handles.get(HOUND_ID-skin,0)
 if handle==0 or snapshot_view==null:return 0.0
 var slot:int=handle&0xffffffff
 if slot>=snapshot_view.rows_by_slot.size():return 0.0
 var row:int=snapshot_view.rows_by_slot[slot]
 if row<0 or snapshot_view.handles[row]!=handle:return 0.0
 return clampf(snapshot_view.hp[row]/snapshot_view.max_hp[row],0.0,1.0)

func pet_stats(skin:int)->Dictionary:
 if skin<0 or skin>=Pets.COUNT:return {}
 finish_integration()
 var progression=game.model.team_progression
 var key=Pets.key(skin)
 var xp=progression.pet_experience.get(key)
 var level_:int=xp.level if xp!=null else 1
 var profile=Roles.stats(Roles.GATEKEEPER_HOUND)
 var handle:int=handles.get(HOUND_ID-skin,0)
 var state=unit_state(handle) if handle!=0 and valid(handle) else {}
 var maximum:float=Pets.BASE_HEALTH*progression.multiplier("pet_health")+progression.pet_health_bonus(key)
 var mana_max:float=Pets.BASE_MANA+progression.pet_mana_bonus(key)
 var pattern=Pets.attack_pattern(skin)
 return {"hp":state.get("hp",maximum),"max_hp":state.get("max_hp",maximum),
  "mana":state.get("mana",recalled_pet_mana.get(skin,mana_max)),"max_mana":state.get("max_mana",mana_max),
  "summoned":not state.is_empty(),"damage":Pets.BASE_DAMAGE*progression.pet_damage_multiplier(key),
  "level":level_,"xp":xp.experience() if xp!=null else 0.0,"xp_required":progression.Experience.xp_required(level_),
  "attack_speed":1.0+.10*progression.pet_rank(key,"attack_speed"),"dodge_chance":state.get("dodge_chance",.01*progression.pet_rank(key,"dodge_chance")),"counter_chance":state.get("counter_chance",.01*progression.pet_rank(key,"counter_chance")),
  "speed":profile.speed*progression.multiplier("pet_speed")*(1+.05*progression.pet_rank(key,"speed")),"duration":pattern.duration,"contacts":pattern.contacts.size()}

func record_pet_participation(event:Dictionary):
 if event.amount<=0:return
 var pet_id:int=event.source_id if event.team==0 else event.target_id
 var enemy_id:int=event.target_id if event.team==0 else event.source_id
 var skin=HOUND_ID-pet_id
 if skin<0 or skin>=Pets.COUNT or enemy_id<=0 or not handles.has(enemy_id):return
 var participants:Dictionary=pet_participants.get_or_add(enemy_id,{})
 participants[Pets.key(skin)]=true

func award_pet_kill(source_id:int,reward_tenths:int,enemy_id:int=0)->bool:
 var participants:Dictionary=pet_participants.get(enemy_id,{})
 pet_participants.erase(enemy_id)
 var skin=HOUND_ID-source_id
 if skin>=0 and skin<Pets.COUNT:participants[Pets.key(skin)]=true
 var leveled=false
 for key in participants:
  var gained:int=game.model.team_progression.award_pet_enemy(key,reward_tenths)
  if gained<=0:continue
  leveled=true
  var handle:int=handles.get(HOUND_ID-Pets.skin(key),0)
  if handle!=0 and valid(handle):apply_pet_growth(handle,key,true)
  game.toast("%s · Level %d · HP, MP and attack increased"%[Pets.display_name(Pets.skin(key),game.settings.forest_pet_names),game.model.team_progression.pet_experience[key].level])
 return leveled

func apply_pet_growth(handle:int,key:String,heal:bool=false):
 var progression=game.model.team_progression
 var applied:bool=native.set_pet_growth(handle,progression.pet_health_bonus(key),progression.pet_damage_bonus(key))
 assert(applied,"Invalid companion growth")
 applied=native.set_pet_training(handle,1.0+.05*progression.pet_rank(key,"speed"),1.0+.10*progression.pet_rank(key,"attack_speed"),progression.pet_mana_bonus(key),heal)
 assert(applied,"Invalid companion training")
 var row=unit_state(handle)
 var dodge=.01*progression.pet_rank(key,"dodge_chance");var counter=.01*progression.pet_rank(key,"counter_chance")
 if not is_equal_approx(row.dodge_chance,dodge) or not is_equal_approx(row.counter_chance,counter):
  applied=native.set_boss_reactions(handle,dodge,counter)
  assert(applied,"Invalid companion reactions")

func begin_combined_power(target:Node)->bool:
 if hound_order!=HoundOrder.COMBINED:return false
 finish_integration()
 if not combined_committed:
  combined_origin=game.player.global_position;combined_facing=game.player.facing
  game.player.active_ability.combined_queued=false;game.player.active_ability.combined_queue_target=null
 combined_committed=true;combined_contacted=false
 native.set_targets(external_targets())
 var handle:int=target.handle if is_instance_valid(target) and target.get("runtime")==self else 0
 if not native.begin_combined_power(handle,game.player.active_ability.combined_windup()):combined_committed=false;return false
 sync_compatibility();presentation_dirty=true
 return true

func strike_combined_power():
 if not combined_committed or combined_contacted:return
 finish_integration();combined_contacted=true
 var connected:int=native.strike_combined_power()
 dispatch_events();game.player.active_ability.confirm_combined_hits(connected)
 presentation_dirty=true

func finish_combined_power(cancel_attack:bool=false,return_player:bool=true):
 combined_committed=false;combined_contacted=false
 var p=game.player
 if is_instance_valid(p) and p.hp>0 and not game.transitioning:
  p.active_ability.combined_queued=false;p.active_ability.combined_queue_target=null
  p.active_ability.primary_hold_target=null
  if return_player:p.move_and_collide(combined_origin-p.global_position);p.velocity=Vector3.ZERO;p.facing=combined_facing
  if cancel_attack or p.active_ability.mode=="combined_wait":p.active_ability.cancel(true)
  if return_player:
   p.model.rotation.y=atan2(-p.facing.x,-p.facing.z)
   p.model.animate(0,0,p.is_on_floor(),0,0,false,0,false)
 native.set_targets(external_targets());native.end_combined_power();dispatch_events()
 presentation_dirty=true

func order_hounds(order:int,focus:int=0,attack_move:Vector3=Vector3(INF,0,0))->bool:
 if combined_committed:return false
 finish_integration()
 for id in handles:
  if id<=HOUND_ID and valid(handles[id]):
   var state=unit_state(handles[id])
   if state.team!=1 or state.kind not in [Roles.GATEKEEPER_HOUND,Roles.CAVE_BEAR]:continue
   if order==HoundOrder.COMBINED and state.kind!=Roles.GATEKEEPER_HOUND:continue
   var was_combined=hound_order==HoundOrder.COMBINED
   hound_order=order;hound_order_serial+=1;hound_focus_target=focus if order==HoundOrder.ATTACK else 0
   hound_attack_move=attack_move if order==HoundOrder.ATTACK and focus==0 else Vector3(INF,0,0)
   hound_focus_actor=null
   if pet_skills!=null:
    if order==HoundOrder.ATTACK and (attack_move.is_finite() or focus!=0):
     for caster in pet_skills.casters.values():caster.finish_cast()
    if order==HoundOrder.COMBINED:pet_skills.clear()
    elif was_combined:pet_skills.reconcile()
   if hound_focus_target!=0 and valid(hound_focus_target):hound_focus_actor=enemy_target(unit_state(hound_focus_target).logical_id)
   return true
 return false

func focused_enemy():
 return hound_focus_actor if is_instance_valid(hound_focus_actor) and not hound_focus_actor.dead and hound_focus_actor.hp>0 else null

func queue_cave_bears():
 for i in 5:
  pending_cave_bears.append(cave_bear_serial)
  cave_bear_serial+=1

func import_hounds():
 import_guards(pending_hounds,Roles.GATEKEEPER_HOUND)

func import_guards(pending:Array[int],kind:int):
 if pending.is_empty():return
 var center:Vector3=game.player.global_position
 var selected=Pets.sanitized(game.settings.forest_pet_loadout)
 var forward:Vector3=game.player.facing.normalized()
 var right=Vector3(-forward.z,0,forward.x)
 var hp:float=Pets.BASE_HEALTH*(game.model.team_progression.multiplier("pet_health") if kind==Roles.GATEKEEPER_HOUND else 1.0)
 var batch_size=pending.size() if kind==Roles.GATEKEEPER_HOUND and not beast_pet_orders.is_empty() else mini(3,pending.size())
 var ordinary_left=3
 for member in batch_size:
  var member_id:int=pending[0]
  var skin:int=member_id if kind==Roles.GATEKEEPER_HOUND else Habaru.VENOA_BEAR_SKIN
  var beast=kind==Roles.GATEKEEPER_HOUND and beast_pet_orders.has(skin)
  if not beast:
   if ordinary_left==0:
    pending.push_back(pending.pop_front());continue
   ordinary_left-=1
  var radius=Roles.footprint_radius(kind)
  if not pet_geometry.is_empty():radius*=pet_geometry[preload("res://scripts/forest/crowd/pet_dimensions.gd").offset(kind,skin)+6]
  if kind==Roles.GATEKEEPER_HOUND:
   var body=preload("res://scripts/forest/crowd/pet_dimensions.gd").companion_body(skin)
   radius=Vector2(body.size.x,body.size.z).length()*.5
  var pad=Vector3(radius+.15,1,radius+.15)
  var ring=(member_id%21)/7
  var angle=(member_id%7)*TAU/7+ring*.34+floori(member_id/21.0)*.21
  var formation_slot=selected.find(Pets.key(skin)) if kind==Roles.GATEKEEPER_HOUND else -1
  var placed=false
  for attempt in (2 if beast else 28):
   var yaw=angle+attempt*2.399963
   var distance=9.0+((ring+attempt/7)%3)*3.0 if kind==Roles.CAVE_BEAR else 5.0+((ring+attempt/7)%4)*3.6
   var point=center+Vector3(sin(yaw),0,cos(yaw))*distance
   if attempt==0 and formation_slot>=0 and formation_slot<PET_FORMATION_POSTS.size():
    var post:Vector3=PET_FORMATION_POSTS[formation_slot]
    point=center+right*post.x+forward*post.z
   if beast and attempt==1:
    # The native step validates the landing before the pet is presented.
    point=center
    if not native.ally_ground_clear(point,0.0):point.y=game.world.height_at(point.x,point.z)
   else:
    var supported:bool=beast and native.ally_ground_clear(point,radius)
    if not supported:point.y=game.world.height_at(point.x,point.z)
    if absf(point.y-center.y)>4 or (not supported and not native.ally_ground_clear(point,radius)):continue
   if not beast:
    var bounds=AABB(point-pad,pad*2)
    if not native.query_aabb(bounds,1).is_empty() or not native.query_aabb(bounds,0).is_empty():continue
   var handle=spawn((HOUND_ID if kind==Roles.GATEKEEPER_HOUND else CAVE_BEAR_ID)-member_id,1,kind,point,hp,radius)
   if handle==0:return
   var assigned:bool=native.set_pet_skin(handle,skin)
   assert(assigned,"Invalid guard companion appearance")
   if kind==Roles.GATEKEEPER_HOUND and game.model.team_progression.pet_experience.has(Pets.key(skin)):
    apply_pet_growth(handle,Pets.key(skin),true)
   if kind==Roles.GATEKEEPER_HOUND and recalled_pet_mana.has(skin):
    var restored:bool=native.set_pet_mana(handle,recalled_pet_mana[skin])
    assert(restored,"Invalid recalled pet mana")
    if restored:recalled_pet_mana.erase(skin)
   native.set_pose(handle,point,yaw+PI);native.set_guard(handle,point,HOUND_GUARD_RADIUS)
   if beast:
    var order:Dictionary=beast_pet_orders[skin]
    var queued:bool=native.queue_beast_pet_attacks(handle,int(order.waiting))
    assert(queued,"Invalid Beast Master summon queue")
    order.waiting=0;order.left=BEAST_PET_RECALL_DELAY;order.arriving=true
   else:
    if kind==Roles.GATEKEEPER_HOUND and pet_skills!=null:pet_skills.reconcile()
    presentation_events.append({"kind":"hound_summon","position":point})
   pending.pop_front();placed=true;break
  if not placed:pending.push_back(pending.pop_front())

func sync_compatibility():
 var clock=Time.get_ticks_usec() if profile_enabled else 0
 latest=render_snapshot();reaction_dirty=false;clock=profile_mark("compatibility_snapshot",clock)
 latest.plain_fields=get_tree().get_meta("forest_army_plain_fields",true)
 latest.profile_facades=profile_enabled and get_tree().get_meta("forest_army_profile_facades",false)
 latest.profile_registered=profile_enabled and get_tree().get_meta("forest_army_profile_registered",false)
 snapshot_epoch+=1;model_rows_seen.clear();snapshot_view=Snapshot.new(latest);latest.shared_facades=shared_snapshot_enabled;latest.guard_poses=get_tree().get_meta("forest_army_guard_poses",true);clock=profile_mark("compatibility_view",clock)
 ally_fields_epoch=snapshot_epoch if shared_snapshot_enabled else -1;latest.lazy_ally_fields=shared_snapshot_enabled;latest.defer_model_rows=true;latest.event_enemy_health=true
 var transferred=-1
 if shared_snapshot_enabled and latest.plain_fields and not latest.profile_facades and get_tree().get_meta("forest_army_registered_facades",true):transferred=native.sync_registered_facades(latest)
 if transferred<0:
  native.sync_facades(latest,game.model.enemies,enemies,allies,snapshot_view);model_rows_epoch=snapshot_epoch
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
   # Keep query/source counts paired until the same facade cleanup boundary.
   if is_instance_valid(actor):
    query_actors.erase(actor.handle);game.enemies.erase(actor)
    if actor.sequence_users>0:pending_retirements[id]=true;continue
    actor.queue_free()
   game.actors.erase(id);enemies.erase(id)
 profile_mark("compatibility_cleanup",clock)
func register_actor_facade(actor:Node3D,row:Dictionary={})->bool:
 if actor is Ninja:model_rows_epoch=-1;model_rows_seen.erase(actor.handle)
 return super.register_actor_facade(actor,row)
func publish_model_rows(requested:PackedInt64Array=PackedInt64Array()):
 if latest.is_empty() or model_rows_epoch==snapshot_epoch:return
 var clock=Time.get_ticks_usec() if profile_enabled else 0
 var count=0
 if requested.is_empty():
  count=native.sync_model_rows();model_rows_epoch=snapshot_epoch
 else:
  var fresh=PackedInt64Array()
  for handle in requested:
   if not model_rows_seen.has(handle):fresh.append(handle);model_rows_seen[handle]=true
  if not fresh.is_empty():count=native.sync_model_rows_for(fresh)
 if count>0:model_rows_written+=count;model_rows_publications+=1
 profile_mark("model_rows",clock)
func _enemy_retired(id:int)->void:
 boss_handles.erase(id)
 pending_retirements[id]=true
func set_guard(handle:int,point:Vector3,radius:float):native.set_guard(handle,point,radius)
func target_actor(id:int)->Node3D:return ally_target(id) if id<0 else enemy_target(id)
func summon(slot:int)->bool:return game.explorer_helpers.request(slot)
func rest():
 if combined_committed:return
 recall_beast_pets()
 if pet_skills!=null:pet_skills.clear()
 native.rest_allies();navigation_revision=-1;presentation_events.clear();pet_participants.clear()
 if pet_skills!=null:pet_skills.reconcile()
 sync_targets()
func begin_wave():
 for unit in game.explorer_helpers.active_units():unit.state="acting";unit.age=0
func external_targets()->Dictionary:
 var rows={"ids":PackedInt64Array(),"kinds":PackedInt32Array(),"positions":PackedVector3Array(),"hp":PackedFloat32Array(),"targetable":PackedByteArray(),"taunting":PackedByteArray(),"minimum":PackedVector3Array(),"maximum":PackedVector3Array(),"ignore_building":PackedInt64Array(),"assault_priority":PackedInt32Array(),"shelter_ids":PackedInt64Array(),"shelter_damage":PackedInt64Array(),"shelter_entrances":PackedVector3Array(),"shelter_centers":PackedVector3Array()}
 var velocity:Vector3=game.player.velocity
 rows.player_aggro_kills=game.model.aggro_kills
 rows.player_map_swarm=game.model.waves.get("swarm_active")==true
 rows.hound_player_speed=Vector2(velocity.x,velocity.z).length()
 rows.pet_formation_facing=game.player.facing
 var formation_ids=PackedInt64Array()
 for key in Pets.sanitized(game.settings.forest_pet_loadout):formation_ids.append(HOUND_ID-Pets.skin(key))
 rows.pet_formation_ids=formation_ids
 if game.player.RogueRoster.is_crossgate_fighter(game.player.character_id):
  rows.combined_player_attacking=combined_committed and (game.player.active_ability.is_attacking() or game.player.impact_pause>0 or game.player.timed_dodge.rescue_left>0)
  rows.player_attack_serial=game.player.active_ability.guard_threat()
  rows.player_attack_facing=game.player.facing
  rows.player_attack_reach=maxf(6.0,game.player.active_ability.melee_visual_reach())
  rows.player_guarding=game.player.crossgate_guarding() and game.player.invuln<=0 and not game.tuning.invincible
  rows.player_evading=game.player.timed_dodge.evading_charge()
  rows.player_bodyguard=game.player.timed_dodge.bodyguard_equipped and game.player.cursed_afflictions[1]<=0 and game.player.cursed_afflictions[2]<=0
  rows.player_bodyguard_level=clampi(preload("res://scripts/spells/skill_balance.gd").level_for(game.player,preload("res://scripts/spells/spell_catalog.gd").BODYGUARD),1,30)
 rows.hound_order_serial=hound_order_serial
 if hound_order==HoundOrder.ATTACK and hound_attack_move.is_finite():rows.hound_attack_move=hound_attack_move
 if hound_focus_target!=0:rows.hound_focus_target=hound_focus_target
 if hound_order!=HoundOrder.DEFEND:rows.hound_order=hound_order
 var camera=get_viewport().get_camera_3d()
 if camera!=null:
  var right=camera.global_basis.x
  rows.hound_camera_yaw=atan2(-right.z,right.x)
 var bounds=AABB()
 if game.player.RogueRoster.is_enemy(game.player.character_id):bounds=game.player.global_transform*game.player.model.bounds()
 var outer_road=not game.model.falan_road.is_empty()
 var map_scale:float=game.model.falan_scale
 # Targetability follows the same boundary as native patrol movement.
 var exposed=game.model.FalanFrontier.enemy_exposed(game.model,Vector2(game.player.position.x,game.player.position.z)/map_scale)
 append_target(rows,0,0,game.player.position,game.player.hp,exposed and not game.player.rogue_untargetable() and game.respawn_left<=0,game.player.character_id==33 and game.player.active_ability.taunt_left>0,bounds.position,bounds.end)
 if outer_road:return rows
 for w:Dictionary in game.model.workers.values():
  if not game.model.worker_targetable(w.id):continue
  var deck:float=preload("res://scripts/forest/forest_structure_profile.gd").TOWER_DECK_HEIGHT if w.state=="garrison" else w.get("deck_height",0.0)
  append_target(rows,w.id,1,w.pos+Vector3.UP*deck,w.hp)
 for b:Dictionary in game.model.buildings.values():
  if b.hp<=0 or b.kind=="wall" or b.get("breached",false):continue
  if b.kind=="barracks":rows.shelter_ids.append(b.id);rows.shelter_damage.append(b.get("damage_serial",0));rows.shelter_entrances.append(game.model.point(game.model.entry(b))*map_scale);rows.shelter_centers.append(game.model.center(b)*map_scale)
  var size:Vector2i=game.model.dimensions(b.kind,b.rotation,b.get("span",0));var low:Vector3=game.model.point(b.cell)-Vector3(3,0,3)
  low.y=game.model.center(b).y
  var high=low+Vector3(size.x*6,preload("res://scripts/forest/forest_structure_profile.gd").height(b.kind),size.y*6)
  append_target(rows,b.id,2,game.model.center(b)*map_scale,b.hp,true,false,low*map_scale,high*map_scale,b.id,4 if b.kind in ["barracks","tower","cannon_tower"] else 2 if b.kind=="shrine" else 1 if b.kind=="gate" else 0)
 return rows
func append_target(rows:Dictionary,id:int,kind:int,point:Vector3,hp:float,targetable_:bool=true,taunt:bool=false,low:Vector3=Vector3.ZERO,high:Vector3=Vector3.ZERO,ignore:int=-1,assault_priority:int=0):
 rows.ids.append(id);rows.kinds.append(kind);rows.positions.append(point);rows.hp.append(hp);rows.targetable.append(1 if targetable_ else 0);rows.taunting.append(1 if taunt else 0);rows.minimum.append(low);rows.maximum.append(high);rows.ignore_building.append(ignore);rows.assault_priority.append(assault_priority)

func clear():
 finish_integration()
 combined_committed=false
 combined_contacted=false
 if is_instance_valid(game) and is_instance_valid(game.player) and is_instance_valid(game.player.active_ability) and game.player.active_ability.mode=="combined_wait":game.player.active_ability.cancel(true)
 if pet_skills!=null:pet_skills.clear()
 # Paid guard facade nodes belong to the hiring UI pool across resets.
 for unit in allies.values():
  if is_instance_valid(unit) and unit.get("director")!=null:unit.handle=0;unit.hp=0;unit.state="idle";unit.dead=false;unit.targetable=false
 allies.clear()
 super.clear()
 boss_handles.clear()
 hound_order=HoundOrder.DEFEND;hound_order_serial=0;hound_focus_target=0;hound_focus_actor=null
 hound_attack_move=Vector3(INF,0,0)
 recalled_pet_mana.clear();pet_participants.clear()
 pending_hounds.clear();beast_pet_orders.clear();pending_cave_bears.clear();cave_bear_serial=0;latest={};model_rows_epoch=-1;model_rows_seen.clear();arrival_rows.clear();arrival_ids.clear();pending_retirements.clear();retirement_reconcile=true;presentation_delta=0;presentation_dirty=false;reaction_dirty=false

func preparation_tick(delta:float):
 if not game.playing or game.model.phase!="preparing" or game.ordinary_pause or game.settings_open or game.rogue_roster_open or game.transitioning or (is_instance_valid(game.map_editor) and game.map_editor.active):return
 if not configured_helpers or configured_tuning!=hash([game.character_tuning,game.tuning,game.model.balance]):refresh_kits()
 native.set_targets(external_targets());native.rest_tick(delta);sync_compatibility()
 presentation_dirty=true

func flush_presentation():
 if not presentation_dirty:return
 var clock=Time.get_ticks_usec() if profile_enabled else 0
 # Coalesce post-step player hits into one fresh render snapshot per frame.
 if reaction_dirty:latest=render_snapshot();reaction_dirty=false
 game.crowd.army.presentation.tick(presentation_delta)
 clock=profile_mark("presentation_tick",clock)
 game.crowd.present_army(latest,presentation_events)
 presentation_events=[];presentation_delta=0;presentation_dirty=false;presentation_frames+=1
 profile_mark("presentation",clock)

func _process(_delta:float):
 if not is_instance_valid(game) or not is_instance_valid(game.crowd) or not is_instance_valid(game.crowd.army):return
 flush_presentation()
 if blocked() or game.sound_library.recording or float(game.settings.get("volume",.65))<=0:game.crowd.army.presentation.suspend_audio()
