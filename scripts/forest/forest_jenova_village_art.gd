extends RefCounted
## Jenova-only prepared visual meshes. Original owns all cells, collision and travel.
const Kit=preload("res://scripts/forest/forest_tina_village_art.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Data=preload("res://assets/maps/falan/jenova/street_art/materials.gd")
const Atlas=preload("res://assets/maps/falan/jenova/street_art/materials.png")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const SITES={11400:Vector2i(39,60),11402:Vector2i(46,35),11403:Vector2i(48,52),11404:Vector2i(59,44),11405:Vector2i(42,22)}
const COLORS={"plaster":"d7ceb0","wood":"b3a080","trim":"68543b","stone":"99988a","orange":"bd7139","green":"52684b","glass":"476575","teal":"4b7779","shutter":"a08355","red":"874638","sign":"ffffff","banner":"ffffff","letter":"e8dab5","carving":"b29b65"}
static var meshes={}
static var materials={}
static var ground_meshes={}
static var scope={}
static var reachable={}
static var ground_texture:Texture2D

static func owns(source:int,serial:int,cell:Vector2i)->bool:
 if source==400:
  cell-=Vector2i(193,416)
  source=4000
 if source!=4000:return false
 if SITES.has(serial):return cell==SITES[serial]
 if serial not in range(11300,11333) and serial not in range(11363,11377) and serial not in [11393,11496]:return false
 prepare_scope()
 for y in range(-2,3):
  for x in range(-2,3):
   var at=cell+Vector2i(x,y)
   if at.x>=0 and at.x<100 and at.y>=0 and at.y<100 and reachable.has(at.y*100+at.x):return true
 return false

static func prepare_scope():
 if not scope.is_empty():return
 scope=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/jenova/street_art/provenance.json"))
 for index in scope.reachable_cells:reachable[int(index)]=true

static func paint(role:String)->Material:
 if materials.has(role):return materials[role]
 var mat:ShaderMaterial=Source.material(Atlas,true).duplicate()
 mat.set_shader_parameter("original_palette",false);mat.set_shader_parameter("alpha_cutout",false)
 mat.set_shader_parameter("base_color",Color(COLORS[role]))
 mat.set_shader_parameter("surface_kind",0.0 if role in ["wood","trim","shutter"] else 1.7 if role=="stone" else 5.0)
 if role in ["orange","green"]:
  mat.set_shader_parameter("architecture_roof",true);mat.set_shader_parameter("surface_kind",5.0)
 if role in ["glass","teal","letter","red"]:mat.set_shader_parameter("use_base_texture",false)
 if role=="glass":mat.set_shader_parameter("surface_kind",6.0)
 materials[role]=mat;return mat

static func skins()->Dictionary:
 var result={}
 for role in COLORS:
  var s=Source.new([],Atlas,.045);s.tiles=Data.TILES.duplicate();s.tiles["letter"]=Data.TILES.plaster;s.tiles["red"]=Data.TILES.teal;s.part=role;result[role]=s
 return result

static func finish(s:Dictionary)->Mesh:
 var result=ArrayMesh.new()
 for role in s:
  var mesh:Mesh=s[role].surface.commit()
  if mesh==null or mesh.get_surface_count()==0:continue
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
  result.surface_set_material(result.get_surface_count()-1,paint(role))
 return result

static func mesh(serial:int,g:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var s=skins()
 match serial:
  11400:porch_house(s)
  11402:round_landmark(s)
  11403:green_shop(s)
  11404:bay_house(s)
  11405:north_shop(s)
  11393:well(s)
  11496:street_sign(s)
  _:street_piece(s,serial,g)
 meshes[serial]=finish(s);meshes[serial].set_meta("jenova_village_art",serial)
 return meshes[serial]

static func block(s,at:Vector3,size_:Vector3,basis:Basis=Basis.IDENTITY):
 Kit.block(s,at,size_,basis)

static func shell(s:Dictionary,c:Vector3,w:float,d:float,h:float,base:float=.3):
 block(s.stone,c+Vector3.UP*(base*.5),Vector3(w+.14,base,d+.14))
 block(s.plaster,c+Vector3.UP*(base+h*.5),Vector3(w,h,d))
 for x in [-1,1]:
  for z in [-1,1]:block(s.trim,c+Vector3(x*w*.5,base+h*.5,z*d*.5),Vector3(.24,h+.12,.24))
 for y in [base+.18,base+h-.10]:block(s.trim,c+Vector3.UP*y,Vector3(w+.18,.18,d+.18))
 # Solid fascia and soffit close the wall/roof seam from low and side cameras.
 block(s.trim,c+Vector3.UP*(base+h+.03),Vector3(w+.70,.22,d+.70))
 block(s.wood,c+Vector3.UP*(base+h+.16),Vector3(w+1.10,.14,d+1.10))

static func hip(s:Dictionary,c:Vector3,w:float,d:float,base:float,rise:float,color:String):
 Kit.Forms.hip_roof(s[color],w+1.12,d+1.12,base,rise,c,false,true)
 # Crown and corner ribs make the original bell silhouette readable in 3D.
 Kit.Forms.Buildings.kili_round(s.trim,c+Vector3.UP*(base+rise),[Vector2(.18,0),Vector2(.22,.12),Vector2(.11,.26),Vector2(.02,.48)])

static func window(s:Dictionary,at:Vector3,normal:Vector3,width:float=1.25,height:float=1.55,shutters:bool=true):
 Kit.window(s,at,normal,width,height)
 if not shutters:return
 var basis=Kit.facade_basis(normal)
 for side in [-1,1]:
  block(s.shutter,at+basis.x*(side*(width*.5+.37))+normal*.13,Vector3(.42,height+.08,.18),basis)
  for y in [-height*.32,height*.32]:block(s.trim,at+basis.x*(side*(width*.5+.37))+Vector3.UP*y+normal*.25,Vector3(.42,.09,.08),basis)

static func door(s:Dictionary,at:Vector3,normal:Vector3,height:float=2.7,width:float=1.55,color:String="teal"):
 Kit.door(s,at,normal,height,width,color)

static func rail(s:Dictionary,a:Vector3,b:Vector3,height:float=.90):
 var count=maxi(1,ceili(a.distance_to(b)/1.6))
 for i in count+1:block(s.trim,a.lerp(b,float(i)/count)+Vector3.UP*height*.5,Vector3(.14,height,.14))
 for y in [height*.40,height]:Kit.rod(s.trim,a+Vector3.UP*y,b+Vector3.UP*y,.055)

static func porch(s:Dictionary,c:Vector3,w:float,d:float,base:float=.4):
 block(s.stone,c+Vector3.UP*(base*.5),Vector3(w,base,d))
 block(s.wood,c+Vector3.UP*(base+.04),Vector3(w+.06,.10,d+.06))

static func green_shop(s:Dictionary):
 var c=Vector3(9,0,-6);var w=17.0;var d=11.4;var wall=4.8
 shell(s,c,w,d,wall,.65);hip(s,c,w,d,wall+.91,4.0,"green")
 # Entrance-side terrace and inset red door retain this shop's original identity.
 porch(s,Vector3(-1.2,0,-5.5),2.6,12.0,.60)
 door(s,Vector3(.5,.66,-2.3),Vector3.LEFT,2.9,1.7,"red")
 for z in [-9.0,-5.8]:window(s,Vector3(.5,3.05,z),Vector3.LEFT,1.15,1.7)
 for x in [4.2,9.4,14.6]:window(s,Vector3(x,3.0,-.3),Vector3.BACK)
 for x in [4.5,13.0]:window(s,Vector3(x,3.0,-11.7),Vector3.FORWARD)
 for z in [-8.6,-3.1]:window(s,Vector3(17.5,3.0,z),Vector3.RIGHT)
 rail(s,Vector3(-2.4,.65,-11.5),Vector3(-2.4,.65,-3.8))
 # Broad hood meets the eave; the door no longer stretches into the roof.
 brow(s,Vector3(-.65,5.0,-2.3),Vector3.LEFT,"green")
 # Reuse the existing cask shape at a scale that supports the doorway.
 for z in [-.65,-1.85]:
  Kit.Forms.Buildings.kili_round(s.wood,Vector3(-1.25,.65,z),[Vector2(.40,0),Vector2(.50,.22),Vector2(.50,.85),Vector2(.39,1.05)])
  for y in [.85,1.47]:Kit.Forms.Buildings.kili_round(s.trim,Vector3(-1.25,y,z),[Vector2(.50,0),Vector2(.50,.08)])
 var basis=Kit.facade_basis(Vector3.LEFT)
 block(s.trim,Vector3(-.65,3.55,-.25),Vector3(1.2,.85,.15),basis)
 s.sign.panel(Vector3(-.75,3.15,-.85),Vector3(-.75,3.95,-.85),Vector3(-.75,3.95,.35),Vector3(-.75,3.15,.35),"sign")

static func porch_house(s:Dictionary):
 var c=Vector3(6,0,-4.5);var w=13.8;var d=10.0;var h=4.9
 shell(s,c,w,d,h,.5);hip(s,c,w,d,h+.76,4.1,"orange")
 porch(s,Vector3(-1.9,0,-4.5),2.2,10.5,.45)
 door(s,Vector3(-.9,.52,-2.7),Vector3.LEFT)
 for z in [-8.1,-5.8]:window(s,Vector3(-.9,2.95,z),Vector3.LEFT,1.0,1.6)
 for x in [2.3,9.4]:window(s,Vector3(x,2.95,.5),Vector3.BACK)
 for z in [-7.2,-1.8]:window(s,Vector3(12.9,2.95,z),Vector3.RIGHT)
 window(s,Vector3(6,2.95,-9.5),Vector3.FORWARD)
 rail(s,Vector3(-2.8,.5,-9.5),Vector3(-2.8,.5,-4.1))
 rail(s,Vector3(-2.8,.5,-1.3),Vector3(-2.8,.5,.5))
 # The original arched roof brow projects above the blue entrance.
 brow(s,Vector3(-2.15,5.10,-2.7),Vector3.LEFT,"orange")

static func brow(s:Dictionary,at:Vector3,normal:Vector3,color:String):
 var basis=Kit.facade_basis(normal)
 var roof=PackedVector2Array([Vector2(-1.50,0),Vector2(-1.45,.35),Vector2(-1.10,.85),Vector2(-.6,1.23),Vector2(0,1.38),Vector2(.6,1.23),Vector2(1.10,.85),Vector2(1.45,.35),Vector2(1.50,0)])
 for i in roof.size()-1:
  var a=Vector3(roof[i].x,roof[i].y,0);var b=Vector3(roof[i+1].x,roof[i+1].y,0)
  s[color].quad(at+basis*a,at+basis*(a+Vector3.FORWARD*1.9+Vector3.UP*.48),at+basis*(b+Vector3.FORWARD*1.9+Vector3.UP*.48),at+basis*b)
  Kit.rod(s.shutter,at+basis*a,at+basis*b,.075)
  s.wood.quad(at+basis*(b-Vector3.UP*.14),at+basis*(b+Vector3.FORWARD*1.9+Vector3.UP*.34),at+basis*(a+Vector3.FORWARD*1.9+Vector3.UP*.34),at+basis*(a-Vector3.UP*.14))

static func round_body(s:Dictionary,c:Vector3,radius:float,h:float):
 Kit.Forms.Buildings.kili_round(s.stone,c,[Vector2(radius+.18,.02),Vector2(radius+.18,.45),Vector2(radius,.55)])
 Kit.Forms.Buildings.kili_round(s.plaster,c,[Vector2(radius,.45),Vector2(radius,h)])
 for y in [.65,h*.54,h-.1]:Kit.Forms.Buildings.kili_round(s.trim,c,[Vector2(radius+.05,y),Vector2(radius+.05,y+.14)])
 for i in 16:
  var normal=Vector3(cos(i*TAU/16),0,sin(i*TAU/16))
  block(s.trim,c+normal*(radius+.03)+Vector3.UP*(h*.5+.25),Vector3(.16,h-.5,.16),Kit.facade_basis(normal))

static func bell(s:Dictionary,c:Vector3,radius:float,base:float,rise:float,cupola:bool=false):
 Kit.Forms.Buildings.kili_round(s.trim,c,[Vector2(radius+.48,base-.13),Vector2(radius+.48,base+.04)])
 var profile=[Vector2(radius+.49,base),Vector2(radius+.51,base+.13),Vector2(radius*.98,base+rise*.28),Vector2(radius*.84,base+rise*.60),Vector2(radius*.59,base+rise*.85),Vector2(radius*.24,base+rise)]
 if not cupola:profile.append(Vector2(.03,base+rise+.12))
 Kit.Forms.Buildings.kili_round(s.orange,c,profile)
 if cupola:
  var y=base+rise
  Kit.Forms.Buildings.kili_round(s.trim,c,[Vector2(radius*.25,y-.03),Vector2(radius*.25,y+.12)])
  Kit.Forms.Buildings.kili_round(s.plaster,c,[Vector2(radius*.22,y+.12),Vector2(radius*.22,y+1.10)])
  for i in 8:
   var n=Vector3(cos(i*TAU/8),0,sin(i*TAU/8))
   window(s,c+n*(radius*.22)+Vector3.UP*(y+.62),n,.55,.62,false)
  Kit.Forms.Buildings.kili_round(s.orange,c,[Vector2(radius*.29,y+1.1),Vector2(radius*.29,y+1.2),Vector2(radius*.17,y+1.55),Vector2(.02,y+1.75)])

static func round_landmark(s:Dictionary):
 var c=Vector3(6,0,-7.5);var radius=6.7;var h=6.3
 round_body(s,c,radius,h);bell(s,c,radius,h+.13,3.1,true)
 for i in 12:
  var angle=i*TAU/12;var normal=Vector3(cos(angle),0,sin(angle))
  window(s,c+normal*(radius+.03)+Vector3.UP*4.85,normal,1.0,1.25,false)
  if i not in [6,7]:window(s,c+normal*(radius+.03)+Vector3.UP*2.1,normal,1.0,1.4)
 door(s,c+Vector3(-radius,.48,0),Vector3.LEFT,3.0,1.65)
 # Native sign becomes a small raised plaque, rather than an entire wall image.
 var n=Vector3(-1,0,1).normalized();var basis=Kit.facade_basis(n);var at=c+n*(radius+.2)+Vector3.UP*2.4
 block(s.red,at,Vector3(1.2,.8,.16),basis)
 block(s.letter,at+n*.12,Vector3(.78,.14,.03),basis)

static func bay_house(s:Dictionary):
 var c=Vector3(12.0,0,-8.5);var w=13.5;var d=14.3;var h=5.4
 shell(s,c,w,d,h,.5);hip(s,c,w,d,h+.76,4.0,"orange")
 var bay=Vector3(3.8,0,-2.3);var radius=4.2
 round_body(s,bay,radius,5.0);bell(s,bay,radius,5.13,2.55)
 for angle in [0.0,PI*.25,PI*.5,PI*.75]:
  var n=Vector3(cos(angle),0,sin(angle))
  window(s,bay+n*(radius+.04)+Vector3.UP*3.1,n,1.05,1.65)
 door(s,bay+Vector3(-radius,.48,0),Vector3.LEFT,2.85,1.65)
 for z in [-13.1,-7.0,-2.8]:window(s,Vector3(18.75,3.05,z),Vector3.RIGHT)
 for x in [10.3,15.6]:window(s,Vector3(x,3.05,-1.35),Vector3.BACK)
 for z in [-12.3,-8.2]:window(s,Vector3(5.25,3.05,z),Vector3.LEFT)
 for x in [8.4,14.9]:window(s,Vector3(x,3.05,-15.65),Vector3.FORWARD)
 # Keep the original open courtyard and its source-side fence, without a solid deck.
 rail(s,Vector3(-1.7,.02,-14.8),Vector3(-1.7,.02,-5.2),1.0)
 rail(s,Vector3(-1.7,.02,-14.8),Vector3(5.0,.02,-14.8),1.0)

static func north_shop(s:Dictionary):
 var c=Vector3(4.5,0,-4.5);var w=10.7;var d=10.7;var h=6.4
 shell(s,c,w,d,h,.6);hip(s,c,w,d,h+.86,4.15,"orange")
 # Stone lower story, lighter upper story and the two original roof brows.
 block(s.stone,c+Vector3.UP*1.35,Vector3(w+.05,2.7,d+.05))
 block(s.trim,c+Vector3.UP*2.75,Vector3(w+.20,.20,d+.20))
 door(s,Vector3(2.2,.6,.85),Vector3.BACK,2.8,1.7,"wood")
 for x in [1.0,7.5]:window(s,Vector3(x,4.55,.85),Vector3.BACK,1.05,1.65,false)
 for z in [-7.8,-2.2]:window(s,Vector3(-.85,4.55,z),Vector3.LEFT,1.05,1.65,false)
 for z in [-7.4,-1.6]:window(s,Vector3(9.85,4.4,z),Vector3.RIGHT)
 window(s,Vector3(4.5,4.4,-9.85),Vector3.FORWARD)
 brow(s,Vector3(2.2,6.55,1.95),Vector3.BACK,"orange")
 brow(s,Vector3(-1.95,6.55,-2.2),Vector3.LEFT,"orange")
 porch(s,Vector3(-1.6,3.15,-2.2),1.5,3.5,.16)
 rail(s,Vector3(-2.3,3.45,-3.95),Vector3(-2.3,3.45,-.45),.85)
 for z in [-3.8,-.6]:Kit.rod(s.trim,Vector3(-.9,2.7,z),Vector3(-2.1,3.4,z),.09)
 var sign_at=Vector3(6.6,2.65,1.16)
 block(s.trim,sign_at,Vector3(2.3,1.3,.18))
 s.sign.panel(sign_at+Vector3(-1.05,-.55,.12),sign_at+Vector3(-1.05,.55,.12),sign_at+Vector3(1.05,.55,.12),sign_at+Vector3(1.05,-.55,.12),"sign")
 for x in [-.6,9.6]:
  block(s.trim,Vector3(x,5.25,1.4),Vector3(.14,.14,1.2))
  var at=Vector3(x,4.4,1.8)
  s.banner.panel(at+Vector3(-.45,-.75,.05),at+Vector3(-.45,.75,.05),at+Vector3(.45,.75,.05),at+Vector3(.45,-.75,.05),"banner")

static func well(s:Dictionary):
 var c=Vector3(1.5,0,-1.5);var radius=1.35
 Kit.Forms.Buildings.kili_round(s.stone,c,[Vector2(radius,0),Vector2(radius,.95),Vector2(radius*.75,.95),Vector2(radius*.75,.10)])
 for angle in [0.0,TAU/3,TAU*2/3]:
  var n=Vector3(cos(angle),0,sin(angle))
  Kit.rod(s.trim,c+n*1.8,c+n*1.35+Vector3.UP*2.85,.095)
 bell(s,c,1.85,2.85,1.25)
 Kit.rod(s.trim,c+Vector3(-1.3,2.1,0),c+Vector3(1.3,2.1,0),.075)

static func street_sign(s:Dictionary):
 block(s.trim,Vector3(0,.8,0),Vector3(.12,1.6,.12))
 var at=Vector3(0,1.45,0)
 block(s.wood,at,Vector3(1.6,.55,.16))
 # Keep the native carved sign's motif as a painted detail on a solid plank.
 s.sign.panel(at+Vector3(-.72,-.22,.09),at+Vector3(-.72,.22,.09),at+Vector3(.72,.22,.09),at+Vector3(.72,-.22,.09),"sign")

static func street_piece(s:Dictionary,serial:int,g:Dictionary):
 if serial in range(11363,11377):
  var arms=Kit.Forms.Tina.fence_arms(serial)
  block(s.trim,Vector3(0,.65,0),Vector3(.16,1.3,.16))
  for y in [.50,.98]:
   if arms.y>arms.x:block(s.wood,Vector3((arms.x+arms.y)*.76,y,0),Vector3((arms.y-arms.x)*1.52,.14,.14))
   if arms.w>arms.z:block(s.wood,Vector3(0,y,(arms.z+arms.w)*.76),Vector3(.14,.14,(arms.w-arms.z)*1.52))
  return
 if serial==11314:
  block(s.stone,Vector3(0,.14,0),Vector3(1.5,.28,1.5))
  block(s.shutter,Vector3(0,1.85,0),Vector3(.9,3.2,.9))
  for y in [.5,2.7,3.15]:block(s.trim,Vector3(0,y,0),Vector3(1.12,.13,1.12))
  Kit.Forms.hip_roof(s.shutter,1.3,1.3,3.45,.9,Vector3.ZERO,false,true,true)
  for normal in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
   var basis=Kit.facade_basis(normal);var at=normal*.46+Vector3.UP*1.75
   s.carving.panel(at+basis*Vector3(-.37,-1.20,0),at+basis*Vector3(-.37,1.20,0),at+basis*Vector3(.37,1.20,0),at+basis*Vector3(.37,-1.20,0),"carving")
  return
 # Reuse the original modular wall/gate connectivity; replace stretched paint.
 var original:Mesh
 if serial in range(11317,11333):
  original=load("res://scripts/forest/forest_university_route_art.gd").wall_mesh(serial,g)
 else:
  original=Kit.Forms.mesh(serial,Kit.Forms.kind(serial,false,g),g,Art.solid_texture(int(g.page)))
 var bounds=original.get_aabb();var factor=minf(1.0,3.25/bounds.size.y)
 for slot in original.get_surface_count():
  var arrays=original.surface_get_arrays(slot);var indices=arrays[Mesh.ARRAY_INDEX]
  for j in indices.size() if indices is PackedInt32Array and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size():
   var i=indices[j] if indices is PackedInt32Array and not indices.is_empty() else j
   var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i];p.y=(p.y-bounds.position.y)*factor
   var n:Vector3=arrays[Mesh.ARRAY_NORMAL][i];n=(n/Vector3(1,factor,1)).normalized()
   var axis=Vector2(p.z,-p.y) if absf(n.x)>absf(n.z) else Vector2(p.x,-p.y)
   s.stone.surface.set_normal(n);s.stone.surface.set_uv(axis/1.5);s.stone.surface.set_uv2(Data.TILES.stone);s.stone.surface.add_vertex(p)

static func floor_owns(source:int,cell:Vector2i)->bool:
 if source!=4000:return false
 prepare_scope();return reachable.has(cell.y*100+cell.x)

static func floor_mesh(serial:int,g:Dictionary)->Mesh:
 if ground_meshes.has(serial):return ground_meshes[serial]
 prepare_scope()
 if ground_texture==null:ground_texture=load("res://assets/maps/falan/jenova/street_art/ground.png")
 var record:Dictionary=scope.graphics[str(serial)]
 assert(record.source_rgba_sha256==g.rgba_sha256,"Regenerate Jenova floor derivatives")
 var r:Array=record.rect
 var s=Source.new([Rect2(r[0],r[1],r[2],r[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],ground_texture,.045)
 s.quad(Vector3(-1.5,.012,-1.5),Vector3(1.5,.012,-1.5),Vector3(1.5,.012,1.5),Vector3(-1.5,.012,1.5))
 ground_meshes[serial]=s.finish();return ground_meshes[serial]

static func floor_material()->Material:
 if materials.has("ground"):return materials.ground
 var mat=ShaderMaterial.new();mat.shader=preload("res://scripts/forest/forest_tina_ground.gdshader")
 mat.set_shader_parameter("continuous_floor",preload("res://assets/maps/falan/jenova/street_art/ground-continuous.png"))
 mat.set_shader_parameter("map_origin",Vector2(-150,-150))
 materials.ground=mat
 return mat
