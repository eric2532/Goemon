extends RefCounted
## Complete native building parts with surface-specific paint; saved placements stay authoritative.
const Proportions=preload("res://scripts/forest/forest_falan_proportions.gd")
const Data=preload("res://assets/maps/falan/city_architecture.gd")
const HouseParts=preload("res://scripts/forest/forest_falan_houses.gd")
const Atlas=HouseParts.Atlas
static var meshes:Dictionary={}

static func batch(parent:Node3D,serial:int,poses:Array):
 var node=MultiMeshInstance3D.new();node.name="RecoveredFalanArchitecture%d"%serial
 node.set_meta("falan_architecture_graphic",serial)
 node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
 node.multimesh.mesh=prepare(serial);node.multimesh.instance_count=poses.size()
 for i in poses.size():node.multimesh.set_instance_transform(i,poses[i])
 parent.add_child(node)

static func unmarked_bounds(model,index:int)->AABB:
 var row:Array=Data.UNMARKED[index];var at:Vector2=row[1]
 var bounds=collision(row[0]);bounds.position+=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
 return bounds

static func build_unmarked(parent:Node3D,model):
 var old=parent.get_node_or_null("OriginalFalanUnmarkedHouses")
 var plan=[]
 for i in Data.UNMARKED.size():plan.append(unmarked_bounds(model,i))
 if old!=null and old.get_meta("source_plan")==plan:return
 if old!=null:parent.remove_child(old);old.queue_free()
 var root=Node3D.new();root.name="OriginalFalanUnmarkedHouses";root.set_meta("source_plan",plan);parent.add_child(root)
 var groups={}
 for row in Data.UNMARKED:
  var at:Vector2=row[1]
  if not groups.has(row[0]):groups[row[0]]=[]
  groups[row[0]].append(Transform3D(Basis(Vector3.UP,PI*.5),Vector3(at.x,model.surface_height(at.x,at.y),at.y)))
 for serial in groups:batch(root,serial,groups[serial])
 for bounds:AABB in plan:preload("res://scripts/forest/forest_art.gd").solid(root,bounds.get_center(),bounds.size,1,"stone")

static func point(at:Vector2,height:float=0)->Vector3:return Vector3(at.x,height,at.y)

static func bay_floor(serial:int)->Array:
 var row:Array=Data.GRAPHICS[serial]
 if int(row[8]) not in [3,6,7,8,9,10,11,13,16]:return []
 var edge:int=row[3];var floor_:Array=row[2]
 var a=point(floor_[edge]);var b=point(floor_[(edge+1)%4])
 var along=(b-a).normalized();var out=along.cross(Vector3.UP).normalized()
 var width=minf(3.4,a.distance_to(b)*.32)
 var center=(a+b)*.5-along*((out.x+out.z)*.5)
 return [center-along*width*.5,center-along*width*.5+out*.5,center+along*width*.5+out*.5,center+along*width*.5]

static func collision(serial:int)->AABB:
 var row:Array=Data.GRAPHICS[serial]
 var footprint:Vector2=row[9]
 var bounds=AABB(Vector3(-footprint.x*.5,0,-footprint.y*.5),Vector3(footprint.x,0,footprint.y))
 for p:Vector3 in bay_floor(serial):bounds=bounds.expand(Basis(Vector3.UP,PI*.5)*p)
 for p:Vector2 in row[4]:bounds.size.y=maxf(bounds.size.y,p.y+3.1)
 bounds.size.y=Proportions.height("house_%d"%serial,bounds.size.y)
 return bounds

static func prepare(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var row:Array=Data.GRAPHICS[serial]
 var source:Mesh=HouseParts.shape("falan_townhouse",row[8],serial)
 var result=HouseParts.surface_mesh(source,Basis(Vector3.UP,0.0 if row[3]==1 else -PI*.5))
 result=Proportions.fitted(result,"house_%d"%serial)
 meshes[serial]=result
 return result

static func entry(serial:int)->Dictionary:
 var row:Array=Data.GRAPHICS[serial];var raw:Array=HouseParts.raw_entry(serial)
 var turn=Basis(Vector3.UP,0.0 if row[3]==1 else -PI*.5)
 var fit:Transform3D=Proportions.Data.FITS["house_%d"%serial]
 var city_turn=Basis(Vector3.UP,PI*.5)
 var at:Vector3=city_turn*(fit*(turn*raw[0]))
 var normal:Vector3=city_turn*turn*raw[1]
 return {"at":Vector2(at.x,at.z),"direction":Vector2(normal.x,normal.z)}
