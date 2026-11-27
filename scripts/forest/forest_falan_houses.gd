extends RefCounted
## Native roof families and surface paint, fitted to the existing saved house bounds.
const Data=preload("res://assets/maps/falan/city_building_surfaces.gd")
const Atlas=preload("res://assets/maps/falan/city_building_surfaces.png")
const SourceMesh=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Village=preload("res://scripts/forest/forest_coastal_buildings.gd")
const ArchitectureData=preload("res://assets/maps/falan/city_architecture.gd")
static var meshes:Dictionary={}
static var paint:ShaderMaterial
static var facade_paint:ShaderMaterial
static var roof_materials:Dictionary={}
static var rosette_ring:Mesh
const GREEN_SHIELD_CENTER=Vector3(4.15,8.56785,-1.30114)
# Fixed authoring stations measured from the original plaques; independent of regenerated fits.
const SIGN_STATIONS={
 10005:[Vector3(-4.72,6.712178,-2.074618),Vector2(3.844760,3.286327),"native_baker_sign"],
 10049:[Vector3(-3.57,9.916074,-2.394267),Vector2(3.207200,3.339542),"native_bar_sign"],
 10050:[Vector3(3.57,9.636111,-2.591200),Vector2(3.263467,3.449835),"native_bar_sign"],
 10078:[Vector3(4.72,7.938503,-.748839),Vector2(3.181870,2.962382),"native_weapon_sign"],
 10080:[Vector3(5.420000,10.625926,0.097616),Vector2(3.242359,2.309340),"native_inn_sign"],
}
const HOUSE_SIGNS={
 10003:[Vector3(-4.88,3.095157,-4.897622),Vector2(2.474788,1.766535)],
 10005:[Vector3(-4.88,4.644700,-4.765044),Vector2(2.474788,2.049538)],
 10049:[Vector3(-3.73,6.420910,2.914133),Vector2(2.231911,2.156787)],
 10306:[Vector3(-4.88,3.761134,-4.897622),Vector2(2.474788,1.785451)],
}
const HOUSE_LANTERNS={
 10050:[Vector3(3.63,7.717111,1.463733),Vector3(3.63,6.500428,-4.219200)],
 10076:[Vector3(4.78,4.141287,4.349122),Vector3(4.78,3.803842,-5.063910)],
 10077:[Vector3(4.78,4.067028,4.381136),Vector3(4.78,3.390766,-5.191591)],
 10304:[Vector3(4.78,3.897962,4.181705),Vector3(4.78,3.598846,-5.191591)],
}

static func body_half(style:int)->float:
 return 3.15 if style==15 else 3.5 if style==16 else 5.0 if style in [6,7,9,10,11] else 4.3

static func door_z(serial:int)->float:
 return -2.0 if serial in [10049,10050] else -1.8 if serial in [10080,10309] else 0.0

static func raw_entry(serial:int)->Array:
 var row:Array=ArchitectureData.GRAPHICS[serial];var style:int=row[8]
 if style in [2,12]:return [Vector3(0,0,6.54),Vector3.BACK]
 if style in [6,7,8,9,10,11]:return [Vector3(0,0,7.60),Vector3.BACK]
 var front=-1 if row[3]==1 else 1
 return [Vector3(front*(body_half(style)+.06),0,door_z(serial)),Vector3.RIGHT*front]

static func surface_mesh(source:Mesh,turn:Basis=Basis.IDENTITY)->Mesh:
 var arrays=source.surface_get_arrays(0)
 assert(source.get_surface_count()==1 and (arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty()),"Native building parts must remain non-indexed triangles")
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var tiles:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
 var roof_tiles={Data.TILES.blue_roof:[2.0,Data.TILES.architecture_blue_roof,Color("365d78")],Data.TILES["10006_roof"]:[3.0,Data.TILES.architecture_green_roof,Color("48695c")],Data.TILES["10007_roof"]:[3.0,Data.TILES.architecture_red_roof,Color("9c4133")],Data.TILES["10300_roof"]:[1.5,Data.TILES["10300_roof"],Color("879b98")],Data.TILES.magic_roof:[1.5,Data.TILES.magic_roof,Color("76529d")]}
 var body=SurfaceTool.new();body.begin(Mesh.PRIMITIVE_TRIANGLES)
 var roofs={}
 for i in range(0,vertices.size(),3):
  var tile:Vector2=tiles[i];var is_roof=roof_tiles.has(tile)
  if is_roof and not roofs.has(tile):
   var section=SurfaceTool.new();section.begin(Mesh.PRIMITIVE_TRIANGLES);roofs[tile]=section
  var tool:SurfaceTool=roofs[tile] if is_roof else body
  for j in range(i,i+3):
   assert(tiles[j]==tile,"A native triangle must use one surface patch")
   tool.set_color(Color(1,1,1,1 if absf(normals[j].y)<.5 and tile in [Data.TILES.plaster,Data.TILES.stone,Data.TILES["10003_base"]] else 0))
   tool.set_normal(turn*normals[j]);tool.set_uv(uv[j]*float(roof_tiles[tile][0]) if is_roof else uv[j]);tool.set_uv2(roof_tiles[tile][1] if is_roof else tiles[j]);tool.add_vertex(turn*vertices[j])
 if facade_paint==null:
  facade_paint=source.surface_get_material(0).duplicate();facade_paint.set_shader_parameter("architecture_facade",true)
 var result=body.commit();result.surface_set_material(0,facade_paint)
 for tile in roofs:
  if not roof_materials.has(tile):
   var paint:ShaderMaterial=SourceMesh.material(Atlas).duplicate()
   paint.set_shader_parameter("atlas_tile_pixels",128.0);paint.set_shader_parameter("alpha_cutout",false)
   paint.set_shader_parameter("original_palette",false);paint.set_shader_parameter("architecture_roof",true)
   paint.set_shader_parameter("base_color",roof_tiles[tile][2])
   roof_materials[tile]=paint
  var slate=roofs[tile].commit();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,slate.surface_get_arrays(0))
  result.surface_set_material(result.get_surface_count()-1,roof_materials[tile])
 return result

static func source_centered(model,anchor)->bool:
 return model.falan_area=="city" and anchor is Vector2i and ArchitectureData.BINDINGS.has(anchor) and model.props.has(anchor) and model.scenery_heights.get(anchor,0)==0 and family(anchor,model.props[anchor])>=0

static func offset(model,anchor)->Vector3:
 if not source_centered(model,anchor):return Vector3.ZERO
 var at:Vector2=ArchitectureData.BINDINGS[anchor][1]
 return Vector3(at.x-anchor.x*6,model.surface_height(at.x,at.y)-model.surface_height(anchor.x*6,anchor.y*6),at.y-anchor.y*6)

