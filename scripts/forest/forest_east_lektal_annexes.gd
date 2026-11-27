extends RefCounted
## Two native Lektal annex forms; original map owns every placement and doorway.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Timber=preload("res://scripts/forest/forest_il_laruka_buildings.gd")
const Logs=preload("res://scripts/forest/forest_falan_lamps.gd")
const Supports=preload("res://scripts/forest/forest_falan_palace_art.gd")
const ROOT="res://assets/maps/falan/east_region/lektal_annexes/"
const IDS=[1233256,1233257]
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static var support_rows:Array=[]
static var support_cells:Dictionary={}
static var support_origin=Vector2.ZERO
static var support_navigation:Dictionary={}

static func owns(serial:int)->bool:return serial in IDS
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog

static func source_point(pixel:Vector2,height:float,g:Dictionary)->Vector3:
 var u=(pixel.x+float(g.origin[0]))/(32./3.)
 var v=(pixel.y+float(g.origin[1])+height/.045)/8.
 return Vector3((u-v)*.5,height,(u+v)*.5)

static func on_front(pixel:Vector2,plane:float,g:Dictionary)->Vector3:
 var x=(pixel.x+float(g.origin[0]))/(32./3.)-plane
 return Vector3(x,((plane-x)*8.-pixel.y-float(g.origin[1]))*.045,plane)

static func prepare_support():
 if not support_rows.is_empty():return
 var spec:Dictionary=data().support
 support_origin=Vector2(spec.origin[0],spec.origin[1])
 for row:Dictionary in spec.sampling_cells:
  support_cells[Vector2i(row.cell[0],row.cell[1])]=bool(row.open)
 var g:Dictionary=data().graphics["1233256"];var deck=PackedVector2Array()
 for pixel:Array in g.deck_pixels:
  var p=source_point(Vector2(pixel[0],pixel[1]),float(g.deck_height),g);deck.append(Vector2(p.x,p.z))
 var low_x=minf(deck[1].x,deck[2].x);var high_x=maxf(deck[1].x,deck[2].x)
 var rear_z=minf(deck[1].y,deck[2].y);var nose_z=maxf(deck[1].y,deck[2].y)+float(g.tread_depth)
 var foot_z=maxf(deck[1].y,deck[2].y)+(float(g.steps)+1.)*float(g.tread_depth)
 for path:Dictionary in spec.paths:
  var cell=Vector2i(path.porch_cell[0],path.porch_cell[1]);var anchor=support_origin+Vector2(cell)*3.
  var apron=PackedVector2Array([Vector2(low_x,rear_z),Vector2(high_x,rear_z),Vector2(high_x,nose_z),Vector2(low_x,nose_z)])
  var ramp=PackedVector2Array([Vector2(low_x,nose_z),Vector2(high_x,nose_z),Vector2(high_x,foot_z),Vector2(low_x,foot_z)])
  support_rows.append({"cell":cell,"anchor":anchor,"deck":deck,"apron":apron,"ramp":ramp,"height":float(g.deck_height),"nose_z":nose_z,"foot_z":foot_z})

static func source_support_cell(point:Vector2)->Vector2i:
 prepare_support()
 return Vector2i(floori((point.x-support_origin.x)/3.+.5),floori((point.y-support_origin.y)/3.+.5))

static func support_height(row:Dictionary,point:Vector2,kind:String)->float:
 return float(row.height)*clampf(inverse_lerp(float(row.foot_z),float(row.nose_z),point.y),0.,1.) if kind=="ramp" else float(row.height)

static func surface_height(x:float,z:float)->float:
 prepare_support();var at=Vector2(x,z)
 if not support_cells.get(source_support_cell(at),false):return 0.
 var high=0.
 for row:Dictionary in support_rows:
  var p=at-Vector2(row.anchor)
  for kind in ["deck","apron","ramp"]:
   if Geometry2D.is_point_in_polygon(p,row[kind]):high=maxf(high,support_height(row,p,kind))
 return high

