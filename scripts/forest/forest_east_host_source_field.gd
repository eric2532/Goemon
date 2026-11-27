extends "res://scripts/forest/forest_freyja_terrain.gd"
## Private composite of immutable canonical CPU fields and original100 products.
var proposal:Dictionary={}
var private_field:Resource
var private_geometry:Dictionary={}
var private_mask:Texture2D
var private_image:Image
var raw=PackedByteArray()
var scope_bits=PackedByteArray()
var base_bed=PackedFloat32Array()
var modified:Dictionary={}
var bank_cells:Dictionary={}
var dry_floors:Dictionary={}

static func unpack(value:Dictionary)->PackedByteArray:
 var result=Marshalls.base64_to_raw(value.deflate).decompress(int(value.raw_bytes),FileAccess.COMPRESSION_DEFLATE)
 assert(result.size()==int(value.raw_bytes),"Private composite field blob is incomplete")
 return result

func setup(data:Dictionary):
 proposal=data;variant=data.area;horizontal_scale=2.;private_geometry.clear();modified.clear();bank_cells.clear();dry_floors.clear();private_mask=null;private_image=null
 raw=FileAccess.get_file_as_bytes(data.source_raw_path);assert(FileAccess.get_sha256(data.source_raw_path)==data.raw_sha256,"Private composite uses one merged original100 source")
 scope_bits=unpack(data.scope_bits);base_bed=unpack(data.base_bed).to_float32_array()
 private_field=Resource.new()
 for item in [["width",int(data.width)],["spacing",float(data.spacing)],["heights",unpack(data.heights).to_float32_array()],["bed",unpack(data.bed).to_float32_array()],["covered",unpack(data.covered)],["bridges",unpack(data.bridges)]]:private_field.set_meta(item[0],item[1])
 if data.has("diagonal_flips"):private_field.set_meta("diagonal_flips",unpack(data.diagonal_flips))
 var floors=[]
 for r:Array in data.water_rectangles:
  var a=source_point(Vector2(r[0]-.5,r[1]+r[3]*.5-.5));var axis=Vector2.RIGHT if variant=="north_coast" else Vector2.DOWN;var b=a+axis*float(r[2])*3.
  floors.append({"ax":a.x/6.,"az":a.y/6.,"bx":b.x/6.,"bz":b.y/6.,"width":r[3]*.5,"h0":2.,"h1":2.,"cap_start":false,"cap_end":false,"joined":true})
 for row:Dictionary in data.get("source_dry_floor_rectangles",[]):
  var r:Array=row.rect;var a=source_point(Vector2(r[0]-.5,r[1]+r[3]*.5-.5));var axis=Vector2.RIGHT if variant=="north_coast" else Vector2.DOWN;var b=a+axis*float(r[2])*3.
  floors.append({"ax":a.x/6.,"az":a.y/6.,"bx":b.x/6.,"bz":b.y/6.,"width":r[3]*.5,"h0":row.height,"h1":row.height,"cap_start":false,"cap_end":false,"joined":true})
  for z in range(r[1],r[1]+r[3]):
   for x in range(r[0],r[0]+r[2]):dry_floors[z*840+x]=float(row.height)
 configure(floors)
 # This existing source-floor marker is shared by the two private villages;
 # it keeps the fortress visual adapter off these genuine water floors too.
 for piece:Dictionary in pieces:piece.source_il_low_floor=true;piece.source_map=100
 for index in data.modified_quads:modified[int(index)]=true
 for index in data.bank_cells:bank_cells[int(index)]=true
 set_meta("east_source100_context_private",true);set_meta("source_raw_sha256",data.raw_sha256)

func source_point(cell:Vector2)->Vector2:return Vector2(cell.x*3.-1902.,cell.y*3.-333.) if variant=="north_coast" else Vector2(591.-cell.y*3.,cell.x*3.-1251.)
func source_cell(at:Vector2)->Vector2i:return Vector2i(((at+Vector2(1902,333))/3.).round()) if variant=="north_coast" else Vector2i(roundi((at.y+1251.)/3.),roundi((591.-at.x)/3.))
func index_of(cell:Vector2i)->int:return cell.y*840+cell.x if Rect2i(0,0,840,610).has_point(cell) else -1
func scoped(cell:Vector2i)->bool:
 var index=index_of(cell);return index>=0 and bool(scope_bits[index>>3]&(1<<(index&7)))
func source_open(cell:Vector2i)->bool:
 var index=index_of(cell);var bits:PackedByteArray=private_geometry.get("source_bits",PackedByteArray())
 if bits.is_empty():bits=Marshalls.base64_to_raw(proposal.source_native_bits);private_geometry.source_bits=bits
 return index>=0 and bool(bits[index>>3]&(1<<(index&7)))
