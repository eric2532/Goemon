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
   tool.set_color(Color(1,1,1,1 if tile in [Data.TILES.plaster,Data.TILES.stone,Data.TILES["10003_base"]] else 0))
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

static func shape(kind:String,style:int)->Mesh:
 if style in [2,12]:return source_10605_shape(style==12)
 if style>=3:return source_10003_shape(style)
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

static func dormer(skin,side:int,z:float,half:float,wall:float,lift:float=0.0):
 var front=side*half*.78;var back=side*half*.52;var base=wall+2.0+lift
 skin.part="trim"
 for i in 8:
  var a=i*PI/8;var b=(i+1)*PI/8
  var first=Vector3(front,base+sin(a)*.95,z+cos(a)*.88)
  var next=Vector3(front,base+sin(b)*.95,z+cos(b)*.88)
  var behind=Vector3(back,first.y,first.z);var behind_next=Vector3(back,next.y,next.z)
  if side>0:skin.quad(next,first,behind,behind_next)
  else:skin.quad(first,next,behind_next,behind)
 Village.detail(skin,Vector3(front+side*.025,base-.05,z),Vector3.FORWARD*side,"dormer_window",2.15)


static func source_10605_shape(reverse:bool=false)->Mesh:
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
 for i in profile.size()-1:
  var a:Vector2=profile[i];var b:Vector2=profile[i+1]
  skin.quad(Vector3(a.x,a.y,length+.5),Vector3(a.x,a.y,-length-.5),Vector3(b.x,b.y,-length-.5),Vector3(b.x,b.y,length+.5))
 for side in [-1,1]:
  skin.part="stone"
  for i in profile.size()-1:
   var a:Vector2=profile[i];var b:Vector2=profile[i+1]
   var low=Vector3(0,wall,side*length)
   var first=Vector3(a.x,a.y,side*length);var next=Vector3(b.x,b.y,side*length)
   if side>0:skin.quad(first,next,low,low)
   else:skin.quad(next,first,low,low)
  for z in [-length*.44,length*.44]:dormer(skin,side,z,width,wall,1.1)
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

