extends Node3D
## Native contrails: persistent stateful points and textured camera-facing ribbons.
## `scale` multiplies converted lengths; optional definition._density is the
## native attachment function value used only by authored scale flags.
const Math=preload("res://scripts/halo_particle_math.gd")
const HALO_METRES=3.048
const MAX_TRAILS=128
const MAX_POINTS_PER_TRAIL=256
const MAX_TOTAL_POINTS=8192
var data
var particles:Node3D
var camera_override:Camera3D
var layer=1
var clock=0.0
var trails:Dictionary={}
var groups:Dictionary={}
var next_streak_id=-1
var shader_alpha:Shader
var shader_add:Shader

func configure(data_helper,particle_parent:Node3D,camera:Camera3D=null,render_layer:int=1):
 clear()
 data=data_helper;particles=particle_parent;camera_override=camera;layer=render_layer

func start(id:int,definition:Dictionary,at:Vector3,direction:Vector3,scale:float=1.0):
 if definition.get("point_states",[]).is_empty() or data==null or not is_instance_valid(particles):return
 if not trails.has(id) and trails.size()>=MAX_TRAILS:trails.erase(trails.keys()[0])
 var trail={"id":id,"definition":definition,"points":[],"active":true,"at":at,"direction":direction.normalized(),"scale":maxf(0.0,scale),"density":float(definition.get("_density",1.0)),"pending":0.0,"last_time":clock,"flight":{}}
 trails[id]=trail
 _add_point(trail,at,direction,Vector3.ZERO,clock)

func move(id:int,at:Vector3,direction:Vector3,delta:float):
 if not trails.has(id):return
 var trail:Dictionary=trails[id]
 if not trail.active:return
 var previous:Vector3=trail.at
 trail.at=at;trail.direction=direction.normalized();trail.last_time=clock+maxf(0.0,delta)
 if delta<=0.0:return
 var creation:Dictionary=trail.definition.get("point_creation",{})
 var rate=float(creation.get("generation_rate",0.0))
 if int(trail.definition.get("scale_flags",0))&1:rate*=trail.density
 if rate<=0.0:return
 var pending=float(trail.pending)
 var count=int(floor((pending+delta)*rate+.0000001))
 trail.pending=pending+delta-count/rate
 var owner_velocity=(at-previous)/delta
 # The pool bound limits overload work while keeping the newest segment.
 var first=maxi(0,count-MAX_POINTS_PER_TRAIL)
 for index in range(first,count):
  var offset=(index+1)/rate-pending
  var fraction=clampf(offset/delta,0.0,1.0)
  _add_point(trail,previous.lerp(at,fraction),direction,owner_velocity,clock+offset)

func stop(id:int):
 if not trails.has(id):return
 var trail:Dictionary=trails[id]
 if trail.active:
  var points:Array=trail.points
  if not points.is_empty() and points[-1].position.distance_squared_to(trail.at)>.000001:
   _add_point(trail,trail.at,trail.direction,Vector3.ZERO,trail.last_time)
 trail.active=false;trail.flight={}

func streak(definition:Dictionary,from:Vector3,to:Vector3,scale:float=1.0):
 if from.is_equal_approx(to):return
 var speed=float(definition.get("_projectile_speed",0.0))
 if speed<=0.0 and data!=null:
  var projectile:Dictionary=data.resolve("weapons\\assault rifle\\bullet","projectile")
  speed=float(projectile.get("proj_attrs",{}).get("physics",{}).get("initial_velocity",0.0))
 if speed<=0.0:return
 var id=next_streak_id;next_streak_id-=1
 var direction=(to-from).normalized()
 start(id,definition,from,direction,scale)
 if trails.has(id):trails[id].flight={"from":from,"to":to,"elapsed":0.0,"duration":from.distance_to(to)/(speed*HALO_METRES*maxf(scale,.000001))}

func tick(delta:float,submit:bool=true):
 delta=maxf(0.0,delta)
 for trail in trails.values():
  var flight:Dictionary=trail.flight
  if flight.is_empty():continue
  var remaining=maxf(0.0,float(flight.duration)-float(flight.elapsed))
  var step=minf(delta,remaining)
  flight.elapsed+=step
  var fraction=clampf(flight.elapsed/flight.duration,0.0,1.0)
  move(trail.id,flight.from.lerp(flight.to,fraction),trail.direction,step)
  if fraction>=1.0:stop(trail.id)
 clock+=delta
 for id in trails.keys():
  var trail:Dictionary=trails[id]
  for point in trail.points:
   _advance_point(trail,point,delta)
  var points:Array=trail.points
  # Preserve one expired endpoint next to a living point, as the native linked
  # trail does. A lone active endpoint is invisible but connects the next birth
  # when rendering faster than the native point-generation interval.
  while points.size()>1 and points[0].expired and points[1].expired:points.pop_front()
  if points.size()==1 and points[0].expired and not trail.active:points.clear()
  if points.is_empty() and not trail.active:trails.erase(id)
 if submit:_render()

