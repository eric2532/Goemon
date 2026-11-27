extends RefCounted
## Private native-plant prototype, reusing the existing round-profile builder.
const Base=preload("res://scripts/forest/forest_east_region_art.gd")
const ROOT="res://assets/maps/falan/east_region/round_cactus/"
static var catalog={}
static var meshes={}
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func owns(serial:int)->bool:return data().graphics.has(str(serial))
static func ribbed_round(skin,profile:Array[Vector2]):
 # Same existing round-section contract, with enough samples to describe the
 # observed cactus ribs instead of turning eight lobes into sixteen flat sides.
 for level in profile.size()-1:
  var lower:Vector2=profile[level];var upper:Vector2=profile[level+1]
  for side in 64:
   var a=-side*TAU/64.;var b=-(side+1)*TAU/64.
   var ra=1.+.12*cos(a*10.);var rb=1.+.12*cos(b*10.)
   skin.quad(Vector3(cos(a)*lower.x*ra,lower.y,sin(a)*lower.x*ra),Vector3(cos(a)*upper.x*ra,upper.y,sin(a)*upper.x*ra),Vector3(cos(b)*upper.x*rb,upper.y,sin(b)*upper.x*rb),Vector3(cos(b)*lower.x*rb,lower.y,sin(b)*lower.x*rb))
static func source_surface(pixel:Vector2,g:Dictionary,arrays_list:Array)->Vector3:
 var eye=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized();var from=Base.projected(pixel,g,0.,0.)+eye*100.;var nearest=INF;var result=Vector3.ZERO
 for arrays:Array in arrays_list:
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  for index in range(0,points.size(),3):
   var hit:Variant=Geometry3D.ray_intersects_triangle(from,-eye,points[index],points[index+1],points[index+2])
   if hit is Vector3 and from.distance_squared_to(hit)<nearest:nearest=from.distance_squared_to(hit);result=hit
 assert(is_finite(nearest),"A native flower attachment must intersect its plant body")
 return result
static func mesh(serial:int,g:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var spec:Dictionary=data().graphics[str(serial)]
 assert(g.rgba_sha256==spec.source_rgba_sha256 and g.origin==spec.origin)
 var pieces=[];var body_arrays=[];var body_paint:Texture2D=load(ROOT+str(serial)+"-body.png")
 for part_index in spec.parts.size():
  var box:Array=spec.parts[part_index];var grain:Texture2D=load(ROOT+spec.part_grains[part_index])
  var shape=Base.PreparedSkin.new([],grain,1./Base.Fit.VERTICAL);shape.tiles={"stone":Vector2.ZERO};shape.part="stone";shape.pitches.stone=.85
  var profile:Array[Vector2]=[Vector2.ZERO]
  for point:Array in spec.profile:profile.append(Vector2(float(point[1]),float(point[0])*2.))
  profile.append(Vector2(0.,2.))
  ribbed_round(shape,profile)
  var raw:Mesh=shape.finish();var points:Array[Vector3]=[]
  # A round source silhouette includes top-down depth. Its shallow hidden axis
  # must be fitted separately, or a low barrel degenerates into a zero-height disc.
  var depth=Basis(Vector3(.725,0,.275),Vector3.UP,Vector3(.275,0,.725))
  for p:Vector3 in raw.get_meta("east_cpu_arrays")[0][Mesh.ARRAY_VERTEX]:points.append(depth*p)
  var target=Rect2(float(g.origin[0])+float(box[0]),float(g.origin[1])+float(box[1]),float(box[2])-float(box[0]),float(box[3])-float(box[1]))
  var pose=Base.Fit.measure(points,"",Basis(Vector3.UP,PI*.5),target)*Transform3D(depth,Vector3.ZERO)
  var fitted:Mesh=Base.transformed_existing(raw,pose);var arrays:Array=fitted.get_meta("east_cpu_arrays")[0]
  body_arrays.append(arrays)
  var row:Dictionary=g.duplicate(true);row.rect=[0,0,g.rect[2],g.rect[3]]
  var native=Base.native_skin(row,body_paint);var back=Base.PreparedSkin.new([],grain,1./Base.Fit.VERTICAL);back.tiles={"stone":Vector2.ZERO};back.part="stone";back.pitches.stone=.85
  var eye=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized();var center=fitted.get_aabb().get_center()
  for offset in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
   for index in range(offset,offset+3):
    var vertex:Vector3=arrays[Mesh.ARRAY_VERTEX][index]
    var around=(atan2(vertex.z-center.z,vertex.x-center.x)+PI)/TAU
    back.surface.set_normal(arrays[Mesh.ARRAY_NORMAL][index]);back.surface.set_uv2(Vector2.ZERO);back.surface.set_uv(Vector2(around*3.,-vertex.y/1.6));back.surface.add_vertex(vertex)
   if arrays[Mesh.ARRAY_NORMAL][offset].dot(eye)<=0.:continue
   for index in range(offset,offset+3):native.projected_vertex(arrays[Mesh.ARRAY_VERTEX][index]+arrays[Mesh.ARRAY_NORMAL][index]*.012,arrays[Mesh.ARRAY_NORMAL][index],arrays[Mesh.ARRAY_VERTEX][index])
  var reverse:Mesh=back.finish();var material:ShaderMaterial=reverse.surface_get_material(0).duplicate();material.set_shader_parameter("original_palette",false);material.set_shader_parameter("surface_kind",5.0);reverse.surface_set_material(0,material)
  pieces.append(reverse);pieces.append(native.finish())
 for index in spec.get("details",[]).size():
  var box:Array=spec.details[index];var base=Vector2(spec.detail_attachments[index][0],spec.detail_attachments[index][1]);var at=source_surface(base,g,body_arrays)
  var ground=base.y+float(g.origin[1])+at.y*Base.Fit.VERTICAL
  pieces.append(Base.foliage(g,load(ROOT+str(serial)+"-detail-"+str(index)+".png"),box,ground,base))
 var floor_row:Dictionary=g.duplicate(true);floor_row.rect=[0,0,g.rect[2],g.rect[3]]
 var floor_skin=Base.native_skin(floor_row,load(ROOT+str(serial)+"-ground.png"));var p=[]
 for pixel in [Vector2.ZERO,Vector2(g.rect[2],0),Vector2(g.rect[2],g.rect[3]),Vector2(0,g.rect[3])]:p.append(Base.point(pixel,.06,g))
 for index in [0,2,1,0,3,2]:floor_skin.projected_vertex(p[index],Vector3.UP,p[index])
 pieces.append(floor_skin.finish());var result=Base.owner_frame(Base.combine(pieces));result.set_meta("east_round_cactus",serial);meshes[serial]=result;return result
