extends RefCounted
## Source-specific silhouettes, roof lines and original facade paint.
const Data=preload("res://assets/maps/falan/coastal_building_art.gd")
const Atlas=preload("res://assets/maps/falan/coastal_building_art.png")
const SourceMesh=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Proportions=preload("res://scripts/forest/forest_falan_proportions.gd")
const KILI_GRAPHICS=[11289,11290,11292,11293,11294,11295,11297,11298]
const KiliSurfaces=preload("res://assets/maps/falan/kili_surfaces.gd")
const KiliAtlas=preload("res://assets/maps/falan/kili_surfaces.png")
const VILLAGE_GRAPHICS=[10607,11268,11269,11271,11272,11273,11275]
const Surfaces=preload("res://assets/maps/falan/village_building_surfaces.gd")
const SurfaceAtlas=preload("res://assets/maps/falan/village_building_surfaces.png")
static var meshes:Dictionary={}

static func build(parent:Node3D,at:Vector3,serial:int,data=Data,atlas:Texture2D=Atlas,fit:Vector3=Vector3.ONE):
 if serial==10607:
  # Il uses the same native guild graphic as the city employment office.
  var civic=load("res://scripts/forest/forest_falan_civic_exterior.gd")
  var spec:Array=civic.SHELLS[Vector2i(-42,-23)].duplicate()
  spec[3]=Vector2(at.x,at.z)
  var node:Node3D=civic.build(parent,at,spec)
  node.rotation.y=-PI*.5
  # This is the same graphic at the same three-metre tile scale as Falan.
  # The old collision-box fit must not compress the calibrated source facade.
  node.name="BlueCGVillageBuilding_10607"
  node.set_meta("source_graphic",serial)
  return
 var key=[SurfaceAtlas,serial,fit] if serial in VILLAGE_GRAPHICS else [atlas,serial]
 if not meshes.has(key):meshes[key]=shape(serial,data,atlas,fit)
 var node=Geo.mesh(parent,meshes[key],at,null)
 node.scale=Vector3.ONE if serial in VILLAGE_GRAPHICS else fit
 node.name="BlueCGVillageBuilding_"+str(serial)
 node.set_meta("source_graphic",serial)

