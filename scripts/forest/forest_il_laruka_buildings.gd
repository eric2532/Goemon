extends RefCounted
## Coherent solid houses; source footprints, separate native surface paint and bounded details.
const Data=preload("res://assets/maps/falan/il_laruka/data.gd")
const Surfaces=preload("res://assets/maps/falan/il_laruka/building-surfaces.gd")
const Atlas=preload("res://assets/maps/falan/il_laruka/building-surfaces.png")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Parts=preload("res://scripts/forest/forest_coastal_buildings.gd")
static var meshes={}

static func bar(skin,a:Vector3,b:Vector3,width:float=.18):
 var basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()));var points=[]
 for i in 8:points.append((a+b)*.5+basis*Vector3(width*(.5 if i&1 else -.5),a.distance_to(b)*(.5 if i&2 else -.5),width*(.5 if i&4 else -.5)))
 for face in [[0,1,3,2],[4,6,7,5],[0,2,6,4],[1,5,7,3],[2,3,7,6],[0,4,5,1]]:skin.quad(points[face[0]],points[face[1]],points[face[2]],points[face[3]])

static func pitched(skin,w:float,d:float,h:float,rise:float,along_x:bool,paint:String,at:Vector3=Vector3.ZERO,gable:String="plaster"):
 var profile=[Vector2(-1,0),Vector2(-.84,.08),Vector2(-.48,.54),Vector2(0,1),Vector2(.48,.54),Vector2(.84,.08),Vector2(1,0)]
 for i in profile.size()-1:
  var a:Vector2=profile[i];var b:Vector2=profile[i+1]
  var p=Vector3(-w*.5,h+a.y*rise,a.x*d*.5) if along_x else Vector3(a.x*w*.5,h+a.y*rise,-d*.5)
  var q=Vector3(-w*.5,h+b.y*rise,b.x*d*.5) if along_x else Vector3(b.x*w*.5,h+b.y*rise,-d*.5)
  var back=Vector3.RIGHT*w if along_x else Vector3.BACK*d
  skin.part=paint
  skin.quad(at+p,at+q,at+q+back,at+p+back)
  skin.quad(at+p+back,at+q+back,at+q,at+p)
  skin.part=gable
  for offset in [Vector3.ZERO,back]:
   var u=p+offset;var v=q+offset
   skin.quad(at+Vector3(u.x,h,u.z),at+u,at+v,at+Vector3(v.x,h,v.z))
   skin.quad(at+Vector3(v.x,h,v.z),at+v,at+u,at+Vector3(u.x,h,u.z))
 skin.part="timber"
 for side in [-1,1]:
  var a=Vector3(side*w*.5,h,-d*.5) if along_x else Vector3(-w*.5,h,side*d*.5)
  var b=Vector3(side*w*.5,h,d*.5) if along_x else Vector3(w*.5,h,side*d*.5)
  var peak=Vector3(side*w*.5,h+rise,0) if along_x else Vector3(0,h+rise,side*d*.5)
  bar(skin,at+a,at+b)
  bar(skin,at+(a+b)*.5,at+peak)
  if gable=="woodwall":
   for fraction in [-.5,.5]:
    var foot=(a+b)*.5+(b-a)*fraction*.72
    var top=foot+Vector3.UP*rise*.23
    bar(skin,at+foot,at+top,.24)
    bar(skin,at+foot,at+(a+b)*.5+Vector3.UP*rise*.55,.20)
  # Solid fascia follows the bent source eaves on both gable ends.
  for i in profile.size()-1:
   var u:Vector2=profile[i];var v:Vector2=profile[i+1]
   var p=Vector3(side*w*.5,h+u.y*rise,u.x*d*.5) if along_x else Vector3(u.x*w*.5,h+u.y*rise,side*d*.5)
   var q=Vector3(side*w*.5,h+v.y*rise,v.x*d*.5) if along_x else Vector3(v.x*w*.5,h+v.y*rise,side*d*.5)
   bar(skin,at+p,at+q,.22)

static func panel(skin,p:Vector3,normal:Vector3,paint:String,height:float):
 Parts.detail(skin,p,Vector3.UP.cross(normal),paint,height)

