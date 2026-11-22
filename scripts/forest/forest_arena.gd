extends "res://scripts/forest/forest_wind_meadow_terrain.gd"
## Falan's archived main arena, recentered for four-sided native survival waves.
const ID="arena"
const Room=preload("res://scripts/forest/forest_falan_room_art.gd")
const SOURCE_SIZE=Vector2i(70,150)
const SOURCE_ORIGIN=Vector2(-105,-222)
const CENTER=Vector2(1.5,124.5)
const CROP=Rect2i(0,90,70,60)
const GATE_HALF_WIDTH=27.0
# Shallow original steps keep the existing native slime footprint traversable.
const RISE_SCALE=.2
const WALL_HEIGHT=80.0
const PAD_RISE=6.0
const CARVE_DEPTH=1.5
const INLAY_SIZE=13.52
const INLAY_GRID=256
static var fields:Dictionary={}
static var carved_inlays:ArrayMesh
static var floor_index:ImageTexture
static var floor_image:Image
static var walls:PackedByteArray
static var wall_details:Array[ArrayMesh]=[]
func floor_radius()->float:return arena_bounds().size.x*.5
func wall_height()->float:return WALL_HEIGHT*horizontal_scale
func arena_bounds()->Rect2:
 var scale_=horizontal_scale*2.0
 return Rect2((SOURCE_ORIGIN+Vector2(CROP.position)*3.0-CENTER-Vector2.ONE*1.5)*scale_,Vector2(CROP.size)*3.0*scale_)
func uses_baked_geometry()->bool:return false
func uses_baked_apron()->bool:return false
static func entrance(p:Vector2)->bool:
 return absf(p.x)<GATE_HALF_WIDTH or absf(p.y)<GATE_HALF_WIDTH
static func source_height(p:Vector2)->float:
 # Sample the archived floor's original triangle vertices, including its platforms.
 var grid=(p-SOURCE_ORIGIN+Vector2.ONE*1.5)/3.0
 var cell=grid.floor();var uv=grid-cell
 var low=SOURCE_ORIGIN+(cell-Vector2.ONE*.5)*3.0
 var h00=Room.Arena.surface_height(1401,low.x,low.y)
 var h10=Room.Arena.surface_height(1401,low.x+3,low.y)
 var h01=Room.Arena.surface_height(1401,low.x,low.y+3)
 var h11=Room.Arena.surface_height(1401,low.x+3,low.y+3)
 var height=h00+(h10-h00)*uv.x+(h11-h10)*uv.y if uv.x>=uv.y else h00+(h11-h01)*uv.x+(h01-h00)*uv.y
 for row in Room.Arena.Data.ARENA_MARKS:
  if row[0].y<90:continue
  var center=SOURCE_ORIGIN+Vector2(row[0])*3.0
  var q=(p-center).abs()
  var edge=maxf(maxf(q.x,q.y),(q.x+q.y)*.707107-3.0)
  height+=PAD_RISE*clampf((11.0-edge)/4.0,0.0,1.0)
 return height
static func prepare():
 if floor_index!=null:return
 var tiles=Room.floor_tiles(1401,SOURCE_SIZE)
 walls=Room.wall_tiles(1401,SOURCE_SIZE)
 var image=Image.create(CROP.size.x,CROP.size.y,false,Image.FORMAT_RGBA8)
 var entry_tile=tiles.decode_u16((138*SOURCE_SIZE.x+36)*2)-1
 for z in SOURCE_SIZE.y:
  for x in SOURCE_SIZE.x:
   var index=z*SOURCE_SIZE.x+x
   var p=SOURCE_ORIGIN+Vector2(x,z)*3.0-CENTER
   if not CROP.has_point(Vector2i(x,z)) or entrance(p):walls.encode_u16(index*2,0)
   if not CROP.has_point(Vector2i(x,z)):continue
   var tile=tiles.decode_u16(index*2)-1
   if tile<0 and entrance(p):tile=entry_tile
   if tile<0:continue
   image.set_pixel(x-CROP.position.x,z-CROP.position.y,Color(float(tile%32)/255.0,float(int(tile/32))/255.0,0,1))
 floor_image=image
 floor_index=ImageTexture.create_from_image(image)