static func shape(serial:int,data=Data,atlas:Texture2D=Atlas,fit:Vector3=Vector3.ONE)->Mesh:
 if data==Data and atlas==Atlas and serial in [11276,11279,11280,11283,11284,11286]:
  return load("res://scripts/forest/forest_venoa_buildings.gd").prepare(serial)
 var art:Array=data.GRAPHICS[serial]
 var span:Vector2=art[2]
 var profile:Vector2=data.PROFILES[serial]*.045
 var body=SourceMesh.new(art,SurfaceAtlas if serial in VILLAGE_GRAPHICS else atlas,.045)
 var w=span.x;var d=span.y;var h=profile.x
 if serial in KILI_GRAPHICS:return Proportions.transformed(kili_building(body,serial,w,d,h),Proportions.native_coastal_frame())
 if serial in VILLAGE_GRAPHICS:
  body.tiles=Surfaces.TILES
  body.baked_scale=fit
  var source_height=h+1.05 if serial==10607 else h+profile.y+(2.2 if serial in [11268,11269,11271] else 0.0)
  body.baked_scale.y*=(h+profile.y+2.2)/source_height
  village_house(body,serial,w,d,h,profile.y)
 elif serial==11297:
  body.box(AABB(Vector3(-w*.5,h-.65,-d*.5),Vector3(w,.65,d)))
  for side in [-1,1]:body.box(AABB(Vector3(side*(w*.5-.6)-.6,0,-d*.5),Vector3(1.2,h,d)))
  body.box(AABB(Vector3(-w*.5,h,-d*.5),Vector3(w,2.8,.45)))
 elif serial==11294:
  body.box(AABB(Vector3(-w*.5,0,-d*.5),Vector3(w,h,d*2.0/3.0)))
  body.box(AABB(Vector3(-w*.5,0,d/6.0),Vector3(w,h*.60,d/3.0)))
  terrace(body,Vector2(w,d*2.0/3.0),Vector3(0,h,-d/6.0))
  terrace(body,Vector2(w,d/3.0),Vector3(0,h*.60,d/3.0))
 else:
  body.box(AABB(Vector3(-w*.5,0,-d*.5),Vector3(w,h,d)))
  if profile.y>0:
   var along_x=w>=d
   roof(body,w,d,h,profile.y,along_x)
   var stacks=4 if serial in [11279,11284] else 2
   if serial==11286:stacks=1
   for i in stacks:
    var offset=(float(i)+.5)/stacks-.5
    var p=Vector3(offset*w*.73,h+profile.y-.8,0) if along_x else Vector3(0,h+profile.y-.8,offset*d*.73)
    body.box(AABB(p-Vector3(.7,0,.7),Vector3(1.4,2.2,1.4)))
    body.box(AABB(p+Vector3(-.84,2.0,-.84),Vector3(1.68,.24,1.68)))
  else:
   terrace(body,span,Vector3.UP*h)
   if serial==11293:
    for side in [-1,1]:
     var p=Vector3(side*w*.32,h,-d*.36)
     body.box(AABB(p-Vector3(.85,0,.7),Vector3(1.7,3.7,1.4)))
     body.box(AABB(p+Vector3(-1.0,3.7,-.82),Vector3(2.0,.35,1.64)))
     body.box(AABB(p+Vector3(-.18,4.0,-.18),Vector3(.36,1.3,.36)))
     body.box(AABB(p+Vector3(-.60,4.7,-.18),Vector3(1.2,.28,.36)))
   elif serial in [11289,11290,11292]:
    var p=Vector3(-w*.10,h,d*.08)
    body.box(AABB(p+Vector3(-1.8,1.4,-1.3),Vector3(3.6,.14,2.6)))
    for x in [-1.65,1.65]:
     for z in [-1.16,1.16]:body.box(AABB(p+Vector3(x-.05,0,z-.05),Vector3(.10,1.4,.10)))
 return body.finish()

