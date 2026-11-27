extends "res://scripts/character_projectile.gd"
## Ground-gliding Cross Gate sword wave with a shared solid crescent.
const TICK=1.0/60.0
const PIXEL=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT/83.0
const SPEED=10.0*PIXEL/TICK
const GROUND_CLEARANCE=.08
const VISUAL_SCALE=Vector3(.72,.34,1.0)*preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER/78.0
const VISUAL_LENGTH=78.0*VISUAL_SCALE.z
const ARC_SEGMENTS=40
const ARC_HALF_SPAN=4.1
const ARC_DEPTH=3.3
const BLADE_WIDTH=1.18
const BLADE_THICKNESS=.11
const PROFILE=[Vector2(0,0),Vector2(.17,.82),Vector2(1,.82),Vector2(1,-.18),Vector2(.17,-.18)]
static var shock_mesh:ArrayMesh
static var shock_material:ShaderMaterial
static var spark_mesh:QuadMesh
static var spark_shrink:Curve
var visual:MeshInstance3D
var sparks:CPUParticles3D
var target:Ninja
var velocity=Vector3.ZERO
var terrain_exclude:Array[RID]=[]
var hit_radius=31.0*VISUAL_SCALE.x
var damage=0.0
var flight_life=0.0
var age=0.0
var first_from=Vector3.ZERO
var visual_growth=-1.0
var ground_normal=Vector3.UP

func _ready():
 if shock_mesh==null:
  shock_mesh=build_shock_mesh()
  shock_material=ShaderMaterial.new()
  shock_material.shader=preload("res://assets/characters/crossgate/kazi/moon-shockwave.gdshader")
  var glint=GradientTexture2D.new()
  glint.width=16;glint.height=16
  glint.fill=GradientTexture2D.FILL_RADIAL
  glint.fill_from=Vector2(.5,.5);glint.fill_to=Vector2(1,.5)
  glint.gradient=Gradient.new()
  glint.gradient.offsets=PackedFloat32Array([0.0,.36,1.0])
  glint.gradient.colors=PackedColorArray([Color.WHITE,Color.WHITE,Color(1,1,1,0)])
  var white=StandardMaterial3D.new()
  white.albedo_texture=glint
  white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  white.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  white.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
  white.billboard_keep_scale=true
  spark_mesh=QuadMesh.new()
  spark_mesh.material=white
  spark_shrink=Curve.new()
  spark_shrink.add_point(Vector2(0,1))
  spark_shrink.add_point(Vector2(.45,.9))
  spark_shrink.add_point(Vector2(1,0))
 visual=MeshInstance3D.new()
 visual.mesh=shock_mesh;visual.material_override=shock_material;visual.scale=VISUAL_SCALE
 # Clear the visible stair treads above the ground trace.
 visual.position.y=.42
 visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(visual)
 sparks=CPUParticles3D.new()
 sparks.emitting=false
 sparks.mesh=spark_mesh
 sparks.amount=8
 sparks.lifetime=.28
 sparks.local_coords=false
 sparks.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
 sparks.emission_box_extents=Vector3(.85,.12,.16)
 sparks.gravity=Vector3.ZERO
 sparks.direction=Vector3.UP
 sparks.spread=55.0
 sparks.initial_velocity_min=.25
 sparks.initial_velocity_max=.8
 sparks.scale_amount_min=.13
 sparks.scale_amount_max=.24
 sparks.scale_amount_curve=spark_shrink
 sparks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(sparks)

static func build_shock_mesh()->ArrayMesh:
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var tip_angle=deg_to_rad(85.0)
 var ring_size=PROFILE.size()
 for section in range(ARC_SEGMENTS+1):
  var t=2.0*section/ARC_SEGMENTS-1.0
  var taper=pow(1.0-t*t,1.18)
  var x=ARC_HALF_SPAN*sin(t*tip_angle)/sin(tip_angle)
  var edge_z=ARC_DEPTH*(cos(t*tip_angle)-1.0)/(1.0-cos(tip_angle))
  # Each tip is one vertex shared by all five faces.
  var count_=1 if section==0 or section==ARC_SEGMENTS else ring_size
  for side in count_:
   var profile:Vector2=PROFILE[side]
   var z=edge_z-BLADE_WIDTH*taper*profile.x
   var y=-.20*z+BLADE_THICKNESS*taper*profile.y
   surface.set_uv(Vector2(profile.x,(t+1.0)*.5))
   surface.add_vertex(Vector3(x,y,z)/VISUAL_SCALE)
 for segment in ARC_SEGMENTS:
  var first=segment==0
  var last=segment==ARC_SEGMENTS-1
  var from=0 if first else 1+(segment-1)*ring_size
  var to=1+segment*ring_size
  for side in ring_size:
   var next=(side+1)%ring_size
   if not first:
    for index in [from+side,from+next,to+(0 if last else side)]:surface.add_index(index)
   if not last:
    for index in [from+(0 if first else next),to+next,to+side]:surface.add_index(index)
 surface.generate_normals()
 return surface.commit()

