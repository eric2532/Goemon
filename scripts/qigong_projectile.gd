extends "res://scripts/character_projectile.gd"
## The eight original Blue Cross Gate frames share one material and mesh.
const LIFE=2.5
const SOURCE_ID=34
const IMPACT_SHEETS=preload("res://scripts/crossgate_element_projectile.gd").BURSTS
const SHINE_LEAD=.10
const SHINE_DURATION=7.0/30.0
const BRAKE_DISTANCE=2.5
const CONTACT_SPEED_FACTOR=.55
const ORB_SCALE=.72
const VISUAL_SCALE=.3
const REFERENCE_DIAMETER=6.88
const DIAMETER=REFERENCE_DIAMETER*ORB_SCALE
const FRAME_DIAMETERS=[51.0,63.0,56.0,63.0,60.0,63.0,56.0,63.0]
const Tiers=preload("res://scripts/spells/skill_effects.gd")
static var mesh:QuadMesh
static var material:ShaderMaterial
static var ex_material:ShaderMaterial
var visual:MeshInstance3D
var target:Ninja
var target_range=0.0
var was_targeted=false
var velocity=Vector3.ZERO
var hit_radius=DIAMETER*.5
var effect_height=0.0
var damage=0.0
var flight_life=LIFE
var terrain_exclude:Array[RID]=[]
var start_delay=0.0
var age=0.0
var frame=-1
var shine:Sprite3D
var rank11_shine=false
var burst_index=0
var shine_age=-1.0
var contact_done=false
var collision_scale=1.0
var shine_anchor:Dictionary={}

func _ready():
 if mesh==null:
  mesh=QuadMesh.new();mesh.size=Vector2(7.0*ORB_SCALE,DIAMETER)
  material=ShaderMaterial.new();material.shader=preload("res://assets/characters/crossgate/qigong/orbs.gdshader")
  material.set_shader_parameter("atlas",preload("res://assets/characters/crossgate/qigong/orbs.png"))
  Tiers.prepare()
  ex_material=material.duplicate()
  ex_material.set_shader_parameter("atlas",Tiers.textures["111055"])
 visual=MeshInstance3D.new();visual.mesh=mesh;visual.material_override=material
 visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)
 shine=Sprite3D.new();shine.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 shine.shaded=false;shine.render_priority=1;shine.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 shine.hframes=7;shine.top_level=true;add_child(shine);shine.hide()

func restart_visual():
 set_process(false)
 was_targeted=is_instance_valid(target)
 var size=effect_height/DIAMETER if effect_height>0 else 1.0
 collision_scale=size
 visual.scale=Vector3.ONE*size*VISUAL_SCALE
 var ex=Tiers.Levels.is_ex(attack_ticket)
 visual.material_override=ex_material if ex else material
 if ex:visual.scale*=Vector3(116.0/64.0,104.0/63.0,1)
 visual.position=Vector3.ZERO
 frame=0;visual.set_instance_shader_parameter("frame",0.0)
 visual.show();shine.hide();shine.modulate=attack_ticket.get("qi_color",Color.WHITE)
 visual.set_instance_shader_parameter("uru_palette",0.0)
 visual.set_instance_shader_parameter("gold_palette",1.0 if attack_ticket.get("gold_palette",false) else 0.0)
 visual.set_instance_shader_parameter("qi_tint",attack_ticket.get("qi_color",Color.WHITE))
 visual.set_instance_shader_parameter("qi_chrome",1.0 if attack_ticket.get("qi_chrome",false) else 0.0)
 rank11_shine=bool(attack_ticket.get("rank11_shine",false))
 if rank11_shine:
  shine.texture=IMPACT_SHEETS[burst_index];shine.frame=0
  shine.pixel_size=effect_height*VISUAL_SCALE/131.0
 if start_delay>0.0:hide()
 else:reveal()

func reveal():
 show()
 if not hero.ai_controlled or game.move_audio.ally_nearby(game,global_position):
  var source=int(attack_ticket.get("crossgate_sound_source",SOURCE_ID))
  game.sound("qigong_launch",.8,false,attack_ticket,source)

static func flight_aim_point(enemy:Ninja,from:Vector3)->Vector3:
 if enemy.has_method("combat_bounds"):
  var bounds:AABB=enemy.combat_bounds()
  from.y=bounds.get_center().y
 return AttackChain.aim_point(enemy,from)

