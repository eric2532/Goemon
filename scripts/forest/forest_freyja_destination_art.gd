extends RefCounted
## Build original outdoor cliff footprints around the recovered warps.
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Gates=preload("res://assets/maps/falan/gate_exterior_data.gd")
const Archive=preload("res://assets/maps/falan/freyja_entrance_data.gd")
const Sokia=preload("res://scripts/forest/forest_sokia_scenery.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Scenery=preload("res://scripts/forest/forest_scenery.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
const RIDGE=[Vector2(-1,-.61),Vector2(-.57,-1),Vector2(.56,-1),Vector2(1,-.59),
 Vector2(1,.62),Vector2(.57,1),Vector2(-.62,1),Vector2(-1,.53)]
const CLIFF_LAYERS=[Vector2(.98,-.16),Vector2(1.0,.12),Vector2(.97,.33),
 Vector2(.86,.55),Vector2(.71,.77),Vector2(.56,.97)]
const HABARU_MOUTHS={Vector2i(672,223):"HabaruIlMouth",Vector2i(691,188):"HabaruAlyutMouth"}
const HABARU_MOUTH_SCALE=Vector3(3.2,2.35,1.5)
const UNDERSEA_MOUTHS=preload("res://assets/maps/falan/undersea_entrances.gd")
const Villages=preload("res://scripts/forest/forest_kili_art.gd")

static func build(parent:Node3D,model,area:String):
 if area=="il_village":
  il_gate(parent,model,Regions.IL_GATE)
  il_shore(parent,model)
 if area=="laruka":laruka_gate(parent,model,Regions.LARUKA_GATE)
 if area=="alyut":
  alyut_gate(parent,model,Regions.ALYUT_SOUTH_GATE)
  alyut_north_gate(parent,model,Regions.ALYUT_NORTH_GATE)
 if area=="tomato_farm":
  tomato_plot(parent,model,Regions.Sites.TOMATO_CROPS,"MountainTomatoBeds")
  tomato_storehouse(parent,model)
 if area in ["east_gate","east_coast"]:il_canal_crossing(parent,model,area)
 var sites=Regions.site_links(area).filter(func(site):return site.site not in [2000,2400])
 if sites.is_empty() and not Villages.SOURCE.SCENERY.has(area):return
 var root=Node3D.new()
 root.name="FreyjaDestinationEntrances"
 parent.add_child(root)
 build_archive(root,model,area)
 if model.terrain.variant=="east_gate":
  var coast=Node3D.new();coast.name="JoinedIlCountryside";root.add_child(coast)
  build_archive(coast,model,"east_coast")
 if Regions.HABARU_TRAIL.has(area) or area=="east_gate":
  var boxes=preload("res://scripts/forest/forest_static_boxes.gd").new()
  var goods=load("res://scripts/forest/forest_falan_market_goods.gd")
  var wood=Fort.material(Color("87613f"),false)
  var cut=Fort.material(Color("bb945d"),false)
  var iron=Geo.mat("495751")
  for sign_ in Regions.signs(area):
   if not sign_.get("habaru_trail",false):continue
   var at:Vector2=sign_.at
   goods.signpost(boxes,Vector3(at.x,model.surface_height(at.x,at.y),at.y),10415,wood,cut,iron)
  boxes.build(root)
 if area=="east_gate":tomato_plot(root,model,Gates.EXTERIORS.east_gate.crops,"WoodcutterCropRows")
 var stone=Fort.material(Color("877f6f"))
 var lintel=Fort.material(Color("b0a489"))
 for site in sites:
  if site.kind not in ["house","village"]:continue
  if site.site in [2100,3200]:continue
  if site.site==2300:
   laruka_gate(root,model,Regions.LARUKA_GATE+Regions.LARUKA_TO_ROAD)
   continue
  var at:Vector2=site.at
  var point=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
  var mouth=Node3D.new()
  mouth.position=point
  mouth.rotation.y=atan2(site.direction.x,site.direction.y)
  root.add_child(mouth)
  if site.kind=="house":
   var pose=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.72),Vector3(0,0,8))
   Assets.batch(mouth,Scenery.asset("falan_townhouse"),[pose])
   continue
  for side in [-1,1]:
   Geo.box(mouth,Vector3(side*2.6,2.0,2.5),Vector3(1.5,4,2.4),stone)
   Geo.box(mouth,Vector3(side*2.6,3.8,2.5),Vector3(1.72,.4,2.6),lintel)
  Geo.box(mouth,Vector3(0,4.25,2.5),Vector3(6.8,1.1,2.55),stone)
 if area=="freyja":
  var at=Regions.frame(area).inverse()*Vector2(894,444)
  var point=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
  Assets.batch(root,Scenery.asset("tree"),[Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*3.5),point)],true)

