extends RefCounted
## Il/Alyut source props share existing geometry, native alpha relief and foliage assets.
const ROOT="res://assets/maps/falan/east_village_props/"
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Parts=preload("res://scripts/forest/forest_il_laruka_buildings.gd")
const Kit=preload("res://scripts/forest/forest_coastal_buildings.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Relief=preload("res://scripts/forest/forest_elsa_scenery.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Tiles=preload("res://assets/maps/falan/il_laruka/building-surfaces.gd")
const SOURCE_VIEW=Vector3(-1,.72,1)
static var catalog:Dictionary={}
static var meshes={}
static var tree_fits={}
static var texture:Texture2D
static var surface_texture:Texture2D
static var flower_shader:Shader

static func data()->Dictionary:
 if catalog.is_empty():
  catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"));texture=load(ROOT+"native.png")
  surface_texture=load(ROOT+"surfaces.png")
  var original=load("res://scripts/forest/forest_original_map_art.gd");var archive:Dictionary=original.data()
  var page:int=archive.pages.size();archive.pages.append("../falan/east_village_props/native.png");archive.solid_pages.append("../falan/east_village_props/native.png")
  for key in catalog.graphics:
   var g:Dictionary=catalog.graphics[key];g.page=page;g.rgba_sha256=g.source_rgba_sha256
   if not archive.graphics.has(key):archive.graphics[key]=g
 return catalog

static func owns(serial:int)->bool:return data().graphics.has(str(serial))
static func flowering_tree(serial:int)->bool:return owns(serial) and data().graphics[str(serial)].mode=="flowering_tree"

static func skin():
 data()
 var result=Source.new([],surface_texture,.045);result.tiles=Tiles.TILES.duplicate()
 for name_ in catalog.surface_patches:
  var tile=catalog.surface_patches[name_].tile;result.tiles[name_]=Vector2(tile[0],tile[1])
 result.pitches={"plaster":.6,"timber":.9,"stone":1.3,"thatch":2.0,"round_thatch":2.0}
 return result

static func dark_water(base,radius:float,height:float):
 base.part="flue_dark"
 for i in 16:
  var a=-i*TAU/16.;var b=-(i+1)*TAU/16.
  base.quad(Vector3(0,height,0),Vector3(cos(b)*radius,height,sin(b)*radius),Vector3(cos(a)*radius,height,sin(a)*radius),Vector3(0,height,0))

static func fitted(raw:Mesh,g:Dictionary)->Mesh:
 var b:Array=g.bounds;var target=Rect2(float(g.origin[0])+b[0],float(g.origin[1])+b[1],b[2]-b[0],b[3]-b[1])
 var pose=Fit.measure(Fit.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),target)
 return Fit.transformed(raw,Transform3D(Basis.IDENTITY.scaled(Vector3(1,.045*Fit.VERTICAL,1)),Vector3.ZERO)*pose)

static func source_point(g:Dictionary,pixel:Vector2,height:float=0.)->Vector3:
 var across=(pixel.x+g.origin[0])/Fit.HORIZONTAL
 var ground=(pixel.y+g.origin[1]+height/.045)/Fit.FLOOR
 return Vector3((across-ground)*.5,height,(across+ground)*.5)

static func source_paint(g:Dictionary):
 var result=Source.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,.045)
 result.reflection_threshold=INF;return result

static func native_quad(base,_front,points:Array,paint:String,roof:bool=false):
 var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
 if roof and normal.y<0:points=points.duplicate();points.reverse();normal=-normal
 base.part=paint;base.quad(points[0],points[1],points[2],points[3])
 base.quad(points[3],points[2],points[1],points[0])
 if roof:
  for i in 4:
   var a:Vector3=points[i];var b:Vector3=points[(i+1)%4]
   base.quad(a-Vector3.UP*.12,a,b,b-Vector3.UP*.12)

static func native_wall(base,_front,a:Vector3,b:Vector3,height:float):
 base.part="fixture_wood"
 var rows=maxi(4,roundi(height/.36));var plank=BoxMesh.new();plank.size=Vector3(a.distance_to(b),height/rows-.025,.12)
 var turn=Basis(Vector3.UP,atan2(-(b.z-a.z),b.x-a.x))
 for row in rows:Forms.append(base,plank,Transform3D(turn,(a+b)*.5+Vector3.UP*(height*(row+.5)/rows)))