func clear():
 trails.clear();clock=0.0
 for group in groups.values():
  var mesh:MeshInstance3D=group.node
  if is_instance_valid(mesh):
   mesh.hide();mesh.queue_free()
 groups.clear()

func live_count()->int:return trails.size()

func _add_point(trail:Dictionary,position:Vector3,direction:Vector3,owner_velocity:Vector3,birth:float):
 var points:Array=trail.points
 var creation:Dictionary=trail.definition.get("point_creation",{})
 var density=float(trail.density)
 var flags=int(trail.definition.get("scale_flags",0))
 var speed=_scaled_range(creation.get("velocity",{}),density,flags,1)
 var cone=float(creation.get("velocity_cone_angle",0.0))*(density if flags&8 else 1.0)
 var inherited=float(creation.get("inherited_velocity_fraction",0.0))*(density if flags&16 else 1.0)
 var velocity=_cone_direction(direction,cone)*speed*HALO_METRES*trail.scale+owner_velocity*inherited
 var plan:Array=[]
 var start_time=0.0
 var states:Array=trail.definition.get("point_states",[])
 for index in states.size():
  var state:Dictionary=states[index]
  var state_flags=int(state.get("scale_flags",0))
  var hold=maxf(0.0,_scaled_range(state.get("state_duration",{}),density,state_flags,0))
  var transition=maxf(0.0,_scaled_range(state.get("state_transition_duration",{}),density,state_flags,2)) if index+1<states.size() else 0.0
  var width=float(state.get("width",0.0))*(density if state_flags&16 else 1.0)
  var tint_factor=density if state_flags&32 else 1.0
  var tint=Math.color(state.get("color_lower_bound",{})).lerp(Math.color(state.get("color_upper_bound",{})),tint_factor)
  plan.append({"data":state,"start":start_time,"hold":hold,"transition":transition,"end":start_time+hold+transition,"width":width,"color":tint})
  start_time+=hold+transition
 var point={"position":position,"velocity":velocity,"born":birth,"updated":birth,"plan":plan,"width":0.0,"color":Color.WHITE,"expired":false}
 points.append(point)
 if points.size()>MAX_POINTS_PER_TRAIL:points.pop_front()
 _advance_point(trail,point,0.0)

func _advance_point(trail:Dictionary,point:Dictionary,_delta:float):
 var age=maxf(0.0,clock-float(point.born))
 var plan:Array=point.plan
 if plan.is_empty():point.expired=true;return
 var state:Dictionary=plan[-1]
 var state_index=plan.size()-1
 for index in plan.size():
  if age<plan[index].end:
   state=plan[index];state_index=index;break
 point.expired=age>=float(plan[-1].end)
 point.width=state.width;point.color=state.color
 var transition_start=float(state.start)+float(state.hold)
 if age>=transition_start and state.transition>0.0 and state_index+1<plan.size():
  var fraction=clampf((age-transition_start)/state.transition,0.0,1.0)
  point.width=lerpf(state.width,plan[state_index+1].width,fraction)
  point.color=state.color.lerp(plan[state_index+1].color,fraction)
 var dt=maxf(0.0,clock-maxf(float(point.updated),float(point.born)))
 if dt>0.0 and not point.expired:
  var physics:Dictionary=data.resolve(state.data.get("physics",{}),"point_physics")
  if not physics.is_empty():
   var scale=maxf(.000001,trail.scale)
   point.velocity=Math.physics_velocity(point.velocity/scale,maxf(0.0,float(state.data.get("width",0.0)))*.5,physics,dt)*scale
  point.position+=point.velocity*dt
 point.updated=maxf(float(point.updated),clock)

func _scaled_range(bounds:Variant,density:float,flags:int,bit:int)->float:
 if not bounds is Dictionary:return Math.sample(bounds)
 var lower=float(bounds.get("from",0.0))
 var span=float(bounds.get("to",lower))-lower
 if flags&(1<<bit):lower*=density
 if flags&(1<<(bit+1)):span*=density
 return lower+span*randf()

func _cone_direction(direction:Vector3,angle:float)->Vector3:
 var forward=direction.normalized() if direction.length_squared()>.000001 else Vector3.FORWARD
 if angle<=0.0:return forward
 var side=forward.cross(Vector3.UP)
 if side.length_squared()<.000001:side=forward.cross(Vector3.RIGHT)
 side=side.normalized()
 var up=side.cross(forward).normalized()
 var cosine=lerpf(cos(clampf(angle,0.0,PI)),1.0,randf())
 var sine=sqrt(maxf(0.0,1.0-cosine*cosine))
 var rotation=randf()*TAU
 return forward*cosine+(side*cos(rotation)+up*sin(rotation))*sine

