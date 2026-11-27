extends RefCounted
## One source gate template; ordinary Explore still owns its path and collision.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const ROOT="res://assets/maps/falan/elsa/scenery/gate/"
static var metadata:Dictionary={}
static var prepared:Dictionary={}

static func data()->Dictionary:
 if metadata.is_empty():metadata=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return metadata

static func replaces(placement:Dictionary)->bool:
 for gate in [data()]+data().get("others",[]):
  if gate.members.any(func(member):return member.group==placement.group and Vector2(member.anchor[0],member.anchor[1])==Vector2(placement.anchor[0],placement.anchor[1])):return true
 return false

static func body(skin,at:Vector3,radius_scale:float,heights:Dictionary):
 var roof:float=heights.roof;var pole:float=heights.pole
 var profile=[[2.7,0.],[2.7,.35],[2.45,.55],[2.45,8.9],[2.7,9.0],[2.7,9.45],[2.4,9.6],[2.4,10.25],[3.05,10.5],[.17,roof],[.10,minf(roof+.4,pole)],[.07,pole]]
 if heights.has("eave"):
  for i in 9:profile[i][1]*=heights.eave/10.5
 for band in profile.size()-1:
  for side in 32:
   var a=side*TAU/32.;var b=(side+1)*TAU/32.
   var low:Array=[profile[band][0]*radius_scale,profile[band][1]];var high:Array=[profile[band+1][0]*radius_scale,profile[band+1][1]]
   var corners=[at+Vector3(cos(a)*low[0],low[1],sin(a)*low[0]),at+Vector3(cos(b)*low[0],low[1],sin(b)*low[0]),at+Vector3(cos(b)*high[0],high[1],sin(b)*high[0]),at+Vector3(cos(a)*high[0],high[1],sin(a)*high[0])]
   if band<9:
    var normal:Vector3=(corners[2]-corners[0]).cross(corners[1]-corners[0]).normalized()
    for i in [0,1,2,0,2,3]:
     var point:Vector3=corners[i];var sample=point
     sample.y+=((point.z-at.z)-(point.x-at.x))*8.*.045
     skin.projected_vertex(point,normal,sample)
   else:skin.quad(corners[0],corners[1],corners[2],corners[3])

static func surface(texture:Texture2D,entry:Dictionary):
 var rect:Array=entry.rect
 var skin=Source.new([Rect2(Vector2.ZERO,texture.get_size()),-Vector2(rect[0],rect[1]),Vector2.ONE,0],texture,.045)
 skin.reflection_threshold=2.
 return skin

static func mesh(entry:Dictionary={})->Mesh:
 if entry.is_empty():entry=data()
 var key:String=entry.get("name","arrival");var folder:String=entry.get("folder","")
 if prepared.has(key):return prepared[key]
 var solid:Texture2D=load(ROOT+folder+"solid.png");var foreground:Texture2D=load(ROOT+folder+"foreground.png")
 var skin=surface(solid,entry);var grid=surface(foreground,entry)
 var a=Vector3(entry.feet[0][0]*3.,0,entry.feet[0][1]*3.);var b=Vector3(entry.feet[1][0]*3.,0,entry.feet[1][1]*3.)
 var across=(b-a).normalized();var normal=Vector3(-across.z,0,across.x);var center=(a+b)*.5
 var radius_scale:float=entry.get("radius_scale",1.);var arch_scale:float=entry.get("arch_scale",1.)
 body(skin,a,radius_scale,entry.heights[0]);body(skin,b,radius_scale,entry.heights[1])
 var half=a.distance_to(b)*.5-2.35*radius_scale
 for segment in 24:
  var x0=lerpf(-half,half,segment/24.);var x1=lerpf(-half,half,(segment+1)/24.)
  var curve0=sqrt(maxf(0.,1.-pow(x0/half,2)));var curve1=sqrt(maxf(0.,1.-pow(x1/half,2)))
  var inner0=center+across*x0+Vector3.UP*(8.1+3.7*curve0)*arch_scale;var inner1=center+across*x1+Vector3.UP*(8.1+3.7*curve1)*arch_scale
  var outer0=center+across*x0+Vector3.UP*(8.7+4.2*curve0)*arch_scale;var outer1=center+across*x1+Vector3.UP*(8.7+4.2*curve1)*arch_scale
  var front=normal*.6
  skin.quad(inner0+front,outer0+front,outer1+front,inner1+front)
  skin.quad(inner1-front,outer1-front,outer0-front,inner0-front)
  skin.quad(outer0+front,outer0-front,outer1-front,outer1+front)
  skin.quad(inner0-front,inner0+front,inner1+front,inner1-front)
  grid.quad(center+across*x0+normal*.61,inner0+normal*.61,inner1+normal*.61,center+across*x1+normal*.61)
 var mesh_:ArrayMesh=skin.finish();var bars:Mesh=grid.finish()
 mesh_.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,bars.surface_get_arrays(0));mesh_.surface_set_material(1,bars.surface_get_material(0))
 for panel in entry.get("panels",[]):
  var g={"rect":panel.rect,"origin":panel.origin,"cut":[300811]}
  var piece:Mesh=load("res://scripts/forest/forest_elsa_scenery.gd").relief_shape(g,foreground,solid,panel.edges,Vector2(panel.foot[0],panel.foot[1]))
  for slot in piece.get_surface_count():
   var index=mesh_.get_surface_count();mesh_.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,piece.surface_get_arrays(slot));mesh_.surface_set_material(index,piece.surface_get_material(slot))
 if entry.has("span"):
  var span_texture:Texture2D=load(ROOT+folder+"span.png")
  var span:Mesh=load("res://scripts/forest/forest_elsa_scenery.gd").bridge(entry.span,span_texture,entry.span.shape)
  for slot in span.get_surface_count():
   var index=mesh_.get_surface_count();mesh_.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,span.surface_get_arrays(slot));mesh_.surface_set_material(index,span.surface_get_material(slot))
 prepared[key]=Fit.transformed(mesh_,Fit.native_coastal_frame());return prepared[key]

static func build(root:Node3D,origin:Vector2):
 for entry in [data()]+data().get("others",[]):
  var node=MeshInstance3D.new();node.name="ElsaSourceGate_"+entry.get("name","arrival");node.mesh=mesh(entry);node.position=Vector3(origin.x,0,origin.y)
  node.set_meta("source_members",entry.members);node.set_meta("inferred_depth",true);root.add_child(node)