static func painted_finish(base,front)->Mesh:
 var body:Mesh=base.finish()
 for slot in body.get_surface_count():
  var arrays=body.surface_get_arrays(slot)
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
   if normal.dot(SOURCE_VIEW)<=.08:continue
   var point:Vector3=arrays[Mesh.ARRAY_VERTEX][i]
   front.projected_vertex(point+normal*.025,normal,point)
 var result=ArrayMesh.new();add_mesh(result,body,Transform3D.IDENTITY)
 add_mesh(result,front.finish(),Transform3D.IDENTITY);return result

static func source_housing(g:Dictionary)->Mesh:
 var base=skin();var front=source_paint(g);var feet=[]
 for p in [Vector2(22,89),Vector2(54,108),Vector2(104,78),Vector2(72,59)]:feet.append(source_point(g,p))
 base.part="timber"
 for p:Vector3 in feet:Parts.bar(base,p,p+Vector3.UP*1.95,.16)
 native_wall(base,front,feet[1],feet[2],1.78);native_wall(base,front,feet[2],feet[3],1.78)
 var near_left=source_point(g,Vector2(11,42),1.95);var far_left=source_point(g,Vector2(63,7),1.95)
 var near_right=source_point(g,Vector2(53,75),1.95);var far_right=source_point(g,Vector2(112,44),1.95)
 var near_ridge=source_point(g,Vector2(33,37),2.8);var far_ridge=source_point(g,Vector2(85,1),2.8)
 native_quad(base,front,[near_left,near_ridge,far_ridge,far_left],"thatch",true)
 native_quad(base,front,[near_right,far_right,far_ridge,near_ridge],"thatch",true)
 base.part="timber"
 for line in [[near_left,near_ridge],[near_right,near_ridge],[far_left,far_ridge],[far_right,far_ridge],[near_ridge,far_ridge]]:Parts.bar(base,line[0],line[1],.13)
 for p:Vector3 in [feet[0],feet[1]]:Parts.bar(base,p+Vector3.UP*1.95,near_ridge,.11)
 # The visible curved fixture remains a small source-positioned wooden/rope detail, with no service or entrance.
 var hook=source_point(g,Vector2(4,90));Parts.bar(base,hook,hook+Vector3.UP*1.2,.07)
 Parts.bar(base,hook+Vector3.UP*1.2,hook+Vector3(.15,1.2,.12),.07)
 return painted_finish(base,front)

static func source_stable(g:Dictionary)->Mesh:
 var base=skin();var front=source_paint(g);var feet=[];var width=Vector3(8.8,0,.30)
 for p in [Vector2(43,238),Vector2(118,296),Vector2(195,351),Vector2(288,425)]:feet.append(source_point(g,p))
 base.part="timber"
 for p:Vector3 in feet:
  for side in [Vector3.ZERO,width]:Parts.bar(base,p+side,p+side+Vector3.UP*4.05,.25)
 for i in 3:
  native_wall(base,front,feet[i+1]+width,feet[i]+width,3.7)
  for y in [1.0,2.2]:Parts.bar(base,feet[i]+Vector3.UP*y,feet[i+1]+Vector3.UP*y,.12)
 native_wall(base,front,feet[3],feet[3]+width,4.05);native_wall(base,front,feet[0]+width,feet[0],4.05)
 # Native painted horses, buckets and stall furniture remain decoration in their observed open bays.
 var a:Vector3=feet[0];var b:Vector3=feet[3];var lift=(b-a).cross(Vector3.UP).normalized()*.03
 front.quad(a+lift,a+Vector3.UP*4.05+lift,b+Vector3.UP*4.05+lift,b+lift)
 var near_eave=source_point(g,Vector2(0,123),4.05);var far_eave=source_point(g,Vector2(287,355),4.05)
 var near_ridge=source_point(g,Vector2(64,31),7.1);var far_ridge=source_point(g,Vector2(371,235),7.1)
 var near_back=source_point(g,Vector2(105,50),4.05);var far_back=source_point(g,Vector2(430,265),4.05)
 native_quad(base,front,[near_eave,near_ridge,far_ridge,far_eave],"thatch",true)
 native_quad(base,front,[near_back,far_back,far_ridge,near_ridge],"thatch",true)
 base.part="timber"
 for line in [[near_eave,near_ridge],[near_back,near_ridge],[far_eave,far_ridge],[far_back,far_ridge],[near_ridge,far_ridge]]:Parts.bar(base,line[0],line[1],.18)
 native_quad(base,front,[near_ridge,near_ridge+Vector3.UP*.50,far_ridge+Vector3.UP*.50,far_ridge],"fixture_wood")
 base.part="timber"
 for i in 14:
  var at=near_ridge.lerp(far_ridge,float(i)/13.)
  Parts.bar(base,at,at+Vector3.UP*(1.4 if i in [0,13] else .72 if i%3==0 else .46),.22)
 return painted_finish(base,front)