static func family(anchor,item:Dictionary)->int:
 var spec:Array=Data.LEGACY.get(anchor,[])
 if spec.is_empty() or item.kind!=spec[0] or item.rotation!=spec[1] or not is_equal_approx(float(item.scale),spec[2]):return -1
 return spec[3]

static func batch(parent:Node3D,kind:String,style:int,poses:Array):
 var key=[kind,style]
 if not meshes.has(key):meshes[key]=shape(kind,style)
 var node=MultiMeshInstance3D.new();node.name="RecoveredFalanHouses"
 node.set_meta("falan_house_family",style);node.set_meta("falan_house_kind",kind)
 node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
 node.multimesh.mesh=meshes[key];node.multimesh.instance_count=poses.size()
 for i in poses.size():
  var angle=-PI*.5 if style in [3,4,5,7,8,11,13,14,15,16] else PI if style==9 else 0.0
  if style==12:angle=-atan2(poses[i].basis.z.x,poses[i].basis.z.z)
  var local_rotation=Transform3D(Basis(Vector3.UP,angle),Vector3.ZERO)
  node.multimesh.set_instance_transform(i,poses[i]*local_rotation)
 parent.add_child(node)

static func shape(kind:String,style:int,serial:int=0)->Mesh:
 if style in [2,12]:return source_10605_shape(style==12,serial>0)
 if style>=3:return source_10003_shape(style,serial)
 var skin=SourceMesh.new([],Atlas,.045);skin.tiles=Data.TILES
 var half=6.35 if kind=="falan_shop" else 6.5
 var edge=7.4 if kind=="falan_shop" else 7.0
 var wall=7.2
 skin.part="plaster";skin.box(AABB(Vector3(-half,0,-half),Vector3(half*2,wall,half*2)))
 skin.part="stone";skin.box(AABB(Vector3(-half-.015,0,-half-.015),Vector3(half*2+.03,.75,half*2+.03)))
 skin.part="trim"
 for x in [-1,1]:
  for z in [-1,1]:skin.box(AABB(Vector3(x*(half-.18)-.18,0,z*(half-.18)-.18),Vector3(.36,wall,.36)))
 for y in [3.55,7.0]:skin.box(AABB(Vector3(-half-.02,y,-half-.02),Vector3(half*2+.04,.18,half*2+.04)))
 for normal:Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
  var horizontal=Vector3.UP.cross(normal)
  var face=normal*(half+.035)
  for side in [-1,1]:
   for y in [1.9,5.2]:Village.detail(skin,face+horizontal*side*half*.57+Vector3.UP*y,horizontal,"window",2.8)
  if normal==Vector3.BACK:Village.detail(skin,face+Vector3.UP*2.1,horizontal,"door",4.25)
 var profile=[Vector2(-edge,wall),Vector2(-edge*.93,wall+1),Vector2(-edge*.77,wall+3),
  Vector2(-edge*.5,wall+4.8),Vector2(0,wall+5.7),Vector2(edge*.5,wall+4.8),
  Vector2(edge*.77,wall+3),Vector2(edge*.93,wall+1),Vector2(edge,wall)] if style==0 else [
  Vector2(-edge,wall),Vector2(-edge*.86,wall+.8),Vector2(0,wall+5.4),Vector2(edge*.86,wall+.8),Vector2(edge,wall)]
 skin.part="blue_roof"
 for i in profile.size()-1:
  var a:Vector2=profile[i];var b:Vector2=profile[i+1]
  skin.quad(Vector3(a.x,a.y,edge),Vector3(a.x,a.y,-edge),Vector3(b.x,b.y,-edge),Vector3(b.x,b.y,edge))
 if style==0:
  skin.part="trim"
  skin.box(AABB(Vector3(-.23,wall+5.58,-edge+.20),Vector3(.46,.24,edge*2-.40)))
  for i in 8:
   var z=lerpf(-edge+.65,edge-.65,float(i)/7)
   skin.box(AABB(Vector3(-.19,wall+5.80,z-.24),Vector3(.38,.42,.48)))
 for side in [-1,1]:
  skin.part="plaster"
  for i in profile.size()-1:
   var a:Vector2=profile[i];var b:Vector2=profile[i+1]
   var low=Vector3(0,wall,side*half)
   var first=Vector3(a.x,a.y,side*half);var next=Vector3(b.x,b.y,side*half)
   if side>0:skin.quad(first,next,low,low)
   else:skin.quad(next,first,low,low)
  skin.part="trim"
  skin.box(AABB(Vector3(-.34,wall+5.4,side*(edge-.7)-.6),Vector3(.68,.5,1.2)))
  skin.part="timber"
  skin.box(AABB(Vector3(-.11,wall,side*(half+.025)-.06),Vector3(.22,5.4,.12)))
  skin.box(AABB(Vector3(-half,wall+.22,side*(half+.025)-.06),Vector3(half*2,.18,.12)))
  for along in [-1,1]:dormer(skin,side,along*half*.45,half,wall)
 var result=skin.finish()
 if paint==null:
  paint=result.surface_get_material(0).duplicate()
  paint.set_shader_parameter("original_palette",false)
 result.surface_set_material(0,paint)
 return result

static func dormer(skin,side:int,z:float,half:float,wall:float,lift:float=0.0,projecting:bool=false):
 var front=side*half*(1.04 if projecting else .78);var back=side*half*(.60 if projecting else .52);var base=wall+2.0+lift
 skin.part="trim"
 for i in 8:
  var a=i*PI/8;var b=(i+1)*PI/8
  var first=Vector3(front,base+sin(a)*.95,z+cos(a)*.88)
  var next=Vector3(front,base+sin(b)*.95,z+cos(b)*.88)
  var behind=Vector3(back,first.y,first.z);var behind_next=Vector3(back,next.y,next.z)
  if side>0:skin.quad(next,first,behind,behind_next)
  else:skin.quad(first,next,behind_next,behind)
 Village.detail(skin,Vector3(front+side*.025,base-.05,z),Vector3.FORWARD*side,"dormer_window",2.15)


