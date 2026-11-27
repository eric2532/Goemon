extends RefCounted
## East-only building solids: original-camera paint on observed faces, separate native parts behind.
const PATH="res://assets/maps/falan/east_region/village_buildings/"
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Parts=preload("res://scripts/forest/forest_il_laruka_buildings.gd")
const Tiles=preload("res://assets/maps/falan/il_laruka/building-surfaces.gd")
const Atlas=preload("res://assets/maps/falan/il_laruka/building-surfaces.png")
const RoundAtlas=preload("res://assets/maps/falan/east_region/village_buildings/round-surfaces.png")
const Fit=preload("res://scripts/forest/forest_il_chief.gd")
const VIEW=Vector3(-1,1.603567,1)
const IDS=[11269,11271,11272,11273,11275]
const CAPS={
 11272:[[[123,36],[142,22],[142,4],[151,0],[166,8],[167,28],[190,35],[187,44],[171,48],[171,64],[145,60]],[[183,81],[211,61],[211,34],[223,25],[238,36],[238,57],[257,65],[255,80],[242,85],[242,103],[215,97]],[[245,133],[272,111],[272,95],[280,87],[295,99],[296,117],[315,127],[313,140],[298,148],[298,164],[273,151]]],
 11273:[[[154,47],[173,31],[173,9],[190,1],[211,8],[214,28],[252,45],[253,27],[266,24],[279,35],[280,72],[269,94],[223,92]]],
 11275:[[[202,37],[221,22],[221,7],[233,0],[246,9],[247,29],[267,37],[264,51],[250,55],[249,70],[224,60]],[[140,79],[160,62],[160,42],[171,35],[187,45],[188,64],[207,78],[204,94],[188,102],[187,117],[162,105]],[[84,126],[105,108],[104,91],[115,82],[131,93],[132,113],[149,126],[147,142],[132,150],[131,165],[105,153]]]
}
static var catalog={}
static var meshes={}

static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(PATH+"data.json"))
 return catalog

static func owns(serial:int)->bool:return serial in IDS

static func alyut_plan(model,legacy_plan:Array)->Array:
 var old=preload("res://assets/maps/falan/alyut_restoration_data.gd").BUILDINGS
 var plan=legacy_plan.filter(func(row):return row[0] not in ["falan_townhouse","falan_shop"] or not old.has(Vector2(row[1].origin.x,row[1].origin.z)))
 for placement:Dictionary in data().maps["2400"].placements:
  var at=Vector2(placement.center_local[0],placement.center_local[1])
  var p=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
  var extent=Vector3(placement.collision_size[0],placement.collision_size[1],placement.collision_size[2])
  plan.append(["east_village_building",Transform3D(Basis.IDENTITY,p),AABB(p-Vector3(extent.x*.5,0,extent.z*.5),extent),placement.graphic,placement.cell])
 return plan

static func point(g:Dictionary,pixel:Vector2,y:float=0.0)->Vector3:
 var sum=(pixel.x-g.center[0])/(32.0/3.0)
 var depth=(pixel.y-g.center[1]+y*Fit.VERTICAL)/8.0
 return Vector3((sum-depth)*.5,y,(sum+depth)*.5)

static func projected(g:Dictionary,pixel:Vector2,normal:Vector3,plane:float)->Vector3:
 var sum=(pixel.x-g.center[0])/(32.0/3.0)
 var x=(plane-normal.z*sum)/(normal.x-normal.z);var z=sum-x
 return Vector3(x,(g.center[1]+(z-x)*8.0-pixel.y)/Fit.VERTICAL,z)

static func quad(ctx:Dictionary,a:Vector3,b:Vector3,c:Vector3,d:Vector3,paint:String,observed:bool=true):
 ctx.base.part=paint;ctx.base.quad(a,b,c,d)
 var normal=(c-a).cross(b-a).normalized()
 var visible=observed and normal.dot(VIEW)>.08
 if visible:
  var lift=normal*.025;ctx.front.quad(a+lift,b+lift,c+lift,d+lift)

