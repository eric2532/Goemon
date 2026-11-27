extends RefCounted
## Native landmark paint on shared solid parts; the original map owner batches every placement.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Parts=preload("res://scripts/forest/forest_coastal_buildings.gd")
const Harbor=preload("res://scripts/forest/forest_tina_harbor_details.gd")
const Elsa=preload("res://scripts/forest/forest_elsa_scenery.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Surfaces=preload("res://assets/maps/falan/east_region/landmarks/surfaces.gd")
const Atlas=preload("res://assets/maps/falan/east_region/landmarks/surfaces.png")
const ROOT="res://assets/maps/falan/east_region/landmarks/"
const OWNER_HEIGHT_PER_PIXEL=.045
const OWNER_Y_SCALE=OWNER_HEIGHT_PER_PIXEL*Fit.VERTICAL
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static var textures:Dictionary={}
static var minor_meshes:Dictionary={}
static var rod_arrays:Array=[]

class PreparedSkin extends "res://scripts/forest/forest_coastal_mesh.gd":
 static var lit_surfaces:Dictionary={}
 func finish(retain_arrays:bool=false)->Mesh:
  var arrays=surface.commit_to_arrays();var result=ArrayMesh.new()
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var paint=material(texture,not tiles.is_empty())
  if not tiles.is_empty():
   if not lit_surfaces.has(texture):
    var lit:ShaderMaterial=paint.duplicate();lit.set_shader_parameter("original_palette",false)
    lit_surfaces[texture]=lit
   paint=lit_surfaces[texture]
  result.surface_set_material(0,paint)
  result.set_meta("east_cpu_arrays",[arrays])
  if retain_arrays:result.set_meta("source_surface_arrays",arrays)
  return result

static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"profiles.json"))
 return catalog

static func owns(_source_id:int,serial:int)->bool:return data().graphics.has(str(serial))

static func minor_prop_allowed(serial:int,_g:Dictionary)->bool:
 # Individually inspected native contact art: trimmed hedges, thin leaves and flowers.
 # Structural walls, cave faces, gates, furniture and existing exact owners stay outside this fallback.
 return serial in [1233045,1233046,1230116,1230117,1230119,1230120,1260089,1260091,1260092,15011,1238095,1260002,1260003,1260004,1260005,1260006,1260090,1260093,1260094,1260182,1260402,1230115,1230118,1231041,1231048,1231049,1231050,1231051,1233047,1233048,1233049,1233050,1235039,1235040,1235041,1235042,1235043,1235044]

static func minor_prop_mesh(serial:int,g:Dictionary)->Mesh:
 # Called only for the East owner's remaining generic `prop` family, after exact owners.
 # Keep small unknown native artwork legible instead of stretching it around a cube.
 if minor_meshes.has(serial):return minor_meshes[serial]
 if serial in [1260182,1260402] or float(g.rect[3])<=float(g.rect[2])*.60:
  minor_meshes[serial]=owner_frame(native_floor_piece(g));return minor_meshes[serial]
 var skin=native_skin(g);var ground=float(g.origin[1])+float(g.rect[3])-3.;var corners=[]
 if serial in [1238095,1260002,1260003,1260004,1260005,1260006,1260090,1260093,1260094,1230115,1230118,1231041,1231048,1231049,1231050,1231051,1233047,1233048,1233049,1233050,1235039,1235040,1235041,1235042,1235043,1235044]:
  # Original hanging height remains meaningful, especially for ceiling cobwebs.
  ground=-(float(g.footprint[0])+float(g.footprint[1])-2.)*12.
 for pixel in [Vector2.ZERO,Vector2(0,g.rect[3]),Vector2(g.rect[2],g.rect[3]),Vector2(g.rect[2],0)]:corners.append(projected(pixel,g,0.,ground))
 var normal:Vector3=(corners[2]-corners[0]).cross(corners[1]-corners[0]).normalized()
 for index in [0,1,2,0,2,3]:skin.projected_vertex(corners[index],normal,corners[index])
 for index in [3,2,1,3,1,0]:skin.projected_vertex(corners[index]-normal*.015,-normal,corners[index])
 var result=owner_frame(skin.finish());result.set_meta("east_minor_source_card",serial);result.set_meta("east_inferred_depth",false);minor_meshes[serial]=result
 return result
static func v(row:Array)->Vector2:return Vector2(row[0],row[1])

static func point(pixel:Vector2,height:float,g:Dictionary)->Vector3:
 var native=pixel+Vector2(g.origin[0],g.origin[1]);var floor_y=native.y+height*Fit.VERTICAL
 return Vector3(native.x*3./64.-floor_y/16.,height,native.x*3./64.+floor_y/16.)

static func projected(pixel:Vector2,g:Dictionary,slope:float,offset:float)->Vector3:
 var native=pixel+Vector2(g.origin[0],g.origin[1]);var ground=slope*native.x+offset
 return point(pixel,(ground-native.y)/Fit.VERTICAL,g)

static func texture(g:Dictionary)->Texture2D:
 var page=int(g.page)
 if not textures.has(page):textures[page]=load(Art.ROOT+Art.data().pages[page])
 return textures[page]

static func native_skin(g:Dictionary,paint:Texture2D=null):
 var result=PreparedSkin.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture(g) if paint==null else paint,1./Fit.VERTICAL)
 result.reflection_threshold=2.
 return result

