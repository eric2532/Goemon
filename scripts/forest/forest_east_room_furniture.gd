extends RefCounted
## Whole native-compatible furniture masters, fitted once and shared across placements.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const ROOT="res://assets/maps/falan/east_region/room_furniture/"
const IDS=[10038,11023,11031,11038,11039,11040,16035,16036,16038,16039,16040,16044,16046,16047,16049,16050,16051,16052,16053,16055,16056,16057,16058,16059,16062,16085,16087,16098,16147,16150,16631,17000,17001,17513,17514,17515,17588,17589]
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static func owns(serial:int)->bool:return serial in IDS
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog

static func fitted(raw:Mesh,g:Dictionary,turn:float=0.)->Mesh:
 var b:Array=g.bounds;var target=Rect2(g.origin[0]+b[0],g.origin[1]+b[1],b[2]-b[0],b[3]-b[1])
 var rotated=East.transformed_existing(raw,Transform3D(Basis(Vector3.UP,turn),Vector3.ZERO))
 var pose=Fit.measure(Fit.mesh_points(rotated),"",Basis(Vector3.UP,PI*.5),target)
 return East.owner_frame(East.transformed_existing(rotated,pose))

static func native_front(model:Mesh,serial:int,g:Dictionary,frame_only:bool=false)->Mesh:
 var skin=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(ROOT+str(serial)+"-front.png"),.045)
 for slot in model.get_surface_count():
  if frame_only and slot!=0:continue
  var arrays:Array=model.get_meta("east_cpu_arrays")[slot] if model.has_meta("east_cpu_arrays") else model.surface_get_arrays(slot)
  var indices:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty()
  var count_:int=indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()
  for i in range(0,count_,3):
   var ids=[indices[i],indices[i+1],indices[i+2]] if indexed else [i,i+1,i+2]
   var n:Vector3=(arrays[Mesh.ARRAY_NORMAL][ids[0]]+arrays[Mesh.ARRAY_NORMAL][ids[1]]+arrays[Mesh.ARRAY_NORMAL][ids[2]]).normalized()
   if n.y>.45:continue
   if n.y<=.45 and n.dot(Vector3(-1,0,1))<=.15:continue
   for j in 3:
    var p:Vector3=arrays[Mesh.ARRAY_VERTEX][ids[j]];skin.projected_vertex(p+n*.003,n,p)
 return East.combine([model,skin.finish()])

static func bed_frame(serial:int,color:Color)->Mesh:
 # Reuse the complete mattress/legs. Replace incompatible solid boards with the
 # observed metal bars, open lattice or rounded timber board from this family.
 var original=Furniture.bed(4.,6.,-1);var arrays=original.surface_get_arrays(0)
 var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
 if ids.is_empty():
  ids.resize(arrays[Mesh.ARRAY_VERTEX].size())
  for i in ids.size():ids[i]=i
 var wood=Furniture.tool();var new_parts=Furniture.tool()
 for i in range(0,ids.size(),3):
  var vertices=[arrays[Mesh.ARRAY_VERTEX][ids[i]],arrays[Mesh.ARRAY_VERTEX][ids[i+1]],arrays[Mesh.ARRAY_VERTEX][ids[i+2]]]
  var lo=INF;var hi=-INF;var across=0.;var head=true;var foot=true
  for p:Vector3 in vertices:
   lo=minf(lo,p.y);hi=maxf(hi,p.y);across=maxf(across,absf(p.x));head=head and absf(p.z+2.46)<.13;foot=foot and absf(p.z-2.46)<.13
  if across<1.34 and (head and lo>1.1 or foot and lo>.55 and hi<1.14):continue
  for j in 3:wood.set_normal(arrays[Mesh.ARRAY_NORMAL][ids[i+j]]);wood.add_vertex(vertices[j])
 var metal=serial in [16035,16036,16038]
 var lattice=serial in [16044,16046,16047,16049,16050,16055,16056,16057,16058]
 for end in [-1,1]:
  var z=end*2.46;var high=1.94 if end==-1 else 1.27
  if metal or lattice:
   var last=Vector3(-1.28,high,z)
   for step in range(1,17):
    var x=-1.28+2.56*step/16.;var rise=.16*(1.-pow(x/1.28,2));var next=Vector3(x,high+rise,z)
    Furniture.Parts.rod(new_parts,last,next,.055 if metal else .075);last=next
   for bar in range(1,8):
    var x=-1.28+2.56*bar/8.
    Furniture.Parts.rod(new_parts,Vector3(x,.99 if end==-1 else .69,z),Vector3(x,high+.16*(1.-pow(x/1.28,2)),z),.035 if metal else .045)
   Furniture.Parts.rod(new_parts,Vector3(-1.28,1.02 if end==-1 else .70,z),Vector3(1.28,1.02 if end==-1 else .70,z),.045)
  else:
   var outline=PackedVector2Array([Vector2(-1.28,.96 if end==-1 else .61),Vector2(1.28,.96 if end==-1 else .61)])
   for step in range(16,-1,-1):
    var x=-1.28+2.56*step/16.;outline.append(Vector2(x,high+.22*(1.-pow(x/1.28,2))))
   var shape=load("res://scripts/forest/forest_falan_building_shapes.gd").extrude(outline,.17)
   new_parts.append_from(shape,0,Transform3D(Basis.IDENTITY,Vector3(0,0,z)))
 var additions=new_parts.commit();var extra=additions.surface_get_arrays(0)
 var extra_ids:Variant=extra[Mesh.ARRAY_INDEX];var indexed=extra_ids is PackedInt32Array and not extra_ids.is_empty()
 for i in (extra_ids.size() if indexed else extra[Mesh.ARRAY_VERTEX].size()):
  var index:int=extra_ids[i] if indexed else i
  wood.set_normal(extra[Mesh.ARRAY_NORMAL][index]);wood.add_vertex(extra[Mesh.ARRAY_VERTEX][index])
 var frame=wood.commit();frame.surface_set_material(0,load("res://scripts/forest/forest_stone_fort.gd").material(color,false))
 var pieces=[frame]
 for slot in [1,2]:
  var part=ArrayMesh.new();part.add_surface_from_arrays(original.surface_get_primitive_type(slot),original.surface_get_arrays(slot));part.surface_set_material(0,original.surface_get_material(slot));pieces.append(part)
 return East.combine(pieces)

