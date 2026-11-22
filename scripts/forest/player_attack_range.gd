extends RefCounted
## Horizontal envelope of basic melee attacks; facing, height and cover still gate hits.
var signature:Array=[]
var cached_radius=0.0
func radius(hero:Hero)->float:
 var ability=hero.active_ability
 var buff=ability.buff_time() if hero.is_rogue_character() else 0.0
 var crossgate=hero.RogueRoster.is_crossgate_fighter(hero.character_id)
 var stance=hero.model.maze_weapon if hero.RogueRoster.has_crossgate_throws(hero.character_id) else hero.model.shin_weapon_index if crossgate else 0
 # Fixed-weapon skins can have a different reach at the same stance index.
 if crossgate:stance=Vector2i(stance,int(hero.model.motions.get("source_id",0)))
 var key=[hero.character_id,hero.weapon_slot,hero.growth_multiplier(),hero.melee_reach_setting(),hero.pickup_multiplier("range"),hero.surge_left>0,hero.combat_tuning("pipe_range"),hero.combat_tuning("model_scale"),buff>0,hero.is_meta_shooter(),stance,hero.model.current_weapon() if crossgate else "",hero.accessory_bonuses.get("range",1.0),hero.accessory_bonuses.get("primary","")]
 if key==signature:return cached_radius
 signature=key;cached_radius=0.0
 if hero.accessory_bonuses.get("primary","")=="fire":return cached_radius
 if hero.character_id==1 and hero.weapon_slot==1:
  var model=hero.model
  if model.pipe_bounds.is_empty():model.cache_pipe_bounds(model.pipe)
  var size=HeroModel.WeaponProportions.SCALE*hero.combat_tuning("pipe_range")/3.5*hero.range_multiplier()*hero.melee_reach_setting()/hero.growth_multiplier()
  for action in model.Profile.COMBO_ACTIONS:
   for frame in range(ceili(model.Profile.action_duration(action)*model.Profile.source_fps(action))+1):
    var pose=model.rig_visual.global_transform*model.pipe_pose(action,float(frame)/model.Profile.source_fps(action),size)
    for corner in model.pipe_bounds:
     var offset=pose*corner-hero.global_position
     cached_radius=maxf(cached_radius,Vector2(offset.x,offset.z).length()+.18*hero.growth_multiplier())
 elif hero.is_rogue_character() and ability.class_id not in ["mage","ranger"]:
  var saved=ability._ticket;ability._ticket={}
  for i in ability.Actions.primary_count(ability.class_id):
   var a=ability.COMBO[i].duplicate(true) if ability.class_id=="pirate" else ability.Actions.primary_config(ability,i)
   if ability.class_id=="pirate":a.primary=true;a.style="sword"
   a.index=i;a.angle=ability.player.angle;a.weapon="cutlass"
   ability.refine_melee_primary(a)
   ability.fit_primary_reach(a,true)
   cached_radius=maxf(cached_radius,float(a.reach))
  ability._ticket=saved
 elif hero.character_id==13:cached_radius=ability.blade_reach(true)+.25*hero.contact_size_multiplier()
 elif crossgate or hero.character_id in [15,16,17]:cached_radius=hero.melee_strike_reach()
 elif hero.character_id==29:
  var pattern=ability.Roles.ATTACKS[ability.Dark.ROLE]
  var scale=ability.Dark.SCALE*ability.Dark.ATTACK_RANGE*hero.melee_range_multiplier()
  for point in [pattern.from,pattern.to]:
   var endpoint=hero.model.basis*(ability.Visual.source_point(point)*Vector3(scale,hero.melee_range_multiplier(),scale))
   cached_radius=maxf(cached_radius,Vector2(endpoint.x,endpoint.z).length()+.8*scale)
 elif hero.character_id in [31,32,33] and not hero.is_meta_shooter():
  cached_radius=preload("res://scripts/warcraft_kit.gd").MELEE_REACH*hero.contact_size_multiplier()*hero.melee_reach_setting()*hero.pickup_multiplier("range")
 elif hero.character_id==28:
  var origin=hero.model.source_point(hero.model.data().contacts.slash[0])
  var padding=24.0*hero.model.source_unit()*hero.melee_reach_setting()
  for endpoint in hero.model.data().contacts.slash.slice(1):
   var point=origin+(hero.model.source_point(endpoint)-origin)*hero.melee_reach_setting()*hero.pickup_multiplier("range")-hero.global_position
   cached_radius=maxf(cached_radius,Vector2(point.x,point.z).length()+padding)
 return cached_radius
