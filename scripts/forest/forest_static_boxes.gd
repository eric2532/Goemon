extends RefCounted
## One immutable box mesh per build; keep batches small enough for local culling.
const CHUNK_SIZE=48.0
var groups:Dictionary={}
func add(point:Vector3,size_:Vector3,material:Material,shadow:int=GeometryInstance3D.SHADOW_CASTING_SETTING_ON):
 var chunk=Vector2i(floori(point.x/CHUNK_SIZE),floori(point.z/CHUNK_SIZE))
 var key="%d:%d:%d:%d"%[chunk.x,chunk.y,material.get_instance_id(),shadow]
 if not groups.has(key):groups[key]={"origin":Vector3(chunk.x*CHUNK_SIZE,0,chunk.y*CHUNK_SIZE),"material":material,"shadow":shadow,"transforms":[]}
 var group:Dictionary=groups[key]
 group.transforms.append(Transform3D(Basis.IDENTITY.scaled(size_),point-group.origin))
func build(parent:Node3D):
 var mesh=BoxMesh.new();mesh.size=Vector3.ONE
 for group in groups.values():
  var batch=MultiMeshInstance3D.new();batch.name="StaticStoneBoxes"
  batch.position=group.origin;batch.material_override=group.material;batch.cast_shadow=group.shadow
  var instances=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.mesh=mesh;instances.instance_count=group.transforms.size()
  var bounds:AABB
  for index in group.transforms.size():
   var pose:Transform3D=group.transforms[index];instances.set_instance_transform(index,pose)
   var box=pose*AABB(-Vector3.ONE*.5,Vector3.ONE)
   bounds=box if index==0 else bounds.merge(box)
  instances.custom_aabb=bounds
  batch.multimesh=instances;parent.add_child(batch)
 # The collector owns no nodes or resources after delivery to the scene tree.
 groups.clear()