static func painted_quad(skin,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
 var normal=(c-a).cross(b-a)
 if normal.length_squared()<.00000001:normal=(d-a).cross(b-a)
 if normal.length_squared()<.00000001:return
 normal=normal.normalized();var points=[a,b,c,d]
 for index in [0,1,2,0,2,3]:skin.projected_vertex(points[index]+normal*.018,normal,points[index])

static func structure():
 var result=PreparedSkin.new([],Atlas,1./Fit.VERTICAL);result.tiles=Surfaces.TILES
 result.pitches={"plaster":.65,"brick":1.4,"stone":.8,"roof_gold":2.4,"roof_blue":2.5,"roof_red":2.4,"roof_green":2.4,"timber":1.8,"bark":1.4,"living_bark":2.6,"gold":.6,"rope":.7,"dark":1.4,"blue_wood":1.4}
 return result

static func rod(target,a:Vector3,b:Vector3,radius:float,part:String):
 # Exact existing Harbor.rod primitive/UVs, retained on the CPU once instead of one GPU readback per rail.
 var delta=b-a
 if delta.length_squared()<.000001:return
 if rod_arrays.is_empty():Harbor.Parts.prepare_primitives();rod_arrays=Harbor.Parts.cylinder.surface_get_arrays(0)
 var pose=Transform3D(Basis(Quaternion(Vector3.UP,delta.normalized())).scaled_local(Vector3(radius*2,delta.length(),radius*2)),(a+b)*.5)
 var normals=pose.basis.inverse().transposed()
 for index in rod_arrays[Mesh.ARRAY_INDEX]:
  target.surface.set_normal((normals*rod_arrays[Mesh.ARRAY_NORMAL][index]).normalized())
  target.surface.set_uv(rod_arrays[Mesh.ARRAY_TEX_UV][index]);target.surface.set_uv2(target.tiles[part]);target.surface.add_vertex(pose*rod_arrays[Mesh.ARRAY_VERTEX][index])

static func combine(parts:Array)->Mesh:
 var result=ArrayMesh.new();var retained=[]
 for mesh in parts:
  if mesh==null:continue
  for surface in mesh.get_surface_count():
   var arrays:Array=mesh.get_meta("east_cpu_arrays")[surface] if mesh.has_meta("east_cpu_arrays") else mesh.surface_get_arrays(surface)
   result.add_surface_from_arrays(mesh.surface_get_primitive_type(surface),arrays);retained.append(arrays)
   result.surface_set_material(result.get_surface_count()-1,mesh.surface_get_material(surface))
 result.set_meta("east_cpu_arrays",retained)
 return result

static func mesh(_source_id:int,serial:int,g:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var spec:Dictionary=data().graphics[str(serial)];var result:Mesh
 match spec.kind:
  "tree":
   var row:Dictionary=g.duplicate(true);row.cut=[spec.source_serial]
   result=Elsa.fitted_model(spec.asset,row,Rect2(spec.visible[0],spec.visible[1],spec.visible[2]-spec.visible[0],spec.visible[3]-spec.visible[1]))
  "seasonal_tree","native_branch_tree","native_canopy_tree":result=load("res://scripts/forest/forest_east_tree_families.gd").mesh(g,spec)
  "hip_house":result=house(g,spec)
  "compound":result=compound(g,spec)
  "native_foliage":result=foliage(g,load(ROOT+str(serial)+"-foliage.png"),[0,0,g.rect[2],g.rect[3]],float(spec.visible[3])+float(g.origin[1]))
  "source_rock":result=source_rock(g,spec,load(ROOT+str(serial)+"-rock-front.png"))
  "statue":
   var plinth={"blocks":spec.get("blocks",[])}
   result=combine([compound(g,plinth),sculpted_relief(g,spec,load(ROOT+str(serial)+"-back.png"),load(ROOT+str(serial)+"-front.png"))])
  "relief":result=relief(g,spec,load(ROOT+str(serial)+"-back.png"),load(ROOT+str(serial)+"-front.png"))
  "source_islet":result=source_islet(g,spec)
  "boat":result=boat(g,spec)
  "mast":result=mast(g,spec)
  "classic_reuse":result=classic_reuse(serial,g,spec)
  "shelter":result=shelter(g,spec)
  "log_deck":result=log_deck(g,spec)
  "mine_frame":result=mine_frame(g,spec)
  "native_floor_piece":result=native_floor_piece(g)
  "rope_post":result=rope_post(g)
  "bridge_gate":result=bridge_gate(serial,g)
 if result!=null:
  if spec.get("height_frame","")!="original-owner":result=owner_frame(result)
  result.set_meta("east_source_graphic",serial);result.set_meta("east_inferred_reverse",true);meshes[serial]=result
 return result

static func transformed_existing(reference:Mesh,pose:Transform3D,override:Material=null)->Mesh:
 var result=ArrayMesh.new();var retained=[];var normal=pose.basis.inverse().transposed()
 for slot in reference.get_surface_count():
  var arrays:Array=reference.get_meta("east_cpu_arrays")[slot].duplicate() if reference.has_meta("east_cpu_arrays") else reference.surface_get_arrays(slot)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate();var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL].duplicate()
  for i in vertices.size():vertices[i]=pose*vertices[i];normals[i]=(normal*normals[i]).normalized()
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
  result.add_surface_from_arrays(reference.surface_get_primitive_type(slot) if reference is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES,arrays);retained.append(arrays)
  var paint:Material=override if override!=null else reference.surface_get_material(slot)
  if paint is ShaderMaterial and paint.get_shader_parameter("falan_source_projection")==true:
   paint=paint.duplicate();var frame:Transform3D=paint.get_shader_parameter("falan_source_frame")
   paint.set_shader_parameter("falan_source_local",true);paint.set_shader_parameter("falan_source_frame",frame*pose.affine_inverse())
  result.surface_set_material(slot,paint)
 result.set_meta("east_cpu_arrays",retained)
 return result

static func reusable_node_mesh(root:Node3D)->Mesh:
 var parts=[];var pending=[[root,Transform3D.IDENTITY]]
 while not pending.is_empty():
  var item:Array=pending.pop_back();var owner:Node3D=item[0];var pose:Transform3D=item[1]*owner.transform
  if owner is MeshInstance3D and owner.mesh!=null:parts.append(transformed_existing(owner.mesh,pose,owner.material_override))
  if owner is MultiMeshInstance3D and owner.multimesh!=null:
   for index in owner.multimesh.instance_count:parts.append(transformed_existing(owner.multimesh.mesh,pose*owner.multimesh.get_instance_transform(index),owner.material_override))
  for child in owner.get_children():
   if child is Node3D:pending.append([child,pose])
 return combine(parts)

static func classic_reuse(serial:int,g:Dictionary,spec:Dictionary)->Mesh:
 var reference:Mesh
 match spec.kit:
  "il_chief":reference=load("res://scripts/forest/forest_il_chief.gd").prepare()
  "coastal_village":reference=load("res://scripts/forest/forest_east_village_buildings.gd").prepare(serial)
  "il_house":reference=load("res://scripts/forest/forest_east_village_buildings.gd").prepare(serial)
  "falan_house":reference=load("res://scripts/forest/forest_falan_houses.gd").shape("falan_townhouse",int(spec.style),serial)
  "falan_special":
   var kit=load("res://scripts/forest/forest_falan_special_exteriors.gd");reference=kit.prepare(kit.SPECS[Vector2i(-4,18)])
  "falan_office":
   var kit=load("res://scripts/forest/forest_falan_civic_exterior.gd");var root=Node3D.new();var row:Array=kit.SHELLS[Vector2i(-42,-23)].duplicate();row[3]=Vector2.ZERO
   kit.build(root,Vector3.ZERO,row);reference=reusable_node_mesh(root);root.free()
  "falan_round_tower":reference=load("res://scripts/forest/forest_falan_fort_parts.gd").prepare(serial)
  "writing_desk":reference=load("res://scripts/forest/forest_falan_interior_furniture.gd").desk(float(g.footprint[0])*3.,float(g.footprint[1])*3.,true)
 assert(reference!=null,"Exact existing source kit must produce a mesh")
 if spec.has("turn"):reference=transformed_existing(reference,Transform3D(Basis(Vector3.UP,deg_to_rad(float(spec.turn))),Vector3.ZERO))
 var target=Rect2(Vector2(g.origin[0],g.origin[1])+v(spec.visible),Vector2(spec.visible[2]-spec.visible[0],spec.visible[3]-spec.visible[1]))
 var pose=Fit.measure(Fit.mesh_points(reference),"",Basis(Vector3.UP,PI*.5),target)
 var result=transformed_existing(reference,pose)
 if spec.has("finial"):result=combine([result,finial(g,spec,Vector3.ZERO)])
 result.set_meta("east_reused_owner",spec.owner)
 return result

static func shelter(g:Dictionary,spec:Dictionary)->Mesh:
 var wood=structure();var native=native_skin(g);var h=float(spec.wall_pixels)/Fit.VERTICAL
 var left=point(v(spec.feet[0]),0.,g);var near=point(v(spec.feet[1]),0.,g);var right=point(v(spec.feet[2]),0.,g)
 var eleft=point(v(spec.eaves[0]),h,g);var enear=point(v(spec.eaves[1]),h,g);var eright=point(v(spec.eaves[2]),h,g)
 var ring=[near,left,left+right-near,right]
 for pixel in spec.post_pixels:
  var at=point(v(pixel),0.,g);rod(wood,at,at+Vector3.UP*h,.16,"timber")
 wood.part=spec.get("wall","timber")
 # Only the observed end is closed; the long feeding side remains open.
 native.quad(ring[1],ring[1]+Vector3.UP*h,ring[2]+Vector3.UP*h,ring[2])
 wood.quad(ring[2],ring[2]+Vector3.UP*h,ring[3]+Vector3.UP*h,ring[3])
 for i in 4:
  rod(wood,ring[i]+Vector3.UP*h,ring[(i+1)%4]+Vector3.UP*h,.14,"timber")
  rod(wood,ring[i]+Vector3.UP*.48,ring[(i+1)%4]+Vector3.UP*.48,.10,"timber")
 var parts=[native.finish(),wood.finish(),gable_roof(g,spec,[enear,eleft,eleft+eright-enear,eright])]
 for box in spec.get("details",[]):parts.append(finial(g,{"finial":box},Vector3.ZERO))
 return combine(parts)

static func log_deck(g:Dictionary,spec:Dictionary)->Mesh:
 var wood=structure();var count_=int(spec.logs)
 for index in count_:
  var t=(index+.5)/count_;var a=point(v(spec.near[0]).lerp(v(spec.near[1]),t),.24,g);var b=point(v(spec.far[0]).lerp(v(spec.far[1]),t),.24,g)
  rod(wood,a,b,.25,"timber")
  for fraction in [.1,.9]:
   var at=a.lerp(b,fraction);var side=(b-a).normalized().cross(Vector3.UP)*.28
   rod(wood,at-side+Vector3.UP*.18,at+side+Vector3.UP*.18,.035,"rope")
 return wood.finish()

static func mine_frame(g:Dictionary,spec:Dictionary)->Mesh:
 var solid=structure();var native=native_skin(g);var ground=float(g.origin[1])+float(spec.feet[1][1]);var rim=[];var back=[];var recess=Vector3(1,0,-1).normalized()*2.0
 for pixel in spec.rim:
  var at=projected(v(pixel),g,0.,ground);rim.append(at);back.append(at+recess)
 for index in rim.size()-1:
  rod(solid,rim[index],rim[index+1],.32,"timber");solid.part="timber";solid.quad(rim[index],back[index],back[index+1],rim[index+1])
 var center=Vector3.ZERO
 for at in back:center+=at/back.size()
 solid.part="dark"
 for index in back.size()-1:solid.quad(back[index],center,back[index+1],back[index+1])
 var h=float(spec.wall_pixels)/Fit.VERTICAL;var eleft=point(v(spec.eaves[0]),h,g);var enear=point(v(spec.eaves[1]),h,g);var eright=point(v(spec.eaves[2]),h,g)
 native.quad(rim[-1],rim[0],rim[0]+recess*.25,rim[-1]+recess*.25)
 return combine([solid.finish(),native.finish(),gable_roof(g,spec,[enear,eleft,eleft+eright-enear,eright])])

static func native_floor_piece(g:Dictionary)->Mesh:
 var native=native_skin(g);var edge=structure();edge.part="timber";var corners=[]
 for pixel in [Vector2.ZERO,Vector2(g.rect[2],0),Vector2(g.rect[2],g.rect[3]),Vector2(0,g.rect[3])]:corners.append(point(pixel,.04,g))
 native.quad(corners[0],corners[1],corners[2],corners[3])
 for index in 4:
  var a:Vector3=corners[index];var b:Vector3=corners[(index+1)%4]
  edge.quad(a,b,b-Vector3.UP*.04,a-Vector3.UP*.04)
 return combine([native.finish(),edge.finish()])

static func rope_post(g:Dictionary)->Mesh:
 var w=float(g.rect[2]);var h=float(g.rect[3]);var base=Vector2(w*.52,h-20.);var top=Vector2(w*.52,14.)
 var ground=base.y+float(g.origin[1]);var rope=structure()
 var foot=projected(base,g,0.,ground);var head=projected(top,g,0.,ground)
 rod(rope,foot,head,.055,"rope")
 rod(rope,projected(Vector2(5,1),g,0.,ground),projected(Vector2(w-8,25),g,0.,ground),.055,"rope")
 var planks=native_skin(g);var low=h-39.;var pixels=[Vector2(0,low),Vector2(0,h),Vector2(w,h),Vector2(w,low)];var points=[]
 for pixel in pixels:points.append(point(pixel,.06,g))
 planks.quad(points[0],points[1],points[2],points[3])
 return combine([rope.finish(),planks.finish()])

static func bridge_gate(serial:int,g:Dictionary)->Mesh:
 var w=float(g.rect[2]);var h=float(g.rect[3]);var base=Vector2(w*.51,h-8.);var ground=base.y+float(g.origin[1]);var solid=structure()
 var foot=projected(base,g,0.,ground);var top=projected(Vector2(w*.51,6),g,0.,ground)
 solid.part="stone";Parts.kili_round(solid,foot,[Vector2(1.18,0),Vector2(1.22,3.),Vector2(.95,4.)])
 solid.part="timber";Parts.kili_round(solid,foot+Vector3.UP*4.,[Vector2(.91,0),Vector2(.91,2.7),Vector2(.42,3.1)])
 rod(solid,foot+Vector3.UP*6.2,top,.30,"timber")
 var reverse=serial in [1260075,1260312];var a=Vector2(3,6 if reverse else h*.30);var b=Vector2(w-3,h*.30 if reverse else 6)
 for offset in [0.,12.]:rod(solid,projected(a+Vector2(0,offset),g,0.,ground),projected(b+Vector2(0,offset),g,0.,ground),.19,"timber")
 var front=finial(g,{"finial":[0,0,int(w),int(h*.44)]},Vector3(-ground/16.,0,ground/16.))
 return combine([solid.finish(),front])

static func owner_frame(reference:Mesh)->Mesh:
 var result=transformed_existing(reference,Transform3D(Basis.IDENTITY.scaled(Vector3(1.,OWNER_Y_SCALE,1.)),Vector3.ZERO))
 result.set_meta("east_owner_height_per_pixel",OWNER_HEIGHT_PER_PIXEL)
 return result

static func house(g:Dictionary,spec:Dictionary)->Mesh:
 var native=native_skin(g);var solid=structure();var roots=structure();roots.part=spec.get("living_root_material","bark");var base_level=float(spec.get("level_pixels",0))/Fit.VERTICAL;var h=float(spec.wall_pixels)/Fit.VERTICAL
 var left=point(v(spec.feet[0]),base_level,g);var near=point(v(spec.feet[1]),base_level,g);var right=point(v(spec.feet[2]),base_level,g)
 var ring=[near,left,left+right-near,right]
 if spec.get("living_root_walls",false):solid.pitches.living_bark=2.6;roots.pitches.living_bark=2.6
 if spec.get("living_root_walls",false):
  var far:Vector3=left+right-near
  ring=[near,left,far.lerp(left,.13),far.lerp(right,.13),right]
 for i in ring.size():
  var j=(i+1)%ring.size();var observed=i==0 or i==ring.size()-1
  var root_continuation=i in spec.get("root_continuation_faces",[])
  solid.part=spec.get("living_root_material","bark") if spec.get("living_root_walls",false) and (not observed or root_continuation) else spec.get("wall","plaster");solid.quad(ring[j],ring[j]+Vector3.UP*h,ring[i]+Vector3.UP*h,ring[i])
  if observed:painted_quad(native,ring[j],ring[j]+Vector3.UP*h,ring[i]+Vector3.UP*h,ring[i])
  if not observed or root_continuation:
   var outward:Vector3=(ring[i]+Vector3.UP*h-ring[j]).cross(Vector3.UP*h).normalized();var shift=outward*.025
   solid.part=spec.get("base_material","brick");solid.quad(ring[j]+shift,ring[j]+shift+Vector3.UP*h*.32,ring[i]+shift+Vector3.UP*h*.32,ring[i]+shift)
   if spec.has("back_upper_material"):
    solid.part=spec.back_upper_material;solid.quad(ring[j]+shift+Vector3.UP*h*.55,ring[j]+shift+Vector3.UP*h,ring[i]+shift+Vector3.UP*h,ring[i]+shift+Vector3.UP*h*.55)
   var tangent:Vector3=(ring[i]-ring[j]).normalized();var half=minf(1.1,ring[i].distance_to(ring[j])*.12)
   if spec.get("living_root_walls",false):
    # Plaster remains in bounded infill panels; broad structural bark carries around the corner.
    solid.part="plaster"
    solid.quad(ring[j].lerp(ring[i],.18)+shift+Vector3.UP*h*.21,ring[j].lerp(ring[i],.27)+shift+Vector3.UP*h*.83,ring[j].lerp(ring[i],.79)+shift+Vector3.UP*h*.89,ring[j].lerp(ring[i],.84)+shift+Vector3.UP*h*.27)
    for fraction in [.08,.51,.92]:
     var low:Vector3=ring[j].lerp(ring[i],fraction)+outward*.12
     var drift=tangent*(.58 if fraction<.5 else -.58)
     var bend=low+Vector3.UP*h*.48+drift+outward*.20
     var high=low+Vector3.UP*h*.99+drift*.55
     root_buttress(roots,[low,bend,high],[.74,.54,.39])
   if not observed:
    for fraction in [.28,.72]:
     var at:Vector3=ring[j].lerp(ring[i],fraction)+shift*2.+Vector3.UP*h*.42
     solid.panel(at-tangent*half,at-tangent*half+Vector3.UP*h*.48,at+tangent*half+Vector3.UP*h*.48,at+tangent*half,spec.get("window","window"))
  solid.part="bark" if spec.get("living_root_walls",false) else "stone"
  var low=ring[i];var high=ring[j]
  solid.quad(high,high+Vector3.UP*.28,low+Vector3.UP*.28,low)
  rod(solid,ring[i]+Vector3.UP*.28,ring[i]+Vector3.UP*(h-.08),.16,spec.get("living_root_material","bark") if spec.get("living_root_walls",false) else "stone")
 var eleft=point(v(spec.eaves[0]),base_level+h,g);var enear=point(v(spec.eaves[1]),base_level+h,g);var eright=point(v(spec.eaves[2]),base_level+h,g)
 var eaves=[enear,eleft,eleft+eright-enear,eright];var center=(eleft+eright)*.5
 if spec.has("ridge"):
  return combine([native.finish(),solid.finish(),bark_finish(roots) if spec.get("living_root_walls",false) else null,gable_roof(g,spec,eaves)])
 var apex_pixel=v(spec.apex);var peak_h=((center.z-center.x)*8.-apex_pixel.y-float(g.origin[1]))/Fit.VERTICAL
 var apex=point(apex_pixel,peak_h,g)
 var profile=[Vector2(1.,0.),Vector2(.98,.05),Vector2(.86,.19),Vector2(.66,.43),Vector2(.40,.69),Vector2(.17,.88),Vector2(.015,1.)]
 for face in 4:
  var next=(face+1)%4;solid.part=spec.get("roof","roof_gold")
  for layer in profile.size()-1:
   var low:Vector2=profile[layer];var high:Vector2=profile[layer+1]
   for step in 8:
    var a=eaves[face].lerp(eaves[next],float(step)/8.);var b=eaves[face].lerp(eaves[next],float(step+1)/8.)
    var p=apex.lerp(a,low.x);p.y=lerpf(base_level+h,peak_h,low.y)
    var q=apex.lerp(a,high.x);q.y=lerpf(base_level+h,peak_h,high.y)
    var r=apex.lerp(b,high.x);r.y=q.y
    var s=apex.lerp(b,low.x);s.y=p.y
    solid.quad(p,s,r,q)
    if face in [0,3]:painted_quad(native,p,s,r,q)
  rod(solid,eaves[face],eaves[next],.1,spec.get("trim","gold"))
 var peak_base=apex-Vector3.UP*.25
 solid.part="dark";solid.quad(eaves[3],eaves[2],eaves[1],eaves[0])
 if spec.get("cap",true):solid.part="gold";Parts.kili_round(solid,peak_base,[Vector2(.38,0),Vector2(.48,.25),Vector2(.25,.55)])
 return combine([native.finish(),solid.finish(),bark_finish(roots) if spec.get("living_root_walls",false) else null,finial(g,spec,center) if spec.has("finial") else null])

static func root_buttress(wood,centers:Array,radii:Array):
 # Inferred hidden roots continue the source's broad, tapering ribs around the chamfer.
 var rings=[]
 for index in centers.size():
  var ring=[]
  for side in 16:
   var angle=float(side)*TAU/16.;var radius=float(radii[index])*(1.+.06*sin(angle*3.))
   ring.append(centers[index]+Vector3(cos(angle)*radius,0,sin(angle)*radius))
  rings.append(ring)
 for level in rings.size()-1:
  for side in 16:
   var next=(side+1)%16
   wood.quad(rings[level][next],rings[level+1][next],rings[level+1][side],rings[level][side])

static func gable_roof(g:Dictionary,spec:Dictionary,eaves:Array)->Mesh:
 if int(spec.get("ridge_axis",0))==1:eaves=[eaves[1],eaves[2],eaves[3],eaves[0]]
 var front=native_skin(g);var back=structure();back.part=spec.get("roof","roof_gold");var ridge=[]
 for i in 2:
  var middle:Vector3=(eaves[0]+eaves[1])*.5 if i==0 else (eaves[2]+eaves[3])*.5
  var pixel=v(spec.ridge[i]);var height=((middle.z-middle.x)*8.-pixel.y-float(g.origin[1]))/Fit.VERTICAL
  ridge.append(point(pixel,height,g))
 var profile=[Vector2(1.,0.),Vector2(.95,.06),Vector2(.78,.24),Vector2(.54,.48),Vector2(.28,.74),Vector2(0.,1.)]
 for side in 2:
  var a:Vector3=eaves[0] if side==0 else eaves[1];var b:Vector3=eaves[3] if side==0 else eaves[2]
  for layer in profile.size()-1:
   var low:Vector2=profile[layer];var high:Vector2=profile[layer+1]
   var p:Vector3=ridge[0].lerp(a,low.x);p.y=lerpf(a.y,ridge[0].y,low.y)
   var q:Vector3=ridge[0].lerp(a,high.x);q.y=lerpf(a.y,ridge[0].y,high.y)
   var r:Vector3=ridge[1].lerp(b,high.x);r.y=lerpf(b.y,ridge[1].y,high.y)
   var s:Vector3=ridge[1].lerp(b,low.x);s.y=lerpf(b.y,ridge[1].y,low.y)
   if side==0:back.quad(p,s,r,q);painted_quad(front,p,s,r,q)
   else:back.quad(s,p,q,r)
  rod(back,a,b,.12,"gold")
 back.part=spec.get("wall","plaster")
 var center:Vector3=(eaves[0]+eaves[2])*.5
 for end in 2:
  var a:Vector3=eaves[0] if end==0 else eaves[3];var b:Vector3=eaves[1] if end==0 else eaves[2];var peak:Vector3=ridge[end]
  var normal=(b-a).cross(peak-a).normalized();var observed=normal.dot((a+b)*.5-center)>0.
  if observed:
   back.quad(a,peak,b,b)
   if normal.dot(Vector3(-1,0,1))>0:painted_quad(front,a,peak,b,b)
  else:
   back.quad(b,peak,a,a)
   if -normal.dot(Vector3(-1,0,1))>0:painted_quad(front,b,peak,a,a)
 back.part="dark";back.quad(eaves[3],eaves[2],eaves[1],eaves[0])
 return combine([front.finish(),back.finish()])

static func finial(g:Dictionary,spec:Dictionary,center:Vector3)->Mesh:
 var box:Array=spec.finial;var r=Rect2(box[0],box[1],box[2]-box[0],box[3]-box[1]);var skin=native_skin(g)
 var corners=[r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)];var points=[]
 var ground=(center.z-center.x)*8.
 for pixel in corners:points.append(projected(pixel,g,0.,ground))
 skin.quad(points[0],points[1],points[2],points[3]);skin.quad(points[3],points[2],points[1],points[0])
 return skin.finish()

