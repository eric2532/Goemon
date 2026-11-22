extends RefCounted
## Editable solid castle, fitted to the original doorway and 71 native paint fragments.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Paint=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Sculptures=preload("res://assets/maps/original_crossgate/beast-sculptures.gd")
const Carvings=preload("res://scripts/forest/forest_falan_carvings.gd")
const CarvingData=preload("res://assets/maps/original_crossgate/beast-castle-carvings.gd")
const Civic=preload("res://scripts/forest/forest_falan_civic_exterior.gd")
static var prepared:Mesh
static var prepared_pose=Transform3D.IDENTITY
static var reliefs:Dictionary={}

static func relief(tool:SurfaceTool,feature:String,pose:Transform3D,size_:Vector2):
 if not reliefs.has(feature):reliefs[feature]=Carvings.relief(feature,CarvingData)
 tool.append_from(reliefs[feature],0,pose*Transform3D(Basis.IDENTITY.scaled(Vector3(size_.x,size_.y,1)),Vector3.ZERO))

static func window_frame(skin,p:Vector3,tangent:Vector3,width:float,height:float):
 var previous:String=skin.part;skin.part="plaster"
 var pose=Transform3D(Basis(tangent,Vector3.UP,tangent.cross(Vector3.UP)),p)
 Forms.append(skin,Shapes.bank_frame(width,height),pose)
 var pane=Civic.lancet().surface_get_arrays(0)
 for i in pane[Mesh.ARRAY_VERTEX].size():
  skin.surface.set_normal(pose.basis*Vector3.BACK)
  skin.surface.set_uv2(skin.tiles.window);skin.surface.set_uv(pane[Mesh.ARRAY_TEX_UV][i]*.9998+Vector2.ONE*.0001)
  skin.surface.add_vertex(pose*(pane[Mesh.ARRAY_VERTEX][i]*Vector3(width*.94,height-.12,1)+Vector3(0,.09,.025)))
 skin.part=previous

static func block(skin,p:Vector3,size_:Vector3,paint:String="stone"):
 var previous:String=skin.part;skin.part=paint
 skin.box(AABB(p-size_*.5,size_));skin.part=previous

static func entrance_wing(skin,p:Vector3):
 var outline=PackedVector2Array([Vector2(-1.85,-1.35),Vector2(1.85,-1.35),Vector2(2.3,-.9),Vector2(2.3,.9),Vector2(1.85,1.35),Vector2(-1.85,1.35),Vector2(-2.3,.9),Vector2(-2.3,-.9)])
 skin.part="plaster"
 Forms.append(skin,Shapes.extrude(outline,7.1),Transform3D(Basis(Vector3.RIGHT,-PI*.5),p+Vector3.UP*3.55))

static func arch(skin,center:Vector3,width:float,height:float,depth:float,yaw:float=0.0):
 var outline=PackedVector2Array([Vector2(-width*.5,0),Vector2(-width*.5,height),Vector2(width*.5,height),Vector2(width*.5,0),Vector2(width*.24,0),Vector2(width*.24,height*.48)])
 for i in range(1,17):
  var angle=PI*i/16
  outline.append(Vector2(cos(angle)*width*.24,height*.48+sin(angle)*height*.40))
 outline.append(Vector2(-width*.24,0))
 Forms.append(skin,Shapes.extrude(outline,depth),Transform3D(Basis(Vector3.UP,yaw),center))

static func entry(skin,data:Dictionary):
 # Native jambs are x=344/442, with the opening at 373/402; its crown is near (388,422).
 var half=(442.0-344.0)*.5/Fit.HORIZONTAL
 var opening=(402.0-373.0)*.5/Fit.HORIZONTAL
 var offset=(387.5-393.0)/Fit.HORIZONTAL
 var footing=native_floor(Vector2(387.5,512),0,data)
 var crown=(512.0-422.0)/Fit.VERTICAL;var spring=7.2
 var outline=PackedVector2Array([Vector2(-half,0),Vector2(-half,10.8),Vector2(half,10.8),Vector2(half,0),Vector2(offset+opening,0),Vector2(offset+opening,spring)])
 for i in range(1,25):
  var angle=PI*i/24
  outline.append(Vector2(offset+cos(angle)*opening,spring+sin(angle)*(crown-spring)))
 outline.append(Vector2(offset-opening,0))
 var center=Vector3(footing.x-offset,0,footing.z-1.5)
 Forms.append(skin,Shapes.extrude(outline,3.0),prepared_pose.affine_inverse()*Transform3D(Basis.IDENTITY,center))