static func window(skin,p:Vector3,normal:Vector3,height:float,paint:String="window"):
 var tangent=Vector3.UP.cross(normal)
 panel(skin,p+normal*.04,normal,paint,height)
 skin.part="timber"
 for side in [-1,1]:bar(skin,p+tangent*height*.34*side-Vector3.UP*height*.43,p+tangent*height*.34*side+Vector3.UP*height*.43,.14)
 for side in [-1,1]:bar(skin,p-tangent*height*.40+Vector3.UP*height*.43*side,p+tangent*height*.40+Vector3.UP*height*.43*side,.16)

static func walls(skin,w:float,d:float,h:float,doors:Array,at:Vector3=Vector3.ZERO,bottom:float=0,paint:String="plaster"):
 skin.part=paint
 skin.box(AABB(at+Vector3(-w*.5,bottom,-d*.5),Vector3(w,h-bottom,d)))
 skin.part="timber"
 for x in [-w*.5,0,w*.5]:
  for z in [-d*.5,d*.5]:skin.box(AABB(at+Vector3(x-.16,bottom,z-.18),Vector3(.32,h-bottom,.36)))
 for z in [-d*.5,0,d*.5]:
  for x in [-w*.5,w*.5]:skin.box(AABB(at+Vector3(x-.18,bottom,z-.16),Vector3(.36,h-bottom,.32)))
 for y in [bottom+.15,h-.18]:
  skin.box(AABB(at+Vector3(-w*.5-.13,y,-d*.5-.13),Vector3(w+.26,.24,d+.26)))
 for normal:Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
  var side=absf(normal.x)>.5
  var center=at+normal*(w*.5+.15 if side else d*.5+.15)+Vector3.UP*(bottom+(h-bottom)*.58)
  var tangent=Vector3.UP.cross(normal);var span=d if side else w
  for station in [-.29,.29]:window(skin,center+tangent*span*station,normal,minf(2.35,(h-bottom)*.68),"laruka_window" if paint=="woodwall" else "window")
  if paint=="woodwall":
   skin.part="timber"
   bar(skin,at+normal*(w*.5+.18 if side else d*.5+.18)-tangent*span*.5+Vector3.UP*(bottom+.75),at+normal*(w*.5+.18 if side else d*.5+.18)+tangent*span*.5+Vector3.UP*(bottom+.75),.20)
   for station in [-.41,-.13,.13,.41]:
    var blocked=false
    for door in doors:
     if door[0]==normal and absf(station*span-door[1]*(1.0 if normal.x>0 or normal.z<0 else -1.0))<1.5:blocked=true
    if blocked:continue
    var p=at+normal*(w*.5+.20 if side else d*.5+.20)+tangent*span*station+Vector3.UP*bottom
    bar(skin,p-tangent*minf(1.25,span*.08)+Vector3.UP*.18,p+tangent*minf(1.25,span*.08)+Vector3.UP*.75,.20)
   if h-bottom>5.5:
    var low=at+normal*(w*.5+.20 if side else d*.5+.20)+Vector3.UP*(bottom+1.55)
    bar(skin,low-tangent*span*.5+Vector3.UP*1.25,low+tangent*span*.5+Vector3.UP*1.25,.25)
    for station in [-.29,0,.29]:
     var blocked=false
     for door in doors:
      if door[0]==normal and absf(station*span-door[1]*(1.0 if normal.x>0 or normal.z<0 else -1.0))<1.8:blocked=true
     if not blocked:window(skin,low+tangent*span*station,normal,2.0,"laruka_window")
 for door in doors:
  var normal:Vector3=door[0]
  var p=at+normal*(w*.5+.17 if absf(normal.x)>.5 else d*.5+.17)
  p+=Vector3.UP*(bottom+1.35)+(Vector3.BACK if absf(normal.x)>.5 else Vector3.RIGHT)*door[1]
  panel(skin,p,normal,"laruka_door" if paint=="woodwall" else "door",3.05 if paint=="woodwall" else 2.65)
  skin.part="timber"
  var tangent=Vector3.UP.cross(normal)
  for side in [-1,1]:bar(skin,p+tangent*.73*side-Vector3.UP*1.35,p+tangent*.73*side+Vector3.UP*1.35,.20)
  bar(skin,p-tangent*.84+Vector3.UP*1.35,p+tangent*.84+Vector3.UP*1.35,.22)

