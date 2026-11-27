extends RefCounted
## Final source-specific exteriors. Saved marker signatures protect edited maps.
const Proportions=preload("res://scripts/forest/forest_falan_proportions.gd")
const Houses=preload("res://scripts/forest/forest_falan_houses.gd")
const Turned=preload("res://scripts/forest/forest_falan_magic_shop.gd")
const Workshop=preload("res://scripts/forest/forest_falan_workshop.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
# graphic, saved kind/rotation/scale, archive center/footprint, wall height, front yaw, room
const SPECS={
 Vector2i(-28,-23):[10300,"falan_shop",0,.92,Vector2(-168,-136.5),Vector2(21,12),8.0,0.0,1031,7.5],
 Vector2i(-4,18):[10606,"falan_townhouse",90,.92,Vector2(-22.5,103.5),Vector2(18,24),9.0,PI*.5,1081,10.5],
 Vector2i(-50,24):[10311,"falan_townhouse",90,.92,Vector2(-298.5,141),Vector2(18,21),10.0,PI*.5,1183,10.5],
 Vector2i(-35,-44):[10312,"falan_townhouse",0,.92,Vector2(-210,-267),Vector2(21,15),10.5,0.0,1154,12.0],
 Vector2i(-49,30):[10313,"falan_townhouse",0,.92,Vector2(-303,189),Vector2(15,21),15.0,PI*.5,1540,9.0],
 Vector2i(20,-8):[10314,"falan_townhouse",180,.92,Vector2(109.5,-54),Vector2(18,27),18.0,PI*.5,1541,10.5],
}
const RETIRED=Vector2i(-49,-16)
static var meshes:Dictionary={}

static func spec(model,anchor)->Array:
 var row:Array=SPECS.get(anchor,[])
 if row.is_empty():return []
 var item:Dictionary=model.props.get(anchor,{})
 if item.get("kind","")!=row[1] or item.get("rotation",-1)!=row[2] or not is_equal_approx(float(item.get("scale",0)),row[3]) or model.scenery_heights.get(anchor,0)!=0:return []
 return row

static func retired(model,anchor)->bool:
 if not anchor is Vector2i or anchor!=RETIRED:return false
 var item:Dictionary=model.props.get(anchor,{})
 return item.get("kind","")=="falan_townhouse" and item.get("rotation",-1)==0 and is_equal_approx(float(item.get("scale",0)),.92) and model.scenery_heights.get(anchor,0)==0

static func bounds(anchor:Vector2i,row:Array)->AABB:
 var p:Vector2=row[4];var size_:Vector2=row[5]
 return AABB(Vector3(p.x-anchor.x*6-size_.x*.5,0,p.y-anchor.y*6-size_.y*.5),Vector3(size_.x,Proportions.height("special_%d"%row[0],row[6]+8),size_.y))

static func build(parent:Node3D,model,row:Array):
 var node=MeshInstance3D.new();node.name="RecoveredFalanExterior%d"%row[0];node.mesh=prepare(row)
 var p:Vector2=row[4];node.position=Vector3(p.x,model.surface_height(p.x,p.y),p.y);node.rotation.y=row[7]
 node.set_meta("original_graphic",row[0]);parent.add_child(node)

static func prepare(row:Array)->Mesh:
 var serial:int=row[0]
 if meshes.has(serial):return meshes[serial]
 var skin=Houses.SourceMesh.new([],Houses.Atlas,.045);skin.tiles=Houses.Data.TILES
 var dims:Vector2=row[5]
 if row[7]!=0:dims=Vector2(dims.y,dims.x)
 var w=dims.x*.5-1.0;var d=dims.y*.5-1.0;var h:float=row[6]
 skin.part="villa_stone" if serial in [10311,10312,10313] else "stone"
 if serial in [10311,10312,10313]:
  var side=1 if serial==10312 else -1
  # The native kiln occupies a recessed corner instead of disappearing inside a solid box.
  var cut=3.8;var lower=6.2
  skin.box(AABB(Vector3(-w+cut if side<0 else -w,0,-d),Vector3(w*2-cut,lower,d*2)))
  skin.box(AABB(Vector3(-w if side<0 else w-cut,0,-d),Vector3(cut,lower,d*2-cut)))
  skin.box(AABB(Vector3(-w,lower,-d),Vector3(w*2,h-lower,d*2)))
 else:skin.box(AABB(Vector3(-w,0,-d),Vector3(w*2,h,d*2)))
 skin.part="special_brick";skin.box(AABB(Vector3(-w-.02,0,-d-.02),Vector3(w*2+.04,3.0 if serial==10300 else 1.6,d*2+.04)))
 skin.part="trim"
 for y in [1.6,h*.5,h-.25]:skin.box(AABB(Vector3(-w-.04,y,-d-.04),Vector3(w*2+.08,.18,d*2+.08)))
 skin.part="trim"
 for side_x in [-1,1]:
  for side_z in [-1,1]:
   for course in ceili(h/.8):
    var y=course*.8
    skin.box(AABB(Vector3(side_x*w-.23,y,side_z*d-.55),Vector3(.46,.25,1.1)))
    skin.box(AABB(Vector3(side_x*w-.55,y,side_z*d-.23),Vector3(1.1,.25,.46)))
 var window="10300_window" if serial==10300 else "10606_window" if serial==10606 else str(serial)+"_window"
 var levels=1 if serial==10300 else 4 if serial==10314 else 3 if serial==10313 else 2
 for normal:Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
  var tangent=Vector3.UP.cross(normal)
  var face=normal*(w+.045 if absf(normal.x)>.5 else d+.045)
  var span=d if absf(normal.x)>.5 else w
  for x in [-.55,.55]:
   for level in levels:
    framed_window(skin,face+tangent*x*span+Vector3.UP*(2.8+level*(h-5.6)/maxi(1,levels-1)),tangent,window,minf(4.6,span*.90))
 entrance(skin,w,d,serial,row[9])
 if serial in [10311,10312,10313,10314]:
  # A projecting timber arch frames the existing source doorway; it adds no route.
  skin.part="10003_wood"
  for side in [-1,1]:
   skin.box(AABB(Vector3(side*1.85-.20,0,d+.30),Vector3(.4,4.0,.5)))
   for y in [.1,.6,3.8]:skin.box(AABB(Vector3(side*1.85-.29,y,d+.18),Vector3(.58,.22,.74)))
  for i in 16:
   var a=i*PI/16;var b=(i+1)*PI/16
   skin.quad(Vector3(cos(b)*1.65,3.6+sin(b)*1.5,d+.83),Vector3(cos(b)*2.05,3.6+sin(b)*1.85,d+.83),Vector3(cos(a)*2.05,3.6+sin(a)*1.85,d+.83),Vector3(cos(a)*1.65,3.6+sin(a)*1.5,d+.83))
 if serial==10300:apothecary(skin,w,d,h)
 elif serial==10606:fortified(skin,w,d,h)
 elif serial==10314:tall_house(skin,w,d,h)
 else:villa(skin,w,d,h,serial)
 var result=skin.finish()
 var paint=result.surface_get_material(0).duplicate();paint.set_shader_parameter("original_palette",false);result.surface_set_material(0,paint)
 result=Houses.surface_mesh(result)
 result=Proportions.fitted(result,"special_%d"%serial)
 meshes[serial]=result
 return result

static func entrance(skin,w:float,d:float,serial:int,distance:float):
 var feature="10606_gate" if serial==10606 else "door"
 Houses.Village.detail(skin,Vector3(0,2.6,d+.05),Vector3.RIGHT,feature,5.2)
 skin.part="10003_wood"
 for side in [-1,1]:
  skin.box(AABB(Vector3(side*1.75-.16,0,d+.05),Vector3(.32,4.5,.32)))
  skin.part="trim";skin.box(AABB(Vector3(side*1.75-.3,.1,d-.05),Vector3(.6,.4,.6)));skin.part="10003_wood"
 for i in 12:
  var a=float(i)*PI/12;var b=float(i+1)*PI/12
  skin.quad(Vector3(cos(b)*1.55,3.7+sin(b)*1.55,d+.35),Vector3(cos(b)*1.9,3.7+sin(b)*1.9,d+.35),Vector3(cos(a)*1.9,3.7+sin(a)*1.9,d+.35),Vector3(cos(a)*1.55,3.7+sin(a)*1.55,d+.35))
 Workshop.roof(skin,Vector3(0,5.35,d+.55),2.25,1.0,1.2,"10300_roof" if serial==10300 else "blue_roof")
 skin.part="stone"
 for i in maxi(3,ceili((distance-d-.5)/.55)):skin.box(AABB(Vector3(-1.65,i*.14,distance-.65-i*.55),Vector3(3.3,.14,.6)))

static func curved_roof(skin,p:Vector3,w:float,d:float,height:float,paint:String):
 var profile=[]
 for side in [-1,1]:
  var points=Shapes.BARREL.duplicate()
  if side>0:points.reverse()
  for v:Vector2 in points:
   var at=Vector2(side*v.x*d,v.y*height)
   if profile.is_empty() or at!=profile[-1]:profile.append(at)
 skin.part=paint
 for i in profile.size()-1:
  var a:Vector2=profile[i];var b:Vector2=profile[i+1]
  skin.quad(p+Vector3(-w,a.y,a.x),p+Vector3(w,a.y,a.x),p+Vector3(w,b.y,b.x),p+Vector3(-w,b.y,b.x))
 skin.part="stone"
 for side in [-1,1]:
  for i in profile.size()-1:
   var a:Vector2=profile[i];var b:Vector2=profile[i+1]
   var first=p+Vector3(side*w,a.y,a.x);var next=p+Vector3(side*w,b.y,b.x)
   var low=p+Vector3(side*w,0,0)
   if side>0:skin.quad(next,first,low,low)
   else:skin.quad(first,next,low,low)
 for side in [-1,1]:
  for i in profile.size()-1:
   var a:Vector2=profile[i];var b:Vector2=profile[i+1]
   stroke(skin,p+Vector3(side*w,a.y,a.x),p+Vector3(side*w,b.y,b.x),.26,"trim")

static func apothecary(skin,w:float,d:float,h:float):
 curved_roof(skin,Vector3(0,h,0),w+.6,d+.6,4.8,"10300_roof")
 for x in [-w*.72,w*.72]:
  Turned.lathe(skin,Vector3(x,h+4.4,0),[Vector2(2.5,0),Vector2(3.0,.6),Vector2(2.1,1.6),Vector2(.1,2.0)],"10300_roof")
  Turned.lathe(skin,Vector3(x,h+6.35,0),[Vector2(.18,0),Vector2(0,.45)],"trim")
 var emblem=Vector3(0,6.8,d+1.02)
 skin.panel(emblem-Vector3(4,3,0),emblem+Vector3(-4,3,0),emblem+Vector3(4,3,0),emblem+Vector3(4,-3,0),"10300_emblem")
 for side in [-1,1]:
  skin.part="magic_stone"
  var outline=PackedVector2Array([Vector2(-d,0)])
  for v:Vector2 in Shapes.CROWN:outline.append(Vector2(v.x*d/7.35,v.y*.98))
  outline.append(Vector2(d,0))
  var indices=Geometry2D.triangulate_polygon(outline)
  for i in range(0,indices.size(),3):
   var points=[]
   for j in 3:
    var v=outline[indices[i+j]];points.append(Vector3(side*(w+.65),h+v.y,v.x))
   if (points[2]-points[0]).cross(points[1]-points[0]).x*side<0:skin.quad(points[2],points[1],points[0],points[0])
   else:skin.quad(points[0],points[1],points[2],points[2])
  Houses.Village.detail(skin,Vector3(side*(w+.69),h+1.7,0),Vector3.FORWARD*side,"10300_scroll",minf(d*1.5,6.0))
  var last=Vector3.ZERO
  for i in Shapes.CROWN.size():
   var v:Vector2=Shapes.CROWN[i]
   var point=Vector3(side*(w+.83),h+v.y*.98,v.x*d/7.35)
   if i>0:stroke(skin,last,point,.13,"trim")
   last=point
  for direction in [-1,1]:
   var center=Vector3(side*(w+.87),h+2.4,direction*d*.4)
   var previous=center+Vector3(0,0,.8)
   for i in range(1,25):
    var t=float(i)/24;var angle=t*TAU*1.15;var radius=lerpf(.8,.08,t)
    var point=center+Vector3(0,sin(angle)*radius,cos(angle)*radius)
    stroke(skin,previous,point,.085,"trim");previous=point

static func fortified(skin,w:float,d:float,h:float):
 curved_roof(skin,Vector3(0,h,-d*.15),w-.7,d*.7,3.7,"blue_roof")
 Workshop.roof(skin,Vector3(0,h-1.0,d*.3),w*.5,d*.8,3.3)
 for x in [-w+.8,w-.8]:
  for z in [-d+.8,d-.8]:
   skin.part="stone";skin.box(AABB(Vector3(x-.85,0,z-.85),Vector3(1.7,h+1.0,1.7)))
   for y in [.3,3.0,6.0,h+.8]:
    skin.part="trim";skin.box(AABB(Vector3(x-.95,y,z-.95),Vector3(1.9,.22,1.9)))
   for a in [-.7,.7]:
    for b in [-.7,.7]:skin.box(AABB(Vector3(x+a-.22,h+1.0,z+b-.22),Vector3(.44,.6,.44)))
 for side in [-1,1]:
  skin.part="trim";skin.box(AABB(Vector3(-w,h-.05,side*(d-.35)-.3),Vector3(w*2,.4,.6)))
  for i in 10:
   skin.part="trim";skin.box(AABB(Vector3(lerpf(-w+.5,w-.5,float(i)/9)-.25,h+.15,side*(d-.35)-.25),Vector3(.5,.7,.5)))
  for x in [-w*.7,w*.7]:
   var p=Vector3(x,0,side*(d+.65))
   Turned.lathe(skin,p,[Vector2(1.8,0),Vector2(1.8,6.0)],"stone")
   Turned.lathe(skin,p,[Vector2(2.1,6.0),Vector2(1.3,7.4),Vector2(0,8.6)],"blue_roof")

static func rail(skin,w:float,d:float,h:float):
 skin.part="trim"
 for side in [-1,1]:
  skin.box(AABB(Vector3(-w,h,side*d-.12),Vector3(w*2,.18,.24)))
  skin.box(AABB(Vector3(-w,h+1.25,side*d-.12),Vector3(w*2,.18,.24)))
  for i in 10:skin.box(AABB(Vector3(lerpf(-w,w,float(i)/9)-.07,h,side*d-.07),Vector3(.14,1.4,.14)))
  skin.box(AABB(Vector3(side*w-.12,h,-d),Vector3(.24,.18,d*2)))
  skin.box(AABB(Vector3(side*w-.12,h+1.25,-d),Vector3(.24,.18,d*2)))
  for i in 9:skin.box(AABB(Vector3(side*w-.07,h,lerpf(-d,d,float(i)/8)-.07),Vector3(.14,1.4,.14)))

static func villa(skin,w:float,d:float,h:float,serial:int):
 skin.part="stone";skin.box(AABB(Vector3(-w-.1,h,-d-.1),Vector3(w*2+.2,.25,d*2+.2)))
 # The source terraces have a solid coping below their open railing.
 skin.part="trim"
 for side in [-1,1]:
  skin.box(AABB(Vector3(-w,h+.22,side*d-.16),Vector3(w*2,.38,.32)))
  skin.box(AABB(Vector3(side*w-.16,h+.22,-d),Vector3(.32,.38,d*2)))
 if serial==10311:
  rail(skin,w-.15,d-.15,h+.25)
  Turned.lathe(skin,Vector3(0,4.2,d+.1),[Vector2(3.4,0),Vector2(3.4,h-4.2),Vector2(3.55,h-4.05)],"villa_stone")
  skin.part="stone"
  for i in 32:
   var a=i*TAU/32;var b=(i+1)*TAU/32
   var center=Vector3(0,h+.25,d+.1)
   skin.quad(center,center+Vector3(cos(a)*3.55,0,sin(a)*3.55),center+Vector3(cos(b)*3.55,0,sin(b)*3.55),center)
  skin.part="trim"
  for i in 13:
   var a=float(i)*PI/12
   var p=Vector3(cos(a)*3.45,h+.25,d+.1+sin(a)*3.45)
   skin.box(AABB(p-Vector3(.075,0,.075),Vector3(.15,1.4,.15)))
  for angle in [PI/6,PI/2,PI*5/6]:
   var normal=Vector3(cos(angle),0,sin(angle))
   framed_window(skin,Vector3(0,6.9,d+.1)+normal*3.58,Vector3.UP.cross(normal),"10312_window",3.7)
  # Blue brows on the rounded bay and side windows are visible in original 10311.
  for x in [-w*.55,w*.55]:window_hood(skin,Vector3(x,8.4,d+.12),Vector3.RIGHT,2.45)
  for side in [-1,1]:
   for z in [-d*.55,d*.55]:window_hood(skin,Vector3(side*(w+.12),8.1,z),Vector3.FORWARD*side,2.45)
  # Both original rows recede along the same terrace axis.
  skin.part="10003_wood"
  for z in [-d*.34,d*.34]:
   for x in [-w*.4,w*.4]:skin.box(AABB(Vector3(x-.08,h+.3,z-.08),Vector3(.16,2.8,.16)))
   skin.box(AABB(Vector3(-w*.4,h+3.0,z-.06),Vector3(w*.8,.12,.12)))
  terrace_cloth(skin,Vector3(w*.26,h+3.0,d*.34+.03),Vector3.RIGHT,Vector2(6.0,2.8),"10311_cloth")
  terrace_cloth(skin,Vector3(-w*.18,h+3.0,d*.34+.03),Vector3.RIGHT,Vector2(3.2,2.7),"10311_trousers")
  for row in [[-w*.22,"10311_stripes",Vector2(3.7,2.8)],[0.0,"10311_socks",Vector2(2.3,1.8)],[w*.22,"10311_shirt",Vector2(3.4,2.8)]]:
   terrace_cloth(skin,Vector3(row[0],h+3.0,-d*.34+.03),Vector3.RIGHT,row[2],row[1])
 else:
  rail(skin,w-.2,d-.2,h+.25)
  curved_roof(skin,Vector3(0,h+.25,d*.25),w*.8,d*.47,4.6,"blue_roof")
  Houses.Village.detail(skin,Vector3(0,h+1.3,d*.73+.03),Vector3.RIGHT,"10003_window",2.8)
  skin.part="trim"
  for side in [-1,1]:
   for contour in [Vector2(-1,0),Vector2(-.91,.17),Vector2(-.62,.65),Vector2(0,1),Vector2(.62,.65),Vector2(.91,.17),Vector2(1,0)]:
    skin.box(AABB(Vector3(side*w*.8-.15,h+.25+contour.y*4.6,d*.25+contour.x*d*.47-.2),Vector3(.3,.35,.4)))
 for side in [-1,1]:
  var p=Vector3(side*(w-.65),h-2.0,-side*(d-.65))
  chimney_stack(skin,p,1.65,1.65,6.5)
  skin.part="trim"
  for x in [-.65,.65]:
   for z in [-.65,.65]:skin.box(AABB(p+Vector3(x-.20,6.5,z-.20),Vector3(.4,.65,.4)))
 var kiln_side=1 if serial==10312 else -1
 var kiln=Vector3(kiln_side*(w-1.3),0,d-1.1)
 Turned.lathe(skin,kiln,[Vector2(2.3,0),Vector2(2.6,.7),Vector2(2.3,2.0),Vector2(1.8,3.3),Vector2(1.1,5.0),Vector2(.7,6.2),Vector2(0,6.5)],"trim")
 for station:Vector2 in [Vector2(2.5,1.5),Vector2(1.82,3.4),Vector2(1.15,5.0)]:
  for i in 8:
   var angle=i*TAU/8;var normal=Vector3(cos(angle),0,sin(angle))
   var at=kiln+normal*station.x+Vector3.UP*station.y;var across=Vector3.UP.cross(normal)*.20
   skin.part="10003_wood";skin.quad(at-across-Vector3.UP*.20,at-across+Vector3.UP*.20,at+across+Vector3.UP*.20,at+across-Vector3.UP*.20)
 for side in [-1,1]:
  Houses.Village.detail(skin,Vector3(side*(w+.06),3.6,0),Vector3.FORWARD*side,"10312_vines",5.2)
 if serial==10313:
  skin.part="villa_stone";skin.box(AABB(Vector3(-2.65,h*.46,d-.10),Vector3(5.3,h*.47,1.4)))
  for y in [h*.61,h*.80]:framed_window(skin,Vector3(0,y,d+1.34),Vector3.RIGHT,"10313_window",4.1)
  skin.part="stone";skin.box(AABB(Vector3(-2.7,h*.48,d+.05),Vector3(5.4,.3,1.90)))
  for x in [-2.5,0,2.5]:
   skin.box(AABB(Vector3(x-.28,h*.48,d+1.68),Vector3(.56,1.55,.45)))
   skin.box(AABB(Vector3(x-.38,h*.48+1.35,d+1.56),Vector3(.76,.3,.68)))
  skin.box(AABB(Vector3(-2.7,h*.48+1.25,d+1.58),Vector3(5.4,.3,.4)))
  for side in [-1,1]:skin.box(AABB(Vector3(side*2.5-.13,h*.48+1.25,d+.1),Vector3(.26,.3,1.7)))
  window_hood(skin,Vector3(0,5.95,d+1.0),Vector3.RIGHT,2.9)
  Houses.native_panel(skin,Vector3(0,6.5,d+1.96),Vector3.RIGHT,Vector2(3.36,2.1),"10313_emblem")

static func terrace_cloth(skin,at:Vector3,tangent:Vector3,size_:Vector2,feature:String):
 # Align the visible native fabric edge with its line, excluding transparent tile margins.
 at.y-=(.5-float(Houses.Data.CLOTH_TOP[feature]))*size_.y
 for facing in [-1,1]:Houses.native_panel(skin,at,tangent*facing,size_,feature)

static func tall_house(skin,w:float,d:float,h:float):
 for x in [-w*.65,0,w*.65]:
  Workshop.roof(skin,Vector3(x,h,0),w*.37,d+.3,5.7 if x==0 else 4.2)
  framed_window(skin,Vector3(x,h+1.9,d+.35),Vector3.RIGHT,"10314_window",3.5)
 for side in [-1,1]:
  for end in [-1,1]:
   var p=Vector3(side*(w-.2),0,end*(d-.2))
   Turned.lathe(skin,p,[Vector2(1.35,0),Vector2(1.35,h+1.0)],"stone")
   for y in [1.5,6.0,10.5,15.0]:Houses.Village.detail(skin,p+Vector3(0,y,end*1.04),Vector3.RIGHT*end,"10314_window",2.4)
   Turned.lathe(skin,p,[Vector2(1.50,h+1.0),Vector2(1.2,h+2.7),Vector2(.4,h+4.5),Vector2(0,h+4.9)],"blue_roof")
  for z in [-d*.6,d*.35]:chimney_stack(skin,Vector3(side*w*.55,h+3.5,z),1.0,1.1,4.0)
 chimney_stack(skin,Vector3(-w+.1,0,d*.2),1.5,1.6,h*.75)
 # Stacked arched bays, rather than thin horizontal ledges, define the source frontage.
 for y in [7.2,12.5]:
  window_hood(skin,Vector3(0,y,d+.2),Vector3.RIGHT,w*.48)
  skin.part="villa_stone";skin.box(AABB(Vector3(-2.2,y-3.9,d-.04),Vector3(4.4,3.5,.64)))
  for x in [-1.1,1.1]:framed_window(skin,Vector3(x,y-2.0,d+.65),Vector3.RIGHT,"10314_window",2.6)
  skin.part="10003_wood"
  for x in [-2.35,2.35]:skin.box(AABB(Vector3(x-.18,y-4.0,d+.56),Vector3(.36,3.45,.34)))
  for i in 16:
   var a=i*PI/16;var b=(i+1)*PI/16
   var first=Vector3(cos(a)*2.25,y-1.0+sin(a)*1.55,d+.78)
   var next=Vector3(cos(b)*2.25,y-1.0+sin(b)*1.55,d+.78)
   stroke(skin,first,next,.18,"10003_wood")

static func window_hood(skin,center:Vector3,tangent:Vector3,span:float):
 var normal=tangent.cross(Vector3.UP)
 var contour=[Vector2(-span,.0),Vector2(-span*.86,.28),Vector2(-span*.48,.90),Vector2(0,1.25),Vector2(span*.48,.90),Vector2(span*.86,.28),Vector2(span,0)]
 for i in contour.size()-1:
  var a:Vector2=contour[i];var b:Vector2=contour[i+1]
  var front_a=center+tangent*a.x+Vector3.UP*a.y+normal*.9
  var front_b=center+tangent*b.x+Vector3.UP*b.y+normal*.9
  var back_a=front_a-normal*1.05;var back_b=front_b-normal*1.05
  skin.part="blue_roof";skin.quad(front_a,back_a,back_b,front_b)
  skin.quad(front_b-Vector3.UP*.14,back_b-Vector3.UP*.14,back_a-Vector3.UP*.14,front_a-Vector3.UP*.14)
  skin.part="10003_wood";skin.quad(front_a-Vector3.UP*.14,front_a,front_b,front_b-Vector3.UP*.14)
  if i==0:skin.quad(back_a-Vector3.UP*.14,back_a,front_a,front_a-Vector3.UP*.14)
  if i==contour.size()-2:skin.quad(front_b-Vector3.UP*.14,front_b,back_b,back_b-Vector3.UP*.14)

static func chimney_stack(skin,p:Vector3,width:float,depth:float,height:float):
 skin.part="stone";skin.box(AABB(p-Vector3(width*.5,0,depth*.5),Vector3(width,height,depth)))
 skin.part="10003_wood";skin.box(AABB(p+Vector3(-width*.35,height+.01,-depth*.35),Vector3(width*.7,.02,depth*.7)))
 skin.part="trim"
 for side in [-1,1]:
  skin.box(AABB(p+Vector3(side*width*.5-.12,height-.15,-depth*.5-.15),Vector3(.24,.45,depth+.3)))
  skin.box(AABB(p+Vector3(-width*.5-.15,height-.15,side*depth*.5-.12),Vector3(width+.3,.45,.24)))

# Atlas-aware coping shares the building surface instead of adding a plain-material rod mesh.
static func stroke(skin,a:Vector3,b:Vector3,radius:float,paint:String):
 var direction=(b-a).normalized()
 var tangent=direction.cross(Vector3.UP)
 if tangent.length_squared()<.001:tangent=Vector3.RIGHT
 tangent=tangent.normalized();var across=direction.cross(tangent).normalized()
 skin.part=paint
 for i in 8:
  var t=float(i)*TAU/8;var u=float(i+1)*TAU/8
  var first=(cos(t)*tangent+sin(t)*across)*radius
  var next=(cos(u)*tangent+sin(u)*across)*radius
  skin.quad(a+first,b+first,b+next,a+next)

static func framed_window(skin,center:Vector3,tangent:Vector3,paint:String,span:float):
 var right=tangent*span*.575;var up=Vector3.UP*span*.375
 skin.panel(center-right-up,center-right+up,center+right+up,center+right-up,paint)
 var normal=tangent.cross(Vector3.UP);var half_w=span*.26*1.15;var half_h=span*.47*.75
 skin.part="trim"
 for side in [-1,1]:
  for vertical in [false,true]:
   var at=center+normal*.07+(tangent*side*half_w if vertical else Vector3.UP*side*half_h)
   var width=.09 if vertical else half_w*2+.09;var height=half_h*2 if vertical else .09
   var extent=Vector3(absf(tangent.x)*width+absf(normal.x)*.12,height,absf(tangent.z)*width+absf(normal.z)*.12)
   skin.box(AABB(at-extent*.5,extent))
