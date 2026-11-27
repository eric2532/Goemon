extends RefCounted
## Flat-roof limestone shells built from the same stone and timber as Falan.
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const SOURCE=preload("res://assets/maps/falan/coastal_village_data.gd")
const Buildings=preload("res://scripts/forest/forest_coastal_buildings.gd")
const Proportions=preload("res://scripts/forest/forest_falan_proportions.gd")
const WallBounds=preload("res://assets/maps/falan/kili_wall_proportions.gd")
const SHELLS={
 "kili_house":Vector3(10.8,8.1,8.6),
 "kili_tavern":Vector3(13.0,8.0,8.8),
 "kili_shop":Vector3(21.0,9.8,9.2),
 "kili_chief":Vector3(21.0,10.8,12.0),
 "ghana_hospital":Vector3(11.8,10.8,7.8),
}
const PALM="res://assets/models/environments/palm.glb"
const WELL="res://assets/models/cedar_pass/well.glb"

static var recovered_walls:Dictionary={}

static func wall_mesh_size(serial:int)->Vector3:
 var size_=wall_size(serial)
 # 11236 exposes the opposite stone face; its existing physical wall stays put.
 return Vector3(size_.z,size_.y,size_.x) if serial==11236 else size_

static func wall_key(serial:int)->Array:
 return [serial]

static func prepare_wall(serial:int)->Mesh:
 var key=wall_key(serial)
 if not recovered_walls.has(key):recovered_walls[key]=recovered_wall(serial)
 return recovered_walls[key]

static func batch_walls(parent:Node3D,groups:Dictionary):
 var prepared={}
 for serial in groups:prepared[serial]=prepare_wall(serial)
 batch_meshes(parent,groups,prepared,"NativeGhanaWall")

static func batch_meshes(parent:Node3D,groups:Dictionary,prepared:Dictionary,prefix:String):
 for serial in groups:
  var chunks={}
  for pose:Transform3D in groups[serial]:
   var key=Vector2i(floori(pose.origin.x/48),floori(pose.origin.z/48))
   if not chunks.has(key):chunks[key]=[]
   chunks[key].append(pose)
  for key in chunks:
   var node=MultiMeshInstance3D.new();node.name=prefix+"_%d_%d_%d"%[serial,key.x,key.y]
   var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
   multi.mesh=prepared[serial];multi.instance_count=chunks[key].size()
   for i in chunks[key].size():multi.set_instance_transform(i,chunks[key][i])
   node.multimesh=multi;node.set_meta("source_graphic",serial);parent.add_child(node)

static func wall_material()->Material:
 return Fort.material(Color("c9ad7f"))

static func wall_size(serial:int)->Vector3:
 if serial in [11235,11237,11238,11248,11249]:return Vector3(1.15,4.7,1.15)
 var along_x=serial in [11231,11239,11240,11241,11242,11254,11255,11256,11257,11258,11259,11260]
 return Vector3(3.0,3.25,.60) if along_x else Vector3(.60,3.25,3.0)

static func wall_plan(model,at:Vector2,serial:int)->Array:
 var p=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
 var size_=wall_size(serial)
 return ["coastal_wall",Transform3D(Basis.IDENTITY,p),AABB(p-Vector3(size_.x*.5,0,size_.z*.5),size_),serial]