static func add_navigation(nav:Dictionary):
 prepare_support()
 assert(nav.width==int(data().support.size[0])+1 and Vector2(nav.origin.x,nav.origin.z)==support_origin,"Lektal navigation must retain the original source frame")
 assert(is_equal_approx(float(nav.route_spacing),3.),"Keep original native route spacing")
 var width_=int(nav.width)*2-1
 if support_navigation.is_empty():
  var heights=PackedFloat32Array();heights.resize(width_*width_)
  var covered=PackedByteArray();covered.resize(heights.size());covered.fill(1)
  # Same1.5m height-grid contract as Elsa; only two small native support patches need writes.
  # Route spacing, source bounds and the spatial covered domain stay unchanged.
  for row:Dictionary in support_rows:
   var bounds=Rect2(row.deck[0],Vector2.ZERO)
   for kind in ["deck","apron","ramp"]:
    for p:Vector2 in row[kind]:bounds=bounds.expand(p)
   bounds.position+=Vector2(row.anchor)
   var low=((bounds.position-support_origin)/1.5).floor();var high=((bounds.end-support_origin)/1.5).ceil()
   for z in range(maxi(0,int(low.y)),mini(width_-1,int(high.y))+1):
    for x in range(maxi(0,int(low.x)),mini(width_-1,int(high.x))+1):
     var at=support_origin+Vector2(x,z)*1.5
     heights[z*width_+x]=surface_height(at.x,at.y)
  support_navigation={"width":width_,"spacing":1.5,"origin":nav.origin,"heights":heights,"covered":covered}
 nav.merge(support_navigation,true)

static func build_supports(root:Node3D,source_id:int,state:Dictionary)->int:
 if source_id!=43700:return 0
 prepare_support()
 assert(Vector2(state.origin)==support_origin,"Lektal support must retain its original source frame")
 var size_:Vector2i=state.size
 for sample:Dictionary in data().support.sampling_cells:
  var cell=Vector2i(sample.cell[0],sample.cell[1]);var index=cell.y*size_.x+cell.x
  assert(bool(state.bits[index>>3] & (1<<(index&7)))==bool(sample.open),"Regenerate stale native Lektal walk support")
 var count=0
 for row:Dictionary in support_rows:
  for kind in ["deck","apron","ramp"]:
   var original=PackedVector2Array()
   for p:Vector2 in row[kind]:original.append(p+Vector2(row.anchor))
   for cell:Vector2i in support_cells:
    if not support_cells[cell]:continue
    var center=support_origin+Vector2(cell)*3.;var a=center-Vector2.ONE*1.5;var b=center+Vector2.ONE*1.5
    var tile=PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)])
    for polygon:PackedVector2Array in Geometry2D.intersect_polygons(original,tile):
     if polygon.size()<3:continue
     var points=PackedVector3Array()
     for p:Vector2 in polygon:
      var h=support_height(row,p-Vector2(row.anchor),kind)
      points.append(Vector3(p.x,h-.12,p.y));points.append(Vector3(p.x,h,p.y))
     var shape=ConvexPolygonShape3D.new();shape.points=points
     Supports.support(root,shape,Vector3.ZERO)
     var node=root.get_child(root.get_child_count()-1)
     node.name="NativeLektalTreadSupport_%d_%d_%s_%d"%[row.cell.x,row.cell.y,kind,count]
     node.set_meta("native_lektal_tread",true);node.set_meta("source_cell",cell);node.set_meta("porch_cell",row.cell);count+=1
 return count

static func append_piece(piece:Mesh,pose:Transform3D,base,part:String,front=null,paint_front:bool=false):
 var arrays=piece.surface_get_arrays(0)
 for i in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
  var normal:Vector3=(pose.basis*arrays[Mesh.ARRAY_NORMAL][i]).normalized()
  var axis=Vector3.RIGHT if absf(normal.z)>.5 else Vector3.BACK
  for j in 3:
   var p:Vector3=pose*arrays[Mesh.ARRAY_VERTEX][i+j]
   base.surface.set_normal(normal);base.surface.set_uv2(base.tiles[part])
   base.surface.set_uv(Vector2(p.dot(axis),-p.y)/1.35 if absf(normal.y)<.7 else Vector2(p.x,p.z)/1.35)
   base.surface.add_vertex(p)
   if paint_front and normal.z>.9:front.projected_vertex(p+normal*.006,normal,p)