func _render():
 for group in groups.values():group.node.hide();group.vertices=PackedVector3Array();group.colors=PackedColorArray();group.uvs=PackedVector2Array()
 var camera=camera_override
 if not is_instance_valid(camera) and is_inside_tree():camera=get_viewport().get_camera_3d()
 var eye=camera.global_position if is_instance_valid(camera) else Vector3(0,0,1000)
 var total=0
 for trail in trails.values():
  var points:Array=trail.points
  if points.size()<2:continue
  var rendering:Dictionary=trail.definition.get("rendering",{})
  var animation=float(rendering.get("animation_rate",0.0))
  if int(trail.definition.get("scale_flags",0))&32:animation*=trail.density
  var frame:Dictionary=data.bitmap_frame(rendering.get("bitmap",{}),int(rendering.get("first_sequence_index",0)),clock*animation)
  if frame.is_empty():continue
  var group=_group(frame,str(rendering.get("framebuffer_blend_function","alpha_blend")))
  var repeats_u=float(rendering.get("texture_repeats_u",1.0))
  var repeats_v=float(rendering.get("texture_repeats_v",1.0))
  var scale_flags=int(trail.definition.get("scale_flags",0))
  if scale_flags&64:repeats_u*=trail.density
  if scale_flags&128:repeats_v*=trail.density
  var offset_u=-clock*float(rendering.get("texture_animation_u",0.0))*(trail.density if scale_flags&256 else 1.0)
  var offset_v=clock*float(rendering.get("texture_animation_v",0.0))*(trail.density if scale_flags&512 else 1.0)
  var previous:Dictionary={}
  for index in points.size():
   if total>=MAX_TOTAL_POINTS:break
   var point:Dictionary=points[index]
   var tangent:Vector3=point.position-points[index-1].position if index>0 else points[1].position-point.position
   if tangent.length_squared()<.000001:tangent=trail.direction
   var side=tangent.cross(eye-point.position).normalized()
   if side.length_squared()<.000001:side=Vector3.RIGHT
   var half_width=float(point.width)*HALO_METRES*trail.scale*.5
   var tint:Color=point.color
   var fade_mode=str(rendering.get("framebuffer_fade_mode","none"))
   if fade_mode!="none":
    var normal=side.cross(tangent).normalized()
    var orientation=absf(normal.dot((eye-point.position).normalized()))
    if int(trail.definition.get("flags",0))&64:orientation=Math.blend_ease("very_early",orientation)
    if fade_mode=="fade_when_parallel":orientation=1.0-orientation
    tint.a*=orientation
   var flags=int(trail.definition.get("flags",0))
   if index==0 and flags&2==0:tint.a=0.0
   if index==points.size()-1 and flags&1==0:tint.a=0.0
   var u=(points.size()-1-index)*-repeats_u+offset_u
   var row={"left":point.position-side*half_width,"right":point.position+side*half_width,"color":tint,"u":u}
   if not previous.is_empty():
    _vertex(group,previous.left,Vector2(previous.u,offset_v+repeats_v),previous.color)
    _vertex(group,previous.right,Vector2(previous.u,offset_v),previous.color)
    _vertex(group,row.left,Vector2(u,offset_v+repeats_v),tint)
    _vertex(group,row.left,Vector2(u,offset_v+repeats_v),tint)
    _vertex(group,previous.right,Vector2(previous.u,offset_v),previous.color)
    _vertex(group,row.right,Vector2(u,offset_v),tint)
   previous=row;total+=1
 for group in groups.values():
  if group.vertices.is_empty():continue
  var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=group.vertices;arrays[Mesh.ARRAY_COLOR]=group.colors;arrays[Mesh.ARRAY_TEX_UV]=group.uvs
  var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  group.node.mesh=mesh;group.node.show()

func _vertex(group:Dictionary,position:Vector3,uv:Vector2,tint:Color):
 group.vertices.append(position);group.uvs.append(uv);group.colors.append(tint)

func _group(frame:Dictionary,blend:String)->Dictionary:
 var rect:Rect2=frame.get("rect",Rect2(0,0,1,1))
 var key=str(frame.texture.get_rid().get_id())+str(rect)+blend
 if groups.has(key):return groups[key]
 var node=MeshInstance3D.new();node.name="HaloNativeContrail_%d"%groups.size();node.layers=layer;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 particles.add_child(node);node.top_level=true;node.global_transform=Transform3D.IDENTITY
 var shader:Shader
 if blend=="add":
  if shader_add==null:shader_add=_shader(true)
  shader=shader_add
 else:
  if shader_alpha==null:shader_alpha=_shader(false)
  shader=shader_alpha
 var material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("atlas",frame.texture);material.set_shader_parameter("uv_rect",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y));node.material_override=material
 var group={"node":node,"vertices":PackedVector3Array(),"colors":PackedColorArray(),"uvs":PackedVector2Array()}
 groups[key]=group;return group

func _shader(additive:bool)->Shader:
 var shader=Shader.new()
 shader.code="shader_type spatial;\nrender_mode unshaded,cull_disabled,depth_draw_never,fog_disabled,"+("blend_add" if additive else "blend_mix")+";\nuniform sampler2D atlas : source_color,filter_linear_mipmap,repeat_enable;\nuniform vec4 uv_rect=vec4(0.0,0.0,1.0,1.0);\nvoid fragment(){vec2 uv=uv_rect.xy+fract(UV)*uv_rect.zw;vec4 texel=texture(atlas,uv);ALBEDO=texel.rgb*COLOR.rgb;ALPHA=texel.a*COLOR.a;}"
 return shader