static func village_house(skin,serial:int,w:float,d:float,h:float,rise:float):
 if serial in [11268,11269]:
  round_house(skin,w,d,h,rise)
  return
 if serial==11271:
  round_house(skin,w*.68,d*.90,h,rise)
  for side in [-1,1]:
   var at=Vector3(side*w*.40,0,0)
   skin.part="plaster"
   skin.box(AABB(at+Vector3(-w*.13,0,-d*.44),Vector3(w*.26,h*.56,d*.88)))
   wall_details(skin,serial,w*.26,d*.88,h*.56,at,false)
   skin.part="timber"
   roof(skin,w*.28,d*.94,h*.56,rise*.24,true,at)
  return
 skin.part="stone" if serial==10607 else "plaster"
 skin.box(AABB(Vector3(-w*.5,0,-d*.5),Vector3(w,h,d)))
 wall_details(skin,serial,w,d,h)
 if serial==10607:
  skin.part="blue_roof"
  skin.quad(Vector3(-w*.5,h+.01,-d*.5),Vector3(w*.5,h+.01,-d*.5),Vector3(w*.5,h+.01,d*.5),Vector3(-w*.5,h+.01,d*.5))
  skin.part="plaster"
  terrace(skin,Vector2(w,d),Vector3.UP*h)
  for i in 8:
   var a=PI*.5+i*PI/8
   var b=PI*.5+(i+1)*PI/8
   var p=Vector3(-w*.5,0,0)
   var lower=p+Vector3(cos(a)*2.9,0,sin(a)*4.0)
   var next=p+Vector3(cos(b)*2.9,0,sin(b)*4.0)
   skin.part="stone"
   skin.quad(next,next+Vector3.UP*h*.63,lower+Vector3.UP*h*.63,lower)
   skin.part="blue_roof"
   skin.quad(p+Vector3.UP*h*.67,lower+Vector3.UP*h*.67,next+Vector3.UP*h*.67,p+Vector3.UP*h*.67)
  detail(skin,Vector3(-w*.5-2.93,h*.32,0),Vector3.BACK,"door",h*skin.baked_scale.y*.63)
  return
 var along_x=w>=d
 skin.part="thatch"
 roof(skin,w,d,h,rise,along_x)
 skin.part="trim"
 skin.box(AABB(Vector3(-w*.5,h+rise-.22,-.14),Vector3(w,.22,.28)) if along_x else AABB(Vector3(-.14,h+rise-.22,-d*.5),Vector3(.28,.22,d)))
 var count_=1 if serial==11273 else 3
 # Both slopes get real dormers; a whole roof image no longer supplies flattened copies.
 for side in [-1,1]:
  for i in count_:
   var along=(float(i)-(count_-1)*.5)*(.30 if along_x else .36)
   var at=Vector3((along+.075)*w,0,side*d*.27) if along_x else Vector3(side*w*.29,0,along*d)
   var size_=Vector3(2.6,2.3,w*.55 if serial==11273 else 3.1)
   var base=h+rise*(.22 if along_x else .17)
   skin.part="trim"
   skin.box(AABB(at+Vector3(-size_.x*.5,base,-size_.z*.5),size_))
   var outward=Vector3(0,0,side) if along_x else Vector3(side,0,0)
   var center=at+Vector3(0,base+size_.y*.5,0)
   center+=outward*(size_.z*.5+.025 if along_x else size_.x*.5+.025)
   detail(skin,center,Vector3.UP.cross(outward),"window",size_.y*skin.baked_scale.y*.93)
   skin.part="dormer_cap"
   roof(skin,size_.x+.25,size_.z+.25,base+size_.y,rise*.13,not along_x,at)
 if serial==11275:
  var inner=-w*.49;var outer=-w*.70
  var z=d*.33
  skin.part="canopy"
  skin.feature=true
  skin.quad(Vector3(outer,h*.55,-z),Vector3(inner,h*.79,-z),Vector3(inner,h*.79,z),Vector3(outer,h*.55,z))
  skin.feature=false;skin.part="trim"
  for side in [-1,1]:skin.box(AABB(Vector3(outer-.08,0,side*z-.08),Vector3(.16,h*.55,.16)))

static func detail(skin,center:Vector3,horizontal:Vector3,paint:String,span:float):
 # Square panels stay square after fitting; the recovered feature keeps its own aspect within the tile.
 var right=horizontal*span/(horizontal*skin.baked_scale).length()*.5
 var up=Vector3.UP*span/skin.baked_scale.y*.5
 skin.panel(center-right-up,center-right+up,center+right+up,center+right-up,paint)

static func wall_details(skin,serial:int,w:float,d:float,h:float,origin:Vector3=Vector3.ZERO,door:bool=true):
 var height=h*skin.baked_scale.y
 for normal:Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
  var horizontal=Vector3.UP.cross(normal)
  var center=origin+normal*(w*.5+.04 if absf(normal.x)>.5 else d*.5+.04)
  var width=d if absf(normal.x)>.5 else w
  var world_width=width*(horizontal*skin.baked_scale).length()
  var span=minf(height*.48,world_width*.32)
  for side in [-1,1]:
   detail(skin,center+horizontal*width*side*.27+Vector3.UP*h*.54,horizontal,"church_window" if serial==10607 else "window",span)
  if serial==10607:
   detail(skin,center+Vector3.UP*h*.79,horizontal,"medallion",minf(height*.32,world_width*.3))
  if door and normal==Vector3.LEFT and serial!=10607:
   detail(skin,center+Vector3.UP*h*.33,horizontal,"door",height*.67)
 skin.part="stone"
 skin.box(AABB(origin+Vector3(-w*.5-.015,0,-d*.5-.015),Vector3(w+.03,h*.10,d+.03)))
 skin.part="plaster" if serial==10607 else "trim"
 for x in [-1,1]:
  for z in [-1,1]:
   skin.box(AABB(origin+Vector3(x*(w*.5-.10)-.10,0,z*(d*.5-.10)-.10),Vector3(.20,h,.20)))

