extends RefCounted
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const Winter=preload("res://scripts/forest/forest_frostpass.gd")
const WinterRooms=preload("res://scripts/forest/forest_frostpass_interiors.gd")
const WinterArt=preload("res://scripts/forest/forest_frostpass_art.gd")
const DecreeArt=preload("res://scripts/forest/forest_holy_decree_art.gd")
const Falken=preload("res://scripts/forest/forest_falken_route.gd")
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
const Data=preload("res://assets/maps/falan/interior_data.gd")
const Freyja=preload("res://assets/maps/falan/freyja_destinations_data.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const RoomArt=preload("res://scripts/forest/forest_falan_room_art.gd")
const Captain=preload("res://scripts/forest/crowd/captain_sprites.gd")
const ZombieMaze=preload("res://scripts/forest/forest_zombie_maze.gd")
const Imur=preload("res://scripts/forest/forest_imur_maze.gd")
const Ruby=preload("res://scripts/forest/crowd/ruby_boss_sprites.gd")
const Dungeons=preload("res://scripts/forest/forest_freyja_dungeons.gd")
const Undersea=preload("res://scripts/forest/crowd/undersea_sprites.gd")
const Ladder=preload("res://scripts/forest/forest_habaru_ladder.gd")
const CEILING_HEIGHT=8.50
const ROCK_WALL_HEIGHT=10.0
const CAVE_ROCK={
 11000:0,11001:0,11002:0,11020:0,11021:0,11022:0,11023:0,11024:0,11028:0,11029:0,21051:0,
 16500:0,16501:0,16502:0,16503:0,16504:0,16505:0,
 11003:1,11004:1,11005:1,11013:1,
 15003:2,15004:2,15005:2,15592:2,15593:2,15594:2,16516:2,16517:2,16518:2,16519:2,
 13001:3,16507:1,30101:0,30102:0,30103:0,30104:0,30105:0,30106:0,
}
const ROCK_TRIANGLES=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]
const HABARU_FACES=preload("res://assets/maps/falan/habaru_wall_faces.png")
const GRAVE_MAZE_SIZE=Vector2i(30,26)
const NEIGHBOR_RING=[Vector2i.UP,Vector2i(1,-1),Vector2i.RIGHT,Vector2i(1,1),
 Vector2i.DOWN,Vector2i(-1,1),Vector2i.LEFT,Vector2i(-1,-1)]
const SIMPLE=[Vector2i(8,7),Vector2(-9,-9),"ffffffffffffff"]

static func floor_info(id:int,run_seed:int=0)->Array:
 if RoomArt.palace(id):return RoomArt.RubySource.palace_info(id)
 if Original.owns(id):return Original.floor_info(id,run_seed)
 if Winter.TITLES.has(id):return Winter.floor_info(id)
 if Winter.Decree.owns(id):return Winter.Decree.floor_info(id,run_seed)
 if Falken.owns(id):return Falken.floor_info(id)
 if Prayer.owns(id):return Prayer.floor_info(id)
 return Data.FLOORS.get(id,Freyja.ROOMS.get(id,SIMPLE))

static func layout(id:int)->Dictionary:
 if id==RoomArt.RubySource.POST:return {"format":"forest_shrine_map","schema":1,"title":"露比的宮殿 · 戰鬥後","falan_area":"interior","falan_floor":id,"buildings":[],"trees":[],"deposits":[]}
 if Original.owns(id):return Original.layout(id)
 var title:String=Winter.TITLES.get(id,"")
 if title.is_empty():title=Winter.Decree.title(id)
 if title.is_empty():title=Falken.title(id) if Falken.owns(id) else Prayer.title(id) if Prayer.owns(id) else Dungeons.TITLES.get(id,Freyja.TITLES.get(id,"Falan Interior"))
 var map={"format":"forest_shrine_map","schema":1,"title":title,"falan_area":"interior","falan_floor":id,
  "buildings":[],"trees":[],"deposits":[]}
 if id==Winter.TRAIL:map.ramparts=[Winter.TRAIL_GRADE]
 return map

static func open_cell(bits:PackedByteArray,size:Vector2i,x:int,z:int)->bool:
 if x<0 or z<0 or x>=size.x or z>=size.y:return false
 var index=z*size.x+x
 return (bits[index>>3] & (1<<(index&7)))!=0

