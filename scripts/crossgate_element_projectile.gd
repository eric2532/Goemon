extends "res://scripts/character_projectile.gd"
## Recovered Blue Cross Gate level-11 sprites, on the shared character pool.
const CAST=preload("res://assets/characters/crossgate/elements/cast.png")
const FIRE=preload("res://assets/characters/crossgate/elements/fire.png")
const ICE=preload("res://assets/characters/crossgate/elements/ice.png")
const WIND=preload("res://assets/characters/crossgate/elements/wind.png")
const METEORS=[
 preload("res://assets/characters/crossgate/elements/meteor-1.png"),
 preload("res://assets/characters/crossgate/elements/meteor-2.png"),
 preload("res://assets/characters/crossgate/elements/meteor-3.png")]
const TRAIL=preload("res://assets/characters/crossgate/elements/wind-trail.png")
const BURSTS=[
 preload("res://assets/characters/crossgate/elements/wind-hit-1.png"),
 preload("res://assets/characters/crossgate/elements/wind-hit-2.png"),
 preload("res://assets/characters/crossgate/elements/wind-hit-3.png")]
const DAMAGE={"fire":1500.0,"ice":400.0,"wind":250.0,"meteor":650.0}
const Tiers=preload("res://scripts/spells/skill_effects.gd")
const VISUAL_SCALE=1.25
# Fire's native hit is frame 9. Ice adds two hits on earlier source crack frames.
const FIRE_CUES=[[4,"cg_fire_rise",0.0,-1],[9,"cg_fire_hit",76.5,0]]
const ICE_CUES=[[0,"cg_ice_rise",0.0,-1],[5,"cg_ice_a",72.0,0],[6,"cg_ice_b",0.0,-1],[7,"cg_ice_a",73.0,1],[10,"cg_ice_b",51.0,2]]
# The opening crack lies flat. The rising crystal uses its painted base.
const ICE_CRACK_CENTER=[277.0,277.0,277.0,274.0]
const ICE_BOTTOM=[333,318,317,317,317,274,275,275,275,275,275]
const WIND_INTERVAL=8.0/60.0
const WIND_REFERENCE_HEIGHT=.014*214.0
const WIND_RADIUS_PER_METRE=1.65/WIND_REFERENCE_HEIGHT
const METEOR_FALL=11.0/30.0
const METEOR_SECOND=10.0/60.0
const METEOR_CONTACT=[Rect2(1,13,148,120),Rect2(7,9,144,134),Rect2(14,0,121,140)]
# Visible height at Fire's impact, the shortest damaging Ice frame, and full Wind.
const BODY_PIXELS={"fire":165.0,"ice":205.0,"wind":214.0}
var kind="fire"
var target:Ninja
var velocity=Vector3.ZERO
var damage=0.0
var flight_life=2.5
var ignore_cover=false
var cast_hits:Array=[]
var sound_lead=false
var burst_index=0
var sprite:Sprite3D
var echo_sprite:Sprite3D
var effect_height=0.0
var effect_tier=3
var tier_clip:Dictionary={}
var combat_clip:Dictionary={}
var tier_ratio=1.0
var tier_cues:Array=[]
var start_delay=0.0
var age=0.0
var impact_age=-1.0
var marker=0
var ice_hit_count=3
var wind_spread=Vector3.ZERO

func _ready():
 Tiers.prepare()
 sprite=make_sprite()
 match kind:
  "fire":
   set_sheet(sprite,FIRE,8,2,.01)
   sprite.offset.y=86.5
  "ice":
   set_sheet(sprite,ICE,8,2,.01)
  "wind":
   set_sheet(sprite,WIND,4,1,.01)
   echo_sprite=make_sprite()
  "meteor":
   echo_sprite=make_sprite()

func make_sprite()->Sprite3D:
 var node=Sprite3D.new()
 node.billboard=BaseMaterial3D.BILLBOARD_ENABLED;node.shaded=false
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(node)
 return node

func set_sheet(node:Sprite3D,texture:Texture2D,columns:int,rows:int,pixel:float):
 node.frame=0;node.texture=texture;node.hframes=columns;node.vframes=rows;node.pixel_size=pixel