static func roofed_well(serial:int,g:Dictionary)->Mesh:
 if serial==11044:return source_housing(g)
 # The larger well reuses the shared open-well, roof and native rock pieces.
 var base=skin()
 if serial==11072:
  dark_water(base,1.15,.35)
  base.part="well_stone"
  Kit.kili_round(base,Vector3.ZERO,[Vector2(1.47,0),Vector2(1.47,1.18),Vector2(1.12,1.18),Vector2(1.12,.30)])
  var stones=SurfaceTool.new();stones.begin(Mesh.PRIMITIVE_TRIANGLES)
  for course in 2:
   for i in 12:
    var angle=(i+float(course)*.5)*TAU/12.
    Forms.Crags.ridge(stones,Vector3(cos(angle)*1.38,.08+course*.6,sin(angle)*1.38),Vector2(.68,.62),.65,11072+i+course*12,false)
  stones.generate_normals();Forms.append(base,stones.commit())
  base.part="timber"
  for x in [-1.75,1.75]:
   for z in [-1.5,1.5]:Parts.bar(base,Vector3(x,0,z),Vector3(x,3.7,z),.18)
  Parts.pitched(base,4.35,4.15,3.5,1.15,true,"thatch",Vector3.ZERO,"timber")
  Parts.bar(base,Vector3(-1.75,2.85,0),Vector3(1.75,2.85,0),.18)
  Parts.bar(base,Vector3(0,2.8,0),Vector3(0,1.1,0),.045)
  Kit.kili_round(base,Vector3(0,.65,0),[Vector2(.32,0),Vector2(.40,.1),Vector2(.43,.72),Vector2(.31,.72),Vector2(.27,.18)])
  for side in [-1,1]:
   for row in 3:base.box(AABB(Vector3(-1.65,.15+row*.38,side*1.4-.055),Vector3(3.3,.34,.11)))
 var result=fitted(base.finish(),g)
 return result

static func native_relief(serial:int,g:Dictionary,grounded:bool=false)->Mesh:
 assert(not g.outline.is_empty(),"Regenerate the native prop outline: "+str(serial))
 var row=g.duplicate(true);row.cut=[serial];row.depth=.10 if grounded else .16 if row.mode=="flora" else .20
 var along=0.0
 if row.footprint[0]>row.footprint[1]:along=-.75
 elif row.footprint[1]>row.footprint[0]:along=.75
 var vertical=1.0 if grounded else .40 if serial in [12169,12170,12171,12179,12180] else 0.0
 return Relief.relief_shape(row,texture,texture,row.outline,Vector2(along,0),vertical)

static func tree_pose(height:float,width:float)->Transform3D:
 var token=Vector2(height,width)
 if tree_fits.has(token):return tree_fits[token]
 var bounds=AABB();var first=true
 for part in Meadow.source(Meadow.crossgate_tree(10090)):
  var box:AABB=part.transform*part.mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
 var fit=Vector3(width/maxf(.01,bounds.size.x),height/maxf(.01,bounds.size.y),width/maxf(.01,bounds.size.z))
 tree_fits[token]=Transform3D(Basis.IDENTITY.scaled(fit),-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*fit)
 return tree_fits[token]

