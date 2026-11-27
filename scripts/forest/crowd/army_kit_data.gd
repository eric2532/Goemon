extends RefCounted
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
const Winter=preload("res://scripts/forest/forest_frostpass.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
## Shared animation wire codes; native simulation consumes these values.
const ACTION={"walk":0,"melee_a":1,"combo_prepare":2,"melee_b":3,"fire":4,"reload":5,"hurt":6,"dead":7,"primary":8,"shadow_cut":9,"lance_leap":10,"landing_pulse":11,"ranger_fan":12,"guard":13,"code":14,"buff":15,"lance_sweep":16}
const Habaru=preload("res://scripts/forest/crowd/habaru_sprites.gd")
const Zombie=preload("res://scripts/forest/crowd/zombie_sprites.gd")
const Captain=preload("res://scripts/forest/crowd/captain_sprites.gd")
const Grave=preload("res://scripts/forest/crowd/grave_sprites.gd")
const Ruby=preload("res://scripts/forest/crowd/ruby_boss_sprites.gd")
const Falken=preload("res://scripts/forest/crowd/falken_sprites.gd")
const Undersea=preload("res://scripts/forest/crowd/undersea_sprites.gd")
const Patrols=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
const Cursed=preload("res://scripts/forest/crowd/cursed_maze_sprites.gd")
const Beast=preload("res://scripts/forest/crowd/beast_maze_sprites.gd")
const University=preload("res://scripts/forest/crowd/university_region_sprites.gd")
const East=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const Sites=preload("res://assets/maps/falan/freyja_destinations_data.gd")
const STATUS={"frozen":1,"slow":2,"stunned":4,"invulnerable":8,"guard":16,"buff":32,"untargetable":64}
static func from_model(model:RefCounted,damage_taken_multiplier:float=1.0,game:Node=null)->Dictionary:
 var roles=preload("res://scripts/forest/forest_enemy_roles.gd")
 var kinds=PackedInt32Array(roles.NATIVE_TYPES);var profiles=PackedFloat32Array()
 var bear_cave:bool=model.falan_floor==Habaru.ROOM or Sites.VENOA_BEARS.has(model.falan_floor)
 var habaru_passage:bool=Habaru.SLIME_CELLS.has(model.falan_floor)
 var zombie:bool=Sites.ZOMBIE_FORMATIONS.has(model.falan_floor)
 var captain:bool=model.falan_floor==Captain.ROOM or model.falan_floor>=14017 and model.falan_floor<=14039
 var tina_flowers:bool=model.falan_floor in [32193,32194]
 var grave:bool=model.falan_floor==Grave.ROOM
 var ruby:bool=model.falan_floor==Ruby.ROOM or model.falan_floor in Prayer.FLOORS
 var falken:bool=Falken.Route.owns(model.falan_floor)
 var undersea:bool=Undersea.PATROLS.has(model.falan_floor)
 var snow:bool=preload("res://scripts/forest/crowd/snow_region_sprites.gd").owns(model.falan_floor)
 var university:bool=University.owns(model.falan_floor)
 var eastern:bool=East.owns_model(model)
 var elsa:bool=preload("res://scripts/forest/crowd/elsa_region_sprites.gd").owns(model.falan_floor)
 var frontier:bool=not model.waves.patrol_posts.is_empty() or preload("res://scripts/forest/forest_south_kili_population.gd").encounters_own(model) or eastern
 var cursed:bool=Winter.Decree.floor_number(model.falan_floor)>0
 var beast:bool=Winter.Recovered.Beast.owns(model.falan_floor)
 var use_slimes:bool=bear_cave or habaru_passage or zombie or captain or tina_flowers or grave or ruby or falken or undersea or model.waves.crossgate_pet_test or frontier or cursed or beast or snow or university or elsa
 if use_slimes:kinds.append(roles.SLIME)
 for kind in kinds:
  var stats:Dictionary=roles.stats(kind) if kind in [roles.GATEKEEPER_HOUND,roles.CAVE_BEAR] else model.waves.role_stats(kind)
  if bear_cave and kind==roles.SLIME:stats.merge(Habaru.STATS,true)
  if habaru_passage and kind==roles.SLIME:
   stats.range=2.85
   stats.stride=2.3
  if zombie and kind==roles.SLIME:stats.merge(Zombie.STATS,true)
  if captain and kind==roles.SLIME:stats.merge(Captain.STATS,true)
  if tina_flowers and kind==roles.SLIME:stats.merge(preload("res://scripts/forest/crowd/tina_creatures.gd").STATS,true)
  if grave and kind==roles.SLIME:stats.merge(Grave.STATS,true)
  if ruby and kind==roles.SLIME:stats.merge(Ruby.STATS,true)
  if falken and kind==roles.SLIME:stats.merge(Falken.STATS,true)
  if undersea and kind==roles.SLIME:stats.merge(Undersea.STATS,true)
  if snow and kind==roles.SLIME:stats.merge(preload("res://scripts/forest/crowd/snow_region_sprites.gd").STATS,true)
  if university and kind==roles.SLIME:stats.merge(University.STATS,true)
  if eastern and kind==roles.SLIME:stats.merge(East.STATS,true)
  if elsa and kind==roles.SLIME:stats.merge(preload("res://scripts/forest/crowd/elsa_region_sprites.gd").STATS,true)
  if cursed and kind==roles.SLIME:stats.merge(Cursed.STATS,true)
  if beast and kind==roles.SLIME:stats.merge(Beast.STATS,true)
  for key in ["hp","speed","damage","range","turn_speed","stride"]:profiles.append(stats[key])
 var boss:Dictionary=model.waves.role_stats(4)
 var enemy_size:float=model.balance.enemy_size_mult
 var source=preload("res://scripts/forest/forest_thirstquencher_combat.gd")
 var visual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
 var result={"skullpion":PackedFloat64Array([boss.speed,boss.damage]),"enemy_size":enemy_size,"soldier_kinds":kinds,"soldier_profiles":profiles,"actions":PackedInt32Array(ACTION.values()),"status_bits":PackedInt32Array(STATUS.values()),"phase_ticks":PackedFloat32Array([source._duration("melee_a"),source._duration("combo_prepare"),source._duration("melee_b"),source._duration("fire"),source._duration("reload")]),"contact_ticks":PackedFloat32Array([13,14,15,18]),"melee_from":visual.source_point(source.MELEE_FROM)*enemy_size,"melee_to":visual.source_point(source.MELEE_TO)*enemy_size,"muzzle":visual.source_point(source.MUZZLE)*enemy_size,"bullet_speed":8.64,"bullet_life":100.0/30,"bullet_tail":32*.01*visual.SCALE*enemy_size,"bullet_radius":.576,"damage_taken_multiplier":damage_taken_multiplier}
 var evasion=PackedFloat64Array();evasion.resize(22);evasion.fill(5.0)
 for kind in preload("res://scripts/forest/core_balance.gd").profile_types():
  evasion[kind]=float(preload("res://scripts/forest/enemy_balance.gd").base_stats(model.balance,kind).dodge_chance)
 result.enemy_evasion=evasion
 result.merge(preload("res://scripts/forest/dark_lumina_3_kit.gd").native())
 result.dark_lumina=preload("res://scripts/forest/dark_lumina_kit.gd").native()
 result.dark_lumina_spin=roles.Dark.native_spin(visual.data(roles.DARK_LUMINA_2))
 result.hound_move_scale=model.team_progression.multiplier("pet_speed")
 result.hound_hp=Pets.BASE_HEALTH*model.team_progression.multiplier("pet_health")
 result.hound_damage=Pets.BASE_DAMAGE*model.team_progression.multiplier("pet_damage")
 result.bear_damage=Pets.BASE_DAMAGE
 result.pet_mana=Pets.BASE_MANA
 result.pet_mana_regen=Pets.MANA_REGEN
 result.pet_skill_costs=Pets.native_mana_costs()
 result.pet_ranged_reach=Pets.RANGED_REACH
 result.bear_attacks=expanded_timelines(PackedFloat32Array(Habaru.motions().timelines))
 result.hound_attacks=PackedFloat32Array(Pets.motions().timelines)
 if model.falan_floor in Winter.SNOW_FLOORS:
  result.snow_patrol_skins=PackedInt32Array(Winter.creature_keys(model.falan_floor).map(func(key):return Pets.skin(key)))
 result.cave_sprites=Habaru if bear_cave or habaru_passage else Zombie if zombie else Captain if captain else Grave if grave else Ruby if ruby else Falken if falken else Undersea if undersea else model.waves.patrol_source if frontier else Cursed if cursed else Beast if beast else null
 if snow:result.cave_sprites=preload("res://scripts/forest/crowd/snow_region_sprites.gd")
 if university:result.cave_sprites=University
 if eastern:result.cave_sprites=East
 if elsa:result.cave_sprites=preload("res://scripts/forest/crowd/elsa_region_sprites.gd")
 if model.falan_floor in [11000,11001,11002]:result.cave_sprites=preload("res://scripts/forest/crowd/venoa_route_sprites.gd")
 if tina_flowers:result.cave_sprites=preload("res://scripts/forest/crowd/tina_creatures.gd")
 var dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
 result.enemy_charge=dimensions.exploring(model)
 result.map_enemy_scale=roles.MAP_ENEMY_SCALE
 result.pet_geometry=dimensions.geometry(result.cave_sprites,dimensions.exploring(model),roles.MAP_ENEMY_SCALE)
 result.undersea_boss=model.falan_floor==Undersea.SOKIA
 result.slime_approach_boost=model.terrain_detail==model.Arena.ID and model.waves.crossgate_pet_test
 result.slime_guard=use_slimes and (result.cave_sprites in [null,Patrols,preload("res://scripts/forest/crowd/shalena_sprites.gd"),preload("res://scripts/forest/crowd/snow_region_sprites.gd"),preload("res://scripts/forest/crowd/elsa_region_sprites.gd"),preload("res://scripts/forest/crowd/sokia_region_sprites.gd"),University,East,Undersea] or habaru_passage or model.falan_floor==Habaru.ROOM)
 result.zombie_boss=model.falan_floor==Zombie.FINAL
 result.grave_boss=grave
 result.ruby_boss=model.falan_floor==Ruby.ROOM
 result.cursed_guardian=Winter.Decree.GUARDIAN_FLOORS.find(model.falan_floor)+1
 result.falken_boss=model.falan_floor==Falken.ROOM
 result.habaru_bears=model.falan_floor==Habaru.ROOM
 if result.cave_sprites!=null:result.slime_attacks=result.cave_sprites.timelines()
 elif use_slimes:result.slime_attacks=PackedFloat32Array(preload("res://scripts/forest/crowd/slime_sprites.gd").motions().timelines)
 if result.has("slime_attacks"):
  result.slime_attacks=expanded_timelines(result.slime_attacks,int(result.cave_sprites.motions().get("timeline_stride",28 if ruby or tina_flowers or undersea else 32 if frontier or snow or university or elsa or model.falan_floor in [11000,11001,11002] else 28)) if result.cave_sprites!=null else 28,dimensions.CAVE_SKINS)
 var pose_meta=PackedInt32Array();var pose_rows=PackedInt32Array();var enemy_kits=PackedFloat32Array();var contact_ends=PackedFloat32Array()
 for kind in kinds:
  if kind in [roles.GATEKEEPER_HOUND,roles.SLIME,roles.CAVE_BEAR]:
   # Sprite timing comes from its own immutable table; only the fitted combat box is needed here.
   for i in 8:pose_meta.append_array(PackedInt32Array([0,1]))
   contact_ends.append(0)
   enemy_kits.append_array(result.phase_ticks);enemy_kits.append_array(result.contact_ticks)
   var size:float=(1.25 if bear_cave or habaru_passage else roles.SLIME_SCALE) if kind==roles.SLIME else 1.0 if kind==roles.CAVE_BEAR else roles.HOUND_SCALE
   if kind==roles.SLIME and (ruby or falken or undersea or frontier):enemy_kits.append_array(PackedFloat32Array([0,1.1,-.3,0,1.4,-3.8,1.05,0,0,0]))
   elif kind==roles.SLIME and (zombie or captain or grave or cursed):enemy_kits.append_array(PackedFloat32Array([0,1.05,-.3,0,1.25,-2.45,.75,0,0,0]))
   elif kind==roles.SLIME:enemy_kits.append_array(PackedFloat32Array([0,.55*size,-.25*size,0,.75*size,-2.0*size,.60*size,0,0,0]))
   else:enemy_kits.append_array(PackedFloat32Array([0,.9*size,-.35*size,0,1.15*size,-2.25*size,.65*size,0,0,0]))
   var bounds:AABB=result.cave_sprites.BODY if result.cave_sprites!=null and kind==roles.SLIME else visual.hurt_bounds(kind)
   if kind==roles.SLIME and result.habaru_bears:bounds=Habaru.CHAMBER_BODY
   elif kind==roles.SLIME and habaru_passage:bounds=Habaru.SLIME_BODY
   for point in [bounds.position,bounds.end]:enemy_kits.append_array(PackedFloat32Array([point.x,point.y,point.z]))
   enemy_kits.append(-1)
   continue
  var resource=visual.data(kind);var clips:Dictionary=resource.get_meta("clips");var semantic:Dictionary=resource.get_meta("semantics")
  var monster:bool=roles.RECOVERED.has(kind)
  var pattern:Dictionary=roles.ATTACKS.get(kind,{})
  contact_ends.append(pattern.get("contact_end",0))
  var attack:String=semantic.attack[0] if monster else "Source__801b0118"
  if monster:attack=semantic[pattern.clip][0] if semantic[pattern.clip] is Array else semantic[pattern.clip]
  var keys=[semantic.idle,semantic.walk if kind==1 else semantic.run,attack,semantic.idle,attack,semantic.attack[0],semantic.idle,semantic.hurt[0]] if monster else [semantic.idle,semantic.walk if kind==1 else semantic.run,"Source__801b0118","Source__801afd28","Source__801b01e0","Source__801b0d50","Source__801b0e48","Source__801b02a8"]
  if kind==roles.DARK_LUMINA_2:keys=[semantic.idle,semantic.walk,attack,semantic.rest,semantic.grab,semantic.fireballs,semantic.shockwave,roles.Dark.HURT_CLIP]
  for key in keys:
   var clip:Dictionary=clips.get(key,clips[semantic.idle]);var rows:PackedInt32Array=clip.rows.duplicate()
   if kind==roles.DARK_LUMINA_2 and key==attack:rows.append_array(clips[semantic.recover].rows)
   pose_meta.append_array(PackedInt32Array([pose_rows.size(),rows.size()]));pose_rows.append_array(rows)
  # Five phase lengths, four markers, fitted melee segment/radius, travel,
  # opening phase, combo flag, actor-local OBB and next form share one engine.
  var durations:PackedFloat32Array=result.phase_ticks.duplicate();var markers:PackedFloat32Array=result.contact_ticks.duplicate()
  var from:Vector3=result.melee_from;var to:Vector3=result.melee_to;var radius=.576;var travel=0.0
  if monster:
   durations[0]=clips[attack].ticks;markers[0]=pattern.contact
   from=visual.source_point(pattern.from)*enemy_size
   to=visual.source_point(pattern.to)*enemy_size
   radius=pattern.get("radius",.42)*enemy_size
   travel=model.waves.role_stats(kind).speed*pattern.travel
   if kind==roles.DARK_LUMINA_3:
    from*=roles.DARK_LUMINA_3_SCALE;to*=roles.DARK_LUMINA_3_SCALE;radius*=roles.DARK_LUMINA_3_SCALE
  if kind==roles.DARK_LUMINA_2:
   # The enlarged claw sweeps ground-level fighters as well as larger bodies.
   from*=Vector3(roles.Dark.SCALE*roles.Dark.ATTACK_RANGE,1,roles.Dark.SCALE*roles.Dark.ATTACK_RANGE);to*=Vector3(roles.Dark.SCALE*roles.Dark.ATTACK_RANGE,1,roles.Dark.SCALE*roles.Dark.ATTACK_RANGE);radius*=roles.Dark.SCALE*roles.Dark.ATTACK_RANGE
   for i in 5:durations[i]=clips[keys[i+2]].ticks
   durations[0]+=clips[semantic.recover].ticks
  enemy_kits.append_array(durations);enemy_kits.append_array(markers)
  for point in [from,to]:enemy_kits.append_array(PackedFloat32Array([point.x,point.y,point.z]))
  enemy_kits.append_array(PackedFloat32Array([radius,travel,3 if kind==1 else 0,1 if kind==0 else 0]))
  var box:AABB=visual.hurt_bounds(kind);box=AABB(box.position*enemy_size,box.size*enemy_size)
  for point in [box.position,box.end]:enemy_kits.append_array(PackedFloat32Array([point.x,point.y,point.z]))
  enemy_kits.append(pattern.get("next_form",-1))
 result.enemy_kits=enemy_kits
 result.enemy_contact_ends=contact_ends
 result.soldier_pose_meta=pose_meta;result.soldier_pose_rows=pose_rows
 var kinds_=PackedInt32Array([11,5,8,10,7]);var ally_profiles=PackedFloat64Array();var primaries=PackedFloat64Array()
 var baked:Dictionary=load("res://assets/crowd/army_kit_profiles.tres").get_meta("profiles").duplicate(true)
 var tuned={"poses":{}}
 if game!=null:
  tuned=preload("res://scripts/forest/crowd/army_tuning.gd").prepare(game);baked=tuned.profiles
  for kind in kinds_:
   baked[kind].damage_multiplier=game.balance_value(kind,"damage_mult")
   baked[kind].speed=game.balance_value(kind,"walk_speed")
   baked[kind].critical_chance=game.balance_value(kind,"critical_chance")
   baked[kind].jump_speed=game.balance_value(kind,"jump_speed")*sqrt(game.balance_value(kind,"jump_height"))
 for kind in kinds_:
  var row:Dictionary=baked[kind]
  for field in ["hp","speed","damage_multiplier","attack_rate","critical_chance"]:ally_profiles.append(row[field])
  for attack in row.primary:
   for field in ["duration","contact","damage","reach","arc","stop","swingSide"]:primaries.append(attack.get(field,1))
 result.pose_resources=tuned.poses
 result.ally_kinds=kinds_;result.ally_profiles=ally_profiles;result.ally_primaries=primaries
 var cadence=PackedFloat64Array();var user_run=preload("res://scripts/user_stride_run.gd");var reference_run=preload("res://scripts/goemon_reference_run_body.gd")
 for kind in kinds_:
  for sample in 161:
   var speed=sample*.25
   cadence.append(user_run.cadence(speed) if user_run.enabled(baked[kind]["class"]) and speed>2.2 else reference_run.cadence(speed))
 result.walk_cadence=cadence
 var ninja:Dictionary=baked[5];var effect=float(ninja.range_scale)*float(ninja.melee_reach_scale)
 var dash=preload("res://scripts/ninja_dash_strike.gd")
 result.ninja=PackedFloat64Array([dash.DURATION,dash.SPEED,76,.85*effect,dash.FINISH_REACH*effect,dash.FINISH_WIDTH*effect,ninja.cooldowns.flintlock,ninja.cooldowns.roll,ninja.cooldowns.drink,10,ninja.range_scale,.25])
 var dragoon:Dictionary=baked[8];var scale_=float(dragoon.range_scale)
 var actions=preload("res://assets/rogue/scripts/class_actions.gd")
 # Ground sweep is not responsiveMelee; source hit() applies the heavy .075s self-stop.
 result.dragoon=PackedFloat64Array([45,38,55,30,30*scale_,5,dragoon.cooldowns.flintlock,dragoon.cooldowns.drink,10,scale_,dragoon.jump_speed,dragoon.body.radius,dragoon.body.height,dragoon.body.center,.84,.22,.12,actions.PRIMARY.dragoon.damage*3,actions.PRIMARY.dragoon.reach*scale_*float(dragoon.melee_reach_scale),PI/2,.075,64,.26,actions.dragoon_impact_radius(0),actions.dragoon_impact_radius(1),actions.dragoon_impact_radius(2)])
 var hunt=preload("res://assets/rogue/scripts/dragoon_dragon_flight.gd")
 result.dragoon.append_array(PackedFloat64Array([hunt.DURATION,hunt.SPEED,hunt.DAMAGE,hunt.WIDTH,hunt.SEEK,hunt.DASH_TIME,hunt.VISUAL_SCALE]))
 var ranger:Dictionary=baked[10];var flight=preload("res://assets/rogue/scripts/ranger_arrow_flight.gd")
 result.ranger=PackedFloat64Array([ranger.cooldowns.drink,10,ranger.cooldowns.flintlock,.55,ranger.range_scale,3*float(ranger.range_scale),ranger.growth_scale,36,34,20,.25,actions.RANGER_FAN_STEP,deg_to_rad(flight.NORMAL_YAW_DEGREES),deg_to_rad(flight.NORMAL_PITCH_DEGREES),deg_to_rad(flight.POWER_YAW_DEGREES),deg_to_rad(flight.POWER_PITCH_DEGREES),1.5,25,38,19,17,7,4,22,12,.18,.12,1])
 var muzzles=PackedVector3Array()
 for attack in ranger.primary:muzzles.append_array(attack.muzzles)
 result.ranger_muzzles=muzzles
 var motion_muzzles=PackedVector3Array()
 if FileAccess.file_exists("res://assets/characters/ally_crowd/10.res"):
  var atlas=tuned.poses.get(10,load("res://assets/characters/ally_crowd/10.res"))
  for suffix in ["_walk","_back"]:
   for index in 6:
    var key="primary%d"%index+suffix;var points:PackedVector3Array=atlas.get_meta("muzzles")[key]
    for sample in 33:
     var t=float(ranger.primary[index].duration)*sample/32*60;var low=mini(floori(t),points.size()-1);var high=mini(low+1,points.size()-1)
     motion_muzzles.append(points[low].lerp(points[high],t-low))
 result.ranger_motion_muzzles=motion_muzzles
 var knight:Dictionary=baked[7];var counter=preload("res://scripts/knight_guard_counter.gd")
 result.knight=PackedFloat64Array([knight.cooldowns.drink,8,1.8,counter.DAMAGE,counter.INTERVAL,counter.TRAVEL,counter.TAIL,counter.START,counter.DISTANCE,counter.THICKNESS,counter.WIDTH,counter.HEIGHT,knight.range_scale])
 result.bunker=PackedFloat64Array([preload("res://scripts/forest/forest_bunker_combat.gd").FACE,preload("res://scripts/forest/forest_structure_profile.gd").BARRACKS_DECK_HEIGHT+.12,preload("res://scripts/forest/forest_structure_profile.gd").BARRACKS_BODY_HEIGHT,actions.PRIMARY.ranger.duration,actions.PRIMARY.explorer.reach+1])
 preload("res://scripts/warcraft_kit.gd").append_native(result,game)
 for i in result.ally_kinds.size():
  result.ally_profiles[i*5+2]*=model.team_progression.multiplier("character_damage")
  result.ally_profiles[i*5+3]*=model.team_progression.multiplier("character_speed")
 return result
static func expanded_timelines(source:PackedFloat32Array,stride:int=28,skins:int=0)->PackedFloat32Array:
 var target_stride:int=Pets.motions().timeline_stride
 assert(source.size()%stride==0 and stride<=target_stride)
 var result=PackedFloat32Array()
 var padding=PackedFloat32Array()
 padding.resize(target_stride-stride)
 for at in range(0,source.size(),stride):
  result.append_array(source.slice(at,at+stride));result.append_array(padding)
 if skins>0:
  assert(result.size()<=skins*8*target_stride and result.size()>=8*target_stride)
  var first=result.slice(0,8*target_stride)
  while result.size()<skins*8*target_stride:result.append_array(first)
 return result
