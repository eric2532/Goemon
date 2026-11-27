extends RefCounted
## Six recovered city rooms; original navigation, walls, NPCs and warps retain ownership.
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Atlas=preload("res://assets/maps/falan/city_room_fixtures.png")
const ROOMS=[1810,1811,1156,1182,1181,1172]
const HEIGHT_SCALE=(4.8/139.)/.045
static var catalog:Dictionary={}
static var meshes:Dictionary={}

static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/city_room_fixtures.json"))
 return catalog

static func build(root:Node3D,id:int,origin:Vector2)->Dictionary:
 var rows:Array=data().maps[str(id)].placements;var fences={}
 for row in rows:
  if data().graphics[str(int(row.graphic))].family=="city_fence":fences[Vector2i(row.source_cell[0],row.source_cell[1])]=true
 var groups={}
 for row in rows:
  var serial=int(row.graphic);var g:Dictionary=data().graphics[str(serial)]
  var cell=Vector2i(row.cell[0],row.cell[1]);var span=Vector2i(row.span[0],row.span[1])
  var arms=0
  if g.family=="city_fence":
   for i in 4:
    if fences.has(Vector2i(row.source_cell[0],row.source_cell[1])+[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN][i]):arms|=1<<i
  var key=Vector2i(serial,arms)
  if not meshes.has(key):meshes[key]=shape(serial,g,arms)
  if not groups.has(key):groups[key]=[]
  var at=origin+(Vector2(cell)+Vector2(span-Vector2i.ONE)*.5)*3.
  groups[key].append(Transform3D(Basis(Vector3.UP,PI*.5),Vector3(at.x,0,at.y)))
 for key in groups:
  var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=meshes[key];batch.instance_count=groups[key].size()
  for i in batch.instance_count:batch.set_instance_transform(i,groups[key][i])
  var node=MultiMeshInstance3D.new();node.multimesh=batch;node.name="OriginalCityRoomFixture_%d_%d"%[id,key.x]
  node.set_meta("falan_city_room",id);node.set_meta("original_graphic",key.x);node.set_meta("original_placements",batch.instance_count)
  root.add_child(node)
 root.set_meta("falan_city_fixture_count",rows.size())
 # Original floor/wall layers already own these boundaries, including the exterior storage row.
 return {}

static func shape(serial:int,g:Dictionary,arms:int)->Mesh:
 # These owners reach RoomArt themselves; resolve them after the room scripts are initialized.
 var forms=load("res://scripts/forest/forest_original_map_solids.gd")
 var original=load("res://scripts/forest/forest_original_map_art.gd")
 var raw:Mesh
 if g.family.begins_with("city_"):raw=city_shape(serial,g,arms)
 elif g.has("raised_base_pixels"):
  var w=float(g.footprint[0])*3.;var d=float(g.footprint[1])*3.
  var base=float(g.raised_base_pixels)*.045
  var fit=minf(1.,float(g.rect[2])/((w+d)*32./3.))
  raw=forms.furnishing(serial,g.family,w*fit*.84,d*fit*.84,maxf(.15,forms.source_height(g)-base),Vector3((w-3)*.5,base,(3-d)*.5))
 else:
  var shared:Dictionary=original.data().graphics.get(str(serial),{})
  if not shared.is_empty():
   assert(shared.rgba_sha256==g.rgba_sha256,"City fixture must reuse matching original pixels")
   raw=forms.mesh(serial,g.family,shared,original.solid_texture(int(shared.page)))
  else:raw=forms.mesh(serial,g.family,g,Atlas)
 var offset=Vector3((float(g.footprint[0])-1)*1.5,0,(1-float(g.footprint[1]))*1.5)
 if g.family not in ["city_panel","city_fence","city_crop","city_planter","city_conifer"]:raw=profile(raw,g,offset)
 return Fit.transformed(raw,Transform3D(Basis.IDENTITY.scaled(Vector3(1,HEIGHT_SCALE,1)),-offset))

