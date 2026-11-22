extends RefCounted
## Original scenery for the existing boss-room layout. Navigation owns all collision.
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Water=preload("res://scripts/forest/forest_falken_channel.gdshader")
const WATER_TILE=23 # Water surface slot in the current room's floor plane.
const WATER_LEVEL=-.32
const GATE_MARKER=17090
const PLINTH_MARKER=17110
const BASIN_MARKER=16328
const SIDES=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
static var gate_mesh:Mesh
static var plinth_mesh:Mesh
static var basin_mesh:Mesh

static func water_mask(floors:PackedByteArray)->PackedByteArray:
 var mask=PackedByteArray()
 mask.resize(floors.size())
 for i in range(0,floors.size(),2):
  if floors.decode_u16(i)==WATER_TILE:mask[i]=1
 return mask

static func water_material()->ShaderMaterial:
 var material=ShaderMaterial.new()
 material.shader=Water
 return material

static func shore(boxes,center:Vector2,outward:Vector2i,cell:Vector2i,mask:PackedByteArray,size:Vector2i):
 var tangent=Vector2(outward).orthogonal()
 var edge=center+Vector2(outward)*1.35
 # The east/west banks own the corner blocks, so perpendicular coping never overlaps.
 var start=-1.49
 var end=1.49
 if outward.y!=0:
  if not is_water(mask,size,cell-Vector2i(tangent)):start+=.31
  if not is_water(mask,size,cell+Vector2i(tangent)):end-=.31
 var width=end-start
 var mid=edge+tangent*((start+end)*.5)
 var lining=Vector3(.30,.57,width) if outward.x!=0 else Vector3(width,.57,.30)
 boxes.add(Vector3(mid.x,-.31,mid.y),lining,Fort.material(Color("424d4b"),false))
 var sill=Vector3(.30,.12,width/3.0-.02) if outward.x!=0 else Vector3(width/3.0-.02,.12,.30)
 for brick in 3:
  var at=mid+tangent*((brick-1)*width/3.0)
  var shade="9aada6" if (cell.x+cell.y+brick)%3==0 else "7b928c"
  boxes.add(Vector3(at.x,.025,at.y),sill,Fort.material(Color(shade),false))

static func is_water(mask:PackedByteArray,size:Vector2i,cell:Vector2i)->bool:
 return Rect2i(Vector2i.ZERO,size).has_point(cell) and mask[(cell.y*size.x+cell.x)*2]!=0

static func crossing(boxes,center:Vector2):
 # The existing walk grid carries these crossings at the floor's height.
 var paving=Fort.material(Color("717e79"),false)
 for slab in 4:
  var x=center.x+(slab-1.5)*.75
  boxes.add(Vector3(x,-.06,center.y),Vector3(.73,.17,2.99),paving)

static func gate(parent:Node3D,at:Vector2):
 if gate_mesh==null:
  Parts.prepare_primitives()
  var stone=Furniture.tool()
  var iron=Furniture.tool()
  var bronze=Furniture.tool()
  for side in [-1,1]:
   var x=side*2.54
   for band in [[.13,.26,.65],[1.60,2.72,.40],[3.04,.16,.58],[3.19,.14,.70]]:
    Furniture.rounded_block(stone,Vector3(x,band[0],0),Vector3(band[2],band[1],band[2]),.06)
   for y in [.57,2.66]:
    Parts.block(bronze,Vector3(x,y,0),Vector3(.44,.11,.44))
  for y in [.25,.63,2.52,2.94]:
   Parts.block(iron,Vector3(0,y,0),Vector3(4.82,.12,.20))
  for column in range(-5,6):
   var x=column*.43
   Parts.rod(iron,Vector3(x,.24,0),Vector3(x,2.98,0),.065)
   for y in [.63,2.52]:Parts.oval(bronze,Vector3(x,y,0),Vector3(.16,.17,.27))
  for x in [-1.72,-.86,0.0,.86,1.72]:
   var points=[Vector3(x,2.34,0),Vector3(x+.40,1.65,0),Vector3(x,.96,0),Vector3(x-.40,1.65,0)]
   for side in 4:Parts.rod(bronze,points[side],points[(side+1)%4],.045)
  gate_mesh=Furniture.finish([stone,iron,bronze],[Fort.material(Color("747c79"),false),Geo.mat("32484b",.62),Geo.mat("9f744a",.58)])
 Geo.mesh(parent,gate_mesh,Vector3(at.x,0,at.y),null).name="ChamberForgedGate"

static func plinth(parent:Node3D,at:Vector2)->MeshInstance3D:
 if plinth_mesh==null:
  Parts.prepare_primitives()
  var stone=Furniture.tool()
  var brass=Furniture.tool()
  var glass=Furniture.tool()
  for band in [[.07,.14,.94],[.22,.16,.77],[.51,.44,.56],[.80,.14,.72]]:
   Furniture.rounded_block(stone,Vector3(0,band[0],0),Vector3(band[2],band[1],band[2]),.11)
  Parts.block(brass,Vector3(0,.70,0),Vector3(.63,.057,.63))
  Parts.oval(glass,Vector3(0,.91,0),Vector3(.33,.27,.33))
  plinth_mesh=Furniture.finish([stone,brass,glass],[Fort.material(Color("b4b7a3"),false),Geo.mat("9f744a",.58),Geo.mat("59a995",.16,.28)])
 var node=Geo.mesh(parent,plinth_mesh,Vector3(at.x,0,at.y),null)
 node.name="ChamberStonePlinth"
 return node

static func basins(parent:Node3D,poses:Array[Transform3D]):
 if poses.is_empty():return
 if basin_mesh==null:
  Parts.prepare_primitives()
  var stone=Furniture.tool()
  var metal=Furniture.tool()
  Furniture.rounded_block(stone,Vector3.UP*.09,Vector3(1.10,.18,1.10),.19)
  Furniture.rounded_block(stone,Vector3.UP*.23,Vector3(.95,.14,.95),.14)
  var ring=TorusMesh.new()
  ring.inner_radius=.26
  ring.outer_radius=.35
  ring.rings=12
  ring.ring_segments=6
  metal.append_from(ring,0,Transform3D(Basis.IDENTITY,Vector3.UP*.30))
  for angle in [0.0,PI/3.0,-PI/3.0]:
   var direction=Vector3(cos(angle),0,sin(angle))*.26
   Parts.rod(metal,Vector3.UP*.31-direction,Vector3.UP*.31+direction,.025)
  basin_mesh=Furniture.finish([stone,metal],[Fort.material(Color("78827d"),false),Geo.mat("665743",.48)])
 var node=MultiMeshInstance3D.new()
 node.name="ChamberSluiceCovers"
 node.multimesh=MultiMesh.new()
 node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
 node.multimesh.mesh=basin_mesh
 node.multimesh.instance_count=poses.size()
 for i in poses.size():node.multimesh.set_instance_transform(i,poses[i])
 parent.add_child(node)
