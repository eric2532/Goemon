extends MultiMeshInstance3D
## Prepared cosmetic masonry; the original target still owns breach collision.
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const CHUNKS=6
const DURATION=1.35
var poses:Array=[]
var active:Dictionary={}
var broken:Dictionary={}

func setup(wall_poses:Array):
	name="FallingMasonry";poses=wall_poses
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true
	multimesh.mesh=Meadow.source("buildings/stone_block")[0].mesh
	multimesh.instance_count=poses.size()*CHUNKS
	var material=multimesh.mesh.surface_get_material(0).duplicate()
	material.vertex_color_use_as_albedo=true;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override=material
	for i in multimesh.instance_count:multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
	hide();set_process(false)

func play(slot:int):
	if broken.has(slot):return
	broken[slot]=true;active[slot]=0.0
	_pose(slot,0.0);show();set_process(true)

func _process(delta:float):
	for slot in active.keys():
		active[slot]+=delta
		if active[slot]>=DURATION:
			for i in CHUNKS:multimesh.set_instance_transform(slot*CHUNKS+i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),poses[slot].origin))
			active.erase(slot)
		else:_pose(slot,active[slot])
	if active.is_empty():hide();set_process(false)

func _pose(slot:int,age:float):
	var frame:Transform3D=poses[slot].orthonormalized()
	var size_=Vector3(3.0*poses[slot].basis.get_scale().x,16.0/3.0,5.6)
	for i in CHUNKS:
		var row=i/2;var side=-1.0 if i%2==0 else 1.0
		var outward=-1.0 if (i+slot)%3==0 else 1.0
		# Upper courses release first; acceleration and rotation make the fall readable.
		var t=maxf(0.0,age-.06*(2-row))
		var turn=Basis.from_euler(Vector3(outward*t*1.5,side*t*.35,side*t*.4))
		var basis_=turn.scaled_local(size_/6.0)
		var half_height=(absf(turn.x.y)*size_.x+absf(turn.y.y)*size_.y+absf(turn.z.y)*size_.z)*.5
		var center=Vector3(side*(size_.x*.5+t*1.2),(row+.5)*size_.y,outward*t*3.4)
		center.y=maxf(half_height,center.y+1.8*t-20.0*t*t)
		var shake=sin(age*65.0)*.09*maxf(0.0,1.0-age/.18)
		center.x+=shake
		multimesh.set_instance_transform(slot*CHUNKS+i,frame*Transform3D(basis_,center-basis_*Vector3(0,3,0)))
		multimesh.set_instance_color(slot*CHUNKS+i,Color(1,1,1,1.0-smoothstep(.95,DURATION,age)))
