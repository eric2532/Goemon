extends RefCounted
## Authored street-facing variants, inside Tina only; source layouts/physics are untouched.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Data=preload("res://assets/maps/falan/tina/street_art/materials.gd")
const Atlas=preload("res://assets/maps/falan/tina/street_art/materials.png")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
const Scenery=preload("res://scripts/forest/forest_tina_scenery.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const SITES={11409:Vector2i(36,38),11410:Vector2i(21,54),11414:Vector2i(36,27),11407:Vector2i(30,61),11416:Vector2i(46,55),11451:Vector2i(48,35)}
const ACTIVE=[11409,11410,11414,11407,11416,11451]
const STREET_BOUNDARY=[Vector2(24,21),Vector2(43,21),Vector2(43,30),Vector2(75,30),Vector2(75,59),Vector2(48,59),Vector2(48,62),Vector2(40,62),Vector2(40,60),Vector2(38,60),Vector2(38,65),Vector2(19,65),Vector2(19,57),Vector2(16,57),Vector2(16,49),Vector2(26,49),Vector2(26,37),Vector2(27,37),Vector2(27,31),Vector2(24,31)]
static var meshes:Dictionary={}
static var materials:Dictionary={}

static func owns(source:int,serial:int,cell:Vector2i)->bool:
 if source not in [4200,4201]:return false
 if serial in ACTIVE:return cell==SITES[serial] or source==4201 and serial==11407 and cell==Vector2i(30,60)
 var plant=serial<13000 and serial not in Scenery.TREES and Scenery.Profiles.GRAPHICS.has(str(serial))
 return inside(cell) and (plant or serial in [11314,10017,10032,10033,10055] or serial in range(11363,11377) or serial in range(11378,11392))

static func inside(cell:Vector2i)->bool:
 return cell.y>21 and Geometry2D.is_point_in_polygon(Vector2(cell)+Vector2(.01,.01),PackedVector2Array(STREET_BOUNDARY))

static func paint(role:String)->Material:
 if materials.has(role):return materials[role]
 var mat:ShaderMaterial=Source.material(Atlas,true).duplicate()
 mat.set_shader_parameter("original_palette",false);mat.set_shader_parameter("alpha_cutout",false)
 mat.set_shader_parameter("surface_kind",0.0 if role in ["wood","trim","log"] else 1.0)
 if role in ["blue","green","brown"]:
  mat.set_shader_parameter("architecture_roof",true)
  mat.set_shader_parameter("surface_kind",5.0)
  mat.set_shader_parameter("base_color",{"blue":Color("28495f"),"green":Color("354e37"),"brown":Color("55412c")}[role])
 elif role=="glass":
  mat.set_shader_parameter("use_base_texture",false);mat.set_shader_parameter("base_color",Color("355762"))
  mat.set_shader_parameter("surface_kind",6.0)
 elif role=="blue_door":
  mat.set_shader_parameter("use_base_texture",false);mat.set_shader_parameter("base_color",Color("355967"))
  mat.set_shader_parameter("surface_kind",0.0)
 elif role in ["oak_door","red_door","letter"]:
  mat.set_shader_parameter("use_base_texture",false)
  mat.set_shader_parameter("base_color",{"oak_door":Color("695137"),"red_door":Color("742f26"),"letter":Color("e8dac0")}[role])
  mat.set_shader_parameter("surface_kind",5.0)
 elif role=="snowroof":mat.set_shader_parameter("base_color",Color("eee8d6"))
 elif role=="wood":mat.set_shader_parameter("base_color",Color("9d9485"))
 elif role=="trim":mat.set_shader_parameter("base_color",Color("9b8669"))
 materials[role]=mat
 return mat

static func skin(role:String):
 var value=Source.new([],Atlas,.045)
 value.tiles=Data.TILES.duplicate()
 for name_ in ["glass","blue_door","oak_door","red_door","letter"]:value.tiles[name_]=Data.TILES.wood
 value.part=role
 return value

static func block(s,center:Vector3,size_:Vector3,basis:Basis=Basis.IDENTITY):
 var a=-size_*.5;var b=size_*.5
 var points=[Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),Vector3(b.x,b.y,a.z),Vector3(a.x,b.y,a.z),Vector3(a.x,a.y,b.z),Vector3(b.x,a.y,b.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z)]
 for i in points.size():points[i]=center+basis*points[i]
 for face in [[4,7,6,5],[1,2,3,0],[0,3,7,4],[5,6,2,1],[7,3,2,6],[0,4,5,1]]:s.quad(points[face[0]],points[face[1]],points[face[2]],points[face[3]])

