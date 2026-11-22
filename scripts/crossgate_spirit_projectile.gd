extends "res://scripts/crossgate_moon_projectile.gd"

var visual_frame=-1

const RINGS=preload("res://assets/characters/crossgate/ruby/spirit-rings.png")
const IMPACTS=preload("res://scripts/crossgate_element_projectile.gd").BURSTS
const RING_COUNT=5
const TRAVEL_SPEED=144.0
const IMPACT_FRAME_TIME=2*TICK
const IMPACT_FRAMES=7
const GHOST_LIFE=12
const GHOSTS_PER_TICK=RING_COUNT-1
const GHOST_CAPACITY=GHOST_LIFE*GHOSTS_PER_TICK
static var ghost_quad:QuadMesh
var rings:Array[Sprite3D]=[]
var burst:Sprite3D
var ghosts:MultiMeshInstance3D
var impact_age=-1.0
var travel_time=0.0
var spread_radius=0.0
var ghost_elapsed=0.0
var ghost_tick=0
var last_stamp=0
var ghost_cursor=0

func _ready():
 for i in RING_COUNT:rings.append(make_sprite(RINGS,8,2))
 burst=make_sprite(IMPACTS[0],IMPACT_FRAMES,1)
 if ghost_quad==null:
  ghost_quad=QuadMesh.new()
  ghost_quad.size=Vector2(40,80)*PIXEL
  var material=ShaderMaterial.new()
  material.shader=preload("res://assets/characters/crossgate/ruby/spirit-afterimages.gdshader")
  material.set_shader_parameter("atlas",RINGS)
  ghost_quad.material=material
 ghosts=MultiMeshInstance3D.new()
 ghosts.top_level=true
 ghosts.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 ghosts.multimesh=MultiMesh.new()
 ghosts.multimesh.transform_format=MultiMesh.TRANSFORM_3D
 ghosts.multimesh.use_custom_data=true
 ghosts.multimesh.mesh=ghost_quad
 ghosts.multimesh.instance_count=GHOST_CAPACITY
 ghosts.multimesh.visible_instance_count=0
 add_child(ghosts)

func make_sprite(sheet:Texture2D,columns:int,rows:int)->Sprite3D:
 var sprite=Sprite3D.new()
 sprite.texture=sheet;sprite.hframes=columns;sprite.vframes=rows
 sprite.pixel_size=PIXEL
 sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(sprite)
 return sprite

func restart_visual():
 burst.hide()
 burst.modulate.a=.55 if game.settings.get("reduced_flashes",false) else 1.0
 for ring in rings:ring.show()
 var distance=global_position.distance_to(AttackChain.aim_point(target,global_position))
 travel_time=maxf(TICK,distance/maxf(1.0,velocity.length()))
 spread_radius=minf(180.0*PIXEL,distance*.20)
 ghosts.global_position=global_position
 var bounds=Vector3.ONE*(velocity.length()*flight_life+spread_radius+5.0)
 ghosts.multimesh.custom_aabb=AABB(-bounds,bounds*2.0)
 ghosts.multimesh.visible_instance_count=0
 ghosts.set_instance_shader_parameter("tick",0.0)
 ghosts.set_instance_shader_parameter("opacity",burst.modulate.a)
 update_visual()
 first_from=global_position

func tune_visual():
 super.tune_visual()
 ghosts.scale=Vector3.ONE

func stamp_ghosts():
 last_stamp=ghost_tick
 var batch=ghosts.multimesh
 var scale_basis=Basis.from_scale(rings[0].scale)
 for i in GHOSTS_PER_TICK:
  var ring=rings[i+1]
  batch.set_instance_transform(ghost_cursor+i,Transform3D(scale_basis,ring.global_position-ghosts.global_position))
  batch.set_instance_custom_data(ghost_cursor+i,Color(float(ring.frame),float(ghost_tick),0.0,0.0))
 batch.visible_instance_count=maxi(batch.visible_instance_count,ghost_cursor+GHOSTS_PER_TICK)
 ghost_cursor=(ghost_cursor+GHOSTS_PER_TICK)%GHOST_CAPACITY

func update_visual():
 var basis:Basis=game.camera_rig.camera.global_basis
 var facing=velocity.normalized()
 var right=Vector3(basis.x.x,0,basis.x.z).normalized()
 var back=Vector3(basis.z.x,0,basis.z.z).normalized()
 var direction=posmod(roundi(atan2(facing.dot(right),-facing.dot(back))*8/TAU)+1,8)
 if direction!=visual_frame:
  for ring in rings:ring.frame=direction
  visual_frame=direction
 # The client fans four child rings out and back using a quadratic radius.
 var heading=Vector2(facing.dot(basis.x),facing.dot(basis.y)).normalized()
 if heading.is_zero_approx():heading=Vector2.UP
 var progress=clampf(age/travel_time,0.0,1.0)
 var radius=4.0*spread_radius*progress*(1.0-progress)
 for i in range(1,RING_COUNT):
  var offset=heading.rotated(deg_to_rad(135.0+30.0*(i-1)))*radius
  rings[i].position=basis.x*offset.x+basis.y*offset.y

func finish_contact(point:Vector3):
 global_position=point
 burst.texture=IMPACTS[posmod(target.get_instance_id(),IMPACTS.size())]
 burst.frame=0;burst.show()
 var audio_frame=Engine.get_physics_frames()
 if attack_ticket.get("spirit_hit_frame",-1)!=audio_frame and (not hero.ai_controlled or game.move_audio.ally_nearby(game,point)):
  attack_ticket.spirit_hit_frame=audio_frame
  game.sound("cg_spirit_hit",.8,false,attack_ticket,35)
 end_flight()

func end_flight():
 for ring in rings:ring.hide()
 impact_age=0.0
 if attack_ticket.has("magic_result"):attack_ticket.magic_result.pending-=1
 attack_ticket={}
 target=null

func step_destination(delta:float,tracking:bool)->Vector3:
 var travel=velocity*delta
 if tracking:
  var offset=AttackChain.aim_point(target,global_position)-global_position
  travel=offset.limit_length(travel.length())
  if not travel.is_zero_approx():velocity=travel.normalized()*velocity.length()
 return global_position+travel

func _physics_process(delta:float):
 if not is_instance_valid(hero) or not game.playing:retire();return
 if game.paused or game.transitioning:return
 ghost_elapsed+=delta
 var tick=floori(ghost_elapsed/TICK+.000001)
 if tick>ghost_tick:
  ghost_tick=tick
  ghosts.set_instance_shader_parameter("tick",float(tick))
  if impact_age<0:stamp_ghosts()
 if impact_age<0:
  super._physics_process(delta);return
 impact_age+=delta
 var frame=floori(impact_age/IMPACT_FRAME_TIME+.000001)
 if burst.visible:
  if frame>=IMPACT_FRAMES:burst.hide()
  else:burst.frame=frame
 if not burst.visible and ghost_tick-last_stamp>=GHOST_LIFE:retire()
