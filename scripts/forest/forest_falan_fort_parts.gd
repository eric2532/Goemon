extends RefCounted
## Shared solid fort parts with original paint assigned to individual surfaces.
const Data=preload("res://assets/maps/falan/city_fort_paint.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Paint=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Masonry=preload("res://assets/maps/falan/city_fort_masonry.png")
const BasePaint=preload("res://assets/maps/falan/city_fort_base.png")
const WindowPaint=preload("res://assets/maps/falan/city_fort_window.png")
const WindowDetails=preload("res://assets/maps/falan/city_fort_windows.png")
const BannerPaint=preload("res://assets/maps/falan/city_fort_banner.png")
const BlueBannerPaint=preload("res://assets/maps/falan/city_fort_blue_banner.png")
const GateWindowPaint=preload("res://assets/maps/falan/city_fort_gate_window.png")
const GateBadgePaint=preload("res://assets/maps/falan/city_fort_gate_badge.png")
const LeafPaint=preload("res://assets/maps/falan/city_fort_leaf.png")
const LeafFrontPaint=preload("res://assets/maps/falan/city_fort_leaf_front.png")
const PavingPaint=preload("res://assets/maps/falan/city_fort_paving.png")
const GatePaving=preload("res://assets/maps/falan/city_fort_gate_paving.png")
const HoodLeft=preload("res://assets/maps/falan/city_fort_hood_left.png")
const HoodRight=preload("res://assets/maps/falan/city_fort_hood_right.png")
const ArrowDetails=preload("res://assets/maps/falan/city_fort_arrow_details.png")
const SquareCoursePaint=preload("res://assets/maps/falan/city_fort_square_courses.png")
const WallOpeningPaint=preload("res://assets/maps/falan/city_fort_wall_openings.png")
const WallSupportPaint=preload("res://assets/maps/falan/city_fort_wall_supports.png")
const WallSpurPaint=preload("res://assets/maps/falan/city_fort_wall_spurs.png")
const SpurEndPaint=preload("res://assets/maps/falan/city_fort_spur_ends.png")
static var stone_paint:ShaderMaterial
static var base_paint:ShaderMaterial
static var meshes={}
static var beams={}
static var supports={}
static var square_tooth:Mesh
static var wall_tooth:Mesh
static var round_tooth:Mesh
static var round_rim:Mesh
static var round_course:Mesh
static var round_base_band:CylinderMesh
static var round_shaft:CylinderMesh
static var round_flare:CylinderMesh
static var window_arch:Mesh
static var window_shutter:Mesh
static var square_course_mesh:Mesh
const WALL_PROFILES={
 10640:[10.1622,4.8206,4.2289,2.922,1.3,.2839,9.2531,2.0728,.8927],
 10641:[10.6754,4.1825,4.6501,3.3775,1.5,.374,9.673,2.1678,.6396],
}
# Preserve the measured wall shell while fitting its crown independently.
static var WALL_FRAMES={
 10640:Transform3D(Basis(Vector3(.864614188671112,0,0),Vector3(0,.941105306148529,0),Vector3(0,0,.864614188671112)),Vector3(.171875417232513,0,-.471432149410248)),
 10641:Transform3D(Basis(Vector3(.821003079414368,0,0),Vector3(0,.947233021259308,0),Vector3(0,0,.821003079414368)),Vector3(-.528140366077423,0,.078124374151230)),
}
# Native top-face centres, full head widths/depths in pixels, and the terminal overhang.
const WALL_CROWNS=[
 [Vector2(47.5,6.063559322),Vector2(9,9),false],
 [Vector2(75.389830508,24.758474576),Vector2(19,7),false],
 [Vector2(107.389830508,48.758474576),Vector2(19,7),false],
 [Vector2(134.5,71),Vector2(8.5,8.5),true],
 [Vector2(26.5,21.726694915),Vector2(8.5,8.5),false],
 [Vector2(54.389830508,40.508474576),Vector2(19,7),false],
 [Vector2(86.389830508,64.508474576),Vector2(19,7),false],
]
const GATE_QUADS={
 "banner":[Vector2(88,125),Vector2(88,156),Vector2(99,149),Vector2(99,118)],
 "blue_banner":[Vector2(100,115),Vector2(100,148),Vector2(109,143),Vector2(109,110)],
 "gate_window":[Vector2(47,170),Vector2(47,186),Vector2(55,181),Vector2(55,165)],
 "gate_badge":[Vector2(107,84),Vector2(107,96),Vector2(116,90),Vector2(116,78)],
}
const LEAF_QUADS={
 10647:[Vector2(1,128),Vector2(1,255),Vector2(39,278),Vector2(39,151)],
 10661:[Vector2(112,161),Vector2(112,290),Vector2(130,279),Vector2(130,172)],
}
const SOUTH_CROWN_TOPS={
 -1:[Vector2(46,105),Vector2(61,94),Vector2(76,83),Vector2(91,72),Vector2(106,61)],
 1:[Vector2(81,110),Vector2(105,92),Vector2(129,74)],
}
# Keep the measured stone frame independent of the replacement ironwork.
const WEST_EAST_FRAME=Transform3D(Basis(Vector3(.727449,0,0),Vector3(0,.598112,0),Vector3(0,0,.727449)),Vector3(.108308,7.438402,-.108308))
const CROWN_PROFILE=[Vector2(.59,-.38),Vector2(.59,.10),Vector2(.59,.28),Vector2(.53,.38)]
const WEST_EAST_FRONT=-1.25
# Filled terminal pixels have different exposed edges in the two native facings.
const IRON_PIXEL_EDGES={10646:Vector2(-.5,1),10662:Vector2(1,.5)}
const SOUTH_WINDOW_MIN_U=45.0
const SOUTH_RETURN_BOTTOM=13.1
const SOUTH_COPING_C=-61.25
const SOUTH_COPING_TOP=19.86
const SOUTH_COPING_END_U=175.0
const SOUTH_CORBEL_PROFILE=[Vector2(155,85),Vector2(174,73),Vector2(177,76),Vector2(177,136),Vector2(174,142),Vector2(156,130)]
const BRACE_SIDES={10648:[1],10649:[-1],10651:[-1,1],10652:[-1],10653:[1],10655:[1],10656:[-1],10658:[-1,1],10659:[-1],10660:[1]}
const SQUARE_BRACE_EDGE=[Vector2(29,-103),Vector2(34,-95),Vector2(37,-85),Vector2(39,-60),Vector2(35,-35),Vector2(31,-10),Vector2(26,15),Vector2(22,40),Vector2(21,50)]
const ROUND_BRACE_EDGE=[Vector2(35,-103),Vector2(38,-83),Vector2(40,-68),Vector2(36,-43),Vector2(31,-13),Vector2(26,17),Vector2(22,42),Vector2(21,47),Vector2(19,52)]
const ROUND_RADIUS=2.985
const ROUND_FOOTING_HEIGHT=4.6
const ROUND_FOOTING_RADIUS=3.076
const ROUND_FLARE_TOP=5.9
const ROUND_BASE_RADIUS=3.30
const ROUND_SETBACK=-.20
# Half a native pixel separates the shaft centre from the crown frame.
const ROUND_CENTER=Vector3(.015523,0,-.015523)
const SQUARE_FOUNDATION_HEIGHT=3.45
const GATE_ROTATIONS={"freyja":{Vector2i(0,10):0,Vector2i(0,26):2},"east_gate":{Vector2i(0,10):0,Vector2i(0,26):0},"south_gate":{Vector2i(0,7):0,Vector2i(0,26):0}}
const GATE_YAWS={"freyja":0.0,"east_gate":PI,"south_gate":-PI*.5}
# Native-mask fits: base width, taper/shaft heights, crown width, setback, knee fraction, depth ratio, cut plane/slope.
const PIER_PROFILES={
 10642:[6.54154,6.40655,5.688,3.49925,2.19803,.16527,.74491,.85476,.20241],
 10643:[7.0,9.8,4.0,4.3075,2.06,.2,1.31,20.0,0.0],
 10644:[7.0,9.85,4.75,4.495,2.01,.2075,1.3,20.0,0.0],
 10645:[6.25517,5.3656,4.46395,3.43582,2.45921,.37978,.75358,1.0712,.218],
}
# Crown setback correction, tooth width/height, coping overhang and tooth inset.
const PIER_CROWNS={10642:[.35719,.79443,.82648,.30412,.57085],10645:[.38945,1.15078,1.29626,.19018,.57238]}

static func pier_ring(width:float,depth:float,y:float,offset:float)->Array:
 var result=[]
 for p:Vector2 in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]:result.append(Vector3(p.x*width*.5,y,p.y*depth*.5+offset))
 return result

static func pier_loft(lower:Array,upper:Array,cut:float,slope:float=0.0)->Mesh:
 assert(lower.size()>=3 and lower.size()==upper.size(),"A solid loft needs matching rings")
 var top=upper.duplicate();top.reverse()
 var faces=[lower,top];var cap=[];var did_clip=false
 for i in lower.size():faces.append([lower[i],upper[i],upper[(i+1)%lower.size()],lower[(i+1)%lower.size()]])
 var clipped=[]
 for face in faces:
  var polygon=[]
  for i in face.size():
   var a:Vector3=face[i];var b:Vector3=face[(i+1)%face.size()];var da=a.x-a.z-a.y*slope-cut;var db=b.x-b.z-b.y*slope-cut
   if absf(da)<.000001:da=0.0
   if absf(db)<.000001:db=0.0
   if da>0:did_clip=true
   if da<=0:polygon.append(a)
   if da==0.0 and not cap.any(func(p):return p.is_equal_approx(a)):cap.append(a)
   if da*db<0:
    var hit=a.lerp(b,da/(da-db));polygon.append(hit)
    if not cap.any(func(p):return p.is_equal_approx(hit)):cap.append(hit)
  if polygon.size()>=3:clipped.append(polygon)
 if did_clip and cap.size()>=3:
  var center=Vector3.ZERO
  for p:Vector3 in cap:center+=p
  center/=cap.size();var along=Vector3(1,0,1).normalized()
  cap.sort_custom(func(a,b):return atan2((a-center).y,(a-center).dot(along))<atan2((b-center).y,(b-center).dot(along)))
  if (cap[2]-cap[0]).cross(cap[1]-cap[0]).dot(Vector3(1,-slope,-1))<0:cap.reverse()
  clipped.append(cap)
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for face in clipped:
  for i in range(1,face.size()-1):
   var n:Vector3=(face[i+1]-face[0]).cross(face[i]-face[0])
   if n.length_squared()<.000000000001:continue
   for p in [face[0],face[i],face[i+1]]:tool.set_normal(n.normalized());tool.add_vertex(p)
 return tool.commit()

static func pier(root:Node3D,serial:int,stone:Material,trim:Material,base:Material,dark:Material):
 var row:Array=PIER_PROFILES[serial];var bt:float=row[0];var taper:float=row[1];var shaft:float=row[2];var top_width:float=row[3];var offset:float=row[4];var fraction:float=row[5];var aspect:float=row[6];var cut:float=row[7];var slope:float=row[8]
 var body=Node3D.new();root.add_child(body)
 if serial in [10643,10645]:body.basis=Basis(Vector3.BACK,Vector3.UP,Vector3.RIGHT)
 var bottom=pier_ring(8.34,8.34*aspect,0,0);var middle=pier_ring(bt,bt*aspect,3.8,-offset*fraction);var neck=pier_ring(top_width,top_width,3.8+taper,-offset);var top=pier_ring(top_width,top_width,3.8+taper+shaft,-offset)
 Geo.mesh(body,pier_loft(bottom,middle,cut,slope),Vector3.ZERO,base)
 Geo.mesh(body,pier_loft(middle,neck,cut,slope),Vector3.ZERO,stone)
 Geo.mesh(body,pier_loft(neck,top,cut,slope),Vector3.ZERO,stone)
 Geo.mesh(body,pier_loft(pier_ring(8.5,8.5*aspect,0,0),pier_ring(8.5,8.5*aspect,.16,0),cut,slope),Vector3.ZERO,trim)
 var height=3.8+taper+shaft
 var crest:Array=PIER_CROWNS.get(serial,[0.0,.65,.68,.35,.36]);var crown_z=-offset+crest[0]
 Geo.box(body,Vector3(0,height+.2,crown_z),Vector3(top_width+crest[3],.4,top_width+crest[3]),trim).set_meta("falan_fort_paving_top",true)
 for x in [-1,1]:
  for z in [-1,1]:
   var block=Geo.mesh(body,merlon(),Vector3(x*(top_width*.5-crest[4]),height+.4+crest[2]*.5,crown_z+z*(top_width*.5-crest[4])),trim)
   block.scale=Vector3(crest[1]/1.18,crest[2]/.76,crest[1]/1.18);block.set_meta("falan_crown_block",true)
 for z in [-.6,.6]:Geo.box(body,Vector3(0,height+.45,crown_z+z),Vector3(top_width*.62,.09,.08),dark)
 for side in [-1,1]:
  Geo.box(body,Vector3(side*(top_width*.5-.14),height+.50,crown_z),Vector3(.28,.20,top_width),trim)
  Geo.box(body,Vector3(0,height+.50,crown_z+side*(top_width*.5-.14)),Vector3(top_width,.20,.28),trim)
 var hatch=PackedVector2Array([Vector2(-.42,.48),Vector2(-.28,-.36),Vector2(0,-.54),Vector2(.28,-.36),Vector2(.42,.48)])
 Geo.mesh(body,Shapes.extrude(hatch,.055),Vector3(0,height-1.35,-offset+top_width*.5+.015),dark)

