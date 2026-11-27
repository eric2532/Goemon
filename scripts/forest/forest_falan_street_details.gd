extends RefCounted
## Native paint on shared solid street props and volumetric foliage.
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const SourceMesh=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Data=preload("res://assets/maps/falan/city_street_surfaces.gd")
const Atlas=preload("res://assets/maps/falan/city_street_surfaces.png")
const PlanterAtlas=preload("res://assets/maps/falan/city_planter_art.png")
const LeafAtlas=preload("res://assets/maps/falan/city_planter_leaves.png")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const OriginalArt=preload("res://scripts/forest/forest_original_map_art.gd")
static var meshes:Dictionary={}
static var canopies:Dictionary={}

static func yaw(serial:int)->float:
 return -PI*.5 if serial in [10413,10415,10417,11496] else 0.0

static func planter_height(serial:int)->float:return Data.PLANTERS[serial][3]

static func planter_foliage(p:Vector3,serial:int)->Array:
 var poses=[]
 var floor_:Array=Data.PLANTERS[serial][2]
 var center=Vector3.ZERO
 for at:Vector2 in floor_:center+=Vector3(at.x,0,at.y)*.25
 var first:Vector2=floor_[1]-floor_[0];var second:Vector2=floor_[2]-floor_[1]
 var axis:Vector2=(first if first.length_squared()>second.length_squared() else second).normalized()
 var angle=-atan2(axis.y,axis.x)
 for side in [-1,1]:
  poses.append(Transform3D(Basis(Vector3.UP,angle+(PI if side<0 else 0.0)).scaled_local(Vector3(.75,.80,.85)),p+center+Vector3(axis.x*side*.40,planter_height(serial)-.48,axis.y*side*.40)))
 return poses

static func place(parent:Node3D,serial:int,p:Vector3):
 var node=MeshInstance3D.new();node.name="RecoveredFalanStreetDetail%d_%d_%d"%[serial,roundi(p.x),roundi(p.z)]
 node.mesh=prepare(serial);node.position=p;node.rotation.y=yaw(serial)
 node.set_meta("original_graphic",serial);parent.add_child(node)

static func batch(parent:Node3D,serial:int,poses:Array):
 var at:Vector3=poses[0].origin
 var node=MultiMeshInstance3D.new();node.name="RecoveredFalanPlanters%d_%d_%d"%[serial,floori(at.x/48),floori(at.z/48)]
 node.set_meta("original_graphic",serial)
 node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
 node.multimesh.mesh=prepare(serial);node.multimesh.instance_count=poses.size()
 for i in poses.size():node.multimesh.set_instance_transform(i,poses[i])
 parent.add_child(node)
 var leaves=MultiMeshInstance3D.new();leaves.name="RecoveredFalanPlanterLeaves%d_%d_%d"%[serial,floori(at.x/48),floori(at.z/48)]
 leaves.multimesh=MultiMesh.new();leaves.multimesh.transform_format=MultiMesh.TRANSFORM_3D
 leaves.multimesh.mesh=foliage(serial);leaves.multimesh.instance_count=poses.size()
 for i in poses.size():leaves.multimesh.set_instance_transform(i,poses[i])
 parent.add_child(leaves)

static func foliage(serial:int)->Mesh:
 if canopies.has(serial):return canopies[serial]
 var skin=SourceMesh.new(Data.PLANTERS[serial],LeafAtlas,.045)
 skin.reflection_threshold=2.0
 for pose:Transform3D in planter_foliage(Vector3.ZERO,serial):
  for part in Assets.source("leafy_shrub"):
   var transform_:Transform3D=pose*part.transform
   for surface in part.mesh.get_surface_count():
    var arrays=part.mesh.surface_get_arrays(surface)
    var indices=arrays[Mesh.ARRAY_INDEX]
    var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var normal_basis=transform_.basis.inverse().transposed()
    for i in (indices.size() if indices!=null and not indices.is_empty() else points.size()):
     var vertex:int=indices[i] if indices!=null and not indices.is_empty() else i
     skin.vertex(transform_*points[vertex],(normal_basis*normals[vertex]).normalized())
 var mesh=skin.finish()
 var material=ShaderMaterial.new();material.shader=Assets.WIND
 material.set_shader_parameter("tree",true);material.set_shader_parameter("strength",0.0)
 material.set_shader_parameter("use_source_paint",true);material.set_shader_parameter("source_cutout",true)
 material.set_shader_parameter("source_paint",LeafAtlas)
 mesh.surface_set_material(0,material);canopies[serial]=mesh
 return mesh

