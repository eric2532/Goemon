class_name RecoveredGoemonChargeVFX
extends Node3D
## Original selector11 charge particles. Caller owns charge time and cancellation.
const ROOT="res://assets/characters/recovered_goemon/vfx/charge/"
const SOURCE_SHADER=preload("res://assets/characters/recovered_goemon/vfx/charge/charge_sprite.gdshader")
static var _source:Dictionary={}
var source_scale:float=.016
var source_offset=Vector3.ZERO
var particle_roots:Array[Node3D]=[]
var particle_parts:Array=[]
var impact_mesh:MeshInstance3D
var impact_age:float=0.0

static func data()->Dictionary:
 if _source.is_empty():_source=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"charge.json"))
 return _source

static func create(parent:Node3D,scale_:float=.016,offset_:Vector3=Vector3.ZERO)->RecoveredGoemonChargeVFX:
 var effect=RecoveredGoemonChargeVFX.new()
 effect.name="OriginalGoemonChargeParticles"
 effect.source_scale=scale_;effect.source_offset=offset_
 effect.set_meta("native_selector",0x11)
 parent.add_child(effect)
 for variant in range(3):
  var root_=Node3D.new();root_.name="NativeCharge_%d"%variant;effect.add_child(root_)
  effect.particle_roots.append(root_)
  var meshes:Array=[]
  for pointer in data().clips[variant].parts:
   var mesh=effect._part(data().parts[pointer])
   root_.add_child(mesh);meshes.append(mesh)
  effect.particle_parts.append(meshes)
 effect.set_charge_time(0)
 return effect

static func impact(parent:Node3D,position_:Vector3,scale_:float=.016)->RecoveredGoemonChargeVFX:
 var effect=RecoveredGoemonChargeVFX.new()
 effect.name="OriginalChargedCoinImpact"
 effect.source_scale=scale_
 var part:Dictionary=data().impact
 effect.impact_mesh=effect._part(part)
 effect.impact_mesh.scale=Vector3.ONE*float(part.scale)*scale_
 var material=effect.impact_mesh.mesh.surface_get_material(0) as ShaderMaterial
 material.set_shader_parameter("source_size",Vector2(64,32))
 material.set_shader_parameter("source_texture",load(ROOT+String(part.frames[0].file)))
 material.set_shader_parameter("use_environment_combiner",false)
 effect.add_child(effect.impact_mesh)
 parent.add_child(effect);effect.global_position=position_
 return effect

func _part(part:Dictionary)->MeshInstance3D:
 var result=MeshInstance3D.new();result.name="Source_"+String(part.display_list_pointer)
 var positions=PackedVector3Array();var uvs=PackedVector2Array()
 for face in part.faces:
  for index in face:
   var v:Dictionary=part.vertices[index]
   positions.append(Vector3(v.position[0],v.position[1],v.position[2]))
   uvs.append(Vector2(float(v.uv_raw[0])*float(part.uv_scale[0])/32.0/float(part.texture_size[0]),float(v.uv_raw[1])*float(part.uv_scale[1])/32.0/float(part.texture_size[1])))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_TEX_UV]=uvs
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material=ShaderMaterial.new();material.shader=SOURCE_SHADER
 material.set_shader_parameter("source_texture",load(ROOT+"charge_source_801f.png"))
 material.set_shader_parameter("source_size",Vector2(32,64))
 material.set_shader_parameter("use_environment_combiner",true)
 material.set_shader_parameter("billboard",bool(part.get("billboard",true)))
 material.set_shader_parameter("primitive_color",Vector3(255,245,184)/255.0)
 material.set_shader_parameter("environment_color",Vector3(255,250,36)/255.0)
 mesh.surface_set_material(0,material);result.mesh=mesh
 return result

func set_charge_time(held_seconds:float)->void:
 visible=held_seconds>=.5
 if not visible:return
 var tick=maxi(0,int(floor((held_seconds-.5)*30.0+.00001)))
 for variant in range(3):
  var clip:Dictionary=data().clips[variant]
  var frame=posmod(tick,22)
  var full_ticks=maxi(0,tick-45)
  var spin:int=[28,8,16][variant]
  var native_scale=minf(1.0,float(tick)*.01)
  var root_=particle_roots[variant]
  root_.position=Vector3(0,50,0)*source_scale+source_offset
  root_.basis=Basis(Vector3.UP,TAU*float(posmod(full_ticks*spin,1024))/1024.0).scaled(Vector3.ONE*native_scale*source_scale)
  for i in range(clip.parts.size()):
   var mesh:MeshInstance3D=particle_parts[variant][i]
   var v:Array=clip.frames[frame][i]
   var basis_=Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8]))
   mesh.visible=absf(basis_.determinant())>.00000001
   mesh.transform=Transform3D(basis_,Vector3(v[9],v[10],v[11]))

func _process(delta:float)->void:
 if not is_instance_valid(impact_mesh):return
 impact_age+=delta
 var tick=int(floor(impact_age*30.0))
 var source:Dictionary=data().impact
 if tick>=int(source.lifetime_ticks):
  queue_free();return
 var frame=mini(source.frames.size()-1,int(tick/int(source.frame_ticks)))
 var material=impact_mesh.mesh.surface_get_material(0) as ShaderMaterial
 material.set_shader_parameter("source_texture",load(ROOT+String(source.frames[frame].file)))
 material.set_shader_parameter("opacity",maxf(0.0,255.0-16.0*float(tick))/255.0)