static func tomato_plot(parent:Node3D,model,rows:Array,label:String):
 var plot=Node3D.new()
 plot.name=label
 parent.add_child(plot)
 var leaves=[]
 var fruit=[]
 for row in rows:
  var at:Vector2=row[0]
  var point=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
  if row[1]==11066:
   var handle=Geo.mat("896044")
   var iron=Geo.mat("63665d")
   Geo.beam(plot,point,point+Vector3(.3,1.35,.2),.06,handle)
   Geo.beam(plot,point+Vector3(-.28,.31,0),point+Vector3(.36,.31,0),.06,iron)
   for x in [-.25,0.0,.32]:
    Geo.beam(plot,point+Vector3(x,.31,0),point+Vector3(x-.08,.04,-.09),.045,iron)
   continue
  var scale_=.30 if row[1]==11091 else .42
  leaves.append(Transform3D(Basis(Vector3.UP,at.x+at.y).scaled(Vector3.ONE*scale_),point))
  if row[1] in [11088,11090,11091]:
   for offset in [Vector3(-.24,.29,.21),Vector3(.19,.32,-.22),Vector3(.35,.22,.14)]:
    fruit.append(Transform3D(Basis.IDENTITY,point+offset))
 Assets.batch(plot,Scenery.asset("shrub"),leaves,true)
 var berry=SphereMesh.new()
 berry.radius=.13
 berry.height=.23
 berry.radial_segments=8
 berry.rings=4
 berry.material=Geo.mat("bb452a")
 var batch=MultiMeshInstance3D.new()
 batch.multimesh=MultiMesh.new()
 batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
 batch.multimesh.mesh=berry
 batch.multimesh.instance_count=fruit.size()
 for i in fruit.size():batch.multimesh.set_instance_transform(i,fruit[i])
 plot.add_child(batch)

static func tomato_storehouse(parent:Node3D,model):
 var root=Node3D.new()
 root.name="TomatoStorehouse"
 parent.add_child(root)
 var poses=[]
 for row in Regions.Sites.DOORS[Regions.Sites.TOMATO_MAPS[1]]:
  if row[1]!=Regions.Sites.TOMATO_MAPS[2]:continue
  var at:Vector2=row[0]-Vector2(0,5.0)
  var point=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
  poses.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.93,.90,.82)),point))
  Art.solid(root,point+Vector3.UP*2.15,Vector3(9,4.3,5.6),1,"wood")
 Assets.batch(root,Scenery.asset("falan_shop"),poses)

static func il_shore(parent:Node3D,model):
 var mesh=SurfaceTool.new()
 mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in Regions.Sites.IL_SHORE:
  var at:Vector2=row[0]
  var y=maxf(1.6,model.surface_height(at.x,at.y)-.4)
  ridge(mesh,Vector3(at.x,y,at.y),Vector2(3.15,3.15),1.1,row[1],false)
 mesh.generate_normals()
 Geo.mesh(parent,mesh.commit(),Vector3.ZERO,cliff_material(false)).name="IlArchivedShore"

static func il_gate(parent:Node3D,model,gate:Vector2,yaw:float=0.0):
 var root=Node3D.new()
 root.name="IlVillageTimberGate"
 root.position=Vector3(gate.x,model.surface_height(gate.x,gate.y),gate.y)
 root.rotation.y=yaw
 parent.add_child(root)
 var boxes=preload("res://scripts/forest/forest_static_boxes.gd").new()
 var timber=Geo.mat("775538")
 var end_grain=Geo.mat("ae8754")
 var stone=Fort.material(Color("959480"))
 for stretch in [Rect2(-.35,-16.5,.7,12),Rect2(-.35,4.5,.7,3),Rect2(0,5.65,13.5,.7)]:
  palisade(root,boxes,stretch,stone,timber,end_grain)
 open_gate_leaves(boxes,0.0,3.0,stone,timber,end_grain)
 boxes.build(root)
 # The archive places the timber lookout on the north end of the palisade.
 var offset=Vector3(-6,0,-21).rotated(Vector3.UP,yaw)
 var tower=Vector3(-6,model.surface_height(gate.x+offset.x,gate.y+offset.z)-root.position.y,-21)
 for side in [-1,1]:
  for back in [-1,1]:
   Geo.beam(root,tower+Vector3(side*2.65,0,back*2.65),tower+Vector3(side*1.9,14,back*1.9),.42,timber)
  for level in [0.0,4.2,8.4]:
   Geo.beam(root,tower+Vector3(side*2.5,level,-2.4),tower+Vector3(side*2.15,level+4.2,2.4),.27,timber)
   Geo.beam(root,tower+Vector3(-2.4,level,side*2.5),tower+Vector3(2.4,level+4.2,side*2.15),.27,timber)
 Geo.box(root,tower+Vector3.UP*12.2,Vector3(5,.65,5),timber)
 for side in [-1,1]:
  Geo.box(root,tower+Vector3(side*2.3,13.2,0),Vector3(.26,1.5,4.65),timber)
  Geo.box(root,tower+Vector3(0,13.2,side*2.3),Vector3(4.65,1.5,.26),timber)
 var roof=Geo.cylinder(root,tower+Vector3.UP*15.5,4.45,3.1,Geo.mat("b59958"),false,.22)
 roof.mesh.radial_segments=4
 roof.rotation.y=PI*.25
 Art.solid(root,tower+Vector3.UP*6.1,Vector3(5.1,12.2,5.1),1,"wood")

static func palisade(root:Node3D,boxes,stretch:Rect2,stone:Material,timber:Material,trim:Material):
 var center=stretch.get_center()
 var p=Vector3(center.x,0,center.y)
 var extent=Vector3(stretch.size.x,1.25,stretch.size.y)
 boxes.add(p+Vector3.UP*.625,extent,stone)
 Art.solid(root,p+Vector3.UP*1.3,Vector3(extent.x,2.6,extent.z),1,"stone")
 var along_x=stretch.size.x>stretch.size.y
 var count=roundi(maxf(stretch.size.x,stretch.size.y)/.6)
 for i in count:
  var at=p+(Vector3.RIGHT if along_x else Vector3.BACK)*((i+.5-count*.5)*.6)
  var h=1.15+float(i%3)*.16
  boxes.add(at+Vector3.UP*(1.25+h*.5),Vector3(.42,h,.42),timber)
  boxes.add(at+Vector3.UP*(1.25+h),Vector3(.39,.08,.39),trim)

