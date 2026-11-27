extends RefCounted
## Local snow-town recipes. Original cells, doors, collision and props stay authoritative.
const Kit=preload("res://scripts/forest/forest_tina_village_art.gd")
const Town=preload("res://scripts/forest/forest_jenova_village_art.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Atlas=preload("res://assets/maps/falan/tina/street_art/materials.png")
const Tiles=preload("res://assets/maps/falan/tina/street_art/materials.gd")
const IDS=[11408,11411,11412,11413,11415,11450]
const GROUND=preload("res://assets/maps/falan/snow_region/ground.png")
static var meshes={}
static var materials={}
static var ground_materials={}
static var floor_meshes={}
static var surfaces={}
static var cliff_material:Material

static func floor_owns(source:int,serial:int,cell:Vector2i,generated:bool)->bool:
 if surfaces.is_empty():surfaces=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/snow_region/surfaces.json"))
 if not surfaces.floors.has(str(serial)):return false
 if generated or source in [14000,14001,14002]:return true
 return source in [400,402,4300,4400,15522] and preload("res://scripts/forest/forest_university_route_art.gd").contains(source,cell)

static func floor_mesh(serial:int,g:Dictionary,texture:Texture2D)->Mesh:
 if floor_meshes.has(serial):return floor_meshes[serial]
 var mesh=Forms.mesh(serial,"floor",g,texture)
 var arrays=mesh.surface_get_arrays(0);var uv=PackedVector2Array()
 var rect:Array=surfaces.floors[str(serial)].rect
 for old in arrays[Mesh.ARRAY_TEX_UV]:uv.append((old*texture.get_size()-Vector2(g.rect[0],g.rect[1])+Vector2(rect[0],rect[1]))/GROUND.get_size())
 arrays[Mesh.ARRAY_TEX_UV]=uv
 var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 floor_meshes[serial]=result
 return result

static func cliff_finish(root:Node3D):
 if cliff_material==null:
  cliff_material=ShaderMaterial.new()
  cliff_material.shader=preload("res://scripts/forest/forest_snow_cliff.gdshader")
  cliff_material.set_shader_parameter("brush_texture",Kit.Source.Paint.BRUSH)
  cliff_material.set_shader_parameter("base_texture",preload("res://assets/maps/falan/snow_region/cliff-paint.png"))
 # Owned overrides retain the existing chunk meshes and the shared original material.
 for node in root.find_children("*","GeometryInstance3D",true,false):
  var mesh:Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D else null
  if mesh!=null and mesh.get_surface_count()==1 and mesh.surface_get_material(0)==Forms.Cliffs.material():node.material_override=cliff_material

static func ground_material(texture:Texture2D)->Material:
 if not ground_materials.has(texture):
  var mat=ShaderMaterial.new();mat.shader=preload("res://scripts/forest/forest_snow_ground.gdshader")
  mat.set_shader_parameter("native_texture",texture)
  mat.set_shader_parameter("earth_texture",preload("res://assets/maps/falan/snow_region/earth-mask.png"))
  mat.set_shader_parameter("brush_texture",preload("res://scripts/forest/forest_painterly_environment.gd").BRUSH)
  ground_materials[texture]=mat
 return ground_materials[texture]

static func owns(source:int,serial:int)->bool:
 return source in [402,4300,4400,15522] and serial in IDS

static func paint(role:String)->Material:
 if materials.has(role):return materials[role]
 var mat:ShaderMaterial=Kit.Source.material(Atlas,true).duplicate()
 mat.set_shader_parameter("original_palette",false);mat.set_shader_parameter("alpha_cutout",false)
 mat.set_shader_parameter("surface_kind",0.0 if role in ["wood","trim"] else 5.0)
 mat.set_shader_parameter("base_color",Color({"wood":"9c8262","trim":"5b4938","stone":"9a9f9e","snowroof":"ccdbe2","glass":"527480","door":"68868a","red":"873c31","sign":"ffffff"}[role]))
 if role in ["glass","door","red"]:mat.set_shader_parameter("use_base_texture",false)
 materials[role]=mat
 return mat

static func skins()->Dictionary:
 var result={}
 for role in ["wood","trim","stone","snowroof","glass","door","red","sign"]:
  var s=Kit.Source.new([],Atlas,.045);s.tiles=Tiles.TILES.duplicate()
  for key in ["glass","door","red"]:s.tiles[key]=Tiles.TILES.wood
  s.part=role;result[role]=s
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
 var s=skins();var w=float(g.footprint[0])*3;var d=float(g.footprint[1])*3
 var c=Vector3((w-3)*.5,0,(3-d)*.5)
 match serial:
  11408:bay_house(s,c,w,d)
  11413:round_house(s)
  11450:shelter(s,c,w,d)
  _:hip_house(s,serial,c,w,d)
 meshes[serial]=finish(s);meshes[serial].set_meta("abanis_village_art",serial)
 return meshes[serial]

static func shell(s:Dictionary,c:Vector3,w:float,d:float,h:float,base:float):
 Kit.block(s.stone,c+Vector3.UP*base*.5,Vector3(w+.12,base,d+.12))
 Kit.block(s.wood,c+Vector3.UP*(base+h*.5),Vector3(w,h,d))
 for x in [-1,1]:
  for z in [-1,1]:Kit.block(s.trim,c+Vector3(x*w*.5,base+h*.5,z*d*.5),Vector3(.25,h+.2,.25))
 for y in [base+.15,base+h-.12]:Kit.block(s.trim,c+Vector3.UP*y,Vector3(w+.20,.20,d+.20))
 for side in [-1,1]:
  for i in range(1,5):
   Kit.block(s.trim,c+Vector3((float(i)/5-.5)*w,base+h*.5,side*d*.5),Vector3(.13,h,.18))
   Kit.block(s.trim,c+Vector3(side*w*.5,base+h*.5,(float(i)/5-.5)*d),Vector3(.18,h,.13))
 # A solid soffit closes the shell from reachable low and rear views.
 Kit.block(s.trim,c+Vector3.UP*(base+h+.04),Vector3(w+.62,.22,d+.62))

static func mound(s,at:Vector3,size_:Vector3):
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 Forms.Lamps.prepare_primitives();Forms.Lamps.oval(tool,at,size_)
 Kit.append(s,tool.commit(),Transform3D.IDENTITY)

static func roof(s:Dictionary,c:Vector3,w:float,d:float,base:float,rise:float):
 Kit.block(s.trim,c+Vector3.UP*(base-.06),Vector3(w+.88,.18,d+.88))
 Forms.hip_roof(s.snowroof,w+1.15,d+1.15,base,rise,c,false,true)
 # Snow lobes collect on the eave while retaining the curved roof silhouette.
 for side in [-1,1]:
  for i in 4:
   var u=(float(i)+.5)/4-.5
   var h=.16+.05*sin(i*2.1+side)
   mound(s.snowroof,c+Vector3(u*(w+1.1),base+.05,side*(d+.95)*.5),Vector3((w+1.2)*.32,h,.42))
   mound(s.snowroof,c+Vector3(side*(w+.95)*.5,base+.05,u*(d+1.1)),Vector3(.42,h,(d+1.2)*.32))
  for i in 6:
   var u=float(i)/5-.5;var length_=.24+.18*(.5+.5*sin(i*2.4+side))
   Kit.rod(s.snowroof,c+Vector3(u*w*.91,base-.02,side*(d+.94)*.5),c+Vector3(u*w*.91,base-length_,side*(d+.94)*.5),.045)

static func window(s:Dictionary,at:Vector3,n:Vector3,w:float=1.4,h:float=1.65):
 Kit.window(s,at,n,w,h)
 var basis=Kit.facade_basis(n)
 Kit.block(s.snowroof,at+Vector3.UP*(h*.5+.30)+n*.28,Vector3(w+.58,.15,.50),basis)

static func drifts(s:Dictionary,c:Vector3,w:float,d:float,door_normal:Vector3):
 for side in [-1,1]:
  for i in 3:
   var u=(float(i)-1)/3
   if door_normal!=Vector3.BACK or side<0:mound(s.snowroof,c+Vector3(u*w,.10,side*d*.51),Vector3(w*.46,.30+.04*sin(i*1.7),.65))
   if door_normal!=Vector3.LEFT or side>0:mound(s.snowroof,c+Vector3(side*w*.51,.10,u*d),Vector3(.65,.28+.04*cos(i),d*.46))

static func facade_windows(c:Vector3,w:float,d:float,doorway:Vector3,normal:Vector3)->Array:
 var candidates=[];var axis=Vector3.UP.cross(normal)
 for side in [-1,1]:candidates.append([doorway+axis*(side*3.0)+Vector3.UP*3.15,normal])
 for side in [-1,1]:
  candidates.append([c+Vector3(side*w*.5,3.1,-d*.22),Vector3.RIGHT*side])
  candidates.append([c+Vector3(-w*.19,3.1,side*d*.5),Vector3.BACK*side])
 var result=[]
 for item in candidates:
  var n:Vector3=item[1];var tangent=Vector3.UP.cross(n)
  var half=(d if absf(n.x)>.5 else w)*.5-1.05
  var at:Vector3=item[0];at+=tangent*(clampf((at-c).dot(tangent),-half,half)-(at-c).dot(tangent))
  if n==normal and absf((at-doorway).dot(tangent))<2.0:continue
  if result.any(func(old):return old[1]==n and absf((old[0]-at).dot(tangent))<1.9):continue
  result.append([at,n])
 return result

static func snowy_rail(s:Dictionary,a:Vector3,b:Vector3):
 Town.rail({"trim":s.trim},a,b,1.0)
 Kit.rod(s.snowroof,a+Vector3.UP*1.05,b+Vector3.UP*1.05,.075)

static func hip_house(s:Dictionary,serial:int,c:Vector3,w:float,d:float):
 w*=.84;d*=.82
 var h=5.5 if serial!=11415 else 5.9
 var base=.55;var n=Vector3.BACK if serial==11411 else Vector3.LEFT
 shell(s,c,w,d,h,base);roof(s,c,w,d,h+base+.18,4.8 if serial!=11415 else 4.0)
 if serial==11415:Forms.hip_roof(s.snowroof,w*.82,d*.82,h+base+1.6,2.65,c,false,true)
 var doorway=c+n*((d if n==Vector3.BACK else w)*.5+.05)
 if serial==11411:doorway.x=3.0
 elif serial==11415:doorway.z=minf(2.0,c.z+d*.5-1.3)
 Kit.door(s,doorway+Vector3.UP*base,n,3.0,1.8,"red" if serial==11415 else "door")
 var axis=Vector3.UP.cross(n)
 for item in facade_windows(c,w,d,doorway,n):window(s,item[0],item[1])
 var platform=c+n*((d if n==Vector3.BACK else w)*.5+1.0)
 Kit.block(s.stone,platform+Vector3.UP*.25,Vector3(w+.3,.5,2.1) if n==Vector3.BACK else Vector3(2.1,.5,d+.3))
 var rail_center=platform+n*.75;var rail_half=(w if n==Vector3.BACK else d)*.5
 var gap=rail_center+axis*clampf((doorway-platform).dot(axis),-rail_half+1.3,rail_half-1.3)
 var a=rail_center-axis*rail_half;var b=rail_center+axis*rail_half
 if a.distance_to(gap-axis*1.3)>.25:snowy_rail(s,a,gap-axis*1.3)
 if b.distance_to(gap+axis*1.3)>.25:snowy_rail(s,gap+axis*1.3,b)
 # Original arched door brow stands in front of the hip, without painted facade duplication.
 var brow=doorway+Vector3.UP*5.0+n*.35
 if serial!=11415:
  var brow_s=s.duplicate();brow_s.shutter=s.trim
  Town.brow(brow_s,doorway+Vector3.UP*(h+base-.15)+n*.8,n,"snowroof")
 else:
  Kit.block(s.trim,brow,Vector3(2.5,.22,1.1),Kit.facade_basis(n))
  mound(s.snowroof,brow+Vector3.UP*.19,Vector3(1.2,.28,2.6))
 drifts(s,c,w,d,n)
 if serial==11415:
  for offset in [-3.7,-2.4]:
   var at=doorway+axis*offset+n*.9+Vector3.UP*.5
   Forms.Buildings.kili_round(s.wood,at,[Vector2(.45,0),Vector2(.53,.25),Vector2(.53,1.0),Vector2(.43,1.15)])
   mound(s.snowroof,at+Vector3.UP*1.17,Vector3(.52,.15,.52))
  var at=doorway+axis*2.7+n*.35+Vector3.UP*2.4
  Kit.block(s.trim,at,Vector3(1.3,1.15,.15),Kit.facade_basis(n))
  Kit.block(s.sign,at+n*.09,Vector3(1.1,.96,.035),Kit.facade_basis(n))

static func round_house(s:Dictionary):
 var c=Vector3(1.0,0,-6.0);var r=7.0;var h=7.0
 Forms.Buildings.kili_round(s.stone,c,[Vector2(r+.2,0),Vector2(r+.2,.55)])
 Forms.Buildings.kili_round(s.wood,c,[Vector2(r,.55),Vector2(r,h)])
 for y in [.7,3.3,h-.1]:Forms.Buildings.kili_round(s.trim,c,[Vector2(r+.10,y),Vector2(r+.10,y+.17)])
 for i in 16:
  var angle=TAU*i/16;var n=Vector3(cos(angle),0,sin(angle))
  Kit.block(s.trim,c+n*r+Vector3.UP*3.7,Vector3(.18,6.6,.18))
  if i%2==0 and i!=8:window(s,c+n*(r+.06)+Vector3.UP*4.8,n,1.65,1.7)
 Kit.door(s,c+Vector3(-r-.03,.55,0),Vector3.LEFT,3.0,1.9,"door")
 Forms.Buildings.kili_round(s.snowroof,c,[Vector2(r+1,h),Vector2(r+1,h+.25),Vector2(r*.95,h+1.4),Vector2(r*.68,h+3.4),Vector2(r*.28,h+4.2)])
 Forms.Buildings.kili_round(s.wood,c,[Vector2(r*.24,h+3.8),Vector2(r*.24,h+5.5)])
 for i in 8:
  var n=Vector3(cos(i*TAU/8),0,sin(i*TAU/8))
  Kit.block(s.trim,c+n*r*.24+Vector3.UP*(h+4.7),Vector3(.15,1.5,.15))
  window(s,c+n*(r*.24+.02)+Vector3.UP*(h+4.7),n,.65,.80)
  mound(s.snowroof,c+n*(r+.85)+Vector3.UP*(h+.1),Vector3(1.8,.26,1.8))
 Forms.Buildings.kili_round(s.snowroof,c,[Vector2(r*.31,h+5.5),Vector2(r*.29,h+5.8),Vector2(.12,h+6.5)])
 for i in 16:
  var angle=TAU*i/16
  if i in [7,8,9]:continue
  mound(s.snowroof,c+Vector3(cos(angle)*(r+.15),.15,sin(angle)*(r+.15)),Vector3(1.8,.40,1.8))

static func bay_house(s:Dictionary,c:Vector3,w:float,d:float):
 c+=Vector3(1,0,-3);w*=.80;d*=.62
 shell(s,c,w,d,6.0,.55);roof(s,c,w,d,6.75,5.3)
 for side in [-1,1]:
  for i in 3:window(s,c+Vector3(side*w*.5,3.2,(i-1)*3.1),Vector3.RIGHT*side)
  for i in 3:window(s,c+Vector3((i-1)*4.5,3.2,side*d*.5),Vector3.BACK*side)
 var bay=Vector3(6,0,-1);var r=4.0
 # Close the narrow wall gap beneath the already-overlapping main/bay roofs.
 Kit.block(s.wood,Vector3(bay.x,3.0,c.z+d*.5+.30),Vector3(3.0,5.5,.75))
 Forms.Buildings.kili_round(s.stone,bay,[Vector2(r+.2,0),Vector2(r+.2,.55)])
 Forms.Buildings.kili_round(s.wood,bay,[Vector2(r,.55),Vector2(r,5.5)])
 for y in [.7,3.5,5.35]:Forms.Buildings.kili_round(s.trim,bay,[Vector2(r+.07,y),Vector2(r+.07,y+.16)])
 for i in 12:
  var n=Vector3(cos(i*TAU/12),0,sin(i*TAU/12))
  Kit.block(s.trim,bay+n*r+Vector3.UP*3.0,Vector3(.16,5.2,.16))
  if i in [0,1,2,4,5,6]:window(s,bay+n*(r+.03)+Vector3.UP*4.5,n,.85,.75)
 Kit.door(s,bay+Vector3(0,.55,r+.04),Vector3.BACK,3.0,1.7,"door")
 Forms.Buildings.kili_round(s.snowroof,bay,[Vector2(r+.6,5.5),Vector2(r+.65,5.7),Vector2(r*.95,6.5),Vector2(r*.6,7.6),Vector2(.12,8.4)])
 for i in 10:
  var n=Vector3(cos(i*TAU/10),0,sin(i*TAU/10))
  mound(s.snowroof,bay+n*(r+.45)+Vector3.UP*5.65,Vector3(1.2,.23,1.2))
 var a=Vector3(11,.4,3.4);var b=Vector3(19,.4,3.4)
 Kit.block(s.stone,Vector3(15,.2,-.5),Vector3(9,.4,8))
 snowy_rail(s,a,b);snowy_rail(s,b,Vector3(19,.4,-4.0))
 drifts(s,c,w,d,Vector3.BACK)

static func shelter(s:Dictionary,c:Vector3,w:float,d:float):
 var h=5.8
 Kit.block(s.stone,c+Vector3.UP*.18,Vector3(w,.36,d))
 for side in [-1,1]:
  for z in [-d*.43,0,d*.43]:Kit.block(s.trim,c+Vector3(side*w*.42,h*.5,z),Vector3(.30,h,.30))
 Kit.block(s.wood,c+Vector3(w*.42,h*.42,0),Vector3(.25,h*.84,d*.88))
 for side in [-1,1]:
  var a=c+Vector3(-w*.52,4.2,side*d*.53);var b=c+Vector3(w*.52,h,side*d*.53)
  Kit.rod(s.trim,a,b,.16);Kit.rod(s.snowroof,a+Vector3.UP*.20,b+Vector3.UP*.20,.18)
 s.snowroof.quad(c+Vector3(-w*.53,4.38,-d*.54),c+Vector3(w*.53,h+.22,-d*.54),c+Vector3(w*.53,h+.22,d*.54),c+Vector3(-w*.53,4.38,d*.54))
 for z in [-d*.3,0,d*.3]:
  Forms.Buildings.kili_round(s.wood,c+Vector3(0,.36,z),[Vector2(.55,0),Vector2(.68,.2),Vector2(.68,1.2),Vector2(.52,1.4)])
 drifts(s,c,w,d,Vector3.LEFT)
