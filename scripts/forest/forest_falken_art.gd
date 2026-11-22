extends RefCounted
const Route=preload("res://scripts/forest/forest_falken_route.gd")
const Data=Route.Data
const Floor=preload("res://assets/maps/falan/falken/floors.png")
const Walls=preload("res://assets/maps/falan/falken/walls.png")
const Atlas=preload("res://assets/maps/falan/falken/props.png")
const Chamber=preload("res://scripts/forest/forest_falken_chamber.gd")
const ChamberProps=preload("res://scripts/forest/forest_falken_chamber_props.gd")
const Dais=preload("res://scripts/forest/forest_falken_dais.gd")
const PILLARS=[17361,17363,17365,17367,17368,17369]
static var material:ShaderMaterial
static var meshes={}
static var stairs_materials={}
static var boundary_texture:Texture2D
static var wall_caps={}
static func wall_cap(tile:int)->Material:
 var color:Color=Data.WALL_CAPS[tile-1]
 if not wall_caps.has(color):
  var cap=ShaderMaterial.new();cap.shader=preload("res://scripts/forest/forest_painterly_surface.gdshader")
  var image=Image.create(1,1,false,Image.FORMAT_RGB8);image.fill(color)
  cap.set_shader_parameter("base_texture",ImageTexture.create_from_image(image))
  cap.set_shader_parameter("use_base_texture",true);cap.set_shader_parameter("use_vertex_color",false)
  cap.set_shader_parameter("original_palette",true);wall_caps[color]=cap
 return wall_caps[color]
static func stair_mesh(serial:int)->Mesh:
 var key="stair-"+str(serial)
 if meshes.has(key):return meshes[key]
 var parts=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
 var stone=parts.tool()
 if serial==12002:
  for side in [-1,1]:
   parts.rounded_block(stone,Vector3(side*1.36,-.59,0),Vector3(.28,1.31,3),.025)
   for slab in 4:parts.rounded_block(stone,Vector3(side*1.36,.037,-1.125+slab*.75),Vector3(.28,.12,.73),.035)
  for slab in 3:
   parts.rounded_block(stone,Vector3((slab-1)*.813,.013,1.44),Vector3(.79,.10,.12),.025)
   parts.rounded_block(stone,Vector3((slab-1)*.813,-.59,-1.38),Vector3(.81,1.30,.24),.025)
   parts.rounded_block(stone,Vector3((slab-1)*.813,.037,-1.36),Vector3(.79,.12,.28),.035)
 for step in (4 if serial==12002 else 5):
  var down=serial==12002
  var top=-.08-step*.26 if down else 1.62*(step+1)/5
  var depth=.64 if down else .62
  var z=1.14-step*.59 if down else 1.5-.6*(step+.5)
  var height=.14 if down else top-.06
  var width=2.4 if down else 2.68
  parts.rounded_block(stone,Vector3(0,top-.06-height*.5,z),Vector3(width,height,depth),.035)
  var count=3+step%2
  var span=(2.39 if down else 2.78)/count
  for slab in count:
   parts.rounded_block(stone,Vector3((slab-(count-1)*.5)*span,top-.04,z+(.0 if down else .018)),Vector3(span-.018,.115,.61 if down else .69),.035)
 var tools=[stone];var materials=[stairs_materials[serial]]
 if serial==12002:
  var dark=parts.tool();parts.rounded_block(dark,Vector3(0,-1.22,0),Vector3(2.44,.12,2.76),.025)
  tools.append(dark);materials.append(Geo.mat("211e19"))
 meshes[key]=parts.finish(tools,materials)
 return meshes[key]
static func boundary_paint()->Texture2D:
 if boundary_texture==null:
  var tile=(Data.TOWER_WALL-1)*2
  boundary_texture=ImageTexture.create_from_image(Walls.get_image().get_region(Rect2i(tile%16*36+2,tile/16*100+2,32,96)))
 return boundary_texture
