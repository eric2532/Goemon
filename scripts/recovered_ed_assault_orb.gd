class_name RecoveredEdAssaultOrb
extends Node3D
## SC06/016 actors2FF -> eight303, effects5E/60. Ballistics, reach and damage
## are playable port tuning; sprites and eight headings come from the source.
const BALL=preload("res://assets/characters/recovered_leaders/ed/assault/ball.png")
const FIRE=preload("res://assets/characters/recovered_leaders/ed/assault/fire.png")
const FIRE_SCALE=3.0
const FIRE_LIFETIME=4.5
var game: Node
var hero: Hero
var attack_ticket: Dictionary={}
var cast_stats: Dictionary={"bursts":0}
var velocity=Vector3.ZERO
var damage=270.0
var attack_scale=1.0
var range_scale=1.0
var age=0.0
var fire_age=0.0
var floor_bounces=0
var exploded=false
var fire_origin=Vector3.ZERO
var body: Sprite3D
var flames: Array[Sprite3D]=[]
var directions: Array[Vector3]=[]
var blocked: Array[bool]=[]
var struck: Dictionary={}

static func sprite(host: Node3D,texture: Texture2D,pixel_size: float)->Sprite3D:
 var node=Sprite3D.new();node.texture=texture;node.pixel_size=pixel_size
 node.billboard=BaseMaterial3D.BILLBOARD_ENABLED;node.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/recovered_leaders/source_palette.gdshader")
 material.set_shader_parameter("textured",true);material.set_shader_parameter("billboard",true);material.set_shader_parameter("albedo_texture",texture)
 var environment=host.get_world_3d().environment
 if environment:
  material.set_shader_parameter("compensate_filmic",environment.tonemap_mode==Environment.TONE_MAPPER_FILMIC)
  material.set_shader_parameter("scene_exposure",environment.tonemap_exposure);material.set_shader_parameter("scene_white",environment.tonemap_white)
 node.material_override=material;host.add_child(node);return node

func _ready():
 add_to_group("projectiles");add_to_group("ed_assault_orbs")
 body=sprite(self,BALL,.06*attack_scale)

func _physics_process(delta: float):
 if is_queued_for_deletion():return
 if not is_instance_valid(game) or not is_instance_valid(hero) or not game.playing or game.transitioning:
  queue_free();return
 if game.paused:return
 var remaining=maxf(0,delta)
 while remaining>.000001:
  var step=minf(remaining,1.0/60.0);remaining-=step
  if exploded:
   _spread(step)
   if fire_age>=FIRE_LIFETIME:queue_free();return
  else:_fly(step)

func _ray(from: Vector3,to: Vector3)->Dictionary:
 if from.distance_squared_to(to)<.000001:return {}
 var query=PhysicsRayQueryParameters3D.create(from,to,1);query.hit_from_inside=true
 return get_world_3d().direct_space_state.intersect_ray(query)

func _fly(step: float):
 age+=step
 var from=global_position
 var gravity=Vector3.DOWN*16.0*attack_scale
 var next=from+velocity*step+gravity*step*step*.5
 velocity+=gravity*step
 var wall=_ray(from,next)
 if wall.is_empty() and velocity.y<0:
  var floor_=_ray(from-Vector3.UP*.9*attack_scale,next-Vector3.UP*.9*attack_scale)
  if not floor_.is_empty() and floor_.normal.y>.65:
   wall=floor_;wall.position+=Vector3.UP*.9*attack_scale
 var end: Vector3=next if wall.is_empty() else wall.position
 var nearest=INF
 for enemy in game.enemies:
  if not is_instance_valid(enemy) or enemy.dead:continue
  var contact=AttackChain.segment_contact(enemy,from,end,1.1*attack_scale)
  if contact.is_empty() or float(contact.t)>=nearest:continue
  var center=from.lerp(end,float(contact.t))
  if _ray(center,AttackChain.aim_point(enemy,center)).is_empty():nearest=float(contact.t)
 if nearest<INF:
  global_position=from.lerp(end,nearest);_explode();return
 if not wall.is_empty():
  global_position=wall.position+wall.normal*.04
  if wall.normal.y>.65 and velocity.y<0 and floor_bounces<1:
   floor_bounces+=1;velocity=velocity.bounce(wall.normal);velocity.y=maxf(5*attack_scale,velocity.y*.72)
   game.sound("ed_assault_bounce",.5,false,attack_ticket,14)
  else:_explode();return
 else:global_position=next
 if age>=2.4:_explode();return
 var squash=1.0+.12*sin(age*18)
 body.scale=Vector3(1.0/squash,squash,1)

