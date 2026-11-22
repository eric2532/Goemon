extends RefCounted
## Solid interpretations of the curved roofs/stonework in original 10010/10607/10004 and urn 10403.
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
const BARREL=[Vector2(1,0),Vector2(.98,.12),Vector2(.93,.29),Vector2(.84,.49),Vector2(.70,.69),Vector2(.51,.85),Vector2(.28,.96),Vector2(0,1)]
const INN_ROOF=[Vector2(1,0),Vector2(.92,.07),Vector2(.82,.23),Vector2(.67,.48),Vector2(.47,.75),Vector2(.25,.94),Vector2(0,1)]
const LANCET=[Vector3(-.5,0,0),Vector3(-.5,.68,0),Vector3(-.42,.80,0),Vector3(-.24,.92,0),Vector3(0,1,0),Vector3(.24,.92,0),Vector3(.42,.80,0),Vector3(.5,.68,0),Vector3(.5,0,0)]
# Upper contour in the end-wall plane: scroll shoulders rise to a narrow center crest.
const CROWN=[Vector2(-7.35,1.10),Vector2(-6.95,1.10),Vector2(-6.60,1.20),Vector2(-6.40,1.43),
 Vector2(-6.38,1.76),Vector2(-6.43,2.10),Vector2(-6.36,2.48),Vector2(-6.12,2.86),
 Vector2(-5.72,3.13),Vector2(-5.19,3.28),Vector2(-4.51,3.32),Vector2(-3.78,3.33),
 Vector2(-3.14,3.44),Vector2(-2.62,3.67),Vector2(-2.22,4.02),Vector2(-1.98,4.46),
 Vector2(-1.88,4.85),Vector2(-1.88,5.20),Vector2(1.88,5.20),Vector2(1.88,4.85),
 Vector2(1.98,4.46),Vector2(2.22,4.02),Vector2(2.62,3.67),Vector2(3.14,3.44),
 Vector2(3.78,3.33),Vector2(4.51,3.32),Vector2(5.19,3.28),Vector2(5.72,3.13),
 Vector2(6.12,2.86),Vector2(6.36,2.48),Vector2(6.43,2.10),Vector2(6.38,1.76),
 Vector2(6.40,1.43),Vector2(6.60,1.20),Vector2(6.95,1.10),Vector2(7.35,1.10)]
static var bank_wall:Mesh
static var bank_coping:Mesh
static var bank_gallery:Mesh
static var bank_glass:Mesh
static var urn:Mesh
static var bank_frames:Dictionary={}

static func bank_frame(width:float,height:float)->Mesh:
 var key=Vector2(width,height)
 if bank_frames.has(key):return bank_frames[key]
 Parts.prepare_primitives()
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for band in 2:
  var size_=Vector2(width+.48-band*.20,height+.23-band*.10)
  var depth=.12+band*.10
  for i in LANCET.size()-1:
   var a:Vector3=LANCET[i]*Vector3(size_.x,size_.y,1)+Vector3.BACK*depth
   var b:Vector3=LANCET[i+1]*Vector3(size_.x,size_.y,1)+Vector3.BACK*depth
   Parts.rod(tool,a,b,.070 if band==0 else .045)
 Parts.block(tool,Vector3(0,height+.20,.17),Vector3(.32,.43,.31))
 for side in [-1,1]:
  for y in [.16,height*.64]:Parts.block(tool,Vector3(side*(width*.5+.18),y,.17),Vector3(.28,.18,.32))
 var result=tool.commit();bank_frames[key]=result
 return result