func serial(cell:Vector2i,plane:int)->int:
 var index=index_of(cell);return raw.decode_u16(20+(plane*840*610+index)*2) if index>=0 else 0
func owns_source_bank(serial_:int,at:Vector2)->bool:
 var cell=source_cell(at);return serial_ in range(12500,12536) and bank_cells.has(index_of(cell)) and serial(cell,1)==serial_
func terrain_field()->Resource:
 assert(private_field!=null,"Original100 composite requires prepared current CPU inputs")
 return private_field
func coordinate(x:float,z:float)->Vector2:return (Vector2(x,z)-Vector2(proposal.origin[0],proposal.origin[1]))/spacing
func geometry_entry()->Dictionary:return private_geometry
func uses_baked_apron()->bool:return false
func mask_origin()->Vector2:return Vector2(proposal.mask_origin[0],proposal.mask_origin[1])
func mask_bounds()->Rect2:return Rect2(proposal.mask_bounds[0],proposal.mask_bounds[1],proposal.mask_bounds[2],proposal.mask_bounds[3])
func mask_texture()->Texture2D:
 if private_mask==null:
  private_image=Image.load_from_file(proposal.mask_path);assert(private_image!=null,"Original100 private source mask is missing")
  private_mask=ImageTexture.create_from_image(private_image);private_mask.set_meta("source_cpu_image",private_image)
 return private_mask
func mask_image()->Image:
 mask_texture();return private_image
func height(x:float,z:float)->float:
 var cell=source_cell(Vector2(x,z))
 if scoped(cell):
  if not source_open(cell) and proposal.visual_anchor_heights.has(str(index_of(cell))):return float(proposal.visual_anchor_heights[str(index_of(cell))])
  var support=_covered_height(x,z)
  if is_finite(support):return support
  if serial(cell,0) in [0,100] and serial(cell,1)<1000:return 0.
 return super.height(x,z)

func add_quad(tool,points:Array,normals:Array=[],flipped:bool=false):
 for triangle:Array in ([[0,1,2],[0,2,3]] if flipped else [[0,1,3],[1,2,3]]):
  var normal:Vector3=(points[triangle[2]]-points[triangle[0]]).cross(points[triangle[1]]-points[triangle[0]]).normalized()
  for index:int in triangle:tool.set_normal(normal if normals.is_empty() else normals[index]);tool.add_vertex(points[index])
func old_normal(x:int,z:int)->Vector3:
 var count=int(proposal.base_width)
 var dx=base_bed[z*count+mini(x+1,count-1)]-base_bed[z*count+maxi(x-1,0)]
 var dz=base_bed[mini(z+1,count-1)*count+x]-base_bed[maxi(z-1,0)*count+x]
 return Vector3(-dx,6.,-dz).normalized()
func old_normals(x:int,z:int,fine:bool=false)->Array:
 var result=[]
 for corner:Vector2i in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
  var fx=x+corner.x;var fz=z+corner.y
  if not fine:result.append(old_normal(fx,fz));continue
  var ix=fx/2;var iz=fz/2
  if fx%2==0 and fz%2==0:result.append(old_normal(ix,iz))
  elif fz%2==0:result.append((old_normal(ix,iz)+old_normal(ix+1,iz))*.5)
  elif fx%2==0:result.append((old_normal(ix,iz)+old_normal(ix,iz+1))*.5)
  else:result.append((old_normal(ix+1,iz)+old_normal(ix,iz+1))*.5)
 return result
func fine_points(x:int,z:int,values:PackedFloat32Array)->Array:
 var origin=Vector2(proposal.origin[0],proposal.origin[1]);var result=[]
 for corner:Vector2i in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
  var at=origin+Vector2(x+corner.x,z+corner.y)*spacing;result.append(Vector3(at.x,values[(z+corner.y)*width+x+corner.x],at.y))
 return result
func old_points(x:int,z:int)->Array:
 var result=[];var origin=Vector2(proposal.origin[0],proposal.origin[1]);var old_width=int(proposal.base_width)
 for corner:Vector2i in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
  var at=origin+Vector2(x+corner.x,z+corner.y)*3.;result.append(Vector3(at.x,base_bed[(z+corner.y)*old_width+x+corner.x],at.y))
 return result
func old_fine_points(x:int,z:int)->Array:
 var result=[];var origin=Vector2(proposal.origin[0],proposal.origin[1]);var old_width=int(proposal.base_width)
 for corner:Vector2i in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
  var fx=x+corner.x;var fz=z+corner.y;var ix=fx/2;var iz=fz/2;var i=iz*old_width+ix;var h:float
  if fx%2==0 and fz%2==0:h=base_bed[i]
  elif fz%2==0:h=(base_bed[i]+base_bed[i+1])*.5
  elif fx%2==0:h=(base_bed[i]+base_bed[i+old_width])*.5
  else:h=(base_bed[i+1]+base_bed[i+old_width])*.5
  var at=origin+Vector2(fx,fz)*spacing;result.append(Vector3(at.x,h,at.y))
 return result