static func banner_points(banner:Dictionary,data:Dictionary)->Array:
 var inverse=prepared_pose.affine_inverse()
 var ray=inverse.basis*Vector3(-1,1.603567,1)
 var points=[]
 for pixel:Vector2 in banner.quad:
  var p=inverse*native_floor(pixel,0,data)
  points.append(p+ray*((1.21-p.z)/ray.z))
 return points

static func banners(skin,data:Dictionary):
 for banner:Dictionary in Sculptures.CASTLE_BANNERS:
  skin.tiles[banner.part]=banner.tile
  var points=banner_points(banner,data)
  skin.panel(points[3],points[0],points[1],points[2],banner.part)

static func round_tower(skin,p:Vector3,radius:float,height:float):
 skin.part="stone"
 var shaft=CylinderMesh.new();shaft.radial_segments=16;shaft.rings=0;shaft.top_radius=radius;shaft.bottom_radius=radius;shaft.height=height
 shaft.cap_top=false
 Forms.append(skin,shaft,Transform3D(Basis.IDENTITY,p+Vector3.UP*height*.5))
 Forms.Buildings.kili_round(skin,p,[Vector2(radius-.35,height),Vector2(radius-.35,height-1.2)])
 for i in 16:
  var a=i*TAU/16;var b=(i+1)*TAU/16
  var outer_a=p+Vector3(cos(a)*radius,height,sin(a)*radius)
  var outer_b=p+Vector3(cos(b)*radius,height,sin(b)*radius)
  var inner_a=p+Vector3(cos(a)*(radius-.35),height,sin(a)*(radius-.35))
  var inner_b=p+Vector3(cos(b)*(radius-.35),height,sin(b)*(radius-.35))
  outward_quad(skin,outer_a,outer_b,inner_b,inner_a,Vector3.UP)
 skin.part="plaster"
 for y in [.12,height-.18]:
  Forms.Buildings.kili_round(skin,p,[Vector2(radius*1.04,y),Vector2(radius*1.04,y+.18)])
 for i in 8:
  var angle=i*TAU/8
  block(skin,p+Vector3(cos(angle)*radius*.84,height+.45,sin(angle)*radius*.84),Vector3(.75,.9,.75))
 var normal=Vector3(-1,0,1).normalized()
 window_frame(skin,p+normal*radius+Vector3.UP*1.0,Vector3.UP.cross(normal),.72,height*.65)

static func band(skin,p:Vector3,span:Vector2,y:float):
 for side in [-1,1]:
  block(skin,p+Vector3(0,y,side*span.y*.5),Vector3(span.x+.24,.20,.30),"plaster")
  block(skin,p+Vector3(side*span.x*.5,y,0),Vector3(.30,.20,span.y+.24),"plaster")

static func roof(skin,center:Vector3,half_width:float,depth:float,height:float,paint:String="blue_roof",top_span:Vector2=Vector2.ZERO):
 var previous:String=skin.part;skin.part=paint
 var was_feature:bool=skin.feature;skin.feature=true
 if top_span==Vector2.ZERO:top_span=Vector2(half_width*2,depth)*(.84 if paint=="blue_roof" else .62)
 var low=[];var high=[]
 for corner:Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
  low.append(center+Vector3(corner.x*half_width,0,corner.y*depth*.5))
  high.append(center+Vector3(corner.x*top_span.x*.5,height,corner.y*top_span.y*.5))
 for i in 4:
  var next=(i+1)%4;var out=(low[i]+low[next])*.5-center;out.y=0
  outward_quad(skin,low[i],high[i],high[next],low[next],out)
 outward_quad(skin,high[0],high[1],high[2],high[3],Vector3.UP)
 skin.part=previous
 skin.feature=was_feature