static func facade_basis(normal:Vector3)->Basis:
 return Basis(Vector3.UP.cross(normal).normalized(),Vector3.UP,normal)

static func window(skins:Dictionary,at:Vector3,normal:Vector3,width:float=1.35,height:float=1.65):
 var basis=facade_basis(normal)
 block(skins.trim,at+normal*.13,Vector3(width+.34,height+.34,.22),basis)
 block(skins.glass,at+normal*.255,Vector3(width,height,.035),basis)
 for x in [-width*.5,0,width*.5]:block(skins.trim,at+basis.x*x+normal*.30,Vector3(.09,height+.08,.12),basis)
 for y in [-height*.5,height*.08,height*.5]:block(skins.trim,at+Vector3.UP*y+normal*.30,Vector3(width+.10,.09,.12),basis)
 block(skins.trim,at-Vector3.UP*(height*.5+.15)+normal*.27,Vector3(width+.55,.17,.48),basis)
 block(skins.trim,at+Vector3.UP*(height*.5+.20)+normal*.24,Vector3(width+.48,.16,.38),basis)

static func door(skins:Dictionary,at:Vector3,normal:Vector3,height:float=2.8,width:float=1.65,role:String="blue_door"):
 var basis=facade_basis(normal)
 var outline=PackedVector2Array([Vector2(-width*.5,0),Vector2(width*.5,0),Vector2(width*.5,height*.74),Vector2(width*.40,height*.88),Vector2(width*.22,height*.97),Vector2(0,height),Vector2(-width*.22,height*.97),Vector2(-width*.40,height*.88),Vector2(-width*.5,height*.74)])
 var panel=Shapes.extrude(outline,.14)
 append(skins[role],panel,Transform3D(basis,at+normal*.12))
 for i in outline.size()-1:
  rod(skins.trim,at+basis*Vector3(outline[i].x,outline[i].y,.24),at+basis*Vector3(outline[i+1].x,outline[i+1].y,.24),.11)
 block(skins.trim,at+basis*Vector3(0,.08,.30),Vector3(width+.32,.16,.48),basis)
 for x in [-.33,.33]:
  block(skins.trim,at+basis*Vector3(x,.94,.25),Vector3(.075,1.63,.075),basis)
 block(skins.trim,at+basis*Vector3(.44,1.3,.30),Vector3(.11,.14,.12),basis)
 # Two shallow steps retain the original ground/collision owner.
 for i in 2:block(skins.stone,at+normal*(.40+i*.47)+Vector3.UP*(-.18-i*.06),Vector3(width+.70,.15,.50),basis)

static func rod(s,a:Vector3,b:Vector3,radius:float):
 Parts.prepare_primitives()
 append(s,Parts.cylinder,Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())).scaled_local(Vector3(radius*2,a.distance_to(b),radius*2)),(a+b)*.5))

