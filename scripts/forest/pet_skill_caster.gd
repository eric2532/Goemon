extends Hero
## Prepared skill ownership/audio/projectiles; no movement or combat clock of its own.
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
const ShineTiers=preload("res://scripts/spells/skill_effects.gd")
const Qi=preload("res://scripts/qigong_combat.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
var runtime
var pet_key=""
var native_handle=0
var gate_id=0
var controllers:Dictionary={}
var selected:Array=[]
var current_skill=""
var cast_serial=-1
var ticket:Dictionary={}
var charge:Sprite3D
var ready_mask=-1
var sequence_target:Ninja
func hold_sequence_target(id:int):
 if is_instance_valid(sequence_target) and sequence_target.forest_id==id:return
 if is_instance_valid(sequence_target):sequence_target.release_sequence()
 sequence_target=runtime.enemy_target(id)
 if is_instance_valid(sequence_target):sequence_target.retain_sequence()

func _ready():
 ShineTiers.prepare()
 ai_controlled=true;mirror_copy=true;character_id=RogueRoster.KAZI_ID
 collision_layer=0;collision_mask=0;set_physics_process(false);set_process(false)
 set_process_input(false);set_process_unhandled_input(false)
 attack_chain.hero_owner=weakref(self)
 game.sound_library.prepare_character(character_id)
 model=preload("res://scripts/forest/pet_skill_model.gd").new();add_child(model)
 var skin=Pets.skin(pet_key);model.pattern=Pets.attack_pattern(skin)
 model.bounds=preload("res://scripts/forest/crowd/pet_dimensions.gd").companion_body(skin)
 spell_loadout=preload("res://scripts/spells/spell_loadout.gd").new();spell_loadout.hero=self;add_child(spell_loadout)
 charge=Sprite3D.new();charge.texture=preload("res://assets/characters/crossgate/qigong/charge.png")
 charge.hframes=8;charge.vframes=2;charge.pixel_size=Skills.BASE_DIAMETER/357.0;charge.offset=Vector2(22.5,-10.5)
 charge.billboard=BaseMaterial3D.BILLBOARD_ENABLED;charge.shaded=false;charge.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(charge);charge.hide()
func configure(skills:Array):
 if selected==skills:return
 finish_cast();ticket={};cast_serial=-1;current_skill=""
 selected=skills.duplicate()
 for id in controllers.keys():
  if id not in selected:controllers[id].cancel();controllers[id].queue_free();controllers.erase(id)
 for id in selected:
  if id.is_empty() or id in [Pets.Spells.SURE_STRIKE,Pets.Spells.COMBO,Pets.Spells.BEE_FLURRY,Pets.Spells.BODYGUARD] or controllers.has(id):continue
  var skill=Qi.new();skill.hero=self;skill.game=game;skill.spell_id=id
  if id not in [Qi.ID,Qi.MAZE_QI,Qi.MOON_ID,Qi.SPIRIT_ID]:skill.kind=id.get_slice("/",1)
  add_child(skill);controllers[id]=skill
 ready_mask=-1
func bind_unit(handle:int):
 if native_handle!=handle:retire();native_handle=handle
 var row=runtime.unit_state(handle)
 if not row.is_empty():
  position=row.position;hp=row.hp;max_hp=row.max_hp
  var configured:bool=runtime.native.set_pet_bodyguard_level(handle,clampi(Skills.level_for(self,Pets.Spells.BODYGUARD),1,30))
  assert(configured,"Invalid pet 護衛 level")
func receive(event:Dictionary):
 if int(event.ticket_id)!=native_handle:return
 var code=int(event.action_index)
 var id=Pets.skill_id(code)
 if id not in selected:return
 position=event.position;facing=event.direction
 if event.kind=="pet_skill_started":
  if cast_serial==int(event.projectile_id):
   if id==Pets.Spells.COMBO:hold_sequence_target(int(event.get("target_id",0)))
   return
  var streak=attack_chain.kazi_combo_streak
  finish_cast();attack_chain.reset();cast_serial=event.projectile_id;current_skill=id
  if id in [Pets.Spells.COMBO,Pets.Spells.BEE_FLURRY]:hold_sequence_target(int(event.get("target_id",0)))
  if id==Pets.Spells.COMBO:attack_chain.kazi_combo_streak=streak+1
  if controllers.has(id):
   var skill=controllers[id];skill.clear_cooldowns();skill.start_cast();ticket=skill.ticket
  else:
   ticket=attack_chain.make_ticket(Pets.Spells.BEE_FLURRY if id==Pets.Spells.BEE_FLURRY else "shin_sure_strike" if id==Pets.Spells.SURE_STRIKE else "kazi_combo")
   ShineTiers.physical_shine(charge,ticket)
   charge.scale=Vector3.ONE*Skills.shine_factor(ticket);charge.frame=0;charge.position=model.bounds.get_center()
   charge.modulate.a=.35 if game.settings.get("reduced_flashes",false) else 1.0;charge.show()
   play_sound("cg_shin_sure_strike_charge" if id==Pets.Spells.SURE_STRIKE else "cg_combo_charge",.8,ticket)
  ticket.chain_enabled=false;ticket.pet_skill=id;ticket.native_strike_fraction=event.amount
  if id==Pets.Spells.COMBO:ticket.kazi_combo_multiplier=1.0+.5*streak
  return
 if cast_serial!=int(event.projectile_id) or current_skill!=id or ticket.is_empty():return
 charge.hide()
 if event.kind=="pet_skill_move":
  play_sound("maze_assassination_vanish",.8,ticket)
  return
 if controllers.has(id):
  var skill=controllers[id];skill.charge_fx.hide()
  var target=runtime.enemy_target(int(event.target_id))
  if not is_instance_valid(target) or target.dead:return
  var row=runtime.unit_state(target.handle)
  if row.is_empty() or row.hp<=0:return
  target.sync(row)
  ticket.pet_cast_reach=Pets.RANGED_REACH
  ticket.native_strike_fraction=1.0 if skill.punches() else event.amount
  skill.native_contact+=1
  if id==Qi.MOON_ID:skill.release_moon(target)
  elif id==Qi.SPIRIT_ID:skill.release_spirit(target)
  else:skill.release_volley(target)
  return
 var enemy=sequence_target if is_instance_valid(sequence_target) and sequence_target.forest_id==int(event.target_id) else runtime.enemy_target(int(event.target_id))
 if not is_instance_valid(enemy):return
 if enemy.dead:
  if enemy==sequence_target:
   var at=AttackChain.effect_anchor(enemy).position
   enemy.overkill_feedback(ticket)
   game.confirm_ally_impact(enemy,at,facing,0,false,character_id,false)
  return
 var target_state=runtime.unit_state(enemy.handle)
 if target_state.is_empty() or target_state.hp<=0:return
 enemy.sync(target_state)
 var anchor=AttackChain.effect_anchor(enemy)
 var damage=Skills.damage(self,ticket,5000.0 if id==Pets.Spells.SURE_STRIKE else 375.0)*float(event.amount)*damage_multiplier()
 if id==Pets.Spells.COMBO:damage*=float(ticket.get("kazi_combo_multiplier",1.0))
 if id==Pets.Spells.SURE_STRIKE:
  ticket.sure_strike_size=Skills.BASE_DIAMETER*Skills.factor(ticket,"size")
 elif id==Pets.Spells.COMBO:
  ticket.combo_hit_size=Skills.BASE_DIAMETER*Skills.factor(ticket,"size");ticket.combo_hit_shin=Skills.Levels.is_ex(ticket)
 enemy.take_hit(damage,facing,false,ticket)
 game.confirm_ally_impact(enemy,anchor.position,facing,0,false,character_id,false)
 if id==Pets.Spells.COMBO:
  var center=enemy.global_position;center.y=AttackChain.aim_point(enemy,global_position+Vector3.UP).y
  AttackChain.damage_splash(self,enemy,center,Skills.BASE_DIAMETER*.5*Skills.factor(ticket,"hit_area"),damage,ticket)
func step(_delta:float):
 if native_handle==0:return
 var row=runtime.unit_state(native_handle)
 if row.is_empty() or row.hp<=0:retire();return
 position=row.position;hp=row.hp;max_hp=row.max_hp
 if int(row.action)!=1 and not row.get("pet_sequence",false):finish_cast()
 elif charge.visible:charge.frame=ShineTiers.charge_frame(ticket,float(row.action_time)/.05,9,12)
 for skill in controllers.values():
  if skill.spell_id==Qi.SPIRIT_ID:skill.advance_spirit_targets()
  if skill.charge_fx.visible:
   skill.charge_fx.global_position=global_position if not skill.kind.is_empty() else model.qi_blast_chest()
   skill.set_charge_frame(minf(8.999,float(row.action_time)/.05))
 var mask=7
 for slot in selected.size():
  if controllers.has(selected[slot]) and not controllers[selected[slot]].spirit_targets.is_empty():mask&=~(1<<slot)
 if mask!=ready_mask:runtime.native.set_pet_skill_ready(native_handle,mask);ready_mask=mask
func finish_cast():
 if is_instance_valid(sequence_target):sequence_target.release_sequence()
 sequence_target=null
 if is_instance_valid(charge):charge.hide()
 for skill in controllers.values():
  skill.charge_fx.hide();skill.charge_left=0;skill.punch_left=0;skill.cooldown=0
func retire():
 finish_cast()
 for skill in controllers.values():skill.cancel(true)
 if is_instance_valid(game):
  var pool=game.get_node_or_null("CharacterProjectiles")
  if pool!=null:pool.release_owner(self)
 attack_chain.reset()
 native_handle=0;ticket={};cast_serial=-1;current_skill="";hp=0;ready_mask=-1
func prepare_skill_count(id:String):
 runtime.finish_integration()
 if id==Pets.Spells.BODYGUARD and native_handle:
  var configured:bool=runtime.native.set_pet_bodyguard_level(native_handle,clampi(Skills.level_for(self,id),1,30))
  assert(configured,"Invalid pet 護衛 upgrade")
 for skill in controllers:
  if Skills.Levels.family(skill)==Skills.Levels.family(id):controllers[skill].prepare_projectiles()
 if Skills.Levels.family(id)==Skills.Levels.family(Pets.Spells.COMBO) and native_handle:
  runtime.native.set_pet_skills(native_handle,Pets.skill_codes(selected),int(Skills.effective(self,Pets.Spells.COMBO,"count")))
func damage_multiplier()->float:return team_progression.pet_damage_multiplier(pet_key)
func base_magic_damage()->float:return 0.0
func combat_tuning(key:String)->float:return 0.0 if key=="critical_chance" else game.balance_value(RogueRoster.KAZI_ID,key)
func auto_aim_origin()->Vector3:return model.qi_blast_chest()
func combat_attack_direction()->Vector3:return facing
func hit_effect_scale()->float:return 1.0
func melee_range_multiplier()->float:return 1.0
func _exit_tree():retire()