static func relief(g:Dictionary,spec:Dictionary,back:Texture2D,front:Texture2D)->Mesh:
 var row:Dictionary=g.duplicate(true);row.rect=[0,0,g.rect[2],g.rect[3]];var native=native_skin(row,front)
 var rear=native_skin(row,back);var slope=float(spec.slope);var depth=float(spec.depth)
 var pixels=[Vector2.ZERO,Vector2(g.rect[2],0),Vector2(g.rect[2],g.rect[3]),Vector2(0,g.rect[3])];var points=[]
 var ground=float(spec.get("ground_offset",0.))
 for pixel in pixels:points.append(projected(pixel,g,slope,ground))
 var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized();var shift=normal*depth
 native.quad(points[0],points[1],points[2],points[3])
 for i in [3,2,1,3,1,0]:rear.projected_vertex(points[i]-shift,-normal,points[i])
 for edge in spec.edges:
  var a=projected(Vector2(edge[0],edge[1]),g,slope,ground);var b=projected(Vector2(edge[2],edge[3]),g,slope,ground)
  var sample=projected(Vector2(edge[4],edge[5]),g,slope,ground);var vertices=[a,b,b-shift,a-shift]
  var n:Vector3=(vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
  for i in [0,1,2,0,2,3]:rear.projected_vertex(vertices[i],n,sample)
 return combine([native.finish(),rear.finish()])

static func source_islet(g:Dictionary,spec:Dictionary)->Mesh:
 var serial=str(int(spec.graphic_id));var row:Dictionary=g.duplicate(true);row.rect=[0,0,g.rect[2],g.rect[3]]
 var water=native_skin(row,load(ROOT+serial+"-islet-water.png"));var corners=[]
 for pixel in [Vector2.ZERO,Vector2(g.rect[2],0),Vector2(g.rect[2],g.rect[3]),Vector2(0,g.rect[3])]:corners.append(point(pixel,-2.08/OWNER_Y_SCALE,g))
 painted_quad(water,corners[0],corners[1],corners[2],corners[3])
 var front:Texture2D=load(ROOT+serial+"-islet-rock.png");var back:Texture2D=load(ROOT+serial+"-islet-back.png")
 var rock=native_skin(row,front);var w=int(g.rect[2]);var h=int(g.rect[3]);var eye=Vector3(-1./16.,1./Fit.VERTICAL,1./16.).normalized()
 var bounds:Array=spec.rock_bounds
 for y in range(0,h,8):
  for x in range(0,w,8):
   var pixels=[Vector2(x,y),Vector2(mini(x+8,w),y),Vector2(mini(x+8,w),mini(y+8,h)),Vector2(x,mini(y+8,h))];var points=[]
   for pixel in pixels:
    var u=clampf((pixel.x-float(bounds[0]))/maxf(1.,float(bounds[2]-bounds[0])),0.,1.)
    var v=clampf((pixel.y-float(bounds[1]))/maxf(1.,float(bounds[3]-bounds[1])),0.,1.)
    points.append(projected(pixel,g,0.,float(spec.ground_offset))+eye*sin(u*PI)*sin(v*PI)*1.6)
   var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
   for index in [0,1,2,0,2,3]:rock.projected_vertex(points[index],normal,projected(pixels[index],g,0.,float(spec.ground_offset)))
 var shell:Mesh=relief(g,spec,back,front);var reverse=ArrayMesh.new();var arrays:Array=shell.get_meta("east_cpu_arrays")[1]
 reverse.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);reverse.surface_set_material(0,shell.surface_get_material(1));reverse.set_meta("east_cpu_arrays",[arrays])
 return combine([water.finish(),rock.finish(),reverse])