static func pier_cap(skin,p:Vector3):
 var outline=PackedVector2Array([Vector2(-1.8,0),Vector2(-1.8,.5)])
 for i in range(1,17):
  var angle=PI-PI*i/16
  outline.append(Vector2(cos(angle)*1.8,.5+sin(angle)*.75))
 outline.append(Vector2(1.8,0))
 var arrays=Shapes.extrude(outline,4.1).surface_get_arrays(0)
 for i in arrays[Mesh.ARRAY_VERTEX].size():
  var at:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
  var across=(at.x/3.6+.5) if absf(normal.z)>.5 else (at.z/4.1+.5)
  skin.surface.set_normal(normal);skin.surface.set_uv2(skin.tiles.buttress)
  skin.surface.set_uv(Vector2(across,1.0-at.y/1.25).clamp(Vector2.ONE*.0001,Vector2.ONE*.9999));skin.surface.add_vertex(p+at)

static func pier(skin,p:Vector3):
 skin.part="plaster"
 var levels=[[0,1.05],[.5,1.0],[1.25,.97],[2.35,.88],[2.8,1.0],[3.35,1.0],[3.8,.86],[4.5,.65],[6.8,.65],[7.6,1.0]]
 for i in levels.size()-1:
  for side in 4:
   var corners=[Vector3(-1.5,0,-1.75),Vector3(1.5,0,-1.75),Vector3(1.5,0,1.75),Vector3(-1.5,0,1.75)]
   var a:Vector3=corners[side];var b:Vector3=corners[(side+1)%4]
   var points=[p+b*levels[i][1]+Vector3.UP*levels[i][0],p+b*levels[i+1][1]+Vector3.UP*levels[i+1][0],p+a*levels[i+1][1]+Vector3.UP*levels[i+1][0],p+a*levels[i][1]+Vector3.UP*levels[i][0]]
   if levels[i+1][0]<=1.25:
    var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
    for corner in [0,1,2,0,2,3]:
     skin.surface.set_normal(normal);skin.surface.set_uv2(skin.tiles.buttress_relief)
     skin.surface.set_uv(Vector2(.0001 if corner<2 else .9999,clampf(1.0-(points[corner].y-p.y)/1.25,.0001,.9999)))
     skin.surface.add_vertex(points[corner])
   else:skin.quad(points[0],points[1],points[2],points[3])

static func claw_mount(sculpted:SurfaceTool,carved:SurfaceTool,p:Vector3,side:int):
 Forms.Lamps.prepare_primitives()
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 Forms.Lamps.oval(tool,p+Vector3(side*.22,1.23,0),Vector3(.70,.5,2.0))
 for i in 4:
  var z=(i-1.5)*.45;var previous=p+Vector3(side*.12,1.23,z)
  for step in range(1,9):
   var t=step/8.0
   var next=p+Vector3(side*(.12+.65*sin(t*PI*.7)),1.23-t*1.35,z)
   Forms.Lamps.rod(tool,previous,next,lerpf(.16,.015,t));previous=next
 sculpted.append_from(tool.commit(),0,prepared_pose)
 var shield=PackedVector2Array([Vector2(-.65,.9),Vector2(.65,.9),Vector2(.65,-.25),Vector2(0,-.9),Vector2(-.65,-.25)])
 sculpted.append_from(Shapes.extrude(shield,.12),0,prepared_pose*Transform3D(Basis(Vector3.UP,side*PI*.5),p+Vector3(-side*.15,1.65,0)))
 relief(carved,"shield",prepared_pose*Transform3D(Basis(Vector3.UP,side*PI*.5),p+Vector3(-side*.075,1.65,0)),Vector2(1.18,1.7))