static func gallery_box(root:Node3D,at:Vector3,size_:Vector3,material:Material,cut:float=INF)->MeshInstance3D:
 if is_inf(cut):return Geo.box(root,at,size_,material)
 if at.x-at.z+(size_.x+size_.z)*.5<=-cut:return null
 # The original 10662 part ends at a diagonal join hidden inside its neighbouring tower.
 var lower=pier_ring(size_.x,size_.z,at.y-size_.y*.5,at.z);var upper=pier_ring(size_.x,size_.z,at.y+size_.y*.5,at.z)
 for ring in [lower,upper]:
  for i in ring.size():ring[i]=Vector3(ring[i].z,ring[i].y,ring[i].x+at.x)
  ring.reverse()
 var node=Geo.mesh(root,pier_loft(lower,upper,cut),Vector3.ZERO,material)
 node.basis=Basis(Vector3.BACK,Vector3.UP,Vector3.RIGHT)
 return node

static func south_ring(ring:Array,turn:Basis)->Array:
 var result=[]
 for i in ring.size():
  var a:Vector3=ring[i];var b:Vector3=ring[(i+1)%ring.size()]
  var limit=(SOUTH_COPING_END_U+Data.PARTS[10646][1].position.x)/Fit.HORIZONTAL+.28125
  var da=a.z-a.x-limit;var db=b.z-b.x-limit
  if da<=0:result.append(turn*a)
  if da*db<0:result.append(turn*a.lerp(b,da/(da-db)))
 return result

static func south_corbel(root:Node3D,material:Material)->MeshInstance3D:
 var outline=PackedVector2Array();var plane=-.815
 for pixel:Vector2 in SOUTH_CORBEL_PROFILE:
  var native=pixel+Data.PARTS[10646][1].position;var z=plane-native.x/Fit.HORIZONTAL
  outline.append(Vector2(z,((plane+z)*Fit.FLOOR-native.y)/Fit.VERTICAL))
 var node=Geo.mesh(root,Shapes.extrude(outline,.64),Vector3(plane-.32,0,0),material)
 node.basis=Basis(Vector3.BACK,Vector3.UP,Vector3.RIGHT);node.set_meta("falan_fort_feature","base")
 return node

static func south_return(root:Node3D,at:Vector3,size_:Vector3,material:Material)->MeshInstance3D:
 var turn=Basis(Vector3.UP,-PI*.75)
 var lower=pier_ring(size_.x,size_.z,at.y-size_.y*.5,at.z);var upper=pier_ring(size_.x,size_.z,at.y+size_.y*.5,at.z)
 for ring in [lower,upper]:
  for i in ring.size():ring[i]+=Vector3.RIGHT*at.x
 lower=south_ring(lower,turn);upper=south_ring(upper,turn)
 # Recess structural cuts behind the coping so their different stone finishes cannot flicker.
 var clip=(232.75-SOUTH_COPING_C-.35)*sqrt(2.0)/16.0;var slope=-Fit.VERTICAL*sqrt(2.0)/16.0
 var node=Geo.mesh(root,pier_loft(lower,upper,clip,slope),Vector3.ZERO,material)
 node.basis=turn.inverse()
 return node

# Bevel both arrises; shared internal band faces are omitted from this closed profile.
static func gallery_coping(root:Node3D,at:Vector3,size_:Vector3,material:Material,cut:float=INF,south_end:bool=false)->MeshInstance3D:
 var turn=Basis(Vector3.UP,-PI*.75) if south_end else Basis(Vector3.BACK,Vector3.UP,Vector3.RIGHT)
 var slope=0.0
 if south_end:cut=(232.75-SOUTH_COPING_C)*sqrt(2.0)/16.0;slope=-Fit.VERTICAL*sqrt(2.0)/16.0
 var bevel=minf(.03,size_.y*.2);var rings=[]
 for level in [Vector2(bevel,-size_.y*.5),Vector2(0,-size_.y*.5+bevel),Vector2(0,size_.y*.5-bevel),Vector2(bevel,size_.y*.5)]:
  var ring=pier_ring(size_.x-2*level.x,size_.z-2*level.x,at.y+level.y,at.z)
  for i in ring.size():ring[i]+=Vector3.RIGHT*at.x
  if south_end:ring=south_ring(ring,turn)
  else:
   for i in ring.size():ring[i]=turn*ring[i]
  if turn.determinant()<0:ring.reverse()
  rings.append(ring)
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for band in rings.size()-1:
  var arrays=pier_loft(rings[band],rings[band+1],cut,slope).surface_get_arrays(0);var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  for i in range(0,points.size(),3):
   if (normals[i].y>.99 and band<rings.size()-2) or (normals[i].y<-.99 and band>0):continue
   for j in 3:tool.set_normal(normals[i+j]);tool.add_vertex(points[i+j])
 var node=Geo.mesh(root,tool.commit(),Vector3.ZERO,material);node.basis=turn.inverse();return node

static func merlon(narrow_stem:bool=false)->Mesh:
 if narrow_stem and wall_tooth!=null:return wall_tooth
 if not narrow_stem and square_tooth!=null:return square_tooth
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var corners=[Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]
 var rings=[]
 var profile=[Vector2(.40,-.38),Vector2(.40,.10),Vector2(.59,.10),Vector2(.59,.28),Vector2(.53,.38)] if narrow_stem else CROWN_PROFILE
 for level in profile:
  var ring=[]
  for p:Vector2 in corners:ring.append(Vector3(p.x*level.x,level.y,p.y*level.x))
  rings.append(ring)
 for k in rings.size()-1:
  tool.set_color(Color("b9a787") if k==0 else Color.WHITE)
  for i in 4:Shapes.quad(tool,rings[k][i],rings[k+1][i],rings[k+1][(i+1)%4],rings[k][(i+1)%4])
 tool.set_color(Color("b9a787"))
 Shapes.quad(tool,rings[0][0],rings[0][1],rings[0][2],rings[0][3])
 tool.set_color(Color.WHITE)
 Shapes.quad(tool,rings[-1][3],rings[-1][2],rings[-1][1],rings[-1][0])
 var result=tool.commit()
 if narrow_stem:wall_tooth=result
 else:square_tooth=result
 return result

static func wall_crowns(root:Node3D,serial:int,trim:Material):
 var frame:Transform3D=WALL_FRAMES[serial];var native_origin=-Data.PARTS[serial][1].position
 var group=Node3D.new();group.transform=frame.affine_inverse();root.add_child(group)
 var turn=Basis(Vector3.UP,PI*.5 if serial==10641 else 0.0);var base_y=15.4*frame.basis.y.y
 for row in WALL_CROWNS:
  var pixel:Vector2=row[0]
  if serial==10641:pixel.x=143-pixel.x
  pixel-=native_origin
  var top=(16.2 if row[2] else 16.6)*frame.basis.y.y;var along=(pixel.y+top*Fit.VERTICAL)/Fit.FLOOR;var across=pixel.x/Fit.HORIZONTAL
  var center=Vector3((along+across)*.5,top,(along-across)*.5);var size_:Vector2=row[1]/Fit.HORIZONTAL
  if row[2]:
   var head=gallery_coping(group,center-Vector3.UP*.065,Vector3(size_.x,.13,size_.y),trim);head.set_meta("falan_crown_block",true)
   var clip_turn=Basis(Vector3.UP,PI) if serial==10641 else Basis.IDENTITY
   var lower=pier_ring(size_.x,size_.y,base_y,center.z);var upper=pier_ring(size_.x,size_.y,top-.12,center.z)
   for ring in [lower,upper]:
    for i in ring.size():ring[i]=clip_turn*(ring[i]+Vector3.RIGHT*center.x)
   var cut=(135-native_origin.x)/Fit.HORIZONTAL if serial==10640 else (native_origin.x-8)/Fit.HORIZONTAL
   var stem=Geo.mesh(group,pier_loft(lower,upper,cut),Vector3.ZERO,trim);stem.basis=clip_turn.inverse()
  else:
   var height=top-base_y;var block=Geo.mesh(group,merlon(true),center-Vector3.UP*(height*.5),trim)
   block.basis=turn*Basis.from_scale(Vector3(size_.x/1.18,height/.76,size_.y/1.18));block.set_meta("falan_crown_block",true)

static func west_east_crowns(root:Node3D,trim:Material):
 var frame=Node3D.new();frame.transform=WEST_EAST_FRAME.affine_inverse();root.add_child(frame)
 for rear in [true,false]:
  for i in (8 if rear else 5):
   var pixel=Vector2(-1+i*15,6+i*11) if rear else Vector2(6+i*15,64+i*11)
   var native:Vector2=pixel+Data.PARTS[10662][1].position;var top_y=19.87;var along=(native.y+top_y*Fit.VERTICAL)/Fit.FLOOR
   var center=Vector3((along+native.x/Fit.HORIZONTAL)*.5,top_y-.425,(along-native.x/Fit.HORIZONTAL)*.5)
   var size_=Vector3(.82,.85,.68);var cap:MeshInstance3D
   if i==0:
    var rings=[]
    for level:Vector2 in CROWN_PROFILE:
     var ring=[]
     for corner:Vector2 in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]:
      var p=center+Vector3(corner.x*level.x*size_.x/1.18,level.y*size_.y/.76,corner.y*level.x*size_.z/1.18)
      ring.append(Vector3(p.z,p.y,p.x))
     ring.reverse()
     rings.append(ring)
    var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for band in rings.size()-1:
     var arrays=pier_loft(rings[band],rings[band+1],31.0/Fit.HORIZONTAL).surface_get_arrays(0)
     var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
     for j in range(0,vertices.size(),3):
      if (normals[j].y>.99 and band<rings.size()-2) or (normals[j].y<-.99 and band>0):continue
      for k in 3:tool.set_normal(normals[j+k]);tool.set_color(Color("b9a787") if band==0 else Color.WHITE);tool.add_vertex(vertices[j+k])
    cap=Geo.mesh(frame,tool.commit(),Vector3.ZERO,trim);cap.basis=Basis(Vector3.BACK,Vector3.UP,Vector3.RIGHT)
    if rear:
     # The cropped tooth exposes native y=0; its foot still seats on the coping.
     var bounds=Fit.projected_bounds(Fit.mesh_points(cap.mesh,cap.transform))
     var lift=(bounds.position.y-Data.PARTS[10662][1].position.y)/Fit.VERTICAL
     var arrays=cap.mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
     for j in vertices.size():
      if absf(vertices[j].y-(top_y-size_.y))<.0001:vertices[j].y-=lift
     arrays[Mesh.ARRAY_VERTEX]=vertices;var extended=ArrayMesh.new();extended.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);cap.mesh=extended;cap.position.y=lift
   else:
    cap=Geo.mesh(frame,merlon(),center,trim);cap.scale=size_/Vector3(1.18,.76,1.18)
   cap.set_meta("falan_crown_block",true)

static func ironwork(root:Node3D,serial:int):
 var field=Node3D.new();root.add_child(field)
 if serial==10662:field.transform=WEST_EAST_FRAME.affine_inverse()
 var iron=Court.Fort.material(Color("39251c"),false);var brass=Court.Fort.material(Color("858e6c"),false)
 var cut=31.0/Fit.HORIZONTAL if serial==10662 else INF
 for rear in [false,true]:
  var plane:float
  var first:float;var count:int;var tip_q:float;var rail_q:Array
  if serial==10646:
   plane=-4.59375 if rear else -2.0;first=60.833333 if rear else 48.5;count=10 if rear else 15
   tip_q=246.25+16*(plane+2.0);rail_q=[226.0,234.0]
  else:
   plane=WEST_EAST_FRAME.origin.z+WEST_EAST_FRAME.basis.z.z*(-6.1246) if rear else WEST_EAST_FRONT
   # Rear pickets continue along the longer, diagonally cropped side of the gallery.
   first=1.0 if rear else .5
   count=15 if rear else 9;tip_q=115.5;rail_q=[96.0,103.5]
  var ends=[]
  for i in count:
   var pixel_x=first+i*8.0
   var is_long=serial==10646 and (i+(5 if rear else 0)) in [5,10]
   var q=tip_q+(5.75 if is_long else 0.0);var shift=(-.5 if is_long else -1.5) if serial==10646 else 1.5
   var tip_pixel=Vector2(pixel_x+shift,q+(-.75 if serial==10646 else .75)*(pixel_x+shift))
   if serial==10662 and rear:tip_pixel.y+=16*(plane-WEST_EAST_FRONT)
   var tip=iron_point(serial,tip_pixel,plane);var axis=iron_point(serial,Vector2(pixel_x,tip_pixel.y),plane)
   var top_y=18.56 if serial==10646 else 18.52;var neck=tip.y+.55
   axis.y=(top_y+neck)*.5;var width=.16 if is_long else .10
   gallery_box(field,axis,Vector3(width,top_y-neck,width),iron,cut)
   var collar=axis;collar.y=tip.y+(1.18 if is_long else .6)
   gallery_box(field,collar,Vector3(.34 if is_long else .19,.26 if is_long else .19,.20 if is_long else .14),brass,cut)
   var upper=pier_ring(.20 if is_long else .16,.16 if is_long else .12,neck,axis.z)
   for j in 4:upper[j].x+=axis.x
   var lower=[tip,tip,tip,tip]
   if serial==10662:
    lower=lower.map(func(p):return Vector3(p.z,p.y,p.x));upper=upper.map(func(p):return Vector3(p.z,p.y,p.x))
    lower.reverse();upper.reverse()
   var tooth=Geo.mesh(field,pier_loft(lower,upper,cut),Vector3.ZERO,iron)
   if serial==10662:tooth.basis=Basis(Vector3.BACK,Vector3.UP,Vector3.RIGHT)
   tooth.set_meta("falan_iron_spike",true);tooth.set_meta("falan_iron_tip",lower[0])
   ends.append(axis)
  var center:Vector3=(ends[0]+ends[-1])*.5
  for q in rail_q:
   var pixel=Vector2(first,q+(-.75 if serial==10646 else .75)*first)
   if rear:pixel.y+=16*(plane-(-2.0 if serial==10646 else WEST_EAST_FRONT))
   center.y=iron_point(serial,pixel,plane).y
   gallery_box(field,center,Vector3(.08,.08,(count-1)*.75+.30) if serial==10646 else Vector3((count-1)*.75+.30,.08,.08),iron,cut)