func terrain_field()->Resource:
 prepare()
 var key=Vector2(horizontal_scale,expansion)
 if fields.has(key):return fields[key]
 var count=roundi(160*horizontal_scale*expansion)+1
 var values=PackedFloat32Array();values.resize(count*count)
 var coverage=PackedByteArray();coverage.resize(values.size())
 var scale_=horizontal_scale*2.0
 var extent=240*horizontal_scale*expansion
 var bounds=arena_bounds()
 for z in count:
  for x in count:
   var world=Vector2(x*3.0-extent,z*3.0-extent)
   var source=world/scale_+CENTER
   var tile=Vector2i(((source-SOURCE_ORIGIN)/3.0+Vector2.ONE*.5).floor())
   var at=z*count+x
   if not bounds.has_point(world) or not CROP.has_point(tile):continue
   var pixel=floor_image.get_pixel(tile.x-CROP.position.x,tile.y-CROP.position.y)
   if pixel.a<.5:
    values[at]=10.0*scale_*RISE_SCALE;coverage[at]=1;continue
   coverage[at]=1
   values[at]=source_height(source)*scale_*RISE_SCALE
   if walls.decode_u16((tile.y*SOURCE_SIZE.x+tile.x)*2)>0:values[at]=10.0*scale_*RISE_SCALE
 var bridge=PackedByteArray();bridge.resize(values.size())
 var result=Resource.new();result.set_meta("width",count);result.set_meta("spacing",3.0);result.set_meta("heights",values);result.set_meta("covered",coverage);result.set_meta("bridges",bridge)
 fields[key]=result
 return result