static func source_10605_shape(reverse:bool=false,native_city:bool=false)->Mesh:
 var skin=SourceMesh.new([],Atlas,.045);skin.tiles=Data.TILES
 var width=5.2;var length=6.5;var edge=5.6;var wall=7.2
 skin.part="stone"
 skin.box(AABB(Vector3(-width,0,-length),Vector3(width*2,wall,length*2)))
 for side in [-1,1]:
  var normal=Vector3(side,0,0);var horizontal=Vector3.UP.cross(normal)
  for i in 8:
   var z=lerpf(-length*.78,length*.78,float(i)/7)
   Village.detail(skin,Vector3(side*(width+.035),5.25,z),horizontal,"10609_window" if reverse else "10605_window",3.5)
  skin.part="trim"
  for z in [-4.7,-1.55,1.55,4.7]:
   skin.box(AABB(Vector3(side*(width+.22)-.22,0,z-.23),Vector3(.44,2.7,.46)))
 Village.detail(skin,Vector3(0,2.4,length+.04),Vector3.RIGHT,"door",5.0)
 var profile=[Vector2(-edge,wall),Vector2(-edge*.93,wall+1),Vector2(-edge*.77,wall+3),
  Vector2(-edge*.5,wall+4.8),Vector2(0,wall+5.7),Vector2(edge*.5,wall+4.8),
  Vector2(edge*.77,wall+3),Vector2(edge*.93,wall+1),Vector2(edge,wall)]
 skin.part="blue_roof"
 if native_city:curved_roof(skin,profile,-length-.5,length+.5,"blue_roof",true)
 else:
  for i in profile.size()-1:
   var a:Vector2=profile[i];var b:Vector2=profile[i+1]
   skin.quad(Vector3(a.x,a.y,length+.5),Vector3(a.x,a.y,-length-.5),Vector3(b.x,b.y,-length-.5),Vector3(b.x,b.y,length+.5))
 for side in [-1,1]:
  skin.part="10003_wood" if native_city else "stone"
  for i in profile.size()-1:
   var a:Vector2=profile[i];var b:Vector2=profile[i+1]
   var low=Vector3(0,wall,side*length)
   var first=Vector3(a.x,a.y,side*length);var next=Vector3(b.x,b.y,side*length)
   if side>0:skin.quad(first,next,low,low)
   else:skin.quad(next,first,low,low)
  for z in [-length*.44,length*.44]:dormer(skin,side,z,width,wall,1.1,native_city)
 if native_city:
  skin.part="10003_wood"
  for side in [-1,1]:
   skin.box(AABB(Vector3(-width,wall-.15,side*(length+.08)-.10),Vector3(width*2,.28,.20)))
   skin.box(AABB(Vector3(-.12,wall,side*(length+.10)-.12),Vector3(.24,5.5,.24)))
  skin.part="trim"
  skin.box(AABB(Vector3(-2.9,5.65,length+.10),Vector3(5.8,.34,.70)))
  for x in [-2.65,2.65]:skin.box(AABB(Vector3(x-.15,5.25,length+.08),Vector3(.30,.45,.48)))
  native_lantern(skin,Vector3(-4.7 if reverse else 4.7,6.0,length+.30),1)
  # The unseen end continues the confirmed high window band without adding an entrance.
  for x in [-2.6,2.6]:Village.detail(skin,Vector3(x,5.25,-length-.06),Vector3.LEFT,"10609_window" if reverse else "10605_window",3.5)
 skin.part="trim"
 skin.box(AABB(Vector3(-.23,wall+5.58,-length+.2),Vector3(.46,.24,length*2-.4)))
 for i in 10:
  var z=lerpf(-length+.5,length-.5,float(i)/9)
  skin.box(AABB(Vector3(-.19,wall+5.8,z-.19),Vector3(.38,.42,.38)))
 var result=skin.finish()
 if paint==null:
  paint=result.surface_get_material(0).duplicate()
  paint.set_shader_parameter("original_palette",false)
 result.surface_set_material(0,paint)
 return result

