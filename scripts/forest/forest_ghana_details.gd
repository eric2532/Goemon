extends RefCounted
## Native well in the existing village visual owner; no collision or route changes.
# shortcut: The archive supplies one view; hidden ring paint and bucket depth remain inferred.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Parts=preload("res://scripts/forest/forest_tina_building_details.gd")
const Kili=preload("res://scripts/forest/forest_kili_art.gd")
const BuildingData=preload("res://assets/maps/original_crossgate/building-surfaces.gd")
const BuildingAtlas=preload("res://assets/maps/original_crossgate/building-surfaces.png")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Atlas=preload("res://assets/maps/falan/ghana_well.png")
const Data=preload("res://assets/maps/falan/ghana_fronts.gd")
const ORIGIN=Vector2(45,79)
static var prepared:Mesh
static var fences={}

static func fence_mesh(serial:int)->Mesh:
 if not fences.has(serial):
  var skin=Source.new([],BuildingAtlas,1.0/Fit.VERTICAL)
  skin.tiles=BuildingData.TILES
  Parts.fence(skin,serial,Data.FENCE_POST_PIXELS[serial]/Fit.VERTICAL)
  fences[serial]=skin.finish()
 return fences[serial]

static func batch_fences(parent:Node3D,groups:Dictionary):
 for serial in groups:fence_mesh(serial)
 Kili.batch_meshes(parent,groups,fences,"NativeGhanaFence")

static func point(pixel:Vector2,height:float)->Vector3:
 var u=(pixel.x-ORIGIN.x)/Fit.HORIZONTAL
 var w=(pixel.y-ORIGIN.y+height*Fit.VERTICAL)/Fit.FLOOR
 return Vector3((u-w)*.5,height,(u+w)*.5)

static func rod(skin,a:Vector3,b:Vector3,radius:float):
 var axis=(b-a).normalized()
 var tangent=axis.cross(Vector3.RIGHT if absf(axis.y)>.9 else Vector3.UP).normalized()*radius
 var other=axis.cross(tangent)
 for i in 12:
  var offset=tangent*cos(i*TAU/12)+other*sin(i*TAU/12)
  var next=tangent*cos((i+1)*TAU/12)+other*sin((i+1)*TAU/12)
  skin.quad(a+offset,b+offset,b+next,a+next)
  skin.quad(a,a+next,a+offset,a)
  skin.quad(b,b+offset,b+next,b)

static func mesh()->Mesh:
 if prepared!=null:return prepared
 var skin=Source.new([Rect2(0,0,92,118),ORIGIN,Vector2.ONE,0],Atlas,1.0/Fit.VERTICAL)
 skin.reflection_threshold=1.0
 var radius=44.0/(sqrt(2.0)*Fit.HORIZONTAL)
 var height=25.0/Fit.VERTICAL
 Parts.round_roof(skin,Vector3.ZERO,radius,radius,[[1,0,79,31],[1.02,height,54,31],[.72,height,54,22],[.72,.6,73,22]],45,44)
 var dark:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/ghana_well.json"))
 var dark_pixel=Vector2(dark.dark_pixel[0],dark.dark_pixel[1])
 var center=Vector3.UP*.59
 Parts.painted_quad(skin,center+Vector3(-1.5,0,-1.5),center+Vector3(-1.5,0,1.5),center+Vector3(1.5,0,1.5),center+Vector3(1.5,0,-1.5),[dark_pixel,dark_pixel,dark_pixel,dark_pixel])
 var near=point(Vector2(8,114),0);var far=point(Vector2(78,63),0)
 var near_top=near+Vector3.UP*(61.0/Fit.VERTICAL)
 var far_top=far+Vector3.UP*(60.0/Fit.VERTICAL)
 rod(skin,near,near_top,.14);rod(skin,far,far_top,.14)
 rod(skin,near_top,far_top,.12)
 var bucket=point(Vector2(48,69),height+.08)
 var rope=point(Vector2(48,26),height+43.0/Fit.VERTICAL)
 rod(skin,bucket+Vector3.UP*.8,rope,.035)
 Parts.Parts.kili_round(skin,bucket,[Vector2(.29,0),Vector2(.40,.12),Vector2(.45,.85),Vector2(.35,.85),Vector2(.30,.20)])
 rod(skin,bucket+Vector3(-.32,.75,0),bucket+Vector3(-.32,1.2,0),.035)
 rod(skin,bucket+Vector3(.32,.75,0),bucket+Vector3(.32,1.2,0),.035)
 rod(skin,bucket+Vector3(-.32,1.2,0),bucket+Vector3(.32,1.2,0),.035)
 prepared=skin.finish();prepared.set_meta("source_graphic",11229)
 return prepared

static func build(parent:Node3D,height:float):
 var node=Geo.mesh(parent,mesh(),Vector3(10.5,height,13.5),null)
 node.name="NativeGhanaWell_11229";node.set_meta("source_graphic",11229)
