extends Node3D
## Retail Rotation actor0x19 variants0/1 and actor0x1D. Geometry, RGB and
## fixed12 state constants are recovered; PS1 lighting is a host approximation.
static var sources:Dictionary={}
var vortices:Array[MeshInstance3D]=[]
var states:Array=[]
var shock_ring:MeshInstance3D
var source_clock=0.0
var ring_rgb=Vector3.ZERO
var ring_scale=4096
var ring_speed=1792
var ring_growing=true
var spawn_transform=Transform3D.IDENTITY
static func data()->Dictionary:
 if sources.is_empty():sources=JSON.parse_string(FileAccess.get_file_as_string('res://assets/characters/recovered_musashi/effects/special_sources.json')).rotation
 return sources
func _ready():top_level=true;global_transform=Transform3D.IDENTITY
func clear():
 for instance in vortices:instance.free()
 vortices.clear();states.clear()
 if is_instance_valid(shock_ring):shock_ring.free()
 shock_ring=null;source_clock=0
func _material()->ShaderMaterial:
 var result=ShaderMaterial.new();result.shader=preload('res://scripts/recovered_musashi_effect.gdshader')
 return result
func spawn(transform:Transform3D):
 clear();spawn_transform=transform
 var anchor=data().get("spawn_anchor_source",[0,-6,-120])
 spawn_transform.origin=transform*(Vector3(anchor[0],-anchor[1],-anchor[2])*.01)
 spawn_transform.basis=Basis.IDENTITY.scaled(transform.basis.get_scale())
 var native=data().vortex_mesh
 for variant in 2:
  var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  # Source contains both sides as separate triangles. Keep only their front
  # faces in the shader to avoid double-addition of the original back faces.
  for triangle in native.triangles.size():
   for corner in 3:
    var rgb=native.triangle_rgb8[triangle][corner];surface.set_color(Color(rgb[0]/255.0,rgb[1]/255.0,rgb[2]/255.0))
    var point=native.vertices[int(native.triangles[triangle][corner])]
    surface.add_vertex(Vector3(point[0],-point[1],-point[2])*.01)
  var instance=MeshInstance3D.new();instance.mesh=surface.commit()
  instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var material=_material();material.shader=preload('res://scripts/recovered_musashi_vortex.gdshader');instance.material_override=material
  add_child(instance);vortices.append(instance)
  states.append({'size':Vector3(4096,0,4096),'speed':0,'yaw':0,'fading':false,'bias':128})
  _pose(variant)
 ring_rgb=Vector3(240,240,192);ring_scale=4096;ring_speed=1792;ring_growing=true
 shock_ring=MeshInstance3D.new();shock_ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 shock_ring.material_override=_material();add_child(shock_ring);_draw_ring()
func advance(delta:float):
 if vortices.is_empty() and not is_instance_valid(shock_ring):return
 source_clock+=delta*30
 while source_clock+.000001>=1:source_clock-=1;source_tick()
func source_tick():
 var expired=false
 for variant in vortices.size():
  var state=states[variant];var spec=data().actors[variant]
  if not state.fading:
   state.speed+=int(spec.acceleration);state.size.y+=state.speed
   state.size.x+=int(spec.growth.xz_increment);state.size.z=state.size.x
   state.yaw+=int(spec.growth.yaw_increment)
   if state.size.y>int(spec.growth.transitions_after_y_exceeds):state.fading=true
  else:
   state.size.x+=int(spec.fade.xz_increment);state.size.z=state.size.x
   state.yaw+=int(spec.fade.yaw_increment)
   if variant==0:
    state.bias-=8
    if state.bias< -128:expired=true
   else:state.size.y=maxf(0,state.size.y-512)
  _pose(variant)
 if expired:
  for instance in vortices:instance.free()
  vortices.clear();states.clear()
 if is_instance_valid(shock_ring):
  ring_rgb=(ring_rgb-Vector3.ONE*16).max(Vector3.ZERO)
  if ring_rgb==Vector3.ZERO:shock_ring.free();shock_ring=null
  else:
   if ring_growing:
    ring_speed-=96
    if ring_speed<0:ring_growing=false
    else:ring_scale+=ring_speed
   else:ring_scale+=256
   _draw_ring()
func _pose(index:int):
 var state=states[index]
 var basis=spawn_transform.basis*Basis(Vector3.UP,-float(state.yaw)*TAU/4096.0)
 # Original initializer is flat; growth begins on its next source update.
 vortices[index].transform=Transform3D(basis,spawn_transform.origin)
 vortices[index].scale*=state.size/4096.0
 vortices[index].material_override.set_shader_parameter('native_bias',float(states[0].bias)/128.0)
func _draw_ring():
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var spec=data().shock_ring;var fraction=float(spec.inner_fraction_fixed12)/4096.0
 var color=Color(ring_rgb.x/255,ring_rgb.y/255,ring_rgb.z/255)
 for i in 12:
  var a=spec.outer_points_source[i];var b=spec.outer_points_source[(i+1)%12]
  var outer_a=Vector3(a[0],0,-a[1])*.01;var outer_b=Vector3(b[0],0,-b[1])*.01
  var points=[outer_a,outer_a*fraction,outer_b,outer_b*fraction]
  for index in [0,1,2,1,3,2]:
   surface.set_color(Color.BLACK if index in [0,2] else color);surface.add_vertex(points[index])
 shock_ring.mesh=surface.commit()
 shock_ring.transform=spawn_transform
 shock_ring.position=spawn_transform*(Vector3(0,64,0)*.01)
 shock_ring.scale*=Vector3(ring_scale/4096.0,1,ring_scale/4096.0)