static func source_10003_shape(style:int,serial:int=0)->Mesh:
 var roof="10007_roof" if style==4 else "10006_roof" if style==5 else "blue_roof"
 var skin=SourceMesh.new([],Atlas,.045);skin.tiles=Data.TILES
 var half=body_half(style)
 # At the native camera, edge-one houses expose their negative-X long facade.
 var front=-1 if serial>0 and ArchitectureData.GRAPHICS[serial][3]==1 else 1
 var length=9.0 if style==17 else 6.3;var edge=half+.5;var roof_end=length+.6;var wall=6.0
 var profile=source_roof_profile(edge,wall,style,serial)
 var ridge=0.0
 for point:Vector2 in profile:ridge=maxf(ridge,point.y)
 skin.part="plaster"
 if serial==10080:
  skin.box(AABB(Vector3(-half,0,-length),Vector3(half*2-1.6,wall,length*2)))
  skin.box(AABB(Vector3(half-1.6,0,door_z(serial)-1.3),Vector3(1.6,wall,2.6)))
 else:skin.box(AABB(Vector3(-half,0,-length),Vector3(half*2,wall,length*2)))
 skin.part="stone" if style in [6,7] else "10003_base"
 skin.box(AABB(Vector3(-half-.02,0,-length-.02),Vector3(half*2+.04,1.3,length*2+.04)))
 skin.part="trim"
 skin.box(AABB(Vector3(-half-.04,1.3,-length-.04),Vector3(half*2+.08,.15,length*2+.08)))
 skin.part="trim"
 for x in [-1,1]:
  for z in [-1,1]:skin.box(AABB(Vector3(x*(half-.18)-.18,0,z*(length-.18)-.18),Vector3(.36,wall,.36)))
  for z in [-1,1]:
   for course in 9:
    var size_=Vector3(.58,.54,.32) if course%2==0 else Vector3(.32,.54,.58)
    skin.box(AABB(Vector3(x*(half-size_.x*.5+.06),course*.66+.04+size_.y*.5,z*(length-size_.z*.5+.06))-size_*.5,size_))
 skin.box(AABB(Vector3(-half-.08,wall-.28,-length-.08),Vector3(half*2+.16,.22,length*2+.16)))
 for side in [-1,1]:
  var horizontal=Vector3.FORWARD*side
  if serial==10080 and side==front:continue
  if style==6 and side==front:
   Village.detail(skin,Vector3(side*(half+.04),2.85,0),horizontal,"10081_grille",8.8)
  else:
   var stations=[-5.0,1.1] if serial in [10049,10050] and side==front else [-5.0,3.8] if serial==10309 and side==front else [-5.8,5.8] if style==17 else [-3.8,3.8]
   for z in stations:
    for level in ([1.55,4.5] if style==17 or (serial>0 and style==16) else [3.5]):
     var two_storey=style==17 or (serial>0 and style==16)
     var window_height=2.15 if two_storey else 3.1
     var low=level-window_height*.45 if two_storey else 2.10
     var high=level+window_height*.45 if two_storey else 4.92
     Village.detail(skin,Vector3(side*(half+.04),level,z),horizontal,"10003_window",window_height)
     skin.part="trim"
     for y in [low,high]:skin.box(AABB(Vector3(side*(half+.10)-.10,y-.08,z-1.0),Vector3(.20,.16,2.0)))
     for offset in [-.89,.89]:skin.box(AABB(Vector3(side*(half+.08)-.08,low if two_storey else 2.12,z+offset-.07),Vector3(.16,window_height*.9 if two_storey else 2.76,.14)))
 if style<6 or style in [13,14,15,16,17]:
  var entry=Vector3(0,0,door_z(serial))
  Village.detail(skin,Vector3(front*(half+.06),2.25,0)+entry,Vector3.FORWARD*front,"10003_door",4.5)
  skin.part="stone" if style==17 else "10003_wood"
  for z in [-1.3,1.3]:skin.box(AABB(Vector3(front*(half+.18)-.14,0,z-.15)+entry,Vector3(.28,3.65 if serial>0 else 4.1,.30)))
  if serial==0:skin.box(AABB(Vector3(front*(half+.19)-.16,4.0,-1.45),Vector3(.32,.22,2.9)))
  for i in 12:
   var a=i*PI/12;var b=(i+1)*PI/12
   var points=[Vector3(front*(half+.20),3.65+sin(a)*.75,cos(a)),Vector3(front*(half+.20),3.65+sin(a)*1.02,cos(a)*1.28),Vector3(front*(half+.20),3.65+sin(b)*1.02,cos(b)*1.28),Vector3(front*(half+.20),3.65+sin(b)*.75,cos(b))]
   for j in points.size():points[j]+=entry
   if front<0:points.reverse()
   skin.quad(points[0],points[1],points[2],points[3])
   if serial>0:
    var back=Vector3.LEFT*front*.18
    skin.quad(points[3]+back,points[2]+back,points[1]+back,points[0]+back)
    for edge_index in [0,2]:
     var first:Vector3=points[edge_index];var next:Vector3=points[edge_index+1]
     skin.quad(first+back,first,next,next+back)
 curved_roof(skin,profile,-roof_end,roof_end,roof,serial>0)
 var gable_outline=PackedVector2Array(profile)
 gable_outline.append(Vector2(edge,wall-.02));gable_outline.append(Vector2(-edge,wall-.02))
 var indices=Geometry2D.triangulate_polygon(gable_outline)
 assert(not indices.is_empty(),"The native curved gable must remain a simple polygon")
 for side in [-1,1]:
  skin.part="plaster"
  for i in range(0,indices.size(),3):
   var points=[]
   for index in [indices[i],indices[i+1],indices[i+2]]:points.append(Vector3(gable_outline[index].x,gable_outline[index].y,side*length))
   if (points[2]-points[0]).cross(points[1]-points[0]).z*side<0:points.reverse()
   skin.quad(points[0],points[1],points[2],points[0])
  skin.part="10003_wood"
  skin.box(AABB(Vector3(-half,wall-.08,side*length-.055),Vector3(half*2,.18,.11)))
  var beam_top=roof_height(profile,0)-.10 if serial>0 else ridge
  skin.box(AABB(Vector3(-.1,wall,side*length-.055),Vector3(.2,maxf(.1,beam_top-wall),.11)))
  if serial>0:
   # The original roof edge has a deep timber fascia; carry it around the hidden end.
   for i in profile.size()-1:
    var a:Vector2=profile[i];var b:Vector2=profile[i+1]
    var first=Vector3(a.x,a.y-.16,side*(length+.11))
    var next=Vector3(b.x,b.y-.16,side*(length+.11))
    var low_first=first-Vector3.UP*.25;var low_next=next-Vector3.UP*.25
    var back=Vector3.FORWARD*side*.16
    var points=[low_first,first,next,low_next]
    if side<0:points.reverse()
    skin.quad(points[0],points[1],points[2],points[3])
    if side>0:skin.quad(low_next+back,low_first+back,low_first,low_next)
    else:skin.quad(low_next,low_first,low_first+back,low_next+back)
  if side<0 and serial>0:
   var crown=profile[0]
   for point:Vector2 in profile:
    if point.y>crown.y:crown=point
   Village.detail(skin,Vector3(crown.x,wall+(crown.y-wall)*.38,side*(length+.08)),Vector3.RIGHT*side,"10003_window",1.65)
  if side>0 and serial in [10003,10009,10076,10077,10081,10082,10083,10304,10306,10308]:
   var at=Vector3(-.9,wall+(ridge-wall)*.27,side*(length+.16))
   source_rosette(skin,at,side)
   skin.panel(at-Vector3(2.0,1.6,0),at+Vector3(-2.0,1.6,0),at+Vector3(2.0,1.6,0),at+Vector3(2.0,-1.6,0),"10003_gable_rosette")
  if style in [4,5]:
   var center=Vector3(.3,9.4,side*(length+.13))
   source_rosette(skin,center,side)
   Village.detail(skin,center+Vector3.BACK*side*.10,Vector3.RIGHT*side,"shop_medallion",3.9)
 if style==17:
  # Original 10310 has two ridge chimneys and two long-side dormers.
  var top=roof_height(profile,0)
  for z in [-4.6,4.6]:
   skin.part="plaster";skin.box(AABB(Vector3(-.72,top-.45,z-.72),Vector3(1.44,.9,1.44)))
   var corners=[Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]
   skin.part="blue_roof"
   for i in 4:
    var a:Vector2=corners[i];var b:Vector2=corners[(i+1)%4]
    skin.quad(Vector3(a.x*.78,top+.45,z+a.y*.78),Vector3(b.x*.78,top+.45,z+b.y*.78),Vector3(b.x*.39,top+2.45,z+b.y*.39),Vector3(a.x*.39,top+2.45,z+a.y*.39))
   skin.part="trim"
   for x in [-.43,.43]:skin.box(AABB(Vector3(x-.08,top+2.43,z-.51),Vector3(.16,.16,1.02)))
   for dz in [-.43,.43]:skin.box(AABB(Vector3(-.35,top+2.43,z+dz-.08),Vector3(.7,.16,.16)))
   skin.part="10003_wood";skin.box(AABB(Vector3(-.34,top+2.44,z-.34),Vector3(.68,.015,.68)))
   for side in [-1,1]:
    skin.part="plaster";skin.box(AABB(Vector3(side*(half-.2)-.35,wall-.1,z-.9),Vector3(.7,2.5,1.8)))
    dormer(skin,side,z,half,wall,.25,true)
 elif style in [10,16]:
  for z in [-4.9,4.9]:
   for x in [-2.0,2.0]:
    if serial>0:
     native_box_dormer(skin,1 if x>0 else -1,z,half,profile,roof)
    else:
     skin.part="plaster"
     skin.box(AABB(Vector3(x-.38,9.4,z-.42),Vector3(.76,1.45,.84)))
     skin.part=roof
     skin.box(AABB(Vector3(x-.53,10.7,z-.53),Vector3(1.06,.65,1.06)))
 else:
  for z in ([-4.2,0.0,4.2] if style in [4,5,15] else [-4.2,4.2]):
   source_10003_beam(skin,z,profile,roof,serial>0)
 if style in [3,13,14]:
  # The far gable's projecting bay and its timber frame use the original facade window.
  skin.part="10003_wood"
  for x in [-1.8,1.8]:skin.box(AABB(Vector3(x-.18,0,length+.05),Vector3(.36,4.5,.35)))
  skin.part="plaster"
  skin.box(AABB(Vector3(-1.65,1.25,length+.03),Vector3(3.3,3.1,.75 if serial>0 else .35)))
  Village.detail(skin,Vector3(0,3,length+(.81 if serial>0 else .40)),Vector3.RIGHT,"10003_bay_window",3.1)
  skin.part="10003_wood"
  for i in 10:
   var a=PI*float(i)/10;var b=PI*float(i+1)/10
   var depth=length+(.90 if serial>0 else .43)
   var inner_a=Vector3(cos(a)*1.45,4.0+sin(a)*1.55,depth)
   var inner_b=Vector3(cos(b)*1.45,4.0+sin(b)*1.55,depth)
   var outer_a=Vector3(cos(a)*1.8,4.0+sin(a)*1.9,depth)
   var outer_b=Vector3(cos(b)*1.8,4.0+sin(b)*1.9,depth)
   skin.quad(inner_b,outer_b,outer_a,inner_a)
   if serial>0:
    var back=Vector3.FORWARD*.28
    skin.quad(outer_a+back,outer_b+back,inner_b+back,inner_a+back)
    skin.quad(inner_a+back,inner_b+back,inner_b,inner_a)
    skin.quad(outer_a,outer_b,outer_b+back,outer_a+back)
  skin.part=roof
  var z0=length-.02;var z1=length+.65
  skin.quad(Vector3(-2.05,4.35,z1),Vector3(-2.05,4.35,z0),Vector3(0,6.1,z0),Vector3(0,6.1,z1))
  skin.quad(Vector3(0,6.1,z1),Vector3(0,6.1,z0),Vector3(2.05,4.35,z0),Vector3(2.05,4.35,z1))
 elif style in [4,5]:
  var center=Vector3(0,0,length-.15);var radius=1.7;var slices=12
  skin.part="plaster"
  for i in slices:
   var a=float(i)*TAU/slices;var b=float(i+1)*TAU/slices
   var p=center+Vector3(cos(a)*radius,0,sin(a)*radius)
   var q=center+Vector3(cos(b)*radius,0,sin(b)*radius)
   skin.part="stone";skin.quad(q,q+Vector3.UP*.75,p+Vector3.UP*.75,p)
   skin.part="plaster";skin.quad(q+Vector3.UP*.75,q+Vector3.UP*4.3,p+Vector3.UP*4.3,p+Vector3.UP*.75)
  for angle in [PI/6,PI/2]:
   var normal=Vector3(cos(angle),0,sin(angle))
   Village.detail(skin,center+normal*(radius+.04)+Vector3.UP*2.85,Vector3.UP.cross(normal),"10003_bay_window",2.2)
  skin.part="trim"
  for i in slices:
   var a=float(i)*TAU/slices;var b=float(i+1)*TAU/slices
   skin.quad(center+Vector3(cos(a)*radius*1.10,4.28,sin(a)*radius*1.10),center+Vector3(cos(a)*radius,4.28,sin(a)*radius),center+Vector3(cos(b)*radius,4.28,sin(b)*radius),center+Vector3(cos(b)*radius*1.10,4.28,sin(b)*radius*1.10))
  skin.part=roof
  var hood=[Vector2(1.12,4.3),Vector2(1.06,4.75),Vector2(.80,5.5),Vector2(.50,6.2),Vector2(0,6.2)]
  for ring in hood.size()-1:
   var lower:Vector2=hood[ring];var upper:Vector2=hood[ring+1]
   for i in slices:
    var a=float(i)*TAU/slices;var b=float(i+1)*TAU/slices
    skin.quad(center+Vector3(cos(a)*radius*upper.x,upper.y,sin(a)*radius*upper.x),center+Vector3(cos(a)*radius*lower.x,lower.y,sin(a)*radius*lower.x),center+Vector3(cos(b)*radius*lower.x,lower.y,sin(b)*radius*lower.x),center+Vector3(cos(b)*radius*upper.x,upper.y,sin(b)*radius*upper.x))
 else:
  if serial>0:
   native_bay(skin,Vector3(0,0,length),Basis.IDENTITY,roof)
   if style==9:
    for z in [-3.8,3.8]:native_bay(skin,Vector3(front*half,0,z),Basis(Vector3.UP,front*PI*.5),roof,.72)
  else:
   skin.part="plaster"
   skin.box(AABB(Vector3(-1.35,1.0,length-.25),Vector3(2.7,3.6,.85)))
   Village.detail(skin,Vector3(0,3,length+.62),Vector3.RIGHT,"10081_bay",3.6)
   skin.part=roof
   var z0=length-.25;var z1=length+.65
   skin.quad(Vector3(-1.55,4.6,z1),Vector3(-1.55,4.6,z0),Vector3(0,5.55,z0),Vector3(0,5.55,z1))
   skin.quad(Vector3(0,5.55,z1),Vector3(0,5.55,z0),Vector3(1.55,4.6,z0),Vector3(1.55,4.6,z1))
  if style==11:
   skin.part="trim"
   skin.box(AABB(Vector3(front*(half+.22)-.2,1.65,-1.35),Vector3(.4,.4,2.7)))
   Village.detail(skin,Vector3(front*(half+.44),2.25,0),Vector3.FORWARD*front,"10308_flowers",3.3)
 if style==14:
  if serial>0:
   # Three crowns are visible in 10080; the occluded fourth continues the same corner design.
   for side in [-1,1]:
    for z in [-5.2,3.4]:source_shop_tower(skin,Vector3(side*(half+.55),0,z),true)
  else:
   for z in [-3.6,3.6]:source_shop_tower(skin,Vector3(half-.65,0,z))
 if style==13:
  skin.part="trim"
  for z in [-1.7,1.7]:skin.box(AABB(Vector3(front*(half+.275)-.225,0,z-.18),Vector3(.45,5.0,.36)))
  skin.box(AABB(Vector3(front*(half+.275)-.225,4.8,-1.9),Vector3(.45,.6,3.8)))
 if style==5:
  var center=Vector3(4.15,8.268843,-1.286136) if serial==10079 else GREEN_SHIELD_CENTER
  center.x*=front
  skin.part="trim"
  skin.box(AABB(center+Vector3(-.08,-2.0,-.08),Vector3(.16,1.05,.16)))
  var shield_outline=[Vector2(-.83,1.25),Vector2(-.62,1.02),Vector2(0,.96),Vector2(.78,1.25),Vector2(.72,-.25),Vector2(.56,-.75),Vector2(0,-1.15),Vector2(-.64,-.65)]
  for i in shield_outline.size():
   var a=center+Vector3(0,shield_outline[i].y,-shield_outline[i].x);var b=center+Vector3(0,shield_outline[(i+1)%shield_outline.size()].y,-shield_outline[(i+1)%shield_outline.size()].x)
   var back=Vector3.RIGHT*.12*front
   if front>0:
    skin.quad(a-back,b-back,b,a)
    skin.quad(center-back,b-back,a-back,center-back)
   else:
    skin.quad(a,b,b-back,a-back)
    skin.quad(center-back,a-back,b-back,center-back)
  Village.detail(skin,center+Vector3.RIGHT*.015*front,Vector3.FORWARD*front,"shop_shield",3.6)
 if serial>0:native_frontage(skin,serial,front,half,length,wall,profile,roof)
 var result=skin.finish()
 if paint==null:
  paint=result.surface_get_material(0).duplicate()
  paint.set_shader_parameter("original_palette",false)
 result.surface_set_material(0,paint)
 return result