static func wall(parent:Node3D,boxes,pose:Transform3D,serial:int):
 if serial in range(11230,11251):
  var column=serial in [11235,11237,11238,11248,11249]
  var key=wall_key(serial)
  var node=Geo.mesh(parent,prepare_wall(serial),Vector3.ZERO,null)
  node.transform=pose;node.name="RecoveredKiliColumn" if column else "RecoveredKiliWall"
  node.set_meta("kili_wall_graphic",serial);node.set_meta("kili_wall_key",key)
  return
 var village_stone=serial>=11252
 var stone=Fort.material(Color("d4d2b5") if village_stone else Color("cfb286"),false)
 var trim=Fort.material(Color("e3d8b4"),false)
 var size_=wall_size(serial)
 if serial in [11235,11237,11238,11248,11249]:
  var pillar=Node3D.new()
  pillar.name="ArchivedGateColumn_"+str(serial)
  pillar.transform=pose
  parent.add_child(pillar)
  Geo.cylinder(pillar,Vector3.UP*2.05,.53,4.1,stone)
  for height in [.12,.34,3.95,4.16]:Geo.cylinder(pillar,Vector3.UP*height,.66,.18,trim)
  for side in 4:
   var angle=side*PI*.5
   Geo.torus(pillar,Vector3(sin(angle)*.39,4.43,cos(angle)*.39),.12,.31,trim)
  return
 add(boxes,pose,Vector3.UP*size_.y*.5,size_,stone)
 add(boxes,pose,Vector3.UP*.23,Vector3(size_.x+.08,.46,size_.z+.08),Fort.material(Color("939b7e")))
 add(boxes,pose,Vector3.UP*3.27,Vector3(size_.x+.08,.18,size_.z+.08),trim)
 if serial in [11240,11242,11244,11246]:
  add(boxes,pose,Vector3.UP*3.47,Vector3(.78,.28,.78),trim)
 if serial in range(11252,11256) or serial==11261:
  add(boxes,pose,Vector3.UP*2.05,Vector3(.40,4.1,.40),Fort.material(Color("72583b"),false))

static func bounds(kind:String,pose:Transform3D)->AABB:
 if kind=="kili_palm":return pose*AABB(Vector3(-.35,0,-.35),Vector3(.7,7.0,.7))
 if kind=="ghana_well":return pose*AABB(Vector3(-1.9,0,-1.46),Vector3(3.8,4.01,2.92))
 var size:Vector3=SHELLS[kind]
 return pose*AABB(Vector3(-size.x*.5,0,-size.z*.5),size)

static func add(boxes,pose:Transform3D,point:Vector3,size:Vector3,material:Material):
 var box=pose*AABB(point-size*.5,size)
 boxes.add(box.get_center(),box.size,material)

static func shell(boxes,kind:String,pose:Transform3D,serial:int=0):
 var size:Vector3=SHELLS[kind]
 var wall=Fort.material(Color("e7e8dc") if kind=="ghana_hospital" else Color("e5cfa3"),false)
 var plinth=Fort.material(Color("baa078"))
 var cap=Fort.material(Color("b4c8c2") if kind=="ghana_hospital" else Color("f1d8ab"),false)
 var wood=Fort.material(Color("6e4b30"),false)
 var recess=Fort.material(Color("403b30"),false)
 var height=size.y-1.1
 var face=size.z*.5
 add(boxes,pose,Vector3(0,height*.5,0),Vector3(size.x,height,size.z),wall)
 add(boxes,pose,Vector3(0,.42,0),Vector3(size.x,.84,size.z),plinth)
 add(boxes,pose,Vector3(0,height-.15,0),Vector3(size.x,.48,size.z),cap)
 for side in [-1,1]:
  add(boxes,pose,Vector3(0,height+.35,side*(face-.21)),Vector3(size.x,1.1,.42),wall)
  add(boxes,pose,Vector3(side*(size.x*.5-.21),height+.35,0),Vector3(.42,1.1,size.z),wall)
  add(boxes,pose,Vector3(side*size.x*.32,height*.6,face+.018),Vector3(1.5,1.75,.038),recess)
  add(boxes,pose,Vector3(side*size.x*.32,height*.6-.87,face+.10),Vector3(1.78,.16,.26),cap)
  add(boxes,pose,Vector3(side*1.16,1.82,face+.09),Vector3(.23,3.64,.21),plinth)
 add(boxes,pose,Vector3(0,1.72,face+.017),Vector3(2.1,3.44,.035),recess)
 add(boxes,pose,Vector3(0,3.57,face+.13),Vector3(2.6,.30,.30),cap)
 if (kind=="kili_shop" and serial==0) or kind=="kili_tavern":
  var cloth=Fort.material(Color("a45239") if kind=="kili_tavern" else Color("84754a"),false)
  add(boxes,pose,Vector3(0,4.3,face+.55),Vector3(size.x*.55,.29,1.3),cloth)
  for side in [-1,1]:
   add(boxes,pose,Vector3(side*size.x*.24,2.14,face+.46),Vector3(.20,4.28,.20),wood)
 if kind=="kili_chief":
  add(boxes,pose,Vector3(0,height+.55,0),Vector3(size.x*.57,2.6,size.z*.69),wall)
  add(boxes,pose,Vector3(0,height+1.9,0),Vector3(size.x*.59,.34,size.z*.72),cap)
 if kind=="ghana_hospital":
  for side in [-1,1]:
   var tower=Vector3(side*size.x*.33,height,face-1.25)
   add(boxes,pose,tower,Vector3(2.3,4.5,2.3),wall)
   add(boxes,pose,tower+Vector3.UP*2.35,Vector3(2.65,.5,2.65),cap)
   add(boxes,pose,tower+Vector3.UP*3.05,Vector3(1.2,1.4,1.2),wall)
  add(boxes,pose,Vector3(0,5.3,face+.04),Vector3(.42,1.65,.11),wood)
  add(boxes,pose,Vector3(0,5.3,face+.04),Vector3(1.65,.42,.11),wood)


