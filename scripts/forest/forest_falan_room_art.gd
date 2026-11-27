extends RefCounted
const FalkenArt=preload("res://scripts/forest/forest_falken_art.gd")
const PrayerArt=preload("res://scripts/forest/forest_black_prayer_art.gd")
const Prayer=preload("res://scripts/forest/forest_black_prayer.gd")
const RubySource=preload("res://scripts/forest/forest_black_prayer_events.gd")
## Visual reconstruction only. The archived navigation grid still owns collision.
const Data=preload("res://assets/maps/falan/room_art_data.gd")
const Coastal=preload("res://scripts/forest/forest_coastal_rooms.gd")
const CityFixtures=preload("res://scripts/forest/forest_falan_city_room_fixtures.gd")
const IlLaruka=preload("res://scripts/forest/forest_il_laruka_art.gd")
const ZombieMaze=preload("res://scripts/forest/forest_zombie_maze.gd")
const Dungeons=preload("res://scripts/forest/forest_freyja_dungeons.gd")
const Ladder=preload("res://scripts/forest/forest_habaru_ladder.gd")
const HabaruStairs=preload("res://scripts/forest/forest_habaru_stairs.gd")
const BossProps=preload("res://assets/maps/falan/boss_room_props.gd")
const RubyProps=preload("res://assets/maps/falan/ruby_room_props.gd")
const Atlas=preload("res://assets/maps/falan/room_floor_atlas.png")
const CoastalFloor=preload("res://assets/maps/falan/coastal_room_floors.png")
const WallAtlas=preload("res://assets/maps/falan/room_wall_atlas.png")
const UnderseaFloor=preload("res://assets/maps/falan/undersea_floor_atlas.png")
const UnderseaWalls=preload("res://assets/maps/falan/undersea_wall_atlas.png")
const Paint=preload("res://scripts/forest/forest_painterly_environment.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Palace=preload("res://scripts/forest/forest_falan_palace_art.gd")
const Cellar=preload("res://scripts/forest/forest_falan_cellar_art.gd")
const Civic=preload("res://scripts/forest/forest_falan_civic_rooms.gd")
const Arena=preload("res://scripts/forest/forest_falan_arena_art.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Mansion=preload("res://scripts/forest/forest_falan_mansion_art.gd")
const Employment=preload("res://scripts/forest/forest_falan_employment_art.gd")
const Guild=preload("res://scripts/forest/forest_falan_guild_art.gd")
const Inn=preload("res://scripts/forest/forest_falan_inn_art.gd")
const Bank=preload("res://scripts/forest/forest_falan_bank_art.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const FLOOR_OVERLAY=&"floor_overlay"
const PLAYER_SCENERY_FIXTURE=&"player_scenery_fixture"
const SCENERY_FIXTURE_KINDS=["bed","counter","shelf","rack","table","bench","chair","plant","barrel",
 "royal_stool","armor","brazier","state_bed","moon","lectern","finial","bust","crate","chest",
 "civic_pew","civic_stall","civic_font","civic_globes","civic_basin","civic_statue","civic_stool",
 "arena_counter","arena_tree","arena_statue","mansion_desk","mansion_piano",
 "inn_counter","inn_table","inn_cupboard","inn_produce","inn_sign","inn_chest","inn_sack","inn_bucket","inn_display",
 "guild_counter","guild_supply","bank_counter","bank_desk","bank_stand","bank_clock"]
const POOL_LEVEL=-.16
const TILE_TRIANGLES=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]

static func palace(id:int)->bool:return id in [Prayer.BOSS,RubySource.POST]
static func floor_tiles(id:int,size:Vector2i)->PackedByteArray:
 if palace(id):return RubySource.palace_tiles(id,"floor_tiles")
 if IlLaruka.Data.FLOORS.has(id):return Marshalls.base64_to_raw(IlLaruka.Data.FLOORS[id]).decompress(size.x*size.y*2,FileAccess.COMPRESSION_DEFLATE)
 if id in FalkenArt.Route.FLOORS:return FalkenArt.floor_tiles(id,size)
 if FalkenArt.Route.owns(id):return Marshalls.base64_to_raw(FalkenArt.Data.FLOORS[id]).decompress(size.x*size.y*2,FileAccess.COMPRESSION_DEFLATE)
 if Prayer.owns(id):return PrayerArt.floors(id,size)
 if Coastal.Data.FLOORS.has(id):return Marshalls.base64_to_raw(Coastal.Data.FLOORS[id]).decompress(size.x*size.y*2,FileAccess.COMPRESSION_DEFLATE)
 if not Data.FLOORS.has(id):return PackedByteArray()
 return Marshalls.base64_to_raw(Data.FLOORS[id]).decompress(size.x*size.y*2,FileAccess.COMPRESSION_DEFLATE)

static func wall_tiles(id:int,size:Vector2i)->PackedByteArray:
 if palace(id):return RubySource.palace_tiles(id,"wall_tiles")
 if IlLaruka.owns_room(id):return PackedByteArray()
 if id in FalkenArt.Route.FLOORS:return PackedByteArray()
 if FalkenArt.Route.owns(id):return Marshalls.base64_to_raw(FalkenArt.Data.WALLS[id]).decompress(size.x*size.y*2,FileAccess.COMPRESSION_DEFLATE)
 if not Data.WALLS.has(id):return PackedByteArray()
 return Marshalls.base64_to_raw(Data.WALLS[id]).decompress(size.x*size.y*2,FileAccess.COMPRESSION_DEFLATE)

static func habaru_wall_tiles(id:int,size:Vector2i)->PackedByteArray:
 if not Data.HABARU_WALLS.has(id):return PackedByteArray()
 return Marshalls.base64_to_raw(Data.HABARU_WALLS[id]).decompress(size.x*size.y*2,FileAccess.COMPRESSION_DEFLATE)

static func pool_tiles(id:int,size:Vector2i)->PackedByteArray:
 if not Data.CAVE_POOLS.has(id):return PackedByteArray()
 return Marshalls.base64_to_raw(Data.CAVE_POOLS[id]).decompress(size.x*size.y*2,FileAccess.COMPRESSION_DEFLATE)

static func is_pool(pools:PackedByteArray,size:Vector2i,cell:Vector2i)->bool:
 return not pools.is_empty() and Rect2i(Vector2i.ZERO,size).has_point(cell) and pools.decode_u16((cell.y*size.x+cell.x)*2)!=0

static func painted_atlas(atlas:Texture2D)->ShaderMaterial:
 var material=ShaderMaterial.new()
 material.shader=Paint.SURFACE
 material.set_shader_parameter("surface_kind",5)
 material.set_shader_parameter("use_vertex_color",false)
 material.set_shader_parameter("use_base_texture",true)
 material.set_shader_parameter("base_texture",atlas)
 material.set_shader_parameter("brush_texture",Paint.BRUSH)
 material.set_shader_parameter("base_color",Color.WHITE)
 return material

static func build_floor(root:Node3D,id:int,tiles:PackedByteArray,size:Vector2i,origin:Vector2,walk:PackedByteArray,pools:PackedByteArray,furnished:Dictionary,run_seed:int=0):
 if palace(id):PrayerArt.palace_void(root,size,origin)
 var chamber=id==FalkenArt.Route.ROOM
 var coping=FalkenArt.Chamber.Boxes.new() if chamber else null
 if chamber:pools=FalkenArt.Chamber.water_mask(tiles)
 var coastal=Coastal.Data.ROOMS.has(id)
 var floor_atlas=IlLaruka.Data.LOWER_FLOOR_ATLAS if IlLaruka.Data.FLOORS.has(id) else FalkenArt.Floor if FalkenArt.Route.owns(id) else PrayerArt.Floor if Prayer.owns(id) else CoastalFloor if coastal else UnderseaFloor if id in Dungeons.UNDERSEA_FLOORS else Atlas
 var atlas_size=floor_atlas.get_size()
 var roofed=Dungeons.roofed(id) and not palace(id)
 var habaru=id in Dungeons.HABARU_FLOORS+Dungeons.VENOA_FLOORS
 var open_stairs:Array=[Prayer.stairs(id,run_seed)[1]] if id in Prayer.FLOORS else HabaruStairs.DOWN_CELLS.get(id,[])
 var village_stairs=IlLaruka.stair_openings(id)
 if id in FalkenArt.Route.FLOORS:open_stairs=[FalkenArt.Route.maze(id,run_seed).stairs[0]]
 var arena:Rect2i=BossProps.ARENAS.get(id,Rect2i())
 var floor_mesh=SurfaceTool.new()
 floor_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var water=SurfaceTool.new()
 water.begin(Mesh.PRIMITIVE_TRIANGLES)
 var bank=SurfaceTool.new()
 bank.begin(Mesh.PRIMITIVE_TRIANGLES)
 var wet_count=0
 for z in size.y:
  for x in size.x:
   var index=z*size.x+x
   var cell=Vector2i(x,z)
   if id==Ladder.CHAMBER and cell==Ladder.HATCH_CELL:continue
   if cell in open_stairs or village_stairs.has(cell):continue
   var wet=is_pool(pools,size,cell)
   if roofed and not wet and (walk[index>>3] & (1<<(index&7)))==0 and not arena.has_point(cell) and not furnished.has(cell):continue
   var tile=tiles.decode_u16(index*2) if not tiles.is_empty() else int((walk[index>>3] & (1<<(index&7)))!=0)
   if tile==0:continue
   tile-=1
   var center=origin+Vector2(x,z)*3.0
   if chamber and FalkenArt.Dais.BOUNDS.has_point(center):continue
   if id==1511 and center.x>Palace.DAIS_EDGE and center.x<Palace.DAIS_FOOT and center.y>Palace.DAIS_Z.x and center.y<Palace.DAIS_Z.y:continue
   var texture_origin=Vector2(tile%32,tile/32)*36.0+Vector2.ONE*2.5
   if wet and chamber:
    wet_count+=1
    var walkable=(walk[index>>3] & (1<<(index&7)))!=0
    var banks=Color(0,0,0,0)
    for side in FalkenArt.Chamber.SIDES.size():
     var direction:Vector2i=FalkenArt.Chamber.SIDES[side]
     if is_pool(pools,size,cell+direction):continue
     banks[side]=1.0
     if not walkable:FalkenArt.Chamber.shore(coping,center,direction,cell,pools,size)
    if walkable:FalkenArt.Chamber.crossing(coping,center)
    water.set_color(banks)
   elif wet:
    wet_count+=1
    for direction:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
     var neighbor=cell+direction
     if not Rect2i(Vector2i.ZERO,size).has_point(neighbor) or is_pool(pools,size,neighbor):continue
     var neighbor_index=neighbor.y*size.x+neighbor.x
     if (walk[neighbor_index>>3] & (1<<(neighbor_index&7)))==0 and not arena.has_point(neighbor):continue
     var normal=Vector2(direction)
     var tangent=normal.orthogonal()
     for corner:Vector2 in TILE_TRIANGLES:
      var at=center+normal*1.5+tangent*(corner.x-.5)*3.0
      bank.set_normal(Vector3(-normal.x,0,-normal.y))
      bank.set_uv((texture_origin+corner*31.0)/atlas_size)
      bank.add_vertex(Vector3(at.x,lerpf(POOL_LEVEL,.03,corner.y),at.y))
   var surface=water if wet else floor_mesh
   for corner:Vector2 in TILE_TRIANGLES:
    var point=center+(corner-Vector2.ONE*.5)*3.0
    surface.set_normal(Vector3.UP)
    var uv=Vector2(corner.y,1.0-corner.x) if habaru or coastal or palace(id) or Prayer.owns(id) or id in [15003,15004,15005] else corner
    surface.set_uv(corner if wet and chamber else (texture_origin+uv*31.0)/atlas_size)
    var height=Palace.surface_height(id,point.x,point.y)+Cellar.surface_height(id,point.x,point.y)+Arena.surface_height(id,point.x,point.y)
    if id in Mansion.STAGES:height+=Mansion.surface_height(id,point.x,point.y)
    var water_level=FalkenArt.Chamber.WATER_LEVEL if chamber else POOL_LEVEL
    surface.add_vertex(Vector3(point.x,water_level if wet else height+.025,point.y))
 var ground=painted_atlas(floor_atlas)
 ground.set_shader_parameter("original_palette",FalkenArt.Route.owns(id) or Prayer.owns(id) or palace(id) or coastal or id in Dungeons.UNDERSEA_FLOORS+Dungeons.VENOA_FLOORS)
 ground.set_shader_parameter("cave_floor",habaru or not pools.is_empty())
 var floor_node=Geo.mesh(root,floor_mesh.commit(),Vector3.ZERO,FalkenArt.Dais.material() if chamber else ground,id in Cellar.RAISED_FLOORS or id in Arena.RAISED or id in Mansion.STAGES or id==Ladder.BASEMENT)
 floor_node.name="ArchivedRoomFloor"
 floor_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 if chamber and wet_count>0:
  var channel=Geo.mesh(root,water.commit(),Vector3.ZERO,FalkenArt.Chamber.water_material())
  channel.name="ChamberWaterChannels"
  channel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var banks=Node3D.new()
  banks.name="ChamberStoneBanks"
  root.add_child(banks)
  coping.build(banks)
 elif wet_count>0:
  var material=ShaderMaterial.new()
  material.shader=preload("res://scripts/forest/forest_cave_pool.gdshader")
  material.set_shader_parameter("floor_atlas",UnderseaFloor if id in Dungeons.UNDERSEA_FLOORS else Atlas)
  material.set_shader_parameter("original_palette",id in Dungeons.UNDERSEA_FLOORS+Dungeons.VENOA_FLOORS)
  var pool=Geo.mesh(root,water.commit(),Vector3.ZERO,material)
  pool.name="ArchivedCavePools"
  pool.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var edges=bank.commit()
  if edges.get_surface_count()>0:
   var shore=painted_atlas(UnderseaFloor) if id in Dungeons.UNDERSEA_FLOORS else Fort.material(Color("544b39"),false)
   if id in Dungeons.UNDERSEA_FLOORS:shore.set_shader_parameter("original_palette",true)
   Geo.mesh(root,edges,Vector3.ZERO,shore).name="CavePoolShore"

static func build_undersea_edges(root:Node3D,id:int,origin:Vector2,height:float):
 var data=preload("res://assets/maps/falan/undersea_edges.gd")
 if not data.TILES.has(id):return
 var atlas=preload("res://assets/maps/falan/undersea_edges.png")
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for cell:Vector3i in data.TILES[id]:
  var center=origin+Vector2(cell.x,cell.y)*3.0
  for corner:Vector2 in TILE_TRIANGLES:
   var at=center+(corner-Vector2.ONE*.5)*3.0
   surface.set_normal(Vector3.DOWN)
   surface.set_uv((Vector2(cell.z*36+2.5,2.5)+corner*31)/atlas.get_size())
   surface.add_vertex(Vector3(at.x,height,at.y))
 var material=painted_atlas(atlas)
 material.set_shader_parameter("alpha_cutout",true)
 material.set_shader_parameter("original_palette",true)
 var mesh=Geo.mesh(root,surface.commit(),Vector3.ZERO,material)
 mesh.name="ArchivedUnderseaEdges"
 mesh.set_meta("archived_placements",data.TILES[id].size())
 mesh.set_meta("wall_caps",true)
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func build_walls(root:Node3D,boxes,tiles:PackedByteArray,size:Vector2i,origin:Vector2,height_scale:float,stair_well:Rect2i,ceiling_wall_height:float=0.0,rock_relief:bool=false,face_atlas:Texture2D=WallAtlas,heights:Array=Data.WALL_HEIGHTS):
 if tiles.is_empty():return
 var mesh=SurfaceTool.new()
 mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var native_tower=face_atlas==FalkenArt.Walls
 var native_palace=face_atlas==PrayerArt.PalaceWalls
 var cap:Material=null if native_tower else Fort.material(Color("101010") if native_palace else Color("37342b"),false)
 var atlas_size=face_atlas.get_size()
 var corners=[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]
 var divisions=FalkenArt.Data.WALL_RELIEF_SIZE if native_tower else Vector2i(3,4) if rock_relief else Vector2i.ONE
 for z in size.y:
  for x in size.x:
   var tile=tiles.decode_u16((z*size.x+x)*2)
   if tile==0 or stair_well.has_point(Vector2i(x,z)):continue
   if native_tower and (tile in FalkenArt.Data.WALL_PILLARS or tile in FalkenArt.Data.WALL_INVISIBLE):continue
   var height=ceiling_wall_height if ceiling_wall_height>0.0 else 4.8*height_scale*(heights[tile-1]-46)/139.0
   var center=Vector3(origin.x+x*3,0,origin.y+z*3)
   boxes.add(center+Vector3.UP*(height-.055),Vector3(3,.11,3),FalkenArt.wall_cap(tile) if native_tower else cap)
   for axis in [Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3.FORWARD]:
    var face=(tile-1)*2+int(axis.x!=0 if native_palace else axis.x==0)
    var texture_origin=Vector2(face%16,face/16)*Vector2(36,100)+Vector2(2.5,2.5)
    var normal:Vector3=axis.cross(Vector3.UP)
    if native_tower:
     var adjacent=Vector2i(x+int(normal.x),z+int(normal.z))
     if Rect2i(Vector2i.ZERO,size).has_point(adjacent) and not stair_well.has_point(adjacent) and tiles.decode_u16((adjacent.y*size.x+adjacent.x)*2)==tile:continue
    for v in divisions.y:
     for h in divisions.x:
      for corner:Vector2 in corners:
       var uv=(Vector2(h,v)+corner)/Vector2(divisions)
       var u=uv.x if axis in ([Vector3.RIGHT,Vector3.BACK] if native_palace else [Vector3.RIGHT,Vector3.FORWARD]) else 1.0-uv.x
       mesh.set_uv((texture_origin+Vector2(u*31,uv.y*95))/atlas_size)
       mesh.set_normal(normal)
       var relief=sin(uv.x*PI)*sin(uv.y*PI)*sin(x*.87+z*1.77+u*5.8+uv.y*8.0)*.23 if rock_relief else 0.0
       if native_tower:
        var sample_=Vector2i(roundi(u*divisions.x),roundi(uv.y*divisions.y))
        relief=-.12*(1.0-FalkenArt.Data.WALL_RELIEF[face][sample_.y*(divisions.x+1)+sample_.x])*sin(uv.x*PI)*sin(uv.y*PI)
       mesh.add_vertex(center+axis*((uv.x-.5)*3.0)+Vector3.UP*((1.0-uv.y)*height)+normal*(1.5+relief))
 var surface=mesh.commit()
 if surface!=null and surface.get_surface_count()>0:
  var material=painted_atlas(face_atlas)
  if face_atlas==FalkenArt.Walls or native_palace:material.set_shader_parameter("original_palette",true)
  Geo.mesh(root,surface,Vector3.ZERO,material).name="ArchivedRoomWalls"

static func build_freyja_stairs(root:Node3D,boxes,id:int,origin:Vector2,thresholds:Array=[]):
 for row in Data.FREYJA_STAIRS.get(id,[]):
  if IlLaruka.owns_room(id) and row[1] in [16590,16592,16594,16595]:continue
  if id==Ladder.BASEMENT and row[0]==Ladder.BASEMENT_CELL:continue
  var at=origin+Vector2(row[0])*3.0
  if not thresholds.is_empty() and at not in thresholds:continue
  var serial:int=row[1]
  if Coastal.Data.ROOMS.has(id) and serial in [16590,16592,16594]:continue
  if id in Dungeons.UNDERSEA_FLOORS and serial in [13268,13269]:
   var material=painted_atlas(preload("res://assets/maps/falan/undersea_stair_13268.png") if serial==13268 else preload("res://assets/maps/falan/undersea_stair_13269.png"))
   material.set_shader_parameter("original_palette",true)
   material.set_shader_parameter("archive_triplanar",true)
   material.set_shader_parameter("uv_scale",Vector2(.67,.95))
   HabaruStairs.build(root,id,row[0],at,serial,material)
   continue
  if id in Dungeons.HABARU_FLOORS+Dungeons.VENOA_FLOORS:
   HabaruStairs.build(root,id,row[0],at,serial)
   continue
  var stone=serial in [12000,12001,12002,13268,13269,13270,13271,13274,17952,17953,17954,17955]
  var riser=Fort.material(Color("69695c") if stone else Color("65442c"),false)
  var edge=Fort.material(Color("9a9982") if stone else Color("ae794d"),false)
  var span=Vector2(2.60,2.65)
  if serial in [12002,13269,13271,17953,17955]:
   boxes.add(Vector3(at.x,.035,at.y),Vector3(2.6,.08,2.6),Fort.material(Color("292b28"),false))
   for side in [-1,1]:
    boxes.add(Vector3(at.x+side*1.28,.075,at.y),Vector3(.18,.15,2.74),edge)
    boxes.add(Vector3(at.x,.075,at.y+side*1.28),Vector3(2.74,.15,.18),edge)
   continue
  var along_x=serial in [16590,16592,17954]
  for i in 5:
   var offset=(i-2)*span.y/5.0
   var h=.07+float(i)*.055
   var point=Vector3(at.x+offset,h*.5,at.y) if along_x else Vector3(at.x,h*.5,at.y+offset)
   var tread=Vector3(span.y/5.0,h,span.x) if along_x else Vector3(span.x,h,span.y/5.0)
   boxes.add(point,tread,riser)
   boxes.add(point+Vector3.UP*(h*.5),Vector3(tread.x,.035,tread.z),edge)

static func build_archived_props(root:Node3D,id:int,origin:Vector2,size:Vector2i,pools:PackedByteArray,walk:PackedByteArray=PackedByteArray())->Dictionary:
 var ruby=palace(id)
 var data=RubyProps if ruby else BossProps
 var atlas=preload("res://assets/maps/falan/ruby_room_props.png") if ruby else preload("res://assets/maps/falan/boss_room_props.png")
 if id in Dungeons.UNDERSEA_FLOORS:atlas=preload("res://assets/maps/falan/undersea_props.png")
 var group=Node3D.new()
 group.name="ArchivedRubyProps" if ruby else "ArchivedBossProps"
 root.add_child(group)
 var textures={}
 var cells={}
 var ruby_stone:ShaderMaterial
 if ruby:
  ruby_stone=painted_atlas(PrayerArt.PalaceWall)
  ruby_stone.set_shader_parameter("original_palette",true)
  ruby_stone.set_shader_parameter("archive_triplanar",true)
  ruby_stone.set_shader_parameter("uv_scale",Vector2(.32,.11))
 var habaru=id in [11004,11028]
 var woodwork=preload("res://scripts/forest/forest_static_boxes.gd").new() if habaru else null
 var banks=SurfaceTool.new()
 banks.begin(Mesh.PRIMITIVE_TRIANGLES)
 var bank_count=0
 var cliffs=SurfaceTool.new()
 cliffs.begin(Mesh.PRIMITIVE_TRIANGLES)
 var cliff_count=0
 var placements=RubySource.palace_props(id) if ruby else data.PLACEMENTS[id]
 for row in placements:
  var cell:Vector2i=row[0]
  var serial:int=row[1]
  # The stair builder (or hidden-room ladder) already owns these archived placements.
  if Data.FREYJA_STAIRS.get(id,[]).any(func(stair):return stair[0]==cell and stair[1]==serial):continue
  var rect:Rect2=data.GRAPHICS[serial][0]
  var span:Vector2i=data.GRAPHICS[serial][1]
  var flat:bool=data.GRAPHICS[serial][2]
  var corner=cell-Vector2i(0,span.y-1)
  var center=origin+(Vector2(corner)+Vector2(span-Vector2i.ONE)*.5)*3.0
  for z in span.y:
   for x in span.x:cells[corner+Vector2i(x,z)]=FLOOR_OVERLAY if flat else true
  if ruby and serial in [16218,16219,16223,16232]:
   PrayerArt.floral_prop(group,cell,center,serial)
   continue
  if ruby and serial in [16465,16466,16193,16196]:
   PrayerArt.court_prop(group,cell,center,serial)
   continue
  if ruby and serial in [16137,17680]:
   PrayerArt.ornament(group,cell,center,serial)
   continue
  if ruby and serial in [16079,16080,16143,16100,16128,16129,16464,16499,16130,16131,16132,16115,16124,16140,16204,16205]:
   PrayerArt.furniture(group,cell,center,span,serial)
   continue
  if ruby and serial in [17683,17684]:
   PrayerArt.arch(group,center,cell,serial,ruby_stone)
   continue
  if ruby and serial==15819:
   # This graphic is only black source occlusion; the solid wall builder already supplies its cap.
   continue
  if ruby and serial==17206:
   PrayerArt.bars(group,center,serial,cell)
   continue
  if habaru and serial in [10456,10458,10494,10500,10533,10537,10541,11016,11017,11018,11044,16524,
   16503,16511,16512,16558,16754,10018,10032,10033,10034]:
   habaru_furniture(group,woodwork,Vector3(center.x,0,center.y),serial)
   continue
  if flat and (habaru or not pools.is_empty()):
   var level=POOL_LEVEL+.013 if is_pool(pools,size,cell) else .037
   if id in Dungeons.UNDERSEA_FLOORS and serial in range(13036,13072):
    level=.037
    var index=cell.y*size.x+cell.x
    if not walk.is_empty() and (walk[index>>3] & (1<<(index&7)))==0:level=.74
    for direction:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
     if not is_pool(pools,size,cell+direction):continue
     var face=(serial-13036)*2+int(direction.x==0)
     var texture_origin=Vector2(face%16*36,face/16*100)+Vector2.ONE*2.5
     var normal=Vector2(direction)
     var tangent=normal.orthogonal()
     for uv:Vector2 in TILE_TRIANGLES:
      var at=center+normal*1.5+tangent*(uv.x-.5)*3.0
      cliffs.set_normal(Vector3(normal.x,0,normal.y))
      cliffs.set_uv((texture_origin+Vector2(uv.x*31,uv.y*95))/Vector2(576,500))
      cliffs.add_vertex(Vector3(at.x,lerpf(level,POOL_LEVEL,uv.y),at.y))
     cliff_count+=1
   for uv:Vector2 in TILE_TRIANGLES:
    var at=center+(uv-Vector2.ONE*.5)*Vector2(span)*3.0
    var tile_uv=Vector2(uv.y,1.0-uv.x) if id in [Ladder.CHAMBER,11005,15003,15004,15005] else uv
    banks.set_normal(Vector3.UP)
    banks.set_uv((rect.position+Vector2(.5,.5)+tile_uv*(rect.size-Vector2.ONE))/atlas.get_size())
    banks.add_vertex(Vector3(at.x,level,at.y))
   bank_count+=1
   continue
  if not textures.has(serial):
   var texture=AtlasTexture.new()
   texture.atlas=atlas
   texture.region=rect
   texture.filter_clip=true
   textures[serial]=texture
  var sprite=Sprite3D.new()
  sprite.texture=textures[serial]
  sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y if not flat and serial!=17206 else BaseMaterial3D.BILLBOARD_DISABLED
  sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
  sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
  var base=2.4 if serial in [17683,17684] else 0.0
  sprite.pixel_size=minf(.046,(8.3-base)/rect.size.y)
  if habaru and not flat:sprite.pixel_size=minf(sprite.pixel_size,3.0/rect.size.y)
  sprite.position=Vector3(center.x,base+rect.size.y*sprite.pixel_size*.5,center.y)
  if flat:
   sprite.rotation.x=-PI*.5
   sprite.pixel_size=3.0/rect.size.x
   sprite.position.y=.038
  sprite.set_meta("blue_cg_serial",serial)
  group.add_child(sprite)
 if bank_count>0:
  var material=painted_atlas(atlas)
  material.set_shader_parameter("original_palette",id in Dungeons.UNDERSEA_FLOORS)
  material.set_shader_parameter("alpha_cutout",true)
  var bank=Geo.mesh(group,banks.commit(),Vector3.ZERO,material)
  bank.name="CaveBankStones"
  bank.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  bank.set_meta("archived_placements",bank_count)
 if cliff_count>0:
  var material=painted_atlas(preload("res://assets/maps/falan/undersea_shore_faces.png"))
  material.set_shader_parameter("original_palette",true)
  material.set_shader_parameter("alpha_cutout",true)
  var cliff=Geo.mesh(group,cliffs.commit(),Vector3.ZERO,material)
  cliff.name="ArchivedUnderseaShoreCliffs"
  cliff.set_meta("archived_faces",cliff_count)
  cliff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 if woodwork!=null:
  var geometry=Node3D.new()
  geometry.name="HabaruTimberwork"
  geometry.set_meta("archived_placements",0)
  group.add_child(geometry)
  woodwork.build(geometry)
 if ruby:PrayerArt.fit_palace_props(group,origin)
 return cells

static func habaru_furniture(group:Node3D,boxes,p:Vector3,serial:int):
 var oak=Fort.material(Color("956137"),false)
 var cut=Fort.material(Color("bb8856"),false)
 var iron=Fort.material(Color("515954"),false)
 var prop=Node3D.new()
 prop.set_meta("blue_cg_serial",serial)
 group.add_child(prop)
 match serial:
  10456,10458:
   for x in ([-1.2,1.2] if serial==10456 else [-1.2]):
    boxes.add(p+Vector3(x,1.0,0),Vector3(.20,2.0,.24),oak)
    boxes.add(p+Vector3(x,2.02,0),Vector3(.24,.10,.28),cut)
   if serial==10456:
    for y in [.50,1.13]:
     boxes.add(p+Vector3(0,y,0),Vector3(3.0,.18,.14),cut)
  10533,10537,11016,11017,11018,16524:
   Cellar.furnish(prop,boxes,p,"crate",serial,false,0.0)
   if serial in [10533,10537,16524]:
    for i in 5:
     var tint=Color(["a85f3e","849851","c18f47","656485","9ca668"][i])
     Geo.box(prop,p+Vector3((i%3-1)*.33,1.54,i/3*.31-.14),Vector3(.26,.23,.25),Fort.material(tint,false))
  10541:
   boxes.add(p+Vector3.UP*1.00,Vector3(.80,.15,3.36),cut)
   for x in [-.28,.28]:
    for z in [-1.47,1.47]:
     boxes.add(p+Vector3(x,.48,z),Vector3(.13,.96,.13),oak)
   for i in 5:
    var tint=Fort.material(Color(["688371","976e50","72688b","7b9f79","998259"][i]),false)
    var at=p+Vector3((i%2-.5)*.29,1.24,i*.53-1.06)
    Geo.cylinder(prop,at,.15,.32,tint)
    Geo.cylinder(prop,at+Vector3.UP*.19,.075,.14,tint)
  10494,10500,16511,16512,16754:
   var swap=serial in [16512,16754]
   var width=3.55 if serial in [16511,16512] else 1.85
   var height=2.45 if serial==16754 else 2.82
   block(boxes,p,swap,Vector3(0,height*.50,-.38),Vector3(width,height,.16),oak)
   for side in [-1,1]:
    block(boxes,p,swap,Vector3(side*width*.47,height*.50,0),Vector3(.17,height,.90),oak)
   for level in 4:
    var y=.13+level*(height-.22)/3.0
    block(boxes,p,swap,Vector3(0,y,0),Vector3(width,.14,.98),cut)
    if level==3 or serial==10494:continue
    if serial==16754:
     block(boxes,p,swap,Vector3(0,y+.36,.39),Vector3(width*.73,.085,.12),iron)
     block(boxes,p,swap,Vector3(-width*.38,y+.36,.39),Vector3(.22,.12,.14),oak)
     continue
    for book in int(width/.31)-1:
     var color=["815241","637b69","8b8267","4d5c70"][(book+level)%4]
     var spine=.28+.11*((book+level)%3)
     block(boxes,p,swap,Vector3(-width*.5+.29+book*.29,y+.07+spine*.5,.16),
      Vector3(.21,spine,.53),Fort.material(Color(color),false))
  16558:
   boxes.add(p+Vector3.UP*1.16,Vector3(2.15,.17,1.54),cut)
   for x in [-.90,.90]:
    for z in [-.60,.60]:
     boxes.add(p+Vector3(x,.56,z),Vector3(.18,1.12,.18),oak)
   for x in [-.55,.25,.63]:
    boxes.add(p+Vector3(x,1.31,.05),Vector3(.30,.13,.33),iron)
  11044:
   var canvas=Fort.material(Color("77794e"),false)
   for x in [-1.55,1.55]:
    for z in [-1.32,1.32]:
     boxes.add(p+Vector3(x,1.06,z),Vector3(.21,2.12,.20),oak)
   for side in [-1,1]:
    var roof=Geo.box(prop,p+Vector3(side*.85,2.58,0),Vector3(2.12,.16,3.38),canvas)
    roof.rotation.z=-side*.51
    for end in [-1,1]:
     Geo.beam(prop,p+Vector3(0,3.1,end*1.59),p+Vector3(side*1.75,2.11,end*1.59),.085,cut)
   boxes.add(p+Vector3(0,1.01,-1.32),Vector3(3.12,1.78,.17),oak)
  16503:
   var linen=Fort.material(Color("dfd2aa"),false)
   var covers=Fort.material(Color("a4ad87"),false)
   boxes.add(p+Vector3.UP*.61,Vector3(5.9,.36,2.3),oak)
   boxes.add(p+Vector3.UP*.92,Vector3(5.68,.30,2.18),linen)
   boxes.add(p+Vector3(-.75,1.10,0),Vector3(3.85,.18,2.21),covers)
   boxes.add(p+Vector3(2.18,1.15,0),Vector3(.83,.23,1.72),linen)
   for end in [-1,1]:
    var height=1.80 if end==1 else 1.29
    boxes.add(p+Vector3(end*2.95,height*.50,0),Vector3(.19,height,2.44),oak)
    for side in [-1,1]:
     boxes.add(p+Vector3(end*3.0,(height+.23)*.50,side*1.23),Vector3(.23,height+.23,.23),cut)
  _:
   var positions=[Vector3.ZERO]
   if serial!=10018:positions=[Vector3(-.64,0,.36),Vector3(.60,0,.42),Vector3(0,0,-.67)]
   if serial in [10033,10034]:positions.append(Vector3(0,1.23,-.67))
   if serial==10034:positions.append(Vector3(-.64,1.23,.36))
   for offset in positions:
    var center=p+offset
    Geo.cylinder(prop,center+Vector3.UP*.61,.60,1.22,oak)
    Geo.cylinder(prop,center+Vector3.UP*1.23,.53,.07,cut)
    for y in [.20,.98]:
     Geo.cylinder(prop,center+Vector3.UP*y,.62,.09,iron)

static func build_fixtures(root:Node3D,boxes,id:int,origin:Vector2,reserved:Rect2i)->Dictionary:
 if IlLaruka.owns_room(id):return IlLaruka.build_room(root,id,origin)
 if id in CityFixtures.ROOMS:return CityFixtures.build(root,id,origin)
 var cells={}
 var coastal_batches={}
 var plants=[]
 var barrels=[]
 var wood=Fort.material(Color("794b31"),false)
 var oak=Fort.material(Color("b07847"),false)
 var dark=Fort.material(Color("503728"),false)
 var linen=Fort.material(Color("e7d8b4"),false)
 var brass=Fort.material(Color("a8915b"),false)
 var cloth=Fort.material(Color("833f35"),false)
 var blanket=Fort.material(Color("b8a783"),false)
 var porcelain=Fort.material(Color("a9bbc0"),false)
 var steel=Fort.material(Color("8d9d9d"),false)
 var stone_top=Fort.material(Color("ece7dc"),false)
 var mahogany=Fort.material(Color("78482f"),false)
 var shelf_colors=[cloth,Fort.material(Color("455e60"),false),Fort.material(Color("566746"),false),brass]
 var hospital=id in [1111,1112,2010,2110,2111,2310,2311,2410,3010,3210]
 var fixtures:Array=Coastal.Data.ROOMS.get(id,Data.FIXTURES.get(id,[]))
 for row in fixtures:
  var anchor:Vector2i=row[0]
  if id==ZombieMaze.ROOM and not ZombieMaze.LAB.has_point(anchor):continue
  var count:Vector2i=row[1]
  if reserved.has_area() and reserved.intersects(Rect2i(anchor,count)):continue
  var fixture=PLAYER_SCENERY_FIXTURE if row[2] in SCENERY_FIXTURE_KINDS else true
  for z in count.y:
   for x in count.x:cells[anchor+Vector2i(x,z)]=fixture
  var at=origin+(Vector2(anchor)+Vector2(count-Vector2i.ONE)*.5)*3.0
  var floor_y=Palace.surface_height(id,at.x,at.y)+Cellar.surface_height(id,at.x,at.y)+Arena.surface_height(id,at.x,at.y)
  if id in Mansion.STAGES:floor_y+=Mansion.surface_height(id,at.x,at.y)
  var center=Vector3(at.x,floor_y,at.y)
  var swap=count.x>count.y
  var width=minf(count.x,count.y)*3.0-.34
  var length=maxf(count.x,count.y)*3.0-.34
  var serial:int=row[3]
  if row[2].begins_with("coast_"):
   Coastal.furnish(root,boxes,center,Vector2(count)*3,serial,row[2],coastal_batches)
   continue
  if Furniture.handles(id,serial):
   Furniture.build(root,id,serial,center,width,length,swap)
   continue
  match row[2]:
   "bed":
    var head=-1 if serial in [17537,16040] else 1
    var covers=Fort.material(Color("ddab8b"),false) if serial==16040 else blanket
    block(boxes,center,swap,Vector3(0,.58,0),Vector3(width*.64,.40,length*.82),wood)
    block(boxes,center,swap,Vector3(0,.95,0),Vector3(width*.61,.44,length*.78),linen)
    block(boxes,center,swap,Vector3(0,1.21,-head*length*.07),Vector3(width*.62,.16,length*.59),covers)
    block(boxes,center,swap,Vector3(0,1.26,head*length*.27),Vector3(width*.43,.24,length*.14),stone_top)
    for side in [-1,1]:
     block(boxes,center,swap,Vector3(side*width*.30,.95,-head*length*.07),Vector3(.14,.58,length*.59),covers)
     for end in [-1,1]:
      var post_height=2.04 if end==head else 1.28
      block(boxes,center,swap,Vector3(side*width*.33,post_height*.5,end*length*.41),Vector3(.22,post_height,.22),oak)
    block(boxes,center,swap,Vector3(0,1.48,head*length*.41),Vector3(width*.64,.70,.17),wood)
    block(boxes,center,swap,Vector3(0,.84,-head*length*.41),Vector3(width*.64,.54,.16),wood)
    if hospital:
     var folded=Fort.material(Color("c9b998"),false)
     block(boxes,center,swap,Vector3(0,1.32,head*length*.18),Vector3(width*.58,.13,.24),folded)
     block(boxes,center,swap,Vector3(0,1.25,-head*length*.33),Vector3(width*.65,.10,.19),folded)
     for side in [-1,1]:
      block(boxes,center,swap,Vector3(side*width*.23,1.37,-head*length*.06),Vector3(.067,.047,length*.45),folded)
   "counter":
    var marble=id==3010 or serial in [17049,17050,17051,17053,17054,17595,17596]
    var honey=serial in [17527,17529,17568,17570]
    var top=stone_top if marble else oak
    var frame=oak if honey else mahogany
    block(boxes,center,swap,Vector3(0,.68,0),Vector3(width*.88,1.36,length*.96),frame)
    block(boxes,center,swap,Vector3(0,1.42,0),Vector3(width,.21,length),top)
    block(boxes,center,swap,Vector3(0,.16,0),Vector3(width*.96,.27,length*.98),porcelain if marble else dark)
    for side in [-1,1]:
     block(boxes,center,swap,Vector3(side*width*.45,1.22,0),Vector3(.10,.16,length*.95),oak)
     for panel in range(1,ceili(length/.56)):
      block(boxes,center,swap,Vector3(side*width*.45,.71,-length*.46+panel*.53),Vector3(.09,.80,.11),oak)
   "shelf","rack":
    if serial in [16004,16005]:
     block(boxes,center,swap,Vector3(0,1.6,0),Vector3(1.33,3.2,1.76),mahogany)
     block(boxes,center,swap,Vector3(0,3.22,0),Vector3(1.46,.21,1.93),wood)
     for side in [-1,1]:
      for door in [-1,1]:
       block(boxes,center,swap,Vector3(side*.674,1.66,door*.42),Vector3(.10,2.66,.69),wood)
       block(boxes,center,swap,Vector3(side*.735,1.66,door*.19),Vector3(.08,.17,.085),brass)
     continue
    var weapon_table=serial in [17157,17158,17159]
    var weapons=serial in [17155,17156,17211,17212,17213,17214,17215]
    var bottles=serial in [17012,17013,17014,17015,17541]
    var archive_bookcase=id==1531 and serial in [16078,16080]
    var height=1.12 if weapon_table else 2.65 if weapons else 4.65 if archive_bookcase else 3.25
    var shelf_width=width*(.72 if weapon_table else .48)
    if not weapon_table:block(boxes,center,swap,Vector3(0,height*.5,0),Vector3(.13,height,length*.90),dark)
    for side in [-1,1]:
     block(boxes,center,swap,Vector3(0,height*.5,side*length*.46),Vector3(shelf_width,height,.25 if archive_bookcase else .20),mahogany if archive_bookcase else wood)
    var levels=[.24,height] if weapons or weapon_table else [.30,.99,1.71,2.43,height]
    if archive_bookcase:
     levels=[.38,1.36,2.33,3.33,height]
     block(boxes,center,swap,Vector3(0,height-.06,0),Vector3(shelf_width+.22,.29,length*.98),mahogany)
    for level in levels:
     block(boxes,center,swap,Vector3(0,level,0),Vector3(shelf_width+.08,.13,length*.95),mahogany if archive_bookcase else oak)
    var columns=maxi(1,int(length/(.66 if weapons or weapon_table else .32)))
    for i in columns:
     var depth=((i+.5)/columns-.5)*length*.86
     for side in [-1,1]:
      var face=side*shelf_width*.27
      if weapons:
       block(boxes,center,swap,Vector3(face,1.66,depth),Vector3(.09,1.7,.14),steel)
       block(boxes,center,swap,Vector3(face,.79,depth),Vector3(.13,.09,.32),brass)
      elif weapon_table:
       block(boxes,center,swap,Vector3(face,height+.13,depth),Vector3(shelf_width*.42,.08,.11),steel)
       block(boxes,center,swap,Vector3(face*1.8,height+.13,depth),Vector3(.10,.12,.25),brass)
      elif serial not in [17542,17549]:
       for shelf in range(4):
        var h:float=levels[shelf]+(.36 if archive_bookcase else .24)
        var book_height=.51 if archive_bookcase else .31
        block(boxes,center,swap,Vector3(face,h,depth),Vector3(.27,book_height+(i%3)*.06,.16),shelf_colors[(i+shelf)%4])
        if bottles:block(boxes,center,swap,Vector3(face,h+.22,depth),Vector3(.10,.15,.09),porcelain)
   "table","bench","chair":
    var table:bool=row[2]=="table"
    var height=1.25 if table else .74
    var top_width=width*(.78 if table else .60)
    var top_length=length*.78
    var banquet=serial in range(16151,16161)
    var linen_table=serial in range(16117,16121)
    var court_table=serial in [16067,16068,16072,16073,16075,16076,16077,16115,16116,16140]
    var round_table=serial in [10519,17024,17507,17508,17509]
    if round_table:
     Geo.cylinder(root,center+Vector3.UP*height,top_width*.49,.20,wood)
     if serial!=17024:Geo.cylinder(root,center+Vector3.UP*(height+.11),top_width*.44,.05,linen)
     block(boxes,center,swap,Vector3(0,height*.5,0),Vector3(.38,height,.38),dark)
     block(boxes,center,swap,Vector3(0,.09,0),Vector3(top_width*.48,.18,.25),dark)
     block(boxes,center,swap,Vector3(0,.09,0),Vector3(.25,.18,top_width*.48),dark)
    else:
     var top_material=mahogany if banquet else linen if linen_table else stone_top if court_table else oak if table else wood
     block(boxes,center,swap,Vector3(0,height,0),Vector3(top_width,.20,top_length),top_material)
     for side in [-1,1]:
      for end in [-1,1]:
       block(boxes,center,swap,Vector3(side*top_width*.39,height*.5,end*top_length*.39),Vector3(.21,height,.21),brass if court_table or serial in range(16122,16127) else dark)
    if linen_table:
     for side in [-1,1]:
      block(boxes,center,swap,Vector3(side*top_width*.48,.70,0),Vector3(.10,1.05,top_length),linen)
    if banquet and serial in [16151,16157,16158,16159,16160]:
     for end in [-1,1]:
      for side in [-1,1]:
       var plate=Vector3(side*top_width*.28,height+.12,end*top_length*.36)
       if swap:plate=Vector3(plate.z,plate.y,plate.x)
       Geo.cylinder(root,center+plate,.23,.05,stone_top)
    if serial in [17539,17540,17572]:
     block(boxes,center,swap,Vector3(0,height+.13,0),Vector3(top_width*.47,.06,top_length*.29),shelf_colors[2])
     for end in [-1,1]:
      block(boxes,center,swap,Vector3(.12,height+.16,end*top_length*.29),Vector3(.51,.12,.39),linen)
    if hospital and serial in [17540,17572,17586]:Civic.hospital_desk(root,boxes,center,swap,length)
    if not table:
     var gilded=serial in range(16122,16127)
     if not (hospital and serial in [17532,17533]):
      block(boxes,center,swap,Vector3(-top_width*.38,1.18,0),Vector3(.15,1.02,top_length),brass if gilded else wood)
     if row[2]=="chair" or serial in [17524,17525,17532,17533]:
      var upholstery=linen if serial in [17532,17533] else cloth
      block(boxes,center,swap,Vector3(0,.88,0),Vector3(top_width*.88,.22,top_length*.89),upholstery)
   "plant":
    Geo.cylinder(root,center+Vector3.UP*.32,.34,.64,porcelain,false,.47)
    var plant_scale=Vector3(.33,.58,.33) if serial in [10026,10039,16225,16226,17535,17536] else Vector3.ONE*.43
    plants.append(Transform3D(Basis.IDENTITY.scaled(plant_scale),center+Vector3.UP*.59))
   "barrel":
    barrels.append(center)
   "royal_stool","armor","brazier","state_bed":
    Palace.furnishing(root,boxes,center,row[2],serial)
   "moon","lectern","finial","grille","rope","bust","crate","chest":
    Cellar.furnish(root,boxes,center,row[2],serial,swap,length)
   "civic_screen","civic_pew","civic_reredos","civic_stall","civic_font","civic_globes","civic_basin","civic_statue","civic_stool":
    Civic.furnish(root,boxes,center,not swap,length,row[2],serial)
   "arena_counter","arena_gallery","arena_tree","arena_statue":
    Arena.furnish(root,boxes,center,length,row[2],serial)
   "mansion_column","mansion_stair","mansion_desk","mansion_piano":
    Mansion.furnishings(root,center,width,length,swap,serial,row[2])
   "inn_counter","inn_table","inn_cupboard","inn_produce","inn_sign","inn_chest","inn_sack","inn_bucket","inn_display":
    Inn.furnish(root,boxes,center,width,length,swap,serial,row[2])
   "guild_counter","guild_supply":
    Guild.furnish(root,boxes,center,row[2],serial)
   "bank_counter","bank_desk","bank_stand","bank_clock","bank_vault":
    Bank.furnish(root,boxes,center,width,length,swap,row[2],serial)
   "fireplace":
    block(boxes,center,swap,Vector3(0,.14,0),Vector3(width*.85,.28,length*.83),stone_top)
    block(boxes,center,swap,Vector3(-.34,1.47,0),Vector3(.45,2.8,length*.72),dark)
    for end in [-1,1]:
     block(boxes,center,swap,Vector3(.12,1.34,end*length*.33),Vector3(1.00,2.69,.42),linen)
    block(boxes,center,swap,Vector3(.06,2.64,0),Vector3(1.18,.39,length*.80),linen)
    block(boxes,center,swap,Vector3(.10,2.88,0),Vector3(1.43,.16,length*.86),stone_top)
    block(boxes,center,swap,Vector3(.17,.34,0),Vector3(.62,.18,1.12),dark)
    block(boxes,center,swap,Vector3(.23,.45,0),Vector3(.37,.16,.73),cloth)
 if Coastal.Data.ROOMS.has(id):
  Coastal.batch(root,coastal_batches)
  root.set_meta("coastal_source_objects",fixtures.size())
 if not plants.is_empty():Meadow.batch(root,"leafy_shrub",plants)
 if not barrels.is_empty():
  for spec in [[1.17,.72,.57,oak],[.12,.76,.72,brass]]:
   var barrel=CylinderMesh.new()
   barrel.radial_segments=10
   barrel.height=spec[0]
   barrel.bottom_radius=spec[1]
   barrel.top_radius=spec[2]
   for center:Vector3 in barrels:
    var height:float=spec[0]*.5 if spec[0]>1.0 else .30
    Geo.mesh(root,barrel,center+Vector3.UP*height,spec[3])
 return cells

static func block(boxes,center:Vector3,swap:bool,offset:Vector3,extent:Vector3,material:Material):
 if swap:
  offset=Vector3(offset.z,offset.y,offset.x)
  extent=Vector3(extent.z,extent.y,extent.x)
 boxes.add(center+offset,extent,material)