static func source_roof_profile(edge:float,wall:float,style:int,serial:int=0)->Array:
 var native:Array=ArchitectureData.GRAPHICS[serial if serial>0 else 10078 if style in [4,5] else 10077][4]
 var bottom=INF
 for point:Vector2 in native:bottom=minf(bottom,point.y)
 var result=[]
 for point:Vector2 in native:
  var across=point.x if serial==0 else inverse_lerp(native[0].x,native[-1].x,point.x)
  result.append(Vector2(lerpf(-edge,edge,across),wall+point.y-bottom))
 return result

static func native_box_dormer(skin,side:int,z:float,half:float,profile:Array,roof:String):
 var front=side*(half+.12);var back=side*half*.4
 var y=roof_height(profile,side*half*.55)-.55
 skin.part="plaster";skin.box(AABB(Vector3(minf(front,back),y,z-.72),Vector3(absf(front-back),1.85,1.44)))
 Village.detail(skin,Vector3(front+side*.04,y+.8,z),Vector3.FORWARD*side,"dormer_window",2.15)
 skin.part="plaster"
 for end in [front,back]:
  var a=Vector3(end,y+1.7,z-.9);var b=Vector3(end,y+2.3,z);var c=Vector3(end,y+1.7,z+.9)
  if (end==front)==(side>0):skin.quad(c,b,a,a)
  else:skin.quad(a,b,c,c)
 skin.part=roof
 for direction in [-1,1]:
  var a=Vector3(front,y+1.7,z+direction*.9);var b=Vector3(back,y+1.7,z+direction*.9)
  var c=Vector3(back,y+2.3,z);var d=Vector3(front,y+2.3,z)
  if direction*side>0:skin.quad(a,b,c,d)
  else:skin.quad(d,c,b,a)

