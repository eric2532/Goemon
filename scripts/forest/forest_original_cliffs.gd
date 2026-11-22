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
const MAPS=[400,402,14000,14001,14002]
const EDGES=[[Vector2i(-1,-1),Vector2i(-1,1),Vector2i.LEFT],[Vector2i(-1,1),Vector2i(1,1),Vector2i.DOWN],[Vector2i(1,1),Vector2i(1,-1),Vector2i.RIGHT],[Vector2i(1,-1),Vector2i(-1,-1),Vector2i.UP]]

static func data()->Dictionary:
 if profiles.is_empty():
  var prepared=JSON.parse_string(FileAccess.get_file_as_string(Art.ROOT+"cliff-profiles.json"))
  profiles=prepared.profiles;entrance_paint=prepared.entrance_paint;cap_paint=prepared.cap_paint
 return profiles

static func texture()->Texture2D:
 if paint==null:paint=load(Art.ROOT+"cliff-paint.png")
 return paint

static func owns(serial:int)->bool:return data().has(str(serial))

static func continuous(serial:int)->bool:return owns(serial) and float(data()[str(serial)].height)>=3.0

static func material()->Material:
 var atlas=texture()
 if not materials.has(atlas):
  var result=Paint.material(atlas).duplicate();result.set_shader_parameter("original_palette",false)
  materials[atlas]=result
 return materials[atlas]

static func collect(placements:Array,size_:Vector2i,bits:PackedByteArray)->Dictionary:
 var reserved={};var cells={};var count_=size_.x*size_.y
 for p in placements:
  if p[4]<count_ or p[3] not in [12834,12839]:continue
  var g:Dictionary=Art.data().graphics[str(p[3])]
  for z in int(g.footprint[1]):
   for x in int(g.footprint[0]):reserved[p[5]+Vector2i(x,-z)]=true
 for p in placements:
  if p[4]<count_ or not continuous(int(p[3])):continue
  var g:Dictionary=Art.data().graphics[str(p[3])];var high=float(data()[str(p[3])].height)
  for z in int(g.footprint[1]):
   for x in int(g.footprint[0]):
    var cell:Vector2i=p[5]+Vector2i(x,-z)
    if cell.x<0 or cell.y<0 or cell.x>=size_.x or cell.y>=size_.y or reserved.has(cell):continue
    var index=cell.y*size_.x+cell.x
    if bits[index>>3]&(1<<(index&7)):continue
    if not cells.has(cell) or high>float(cells[cell][0]):cells[cell]=[high,int(p[3])]
 return cells

static func corner(key:Vector2i,cells:Dictionary,cache:Dictionary)->Array:
 if cache.has(key):return cache[key]
 var center=Vector2(key)*1.5;var average=Vector2.ZERO;var high=0.0;var count_=0
 for z in [-1,1]:
  for x in [-1,1]:
   var cell=(key+Vector2i(x,z))/2
   if not cells.has(cell):continue
   average+=Vector2(cell)*3;high+=float(cells[cell][0]);count_+=1
 assert(count_>0)
 var inward=(average/count_-center).normalized()
 var body=center+inward*(.30 if count_==1 else 0.0)
 var top=center+inward*.18
 cache[key]=[Vector3(body.x,0,body.y),Vector3(top.x,high/count_,top.y)]
 return cache[key]

static func wall_pixel(row:Dictionary,face:int,u:float,v:float)->Vector2:
 var rect:Array=row.paint_rect
 if face>=2:u=1-u
 var horizontal=(.03+u*.47) if face%2==0 else (.50+u*.47)
 var x=.5+(float(rect[2])-1)*horizontal
 var column:Array=row.columns[clampi(roundi(x),0,int(rect[2])-1)]
 return Vector2(float(rect[0])+x,float(rect[1])+.5+lerpf(float(column[1]),float(column[0]),v))

static func section_mesh(cells:Dictionary,section:Array,offset:Vector3,cache:Dictionary)->Mesh:
 var atlas=texture()
 var skin=Paint.new([Rect2(Vector2.ZERO,atlas.get_size()),Vector2.ZERO,Vector2.ONE,0],atlas,.045)
 skin.surface.set_smooth_group(0)
 for cell:Vector2i in section:
  var serial=int(cells[cell][1]);var native:Dictionary=data()[str(serial)]
  var row:Dictionary=data()[str(int(native.paint_source))]
  var cap_name="cave" if serial>=13360 else "snow" if serial>=12756 else "rock"
  var cap:Array=cap_paint[cap_name];var points=[]
  for sign_ in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]:points.append(corner(cell*2+sign_,cells,cache)[1]+offset)
  var uv=[Vector2(1,127),Vector2(1,1),Vector2(127,1),Vector2(127,127)]
  for i in 4:
   if cell.x%2!=0:uv[i].x=128-uv[i].x
   if cell.y%2!=0:uv[i].y=128-uv[i].y
   uv[i]+=Vector2(cap[0],cap[1])
  Parts.painted_quad(skin,points[0],points[1],points[2],points[3],uv)
  for face in 4:
   var edge:Array=EDGES[face]
   if cells.has(cell+edge[2]):continue
   var a:Array=corner(cell*2+edge[0],cells,cache);var b:Array=corner(cell*2+edge[1],cells,cache)
   var normal=Vector3(edge[2].x,0,edge[2].y);var wall=[];var pixels=[]
   for level in 5:
    var v=level/4.0
    for step in 3:
     var u=step/2.0
     var base:Vector3=a[0].lerp(b[0],u);var top:Vector3=a[1].lerp(b[1],u)
     var p=base;var bevel=smoothstep(.75,1.0,v)
     p.x=lerpf(base.x,top.x,bevel);p.z=lerpf(base.z,top.z,bevel);p.y=top.y*v
     if step==1 and level>0 and level<4:
      var source:Array=native.vertices[roundi(v*6)*16+(face*4)%16]
      var relief=absf(float(source[0])-float(native.crown[0]))+absf(float(source[2])-float(native.crown[2]))
      p-=normal*clampf(relief*.025,.02,.12)*sin(v*PI)
     wall.append(p+offset);pixels.append(wall_pixel(row,face,u,v))
   for level in 4:
    for step in 2:
     var i=level*3+step
     Parts.painted_quad(skin,wall[i],wall[i+3],wall[i+4],wall[i+1],[pixels[i],pixels[i+3],pixels[i+4],pixels[i+1]])
 skin.surface.generate_normals()
 var result=skin.finish();result.surface_set_material(0,material())
 return result

static func build(root:Node3D,placements:Array,size_:Vector2i,bits:PackedByteArray,origin:Vector2):
 var cells=collect(placements,size_,bits);var sections={};var cache={};var span=48.0
 for cell:Vector2i in cells:
  var p=origin+Vector2(cell)*3
  var key=Vector2i(floori(p.x/span),floori(p.y/span))
  if not sections.has(key):sections[key]=[]
  sections[key].append(cell)
 for key:Vector2i in sections:
  var node=MeshInstance3D.new();node.name="RecoveredCliffMass_%d_%d"%[key.x,key.y]
  node.position=Vector3(key.x*span,0,key.y*span)
  node.mesh=section_mesh(cells,sections[key],Vector3(origin.x,0,origin.y)-node.position,cache)
  root.add_child(node)
 root.set_meta("recovered_cliff_cells",cells.keys())
 root.set_meta("recovered_cliff_chunks",sections.size())

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