static func quad(tool:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
 for triangle in [[a,b,c],[a,c,d]]:
  var normal:Vector3=(triangle[2]-triangle[0]).cross(triangle[1]-triangle[0])
  if normal.length_squared()<.00000001:continue
  for p in triangle:tool.set_normal(normal.normalized());tool.add_vertex(p)

static func extrude(outline:PackedVector2Array,depth:float)->Mesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var area=0.0
 for i in outline.size():area+=outline[i].cross(outline[(i+1)%outline.size()])
 var indices=Geometry2D.triangulate_polygon(outline)
 assert(not indices.is_empty(),"The stone profile must remain a simple solid polygon")
 for i in range(0,indices.size(),3):
  var a=outline[indices[i]];var b=outline[indices[i+1]];var c=outline[indices[i+2]]
  if (b-a).cross(c-a)>0:var swap=b;b=c;c=swap
  for side in [-1,1]:
   for point in ([a,b,c] if side>0 else [c,b,a]):
    tool.set_normal(Vector3.BACK*side);tool.add_vertex(Vector3(point.x,point.y,side*depth*.5))
 for i in outline.size():
  var a=outline[i];var b=outline[(i+1)%outline.size()]
  if area>0:var swap=a;a=b;b=swap
  quad(tool,Vector3(a.x,a.y,depth*.5),Vector3(a.x,a.y,-depth*.5),Vector3(b.x,b.y,-depth*.5),Vector3(b.x,b.y,depth*.5))
 return tool.commit()

static func prepare_bank():
 if bank_wall!=null:return
 Parts.prepare_primitives()
 var outline=PackedVector2Array([Vector2(-7.35,0)])
 outline.append_array(PackedVector2Array(CROWN));outline.append(Vector2(7.35,0))
 bank_wall=extrude(outline,1.01)
 var coping=SurfaceTool.new();coping.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in CROWN.size()-1:
  var a:Vector2=CROWN[i];var b:Vector2=CROWN[i+1]
  Parts.rod(coping,Vector3(a.x,a.y,0),Vector3(b.x,b.y,0),.17)
 for side in [-1,1]:
  for row in [[1.88,5.20],[6.60,1.20]]:
   var p=Vector3(side*row[0],row[1],0)
   Parts.block(coping,p+Vector3.UP*.37,Vector3(.64,.74,.92))
   Parts.block(coping,p+Vector3.UP*.77,Vector3(.84,.17,1.05))
   Parts.oval(coping,p+Vector3.UP*.99,Vector3(.43,.36,.62))
  var last=Vector3(side*5.43,2.75,.61)
  for i in range(1,33):
   var t=float(i)/32
   var angle=t*TAU*1.15
   var radius=lerpf(.68,.07,t)
   var next=Vector3(side*(4.75+cos(angle)*radius),2.75+sin(angle)*radius,.61)
   Parts.rod(coping,last,next,.075);last=next
 bank_coping=coping.commit()
 var gallery=SurfaceTool.new();gallery.begin(Mesh.PRIMITIVE_TRIANGLES)
 var glass=SurfaceTool.new();glass.begin(Mesh.PRIMITIVE_TRIANGLES)
 Parts.block(glass,Vector3(0,11.05,.62),Vector3(11.65,2.25,.06))
 Parts.block(gallery,Vector3(0,11.64,.48),Vector3(12.2,3.88,.20))
 Parts.block(gallery,Vector3(0,9.70,.73),Vector3(12.2,.24,.94))
 for x in [-5.4,-2.7,0,2.7,5.4]:
  Parts.rod(gallery,Vector3(x,9.9,1.20),Vector3(x,12.25,1.20),.11)
  Parts.oval(gallery,Vector3(x,10.92,1.20),Vector3(.32,.75,.32))
  for y in [10.38,11.62]:Parts.rod(gallery,Vector3(x,y-.055,1.20),Vector3(x,y+.055,1.20),.20)
  for y in [9.95,10.18,12.13,12.30]:Parts.block(gallery,Vector3(x,y,1.20),Vector3(.37,.14,.38))
 var ring=TorusMesh.new();ring.inner_radius=.41;ring.outer_radius=.65;ring.rings=32;ring.ring_segments=8
 for x in [-4.05,-1.35,1.35,4.05]:
  gallery.append_from(ring,0,Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(x,12.91,.88)))
  glass.append_from(Parts.cylinder,0,Transform3D(Basis(Vector3.RIGHT,PI*.5).scaled_local(Vector3(.85,.08,.85)),Vector3(x,12.91,.83)))
 bank_gallery=gallery.commit();bank_glass=glass.commit()

static func bank_end(root:Node3D,edge:float,pale:Material,trim:Material,glass:Material):
 prepare_bank()
 var face=Node3D.new();face.name="RecoveredBankScrollGable";root.add_child(face)
 face.position=Vector3(edge,0,0);face.rotation.y=signf(edge)*PI*.5
 for row in [[bank_wall,pale,13.9,"scroll_wall"],[bank_coping,trim,13.9,"scroll_coping"],[bank_gallery,trim,0.0,"round_window_gallery"],[bank_glass,glass,0.0,"round_windows"]]:
  var node=Geo.mesh(face,row[0],Vector3.UP*row[2],row[1]);node.set_meta("falan_solid_detail",row[3])

static func urn_mesh()->Mesh:
 if urn!=null:return urn
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var profile=[Vector2(0,0),Vector2(.27,0),Vector2(.31,.05),Vector2(.31,.12),Vector2(.24,.16),
  Vector2(.24,.22),Vector2(.30,.27),Vector2(.35,.35),Vector2(.40,.47),Vector2(.43,.58),
  Vector2(.46,.63),Vector2(.48,.66),Vector2(.48,.71),Vector2(.43,.74),Vector2(.39,.70),Vector2(.38,.64),Vector2(0,.64)]
 var slices=48
 for i in profile.size()-1:
  var a:Vector2=profile[i];var b:Vector2=profile[i+1]
  for j in slices:
   var points=[]
   for row in [[a,j],[b,j],[b,j+1],[a,j+1]]:
    var p:Vector2=row[0];var angle=float(row[1])*TAU/slices
    var flute=sin(angle*12)*.017 if p.y>.23 and p.y<.63 else 0.0
    var radius=p.x+flute
    points.append(Vector3(cos(angle)*radius,p.y,sin(angle)*radius))
   quad(tool,points[0],points[3],points[2],points[1])
 urn=tool.commit();return urn