static func profile(raw:Mesh,g:Dictionary,center:Vector3)->Mesh:
 # Sprite hotspots are draw anchors, not furniture heights. Fit the complete visible profile.
 var points=Fit.mesh_points(raw);var low=INF;var high=-INF
 for p:Vector3 in points:low=minf(low,p.x+p.z);high=maxf(high,p.x+p.z)
 var across=float(g.visible_rect[2])*3./32./maxf(.001,high-low)
 var source_base=raw.get_aabb().position.y
 var base=source_base if g.has("raised_base_pixels") or g.family=="coast_hanging" else 0.
 var shift=Vector3(center.x*(1-across),base,center.z*(1-across))
 var lines:Array[Vector2]=[]
 for p:Vector3 in points:
  var x=p.x*across+shift.x;var z=p.z*across+shift.z
  lines.append(Vector2((z-x)*8.,(p.y-source_base)/.045))
 var minimum=0.;var maximum=1.;var target=float(g.visible_rect[3])
 while Fit.vertical_bounds(lines,maximum).y-Fit.vertical_bounds(lines,maximum).x<target and maximum<64:maximum*=2
 for i in 36:
  var middle=(minimum+maximum)*.5;var bounds=Fit.vertical_bounds(lines,middle)
  if bounds.y-bounds.x<target:minimum=middle
  else:maximum=middle
 var vertical=maxf(.01,(minimum+maximum)*.5)
 shift.y=base-source_base*vertical
 var pose=Transform3D(Basis.IDENTITY.scaled(Vector3(across,vertical,across)),shift)
 var bounds=Rect2();var first=true
 for p:Vector3 in points:
  p=pose*p;var pixel=Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.-p.y/.045)
  bounds=Rect2(pixel,Vector2.ZERO) if first else bounds.expand(pixel);first=false
 var delta=Vector2(g.origin[0]+g.visible_rect[0],g.origin[1]+g.visible_rect[1])-bounds.position
 pose.origin+=Vector3((delta.x*3./32.-delta.y/8.)*.5,0,(delta.x*3./32.+delta.y/8.)*.5)
 return Fit.transformed(raw,pose)