static func build_flowering_trees(root:Node3D,serial:int,poses:Array):
 var g:Dictionary=data().graphics[str(serial)];var source_poses=[]
 for placement:Transform3D in poses:
  for crown in g.crowns:
   var pixel=Vector2(crown.foot[0]+g.origin[0],crown.foot[1]+g.origin[1])
   var foot=Vector3(pixel.x*3./64.-pixel.y/16.,0,pixel.x*3./64.+pixel.y/16.)
   source_poses.append(placement*Transform3D(Basis.IDENTITY,foot)*tree_pose(float(crown.height),float(crown.width)))
 var owner=Node3D.new();owner.name="NativeFloweringTrees_"+str(serial);owner.set_meta("source_graphic",serial)
 owner.set_meta("inferred_visual","Existing native silverleaf master fitted to the measured individual source crowns and trunk feet.")
 root.add_child(owner);Meadow.batch(owner,Meadow.crossgate_tree(10090),source_poses,true)
 for node in owner.get_children():
  if node is MultiMeshInstance3D and node.get_meta("crossgate_tree_part","")=="Canopy":
   # These source flowering trees are shorter than the hero camera; the large-tree cutaway would erase every nearby crown.
   if flower_shader==null:
    # The reused native pale-leaf paint already contains its color; generic green vertex tint would suppress the original white flowers.
    flower_shader=Shader.new();flower_shader.code=Meadow.WIND.code.replace("tint=COLOR.rgb*foliage_tint;","tint=foliage_tint;")
   var paint:ShaderMaterial=node.material_override.duplicate()
   paint.shader=flower_shader;paint.set_shader_parameter("canopy",false);paint.set_shader_parameter("tree",true);paint.set_shader_parameter("strength",.025)
   paint.set_shader_parameter("use_source_paint",true);paint.set_shader_parameter("source_paint",node.multimesh.mesh.surface_get_material(0).albedo_texture)
   paint.set_shader_parameter("foliage_tint",Vector3.ONE);node.material_override=paint

static func cart_deck(x:float,z:float)->Vector3:return Vector3(x,.70-z*.25,z)

static func source_cart(serial:int,g:Dictionary)->Mesh:
 # Reuse the market cart's open torus/spoke construction rather than the old painted solid wheel disks.
 var native=skin();native.part="cart_plank"
 var plank=BoxMesh.new();plank.size=Vector3(3.4/8.-.025,.14,4.0/cos(atan(.25)))
 for i in 8:Forms.append(native,plank,Transform3D(Basis(Vector3.RIGHT,atan(.25)),cart_deck(-1.7+(i+.5)*3.4/8.,.2)))
 native.part="fixture_wood"
 for side in [-1,1]:
  Parts.bar(native,cart_deck(side*1.7,-5.8),cart_deck(side*1.7,2.2),.14)
  for h in [.18,.40]:Parts.bar(native,cart_deck(side*1.75,-1.8)+Vector3.UP*h,cart_deck(side*1.75,2.2)+Vector3.UP*h,.16)
 for z in [-5.8,-1.8,2.2]:Parts.bar(native,cart_deck(-1.7,z)+Vector3.UP*(.4 if z!=-5.8 else 0.),cart_deck(1.7,z)+Vector3.UP*(.4 if z!=-5.8 else 0.),.16)
 Parts.bar(native,Vector3(-2.,1.,.3),Vector3(2.,1.,.3),.16)
 var rim=TorusMesh.new();rim.inner_radius=.80;rim.outer_radius=1.;rim.rings=20;rim.ring_segments=6
 var hub=CylinderMesh.new();hub.top_radius=.17;hub.bottom_radius=.17;hub.height=.30;hub.radial_segments=12
 var wheel_turn=Basis(Quaternion(Vector3.UP,Vector3.RIGHT))
 for side in [-1,1]:
  var at=Vector3(side*2.,1.,.3)
  Forms.append(native,rim,Transform3D(wheel_turn,at));Forms.append(native,hub,Transform3D(wheel_turn,at))
  for i in 8:
   var angle=i*TAU/8.;Parts.bar(native,at,at+Vector3(0,cos(angle),sin(angle))*.86,.09)
 var turn=Basis(Vector3.UP,deg_to_rad(-80 if serial==11023 else -10))
 var wheel_foot=source_point(g,Vector2(89,131) if serial==11023 else Vector2(55,134))
 var shift=wheel_foot-turn*Vector3(2. if serial==11023 else -2.,0,.3)
 var result=Fit.transformed(native.finish(),Transform3D(turn,shift));result.set_meta("source_spoked_wheels",2);return result