static func append(s,mesh:Mesh,pose:Transform3D):
 var arrays=mesh.surface_get_arrays(0);var indices=arrays[Mesh.ARRAY_INDEX]
 var normals=pose.basis.inverse().transposed()
 for j in indices.size() if indices is PackedInt32Array and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size():
  var i:int=indices[j] if indices is PackedInt32Array and not indices.is_empty() else j
  var p:Vector3=pose*arrays[Mesh.ARRAY_VERTEX][i]
  s.surface.set_normal((normals*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
  s.surface.set_uv(Vector2(p.x,p.y)/1.5);s.surface.set_uv2(s.tiles[s.part]);s.surface.add_vertex(p)

static func finish(skins:Dictionary)->Mesh:
 var result=ArrayMesh.new()
 for role in skins:
  var mesh:Mesh=skins[role].surface.commit()
  if mesh==null or mesh.get_surface_count()==0:continue
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
  result.surface_set_material(result.get_surface_count()-1,paint(role))
 return result

static func mesh(serial:int,g:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 if serial not in ACTIVE:
  meshes[serial]=street_prop(serial,g);return meshes[serial]
 var skins={}
 for role in ["wood","trim","stone","snowroof","blue","green","brown","glass","blue_door","oak_door","red_door","letter","log"]:skins[role]=skin(role)
 match serial:
  11409:blue_house(skins,Vector3(6,0,-4.5))
  11410:blue_house(skins,Vector3(4.5,0,-6),true)
  11414:hospital(skins)
  11407:green_house(skins)
  11416:pub(skins)
  11451:shed(skins)
 meshes[serial]=finish(skins)
 meshes[serial].set_meta("tina_street_art",serial);meshes[serial].set_meta("tina_only_scenery",serial)
 return meshes[serial]

static func blue_house(s:Dictionary,center:Vector3,night:bool=false):
 var w=11.0 if night else 13.0;var d=13.0 if night else 10.0;var wall=4.65
 block(s.stone,center+Vector3.UP*.15,Vector3(w+.25,.30,d+.25))
 block(s.wood,center+Vector3.UP*(wall*.5+.25),Vector3(w,wall,d))
 for side in [-1,1]:
  for end in [-1,1]:block(s.trim,center+Vector3(side*(w*.5+.01),wall*.5+.25,end*(d*.5+.01)),Vector3(.28,wall+.1,.28))
 for y in [.39,wall+.12]:block(s.trim,center+Vector3.UP*y,Vector3(w+.22,.20,d+.22))
 block(s.trim,center+Vector3.UP*(wall+.27),Vector3(w+1,.22,d+1))
 block(s.snowroof,center+Vector3.UP*(wall+.34),Vector3(w+1.45,.10,d+1.45))
 # Reuse the existing curved hip construction, without a projected whole-facade image.
 s.blue.tiles["trim"]=Data.TILES.trim
 Forms.hip_roof(s.blue,w+1.15,d+1.15,wall+.35,3.15,center,false,true)
 var entrance=center+(Vector3(-1.5,.25,d*.5) if night else Vector3(-w*.5,.25,1.5))
 var normal=Vector3.BACK if night else Vector3.LEFT
 door(s,entrance,normal)
 window(s,center+Vector3(-w*.5,2.55,-2.8),Vector3.LEFT)
 for x in ([3.0] if night else [-3.2,3.2]):window(s,center+Vector3(x,2.55,d*.5),Vector3.BACK)
 for side in [-1,1]:window(s,center+Vector3(w*.5,2.55,side*2.8),Vector3.RIGHT)
 window(s,center+Vector3(0,2.55,-d*.5),Vector3.FORWARD)
 # Carved porch brow, supported from the door frame rather than a floating picture.
 var brow=entrance+normal*.55
 var basis=facade_basis(normal)
 block(s.trim,brow+Vector3.UP*3.20,Vector3(2.75,.18,1.25),basis)
 Forms.hip_roof(s.blue,3.0 if night else 1.65,1.65 if night else 3.0,3.30,.65,brow,false,true)
 for end in [-1,1]:rod(s.trim,entrance+basis.x*end*1.05+Vector3.UP*2.45,brow+basis.x*end*1.05+Vector3.UP*3.18,.095)

static func round_body(s:Dictionary,center:Vector3,radius:float,height:float):
 Forms.Buildings.kili_round(s.stone,center,[Vector2(0,.02),Vector2(radius+.2,.02),Vector2(radius+.2,.28),Vector2(radius,.35)])
 Forms.Buildings.kili_round(s.wood,center,[Vector2(radius,.28),Vector2(radius,height)])
 for y in [.42,height-.08]:Forms.Buildings.kili_round(s.trim,center,[Vector2(radius+.10,y),Vector2(radius+.10,y+.17)])
 for i in 12:
  var normal=Vector3(cos(i*TAU/12),0,sin(i*TAU/12))
  block(s.trim,center+normal*(radius+.02)+Vector3.UP*(height*.5+.15),Vector3(.18,height-.3,.20),facade_basis(normal))

static func bell_roof(s:Dictionary,center:Vector3,radius:float,base:float,rise:float,color:String,cupola:bool=false):
 Forms.Buildings.kili_round(s.snowroof,center,[Vector2(radius+.42,base-.10),Vector2(radius+.42,base+.06)])
 var profile=[Vector2(radius+.46,base),Vector2(radius+.45,base+.14),Vector2(radius*.98,base+rise*.24),Vector2(radius*.86,base+rise*.56),Vector2(radius*.61,base+rise*.82),Vector2(radius*.24,base+rise)]
 if not cupola:profile.append(Vector2(.03,base+rise+.15))
 Forms.Buildings.kili_round(s[color],center,profile)
 if cupola:
  Forms.Buildings.kili_round(s.trim,center,[Vector2(radius*.23,base+rise-.03),Vector2(radius*.23,base+rise+.75)])
  Forms.Buildings.kili_round(s[color],center,[Vector2(radius*.28,base+rise+.72),Vector2(radius*.28,base+rise+.83),Vector2(.04,base+rise+1.15)])

static func hospital(s:Dictionary):
 var center=Vector3(6,0,-7.5);var radius=7.0;var wall=4.9
 round_body(s,center,radius,wall);bell_roof(s,center,radius,wall+.08,2.75,"blue",true)
 for i in [0,1,2,3,4,7,8,9,10,11]:
  var angle=i*TAU/12;var normal=Vector3(cos(angle),0,sin(angle))
  window(s,center+normal*(radius+.03)+Vector3.UP*2.65,normal,1.35,1.7)
 # The projecting entry meets the existing hospital door cell, without moving its gate.
 var entrance=Vector3(-4.5,.25,-6)
 block(s.wood,Vector3(-2.6,1.8,-6),Vector3(3.8,3.1,3.25))
 block(s.trim,Vector3(-2.6,3.36,-6),Vector3(4.1,.18,3.55))
 Forms.hip_roof(s.blue,4.4,3.8,3.46,.8,Vector3(-2.6,0,-6),false,true)
 door(s,entrance,Vector3.LEFT,2.9,1.85,"oak_door")
 var normal=Vector3(-1,0,1).normalized();var plaque=center+normal*(radius+.25)+Vector3.UP*3.50;var basis=facade_basis(normal)
 block(s.blue_door,plaque,Vector3(1.0,1.0,.15),basis)
 block(s.letter,plaque+normal*.12,Vector3(.65,.17,.06),basis);block(s.letter,plaque+normal*.12,Vector3(.17,.65,.06),basis)

static func green_house(s:Dictionary):
 var center=Vector3(8.8,0,-8.5);var w=15.2;var d=14.0;var wall=4.85
 block(s.stone,center+Vector3.UP*.15,Vector3(w+.25,.30,d+.25))
 block(s.wood,center+Vector3.UP*(wall*.5+.25),Vector3(w,wall,d))
 for x in [-1,1]:
  for z in [-1,1]:block(s.trim,center+Vector3(x*w*.5,wall*.5+.25,z*d*.5),Vector3(.28,wall,.28))
 block(s.trim,center+Vector3.UP*(wall+.27),Vector3(w+.8,.22,d+.8))
 block(s.snowroof,center+Vector3.UP*(wall+.34),Vector3(w+1.4,.1,d+1.4))
 Forms.hip_roof(s.green,w+1.1,d+1.1,wall+.35,3.35,center,false,true)
 var bay=Vector3(2.1,0,-2.2);var radius=4.3
 round_body(s,bay,radius,4.45);bell_roof(s,bay,radius,4.53,1.95,"green")
 for angle in [0.0,PI*.25,PI*.5,PI*.75]:
  var normal=Vector3(cos(angle),0,sin(angle));window(s,bay+normal*(radius+.03)+Vector3.UP*2.45,normal,1.15,1.5)
 door(s,bay+Vector3(-radius,.25,0),Vector3.LEFT,2.85,1.8,"oak_door")
 for z in [-3.7,2.4]:window(s,center+Vector3(w*.5,2.7,z),Vector3.RIGHT)
 for x in [-3.4,3.4]:window(s,center+Vector3(x,2.7,-d*.5),Vector3.FORWARD)

static func pub(s:Dictionary):
 var center=Vector3(8,0,-5.5);var w=16.0;var d=15.0;var wall=4.8
 block(s.stone,center+Vector3.UP*.17,Vector3(w+.3,.34,d+.3))
 block(s.wood,center+Vector3.UP*(wall*.5+.28),Vector3(w,wall,d))
 for x in [-1,1]:
  for z in [-1,1]:block(s.trim,center+Vector3(x*w*.5,wall*.5+.25,z*d*.5),Vector3(.32,wall,.32))
 for y in [.45,wall+.20]:block(s.trim,center+Vector3.UP*y,Vector3(w+.3,.22,d+.3))
 block(s.snowroof,center+Vector3.UP*(wall+.36),Vector3(w+1.4,.1,d+1.4))
 Forms.hip_roof(s.brown,w+1.1,d+1.1,wall+.38,3.25,center,false,true)
 var entrance=Vector3(0,.28,1.4);door(s,entrance,Vector3.LEFT,2.95,1.85,"red_door")
 for z in [-9.3,-5.6]:window(s,Vector3(0,2.7,z),Vector3.LEFT,1.6,1.85)
 for x in [4.5,10.5]:window(s,Vector3(x,2.7,2),Vector3.BACK,1.6,1.85)
 for z in [-9.3,-3.3]:window(s,Vector3(16,2.7,z),Vector3.RIGHT,1.6,1.85)
 block(s.stone,Vector3(-1.2,.12,-.2),Vector3(2.6,.24,6.6))
 for z in [-3.2,3.0]:
  block(s.trim,Vector3(-2.3,.8,z),Vector3(.18,1.6,.18))
  block(s.trim,Vector3(-1.3,1.18,z),Vector3(2.0,.14,.16))
 var basis=facade_basis(Vector3.LEFT);var sign=Vector3(-.40,3.75,-1.9)
 block(s.trim,sign,Vector3(2.55,1.0,.20),basis)
 var text=TextMesh.new();text.font=ThemeDB.fallback_font;text.text="PUB";text.font_size=72;text.pixel_size=.013;text.depth=.025
 append(s.letter,text,Transform3D(basis,sign+Vector3.LEFT*.13))

static func shed(s:Dictionary):
 var center=Vector3(3,0,-6);var w=8.0;var d=13.2
 var roof=[center+Vector3(-w*.55,3.3,-d*.55),center+Vector3(w*.55,4.9,-d*.55),center+Vector3(w*.55,4.9,d*.55),center+Vector3(-w*.55,3.3,d*.55)]
 s.brown.quad(roof[0],roof[1],roof[2],roof[3])
 s.wood.quad(roof[3]-Vector3.UP*.14,roof[2]-Vector3.UP*.14,roof[1]-Vector3.UP*.14,roof[0]-Vector3.UP*.14)
 for i in 4:
  var j=(i+1)%4;s.trim.quad(roof[i],roof[j],roof[j]-Vector3.UP*.16,roof[i]-Vector3.UP*.16)
 for x in [-1,1]:
  var high=3.3 if x<0 else 4.9
  for z in [-5.8,0,5.8]:block(s.trim,center+Vector3(x*w*.46,high*.5,z),Vector3(.24,high,.24))
 block(s.wood,center+Vector3(w*.46,1.6,0),Vector3(.19,3.2,d*.91))
 for row in 2:
  for i in 4-row:Forms.Tina.timber_log(s.log,center+Vector3((i-(3-row)*.5)*.62,.32+row*.53,-2.8),Vector3.BACK,5.5,.30,"log","wood")
 for i in 2:
  var at=center+Vector3(-1.7+i*2.0,.7,3.3)
  block(s.wood,at,Vector3(1.5,1.4,1.7))
  for y in [-.55,.55]:block(s.trim,at+Vector3.UP*y,Vector3(1.58,.12,1.78))

static func street_prop(serial:int,g:Dictionary)->Mesh:
 if serial in range(11363,11377) or serial in range(11378,11392):
  var wood=Scenery.Harbor.structure()
  Forms.Tina.fence(wood,serial,1.45,1.0)
  var fence=wood.finish();fence.set_meta("tina_street_art",serial);fence.set_meta("tina_only_scenery",serial)
  return fence
 var original=Scenery.mesh(serial,g) if Scenery.owns(4200,serial) else Forms.mesh(serial,Forms.kind(serial,false,g),g,Scenery.Art.solid_texture(int(g.page)))
 var bounds=original.get_aabb();var height=bounds.size.y
 var target=5.5 if serial==11314 else 3.2 if serial==10033 else 1.55 if serial in [10017,10032] else 1.25 if serial==10055 else .7 if serial in range(12471,12486) else 2.1 if serial in range(11692,11696) else 1.5
 var factor=minf(1,target/height)
 var pose=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*factor),Vector3.UP*(-bounds.position.y*factor))
 var result=ArrayMesh.new()
 for slot in original.get_surface_count():
  var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  surface.append_from(original,slot,pose);surface.commit(result)
  result.surface_set_material(slot,original.surface_get_material(slot))
 result.set_meta("tina_street_art",serial);result.set_meta("tina_only_scenery",serial)
 return result