static func walk_mask(id:int,size:Vector2i,source:PackedByteArray,run_seed:int)->PackedByteArray:
 if RoomArt.palace(id):return source
 if Original.owns(id):return source
 if id in Winter.SNOW_FLOORS:return Winter.snow_maze(id,run_seed).bits
 if id in Falken.FLOORS:return Falken.maze(id,run_seed).bits
 if id in Prayer.FLOORS:return Prayer.walk_mask(id,run_seed)
 if id==Prayer.ENTRY:return source
 if id in Imur.FLOORS:return Imur.walk_mask(size,id,run_seed)
 if id==ZombieMaze.ROOM:return ZombieMaze.walk_mask(size,source,run_seed)
 if id in Dungeons.UNDERSEA_FLOORS+Dungeons.VENOA_FLOORS:return source
 if Dungeons.roofed(id) and not RoomArt.palace(id) and id not in Dungeons.HABARU_FLOORS:
  source=widen_corridors(id,size,source)
 if id==Dungeons.GRAVE:
  var maze=Imur.walk_mask(GRAVE_MAZE_SIZE,id,run_seed)
  var maze_origin=Vector2i(3,size.y)
  source.resize(((size.y+GRAVE_MAZE_SIZE.y)*size.x+7)>>3)
  for z in GRAVE_MAZE_SIZE.y:
   for x in GRAVE_MAZE_SIZE.x:
    if not open_cell(maze,GRAVE_MAZE_SIZE,x,z):continue
    var cell=(maze_origin.y+z)*size.x+maze_origin.x+x
    source[cell>>3]|=1<<(cell&7)
  Imur.carve(source,size,Vector2i(27,29),maze_origin+Imur.EXIT)
 return source

static func widen_corridors(id:int,size:Vector2i,source:PackedByteArray)->PackedByteArray:
 var fixtures={}
 for row in RoomArt.Data.FIXTURES.get(id,[]):
  for z in row[1].y:
   for x in row[1].x:fixtures[row[0]+Vector2i(x,z)]=true
 var arena:Rect2i=RoomArt.BossProps.ARENAS.get(id,Rect2i())
 var wide=source.duplicate()
 for z in range(1,size.y-1):
  for x in range(1,size.x-1):
   if open_cell(source,size,x,z):continue
   if not (open_cell(source,size,x-1,z) or open_cell(source,size,x+1,z)
    or open_cell(source,size,x,z-1) or open_cell(source,size,x,z+1)):continue
   if arena.has_point(Vector2i(x,z)) or fixtures.has(Vector2i(x,z)):continue
   # Grow one tile from the original edge, without joining separate paths or removing a pillar.
   var arcs=0
   var previous=open_cell(wide,size,x-1,z-1)
   for offset:Vector2i in NEIGHBOR_RING:
    var open=open_cell(wide,size,x+offset.x,z+offset.y)
    if open and not previous:arcs+=1
    previous=open
   if arcs==1:
    var cell=z*size.x+x
    wide[cell>>3]|=1<<(cell&7)
 return wide

static func safe_point(id:int,preferred:Vector2,run_seed:int=0)->Vector2:
 var floor_=floor_info(id,run_seed)
 var size:Vector2i=floor_[0]
 var origin:Vector2=floor_[1]
 var bits=walk_mask(id,size,floor_[2].hex_decode(),run_seed)
 if id==Dungeons.GRAVE and not Original.owns(id):size.y+=GRAVE_MAZE_SIZE.y
 var best=Vector2.INF
 var distance=INF
 for z in size.y:
  for x in size.x:
   if not open_cell(bits,size,x,z):continue
   var p=origin+Vector2(x,z)*3.0
   var d=p.distance_squared_to(preferred)
   if d<distance:best=p;distance=d
 return best if best.is_finite() else Vector2.ZERO

static func build_ceiling(root:Node3D,id:int,opening:Vector2i=Vector2i(-1,-1)):
 var ceiling_height=Original.ceiling_height(id) if Original.owns(id) else CEILING_HEIGHT
 var floor_=floor_info(id)
 var size:Vector2i=floor_[0]
 var origin:Vector2=floor_[1]
 var full_roof:bool=Freyja.SOLID_ROOFS.has(id) or not Freyja.ENCLOSED_CAVES.has(id)
 var rock:=CAVE_ROCK.has(id)
 var relief=.12 if full_roof else .48
 var mesh=SurfaceTool.new()
 mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var step=1 if rock or opening.x>=0 else 2
 var vault=undersea_roof_heights(size,floor_[2].hex_decode()) if id in Dungeons.UNDERSEA_FLOORS+Dungeons.HABARU_FLOORS+Dungeons.VENOA_FLOORS and opening.x<0 else PackedFloat32Array()
 for z in range(0,size.y,step):
  for x in range(0,size.x,step):
   if Vector2i(x,z)==opening:continue
   var span=Vector2(mini(step,size.x-x),mini(step,size.y-z))
   for corner:Vector2 in ROCK_TRIANGLES:
    var at=origin+(Vector2(x,z)+corner*span-Vector2.ONE*.5)*3.0
    var y=ceiling_height+relief*absf(sin(at.x*.23+sin(at.y*.16))*cos(at.y*.28))
    if rock:
     var shelves=.5+.5*sin(at.x*.34+at.y*.21+sin(at.y*.47)*.9)
     var relief_scale=.42 if opening.x>=0 else 1.0
     y=ceiling_height+(shelves*.94+absf(sin(at.x*.63-at.y*.54))*.38)*relief_scale
    if not vault.is_empty():y=vault[(z+int(corner.y))*(size.x+1)+x+int(corner.x)]
    mesh.add_vertex(Vector3(at.x,y,at.y))
 mesh.generate_normals()
 var ceiling=Geo.mesh(root,mesh.commit(),Vector3.ZERO,cave_material(id,true))
 ceiling.name="SolidCaveCeiling" if full_roof else "HabaruRockCeiling"
 if RoomArt.palace(id):ceiling.position.y=25.
 ceiling.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var center=origin+(Vector2(size)-Vector2.ONE)*1.5
 if opening.x>=0:
  ceiling.name="HabaruBasementCeiling"
  Ladder.split_slab(root,Rect2(origin-Vector2.ONE*1.5,Vector2(size)*3.0),
   [origin+Vector2(opening)*3.0],ceiling_height+.12,.24)
  return
 var solid=Art.solid(root,Vector3(center.x,ceiling_height+.12,center.y),Vector3(size.x*3.0,.24,size.y*3.0),1,"stone")
 solid.name="SolidCaveCeilingCollision" if full_roof else "HabaruCeilingCollision"