static func laundry_point(pixel:Vector2)->Vector3:
 # Native 11004, relative to its compound-footprint centre in the city frame.
 var x=(pixel.x-51.0)/(32.0/3.0)+.25
 var y=((x+.25)*8.0-(pixel.y-109.0))/sqrt(2.0*(pow(32.0/3.0,2)-64.0))
 return Vector3(x,y,.25)

static func laundry_mesh()->Mesh:
 Parts.prepare_primitives()
 var frame=SurfaceTool.new();frame.begin(Mesh.PRIMITIVE_TRIANGLES)
 var feet=[Vector3(-3.921875,0,.296875),Vector3(4.421875,0,.203125)]
 var height=76.0/sqrt(2.0*(pow(32.0/3.0,2)-64.0))
 for foot:Vector3 in feet:
  Parts.rod(frame,foot,foot+Vector3.UP*height,.12)
  for y in [.13,height-1.35,height-.94,height-.15]:
   Parts.rod(frame,foot+Vector3.UP*(y-.06),foot+Vector3.UP*(y+.06),.20)
  Parts.oval(frame,foot+Vector3.UP*(height+.12),Vector3(.45,.24,.45))
 Parts.rod(frame,feet[0]+Vector3.UP*6.65,feet[1]+Vector3.UP*6.65,.075)
 var objects=[frame.commit()]
 for pixels in [[Vector2(12,19),Vector2(57,49),Vector2(62,53),Vector2(63,76),Vector2(63,94),Vector2(58,99),Vector2(50,96),Vector2(15,72),Vector2(13,68)],
                [Vector2(70,62),Vector2(90,76),Vector2(88,91),Vector2(86,114),Vector2(80,110),Vector2(79,90),Vector2(76,108),Vector2(70,105),Vector2(67,87)]]:
  var outline=PackedVector2Array()
  for pixel:Vector2 in pixels:
   var p=laundry_point(pixel);outline.append(Vector2(p.x,p.y))
  objects.append(Shapes.extrude(outline,.05))
 var g:Dictionary=OriginalArt.data().graphics["11004"]
 var texture:Texture2D=load(OriginalArt.ROOT+OriginalArt.data().pages[int(g.page)])
 var rect=Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3])
 var skin=SourceMesh.new([rect,Vector2(51,109),Vector2.ONE,0],texture,1.0/sqrt(2.0*(pow(32.0/3.0,2)-64.0)))
 for object in objects:
  var a=object.surface_get_arrays(0);var indices=a[Mesh.ARRAY_INDEX]
  var shift=Vector3.ZERO if object==objects[0] else Vector3.BACK*.25
  for i in (indices.size() if indices!=null and not indices.is_empty() else a[Mesh.ARRAY_VERTEX].size()):
   var index:int=indices[i] if indices!=null and not indices.is_empty() else i
   var point:Vector3=a[Mesh.ARRAY_VERTEX][index]+shift
   skin.projected_vertex(point,a[Mesh.ARRAY_NORMAL][index],Vector3(-point.z,point.y,point.x))
 var result=skin.finish()
 result.set_meta("original_graphic",11004)
 return result