static func open_gate_leaves(boxes,center:float,half_gap:float,stone:Material,timber:Material,trim:Material):
 for side in [-1,1]:
  boxes.add(Vector3(0,1.65,center+side*half_gap),Vector3(.82,3.3,.82),stone)
  boxes.add(Vector3(-1.3,1.9,center+side*(half_gap-.15)),Vector3(2.55,3.8,.24),timber)
  for height in [1.2,2.7]:
   boxes.add(Vector3(-1.3,height,center+side*(half_gap-.29)),Vector3(2.47,.14,.12),trim)

static func laruka_gate(parent:Node3D,model,gate:Vector2):
 var root=Node3D.new()
 root.name="LarukaOpenGate"
 root.position=Vector3(gate.x,model.surface_height(gate.x,gate.y),gate.y)
 parent.add_child(root)
 var boxes=preload("res://scripts/forest/forest_static_boxes.gd").new()
 var timber=Geo.mat("775538")
 var stone=Fort.material(Color("c8b997"),false)
 var base=Fort.material(Color("8a9074"))
 open_gate_leaves(boxes,1.5,4.5,stone,timber,Geo.mat("ae8754"))
 for wall in [Rect2(-.35,-10.5,.7,7.5),Rect2(0,8.65,15.6,.7),Rect2(14.65,9,.7,11.4)]:
  var at=wall.get_center()
  var p=Vector3(at.x,0,at.y)
  boxes.add(p+Vector3.UP*1.25,Vector3(wall.size.x,2.5,wall.size.y),stone)
  boxes.add(p+Vector3.UP*.36,Vector3(wall.size.x+.06,.72,wall.size.y+.06),base)
  Art.solid(root,p+Vector3.UP*1.25,Vector3(wall.size.x,2.5,wall.size.y),1,"stone")
 for corner in [Vector2(0,9),Vector2(15,9),Vector2(15,20)]:
  boxes.add(Vector3(corner.x,1.7,corner.y),Vector3(.65,3.4,.65),timber)
 boxes.build(root)

static func alyut_gate(parent:Node3D,model,gate:Vector2):
 var root=Node3D.new()
 root.name="AlyutSouthGate"
 root.position=Vector3(gate.x,model.surface_height(gate.x,gate.y),gate.y)
 root.rotation.y=PI*.5
 parent.add_child(root)
 var boxes=preload("res://scripts/forest/forest_static_boxes.gd").new()
 var stone=Fort.material(Color("b7ae92"),false)
 open_gate_leaves(boxes,0.0,4.5,stone,Geo.mat("775538"),Geo.mat("ae8754"))
 for side in [-1,1]:
  var p=Vector3(0,1.25,side*8.1)
  var size_=Vector3(.7,2.5,6.7)
  boxes.add(p,size_,stone)
  Art.solid(root,p,size_,1,"stone")
 boxes.build(root)

static func alyut_north_gate(parent:Node3D,model,gate:Vector2):
 var root=Node3D.new()
 root.name="AlyutNorthGate"
 root.position=Vector3(gate.x,model.surface_height(gate.x,gate.y),gate.y)
 parent.add_child(root)
 var boxes=preload("res://scripts/forest/forest_static_boxes.gd").new()
 var timber=Geo.mat("775538")
 var trim=Geo.mat("ae8754")
 var stone=Fort.material(Color("959480"))
 for stretch in [Rect2(-30,-.35,24,.7),Rect2(6,-.35,6,.7),Rect2(10.15,0,.7,21.35),Rect2(10.5,20.65,6,.7)]:
  palisade(root,boxes,stretch,stone,timber,trim)
 boxes.build(root)
 var leaves=Node3D.new()
 leaves.position.z=6.0
 leaves.rotation.y=PI*.5
 root.add_child(leaves)
 open_gate_leaves(boxes,0.0,4.5,stone,timber,trim)
 boxes.build(leaves)
 var fence=[]
 var post_basis=Basis(Vector3.UP,PI*.5).scaled(Vector3(.94,1.05,1))
 for offset in range(-12,16,3):
  var z:float=gate.y+offset
  fence.append(Transform3D(post_basis,Vector3(19.5,model.surface_height(gate.x+19.5,z)-root.position.y,offset)))
 for offset in [19.5,22.5,25.5]:
  var x:float=gate.x+offset
  fence.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.94,1.05,1)),Vector3(offset,model.surface_height(x,gate.y-15)-root.position.y,-15)))
 Assets.batch(root,Scenery.asset("fence"),fence)