static func city_shape(serial:int,g:Dictionary,arms:int)->Mesh:
 var forms=load("res://scripts/forest/forest_original_map_solids.gd")
 var w=float(g.footprint[0])*3.;var d=float(g.footprint[1])*3.;var high=forms.source_height(g)
 var center=Vector3((w-3)*.5,0,(3-d)*.5)
 if g.family=="city_panel":return panel(g)
 var stage=Node3D.new();var boxes=Boxes.new()
 var wood=Fort.material(Color("8c6440"),false);var pale=Fort.material(Color("ded2ad"),false)
 var green=Fort.material(Color("54824c"),false);var soil=Fort.material(Color("594a31"),false)
 match g.family:
  "city_conifer":
   var meadow=load("res://scripts/forest/forest_wind_meadow_assets.gd");var bounds=AABB();var first=true
   var tree="res://assets/models/environments/wind_meadow/crossgate_flora/cg_evergreen.glb"
   for part in meadow.source(tree):
    var box:AABB=part.transform*part.mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
   var fit=3.7/bounds.size.y
   var pose=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*fit),Vector3(-bounds.get_center().x*fit,.1-bounds.position.y*fit,-bounds.get_center().z*fit))
   meadow.batch(stage,tree,[pose],true)
   for node in stage.find_children("*","MultiMeshInstance3D",true,false):
    if node.material_override is ShaderMaterial:
     node.material_override=node.material_override.duplicate();node.material_override.set_shader_parameter("strength",0.)
   Geo.cylinder(stage,Vector3.UP*.35,.36,.70,wood,false,.48)
   Geo.cylinder(stage,Vector3.UP*.73,.51,.12,wood)
   Geo.cylinder(stage,Vector3.UP*.79,.45,.035,soil)
  "city_bed":
   var bed:ArrayMesh=Furniture.bed(minf(w,d),maxf(w,d),-1)
   bed=Fit.transformed(bed,Transform3D.IDENTITY)
   bed.surface_set_material(0,Fort.material(Color("b67448"),false))
   bed.surface_set_material(2,Fort.material(Color("db9079" if serial==16060 else "e8e2cc"),false))
   if serial==16063:bed.surface_set_material(0,Fort.material(Color("adbcb9"),false))
   var bed_root=Node3D.new();stage.add_child(bed_root);Geo.mesh(bed_root,bed,Vector3.ZERO,null)
   bed_frontage(bed_root,minf(w,d),maxf(w,d),serial)
   if w>d:bed_root.rotation.y=-PI*.5
  "city_bench":
   var bench=load("res://scripts/forest/forest_original_map_details.gd").build(10037,"detail_bench");stage.add_child(bench);bench.rotation.y=PI*.5
  "city_bench_segment":
   boxes.add(Vector3.UP*.35,Vector3(3.04,.70,1.40),wood)
   var cushion=PackedVector2Array([Vector2(-.7,.65),Vector2(.7,.65)])
   for i in 9:
    var angle=i*PI/8.;cushion.append(Vector2(cos(angle)*.7,.73+sin(angle)*.18))
   var seat=Geo.mesh(stage,Shapes.extrude(cushion,3.04),Vector3.ZERO,Fort.material(Color("aba97f"),false));seat.rotation.y=PI*.5
  "city_wardrobe":
   forms.Inn.furnish(stage,boxes,Vector3.ZERO,1.5,3.,false,serial,"inn_cupboard")
   if serial==16021:
    for child in stage.get_children():
     if child is Node3D:child.rotation.y=PI*.5
   else:
    for child in stage.find_children("*","MeshInstance3D",true,false):
     if child.material_override in [Fort.material(Color("845b42"),false),Fort.material(Color("5f3b31"),false)]:child.material_override=Fort.material(Color("72836b"),false)
     elif child.material_override==Fort.material(Color("b68d62"),false):child.material_override=Fort.material(Color("dcd8b9"),false)
  "city_drawers":
   forms.Inn.furnish(stage,boxes,Vector3.ZERO,1.5,3.,false,serial,"inn_cupboard")
   for i in 4:
    var at=Vector3(-.88,1.32+i*.26,0)
    boxes.add(at,Vector3(.12,.23,2.42),wood)
    boxes.add(at+Vector3(-.08,0,0),Vector3(.06,.045,.34),pale)
  "city_clock":
   load("res://scripts/forest/forest_falan_bank_art.gd").furnish(stage,boxes,Vector3.ZERO,3.,1.5,false,"bank_clock",serial)
   for child in stage.get_children():
    if child is Node3D:child.rotation.y=-PI*.5
  "city_plant_table":
   var table=load("res://scripts/forest/forest_original_map_details.gd").build(10011,"detail_potted");stage.add_child(table);table.rotation.y=PI*.5
  "city_crop":
   var count_=2 if serial in [11087,11088,11090,11092] else 1
   for i in count_:
    var at=Vector3((i-(count_-1)*.5)*.65,0,0)
    if serial!=11091:Geo.sphere(stage,at+Vector3.UP*.22,Vector3(.48,.48,.48),Fort.material(Color("b76945" if serial in [11088,11090] else "dfd6ad"),false))
    for leaf in 3:Geo.sphere(stage,at+Vector3(cos(leaf*2.1)*.13,.52,sin(leaf*2.1)*.13),Vector3(.22,.65,.28),green)
  "city_planter":
   var brick=Fort.material(Color("ab754b"),false)
   boxes.add(Vector3.UP*.55,Vector3(2.65,1.1,2.65),brick)
   boxes.add(Vector3.UP*1.12,Vector3(2.35,.08,2.35),soil)
   for y in [.35,.72]:
    for side in [-1,1]:
     boxes.add(Vector3(0,y,side*1.331),Vector3(2.66,.025,.012),pale)
     boxes.add(Vector3(side*1.331,y,0),Vector3(.012,.025,2.66),pale)
   for i in 5:Geo.sphere(stage,Vector3(cos(i*2.4)*.7,1.45,sin(i*2.4)*.7),Vector3(1.25,.8,1.2),green)
  "city_fence":
   for i in 4:
    if (arms & (1<<i))==0:continue
    var axis:Vector3=[Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK][i]
    for j in 3:
     var at=axis*(j+.15)*.55
     Geo.beam(stage,at,at+Vector3.UP*1.55,.065,wood)
    for y in [.45,1.05]:Geo.beam(stage,Vector3.UP*y,axis*1.52+Vector3.UP*y,.055,wood)
  "city_red_stool":
   Geo.cylinder(stage,Vector3.UP*1.1,1.1,.18,Fort.material(Color("883d2d"),false))
   for i in 4:
    var at=Vector3(cos(i*PI*.5)*.7,0,sin(i*PI*.5)*.7)
    Geo.beam(stage,at,at*.8+Vector3.UP*1.05,.07,wood)
  "city_crate":
   forms.Inn.Goods.crate(stage,boxes,Vector3.ZERO,1.76,true,wood,pale)
  "city_flower_cart":
   forms.Inn.Goods.flower_cart(stage,boxes,Vector3.ZERO,false,wood,pale,Fort.material(Color("515a50"),false),[Fort.material(Color("c87a60"),false),Fort.material(Color("d8bc78"),false),green])
  "city_vanity":
   Geo.mesh(stage,Furniture.desk(2.5,1.2,false),Vector3.ZERO,null)
   boxes.add(Vector3(0,2.65,-.42),Vector3(1.45,2,.16),wood)
   boxes.add(Vector3(0,2.65,-.32),Vector3(1.17,1.72,.035),Fort.material(Color("547881"),false))
  "city_counter_tile":
   boxes.add(Vector3.UP*.75,Vector3(2.8,1.5,2.8),pale)
   boxes.add(Vector3.UP*1.53,Vector3(2.9,.12,2.9),wood)
  "city_kitchen_counter":
   forms.Inn.furnish(stage,boxes,Vector3.ZERO,w,d,false,16164,"inn_counter")
   for z in [-d*.27,0,d*.27]:Geo.cylinder(stage,Vector3(.2,1.59,z),.42,.065,pale)
   var bottles=Furniture.tool()
   for z in [-d*.36,-d*.14]:Furniture.bottle(bottles,bottles,Vector3(-.25,1.57,z),.65)
   Geo.mesh(stage,bottles.commit(),Vector3.ZERO,Fort.material(Color("697b59"),false))
 boxes.build(stage)
 if g.family=="city_fence":
  # Arms are traced from the neighbouring original fence cells; keep the native tile span.
  return forms.append_fitted(null,stage,3,3,high,center,g)
 if g.family=="city_bench_segment":return forms.append_fitted(null,stage,3.04,1.40,high,center)
 if g.family=="city_conifer":return forms.append_fitted(null,stage,2.,2.,4.6,center)
 if g.family=="city_wardrobe":return forms.append_fitted(null,stage,3. if serial==16021 else 1.55,1.55 if serial==16021 else 3.,high,center)
 return forms.append_fitted(null,stage,w*.84,d*.84,high,center)

