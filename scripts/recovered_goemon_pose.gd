extends RefCounted
## Native retail ROM part matrices. No retargeting or skin deformation.
const DATA_PATH="res://assets/characters/recovered_goemon/motion.json"
const PTR={"Pelvis":"0x9004f48","Chest":"0x9005a28","Head":"0x90050f8","Arm_R":"0x9005498","Forearm_R":"0x90055b8","Arm_L":"0x9005748","Forearm_L":"0x9005868","Leg_R":"0x90047f8","Shin_R":"0x9004ac8","Foot_R":"0x9004930","Leg_L":"0x9004bb0","Shin_L":"0x9004e48","Foot_L":"0x9004cd0"}
static var archive:Dictionary={}
var source_scale=0.016
var source_metadata:Dictionary={}

func _init():
	if archive.is_empty():archive=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	source_metadata=archive.metadata

func frame_count(action_id:int)->int:
	var pointer:String=archive.actions.get(str(action_id),"")
	return int(archive.clips[pointer].frame_count) if not pointer.is_empty() else 0

func native_rate(action_id:int)->float:return maxf(0.01,float(archive.rates.get(str(action_id),1.0)))

func duration(action_id:int)->float:return maxf(1.0,float(frame_count(action_id)-1))/(30.0*native_rate(action_id))

func sample_source(action_id:int,time_seconds:float)->Dictionary:
	var pointer:String=archive.actions.get(str(action_id),"")
	if pointer.is_empty():return {}
	var clip:Dictionary=archive.clips[pointer]
	var position=clampf(time_seconds*30.0*native_rate(action_id),0.0,float(clip.frame_count)-1.0)
	var a=int(floor(position));var b=mini(a+1,int(clip.frame_count)-1);var t=position-a
	var result:Dictionary={}
	for i in range(clip.pointers.size()):
		var key:String=clip.pointers[i]
		if key=="0x0":continue
		var first=_transform(clip.frames[a][i])
		result[key]=first if t<0.000001 else _interpolate_transform(first,_transform(clip.frames[b][i]),t)
	return result

func sample_part(action_id:int,time_seconds:float,part:String)->Transform3D:
	# Collision needs the pipe only. Sampling the whole body for every sweep
	# subdivision repeats all unrelated joint conversions and interpolation.
	var pointer:String=archive.actions.get(str(action_id),"")
	if pointer.is_empty():return Transform3D.IDENTITY
	var clip:Dictionary=archive.clips[pointer]
	var index:int=clip.pointers.find(part)
	if index<0:return Transform3D.IDENTITY
	var position=clampf(time_seconds*30.0*native_rate(action_id),0.0,float(clip.frame_count)-1.0)
	var a=int(floor(position));var b=mini(a+1,int(clip.frame_count)-1);var t=position-a
	var first=_transform(clip.frames[a][index])
	return first if t<0.000001 else _interpolate_transform(first,_transform(clip.frames[b][index]),t)

func _transform(values:Array)->Transform3D:
	return Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))

func _interpolate_transform(first:Transform3D,second:Transform3D,t:float)->Transform3D:
	if absf(first.basis.determinant())>0.00000001 and absf(second.basis.determinant())>0.00000001:
		return first.interpolate_with(second,t)
	# Zero scale is a native hide flag, with no defined orientation to interpolate.
	var safe=first.basis if absf(first.basis.determinant())>0.00000001 else second.basis
	if absf(safe.determinant())<0.00000001:safe=Basis.IDENTITY
	return Transform3D(safe.orthonormalized().scaled(first.basis.get_scale().lerp(second.basis.get_scale(),t)),first.origin.lerp(second.origin,t))

func has_part(action_id:int,pointer:String)->bool:
	var clip_pointer:String=archive.actions.get(str(action_id),"")
	return not clip_pointer.is_empty() and archive.clips[clip_pointer].pointers.has(pointer)
