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
 skin.part="villa_stone" if serial in [10311,10312,10313] else "stone";skin.box(AABB(Vector3(-w,0,-d),Vector3(w*2,h,d*2)))
 skin.part="special_brick";skin.box(AABB(Vector3(-w-.02,0,-d-.02),Vector3(w*2+.04,1.6,d*2+.04)))
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
    framed_window(skin,face+tangent*x*span+Vector3.UP*(2.8+level*(h-5.6)/maxi(1,levels-1)),tangent,window,minf(3.3,span*.65))
 entrance(skin,w,d,serial,row[9])
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
 var profile=[Vector2(-d,0),Vector2(-d*.91,height*.17),Vector2(-d*.62,height*.65),Vector2(0,height),Vector2(d*.62,height*.65),Vector2(d*.91,height*.17),Vector2(d,0)]
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

static func apothecary(skin,w:float,d:float,h:float):
 curved_roof(skin,Vector3(0,h,0),w+.6,d+.6,4.8,"10300_roof")
 for x in [-w*.72,w*.72]:
  Turned.lathe(skin,Vector3(x,h+4.4,0),[Vector2(1.1,0),Vector2(1.3,.6),Vector2(.9,1.6),Vector2(.1,2.0)],"10300_roof")
  Turned.lathe(skin,Vector3(x,h+6.35,0),[Vector2(.18,0),Vector2(0,.45)],"trim")
 Houses.Village.detail(skin,Vector3(0,6.8,d+1.02),Vector3.RIGHT,"10300_emblem",4.6)
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
   var p=Vector3(x,0,side*(d+.15))
   Turned.lathe(skin,p,[Vector2(1.3,0),Vector2(1.3,6.0)],"stone")
   Turned.lathe(skin,p,[Vector2(1.5,6.0),Vector2(.9,7.4),Vector2(0,8.6)],"blue_roof")

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
 if serial==10311:
  rail(skin,w-.15,d-.15,h+.25)
  Turned.lathe(skin,Vector3(0,4.2,d-.8),[Vector2(2.3,0),Vector2(2.3,h-4.2),Vector2(2.5,h-4.05)],"villa_stone")
  skin.part="trim"
  for i in 13:
   var a=float(i)*PI/12
   var p=Vector3(cos(a)*2.4,h+.25,d-.8+sin(a)*2.4)
   skin.box(AABB(p-Vector3(.075,0,.075),Vector3(.15,1.4,.15)))
  Houses.Village.detail(skin,Vector3(0,6.8,d+1.53),Vector3.RIGHT,"10311_window",3.2)
  skin.part="10003_wood"
  for x in [-w*.5,w*.5]:skin.box(AABB(Vector3(x-.08,h+.3,-.08),Vector3(.16,2.3,.16)))
  skin.box(AABB(Vector3(-w*.5,h+2.5,-.06),Vector3(w,.12,.12)))
  Houses.Village.detail(skin,Vector3(0,h+1.25,.1),Vector3.RIGHT,"10311_cloth",3.0)
 else:
  rail(skin,w-.2,d-.2,h+.25)
  curved_roof(skin,Vector3(0,h+.25,d*.25),w*.8,d*.47,4.6,"blue_roof")
  Houses.Village.detail(skin,Vector3(0,h+1.3,d*.73+.03),Vector3.RIGHT,"10003_window",2.8)
  skin.part="trim"
  for side in [-1,1]:
   for contour in [Vector2(-1,0),Vector2(-.91,.17),Vector2(-.62,.65),Vector2(0,1),Vector2(.62,.65),Vector2(.91,.17),Vector2(1,0)]:
    skin.box(AABB(Vector3(side*w*.8-.15,h+.25+contour.y*4.6,d*.25+contour.x*d*.47-.2),Vector3(.3,.35,.4)))
 for side in [-1,1]:
  var p=Vector3(side*(w-1),0,-d+1)
  skin.part="magic_stone";skin.box(AABB(p-Vector3(.6,0,.6),Vector3(1.2,h+3.0,1.2)))
  for x in [-.55,.55]:
   for z in [-.55,.55]:
    skin.part="trim";skin.box(AABB(p+Vector3(x-.18,h+3,z-.18),Vector3(.36,.5,.36)))
 Turned.lathe(skin,Vector3(-w+1.7,0,d-1.7),[Vector2(2.3,0),Vector2(2.4,.6),Vector2(1.8,2.8),Vector2(.7,6.2),Vector2(0,6.5)],"stone")
 for side in [-1,1]:
  Houses.Village.detail(skin,Vector3(side*(w+.06),3.6,0),Vector3.FORWARD*side,"10312_vines",5.2)
 if serial==10313:
  skin.part="stone";skin.box(AABB(Vector3(-2.7,h*.48,d+.05),Vector3(5.4,.3,.95)))
  for x in [-2.5,0,2.5]:skin.box(AABB(Vector3(x-.15,h*.48,d+.7),Vector3(.3,1.4,.3)))
  skin.box(AABB(Vector3(-2.7,h*.48+1.25,d+.55),Vector3(5.4,.2,.3)))
  Houses.Village.detail(skin,Vector3(0,6.5,d+.8),Vector3.RIGHT,"10313_emblem",2.7)

static func tall_house(skin,w:float,d:float,h:float):
 for x in [-w*.65,0,w*.65]:Workshop.roof(skin,Vector3(x,h,0),w*.37,d+.3,5.5)
 for side in [-1,1]:
  for end in [-1,1]:
   var p=Vector3(side*(w-.6),0,end*(d-.6))
   Turned.lathe(skin,p,[Vector2(1.0,0),Vector2(1.0,h+.4)],"stone")
   for y in [1.5,6.0,10.5,15.0]:Houses.Village.detail(skin,p+Vector3(0,y,end*1.04),Vector3.RIGHT*end,"10314_window",2.4)
   Turned.lathe(skin,p,[Vector2(1.25,h+.4),Vector2(.8,h+2.3),Vector2(0,h+3.8)],"blue_roof")
  for z in [-d*.6,d*.35]:chimney_stack(skin,Vector3(side*w*.55,h+3.5,z),1.0,1.1,4.0)
 chimney_stack(skin,Vector3(-w+.1,0,d*.2),1.5,1.6,h*.75)
 for y in [7.2,12.5]:Workshop.roof(skin,Vector3(0,y,d+.2),w*.48,1.1,1.2)

static func chimney_stack(skin,p:Vector3,width:float,depth:float,height:float):
 skin.part="magic_stone";skin.box(AABB(p-Vector3(width*.5,0,depth*.5),Vector3(width,height,depth)))
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
 Houses.Village.detail(skin,center,tangent,paint,span)
 var normal=tangent.cross(Vector3.UP);var half_w=span*.26;var half_h=span*.47
 skin.part="trim"
 for side in [-1,1]:
  for vertical in [false,true]:
   var at=center+normal*.07+(tangent*side*half_w if vertical else Vector3.UP*side*half_h)
   var width=.09 if vertical else half_w*2+.09;var height=half_h*2 if vertical else .09
   var extent=Vector3(absf(tangent.x)*width+absf(normal.x)*.12,height,absf(tangent.z)*width+absf(normal.z)*.12)
   skin.box(AABB(at-extent*.5,extent))