static func bed_frontage(root:Node3D,width:float,length_:float,serial:int):
 var wood=Fort.material(Color("b67448"),false);var half=width*.34;var z=-length_*.41
 if serial==16060:
  for inset in [0.,.14]:
   var outline=PackedVector2Array([Vector2(-half+inset,1.+inset),Vector2(half-inset,1.+inset)])
   for i in 13:
    var angle=i*PI/12.;outline.append(Vector2(cos(angle)*(half-inset),1.75+sin(angle)*(.7-inset)))
   Geo.mesh(root,Shapes.extrude(outline,.24 if inset==0 else .04),Vector3(0,0,z+(.04 if inset==0 else .19)),wood if inset==0 else Fort.material(Color("db9079"),false))
 elif serial==16503:
  for end in [-1,1]:
   var base=1.65 if end<0 else 1.05;var rise=.75 if end<0 else .45
   for i in 12:
    var a=i*PI/12.;var b=(i+1)*PI/12.
    Geo.beam(root,Vector3(cos(a)*half,base+sin(a)*rise,end*length_*.41),Vector3(cos(b)*half,base+sin(b)*rise,end*length_*.41),.075,wood)
   for x in [-.5,0.,.5]:Geo.beam(root,Vector3(x*half,1.05 if end<0 else .8,end*length_*.41),Vector3(x*half,base+sqrt(1-x*x)*rise,end*length_*.41),.045,wood)

static func panel(g:Dictionary)->Mesh:
 var rect=Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3])
 var skin=Source.new([rect,-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],Atlas,.045)
 var points=[]
 for pixel in g.panel[1]:
  var at=Vector2(pixel[0]+g.origin[0],pixel[1]+g.origin[1])
  var along=at.x*3./32.
  points.append(Vector3(along,(-along*8-at.y)*.045,0) if g.panel[0] else Vector3(0,(along*8-at.y)*.045,along))
 var normal=Vector3.BACK if g.panel[0] else Vector3.LEFT
 for i in [0,1,2,0,2,3]:skin.projected_vertex(points[i],normal,points[i])
 var result:ArrayMesh=skin.finish();var backing=Furniture.tool()
 var back=[]
 for p:Vector3 in points:back.append(p-normal*float(g.get("panel_depth",.065)))
 Shapes.quad(backing,back[3],back[2],back[1],back[0])
 for i in 4:Shapes.quad(backing,points[i],points[(i+1)%4],back[(i+1)%4],back[i])
 var solid:Mesh=backing.commit()
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,solid.surface_get_arrays(0))
 result.surface_set_material(1,Fort.material(Color("e0d4b5" if g.rect[2]<30 else "80603d"),false))
 return result