func replacement_target()->Ninja:
 var nearest:Ninja
 var closest=INF
 for enemy in AttackChain.enemy_candidates(game,hero.global_position,target_range):
  if not is_instance_valid(enemy) or enemy.dead or enemy.hp<=0:continue
  if hero.global_position.distance_squared_to(enemy.global_position)>target_range*target_range:continue
  if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  var point=flight_aim_point(enemy,global_position)
  var distance=global_position.distance_squared_to(point)
  if distance>=closest or not AttackChain.clear_line(self,global_position,point,terrain_exclude):continue
  nearest=enemy;closest=distance
 return nearest

func _physics_process(delta:float):
 if not is_instance_valid(hero) or not game.playing:retire();return
 if game.paused or game.transitioning:return
 if start_delay>0.0:
  var waiting=minf(delta,start_delay)
  start_delay-=waiting
  if start_delay>0.0:return
  reveal()
  delta-=waiting
 if shine_age>=0.0:
  shine_age+=delta
  update_shine_position()
  shine.frame=mini(6,floori(shine_age*30.0))
  if contact_done:
   if shine_age>=SHINE_DURATION:retire()
   return
 age+=delta
 var tracking=is_instance_valid(target) and not target.dead and target.hp>0
 if was_targeted and not tracking:
  target=replacement_target()
  shine_age=-1.0;shine_anchor={};shine.hide();set_process(false)
  if target==null:retire();return
  tracking=true
 if age>=flight_life and not tracking:retire();return
 var from=global_position
 var next=from+velocity*delta
 var max_radius=hit_radius*collision_scale
 if tracking:
  var offset=flight_aim_point(target,from)-from
  var distance=offset.length()
  if distance>.001:
   # Catch a fleeing target by the prepared flight deadline instead of leaking leases.
   var speed=maxf(velocity.length(),distance/maxf(delta,flight_life-age))
   velocity=offset/distance*speed
   var pace=lerpf(CONTACT_SPEED_FACTOR,1.0,smoothstep(0.0,BRAKE_DISTANCE,distance-max_radius))
   next=from+offset.limit_length(speed*pace*delta)
  else:next=from+offset
 var wall={} if tracking else AttackChain.world_ray(self,from,next,1,terrain_exclude)
 var next_frame=posmod(floori(age*60.0),8)
 if tracking:
  var end:Vector3=next if wall.is_empty() else wall.position
  var point=AttackChain.aim_point(target,end)
  var radius=max_radius*FRAME_DIAMETERS[next_frame]/63.0
  var distance_sq=end.distance_squared_to(point)
  var touching=distance_sq<=radius*radius
  var shine_reach=radius+2.0
  var starts_shine=rank11_shine and shine_age<0.0 and distance_sq<=shine_reach*shine_reach
  if touching or starts_shine:
   if starts_shine:
    shine_age=0.0;shine.show();set_process(true)
   if rank11_shine:
    shine_anchor=AttackChain.effect_anchor(target)
    update_shine_position()
    if touching and shine_age<SHINE_LEAD:return
   if not touching:
    global_position+=next-from
    return
   var direction=velocity.normalized()
   damage_spell_area(target,next,radius,damage,direction,terrain_exclude)
   var source=int(attack_ticket.get("crossgate_sound_source",SOURCE_ID))
   if hero.ai_controlled:game.confirm_ally_impact(target,point,direction,1,true,source,false,null,"qigong_hit")
   else:game.confirm_impact(target,point,direction,1,true,source,false,null,true,"qigong_hit")
   if rank11_shine:
    visual.hide();contact_done=true;target=null
    return
   if not game.has_method("forest_point_visible") or game.forest_point_visible(point):
    var anchor=AttackChain.effect_anchor(target)
    var flash=RecoveredGoemonVFX.hit(game,anchor.position)
    # The visible stars reach about 2.34 m during the bright part of the shared burst.
    if is_instance_valid(flash) and not game.settings.get("reduced_flashes",false):
     flash.scale*=maxf(1.0,effect_height*skill_factor("size")/2.34)*VISUAL_SCALE
   retire();return
 if not wall.is_empty():retire();return
 if shine_age>=0.0 and (not tracking or shine_age>=SHINE_DURATION):
  shine_age=-1.0;shine.hide()
 global_position+=next-from
 if next_frame!=frame:
  frame=next_frame;visual.set_instance_shader_parameter("frame",float(frame))

func update_shine_position():
 if shine_anchor.is_empty():return
 var camera=get_viewport().get_camera_3d()
 if camera!=null:shine.global_transform=AttackChain.centered_effect_pose(camera,shine_anchor.position,Vector3.ONE*skill_factor("size"),shine_anchor.depth)

func _process(_delta:float):
 if shine.visible:update_shine_position()
