extends "res://scripts/character_projectile.gd"
## Recovered Blue Cross Gate sword wave on Kojiro's ground-wave fold.
const ATLAS=preload("res://assets/characters/crossgate/kazi/moon-waves-relief.png")
const Wind=preload("res://scripts/kojiro_projectile.gd")
const TICK=1.0/60.0
const PIXEL=preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT/83.0
const SPEED=10.0*PIXEL/TICK
const GROUND_CLEARANCE=.08
const VISUAL_SCALE=Vector3(.72,.34,1.0)*preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER/78.0
const VISUAL_LENGTH=78.0*VISUAL_SCALE.z
const CREST_SUBDIVISIONS=6
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
  shock_material.set_shader_parameter("atlas",ATLAS)
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
 var vertices:PackedVector3Array=Wind.prepared_wind_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for start in range(0,vertices.size(),3):
  var face=vertices.slice(start,start+3)
  var pixels=PackedVector2Array()
  for point in face:
   pixels.append(Vector2(72.5,25.5) if point.z>0 else (Vector2(72.5,76.0) if point.y>0 else Vector2(90.0,103.0)))
  for x in CREST_SUBDIVISIONS:
   for y in CREST_SUBDIVISIONS-x:
    var cell=Vector2(x,y)
    for vertex in [cell,cell+Vector2.RIGHT,cell+Vector2.DOWN]:
     add_crest_vertex(surface,face,pixels,vertex/CREST_SUBDIVISIONS)
    if x+y+2<=CREST_SUBDIVISIONS:
     for vertex in [cell+Vector2.RIGHT,cell+Vector2.ONE,cell+Vector2.DOWN]:
      add_crest_vertex(surface,face,pixels,vertex/CREST_SUBDIVISIONS)
 surface.index()
 surface.generate_normals()
 return surface.commit()

static func add_crest_vertex(surface:SurfaceTool,face:PackedVector3Array,pixels:PackedVector2Array,weights:Vector2):
 var origin_weight=1.0-weights.x-weights.y
 var point=face[0]*origin_weight+face[1]*weights.x+face[2]*weights.y
 # Round the two faces while retaining the authored leading vertex and edges.
 point.y+=756.0*origin_weight*weights.x*weights.y
 point.z-=52.0
 var pixel=pixels[0]*origin_weight+pixels[1]*weights.x+pixels[2]*weights.y
 surface.set_uv(pixel/Vector2(144.0,128.0))
 surface.add_vertex(point)

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
 if visual_growth<1.0:
  # Let the full crest unfold behind the tip as it clears the muzzle.
  var travelled=(global_position-first_from).dot(forward)
  visual_growth=clampf((travelled+.55)/(VISUAL_LENGTH*skill_factor("size")),.05,1.0)
  visual.set_instance_shader_parameter("growth",visual_growth)
 sparks.global_transform=Transform3D(facing,global_position-forward*(VISUAL_LENGTH*.82*visual_growth*skill_factor("size"))+ground_normal*.23)
