extends "res://scripts/character_combat.gd"

const CAST=preload("res://assets/characters/crossgate/ruby/recovery-cast.png")
const ARRIVAL=preload("res://assets/characters/crossgate/ruby/recovery-ring.png")
const RING=preload("res://assets/characters/crossgate/ruby/recovery-hoops.png")
const WINDUP=21.0/60.0
const ARRIVAL_DURATION=40.0/60.0
const ARRIVAL_TRAVEL=10.0/60.0
const NUMBER_DURATION=.35
const COOLDOWN_DURATION=10.0
const DIGITS=preload("res://assets/characters/crossgate/hit_feedback/healing.fnt")
const Tiers=preload("res://scripts/spells/skill_effects.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
var cooldown=0.0
var cast_left=0.0
var cast_speed=1.0
var arrival_left=0.0
var ring_left=0.0
var number_left=0.0
var moves_left=0
var arrival_height=0.0
var last_action:Dictionary
var effect:Sprite3D
var heal_number:Label3D
var number_height=0.0
var ticket:Dictionary={}
var tier=0
var frames=0

func _ready():
 Tiers.prepare()
 effect=Sprite3D.new()
 effect.name="UruRecoveryEffect"
 effect.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 effect.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 effect.shaded=false
 effect.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 effect.render_priority=1
 effect.hide()
 hero.add_child(effect)
 heal_number=Label3D.new()
 heal_number.name="UruHealNumber"
 heal_number.font=DIGITS
 heal_number.font_size=16
 heal_number.outline_size=0
 heal_number.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 heal_number.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 heal_number.no_depth_test=true
 heal_number.render_priority=2
 heal_number.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 heal_number.hide()
 hero.add_child(heal_number)

func start_recovery():
 if not hero.spend_skill_mana("uru/recovery"):return
 hero.attack_chain.kazi_combo_streak=0
 ticket=hero.attack_chain.make_ticket("uru/recovery")
 tier=int(ticket.get("skill_rules",{}).get("effect_tier",0))
 cooldown=COOLDOWN_DURATION
 moves_left=0
 last_action={}
 arrival_left=0;ring_left=0;number_left=0
 heal_number.hide()
 cast_left=WINDUP
 cast_speed=hero.spell_loadout.primary_combo_cast_speed()
 show_tier(Tiers.recovery(tier).cast,true)
 hero.play_sound("cg_recovery_cast",.8)

func show_tier(ref:String,casting:bool):
 var row:Dictionary=Tiers.clip(ref)
 frames=int(row.frames)
 show_effect(Tiers.textures[ref],int(row.columns),ceili(float(row.frames)/float(row.columns)),Vector2.ZERO,1.0)
 if casting:effect.scale=Vector3.ONE*Skills.shine_factor(ticket)
 effect.offset=Vector2(-(float(row.bounds[0])+float(row.width)*.5),float(row.height)*.5-float(row.bounds[3])) if casting else Vector2.ZERO

func show_effect(sheet:Texture2D,columns:int,rows:int,offset:Vector2,alpha:float):
 effect.frame=0
 effect.texture=sheet
 effect.hframes=columns
 effect.vframes=rows
 var pixel_size:float=hero.model.sprite.pixel_size
 effect.pixel_size=pixel_size*hero.model.global_basis.y.length()/hero.global_basis.y.length()
 effect.scale=Vector3.ONE*skill_factor("size",ticket)
 effect.global_position=hero.model.to_global(Vector3.UP*hero.model.FEET_OFFSET_PIXELS*pixel_size)
 effect.offset=offset
 effect.modulate=Color(1,1,1,alpha*.55 if game.settings.get("reduced_flashes",false) else alpha)
 effect.show()

func tick(delta:float):
 if hero.hp<=0:return
 cooldown=maxf(0,cooldown-delta)
 if number_left>0:
  number_left=maxf(0,number_left-delta)
  var t=1.0-number_left/NUMBER_DURATION
  heal_number.position.y=number_height+effect.pixel_size*17.5*t
  heal_number.modulate.a=minf(1.0,number_left/(NUMBER_DURATION*.4))
  if number_left<=0:heal_number.hide()
 if cast_left>0:
  cast_left=maxf(0,cast_left-delta*cast_speed)
  if cast_left>.000001:
   effect.frame=mini(frames-1,floori(frames*(1.0-cast_left/WINDUP)+.000001))
   return
  cast_left=0
  arrival_left=ARRIVAL_DURATION
  show_tier(Tiers.recovery(tier).target,false)
  arrival_height=effect.position.y+hero.model.body_height_pixels*.55*effect.pixel_size
  effect.position.y=arrival_height+65.0*effect.pixel_size
 elif arrival_left>0:
  var before=ARRIVAL_DURATION-arrival_left
  arrival_left=maxf(0,arrival_left-delta*cast_speed)
  var elapsed=ARRIVAL_DURATION-arrival_left
  effect.position.y=arrival_height+65.0*effect.pixel_size*(1.0-clampf(elapsed/ARRIVAL_TRAVEL,0,1))
  if before<ARRIVAL_TRAVEL-.000001 and elapsed>=ARRIVAL_TRAVEL-.000001:hero.play_sound("cg_recovery_body",.8)
  if arrival_left>.000001:
   effect.frame=mini(frames-1,floori(frames*elapsed/ARRIVAL_DURATION+.000001))
   return
  arrival_left=0
  effect.hide()
  moves_left=0
  heal_pulse()
  last_action={}

func heal_pulse():
 hero.play_sound("cg_recovery_pulse",.8)
 var missing=maxf(0.0,hero.max_hp-hero.hp)
 var fraction=float(ticket.get("skill_healing",.20))
 var restored_hp=missing*fraction
 if restored_hp<=0:
  number_left=0
  heal_number.hide()
  return
 hero.hp+=restored_hp
 var restored=roundi(restored_hp)
 heal_number.visible=restored>0
 if restored>0:
  heal_number.text=str(restored)
  heal_number.pixel_size=effect.pixel_size
  number_height=(hero.model.FEET_OFFSET_PIXELS+72.0)*effect.pixel_size
  heal_number.position.y=number_height
  heal_number.modulate.a=1.0
  number_left=NUMBER_DURATION

func cancel(_preserve_power:bool=false):
 if is_instance_valid(hero) and hero.hp>0:return
 cooldown=0;cast_left=0;arrival_left=0;ring_left=0;number_left=0;moves_left=0
 last_action={}
 effect.hide()
 heal_number.hide()

func _exit_tree():
 if is_instance_valid(effect):effect.queue_free()
 if is_instance_valid(heal_number):heal_number.queue_free()