func restart_visual():
 first_from=ground_point(global_position,12.0)
 if first_from==Vector3.INF:hide();return
 global_position=first_from
 var end=step_destination(2*TICK,is_instance_valid(target))
 if end!=Vector3.INF:
  var wall=AttackChain.world_ray(self,first_from,end,1,terrain_exclude)
  global_position=end if wall.is_empty() else wall.position
 update_visual()
 sparks.restart()
 sparks.emitting=true

func ground_point(point:Vector3,drop:float)->Vector3:
 var floor_hit=AttackChain.world_ray(self,point+Vector3.UP*.65,point-Vector3.UP*drop,1,[],false)
 if floor_hit.is_empty() or floor_hit.normal.y<.55:return Vector3.INF
 ground_normal=floor_hit.normal
 return floor_hit.position+Vector3.UP*GROUND_CLEARANCE

func step_destination(delta:float,tracking:bool)->Vector3:
 var travel=velocity*delta
 if tracking:
  var offset=target.global_position-global_position
  offset.y=0.0
  travel=offset.limit_length(travel.length())
  if not travel.is_zero_approx():velocity=travel.normalized()*velocity.length()
 return ground_point(global_position+travel,3.0)

func _physics_process(delta:float):
 if not is_instance_valid(hero) or not game.playing:retire();return
 if game.paused or game.transitioning:return
 var from=first_from if age==0 else global_position
 if from==Vector3.INF:end_flight();return
 age+=delta
 if age>=flight_life:end_flight();return
 var tracking=is_instance_valid(target) and not target.dead
 var end=step_destination(delta,tracking)
 if end==Vector3.INF:end_flight();return
 var wall=AttackChain.world_ray(self,from,end,1,terrain_exclude)
 if not wall.is_empty():end=wall.position
 if tracking:
  var contact=AttackChain.segment_contact(target,from,end,hit_radius)
  if not contact.is_empty() and AttackChain.clear_line(self,from,AttackChain.aim_point(target,end),terrain_exclude):
   var before=target.hp
   damage_spell_area(target,end,hit_radius,damage,velocity.normalized(),terrain_exclude)
   if is_instance_valid(target) and target.hp<before:
    finish_contact(contact.point)
    return
   end_flight();return
 if not wall.is_empty():end_flight();return
 global_position=end
 update_visual()

func finish_contact(point:Vector3):
 var profile=int(attack_ticket.get("crossgate_skill_audio_profile",34))
 if hero.ai_controlled:game.confirm_ally_impact(target,point,velocity.normalized(),0,true,profile,false,null,"cg_moon_hit")
 else:game.confirm_impact(target,point,velocity.normalized(),0,true,profile,false,null,true,"cg_moon_hit")
 retire()

func end_flight():
 retire()

func retire():
 if sparks!=null:sparks.emitting=false
 super.retire()

func update_visual():
 var forward=velocity.slide(ground_normal).normalized()
 var facing=Basis(ground_normal.cross(forward),ground_normal,forward)
 visual.global_rotation=facing.get_euler()
 var size_factor=skill_factor("size")
 var blade_scale=1.0
 if visual_growth<1.0:
  # Let the full crest unfold behind the tip as it clears the muzzle.
  var travelled=(global_position-first_from).dot(forward)
  visual_growth=clampf((travelled+.55)/(VISUAL_LENGTH*size_factor),.05,1.0)
  blade_scale=lerpf(.55,1.0,visual_growth)
  visual.set_instance_shader_parameter("growth",blade_scale)
 var spark_offset=BLADE_WIDTH*1.35*blade_scale*size_factor
 sparks.global_transform=Transform3D(facing,global_position-forward*spark_offset+ground_normal*.23)
