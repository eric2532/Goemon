extends RefCounted
## Source-measured caps and native whole-face paint on shared solid cliff meshes.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Paint=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Parts=preload("res://scripts/forest/forest_tina_building_details.gd")
static var profiles:Dictionary={}
static var materials:Dictionary={}
static var paint:Texture2D
static var entrance_paint:Dictionary={}
static var cap_paint:Dictionary={}
static var extra_graphics:Dictionary={}
const MAPS=[400,402,14000,14001,14002,15000,15001,15002,15522]
const ENTRANCES=[12834,12838,12839]
const EDGES=[[Vector2i(-1,-1),Vector2i(-1,1),Vector2i.LEFT],[Vector2i(-1,1),Vector2i(1,1),Vector2i.DOWN],[Vector2i(1,1),Vector2i(1,-1),Vector2i.RIGHT],[Vector2i(1,-1),Vector2i(-1,-1),Vector2i.UP]]

static func data(context:Dictionary={})->Dictionary:
 if not context.is_empty():return context.profiles
 if profiles.is_empty():
  var prepared=JSON.parse_string(FileAccess.get_file_as_string(Art.ROOT+"cliff-profiles.json"))
  profiles=prepared.profiles;entrance_paint=prepared.entrance_paint;cap_paint=prepared.cap_paint;extra_graphics=prepared.get("extra_graphics",{})
 return profiles

static func graphic(serial:int,context:Dictionary={})->Dictionary:
 if not context.is_empty():return context.graphics[str(serial)]
 data()
 return extra_graphics[str(serial)] if extra_graphics.has(str(serial)) else Art.data().graphics[str(serial)]

static func texture(context:Dictionary={})->Texture2D:
 if not context.is_empty():return context.texture
 if paint==null:paint=load(Art.ROOT+"cliff-paint.png")
 return paint

static func owns(serial:int)->bool:return data().has(str(serial))

static func continuous(serial:int,freyja:bool=false,context:Dictionary={})->bool:return (freyja or serial not in range(12536,12566)) and data(context).has(str(serial)) and float(data(context)[str(serial)].height)>=3.0

static func material(context:Dictionary={})->Material:
 var atlas=texture(context)
 if not materials.has(atlas):
  var result=Paint.material(atlas).duplicate();result.set_shader_parameter("original_palette",context.get("original_palette",false))
  materials[atlas]=result
 return materials[atlas]

static func collect(placements:Array,size_:Vector2i,bits:PackedByteArray,freyja:bool=false,context:Dictionary={})->Dictionary:
 var reserved={};var cells={};var count_=size_.x*size_.y
 for p in placements:
  if p[4]<count_ or p[3] not in ENTRANCES:continue
  var g:Dictionary=graphic(int(p[3]),context)
  for z in int(g.footprint[1]):
   for x in int(g.footprint[0]):reserved[p[5]+Vector2i(x,-z)]=true
 for p in placements:
  if p[4]<count_ or not continuous(int(p[3]),freyja,context):continue
  var g:Dictionary=graphic(int(p[3]),context);var high=float(data(context)[str(p[3])].height)
  for z in int(g.footprint[1]):
   for x in int(g.footprint[0]):
    var cell:Vector2i=p[5]+Vector2i(x,-z)
    if cell.x<0 or cell.y<0 or cell.x>=size_.x or cell.y>=size_.y or reserved.has(cell):continue
    var index=cell.y*size_.x+cell.x
    if bits[index>>3]&(1<<(index&7)):continue
    if not cells.has(cell) or high>float(cells[cell][0]):cells[cell]=[high,int(p[3]),p[5]]
 return cells

static func height_at(record:Array,point:Vector2,context:Dictionary={})->float:
 var native:Dictionary=data(context)[str(int(record[1]))]
 var anchor:Vector2i=record[2] if record.size()>2 else Vector2i.ZERO
 var g:Dictionary=graphic(int(record[1]),context)
 var sample=point-Vector2(anchor)*3
 var u=clampi(roundi((sample.x+sample.y)*32/3-float(g.origin[0])),0,native.contour_top.size()-1)
 return clampf(((sample.y-sample.x)*8-float(native.contour_top[u])-float(g.origin[1]))*float(native.pixel_height),maxf(.15,float(native.height)*float(context.get("minimum_crown_fraction",0.))),float(native.height)*1.12)*float(record[0])/float(native.height)+(float(record[3]) if record.size()>3 else 0.0)

