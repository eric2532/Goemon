extends RefCounted
## Native weathered wall variants, cached and batched by the existing outdoor owner.
# shortcut: Hidden backs and crowns obscured by posts need additional source views.
const Data=preload("res://assets/maps/falan/venoa_walls.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Shapes=preload("res://scripts/forest/forest_coastal_buildings.gd")
const Proportions=preload("res://scripts/forest/forest_falan_proportions.gd")
static var meshes={}

static func point(along_x:bool,along:float,height:float,plane:float)->Vector3:
 return Vector3(along,height,plane) if along_x else Vector3(plane,height,along)

static func prepare(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var row:Array=Data.FORMS[serial]
 var skin=Source.new([row[0],row[1],Vector2.ONE,0],Data.ATLAS,.045)
 for face in row[2]:wall_face(skin,face[0],face[1])
 var along_x:bool=row[2][0][0]
 var plane=.8 if along_x else -.8
 var post:Vector3=row[3]
 if post!=Vector3.ZERO:
  var r=post.z;var h=post.y
  var center=point(along_x,post.x,0,plane+(.04 if along_x else -.04))
  Shapes.kili_round(skin,center,[Vector2(0,0),Vector2(r*.86,0),Vector2(r*.94,.12),Vector2(r*.86,h-r*1.75),Vector2(r*.98,h-r*1.70),Vector2(r*.88,h-r*1.48),Vector2(r*.55,h-r*1.38),Vector2(r*.88,h-r*1.14),Vector2(r,h-r*.72),Vector2(r*.80,h-r*.24),Vector2(0,h)])
 var mesh=Proportions.transformed(skin.finish(),Proportions.native_coastal_frame());mesh.set_meta("original_graphic",serial)
 meshes[serial]=mesh
 return mesh

static func wall_face(skin,along_x:bool,profile:Array):
 var plane=.8 if along_x else -.8
 var rear=plane+(-.6 if along_x else .6)
 for i in profile.size()-1:
  var a:Vector2=profile[i];var b:Vector2=profile[i+1]
  var low_a=point(along_x,a.x,0,plane);var low_b=point(along_x,b.x,0,plane)
  var high_a=point(along_x,a.x,a.y,plane);var high_b=point(along_x,b.x,b.y,plane)
  var back_a=point(along_x,a.x,a.y,rear);var back_b=point(along_x,b.x,b.y,rear)
  var floor_a=point(along_x,a.x,0,rear);var floor_b=point(along_x,b.x,0,rear)
  skin.quad(low_a,high_a,high_b,low_b)
  skin.quad(floor_b,back_b,back_a,floor_a)
  skin.quad(high_a,back_a,back_b,high_b)
  skin.quad(floor_a,low_a,low_b,floor_b)
 for i in [0,profile.size()-1]:
  var p:Vector2=profile[i]
  var corners=[point(along_x,p.x,0,plane),point(along_x,p.x,0,rear),point(along_x,p.x,p.y,rear),point(along_x,p.x,p.y,plane)]
  if i>0:corners.reverse()
  skin.quad(corners[0],corners[1],corners[2],corners[3])
static func batch(parent:Node3D,groups:Dictionary):
 for serial in groups:
  var chunks={}
  for pose:Transform3D in groups[serial]:
   var key=Vector2i(floori(pose.origin.x/48),floori(pose.origin.z/48))
   if not chunks.has(key):chunks[key]=[]
   chunks[key].append(pose)
  for key in chunks:
   var node=MultiMeshInstance3D.new();node.name="NativeVenoaWall_%d_%d_%d"%[serial,key.x,key.y]
   var instances=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D
   instances.mesh=prepare(serial);instances.instance_count=chunks[key].size()
   for i in chunks[key].size():instances.set_instance_transform(i,chunks[key][i])
   node.multimesh=instances;node.set_meta("source_graphic",serial);parent.add_child(node)
