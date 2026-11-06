extends "res://tests/forest-shrine/large_army_benchmark.gd"
## Normal native army plus pooled legendary bodies, with the current effects intact.
# Fixed native IDs preserve the random skill workload across allocation changes.
class StableMirrors extends "res://scripts/warcraft_mirrors.gd":
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
  var handle:int=runtime.spawn(-1000000000-bodies.find(body),1,100+character,point,body.max_hp,.4)
  var reach=Kit.MELEE_REACH if character in [31,32,33] else 3.0
  if handle==0 or not runtime.native.set_mirror(handle,body.actions.size(),body.combat_tuning("walk_speed")*body.movement_multiplier(),reach*body.contact_size_multiplier()*body.melee_reach_setting(),Vector3.FORWARD):
   if handle!=0:runtime.despawn(handle)
   body.retire();return false
  body.native_handle=handle
  # Permanent card recruits share mercenary pursuit and terrain-height goals.
  runtime.native.set_guard(handle,point,18.0)
  handles.resize(bodies.size());handles[bodies.find(body)]=handle;left=INF
  if not runtime.mirror_action.is_connected(_action):runtime.mirror_action.connect(_action)
  if not runtime.mirrors_advanced.is_connected(tick):runtime.mirrors_advanced.connect(tick)
  return true
const HERO_IDS=[1,13,15,16,17,28,31,32]
var new_allies=0
var hero_serial=0
var hero_by_actor={}
var hero_effects={}
var effect_heroes_seen={}
var hero_starts={}
var was_attacking={}
var peak_attacking=0
var peak_crescents=0
var hero_replacements=0
var hero_samples=[]
var next_sample=0.0
var player_ready=false
func spawn_enemy():
 if not player_ready:
  for path in ["scripts/geo.gd","scripts/spirit_fortress_effects.gd","scripts/melee_assist.gd","native/terrain_math/crowd/air.cpp","tests/forest-shrine/army_benchmark_metrics.gd","tests/forest-shrine/large_army_benchmark.gd","tests/forest-shrine/crescent_battle_benchmark.gd"]:fingerprints[path]=FileAccess.get_sha256("res://"+path)
  game.player.select_character(1);player_ready=true
  game.explorer_helpers.legendary_heroes.dispose()
  game.explorer_helpers.legendary_heroes=StableMirrors.new(game.player,0)
  for path in ["scripts/recovered_goemon_vfx.gd","scripts/sky_strike.gd","scripts/kojiro_projectile.gd","scripts/character_balance.gd","scripts/hero_model.gd","scripts/recovered_goemon_pose.gd","scripts/recovered_sasuke_pose.gd","scripts/recovered_yae_pose.gd","scripts/forest/crowd/army_runtime.gd","scripts/forest/crowd/army_coordinator.gd","scripts/recovered_leader_trail.gd","scripts/recovered_musashi_trail.gd","scripts/kojiro_model.gd","scripts/recovered_goemon_model.gd","scripts/recovered_leader_model.gd","scripts/recovered_sasuke_model.gd","scripts/recovered_yae_model.gd","scripts/warcraft_model.gd","scripts/warcraft_mirrors.gd","scripts/forest/crowd/mirror_body.gd","assets/rogue/scripts/magic_sword_brush.gd","assets/rogue/shaders/magic_ink_brush.gdshader"]:fingerprints[path]=FileAccess.get_sha256("res://"+path)
 super.spawn_enemy()
func spawn_ally(slot:int,unit:Node=null):
 if unit==null:
  var legendary=new_allies%5==4;new_allies+=1
  if legendary:
   spawn_hero(HERO_IDS[hero_serial%HERO_IDS.size()]);hero_serial+=1;return
 super.spawn_ally(slot,unit)
func spawn_hero(character:int):
 var owner=game.explorer_helpers.legendary_heroes
 var point:Vector3=ally_points[ally_cursor%ally_points.size()];ally_cursor+=1
 if not owner.reinforce(character,point):printerr("FAIL: Native hero allocation rejected");stopped=true;return
 for body in owner.bodies:
  var actor_id=-1000000000-owner.bodies.find(body)
  if hero_by_actor.has(actor_id):continue
  hero_by_actor[actor_id]=body
  var model=body.model;var effects=[]
  match character:
   1:effects=[model.reach_trail]
   13:effects=[model.sword_trail,model.dual_sword_trail]
   15:effects=[model.sword_trail]
   16,17:effects=model.reach_trails
   28:effects=[model.trail]
   31,32:effects=model.blade_trails.map(func(b):return b.trail)
  hero_effects[actor_id]=effects
func reinforce(event:Dictionary):
 if event.team==1 and hero_by_actor.has(int(event.target_id)):
  if stopped:return
  var body=hero_by_actor[int(event.target_id)];var state=army.unit_state(body.native_handle)
  if body.leased and (state.is_empty() or float(state.get("hp",0))<=0):body.retire()
  spawn_hero(body.character_id);hero_replacements+=1;replacements+=1
 else:super.reinforce(event)
func _process(delta:float)->bool:
 if phase=="measuring":
  var attacking=0;var crescents=0
  for actor_id in hero_by_actor:
   var body=hero_by_actor[actor_id]
   if not body.leased:continue
   var active=body.has_offensive_action()
   if active:
    attacking+=1
    if not was_attacking.get(actor_id,false):hero_starts[body.character_id]=int(hero_starts.get(body.character_id,0))+1
   was_attacking[actor_id]=active
   for effect in hero_effects[actor_id]:
    if effect.mesh!=null and effect.is_visible_in_tree() and effect.layers!=0:
     crescents+=1;effect_heroes_seen[actor_id]=body.character_id
  peak_attacking=maxi(peak_attacking,attacking);peak_crescents=maxi(peak_crescents,crescents)
  var elapsed=(Time.get_ticks_usec()-started)/1000000.0
  if elapsed>=next_sample:
   next_sample=elapsed+1
   hero_samples.append({"seconds":elapsed,"attacking":attacking,"crescents":crescents,"bodies":game.explorer_helpers.legendary_heroes.bodies.size(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"memory":OS.get_static_memory_usage()})
 return super._process(delta)
func finish():
 var visible_by_character={}
 for character in effect_heroes_seen.values():visible_by_character[character]=int(visible_by_character.get(character,0))+1
 var summary={"visible_effect_heroes_by_character":visible_by_character,"hero_ids":hero_by_actor.keys(),"hero_roster":HERO_IDS,"hero_bodies":game.explorer_helpers.legendary_heroes.bodies.size(),"hero_starts":hero_starts,"hero_replacements":hero_replacements,"hero_bodies_with_visible_crescents":effect_heroes_seen.size(),"peak_attacking_heroes":peak_attacking,"peak_visible_crescents":peak_crescents,"samples":hero_samples,"quality":game.settings.quality,"reduced_flashes":game.settings.get("reduced_flashes",false),"note":"Native AI, normal HP/damage/cooldowns, same effect source and art. Hero starts count transitions into offensive actions; continuous combos may contain more attacks."}
 DirAccess.make_dir_recursive_absolute(out)
 FileAccess.open(out+"/mixed-effects.json",FileAccess.WRITE).store_string(JSON.stringify(summary,"  "))
 var compact=summary.duplicate();compact.erase("samples");print("CRESCENT_BATTLE_EFFECTS ",JSON.stringify(compact))
 if peak_attacking<8 or peak_crescents<4 or effect_heroes_seen.size()<12:printerr("FAIL: Mixed battle did not exercise enough simultaneous hero effects");stopped=true
 super.finish()