static func angel(sculpted:SurfaceTool,p:Vector3,yaw:float,size_:Vector3=Vector3.ONE):
 Forms.Lamps.prepare_primitives()
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 Forms.Lamps.rod(tool,Vector3.UP*.1,Vector3.UP*.35,.28)
 Forms.Lamps.oval(tool,Vector3.UP*.90,Vector3(.44,1.30,.40))
 Forms.Lamps.oval(tool,Vector3.UP*1.55,Vector3(.47,.72,.31))
 Forms.Lamps.oval(tool,Vector3(0,2.04,.04),Vector3(.25,.31,.26))
 for side in [-1,1]:
  Forms.Lamps.rod(tool,Vector3(side*.18,1.76,0),Vector3(side*.41,2.03,.03),.065)
  Forms.Lamps.rod(tool,Vector3(side*.41,2.03,.03),Vector3(side*.37,2.43,0),.05)
  for feather in 7:
   var span=.4+feather*.065;var last=Vector3(side*.14,1.75,-.1)
   for step in range(1,9):
    var t=step/8.0;var next=Vector3(side*(.14+span*sin(t*PI*.55)),1.75+t*(.62+feather*.075),-.1-.11*sin(t*PI))
    Forms.Lamps.rod(tool,last,next,lerpf(.038,.008,t));last=next
 sculpted.append_from(tool.commit(),0,Transform3D(Basis(Vector3.UP,yaw).scaled(size_),p))

static func native_floor(pixel:Vector2,height:float,data:Dictionary)->Vector3:
 var across=(pixel.x-data.origin[0])*3.0/32.0
 var along=(pixel.y-data.origin[1]+height*Fit.VERTICAL)/8.0
 return Vector3((across-along)*.5,height,(across+along)*.5)

static func outward_quad(skin,a:Vector3,b:Vector3,c:Vector3,d:Vector3,out:Vector3):
 if (c-a).cross(b-a).dot(out)>=0:skin.quad(a,b,c,d)
 else:skin.quad(d,c,b,a)