func restart_visual():
 tier_clip={};combat_clip={};tier_ratio=1.0
 tier_cues=FIRE_CUES if kind=="fire" else ICE_CUES
 if attack_ticket.has("skill_level"):
  var spec:Dictionary=Tiers.element(kind,effect_tier)
  var ref:String=spec.targets[burst_index%spec.targets.size()]
  tier_clip=Tiers.clip(ref)
  # EX art uses the same damage clock and contact volumes as the last ordinary tier.
  var combat_spec:Dictionary=Tiers.element(kind,mini(effect_tier,3))
  combat_clip=Tiers.clip(combat_spec.targets[burst_index%combat_spec.targets.size()])
  Tiers.sheet(sprite,ref)
  var bounds:Array=combat_clip.frame_bounds[mini(9,int(combat_clip.frames)-1)]
  tier_ratio=float(bounds[3]-bounds[1])/float(BODY_PIXELS.get(kind,140.0))
  if kind=="fire":
   var contact_frame=int(combat_clip.hit_frames[0])
   var contact:Array=combat_clip.frame_bounds[contact_frame]
   tier_cues=[[mini(4,contact_frame),"cg_fire_rise",0.0,-1],[contact_frame,"cg_fire_hit",float(contact[2]-contact[0])*.5,0]]
 sprite.frame=0;sprite.modulate.a=128.0/255.0 if kind=="fire" else 1.0
 if kind=="ice":set_ice_anchor(0)
 if kind=="meteor":
  var contact:Rect2=METEOR_CONTACT[burst_index]
  var texture:Texture2D=METEORS[burst_index]
  set_sheet(sprite,texture,8,2,effect_height/contact.size.y)
  sprite.offset.y=contact.end.y-texture.get_height()*.25
  if not tier_clip.is_empty():
   var ref:String=Tiers.element(kind,effect_tier).targets[burst_index%3]
   Tiers.sheet(sprite,ref);sprite.pixel_size=effect_height/140.0
   sprite.offset.y=float(tier_clip.height)*.5
 else:
  sprite.pixel_size=effect_height/float(BODY_PIXELS[kind])
  if not tier_clip.is_empty() and kind=="fire":sprite.offset.y=float(tier_clip.frame_bounds[tier_clip.hit_frames[0]][3])-float(tier_clip.height)*.5
 if echo_sprite!=null:
  set_sheet(echo_sprite,TRAIL,7,1,.02*effect_height/WIND_REFERENCE_HEIGHT)
  echo_sprite.position=Vector3.ZERO;echo_sprite.modulate.a=.5
  echo_sprite.hide()
 if kind=="wind":
  sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
  sprite.offset.y=float(tier_clip.frame_bounds[0][3])-float(tier_clip.height)*.5 if effect_tier==Tiers.Levels.EX_TIER else float(sprite.texture.get_height())/sprite.vframes*.5
  set_wind_anchor()
 if kind=="ice" and ice_hit_count>3:
  var frames=int(combat_clip.get("frames",15))
  tier_cues=[]
  for cycle in ceili(ice_hit_count/3.0):
   for original in ICE_CUES:
    var cue:Array=original.duplicate()
    cue[0]+=cycle*frames
    if cue[3]>=0:
     cue[3]+=cycle*3
     if cue[3]>=ice_hit_count:continue
    tier_cues.append(cue)
 if kind=="meteor":step_meteor()
 if start_delay>0.0:hide()
 else:reveal()

func reveal():
 show()
 if kind=="wind":sound("cg_wind_fly")

func tune_visual():
 super.tune_visual()
 sprite.scale*=VISUAL_SCALE
 if echo_sprite!=null:echo_sprite.scale*=VISUAL_SCALE
 if kind=="wind":set_wind_anchor()

func set_ice_anchor(frame:int):
 var crack=effect_tier!=Tiers.Levels.EX_TIER and frame<ICE_CRACK_CENTER.size()
 sprite.axis=Vector3.AXIS_Y if crack else Vector3.AXIS_Z
 sprite.billboard=BaseMaterial3D.BILLBOARD_DISABLED if crack else BaseMaterial3D.BILLBOARD_FIXED_Y
 sprite.position.y=game.world.surface_height_at(global_position)-global_position.y+.04
 if not tier_clip.is_empty():
  var bounds:Array=tier_clip.frame_bounds[frame]
  var anchor=(float(bounds[1])+float(bounds[3]))*.5 if crack else float(bounds[3])
  sprite.offset.y=anchor-float(tier_clip.height)*.5
  return
 var anchor:float=ICE_CRACK_CENTER[frame] if crack else ICE_BOTTOM[frame-ICE_CRACK_CENTER.size()]
 sprite.offset.y=anchor-176.5