static func il_canal_crossing(parent:Node3D,model,area:String):
 var local=Regions.frame(area).inverse()
 var stone=Fort.material(Color("9caa9c"))
 var coping=Fort.material(Color("c4bea6"),false)
 var boxes=preload("res://scripts/forest/forest_static_boxes.gd").new()
 var rail_size=Vector3(.84,1.05,15.2) if area=="east_gate" else Vector3(15.2,1.05,.84)
 for row in [231,235]:
  var at=local*(Vector2(556.5,row)*3.0)
  var rail=Vector3(at.x,model.surface_height(at.x,at.y),at.y)+Vector3.UP*.52
  boxes.add(rail,rail_size,stone)
  boxes.add(rail+Vector3.UP*.57,Vector3(rail_size.x+.12,.19,rail_size.z+.12),coping)
  Art.solid(parent,rail,rail_size,1,"stone")
  for column in range(555,559):
   var merlon=local*(Vector2(column,row)*3.0)
   var top=Vector3(merlon.x,model.surface_height(merlon.x,merlon.y)+1.40,merlon.y)
   boxes.add(top,Vector3(1.60,.48,1.60),coping)
  for column in [554,559]:
   at=local*(Vector2(column,row)*3.0)
   var p=Vector3(at.x,model.surface_height(at.x,at.y),at.y)
   boxes.add(p+Vector3.UP*.76,Vector3(1.48,1.52,1.48),stone)
   for step in 3:
    var size_=1.62-step*.38
    boxes.add(p+Vector3.UP*(1.58+step*.19),Vector3(size_,.19,size_),coping)
 boxes.build(parent)

static func cliff_material(coastal:bool,source_crags:bool=false)->ShaderMaterial:
 var mat:ShaderMaterial=Fort.material(Color("b49b73") if coastal else Color("8c8067"),false).duplicate()
 mat.set_shader_parameter("use_cliff_face",true)
 mat.set_shader_parameter("cliff_face",preload("res://assets/maps/falan/sokia_cliff_face.png")
  if coastal else preload("res://assets/maps/falan/freyja_cliff_face.png"))
 if source_crags:
  mat.set_shader_parameter("cliff_crags",true)
  mat.set_shader_parameter("rock_texture",preload("res://assets/maps/falan/venoa_scenery/cliff_stone.png"))
  mat.set_shader_parameter("cliff_face",preload("res://assets/maps/falan/venoa_scenery/cliff_moss.png"))
 return mat

static func cut_habaru_mouth(material:ShaderMaterial,model,area:String):
 if area=="east_gate":area="east_coast"
 for cell in Archive.MOUTHS.get(area,{}):
  if not HABARU_MOUTHS.has(cell):continue
  var frame=Regions.frame(model.terrain.variant).inverse() if model.terrain.variant=="east_gate" else Regions.frame(area).inverse()
  var at:Vector2=frame*(Vector2(cell)*3.0)
  var back:Vector2=frame.basis_xform(Archive.MOUTHS[area][cell]).normalized()
  # Use the existing cliff cutout so the archived ridge cannot fill the visible recess.
  material.set_shader_parameter("entrance_cut_count",1)
  material.set_shader_parameter("entrance_cuts",PackedVector4Array([Vector4(at.x,model.surface_height(at.x,at.y),at.y,4.04*HABARU_MOUTH_SCALE.y),Vector4.ZERO,Vector4.ZERO]))
  material.set_shader_parameter("entrance_scale",Vector2(HABARU_MOUTH_SCALE.x,HABARU_MOUTH_SCALE.z))
  material.set_shader_parameter("entrance_back",PackedVector2Array([back,Vector2.ZERO,Vector2.ZERO]))
  var profile=PackedVector4Array([Vector4(-1.48,1.44,0,0),Vector4(-1.5,1.5,.5,0),Vector4(-1.5,1.5,1.2,0),Vector4(-1.5,1.5,1.9,0),
   Vector4(-1.4,1.35,2.6,0),Vector4(-1.1,1.05,3.2,0),Vector4(-.65,.6,3.7,0),Vector4(.28,.28,4.04,0)])
  for i in profile.size():profile[i]*=Vector4(HABARU_MOUTH_SCALE.x,HABARU_MOUTH_SCALE.x,HABARU_MOUTH_SCALE.y,1)
  profile.resize(24)
  material.set_shader_parameter("entrance_profile",profile)

static func habaru_opening_bounds(model)->AABB:
 var area:String=model.terrain.variant
 if area=="east_gate":area="east_coast"
 for cell in Archive.MOUTHS.get(area,{}):
  if not HABARU_MOUTHS.has(cell):continue
  var at:Vector2=Regions.frame(model.terrain.variant).inverse()*(Vector2(cell)*3.0)
  var back=Regions.frame(model.terrain.variant).inverse().basis_xform(Vector2.RIGHT).normalized()
  var across=Vector2(back.y,-back.x)
  var size_=back.abs()*17.0+across.abs()*8.6
  var low=at+back*3.5-size_*.5
  return AABB(Vector3(low.x,model.surface_height(at.x,at.y)-.5,low.y),Vector3(size_.x,4.04*HABARU_MOUTH_SCALE.y,size_.y))
 return AABB()