static func iron_point(serial:int,pixel:Vector2,plane:float)->Vector3:
 var native=pixel+IRON_PIXEL_EDGES[serial]+Data.PARTS[serial][1].position
 var x=plane if serial==10646 else plane+native.x/Fit.HORIZONTAL
 var z=plane-native.x/Fit.HORIZONTAL if serial==10646 else plane
 return Vector3(x,((x+z)*Fit.FLOOR-native.y)/Fit.VERTICAL,z)

static func crown_sector(inner:float,outer:float,height:float,angle:float=TAU)->Mesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 assert(inner>0 and outer>inner and height>0 and angle>0 and angle<=TAU,"A crown sector must enclose solid volume")
 var bevel=minf(.08,minf(height*.3,(outer-inner)*.2))
 var profile=PackedVector2Array([Vector2(outer,0),Vector2(outer,height-bevel),Vector2(outer-bevel,height),Vector2(inner+bevel,height),Vector2(inner,height-bevel),Vector2(inner,0)])
 var steps=maxi(1,ceili(angle/TAU*64))
 for i in steps:
  var a=lerpf(-angle*.5,angle*.5,float(i)/steps);var b=lerpf(-angle*.5,angle*.5,float(i+1)/steps)
  for j in profile.size():
   var p:Vector2=profile[j];var q:Vector2=profile[(j+1)%profile.size()]
   Shapes.quad(tool,Vector3(sin(a)*p.x,p.y,cos(a)*p.x),Vector3(sin(a)*q.x,q.y,cos(a)*q.x),Vector3(sin(b)*q.x,q.y,cos(b)*q.x),Vector3(sin(b)*p.x,p.y,cos(b)*p.x))
 if angle<TAU-.001:
  var indices=Geometry2D.triangulate_polygon(profile)
  for side in [-1,1]:
   var theta=side*angle*.5;var normal=Vector3(cos(theta),0,-sin(theta))*side
   for i in range(0,indices.size(),3):
    var points=[]
    for j in 3:
     var p:Vector2=profile[indices[i+j]];points.append(Vector3(sin(theta)*p.x,p.y,cos(theta)*p.x))
    if (points[2]-points[0]).cross(points[1]-points[0]).dot(normal)<0:points.reverse()
    for p in points:tool.set_normal(normal);tool.add_vertex(p)
 return tool.commit()

static func spur_corners(serial:int)->Array:
 var quad:Array=Data.WALL_SPURS[serial][1];var points=[]
 for i in 4:
  var pixel:Vector2=quad[i];var foot:Vector2=quad[1 if i<2 else 2]
  var base=Vector3((foot.y/Fit.FLOOR+foot.x/Fit.HORIZONTAL)*.5,0,(foot.y/Fit.FLOOR-foot.x/Fit.HORIZONTAL)*.5)
  var x=base.x if serial==10640 else base.z+pixel.x/Fit.HORIZONTAL
  var z=x-pixel.x/Fit.HORIZONTAL if serial==10640 else base.z
  points.append(Vector3(x,maxf(0,((x+z)*Fit.FLOOR-pixel.y)/Fit.VERTICAL),z))
 return points

static func wall_foundation(root:Node3D,serial:int,base:Material):
 var row:Array=WALL_PROFILES[serial];var width:float=row[0];var knee:float=row[1];var bottom:float=row[2];var neck:float=row[3];var thick:float=row[5]
 var frame:Transform3D=WALL_FRAMES[serial];var turn=Basis(Vector3.UP,PI*.5 if serial==10641 else 0.0)
 var corners=spur_corners(serial).map(func(p):return turn.inverse()*(frame.affine_inverse()*p))
 var height:float=corners[0].y;var clearance=.02/frame.basis.x.x
 var cut_floor=minf(bottom,corners[1].z-clearance);var cut_top=minf(lerpf(bottom,neck,height/knee),corners[0].z-clearance)
 assert(cut_floor>bottom-thick+.01,"The spur channel must retain a closed stone backing")
 var leading=bottom-cut_floor+.25/frame.basis.x.x;var trailing=.03/frame.basis.x.x
 var lo=minf(corners[1].x,corners[2].x)-(leading if serial==10641 else trailing)
 var hi=maxf(corners[1].x,corners[2].x)+(leading if serial==10640 else trailing)
 for piece in [[-width*.5,lo,false],[lo-.002,hi+.002,true],[hi,width*.5,false]]:
  var profile=PackedVector2Array([Vector2(bottom-thick,0),Vector2(cut_floor,0),Vector2(cut_top,height),Vector2(neck,knee),Vector2(neck-thick,knee)]) if piece[2] else PackedVector2Array([Vector2(bottom-thick,0),Vector2(bottom,0),Vector2(neck,knee),Vector2(neck-thick,knee)])
  profile.reverse();var body=Geo.mesh(root,Shapes.extrude(profile,piece[1]-piece[0]),turn*Vector3((piece[0]+piece[1])*.5,0,0),base)
  body.basis=turn*Basis(Vector3.BACK,Vector3.UP,Vector3.LEFT);body.set_meta("falan_fort_feature","base")

static func wall_spur(serial:int)->Mesh:
 var corners=spur_corners(serial);var normal=Vector3.BACK if serial==10640 else Vector3.RIGHT
 var lower=[corners[1],corners[2],corners[2]-normal*.10,corners[1]-normal*.10]
 var upper=[corners[0],corners[3],corners[3]-normal*.10,corners[0]-normal*.10]
 if serial==10641:lower.reverse();upper.reverse()
 var body=pier_loft(lower,upper,INF);var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var arrays=body.surface_get_arrays(0);var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 for i in vs.size():tool.set_normal(ns[i]);tool.set_uv(Vector2(vs[i].x+vs[i].z,-vs[i].y)/2);tool.set_color(Color.WHITE);tool.add_vertex(vs[i])
 var ends=SurfaceTool.new();ends.begin(Mesh.PRIMITIVE_TRIANGLES);var end_controls=[]
 var ray=Vector3(1,2*Fit.FLOOR/Fit.VERTICAL,1)
 for row in Data.SPUR_ENDS[serial]:
  var region:Rect2=row[0];var top=[];var uvs=[Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)]
  for pixel:Vector2 in row[1]:
   var along=(pixel.y+row[2]*Fit.VERTICAL)/Fit.FLOOR;var across=pixel.x/Fit.HORIZONTAL
   top.append(Vector3((along+across)*.5,row[2],(along-across)*.5))
  if (top[2]-top[0]).cross(top[1]-top[0]).y<0:top.reverse();uvs.reverse()
  var bottom=top.map(func(p):return p-Vector3.UP*row[3]);var ring=top.duplicate();ring.reverse();var end_lower=bottom.duplicate();end_lower.reverse()
  var end_arrays=pier_loft(end_lower,ring,INF).surface_get_arrays(0);var end_vs:PackedVector3Array=end_arrays[Mesh.ARRAY_VERTEX];var end_ns:PackedVector3Array=end_arrays[Mesh.ARRAY_NORMAL]
  for i in end_vs.size():tool.set_normal(end_ns[i]);tool.set_uv(Vector2(end_vs[i].x+end_vs[i].z,-end_vs[i].y)/2);tool.set_color(Color.WHITE);tool.add_vertex(end_vs[i])
  detail_quad(ends,top.map(func(p):return p+ray*.001),uvs.map(func(uv):return (region.position+uv*region.size)/Vector2(SpurEndPaint.get_size())))
  for side in 2:
   var face=[];var face_uv=[Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)];var side_region:Rect2=row[4][side][0]
   for pixel:Vector2 in row[4][side][1]:
    var height:float=row[2] if face.size() in [0,3] else row[2]-row[3]
    var along=(pixel.y+height*Fit.VERTICAL)/Fit.FLOOR;var across=pixel.x/Fit.HORIZONTAL
    face.append(Vector3((along+across)*.5,height,(along-across)*.5))
   if (face[2]-face[0]).cross(face[1]-face[0]).dot(ray)<0:face.reverse();face_uv.reverse()
   detail_quad(ends,face.map(func(p):return p+ray*.001),face_uv.map(func(uv):return (side_region.position+uv*side_region.size)/Vector2(SpurEndPaint.get_size())))
  end_controls.append({"top":top,"bottom":bottom})
 var result=tool.commit();result.surface_set_material(0,stone_paint)
 var paint=SurfaceTool.new();paint.begin(Mesh.PRIMITIVE_TRIANGLES);var region:Rect2=Data.WALL_SPURS[serial][0]
 var order=[0,3,2,1] if serial==10640 else [0,1,2,3];var uv=[Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)]
 detail_quad(paint,order.map(func(i):return corners[i]+ray*.001),order.map(func(i):return (region.position+uv[i]*region.size)/Vector2(WallSpurPaint.get_size())))
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint.commit().surface_get_arrays(0));result.surface_set_material(1,Paint.material(WallSpurPaint))
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,ends.commit().surface_get_arrays(0));result.surface_set_material(2,Paint.material(SpurEndPaint));result.set_meta("falan_spur_ends",end_controls)
 result.set_meta("falan_spur_back",[corners[0]-normal*.10,corners[1]-normal*.10,corners[2]-normal*.10,corners[3]-normal*.10])
 return result