static func hay_bundle(native,at:Vector3,w:float,d:float,h:float):
 native.part="thatch"
 var profile=[Vector2(.84,0),Vector2(1.,.18),Vector2(.98,.74),Vector2(.80,1.),Vector2(0,1.04)]
 for layer in profile.size()-1:
  for i in 16:
   var points=[]
   for part in [Vector2(i,layer),Vector2(i,layer+1),Vector2(i+1,layer+1),Vector2(i+1,layer)]:
    var angle=-part.x*TAU/16.;var ring:Vector2=profile[int(part.y)]
    points.append(at+Vector3(signf(cos(angle))*sqrt(absf(cos(angle)))*w*.5*ring.x,ring.y*h,signf(sin(angle))*sqrt(absf(sin(angle)))*d*.5*ring.x))
   native.quad(points[0],points[1],points[2],points[3])
 native.part="fixture_wood"
 for x in [-w*.22,w*.22]:
  var points=[Vector3(x,.08,-d*.47),Vector3(x,h*.72,-d*.47),Vector3(x,h*1.045,0),Vector3(x,h*.72,d*.47),Vector3(x,.08,d*.47)]
  for i in points.size()-1:Parts.bar(native,at+points[i],at+points[i+1],.045)

static func source_hay(serial:int,g:Dictionary)->Mesh:
 var native=skin();var at=source_point(g,Vector2(g.rect[2]*.5,g.bounds[3]-5.))
 if serial==11021:
  native.part="thatch";Kit.kili_round(native,at,[Vector2(.75,0),Vector2(1.05,.25),Vector2(.45,1.40),Vector2(.25,1.9),Vector2(0,2.05)])
 else:
  if serial==11094:
   for p in [Vector3(-.8,0,.1),Vector3(.8,0,.1),Vector3(0,1.05,-.2)]:hay_bundle(native,at+p,2.2,2.25,1.15)
  else:hay_bundle(native,at,2.7 if serial==11019 else 2.2,2.0 if serial==11019 else 2.6,1.0)
 var result=native.finish();result.set_meta("closed_source_hay",true);return result

static func source_logstore(g:Dictionary)->Mesh:
 var native=skin();var w=g.footprint[0]*3.;var d=g.footprint[1]*3.
 var center=Vector3((w-3.)*.5,0,(3.-d)*.5)
 for row in 3:
  var count_=5-row
  for i in count_:
   var at=center+Vector3((i-(count_-1)*.5)*.70,.34+row*.60,0)
   Forms.Tina.timber_log(native,at,Vector3.BACK,d*.80,.34)
 native.part="fixture_wood"
 for x in [-w*.39,w*.39]:
  for z in [-d*.43,d*.43]:Parts.bar(native,center+Vector3(x,0,z),center+Vector3(x,2.1,z),.15)
 Parts.pitched(native,w+.15,d+.25,2.05,1.05,false,"thatch",center,"fixture_wood")
 var result=native.finish();result.set_meta("solid_source_logstore",true);return result

static func village_measured(raw:Mesh)->Mesh:
 var ratio=.045/Forms.Street.Harbor.PIXEL_HEIGHT
 var posed=Fit.transformed(raw,Transform3D(Basis.IDENTITY.scaled(Vector3(1,ratio,1)),Vector3.ZERO));var result=ArrayMesh.new()
 for slot in posed.get_surface_count():
  var arrays=posed.surface_get_arrays(slot);var paint=posed.surface_get_material(slot)
  var tile:Variant=paint.get_shader_parameter("atlas_tile_pixels") if paint is ShaderMaterial else 0.
  if (tile is float or tile is int) and tile>0:
   var normals:PackedVector3Array=raw.surface_get_arrays(slot)[Mesh.ARRAY_NORMAL];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
   for i in uv.size():
    if absf(normals[i].y)<=maxf(absf(normals[i].x),absf(normals[i].z)):uv[i].y*=ratio
   arrays[Mesh.ARRAY_TEX_UV]=uv
  result.add_surface_from_arrays(posed.surface_get_primitive_type(slot),arrays);result.surface_set_material(slot,paint)
 return result

