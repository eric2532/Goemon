extends "res://scripts/forest/forest_freyja_terrain.gd"
## Explicit private source2000 terrain. No caller/default/live migration.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Caps=preload("res://scripts/forest/forest_east_bank_caps.gd")
var proposal:Dictionary={}
var private_field:Resource
var private_geometry:Dictionary={}
var private_mask:Texture2D
var private_mask_image:Image

func setup(data:Dictionary):
 var source=int(data.source)
 assert(source in [2000,2400],"Private low source terrain supports only the two original villages")
 var expected_size=[90.,120.] if source==2000 else [100.,100.]
 var expected_open=2718 if source==2000 else 4597
 assert(data.size==expected_size and int(data.counts.original_open)==expected_open,"Private low source terrain requires the verified original source dimensions and walk count")
 proposal=data;private_geometry.clear();private_mask=null;private_mask_image=null;variant="il_village" if source==2000 else "alyut";horizontal_scale=2.;expansion=1.
 private_field=Resource.new();var zero=PackedByteArray();zero.resize(int(data.native_width)*int(data.native_width))
 for pair in [["width",int(data.native_width)],["spacing",3.],["heights",PackedFloat32Array(data.native_heights)],["bed",PackedFloat32Array(data.native_heights)],["covered",PackedByteArray(data.native_covered)],["bridges",zero]]:private_field.set_meta(pair[0],pair[1])
 var floors=[];var origin=Vector2(data.source_origin[0],data.source_origin[1])
 for row:Dictionary in data.floor_rectangles:
  var r:Array=row.source_rect;var a=origin+Vector2(r[0]*3.-1.5,(r[1]+r[3]*.5)*3.-1.5);var b=a+Vector2(r[2]*3.,0)
  floors.append({"ax":a.x/6.,"az":a.y/6.,"bx":b.x/6.,"bz":b.y/6.,"width":r[3]*.5,"h0":row.height,"h1":row.height,"cap_start":false,"cap_end":false,"joined":true})
 configure(floors)
 for index in pieces.size():pieces[index].source_il_low_floor=true;pieces[index].source_rect=data.floor_rectangles[index].source_rect
 set_meta("east_il_low_source_private",true)

func terrain_field()->Resource:
 assert(private_field!=null,"Low Il must be initialized explicitly, never through the canonical field cache")
 return private_field
func coordinate(x:float,z:float)->Vector2:return (Vector2(x,z)-Vector2(proposal.native_origin[0],proposal.native_origin[1]))/3.
func geometry_entry()->Dictionary:return private_geometry
func uses_baked_apron()->bool:return false
func mask_origin()->Vector2:return Vector2(proposal.source_origin[0],proposal.source_origin[1])
func mask_texture()->Texture2D:
 if private_mask==null:
  var path=String(proposal.get("source_mask_path","res://assets/maps/falan/east_region/il_source_completion/mask.png"))
  assert(int(proposal.source)==2000 or proposal.has("source_mask_path"),"Standalone2400 requires its own source-derived private mask")
  private_mask_image=Image.load_from_file(path)
  assert(private_mask_image!=null and private_mask_image.get_size()==Vector2i(proposal.size[0],proposal.size[1]),"Private source mask must match the original village frame")
  private_mask=ImageTexture.create_from_image(private_mask_image);private_mask.set_meta("source_cpu_image",private_mask_image)
 return private_mask
func mask_image()->Image:
 mask_texture();return private_mask_image
func mask_bounds()->Rect2:return Rect2(proposal.source_bounds[0],proposal.source_bounds[1],proposal.source_bounds[2],proposal.source_bounds[3])

func height(x:float,z:float)->float:
 var physical=piece_height(x,z)
 if is_finite(physical):return physical
 # Source-blocked building/prop anchors still need a visual ground datum;
 # disk_clear/Native continue to use coverage, exact pieces and blocked cells.
 var cell=Vector2i(((Vector2(x,z)-Vector2(proposal.source_origin[0],proposal.source_origin[1]))/3.).round())
 var size_=Vector2i(proposal.size[0],proposal.size[1])
 if not Rect2i(Vector2i.ZERO,size_).has_point(cell):return 0.
 var row:Array=proposal.cells[cell.y*size_.x+cell.x]
 if int(row[2]) in [0,100] and int(row[3])<1000:return 0.
 return float(proposal.land_bank_height) if row[6] in ["dry","bank"] or int(row[3])>=1000 else float(proposal.water_height) if int(row[2]) in range(5000,5009) else 0.