static func raw(serial:int)->Mesh:
 var root=Node3D.new();var boxes=Court.Boxes.new();var gate_planes={}
 var masonry_tone=Color("c1b59a")
 var stone=Court.Fort.material(masonry_tone);var trim=Court.Fort.material(Color("e0d5b8"),false)
 var base=Court.Fort.material(Color("888675"));var dark=Court.Fort.material(Color("39443e"),false)
 var quoin=Court.Fort.material(Color("9d6344"),false)
 if serial in [10640,10641]:
  var row:Array=WALL_PROFILES[serial];var width:float=row[0];var knee:float=row[1];var bottom:float=row[2];var neck:float=row[3];var top:float=row[4];var thick:float=row[5];var gap:float=row[7]
  wall_foundation(root,serial,base)
  for piece in [[PackedVector2Array([Vector2(neck-thick,knee),Vector2(neck,knee),Vector2(top,15.1),Vector2(top-thick,15.1)]),stone]]:
   var profile:PackedVector2Array=piece[0];profile.reverse() # The shared extrusion expects clockwise solid outlines.
   var body=Geo.mesh(root,Shapes.extrude(profile,width),Vector3.ZERO,piece[1])
   if piece[1]==base:body.set_meta("falan_fort_feature","base")
   body.basis=Basis(Vector3.BACK,Vector3.UP,Vector3.LEFT)
   if serial==10641:body.rotate_y(PI*.5)
  var rotated=serial==10641
  var turn=Basis(Vector3.UP,PI*.5 if rotated else 0.0)
  for band in [[knee,.25,neck-.1,thick+.3],[14.65,.25,top-.6,gap+.3],[15.25,.30,top-gap*.5+.25,gap+1.30]]:
   Court.part(boxes,Vector3.ZERO,rotated,Vector3(0,band[0],band[2]),Vector3(width+.1,band[1],band[3]),trim)
  var walk=Geo.box(root,turn*Vector3(0,15.44,top-gap*.5),Vector3(width,.08,gap-.6) if not rotated else Vector3(gap-.6,.08,width),base)
  walk.set_meta("falan_fort_paving_top",true)
  wall_crowns(root,serial,trim)
 elif serial in range(10642,10646):pier(root,serial,stone,trim,base,dark)
 elif serial in [10646,10662]:
  var rotated=serial==10646;var gallery=Node3D.new();root.add_child(gallery);gallery.position=Vector3(-3,0,-3)
  if rotated:gallery.basis=Basis(Vector3.BACK,Vector3.UP,Vector3.RIGHT);gallery.position.x=-3.28125
  var length_=12.355 if rotated else 15.335;var depth=3.125 if rotated else 6.7492
  var floor_y=18.5
  var post_height=floor_y-147.42/Fit.VERTICAL if rotated else 4.3354;var block_size=1.1;var block_count=5 if rotated else 0
  var fore_return=.84375
  var cut=INF if rotated else (length_-depth)*.5
  var walk_length=8.6 if rotated else length_
  var beam=gallery_box(gallery,Vector3(0,floor_y-.18,0),Vector3(walk_length,.36,depth),stone,cut)
  beam.set_meta("falan_gate_beam",true);beam.set_meta("falan_fort_paving_top",true)
  if rotated:
   for side in [-1,1]:
    var end_length=(length_-walk_length)*.5
    var landing=south_return(gallery,Vector3(side*(walk_length+end_length)*.5,floor_y+.97,0),Vector3(end_length,.36,depth),stone) if side<0 else gallery_box(gallery,Vector3(side*(walk_length+end_length)*.5,floor_y+.97,0),Vector3(end_length,.36,depth),stone)
    landing.set_meta("falan_gate_beam",true);landing.set_meta("falan_fort_paving_top",true)
    gallery_box(gallery,Vector3(side*(walk_length*.5+.11),floor_y+.395,0),Vector3(.22,1.51,depth-.4),stone)
  for side in [-1,1]:
   var z=side*(depth*.5-.25)
   var wall_height=(1.15 if side>0 else .55) if rotated else .710
   var wall_z=z-side*.25 if rotated else z
   var wall_length=walk_length;var wall_x=0.0
   if not rotated and side>0:
    wall_z=(WEST_EAST_FRONT-WEST_EAST_FRAME.origin.z)/WEST_EAST_FRAME.basis.z.z-gallery.position.z
    var end_x=(2.03125-WEST_EAST_FRAME.origin.x)/WEST_EAST_FRAME.basis.x.x-gallery.position.x+.44
    wall_length=end_x+length_*.5;wall_x=(end_x-length_*.5)*.5
   gallery_box(gallery,Vector3(wall_x,floor_y+wall_height*.5,wall_z),Vector3(wall_length,wall_height,.5),stone,cut)
   gallery_coping(gallery,Vector3(wall_x,floor_y+wall_height+.08,wall_z),Vector3(wall_length+.12,.16,.64),trim,cut)
   for i in block_count:
    if rotated and side>0 and i in [0,4]:continue
    var x=(float(i)-(block_count-1)*.5)*(10.5 if rotated else length_-block_size)/(block_count-1)
    var cap_height=(1.0 if side>0 else .85) if rotated else block_size;var cap_depth=(1.0 if side>0 else .8) if rotated else block_size
    var at=Vector3(x,floor_y+wall_height+.16+cap_height*.5,z);var cap:MeshInstance3D
    if is_inf(cut) or x-z-block_size>=-cut:
     cap=Geo.mesh(gallery,merlon(),at,trim);cap.scale=Vector3(block_size/1.18,cap_height/.76,cap_depth/1.18)
    else:cap=gallery_box(gallery,at,Vector3.ONE*block_size,trim,cut)
    if cap!=null:
     if rotated:
      var pixel:Vector2=SOUTH_CROWN_TOPS[side][i-1 if side>0 else i]+Data.PARTS[serial][1].position
      var top_y=22.025 if side>0 else 20.025;var along=(pixel.y+top_y*Fit.VERTICAL)/Fit.FLOOR
      cap.position=gallery.transform.affine_inverse()*Vector3((along+pixel.x/Fit.HORIZONTAL)*.5,top_y-cap_height*.5,(along-pixel.x/Fit.HORIZONTAL)*.5)
      cap.scale.x=(1.1 if side>0 else .8)/1.18
     cap.set_meta("falan_crown_block",true)
   if not rotated:
    for x in [-length_*.5+.3,length_*.5-.3]:
     var at_x=x;var height=post_height;var width=.6;var depth_=.64
     if side>0 and x>0:
      width=.88;depth_=.76;at_x=(2.03125-WEST_EAST_FRAME.origin.x)/WEST_EAST_FRAME.basis.x.x-gallery.position.x
      var maximum_sum=2.03125+WEST_EAST_FRONT+(width+depth_)*WEST_EAST_FRAME.basis.x.x*.5
      var bottom=(301+maximum_sum*Fit.FLOOR-172)/Fit.VERTICAL
      height=(WEST_EAST_FRAME.origin.y+WEST_EAST_FRAME.basis.y.y*floor_y-bottom)/WEST_EAST_FRAME.basis.y.y
     gallery_box(gallery,Vector3(at_x,floor_y-height*.5,wall_z),Vector3(width,height,depth_),stone,cut)
  if not rotated:west_east_crowns(root,trim)
  ironwork(root,serial)
  if rotated:
   for x in [-length_*.5+.3,length_*.5-.3]:
    south_return(gallery,Vector3(x,floor_y+1.04,fore_return*.5),Vector3(.6,.22,depth+fore_return),stone) if x<0 else Geo.box(gallery,Vector3(x,floor_y+1.04,fore_return*.5),Vector3(.6,.22,depth+fore_return),stone)
    gallery_coping(gallery,Vector3(x,(19.1+SOUTH_COPING_TOP)*.5,fore_return*.5),Vector3(.75,SOUTH_COPING_TOP-19.1,depth+fore_return+.12),trim,INF,true) if x<0 else gallery_coping(gallery,Vector3(x,floor_y+1.23,fore_return*.5),Vector3(.75,.16,depth+fore_return+.12),trim)
    var at_x=5.45 if x>0 else x+.2
    var native_height=post_height+1.15+(.62/Fit.VERTICAL if x>0 else 1.25)
    var pier_z=depth*.5+fore_return-.32
    if x>0:
     var pier_cut=gallery.position.x-gallery.position.z-(SOUTH_WINDOW_MIN_U+Data.PARTS[serial][1].position.x)/Fit.HORIZONTAL
     var old_edge=Fit.project(gallery.transform*Vector3(at_x+.65,0,pier_z+.32)).x-Data.PARTS[serial][1].position.x
     native_height+=(SOUTH_WINDOW_MIN_U-old_edge)*Fit.FLOOR/(Fit.HORIZONTAL*Fit.VERTICAL)
     var lower=pier_ring(1.3,.64,floor_y+1.15-native_height,pier_z);var upper=pier_ring(1.3,.64,floor_y+1.15,pier_z)
     for ring in [lower,upper]:
      for i in ring.size():ring[i].x+=at_x
     # The native jamb starts at u=45; cut its hidden outer corner without thinning the solid pier.
     Geo.mesh(gallery,pier_loft(lower,upper,pier_cut),Vector3.ZERO,stone).set_meta("falan_fort_feature","base")
    else:south_corbel(root,stone)
    if x<0:
     var return_height=floor_y+1.15-SOUTH_RETURN_BOTTOM
     south_return(gallery,Vector3(x,SOUTH_RETURN_BOTTOM+return_height*.5,fore_return*.5),Vector3(.6,return_height,depth+fore_return),stone).set_meta("falan_fort_feature","base")
    for side in [-1,1]:
     var end_length=(length_-walk_length)*.5;var overlap=.04 if x<0 else 0.0
     var coping_top=SOUTH_COPING_TOP if x<0 else floor_y+1.31;var coping_height=coping_top-floor_y-1.15
     # Overlap the raised inner mitres while retaining the outside source footprint.
     gallery_coping(gallery,Vector3(signf(x)*(walk_length+end_length)*.5+overlap*.5,floor_y+1.15+coping_height*.5,side*(depth*.5-.25)),Vector3(end_length+overlap,coping_height,.64),trim,INF,x<0)
   for i in [-1,0,1]:
    var x=i*2.25+.016
    Geo.box(gallery,Vector3(x,19.025,1.60),Vector3(1.35,4.2,.9),stone).set_meta("falan_fort_feature","base")
    gallery_coping(gallery,Vector3(x,21.14,1.70),Vector3(1.5,.22,1.0),trim)
   for side in [-1,1]:
    var top=Vector3(side*4.875,(255.97 if side>0 else 257.97)/Fit.VERTICAL-.12,.1875)
    Geo.box(gallery,Vector3(top.x,19.2,top.z),Vector3(.5,1.4,.5),Court.Fort.material(Color("b5a376"),false))
    Geo.beam(gallery,Vector3(top.x,19.9,top.z),top,.032,trim)
    for size_ in [Vector3(.15,.035,.035),Vector3(.035,.24,.035),Vector3(.035,.035,.15)]:Geo.box(gallery,top,size_,Court.Fort.material(Color("b5a376"),false))
   # The native gold and blue cloth strips are adjacent on the same front face, not opposite parapets.
   for cloth in [[0.0,1.65,"banner"],[-1.5,1.35,"blue_banner"]]:
    for side in [-1,1]:
     var banner=QuadMesh.new();banner.size=Vector2(cloth[1],2.1)
     var panel=Geo.mesh(gallery,banner,Vector3(cloth[0],floor_y-.60,depth*.5+.035+side*.075),null)
     panel.rotation.y=0 if side>0 else PI;panel.set_meta("falan_fort_feature",cloth[2])
   for feature in ["gate_window","gate_badge"]:
    var detail=QuadMesh.new();detail.size=Vector2(.7,1.1)
    Geo.mesh(gallery,detail,Vector3(0,floor_y+.3,0),null).set_meta("falan_fort_feature",feature)
   Geo.beam(gallery,Vector3(-1.996875,18.5,.58125),Vector3(-1.996875,19.3,.58125),.025,dark)
   gate_planes={"banner":-1.18,"blue_banner":-1.18,"gate_window":-.863,"gate_badge":-2.7}
   var badge=[];var ray=Vector3(1,2*Fit.FLOOR/Fit.VERTICAL,1)
   for pixel_:Vector2 in GATE_QUADS.gate_badge:
    var pixel=pixel_+Data.PARTS[serial][1].position;var x:float=gate_planes.gate_badge+.012;var z=x-pixel.x/Fit.HORIZONTAL
    badge.append(Vector3(x,((x+z)*Fit.FLOOR-pixel.y)/Fit.VERTICAL,z)-ray*.004)
   # The original small emblem needs a closed back; its thickness projects along the source camera ray.
   var badge_mesh=pier_loft([badge[1],badge[2],badge[2]-ray*.116,badge[1]-ray*.116],[badge[0],badge[3],badge[3]-ray*.116,badge[0]-ray*.116],INF)
   Geo.mesh(root,badge_mesh,Vector3.ZERO,dark)
 elif serial in range(10655,10661):
  if round_tooth==null:
   var cap=SurfaceTool.new();cap.begin(Mesh.PRIMITIVE_TRIANGLES)
   cap.append_from(merlon(),0,Transform3D(Basis.IDENTITY.scaled(Vector3(1.20/1.18,.85/.76,.84/1.18)),Vector3(0,.425,2.53)))
   round_tooth=cap.commit()
  if round_rim==null:round_rim=crown_sector(2.18,2.95,1.05)
  if round_course==null:round_course=crown_sector(2.85,3.02,.10)
  if round_base_band==null:
   round_base_band=CylinderMesh.new();round_base_band.top_radius=1;round_base_band.bottom_radius=1;round_base_band.height=.06;round_base_band.radial_segments=64;round_base_band.rings=0
  for part in Assets.source("res://assets/models/environments/wind_meadow/buildings/round_gate_tower.tscn"):
   if part.material is StandardMaterial3D:continue
   if part.name in ["Coping","Footing"] or part.name.begins_with("Merlon"):continue
   if part.name=="Shaft":
    if round_shaft==null:
     round_shaft=CylinderMesh.new();round_shaft.top_radius=ROUND_RADIUS;round_shaft.bottom_radius=ROUND_RADIUS;round_shaft.height=17-ROUND_FLARE_TOP;round_shaft.radial_segments=64;round_shaft.rings=0
     round_flare=CylinderMesh.new();round_flare.top_radius=ROUND_RADIUS;round_flare.bottom_radius=ROUND_FOOTING_RADIUS;round_flare.height=ROUND_FLARE_TOP-ROUND_FOOTING_HEIGHT;round_flare.radial_segments=64;round_flare.rings=0
    Geo.mesh(root,round_shaft,ROUND_CENTER+Vector3.UP*((17+ROUND_FLARE_TOP)*.5),stone)
    Geo.mesh(root,round_flare,ROUND_CENTER+Vector3.UP*((ROUND_FLARE_TOP+ROUND_FOOTING_HEIGHT)*.5),stone)
   else:
    var node=Geo.mesh(root,part.mesh,Vector3.ZERO,part.material);node.transform=part.transform
  Geo.mesh(root,round_rim,Vector3.UP*16.94,trim)
  for y in [17.05,17.34,17.63]:Geo.mesh(root,round_course,Vector3.UP*y,Court.Fort.material(Color("b5a376"),false))
  var paving=Geo.cylinder(root,Vector3.UP*17.08,2.20,.14,base);paving.mesh.radial_segments=64;paving.set_meta("falan_fort_feature","paving")
  for i in 10:
   var block=Geo.mesh(root,round_tooth,Vector3.UP*17.99,trim);block.rotation.y=i*TAU/10;block.set_meta("falan_crown_block",true)
  var base_course=Court.Fort.material(Color("a89565"),false)
  var plinth=Geo.cylinder(root,ROUND_CENTER+Vector3(ROUND_SETBACK*.5,ROUND_FOOTING_HEIGHT*.5,ROUND_SETBACK*.5),ROUND_BASE_RADIUS,ROUND_FOOTING_HEIGHT,base_course,false,ROUND_FOOTING_RADIUS);plinth.mesh.radial_segments=64;plinth.mesh.rings=0
  plinth.set_meta("falan_fort_feature","base")
  plinth.basis=Basis(Vector3.RIGHT,Vector3(-ROUND_SETBACK/ROUND_FOOTING_HEIGHT,1,-ROUND_SETBACK/ROUND_FOOTING_HEIGHT),Vector3.BACK)
  for y in [.14,.55,.96,1.37,1.78,2.19,2.60,3.01,3.42,3.83,4.24,4.55]:
   var setback=lerpf(ROUND_SETBACK,0,y/ROUND_FOOTING_HEIGHT);var ring=Geo.mesh(root,round_base_band,ROUND_CENTER+Vector3(setback,y,setback),base_course);var radius=lerpf(ROUND_BASE_RADIUS,ROUND_FOOTING_RADIUS,y/ROUND_FOOTING_HEIGHT)+.018;ring.scale=Vector3(radius,1,radius)
 else:
  Court.castle_tower(root,boxes,Vector3.ZERO,9,17.5,stone,trim,quoin,dark,base,merlon())
  var lower=pier_ring(12.4,12.4,0,-1.25).map(func(p):return p+Vector3(-1.25,0,0))
  Geo.mesh(root,pier_loft(lower,pier_ring(9,9,SQUARE_FOUNDATION_HEIGHT,0),INF),Vector3.ZERO,base).set_meta("falan_fort_feature","base")
 boxes.build(root,true)
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var crown_points=[];var crown_feet:Array[Vector3]=[];var crown_vertices:Array[Vector3]=[];var iron_spikes=0;var iron_tips:Array[Vector3]=[];var beam_bounds=AABB()
 var features={};var lancet=load(Court.Keep.CIVIC_ART).lancet()
 for node in root.find_children("*","MeshInstance3D",true,false):
  var pose=node.transform;var parent=node.get_parent()
  while parent!=root:pose=parent.transform*pose;parent=parent.get_parent()
  if node.has_meta("falan_gate_beam"):
   var bounds=pose*node.mesh.get_aabb();beam_bounds=beam_bounds.merge(bounds) if beam_bounds.has_volume() else bounds
  if node.has_meta("falan_iron_spike"):
   iron_spikes+=1
   if node.has_meta("falan_iron_tip"):iron_tips.append(pose*node.get_meta("falan_iron_tip"))
  if node.has_meta("falan_crown_block"):
   var bounds=node.mesh.get_aabb();crown_points.append(pose*Vector3(bounds.get_center().x,bounds.end.y,bounds.get_center().z))
   crown_vertices.append_array(Fit.mesh_points(node.mesh,pose))
   var foot=Vector3.ZERO;var count=0
   for p:Vector3 in Fit.mesh_points(node.mesh):
    if absf(p.y-bounds.position.y)<.0001:foot+=p;count+=1
   crown_feet.append(pose*(foot/count))
  for part in node.mesh.get_surface_count():
   # Explicitly share a vertex format: append_from resets earlier geometry when box UVs differ from profiles.
   var arrays=node.mesh.surface_get_arrays(part);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices=arrays[Mesh.ARRAY_INDEX]
   var paint=node.get_active_material(part);var tint=Color.WHITE
   var feature:String=node.get_meta("falan_fort_feature","")
   if paint is ShaderMaterial and paint.shader==Court.Fort.SHADER:
    var native:Color=paint.get_shader_parameter("stone_color")
    tint=Color(minf(native.r/masonry_tone.r,1.0),minf(native.g/masonry_tone.g,1.0),minf(native.b/masonry_tone.b,1.0))
    if node.mesh==lancet and native.is_equal_approx(Color("394547")):feature="window"
   elif paint is StandardMaterial3D:tint=paint.albedo_color
   var normal_pose=pose.basis.inverse().transposed()
   var order=(indices if indices!=null and not indices.is_empty() else range(vertices.size())).duplicate()
   if pose.basis.determinant()<0:
    for i in range(0,order.size(),3):var saved=order[i+1];order[i+1]=order[i+2];order[i+2]=saved
   for i in order:
    var n=(normal_pose*normals[i]).normalized();var p:Vector3=pose*vertices[i];var axis=n.abs()
    var uv=Vector2(p.x,p.z) if axis.y>maxf(axis.x,axis.z) else Vector2(p.z,-p.y) if axis.x>axis.z else Vector2(p.x,-p.y)
    var layer=feature
    if layer.is_empty() and n.y>.99 and node.get_meta("falan_fort_paving_top",false):layer="paving"
    var target=tool
    if not layer.is_empty():
     if not features.has(layer):features[layer]=SurfaceTool.new();features[layer].begin(Mesh.PRIMITIVE_TRIANGLES)
     target=features[layer]
    var vertex_tint=tint
    if (node.mesh in [square_tooth,round_tooth] or node.has_meta("falan_crown_block")) and arrays[Mesh.ARRAY_COLOR]!=null:vertex_tint*=arrays[Mesh.ARRAY_COLOR][i]
    target.set_normal(n);target.set_uv(uv/2.0 if layer.is_empty() or layer in ["paving","base"] else arrays[Mesh.ARRAY_TEX_UV][i]);target.set_color(vertex_tint if layer.is_empty() else Color.WHITE);target.add_vertex(p)
 var result=tool.commit();root.free()
 if stone_paint==null:
  stone_paint=Paint.material(Masonry).duplicate();stone_paint.set_shader_parameter("use_vertex_color",true);stone_paint.set_shader_parameter("vertex_color_srgb",true);stone_paint.set_shader_parameter("alpha_cutout",false);stone_paint.set_shader_parameter("original_palette",false)
 result.surface_set_material(0,stone_paint)
 for feature in features:
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,features[feature].commit().surface_get_arrays(0))
  var texture:Texture2D={"base":BasePaint,"window":WindowPaint,"gate_window":GateWindowPaint,"gate_badge":GateBadgePaint,"banner":BannerPaint,"blue_banner":BlueBannerPaint,"leaf":LeafPaint,"leaf_front":LeafFrontPaint,"paving":GatePaving if serial in [10646,10662] else PavingPaint}[feature]
  if feature=="base":
   if base_paint==null:
    base_paint=Paint.material(texture).duplicate();base_paint.set_shader_parameter("original_palette",false);base_paint.set_shader_parameter("alpha_cutout",false)
   result.surface_set_material(result.get_surface_count()-1,base_paint)
  else:result.surface_set_material(result.get_surface_count()-1,Paint.material(texture))
 result.set_meta("falan_crown_points",crown_points)
 result.set_meta("falan_crown_feet",crown_feet)
 result.set_meta("falan_crown_vertices",crown_vertices)
 result.set_meta("falan_wall_slab_volume",WALL_PROFILES[serial][0]*WALL_PROFILES[serial][5]*15.1 if WALL_PROFILES.has(serial) else 0.0)
 result.set_meta("falan_iron_spikes",iron_spikes)
 result.set_meta("falan_iron_tips",iron_tips)
 result.set_meta("falan_gate_beam",beam_bounds)
 result.set_meta("falan_gate_detail_planes",gate_planes)
 return result