static func sculpture_point(pixel:Vector2,g:Dictionary)->Vector3:
 var uv=pixel/Vector2(g.rect[2],g.rect[3]);var depth=0.
 # Inferred low relief: broad body, head and thin wings. The original source alpha/paint owns the silhouette.
 for mass in [Vector4(.55,.52,.28,.24),Vector4(.25,.60,.19,.15),Vector4(.73,.22,.24,.18),Vector4(.64,.81,.20,.13)]:
  var delta=(uv-Vector2(mass.x,mass.y))/Vector2(mass.z,mass.w);depth=maxf(depth,exp(-delta.length_squared()*2.0)*1.4)
 return projected(pixel,g,0.,0.)+Vector3(-1./16.,1./Fit.VERTICAL,1./16.).normalized()*depth

static func sculpted_relief(g:Dictionary,spec:Dictionary,back:Texture2D,front:Texture2D)->Mesh:
 var row:Dictionary=g.duplicate(true);row.rect=[0,0,g.rect[2],g.rect[3]];var skin=native_skin(row,front)
 var rear=native_skin(row,back);var eye=Vector3(-1./16.,1./Fit.VERTICAL,1./16.).normalized()
 var w=int(g.rect[2]);var h=int(g.rect[3])
 for y in range(0,h,8):
  for x in range(0,w,8):
   var pixels=[Vector2(x,y),Vector2(min(x+8,w),y),Vector2(min(x+8,w),min(y+8,h)),Vector2(x,min(y+8,h))];var points=[]
   for pixel in pixels:points.append(sculpture_point(pixel,g))
   var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
   for index in [0,1,2,0,2,3]:skin.projected_vertex(points[index],normal,projected(pixels[index],g,0.,0.))
   var back_points=[]
   for index in 4:
    var base=projected(pixels[index],g,0.,0.)
    back_points.append(base-eye*(float(spec.depth)+points[index].distance_to(base)*.70))
   var back_normal:Vector3=(back_points[1]-back_points[0]).cross(back_points[2]-back_points[0]).normalized()
   for index in [3,2,1,3,1,0]:rear.projected_vertex(back_points[index],back_normal,projected(pixels[index],g,0.,0.))
 for edge in spec.edges:
  var pa=Vector2(edge[0],edge[1]);var pb=Vector2(edge[2],edge[3]);var a=sculpture_point(pa,g);var b=sculpture_point(pb,g)
  var base_a=projected(pa,g,0.,0.);var base_b=projected(pb,g,0.,0.)
  var back_a=base_a-eye*(float(spec.depth)+a.distance_to(base_a)*.70);var back_b=base_b-eye*(float(spec.depth)+b.distance_to(base_b)*.70)
  var vertices=[a,b,back_b,back_a];var normal:Vector3=(vertices[2]-a).cross(b-a).normalized();var sample=projected(Vector2(edge[4],edge[5]),g,0.,0.)
  for index in [0,1,2,0,2,3]:rear.projected_vertex(vertices[index],normal,sample)
 var reverse=rear.finish();var stone:ShaderMaterial=reverse.surface_get_material(0).duplicate()
 stone.set_shader_parameter("original_palette",false);reverse.surface_set_material(0,stone)
 return combine([skin.finish(),reverse])