func set_wind_anchor():
 var spread=wind_spread*smoothstep(0.0,.12,age)
 if is_instance_valid(target) and not target.dead:
  spread*=smoothstep(0.0,4.0,global_position.distance_to(target.global_position))
 elif impact_age>=0.0:spread=Vector3.ZERO
 # Only the artwork fans out; contacts keep the original homing path.
 sprite.position=spread
 sprite.position.y=game.world.surface_height_at(global_position+spread)-global_position.y+.04
 echo_sprite.position=sprite.position+Vector3.UP*float(sprite.texture.get_height())/sprite.vframes*sprite.pixel_size*sprite.scale.y*.5
 if impact_age<0.0:echo_sprite.position-=velocity.normalized()*1.05

func _physics_process(delta:float):
 if not is_instance_valid(hero) or not game.playing:retire();return
 if game.paused or game.transitioning:return
 if start_delay>0.0:
  var waiting=minf(delta,start_delay)
  start_delay-=waiting
  if start_delay>0.0:return
  reveal()
  delta-=waiting
 age+=delta
 if kind=="wind":
  step_wind(delta)
  if pool_live:set_wind_anchor()
  return
 if kind=="meteor":
  step_meteor();return
 var fire=kind=="fire"
 var fps=20.0 if fire else 30.0
 var frames=16 if fire else 15
 if not combat_clip.is_empty():frames=int(combat_clip.frames);fps=float(frames)*1000.0/float(combat_clip.duration)
 var frame=floori(age*fps)
 var cues=tier_cues
 while marker<cues.size() and frame>=int(cues[marker][0]):
  var cue:Array=cues[marker]
  if sound_lead or cue[3]==0:sound(cue[1])
  if cue[3]>=0:
   var radius=float(cue[2])*sprite.pixel_size
   if not combat_clip.is_empty() and not fire:
    var bounds:Array=combat_clip.frame_bounds[int(cue[0])%frames]
    radius=float(bounds[2]-bounds[0])*.5*sprite.pixel_size
   pulse(global_position+Vector3.UP*effect_height*tier_ratio*.5,radius,cast_hits[cue[3]])
  marker+=1
 var total_frames=frames*(ceili(ice_hit_count/3.0) if not fire else 1)
 if age>=total_frames/fps+(0.0 if fire else 19.0/60.0):retire();return
 var next_frame=mini(frame,frames-1) if fire or frame>=total_frames else frame%frames
 if effect_tier==Tiers.Levels.EX_TIER:
  var visual_frames=int(tier_clip.frames)
  if fire:
   var contact=float(combat_clip.hit_frames[0])
   var visual_contact=float(tier_clip.hit_frames[0])
   var phase=age*fps
   next_frame=clampi(floori(remap(phase,0.0,contact,0.0,visual_contact) if phase<contact else remap(phase,contact,frames,visual_contact,visual_frames)),0,visual_frames-1)
  elif frame>=total_frames:next_frame=visual_frames-1
  else:next_frame=floori(fposmod(age*fps,frames)*visual_frames/frames)
 if sprite.frame!=next_frame:
  sprite.frame=next_frame
  if not fire:set_ice_anchor(next_frame)
 if frame>=total_frames:sprite.modulate.a=.5

func step_meteor():
 if age<METEOR_FALL:
  var progress=age/METEOR_FALL
  sprite.position=Vector3(.35,1.2,0)*effect_height*(1.0-progress*progress)
  sprite.frame=floori(progress*int(tier_clip.frames)) if effect_tier==Tiers.Levels.EX_TIER else floori(age*30.0)
  echo_sprite.position=sprite.position+Vector3.UP*effect_height*.4
  echo_sprite.frame=posmod(floori(age*15.0),7);echo_sprite.show()
  return
 var landed=age-METEOR_FALL
 sprite.position=Vector3.ZERO;sprite.frame=int(tier_clip.frames)-1 if effect_tier==Tiers.Levels.EX_TIER else 10
 sprite.modulate.a=1.0-smoothstep(0.0,METEOR_SECOND+7.0/30.0,landed)
 while marker<2 and landed>=marker*METEOR_SECOND:
  sound("cg_meteor_hit")
  var center=global_position+Vector3.UP*effect_height*tier_ratio*.5
  var radius=METEOR_CONTACT[burst_index].size.x*.5*sprite.pixel_size if combat_clip.is_empty() else float(combat_clip.width)*.5*sprite.pixel_size
  pulse(center,radius,cast_hits[marker])
  set_sheet(echo_sprite,BURSTS[burst_index],7,1,effect_height*tier_ratio/131.0)
  echo_sprite.position=Vector3.UP*effect_height*tier_ratio*.5*sprite.scale.y;echo_sprite.show()
  marker+=1
 echo_sprite.frame=clampi(floori((landed-(marker-1)*METEOR_SECOND)*30.0),0,6)
 if landed>=METEOR_SECOND+7.0/30.0:retire()