static func native_bay(skin,origin:Vector3,turn:Basis,roof:String,depth:float=1.0):
 var outline=[Vector2(-1.6,-.12),Vector2(-1.6,.65),Vector2(-.95,1.25),Vector2(.95,1.25),Vector2(1.6,.65),Vector2(1.6,-.12)]
 for i in outline.size()-1:
  var first:Vector2=outline[i];var next:Vector2=outline[i+1]
  var a=origin+turn*Vector3(first.x,0,first.y*depth);var b=origin+turn*Vector3(next.x,0,next.y*depth)
  skin.part="plaster";skin.quad(b,a,a+Vector3.UP*4.7,b+Vector3.UP*4.7)
  skin.part="stone"
  for y in [.12,.65]:skin.quad(b+Vector3.UP*y,a+Vector3.UP*y,a+Vector3.UP*(y+.18),b+Vector3.UP*(y+.18))
  var tangent=(b-a).normalized();var normal=tangent.cross(Vector3.UP)
  Village.detail(skin,(a+b)*.5+normal*.045+Vector3.UP*2.9,tangent,"10081_bay",2.9 if i==2 else 2.0)
  skin.part=roof
  var top=origin+turn*Vector3(0,5.85,.35*depth)
  skin.quad(b+Vector3.UP*4.7,a+Vector3.UP*4.7,top,top)