static func build_archive(root:Node3D,model,area:String):
 if area=="sokia_desert":preload("res://scripts/forest/forest_falken_art.gd").desert_guide(root,model,Regions.frame(area))
 var village=Villages.SOURCE.SCENERY.has(area)
 if not Archive.SCENERY.has(area) and not village and not Sokia.owns(area):return
 var frame=Transform2D(0.0,Regions.Sites.VILLAGES[area][2]) if village else Regions.frame(area).inverse()
 if model.terrain.variant=="east_gate":frame=Regions.frame("east_gate").inverse()
 var coastal=area=="kili" or area.begins_with("sokia_") or area.begins_with("ghana_")
 var source_crags=area in ["south_lakes","kili","sokia_coast"] or Sokia.owns(area)
 var rock=SurfaceTool.new()
 rock.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rock_count=0
 var darkness=SurfaceTool.new()
 darkness.begin(Mesh.PRIMITIVE_TRIANGLES)
 var plants={}
 var native_palms={}
 var scenery:Dictionary={}
 if Sokia.owns(area):
  for row in Sokia.Data.SCENERY[area]:scenery[row[0]]=row
  Sokia.build(root,model,frame,Sokia.Data.SCENERY[area])
  root.set_meta("sokia_source_placements",Sokia.Data.SCENERY[area].size())
 elif area=="kili":
  var rows:Array=Villages.SOURCE.SCENERY.kili.filter(func(row):return Sokia.kili_prop(row[1]))
  Sokia.build(root,model,frame,rows)
  root.set_meta("kili_native_props",rows.size())
 for row in UNDERSEA_MOUTHS.SCENERY.get(area,[]):scenery[row[0]]=row
 for row in Villages.SOURCE.SCENERY.get(area,[]):scenery[row[0]]=row
 # Preserve existing mouth collision and the previously traced approach clearance.
 for row in Archive.SCENERY.get(area,[]):scenery[row[0]]=row
 var existing_trees={}
 for row in model.falan_frontier_plan:
  if row[0] not in ["tree","pine","cedar"]:continue
  var p:Vector3=row[1].origin
  existing_trees[Vector2i((frame.inverse()*Vector2(p.x,p.z)/3.0).round())]=true
 var banks=SurfaceTool.new()
 banks.begin(Mesh.PRIMITIVE_TRIANGLES)
 var bank_count=0
 for row in scenery.values():
  var anchor:Vector2=Vector2(row[0])
  var serial:int=row[1]
  if (Sokia.owns(area) and Sokia.Data.GRAPHICS.has(serial)) or (area=="kili" and Sokia.kili_prop(serial)):continue
  var span:Vector2=Vector2(row[2])
  var center=frame*((anchor+Vector2((span.x-1)*.5,-(span.y-1)*.5))*3.0)
  if Regions.village_contains(model.falan_area,center):continue
  if not model.terrain.mask_bounds().has_point(center):continue
  var point=Vector3(center.x,model.surface_height(center.x,center.y),center.y)
  if serial in range(11230,11266):continue
  if serial==11297:
   Villages.Buildings.build(root,point,serial)
   continue
  if serial in range(12500,12536) and (village or Sokia.owns(area) or undersea_surroundings(area,row[0])):
   coast_bank(banks,model,frame,anchor,serial)
   bank_count+=1
   continue
  if serial>=12500 and serial<=12565:
   var tall=serial>=12536
   if not tall:point.y=maxf(point.y,model.terrain.WATER_HEIGHT-.35)
   var extent=(frame.basis_xform(Vector2(span.x,0)).abs()+frame.basis_xform(Vector2(0,span.y)).abs())*3.0
   var height=clampf((row[3]-46)*.039,9.4,14.0) if tall else clampf(row[3]*.020,.42,1.75)
   if tall and Sokia.owns(area):
    crag_cluster(rock,point,extent,height,serial,Sokia.Details.Data.CLIFFS[serial],Sokia.Details.Data.CLIFF_CROWNS[serial])
   elif tall and source_crags:crag_cluster(rock,point,extent,height,serial)
   else:ridge(rock,point,extent,height,serial,tall)
   rock_count+=1
   if row[4]:
    Art.solid(root,point+Vector3.UP*(height*.39),Vector3(extent.x-.25,height*.85,extent.y-.25),1,"stone").name="ArchivedCliffCollision"
   if tall and not coastal and area!="south_lakes" and not Sokia.owns(area):
    for level in 2:
     var ledge:Vector2=RIDGE[posmod(serial+level*3,RIDGE.size())]*extent*(.44-level*.07)
     add_plant(plants,"shrub",point+Vector3(ledge.x,height*(.26+level*.36),ledge.y),serial,.66)
   continue
  if existing_trees.has(row[0]) and (serial in range(10058,10075) or serial in range(10085,10095)):continue
  if serial in range(11363,11373):
   var yaw=frame.get_rotation()+ (PI*.5 if serial in [11363,11368,11370] else 0.0)
   var fence:String=Scenery.asset("fence")
   if not plants.has(fence):plants[fence]=[]
   plants[fence].append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(.95,1.05,1)),point))
  elif serial in range(11188,11209):
   if Sokia.owns(area) or area=="kili":
    if not native_palms.has(serial):native_palms[serial]=[]
    native_palms[serial].append(Transform3D(Basis.IDENTITY,point))
   else:
    var height_scale=clampf(float(row[3])/385.0,.38,1.12)
    add_plant(plants,Villages.PALM,point,serial,.85*height_scale)
    if serial in [11191,11194,11197,11201,11204,11207,11208]:
     add_plant(plants,Villages.PALM,point+Vector3(.55,0,-.35),serial+1,.48*height_scale)
  elif serial in range(10058,10075) or serial in range(10085,10095):
   var kind=Assets.crossgate_tree(serial) if area in ["south_lakes","kili","sokia_coast"] or Sokia.owns(area) else "tree"
   add_plant(plants,kind,point,serial,1.1)
  elif serial in range(11625,11711) or serial in range(12160,12181):
   add_plant(plants,"flowers_ivory",point,serial,.8)
  else:
   add_plant(plants,"shrub",point,serial,.46)
 var mouths:Dictionary=Archive.MOUTHS.get(area,{})
 var cuts=PackedVector4Array([Vector4.ZERO,Vector4.ZERO,Vector4.ZERO])
 var cut_back=PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])
 var cut_profile=PackedVector4Array()
 cut_profile.resize(24)
 var cut_count=0
 for cell in mouths:
  var at=frame*(Vector2(cell)*3.0)
  var back=frame.basis_xform(mouths[cell]).normalized()
  var pose=Transform3D(Basis(Vector3.UP,atan2(back.x,back.y)),Vector3(at.x,model.surface_height(at.x,at.y),at.y))
  # Both Venoa-side entrances sit immediately in front of a broad cliff base.
  if area=="south_lakes" and cell in [Vector2i(442,349),Vector2i(299,538)]:
   pose.origin-=Vector3(back.x,0,back.y)*1.8
  if HABARU_MOUTHS.has(cell):
   var entrance=Node3D.new()
   entrance.name=HABARU_MOUTHS[cell]
   entrance.transform=pose
   entrance.set_meta("archive_cell",cell)
   root.add_child(entrance)
   habaru_mouth(entrance,darkness,pose)
   continue
  if UNDERSEA_MOUTHS.MOUTHS.has(cell):
   var height:float=UNDERSEA_MOUTHS.MOUTHS[cell].map(func(p):return p.y).max()
   var profile:Array=UNDERSEA_MOUTHS.MOUTHS[cell]
   for row in 8:cut_profile[cut_count*8+row]=Vector4(profile[row].x,profile[15-row].x,profile[row].y,0)
   cuts[cut_count]=Vector4(pose.origin.x,pose.origin.y,pose.origin.z,height)
   cut_back[cut_count]=back
   cut_count+=1
   var entrance=Node3D.new()
   entrance.name="UnderseaMouth_%d_%d"%[cell.x,cell.y]
   entrance.transform=pose
   entrance.set_meta("archive_cell",cell)
   root.add_child(entrance)
   undersea_mouth(entrance,darkness,pose,UNDERSEA_MOUTHS.MOUTHS[cell],coastal,source_crags)
   continue
  if Sokia.owns(area):
   cuts[cut_count]=Vector4(pose.origin.x,pose.origin.y,pose.origin.z,3.78)
   cut_back[cut_count]=back
   var profile=[Vector4(-1.16,1.16,0,0),Vector4(-1.15,1.18,.64,0),Vector4(-1.15,1.21,1.44,0),Vector4(-1.14,1.20,1.99,0),
    Vector4(-.98,1.11,2.64,0),Vector4(-.86,.9,3.16,0),Vector4(-.4,.54,3.66,0),Vector4(-.25,-.25,3.78,0)]
   for row in 8:cut_profile[cut_count*8+row]=profile[row]
   cut_count+=1
  cave_opening(rock,darkness,pose)
  rock_count+=1
 Sokia.Details.build_palms(root,native_palms)
 for key in plants:
  Assets.batch(root,key,plants[key],key.begins_with(Assets.DIR+"crossgate_flora/") or key.ends_with("broadleaf_tree.glb") or key.ends_with("cedar_tree.glb") or key.ends_with("pine_tree.glb") or key.ends_with("leafy_shrub.glb"))
 if bank_count>0:
  var material=preload("res://scripts/forest/forest_falan_room_art.gd").painted_atlas(preload("res://assets/maps/falan/undersea_coast_banks.png"))
  material.set_shader_parameter("alpha_cutout",true)
  var bank=Geo.mesh(root,banks.commit(),Vector3.ZERO,material)
  bank.name="ArchivedUnderseaCoastBanks"
  bank.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  bank.set_meta("archived_placements",bank_count)
 root.set_meta("undersea_surrounding_placements",UNDERSEA_MOUTHS.SCENERY.get(area,[]).size())
 rock.generate_normals()
 if source_crags:rock.index()
 var cliff=cliff_material(coastal,source_crags and not Sokia.owns(area))
 cliff.set_shader_parameter("entrance_cut_count",cut_count)
 cliff.set_shader_parameter("entrance_cuts",cuts)
 cliff.set_shader_parameter("entrance_back",cut_back)
 cliff.set_shader_parameter("entrance_profile",cut_profile)
 cut_habaru_mouth(cliff,model,area)
 if rock_count>0:Geo.mesh(root,rock.commit(),Vector3.ZERO,cliff).name="ArchivedCliffForms"
 root.set_meta("coastal_village_scenery",Villages.SOURCE.SCENERY.get(area,[]).size())
 if not mouths.is_empty():
  darkness.generate_normals()
  Geo.mesh(root,darkness.commit(),Vector3.ZERO,Geo.mat("171a17")).name="RecessedCaveMouths"

