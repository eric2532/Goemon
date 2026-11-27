extends RefCounted
## Source-sized moulded columns with independent closed backs; no navigation owner.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Profiles=preload("res://scripts/forest/forest_east_fallback_families.gd")
const ROOT="res://assets/maps/falan/east_region/room_columns/"
const IDS=[1235141,1235142,1235143,1235144,1235145,1235151,1235152,1235153,1235154,1235155,1235156,1235160,1235183,1235184,1235185,1235186,1235187,1235188]
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static func owns(serial:int)->bool:return serial in IDS
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog

static func mesh(serial:int,graphic:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)]
 assert(graphic.rgba_sha256==g.source_rgba_sha256,"Regenerate the native room-column derivative")
 var base=Source.new([],load(ROOT+g.style+"-surfaces.png"),.045)
 base.tiles={"stone":Vector2.ZERO,"gold":Vector2.ZERO,"cap":Vector2(128,0)}
 base.pitches={"stone":1.4,"gold":1.4,"cap":1.4}
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(ROOT+str(serial)+".png"),.045)
 var h:float=g.height
 if not g.round:
  Profiles.profile(base,front,[Vector3(1.5,0,1.5),Vector3(1.5,.32,1.5),Vector3(1.20,.54,1.20),Vector3(1.08,.70,1.08),Vector3(1.08,h-.75,1.08),Vector3(1.28,h-.57,1.28),Vector3(1.5,h-.40,1.5),Vector3(1.5,h,1.5)],Vector3.ZERO,.035)
 else:
  var r=float(g.size[0])/(2.*sqrt(2.)*(32./3.))
  var rings=[Vector2(r,0),Vector2(r,.18),Vector2(r*.85,.34),Vector2(r*.68,.51),Vector2(r*.61,h-.44),Vector2(r*.82,h-.30),Vector2(r,h-.18),Vector2(r,h)]
  for level in rings.size()-1:
   for side in 32:
    var a=-side*TAU/32.;var b=-(side+1)*TAU/32.;var lo:Vector2=rings[level];var hi:Vector2=rings[level+1]
    var points=[Vector3(cos(a)*lo.x,lo.y,sin(a)*lo.x),Vector3(cos(a)*hi.x,hi.y,sin(a)*hi.x),Vector3(cos(b)*hi.x,hi.y,sin(b)*hi.x),Vector3(cos(b)*lo.x,lo.y,sin(b)*lo.x)]
    base.part="stone";base.quad(points[0],points[1],points[2],points[3])
    var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
    if normal.dot(Vector3(-1,0,1))>0:
     for i in [0,1,2,0,2,3]:front.projected_vertex(points[i]+normal*.003,normal,points[i])
  for top in [false,true]:
   var center=Vector3.UP*(h if top else 0.);base.part="cap"
   for side in 32:
    var a=side*TAU/32.;var b=(side+1)*TAU/32.
    var p=center+Vector3(cos(a)*r,0,sin(a)*r);var q=center+Vector3(cos(b)*r,0,sin(b)*r)
    base.quad(center,p,q,q) if top else base.quad(center,q,p,p)
 var result=base.finish();var paint=front.finish();var back:ShaderMaterial=result.surface_get_material(0).duplicate()
 back.set_shader_parameter("original_palette",false);result.surface_set_material(0,back)
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint.surface_get_arrays(0));result.surface_set_material(1,paint.surface_get_material(0))
 result.set_meta("east_source_room_column",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("inferred_closed_reverse",true)
 meshes[serial]=result
 return result