func _damage(enemy: Ninja,point: Vector3):
 var id=enemy.get_instance_id()
 if struck.has(id):return
 struck[id]=true
 var direction=(point-global_position).normalized()
 if direction.length_squared()<.001:direction=Vector3.UP
 enemy.take_hit(damage,direction,true,attack_ticket)
 var local=not attack_ticket.get("allied",false) and game.player==hero and hero.character_id==14
 if local:game.confirm_impact(enemy,point,direction,2,true,14)
 else:game.confirm_ally_impact(enemy,point,direction,2,true,14)

func _explode():
 if exploded:return
 exploded=true;cast_stats.bursts+=1
 var radius=9.0*attack_scale*range_scale
 for enemy in game.enemies:
  if not is_instance_valid(enemy) or enemy.dead or struck.has(enemy.get_instance_id()):continue
  if AttackChain.segment_contact(enemy,global_position,global_position,radius).is_empty():continue
  var contact=AttackChain.contact_point(enemy,global_position,enemy.global_position+Vector3.UP)
  if _ray(global_position,contact).is_empty():_damage(enemy,contact)
 BreakableBuilding.hit_area(game,global_position,radius,damage,attack_ticket,Vector3.ZERO,-1.0,struck)
 game.sound("ed_assault_burst",.6,false,attack_ticket,14)
 fire_origin=global_position
 var floor_=_ray(global_position,global_position-Vector3.UP*40*attack_scale)
 if not floor_.is_empty() and floor_.normal.y>.65:fire_origin.y=floor_.position.y+1.05*attack_scale
 # The orange ball expands into the native animated fire sprites. Each spoke
 # stops at cover and shares the burst's hit set, so overlap never multiplies HP.
 for i in 8:
  var direction=Vector3.FORWARD.rotated(Vector3.UP,i*TAU/8)
  var flame=sprite(self,FIRE,.038*FIRE_SCALE*attack_scale);flame.hframes=4;flame.vframes=4
  flame.material_override.set_shader_parameter("billboard_direction",direction)
  # Keep the enlarged quad above the floor without lifting its collision ray
  # over low cover. Ground following still uses the original front altitude.
  flame.material_override.set_shader_parameter("billboard_lift",(.038*64*FIRE_SCALE*.5-1.05)*attack_scale)
  flame.global_position=fire_origin
  flames.append(flame);directions.append(direction);blocked.append(false)
 _spread(0)

func _spread(step: float):
 fire_age=minf(FIRE_LIFETIME,fire_age+step)
 var distance=fire_age*4.0*attack_scale*range_scale
 body.visible=fire_age<.22;body.scale=Vector3.ONE*(1+fire_age*12)
 for i in 8:
  if blocked[i]:continue
  var from=flames[i].global_position
  var to=fire_origin+directions[i]*distance
  to.y=from.y
  # Sweep ahead before sampling the next floor, so a wall's top cannot lift
  # the front over cover. Probe from the current altitude to keep climbing ramps.
  var wall=_ray(from,to)
  if wall.is_empty():
   var floor_=_ray(to+Vector3.UP*2*attack_scale,to-Vector3.UP*20*attack_scale)
   if not floor_.is_empty() and floor_.normal.y>.65:to.y=floor_.position.y+1.05*attack_scale
   wall=_ray(from,to)
  if not wall.is_empty():to=wall.position;blocked[i]=true
  flames[i].global_position=to;flames[i].frame=posmod(floori(fire_age*30),16)
  if blocked[i]:flames[i].visible=false
  for enemy in game.enemies:
   if not is_instance_valid(enemy) or enemy.dead or struck.has(enemy.get_instance_id()):continue
   var contact=AttackChain.segment_contact(enemy,from,to,1.2*FIRE_SCALE*attack_scale)
   if contact.is_empty():continue
   var center=from.lerp(to,float(contact.t))
   if _ray(center,AttackChain.aim_point(enemy,center)).is_empty():_damage(enemy,contact.point)
  BreakableBuilding.hit_segment(game,from,to+directions[i]*.02 if blocked[i] else to,damage,attack_ticket,struck)