static func native_frontage(skin,serial:int,front:int,half:float,length:float,wall:float,profile:Array,roof:String):
 if SIGN_STATIONS.has(serial):
  var row:Array=SIGN_STATIONS[serial];var at:Vector3=row[0];var size_:Vector2=row[1]
  native_panel(skin,at,Vector3.FORWARD*front,size_,row[2])
  if serial in [10049,10050,10080]:
   skin.part="10003_wood"
   skin.box(AABB(at+Vector3(-front*.08-.05,-size_.y*(64.0/112.0)*.38,-size_.x*.43),Vector3(.10,size_.y*(64.0/112.0)*.76,size_.x*.86)))
   for side in [-1,1]:
    var foot=Vector3(at.x,roof_height(profile,at.x),at.z+side*size_.x*.52)
    var top=at.y+size_.y*.29+.25
    skin.box(AABB(foot-Vector3(.08,0,.08),Vector3(.16,maxf(.2,top-foot.y),.16)))
 if HOUSE_SIGNS.has(serial):
  var row:Array=HOUSE_SIGNS[serial];var at:Vector3=row[0]
  skin.part="10003_wood";skin.box(AABB(at+Vector3(-.06,.65,-.56),Vector3(.12,.12,1.0)))
  native_panel(skin,at,Vector3.FORWARD*front,row[1],"native_house_sign")
 for at:Vector3 in HOUSE_LANTERNS.get(serial,[]):native_lantern(skin,at,front)
 if serial in [10049,10050]:
  var p=Vector3(half-.45,0,length-.65);var height=wall+3.5
  skin.part="stone";skin.box(AABB(p-Vector3(.66,0,.72),Vector3(1.32,height,1.44)))
  skin.part="trim"
  for i in ceili(height/.75):
   var span=1.65 if i%2==0 else 1.4
   skin.box(AABB(p+Vector3(-span*.5,i*.75,-.85),Vector3(span,.22,1.7)))
  skin.part="10003_wood";skin.box(AABB(p+Vector3(-.48,height+.015,-.54),Vector3(.96,.02,1.08)))
  skin.part="trim"
  for side in [-1,1]:
   skin.box(AABB(p+Vector3(side*.65-.12,height-.12,-.85),Vector3(.24,.4,1.7)))
   skin.box(AABB(p+Vector3(-.85,height-.12,side*.72-.12),Vector3(1.7,.4,.24)))
 if serial in [10003,10005,10009,10076,10077,10304,10306]:
  # The native bay's canopy is curved and projects beyond its timber arch.
  var contour=[Vector2(-2.15,4.25),Vector2(-1.94,4.63),Vector2(-1.55,5.29),Vector2(-.93,5.94),Vector2(0,6.35),Vector2(.93,5.94),Vector2(1.55,5.29),Vector2(1.94,4.63),Vector2(2.15,4.25)]
  curved_roof(skin,contour,length+.03,length+1.03,roof,true)
  skin.part="10003_wood"
  for side in [-1,1]:
   var at=Vector3(side*1.8,0,length+.80)
   skin.box(AABB(at-Vector3(.22,0,.22),Vector3(.44,4.5,.44)))
   for y in [.12,.65,3.9,4.35]:skin.box(AABB(at+Vector3(-.30,y,-.30),Vector3(.6,.19,.6)))
 if serial in [10080,10309,10310]:
  var entry=Vector3(0,0,door_z(serial))
  var peak=roof_height(profile,0)-.40
  skin.part="plaster"
  var a=Vector3(front*(half+.05),wall,-2.4)+entry;var b=Vector3(front*(half+.05),peak,0)+entry;var c=Vector3(front*(half+.05),wall,2.4)+entry
  if front>0:skin.quad(c,b,a,a)
  else:skin.quad(a,b,c,c)
  skin.part=roof
  for side in [-1,1]:
   var a_=Vector3(front*(half+1.0),wall,side*2.65)+entry;var b_=Vector3(front*(half-1.1),wall,side*2.65)+entry
   var c_=Vector3(front*(half-1.1),peak+.18,0)+entry;var d_=Vector3(front*(half+1.0),peak+.18,0)+entry
   if side*front>0:skin.quad(a_,b_,c_,d_)
   else:skin.quad(d_,c_,b_,a_)

  Village.detail(skin,Vector3(front*(half+.10),wall+(.85 if serial==10310 else .35),0)+entry,Vector3.FORWARD*front,"10003_window",2.6 if serial==10310 else 2.1)
  skin.part="10003_wood"
  var arch_radius=1.7 if serial==10310 else 1.4
  var arch_face=half+(.78 if serial==10310 else .4)
  for side in [-1,1]:
   var z=side*arch_radius
   skin.box(AABB(Vector3(front*(arch_face-.12)-.20,0,z-.20)+entry,Vector3(.4,4.2,.4)))
   if serial==10310:
    skin.part="trim"
    for y in [.08,.65,3.8]:skin.box(AABB(Vector3(front*(arch_face-.12)-.29,y,z-.29)+entry,Vector3(.58,.20,.58)))
    skin.part="10003_wood"
    native_lantern(skin,Vector3(front*(half+.78),3.35,side*2.17)+entry,front)
  for i in 16:
   var t=i*PI/16;var u=(i+1)*PI/16
   var radius=1.45 if serial==10310 else 1.2
   var spring=3.8 if serial==10310 else 3.6
   var a_=Vector3(front*arch_face,spring+sin(t)*radius,cos(t)*radius)+entry;var b_=Vector3(front*arch_face,spring+sin(t)*(radius+.35),cos(t)*(radius+.35))+entry
   var c_=Vector3(front*arch_face,spring+sin(u)*(radius+.35),cos(u)*(radius+.35))+entry;var d_=Vector3(front*arch_face,spring+sin(u)*radius,cos(u)*radius)+entry
   if front>0:skin.quad(a_,b_,c_,d_)
   else:skin.quad(d_,c_,b_,a_)
   var behind=Vector3.LEFT*front*.28
   if front>0:skin.quad(d_+behind,c_+behind,b_+behind,a_+behind)
   else:skin.quad(a_+behind,b_+behind,c_+behind,d_+behind)
   for edge in [[a_+behind,d_+behind,d_,a_],[b_,c_,c_+behind,b_+behind]]:
    if front>0:edge.reverse()
    skin.quad(edge[0],edge[1],edge[2],edge[3])


static func native_panel(skin,at:Vector3,tangent:Vector3,size_:Vector2,feature:String):
 var right=tangent*size_.x*.5;var up=Vector3.UP*size_.y*.5
 skin.panel(at-right-up,at-right+up,at+right+up,at+right-up,feature)

static func native_lantern(skin,at:Vector3,front:int):
 skin.part="trim";skin.box(AABB(at-Vector3(.23,.45,.34),Vector3(.46,.90,.68)))
 skin.part="10003_wood"
 for y in [-.49,.45]:skin.box(AABB(at+Vector3(-.28,y,-.39),Vector3(.56,.12,.78)))
 for x in [-.24,.24]:
  for z in [-.35,.35]:skin.box(AABB(at+Vector3(x-.04,-.45,z-.04),Vector3(.08,.90,.08)))
 skin.box(AABB(at+Vector3(-.06,.55,-.06),Vector3(.12,.30,.12)))
 skin.box(AABB(at+Vector3(-.38 if front>0 else -.06,.80,-.06),Vector3(.44,.12,.12)))
 skin.quad(at+Vector3(-.28,-.49,.39),at+Vector3(.28,-.49,.39),at+Vector3(.28,-.49,-.39),at+Vector3(-.28,-.49,-.39))

static func source_rosette(skin,center:Vector3,side:int):
 if rosette_ring==null:
  var ring=TorusMesh.new();ring.inner_radius=.88;ring.outer_radius=1.04;ring.rings=32;ring.ring_segments=8;rosette_ring=ring
 var pose=Transform3D(Basis(Vector3.RIGHT,side*PI*.5).scaled(Vector3(1,1.2,1)),center)
 var normal=pose.basis.inverse().transposed()
 var arrays=rosette_ring.surface_get_arrays(0);var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 for index in indices:
  skin.surface.set_normal((normal*normals[index]).normalized());skin.surface.set_uv2(Data.TILES.trim);skin.surface.set_uv(uv[index]);skin.surface.add_vertex(pose*points[index])