func step_wind(delta:float):
 if effect_tier==Tiers.Levels.EX_TIER:
  sprite.frame=posmod(floori(age*1000.0*float(tier_clip.frames)/float(tier_clip.duration)),int(tier_clip.frames))
  sprite.offset.y=float(tier_clip.frame_bounds[sprite.frame][3])-float(tier_clip.height)*.5
 else:sprite.frame=posmod(floori(age*60.0),4)
 if impact_age>=0.0:
  impact_age+=delta
  echo_sprite.frame=mini(floori(impact_age*30.0),6)
  if impact_age>=7.0/30.0:echo_sprite.hide()
  while marker<4 and impact_age>=marker*WIND_INTERVAL:
   pulse(global_position,WIND_RADIUS_PER_METRE*effect_height*tier_ratio,cast_hits[marker] if cast_hits.size()>marker else {})
   marker+=1
  if impact_age>=4*WIND_INTERVAL:retire()
  return
 if age>=flight_life:retire();return
 var from=global_position
 var tracking=is_instance_valid(target) and not target.dead
 if tracking:
  var offset=AttackChain.aim_point(target,from)-from
  if not offset.is_zero_approx():velocity=offset.normalized()*velocity.length()
 var next=from+velocity*delta
 var wall={} if ignore_cover else AttackChain.world_ray(self,from,next)
 var end:Vector3=next if wall.is_empty() else wall.position
 if tracking:
  var hit=AttackChain.segment_contact(target,from,end,.48*skill_factor("hit_area"))
  if not hit.is_empty() and (ignore_cover or AttackChain.clear_line(self,from,hit.point)):
   global_position=hit.point;target=null;impact_age=0.0
   set_sheet(echo_sprite,BURSTS[burst_index],7,1,effect_height/131.0)
   echo_sprite.position=Vector3.ZERO;echo_sprite.show()
   sound("cg_wind_hit")
   pulse(global_position,WIND_RADIUS_PER_METRE*effect_height*tier_ratio,cast_hits[0] if not cast_hits.is_empty() else {})
   marker=1
   return
 if not wall.is_empty():retire();return
 global_position=next
 echo_sprite.position=-velocity.normalized()*1.05
 echo_sprite.frame=posmod(floori(age*15.0),7);echo_sprite.show()

func pulse(center:Vector3,radius:float,struck:Dictionary):
 radius*=skill_factor("hit_area")
 var half_height=effect_height*tier_ratio*.5*skill_factor("hit_area")
 var reach=sqrt(radius*radius+half_height*half_height)
 for enemy in AttackChain.enemy_candidates(game,center,reach):
  if not is_instance_valid(enemy) or enemy.dead or struck.has(enemy.get_instance_id()):continue
  if attack_ticket.has("element_target_ids") and not attack_ticket.element_target_ids.has(enemy.get_instance_id()):continue
  if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  var point=AttackChain.aim_point(enemy,center)
  var offset=point-center
  if absf(offset.y)>half_height or Vector2(offset.x,offset.z).length_squared()>radius*radius:continue
  if not ignore_cover and not AttackChain.clear_line(self,center,point):continue
  struck[enemy.get_instance_id()]=true
  var direction=velocity.normalized() if kind=="wind" else Vector3(offset.x,0,offset.z).normalized()
  damage_spell_target(enemy,damage,direction)

func sound(cue:String):
 if not hero.ai_controlled or game.move_audio.ally_nearby(game,global_position):
  game.sound(cue,.8,false,attack_ticket,int(attack_ticket.get("crossgate_sound_source",34)))

func retire():
 cast_hits=[]
 super.retire()