static func undersea_roof_heights(size:Vector2i,bits:PackedByteArray)->PackedFloat32Array:
 var heights=PackedFloat32Array()
 for z in size.y+1:
  for x in size.x+1:
   var clearance=3
   for direction:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    for distance in range(3):
     var cell=Vector2i(x,z)+direction*distance
     if not open_cell(bits,size,cell.x,cell.y):
      clearance=mini(clearance,distance)
      break
   heights.append(CEILING_HEIGHT+.18+.34*clearance+.14*sin(x*1.17+z*.73))
 return heights

static func cave_material(id:int,roof:bool)->ShaderMaterial:
 var material=ShaderMaterial.new()
 material.shader=preload("res://scripts/forest/habaru_ceiling.gdshader")
 material.set_shader_parameter("rock",Fort.ROCK)
 material.set_shader_parameter("rock_family",CAVE_ROCK.get(id,-1))
 material.set_shader_parameter("is_roof",roof)
 material.set_shader_parameter("archive_rock",preload("res://assets/maps/falan/undersea_rock_atlas.png") if id in Dungeons.UNDERSEA_FLOORS else preload("res://assets/maps/falan/cave_rock_atlas.png"))
 if roof and id in Dungeons.UNDERSEA_FLOORS:material.set_shader_parameter("archive_rock",preload("res://assets/maps/falan/undersea_roof_atlas.png"))
 if id in Dungeons.UNDERSEA_FLOORS+Dungeons.VENOA_FLOORS:material.set_shader_parameter("original_palette",true)
 if id in Dungeons.VENOA_FLOORS:material.set_shader_parameter("crag_surface",true)
 if id in Dungeons.VENOA_FLOORS:material.set_shader_parameter("archive_rock",preload("res://assets/maps/falan/venoa_scenery/cave_rock_atlas.png"))
 if not roof and id in Dungeons.HABARU_FLOORS+Dungeons.UNDERSEA_FLOORS+Dungeons.VENOA_FLOORS:
  material.set_shader_parameter("has_wall_faces",true)
  material.set_shader_parameter("wall_faces",RoomArt.UnderseaWalls if id in Dungeons.UNDERSEA_FLOORS else HABARU_FACES)
 if Prayer.owns(id):
  material.set_shader_parameter("archive_rock",RoomArt.PrayerArt.Rock)
  material.set_shader_parameter("original_palette",true)
  if not roof:
   material.set_shader_parameter("has_wall_faces",true)
   material.set_shader_parameter("wall_faces",RoomArt.PrayerArt.Walls)
 return material