static func square_windows(serial:int,pose:Transform3D)->Mesh:
 var stone=SurfaceTool.new();stone.begin(Mesh.PRIMITIVE_TRIANGLES)
 var paint=SurfaceTool.new();paint.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in Data.WINDOWS[serial]:
  var normal=Vector3.RIGHT if row[0] else Vector3.BACK;var quad:Array=row[3];var region:Rect2=row[2]
  var plane=(pose*(normal*4.5)).dot(normal)+.03;var corners=[]
  for pixel:Vector2 in quad:
   var x=plane if row[0] else plane+pixel.x/Fit.HORIZONTAL;var z=plane-pixel.x/Fit.HORIZONTAL if row[0] else plane
   corners.append(Vector3(x,((x+z)*Fit.FLOOR-pixel.y)/Fit.VERTICAL,z))
  var front=Transform3D(Basis(corners[2]-corners[1],corners[0]-corners[1],normal),(corners[1]+corners[2])*.5)
  var outline=PackedVector2Array()
  if row[1]:
   for p:Vector3 in Shapes.LANCET:outline.append(Vector2(p.x,p.y))
   if window_arch==null:window_arch=Shapes.extrude(outline,.16)
  else:
   outline=PackedVector2Array([Vector2(-.5,0),Vector2(-.5,1),Vector2(.5,1),Vector2(.5,0)])
   if window_shutter==null:window_shutter=Shapes.extrude(outline,.16)
  var body=window_arch if row[1] else window_shutter;var arrays=body.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var triangles=Geometry2D.triangulate_polygon(outline)
  # shortcut: unseen opposite windows repeat their source face; replace only when rear artwork is recovered.
  for rear in [false,true]:
   var face=front
   if rear:
    var turn=Basis(Vector3.UP,PI);face=Transform3D(turn,pose.origin-turn*pose.origin)*front
   var frame=face*Transform3D(Basis.IDENTITY.scaled(Vector3(1.12,1.06,1)),Vector3(0,-.03,-.098));var normal_pose=frame.basis.inverse().transposed()
   for i in vertices.size():
    var p:Vector3=frame*vertices[i];var n:Vector3=(normal_pose*normals[i]).normalized();var axis=n.abs()
    var uv=Vector2(p.x,p.z) if axis.y>maxf(axis.x,axis.z) else Vector2(p.z,-p.y) if axis.x>axis.z else Vector2(p.x,-p.y)
    stone.set_normal(n);stone.set_uv(uv/2);stone.set_color(Color.WHITE);stone.add_vertex(p)
   for i in range(0,triangles.size(),3):
    var a:Vector2=outline[triangles[i]];var b:Vector2=outline[triangles[i+1]];var c:Vector2=outline[triangles[i+2]]
    if (b-a).cross(c-a)>0:var swap=b;b=c;c=swap
    for p in [a,b,c]:
     var uv=(region.position+Vector2(p.x+.5,1-p.y)*region.size)/Vector2(WindowDetails.get_size())
     paint.set_normal(face.basis.z);paint.set_uv(uv);paint.set_color(Color.WHITE);paint.add_vertex(face*Vector3(p.x,p.y,0))
 var result=stone.commit();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint.commit().surface_get_arrays(0));result.surface_set_material(1,Paint.material(WindowDetails))
 return result

static func hood_point(serial:int,pixel:Vector2,plane:float)->Vector3:
 var x=plane if serial==10656 else plane+pixel.x/Fit.HORIZONTAL
 var z=plane-pixel.x/Fit.HORIZONTAL if serial==10656 else plane
 return Vector3(x,((x+z)*Fit.FLOOR-pixel.y)/Fit.VERTICAL,z)

static func tower_braces(serial:int)->Mesh:
 var square=serial<10655;var edge:Array=SQUARE_BRACE_EDGE if square else ROUND_BRACE_EDGE
 var plane=(edge[-1].y-.75*edge[-1].x)/16.0
 var step=Vector3(.234375,0,-2.484375) if square else Vector3(0,0,-2.25)
 var cap_pixel=Vector2(27,-114) if square else Vector2(33,-114)
 var cap_top=hood_point(10655,cap_pixel,plane);var outline=PackedVector2Array()
 var ring=edge.duplicate()
 for i in range(edge.size()-1,-1,-1):ring.append(edge[i]-Vector2(6,4.5))
 for pixel:Vector2 in ring:
  var p=hood_point(10655,pixel,plane);outline.append(Vector2(p.x,p.y))
 var fin=Shapes.extrude(outline,.20);var pieces=[];var heads=[];var controls=[]
 # shortcut: one source view fixes the contour, not depth; revisit this lean if a second view is recovered.
 var ray=Vector3(1,2*Fit.FLOOR/Fit.VERTICAL,1)
 var lean=Transform3D(Basis(Vector3.RIGHT,Vector3.UP-ray*.06,Vector3.BACK),Vector3.ZERO)
 for side in BRACE_SIDES[serial]:
  # Native tower art is symmetric about u=1, including the paired rib rows.
  var mirror=Transform3D.IDENTITY if side>0 else Transform3D(Basis(Vector3.BACK,Vector3.UP,Vector3.RIGHT),Vector3(.09375,0,-.09375))
  for offset in [Vector3.ZERO,step]:
   pieces.append([fin,lean*mirror*Transform3D(Basis.IDENTITY,Vector3(0,0,plane-.10)+offset)])
   var top=cap_top+offset;var at=top-Vector3.UP*.38
   pieces.append([merlon(),lean*mirror*Transform3D(Basis.IDENTITY.scaled(Vector3(.52,1,.52)),at)])
   heads.append(lean*mirror*top)
   for pixel:Vector2 in edge:controls.append(lean*mirror*(hood_point(10655,pixel,plane)+offset))
  var top_y=hood_point(10655,edge[0],plane).y
  var inner=2.65 if square else 3.0;var outer=cap_top.x+.30
  var lower=[Vector3(inner,top_y,plane+step.z-.25),Vector3(inner,top_y,plane+.12),Vector3(outer,top_y,plane+.12),Vector3(outer+step.x,top_y,plane+step.z-.25)]
  pieces.append([pier_loft(lower,lower.map(func(p):return p+Vector3.UP*.20),INF),lean*mirror])
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for piece in pieces:
  var mesh:Mesh=piece[0];var pose:Transform3D=piece[1];var arrays=mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var colors=arrays[Mesh.ARRAY_COLOR];var indices=arrays[Mesh.ARRAY_INDEX]
  var order=(indices if indices!=null and not indices.is_empty() else range(vertices.size())).duplicate()
  if pose.basis.determinant()<0:
   for i in range(0,order.size(),3):var swap=order[i+1];order[i+1]=order[i+2];order[i+2]=swap
  var normal_pose=pose.basis.inverse().transposed()
  for i in order:
   var p:Vector3=pose*vertices[i];var n:Vector3=(normal_pose*normals[i]).normalized();var axis=n.abs()
   var uv=Vector2(p.x,p.z) if axis.y>maxf(axis.x,axis.z) else Vector2(p.z,-p.y) if axis.x>axis.z else Vector2(p.x,-p.y)
   tool.set_normal(n);tool.set_uv(uv/2);tool.set_color(colors[i] if colors!=null else Color.WHITE);tool.add_vertex(p)
 var result=tool.commit();result.set_meta("falan_brace_caps",heads);result.set_meta("falan_brace_controls",controls)
 return result