static func slatted_chair()->Mesh:
 var back=Furniture.tool()
 for side in [-1,1]:Furniture.Parts.rod(back,Vector3(.54,.87,side*.53),Vector3(.59,2.35,side*.63),.052)
 for bar in [-1,0,1]:Furniture.Parts.rod(back,Vector3(.61,1.18,bar*.30),Vector3(.65,2.20,bar*.32),.040)
 var last=Vector3(.59,2.35,-.63)
 for step in range(1,13):
  var z=-.63+1.26*step/12.;var next=Vector3(.59+.06*(1.-pow(z/.63,2)),2.35-.15*(1.-pow(z/.63,2)),z)
  Furniture.Parts.rod(back,last,next,.055);last=next
 var frame=back.commit();frame.surface_set_material(0,load("res://scripts/forest/forest_stone_fort.gd").material(Color("6b3624"),false))
 return East.combine([Furniture.chair(false),frame])

static func bookcase_shell()->Mesh:
 # Keep the compatible complete outer case. Native book/door artwork supplies
 # its small interior detail instead of projecting it over mismatched rows.
 var raw=Furniture.bookcase(2.,5.,false);var result=ArrayMesh.new()
 result.add_surface_from_arrays(raw.surface_get_primitive_type(0),raw.surface_get_arrays(0));result.surface_set_material(0,raw.surface_get_material(0))
 var arrays=raw.surface_get_arrays(1);var indices:Variant=arrays[Mesh.ARRAY_INDEX]
 var indexed=indices is PackedInt32Array and not indices.is_empty();var count_:int=indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()
 var trim=Furniture.tool()
 for i in range(0,count_,3):
  var ids=[indices[i],indices[i+1],indices[i+2]] if indexed else [i,i+1,i+2]
  var top=true;var bottom=true
  for index:int in ids:
   top=top and arrays[Mesh.ARRAY_VERTEX][index].y>3.55
   bottom=bottom and arrays[Mesh.ARRAY_VERTEX][index].y<.23
  if not top and not bottom:continue
  for index:int in ids:trim.set_normal(arrays[Mesh.ARRAY_NORMAL][index]);trim.add_vertex(arrays[Mesh.ARRAY_VERTEX][index])
 var edge=trim.commit();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,edge.surface_get_arrays(0));result.surface_set_material(1,raw.surface_get_material(1))
 return result

static func bookcase_face(model:Mesh,serial:int,g:Dictionary)->Mesh:
 var b=model.get_aabb();var a=b.position;var c=b.end
 var skin=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(ROOT+str(serial)+"-front.png"),.045)
 if int(g.footprint[0])>int(g.footprint[1]):
  var z=c.z-.025
  skin.quad(Vector3(a.x,a.y,z),Vector3(a.x,c.y,z),Vector3(c.x,c.y,z),Vector3(c.x,a.y,z))
 else:
  var x=a.x+.025
  skin.quad(Vector3(x,a.y,a.z),Vector3(x,c.y,a.z),Vector3(x,c.y,c.z),Vector3(x,a.y,c.z))
 return East.combine([native_front(model,serial,g),skin.finish()])