static func timber_tile(tile:Vector2)->bool:
 return tile in [Forms.BuildingData.TILES.tina_hollow_bark,Forms.BuildingData.TILES.tina_log_end]

static func rounded_stockade(serial:int,raw:Mesh)->Mesh:
 # Keep the original source front and closed stone body; only the inferred timber slab becomes round logs.
 var result=ArrayMesh.new();var wood_points:Array[Vector3]=[]
 for slot in raw.get_surface_count():
  var arrays=raw.surface_get_arrays(slot);var material=raw.surface_get_material(slot)
  var tile:Variant=material.get_shader_parameter("atlas_tile_pixels") if material is ShaderMaterial else 0.
  if not ((tile is float or tile is int) and tile>0):
   result.add_surface_from_arrays(raw.surface_get_primitive_type(slot),arrays);result.surface_set_material(result.get_surface_count()-1,material);continue
  var kept=SurfaceTool.new();kept.begin(Mesh.PRIMITIVE_TRIANGLES);var count_=0
  for i in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
   if timber_tile(arrays[Mesh.ARRAY_TEX_UV2][i]):
    for j in 3:wood_points.append(arrays[Mesh.ARRAY_VERTEX][i+j])
    continue
   for j in 3:
    var index=i+j;kept.set_normal(arrays[Mesh.ARRAY_NORMAL][index]);kept.set_uv(arrays[Mesh.ARRAY_TEX_UV][index]);kept.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][index]);kept.add_vertex(arrays[Mesh.ARRAY_VERTEX][index]);count_+=1
  if count_>0:
   var stone:Mesh=kept.commit();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,stone.surface_get_arrays(0));result.surface_set_material(result.get_surface_count()-1,material)
 assert(not wood_points.is_empty(),"Original stockade timber section is required")
 var bounds=AABB(wood_points[0],Vector3.ZERO)
 for p:Vector3 in wood_points:bounds=bounds.expand(p)
 var along_x:bool=Forms.Street.WALLS[serial][0];var axis=Vector3.RIGHT if along_x else Vector3.BACK;var back=-axis.cross(Vector3.UP)
 var count_=4 if serial==11143 else 3;var span=bounds.size.x if along_x else bounds.size.z
 var start=bounds.position.x if along_x else bounds.position.z;var step=span/count_
 var radius=minf(step*.48,(bounds.size.z if along_x else bounds.size.x)*.49)
 var skin=Forms.Street.Harbor.structure();var lowest=INF;var centers=[]
 for log_ in count_:
  var across=start+step*(log_+.5);var high=bounds.position.y
  for p:Vector3 in wood_points:
   if absf(p.dot(axis)-across)<=step*.58:high=maxf(high,p.y)
  var center=bounds.get_center()+axis*(across-bounds.get_center().dot(axis));center.y=(bounds.position.y+high)*.5
  var log_skin=Forms.Street.Harbor.structure()
  # The shared log primitive has a horizontal radial frame; rotate its complete mesh upright.
  Forms.Tina.timber_log(log_skin,Vector3.ZERO,Vector3.BACK,high-bounds.position.y,radius,"tina_hollow_bark","tina_log_end")
  Forms.append(skin,log_skin.finish(),Transform3D(Basis(Quaternion(Vector3.BACK,Vector3.UP)),center))
  lowest=minf(lowest,high);centers.append(center)
 for fraction in [.42,.69]:
  var a:Vector3=centers[0]+back*(radius+.03);var b:Vector3=centers[-1]+back*(radius+.03)
  a.y=lerpf(bounds.position.y,lowest,fraction);b.y=a.y
  Forms.Street.Harbor.rod(skin,a,b,.035,"tina_fence_rope")
 add_mesh(result,skin.finish(),Transform3D.IDENTITY);result.set_meta("source_round_timber_count",count_)
 return result