static func upper_castle(data:Dictionary,carved:SurfaceTool,sculpted:SurfaceTool)->Mesh:
 var texture:Texture2D=load(Art.ROOT+"beast-castle-sculpture-surfaces.png")
 var skin=Paint.new([Rect2(Vector2.ZERO,Vector2(data.size[0],data.size[1])),Vector2(data.origin[0],data.origin[1]),Vector2.ONE,0],texture,1.0/Fit.VERTICAL)
 for name_ in data.tiles:skin.tiles[name_]=Vector2(data.tiles[name_][0],data.tiles[name_][1])
 var platform=25.08
 var base=27.55
 var top=40.28
 var outline=[Vector2(267,4),Vector2(320,40),Vector2(320,56),Vector2(280,84),Vector2(253,84),Vector2(204,52),Vector2(204,40),Vector2(254,4)]
 var corners=[];var center=Vector3.ZERO
 for pixel:Vector2 in outline:
  var p=native_floor(pixel,top,data);corners.append(p);center+=p
 center/=corners.size();skin.projection_center=center
 for i in corners.size():
  var a:Vector3=corners[i];var b:Vector3=corners[(i+1)%corners.size()]
  var tangent=(b-a).normalized();var out=tangent.cross(Vector3.UP)
  if out.dot((a+b)*.5-center)<0:
   var swap=a;a=b;b=swap;tangent=-tangent;out=-out
  var lower_a=Vector3(a.x,base,a.z);var lower_b=Vector3(b.x,base,b.z)
  skin.part="plaster";skin.feature=false
  outward_quad(skin,lower_a,a,b,lower_b,(a+b)*.5-center)
  var span=a.distance_to(b)
  var face=Basis(tangent,Vector3.UP,out)
  var middle=(lower_a+lower_b)*.5+out*.025
  var feature="keep_left" if absf(tangent.z)>absf(tangent.x) else "keep_right"
  if span<=3:feature="keep_corner"
  var body_height=top-2.7-base
  relief(carved,feature,Transform3D(face,middle+Vector3.UP*body_height*.5),Vector2(span-.12,body_height))
  if span>3:
   relief(carved,"frieze_left" if feature=="keep_left" else "frieze_right",Transform3D(face,Vector3(middle.x,top-1.65,middle.z)),Vector2(span-.12,1.95))
   for fraction in [.19,.49,.79]:
    var foot=lower_a.lerp(lower_b,fraction)+out*.35
    for row in [Vector2(.7,3.1),Vector2(5.8,3.6)]:window_frame(skin,foot+Vector3.UP*row.x,tangent,span*.16,row.y)
   Forms.Lamps.prepare_primitives()
   var ribs=SurfaceTool.new();ribs.begin(Mesh.PRIMITIVE_TRIANGLES)
   for fraction in [.03,.34,.64,.97]:
    var foot=lower_a.lerp(lower_b,fraction)+out*.34
    Forms.Lamps.rod(ribs,foot+Vector3.UP*.4,foot+Vector3.UP*(body_height-.1),.13)
    for y in [.4,4.6,body_height-.1]:Forms.Lamps.block(ribs,foot+Vector3.UP*y,Vector3(.32,.23,.32))
   skin.part="plaster";Forms.append(skin,ribs.commit())
  var bottom_a=center+(lower_a-center)*1.12;bottom_a.y=platform
  var bottom_b=center+(lower_b-center)*1.12;bottom_b.y=platform
  skin.part="blue_roof";skin.feature=true
  outward_quad(skin,bottom_a,lower_a,lower_b,bottom_b,out)
  skin.feature=false;skin.part="floor"
  var inner_a=center+(a-center).normalized()*1.65;var inner_b=center+(b-center).normalized()*1.65
  outward_quad(skin,a,b,inner_b,inner_a,Vector3.UP)
  outward_quad(skin,inner_a,inner_b,inner_b-Vector3.UP*1.0,inner_a-Vector3.UP*1.0,center-(inner_a+inner_b)*.5)
  # The original tower has a clipped square rim around a separate round battlement.
  skin.part="plaster"
  Forms.Buildings.kili_round(skin,lower_a,[Vector2(.30,0),Vector2(.30,.65),Vector2(.18,.9),Vector2(.18,top-base-1.0),Vector2(.31,top-base-.75)])
  for y in [base+.35,base+1.2,top-.8]:
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
   Forms.Lamps.prepare_primitives();Forms.Lamps.rod(tool,Vector3(a.x,y,a.z),Vector3(b.x,y,b.z),.11);Forms.append(skin,tool.commit())
 var circle=native_floor(Vector2(266,45),top-.6,data)
 Forms.Buildings.kili_round(skin,circle,[Vector2(1.8,0),Vector2(1.8,.75)])
 Forms.Buildings.kili_round(skin,circle,[Vector2(1.48,.75),Vector2(1.48,0)])
 for i in 8:
  var angle=i*TAU/8
  skin.box(AABB(circle+Vector3(cos(angle)*1.65-.23,.75,sin(angle)*1.65-.23),Vector3(.46,.58,.46)))
 for pixel:Vector2 in [Vector2(168,236),Vector2(267,323)]:
  var p=native_floor(pixel,platform,data);skin.projection_center=p
  round_tower(skin,p,2.05,6.2)
 for pixel:Vector2 in [Vector2(349,390),Vector2(465,304)]:
  var p=native_floor(pixel,17.0,data);skin.projection_center=p
  angel(sculpted,p,0,Vector3(1.7,2.5,1.7))
 upper_hall(skin,carved,data)
 var result=skin.finish()
 var paint:ShaderMaterial=result.surface_get_material(0).duplicate()
 paint.set_shader_parameter("original_palette",false)
 result.surface_set_material(0,paint)
 return result

static func upper_hall(skin,carved:SurfaceTool,data:Dictionary):
 var rings=[]
 for row:Dictionary in Sculptures.CASTLE_HALL.slice(0,2):
  var points=[]
  for pixel:Array in row.pixels:points.append(native_floor(Vector2(pixel[0],pixel[1]),row.height,data))
  rings.append(points)
 var low:Array=rings[0];var high:Array=rings[1]
 var center:Vector3=(low[0]+low[1]+low[2]+low[3])*.25
 skin.part="plaster";skin.feature=false
 for i in 4:
  var next=(i+1)%4
  outward_quad(skin,low[i],high[i],high[next],low[next],(low[i]+low[next])*.5-center)
 var tangent:Vector3=(low[1]-low[0]).normalized();var out=tangent.cross(Vector3.UP)
 var pose=Basis(tangent,Vector3.UP,out);var span:float=low[0].distance_to(low[1])
 relief(carved,"hall",Transform3D(pose,(low[0]+low[1])*.5+Vector3.UP*2.65+out*.03),Vector2(span,5.3))
 for fraction in [.19,.49,.79]:window_frame(skin,low[0].lerp(low[1],fraction)+Vector3.UP*.35+out*.32,tangent,span*.16,4.25)
 var ribs=SurfaceTool.new();ribs.begin(Mesh.PRIMITIVE_TRIANGLES);Forms.Lamps.prepare_primitives()
 for fraction in [.03,.34,.64,.97]:
  var foot:Vector3=low[0].lerp(low[1],fraction)+out*.31
  Forms.Lamps.rod(ribs,foot,foot+Vector3.UP*5.3,.13)
  for y in [.1,5.2]:Forms.Lamps.block(ribs,foot+Vector3.UP*y,Vector3(.35,.2,.35))
 Forms.append(skin,ribs.commit())