static func corner(key:Vector2i,cells:Dictionary,cache:Dictionary,context:Dictionary={})->Array:
 if cache.has(key):return cache[key]
 var center=Vector2(key)*1.5;var average=Vector2.ZERO;var high=0.0;var ground=0.0;var adjacent=[]
 for z in [-1,1]:
  for x in [-1,1]:
   var cell=(key+Vector2i(x,z))/2
   if cells.has(cell):adjacent.append(cell);average+=Vector2(cell)*3
 assert(not adjacent.is_empty())
 var inward=(average/adjacent.size()-center).normalized()
 var body=center+inward*.45
 var top=center+inward*.65
 for cell:Vector2i in adjacent:
  var record:Array=cells[cell] if cells[cell].size()>2 else [cells[cell][0],cells[cell][1],cell]
  high+=height_at(record,top,context)
  if record.size()>3:ground+=float(record[3])
 var count_=adjacent.size()
 cache[key]=[Vector3(body.x,ground/count_,body.y),Vector3(top.x,high/count_,top.y)]
 return cache[key]

static func wall_pixel(native:Dictionary,anchor:Vector2i,face:int,p:Vector3,context:Dictionary={})->Vector2:
 if context.has("wall_tiles") and context.wall_tiles.has(str(int(native.paint_source))):
  var b:Array=context.get("wall_preview",[])
  if b.is_empty() or anchor.x>=b[0] and anchor.y>=b[1] and anchor.x<b[0]+b[2] and anchor.y<b[1]+b[3]:
   var tile:Array=context.wall_tiles[str(int(native.paint_source))];var scale_:Array=context.wall_tile_scale
   return Vector2(tile[0]+1+fposmod((p.z if face%2==0 else p.x)*scale_[0],126.),tile[1]+127-fposmod(p.y*scale_[1],126.))
 if face>=2 and context.get("tile_unseen_faces",false):
  var cap:Array=context.cap_paint.cave
  return Vector2(cap[0]+1+fposmod((p.x+p.z)*32.,126.),cap[1]+127-fposmod(p.y*32.,126.))
 var row:Dictionary=data(context)[str(int(native.paint_source))]
 var rect:Array=row.paint_rect
 var g:Dictionary=graphic(int(native.paint_source),context)
 var sample=p-Vector3(anchor.x*3,0,anchor.y*3)
 if face==2:sample.x=float(g.footprint[0])*3-3-sample.x
 if face==3:sample.z=3-float(g.footprint[1])*3-sample.z
 var pixel_height=float(row.pixel_height)*float(native.height)/float(row.height)
 var pixel=Vector2((sample.x+sample.z)*32/3,(sample.z-sample.x)*8-sample.y/pixel_height)-Vector2(g.origin[0],g.origin[1])
 pixel=pixel.clamp(Vector2.ONE*.5,Vector2(rect[2],rect[3])-Vector2.ONE*.5)
 return Vector2(rect[0],rect[1])+pixel