static func build(world,parent:Node3D,ground:ShaderMaterial):
 prepare()
 var scale_:float=world.model.terrain_scale*2.0
 var bounds:Rect2=world.model.terrain.arena_bounds()
 ground.set_shader_parameter("use_city_paving",true)
 ground.set_shader_parameter("city_paving_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y))
 ground.set_shader_parameter("city_paving_index",floor_index)
 ground.set_shader_parameter("city_paving_atlas",Room.Atlas)
 ground.set_shader_parameter("arena_floor",true)
 var root=Node3D.new();root.name="FalanSurvivalArena";root.scale=Vector3(scale_,scale_*RISE_SCALE,scale_);root.position=Vector3(-CENTER.x,0,-CENTER.y)*scale_;root.set_meta("native_terrain",true);parent.add_child(root)
 var boxes=Room.Arena.Boxes.new()
 Room.build_walls(root,boxes,walls,SOURCE_SIZE,SOURCE_ORIGIN,1.55,Rect2i())
 Room.build_fixtures(root,boxes,1401,SOURCE_ORIGIN,Rect2i(0,0,70,90))
 var inlays=Room.painted_atlas(preload("res://assets/maps/falan/arena_inlays_detail.png"))
 inlays.set_shader_parameter("alpha_cutout",true)
 inlays.set_shader_parameter("inlay_carving",true)
 Room.Arena.build_rooms(root,boxes,1401,SOURCE_ORIGIN,inlays,true)
 var emblems=root.get_node("FalanArenaInlays")
 # Shallow decorative cuts retain the smooth shared player/native support plane.
 emblems.mesh=carved_inlay_mesh()
 emblems.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
 var cutouts=PackedVector4Array()
 for row in Room.Arena.Data.ARENA_MARKS:
  if row[0].y<90:continue
  var at=(SOURCE_ORIGIN+Vector2(row[0])*3.0-CENTER)*scale_
  cutouts.append(Vector4(at.x,at.y,INLAY_SIZE*scale_*.5,0))
 ground.set_shader_parameter("arena_inlay_cutouts",cutouts)
 boxes.build(root)
 build_enclosure(world,parent)

static func carved_inlay_mesh()->ArrayMesh:
 if carved_inlays!=null:return carved_inlays
 var depth=preload("res://assets/maps/falan/arena_carving_depth.png").get_image()
 assert(depth.get_size()==Vector2i(INLAY_GRID,INLAY_GRID),"Rebuild arena carving depth and refresh Godot imports")
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedColorArray();var indices=PackedInt32Array()
 var step=INLAY_SIZE/(INLAY_GRID-1)
 for row in Room.Arena.Data.ARENA_MARKS:
  if row[0].y<90:continue
  var origin=SOURCE_ORIGIN+Vector2(row[0])*3.0
  var top=Room.Arena.surface_height(1401,origin.x,origin.y)+PAD_RISE+.047
  var start=vertices.size()
  for z in INLAY_GRID:
   for x in INLAY_GRID:
    var uv=Vector2(x,z)/(INLAY_GRID-1)
    var amount=depth.get_pixel(x,z).r
    var p=origin+(uv-Vector2.ONE*.5)*INLAY_SIZE
    vertices.append(Vector3(p.x,top-CARVE_DEPTH*amount,p.y))
    var dx=depth.get_pixel(mini(x+1,INLAY_GRID-1),z).r-depth.get_pixel(maxi(x-1,0),z).r
    var dz=depth.get_pixel(x,mini(z+1,INLAY_GRID-1)).r-depth.get_pixel(x,maxi(z-1,0)).r
    normals.append(Vector3(CARVE_DEPTH*dx,step*2,CARVE_DEPTH*dz).normalized())
    uvs.append(Vector2((row[1]+lerpf(.5/INLAY_GRID,1.0-.5/INLAY_GRID,uv.x))/5.0,uv.y))
    colors.append(Color(amount,amount,amount,1))
  for z in INLAY_GRID-1:
   for x in INLAY_GRID-1:
    var i=start+z*INLAY_GRID+x
    indices.append_array(PackedInt32Array([i,i+1,i+INLAY_GRID,i+1,i+INLAY_GRID+1,i+INLAY_GRID]))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 carved_inlays=ArrayMesh.new();carved_inlays.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return carved_inlays

static func wall_boxes(terrain)->Array:
 var bounds:Rect2=terrain.arena_bounds()
 var scale_:float=terrain.horizontal_scale
 var height:float=terrain.wall_height()
 var gap=GATE_HALF_WIDTH*scale_*2
 var door=24.0*scale_
 var depth=6.0*scale_
 var result=[]
 for side in [-1,1]:
  var z=bounds.position.y-depth if side<0 else bounds.end.y
  var x=bounds.position.x-depth if side<0 else bounds.end.x
  for span in [Vector2(bounds.position.x,-gap),Vector2(gap,bounds.end.x)]:
   result.append(AABB(Vector3(span.x,0,z),Vector3(span.y-span.x,height,depth)))
  result.append(AABB(Vector3(-gap,door,z),Vector3(gap*2,height-door,depth)))
  for span in [Vector2(bounds.position.y,-gap),Vector2(gap,bounds.end.y)]:
   result.append(AABB(Vector3(x,0,span.x),Vector3(depth,height,span.y-span.x)))
  result.append(AABB(Vector3(x,door,-gap),Vector3(depth,height-door,gap*2)))
 return result

static func build_enclosure(world,parent:Node3D):
 var root=Node3D.new();root.name="ArenaOpenSkyWalls";root.set_meta("native_terrain",true);parent.add_child(root)
 var terrain=world.model.terrain
 var bounds:Rect2=terrain.arena_bounds()
 var height:float=terrain.wall_height()
 var scale_:float=terrain.horizontal_scale
 var palette=Vector2i(walls.decode_u16((91*SOURCE_SIZE.x+8)*2),walls.decode_u16((94*SOURCE_SIZE.x+9)*2))
 assert(palette.x>0 and palette.y>0)
 var mesh=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var boxes=wall_boxes(terrain)
 world.model.set_meta("cave_combat_walls",boxes)
 for box:AABB in boxes:
  var horizontal=box.size.x>box.size.z
  var normal=Vector3(0,0,1 if box.position.z<bounds.position.y else -1) if horizontal else Vector3(1 if box.position.x<bounds.position.x else -1,0,0)
  var tangent=Vector3(normal.z,0,-normal.x)
  var width=box.size.x if horizontal else box.size.z
  var center=box.get_center()+normal*((box.size.z if horizontal else box.size.x)*.5-5*scale_)
  var across=maxi(1,roundi(width/(24*scale_)))
  for column in across:
   var tile=palette.y if column%3==0 or column==across-1 else palette.x
   var face=(tile-1)*2+int(normal.x!=0)
   var uv_origin=Vector2(face%16,face/16)*Vector2(36,100)+Vector2(2.5,2.5)
   for uv:Vector2 in [Vector2.ZERO,Vector2.ONE,Vector2.RIGHT,Vector2.ZERO,Vector2.DOWN,Vector2.ONE]:
    var v=(box.position.y+uv.y*box.size.y)/height
    mesh.set_uv2(Vector2(width/across,height))
    mesh.set_normal(normal);mesh.set_uv((uv_origin+Vector2(uv.x*31,(1-v)*95))/Room.WallAtlas.get_size())
    var u=(column+uv.x)/across
    mesh.add_vertex(Vector3(center.x,box.position.y+uv.y*box.size.y,center.z)+tangent*((u-.5)*width))
  var solid=preload("res://scripts/forest/forest_art.gd").solid(root,box.get_center(),box.size,1,"stone")
  solid.name="ArenaPerimeterCollision"
 var material=ShaderMaterial.new();material.shader=preload("res://scripts/forest/arena_wall.gdshader")
 material.set_shader_parameter("base_texture",Room.WallAtlas)
 material.set_shader_parameter("panel_size",Vector2(12,36))
 material.set_shader_parameter("roof_cutaway_height",height)
 var wall=Geo.mesh(root,mesh.commit(),Vector3.ZERO,material)
 wall.name="ArenaOriginalTextureWalls";wall.set_meta("archive_wall_tiles",palette)
 wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var trim=Room.Fort.material(Color("c5ad76"),false).duplicate()
 trim.set_shader_parameter("roof_cutaway_height",height)
 var coping=Room.Arena.Boxes.new()
 for side in [-1,1]:
  var z=bounds.position.y-3*scale_ if side<0 else bounds.end.y+3*scale_
  var x=bounds.position.x-3*scale_ if side<0 else bounds.end.x+3*scale_
  coping.add(Vector3(bounds.get_center().x,height,z),Vector3(bounds.size.x+12*scale_,2*scale_,6*scale_),trim,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
  coping.add(Vector3(x,height,bounds.get_center().y),Vector3(6*scale_,2*scale_,bounds.size.y),trim,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 coping.build(root)
 build_wall_details(root,terrain)
 build_gate_bays(root,terrain)

static func wall_detail_meshes()->Array[ArrayMesh]:
 if not wall_details.is_empty():return wall_details
 # Prepare the existing courtyard/keep recipes once, then share their static surfaces.
 var Court=Room.Arena.Court
 var Keep=Court.Keep
 for kind in 2:
  var source=Node3D.new()
  var boxes=Room.Arena.Boxes.new()
  if kind==0:
   source.scale=Vector3(.8,WALL_HEIGHT/12.46,.8)
   Court.buttress(source,boxes,Vector3.ZERO,Room.Fort.material(Color("c7bea3")),Room.Fort.material(Color("e0d5b6"),false),Room.Fort.material(Color("848973")))
  else:
   Keep.lancet(source,Vector3(0,34,-4.75),0,5.8,22,Room.Fort.material(Color("e0d5b6"),false))
   var flag=Node3D.new();flag.scale=Vector3.ONE*3.5;flag.position=Vector3(0,45,-4.45);source.add_child(flag)
   var flags=Room.Arena.Boxes.new()
   Keep.banner(flags,Vector3.ZERO,0,Room.Fort.material(Color("b69654"),false))
   flags.build(flag)
  boxes.build(source)
  var surfaces={}
  for node in source.find_children("*","GeometryInstance3D",true,false):
   var mesh:Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh
   var pose:Transform3D=node.transform
   var ancestor=node.get_parent()
   while ancestor!=source:pose=ancestor.transform*pose;ancestor=ancestor.get_parent()
   pose=source.transform*pose
   var material:Material=node.material_override
   if not surfaces.has(material):
    surfaces[material]=SurfaceTool.new();surfaces[material].begin(Mesh.PRIMITIVE_TRIANGLES)
   if node is MultiMeshInstance3D:
    for index in node.multimesh.instance_count:surfaces[material].append_from(mesh,0,pose*node.multimesh.get_instance_transform(index))
   else:surfaces[material].append_from(mesh,0,pose)
  var result=ArrayMesh.new()
  for material in surfaces:
   surfaces[material].commit(result);result.surface_set_material(result.get_surface_count()-1,material)
  wall_details.append(result);source.free()
 return wall_details

static func build_wall_details(parent:Node3D,terrain):
 var bounds:Rect2=terrain.arena_bounds()
 var scale_:float=terrain.horizontal_scale
 var height:float=terrain.wall_height()
 var meshes=[]
 for source:ArrayMesh in wall_detail_meshes():
  var mesh:ArrayMesh=source.duplicate()
  for surface in mesh.get_surface_count():
   var material:ShaderMaterial=mesh.surface_get_material(surface).duplicate()
   material.set_shader_parameter("roof_cutaway_height",height);mesh.surface_set_material(surface,material)
  meshes.append(mesh)
 var trim=Room.Fort.material(Color("c5ad76"),false).duplicate()
 trim.set_shader_parameter("roof_cutaway_height",height)
 var corners=Room.Arena.Boxes.new()
 for x in [bounds.position.x-3*scale_,bounds.end.x+3*scale_]:
  for z in [bounds.position.y-3*scale_,bounds.end.y+3*scale_]:corners.add(Vector3(x,height*.5,z),Vector3(6*scale_,height,6*scale_),trim)
 corners.build(parent)
 for box:AABB in wall_boxes(terrain):
  var horizontal=box.size.x>box.size.z
  var normal=Vector3(0,0,1 if box.position.z<bounds.position.y else -1) if horizontal else Vector3(1 if box.position.x<bounds.position.x else -1,0,0)
  var center=box.get_center()+normal*(box.size.z if horizontal else box.size.x)*.5
  var width=(box.size.x if horizontal else box.size.z)/scale_
  var root=Node3D.new();root.name="ArenaWallRelief%d"%parent.get_child_count()
  root.position=Vector3(center.x,0,center.z);root.rotation.y=atan2(normal.x,normal.z);root.scale=Vector3.ONE*scale_;parent.add_child(root)
  var boxes=Room.Arena.Boxes.new()
  for y in [28.0,60.0,78.0]:boxes.add(Vector3(0,y,-2.55),Vector3(width,1.1,4.9),trim)
  boxes.build(root)
  var bays=maxi(1,roundi(width/36.0))
  for kind in 2:
   if box.position.y>0 and kind==0:continue
   var count=(bays+1 if kind==0 else bays) if box.position.y==0 else 1
   var node=MultiMeshInstance3D.new();node.name="ArenaWallPillars" if kind==0 else "ArenaWallBanners"
   node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=meshes[kind];node.multimesh.instance_count=count
   for index in count:
    var x=lerpf(-width*.5+4.2,width*.5-4.2,float(index)/bays) if kind==0 else (index+.5)*width/bays-width*.5
    if box.position.y>0:x=0.0
    node.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,Vector3(x,0,-4.2 if kind==0 else 0)))
   root.add_child(node)

static func build_gate_bays(parent:Node3D,terrain):
 var scale_:float=terrain.horizontal_scale
 var bounds:Rect2=terrain.arena_bounds()
 var half=GATE_HALF_WIDTH*2.0
 var stone=Room.Fort.material(Color("929481")).duplicate()
 var trim=Room.Fort.material(Color("c5ad76"),false).duplicate()
 var timber=Room.Fort.material(Color("494035"),false).duplicate()
 var iron=Room.Fort.material(Color("343936"),false).duplicate()
 for material in [stone,trim,timber,iron]:material.set_shader_parameter("roof_cutaway_height",terrain.wall_height())
 for entry in [[Vector2(0,bounds.position.y),PI,"North"],[Vector2(bounds.end.x,0),PI*.5,"East"],[Vector2(0,bounds.end.y),0.0,"South"],[Vector2(bounds.position.x,0),-PI*.5,"West"]]:
  var root=Node3D.new();root.name="ArenaGateBay"+entry[2]
  root.position=Vector3(entry[0].x,0,entry[0].y)
  root.rotation.y=entry[1];root.scale=Vector3.ONE*scale_;parent.add_child(root)
  var boxes=Room.Arena.Boxes.new()
  # Scenery stays beyond the playable edge; the existing native entrances remain clear.
  boxes.add(Vector3(0,-.5,10),Vector3(half*2+4,1,20),stone)
  boxes.add(Vector3(0,25,10),Vector3(half*2+4,2,20),stone)
  for side in [-1,1]:
   boxes.add(Vector3(side*(half+1),12,10),Vector3(2,24,20),stone)
   boxes.add(Vector3(side*(half-1),12,.5),Vector3(2,24,1),trim)
  boxes.add(Vector3(0,12,19),Vector3(half*2+4,24,2),stone)
  boxes.add(Vector3(0,12,17.8),Vector3(half*2-4,22,.5),timber)
  for column in range(-12,13):
   boxes.add(Vector3(column*4,12,17.45),Vector3(.35,22,.3),iron)
  for y in [2.0,8.0,16.0,22.0]:
   boxes.add(Vector3(0,y,17.2),Vector3(half*2-4,.65,.4),iron)
  boxes.add(Vector3(0,12,17.05),Vector3(.8,22,.5),trim)
  boxes.add(Vector3(0,23.5,.5),Vector3(half*2,1,1),trim)
  boxes.build(root)