static func dormer(skin,at:Vector3,along_x:bool,normal:Vector3,paint:String,width:float=2.7):
 var w=width if along_x else 2.7;var d=2.7 if along_x else width
 walls(skin,w,d,1.65,[],at)
 pitched(skin,w+.25,d+.25,at.y+1.65,.85,not along_x,paint,Vector3(at.x,0,at.z))
 panel(skin,at+normal*(d*.5+.16 if along_x else w*.5+.16)+Vector3.UP*.86,normal,"window",1.55)

static func il_crest(skin,w:float,d:float,h:float,rise:float,along_x:bool,serial:int):
 var tangent=Vector3.RIGHT if along_x else Vector3.BACK
 var normal=Vector3.BACK if along_x else Vector3.RIGHT
 var span=w if along_x else d
 var count_=3 if serial==11272 else 2 if serial==11273 else 4
 for i in count_:
  var station=(i-(count_-1)*.5)*span/(count_+.25)
  var p=tangent*station+Vector3.UP*(h+rise-.25)
  skin.part="timber"
  for side in [-1,1]:
   var at=p+normal*side*.48
   skin.box(AABB(at+Vector3(-.19,0,-.19),Vector3(.38,.95,.38)))
   Parts.kili_round(skin,at+Vector3.UP*.95,[Vector2(.27,0),Vector2(.20,.22),Vector2(.02,.34)])
  skin.part="ridge_cap"
  skin.box(AABB(p+Vector3(-.38,.35,-.38),Vector3(.76,.30,.76)))

static func railing(skin,center:Vector3,tangent:Vector3,length:float):
 skin.part="timber"
 for y in [.40,1.20]:bar(skin,center-tangent*length*.5+Vector3.UP*y,center+tangent*length*.5+Vector3.UP*y,.15)
 for side in [-1,1]:bar(skin,center+tangent*length*.5*side,center+tangent*length*.5*side+Vector3.UP*1.4,.22)
 bar(skin,center-tangent*length*.46+Vector3.UP*.45,center+tangent*length*.46+Vector3.UP*1.15,.13)
 bar(skin,center+tangent*length*.46+Vector3.UP*.45,center-tangent*length*.46+Vector3.UP*1.15,.13)

