extends Node
## Damage-effect presentation owns three bounded native channels. Camera pose is
## composed after ActionCamera runs; weapon recoil and input angles stay intact.
const Math=preload("res://scripts/halo_particle_math.gd")
const METRES=3.048
var game:Node
var hero:Node3D
var overlay:ColorRect
var flash_layer:CanvasLayer
var flash_intensity=0.0
var clock=0.0
var _flash:Dictionary={}
var _shake:Dictionary={}
var _impulse:Dictionary={}
var _offset=Transform3D.IDENTITY
var _applied_camera:Camera3D
var _base=Transform3D.IDENTITY
var _last_applied=Transform3D.IDENTITY
var _applied=false
var _serial=0
var _variable_wave=PackedFloat32Array()
var _rng=RandomNumberGenerator.new()

func configure(owner_game:Node,owner_hero:Node3D):
 clear();game=owner_game;hero=owner_hero;process_priority=1000
 if not is_instance_valid(overlay):
  flash_layer=CanvasLayer.new();flash_layer.name="HaloNativeDamageFlash";flash_layer.layer=20;add_child(flash_layer)
  overlay=ColorRect.new();overlay.name="NativeScreenFlash";overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;flash_layer.add_child(overlay)
  overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  var shader=Shader.new()
  shader.code="shader_type canvas_item;render_mode unshaded,blend_disabled;uniform sampler2D screen_image:hint_screen_texture,filter_nearest;uniform vec4 tint:source_color=vec4(1.0);uniform float strength=0.0;uniform int flash_type=1;void fragment(){vec3 base=texture(screen_image,SCREEN_UV).rgb;vec3 flash=tint.rgb*strength;vec3 out_rgb=base;if(flash_type==1){out_rgb=base*(1.0-tint.a*strength)+flash;}else if(flash_type==2){out_rgb=base-flash;}else if(flash_type==3){out_rgb=max(base,flash);}else if(flash_type==4){out_rgb=min(base,vec3(1.0)-flash);}else if(flash_type==5){out_rgb=mix(base,vec3(1.0)-base,flash);}else if(flash_type==6){out_rgb=base*(vec3(1.0)-(vec3(1.0)-tint.rgb)*strength);}COLOR=vec4(clamp(out_rgb,vec3(0.0),vec3(1.0)),1.0);}"
  var material=ShaderMaterial.new();material.shader=shader;overlay.material=material
 overlay.hide()

func emit(definition:Dictionary,at:Vector3,scale:float=1.0):
 if not is_instance_valid(hero):return
 var radius:Dictionary=definition.get("radius",{})
 var inner=maxf(0.0,float(radius.get("from",0.0)))*METRES*scale
 var outer=maxf(0.0,float(radius.get("to",0.0)))*METRES*scale
 var distance=hero.global_position.distance_to(at)
 var strength=1.0
 if outer>0.0:
  if distance>=outer:return
  if outer>inner:strength=clampf((outer-distance)/(outer-inner),0.0,1.0)
  if int(definition.get("flags",0))&1:strength=1.0
 elif not definition.get("_local",false) and distance>.01:return
 var cutoff=float(definition.get("cutoff_scale",0.0))
 strength=clampf(cutoff+(1.0-cutoff)*strength,0.0,1.0)
 if strength<=0.0:return
 _remove_pose()
 _serial+=1;_rng.seed=_serial*1009+7919
 var flash:Dictionary=definition.get("screen_flash",{})
 var flash_type=str(flash.get("type","none"))
 if flash_type!="none":
  var priority=_priority(str(flash.get("priority","low")))
  var duration=maxf(0.0,float(flash.get("duration",0.0)))
  if _flash.is_empty() or not (_flash.priority>priority and _remaining(_flash)>duration):
   _flash={"data":flash,"age":0.0,"duration":duration,"presented":false,"priority":priority,"strength":minf(strength,float(flash.get("maximum_intensity",1.0)))}
 var shaking:Dictionary=definition.get("camera_shaking",{})
 if float(shaking.get("random_translation",0.0))!=0.0 or float(shaking.get("random_rotation",0.0))!=0.0:
  var duration=maxf(0.0,float(shaking.get("duration",0.0)))
  if _shake.is_empty() or _remaining(_shake)<duration or strength>_shake.strength:
   _shake={"data":shaking,"age":0.0,"duration":duration,"presented":false,"strength":strength,"scale":scale,"seed":_serial}
 var impulse:Dictionary=definition.get("temporary_camera_impulse",{})
 if float(impulse.get("rotation",0.0))!=0.0 or float(impulse.get("pushback",0.0))!=0.0 or _has_jitter(impulse):
  var duration=maxf(0.0,float(impulse.get("duration",0.0)))
  if _impulse.is_empty() or _impulse.age>0.0 or strength>_impulse.strength or _remaining(_impulse)<duration:
   var camera=_camera()
   var direction=hero.global_position-at;direction.y=0.0
   if direction.is_zero_approx():direction=camera.global_basis.z if is_instance_valid(camera) else Vector3.BACK
   direction=direction.normalized()
   var jitter=direction.cross(Vector3.UP).normalized()
   jitter=jitter.rotated(direction,_rng.randf()*TAU)*_sample_jitter(impulse)
   _impulse={"data":impulse,"age":0.0,"duration":duration,"presented":false,"strength":strength,"scale":scale,"direction":direction,"jitter":jitter}
 _evaluate()