static func source_10003_shape(style:int)->Mesh:
 var roof="10007_roof" if style==4 else "10006_roof" if style==5 else "blue_roof"
 var skin=SourceMesh.new([],Atlas,.045);skin.tiles=Data.TILES
 var half=3.15 if style==15 else 3.5 if style==16 else 5.0 if style in [6,7,9,10,11] else 4.3
 var length=6.3;var edge=half+.5;var roof_end=6.9;var wall=6.0
 var profile=source_roof_profile(edge,wall,style)
 var ridge=0.0
 for point:Vector2 in profile:ridge=maxf(ridge,point.y)
 skin.part="plaster"
 skin.box(AABB(Vector3(-half,0,-length),Vector3(half*2,wall,length*2)))
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
  if style==6 and side>0:
   Village.detail(skin,Vector3(side*(half+.04),2.85,0),horizontal,"10081_grille",8.8)
  else:
   for z in [-3.8,3.8]:
    Village.detail(skin,Vector3(side*(half+.04),3.5,z),horizontal,"10003_window",3.1)
    skin.part="trim"
    for y in [2.10,4.92]:skin.box(AABB(Vector3(side*(half+.10)-.10,y-.08,z-1.0),Vector3(.20,.16,2.0)))
    for offset in [-.89,.89]:skin.box(AABB(Vector3(side*(half+.08)-.08,2.12,z+offset-.07),Vector3(.16,2.76,.14)))
 if style<6 or style in [13,14,15,16]:
  Village.detail(skin,Vector3(half+.06,2.25,0),Vector3.FORWARD,"10003_door",4.5)
  skin.part="10003_wood"
  for z in [-1.3,1.3]:skin.box(AABB(Vector3(half+.04,0,z-.15),Vector3(.28,4.1,.30)))
  skin.box(AABB(Vector3(half+.03,4.0,-1.45),Vector3(.32,.22,2.9)))
  for i in 12:
   var a=i*PI/12;var b=(i+1)*PI/12
   skin.quad(Vector3(half+.20,3.65+sin(a)*.75,cos(a)),Vector3(half+.20,3.65+sin(a)*1.02,cos(a)*1.28),Vector3(half+.20,3.65+sin(b)*1.02,cos(b)*1.28),Vector3(half+.20,3.65+sin(b)*.75,cos(b)))
 curved_roof(skin,profile,-roof_end,roof_end,roof)
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
  skin.box(AABB(Vector3(-.1,wall,side*length-.055),Vector3(.2,ridge-wall,.11)))
  if style in [4,5]:
   var center=Vector3(.3,9.4,side*(length+.13))
   source_rosette(skin,center,side)
   Village.detail(skin,center+Vector3.BACK*side*.10,Vector3.RIGHT*side,"shop_medallion",3.9)
 if style in [10,16]:
  for z in [-4.9,4.9]:
   for x in [-2.0,2.0]:
    skin.part="plaster"
    skin.box(AABB(Vector3(x-.38,9.4,z-.42),Vector3(.76,1.45,.84)))
    skin.part=roof
    skin.box(AABB(Vector3(x-.53,10.7,z-.53),Vector3(1.06,.65,1.06)))
 else:
  for z in ([-4.2,0.0,4.2] if style in [4,5,15] else [-4.2,4.2]):
   source_10003_beam(skin,z,profile,roof)
 if style in [3,13,14]:
  # The far gable's projecting bay and its timber frame use the original facade window.
  skin.part="10003_wood"
  for x in [-1.8,1.8]:skin.box(AABB(Vector3(x-.18,0,length+.05),Vector3(.36,4.5,.35)))
  skin.part="plaster"
  skin.box(AABB(Vector3(-1.65,1.25,length+.03),Vector3(3.3,3.1,.35)))
  Village.detail(skin,Vector3(0,3,length+.40),Vector3.RIGHT,"10003_bay_window",3.1)
  skin.part="10003_wood"
  for i in 10:
   var a=PI*float(i)/10;var b=PI*float(i+1)/10
   var inner_a=Vector3(cos(a)*1.45,4.0+sin(a)*1.55,length+.43)
   var inner_b=Vector3(cos(b)*1.45,4.0+sin(b)*1.55,length+.43)
   var outer_a=Vector3(cos(a)*1.8,4.0+sin(a)*1.9,length+.43)
   var outer_b=Vector3(cos(b)*1.8,4.0+sin(b)*1.9,length+.43)
   skin.quad(inner_b,outer_b,outer_a,inner_a)
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
  skin.part="plaster"
  skin.box(AABB(Vector3(-1.35,1.0,length-.25),Vector3(2.7,3.6,.85)))
  Village.detail(skin,Vector3(0,3,length+.62),Vector3.RIGHT,"10081_bay",3.6)
  skin.part=roof
  var z0=length-.25;var z1=length+.65
  skin.quad(Vector3(-1.55,4.6,z1),Vector3(-1.55,4.6,z0),Vector3(0,5.55,z0),Vector3(0,5.55,z1))
  skin.quad(Vector3(0,5.55,z1),Vector3(0,5.55,z0),Vector3(1.55,4.6,z0),Vector3(1.55,4.6,z1))
  if style==11:
   skin.part="trim"
   skin.box(AABB(Vector3(half+.02,1.65,-1.35),Vector3(.4,.4,2.7)))
   Village.detail(skin,Vector3(half+.44,2.25,0),Vector3.FORWARD,"10308_flowers",3.3)
 if style==14:
  for z in [-3.6,3.6]:
   source_shop_tower(skin,Vector3(half-.65,0,z))
 if style==13:
  skin.part="trim"
  for z in [-1.7,1.7]:skin.box(AABB(Vector3(half+.05,0,z-.18),Vector3(.45,5.0,.36)))
  skin.box(AABB(Vector3(half+.05,4.8,-1.9),Vector3(.45,.6,3.8)))
 if style==5:
  var center=GREEN_SHIELD_CENTER
  skin.part="trim"
  skin.box(AABB(center+Vector3(-.08,-2.0,-.08),Vector3(.16,1.05,.16)))
  var shield_outline=[Vector2(-.83,1.25),Vector2(-.62,1.02),Vector2(0,.96),Vector2(.78,1.25),Vector2(.72,-.25),Vector2(.56,-.75),Vector2(0,-1.15),Vector2(-.64,-.65)]
  for i in shield_outline.size():
   var a=center+Vector3(0,shield_outline[i].y,-shield_outline[i].x);var b=center+Vector3(0,shield_outline[(i+1)%shield_outline.size()].y,-shield_outline[(i+1)%shield_outline.size()].x)
   skin.quad(a-Vector3.RIGHT*.12,b-Vector3.RIGHT*.12,b,a)
   skin.quad(center-Vector3.RIGHT*.12,b-Vector3.RIGHT*.12,a-Vector3.RIGHT*.12,center-Vector3.RIGHT*.12)
  Village.detail(skin,center+Vector3.RIGHT*.015,Vector3.FORWARD,"shop_shield",3.6)
 var result=skin.finish()
 if paint==null:
  paint=result.surface_get_material(0).duplicate()
  paint.set_shader_parameter("original_palette",false)
 result.surface_set_material(0,paint)
 return result

