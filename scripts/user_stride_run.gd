extends RefCounted
## The approved Blender action shared by the roster except dedicated weapon carries.
const SHARED_CLASSES=["goemon","edo","pirate","ninja","mage","dragoon","ranger","explorer","master-thief"]

static func enabled(id: String)->bool:
	return id in SHARED_CLASSES

const SOURCE="res://assets/animations/goemon_edo_run.json"
var skeleton: Skeleton3D
var indices: Array[int]=[]
var frames: Array=[]
var period=60.0
func _init(sk: Skeleton3D):
	skeleton=sk
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	period=float(data.period_frames)
	for name_ in data.bones:indices.append(sk.find_bone(name_))
	for samples in data.frames:
		var global_poses: Dictionary={}
		var locals: Array[Transform3D]=[]
		for b in range(indices.size()):
			var v: Array=samples[b]
			var rotation=Quaternion(v[3],v[4],v[5],v[6]).normalized()
			var basis=Basis(rotation).scaled(Vector3(v[7],v[8],v[9]))*sk.get_bone_global_rest(indices[b]).basis
			global_poses[indices[b]]=Transform3D(basis,Vector3(v[0],v[1]+data.floor_offset,v[2]))
		for index in indices:
			var parent=sk.get_bone_parent(index)
			locals.append(global_poses[parent].affine_inverse()*global_poses[index] if parent>=0 else global_poses[index])
		frames.append(locals)

static func weight(speed: float,forward: float)->float:
	return smoothstep(2.2,8.0,speed)*maxf(0,forward)

static func cadence(speed: float)->float:
	return lerpf(1.1,1.5,smoothstep(2.2,10.2,speed)) if speed<=10.2 else lerpf(1.5,1.9,smoothstep(10.2,18.0,speed))

func apply(phase: float,amount: float):
	if amount<.001:return
	var t=fposmod(phase,1.0)*period
	var frame=int(t)
	var fraction=t-frame
	var before: Dictionary={}
	for index in indices:before[index]=skeleton.get_bone_global_pose(index)
	var posed: Dictionary={}
	for b in range(indices.size()):
		var index=indices[b]
		var parent=skeleton.get_bone_parent(index)
		var native: Transform3D=before[parent].affine_inverse()*before[index] if parent>=0 else before[index]
		var target: Transform3D=frames[frame][b].interpolate_with(frames[frame+1][b],fraction)
		var local=native.interpolate_with(target,clampf(amount,0,1))
		posed[index]=posed[parent]*local if parent>=0 else local
	for index in indices:skeleton.set_bone_global_pose(index,posed[index])