static func recovered_wall(serial:int)->Mesh:
 var skin=Buildings.SourceMesh.new([Rect2(),Vector2.ZERO,Vector2.ONE,0],Buildings.KiliAtlas,.045)
 skin.tiles=Buildings.KiliSurfaces.TILES
 var size_=wall_mesh_size(serial)
 if serial in [11235,11237,11238,11248,11249]:
  skin.part="wall"
  Buildings.kili_round(skin,Vector3.ZERO,[Vector2(.54,0),Vector2(.62,.12),Vector2(.62,.24),Vector2(.49,.37),Vector2(.49,3.94),Vector2(.56,4.10),Vector2(.64,4.23),Vector2(.56,4.37)])
  skin.part="trim"
  Buildings.kili_round(skin,Vector3.ZERO,[Vector2(.62,.12),Vector2(.62,.24),Vector2(.49,.37)])
  for i in 4:
   var a=i*PI*.5
   Buildings.kili_round(skin,Vector3(cos(a)*.26,4.28,sin(a)*.26),[Vector2(.18,0),Vector2(.27,.12),Vector2(.26,.25),Vector2(.17,.34),Vector2(.03,.34)])
  # Native 11237/11238 include opposite attached wall ends below the capital.
  if serial in [11237,11238]:
   var corner=Vector3(.38,0,-.28) if serial==11237 else Vector3(-.28,0,-1.50)
   var span=Vector3(1.12,3.25,.56) if serial==11237 else Vector3(.56,3.25,1.12)
   skin.part="wall";skin.box(AABB(corner,span))
   skin.part="trim";skin.box(AABB(corner+Vector3(-.04,3.18,-.04),Vector3(span.x+.08,.18,span.z+.08)))
 else:
  skin.part="wall";skin.box(AABB(Vector3(-size_.x*.5,0,-size_.z*.5),size_))
  skin.part="stone";skin.box(AABB(Vector3(-size_.x*.5-.04,0,-size_.z*.5-.04),Vector3(size_.x+.08,.46,size_.z+.08)))
  skin.part="trim";skin.box(AABB(Vector3(-size_.x*.5-.04,3.18,-size_.z*.5-.04),Vector3(size_.x+.08,.18,size_.z+.08)))
  if serial in [11240,11242,11244,11246]:skin.box(AABB(Vector3(-.39,3.33,-.39),Vector3(.78,.28,.78)))
 var raw=skin.finish(true)
 var fit=Proportions.measure(Proportions.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),WallBounds.RECTS[serial])
 var result=Proportions.transformed(raw,fit)
 # Preserve the established tile density after fitting the larger native forms.
 assert(result.get_surface_count()==1,"The shared wall kit has one native tile surface")
 var arrays:Array=result.get_meta("source_surface_arrays").duplicate(true)
 var normals:PackedVector3Array=raw.get_meta("source_surface_arrays")[Mesh.ARRAY_NORMAL]
 var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var scale_=fit.basis.get_scale()
 for i in uv.size():
  uv[i].x*=scale_.x
  uv[i].y*=sqrt(scale_.y*scale_.y*(1-normals[i].y*normals[i].y)+scale_.x*scale_.x*normals[i].y*normals[i].y)
 arrays[Mesh.ARRAY_TEX_UV]=uv
 var painted=ArrayMesh.new();painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);painted.surface_set_material(0,result.surface_get_material(0))
 return painted