static func round_house(skin,w:float,d:float,h:float,rise:float):
 var rings=[Vector2(.48,0),Vector2(.48,h),Vector2(.55,h),Vector2(.22,h+rise*.60),
  Vector2(.17,h+rise*.60),Vector2(.17,h+rise*.87),Vector2(.25,h+rise*.87),Vector2(.01,h+rise+2.2)]
 for level in rings.size()-1:
  var lower:Vector2=rings[level]
  var upper:Vector2=rings[level+1]
  skin.part="plaster" if level in [0,4] else "round_thatch"
  for i in 16:
   var a=-i*TAU/16.0
   var b=-(i+1)*TAU/16.0
   skin.quad(Vector3(cos(a)*w*lower.x,lower.y,sin(a)*d*lower.x),Vector3(cos(a)*w*upper.x,upper.y,sin(a)*d*upper.x),
    Vector3(cos(b)*w*upper.x,upper.y,sin(b)*d*upper.x),Vector3(cos(b)*w*lower.x,lower.y,sin(b)*d*lower.x))
 for i in 8:
  var angle=(i+.25)*TAU/8
  var normal=Vector3(cos(angle)/w,0,sin(angle)/d).normalized()
  var horizontal=Vector3(sin(angle)*w,0,-cos(angle)*d).normalized()
  var center=Vector3(cos(angle)*w*.48*cos(PI/16),h*.57,sin(angle)*d*.48*cos(PI/16))+normal*.03
  detail(skin,center,horizontal,"round_window",h*skin.baked_scale.y*.42)
  if i%2==0:
   var top=Vector3(cos(angle)*w*.17*cos(PI/16),h+rise*.735,sin(angle)*d*.17*cos(PI/16))+normal*.03
   detail(skin,top,horizontal,"round_window",rise*skin.baked_scale.y*.27)
 detail(skin,Vector3(-w*.48-.035,h*.31,0),Vector3.BACK,"door",h*skin.baked_scale.y*.65)

static func terrace(skin,span:Vector2,p:Vector3):
 for side in [-1,1]:
  skin.box(AABB(p+Vector3(-span.x*.5,0,side*(span.y*.5-.20)-.20),Vector3(span.x,.7,.40)))
  skin.box(AABB(p+Vector3(side*(span.x*.5-.20)-.20,0,-span.y*.5),Vector3(.40,.7,span.y)))
  for i in int(span.x/1.8):
   skin.box(AABB(p+Vector3(-span.x*.5+.25+i*1.8,.7,side*(span.y*.5-.20)-.20),Vector3(.65,.35,.4)))
  for i in int(span.y/1.8):
   skin.box(AABB(p+Vector3(side*(span.x*.5-.20)-.20,.7,-span.y*.5+.25+i*1.8),Vector3(.4,.35,.65)))