static func curved_roof(skin,profile:Array,back:float,front:float,roof:String,solid_edges:bool=false):
 var arc=0.0;var pitch=3.0 if roof in ["10006_roof","10007_roof"] else 2.0
 for i in profile.size()-1:
  var a:Vector2=profile[i];var b:Vector2=profile[i+1];var next=arc+a.distance_to(b)
  var vertices=[Vector3(a.x,a.y,front),Vector3(a.x,a.y,back),Vector3(b.x,b.y,back),Vector3(b.x,b.y,front)]
  var uv=[Vector2(arc,front),Vector2(arc,back),Vector2(next,back),Vector2(next,front)]
  var normal:Vector3=(vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
  for j in [0,1,2,0,2,3]:
   skin.surface.set_normal(normal);skin.surface.set_uv2(Data.TILES[roof]);skin.surface.set_uv(uv[j]/pitch);skin.surface.add_vertex(vertices[j])
  if solid_edges:
   var under=Vector3.DOWN*.15
   skin.part=roof;skin.quad(vertices[3]+under,vertices[2]+under,vertices[1]+under,vertices[0]+under)
   skin.part="10003_wood"
   skin.quad(vertices[0]+under,vertices[0],vertices[3],vertices[3]+under)
   skin.quad(vertices[2]+under,vertices[2],vertices[1],vertices[1]+under)
   if i==0:skin.quad(vertices[1]+under,vertices[1],vertices[0],vertices[0]+under)
   if i==profile.size()-2:skin.quad(vertices[3]+under,vertices[3],vertices[2],vertices[2]+under)
  arc=next

static func roof_height(profile:Array,x:float)->float:
 for i in profile.size()-1:
  if x<=profile[i+1].x:return lerpf(profile[i].y,profile[i+1].y,inverse_lerp(profile[i].x,profile[i+1].x,x))
 return profile[-1].y

static func source_10003_beam(skin,z:float,profile:Array,roof:String,follows_roof:bool=false):
 var limit:float=profile[-1].x*.50
 var crown=profile[0]
 for point:Vector2 in profile:
  if point.y>crown.y:crown=point
 var path=[Vector2(-limit,crown.y-.15),crown,Vector2(limit,crown.y-.15)]
 var feet=[-limit*.92,limit*.92]
 if follows_roof:
  limit=(profile[-1].x-profile[0].x)*.20
  path=[]
  for i in 9:
   var t=float(i)/8
   path.append(Vector2(crown.x+lerpf(-limit,limit,t),crown.y-.25+.35*sin(t*PI)))
  feet=[crown.x-limit*.50,crown.x+limit*.50]
 skin.part="trim"
 for x in feet:
  var y=roof_height(profile,x)
  if follows_roof:
   var height=maxf(.82,crown.y-.32-y)
   var rings=[Vector2(.66,-.12),Vector2(.79,.12),Vector2(.68,.4),Vector2(.49,maxf(.42,height-.12)),Vector2(.65,height+.18)]
   for ring in rings.size()-1:
    var a:Vector2=rings[ring];var b:Vector2=rings[ring+1]
    for segment in 12:
     var t=segment*TAU/12;var u=(segment+1)*TAU/12
     skin.quad(Vector3(x+cos(u)*a.x,y+a.y,z+sin(u)*a.x),Vector3(x+cos(u)*b.x,y+b.y,z+sin(u)*b.x),Vector3(x+cos(t)*b.x,y+b.y,z+sin(t)*b.x),Vector3(x+cos(t)*a.x,y+a.y,z+sin(t)*a.x))
  else:skin.box(AABB(Vector3(x-.47,y-.12,z-.65),Vector3(.94,crown.y+.52-y,1.30)))
 for i in path.size()-1:
  var a:Vector2=path[i];var b:Vector2=path[i+1]
  skin.part=roof
  for side in [-1,1]:
   var p=Vector3(a.x,a.y+.12,z+side*.95);var q=Vector3(b.x,b.y+.12,z+side*.95)
   if side>0:skin.quad(p,p+Vector3.UP*.38,q+Vector3.UP*.38,q)
   else:skin.quad(q,q+Vector3.UP*.38,p+Vector3.UP*.38,p)
  skin.part=roof
  for step in 12:
   var t=step*PI/12;var u=(step+1)*PI/12
   skin.quad(Vector3(a.x,a.y+.50+sin(t)*.65,z-cos(t)*.95),Vector3(b.x,b.y+.50+sin(t)*.65,z-cos(t)*.95),Vector3(b.x,b.y+.50+sin(u)*.65,z-cos(u)*.95),Vector3(a.x,a.y+.50+sin(u)*.65,z-cos(u)*.95))
  skin.part="10003_wood"
  skin.quad(Vector3(a.x,a.y+.12,z-.95),Vector3(a.x,a.y+.12,z+.95),Vector3(b.x,b.y+.12,z+.95),Vector3(b.x,b.y+.12,z-.95))
 for end in [0,path.size()-1]:
  var point:Vector2=path[end];var center=Vector3(point.x,point.y+.50,z)
  skin.part="10003_wood"
  var end_a=center+Vector3(0,-.38,-.95);var end_b=center+Vector3(0,-.38,.95);var end_c=center+Vector3(0,0,.95);var end_d=center+Vector3(0,0,-.95)
  if end==0:skin.quad(end_d,end_c,end_b,end_a)
  else:skin.quad(end_a,end_b,end_c,end_d)
  skin.part=roof
  for step in 12:
   var a=center+Vector3(0,sin(step*PI/12)*.65,-cos(step*PI/12)*.95)
   var b=center+Vector3(0,sin((step+1)*PI/12)*.65,-cos((step+1)*PI/12)*.95)
   if end==0:skin.quad(center,a,b,center)
   else:skin.quad(center,b,a,center)

static func source_shop_tower(skin,center:Vector3,native_glazing:bool=false):
 var radius=1.8 if native_glazing else 1.2
 var height=(3.8 if center.z<0 else 4.6) if native_glazing and center.x<0 else 5.8 if native_glazing else 5.0
 var slices=16 if native_glazing else 12
 skin.part="stone"
 for i in slices:
  var a=float(i)*TAU/slices;var b=float(i+1)*TAU/slices
  var p=center+Vector3(cos(a)*radius,0,sin(a)*radius)
  var q=center+Vector3(cos(b)*radius,0,sin(b)*radius)
  skin.quad(q,q+Vector3.UP*height,p+Vector3.UP*height,p)
 skin.part="trim"
 if native_glazing:
  for i in slices:
   var a=i*TAU/slices;var b=(i+1)*TAU/slices
   var outer_a=Vector3(cos(a)*(radius+.14),height,sin(a)*(radius+.14))
   var outer_b=Vector3(cos(b)*(radius+.14),height,sin(b)*(radius+.14))
   var inner_a=Vector3(cos(a)*(radius-.3),height,sin(a)*(radius-.3))
   var inner_b=Vector3(cos(b)*(radius-.3),height,sin(b)*(radius-.3))
   skin.quad(center+outer_b,center+inner_b,center+inner_a,center+outer_a)
   skin.quad(center+outer_b-Vector3.UP*.3,center+outer_b,center+outer_a,center+outer_a-Vector3.UP*.3)
   skin.quad(center+inner_a-Vector3.UP*.12,center+inner_a,center+inner_b,center+inner_b-Vector3.UP*.12)
   skin.quad(center+Vector3.UP*(height-.12),center+inner_a-Vector3.UP*.12,center+inner_b-Vector3.UP*.12,center+Vector3.UP*(height-.12))
 else:skin.box(AABB(center+Vector3(-1.1,height-.15,-1.1),Vector3(2.2,.3,2.2)))
 for i in 8:
  var angle=float(i)*TAU/8
  if native_glazing and cos(angle)*signf(center.x)<-.01:continue
  var merlon=.6 if native_glazing else .4
  var station=radius-.1 if native_glazing else 1.05
  skin.box(AABB(center+Vector3(cos(angle)*station-merlon*.5,height,sin(angle)*station-merlon*.5),Vector3(merlon,.55,merlon)))
 if native_glazing:
  for angle in ([PI*.5,PI*.75,PI] if center.x<0 else [-PI*.25,0.0,PI*.25]):
   var normal=Vector3(cos(angle),0,sin(angle))
   Village.detail(skin,center+normal*(radius+.04)+Vector3.UP*2.8,Vector3.UP.cross(normal),"10003_window",2.3)