static func rock_panel(mesh:SurfaceTool,at:Vector2,along_x:bool,open_before:bool,archive_tile:int,face_atlas:Texture2D=HABARU_FACES,setback:float=0.0):
 var tangent=Vector2.RIGHT if along_x else Vector2.DOWN
 var normal=Vector2.DOWN if along_x else Vector2.RIGHT
 if open_before:normal=-normal
 var heights=[0.0,.66,1.85,3.15,4.65,6.25,7.45,8.58,ROCK_WALL_HEIGHT]
 var face=(archive_tile-int(face_atlas in [RoomArt.WallAtlas,RoomArt.UnderseaWalls]))*2+int(along_x)
 var face_origin=Vector2(face%16*36,face/16*100)+Vector2(2.5,2.5)
 var relief:PackedFloat32Array=preload("res://assets/maps/falan/undersea_shapes.gd").WALL_RELIEF.get(face,PackedFloat32Array()) if face_atlas==RoomArt.UnderseaWalls else PackedFloat32Array()
 if face_atlas==HABARU_FACES:relief=preload("res://assets/maps/falan/habaru_shapes.gd").WALL_RELIEF.get(face,PackedFloat32Array())
 for band in heights.size()-1:
  for column in 4:
   for i in ROCK_TRIANGLES.size():
    var corner:Vector2=ROCK_TRIANGLES[i if along_x==open_before else ROCK_TRIANGLES.size()-1-i]
    var u=(column+corner.x)*.25
    var point=at+tangent*(u*3.0)
    var height:float=heights[band+int(corner.y)]
    height+=sin(height*PI/ROCK_WALL_HEIGHT)*sin(point.x*.48+point.y*.41+height*.61)*.27
    # The ends stay on the archive grid, so neighboring sections meet at corners.
    var fold=sin(point.x*.81+point.y*.63+height*1.42)
    var chips=cos(point.x*2.61-point.y*2.13-height*2.04)
    var recess=sin(PI*u)*(.31+fold*.26+chips*.13)*smoothstep(0.0,.65,height)
    if not relief.is_empty():
     var column_index=column+int(corner.x)
     var row_index=8-band-int(corner.y)
     recess=sin(PI*u)*relief[row_index*5+column_index]*smoothstep(0.0,.65,height)
    point-=normal*(recess+setback)
    mesh.set_uv((face_origin+Vector2(u*31.0,(1.0-height/ROCK_WALL_HEIGHT)*95.0))/face_atlas.get_size() if archive_tile>0 else Vector2.ZERO)
    mesh.add_vertex(Vector3(point.x,height,point.y))

static func build(root:Node3D,id:int,run_seed:int=0)->Array[AABB]:
 var source:Dictionary=load("res://scripts/forest/forest_sokia_scenery.gd").fixed_map(id)
 if source.get("sokia_visual_only",false):
  var physical=Node3D.new();physical.name="SokiaPreservedRoomPhysics";root.add_child(physical)
  var obstacles=build_legacy(physical,id,run_seed)
  for node in physical.find_children("*","GeometryInstance3D",true,false):node.hide()
  var visual=Node3D.new();visual.name="SokiaNativeRoomVisuals";root.add_child(visual)
  Original.build(visual,id,run_seed)
  var delta:Vector2=floor_info(id,run_seed)[1]-Original.floor_info(id,run_seed)[1]
  visual.position=Vector3(delta.x,0,delta.y)
  for body in visual.find_children("*","CollisionObject3D",true,false):
   body.get_parent().remove_child(body);body.queue_free()
  root.set_meta("sokia_visual_source",id)
  return obstacles
 return build_legacy(root,id,run_seed)