func tick(delta:float):
 _remove_pose();clock+=maxf(0.0,delta)
 _flash=_advance(_flash,delta);_shake=_advance(_shake,delta);_impulse=_advance(_impulse,delta)
 _evaluate()

func _process(_delta:float):
 _remove_pose()
 if live_count()==0:return
 var camera=_camera()
 if not is_instance_valid(camera):return
 _base=camera.global_transform
 _last_applied=_base*_offset
 camera.global_transform=_last_applied;_applied_camera=camera;_applied=true
 for channel in [_flash,_shake,_impulse]:
  if not channel.is_empty():channel.presented=true

func clear():
 _remove_pose();_flash.clear();_shake.clear();_impulse.clear();_offset=Transform3D.IDENTITY;flash_intensity=0.0
 if is_instance_valid(overlay):overlay.hide()

func _exit_tree():clear()
func live_count()->int:return int(not _flash.is_empty())+int(not _shake.is_empty())+int(not _impulse.is_empty())

func _camera()->Camera3D:
 if not is_instance_valid(game):return null
 var rig=game.get("camera_rig")
 return rig.get("camera") as Camera3D if is_instance_valid(rig) else null

func _remove_pose():
 if _applied and is_instance_valid(_applied_camera) and _applied_camera.is_inside_tree() and _applied_camera.global_transform.is_equal_approx(_last_applied):
  _applied_camera.global_transform=_base
 _applied=false

func _advance(channel:Dictionary,delta:float)->Dictionary:
 if channel.is_empty():return channel
 if channel.presented:
  channel.age+=maxf(0.0,delta)
  if channel.duration==0.0 or channel.age>=channel.duration:return {}
 return channel

func _remaining(channel:Dictionary)->float:return maxf(0.0,float(channel.duration)-float(channel.age))
func _priority(priority:String)->int:return ["low","medium","high"].find(priority)
func _has_jitter(impulse:Dictionary)->bool:
 var bounds:Dictionary=impulse.get("jitter",{})
 return float(bounds.get("from",0.0))!=0.0 or float(bounds.get("to",0.0))!=0.0
func _sample_jitter(impulse:Dictionary)->float:
 var bounds:Dictionary=impulse.get("jitter",{})
 return _rng.randf_range(float(bounds.get("from",0.0)),float(bounds.get("to",0.0)))
func _envelope(channel:Dictionary)->float:
 var remaining=1.0-channel.age/channel.duration if channel.duration>0.0 else 1.0
 return Math.blend_ease(str(channel.data.get("fade_function","linear")),remaining)*float(channel.strength)