static func prepare(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 if serial==11004:
  meshes[serial]=laundry_mesh()
  return meshes[serial]
 Parts.prepare_primitives()
 var frame=SurfaceTool.new();frame.begin(Mesh.PRIMITIVE_TRIANGLES)
 var planter=serial in [10426,10427,10452,10453]
 var paint=SourceMesh.new(Data.PLANTERS[serial] if planter else [],PlanterAtlas if planter else Atlas,.045)
 if planter:paint.reflection_threshold=.5
 if not planter:paint.tiles=Data.TILES
 var metal=serial in [10415,10416,10417,10419]
 if planter:
  var h=planter_height(serial)
  var floor_=PackedVector2Array(Data.PLANTERS[serial][2])
  for at:Vector2 in floor_:paint.projection_center+=Vector3(at.x,0,at.y)*.25
  var soil=PackedVector2Array();var center=Vector2(paint.projection_center.x,paint.projection_center.z)
  for at:Vector2 in floor_:soil.append(center+(at-center)*.98)
  frame.append_from(Shapes.extrude(soil,h-.02),0,Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3.UP*h*.5))
  var courses=6 if h>1 else 3
  for course in courses:
   var y=course*h/courses
   for edge in 4:
    var a=Vector3(floor_[edge].x,0,floor_[edge].y)
    var b=Vector3(floor_[(edge+1)%4].x,0,floor_[(edge+1)%4].y)
    var along=(b-a).normalized();var width=a.distance_to(b);var start=0.0
    while start<width-.001:
     var end=minf(width,start+(.24 if course%2==1 and start==0.0 else .48))
     brick(paint,a+along*(start+.012)+Vector3.UP*(y+.012),a+along*(end-.012)+Vector3.UP*(y+.012),h/courses-.012)
     start=end
 elif serial==10419:
  for row in [[.11,.17],[.29,.12],[2.70,.14],[2.84,.11]]:
   Parts.rod(frame,Vector3.UP*(row[0]-.06),Vector3.UP*(row[0]+.06),row[1])
  Parts.rod(frame,Vector3.UP*.18,Vector3.UP*2.72,.055)
  Parts.oval(frame,Vector3.UP*2.98,Vector3(.15,.21,.15))
 elif serial==10417:
  for x in [-1.12,-.75,-.375,0,.375,.75,1.12]:
   Parts.rod(frame,Vector3(x,.08,0),Vector3(x,2.50,0),.024)
   Parts.oval(frame,Vector3(x,2.55,0),Vector3(.07,.17,.07))
  for y in [.32,.57,2.12,2.32]:Parts.rod(frame,Vector3(-1.18,y,0),Vector3(1.18,y,0),.026)
 elif serial in [10415,10416]:
  for side in [-1,1]:
   var x=side*.88
   Parts.rod(frame,Vector3(x,.08,0),Vector3(x,3.25,0),.045)
   Parts.rod(frame,Vector3(x,.02,0),Vector3(x,.14,0),.12)
   Parts.oval(frame,Vector3(x,3.34,0),Vector3(.14,.19,.14))
   var last=Vector3(x,3.18,0)
   for i in range(1,17):
    var t=float(i)/16;var angle=t*TAU*1.1;var r=lerpf(.25,.025,t)
    var next=Vector3(side*(.64+cos(angle)*r),3.25+sin(angle)*r,0)
    Parts.rod(frame,last,next,.027);last=next
  Parts.block(frame,Vector3(0,2.05,0),Vector3(1.40,2.20,.10))
  for y in [.92,3.16]:Parts.rod(frame,Vector3(-.88,y,0),Vector3(.88,y,0),.035)
  face(paint,serial,Vector3(0,2.05,.056),2.22)
 elif serial==10413:
  for side in [-1,1]:
   Parts.block(frame,Vector3(side*.79,1.35,0),Vector3(.13,2.70,.14))
   Parts.oval(frame,Vector3(side*.79,2.76,0),Vector3(.18,.19,.18))
  Parts.block(frame,Vector3(0,1.86,0),Vector3(2.0,1.20,.13))
  face(paint,serial,Vector3(0,1.86,.071),2.0)
 else:
  Parts.block(frame,Vector3(0,1.23,0),Vector3(.12,2.46,.13))
  var outline=PackedVector2Array()
  for point:Vector2 in Data.OVALS[serial]:outline.append(point*2.80)
  # The extruded profile is unindexed; include it after indexed primitive parts.
  frame.deindex()
  frame.append_from(Shapes.extrude(outline,.14),0,Transform3D(Basis.IDENTITY,Vector3(0,2.25,0)))
  face(paint,serial,Vector3(0,2.25,.076),2.80)
 var result=ArrayMesh.new()
 var solid=frame.commit()
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,solid.surface_get_arrays(0))
 result.surface_set_material(0,Geo.mat("544b32" if planter else "9aaeb0" if serial==10419 else "45625b" if metal else "986c39"))
 if serial not in [10417,10419]:
  var source=paint.finish()
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(0))
  var material=source.surface_get_material(0).duplicate();material.set_shader_parameter("original_palette",false)
  result.surface_set_material(1,material)
 meshes[serial]=result
 return result

static func brick(skin,a:Vector3,b:Vector3,height:float):
 var up=Vector3.UP*height;var inset=Vector3.UP.cross(b-a).normalized()*.18
 skin.quad(a,a+up,b+up,b)
 skin.quad(b+inset,b+inset+up,a+inset+up,a+inset)
 skin.quad(a+inset,a+inset+up,a+up,a)
 skin.quad(b,b+up,b+inset+up,b+inset)
 skin.quad(a+up,a+inset+up,b+inset+up,b+up)

static func face(paint,serial:int,p:Vector3,size_:float):
 for side in [-1,1]:
  var center=Vector3(p.x,p.y,p.z*side)
  var across=Vector3.RIGHT*side*size_*.5
  var up=Vector3.UP*size_*.5
  paint.panel(center-across-up,center-across+up,center+across+up,center+across-up,"notice_"+str(serial))