static func ring(ctx:Dictionary,low:Array,high:Array,paint:String,observed:bool=true):
 for i in low.size():quad(ctx,low[i],high[i],high[(i+1)%high.size()],low[(i+1)%low.size()],paint,observed)

static func wall_ring(ctx:Dictionary,floor:Array,height:float,window_count:int=2):
 var top=[]
 for p:Vector3 in floor:top.append(p+Vector3.UP*height)
 ring(ctx,floor,top,"plaster")
 for i in floor.size():
  var a:Vector3=floor[i];var b:Vector3=floor[(i+1)%floor.size()]
  var normal=(b-a).cross(Vector3.UP).normalized()
  if normal.dot(VIEW)<=.08:
   ctx.base.part="timber";Parts.bar(ctx.base,a,a+Vector3.UP*height,.22)
   Parts.bar(ctx.base,a+normal*.06+Vector3.UP*.28,b+normal*.06+Vector3.UP*.28,.25)
   Parts.bar(ctx.base,a+normal*.06+Vector3.UP*(height-.16),b+normal*.06+Vector3.UP*(height-.16),.20)
   var count_=mini(window_count,maxi(1,floori(a.distance_to(b)/4.5)))
   for station in count_:Parts.window(ctx.base,a.lerp(b,(station+.5)/count_)+normal*.12+Vector3.UP*height*.55,normal,minf(4.5,height*.62))

static func cap_relief(ctx:Dictionary,pixels:Array,plane:float):
 var normal=Vector3(-1,0,1).normalized();var points=[];var flat=PackedVector2Array()
 for pixel in pixels:
  flat.append(Vector2(pixel[0],pixel[1]));points.append(projected(ctx.g,flat[-1],normal,plane))
 var triangles=Geometry2D.triangulate_polygon(flat)
 for i in range(0,triangles.size(),3):
  var a:Vector3=points[triangles[i]];var b:Vector3=points[triangles[i+1]];var c:Vector3=points[triangles[i+2]]
  ctx.front.quad(a,b,c,c);ctx.front.quad(c,b,a,a)
  # The reverse of this small native ornament repeats its own cap construction, never a building facade.
  ctx.front.quad(a-normal*.32,c-normal*.32,b-normal*.32,b-normal*.32)
 for i in points.size():
  var a:Vector3=points[i];var b:Vector3=points[(i+1)%points.size()]
  ctx.base.part="timber";ctx.base.quad(a,a-normal*.32,b-normal*.32,b)

static func pitched(ctx:Dictionary,profile:Array,back:Vector3,bottom:float):
 for i in profile.size()-1:
  var a:Vector3=profile[i];var b:Vector3=profile[i+1]
  # A closed solid roof keeps its bent native eave profile from both ends.
  quad(ctx,a,b,b+back,a+back,"thatch")
  quad(ctx,a+back,b+back,b,a,"thatch")
  for shift:Vector3 in [Vector3.ZERO,back]:
   var low_a=Vector3(a.x,bottom,a.z)+shift;var low_b=Vector3(b.x,bottom,b.z)+shift
   quad(ctx,low_a,a+shift,b+shift,low_b,"thatch")
   quad(ctx,low_b,b+shift,a+shift,low_a,"thatch")
 for edge:int in [0,profile.size()-1]:
  var a:Vector3=profile[edge];var b=a+back
  var low_a=Vector3(a.x,bottom,a.z);var low_b=Vector3(b.x,bottom,b.z)
  quad(ctx,low_a,a,b,low_b,"plaster")
  quad(ctx,low_b,b,a,low_a,"plaster")
  quad(ctx,a-Vector3.UP*.32,a,b,b-Vector3.UP*.32,"thatch")
  quad(ctx,b-Vector3.UP*.32,b,a,a-Vector3.UP*.32,"thatch")