static func round_hood(serial:int)->Mesh:
 var data:Array=Data.HOODS[serial];var crop:Rect2=data[2]
 var turn=Basis(Vector3.UP,PI*.5 if serial==10656 else 0.0);var normal=turn.z
 var ray=Vector3(1,2*Fit.FLOOR/Fit.VERTICAL,1)
 var stone=SurfaceTool.new();stone.begin(Mesh.PRIMITIVE_TRIANGLES)
 var paint=SurfaceTool.new();paint.begin(Mesh.PRIMITIVE_TRIANGLES)
 for feature in 2:
  var plane=4.6 if feature==0 else 4.25;var depth=.5625 if feature==0 else .28
  var outline=PackedVector2Array()
  for pixel:Vector2 in data[feature]:
   var point=turn.inverse()*hood_point(serial,pixel,plane);outline.append(Vector2(point.x,point.y))
  var body=Shapes.extrude(outline,depth);var arrays=body.surface_get_arrays(0)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  for i in range(0,vertices.size(),3):
   var n:Vector3=turn*normals[i]
   var visible=n.dot(ray)>0.0001 if feature==0 else n.dot(normal)>.99
   for j in 3:
    # Seat the original hood outside the corrected shaft without moving its native silhouette.
    var p:Vector3=turn*vertices[i+j]+normal*(plane-depth*.5)+ray*.35
    var uv=Vector2(p.x,p.z) if absf(n.y)>.5 else Vector2(p.x+p.z,-p.y)
    stone.set_normal(n);stone.set_uv(uv/2);stone.set_color(Color("385f77") if feature==0 else Color("394547"));stone.add_vertex(p)
    if visible:
     # Only the small source-facing hood/window surfaces carry their own original drawing.
     paint.set_normal(n);paint.set_uv((Fit.project(p)-crop.position)/crop.size);paint.set_color(Color.WHITE);paint.add_vertex(p+ray*.002)
 var result=stone.commit();result.surface_set_material(0,stone_paint);result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint.commit().surface_get_arrays(0))
 result.surface_set_material(1,Paint.material(HoodLeft if serial==10655 else HoodRight))
 return result

static func round_surface(pixel:Vector2,pose:Transform3D,relief:float)->Vector3:
 var center=pose*ROUND_CENTER;var low=0.0;var high=17*pose.basis.y.y;var d=(pixel.x-Fit.project(center).x)/Fit.HORIZONTAL
 var radius=0.0;var setback=0.0;var along=0.0
 for i in 36:
  var y=(low+high)*.5;var raw_y=y/pose.basis.y.y
  radius=(ROUND_RADIUS if raw_y>=ROUND_FLARE_TOP else lerpf(ROUND_FOOTING_RADIUS,ROUND_RADIUS,(raw_y-ROUND_FOOTING_HEIGHT)/(ROUND_FLARE_TOP-ROUND_FOOTING_HEIGHT)) if raw_y>=ROUND_FOOTING_HEIGHT else lerpf(ROUND_BASE_RADIUS,ROUND_FOOTING_RADIUS,raw_y/ROUND_FOOTING_HEIGHT))*pose.basis.x.x+relief
  setback=lerpf(ROUND_SETBACK,0,raw_y/ROUND_FOOTING_HEIGHT)*pose.basis.x.x if raw_y<ROUND_FOOTING_HEIGHT else 0.0
  assert(2*radius*radius>=d*d,"Native detail must lie on the solid round shaft")
  along=sqrt(maxf(0,2*radius*radius-d*d))
  var v=(along+2*setback+center.x+center.z)*Fit.FLOOR-y*Fit.VERTICAL
  if v>pixel.y:low=y
  else:high=y
 return Vector3((along+d)*.5+setback+center.x,(low+high)*.5,(along-d)*.5+setback+center.z)

static func detail_quad(tool:SurfaceTool,points:Array,uvs:Array=[],tint:Color=Color.WHITE):
 for triangle in [[0,1,2],[0,2,3]]:
  var n:Vector3=(points[triangle[2]]-points[triangle[0]]).cross(points[triangle[1]]-points[triangle[0]])
  if n.length_squared()<.000000000001:continue
  for i in triangle:
   tool.set_normal(n.normalized());tool.set_color(tint)
   tool.set_uv(uvs[i] if not uvs.is_empty() else Vector2(points[i].x+points[i].z,-points[i].y)/2)
   tool.add_vertex(points[i])

static func lower_details(serial:int,pose:Transform3D)->Mesh:
 var square=Data.WINDOWS.has(serial);var family="square" if square else "round"
 var stone=SurfaceTool.new();stone.begin(Mesh.PRIMITIVE_TRIANGLES)
 var paint=SurfaceTool.new();paint.begin(Mesh.PRIMITIVE_TRIANGLES)
 var ray=Vector3(1,2*Fit.FLOOR/Fit.VERTICAL,1);var controls=[];var panes=0
 for rear in [false,true]:
  # shortcut: unseen openings repeat the source-facing row; revisit when original rear art is recovered.
  var turn=Basis(Vector3.UP,PI) if rear else Basis.IDENTITY
  var center=pose.origin if square else pose*ROUND_CENTER
  var transform_=Transform3D(turn,center-turn*center)
  for row in Data.LOWER_SLITS[family]:
   var region:Rect2=row[0];var quad:Array=row[1];var grid=[];var back=[];var rows=1 if square else 12
   var normal=Vector3.RIGHT if quad[0].x+quad[3].x>0 else Vector3.BACK
   var plane=(pose*(normal*4.5)).dot(normal)+.025
   for y in rows+1:
    var front_line=[];var back_line=[]
    for x in 2:
     var pixel:Vector2=quad[x*3].lerp(quad[1+x],float(y)/rows)
     var p=hood_point(10656 if normal==Vector3.RIGHT else 10655,pixel,plane) if square else round_surface(pixel,pose,.045)
     var n=normal if square else Vector3(p.x-pose.origin.x,0,p.z-pose.origin.z).normalized()
     front_line.append(transform_*p);back_line.append(transform_*(p-n*.10))
     if not rear and y in [0,rows]:controls.append(p)
    grid.append(front_line);back.append(back_line)
   for y in rows:
    var points=[grid[y][0],grid[y][1],grid[y+1][1],grid[y+1][0]]
    var uv=[Vector2(0,float(y)/rows),Vector2(1,float(y)/rows),Vector2(1,float(y+1)/rows),Vector2(0,float(y+1)/rows)]
    var atlas_uv=uv.map(func(p):return (region.position+p*region.size)/Vector2(ArrowDetails.get_size()))
    detail_quad(stone,points,[],Color("686b5d"));detail_quad(stone,[back[y][0],back[y+1][0],back[y+1][1],back[y][1]],[],Color("39443e"))
    detail_quad(paint,points.map(func(p):return p+turn*ray*.002),atlas_uv)
    detail_quad(stone,[grid[y][0],grid[y+1][0],back[y+1][0],back[y][0]],[],Color("686b5d"))
    detail_quad(stone,[grid[y][1],back[y][1],back[y+1][1],grid[y+1][1]],[],Color("686b5d"))
   detail_quad(stone,[grid[0][0],back[0][0],back[0][1],grid[0][1]],[],Color("686b5d"))
   detail_quad(stone,[grid[rows][0],grid[rows][1],back[rows][1],back[rows][0]],[],Color("686b5d"))
   panes+=1
  if not square:
   var region:Rect2=Data.ROUND_COURSE[0];var line:Array=Data.ROUND_COURSE[1]
   for i in line.size()-1:
    var steps=ceili(line[i+1].x-line[i].x)
    for j in steps:
     var a:Vector2=line[i].lerp(line[i+1],float(j)/steps);var b:Vector2=line[i].lerp(line[i+1],float(j+1)/steps)
     var pixels=[a+Vector2(0,-1.5),b+Vector2(0,-1.5),b+Vector2(0,2.5),a+Vector2(0,2.5)]
     var points=pixels.map(func(p):return transform_*round_surface(p,pose,.008)+turn*ray*.001)
     var uv=[Vector2((a.x-line[0].x)/(line[-1].x-line[0].x),0),Vector2((b.x-line[0].x)/(line[-1].x-line[0].x),0),Vector2((b.x-line[0].x)/(line[-1].x-line[0].x),1),Vector2((a.x-line[0].x)/(line[-1].x-line[0].x),1)]
     detail_quad(paint,points,uv.map(func(p):return (region.position+p*region.size)/Vector2(ArrowDetails.get_size())))
 if not square:
  var center=pose*ROUND_CENTER;var line:Array=Data.ROUND_COURSE[1]
  var a=round_surface(line[0],pose,.008);var b=round_surface(line[-1],pose,.008)
  # Close the unseen side joins with solid trim; only the recovered front/rear strips use original paint.
  for ends in [[a,center*2-b],[b,center*2-a]]:
   ends[1].y=(b.y if ends[0]==a else a.y)
   var begin=atan2(ends[0].x-center.x,ends[0].z-center.z);var delta=wrapf(atan2(ends[1].x-center.x,ends[1].z-center.z)-begin,-PI,PI)
   var radius=ROUND_RADIUS*pose.basis.x.x;var bridge=crown_sector(radius-.005,radius+.025,.045,absf(delta));var turn=Basis(Vector3.UP,begin+delta*.5)
   var vs:PackedVector3Array=bridge.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var points=[]
   for p:Vector3 in vs:
    var t=(atan2(p.x,p.z)+absf(delta)*.5)/absf(delta)
    var y=lerpf(ends[0].y,ends[1].y,t if delta>0 else 1-t)
    points.append(turn*p+Vector3(center.x,y-.0225,center.z))
   for i in range(0,points.size(),3):
    var n:Vector3=(points[i+2]-points[i]).cross(points[i+1]-points[i]).normalized()
    for j in 3:stone.set_normal(n);stone.set_color(Color("61594b"));stone.set_uv(Vector2(points[i+j].x+points[i+j].z,-points[i+j].y)/2);stone.add_vertex(points[i+j])
  for row in Data.ROUND_FEET:
   var region:Rect2=row[0];var top=[]
   for pixel:Vector2 in row[1]:
    var along=(pixel.y+Fit.VERTICAL)/Fit.FLOOR;var across=pixel.x/Fit.HORIZONTAL
    top.append(Vector3((along+across)*.5,1.0,(along-across)*.5))
   var ring=top.duplicate();ring.reverse();var foot=pier_loft(ring.map(func(p):return p-Vector3.UP*.45),ring,INF)
   var arrays=foot.surface_get_arrays(0);var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   for i in vs.size():stone.set_normal(ns[i]);stone.set_color(Color("a89565"));stone.set_uv(Vector2(vs[i].x+vs[i].z,-vs[i].y)/2);stone.add_vertex(vs[i])
   var uv=[Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)]
   detail_quad(paint,top.map(func(p):return p+ray*.001),uv.map(func(p):return (region.position+p*region.size)/Vector2(ArrowDetails.get_size())))
 var result=stone.commit();result.surface_set_material(0,stone_paint)
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint.commit().surface_get_arrays(0));result.surface_set_material(1,Paint.material(ArrowDetails))
 result.set_meta("falan_arrow_panes",panes);result.set_meta("falan_arrow_controls",controls)
 return result

static func wall_details(serial:int,pose:Transform3D)->Mesh:
 var row:Array=WALL_PROFILES[serial];var knee:float=row[1];var neck:float=row[3];var top:float=row[4];var thick:float=row[5]
 var turn=Basis(Vector3.UP,PI*.5 if serial==10641 else 0.0)
 var normal=(pose.basis.inverse().transposed()*turn*Vector3(0,(neck-top)/(15.1-knee),1)).normalized()
 var face=pose*(turn*Vector3(0,knee,neck));var middle=pose*(turn*Vector3(0,knee,neck-thick*.5))
 var ray=Vector3(1,2*Fit.FLOOR/Fit.VERTICAL,1)
 var stone=SurfaceTool.new();stone.begin(Mesh.PRIMITIVE_TRIANGLES)
 var paint=SurfaceTool.new();paint.begin(Mesh.PRIMITIVE_TRIANGLES)
 var controls=[]
 for rear in [false,true]:
  # shortcut: the unseen parallel face repeats the original openings; revisit if original rear art is recovered.
  var outward=-normal if rear else normal;var paint_ray=ray-2*normal*ray.dot(normal) if rear else ray
  for item in Data.WALL_SLITS[serial]:
   var region:Rect2=item[0];var front=[];var uvs=[Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)]
   for pixel:Vector2 in item[1]:
    var x=pixel.x/Fit.HORIZONTAL;var p=Vector3(x,(x*Fit.FLOOR-pixel.y)/Fit.VERTICAL,0)
    p+=ray*((normal.dot(face-p)+.012)/normal.dot(ray))
    if not rear:controls.append(p)
    front.append(p-2*normal*(p-middle).dot(normal) if rear else p)
   if rear:front.reverse();uvs.reverse()
   var backing=pier_loft(front.map(func(p):return p-outward*.10),front,INF)
   var arrays=backing.surface_get_arrays(0);var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   for i in vs.size():stone.set_normal(ns[i]);stone.set_color(Color.WHITE);stone.set_uv(Vector2(vs[i].x+vs[i].z,-vs[i].y)/2);stone.add_vertex(vs[i])
   front.reverse();uvs.reverse()
   detail_quad(paint,front.map(func(p):return p+paint_ray*.002),uvs.map(func(uv):return (region.position+uv*region.size)/Vector2(WallOpeningPaint.get_size())))
 var result=stone.commit();result.surface_set_material(0,stone_paint)
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint.commit().surface_get_arrays(0));result.surface_set_material(1,Paint.material(WallOpeningPaint))
 result.set_meta("falan_wall_opening_controls",controls);result.set_meta("falan_wall_panes",Data.WALL_SLITS[serial].size()*2)
 return result