static func undersea_surroundings(area:String,cell:Vector2i)->bool:
 for bounds:Rect2i in UNDERSEA_MOUTHS.SURROUNDINGS.get(area,[]):
  if bounds.has_point(cell):return true
 return false

static func coast_bank(mesh:SurfaceTool,model,frame:Transform2D,anchor:Vector2,serial:int):
 var slot=serial-12500
 var texture_origin=Vector2(slot%12,slot/12)*36.0+Vector2.ONE*2.5
 # Subdivide the original tile over the existing walkable terrain instead of adding rock mounds.
 for z in 4:
  for x in 4:
   for corner:Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
    var uv=(Vector2(x,z)+corner)*.25
    var point=frame*((anchor+uv-Vector2.ONE*.5)*3.0)
    var height=model.surface_height(point.x,point.y)+.035
    mesh.set_normal(Vector3.UP)
    mesh.set_uv((texture_origin+Vector2(uv.y,1.0-uv.x)*31.0)/Vector2(432,108))
    mesh.add_vertex(Vector3(point.x,height,point.y))

static func add_plant(plants:Dictionary,kind:String,point:Vector3,serial:int,scale_:float):
 var asset=Scenery.asset(kind) if kind=="tree" or Scenery.CATALOG.has(kind) else kind
 if not plants.has(asset):plants[asset]=[]
 plants[asset].append(Transform3D(Basis(Vector3.UP,serial*2.4).scaled(Vector3.ONE*scale_),point))