static func closed_box(base,bounds:AABB,part:String):
 base.part=part;base.box(bounds)
 var a=bounds.position;var b=bounds.end
 base.quad(Vector3(a.x,a.y,b.z),Vector3(b.x,a.y,b.z),Vector3(b.x,a.y,a.z),Vector3(a.x,a.y,a.z))

static func measured_profile(points:Array,plane:float,depth:float,g:Dictionary,base,front,paint:bool=true,part:String="wood"):
 var outline=PackedVector2Array()
 for pixel:Array in points:
  var p=on_front(Vector2(pixel[0],pixel[1]),plane,g);outline.append(Vector2(p.x,p.y))
 append_piece(Shapes.extrude(outline,depth),Transform3D(Basis.IDENTITY,Vector3(0,0,plane-depth*.5)),base,part,front,paint)

static func roof_slab(base,front,points:Array,observed:bool):
 var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
 if normal.y<0:
  points=[points[3],points[2],points[1],points[0]];normal=-normal
 base.part="roof";base.quad(points[0],points[1],points[2],points[3])
 if observed:
  for i in [0,1,2,0,2,3]:front.projected_vertex(points[i]+normal*.008,normal,points[i])
 var underside=[]
 for p:Vector3 in points:underside.append(p-Vector3.UP*.12)
 base.part="wood";base.quad(underside[3],underside[2],underside[1],underside[0])
 for i in 4:
  var j=(i+1)%4;base.quad(points[i],points[j],underside[j],underside[i])

static func porch(g:Dictionary,base,front):
 var height=float(g.deck_height);var deck=[]
 for pixel:Array in g.deck_pixels:deck.append(source_point(Vector2(pixel[0],pixel[1]),height,g))
 base.part="wood";base.quad(deck[3],deck[2],deck[1],deck[0]);front.quad(deck[3]+Vector3.UP*.005,deck[2]+Vector3.UP*.005,deck[1]+Vector3.UP*.005,deck[0]+Vector3.UP*.005)
 base.quad(deck[0]-Vector3.UP*.24,deck[1]-Vector3.UP*.24,deck[2]-Vector3.UP*.24,deck[3]-Vector3.UP*.24)
 for i in 4:
  var a:Vector3=deck[i];var b:Vector3=deck[(i+1)%4]
  base.quad(a,b,b-Vector3.UP*.24,a-Vector3.UP*.24)
  Timber.bar(base,a-Vector3.UP*.24,Vector3(a.x,0,a.z),.15)
 # Three source rail sides; the stair-facing gap is kept open.
 for index in [0,2]:
  var a:Vector3=deck[index];var b:Vector3=deck[(index+1)%4]
  for t in [0.,.5,1.]:
   var p=a.lerp(b,t);Timber.bar(base,p,p+Vector3.UP*1.35,.13)
  for y in [.45,1.20]:Timber.bar(base,a+Vector3.UP*y,b+Vector3.UP*y,.11)
 var low_x=minf(deck[1].x,deck[2].x);var high_x=maxf(deck[1].x,deck[2].x)
 var z=maxf(deck[1].z,deck[2].z)
 for step in int(g.steps):
  var high=height*(float(step)+1.)/float(g.steps)
  closed_box(base,AABB(Vector3(low_x,0,z+float(g.steps-step-1)*float(g.tread_depth)),Vector3(high_x-low_x,high,float(g.tread_depth))),"wood")
 # The original arched door leaf is one measured closed slab, with separate solid frame bars.
 measured_profile(g.door_outline,float(g.door_plane),.16,g,base,front)
 var rim=[]
 for pixel:Array in g.door_outline:rim.append(on_front(Vector2(pixel[0],pixel[1]),float(g.door_plane)+.035,g))
 for i in rim.size()-1:Timber.bar(base,rim[i],rim[i+1],.11)