static func section_mesh(cells:Dictionary,section:Array,offset:Vector3,cache:Dictionary,context:Dictionary={})->Mesh:
 var atlas=texture(context)
 var skin=Paint.new([Rect2(Vector2.ZERO,atlas.get_size()),Vector2.ZERO,Vector2.ONE,0],atlas,.045)
 skin.surface.set_smooth_group(0)
 for cell:Vector2i in section:
  var serial=int(cells[cell][1]);var native:Dictionary=data(context)[str(serial)]
  var anchor:Vector2i=cells[cell][2] if cells[cell].size()>2 else cell
  var cap_name="freyja" if serial in range(12536,12566) else "undersea" if serial in range(13000,13036) else "cave" if serial>=13360 else "snow" if serial>=12756 else "rock"
  var cap:Array=context.get("cap_paint",cap_paint)[cap_name];var points=[]
  if context.has("wall_tiles") and context.wall_tiles.has(str(int(native.paint_source))):
   var b:Array=context.get("wall_preview",[]);var anchor_:Vector2i=cells[cell][2] if cells[cell].size()>2 else cell
   if b.is_empty() or anchor_.x>=b[0] and anchor_.y>=b[1] and anchor_.x<b[0]+b[2] and anchor_.y<b[1]+b[3]:cap=context.wall_tiles[str(int(native.paint_source))]
  for sign_ in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]:points.append(corner(cell*2+sign_,cells,cache,context)[1]+offset)
  var uv=[Vector2(1,127),Vector2(1,1),Vector2(127,1),Vector2(127,127)]
  for i in 4:
   if cell.x%2!=0:uv[i].x=128-uv[i].x
   if cell.y%2!=0:uv[i].y=128-uv[i].y
   uv[i]+=Vector2(cap[0],cap[1])
  var record:Array=cells[cell] if cells[cell].size()>2 else [cells[cell][0],serial,cell]
  var middle=Vector3(cell.x*3,height_at(record,Vector2(cell)*3,context),cell.y*3)+offset
  for edge in 4:
   var vertices=[points[edge],points[(edge+1)%4],middle]
   var pixels=[uv[edge],uv[(edge+1)%4],Vector2(cap[0]+64,cap[1]+64)]
   for i in 3:
    skin.surface.set_normal(Vector3.UP);skin.surface.set_uv(pixels[i]/atlas.get_size());skin.surface.add_vertex(vertices[i])
  for face in 4:
   var edge:Array=EDGES[face]
   if cells.has(cell+edge[2]):continue
   var a:Array=corner(cell*2+edge[0],cells,cache,context);var b:Array=corner(cell*2+edge[1],cells,cache,context)
   var normal=Vector3(edge[2].x,0,edge[2].y);var wall=[];var pixels=[]
   for level in 5:
    var v=level/4.0
    for step in 5:
     var u=step/4.0
     var base:Vector3=a[0].lerp(b[0],u);var top:Vector3=a[1].lerp(b[1],u)
     var p=base;var bevel=smoothstep(.75,1.0,v)
     p.x=lerpf(base.x,top.x,bevel);p.z=lerpf(base.z,top.z,bevel);p.y=lerpf(base.y,top.y,v)
     if step>0 and step<4 and level>0 and level<4:
      var source_vertex:Array=native.vertices[roundi(v*6)*16+(24-face*4)%16]
      var g:Dictionary=graphic(serial,context)
      var radius=Vector2((float(source_vertex[0])-float(native.crown[0]))/(float(g.footprint[0])*1.5),(float(source_vertex[2])-float(native.crown[2]))/(float(g.footprint[1])*1.5)).length()
      p+=normal*clampf(.12+radius*.20,.18,.30)*sin(v*PI)*sin(u*PI)
     var painted=p;painted.y=(p.y-base.y)*float(native.height)/float(cells[cell][0])
     wall.append(p+offset);pixels.append(wall_pixel(native,anchor,face,painted,context))
   for level in 4:
    for step in 4:
     var i=level*5+step
     Parts.painted_quad(skin,wall[i],wall[i+5],wall[i+6],wall[i+1],[pixels[i],pixels[i+5],pixels[i+6],pixels[i+1]])
 skin.surface.generate_normals()
 var result=skin.finish();result.surface_set_material(0,material(context))
 return result

