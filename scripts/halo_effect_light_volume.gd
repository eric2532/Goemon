extends Node3D
## Native owner-bound light volumes use the recovered widget bitmap and shared
## sprite batches. The rocket's twenty sprites are persistent data, not nodes.
const Math=preload("res://scripts/halo_particle_math.gd")
const METRES=3.048
const MAX_OWNERS=6
const MAX_SPRITES_PER_OWNER=64
var data
var particles:Node3D
var camera_override:Camera3D
var layer=1
var owners:Dictionary={}

func configure(source,renderer:Node3D,camera:Camera3D=null,render_layer:int=1):
 clear();data=source;particles=renderer;camera_override=camera;layer=render_layer

func start(id:int,definition:Dictionary,at:Vector3,direction:Vector3):
 stop(id)
 if data==null or not is_instance_valid(particles) or definition.get("frames",[]).is_empty():return
 if owners.size()>=MAX_OWNERS:stop(int(owners.keys()[0]))
 var bitmap:Dictionary=definition.get("map",{})
 if str(bitmap.get("path","")).is_empty():bitmap=data.manifest().get("defaults",{}).get("light_volume_bitmap",{})
 if data.bitmap_frame(bitmap,int(definition.get("map_sequence_index",0))).is_empty():return
 var owner={"definition":definition,"at":at,"direction":_direction(direction),"key":"light-volume:%d"%id,"bitmap":bitmap}
 owners[id]=owner
 _refresh(owner,true)

func move(id:int,at:Vector3,direction:Vector3):
 if not owners.has(id):return
 owners[id].at=at;owners[id].direction=_direction(direction)
 _refresh(owners[id])

func stop(id:int):
 if not owners.has(id):return
 if is_instance_valid(particles):particles.clear_attachment(owners[id].key)
 owners.erase(id)

func tick(_delta:float=0.0):
 # Re-evaluate view-dependent brightness when only the camera moves.
 for owner in owners.values():_refresh(owner)

func clear():
 for id in owners.keys():stop(int(id))

func _exit_tree():clear()

func live_count()->int:return owners.size()

func _direction(value:Vector3)->Vector3:
 return value.normalized() if not value.is_zero_approx() else Vector3.FORWARD

func _refresh(owner:Dictionary,initial:bool=false):
 if not is_instance_valid(particles):return
 var definition:Dictionary=owner.definition
 # Rocket widgets have one native frame and no object-function animation.
 var frame:Dictionary=definition.frames[0]
 var count=clampi(int(definition.get("map_count",0)),0,MAX_SPRITES_PER_OWNER)
 var brightness=_brightness(owner)
 var updates:Array[Dictionary]=[]
 for index in count:
  var offset_fraction=pow(float(index)/maxi(1,count-1),float(frame.get("offset_exponent",1.0)))
  var radius_fraction=pow(offset_fraction,float(frame.get("radius_exponent",1.0)))
  var radius=lerpf(float(frame.get("radius_hither",0.0)),float(frame.get("radius_yon",0.0)),radius_fraction)*METRES
  var color_fraction=pow(offset_fraction,float(frame.get("tint_color_exponent",1.0)))
  var alpha_fraction=pow(offset_fraction,float(frame.get("brightness_exponent",1.0)))
  var hither=Math.color(frame.get("tint_color_hither",{}))
  var yon=Math.color(frame.get("tint_color_yon",{}))
  var tint=_tint(hither,yon,color_fraction,int(definition.get("flags",0)))
  tint.a=lerpf(hither.a,yon.a,alpha_fraction)*brightness
  var distance=(float(frame.get("offset_from_marker",0.0))+offset_fraction*float(frame.get("length",0.0)))*METRES
  updates.append({"position":owner.at+owner.direction*distance,"direction":owner.direction,"radius":radius,"radius_halo":radius/METRES,"tint":tint})
 if not initial and particles.update_attachment(owner.key,updates)==updates.size():return
 particles.clear_attachment(owner.key)
 for update in updates:
  var options:Dictionary=update.duplicate()
  options.bitmap=owner.bitmap;options.sequence=int(definition.get("map_sequence_index",0))
  options.blend="add";options.orientation="screen_facing";options.attachment_id=owner.key
  # A native widget lasts exactly as long as its owner. move/tick refresh its
  # persistent properties; stop/clear explicitly reclaim its bounded pool.
  options.lifetime=INF
  particles.spawn_sprite(options)

func _brightness(owner:Dictionary)->float:
 var camera=camera_override
 if not is_instance_valid(camera) and is_inside_tree():camera=get_viewport().get_camera_3d()
 if not is_instance_valid(camera) or not camera.is_inside_tree():return 1.0
 var definition:Dictionary=owner.definition
 var forward=-camera.global_basis.z
 var depth=(owner.at-camera.global_position).dot(forward)
 var near_distance=float(definition.get("near_fade_distance",0.0))*METRES
 var far_distance=float(definition.get("far_fade_distance",0.0))*METRES
 var fade=1.0
 if far_distance>0.0:
  fade=clampf((far_distance-depth)/(far_distance-near_distance),0.0,1.0) if far_distance!=near_distance else float(depth<far_distance)
 var parallel=absf(forward.dot(owner.direction))
 var perpendicular_scale=float(definition.get("perpendicular_brightness_scale",1.0))
 var parallel_scale=float(definition.get("parallel_brightness_scale",1.0))
 return fade*clampf(lerpf(perpendicular_scale,parallel_scale,parallel),0.0,1.0)

func _tint(a:Color,b:Color,fraction:float,flags:int)->Color:
 if flags&1==0:return a.lerp(b,fraction)
 var delta=b.h-a.h
 if (absf(delta)>.5)!=(flags&2!=0):delta+=-1.0 if delta>0.0 else 1.0
 return Color.from_hsv(fposmod(a.h+delta*fraction,1.0),lerpf(a.s,b.s,fraction),lerpf(a.v,b.v,fraction),1.0)