static func floor_tiles(_id:int,size:Vector2i)->PackedByteArray:
 var bytes=PackedByteArray();bytes.resize(size.x*size.y*2)
 for i in size.x*size.y:bytes.encode_u16(i*2,Data.TOWER_FLOOR)
 return bytes
static func wall_tiles(_id:int,size:Vector2i,bits:PackedByteArray)->PackedByteArray:
 var bytes=PackedByteArray();bytes.resize(size.x*size.y*2)
 for z in size.y:
  for x in size.x:
   var i=z*size.x+x
   if (bits[i>>3]&(1<<(i&7)))!=0:continue
   for step:Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
    var cell=Vector2i(x,z)+step
    if not Rect2i(Vector2i.ZERO,size).has_point(cell):continue
    var other=cell.y*size.x+cell.x
    if (bits[other>>3]&(1<<(other&7)))!=0:bytes.encode_u16(i*2,Data.TOWER_WALL);break
 return bytes
static func batch(parent:Node3D,serial:int,poses:Array):
 if material==null:
  material=ShaderMaterial.new();material.shader=preload("res://scripts/forest/sokia_scenery.gdshader")
  material.set_shader_parameter("source_art",Atlas)
 if not meshes.has(serial):
  var rect:Rect2i=Data.GRAPHICS[serial]
  var quad=QuadMesh.new();quad.size=Vector2(rect.size)*.031
  var arrays=quad.surface_get_arrays(0)
  for i in arrays[Mesh.ARRAY_TEX_UV].size():arrays[Mesh.ARRAY_TEX_UV][i]=(Vector2(rect.position)+arrays[Mesh.ARRAY_TEX_UV][i]*Vector2(rect.size))/Atlas.get_size()
  var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);meshes[serial]=mesh
  if serial==16328 or serial in PILLARS:
   var skin=preload("res://scripts/forest/forest_coastal_mesh.gd").new([Rect2(rect),Data.ORIGINS[serial],Vector2.ONE,0],Atlas,.031)
   var shapes=preload("res://scripts/forest/forest_coastal_buildings.gd")
   if serial==16328:
    skin.box(AABB(Vector3(-.78,0,-.78),Vector3(1.56,.19,1.56)))
    for x in [-.55,.55]:
     for z in [-.55,.55]:shapes.kili_round(skin,Vector3(x,.19,z),[Vector2(.18,0),Vector2(.22,.08),Vector2(.11,.20),Vector2(.10,.63),Vector2(.20,.69),Vector2(.12,.79)])
   else:
    skin.box(AABB(Vector3(-.55,0,-.55),Vector3(1.1,.16,1.1)))
    shapes.kili_round(skin,Vector3.ZERO,[Vector2(.46,.16),Vector2(.36,.25),Vector2(.25,.34),Vector2(.25,3.88),Vector2(.34,3.96),Vector2(.39,4.07),Vector2(.48,4.17)])
    skin.box(AABB(Vector3(-.48,4.17,-.48),Vector3(.96,.16,.96)))
    var arms=[Vector3.LEFT] if serial==17361 else [Vector3.RIGHT] if serial in [17365,17368] else [Vector3.RIGHT,Vector3.FORWARD] if serial==17369 else []
    for arm:Vector3 in arms:
     for band in [[1.10,.32,.30],[1.34,.13,.42],[1.48,.10,.48]]:
      var size_=Vector3(1.24,band[1],band[2]) if arm.x!=0 else Vector3(band[2],band[1],1.24)
      skin.box(AABB(arm*.88+Vector3.UP*band[0]-size_*.5,size_))
   skin.surface.generate_normals();meshes[serial]=skin.finish()
 var node=MultiMeshInstance3D.new();node.name="FalkenNativeProp_"+str(serial);node.material_override=material
 if serial==16328 or serial in PILLARS:node.material_override=null
 node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=meshes[serial]
 node.multimesh.instance_count=poses.size()
 for i in poses.size():node.multimesh.set_instance_transform(i,poses[i])
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node)
static func build(parent:Node3D,id:int,run_seed:int=0):
 if id in Route.FLOORS:
  var points:Array=Route.maze(id,run_seed).stairs
  for i in 2:
   var serial=12002 if i==0 else 12000
   if not stairs_materials.has(serial):
    var texture=ImageTexture.create_from_image(Atlas.get_image().get_region(Data.STAIR_PATCHES[serial]))
    var material_=preload("res://scripts/forest/forest_coastal_mesh.gd").material(texture).duplicate()
    material_.set_shader_parameter("archive_triplanar",true);material_.set_shader_parameter("uv_scale",Vector2(.67,.95))
    material_.set_shader_parameter("original_palette",false);material_.set_shader_parameter("alpha_cutout",false)
    stairs_materials[serial]=material_
   preload("res://scripts/forest/forest_habaru_stairs.gd").build(parent,id,points[i],Route.point(id,points[i]),serial,stairs_materials[serial],stair_mesh(serial))
  return
 var groups={}
 var chamber_props={}
 var basin_poses:Array[Transform3D]=[]
 var chamber_mask:PackedByteArray
 var size:Vector2i=Data.ROOMS[id][0]
 if id==Route.ROOM:
  Dais.build(parent)
  var floor_plane=Marshalls.base64_to_raw(Data.FLOORS[id]).decompress(size.x*size.y*2,FileAccess.COMPRESSION_DEFLATE)
  chamber_mask=Chamber.water_mask(floor_plane)
 for row in Data.PROPS[id]:
  var at=Route.point(id,row[0])+Vector2(row[2]-Vector2i.ONE)*Vector2(1.5,-1.5)
  if id==Route.ROOM:
   if row[1]==Chamber.GATE_MARKER:
    Chamber.gate(parent,at)
    continue
   if row[1]==Chamber.PLINTH_MARKER:
    var plinth=Chamber.plinth(parent,at)
    plinth.position.y=Dais.height(at.x,at.y)
    continue
   if row[1]==Chamber.BASIN_MARKER:
    var level=Chamber.WATER_LEVEL if Chamber.is_water(chamber_mask,size,row[0]) else 0.0
    basin_poses.append(Transform3D(Basis.IDENTITY,Vector3(at.x,level,at.y)))
    continue
   if row[1]>=16305 and row[1]<=16323:continue # The channel and its banks share continuous geometry.
   if ChamberProps.FAMILIES.has(row[1]):
    var family:String=ChamberProps.FAMILIES[row[1]]
    if not chamber_props.has(family):chamber_props[family]=[]
    var placement=ChamberProps.pose(family,at)
    placement.origin.y=Dais.height(placement.origin.x,placement.origin.z)
    chamber_props[family].append(placement)
    continue
  if not groups.has(row[1]):groups[row[1]]=[]
  groups[row[1]].append(Transform3D(Basis.IDENTITY,Vector3(at.x,0 if row[1]==16328 or row[1] in PILLARS else Data.GRAPHICS[row[1]].size.y*.0155,at.y)))
 for serial in groups:batch(parent,serial,groups[serial])
 for family in chamber_props:ChamberProps.batch(parent,family,chamber_props[family])
 if id==Route.ROOM:Chamber.basins(parent,basin_poses)
 var npcs=[[Vector2i(21,18),14193],[Vector2i(35,21),14197]] if id==23000 else [[Vector2i(25,27),14195]] if id==Route.ROOM else []
 for row in npcs:
  var at=Route.point(id,row[0]);batch(parent,row[1],[Transform3D(Basis.IDENTITY,Vector3(at.x,Data.GRAPHICS[row[1]].size.y*.0155,at.y))])
static func desert_guide(parent:Node3D,model,frame:Transform2D):
 var at=frame.inverse()*Route.ANCIENT+Vector2(0,-3)
 batch(parent,14526,[Transform3D(Basis.IDENTITY,Vector3(at.x,model.surface_height(at.x,at.y)+Data.GRAPHICS[14526].size.y*.0155,at.y))])