func source_floor_points(index:int,high:float)->Array:
 var cell=Vector2(index%840,index/840);var a=source_point(cell-Vector2.ONE*.5);var b=source_point(cell+Vector2.ONE*.5);var low=a.min(b);var end=a.max(b)
 return [Vector3(low.x,high,low.y),Vector3(end.x,high,low.y),Vector3(end.x,high,end.y),Vector3(low.x,high,end.y)]
func mesh()->ArrayMesh:
 if private_geometry.has("mesh"):return private_geometry.mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);var bed:PackedFloat32Array=private_field.get_meta("bed");var columns=int(proposal.base_columns);var rows=int(proposal.base_rows)
 for z in rows-1:
  for x in columns-1:
   if not modified.has(z*(columns-1)+x):add_quad(tool,old_points(x,z),old_normals(x,z));continue
   for dz in 2:
    for dx in 2:
     var fx=x*2+dx;var fz=z*2+dz;var middle=Vector2(proposal.origin[0],proposal.origin[1])+Vector2(fx+.5,fz+.5)*spacing;var floor_=serial(source_cell(middle),0)
     var cell=source_cell(middle)
     if dry_floors.has(index_of(cell)):continue
     var flipped=not diagonal_flips.is_empty() and diagonal_flips[fz*width+fx]!=0
     if not scoped(cell):add_quad(tool,old_fine_points(fx,fz),old_normals(fx,fz,true),flipped);continue
     if floor_ in [0,100] or floor_ in range(5000,5009):continue
     add_quad(tool,fine_points(fx,fz,bed),[],flipped)
 for index:int in dry_floors:add_quad(tool,source_floor_points(index,dry_floors[index]),[Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP])
 var arrays=tool.commit_to_arrays();var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.set_meta("source_surface_arrays",arrays);private_geometry.mesh=result;return result
func collision()->ConcavePolygonShape3D:
 if private_geometry.has("collision"):return private_geometry.collision
 var faces=PackedVector3Array();var columns=int(proposal.base_columns);var rows=int(proposal.base_rows)
 for z in rows-1:
  for x in columns-1:
   if not modified.has(z*(columns-1)+x):
    var points=old_points(x,z)
    for index in [0,1,3,1,2,3]:faces.append(points[index])
    continue
   for dz in 2:
    for dx in 2:
     var fx=x*2+dx;var fz=z*2+dz;var middle=Vector2(proposal.origin[0],proposal.origin[1])+Vector2(fx+.5,fz+.5)*spacing;var cell=source_cell(middle)
     if dry_floors.has(index_of(cell)):continue
     if scoped(cell) and not source_open(cell):continue
     var points=fine_points(fx,fz,heights) if scoped(cell) else old_fine_points(fx,fz)
     if scoped(cell) and serial(cell,1)==252:
      for index in points.size():
       var p:Vector3=points[index];p.y=2.;points[index]=p
     var flipped=not diagonal_flips.is_empty() and diagonal_flips[fz*width+fx]!=0
     for index in ([0,1,2,0,2,3] if flipped else [0,1,3,1,2,3]):faces.append(points[index])
 for index:int in dry_floors:
  var points=source_floor_points(index,dry_floors[index])
  for corner in [0,1,3,1,2,3]:faces.append(points[corner])
 for index in faces.size():faces[index]=faces[index].snappedf(.0001)
 var result=ConcavePolygonShape3D.new();result.set_faces(faces);private_geometry.collision=result;return result

func native_data()->Dictionary:
 var origin=Vector3(proposal.origin[0],0,proposal.origin[1]);var result={"width":width,"spacing":spacing,"route_spacing":3.,"origin":origin,"heights":heights,"covered":covered,"pieces":PackedFloat32Array(),"obstacle_min":PackedVector3Array(),"obstacle_max":PackedVector3Array()}
 var flips=native_diagonal_flips()
 if not flips.is_empty():result.diagonal_flips=flips
 for p:Dictionary in pieces:result.pieces.append_array(PackedFloat32Array([p.a.x,p.a.y,p.along.x,p.along.y,p.half,p.length,p.start,p.end,p.h0,p.h1]))
 for r:Array in proposal.closed_rectangles:
  var a=source_point(Vector2(r[0]-.5,r[1]-.5));var b=source_point(Vector2(r[0]+r[2]-.5,r[1]+r[3]-.5))
  result.obstacle_min.append(Vector3(minf(a.x,b.x),-10,minf(a.y,b.y)));result.obstacle_max.append(Vector3(maxf(a.x,b.x),30,maxf(a.y,b.y)))
 return result