static func roof(skin,w:float,d:float,h:float,rise:float,along_x:bool,at:Vector3=Vector3.ZERO):
 var a=Vector3(at.x-w*.5-.25,h,at.z-d*.5-.25)
 var b=Vector3(at.x+w*.5+.25,h,at.z+d*.5+.25)
 if along_x:
  skin.quad(Vector3(a.x,h,b.z),Vector3(a.x,h+rise,at.z),Vector3(b.x,h+rise,at.z),Vector3(b.x,h,b.z))
  skin.quad(Vector3(b.x,h,a.z),Vector3(b.x,h+rise,at.z),Vector3(a.x,h+rise,at.z),Vector3(a.x,h,a.z))
  skin.quad(Vector3(a.x,h,a.z),Vector3(a.x,h+rise,at.z),Vector3(a.x,h,b.z),Vector3(a.x,h,a.z))
  skin.quad(Vector3(b.x,h,b.z),Vector3(b.x,h+rise,at.z),Vector3(b.x,h,a.z),Vector3(b.x,h,b.z))
 else:
  skin.quad(Vector3(a.x,h,a.z),Vector3(at.x,h+rise,a.z),Vector3(at.x,h+rise,b.z),Vector3(a.x,h,b.z))
  skin.quad(Vector3(b.x,h,b.z),Vector3(at.x,h+rise,b.z),Vector3(at.x,h+rise,a.z),Vector3(b.x,h,a.z))
  skin.quad(Vector3(a.x,h,b.z),Vector3(at.x,h+rise,b.z),Vector3(b.x,h,b.z),Vector3(a.x,h,b.z))
  skin.quad(Vector3(b.x,h,a.z),Vector3(at.x,h+rise,a.z),Vector3(a.x,h,a.z),Vector3(b.x,h,a.z))


static func kili_building(walls,serial:int,w:float,d:float,h:float)->Mesh:
 var skin=SourceMesh.new(walls.graphic,KiliAtlas,.045);skin.tiles=KiliSurfaces.TILES
 if serial==11297:
  walls.box(AABB(Vector3(-w*.5,h-.65,-d*.5),Vector3(w,.65,d)))
  for side in [-1,1]:walls.box(AABB(Vector3(side*(w*.5-.6)-.6,0,-d*.5),Vector3(1.2,h,d)))
  kili_terrace(walls,skin,w,d,h,Vector3.ZERO,false,serial)
  skin.part="trim"
  skin.box(AABB(Vector3(-w*.5,h,-d*.5),Vector3(w,1.15,.45)))
  skin.box(AABB(Vector3(-w*.16,h+1.15,-d*.5),Vector3(w*.32,.65,.45)))
 elif serial==11294:
  walls.box(AABB(Vector3(-w*.5,0,-d*.5),Vector3(w,h,d*2/3)))
  walls.box(AABB(Vector3(-w*.5,0,d/6),Vector3(w,h*.60,d/3)))
  kili_terrace(walls,skin,w,d*2/3,h,Vector3(0,0,-d/6),false,serial)
  kili_terrace(walls,skin,w,d/3,h*.60,Vector3(0,0,d/3),false,serial)
 else:
  walls.box(AABB(Vector3(-w*.5,0,-d*.5),Vector3(w,h,d)))
  kili_terrace(walls,skin,w,d,h,Vector3.ZERO,serial==11293,serial)
 if serial in [11289,11290]:
  var p=Vector3(-w*.23,h,d*.26 if serial==11289 else -d*.07)
  kili_canopy(skin,p,Vector2(3.3,2.9),1.5,"canopy")
  kili_rack(skin,Vector3(w*.20,h,-d*.03),3.9)
  for i in 3:kili_pot(skin,Vector3(w*.18+i*.78,h,-d*.30),.43,.65,true)
  if serial==11289:
   skin.part="trim";skin.box(AABB(Vector3(-w*.39,h,-d*.38),Vector3(w*.70,.42,.72)))
   for i in 3:kili_pot(skin,Vector3(-w*.29+i*.90,h+.42,-d*.34),.30,.45,true)
 elif serial==11292:
  kili_canopy(skin,Vector3(-w*.24,h,d*.06),Vector2(3.5,3.4),.92,"table")
  for i in 4:kili_pot(skin,Vector3(w*.22,h,-d*.30+i*.95),.31+i*.045,.69+i*.06,false,"pot_green" if i==1 else "bell" if i==3 else "pottery")
 elif serial==11293:
  for side in [-1,1]:kili_belfry(skin,Vector3(side*w*.32,h,-d*.36))
  for i in 3:kili_crate(skin,Vector3(w*.23,h,-d*.15+i*1.5),1.26)
  for i in 2:
   var p=Vector3(w*.22,h,d*.25+i*1.25)
   skin.part="white";skin.box(AABB(p+Vector3(-.65,0,-.48),Vector3(1.3,.51,.96)))
   skin.part="medical_red";skin.box(AABB(p+Vector3(-.40,.52,-.09),Vector3(.8,.025,.18)));skin.box(AABB(p+Vector3(-.09,.52,-.30),Vector3(.18,.025,.6)))
  skin.part="timber";kili_round(skin,Vector3(0,h+.08,-d*.06),[Vector2(.05,0),Vector2(.63,.05),Vector2(.63,.14),Vector2(.05,.14)])
 elif serial in [11295,11298]:
  for side in [-1,1]:
   kili_awning(skin,Vector3(side*w*.28,h*.63,d*.5+.02),Vector2(w*.25,1.04))
 load("res://scripts/forest/forest_kili_building_details.gd").relief(walls,serial,w,d)
 # Keep original wall/window/door pixels; unwrap roofs so their props have real depth.
 var result=ArrayMesh.new()
 for source in [walls.finish(),skin.finish()]:
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(0))
  result.surface_set_material(result.get_surface_count()-1,source.surface_get_material(0))
 return result