static func prepare(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=Data.GRAPHICS[str(serial)];var w=float(g.footprint[0])*3;var d=float(g.footprint[1])*3
 var skin=Source.new([],Atlas,.045);skin.tiles=Surfaces.TILES
 skin.pitches={"slate_roof":3.0,"pink_roof":3.0}
 if serial==11268:
  skin.part="stone";Parts.kili_round(skin,Vector3.ZERO,[Vector2(9.5,0),Vector2(9.5,.45),Vector2(8.9,.7),Vector2(8.9,1.1)])
  skin.part="plaster";Parts.kili_round(skin,Vector3.ZERO,[Vector2(8.2,1.1),Vector2(8.2,5.8)])
  skin.part="round_thatch";Parts.kili_round(skin,Vector3.ZERO,[Vector2(9.4,5.7),Vector2(7.5,7.1),Vector2(3.3,8.5)])
  skin.part="timber";Parts.kili_round(skin,Vector3.ZERO,[Vector2(3.2,8.4),Vector2(3.2,10.9)])
  skin.part="round_thatch";Parts.kili_round(skin,Vector3.ZERO,[Vector2(4.0,10.8),Vector2(2.8,12),Vector2(.15,12.9)])
  for i in 8:
   var n=Vector3(cos(i*TAU/8),0,sin(i*TAU/8))
   window(skin,n*8.22+Vector3.UP*3.7,n,2.0)
   window(skin,n*3.25+Vector3.UP*9.6,n,1.8)
   skin.part="timber"
   var corner=Vector3(cos((i+.5)*TAU/8),0,sin((i+.5)*TAU/8))
   bar(skin,corner*8.25+Vector3.UP*1.1,corner*8.25+Vector3.UP*5.7,.24)
   bar(skin,n*7.7+Vector3.UP*5.25,n*9.2+Vector3.UP*5.7,.20)
   bar(skin,corner*3.25+Vector3.UP*8.4,corner*3.25+Vector3.UP*10.9,.20)
  panel(skin,Vector3(-8.25,2.8,0),Vector3.LEFT,"door",3.4)
 else:
  var il=serial in [11272,11273,11275]
  var h={11272:3.3,11273:3.3,11275:3.5,11279:4.4,11281:3.6,11284:8.0,11285:4.0,11286:3.8,11106:4.4}[serial]
  var rise={11272:5.4,11273:5.6,11275:5.4,11279:5.5,11281:5.7,11284:5.8,11285:6.4,11286:5.5,11106:6.1}[serial]
  var along_x=w>=d and serial!=11285 or serial==11286
  var roof="thatch" if il else "pink_roof" if serial in [11106,11286] else "slate_roof"
  var doors=[[Vector3.BACK,0.0]] if serial in [11275,11279] else [[Vector3.LEFT,3.0 if serial==11272 else -1.5]]
  if serial==11284:doors=[[Vector3.BACK,-7.5],[Vector3.BACK,10.5]]
  var bottom=1.8 if serial==11284 else 0.0
  var plaster="blue_plaster" if serial==11272 else "plaster" if il else "woodwall"
  walls(skin,w,d,h,doors,Vector3.ZERO,bottom,plaster)
  pitched(skin,w+1.0,d+1.0,h,rise,along_x,roof,Vector3.ZERO,plaster)
  if il:il_crest(skin,w,d,h,rise,along_x,serial)
  skin.part="trim"
  if along_x:skin.box(AABB(Vector3(-w*.5,h+rise,-.13),Vector3(w,.22,.26)))
  else:skin.box(AABB(Vector3(-.13,h+rise,-d*.5),Vector3(.26,.22,d)))
  var count_=2 if serial in [11272,11275,11106] else 1 if serial in [11273,11284] else 0
  for side in [-1,1]:
   for i in count_:
    var station=(i-(count_-1)*.5)*.43
    var normal=Vector3(0,0,side) if along_x else Vector3(side,0,0)
    var at=Vector3(station*w,h+rise*.30,side*d*.29) if along_x else Vector3(side*w*.29,h+rise*.30,station*d)
    dormer(skin,at,along_x,normal,roof,3.7 if serial==11273 else 2.5)
  if serial in [11279,11281,11284]:
   skin.part="stone"
   for side in ([0] if serial==11281 else [-1,1]):
    for position in [-.26,.26]:
     var at=Vector3(position*w,h+rise*.66,side*d*.13) if along_x else Vector3(side*w*.13,h+rise*.66,position*d)
     skin.box(AABB(at-Vector3(.55,0,.55),Vector3(1.1,2.2,1.1)))
     skin.box(AABB(at+Vector3(-.72,2.05,-.72),Vector3(1.44,.25,1.44)))
     skin.part="flue_dark"
     skin.box(AABB(at+Vector3(-.43,2.295,-.43),Vector3(.86,.012,.86)))
     skin.part="stone"
     for rim in [-1,1]:
      skin.box(AABB(at+Vector3(rim*.58-.13,2.28,-.72),Vector3(.26,.20,1.44)))
      skin.box(AABB(at+Vector3(-.45,2.28,rim*.58-.13),Vector3(.90,.20,.26)))
     if serial==11281:
      skin.part="timber"
      for x in [-.34,.34]:Parts.kili_round(skin,at+Vector3(x,2.22,0),[Vector2(.22,0),Vector2(.22,.80),Vector2(.27,.87),Vector2(.17,.87),Vector2(.17,.40)])
      skin.part="stone"
  if serial==11275:
   skin.part="canopy"
   skin.quad(Vector3(-w*.30,2.6,d*.5+3),Vector3(-w*.30,3.7,d*.5),Vector3(w*.30,3.7,d*.5),Vector3(w*.30,2.6,d*.5+3))
   skin.part="timber"
   for x in [-w*.30,w*.30]:skin.box(AABB(Vector3(x-.10,0,d*.5+2.9),Vector3(.20,2.6,.20)))
  if serial in [11106,11285,11279,11281]:
   var end=serial in [11279,11281]
   var side=Vector3.BACK if end else Vector3.LEFT
   var at=side*(d*.5+1.3 if end else w*.5+1.3)
   if serial==11281:at.x=w*.17
   var span=Vector3(4,.30,3) if end else Vector3(3,.30,4)
   skin.part="timber";skin.box(AABB(at-Vector3(span.x*.5,0,span.z*.5),span))
   for position in [-1.75,1.75]:
    var post=Vector3(position,0,1.2) if end else Vector3(-1.2,0,position)
    skin.box(AABB(at+post-Vector3(.09,0,.09),Vector3(.18,3.3,.18)))
   pitched(skin,4.8 if end else 3.8,3.8 if end else 4.8,3.3,1.2,end,roof,at,"woodwall")
   if serial in [11281,11285]:
    for flank in [-1,1]:railing(skin,at+(Vector3.RIGHT*1.8*flank if end else Vector3.BACK*1.8*flank),Vector3.BACK if end else Vector3.RIGHT,2.5)
   if serial==11285:
    panel(skin,at+Vector3(-1.95,3.2,0),Vector3.LEFT,"pub_sign",4.7)
    for flank in [-1,1]:railing(skin,at+Vector3(-1.35,0,flank*1.25),Vector3.BACK,1.0)
  if serial==11285:
   skin.part="timber"
   for side in [-1,1]:Parts.kili_round(skin,Vector3(0,h+rise-.3,side*d*.5),[Vector2(.11,0),Vector2(.11,1.6),Vector2(.18,1.65),Vector2(0,2.0)])
  if serial==11284:
   panel(skin,Vector3(0,5.8,d*.5+.23),Vector3.BACK,"equipment_sign",3.0)
   skin.part="timber"
   for x in [-w*.46,-w*.22,0,w*.22,w*.46]:skin.box(AABB(Vector3(x-.18,0,d*.5-.4),Vector3(.36,bottom,.36)))
   for door in doors:
    for step in 6:skin.box(AABB(Vector3(door[1]-1.6,0,d*.5+step*.48),Vector3(3.2,bottom*(1-step/6.0),.51)))
    for side in [-1,1]:
     bar(skin,Vector3(door[1]+side*1.65,bottom+.7,d*.5),Vector3(door[1]+side*1.65,.7,d*.5+2.9),.13)
  if serial==11286:
   var at=Vector3(-w*.23,h+rise*.67,0)
   skin.part="timber"
   for x in [-.8,.8]:
    for z in [-.8,.8]:skin.box(AABB(at+Vector3(x-.08,0,z-.08),Vector3(.16,2.8,.16)))
   pitched(skin,2.5,2.5,at.y+2.8,1.0,true,roof,Vector3(at.x,0,at.z))
   skin.part="trim";Parts.kili_round(skin,at+Vector3.UP*.8,[Vector2(.55,0),Vector2(.42,.6),Vector2(.19,.8)])
  if serial==11106:
   var at=Vector3(-w*.5-1.1,0,d*.24)
   skin.part="timber"
   skin.box(AABB(at+Vector3(-.75,.85,-1.8),Vector3(1.5,.15,3.6)))
   for side in [-1,1]:
    skin.box(AABB(at+Vector3(-.83,.95,side*1.8-.08),Vector3(1.66,.25,.16)))
    skin.box(AABB(at+Vector3(side*.75-.08,.95,-1.8),Vector3(.16,.25,3.6)))
    for end in [-1,1]:skin.box(AABB(at+Vector3(side*.58-.08,0,end*1.5-.08),Vector3(.16,.90,.16)))
   for i in 18:
    skin.part=["fruit_orange","fruit_green","fruit_yellow"][i/6]
    Parts.kili_round(skin,at+Vector3((i%2-.5)*.48,1.0,(i/2-4)*.36),[Vector2(.11,0),Vector2(.25,.12),Vector2(.18,.38),Vector2(.02,.44)])
 var mesh=skin.finish();meshes[serial]=mesh
 return mesh