static func foundation(data:Dictionary)->Mesh:
 var skin=Paint.new([],load(Art.ROOT+"beast-castle-surfaces.png"),.045)
 for name_ in data.tiles:skin.tiles[name_]=Vector2(data.tiles[name_][0],data.tiles[name_][1])
 skin.part="floor"
 for cell:Vector2i in Sculptures.CASTLE_FOUNDATION:
  var p=Vector3(cell.x*3,.018,cell.y*3)
  outward_quad(skin,p+Vector3(-1.5,0,-1.5),p+Vector3(1.5,0,-1.5),p+Vector3(1.5,0,1.5),p+Vector3(-1.5,0,1.5),Vector3.UP)
 return skin.finish()

static func portal_columns(data:Dictionary)->Mesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in Sculptures.CASTLE_COLUMNS.size():
  var column:Dictionary=Sculptures.CASTLE_COLUMNS[i]
  var foot=Vector2(column.foot[0],column.foot[1]);var top=Vector2(column.top[0],column.top[1])
  var at=native_floor(foot,0,data);var height=(foot.y-top.y)/Fit.VERTICAL
  var skin=Paint.new([],load(Art.ROOT+"beast-castle-columns.png"),1.0/Fit.VERTICAL)
  skin.tiles={"plaster":Vector2.ZERO}
  Forms.Buildings.kili_round(skin,Vector3.ZERO,[Vector2(0,0),Vector2(.56,0),Vector2(.56,.24),Vector2(.43,.42),Vector2(.33,.58),Vector2(.33,height-.48),Vector2(.55,height-.30),Vector2(.55,height),Vector2(0,height)])
  var arrays=skin.finish().surface_get_arrays(0)
  for vertex in arrays[Mesh.ARRAY_VERTEX].size():
   var p:Vector3=arrays[Mesh.ARRAY_VERTEX][vertex]
   tool.set_normal(arrays[Mesh.ARRAY_NORMAL][vertex])
   var around=((vertex/6)%16+(1.0 if vertex%6 in [2,4,5] else 0.0))/16.0
   tool.set_uv(Vector2((i+lerpf(.01,.99,around))*.5,clampf(1.0-p.y/height,.002,.998)))
   tool.add_vertex(at+p)
 var result=tool.commit()
 result.surface_set_material(0,Paint.material(load(Art.ROOT+"beast-castle-columns.png")))
 return result

static func layered_roof(data:Dictionary,layers:Array)->Mesh:
 # shortcut: canopy heights and hidden depth are inferred; replace if original geometry is recovered.
 var skin=Paint.new([Rect2(Vector2.ZERO,Vector2(data.size[0],data.size[1])),Vector2(data.origin[0],data.origin[1]),Vector2.ONE,0],load(Art.ROOT+"beast-castle.png"),1.0/Fit.VERTICAL)
 skin.reflection_threshold=2.0
 var rings=[]
 for row:Dictionary in layers:
  var points=[]
  for pixel:Array in row.pixels:points.append(native_floor(Vector2(pixel[0],pixel[1]),row.height,data))
  rings.append(points)
 for level in rings.size()-1:
  var low:Array=rings[level];var high:Array=rings[level+1]
  var center:Vector3=(low[0]+low[1]+low[2]+low[3])*.25
  for i in 4:
   var next=(i+1)%4
   outward_quad(skin,low[i],high[i],high[next],low[next],(low[i]+low[next])*.5-center)
 var bottom:Array=rings[0];var top:Array=rings[-1]
 outward_quad(skin,bottom[0],bottom[1],bottom[2],bottom[3],Vector3.DOWN)
 outward_quad(skin,top[0],top[1],top[2],top[3],Vector3.UP)
 return skin.finish()