func mesh()->ArrayMesh:
 if private_geometry.has("mesh"):return private_geometry.mesh
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);var origin=Vector2(proposal.source_origin[0],proposal.source_origin[1]);var high=float(proposal.land_bank_height)
 # Draw only original dry BG cells: bank contours own source-water PG1,
 # and no interpolated green triangles are introduced over water or void.
 for row:Array in proposal.cells:
  if int(row[2]) in [0,100] or int(row[2]) in range(5000,5009):continue
  var a=origin+Vector2(row[0],row[1])*3.-Vector2.ONE*1.5
  var p=[Vector3(a.x,high,a.y),Vector3(a.x+3.,high,a.y),Vector3(a.x+3.,high,a.y+3.),Vector3(a.x,high,a.y+3.)]
  for i in [0,1,2,0,2,3]:tool.set_normal(Vector3.UP);tool.add_vertex(p[i])
 var arrays=tool.commit_to_arrays();var result=tool.commit();result.set_meta("source_surface_arrays",Source.committed_arrays(arrays));private_geometry.mesh=result;return result

func collision()->ConcavePolygonShape3D:
 if private_geometry.has("collision"):return private_geometry.collision
 var faces=PackedVector3Array();var origin=Vector2(proposal.source_origin[0],proposal.source_origin[1])
 for row:Dictionary in proposal.floor_rectangles:
  var r:Array=row.source_rect;var a=origin+Vector2(r[0]*3.-1.5,r[1]*3.-1.5);var b=a+Vector2(r[2],r[3])*3.;var h=float(row.height)
  var p=[Vector3(a.x,h,a.y),Vector3(b.x,h,a.y),Vector3(b.x,h,b.y),Vector3(a.x,h,b.y)]
  for index in [0,1,2,0,2,3]:faces.append(p[index])
 var shape=ConcavePolygonShape3D.new();shape.set_faces(faces);private_geometry.collision=shape;return shape

func native_data(scale_:float=1.3)->Dictionary:
 var origin=Vector2(proposal.native_origin[0],proposal.native_origin[1]);var high=Vector2(proposal.native_bounds_max[0],proposal.native_bounds_max[1])
 var data={"width":width,"spacing":3.*scale_,"route_spacing":3.*scale_,"origin":Vector3(origin.x,0,origin.y)*scale_,"bounds_min":Vector3(origin.x,0,origin.y)*scale_,"bounds_max":Vector3(high.x,0,high.y)*scale_,"heights":heights.duplicate(),"covered":covered,"pieces":PackedFloat32Array(),"obstacle_min":PackedVector3Array(),"obstacle_max":PackedVector3Array()}
 for index in data.heights.size():data.heights[index]*=scale_
 for piece:Dictionary in pieces:data.pieces.append_array(PackedFloat32Array([piece.a.x*scale_,piece.a.y*scale_,piece.along.x,piece.along.y,piece.half*scale_,piece.length*scale_,piece.start*scale_,piece.end*scale_,piece.h0*scale_,piece.h1*scale_]))
 for r:Array in proposal.closed_rectangles:
  var a=Vector2(proposal.source_origin[0],proposal.source_origin[1])+Vector2(r[0]*3.-1.5,r[1]*3.-1.5)
  data.obstacle_min.append(Vector3(a.x,-10,a.y)*scale_);data.obstacle_max.append(Vector3(a.x+r[2]*3.,30,a.y+r[3]*3.)*scale_)
 return data

func build_bank_visuals(root:Node3D,source_rows:Array):
 var groups={};var drop=float(proposal.land_bank_height)-float(proposal.water_height)
 for row:Dictionary in source_rows:
  var serial=int(row.serial)
  if not groups.has(serial):groups[serial]=[]
  groups[serial].append(Transform3D(Basis.IDENTITY,Vector3(row.anchor[0],proposal.land_bank_height,row.anchor[1])))
 for serial:int in groups:
  var node=MultiMeshInstance3D.new();node.name="LowIlNativeBank_"+str(serial);node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
  node.multimesh.mesh=Caps.mesh(serial,drop);node.multimesh.instance_count=groups[serial].size()
  for index in groups[serial].size():node.multimesh.set_instance_transform(index,groups[serial][index])
  node.set_meta("source_graphic",serial);node.set_meta("source_il_low_visual",true);root.add_child(node)
