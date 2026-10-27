extends Node3D
## Original ROM geometry/pixels; placement follows the native encounter's scale.
const SAND_START=2.33
const SAND_END=4.1
const SAND_TEMPO=5.0
const SAND_LENGTH=250.0
const SAND_RADIUS=28.8
const SAND_ORIGIN=Vector3(0,5,15)
const SAND_INTERVAL=.2
const SIZE=preload("res://scripts/forest/forest_enemy_roles.gd").BOSS_SCALE
const DRILL=preload("res://assets/characters/recovered_skullpion/drill.glb")
const IMPACT=preload("res://assets/characters/recovered_skullpion/impact.glb")
const SAND=preload("res://assets/characters/recovered_skullpion/effects/sand.png")
const DUST=preload("res://assets/characters/recovered_skullpion/effects/dust.png")
const SHADER=preload("res://assets/characters/recovered_skullpion/effects/plume.gdshader")
var sand:MeshInstance3D
var drill:Node3D
var drill_animation:AnimationPlayer
var dust:CPUParticles3D
var impact:Node3D
var glow:MeshInstance3D
var age=100.0
var burst_scale=1.0
var burst_count=0
func _ready():
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_skullpion/effects/sources.json"))
 sand=MeshInstance3D.new();sand.mesh=plume_mesh(source.sand_mesh)
 var mat=ShaderMaterial.new();mat.shader=SHADER;mat.set_shader_parameter("atlas",SAND);sand.material_override=mat
 sand.hide();add_child(sand)
 var cross_section=MeshInstance3D.new();cross_section.mesh=sand.mesh;cross_section.material_override=mat
 cross_section.rotation.z=PI/2;sand.add_child(cross_section)
 drill=DRILL.instantiate();drill.scale*=2.4*SIZE;drill.hide();add_child(drill)
 drill_animation=drill.find_child("AnimationPlayer",true,false);drill_animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 impact=IMPACT.instantiate();impact.hide();add_child(impact)
 glow=MeshInstance3D.new();glow.mesh=glow_mesh(source.drill_glow)
 var light=StandardMaterial3D.new();light.vertex_color_use_as_albedo=true;light.vertex_color_is_srgb=true;light.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;light.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;light.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;light.cull_mode=BaseMaterial3D.CULL_DISABLED;light.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;glow.material_override=light;glow.hide();add_child(glow)
 dust=CPUParticles3D.new();dust.amount=48;dust.lifetime=.9;dust.one_shot=true;dust.explosiveness=.8;dust.local_coords=false;dust.emitting=false
 dust.direction=Vector3.UP;dust.spread=70;dust.gravity=Vector3(0,-10,0);dust.initial_velocity_min=3;dust.initial_velocity_max=10;dust.scale_amount_min=1;dust.scale_amount_max=3
 dust.anim_speed_min=1.2;dust.anim_speed_max=1.2
 var quad=QuadMesh.new();quad.size=Vector2.ONE*SIZE
 var dust_mat=StandardMaterial3D.new();dust_mat.albedo_texture=DUST;dust_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;dust_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;dust_mat.cull_mode=BaseMaterial3D.CULL_DISABLED;dust_mat.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;dust_mat.particles_anim_v_frames=12;dust_mat.particles_anim_loop=false
 quad.material=dust_mat;dust.mesh=quad;add_child(dust)
func plume_mesh(source:Dictionary)->ArrayMesh:
 var vertices=PackedVector3Array();var uv=PackedVector2Array()
 for i in source.positions.size():
  var p=source.positions[i];vertices.append(Vector3(p[0],p[1],p[2]))
  var t=source.uv[i];uv.append(Vector2((t[0]-.001953125)*4,(t[1]-.001953125)*2))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func glow_mesh(source:Dictionary)->ArrayMesh:
 var vertices=PackedVector3Array();var colors=PackedColorArray();var distances=[-1.0,-float(source.inner_fraction),0.0,float(source.inner_fraction),1.0]
 for face in 4:
  for corner in [0,1,2,1,3,2]:
   var i=face*4+corner
   vertices.append(Vector3(distances[source.x_indices[i]],-distances[source.y_indices[i]],0))
   var rgb:int=source.palette[source.color_indices[i]]
   colors.append(Color8(rgb&255,(rgb>>8)&255,(rgb>>16)&255))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func sync(action:int,time:float,point:Vector3,fit_path:bool=true):
 sand.visible=action==103 and time>=2.33 and time<4.1
 if sand.visible:
  sand.material_override.set_shader_parameter("frame",floori((time-SAND_START)*30)%8)
  if fit_path:
   var origin=global_transform*SAND_ORIGIN
   var direction=global_basis.z.normalized()
   var wall=AttackChain.world_ray(self,origin,origin+direction*SAND_LENGTH)
   sand_path(origin,direction,SAND_LENGTH if wall.is_empty() else origin.distance_to(wall.position),SAND_RADIUS)
 drill.visible=action==105 and time>=1.9 and time<4.3 and fposmod(time-1.9,.9)<.65
 if drill.visible:
  drill.global_position=point
  if drill_animation.assigned_animation!="Source__801e2458":drill_animation.play("Source__801e2458");drill_animation.pause()
  drill_animation.seek(fposmod(time-1.9,.9),true)
func sand_path(origin:Vector3,direction:Vector3,reach:float,radius:float):
 sand.global_transform=Transform3D(Basis.looking_at(-direction,Vector3.FORWARD if absf(direction.dot(Vector3.UP))>.999 else Vector3.UP).scaled(Vector3(radius/40,radius/40,maxf(.001,reach)/160)),origin)

static func advance_sand(time:float,step:float)->float:
 var windup=minf(step,maxf(0,SAND_START-time)/SAND_TEMPO)
 return time+windup*SAND_TEMPO+(step-windup)

func burst(point:Vector3,strength:float=1.0,flash:bool=false):
 burst_count+=1;age=0;burst_scale=strength
 dust.global_position=point+Vector3.UP*.3;dust.restart();dust.emitting=true
 glow.visible=flash;glow.global_position=point+Vector3.UP*4;glow.scale=Vector3.ONE*4*SIZE*strength;glow.transparency=0
 impact.visible=flash;impact.global_position=point;impact.scale=Vector3.ONE*SIZE*.025*strength
func tick(delta:float):
 age+=delta
 if age<.65:
  impact.scale=Vector3.ONE*SIZE*(.025+age*.06)*burst_scale
  glow.transparency=clampf(age/.65,0,1)
 else:glow.hide();impact.hide()
func stop():
 sand.hide();drill.hide();glow.hide();impact.hide();dust.emitting=false