static func kili_terrace(walls,skin,w:float,d:float,h:float,at:Vector3=Vector3.ZERO,white:bool=false,serial:int=0):
 load("res://scripts/forest/forest_kili_building_details.gd").terrace(walls,skin,w,d,h,at,white,serial)

static func kili_round(skin,p:Vector3,profile:Array):
 for level in profile.size()-1:
  var lower:Vector2=profile[level];var upper:Vector2=profile[level+1]
  for i in 16:
   var a=-i*TAU/16;var b=-(i+1)*TAU/16
   skin.quad(p+Vector3(cos(a)*lower.x,lower.y,sin(a)*lower.x),p+Vector3(cos(a)*upper.x,upper.y,sin(a)*upper.x),
    p+Vector3(cos(b)*upper.x,upper.y,sin(b)*upper.x),p+Vector3(cos(b)*lower.x,lower.y,sin(b)*lower.x))

static func kili_pot(skin,p:Vector3,radius:float,height:float,plant:bool,paint:String="pottery"):
 skin.part=paint
 kili_round(skin,p,[Vector2(radius*.65,0),Vector2(radius,height*.15),Vector2(radius*.82,height*.85),Vector2(radius*.62,height),Vector2(radius*.48,height*.92),Vector2(radius*.48,height*.65)])
 if not plant:return
 skin.part="leaf"
 for i in 9:
  var a=i*TAU/9
  var center=p+Vector3.UP*height
  var tip=center+Vector3(cos(a)*radius*1.8,.26+(i%3)*.13,sin(a)*radius*1.8)
  var across=Vector3(-sin(a),0,cos(a))*radius*.28
  var peak=center.lerp(tip,.48)+Vector3.UP*.30
  skin.quad(center,peak+across,tip,peak-across)
  skin.quad(peak-across,tip,peak+across,center)

static func kili_canopy(skin,p:Vector3,size_:Vector2,height:float,paint:String):
 skin.part="timber"
 for side in [-1,1]:
  for end in [-1,1]:skin.box(AABB(p+Vector3(side*size_.x*.45-.045,0,end*size_.y*.45-.045),Vector3(.09,height+.15,.09)))
 skin.part=paint
 for i in 12:
  var a=float(i)/12;var b=float(i+1)/12
  var rise=.17 if paint=="canopy" else 0.0
  var y=height+rise*sin(a*PI);var next=height+rise*sin(b*PI)
  skin.quad(p+Vector3(size_.x*.5,y,(a-.5)*size_.y),p+Vector3(size_.x*.5,next,(b-.5)*size_.y),
   p+Vector3(-size_.x*.5,next,(b-.5)*size_.y),p+Vector3(-size_.x*.5,y,(a-.5)*size_.y))
 if paint=="canopy":kili_rack(skin,p+Vector3(-size_.x*.40,0,0),size_.y*.82)