static func rectangular(ctx:Dictionary):
 var g:Dictionary=ctx.g;var form:Dictionary=g.form;var floor=[]
 for pixel in form.floor:floor.append(point(g,Vector2(pixel[0],pixel[1])))
 floor.append(floor[0]+floor[2]-floor[1])
 var axis=Vector3.BACK if form.end=="right" else Vector3.LEFT
 var plane=-INF
 for p:Vector3 in floor:plane=maxf(plane,axis.dot(p))
 plane+=.6
 var profile=[]
 for pixel in form.roof:profile.append(projected(g,Vector2(pixel[0],pixel[1]),axis,plane))
 var peak:Vector3=profile[int(form.peak)]
 var back=point(g,Vector2(form.rear[0],form.rear[1]))-point(g,Vector2(form.roof[int(form.peak)][0],form.roof[int(form.peak)][1]))
 var height=minf(profile[0].y,profile[-1].y)-.20
 wall_ring(ctx,floor,height)
 pitched(ctx,profile,back,height)
 var min_x=INF;var max_z=-INF
 for p:Vector3 in floor:min_x=minf(min_x,p.x);max_z=maxf(max_z,p.z)
 for dormer:Dictionary in form.get("dormers",[]):
  var normal=Vector3.LEFT if dormer.face=="left" else Vector3.BACK
  var face_plane=-min_x-2.7 if normal==Vector3.LEFT else max_z-2.7
  var roof=[]
  for pixel in dormer.roof:roof.append(projected(g,Vector2(pixel[0],pixel[1]),normal,face_plane))
  var depth=point(g,Vector2(dormer.rear[0],dormer.rear[1]))-point(g,Vector2(dormer.roof[int(dormer.peak)][0],dormer.roof[int(dormer.peak)][1]))
  var foot=projected(g,Vector2(dormer.anchor[0],dormer.anchor[1]),normal,face_plane).y
  pitched(ctx,roof,depth,foot)
  var a:Vector3=roof[0];var b:Vector3=roof[-1]
  quad(ctx,Vector3(a.x,foot,a.z),a,b,Vector3(b.x,foot,b.z),"timber")
  quad(ctx,Vector3(b.x,foot,b.z),b,a,Vector3(a.x,foot,a.z),"timber")
  var back_a:Vector3=a+depth;var back_b:Vector3=b+depth
  var hidden_normal=(back_b-back_a).cross(Vector3.UP).normalized()
  if hidden_normal.dot(depth)<0:hidden_normal=-hidden_normal
  var window_center=(back_a+back_b)*.5;window_center.y=minf(a.y,b.y)-1.7
  Parts.window(ctx.base,window_center+hidden_normal*.12,hidden_normal,3.0)
 for i in CAPS[ctx.serial].size():
  var low_x=INF;var high_x=-INF
  for pixel in CAPS[ctx.serial][i]:low_x=minf(low_x,pixel[0]);high_x=maxf(high_x,pixel[0])
  var source_peak:Vector2=Vector2(form.roof[int(form.peak)][0],form.roof[int(form.peak)][1])
  var station=((low_x+high_x)*.5-source_peak.x)/(form.rear[0]-source_peak.x)
  cap_relief(ctx,CAPS[ctx.serial][i],Vector3(-1,0,1).normalized().dot(peak+back*station))
 if ctx.serial==11275:
  for awning in form.canopies:
   var points=[]
   for pair in awning:points.append(point(g,Vector2(pair[0][0],pair[0][1]),pair[1]/Fit.VILLAGE_HEIGHT))
   quad(ctx,points[0],points[1],points[2],points[3],"canopy")
   quad(ctx,points[3],points[2],points[1],points[0],"canopy")
   ctx.base.part="timber"
   for index in [0,3]:Parts.bar(ctx.base,Vector3(points[index].x,0,points[index].z),points[index],.20)

static func octagon(rx:float,rz:float,cut:float,y:float,offset:Vector3)->Array:
 var result=[]
 for p in [Vector2(-rx,-rz+cut),Vector2(-rx,rz-cut),Vector2(-rx+cut,rz),Vector2(rx-cut,rz),Vector2(rx,rz-cut),Vector2(rx,-rz+cut),Vector2(rx-cut,-rz),Vector2(-rx+cut,-rz)]:result.append(offset+Vector3(p.x,y,p.y))
 return result