static func wall_supports(serial:int,pose:Transform3D)->Mesh:
 var row:Array=WALL_PROFILES[serial];var knee:float=row[1];var neck:float=row[3];var top:float=row[4];var thick:float=row[5]
 var turn=Basis(Vector3.UP,PI*.5 if serial==10641 else 0.0)
 var normal=(pose.basis.inverse().transposed()*turn*Vector3(0,(neck-top)/(15.1-knee),1)).normalized()
 var face=pose*(turn*Vector3(0,knee,neck));var middle=pose*(turn*Vector3(0,knee,neck-thick*.5));var ray=Vector3(1,2*Fit.FLOOR/Fit.VERTICAL,1)
 var stone=SurfaceTool.new();stone.begin(Mesh.PRIMITIVE_TRIANGLES)
 var paint=SurfaceTool.new();paint.begin(Mesh.PRIMITIVE_TRIANGLES)
 var roots=[]
 for rear in [false,true]:
  # shortcut: rear supports repeat the recovered front profiles; revise when original reverse artwork becomes available.
  var outward=-normal if rear else normal;var paint_ray=ray-2*normal*ray.dot(normal) if rear else ray
  for item in Data.WALL_SUPPORTS[serial]:
   var region:Rect2=item[0];var bounds:Rect2=item[1];var front=[];var uvs=[]
   for pixel:Vector2 in item[2]:
    var x=pixel.x/Fit.HORIZONTAL;var p=Vector3(x,(x*Fit.FLOOR-pixel.y)/Fit.VERTICAL,0)
    p+=ray*((normal.dot(face-p)+.85)/normal.dot(ray))
    front.append(p-2*normal*(p-middle).dot(normal) if rear else p);uvs.append((pixel-bounds.position)/bounds.size)
   if (front[2]-front[0]).cross(front[1]-front[0]).dot(outward)>0:front.reverse();uvs.reverse()
   # Recede along the native ray so backing geometry stays within the measured face outline.
   var back=front.map(func(p):return p-paint_ray*(.95/outward.dot(paint_ray)));roots.append(back)
   var body=pier_loft(back,front,INF);var arrays=body.surface_get_arrays(0)
   var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   for i in vs.size():stone.set_normal(ns[i]);stone.set_color(Color.WHITE);stone.set_uv(Vector2(vs[i].x+vs[i].z,-vs[i].y)/2);stone.add_vertex(vs[i])
   var indices=Geometry2D.triangulate_polygon(PackedVector2Array(uvs))
   for i in range(0,indices.size(),3):
    var triangle=[indices[i],indices[i+1],indices[i+2]]
    if (front[triangle[2]]-front[triangle[0]]).cross(front[triangle[1]]-front[triangle[0]]).dot(outward)<0:var swap=triangle[1];triangle[1]=triangle[2];triangle[2]=swap
    for index in triangle:paint.set_normal(outward);paint.set_color(Color.WHITE);paint.set_uv((region.position+uvs[index]*region.size)/Vector2(WallSupportPaint.get_size()));paint.add_vertex(front[index]+paint_ray*.002)
 var result=stone.commit();result.surface_set_material(0,stone_paint)
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint.commit().surface_get_arrays(0));result.surface_set_material(1,Paint.material(WallSupportPaint))
 result.set_meta("falan_wall_supports",Data.WALL_SUPPORTS[serial].size()*2)
 result.set_meta("falan_wall_support_roots",roots)
 return result

static func square_courses()->Mesh:
 if square_course_mesh!=null:return square_course_mesh
 var stone=SurfaceTool.new();stone.begin(Mesh.PRIMITIVE_TRIANGLES)
 var paint=SurfaceTool.new();paint.begin(Mesh.PRIMITIVE_TRIANGLES)
 var root=Node3D.new();var half=63/(2*Fit.HORIZONTAL);var ray=Vector3(1,2*Fit.FLOOR/Fit.VERTICAL,1);var controls=[]
 for band in 2:
  var quad:Array=Data.SQUARE_COURSES[band*2][1]
  var top=(2*half*Fit.FLOOR-quad[3].y)/Fit.VERTICAL
  var bottom=(2*half*Fit.FLOOR-quad[2].y)/Fit.VERTICAL
  var node=gallery_coping(root,Vector3(0,(top+bottom)*.5,0),Vector3(half*2,top-bottom,half*2),stone_paint)
  var arrays=node.mesh.surface_get_arrays(0)
  var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var order=Array(range(vs.size()))
  if node.basis.determinant()<0:
   for i in range(0,order.size(),3):var swap=order[i+1];order[i+1]=order[i+2];order[i+2]=swap
  var normal_pose=node.basis.inverse().transposed()
  for i in order:
   var p:Vector3=node.transform*vs[i];stone.set_normal((normal_pose*ns[i]).normalized());stone.set_color(Color.WHITE);stone.set_uv(Vector2(p.x+p.z,-p.y)/2);stone.add_vertex(p)
  for rear in [false,true]:
   var turn=Basis(Vector3.UP,PI) if rear else Basis.IDENTITY
   for face in 2:
    var region:Rect2=Data.SQUARE_COURSES[band*2+face][0];var native:Array=Data.SQUARE_COURSES[band*2+face][1]
    var points=[Vector3(-half,top-.03,half),Vector3(half,top-.03,half),Vector3(half,bottom+.03,half),Vector3(-half,bottom+.03,half)] if face==0 else [Vector3(half,top-.03,half),Vector3(half,top-.03,-half),Vector3(half,bottom+.03,-half),Vector3(half,bottom+.03,half)]
    var uvs=[]
    for p:Vector3 in points:
     var pixel=Fit.project(p);var u=(pixel.x-native[0].x)/(native[3].x-native[0].x);var v=(pixel.y-lerpf(native[0].y,native[3].y,u))/(native[1].y-native[0].y)
     uvs.append((region.position+Vector2(u,v)*region.size)/Vector2(SquareCoursePaint.get_size()))
     if not rear:controls.append(p)
    detail_quad(paint,points.map(func(p):return turn*(p+ray*.001)),uvs)
 root.free();square_course_mesh=stone.commit();square_course_mesh.surface_set_material(0,stone_paint)
 square_course_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint.commit().surface_get_arrays(0));square_course_mesh.surface_set_material(1,Paint.material(SquareCoursePaint))
 square_course_mesh.set_meta("falan_square_course_controls",controls)
 return square_course_mesh