static func mesh()->Mesh:
 if prepared!=null:return prepared
 var data:Dictionary=Art.data().beast_castle
 var carved=SurfaceTool.new();carved.begin(Mesh.PRIMITIVE_TRIANGLES)
 var sculpted=SurfaceTool.new();sculpted.begin(Mesh.PRIMITIVE_TRIANGLES)
 var front_left=native_floor(Vector2(288,594),0,data)
 var front_right=native_floor(Vector2(527,433),0,data)
 var back_left=native_floor(Vector2(40,421),0,data)
 var x_axis=(front_right-front_left)/23.0;var z_axis=(front_left-back_left)/22.5
 prepared_pose=Transform3D(Basis(x_axis,Vector3.UP*2.4,z_axis),front_left+x_axis*11.5-z_axis)
 var texture:Texture2D=load(Art.ROOT+"beast-castle-sculpture-surfaces.png")
 var skin=Paint.new([Rect2(Vector2.ZERO,Vector2(data.size[0],data.size[1])),Vector2(data.origin[0],data.origin[1]),Vector2.ONE,0],texture,.045)
 for name_ in data.tiles:skin.tiles[name_]=Vector2(data.tiles[name_][0],data.tiles[name_][1])
 skin.part="stone"
 skin.projection_center=Vector3(0,0,-10.5)
 # Source depth is inferred from the visible isometric faces; navigation retains the client mask.
 block(skin,Vector3(0,5.0,-12.5),Vector3(23,10,18),"plaster")
 block(skin,Vector3(0,10.2,-11),Vector3(24.2,.5,22.2),"floor")
 for y in [.25,1.25,8.65,9.8,10.4]:band(skin,Vector3(0,0,-12.5),Vector2(23,18),y)
 for banner:Dictionary in Sculptures.CASTLE_BANNERS:
  var points=banner_points(banner,data);var x:float=(points[0].x+points[1].x)*.5
  entrance_wing(skin,Vector3(x,0,-.35))
  for y in [.3,1.3,6.5,7.1]:band(skin,Vector3(x,0,-.35),Vector2(4.6,2.7),y)
  window_frame(skin,Vector3(x+signf(x)*1.35,4.0,1.02),Vector3.RIGHT,.55,2.2)
 for side in [-1,1]:
  for z in [-18.2,-10.8,-3.4]:
   var p=Vector3(side*12,0,z)
   pier(skin,p)
   for y in [.18,1.5,3.5,7.7]:band(skin,p,Vector2(3.0,3.5),y)
   roof(skin,p+Vector3.UP*2.8,1.8,4.1,.55)
   for front in [-1,1]:
    var face=p+Vector3(0,6.3,front*1.22);var tangent=Vector3.RIGHT*front
    relief(carved,"pier_scroll",prepared_pose*Transform3D(Basis(tangent,Vector3.UP,tangent.cross(Vector3.UP)),face),Vector2(1.9,2.3))
   block(skin,Vector3(side*12.0,7.9,z),Vector3(3.5,.6,4.0),"plaster")
   pier_cap(skin,Vector3(side*12,8.2,z))
   claw_mount(sculpted,carved,Vector3(side*13.5,3.6,z),side)
   skin.part="stone"
  for z in [-14.5,-7.1]:
   window_frame(skin,Vector3(side*11.55,6.0,z),Vector3(0,0,-side),.65,2.2)
  for i in 13:arch(skin,Vector3(side*11.7,10.45,-20.6+i*1.75),1.75,.8,.65,PI*.5)
  for i in 14:block(skin,Vector3(side*11.7,11.55,-21.475+i*1.75),Vector3(.85,.6,.85))
 skin.part="plaster"
 entry(skin,data)
 banners(skin,data)
 for i in 13:arch(skin,Vector3(-10.8+i*1.8,10.45,-.1),1.8,.8,.65)
 for i in 14:block(skin,Vector3(-11.7+i*1.8,11.55,-.1),Vector3(.9,.6,.85))
 for i in 13:arch(skin,Vector3(-10.8+i*1.8,10.45,-21.5),1.8,.8,.65)
 for i in 14:block(skin,Vector3(-11.7+i*1.8,11.55,-21.5),Vector3(.9,.6,.85))
 prepared=skin.finish()
 var fitted=ArrayMesh.new()
 var arrays=prepared.surface_get_arrays(0);var normals=prepared_pose.basis.inverse().transposed()
 for i in arrays[Mesh.ARRAY_VERTEX].size():
  arrays[Mesh.ARRAY_VERTEX][i]=prepared_pose*arrays[Mesh.ARRAY_VERTEX][i]
  arrays[Mesh.ARRAY_NORMAL][i]=(normals*arrays[Mesh.ARRAY_NORMAL][i]).normalized()
 fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:ShaderMaterial=prepared.surface_get_material(0).duplicate()
 material.set_shader_parameter("original_palette",false)
 fitted.surface_set_material(0,material)
 var upper=upper_castle(data,carved,sculpted)
 fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,upper.surface_get_arrays(0))
 fitted.surface_set_material(1,upper.surface_get_material(0))
 var footing=foundation(data)
 fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,footing.surface_get_arrays(0))
 fitted.surface_set_material(2,footing.surface_get_material(0))
 var door_foot=native_floor(Vector2(387.5,512),0,data)
 var doorway=BoxMesh.new();doorway.size=Vector3((402.0-373.0)/Fit.HORIZONTAL,(512.0-422.0)/Fit.VERTICAL,.08)
 var door=SurfaceTool.new();door.begin(Mesh.PRIMITIVE_TRIANGLES)
 var door_x=door_foot.x
 door.append_from(doorway,0,Transform3D(Basis.IDENTITY,Vector3(door_x,doorway.size.y*.5,door_foot.z-.6)))
 var door_arrays=door.commit().surface_get_arrays(0);var door_uv=PackedVector2Array()
 for p:Vector3 in door_arrays[Mesh.ARRAY_VERTEX]:door_uv.append(Vector2((p.x-door_x)/doorway.size.x+.5,1.0-p.y/doorway.size.y))
 door_arrays[Mesh.ARRAY_TEX_UV]=door_uv
 fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,door_arrays)
 fitted.surface_set_material(3,Paint.material(load(Art.ROOT+"beast-castle-door.png")))
 var columns=portal_columns(data)
 fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,columns.surface_get_arrays(0))
 fitted.surface_set_material(4,columns.surface_get_material(0))
 var canopy=layered_roof(data,Sculptures.CASTLE_CANOPY)
 var roofs=SurfaceTool.new();roofs.begin(Mesh.PRIMITIVE_TRIANGLES);roofs.append_from(canopy,0,Transform3D.IDENTITY)
 roofs.append_from(layered_roof(data,Sculptures.CASTLE_HALL.slice(1)),0,Transform3D.IDENTITY)
 fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,roofs.commit().surface_get_arrays(0))
 fitted.surface_set_material(5,canopy.surface_get_material(0))
 var carving_mesh=carved.commit()
 fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,carving_mesh.surface_get_arrays(0))
 var carving_paint:ShaderMaterial=Paint.material(CarvingData.ATLAS).duplicate()
 carving_paint.set_shader_parameter("original_palette",false)
 carving_paint.set_shader_parameter("atlas_tile_pixels",0.0)
 fitted.surface_set_material(6,carving_paint)
 fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sculpted.commit().surface_get_arrays(0))
 var ivory=load(Art.ROOT+"beast-castle.png").get_image().get_pixel(33,401)
 fitted.surface_set_material(7,Forms.Fort.material(ivory,false));prepared=fitted
 return prepared

static func build(parent:Node3D,at:Vector3):
 var node=MeshInstance3D.new();node.name="RecoveredBeastCastle";node.mesh=mesh();node.position=at
 node.set_meta("original_source_graphics",71);node.set_meta("original_source_anchor",Vector2i(135,333))
 parent.add_child(node)