static func build_legacy(root:Node3D,id:int,run_seed:int=0)->Array[AABB]:
 if Original.owns(id):return Original.build(root,id,run_seed)
 var obstacles:Array[AABB]=[]
 var floor_=floor_info(id,run_seed)
 var size:Vector2i=floor_[0]
 var origin:Vector2=floor_[1]
 var maze=id in Imur.FLOORS
 var winter=Winter.TITLES.has(id)
 var winter_town=Winter.HOUSES.has(id) or id==Winter.ROOF_GARDEN
 var decree=Winter.Decree.owns(id)
 var decree_road=id==Winter.Decree.WEST_ROAD
 var decree_corridor=Winter.Decree.floor_number(id)>0 and id not in Winter.Decree.GUARDIAN_FLOORS
 var mountain_trail=id==Winter.TRAIL
 var original_size=size
 var original_bits:PackedByteArray=floor_[2].hex_decode()
 var bits=walk_mask(id,size,original_bits.duplicate(),run_seed)
 if Falken.owns(id):RoomArt.FalkenArt.build(root,id,run_seed)
 if id==Dungeons.GRAVE:size.y+=GRAVE_MAZE_SIZE.y
 var boxes=Boxes.new()
 var floors=RoomArt.FalkenArt.floor_tiles(id,original_size) if id in Falken.FLOORS else RoomArt.floor_tiles(id,original_size)
 var pools=RoomArt.pool_tiles(id,original_size)
 var archived=RoomArt.FalkenArt.wall_tiles(id,original_size,bits) if id in Falken.FLOORS else RoomArt.wall_tiles(id,original_size)
 var exact_cave=id in Dungeons.HABARU_FLOORS+Dungeons.UNDERSEA_FLOORS+Dungeons.VENOA_FLOORS
 var rock_tiles=archived if id in Dungeons.UNDERSEA_FLOORS else RoomArt.habaru_wall_tiles(id,original_size)
 if Prayer.owns(id):
  rock_tiles=RoomArt.PrayerArt.walls(id,size)
 var random_cave=id==ZombieMaze.ROOM
 var tree_points:Array=Freyja.GRAVE_TREES.get(id,[])
 if id==Dungeons.GRAVE:
  var grass=floors.decode_u16(0)
  var dirt=floors.decode_u16((29*size.x+27)*2)
  floors.resize(size.x*size.y*2)
  if not archived.is_empty():archived.resize(size.x*size.y*2)
  tree_points=tree_points.filter(func(at:Vector2):
   var cell=Vector2i((at-origin)/3.0)
   return not open_cell(bits,size,cell.x,cell.y))
  for z in range(29,size.y):
   for x in size.x:
    if open_cell(bits,size,x,z) and not open_cell(original_bits,original_size,x,z):
     floors.encode_u16((z*size.x+x)*2,dirt)
    elif z>=original_size.y:
     floors.encode_u16((z*size.x+x)*2,grass)
     if z%2==1 and (x+z)%3==0 and not open_cell(bits,size,x,z):
      tree_points.append(origin+Vector2(x,z)*3.0)
 if Dungeons.roofed(id) and not RoomArt.palace(id) and id not in Prayer.FLOORS:
  var fallback=1
  if not floors.is_empty():
   for i in size.x*size.y:
    var tile=floors.decode_u16(i*2)
    if tile>0 and open_cell(original_bits,size,i%size.x,i/size.x) and not RoomArt.is_pool(pools,size,Vector2i(i%size.x,i/size.x)):
     fallback=tile
     break
  for z in size.y:
   for x in size.x:
    if open_cell(original_bits,size,x,z) or not open_cell(bits,size,x,z):continue
    var index=(z*size.x+x)*2
    if not floors.is_empty() and not RoomArt.is_pool(pools,size,Vector2i(x,z)):
     var tile=fallback
     for direction:Vector2i in Imur.DIRECTIONS:
      var next=Vector2i(x,z)+direction
      if not open_cell(original_bits,size,next.x,next.y) or RoomArt.is_pool(pools,size,next):continue
      var nearby=floors.decode_u16((next.y*size.x+next.x)*2)
      if nearby>0:
       tile=nearby
       break
     floors.encode_u16(index,tile)
    if not archived.is_empty():archived.encode_u16(index,0)
 if maze:
  # The archived floor atlas already supplies these two trail materials.
  var grass=floors.decode_u16(0)
  var dirt=floors.decode_u16((Imur.ENTRY.y*size.x+Imur.ENTRY.x)*2)
  tree_points=[]
  for z in size.y:
   for x in size.x:
    var open=open_cell(bits,size,x,z)
    floors.encode_u16((z*size.x+x)*2,dirt if open else grass)
    if not open and z%2==1 and (x+z)%3==0:
     tree_points.append(origin+Vector2(x,z)*3.0)
 if random_cave:
  var fallback=1
  for i in size.x*size.y:
   if floors.decode_u16(i*2)>0 and open_cell(original_bits,size,i%size.x,i/size.x):
    fallback=floors.decode_u16(i*2)
    break
  for z in size.y:
   for x in size.x:
    if ZombieMaze.LAB.has_point(Vector2i(x,z)):continue
    floors.encode_u16((z*size.x+x)*2,fallback if open_cell(bits,size,x,z) else 0)
    archived.encode_u16((z*size.x+x)*2,0)
 var arena:Rect2i=RoomArt.BossProps.ARENAS.get(id,Rect2i())
 var furnished=RoomArt.build_fixtures(root,boxes,id,origin,arena) if not RoomArt.palace(id) and id not in [11004,11028] else {}
 if RoomArt.palace(id) or RoomArt.BossProps.PLACEMENTS.has(id):
  furnished.merge(RoomArt.build_archived_props(root,id,origin,size,pools,bits))
 if Winter.INTERIORS.has(id):
  furnished=WinterRooms.build(root,boxes,id)
  if id==Winter.ROOF_GARDEN:WinterArt.mountains(root,id)
 elif mountain_trail:WinterArt.mountain_trail(root,boxes,bits)
 elif winter:furnished=WinterArt.build(root,boxes,id,bits,run_seed,obstacles)
 elif decree:furnished=DecreeArt.build(root,boxes,id,bits)
 else:RoomArt.build_floor(root,id,floors,size,origin,bits,pools,furnished if exact_cave else {},run_seed)
 if id==Winter.ABANIS:DecreeArt.village_gate(root)
 if id in Dungeons.UNDERSEA_FLOORS:RoomArt.build_undersea_edges(root,id,origin,CEILING_HEIGHT-.04)
 var freyja=Freyja.TITLES.has(id)
 var roofed=Dungeons.roofed(id)
 var cavern=roofed and id!=15505
 var forest=Freyja.GRAVE_TREES.has(id)
 var combat_room=winter or decree or Falken.owns(id) or Prayer.owns(id) or id in [11003,11004,11005,Captain.ROOM,47017,Ruby.ROOM] or Freyja.ZOMBIE_FORMATIONS.has(id) or Freyja.VENOA_BEARS.has(id) or Undersea.PATROLS.has(id)
 if forest:
  var trees=[]
  for at:Vector2 in tree_points:
   var scale_=1.45+.12*fposmod(at.x+at.y,5.0)
   trees.append(Transform3D(Basis(Vector3.UP,at.x*.3).scaled(Vector3.ONE*scale_),Vector3(at.x,0,at.y)))
  var tint=Color("566d91") if id in [47014,47017] else Color("b5c19c")
  RoomArt.Meadow.batch(root,"res://assets/models/environments/wind_meadow/broadleaf_tree.glb",trees,true,0.0,tint)
  root.get_node("ArchivedRoomFloor").material_override.set_shader_parameter("base_color",tint)
  if id==47017:
   var stone=Fort.material(Color("777f92"))
   for cell in [Vector2(22,10),Vector2(24,8),Vector2(34,7),Vector2(36,13),Vector2(33,19)]:
    var at=origin+cell*3.0
    boxes.add(Vector3(at.x,.18,at.y),Vector3(1.9,.36,1.3),stone)
    boxes.add(Vector3(at.x,.95,at.y-.38),Vector3(1.15,1.5,.40),stone)
 if cavern and not Prayer.owns(id) and id not in Dungeons.UNDERSEA_FLOORS+Dungeons.VENOA_FLOORS:
  root.get_node("ArchivedRoomFloor").material_override.set_shader_parameter("base_color",
   Color("939fae") if id in [16502,16503] else Color("b0a8a0"))
 if id==16500:
  var altar=origin+Vector2(46.5,21)
  var stone=Fort.material(Color("8e8678"))
  boxes.add(Vector3(altar.x,.16,altar.y),Vector3(5.8,.32,2.8),stone)
  boxes.add(Vector3(altar.x,.72,altar.y),Vector3(4.4,.8,1.9),stone)
  boxes.add(Vector3(altar.x,1.18,altar.y),Vector3(4.8,.24,2.25),stone)
  furnished[Vector2i(15,7)]=true
  furnished[Vector2i(16,7)]=true
 var cave_exits:Array=Dungeons.EXITS.get(id,[])
 var thresholds=cave_exits.map(func(row):return row[1])
 RoomArt.build_freyja_stairs(root,boxes,id,origin,thresholds)
 if Prayer.owns(id):
  RoomArt.PrayerArt.stairs(root,id,run_seed)
  RoomArt.PrayerArt.scatter(root,id,bits,run_seed)
  if id==Prayer.ENTRY:
   var stair_material=RoomArt.painted_atlas(preload("res://assets/maps/falan/black_prayer/entry-stair.png"))
   stair_material.set_shader_parameter("original_palette",true)
   stair_material.set_shader_parameter("archive_triplanar",true)
   RoomArt.HabaruStairs.build(root,id,Vector2i(7,4),origin+Vector2(7,4)*3.0,13268,stair_material)
 var wall_scale=1.34 if id==1202 else 1.0
 var stair_foot=RoomArt.Mansion.stair_cells(id,17657)
 var upper_flight=RoomArt.Mansion.stair_cells(id,17659)
 var rock:=CAVE_ROCK.has(id)
 var rock_walls:SurfaceTool
 var crags:SurfaceTool
 var crag_corners={}
 if id in Dungeons.VENOA_FLOORS:
  crags=SurfaceTool.new()
  crags.begin(Mesh.PRIMITIVE_TRIANGLES)
 if rock or random_cave:
  rock_walls=SurfaceTool.new()
  rock_walls.begin(Mesh.PRIMITIVE_TRIANGLES)
 if not rock and not RoomArt.Coastal.Data.ROOMS.has(id):
  RoomArt.build_walls(root,boxes,archived,size,origin,139.0/(4.8*RoomArt.PrayerArt.Proportions.VERTICAL) if RoomArt.palace(id) else wall_scale,upper_flight,
   CEILING_HEIGHT+.50 if roofed else 0.0,cavern and not RoomArt.palace(id),
   RoomArt.FalkenArt.Walls if Falken.owns(id) else RoomArt.PrayerArt.PalaceWalls if RoomArt.palace(id) else RoomArt.WallAtlas,
   Falken.Data.WALL_HEIGHTS if Falken.owns(id) else RoomArt.PrayerArt.palace_data().wall_heights if RoomArt.palace(id) else RoomArt.Data.WALL_HEIGHTS)
 if id==1121:RoomArt.Bank.details(root,boxes,origin)
 if id==1092:RoomArt.Guild.details(root,boxes,origin)
 if id==1091:RoomArt.Employment.build(root,boxes,origin)
 if RoomArt.Data.INN_DETAILS.has(id):RoomArt.Inn.details(root,boxes,id,origin)
 if RoomArt.Data.MANSION_SETTEES.has(id):
  RoomArt.Mansion.settees(root,boxes,id,origin)
 if RoomArt.Data.ROOM_PICTURES.has(id):
  RoomArt.Mansion.pictures(root,id,origin,RoomArt.painted_atlas(load("res://assets/maps/falan/mansion_pictures.png")))
 RoomArt.Palace.build(root,boxes,id)
 RoomArt.Cellar.build(root,boxes,id,origin)
 if id in RoomArt.Arena.RAISED or RoomArt.Arena.Data.ARENA_BOARDS.has(id):
  var inlays:ShaderMaterial
  if id==1401:
   inlays=RoomArt.painted_atlas(load("res://assets/maps/falan/arena_inlays.png"))
   inlays.set_shader_parameter("alpha_cutout",true)
  RoomArt.Arena.build_rooms(root,boxes,id,origin,inlays)
 var formal=id in range(1201,1209) or id in range(1400,1405) or id in range(1501,1550)
 var wall_stone=Fort.material(Color("655e51") if cavern else Color("ded4bb") if formal else Color("d7bd93"),formal)
 if winter_town:wall_stone=Fort.material(Color("8397a4"))
 elif decree:wall_stone=Fort.material(DecreeArt.wall_color(id),id!=Winter.Decree.HOUSE and not decree_road)
 elif id==Falken.ROOM:
  wall_stone=Fort.material(Color("5a6b66"),true)
 elif Falken.owns(id):
  wall_stone=RoomArt.painted_atlas(RoomArt.FalkenArt.boundary_paint());wall_stone.set_shader_parameter("original_palette",true)
 if RoomArt.palace(id):
  wall_stone=RoomArt.painted_atlas(RoomArt.PrayerArt.PalaceWall)
  wall_stone.set_shader_parameter("original_palette",true)
  wall_stone.set_shader_parameter("archive_triplanar",true)
  wall_stone.set_shader_parameter("uv_scale",Vector2(.32,.11))
 var lower=Fort.material(Color("5d584e") if cavern else Color("a6a69b") if formal else Color("70482e"),formal or cavern)
 var cap=Fort.material(Color("a29a8a") if cavern else Color("ebe0c7") if formal else Color("9d744a"),false)
 if decree:
  lower=Fort.material(DecreeArt.wall_color(id).darkened(.24),true)
  var maze_index=Winter.Decree.section_index(id)
  var cap_color=Color("272a29") if maze_index>=0 else DecreeArt.wall_color(id).lightened(.22)
  cap=Fort.material(cap_color,false)
  if maze_index>=0:
   wall_stone=DecreeArt.maze_masonry(maze_index,false)
   lower=DecreeArt.maze_masonry(maze_index,true)
 for along_x in [true,false]:
  var rows=size.y if along_x else size.x
  var cols=size.x if along_x else size.y
  for row in range(rows+1):
   var start=0
   var current=0
   for col in range(cols+1):
    var edge=0
    if col<cols:
     var a=Vector2i(col,row-1) if along_x else Vector2i(row-1,col)
     var b=Vector2i(col,row) if along_x else Vector2i(row,col)
     var a_open=open_cell(bits,size,a.x,a.y)
     var b_open=open_cell(bits,size,b.x,b.y)
     var stair_entry=not along_x and row==stair_foot.end.x and stair_foot.has_point(a)
     if id==1091 and not along_x and RoomArt.Employment.STAIR_ENTRY.has_point(Vector2i(row,col)):stair_entry=true
     if not stair_entry and a_open!=b_open:
      var blocked=b if a_open else a
      edge=2 if furnished.has(blocked) else 1
      if is_same(furnished.get(blocked),RoomArt.PLAYER_SCENERY_FIXTURE):edge=4
      if decree or id==Winter.ABANIS:
       var landing=origin+Vector2(a if a_open else b)*3.0
       if (id==Winter.ABANIS and not along_x and b_open and landing==Winter.Decree.ABANIS_WEST_GATE
        or decree and along_x and (a_open and landing==Winter.Decree.LOWER_DOOR or b_open and landing==Winter.Decree.UPPER_DOOR)):
        edge=3
      if edge==1 and not archived.is_empty() and Rect2i(Vector2i.ZERO,size).has_point(blocked):
       var index=(blocked.y*size.x+blocked.x)*2
       if archived.decode_u16(index)!=0 or (not freyja and floors.decode_u16(index)!=0):edge=2
     if rock or random_cave:
      # Flat pools and banks continue under the cave roof beyond the walkable edge.
      var a_visible=a_open or RoomArt.is_pool(pools,size,a) or is_same(furnished.get(a),RoomArt.FLOOR_OVERLAY)
      var b_visible=b_open or RoomArt.is_pool(pools,size,b) or is_same(furnished.get(b),RoomArt.FLOOR_OVERLAY)
      if crags!=null and ((a_open and RoomArt.is_pool(pools,size,b)) or (b_open and RoomArt.is_pool(pools,size,a))):
       var bank_at=origin+Vector2(b)*3.0-Vector2.ONE*1.5
       var tangent=Vector2.RIGHT if along_x else Vector2.DOWN
       var wet=(Vector2.DOWN if along_x else Vector2.RIGHT)*(1.0 if a_open else -1.0)
       for i in 3:
        var at=bank_at+tangent*(.5+i)+wet*.28
        preload("res://scripts/forest/forest_freyja_destination_art.gd").ridge(crags,Vector3(at.x,-.25,at.y),Vector2(.68,.68),.26,row*17+col*31+i,false)
      if exact_cave:
       a_visible=a_visible or furnished.has(a)
       b_visible=b_visible or furnished.has(b)
      var blocked=b if a_visible else a
      if a_visible!=b_visible and not furnished.has(blocked) and (not random_cave or not ZombieMaze.LAB.grow(1).has_point(blocked)):
       var at=origin+Vector2(b)*3.0-Vector2.ONE*1.5
       var tile=0
       if not rock_tiles.is_empty() and Rect2i(Vector2i.ZERO,size).has_point(blocked):
        tile=rock_tiles.decode_u16((blocked.y*size.x+blocked.x)*2)
       rock_panel(rock_walls,at,along_x,a_visible,tile,RoomArt.PrayerArt.Walls if Prayer.owns(id) else RoomArt.UnderseaWalls if id in Dungeons.UNDERSEA_FLOORS else HABARU_FACES,1.3 if crags!=null else 0.0)
       if crags!=null:
        preload("res://scripts/forest/forest_freyja_destination_art.gd").cave_crags(crags,at,along_x,a_visible,tile)
        var tangent=Vector2.RIGHT if along_x else Vector2.DOWN
        var inward=(Vector2.UP if along_x else Vector2.LEFT)*(1.0 if a_visible else -1.0)
        for corner:Vector2 in [at,at+tangent*3.0]:
         if not crag_corners.has(corner):crag_corners[corner]=[]
         if inward not in crag_corners[corner]:crag_corners[corner].append(inward)
    if edge==current:continue
    if current!=0:
     var center=(start+col-1)*1.5
     var point=origin+(Vector2(center,row*3-1.5) if along_x else Vector2(row*3-1.5,center))
     var length=(col-start)*3.0+.24
     var height=CEILING_HEIGHT+.50 if roofed else 4.8*wall_scale
     if winter_town or decree_road:height=1.45
     if decree_corridor:height+=.74
     var foot=0.0
     if mountain_trail:
      var half_depth=.15 if along_x else length*.5
      foot=Winter.trail_height(point.y+half_depth)-.18
      height+=Winter.trail_height(point.y-half_depth)-foot
     var extent=Vector3(length,height,.30) if along_x else Vector3(.30,height,length)
     var position=Vector3(point.x,foot+height*.5,point.y)
     if combat_room:obstacles.append(AABB(position-extent*.5,extent))
     if current==1 and (not winter or winter_town) and not forest and not rock and (not random_cave or ZombieMaze.LAB.has_point(Vector2i((point-origin)/3.0))):
      boxes.add(position,extent,wall_stone)
      if winter_town or decree_road:
       var topping=extent+Vector3(.12,-height+.18,.12)
       boxes.add(position+Vector3.UP*height*.5,topping,Fort.material(Color("d4e2e7"),false))
      elif not cavern and not Falken.owns(id):
       var trim=Vector3(extent.x,.96,extent.z)
       if along_x:trim.z+=.08
       else:trim.x+=.08
       boxes.add(Vector3(point.x,.48,point.y),trim,lower)
       trim.y=.15
       boxes.add(Vector3(point.x,1.03,point.y),trim,cap)
       boxes.add(position+Vector3.UP*(height*.5+.02),Vector3(extent.x+.12,.24,extent.z+.12),cap)
     Art.solid(root,position,extent,1,"stone",current==4)
    start=col
    current=edge
 if rock or random_cave:
  for corner:Vector2 in crag_corners:
   var normals:Array=crag_corners[corner]
   for a in normals.size():
    for b in range(a+1,normals.size()):
     if absf(normals[a].dot(normals[b]))>.01:continue
     var cell=Vector2i(((corner-(normals[a]+normals[b])*.65-origin)/3.0).round())
     if open_cell(bits,size,cell.x,cell.y) or RoomArt.is_pool(pools,size,cell) or furnished.has(cell):continue
     var p:Vector2=corner-normals[a]*1.3
     var q:Vector2=corner-normals[b]*1.3
     rock_walls.set_uv(Vector2.ZERO)
     preload("res://scripts/forest/forest_freyja_destination_art.gd").face(rock_walls,
      Vector3(p.x,0,p.y),Vector3(q.x,0,q.y),Vector3(q.x,ROCK_WALL_HEIGHT,q.y),Vector3(p.x,ROCK_WALL_HEIGHT,p.y))
  rock_walls.generate_normals()
  Geo.mesh(root,rock_walls.commit(),Vector3.ZERO,cave_material(11001 if random_cave else id,false)).name="ArchivedCaveRockWalls"
 if crags!=null:
  crags.generate_normals()
  crags.index()
  var material=cave_material(id,false)
  material.set_shader_parameter("has_wall_faces",false)
  Geo.mesh(root,crags.commit(),Vector3.ZERO,material).name="VenoaStoneCrags"
 boxes.build(root)
 return obstacles
