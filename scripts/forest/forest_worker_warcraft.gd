extends MultiMeshInstance3D
## Shared native skin/pose atlas; worker dictionaries still own every job.
const SOURCE="res://assets/characters/warcraft/peasant/worker.res"
static var resource:Resource
static var shared_mesh:ArrayMesh
var clip=""
var row=0.0
var last_clock=0.0
static func prepare():
	if resource!=null:return
	resource=load(SOURCE);shared_mesh=resource.get_meta("mesh").duplicate()
	for surface in shared_mesh.get_surface_count():
		var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/warcraft/mirror_crowd.gdshader")
		material.set_shader_parameter("pose_texture",resource.get_meta("pose_texture"));material.set_shader_parameter("surface_properties",resource.get_meta("properties"));material.set_shader_parameter("textured",true)
		material.set_shader_parameter("albedo_texture",resource.get_meta("textures")[surface]);shared_mesh.surface_set_material(surface,material)
func setup():
	name="WorkerBody";prepare();set_meta("source_model","res://assets/models/characters/warcraft/peasant/peasant.glb")
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_custom_data=true
	multimesh.mesh=shared_mesh;multimesh.instance_count=1;multimesh.set_instance_transform(0,Transform3D.IDENTITY)
	custom_aabb=AABB(Vector3(-4,-1,-4),Vector3(8,7,8))
	update_worker({"state":"idle","id":0},0)
func update_worker(worker:Dictionary,age:float)->bool:
	var state:String=worker.state;var moving=state in ["follow","travel","deliver","move","retreat"]
	var next="walk" if moving else "mine" if state=="mine" else "repair" if state=="repair" else "garrison" if state=="garrison" else "wounded" if state=="wounded" else "idle"
	if int(worker.get("cargo",0))>0 and next in ["idle","walk"]:next+="_gold"
	var data:Dictionary=resource.get_meta("clips")[next];var clock=age+int(worker.id)*.053
	var offset=float(resource.get_meta("work_offset"));var duration=float(data.duration)
	var hammer=next=="repair" and clip==next and clock>last_clock and floori((clock-offset)/duration)>floori((last_clock-offset)/duration)
	clip=next;last_clock=clock
	row=float(data.start)+minf(fposmod(clock,duration)*60,float(data.count)-1.001)
	if next in ["garrison","wounded"]:row=float(data.start)
	multimesh.set_instance_custom_data(0,Color(row,0,0,0))
	return hammer