func _evaluate():
 _offset=Transform3D.IDENTITY;flash_intensity=0.0
 var camera=_camera()
 var basis=camera.global_basis.orthonormalized() if is_instance_valid(camera) else Basis.IDENTITY
 if not _impulse.is_empty():
  var channel=_impulse;var value=_envelope(channel)
  var axis=Vector3.UP.cross(channel.direction).normalized()
  var local_axis=basis.inverse()*axis
  if not local_axis.is_zero_approx():_offset.basis=Basis(local_axis,float(channel.data.get("rotation",0.0))*value)
  var translation:Vector3=(channel.direction*float(channel.data.get("pushback",0.0))+channel.jitter)*METRES*channel.scale*value
  _offset.origin=basis.inverse()*translation
 if not _shake.is_empty():
  var channel=_shake;var value=_envelope(channel)
  var period=float(channel.data.get("wobble_function_period",1.0))
  var phase=channel.age/period if period>0.0 else 0.0
  var weight=clampf(float(channel.data.get("wobble_weight",0.0)),0.0,1.0)
  value*=1.0-weight+weight*_periodic(str(channel.data.get("wobble_function","one")),phase)
  # Independent 30Hz noise avoids frame-rate-dependent vibration and never
  # alters the gameplay random stream. Native random axes are unit vectors.
  _rng.seed=int(channel.seed)*104729+int(floor(clock*30.0))*15485863
  var axis=_random_direction()
  var angle=maxf(0.0,float(channel.data.get("random_rotation",0.0))*value)
  if angle!=0.0:_offset.basis=_offset.basis*Basis(axis,angle)
  _offset.origin+=_random_direction()*maxf(0.0,float(channel.data.get("random_translation",0.0))*value)*METRES*channel.scale
 if is_instance_valid(overlay):
  if _flash.is_empty():overlay.hide()
  else:
   var remaining=1.0-_flash.age/_flash.duration if _flash.duration>0.0 else 1.0
   flash_intensity=Math.blend_ease(str(_flash.data.get("fade_function","linear")),remaining*_flash.strength)
   var material:ShaderMaterial=overlay.material
   material.set_shader_parameter("strength",flash_intensity)
   material.set_shader_parameter("tint",Math.color(_flash.data.get("tint_lower_bound",{})))
   material.set_shader_parameter("flash_type",["none","lighten","darken","max","min","invert","tint"].find(str(_flash.data.get("type","none"))))
   overlay.visible=flash_intensity>0.0

func _random_direction()->Vector3:
 var z=_rng.randf_range(-1.0,1.0)
 var azimuth=_rng.randf()*TAU
 var radial=sqrt(maxf(0.0,1.0-z*z))
 return Vector3(cos(azimuth)*radial,z,sin(azimuth)*radial)

func _periodic(function_name:String,phase:float)->float:
 match function_name:
  "zero":return 0.0
  "cosine":return .5+.5*cos(phase*.7*TAU)
  "cosine_variable_period":
   if _variable_wave.is_empty():_build_variable_wave()
   var index=fposmod(phase*25.6,1024.0)
   return lerpf(_variable_wave[int(index)],_variable_wave[(int(index)+1)%1024],fmod(index,1.0))
  "slide":return fposmod(phase*.7,1.0)
  "diagonal_wave":return 1.0-absf(fposmod(phase*.7,1.0)*2.0-1.0)
 return 1.0

func _build_variable_wave():
 # Native variable-period cosine uses a normalized 1024-sample warped phase
 # table. Rebuild that distribution with an isolated deterministic RNG; its
 # random sequence is engine-local rather than a bitwise Xbox RNG replay.
 var rng=RandomNumberGenerator.new();rng.seed=0x20F3F660
 var phases=PackedFloat32Array();var total=0.0
 for index in 1024:
  phases.append(total)
  var u=float(index)/1024.0
  total+=.25+rng.randf()*.25
  for frequency in [8.2,10.2,14.6]:total+=(1.0+cos(frequency*PI*u))*rng.randf()
 var lower=1.0;var upper=0.0
 for phase in phases:
  var value=.5+.5*cos(phase/total*28.0*TAU)
  _variable_wave.append(value);lower=minf(lower,value);upper=maxf(upper,value)
 if upper>lower:
  for index in _variable_wave.size():_variable_wave[index]=(_variable_wave[index]-lower)/(upper-lower)