static func wing(g:Dictionary,base,front):
 # The asymmetric native gable is kept literal; hidden timber depth continues behind it.
 measured_profile(g.gable_outline,float(g.front_plane),float(g.hidden_depth),g,base,front,true,"log")
 var near=[];var far=[]
 for pixel:Array in g.roof_front:near.append(on_front(Vector2(pixel[0],pixel[1]),float(g.front_plane),g))
 for pixel:Array in g.roof_back:far.append(on_front(Vector2(pixel[0],pixel[1]),float(g.roof_back_plane),g))
 var far_right:Vector3=near[2]+far[1]-near[1]
 roof_slab(base,front,[near[0],near[1],far[1],far[0]],true)
 roof_slab(base,front,[near[1],near[2],far_right,far[1]],false)
 base.part="wood";base.quad(near[0],near[1],near[2],near[2])
 front.quad(near[0]+Vector3.BACK*.009,near[1]+Vector3.BACK*.009,near[2]+Vector3.BACK*.009,near[2]+Vector3.BACK*.009)
 # Native round window/bay remains on the measured front, with a distinct projecting closed volume.
 measured_profile(g.window_outline,float(g.front_plane)+float(g.window_depth),float(g.window_depth)+.08,g,base,front)
 base.part="wood"
 for a in [[near[0],near[1]],[near[1],near[2]],[far[0],far[1]],[far[1],far_right]]:Timber.bar(base,a[0],a[1],.13)
 # Rear joinery is inferred from native logs; there are no reconstructed rear doors.
 var rear=float(g.front_plane)-float(g.hidden_depth)
 for x in [near[0].x+1.,near[1].x,near[2].x-1.]:
  var top=maxf(1.,minf(near[0].y,near[2].y))
  Timber.bar(base,Vector3(x,0,rear),Vector3(x,top,rear),.20)
 # Reuse the existing closed cylindrical log primitive for actual rear/side courses.
 # Course end positions follow the measured gable section; no rectangular extra wall is added.
 Logs.prepare_primitives()
 var profile=[];var top_y=0.
 for pixel:Array in g.gable_outline:
  var p=on_front(Vector2(pixel[0],pixel[1]),float(g.front_plane),g)
  profile.append(Vector2(p.x,p.y));top_y=maxf(top_y,p.y)
 var y=.16
 while y<top_y:
  var cuts:Array[float]=[]
  for index in profile.size():
   var a:Vector2=profile[index];var b:Vector2=profile[(index+1)%profile.size()]
   if y>=minf(a.y,b.y) and y<maxf(a.y,b.y):cuts.append(lerpf(a.x,b.x,inverse_lerp(a.y,b.y,y)))
  cuts.sort()
  if cuts.size()>=2:
   var a=Vector3(cuts[0],y,rear);var b=Vector3(cuts[-1],y,rear)
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
   Logs.rod(tool,a,b,.19)
   for x in [cuts[0],cuts[-1]]:Logs.rod(tool,Vector3(x,y,rear),Vector3(x,y,float(g.front_plane)-.10),.19)
   append_piece(tool.commit(),Transform3D(Basis.IDENTITY.scaled(Vector3(1,.449,1)),Vector3(0,y*(1.-.449),0)),base,"log")
  y+=.30

static func mesh(serial:int,graphic:Dictionary={})->Mesh:
 assert(owns(serial),"Unowned Lektal annex")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)]
 if not graphic.is_empty():assert(graphic.rgba_sha256==g.source_rgba_sha256,"Regenerate stale Lektal annex source")
 var base=Source.new([],load(ROOT+"surfaces.png"),.045);base.tiles={"wood":Vector2(0,0),"timber":Vector2(0,0),"roof":Vector2(128,0),"dark":Vector2(256,0),"log":Vector2(384,0)};base.part="wood"
 var front=Source.new([Rect2(Vector2.ZERO,Vector2(g.size[0],g.size[1])),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(ROOT+str(serial)+".png"),.045)
 if g.form=="porch":porch(g,base,front)
 else:wing(g,base,front)
 var result=base.finish(true);var paint=front.finish(true)
 var paint_arrays:Array=paint.get_meta("source_surface_arrays")
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint_arrays);result.surface_set_material(1,paint.surface_get_material(0))
 result.set_meta("annex_front_arrays",paint_arrays)
 result.set_meta("native_lektal_annex",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256)
 result.set_meta("source_footprint",g.footprint);result.set_meta("reconstructed_hidden_depth",true)
 meshes[serial]=result
 return result