static func prepare(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var source=raw(serial);var reference:Rect2=Data.PARTS[serial][1]
 var pose:Transform3D=WALL_FRAMES[serial] if WALL_FRAMES.has(serial) else Fit.measure(Fit.mesh_points(source),"",Basis.IDENTITY,reference)
 if serial in range(10647,10654) or serial in range(10655,10662):
  var crown: Array[Vector3]=source.get_meta("falan_crown_vertices")
  var square=serial in range(10647,10654) or serial==10661
  var native=Rect2(-63,-260,128,0) if square else Rect2(-68,-283,137,0)
  var bounds=Fit.projected_bounds(crown);var scale_xz=native.size.x/bounds.size.x
  var dx=native.position.x-bounds.position.x*scale_xz;var low=0.0;var high=4.0
  for i in 48:
   var mid=(low+high)*.5;var raised=Transform3D(Basis.IDENTITY.scaled(Vector3(scale_xz,mid,scale_xz)),Vector3.ZERO)
   if Fit.projected_bounds(crown,raised).position.y>native.position.y:low=mid
   else:high=mid
  pose=Transform3D(Basis.IDENTITY.scaled(Vector3(scale_xz,(low+high)*.5,scale_xz)),Vector3(dx/(2*Fit.HORIZONTAL),0,-dx/(2*Fit.HORIZONTAL)))
 # Headers have no ground pixels: keep their station depth instead of letting bounds fitting trade height for depth.
 if serial==10646:pose=Transform3D.IDENTITY
 elif serial==10662:pose=WEST_EAST_FRAME
 var beam_bounds:AABB=source.get_meta("falan_gate_beam",AABB())
 if beam_bounds.has_volume():beams[serial]=pose*beam_bounds
 var windows=square_windows(serial,pose) if Data.WINDOWS.has(serial) else round_hood(serial) if Data.HOODS.has(serial) else null
 var braces=tower_braces(serial) if BRACE_SIDES.has(serial) else null
 var lower=lower_details(serial,pose) if Data.WINDOWS.has(serial) or serial in range(10655,10661) else null
 var courses=square_courses() if Data.WINDOWS.has(serial) else null
 var wall=wall_details(serial,pose) if Data.WALL_SLITS.has(serial) else null
 var brackets=wall_supports(serial,pose) if Data.WALL_SUPPORTS.has(serial) else null
 var spur=wall_spur(serial) if Data.WALL_SPURS.has(serial) else null
 var result=ArrayMesh.new()
 for part in source.get_surface_count():
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.append_from(source,part,pose)
  if part==0 and windows!=null:
   var frames=windows.surface_get_arrays(0);var vertices:PackedVector3Array=frames[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=frames[Mesh.ARRAY_NORMAL];var uvs:PackedVector2Array=frames[Mesh.ARRAY_TEX_UV];var colors:PackedColorArray=frames[Mesh.ARRAY_COLOR]
   for i in vertices.size():tool.set_normal(normals[i]);tool.set_uv(uvs[i]);tool.set_color(colors[i]);tool.add_vertex(vertices[i])
  if part==0 and braces!=null:tool.append_from(braces,0,Transform3D.IDENTITY)
  if part==0 and lower!=null:tool.append_from(lower,0,Transform3D.IDENTITY)
  if part==0 and courses!=null:tool.append_from(courses,0,Transform3D.IDENTITY)
  if part==0 and wall!=null:tool.append_from(wall,0,Transform3D.IDENTITY)
  if part==0 and brackets!=null:tool.append_from(brackets,0,Transform3D.IDENTITY)
  if part==0 and spur!=null:tool.append_from(spur,0,Transform3D.IDENTITY)
  var arrays=tool.commit().surface_get_arrays(0)
  if source.surface_get_material(part).get_shader_parameter("base_texture")==GatePaving:
   var floor_points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var floor_uvs=PackedVector2Array()
   var native=Vector2(26,59)+Data.PARTS[10662][1].position;var height=(WEST_EAST_FRAME*Vector3(0,18.5,0)).y
   var along=(native.y+height*Fit.VERTICAL)/Fit.FLOOR;var across=native.x/Fit.HORIZONTAL
   var origin=Vector2((along+across)*.5,(along-across)*.5)
   for p in floor_points:floor_uvs.append((Vector2(p.x,p.z)-origin)/Vector2(2.25,.75))
   arrays[Mesh.ARRAY_TEX_UV]=floor_uvs
  if serial==10646:
   var texture=source.surface_get_material(part).get_shader_parameter("base_texture")
   var feature={BannerPaint:"banner",BlueBannerPaint:"blue_banner",GateWindowPaint:"gate_window",GateBadgePaint:"gate_badge"}.get(texture,"")
   if not feature.is_empty():
    var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var quad:Array=GATE_QUADS[feature]
    var plane=(pose*Vector3(source.get_meta("falan_gate_detail_planes")[feature],0,0)).x
    for i in points.size():
     var uv=uvs[i];var pixel=quad[0].lerp(quad[3],uv.x).lerp(quad[1].lerp(quad[2],uv.x),uv.y)+reference.position
     var x=plane+(.012 if normals[i].x>0 else -.012);var z=x-pixel.x/Fit.HORIZONTAL;var y=((x+z)*Fit.FLOOR-pixel.y)/Fit.VERTICAL
     points[i]=Vector3(x,y,z);normals[i]=Vector3.RIGHT if normals[i].x>0 else Vector3.LEFT
    # Rectify only these native face details onto fixed stone/cloth planes; there is no view-dependent shader projection.
    var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
    if indices.is_empty():indices=PackedInt32Array(range(points.size()))
    for i in range(0,indices.size(),3):
     var a=indices[i];var b=indices[i+1];var c=indices[i+2]
     if (points[c]-points[a]).cross(points[b]-points[a]).dot(normals[a])<0:indices[i+1]=c;indices[i+2]=b
    if feature in ["banner","blue_banner"]:
     var front=[-1,-1,-1,-1];var rear=[-1,-1,-1,-1];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
     for i in points.size():
      var corner=roundi(uvs[i].x)+2*roundi(uvs[i].y)
      if normals[i].x>0:front[corner]=i
      else:rear[corner]=i
     # Cloth has physical edges; their camera-ray thickness preserves the native drawing.
     var rim=[0,2,3,1];var center=(points[front[0]]+points[front[3]]+points[rear[0]]+points[rear[3]])*.25
     for edge in 4:
      var a:int=rim[edge];var b:int=rim[(edge+1)%4];var corners=[front[a],front[b],rear[b],rear[a]]
      var n:Vector3=(points[corners[2]]-points[corners[0]]).cross(points[corners[1]]-points[corners[0]]).normalized()
      var face_center=(points[corners[0]]+points[corners[2]])*.5
      var order=[0,1,2,0,2,3] if n.dot(face_center-center)>0 else [0,2,1,0,3,2]
      if n.dot(face_center-center)<0:n=-n
      var start=points.size()
      for corner in corners:
       points.append(points[corner]);normals.append(n);uvs.append(uvs[corner]);colors.append(Color.WHITE)
      for i in order:indices.append(start+i)
     arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs
    arrays[Mesh.ARRAY_INDEX]=indices
    # Added cloth rims invalidate the old tangents; this painted material has no normal map.
    arrays[Mesh.ARRAY_TANGENT]=null
    arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(part,source.surface_get_material(part))
 if windows!=null:
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,windows.surface_get_arrays(1));result.surface_set_material(result.get_surface_count()-1,windows.surface_get_material(1))
 if lower!=null:
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,lower.surface_get_arrays(1));result.surface_set_material(result.get_surface_count()-1,lower.surface_get_material(1))
  result.set_meta("falan_arrow_panes",lower.get_meta("falan_arrow_panes"));result.set_meta("falan_arrow_controls",lower.get_meta("falan_arrow_controls"))
 if courses!=null:
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,courses.surface_get_arrays(1));result.surface_set_material(result.get_surface_count()-1,courses.surface_get_material(1))
 if wall!=null:
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,wall.surface_get_arrays(1));result.surface_set_material(result.get_surface_count()-1,wall.surface_get_material(1))
  result.set_meta("falan_wall_panes",wall.get_meta("falan_wall_panes"));result.set_meta("falan_wall_opening_controls",wall.get_meta("falan_wall_opening_controls"))
 if brackets!=null:
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,brackets.surface_get_arrays(1));result.surface_set_material(result.get_surface_count()-1,brackets.surface_get_material(1))
  result.set_meta("falan_wall_supports",brackets.get_meta("falan_wall_supports"))
 if spur!=null:
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,spur.surface_get_arrays(1));result.surface_set_material(result.get_surface_count()-1,spur.surface_get_material(1))
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,spur.surface_get_arrays(2));result.surface_set_material(result.get_surface_count()-1,spur.surface_get_material(2))
 if LEAF_QUADS.has(serial):
  # Grounded doors use their own native corners, independently of the common tower crown scale.
  var quad:Array=LEAF_QUADS[serial];var corners=[]
  for i in 4:
   var pixel:Vector2=quad[i]+reference.position;var foot:Vector2=quad[1 if i<2 else 2]+reference.position
   corners.append(Vector3((foot.x/Fit.HORIZONTAL+foot.y/Fit.FLOOR)*.5,(foot.y-pixel.y)/Fit.VERTICAL,(foot.y/Fit.FLOOR-foot.x/Fit.HORIZONTAL)*.5))
  var normal:Vector3=Vector3.UP.cross(corners[2]-corners[1]).normalized()
  if normal.dot(Vector3(1,0,1))<0:normal=-normal
  var bottom=[corners[1]-normal*.012,corners[2]-normal*.012,corners[2]-normal*.188,corners[1]-normal*.188]
  var top=[corners[0]-normal*.012,corners[3]-normal*.012,corners[3]-normal*.188,corners[0]-normal*.188]
  var body=pier_loft(bottom,top,INF);var arrays=body.surface_get_arrays(0);var body_points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var body_uvs=PackedVector2Array();var colors=PackedColorArray()
  for p in body_points:body_uvs.append(Vector2(p.x+p.z,-p.y)/2);colors.append(Color("394547"))
  arrays[Mesh.ARRAY_TEX_UV]=body_uvs;arrays[Mesh.ARRAY_COLOR]=colors
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(result.get_surface_count()-1,stone_paint)
  for rear in [false,true]:
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);var face_normal=-normal if rear else normal
   # A trapezoid needs bilinear UV samples between its corners, matching the rectified original.
   var columns=4 if serial==10661 else 1;var rows=32 if serial==10661 else 1
   for row in rows:
    for column in columns:
     var uvs=[Vector2(float(column)/columns,float(row)/rows),Vector2(float(column)/columns,float(row+1)/rows),Vector2(float(column+1)/columns,float(row+1)/rows),Vector2(float(column+1)/columns,float(row)/rows)]
     var face_points=[]
     for face_uv:Vector2 in uvs:face_points.append(corners[0].lerp(corners[3],face_uv.x).lerp(corners[1].lerp(corners[2],face_uv.x),face_uv.y)-normal*(.2 if rear else 0.0))
     var order=[0,1,2,0,2,3]
     if (face_points[2]-face_points[0]).cross(face_points[1]-face_points[0]).dot(face_normal)<0:order=[0,2,1,0,3,2]
     for i in order:tool.set_normal(face_normal);tool.set_uv(uvs[i]);tool.add_vertex(face_points[i])
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,tool.commit().surface_get_arrays(0))
   var front_texture=LeafFrontPaint if serial==10647 else LeafPaint;var rear_texture=LeafPaint if serial==10647 else LeafFrontPaint
   result.surface_set_material(result.get_surface_count()-1,Paint.material(rear_texture if rear else front_texture))
  result.set_meta("falan_leaf_body_volume",(corners[0].y+corners[3].y)*.5*(corners[2]-corners[1]).length()*.176)
 result.set_meta("falan_crown_points",source.get_meta("falan_crown_points",[]).map(func(p):return pose*p))
 result.set_meta("falan_source_frame",pose)
 if braces!=null:
  result.set_meta("falan_brace_caps",braces.get_meta("falan_brace_caps"));result.set_meta("falan_brace_controls",braces.get_meta("falan_brace_controls"))
 result.set_meta("falan_crown_feet",source.get_meta("falan_crown_feet",[]).map(func(p):return pose*p))
 var fitted_crown:Array[Vector3]=[]
 for p:Vector3 in source.get_meta("falan_crown_vertices",[]):fitted_crown.append(pose*p)
 result.set_meta("falan_crown_vertices",fitted_crown)
 result.set_meta("falan_wall_slab_volume",source.get_meta("falan_wall_slab_volume",0.0)*pose.basis.determinant())
 if WALL_PROFILES.has(serial):
  result.set_meta("falan_wall_knee",WALL_PROFILES[serial][1]*pose.basis.y.y)
  result.set_meta("falan_wall_top",15.4*pose.basis.y.y)
 elif serial in range(10647,10654) or serial in range(10655,10662):
  var square=serial in range(10647,10654) or serial==10661
  result.set_meta("falan_foundation_top",(SQUARE_FOUNDATION_HEIGHT if square else ROUND_FOOTING_HEIGHT)*pose.basis.y.y)
  result.set_meta("falan_shoulder_height",(17.75 if square else 17.99)*pose.basis.y.y+pose.origin.y)
 result.set_meta("falan_iron_spikes",source.get_meta("falan_iron_spikes",0))
 result.set_meta("falan_iron_tips",source.get_meta("falan_iron_tips",[]).map(func(p):return pose*p))
 meshes[serial]=result
 return result

static func stone_section(serial:int,pose:Transform3D,height:float,z_limits:Vector2=Vector2(-INF,INF))->Rect2:
 var mesh=prepare(serial);var bounds=Rect2();var found=false
 for part in mesh.get_surface_count():
  var texture=mesh.surface_get_material(part).get_shader_parameter("base_texture")
  if texture not in [Masonry,BasePaint]:continue
  var arrays=mesh.surface_get_arrays(part);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
  var order=indices if indices!=null and not indices.is_empty() else range(vertices.size())
  for i in range(0,order.size(),3):
   var triangle=[pose*vertices[order[i]],pose*vertices[order[i+1]],pose*vertices[order[i+2]]];var cuts=[]
   for j in 3:
    var a:Vector3=triangle[j];var b:Vector3=triangle[(j+1)%3];var da=a.y-height;var db=b.y-height
    if absf(da)<.0001:cuts.append(a)
    if da*db<0:cuts.append(a.lerp(b,da/(da-db)))
   if cuts.size()<2:continue
   for j in cuts.size():
    var a:Vector3=cuts[j];var b:Vector3=cuts[(j+1)%cuts.size()];var lo=0.0;var hi=1.0
    if absf(b.z-a.z)<.000001:
     if a.z<z_limits.x or a.z>z_limits.y:continue
    else:
     var first=(z_limits.x-a.z)/(b.z-a.z);var last=(z_limits.y-a.z)/(b.z-a.z)
     lo=maxf(0,minf(first,last));hi=minf(1,maxf(first,last))
     if hi<lo:continue
    for p:Vector3 in [a.lerp(b,lo),a.lerp(b,hi)]:
     var point=Vector2(p.x,p.z)
     bounds=bounds.expand(point) if found else Rect2(point,Vector2.ZERO);found=true
 return bounds

static func batch(parent:Node3D,serial:int,poses:Array):
 if poses.is_empty():return
 var groups={}
 for pose:Transform3D in poses:
  var key=Vector2i(floori(pose.origin.x/48),floori(pose.origin.z/48))
  if not groups.has(key):groups[key]=[]
  groups[key].append(pose)
 for key in groups:
  var node=MultiMeshInstance3D.new();node.name="RecoveredFalanFort%d_%d_%d"%[serial,key.x,key.y]
  node.set_meta("falan_fort_graphic",serial)
  var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=prepare(serial);multi.instance_count=groups[key].size()
  for i in groups[key].size():multi.set_instance_transform(i,groups[key][i])
  node.multimesh=multi;parent.add_child(node)

static func gate_spec(building:Dictionary)->Array:
 var area:String=building.get("falan_gate_area","")
 if not GATE_ROTATIONS.has(area) or GATE_ROTATIONS[area].get(building.cell,-1)!=building.rotation:return []
 var offset=Vector3(3 if area=="freyja" else -3,0,-3 if area=="south_gate" and building.cell.y==7 else 0)
 var undo=Basis(Vector3.UP,-building.rotation*PI*.5)
 return [10646 if area=="south_gate" else 10662,Transform3D(undo*Basis(Vector3.UP,GATE_YAWS[area]),undo*offset)]

static func gate_supports(building:Dictionary)->Array[AABB]:
 var spec=gate_spec(building)
 if spec.is_empty():return []
 var key=[building.falan_gate_area,building.cell]
 if supports.has(key):return supports[key]
 prepare(spec[0])
 var frontier=load("res://scripts/forest/forest_falan_frontier.gd");var area:String=building.falan_gate_area
 var at:Vector2=frontier.from_city(area,Vector2.ZERO)
 var city=Transform3D(Basis(Vector3.UP,frontier.FRAMES[area].get_rotation()),Vector3(at.x,0,at.y))
 var defenses=[]
 for row in frontier.CityForts.Data.FORTIFICATIONS:
  if not (row[1] in range(10647,10654) or row[1] in range(10655,10662)):continue
  var placement=city*Transform3D(Basis.IDENTITY,Court.point(row[0]))
  defenses.append({"serial":row[1],"pose":placement,"bounds":placement*prepare(row[1]).get_aabb()})
 var owner=Transform3D(Basis(Vector3.UP,building.rotation*PI*.5),Vector3(3,6,building.cell.y*6))
 var body:AABB=owner*spec[1]*beams[spec[0]]
 var result:Array[AABB]=[]
 for side in [-1,1]:
  var nearby=defenses.filter(func(row):return (row.pose.origin.x-3)*side>0 and absf(row.pose.origin.x-3)<20 and absf(row.pose.origin.z-body.get_center().z)<10)
  nearby.sort_custom(func(a,b):return Vector2(a.pose.origin.x-3,a.pose.origin.z-body.get_center().z).length_squared()<Vector2(b.pose.origin.x-3,b.pose.origin.z-body.get_center().z).length_squared())
  assert(not nearby.is_empty(),"A source gate requires both flanking towers")
  var tower:Dictionary=nearby[0]
  var shoulder_top:float=tower.pose.origin.y+prepare(tower.serial).get_meta("falan_shoulder_height")
  var y0=minf(body.position.y,shoulder_top-.2);var y1=body.position.y+minf(.85,body.size.y*.4)
  var section=stone_section(tower.serial,tower.pose,minf(y0+.08,shoulder_top-.08),Vector2(body.position.z,body.end.z))
  assert(section.has_area(),"A gate shoulder must meet actual tower stone")
  var z0=maxf(section.position.y,body.position.z);var z1=minf(section.end.y,body.end.z)
  assert(z1>z0,"Gate shoulders must share the source wall depth")
  var beam_rect=stone_section(spec[0],owner*spec[1],body.get_center().y,Vector2(z0,z1))
  assert(beam_rect.has_area(),"A gate seat must enter its actual stone floor")
  if section.grow(-.15).intersects(beam_rect) and body.position.y<shoulder_top-.15:continue
  var x0=minf(section.end.x,beam_rect.position.x)-.35 if side<0 else beam_rect.end.x-.35
  var x1=beam_rect.position.x+.35 if side<0 else maxf(section.position.x,beam_rect.end.x)+.35
  var footprint=Rect2(Vector2(x0,z0),Vector2(x1-x0,z1-z0))
  assert(footprint.intersects(section) and footprint.intersects(beam_rect),"Gate seats must overlap real stone at both ends")
  result.append(owner.affine_inverse()*AABB(Vector3(x0,y0,z0),Vector3(x1-x0,y1-y0,z1-z0)))
 supports[key]=result
 return result