static func source_roof_profile(edge:float,wall:float,style:int)->Array:
 var native:Array=ArchitectureData.GRAPHICS[10078 if style in [4,5] else 10077][4]
 var bottom=INF
 for point:Vector2 in native:bottom=minf(bottom,point.y)
 var result=[]
 for point:Vector2 in native:result.append(Vector2(lerpf(-edge,edge,point.x),wall+point.y-bottom))
 return result

static func source_rosette(skin,center:Vector3,side:int):
 if rosette_ring==null:
  var ring=TorusMesh.new();ring.inner_radius=.88;ring.outer_radius=1.04;ring.rings=32;ring.ring_segments=8;rosette_ring=ring
 var pose=Transform3D(Basis(Vector3.RIGHT,side*PI*.5).scaled(Vector3(1,1.2,1)),center)
 var normal=pose.basis.inverse().transposed()
 var arrays=rosette_ring.surface_get_arrays(0);var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 for index in indices:
  skin.surface.set_normal((normal*normals[index]).normalized());skin.surface.set_uv2(Data.TILES.trim);skin.surface.set_uv(uv[index]);skin.surface.add_vertex(pose*points[index])

static func curved_roof(skin,profile:Array,back:float,front:float,roof:String):
 var arc=0.0;var pitch=3.0 if roof in ["10006_roof","10007_roof"] else 2.0
 for i in profile.size()-1:
  var a:Vector2=profile[i];var b:Vector2=profile[i+1];var next=arc+a.distance_to(b)
  var vertices=[Vector3(a.x,a.y,front),Vector3(a.x,a.y,back),Vector3(b.x,b.y,back),Vector3(b.x,b.y,front)]
  var uv=[Vector2(arc,front),Vector2(arc,back),Vector2(next,back),Vector2(next,front)]
  var normal:Vector3=(vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
  for j in [0,1,2,0,2,3]:
   skin.surface.set_normal(normal);skin.surface.set_uv2(Data.TILES[roof]);skin.surface.set_uv(uv[j]/pitch);skin.surface.add_vertex(vertices[j])
  arc=next

static func roof_height(profile:Array,x:float)->float:
 for i in profile.size()-1:
  if x<=profile[i+1].x:return lerpf(profile[i].y,profile[i+1].y,inverse_lerp(profile[i].x,profile[i+1].x,x))
 return profile[-1].y

static func source_10003_beam(skin,z:float,profile:Array,roof:String):
 var limit:float=profile[-1].x*.50
 var crown=profile[0]
 for point:Vector2 in profile:
  if point.y>crown.y:crown=point
 var path=[Vector2(-limit,crown.y-.15),crown,Vector2(limit,crown.y-.15)]
 skin.part="trim"
 for x in [-limit*.92,limit*.92]:
  var y=roof_height(profile,x)
  skin.box(AABB(Vector3(x-.47,y-.12,z-.65),Vector3(.94,crown.y+.52-y,1.30)))
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

static func source_shop_tower(skin,center:Vector3):
 var radius=1.2;var height=5.0;var slices=12
 skin.part="stone"
 for i in slices:
  var a=float(i)*TAU/slices;var b=float(i+1)*TAU/slices
  var p=center+Vector3(cos(a)*radius,0,sin(a)*radius)
  var q=center+Vector3(cos(b)*radius,0,sin(b)*radius)
  skin.quad(q,q+Vector3.UP*height,p+Vector3.UP*height,p)
 skin.part="trim"
 skin.box(AABB(center+Vector3(-1.1,height-.15,-1.1),Vector3(2.2,.3,2.2)))
 for i in 8:
  var angle=float(i)*TAU/8
  skin.box(AABB(center+Vector3(cos(angle)*1.05-.2,height,sin(angle)*1.05-.2),Vector3(.4,.55,.4)))