static func crag_cluster(mesh:SurfaceTool,point:Vector3,extent:Vector2,height:float,serial:int,contours:Array=[],crowns:Array=[]):
 var seam=-1.0;var strongest=-1.0
 for i in range(1,contours.size()-1):
  var change=absf(contours[i+1][1]-contours[i-1][1])
  if contours[i][2]>.2 and contours[i][2]<.8 and change>strongest:
   seam=contours[i][2];strongest=change
 var second_seam=-1.0;var second_change=-1.0
 for i in range(1,contours.size()-1):
  var change=absf(contours[i+1][1]-contours[i-1][1])
  if contours[i][2]>.2 and contours[i][2]<.8 and absf(contours[i][2]-seam)>.15 and change>second_change:
   second_seam=contours[i][2];second_change=change
 for z in 3:
  for x in 3:
   var offset=Vector2(x-1,z-1)*extent*.29
   var rise=height*(.68+.22*(1.0-(absf(x-1)+absf(z-1))*.5)+sin(serial+x*7+z*13)*.07)
   if not contours.is_empty():rise*=.94+contours[(x+z*3)%contours.size()][1]*.10
   if not crowns.is_empty() and crowns[x+z*3]>0.0:rise=height*crowns[x+z*3]
   ridge(mesh,point+Vector3(offset.x,0,offset.y),extent*.43,rise,serial+x*17+z*31,true,seam,second_seam)

static func cave_crags(mesh:SurfaceTool,at:Vector2,along_x:bool,open_before:bool,serial:int):
 var tangent=Vector2.RIGHT if along_x else Vector2.DOWN
 var inward=(Vector2.UP if along_x else Vector2.LEFT)*(1.0 if open_before else -1.0)
 for i in 3:
  var center=at+tangent*(.5+i)-inward*.85
  var extent=Vector2(.90,1.45) if along_x else Vector2(1.45,.90)
  ridge(mesh,Vector3(center.x,-.12,center.y),extent,5.1+sin(serial+i*7+at.x*.3+at.y*.7)*1.25,serial+i*19,true)

static func ridge(mesh:SurfaceTool,point:Vector3,extent:Vector2,height:float,serial:int,tall:bool,seam:float=-1.0,second_seam:float=-1.0):
 mesh.set_smooth_group(0)
 var rings=[]
 var layers=CLIFF_LAYERS if tall else [Vector2(1.0,-.14),Vector2(.94,.28),Vector2(.72,.66),Vector2(.33,1.0)]
 if seam>=0.0:
  layers=layers.duplicate()
  for cut in [seam,second_seam]:
   if cut<0.0:continue
   for i in CLIFF_LAYERS.size()-1:
    var lower:Vector2=CLIFF_LAYERS[i];var upper:Vector2=CLIFF_LAYERS[i+1]
    if cut<lower.y or cut>upper.y:continue
    var radius=lerpf(lower.x,upper.x,(cut-lower.y)/(upper.y-lower.y))
    layers.append(Vector2(radius*.965,cut-.012));layers.append(Vector2(radius,cut+.008))
    break
  layers.sort_custom(func(a,b):return a.y<b.y)
 var sides=RIDGE.size()*2
 for layer in layers.size():
  var ring:Array[Vector3]=[]
  var profile:Vector2=layers[layer]
  for i in sides:
   var variation=sin(float(serial+i*23+layer*11))
   if seam>=0.0:
    for j in CLIFF_LAYERS.size()-1:
     if profile.y<CLIFF_LAYERS[j].y or profile.y>CLIFF_LAYERS[j+1].y:continue
     var t=(profile.y-CLIFF_LAYERS[j].y)/(CLIFF_LAYERS[j+1].y-CLIFF_LAYERS[j].y)
     variation=lerpf(sin(float(serial+i*23+j*11)),sin(float(serial+i*23+(j+1)*11)),t)
     break
   var edge:Vector2=RIDGE[i/2].lerp(RIDGE[(i/2+1)%RIDGE.size()],float(i%2)*.5)
   var at=edge*extent*.5*(profile.x+variation*.09)
   ring.append(point+Vector3(at.x,height*(profile.y+variation*.065),at.y))
  rings.append(ring)
 for layer in layers.size()-1:
  for i in sides:
   var j=(i+1)%sides
   face(mesh,rings[layer][i],rings[layer][j],rings[layer+1][j],rings[layer+1][i])
 var peak=point+Vector3(sin(serial)*extent.x*.10,height*1.08,cos(serial)*extent.y*.10)
 for i in sides:
  for p:Vector3 in [rings.back()[i],rings.back()[(i+1)%sides],peak]:mesh.add_vertex(p)

