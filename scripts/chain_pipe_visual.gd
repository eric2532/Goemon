class_name ChainPipeVisual
extends Node3D
static var meshes: Dictionary={}
var endpoint_override=false
var endpoint=Vector3.ZERO
var powered=false
var head: MeshInstance3D
var links: MultiMeshInstance3D
var flame: FireEnergy
static func warmup():
	if not meshes.is_empty():return
	var source=GameAssets.instantiate_model("weapons/chain_pipe")
	for name in ["Chain_Handle","Chain_Head","Chain_Link_00","Handle_Attachment","Head_Attachment"]:
		meshes[name]=source.find_child(name,true,false).mesh
	source.free()
func part(name: String,parent: Node3D)->MeshInstance3D:
	var mesh=MeshInstance3D.new();mesh.mesh=meshes[name];parent.add_child(mesh);return mesh
func _ready():
	warmup();process_priority=40
	part("Chain_Handle",self)
	part("Handle_Attachment",self).position.z=-.3
	head=part("Chain_Head",self);part("Head_Attachment",head)
	links=MultiMeshInstance3D.new();links.multimesh=MultiMesh.new()
	links.multimesh.transform_format=MultiMesh.TRANSFORM_3D;links.multimesh.mesh=meshes.Chain_Link_00
	links.multimesh.instance_count=512;links.multimesh.visible_instance_count=0;add_child(links)
	flame=FireEnergy.new();flame.charged=true;head.add_child(flame);flame.position.z=-.2;flame.scale=Vector3.ONE*1.7;flame.hide()
	update_chain()
func _process(_delta):
	if is_visible_in_tree():update_chain()
func update_chain():
	var point=to_local(endpoint) if endpoint_override else Vector3(0,-.15,-1.48)
	head.position=point
	var start=Vector3(0,0,-.3);var direction=(point-start).normalized()
	if direction.length_squared()<.1:direction=Vector3.FORWARD
	head.basis=Basis.looking_at(direction,Vector3.UP if absf(direction.y)<.95 else Vector3.RIGHT)
	var count=clampi(ceili(start.distance_to(point)/.095),2,512)
	links.multimesh.visible_instance_count=count
	for i in range(count):
		var t=float(i)/maxf(1,count-1)
		var p=start.lerp(point,t)
		p.y-=sin(t*PI)*(.08 if endpoint_override else .16)
		var basis=head.basis*Basis(Vector3.FORWARD,(i%2)*PI/2)
		links.multimesh.set_instance_transform(i,Transform3D(basis,p))
	flame.visible=powered