static func hammock(graphic:Dictionary)->Mesh:
 # Reuse the exact existing Sokia post/beam/sag geometry. Native cloth paint
 # belongs on cloth, while closed posts carry separate timber around all sides.
 var raw=load("res://scripts/forest/forest_sokia_house_art.gd").mesh(16631,graphic,Art.solid_texture(int(graphic.page)))
 raw=East.owner_frame(raw)
 var arrays=raw.surface_get_arrays(0);var indices:Variant=arrays[Mesh.ARRAY_INDEX]
 var indexed=indices is PackedInt32Array and not indices.is_empty();var count_:int=indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()
 var wood=East.structure();var cloth=SurfaceTool.new();cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(0,count_,3):
  var ids=[indices[i],indices[i+1],indices[i+2]] if indexed else [i,i+1,i+2]
  var fabric=false
  for index:int in ids:
   if absf(arrays[Mesh.ARRAY_VERTEX][index].x)>.3:fabric=true
  for index:int in ids:
   var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index];var n:Vector3=arrays[Mesh.ARRAY_NORMAL][index]
   if fabric:cloth.set_normal(n);cloth.set_uv(arrays[Mesh.ARRAY_TEX_UV][index]);cloth.add_vertex(p)
   else:
    wood.surface.set_normal(n);wood.surface.set_uv2(wood.tiles.timber);wood.surface.set_uv(Vector2(p.x+p.z,-p.y)/1.8);wood.surface.add_vertex(p)
 var fabric_mesh=cloth.commit();fabric_mesh.surface_set_material(0,raw.surface_get_material(0))
 return East.combine([wood.finish(),fabric_mesh])

static func mesh(serial:int,graphic:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)]
 assert(g.source_rgba_sha256==graphic.rgba_sha256,"Regenerate the native furniture derivative")
 var role:String=g.role;var raw:Mesh;var result:Mesh
 var turn=PI*.5 if int(g.footprint[0])>int(g.footprint[1]) else 0.
 if role in ["hospital_bed","wood_bed"]:
  var color:Array=g.frame_rgb;raw=bed_frame(serial,Color(color[0],color[1],color[2]))
  result=fitted(raw,g,turn)
  var arrays=result.surface_get_arrays(2);var uv=PackedVector2Array()
  for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:uv.append(Vector2(p.x,p.z)/1.4)
  arrays[Mesh.ARRAY_TEX_UV]=uv
  var cloth:ShaderMaterial=Source.material(load(ROOT+str(serial)+"-bedding.png")).duplicate()
  cloth.set_shader_parameter("original_palette",false);cloth.set_shader_parameter("alpha_cutout",false)
  var quilt=ArrayMesh.new();quilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);quilt.surface_set_material(0,cloth)
  var pieces=[]
  for slot in [0,1]:
   var part=ArrayMesh.new();part.add_surface_from_arrays(result.surface_get_primitive_type(slot),result.surface_get_arrays(slot));part.surface_set_material(0,result.surface_get_material(slot));pieces.append(part)
  pieces.append(quilt);result=East.combine(pieces)
 elif role=="wood_chair":result=fitted(slatted_chair(),g,PI*.5 if serial==17515 else 0.)
 elif role=="bookcase":
  # The reused shelves open toward +X. Align that face with the native view;
  # 16087 is the original rear-panel drawing of the matching case family.
  var facing=turn if serial==16087 else -PI*.5 if int(g.footprint[0])>int(g.footprint[1]) else PI
  result=fitted(Furniture.bookcase(2.,5.,false) if serial==16087 else bookcase_shell(),g,facing)
  if serial!=16087:result=bookcase_face(result,serial,g)
 elif role in ["plain_bench","backed_wood_bench"]:
  var street=load("res://scripts/forest/forest_tina_street_details.gd");var template=10037 if role=="plain_bench" else 11041
  raw=street.bench_mesh(template,Art.data().graphics[str(template)]);result=fitted(raw,g,turn)
 elif serial in [11023,11031]:result=load("res://scripts/forest/forest_east_village_props.gd").mesh(serial)
 elif role=="hammock":result=hammock(graphic)
 assert(result!=null,"Every declared furniture role needs its compatible whole master")
 if role in ["hospital_bed","wood_bed","wood_chair"] or serial==16087:result=native_front(result,serial,g,role in ["hospital_bed","wood_bed"])
 result.set_meta("east_native_room_furniture",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("inferred_hidden_geometry",true)
 meshes[serial]=result
 return result