static func simple_model(serial:int,g:Dictionary)->Mesh:
 var native=skin()
 match g.mode:
  "stable":return source_stable(g)
  "logstore":return source_logstore(g)
  "hay":return source_hay(serial,g)
  "planter":
   native.part="quay_brick"
   var size_=Vector3(2.4,.85,2.4 if serial==10452 else 1.8)
   native.box(AABB(-Vector3(size_.x*.5,0,size_.z*.5),size_))
   for side in [-1,1]:
    native.box(AABB(Vector3(side*(size_.x*.5-.08)-.08,.78,-size_.z*.5),Vector3(.16,.16,size_.z)))
    native.box(AABB(Vector3(-size_.x*.5,.78,side*(size_.z*.5-.08)-.08),Vector3(size_.x,.16,.16)))
  "tub":
   dark_water(native,1.3,.6)
   native.part="timber";Kit.kili_round(native,Vector3.ZERO,[Vector2(1.15,0),Vector2(1.45,.3),Vector2(1.55,1.5),Vector2(1.38,1.5),Vector2(1.3,.4)])
  _:
   return Forms.mesh(serial,"stump" if g.mode=="stump" else "coast_logs" if g.mode=="logs" else g.mode,g,texture)
 var result=fitted(native.finish(),g)
 if g.mode=="planter":
  var combined=ArrayMesh.new();add_mesh(combined,result,Transform3D.IDENTITY)
  for part in Meadow.source("leafy_shrub"):
   add_mesh(combined,part.mesh,Transform3D(Basis.IDENTITY.scaled(Vector3(.65,.50,.65)),Vector3(0,.75,0))*part.transform,part.material)
  result=combined
 return result

static func add_mesh(result:ArrayMesh,model:Mesh,pose:Transform3D,override:Material=null):
 for slot in model.get_surface_count():
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.append_from(model,slot,pose)
  var temporary:Mesh=tool.commit();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,temporary.surface_get_arrays(0))
  result.surface_set_material(result.get_surface_count()-1,override if override!=null else model.surface_get_material(slot))

static func mesh(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)];var result:Mesh
 if serial in [11626,12169,12170,12171,12175,12176,12177,12178,12179,12180,12181,11087,11088,11089,11090,11091,11092,11108,11109]:
  result=load("res://scripts/forest/forest_native_garden.gd").mesh(serial,g)
  meshes[serial]=result
  return result
 match g.mode:
  "well_housing","roofed_well":result=roofed_well(serial,g)
  "relief","flora","ground":result=native_relief(serial,g,g.mode=="ground")
  "shared_cart":result=source_cart(serial,g)
  "pond":result=native_relief(serial,g,true)
  "existing":result=Forms.mesh(serial,Forms.kind(serial,false,g),g,texture)
  "flowering_tree":return null
  _:result=simple_model(serial,g)
 if serial in Forms.Street.WALLS or serial in Forms.Street.TOMBS or serial in Forms.Street.MUSHROOMS or serial in Forms.Street.BARRELS:
  # These shared measured forms use Harbor's .1m/pixel; joined villages retain their existing .045m/pixel vertical frame.
  result=village_measured(result)
  if serial in [11143,11145,11146]:result=rounded_stockade(serial,result)
 result.set_meta("source_graphic",serial);result.set_meta("native_source_rgba_sha256",g.source_rgba_sha256)
 meshes[serial]=result;return result

static func build(root:Node3D,model,area:String):
 var groups={};var origin:Vector2=load("res://scripts/forest/forest_freyja_regions.gd").Sites.VILLAGES[area][2]
 for row in data().areas[area]:
  var serial=int(row[2]);var at=origin+Vector2(row[0],row[1])*3.
  if not groups.has(serial):groups[serial]=[]
  groups[serial].append(Transform3D(Basis.IDENTITY,Vector3(at.x,model.surface_height(at.x,at.y),at.y)))
 batch(root,groups)

static func batch(root:Node3D,groups:Dictionary):
 var ready={}
 for serial in groups:
  if flowering_tree(serial):build_flowering_trees(root,serial,groups[serial])
  else:ready[serial]=mesh(serial)
 var flat={}
 for serial in groups:
  if ready.has(serial):flat[serial]=groups[serial]
 load("res://scripts/forest/forest_kili_art.gd").batch_meshes(root,flat,ready,"NativeEastVillageProp")