static func cave_opening(mesh:SurfaceTool,darkness:SurfaceTool,pose:Transform3D):
 var opening=[Vector2(-1.16,-.22),Vector2(-1.14,1.85),Vector2(-.86,3.02),Vector2(-.25,3.64),
  Vector2(.54,3.52),Vector2(1.02,2.88),Vector2(1.22,1.64),Vector2(1.16,-.22)]
 var rock_rim=[Vector2(-2.2,-.31),Vector2(-2.05,2.25),Vector2(-1.65,3.87),Vector2(-.69,4.46),
  Vector2(.51,4.57),Vector2(1.70,3.94),Vector2(2.12,2.07),Vector2(2.15,-.31)]
 mesh.set_smooth_group(-1)
 for i in opening.size()-1:
  var a:Vector2=opening[i]
  var b:Vector2=opening[i+1]
  var c:Vector2=rock_rim[i]
  var d:Vector2=rock_rim[i+1]
  var front=pose*Vector3(a.x,a.y,1.12+sin(i*2.4)*.12)
  var next=pose*Vector3(b.x,b.y,1.12+sin((i+1)*2.4)*.12)
  var back=pose*Vector3(a.x*.82,a.y,1.86)
  var back_next=pose*Vector3(b.x*.82,b.y,1.86)
  face(mesh,front,next,pose*Vector3(d.x,d.y,1.82),pose*Vector3(c.x,c.y,1.82))
  face(mesh,next,front,back,back_next)
  for p:Vector3 in [back_next,back,pose*Vector3(0,1.65,1.86)]:darkness.add_vertex(p)
 for p:Vector3 in [pose*Vector3(-.95,-.22,1.86),pose*Vector3(.95,-.22,1.86),pose*Vector3(0,1.65,1.86)]:
  darkness.add_vertex(p)

static func habaru_mouth(entrance:Node3D,darkness:SurfaceTool,pose:Transform3D):
 var mesh=SurfaceTool.new()
 mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var profile=[Vector3(-1.48,-.18,-.88),Vector3(-1.51,2.1,-.43),Vector3(-.76,3.51,-.62),
  Vector3(.28,3.90,-.09),Vector3(1.12,3.23,-.31),Vector3(1.53,1.89,-.48),Vector3(1.44,-.18,-.83)]
 var stone=[Vector3(-2.80,-.24,.40),Vector3(-2.88,2.83,1.25),Vector3(-1.78,5.16,1.43),
  Vector3(.55,5.52,1.87),Vector3(2.18,4.86,1.31),Vector3(2.94,2.59,.73),Vector3(2.87,-.24,.38)]
 for i in profile.size():
  profile[i]*=HABARU_MOUTH_SCALE
  stone[i]*=HABARU_MOUTH_SCALE
 var end:Vector3
 var start:Vector3
 for i in profile.size()-1:
  var a:Vector3=profile[i]
  var b:Vector3=profile[i+1]
  var c=Vector3(a.x*.77,a.y*.82,5.15*HABARU_MOUTH_SCALE.z)
  var d=Vector3(b.x*.77,b.y*.82,5.15*HABARU_MOUTH_SCALE.z)
  face(mesh,a,b,stone[i+1],stone[i])
  face(mesh,b,a,c,d)
  face(mesh,stone[i],stone[i+1],stone[i+1]+Vector3(0,.65,3.9)*HABARU_MOUTH_SCALE,stone[i]+Vector3(0,.65,3.9)*HABARU_MOUTH_SCALE)
  for point in [d,c,Vector3(0,1.43,5.15)*HABARU_MOUTH_SCALE]:darkness.add_vertex(pose*point)
  if i==0:start=c
  end=d
 for point in [start,end,Vector3(0,1.43,5.15)*HABARU_MOUTH_SCALE]:darkness.add_vertex(pose*point)
 mesh.generate_normals()
 Geo.mesh(entrance,mesh.commit(),Vector3.ZERO,cliff_material(false)).name="HabaruCliffRecess"

static func undersea_mouth(entrance:Node3D,darkness:SurfaceTool,pose:Transform3D,profile:Array,coastal:bool,source_crags:bool=false):
 var mesh=SurfaceTool.new()
 mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var height:float=profile.map(func(p):return p.y).max()
 for i in profile.size()-1:
  var a:Vector2=profile[i]
  var b:Vector2=profile[i+1]
  var front=Vector3(a.x,a.y-.14,1.12)
  var next=Vector3(b.x,b.y-.14,1.12)
  var inner=Vector3(a.x*.86,a.y*.94-.14,4.8)
  var inner_next=Vector3(b.x*.86,b.y*.94-.14,4.8)
  var rim=Vector3(a.x*1.55,a.y*1.14+.24,2.1)
  var rim_next=Vector3(b.x*1.55,b.y*1.14+.24,2.1)
  face(mesh,front,next,rim_next,rim)
  face(mesh,next,front,inner,inner_next)
  face(mesh,rim,rim_next,rim_next+Vector3(0,.3,3),rim+Vector3(0,.3,3))
  for point in [inner_next,inner,Vector3(0,height*.45,4.8)]:darkness.add_vertex(pose*point)
 for point in [Vector3(profile[0].x,-.14,4.8),Vector3(profile[-1].x,-.14,4.8),Vector3(0,height*.45,4.8)]:darkness.add_vertex(pose*point)
 mesh.generate_normals()
 Geo.mesh(entrance,mesh.commit(),Vector3.ZERO,cliff_material(coastal,source_crags)).name="ArchivedUnderseaRecess"
 entrance.set_meta("source_profile",profile)

static func face(mesh:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
 for p:Vector3 in [a,b,c,a,c,d]:mesh.add_vertex(p)
