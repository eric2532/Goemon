extends "res://scripts/character_combat.gd"
## One shared cast for Kazi and anyone who equips the spell.
const Shot=preload("res://scripts/qigong_projectile.gd")
const Moon=preload("res://scripts/crossgate_moon_projectile.gd")
const Spirit=preload("res://scripts/crossgate_spirit_projectile.gd")
const Element=preload("res://scripts/crossgate_element_projectile.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Proportions=preload("res://scripts/character_proportions.gd")
const ID="kazi/qigong"
const MAZE_QI=preload("res://scripts/spells/spell_catalog.gd").MAZE_QI
const MOON_ID="kazi/moon"
const MOON_SHOTS=6
const MOON_DAMAGE=3000.0
# Classic Kaz's sword clip holds each frame for one client update.
const MOON_ATTACK_START=28*Moon.TICK
const MOON_SWINGS=[MOON_ATTACK_START+12*Moon.TICK,MOON_ATTACK_START+26*Moon.TICK]
const MOON_RELEASE=MOON_ATTACK_START+27*Moon.TICK
const MOON_DURATION=MOON_ATTACK_START+42*Moon.TICK
const SPIRIT_ID="uru/spirit"
const SPIRIT_RANGE=192.0
const SPIRIT_DAMAGE=5000.0
const SPIRIT_RELEASE=33*Moon.TICK
const SPIRIT_DURATION=48*Moon.TICK
const SPIRIT_BATCH=12
const SHOTS=8
const RANGE=48.0
const KAZI_RANGE_MULTIPLIER=3.0
const SPEED=30.0
const DAMAGE=750.0
const CHARGE=9.0/20.0
const SHINING=.25
const FOLLOW_THROUGH=.12
const ELEMENT_CHARGE=11.0/20.0
const COOLDOWN=5.0
const EFFECT_SIZE=1.1
const BASE_DIAMETER=preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER
const Skills=preload("res://scripts/spells/skill_balance.gd")
const Tiers=preload("res://scripts/spells/skill_effects.gd")
const ELEMENT_RELEASE_SCALE=4.0
const ORB_CHARGE_ORIGIN_OFFSET=Vector2(22.5,-10.5)
const ORB_CHARGE_BOTTOM=[242,258,285,307,337,354,357,357,357]
const ELEMENT_CHARGE_BOTTOM=[200,210,216,229,228,229,222,222,223,222,169]
const ELEMENT_CHARGE_COLORS={"fire":Color(1.0,.43,.12),"ice":Color(.27,.82,1.0),"wind":Color(1.0,.88,.22),"meteor":Color(.48,1.0,.48)}
var cooldown=0.0
var charge_left=0.0
var punch_left=0.0
var cast_speed=1.0
var ticket:Dictionary={}
var charge_fx:Sprite3D
var pool:Node
var pool_key:String
var kind=""
var spell_id=ID
var basic_attack=false
var moon_elapsed=0.0
var spirit_targets:Array=[]
var spirit_index=0
var spirit_ticket:Dictionary={}
var native_pattern:Dictionary={}
var native_elapsed=0.0
var native_contact=0
var native_sound=0

func _ready():
 Tiers.prepare()
 pool=Pool.service(game)
 prepare_projectiles()
 var spirit=spell_id==SPIRIT_ID
 charge_fx=Sprite3D.new()
 charge_fx.texture=preload("res://assets/characters/crossgate/qigong/charge.png") if kind.is_empty() and not spirit else Element.CAST
 charge_fx.hframes=8;charge_fx.vframes=2
 charge_fx.billboard=BaseMaterial3D.BILLBOARD_ENABLED;charge_fx.shaded=false
 charge_fx.modulate=Color(.77,.42,1,.86) if kind.is_empty() else ELEMENT_CHARGE_COLORS[kind]
 charge_fx.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 charge_fx.hide();hero.add_child(charge_fx)

func prepare_projectiles():
 if pool==null:return
 var spirit=spell_id==SPIRIT_ID
 var projectile=Spirit if spirit else (Moon if spell_id==MOON_ID else (Shot if kind.is_empty() else Element))
 var count_=int(Skills.effective(hero,spell_id,"count","",0,1 if basic_attack else 0))
 if kind=="wind":count_+=int(hero.accessory_bonuses.get("wind_extra",0))
 # A long-range orb or wind volley can still be resolving when its cooldown ends.
 var repeats=hero.model.normal_attack_pattern().contacts.size() if hero.RogueRoster.is_crossgate_fighter(hero.character_id) else 1
 if (punches() or spell_id==MOON_ID) and not Skills.rules_for(hero,spell_id).is_empty():repeats=1
 var cadence=COOLDOWN/5.0 if hero.RogueRoster.uses_crossgate_spells(hero.character_id) and not hero.ai_controlled and spell_id!=MOON_ID else COOLDOWN
 if basic_attack:cadence=ELEMENT_CHARGE+hero.model.normal_attack_pattern().duration/3.0
 var life=RANGE*range_multiplier()/Moon.SPEED+.5 if spell_id==MOON_ID else Shot.LIFE*range_multiplier() if kind.is_empty() or kind=="wind" else 1.0
 if kind=="ice" and hero.accessory_bonuses.get("ice_hits",3)>3:life=3.0
 var slots=count_*(ceili((life+(count_-1)*.1)/cadence)+1)
 if spirit:slots=24 if hero.ai_controlled else 96
 pool.warm(hero,projectile,projectile_profile(),{} if kind.is_empty() else {"kind":kind},slots*repeats)
 pool_key=pool.key_for(hero,projectile,projectile_profile())

func projectile_profile()->String:return spell_id+":basic" if basic_attack else spell_id

func reset_element_hits():
 ticket.element_hits=[]
 for i in maxi(4,int(ticket.get("accessory_ice_hits",3))):ticket.element_hits.append({})

func punches()->bool:return spell_id in [ID,MAZE_QI]

func punch_progress()->float:
 if charge_left>0:return (CHARGE-SHINING-charge_left)/(CHARGE-SHINING)
 return 2.0-punch_left/FOLLOW_THROUGH

func can_cast()->bool:return not is_attacking() and cooldown<=0 and spirit_targets.is_empty() and hero.hp>0 and hero.dodge_time<=0 and hero.spell_loadout.magic_seal_left<=0
func is_attacking()->bool:return charge_left>0 or punch_left>0
func clear_cooldowns():cooldown=0

func caster_height()->float:
 var model_scale=hero.model.global_basis.y.length() if hero.RogueRoster.uses_crossgate_spells(hero.character_id) else 1.0
 return Proportions.GOEMON_HEIGHT*model_scale

func start_cast():
 if not can_cast():return
 if not basic_attack and not hero.spend_skill_mana(spell_id):return
 hero.facing=hero.combat_attack_direction()
 ticket=hero.attack_chain.begin(spell_id);ticket.projectile=kind.is_empty() or kind=="wind"
 if not hero.ai_controlled and game.has_method("enemy_near_crosshair"):
  var reach=SPIRIT_RANGE if spell_id==SPIRIT_ID else RANGE*range_multiplier()
  var target:Ninja=game.enemy_near_crosshair(reach+game.camera_rig.camera.global_position.distance_to(hero.global_position))
  if target!=null and hero.global_position.distance_squared_to(target.global_position)>reach*reach:target=null
  if target==null and hero.active_ability.has_method("locked_primary_enemy"):target=hero.active_ability.locked_primary_enemy()
  if target!=null and hero.global_position.distance_squared_to(target.global_position)<=reach*reach:
   ticket.aim_target=weakref(target)
   var toward=target.global_position-hero.global_position;toward.y=0
   if not toward.is_zero_approx():hero.facing=toward.normalized()
 ticket.magical=kind in ["fire","ice","wind","meteor"]
 if basic_attack:Skills.decorate(hero,ticket,spell_id,1)
 if not kind.is_empty() and ticket.has("skill_rules"):
  reset_element_hits()
 var uru=hero.RogueRoster.crossgate_profile(hero.character_id).get("magic","")=="ruby"
 if uru and spell_id!=MOON_ID:ticket.crossgate_sound_source=hero.RogueRoster.RUBY_ID
 if spell_id==MAZE_QI:
  ticket.crossgate_sound_source=hero.character_id
 var spirit=spell_id==SPIRIT_ID
 ticket.rank11_shine=spell_id!=MOON_ID and not spirit and kind.is_empty() and (punches() or hero.RogueRoster.uses_crossgate_spells(hero.character_id)) and not game.settings.get("reduced_flashes",false)
 cast_speed=1.0
 if not basic_attack and hero.RogueRoster.uses_crossgate_spells(hero.character_id) and not hero.ai_controlled:
  ticket.magic_result=hero.spell_loadout.begin_magic_combo()
  cast_speed=hero.spell_loadout.magic_cast_speed()
 charge_left=CHARGE if kind.is_empty() else ELEMENT_CHARGE
 var charge_profile=SoundLibrary.crossgate_spell_profile(hero.character_id)
 if spell_id==MOON_ID:
  ticket.crossgate_skill_audio_profile=charge_profile
  moon_elapsed=0.0;charge_left=MOON_DURATION;cast_speed=1.0
 elif spirit:charge_left=SPIRIT_DURATION
 if hero.RogueRoster.is_crossgate_fighter(hero.character_id):
  native_pattern=hero.model.normal_attack_pattern()
  native_elapsed=0.0;native_contact=0;native_sound=0
  ticket.native_strike_fraction=1.0/native_pattern.contacts.size()
  if ticket.has("magic_result"):ticket.magic_result.pending=0
  charge_left=MOON_ATTACK_START if spell_id==MOON_ID else SPIRIT_RELEASE if spirit else CHARGE if kind.is_empty() else ELEMENT_CHARGE
 cooldown=0.0 if basic_attack else COOLDOWN/cast_speed
 if not basic_attack:cast_speed*=hero.spell_loadout.primary_combo_cast_speed()
 # Frame 6's actual magic flare is 127 pixels tall. The sheet also has stray pixels below it.
 var charge_pixels=165.0 if kind.is_empty() and not spirit else 127.0
 if not kind.is_empty() and ticket.has("skill_rules"):Tiers.sheet(charge_fx,Tiers.elemental_shine(ticket))
 if kind.is_empty() and not spirit:Tiers.physical_shine(charge_fx,ticket)
 var charge_scale=EFFECT_SIZE if kind.is_empty() and not spirit else 2.0
 if punches() or ticket.rank11_shine or (spell_id==MOON_ID and not game.settings.get("reduced_flashes",false)):charge_scale=2.2
 var height=(hero.model.qi_blast_height() if punches() else caster_height())*charge_scale
 if punches() or spell_id==MOON_ID:
  height=BASE_DIAMETER;charge_pixels=357.0
 charge_fx.pixel_size=height/(hero.global_basis.y.length()*charge_pixels)
 charge_fx.scale=Vector3.ONE*Skills.shine_factor(ticket)*(Element.VISUAL_SCALE if not kind.is_empty() else 1.0)
 if spirit:
  charge_fx.modulate=Color(1,1,1,.55) if game.settings.get("reduced_flashes",false) else Color.WHITE
 elif kind.is_empty():
  charge_fx.modulate=Color(1,.65,.65,.86) if uru else Color(.77,.42,1,.86)
  if spell_id==MOON_ID:charge_fx.modulate=Color.WHITE
  if punches():
   charge_fx.modulate=Color(.45,.7,1.0,.86)
   charge_fx.global_position=hero.model.qi_blast_chest()
   if game.settings.get("reduced_flashes",false):charge_fx.modulate.a=.35
  elif spell_id==MOON_ID:
   charge_fx.global_position=hero.model.qi_blast_chest()
  elif hero.RogueRoster.uses_crossgate_spells(hero.character_id):
   charge_fx.global_position=hero.model.to_global(Vector3.UP*Proportions.GOEMON_HEIGHT*.55)
 if punches() and ticket.get("qi_color",Color.WHITE)!=Color.WHITE:
  var tint:Color=ticket.qi_color
  charge_fx.modulate=Color(tint.r,tint.g,tint.b,charge_fx.modulate.a)
 if not kind.is_empty():charge_fx.global_position=hero.global_position
 set_charge_frame(0)
 charge_fx.show()
 var charge_cue="qigong_charge"
 if spell_id==MOON_ID:charge_cue="cg_moon_charge"
 elif spirit:charge_cue="cg_spirit_charge"
 elif not kind.is_empty():charge_cue="cg_"+kind+"_charge"
 sound(charge_cue,charge_profile)

func tick(delta:float):
 cooldown=maxf(0,cooldown-delta)
 if not native_pattern.is_empty():
  tick_native_cast(delta)
  if spell_id==SPIRIT_ID:advance_spirit_targets()
  return
 if spell_id==SPIRIT_ID:
  tick_spirit(delta);return
 if punch_left>0:
  punch_left=maxf(0.0,punch_left-delta*cast_speed)
  return
 if charge_left<=0:return
 if punches() or spell_id==MOON_ID:charge_fx.global_position=hero.model.qi_blast_chest()
 if spell_id==MOON_ID:
  tick_moon(delta);return
 charge_left=maxf(0,charge_left-delta*cast_speed)
 if charge_left>0:
  if punches() and charge_left<=CHARGE-SHINING:charge_fx.hide()
  elif charge_fx.visible:
   var frame=(CHARGE-charge_left)*9/SHINING if punches() else (11 if not kind.is_empty() else 9)-charge_left*20.0
   set_charge_frame(frame)
  return
 charge_fx.hide()
 if punches():punch_left=FOLLOW_THROUGH
 release_volley();ticket={}

func tick_native_cast(delta:float):
 if charge_left>0:
  charge_fx.global_position=hero.global_position if not kind.is_empty() else hero.model.qi_blast_chest()
  charge_left=maxf(0.0,charge_left-delta*cast_speed)
  if charge_left>0:
   set_charge_frame((CHARGE-charge_left)*20.0 if kind.is_empty() else (ELEMENT_CHARGE-charge_left)*20.0)
   return
  charge_fx.hide();punch_left=native_pattern.duration
 if punch_left<=0:return
 native_elapsed=minf(float(native_pattern.duration),native_elapsed+delta*cast_speed*hero.attack_speed_multiplier())
 punch_left=maxf(0.0,float(native_pattern.duration)-native_elapsed)
 while native_sound<native_pattern.sounds.size() and native_elapsed>=float(native_pattern.sounds[native_sound]):
  native_sound+=1
  if kind.is_empty():hero.play_sound("swing",.8,ticket,hero.model.attack_sound(false,native_sound-1,native_pattern.attack))
 while native_contact<native_pattern.contacts.size() and native_elapsed>=float(native_pattern.contacts[native_contact]):
  native_contact+=1
  if kind.is_empty():
   var effect:AudioStream=hero.model.attack_effect_sound(native_contact-1,native_pattern.attack)
   if effect!=null:hero.play_sound("hit",.7,ticket,effect)
  if ticket.has("element_hits"):
   reset_element_hits()
  if spell_id==MOON_ID:release_moon()
  elif spell_id==SPIRIT_ID:release_spirit()
  else:release_volley()
 if punch_left<=0:ticket={}

func set_charge_frame(source_frame:float):
 var frame=Tiers.charge_frame(ticket,source_frame,9,12) if kind.is_empty() else Tiers.charge_frame(ticket,source_frame,11,14)
 if spell_id==SPIRIT_ID:frame=clampi(floori(source_frame),0,10)
 charge_fx.frame=frame
 if not kind.is_empty() and ticket.has("skill_rules"):
  var ref:String=Tiers.elemental_shine(ticket)
  var row:Dictionary=Tiers.clip(ref)
  # The largest sheet has stray pixels below the flare; keep its recovered baseline.
  var bottom=ELEMENT_CHARGE_BOTTOM[frame] if ref=="110052" else row.frame_bounds[frame][3]
  charge_fx.offset.y=float(bottom)-float(row.height)*.5
  return
 if spell_id==SPIRIT_ID:
  charge_fx.offset.y=float(ELEMENT_CHARGE_BOTTOM[frame])-204.5
 elif punches() or spell_id==MOON_ID or (kind.is_empty() and hero.RogueRoster.uses_crossgate_spells(hero.character_id)):
  # The selected original sheet already carries its source origin.
  if not ticket.has("skill_rules"):charge_fx.offset=ORB_CHARGE_ORIGIN_OFFSET
 else:
  charge_fx.offset.y=float(ORB_CHARGE_BOTTOM[frame])-178.5 if kind.is_empty() else float(ELEMENT_CHARGE_BOTTOM[frame])-204.5

func range_multiplier()->float:
 return (KAZI_RANGE_MULTIPLIER if hero.RogueRoster.uses_crossgate_spells(hero.character_id) else 1.0)*float(hero.accessory_bonuses.get("range",1.0))

func aim_target()->Ninja:
 var reference:WeakRef=ticket.get("aim_target")
 return reference.get_ref() as Ninja if reference!=null else null

func focused_target(origin:Vector3,reach:float,terrain_exclude:Array[RID]=[])->Ninja:
 var target=aim_target()
 if not is_instance_valid(target) or target.dead or target.hp<=0 or hero.global_position.distance_squared_to(target.global_position)>reach*reach:return null
 if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(target):return null
 if (kind.is_empty() or not hero.RogueRoster.uses_crossgate_spells(hero.character_id)) and not AttackChain.clear_line(hero,origin,AttackChain.aim_point(target,origin),terrain_exclude):return null
 return target

func nearest_targets(origin:Vector3,terrain_exclude:Array[RID],limit:int=SHOTS,preferred:Ninja=null)->Array[Ninja]:
 var reach=float(ticket.get("pet_cast_reach",RANGE*range_multiplier()))
 var focus=focused_target(origin,reach,terrain_exclude) if preferred==null else null
 if focus!=null:return [focus]
 var candidates=[]
 for enemy in AttackChain.enemy_candidates(game,origin if preferred==null else hero.global_position,reach):
  if not is_instance_valid(enemy) or enemy.dead:continue
  var distance=hero.global_position.distance_squared_to(enemy.global_position)
  if distance>reach*reach:continue
  if preferred==null and game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  if enemy==preferred:distance=-1.0
  candidates.append([distance,enemy.get_instance_id(),enemy])
 candidates.sort_custom(func(a,b):return a[1]<b[1] if a[0]==b[0] else a[0]<b[0])
 var targets:Array[Ninja]=[]
 var needs_line=preferred!=null or not hero.RogueRoster.uses_crossgate_spells(hero.character_id) or kind.is_empty()
 for row in candidates:
  var enemy:Ninja=row[2]
  if needs_line and not AttackChain.clear_line(hero,origin,AttackChain.aim_point(enemy,origin),terrain_exclude):continue
  targets.append(enemy)
  if targets.size()==limit:break
 return targets

func release_volley(preferred:Ninja=null):
 var origin=hero.global_position+Vector3.UP*1.5*hero.growth_multiplier()
 if preferred!=null:origin=hero.model.qi_blast_chest()
 if punches():
  origin=hero.model.qi_blast_chest()+hero.facing*hero.model.qi_blast_height()*.23
  if not AttackChain.clear_line(hero,hero.model.qi_blast_chest(),origin):origin=hero.model.qi_blast_chest()
 var terrain_exclude:Array[RID]=[]
 if preferred==null and kind.is_empty() and hero.RogueRoster.uses_crossgate_spells(hero.character_id) and game.world.get("terrain_rids")!=null:terrain_exclude=game.world.terrain_rids
 var count_=skill_count(SHOTS,ticket)
 if kind.is_empty() and native_contact>1:return
 if count_<=0:return
 var targets:Array[Ninja]=[]
 if not kind.is_empty() and ticket.has("element_targets"):
  var reach=float(ticket.get("pet_cast_reach",RANGE*range_multiplier()))
  for enemy in ticket.element_targets:
   if not is_instance_valid(enemy) or enemy.dead or hero.global_position.distance_squared_to(enemy.global_position)>reach*reach:continue
   if preferred==null and game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
   if (preferred!=null or not hero.RogueRoster.uses_crossgate_spells(hero.character_id)) and not AttackChain.clear_line(hero,origin,AttackChain.aim_point(enemy,origin),terrain_exclude):continue
   targets.append(enemy)
 else:
  targets=nearest_targets(origin,terrain_exclude,count_,preferred)
  if not kind.is_empty() and ticket.has("skill_rules"):
   ticket.element_targets=targets.duplicate()
   ticket.element_target_ids={}
   for enemy in targets:ticket.element_target_ids[enemy.get_instance_id()]=true
 var focused=preferred==null and targets.size()==1 and targets[0]==aim_target()
 if ticket.has("magic_result"):ticket.magic_result.pending+=count_ if focused and kind.is_empty() else targets.size()
 var height=BASE_DIAMETER if punches() else caster_height()*EFFECT_SIZE
 var flight_life=Shot.LIFE*range_multiplier()
 var stray_ticket=ticket
 if not focused and (kind.is_empty() or kind=="wind") and targets.size()<count_ and ticket.has("magic_result"):
  stray_ticket=ticket.duplicate();stray_ticket.erase("magic_result")
 if not kind.is_empty():
  release_element(origin,targets,height*ELEMENT_RELEASE_SCALE,flight_life,stray_ticket);return
 var damage=Skills.damage(hero,ticket,DAMAGE*float(ticket.get("native_strike_fraction",1.0)))*hero.damage_multiplier()
 for i in count_:
  var target:Ninja=targets[0] if focused else targets[i] if i<targets.size() else null
  var forward=hero.facing.rotated(Vector3.UP,(i-(count_-1)*.5)*.14)
  var direction=(Shot.flight_aim_point(target,origin)-origin).normalized() if target!=null else forward
  pool.launch(hero,Shot,projectile_profile(),{"position":origin,"velocity":direction*SPEED,"target":target,
   "target_range":float(ticket.get("pet_cast_reach",RANGE*range_multiplier())),
   "flight_life":flight_life if target!=null else Shot.LIFE,"terrain_exclude":terrain_exclude,
   "effect_height":height,"damage":damage,"attack_ticket":ticket if target!=null else stray_ticket,"start_delay":randf_range(0.0,.05) if i>0 else 0.0,"burst_index":i%Element.BURSTS.size()})

func tick_moon(delta:float):
 var before=moon_elapsed
 moon_elapsed=minf(MOON_DURATION,moon_elapsed+delta+0.00000001)
 charge_left=MOON_DURATION-moon_elapsed
 if moon_elapsed<CHARGE:
  set_charge_frame(moon_elapsed*20.0)
 else:charge_fx.hide()
 for cue in MOON_SWINGS:
  if before<cue and moon_elapsed>=cue:sound("swing")
 if before<MOON_RELEASE and moon_elapsed>=MOON_RELEASE:release_moon()
 if charge_left<=0:ticket={}

func release_moon(preferred:Ninja=null):
 var origin=hero.global_position+Vector3.UP*caster_height()*.5
 if preferred!=null:origin=hero.model.qi_blast_chest()
 var terrain_exclude:Array[RID]=[]
 if preferred==null and hero.RogueRoster.uses_crossgate_spells(hero.character_id) and game.world.get("terrain_rids")!=null:
  terrain_exclude=game.world.terrain_rids
 var count_=skill_count(MOON_SHOTS,ticket)
 var base_count=release_count(count_-int(ticket.get("accessory_moon_extra",0)))
 count_=release_count(count_)
 if count_<=0:return
 var targets=nearest_targets(origin,terrain_exclude,maxi(1,base_count),preferred)
 var focused=preferred==null and targets.size()==1 and targets[0]==aim_target()
 origin=hero.global_position+Vector3.UP*Moon.GROUND_CLEARANCE
 var forward=hero.facing.slide(Vector3.UP).normalized()
 var muzzle=origin+forward*.95*hero.contact_size_multiplier()
 if AttackChain.clear_line(hero,origin,muzzle,terrain_exclude):origin=muzzle
 if ticket.has("magic_result"):ticket.magic_result.pending+=base_count if focused else mini(targets.size(),base_count)
 var stray=ticket.duplicate()
 stray.erase("magic_result")
 var damage=Skills.damage(hero,ticket,MOON_DAMAGE*float(ticket.get("native_strike_fraction",1.0)))*hero.damage_multiplier()
 var flight_life=RANGE*range_multiplier()/Moon.SPEED+.5
 sound("cg_moon_release")
 for i in count_:
  var target:Ninja=targets[0] if focused else targets[i] if i<targets.size() else null
  if i>=base_count and not targets.is_empty():
   target=targets[(i-base_count)%targets.size()]
   if ticket.has("magic_result"):ticket.magic_result.pending+=1
  var direction=target.global_position-origin if target!=null else forward.rotated(Vector3.UP,(i-(count_-1)*.5)*.14)
  direction.y=0.0
  if direction.is_zero_approx():direction=forward
  pool.launch(hero,Moon,MOON_ID,{"position":origin,"velocity":direction.normalized()*Moon.SPEED,"target":target,
   "flight_life":flight_life if target!=null else Shot.LIFE,"terrain_exclude":terrain_exclude,
   "damage":damage,"attack_ticket":ticket if target!=null else stray})

func tick_spirit(delta:float):
 if charge_left>0:
  var before=SPIRIT_DURATION-charge_left
  charge_left=maxf(0,charge_left-delta*cast_speed)
  var elapsed=SPIRIT_DURATION-charge_left
  if elapsed+.000001<SPIRIT_RELEASE:
   var frame=mini(10,floori(elapsed/(3*Moon.TICK)+.000001))
   if frame!=charge_fx.frame:set_charge_frame(frame)
  elif before+.000001<SPIRIT_RELEASE:
   charge_fx.hide()
   var focus=focused_target(hero.global_position+Vector3.UP*caster_height()*.5,SPIRIT_RANGE)
   spirit_targets=[focus] if focus!=null else AttackChain.enemy_candidates(game,hero.global_position,SPIRIT_RANGE)
   if is_same(spirit_targets,game.enemies):spirit_targets=spirit_targets.duplicate()
   spirit_index=0
   spirit_ticket=ticket
   if spirit_ticket.has("magic_result"):spirit_ticket.magic_result.pending=spirit_targets.size()
  if charge_left<=.000001:charge_left=0;ticket={}
 advance_spirit_targets()

func release_spirit(preferred:Ninja=null):
 var reach=float(ticket.get("pet_cast_reach",SPIRIT_RANGE))
 var focus=focused_target(hero.global_position+Vector3.UP*caster_height()*.5,reach) if preferred==null else null
 var candidates=[focus] if focus!=null else AttackChain.enemy_candidates(game,hero.global_position,reach)
 if spirit_targets.is_empty():spirit_ticket=ticket;spirit_index=0
 if preferred!=null and preferred in candidates:
  spirit_targets.append(preferred)
  for enemy in candidates:
   if enemy!=preferred:spirit_targets.append(enemy)
  return
 spirit_targets.append_array(candidates)
 if spirit_ticket.has("magic_result"):spirit_ticket.magic_result.pending+=candidates.size()

func advance_spirit_targets():
 if spirit_targets.is_empty():return
 # Limit active projectiles and new raycasts per tick without dropping targets.
 var budget=mini(SPIRIT_BATCH,pool.idle[pool_key].size())
 var origin=hero.global_position+Vector3.UP*caster_height()*.5
 var pet_cast=spirit_ticket.has("pet_cast_reach")
 if pet_cast:origin=hero.model.qi_blast_chest()
 var reach=float(spirit_ticket.get("pet_cast_reach",SPIRIT_RANGE))
 var damage=hero.magic_spell_damage(SPIRIT_DAMAGE)*float(spirit_ticket.get("native_strike_fraction",1.0))
 for i in mini(budget,spirit_targets.size()-spirit_index):
  var enemy=spirit_targets[spirit_index]
  spirit_index+=1
  if is_instance_valid(enemy) and not enemy.dead and hero.global_position.distance_squared_to(enemy.global_position)<=reach*reach and (pet_cast or not game.has_method("forest_enemy_visible") or game.forest_enemy_visible(enemy)):
   var point=AttackChain.aim_point(enemy,origin)
   if AttackChain.clear_line(hero,origin,point):
    pool.launch(hero,Spirit,SPIRIT_ID,{"position":origin,"target":enemy,"velocity":origin.direction_to(point)*Spirit.TRAVEL_SPEED,
     "flight_life":SPIRIT_RANGE/Spirit.TRAVEL_SPEED+.5,"damage":damage,"attack_ticket":spirit_ticket})
    continue
  if spirit_ticket.has("magic_result"):spirit_ticket.magic_result.pending-=1
 if spirit_index==spirit_targets.size():spirit_targets=[];spirit_ticket={}

static func stagger_delays(count:int)->Array[float]:
 var delays:Array[float]=[]
 var delay=0.0
 for i in range(1,count):
  delay+=randf_range(.055,.10)
  delays.append(delay)
 delays.shuffle()
 delays.push_front(0.0)
 return delays

func release_element(origin:Vector3,targets:Array[Ninja],height:float,flight_life:float,stray_ticket:Dictionary):
 var pulses=float({"fire":1,"ice":3,"wind":4,"meteor":2}[kind])
 var spell_base=float(Element.DAMAGE[kind])*pulses
 var tier=3
 if ticket.has("skill_rules"):
  tier=int(ticket.skill_rules.effect_tier)
  spell_base=float(ticket.skill_rules.base_damage)
 var damage=hero.magic_spell_damage(spell_base)*float(ticket.get("native_strike_fraction",1.0))/pulses
 var ignore_cover=not ticket.has("pet_cast_reach") and hero.RogueRoster.uses_crossgate_spells(hero.character_id)
 var count_=skill_count(SHOTS,ticket)
 var extra=int(ticket.get("accessory_wind_extra",0)) if kind=="wind" else 0
 var base_count=count_
 count_+=extra
 var delays=stagger_delays(base_count if kind=="wind" else targets.size())
 if kind=="wind":
  var focused=targets.size()==1 and targets[0]==aim_target()
  if focused and ticket.has("magic_result"):ticket.magic_result.pending+=base_count-1
  for i in count_:
   var target:Ninja=targets[0] if focused else targets[i] if i<targets.size() else null
   if i>=base_count and not targets.is_empty():target=targets[(i-base_count)%targets.size()]
   var direction=(AttackChain.aim_point(target,origin)-origin).normalized() if target!=null else hero.facing.rotated(Vector3.UP,(i-(count_-1)*.5)*.14)
   var spread=Vector3.ZERO
   if i>=base_count:
    var lane=i-base_count
    spread=direction.cross(Vector3.UP).normalized()*(lane/2+1)*3.0*Element.VISUAL_SCALE*(-1.0 if lane%2==0 else 1.0)
   if i>=base_count and target!=null and ticket.has("magic_result"):ticket.magic_result.pending+=1
   pool.launch(hero,Element,projectile_profile(),{"kind":kind,"position":origin,"velocity":direction*SPEED,"target":target,
    "flight_life":flight_life if target!=null else Shot.LIFE,"ignore_cover":ignore_cover,"start_delay":delays[i] if i<base_count else .015*(i-base_count+1),"wind_spread":spread,
    "effect_height":height,"effect_tier":tier,"cast_hits":[{}, {}, {}, {}] if i>=base_count else ticket.get("element_hits",[{}, {}, {}, {}]),"burst_index":i%Element.BURSTS.size(),"damage":damage,"attack_ticket":ticket if target!=null else stray_ticket})
  return
 if kind=="meteor" and not targets.is_empty():sound("cg_meteor_fall")
 var cast_hits=ticket.get("element_hits",[{},{},{}])
 for i in targets.size():
  pool.launch(hero,Element,projectile_profile(),{"kind":kind,"position":targets[i].global_position,"sound_lead":i==0,
   "ignore_cover":ignore_cover,"effect_height":height,"effect_tier":tier,"cast_hits":cast_hits,"start_delay":delays[i],
   "ice_hit_count":int(ticket.get("accessory_ice_hits",3)),"burst_index":i%Element.BURSTS.size(),"damage":damage,"attack_ticket":ticket})

func release_count(total:int)->int:
 if not ticket.has("skill_level") or native_pattern.is_empty():return total
 var contacts=roundi(1.0/float(ticket.native_strike_fraction)) if ticket.has("pet_cast_reach") else native_pattern.contacts.size()
 return floori(float(total)*native_contact/contacts)-floori(float(total)*(native_contact-1)/contacts)

func sound(kind:String,profile:int=0):
 if not hero.ai_controlled or game.move_audio.ally_nearby(game,hero.global_position):
  game.sound(kind,.8,false,ticket,profile if profile>0 else int(ticket.get("crossgate_sound_source",Shot.SOURCE_ID)))

func interrupt_for_dodge():
 charge_left=0;punch_left=0;ticket={};native_pattern={}
 native_elapsed=0.0;native_contact=0;native_sound=0
 if is_instance_valid(charge_fx):charge_fx.hide()

func cancel(_preserve_power:bool=false):
 interrupt_for_dodge()
 if not spirit_targets.is_empty() and spirit_ticket.has("magic_result"):
  spirit_ticket.magic_result.pending-=spirit_targets.size()-spirit_index
 spirit_targets=[];spirit_ticket={}
 if is_instance_valid(pool):
  for shot in pool.all.get(pool_key,[]):
   if is_instance_valid(shot) and shot.pool_live:shot.retire()

func _exit_tree():
 cancel()
 if is_instance_valid(charge_fx):charge_fx.queue_free()