static func build(root:Node3D,placements:Array,size_:Vector2i,bits:PackedByteArray,origin:Vector2,source:int=0,crop_origin:Vector2i=Vector2i.ZERO,context:Dictionary={}):
 var cells=collect(placements,size_,bits,source==100,context);var sections={};var cache={};var span=48.0;var triangles=0
 var route=load("res://scripts/forest/forest_west_route_scenery.gd")
 var route_key=root.get_meta("western_route_area",str(source))
 var ground_model=root.get_meta("western_route_height_model") if root.has_meta("western_route_height_model") else null
 var frame=preload("res://scripts/forest/forest_freyja_regions.gd").frame(route_key) if source==100 else Transform2D.IDENTITY
 var fill:Array=context.get("source_cliff_fill",[])
 if route.catalog().maps.has(route_key):fill=fill+route.catalog().maps[route_key].cliff_fill
 for row in fill:
  var cell=Vector2i(row[0],row[1])-crop_origin
  if cells.has(cell) or cell.x<0 or cell.y<0 or cell.x>=size_.x or cell.y>=size_.y:continue
  var index=cell.y*size_.x+cell.x
  if bits[index>>3]&(1<<(index&7)):continue
  var serial=int(row[2])
  cells[cell]=[float(data(context)[str(serial)].height),serial,Vector2i(row[3],row[4])-crop_origin]
 for cell:Vector2i in cells:
  var key=str(source)
  if not context.get("preserve_profile_height",false)and (source==100 or route.contains_cliff(key,Vector2(cell+crop_origin))):
   var native:Dictionary=data(context)[str(int(cells[cell][1]))]
   # Sparse shadow-only pieces borrow their family's painted section, never a taller hidden peak.
   cells[cell][0]=minf(float(cells[cell][0]),float(data(context)[str(int(native.paint_source))].height))/(.045*9.977753)
  if ground_model!=null:
   var at=frame.inverse()*(Vector2(cell+crop_origin)*3)
   cells[cell].append(ground_model.surface_height(at.x,at.y)-root.position.y)
 for cell:Vector2i in cells:
  var p=origin+Vector2(cell)*3
  var key=Vector2i(floori(p.x/span),floori(p.y/span))
  if not sections.has(key):sections[key]=[]
  sections[key].append(cell)
 for key:Vector2i in sections:
  var node=MeshInstance3D.new();node.name="RecoveredCliffMass_%d_%d"%[key.x,key.y]
  node.position=Vector3(key.x*span,0,key.y*span)
  node.mesh=section_mesh(cells,sections[key],Vector3(origin.x,0,origin.y)-node.position,cache,context)
  triangles+=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()/3
  root.add_child(node)
 root.set_meta("recovered_cliff_cells",cells.keys())
 root.set_meta("recovered_cliff_chunks",sections.size())
 root.set_meta("recovered_cliff_triangles",triangles)

static func mesh(serial:int,g:Dictionary)->Mesh:
 var row:Dictionary=data()[str(serial)];var count:int=row.sides
 var rect:Array=row.paint_rect
 var atlas=texture()
 var skin=Paint.new([Rect2(rect[0],rect[1],rect[2],rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],atlas,float(row.pixel_height))
 skin.surface.set_smooth_group(0)
 var points=[];var pixels=[]
 for p in row.vertices:points.append(Vector3(p[0],p[1],p[2]))
 for p in row.uv_pixels:pixels.append(Vector2(p[0],p[1]))
 for level in int(row.levels)-1:
  for side in count:
   var i=level*count+side;var j=level*count+(side+1)%count
   Parts.painted_quad(skin,points[j],points[j+count],points[i+count],points[i],[pixels[j],pixels[j+count],pixels[i+count],pixels[i]])
 var crown=Vector3(row.crown[0],row.crown[1],row.crown[2])
 for side in count:
  skin.surface.set_smooth_group(0)
  var a:Vector3=points[(int(row.levels)-1)*count+side]
  var b:Vector3=points[(int(row.levels)-1)*count+(side+1)%count]
  var normal=(crown-a).cross(b-a).normalized()
  var vertices=[a,b,crown];var uv=[pixels[(int(row.levels)-1)*count+side],pixels[(int(row.levels)-1)*count+(side+1)%count],Vector2(row.crown_uv[0],row.crown_uv[1])]
  for i in 3:
   skin.surface.set_normal(normal);skin.surface.set_uv((skin.graphic[0].position+uv[i])/atlas.get_size());skin.surface.add_vertex(vertices[i])
  var bottom=Vector3(crown.x,0,crown.z)
  skin.surface.set_smooth_group(-1)
  vertices=[points[side],bottom,points[(side+1)%count]];uv=[pixels[side],Vector2(row.bottom_uv[0],row.bottom_uv[1]),pixels[(side+1)%count]]
  for i in 3:
   skin.surface.set_normal(Vector3.DOWN);skin.surface.set_uv((skin.graphic[0].position+uv[i])/atlas.get_size());skin.surface.add_vertex(vertices[i])
 skin.surface.generate_normals()
 var result=skin.finish()
 result.surface_set_material(0,material());result.set_meta("native_cliff_profile",serial)
 return result