static func kili_rack(skin,p:Vector3,length_:float):
 skin.part="timber"
 for end in [-1,1]:skin.box(AABB(p+Vector3(-.04,0,end*length_*.5-.04),Vector3(.08,1.5,.08)))
 skin.box(AABB(p+Vector3(-.025,1.35,-length_*.5),Vector3(.05,.05,length_)))
 for i in 5:
  var z=(i-2)*length_*.18;var y=.68+(i%2)*.25
  skin.box(AABB(p+Vector3(-.018,y,z-.018),Vector3(.036,1.38-y,.036)))
  kili_round(skin,p+Vector3(0,y-.23,z),[Vector2(.05,0),Vector2(.12,.06),Vector2(.12,.22),Vector2(.05,.26)])

static func kili_awning(skin,p:Vector3,size_:Vector2):
 skin.part="awning"
 skin.quad(p+Vector3(-size_.x*.5,-.25,size_.y),p+Vector3(-size_.x*.5,.25,0),p+Vector3(size_.x*.5,.25,0),p+Vector3(size_.x*.5,-.25,size_.y))
 for i in 8:skin.box(AABB(p+Vector3(-size_.x*.5+i*size_.x/8,-.45,size_.y-.04),Vector3(size_.x/8*.9,.22,.08)))

static func kili_crate(skin,p:Vector3,size_:float):
 skin.part="timber";skin.box(AABB(p+Vector3(-size_*.5,0,-size_*.5),Vector3.ONE*size_))
 skin.part="trim"
 for side in [-1,1]:
  for end in [-1,1]:skin.box(AABB(p+Vector3(side*(size_*.5-.06)-.06,0,end*(size_*.5-.06)-.06),Vector3(.12,size_,.12)))
 for i in 4:skin.box(AABB(p+Vector3(-size_*.46+i*size_*.25,size_+.01,-size_*.46),Vector3(.07,.04,size_*.92)))

static func kili_belfry(skin,p:Vector3):
 skin.part="white"
 for side in [-1,1]:skin.box(AABB(p+Vector3(-.51,0,side*.75-.18),Vector3(1.02,2.75,.36)))
 for i in 12:
  var a=i*PI/12;var b=(i+1)*PI/12
  var q=Vector3(0,2.68,0)
  var lower=q+Vector3(0,sin(a)*.87,cos(a)*.76)
  var next=q+Vector3(0,sin(b)*.87,cos(b)*.76)
  var outer=q+Vector3(0,sin(a)*1.13,cos(a)*1.02)
  var out_next=q+Vector3(0,sin(b)*1.13,cos(b)*1.02)
  for side in [-1,1]:
   var offset=p+Vector3(side*.51,0,0)
   if side<0:skin.quad(offset+lower,offset+outer,offset+out_next,offset+next)
   else:skin.quad(offset+next,offset+out_next,offset+outer,offset+lower)
  skin.quad(p+Vector3(-.51,0,0)+outer,p+Vector3(.51,0,0)+outer,p+Vector3(.51,0,0)+out_next,p+Vector3(-.51,0,0)+out_next)
 skin.box(AABB(p+Vector3(-.17,3.7,-.17),Vector3(.34,1.55,.34)))
 skin.box(AABB(p+Vector3(-.17,4.38,-.59),Vector3(.34,.29,1.18)))
 skin.part="timber";skin.box(AABB(p+Vector3(-.08,2.9,-.70),Vector3(.16,.12,1.4)))
 skin.part="bell"
 kili_round(skin,p+Vector3(0,1.35,0),[Vector2(.57,0),Vector2(.58,.12),Vector2(.39,.26),Vector2(.29,.70),Vector2(.12,.96)])
 skin.part="timber";kili_round(skin,p+Vector3(0,1.23,0),[Vector2(.07,0),Vector2(.07,.88)])