static func boat(g:Dictionary,spec:Dictionary)->Mesh:
 var wood=structure();var platform=[]
 for pixel in spec.platform:platform.append(point(v(pixel),0.,g))
 wood.part="timber";wood.quad(platform[0],platform[3],platform[2],platform[1])
 for i in 4:
  var a:Vector3=platform[i];var b:Vector3=platform[(i+1)%4]
  wood.quad(a,b,b-Vector3.UP*.35,a-Vector3.UP*.35)
 var port=[];var starboard=[]
 for pixel in spec.port:port.append(point(v(pixel),1.5,g))
 for pixel in spec.starboard:starboard.append(point(v(pixel),1.5,g))
 var keels=[]
 for i in port.size():keels.append((port[i]+starboard[i])*.5-Vector3.UP*1.15)
 for edge in [port,starboard]:
  for i in edge.size()-1:
   var a:Vector3=edge[i];var b:Vector3=edge[i+1]
   wood.part="blue_wood"
   if edge==port:wood.quad(a,b,keels[i+1],keels[i])
   else:wood.quad(b,a,keels[i],keels[i+1])
   rod(wood,a,b,.16,"blue_wood")
 for i in range(1,port.size()-1):
  wood.part="timber";wood.quad(port[i]-Vector3.UP*.75,port[i+1]-Vector3.UP*.75,starboard[i+1]-Vector3.UP*.75,starboard[i]-Vector3.UP*.75)
  rod(wood,port[i]-Vector3.UP*.25,starboard[i]-Vector3.UP*.25,.12,"timber")
 var cask=point(Vector2(85,146),1.25,g);wood.part="timber"
 Parts.kili_round(wood,cask,[Vector2(.65,0),Vector2(.85,.2),Vector2(.85,1.),Vector2(.65,1.2)])
 wood.part="gold"
 for y in [.2,.95]:Parts.kili_round(wood,cask+Vector3.UP*y,[Vector2(.86,0),Vector2(.86,.08)])
 return wood.finish()