static func thatch(ctx:Dictionary,profile:Array,offset:Vector3):
 var sectors=32
 var levels=[]
 for i in profile.size()-1:
  for step in 4:levels.append(profile[i].lerp(profile[i+1],step/4.0))
 levels.append(profile[-1])
 for level in levels.size()-1:
  var lo:Vector2=levels[level];var hi:Vector2=levels[level+1]
  for i in sectors:
   var a=-i*TAU/sectors+PI/16;var b=-(i+1)*TAU/sectors+PI/16
   var fringe_a=(sin(i*13.17)+sin(i*7.11))*.12 if level==0 else 0.0
   var fringe_b=(sin((i+1)*13.17)+sin((i+1)*7.11))*.12 if level==0 else 0.0
   var p=offset+Vector3(cos(a)*(lo.x+fringe_a),lo.y+fringe_a,sin(a)*(lo.x+fringe_a))
   var q=offset+Vector3(cos(b)*(lo.x+fringe_b),lo.y+fringe_b,sin(b)*(lo.x+fringe_b))
   var u=offset+Vector3(cos(a)*hi.x,hi.y,sin(a)*hi.x)
   var v=offset+Vector3(cos(b)*hi.x,hi.y,sin(b)*hi.x)
   # Cylindrical coordinates keep the hidden straw continuous across roof sectors.
   var normal=(v-p).cross(u-p).normalized()
   var tile=Tiles.TILES.thatch
   var span=profile[0].x*TAU/3.0
   var vertices=[p,u,v,q]
   var uv=[Vector2(i*span/sectors,-lo.y/3.0),Vector2(i*span/sectors,-hi.y/3.0),Vector2((i+1)*span/sectors,-hi.y/3.0),Vector2((i+1)*span/sectors,-lo.y/3.0)]
   var observed=(p+q-offset*2.0).dot(Vector3(-1,0,1))>.01
   for vertex in [0,1,2,0,2,3]:
    ctx.base.surface.set_normal(normal);ctx.base.surface.set_uv2(tile);ctx.base.surface.set_uv(uv[vertex]);ctx.base.surface.add_vertex(vertices[vertex])
   if observed and normal.dot(VIEW)>.08:
    var lift=normal*.025;ctx.front.quad(p+lift,u+lift,v+lift,q+lift)
   if level==0:
    quad(ctx,p-Vector3.UP*.44,p,q,q-Vector3.UP*.44,"thatch",false)
    quad(ctx,offset+Vector3.UP*(lo.y-.44),q-Vector3.UP*.44,p-Vector3.UP*.44,offset+Vector3.UP*(lo.y-.44),"timber",false)

