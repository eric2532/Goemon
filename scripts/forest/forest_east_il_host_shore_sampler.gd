extends "res://scripts/forest/forest_kai_terrain.gd"
## Private numerical/physics candidate only; no map or default caller.
var proposal:Dictionary={}
var private_field:Resource

static func point(source:Vector2,high:float=0.)->Vector3:return Vector3(591.-source.y*3.,high,source.x*3.-1251.)

func setup(data:Dictionary):
 proposal=data;private_field=Resource.new()
 var zero=PackedByteArray();zero.resize(int(data.width)*int(data.width))
 for item in [["width",int(data.width)],["spacing",float(data.spacing)],["heights",PackedFloat32Array(data.heights)],["covered",PackedByteArray(data.covered)],["bridges",zero]]:private_field.set_meta(item[0],item[1])
 var floors=[]
 for r:Array in data.source_water:
  var a=point(Vector2(r[0]-.5,r[1]+r[3]*.5-.5));var b=a+Vector3.BACK*float(r[2])*3.
  floors.append({"ax":a.x/6.,"az":a.z/6.,"bx":b.x/6.,"bz":b.z/6.,"width":r[3]*.5,"h0":2.,"h1":2.,"cap_start":false,"cap_end":false,"joined":true})
 configure(floors)
 for piece:Dictionary in pieces:piece.source100_coast_floor=true

func terrain_field()->Resource:
 assert(private_field!=null,"Private shore sampler requires an explicit prepared input")
 return private_field

func coordinate(x:float,z:float)->Vector2:return (Vector2(x,z)-Vector2(proposal.origin[0],proposal.origin[1]))/spacing

func native_data(scale_:float=1.3)->Dictionary:
 var origin=Vector3(proposal.origin[0],0,proposal.origin[1])
 var extent=(width-1)*spacing
 var result={"width":width,"spacing":spacing*scale_,"route_spacing":3.*scale_,"origin":origin*scale_,"bounds_min":origin*scale_,"bounds_max":(origin+Vector3(extent,0,extent))*scale_,"heights":heights.duplicate(),"covered":covered,"pieces":PackedFloat32Array(),"obstacle_min":PackedVector3Array(),"obstacle_max":PackedVector3Array()}
 for index in result.heights.size():result.heights[index]*=scale_
 for p:Dictionary in pieces:result.pieces.append_array(PackedFloat32Array([p.a.x*scale_,p.a.y*scale_,p.along.x,p.along.y,p.half*scale_,p.length*scale_,p.start*scale_,p.end*scale_,p.h0*scale_,p.h1*scale_]))
 for r:Array in proposal.source_closed:
  var a=point(Vector2(r[0]-.5,r[1]-.5),-10.);var b=point(Vector2(r[0]+r[2]-.5,r[1]+r[3]-.5),30.)
  result.obstacle_min.append(a.min(b)*scale_);result.obstacle_max.append(a.max(b)*scale_)
 return result

func physical_faces()->PackedVector3Array:
 var result=PackedVector3Array()
 for row:Array in proposal.source_cells:
  if not row[3]:continue
  var source=Vector2(row[0],row[1])
  var subdivisions=1 if int(row[2])==252 else 2
  for z in subdivisions:
   for x in subdivisions:
    var points=[]
    for corner:Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
     var p=point(source-Vector2.ONE*.5+(Vector2(x,z)+corner)/float(subdivisions))
     p.y=2. if int(row[2])==252 else height(p.x,p.z)
     points.append(p)
    for index in [0,1,2,0,2,3]:result.append(points[index])
 return result