static func mast(g:Dictionary,spec:Dictionary)->Mesh:
 var wood=structure();var base=point(v(spec.base),0.,g);var height=(float(spec.base[1])-float(spec.top[1]))/Fit.VERTICAL
 var top=point(v(spec.top),height,g);var ground=float(spec.base[1])+float(g.origin[1])
 rod(wood,base,top,.42,"timber")
 var w=float(g.footprint[0])*3.;var d=float(g.footprint[1])*3.
 wood.part="timber";wood.box(AABB(Vector3(-1.5,-.35,1.5-d),Vector3(w,.35,d)))
 for anchor in [Vector3(-1.,0,1.),Vector3(w-2.,0,1.),Vector3(-1.,0,2.-d),Vector3(w-2.,0,2.-d)]:
  rod(wood,anchor,base.lerp(top,.94),.05,"rope")
 var cloth:Texture2D=load(ROOT+"mast-cloth.png");var skin=PreparedSkin.new([Rect2(0,0,g.rect[2],g.rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],cloth,1./Fit.VERTICAL)
 var camera_ray=Vector3(-1./16.,1./Fit.VERTICAL,1./16.).normalized();var width=float(g.rect[2]);var high=float(g.rect[3])
 for y in range(0,int(high),16):
  for x in range(0,int(width),16):
   var pixels=[Vector2(x,y),Vector2(minf(x+16,width),y),Vector2(minf(x+16,width),minf(y+16,high)),Vector2(x,minf(y+16,high))];var points=[]
   for pixel in pixels:
    var billow=sin(pixel.x/width*PI)*sin(pixel.y/high*PI)*1.7
    points.append(projected(pixel,g,0.,ground)+camera_ray*billow)
   var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
   for i in [0,1,2,0,2,3]:
    skin.surface.set_normal(normal);skin.surface.set_uv(pixels[i]/cloth.get_size());skin.surface.add_vertex(points[i])
   for i in [3,2,0,2,1,0]:
    skin.surface.set_normal(-normal);skin.surface.set_uv(pixels[i]/cloth.get_size());skin.surface.add_vertex(points[i])
 return combine([wood.finish(),skin.finish()])

static func compound(g:Dictionary,spec:Dictionary)->Mesh:
 var parts=[]
 for row in spec.get("trunks",[]):parts.append(living_tree_body(g,row) if row.has("trace") else round_body(g,row))
 for row in spec.get("towers",[]):
  if int(spec.get("graphic_id",0)) in [1233260,1233265,1233268] and row.material=="metal_dark":continue
  parts.append(round_body(g,row))
 if int(spec.get("graphic_id",0)) in [1233260,1233265,1233268]:parts.append(observatory_dish(g,spec))
 for row in spec.get("blocks",[]):parts.append(block_mass(g,row))
 for row in spec.get("platforms",[]):parts.append(round_platform(g,row))
 if not spec.get("rods",[]).is_empty():parts.append(measured_rods(g,spec.rods))
 for row in spec.get("houses",[]):parts.append(house(g,row))
 for row in spec.get("stairs",[]):parts.append(stairs(g,row))
 for row in spec.get("terraces",[]):parts.append(terrace(g,row))
 var crown_index=0
 for box in spec.get("crowns",[]):
  parts.append(foliage(g,load(ROOT+str(int(spec.graphic_id))+"-crown-"+str(crown_index)+".png"),box,float(spec.get("crown_ground_pixels",[0.,0.,0.,0.])[crown_index]),v(spec.crown_anchors[crown_index])));crown_index+=1
 if not spec.get("crown_anchors",[]).is_empty():parts.append(crown_branches(g,spec))
 if spec.has("gold_spires"):parts.append(gold_spires(g,spec))
 for box in spec.get("details",[]):
  if spec.has("gold_spires"):continue
  var ground=0.;var nearest=INF
  for row in spec.get("towers",[]):
   var top=v(row.base)-Vector2(0,float(row.height_pixels));var distance=top.distance_squared_to(Vector2((box[0]+box[2])*.5,box[3]))
   if distance<nearest:nearest=distance;ground=float(row.base[1])+float(g.origin[1])+float(row.get("level_pixels",0))
  parts.append(finial(g,{"finial":box},Vector3(-ground/16.,0,ground/16.)))
 return combine(parts)

static func gold_spires(g:Dictionary,spec:Dictionary)->Mesh:
 var solid=structure();solid.part="gold"
 for spire in spec.gold_spires:
  var nearest=INF;var ground=0.
  for row in spec.towers:
   var tip=v(row.base)-Vector2(0,float(row.height_pixels));var distance=tip.distance_squared_to(v(spire.center))
   if distance<nearest:nearest=distance;ground=float(row.base[1])+float(g.origin[1])+float(row.get("level_pixels",0))
  var center=projected(v(spire.center),g,0.,ground);var top=projected(v(spire.tip),g,0.,ground);var bottom=projected(v(spire.bottom),g,0.,ground)
  var radius=float(spire.diameter)/(2.*Fit.HORIZONTAL*sqrt(2.));var half_height=float(spire.diameter)/(2.*Fit.VERTICAL)
  rod(solid,bottom,top,maxf(.045,radius*.065),"gold")
  var rings=[]
  for step in 13:
   var theta=float(step)*PI/12.
   rings.append(Vector2(sin(theta)*radius,(1.-cos(theta))*half_height))
  Parts.kili_round(solid,center-Vector3.UP*half_height,rings)
 var result=solid.finish();var gold:ShaderMaterial=result.surface_get_material(0).duplicate()
 gold.set_shader_parameter("surface_kind",6.0);result.surface_set_material(0,gold)
 return result

static func bark_finish(skin)->Mesh:
 var mesh:Mesh=skin.finish();var bark:ShaderMaterial=mesh.surface_get_material(0).duplicate()
 bark.set_shader_parameter("surface_kind",4.0);bark.set_shader_parameter("original_palette",false);mesh.surface_set_material(0,bark)
 return mesh

static func living_tree_body(g:Dictionary,spec:Dictionary)->Mesh:
 var wood=structure();wood.part="living_bark";wood.pitches.living_bark=2.6;var trace:Array=spec.trace
 var smooth_trace=[]
 for segment in trace.size()-1:
  var before:Array=trace[maxi(0,segment-1)];var low:Array=trace[segment];var high:Array=trace[segment+1];var after:Array=trace[mini(trace.size()-1,segment+2)]
  for step in 4:
   var sample=Vector3(low[0],low[1],low[2]).cubic_interpolate(Vector3(high[0],high[1],high[2]),Vector3(before[0],before[1],before[2]),Vector3(after[0],after[1],after[2]),step/4.)
   smooth_trace.append([sample.x,sample.y,sample.z])
 smooth_trace.append(trace[-1]);trace=smooth_trace
 var base_y=float(spec.base[1]);var end_y=float(trace[-1][1]);var base_level=float(spec.get("level_pixels",0))/Fit.VERTICAL
 var ground=float(spec.top[1])+float(spec.height_pixels)+float(spec.get("level_pixels",0));var height=(ground-end_y)/Fit.VERTICAL
 var radius=float(spec.diameter)/(2.*Fit.HORIZONTAL*sqrt(2.));var rings=[]
 for sample in trace:
  var fraction=(base_y-float(sample[1]))/(base_y-end_y);var center=point(Vector2(sample[0],sample[1]),lerpf(base_level,height,fraction),g);var ring=[]
  for side in 48:
   var angle=side*TAU/48.;var roots=1.+.18*cos(angle*3.)*pow(1.-fraction,3.)+.035*sin(angle*7.+fraction*5.)
   ring.append(center+Vector3(cos(angle)*radius*float(sample[2])*roots,0,sin(angle)*radius*float(sample[2])*roots))
  rings.append(ring)
 for level in rings.size()-1:
  for side in 48:
   var next=(side+1)%48;wood.quad(rings[level][next],rings[level+1][next],rings[level+1][side],rings[level][side])
 var stump_height=float(spec.get("stump_height_pixels",107))
 var stump={"base":[float(spec.top[0]),float(spec.top[1])+stump_height],"top":spec.top,"level_pixels":float(spec.get("level_pixels",0))+float(spec.height_pixels)-stump_height,"height_pixels":stump_height,"diameter":spec.get("stump_diameter",spec.diameter),"material":"living_bark","profile":[[0.,.72],[.3,.86],[.7,.94],[1.,1.]],"hollow_top":true,"hollow_material":"hollow","hollow_depth":3.5,"pitches":{"living_bark":2.6}}
 if spec.has("rim_offsets"):stump.rim_offsets=spec.rim_offsets
 return combine([bark_finish(wood),round_body(g,stump) if spec.get("cut_stump",true) else null])

static func observatory_dish(g:Dictionary,spec:Dictionary)->Mesh:
 var metal=structure();var native=native_skin(g);var shaft:Dictionary=spec.towers[1]
 var center=point(Vector2(float(shaft.base[0])-19.,42.),484./Fit.VERTICAL,g)
 var normal=Vector3(-1.,1.,1.).normalized();var across=Vector3(1,0,1).normalized();var up=normal.cross(across).normalized();var radius=3.45;var depth=2.8
 # The native top is an open, tilted instrument dish. Continue its metal shell around the unseen back.
 for ring in 10:
  var low=float(ring)/10.;var high=float(ring+1)/10.
  for sector in 48:
   var points=[]
   for uv in [Vector2(low,float(sector)/48.),Vector2(high,float(sector)/48.),Vector2(high,float(sector+1)/48.),Vector2(low,float(sector+1)/48.)]:
    var r=sin(uv.x*PI*.5)*radius;var angle=uv.y*TAU
    points.append(center-normal*depth*cos(uv.x*PI*.5)+(across*cos(angle)+up*sin(angle))*r)
   metal.part="dark";metal.quad(points[3],points[2],points[1],points[0]);painted_quad(native,points[3],points[2],points[1],points[0])
   metal.part="metal_dark";metal.quad(points[0]-normal*.13,points[1]-normal*.13,points[2]-normal*.13,points[3]-normal*.13)
 for sector in 48:
  var a=float(sector)*TAU/48.;var b=float(sector+1)*TAU/48.
  rod(metal,center+(across*cos(a)+up*sin(a))*radius,center+(across*cos(b)+up*sin(b))*radius,.085,"metal_dark")
 # Measured projecting optic and blue lens; its unseen circumference continues the metal housing.
 var optic_direction=1. if int(spec.get("graphic_id",0))==1233268 else -1.
 var tube_start=point(Vector2(float(shaft.base[0])+36.*optic_direction,43),484./Fit.VERTICAL,g)
 var tube_end=point(Vector2(float(shaft.base[0])+103.*optic_direction,60 if optic_direction>0 else 53),484./Fit.VERTICAL,g)
 var axis=(tube_end-tube_start).normalized();var side=axis.cross(Vector3.UP).normalized();var vertical=side.cross(axis).normalized()
 var profile=[Vector2(0.,1.35),Vector2(.12,1.35),Vector2(.18,1.08),Vector2(.78,1.08),Vector2(.84,1.44),Vector2(1.,1.44)]
 var source_eye=Vector3(-1./16.,1./Fit.VERTICAL,1./16.).normalized()
 for layer in profile.size()-1:
  for sector in 32:
   var a=float(sector)*TAU/32.;var b=float(sector+1)*TAU/32.
   var low:Vector2=profile[layer];var high:Vector2=profile[layer+1]
   var first=tube_start.lerp(tube_end,low.x);var last=tube_start.lerp(tube_end,high.x)
   var p=first+(side*cos(a)+vertical*sin(a))*low.y;var q=last+(side*cos(a)+vertical*sin(a))*high.y
   var r=last+(side*cos(b)+vertical*sin(b))*high.y;var s=first+(side*cos(b)+vertical*sin(b))*low.y
   metal.part="metal_dark";metal.quad(p,s,r,q)
   if ((r-p).cross(s-p)).dot(source_eye)>0.:painted_quad(native,p,s,r,q)
 var lens_center=tube_end-axis*.08
 for sector in 32:
  var a=float(sector)*TAU/32.;var b=float(sector+1)*TAU/32.
  var p=tube_end+(side*cos(a)+vertical*sin(a))*1.44;var q=tube_end+(side*cos(b)+vertical*sin(b))*1.44
  var inner_p=lens_center+(side*cos(a)+vertical*sin(a))*1.15;var inner_q=lens_center+(side*cos(b)+vertical*sin(b))*1.15
  metal.part="metal_dark";metal.quad(p,q,inner_q,inner_p)
  metal.part="dark";metal.quad(inner_p,inner_q,lens_center,lens_center)
  painted_quad(native,p,q,inner_q,inner_p);painted_quad(native,inner_p,inner_q,lens_center,lens_center)
 return combine([metal.finish(),native.finish()])

static func block_mass(g:Dictionary,spec:Dictionary)->Mesh:
 var native=native_skin(g);var solid=structure();var level=float(spec.get("level_pixels",0))/Fit.VERTICAL;var height=float(spec.height_pixels)/Fit.VERTICAL
 var left=point(v(spec.feet[0]),level,g);var near=point(v(spec.feet[1]),level,g);var right=point(v(spec.feet[2]),level,g);var ring=[near,left,left+right-near,right]
 for i in 4:
  var j=(i+1)%4;solid.part=spec.material
  solid.quad(ring[j],ring[j]+Vector3.UP*height,ring[i]+Vector3.UP*height,ring[i])
  if i in [0,3]:painted_quad(native,ring[j],ring[j]+Vector3.UP*height,ring[i]+Vector3.UP*height,ring[i])
  rod(solid,ring[i],ring[i]+Vector3.UP*height,.12,spec.material)
  if i not in [0,3] and spec.has("window"):
   var tangent:Vector3=(ring[i]-ring[j]).normalized();var normal=tangent.cross(Vector3.UP);var width=minf(1.2,ring[i].distance_to(ring[j])*.15)
   for fraction in [.25,.5,.75]:
    var at:Vector3=ring[j].lerp(ring[i],fraction)+normal*.03+Vector3.UP*height*.3
    solid.panel(at-tangent*width,at-tangent*width+Vector3.UP*height*.55,at+tangent*width+Vector3.UP*height*.55,at+tangent*width,spec.window)
 var top=[]
 for p in ring:top.append(p+Vector3.UP*height)
 solid.quad(top[0],top[1],top[2],top[3]);painted_quad(native,top[0],top[1],top[2],top[3])
 return combine([native.finish(),solid.finish()])

static func round_platform(g:Dictionary,spec:Dictionary)->Mesh:
 var row:Dictionary=spec.duplicate(true);row.profile=[[0.,1.],[1.,1.]];var deck=round_body(g,row);var wood=structure()
 var top=point(v(spec.base),float(spec.get("level_pixels",0)+spec.height_pixels)/Fit.VERTICAL,g);var radius=float(spec.diameter)/(2.*Fit.HORIZONTAL*sqrt(2.));var rail=float(spec.get("rail_pixels",0))/Fit.VERTICAL
 for side in 16:
  var a=float(side)*TAU/16.;var b=float(side+1)*TAU/16.;var p=top+Vector3(cos(a)*radius,0,sin(a)*radius);var q=top+Vector3(cos(b)*radius,0,sin(b)*radius)
  rod(wood,p,p+Vector3.UP*rail,.1,spec.material);rod(wood,p+Vector3.UP*rail,q+Vector3.UP*rail,.07,spec.material)
 return combine([deck,wood.finish()])

static func measured_rods(g:Dictionary,rows:Array)->Mesh:
 var solid=structure()
 for row in rows:
  var ground=float(row.ground_pixel[1])+float(g.origin[1])+float(row.get("level_pixels",0))
  rod(solid,projected(v(row.a),g,0.,ground),projected(v(row.b),g,0.,ground),float(row.radius),row.material)
 return solid.finish()

static func crown_branches(g:Dictionary,spec:Dictionary)->Mesh:
 var wood=structure();var ray=Vector3(-1./16.,1./Fit.VERTICAL,1./16.).normalized()
 for index in spec.get("crown_anchors",[]).size():
  var anchor=spec.crown_anchors[index];var ground=float(spec.get("crown_ground_pixels",[0.,0.,0.,0.])[index])
  var end=projected(v(anchor),g,0.,ground)-ray*.28;var nearest=INF;var start=Vector3.ZERO
  for row in spec.get("trunks",[]):
   var level=float(row.get("level_pixels",0))/Fit.VERTICAL;var height=float(row.height_pixels)/Fit.VERTICAL;var base=point(v(row.base),level,g)
   var top=point(v(row.top),level+height,g) if row.has("top") else base+Vector3.UP*height
   var t=clampf((end.y-base.y)/height,.12,.96);var candidate=base.lerp(top,t)-ray*float(row.get("recess",0.))*sin(t*PI)
   if row.has("trace"):candidate=living_axis_at(g,row,end.y)
   var distance=candidate.distance_squared_to(end)
   if distance<nearest:nearest=distance;start=candidate
  var middle=start.lerp(end,.55)+Vector3.UP*.5
  rod(wood,start,middle,.22,"bark");rod(wood,middle,end,.12,"bark")
 return wood.finish()

static func living_axis_at(g:Dictionary,spec:Dictionary,wanted_height:float)->Vector3:
 # Branches originate inside the actual curved loft, rather than an unrelated straight axis.
 var trace:Array=spec.trace;var base_level=float(spec.get("level_pixels",0))/Fit.VERTICAL
 var ground=float(spec.top[1])+float(spec.height_pixels)+float(spec.get("level_pixels",0))
 var end_height=(ground-float(trace[-1][1]))/Fit.VERTICAL
 var fraction=clampf((wanted_height-base_level)/(end_height-base_level),.12,.96)
 var y=lerpf(float(trace[0][1]),float(trace[-1][1]),fraction)
 for index in trace.size()-1:
  var a:Array=trace[index];var b:Array=trace[index+1]
  if y<=float(a[1]) and y>=float(b[1]):
   var t=(float(a[1])-y)/(float(a[1])-float(b[1]));var pixel=Vector2(lerpf(float(a[0]),float(b[0]),t),y)
   return point(pixel,lerpf(base_level,end_height,fraction),g)
 return point(v(spec.base),base_level,g)

static func round_body(g:Dictionary,spec:Dictionary)->Mesh:
 var front=native_skin(g);var back=structure();back.part=spec.material
 for part in spec.get("pitches",{}):back.pitches[part]=spec.pitches[part]
 var level=float(spec.get("level_pixels",0))/Fit.VERTICAL;var at=point(v(spec.base),level,g)
 var radius=float(spec.diameter)/(2.*Fit.HORIZONTAL*sqrt(2.));var height=float(spec.height_pixels)/Fit.VERTICAL
 var lean=Vector3.ZERO
 if spec.has("top"):lean=point(v(spec.top),level+height,g)-at-Vector3.UP*height
 var profile:Array=spec.profile;var steps=int(spec.get("sides",32))
 for ring in profile.size()-1:
  var low:Array=profile[ring];var high:Array=profile[ring+1]
  for side in steps:
   var a=float(side)*TAU/steps+float(spec.get("angle_offset",0));var b=float(side+1)*TAU/steps+float(spec.get("angle_offset",0))
   var low_recess=-Vector3(-1./16.,1./Fit.VERTICAL,1./16.).normalized()*float(spec.get("recess",0.))*sin(float(low[0])*PI)
   var high_recess=-Vector3(-1./16.,1./Fit.VERTICAL,1./16.).normalized()*float(spec.get("recess",0.))*sin(float(high[0])*PI)
   var pa=at+lean*float(low[0])+low_recess+Vector3(cos(a)*radius*float(low[1]),height*float(low[0]),sin(a)*radius*float(low[1]))
   var pb=at+lean*float(low[0])+low_recess+Vector3(cos(b)*radius*float(low[1]),height*float(low[0]),sin(b)*radius*float(low[1]))
   var qa=at+lean*float(high[0])+high_recess+Vector3(cos(a)*radius*float(high[1]),height*float(high[0]),sin(a)*radius*float(high[1]))
   var qb=at+lean*float(high[0])+high_recess+Vector3(cos(b)*radius*float(high[1]),height*float(high[0]),sin(b)*radius*float(high[1]))
   if spec.has("rim_offsets"):
    if float(low[0])==1.:pa.y+=float(spec.rim_offsets[side])/Fit.VERTICAL;pb.y+=float(spec.rim_offsets[(side+1)%steps])/Fit.VERTICAL
    if float(high[0])==1.:qa.y+=float(spec.rim_offsets[side])/Fit.VERTICAL;qb.y+=float(spec.rim_offsets[(side+1)%steps])/Fit.VERTICAL
   var facing=Vector3(cos((a+b)*.5),0,sin((a+b)*.5)).dot(Vector3(-1.,0,1.))
   back.part=spec.get("ring_materials",[])[ring] if spec.has("ring_materials") else spec.material;back.quad(pb,qb,qa,pa)
   if facing>0 and not spec.get("tiled_front",false):painted_quad(front,pb,qb,qa,pa)
 var end:Array=profile[-1]
 if float(end[1])>.001:
  var top=at+lean+Vector3.UP*height;var top_radius=radius*float(end[1]);var hollow=spec.material=="bark" or spec.get("hollow_top",false)
  if hollow:back.part="hollow"
  for side in steps:
   var a=float(side)*TAU/steps+float(spec.get("angle_offset",0));var b=float(side+1)*TAU/steps+float(spec.get("angle_offset",0))
   var p=top+Vector3(cos(a)*top_radius,0,sin(a)*top_radius);var q=top+Vector3(cos(b)*top_radius,0,sin(b)*top_radius)
   if spec.has("rim_offsets"):p.y+=float(spec.rim_offsets[side])/Fit.VERTICAL;q.y+=float(spec.rim_offsets[(side+1)%steps])/Fit.VERTICAL
   if float(spec.get("cap_inner",0))>0:
    back.quad(p,q,top+(q-top)*float(spec.cap_inner),top+(p-top)*float(spec.cap_inner))
    if spec.get("paint_top",false):painted_quad(front,p,q,top+(q-top)*float(spec.cap_inner),top+(p-top)*float(spec.cap_inner))
   elif hollow:
    var inner_p=top+(p-top)*.76-Vector3.UP*.12;var inner_q=top+(q-top)*.76-Vector3.UP*.12
    back.part=spec.material;back.quad(p,q,inner_q,inner_p)
    var floor_center=top-Vector3.UP*float(spec.get("hollow_depth",.3))
    var floor_p=Vector3(inner_p.x,floor_center.y,inner_p.z);var floor_q=Vector3(inner_q.x,floor_center.y,inner_q.z)
    back.part=spec.get("hollow_material","hollow" if spec.material=="bark" else "dark");back.quad(inner_p,inner_q,floor_q,floor_p);back.quad(floor_p,floor_q,floor_center,floor_center)
    if spec.has("hollow_depth"):
     painted_quad(front,p,q,inner_q,inner_p)
     if Vector3(cos((a+b)*.5),0,sin((a+b)*.5)).dot(Vector3(-1.,0,1.))<0.:painted_quad(front,inner_p,inner_q,floor_q,floor_p)
   else:
    back.quad(p,q,top,top)
    if spec.get("paint_top",false):painted_quad(front,p,q,top,top)
 var bottom_radius=radius*float(profile[0][1]);back.part=spec.material
 for side in steps:
  var a=float(side)*TAU/steps;var b=float(side+1)*TAU/steps
  back.quad(at,at+Vector3(cos(b)*bottom_radius,0,sin(b)*bottom_radius),at+Vector3(cos(a)*bottom_radius,0,sin(a)*bottom_radius),at)
 if spec.has("window"):
  for angle in [0.,-PI*.5,-PI*.25]:
   var normal=Vector3(cos(angle),0,sin(angle));var tangent=Vector3(sin(angle),0,-cos(angle));var at_window=at+normal*radius*1.01+Vector3.UP*height*.18
   back.panel(at_window-tangent*radius*.32,at_window-tangent*radius*.32+Vector3.UP*height*.62,at_window+tangent*radius*.32+Vector3.UP*height*.62,at_window+tangent*radius*.32,spec.window)
 if spec.get("crenellations",false):
  back.part=spec.material
  for tooth in 8:
   var angle=tooth*TAU/8.;var at_tooth=at+lean+Vector3.UP*height+Vector3(cos(angle),0,sin(angle))*radius*.88
   back.box(AABB(at_tooth-Vector3(radius*.12,0,radius*.12),Vector3(radius*.24,12./Fit.VERTICAL,radius*.24)))
 return combine([front.finish() if not spec.get("tiled_front",false) or spec.get("paint_top",false) else null,back.finish()])

static func stairs(g:Dictionary,spec:Dictionary)->Mesh:
 var solid=structure();var native=native_skin(g);var high=float(spec.height_pixels)/Fit.VERTICAL;var steps=int(spec.steps)
 var a=point(v(spec.near[0]),0.,g);var b=point(v(spec.near[1]),0.,g)
 var c=point(v(spec.far[0]),high,g);var d=point(v(spec.far[1]),high,g)
 for i in steps:
  var t=float(i)/steps;var u=float(i+1)/steps
  var left=a.lerp(c,t);var right=b.lerp(d,t);var next_left=a.lerp(c,u);var next_right=b.lerp(d,u)
  var tread_left=left+Vector3.UP*(high/steps);var tread_right=right+Vector3.UP*(high/steps)
  native.quad(tread_left,next_left,next_right,tread_right);native.quad(left,tread_left,tread_right,right)
  solid.part="timber";solid.quad(left,next_left,next_left-Vector3.UP*.2,left-Vector3.UP*.2);solid.quad(next_right,right,right-Vector3.UP*.2,next_right-Vector3.UP*.2)
 for edge in [[a,c],[b,d]]:
  rod(solid,edge[0]+Vector3.UP*.15,edge[1]+Vector3.UP*.15,.16,"timber")
  rod(solid,edge[0]+Vector3.UP*1.25,edge[1]+Vector3.UP*1.25,.1,"timber")
  for i in 5:
   var p:Vector3=edge[0].lerp(edge[1],float(i)/4.)
   rod(solid,p,p+Vector3.UP*1.55,.11,"timber")
   if spec.get("support",false) and i>0:
    var foot=Vector3(p.x,0,p.z);rod(solid,foot,p,.15,"timber")
    if i>1:rod(solid,foot,edge[0].lerp(edge[1],float(i-1)/4.),.1,"timber")
 return combine([native.finish(),solid.finish()])

static func terrace(g:Dictionary,spec:Dictionary)->Mesh:
 var front=native_skin(g);var back=structure();var ring=[];var high=float(spec.height_pixels)/Fit.VERTICAL
 for pixel in spec.points:ring.append(point(v(pixel),high,g))
 front.quad(ring[0],ring[1],ring[2],ring[3])
 for i in ring.size():
  var a:Vector3=ring[i];var b:Vector3=ring[(i+1)%ring.size()]
  var material:String=spec.get("material","timber");back.part=material;back.quad(a,b,b-Vector3.UP*.3,a-Vector3.UP*.3)
  if material=="stone" or spec.get("solid",false):back.quad(a,b,Vector3(b.x,0,b.z),Vector3(a.x,0,a.z))
  rod(back,a+Vector3.UP*1.1,b+Vector3.UP*1.1,.09,material)
  var count=maxi(1,ceili(a.distance_to(b)/1.2))
  for j in count:
   var p=a.lerp(b,float(j)/count);rod(back,p,p+Vector3.UP*1.3,.08,material)
   if high>2. and material!="stone" and not spec.get("solid",false):rod(back,Vector3(p.x,0,p.z),p,.13,material)
 return combine([front.finish(),back.finish()])

static func foliage(g:Dictionary,paint:Texture2D,box:Array,ground:float,junction:Vector2=Vector2(INF,INF))->Mesh:
 assert(paint!=null,"Regenerate the native East foliage derivative before use")
 var row:Dictionary=g.duplicate(true);row.rect=[0,0,box[2]-box[0],box[3]-box[1]];row.origin=[g.origin[0]+box[0],g.origin[1]+box[1]]
 var skin=native_skin(row,paint);var pixels=[Vector2(box[0],box[1]),Vector2(box[2],box[1]),Vector2(box[2],box[3]),Vector2(box[0],box[3])];var source=[]
 for pixel in pixels:source.append(projected(pixel,g,0.,ground))
 var center:Vector3=projected(junction,g,0.,ground) if junction.is_finite() else (source[0]+source[2])*.5
 # Separate thin leaf panels retain native alpha; their crossed depth is inferred.
 for turn in [0.,PI*.5]:
  var basis=Basis(Vector3.UP,turn);var points=[]
  for p in source:points.append(center+basis*(p-center))
  var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for i in [0,1,2,0,2,3]:skin.projected_vertex(points[i],normal,source[i])
  for i in [3,2,1,3,1,0]:skin.projected_vertex(points[i],-normal,source[i])
 return skin.finish()

static func source_rock(g:Dictionary,spec:Dictionary,paint:Texture2D)->Mesh:
 var native=native_skin(g.duplicate(true),paint);native.graphic[0]=Rect2(0,0,g.rect[2],g.rect[3]);var solid=structure();solid.part=spec.material
 var shape:Dictionary=spec.profile;var sides=int(shape.sides);var points=[];var pixels=[]
 for p in shape.vertices:points.append(Vector3(p[0],p[1],p[2]))
 for p in shape.uv_pixels:pixels.append(v(p))
 var hole=PackedVector2Array()
 for p in spec.get("hole",[]):hole.append(v(p))
 for layer in int(shape.levels)-1:
  for side in sides:
   var i=layer*sides+side;var j=layer*sides+(side+1)%sides
   var quad=[points[j],points[j+sides],points[i+sides],points[i]];var uv=[pixels[j],pixels[j+sides],pixels[i+sides],pixels[i]]
   var normal:Vector3=(quad[2]-quad[0]).cross(quad[1]-quad[0]).normalized();var front=normal.dot(Vector3(-1.,0,1.))>0.
   if front and not hole.is_empty() and Geometry2D.is_point_in_polygon((uv[0]+uv[1]+uv[2]+uv[3])*.25,hole):continue
   solid.quad(quad[0],quad[1],quad[2],quad[3])
   if front:
    for k in [0,1,2,0,2,3]:
     native.surface.set_normal(normal);native.surface.set_uv(uv[k]/paint.get_size());native.surface.add_vertex(quad[k]+normal*.015)
 var crown=Vector3(shape.crown[0],shape.crown[1],shape.crown[2]);var bottom=Vector3(crown.x,0,crown.z)
 for side in sides:
  var a:Vector3=points[(int(shape.levels)-1)*sides+side];var b:Vector3=points[(int(shape.levels)-1)*sides+(side+1)%sides]
  solid.quad(a,b,crown,crown);solid.quad(points[(side+1)%sides],points[side],bottom,bottom)
 var parts=[native.finish(),solid.finish()]
 if not hole.is_empty():parts.append(rock_cavity(g,spec,hole))
 return combine(parts)

static func rock_cavity(g:Dictionary,spec:Dictionary,hole:PackedVector2Array)->Mesh:
 var stone=structure();var ground=(hole[0].y+hole[-1].y)*.5+float(g.origin[1]);var front=[];var back=[];var depth=Vector3(1,0,-1).normalized()*2.8
 for pixel in hole:
  var native=pixel+Vector2(g.origin[0],g.origin[1]);var p=Vector3(native.x*3./64.-ground/16.,(ground-native.y)*float(spec.profile.pixel_height),native.x*3./64.+ground/16.)
  front.append(p);back.append(p+depth)
 for i in hole.size()-1:stone.part=spec.material;stone.quad(front[i],back[i],back[i+1],front[i+1])
 stone.part="dark";var center=Vector3.ZERO
 for p in back:center+=p
 center/=back.size()
 for i in back.size()-1:stone.quad(back[i],back[i+1],center,center)
 return stone.finish()