static func roundhouse(ctx:Dictionary):
 var winged=ctx.serial==11271;var offset=Vector3(.68,0,.68)
 var rx=6.6 if winged else 7.2;var rz=7.5 if winged else 7.2
 var height=10.8 if winged else 13.8
 var low=octagon(rx,rz,3.0,0,offset)
 wall_ring(ctx,low,height)
 ring(ctx,octagon(rx+.1,rz+.1,3.0,.15,offset),octagon(rx+.1,rz+.1,3.0,.85,offset),"timber")
 thatch(ctx,[Vector2(9.2,height-.25),Vector2(8.8,height+.35),Vector2(7.25,height+1.7),Vector2(5.6,17.6),Vector2(2.7,19.0)],offset)
 var drum=octagon(2.65,2.65,1.5,18.8,offset)
 wall_ring(ctx,drum,5.0,0)
 # Separate rear timber mullions/windows keep the unseen drum complete.
 for i in 8:
  var a:Vector3=drum[i];var b:Vector3=drum[(i+1)%8];var normal=(b-a).cross(Vector3.UP).normalized()
  if normal.dot(VIEW)<=.08:
   ctx.base.part="timber";Parts.bar(ctx.base,a,a+Vector3.UP*5.0,.22)
   Parts.window(ctx.base,(a+b)*.5+normal*.12+Vector3.UP*2.5,normal,3.5)
 thatch(ctx,[Vector2(3.95,23.35),Vector2(3.65,24.0),Vector2(2.5,25.6),Vector2(1.15,27.3),Vector2(.30,28.3)],offset)
 for i in 12:
  var n=Vector3(cos(i*TAU/12),0,sin(i*TAU/12))
  if n.dot(VIEW)<=.08:
   ctx.base.part="timber";Parts.bar(ctx.base,offset+n*2.65+Vector3.UP*19.5,offset+n*3.85+Vector3.UP*17.9,.24)
 if winged:
  # The source's two timber wings are decorative building volume, never new entrances.
  var fit:Dictionary=ctx.g.left_wing_fit
  var wings=[fit.roof_pixels,[[259,126],[309,101],[375,142],[324,177]]]
  for wing in 2:
   var pixels:Array=wings[wing];var wing_height=float(fit.inferred_wall_roof_height) if wing==0 else 12.0
   var roof=[]
   for pixel in pixels:roof.append(point(ctx.g,Vector2(pixel[0],pixel[1]),wing_height))
   var floor=[]
   if wing==0:
    for pixel in fit.floor_pixels:floor.append(point(ctx.g,Vector2(pixel[0],pixel[1])))
    floor.append(floor[0]+floor[2]-floor[1])
   else:
    for p:Vector3 in roof:floor.append(Vector3(p.x,0,p.z))
    floor.reverse()
   wall_ring(ctx,floor,wing_height)
   quad(ctx,roof[0],roof[1],roof[2],roof[3],"timber")
   quad(ctx,roof[3],roof[2],roof[1],roof[0],"timber")

static func prepare(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 assert(owns(serial))
 var g:Dictionary=data().graphics[str(serial)]
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),Vector2(g.center[0],g.center[1])],load(PATH+str(serial)+".png"),1.0/Fit.VERTICAL)
 front.reflection_threshold=INF
 var base=Source.new([],RoundAtlas if serial in [11269,11271] else Atlas,1.0/Fit.VERTICAL);base.tiles=Tiles.TILES
 base.pitches={"plaster":2.8,"timber":1.5,"thatch":3.0,"stone":2.8}
 var ctx={"g":g,"serial":serial,"front":front,"base":base}
 if serial in [11269,11271]:roundhouse(ctx)
 else:rectangular(ctx)
 var result=ArrayMesh.new()
 for mesh:Mesh in [base.finish(),front.finish()]:
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
  result.surface_set_material(result.get_surface_count()-1,mesh.surface_get_material(0))
 meshes[serial]=result;return result

static func build(root:Node3D,p:Vector3,serial:int,source_frame:bool=false)->MeshInstance3D:
 var node=MeshInstance3D.new();node.mesh=prepare(serial);node.position=p
 node.scale.y=1.0 if source_frame else Fit.VILLAGE_HEIGHT
 node.name="BlueCGVillageBuilding_"+str(serial);node.set_meta("source_graphic",serial)
 node.set_meta("source_inferred","Hidden walls/slopes and wing backs, eave thickness, rafters, rear window rhythm and cap depth; no new entrances or routes.")
 root.add_child(node)
 if serial in [11269,11271]:
  var g:Dictionary=data().graphics[str(serial)];var r:Array=g.rooster_rect
  var vane=Sprite3D.new();vane.name="NativeRooster"+str(serial);vane.texture=load(PATH+str(serial)+"-rooster.png")
  vane.pixel_size=1.0/Fit.VERTICAL;vane.rotation.y=-PI*.25;vane.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
  var center=Vector2((r[0]+r[2])*.5,(r[1]+r[3])*.5)
  vane.position=projected(g,center,Vector3(-1,0,1).normalized(),0)
  vane.scale.x=Fit.VERTICAL/(sqrt(2.0)*32.0/3.0) if source_frame else Fit.VILLAGE_HEIGHT
  vane.double_sided=true;node.add_child(vane)
 return node
