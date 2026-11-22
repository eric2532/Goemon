extends RefCounted
## The saved markers still own these buildings. Their archive footprints are in metres.
const Proportions=preload("res://scripts/forest/forest_falan_proportions.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Arena=preload("res://scripts/forest/forest_falan_arena_art.gd")
const Mansion=preload("res://scripts/forest/forest_falan_mansion_art.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Carvings=preload("res://scripts/forest/forest_falan_carvings.gd")
const Details=preload("res://scripts/forest/forest_falan_landmark_details.gd")
const SHELLS={
 Vector2i(-52,2):[1201,"falan_chapel",180,Vector2(-339,-3),Vector3(35.4,40,26.2)],
 Vector2i(-28,36):[1111,"falan_townhouse",90,Vector2(-168,214.5),Vector3(22,17,13.6)],
 Vector2i(-28,-34):[1112,"falan_townhouse",90,Vector2(-168,-202.5),Vector3(22,17,13.6)],
 Vector2i(8,-14):[1301,"falan_townhouse",180,Mansion.CITY_CENTER,Vector3(20.7,18,20.7)],
 Vector2i(-12,-44):[1121,"falan_townhouse",0,Vector2(-67.5,-265.5),Vector3(23.5,23,17.6)],
 Vector2i(1,-35):[1101,"falan_townhouse",0,Vector2(7.5,-207),Vector3(18.0,18,15.4)],
 Vector2i(-39,40):[1092,"falan_townhouse",90,Vector2(-231,241.5),Vector3(15.0,18,18.0)],
 Vector2i(-42,-23):[1091,"falan_townhouse",0,Vector2(-252,-135),Vector3(21.0,18,15.0)],
 Vector2i(14,18):[1400,"falan_chapel",180,Vector2(66,93),Vector3(24,20,26.7)],
}
static var lancet_mesh:Mesh
static var slate:ShaderMaterial
static var inn_slate:ShaderMaterial
static var bank_paints:Dictionary={}

static func shell(anchor,item:Dictionary)->Array:
 var spec:Array=SHELLS.get(anchor,[])
 if spec.is_empty() or item.get("kind","")!=spec[1] or item.rotation!=spec[2] or not is_equal_approx(float(item.scale),.92):return []
 return spec

static func bounds(anchor:Vector2i,spec:Array)->AABB:
 var offset:Vector2=spec[3]-Vector2(anchor)*6
 var extent:Vector3=spec[4]
 var key="civic_%d"%spec[0]
 var box=AABB(Vector3(-extent.x*.5,0,-extent.z*.5),extent)
 if Proportions.enabled and Proportions.Data.FITS.has(key):
  var fit:Transform3D=Proportions.Data.FITS[key]
  var yaw=0.0 if spec[0] in [1091,1101,1121] else PI*.5
  var turn=Transform3D(Proportions.Data.BASES.get(key,Basis(Vector3.UP,yaw)),Vector3.ZERO)
  box=(turn*fit*turn.affine_inverse())*box
  box.size.y=Proportions.height(key,box.size.y)
 box.position+=Vector3(offset.x,0,offset.y)
 return box

static func build(parent:Node3D,p:Vector3,spec:Array):
 var root=Node3D.new()
 root.name="FalanCivicFacade_%d"%spec[0]
 root.position=Vector3(spec[3].x,p.y,spec[3].y)
 root.rotation.y=0.0 if spec[0] in [1091,1101,1121] else PI*.5
 parent.add_child(root)
 if Details.Data.FACADES.has(spec[0]):
  var source:Array=Details.Data.FACADES[spec[0]]
  root.set_meta("falan_window_feature",source[1])
  root.set_meta("original_graphic",source[0])
 var boxes=Boxes.new()
 var stone=Fort.material(Color("c1b59a"))
 var pale=Fort.material(Color("e0d5b8"))
 var trim=Fort.material(Color("ddc8a2"),false)
 var base=Fort.material(Color("888675"))
 if slate==null:
  slate=Fort.material(Color("386080")).duplicate()
  slate.set_shader_parameter("masonry_tile",Vector2(.79,.47))
 var ridge=Fort.material(Color("547992"),false)
 var copper=Fort.material(Color("a98b52"),false)
 if spec[0]==1201:
  cathedral(root,boxes,stone,pale,trim,base,slate,ridge,copper)
 elif spec[0]==1091:
  employment_office(root,boxes,stone,pale,trim,base,slate,ridge,copper)
 elif spec[0]==1092:
  guild(root,boxes,stone,pale,trim,base,slate,ridge,copper)
 elif spec[0]==1101:
  inn(root,boxes,stone,pale,trim,base,copper)
 elif spec[0]==1121:
  bank(root,boxes,stone,pale,trim,base,slate,ridge,copper)
 elif spec[0]==1301:
  Mansion.exterior(root,boxes,stone,pale,trim,base,slate,copper)
 elif spec[0]==1400:
  Arena.exterior(root,boxes,stone,pale,trim,base,slate,copper)
 else:
  hospital(root,boxes,stone,pale,trim,base,slate,ridge,copper)
 var points:Array[Vector3]=[]
 for group in boxes.groups.values():
  for pose:Transform3D in group.transforms:
   for corner in 8:
    var p_=Vector3(.5 if corner&1 else -.5,.5 if corner&2 else -.5,.5 if corner&4 else -.5)
    points.append(pose*p_+group.origin)
 root.set_meta("source_box_points",points)
 boxes.build(root)
 Proportions.apply(root,"civic_%d"%spec[0])

static func employment_office(root:Node3D,boxes,stone:Material,pale:Material,trim:Material,base:Material,slate:Material,ridge:Material,copper:Material):
 var walnut=Fort.material(Color("715034"),false)
 var orange=Fort.material(Color("b25b32"),false)
 var plinth=Fort.material(Color("b6a98a"))
 boxes.add(Vector3(0,.42,-1.17),Vector3(20.55,.84,12.10),base)
 boxes.add(Vector3(0,5.08,-1.17),Vector3(19.52,10.16,11.64),stone)
 for y in [1.16,4.25,9.55]:
  boxes.add(Vector3(0,y,-1.17),Vector3(19.79,.32,11.89),trim)
 roof(root,Vector3(0,9.77,-1.14),11.96,19.62,5.44,slate,ridge,PI*.5,Shapes.BARREL,stone)
 for side in [-1,1]:
  boxes.add(Vector3(0,10.0,-1.14+side*5.86),Vector3(20.04,1.35,.66),pale)
  for i in 9:
   boxes.add(Vector3((i-4)*2.26,10.87,-1.14+side*5.86),Vector3(.91,.77,.82),trim)
  for z in [-6.41,-4.22,-2.03,.16,2.35,4.54]:
   boxes.add(Vector3(side*9.73,10.87,z),Vector3(.89,.77,.86),trim)
  boxes.add(Vector3(side*9.73,10.0,-1.08),Vector3(.68,1.35,11.72),pale)
  for z in [-6.59,4.62]:
   var p=Vector3(side*9.53,0,z)
   Geo.cylinder(root,p+Vector3.UP*2.82,.51,5.64,pale,false,.39).mesh.radial_segments=10
   Geo.cylinder(root,p+Vector3.UP*5.83,.65,.52,slate,false,.35)
  window(root,Vector3(side*6.63,2.17,4.69),0,1.62,5.09,false)
  roof(root,Vector3(side*6.63,7.17,4.64),2.53,1.24,.95,slate,trim,0.0,[],stone)
  window(root,Vector3(side*9.79,4.54,-1.13),side*PI*.5,2.54,3.19,false)
  Details.add(root,"office_rosette",Vector3(side*9.80,7.0,-4.40),Vector2(2.5,2.5),side*PI*.5)
  var dormer=Vector3(side*4.68,11.55,4.0)
  boxes.add(dormer,Vector3(1.28,1.43,1.66),slate)
  roof(root,dormer+Vector3.UP*.60,1.65,1.83,1.03,slate,trim,0,Shapes.BARREL,stone)
  window(root,Vector3(dormer.x,11.13,4.84),0,.65,1.0,false)
  Carvings.add(root,"office_mask",Vector3(side*9.10,7.65,4.84),Vector2(.85,1.86))
  var pennant=Vector3(side*4.33,6.86,4.76)
  boxes.add(pennant,Vector3(.65,2.23,.08),orange)
  boxes.add(pennant+Vector3(0,1.12,.065),Vector3(.87,.10,.16),copper)
 portal(root,boxes,Vector3(0,.54,4.71),3.18,4.87,trim)
 for row in [[.23,.46,3.26,1.16],[.46,.24,2.96,.99],[5.34,.42,3.47,1.18],[5.61,.19,3.24,1.14]]:
  var arc=Geo.cylinder(root,Vector3(0,row[0],4.11),1.0,row[1],plinth)
  arc.mesh.radial_segments=36
  arc.scale=Vector3(row[2],1,row[3]*2.72)
 for x in [-2.43,2.43]:
  var p=Vector3(x,0,6.13)
  Geo.cylinder(root,p+Vector3.UP*2.83,.23,5.02,walnut,false,.18)
  for h in [.47,.79,4.99,5.12]:Geo.cylinder(root,p+Vector3.UP*h,.32,.15,copper)
 roof(root,Vector3(0,6.08,4.46),4.25,1.77,1.77,slate,trim,0.0,[],stone)
 boxes.add(Vector3(0,6.74,5.39),Vector3(2.59,.89,.13),walnut)
 for side in [-1,1]:
  Geo.beam(root,Vector3(side*.88,6.51,5.47),Vector3(side*.33,6.95,5.47),.073,copper)
 boxes.add(Vector3(0,6.57,5.48),Vector3(.67,.10,.064),copper)

static func guild(root:Node3D,boxes,stone:Material,pale:Material,trim:Material,base:Material,slate:Material,ridge:Material,copper:Material):
 var walnut=Fort.material(Color("6f4c33"),false)
 var brick=Fort.material(Color("8b5243"))
 var gold=Fort.material(Color("ccab63"),false)
 var red=Fort.material(Color("ae3d2d"),false)
 var blue=Fort.material(Color("344c57"),false)
 var entrance=1.5
 var door_red=Fort.material(Color("743e31"),false)
 boxes.add(Vector3(0,.37,-.15),Vector3(17.9,.74,14.35),base)
 boxes.add(Vector3(0,5.28,-1.01),Vector3(16.9,10.56,11.90),stone)
 boxes.add(Vector3(0,8.92,-.93),Vector3(17.39,.49,12.19),trim)
 roof(root,Vector3(0,9.85,-1.14),11.93,12.2,5.65,slate,ridge,0.0,[],stone)
 portal(root,boxes,Vector3(entrance,.72,4.96),3.72,6.12,pale)
 for i in 8:
  boxes.add(Vector3(entrance+(i-3.5)*.435,2.77,5.175),Vector3(.404,3.42,.032),door_red)
 for i in 3:
  boxes.add(Vector3(entrance,.13+i*.22,7.02-i*.50),Vector3(5.30,.26+i*.44,1.0),brick)
 for side in [-1,1]:
  var wall_x=side*8.30
  boxes.add(Vector3(wall_x,9.55,-.90),Vector3(.78,1.78,13.1),pale)
  for i in 7:
   boxes.add(Vector3(wall_x,10.76,-6.6+i*1.85),Vector3(.94,.75,.85),trim)
  for z in [-4.8,-.65,3.46]:
   window(root,Vector3(side*8.47,1.15,z),side*PI*.5,.67,2.86,false)
   var shaft=Vector3(side*8.56,0,z-1.25)
   Geo.cylinder(root,shaft+Vector3.UP*6.33,.19,5.48,pale,false,.16)
   for y in [3.60,4.00,8.83]:
    Geo.cylinder(root,shaft+Vector3.UP*y,.28,.19,trim)
  window(root,Vector3(side*8.49,4.65,-.78),side*PI*.5,2.05,3.60,true)
  roof(root,Vector3(side*8.47,7.46,-.78),2.75,1.30,.90,slate,trim,side*PI*.5,[],stone)
  var p=Vector3(entrance+side*2.38,0,6.45)
  Geo.cylinder(root,p+Vector3.UP*3.35,.42,6.70,walnut,false,.37).mesh.radial_segments=8
  for level in [.48,1.06,3.14,5.72,6.56]:
   Geo.cylinder(root,p+Vector3.UP*level,.56,.21,trim).mesh.radial_segments=8
  var banner=Vector3(entrance+side*2.86,5.35,7.23)
  boxes.add(banner,Vector3(.76,3.54,.09),red)
  boxes.add(banner+Vector3(0,1.77,.035),Vector3(.91,.15,.17),gold)
  boxes.add(banner+Vector3(side*.18,0,.06),Vector3(.09,3.28,.043),gold)
  var pier=Vector3(side*7.74,0,5.00)
  Geo.cylinder(root,pier+Vector3.UP*4.64,.27,8.23,pale,false,.22).mesh.radial_segments=8
  Carvings.add(root,"guild_relief",Vector3(side*7.74,6.70,5.35),Vector2(.72,2.60))
  for y in [.70,1.23,4.87,8.76]:
   Geo.cylinder(root,pier+Vector3.UP*y,.39,.19,trim).mesh.radial_segments=8
 for i in 8:
  boxes.add(Vector3((i-3.5)*2.10,10.76,-7.04),Vector3(.89,.74,.86),trim)
 boxes.add(Vector3(0,9.55,-7.04),Vector3(16.95,1.78,.73),pale)
 boxes.add(Vector3(entrance,7.19,5.89),Vector3(5.92,1.04,2.83),pale)
 for i in 4:
  boxes.add(Vector3(entrance+(i-1.5)*1.46,7.94,7.22),Vector3(.68,.67,.42),trim)
 boxes.add(Vector3(entrance,7.17,7.38),Vector3(2.59,.74,.13),blue)
 for side in [-1,1]:
  Geo.beam(root,Vector3(entrance-side*.39,6.94,7.46),Vector3(entrance+side*.42,7.42,7.46),.062,gold)
  boxes.add(Vector3(entrance-side*.25,7.02,7.46),Vector3(.26,.08,.07),gold)
 for x in [-5.8,5.9]:
  window(root,Vector3(x,2.62,4.97),0,1.18,3.69,false)

 Geo.beam(root,Vector3(5.4,9.3,4.9),Vector3(5.4,9.3,7.4),.075,gold)
 boxes.add(Vector3(5.4,7.8,7.28),Vector3(1.62,2.86,.16),gold)
 Details.add(root,"guild_banner",Vector3(5.4,7.8,7.38),Vector2(1.47,2.69))

static func inn(root:Node3D,boxes,stone:Material,pale:Material,trim:Material,base:Material,copper:Material):
 if inn_slate==null:
  inn_slate=Fort.material(Color("3b6a73")).duplicate()
  inn_slate.set_shader_parameter("masonry_tile",Vector2(.79,.47))
 var timber=Fort.material(Color("72513d"),false)
 var dark=Fort.material(Color("4c382d"),false)
 var brass=Fort.material(Color("d0a564"),false)
 var scarlet=Fort.material(Color("a7442f"),false)
 var doorway=-1.5
 boxes.add(Vector3(0,.42,0),Vector3(17.8,.84,14.5),base)
 boxes.add(Vector3(0,4.23,0),Vector3(15.94,8.46,13.47),stone)
 boxes.add(Vector3(0,1.37,0),Vector3(16.12,1.16,13.66),timber)
 roof(root,Vector3(0,8.03,-.27),14.10,17.2,6.15,inn_slate,trim,PI*.5,Shapes.INN_ROOF,stone)
 roof(root,Vector3(doorway,6.70,4.5),5.12,6.39,3.25,inn_slate,timber,0.0,[],stone)
 portal(root,boxes,Vector3(doorway,0,6.84),2.97,4.87,timber)
 for side in [-1,1]:
  var x=side*6.70
  var tower=Vector3(x,0,5.05)
  for band in [[.36,.72,2.25,base],[3.05,5.50,2.16,pale],[5.80,.50,2.35,trim]]:
   Geo.cylinder(root,tower+Vector3.UP*band[0],band[2],band[1],band[3]).mesh.radial_segments=24
  for merlon in 8:
   var angle=merlon*TAU/8
   var at=tower+Vector3(sin(angle)*1.98,6.36,cos(angle)*1.98)
   Geo.box(root,at,Vector3(.71,.93,.64),pale).rotation.y=angle
  window(root,tower+Vector3(0,1.84,2.17),0,.90,2.30,false)
  var flag=Vector3(doorway+side*3.02,5.48,6.80)
  Geo.beam(root,flag+Vector3(0,1.73,-.36),flag+Vector3(0,1.28,.71),.065,copper)
  boxes.add(flag+Vector3(0,0,.56),Vector3(.42,2.86,.09),scarlet)
  boxes.add(flag+Vector3(side*.12,0,.62),Vector3(.08,2.89,.036),brass)
  Geo.sphere(root,flag+Vector3(0,1.36,.75),Vector3.ONE*.21,brass)
  var chimney=Vector3(side*5.05,11.32,-1.18)
  boxes.add(chimney,Vector3(1.75,6.1,1.64),stone)
  boxes.add(chimney+Vector3.UP*3.13,Vector3(2.18,.35,2.05),trim)
  roof(root,chimney+Vector3.UP*3.20,2.20,2.23,.91,inn_slate,timber,PI*.5,[],stone)
  for z in [-4.06,1.1]:
   window(root,Vector3(side*7.99,3.11,z),side*PI*.5,1.48,2.88,false)
 roof(root,Vector3(7.35,6.48,-1.92),4.81,3.40,2.25,inn_slate,timber,PI*.5,[],stone)
 for z in [-4.03,.2]:
  boxes.add(Vector3(8.04,3.03,z),Vector3(.40,6.06,.42),timber)
 var sign=Vector3(doorway,11.09,7.16)
 boxes.add(sign,Vector3(4.79,2.80,.23),dark)
 boxes.add(sign+Vector3.UP*1.40,Vector3(4.97,.14,.33),brass)
 boxes.add(sign-Vector3.UP*1.40,Vector3(4.97,.14,.33),brass)
 Details.add(root,"inn_sign",sign+Vector3(0,0,.15),Vector2(4.53,2.65))

static func bank(root:Node3D,boxes,stone:Material,pale:Material,trim:Material,base:Material,slate:Material,ridge:Material,copper:Material):
 var dark=Fort.material(Color("374852"),false)
 var brick=Fort.material(Color("88614e"))
 var gold=Fort.material(Color("d8ae5b"),false)
 for original:ShaderMaterial in [stone,pale,trim,base,slate,brick]:
  if bank_paints.has(original):continue
  var paint:ShaderMaterial=original.duplicate()
  paint.set_shader_parameter("weathered_masonry",true)
  paint.set_shader_parameter("weathered_masonry_strength",.15 if original==slate else .28)
  paint.set_shader_parameter("masonry_tile",Vector2(.79,.47) if original==slate else Vector2(.95,.48) if original==brick else Vector2(1.10,.65))
  bank_paints[original]=paint
 stone=bank_paints[stone];pale=bank_paints[pale];trim=bank_paints[trim];base=bank_paints[base];slate=bank_paints[slate];brick=bank_paints[brick]
 boxes.add(Vector3(0,.62,0),Vector3(22.9,1.24,16.6),base)
 boxes.add(Vector3(0,6.1,0),Vector3(20.2,12.2,14.4),stone)
 boxes.add(Vector3(0,2.34,0),Vector3(20.55,2.23,14.63),brick)
 boxes.add(Vector3(0,4.07,0),Vector3(20.57,.36,14.68),trim)
 boxes.add(Vector3(0,11.83,0),Vector3(20.57,.48,14.67),trim)
 roof(root,Vector3(0,12,0),15.3,20.35,6.6,slate,slate,PI*.5,Shapes.BARREL,stone)
 var doorway=-1.5
 for side in [-1,1]:
  var jamb=Vector3(doorway+side*2.8,0,7.92)
  Geo.cylinder(root,jamb+Vector3.UP*3.23,.52,6.46,trim,false,.39).mesh.radial_segments=8
  for height in [.51,1.25,5.90,6.43]:
   Geo.cylinder(root,jamb+Vector3.UP*height,.69,.26,pale).mesh.radial_segments=8
  boxes.add(jamb+Vector3(0,4.7,.56),Vector3(.28,.40,.25),copper)
  Geo.sphere(root,jamb+Vector3(0,4.4,.63),Vector3(.52,.64,.52),gold)
 for x in [-7.2,-1.5,4.2]:
  var central=x==doorway
  var height=14.6 if central else 13.15
  boxes.add(Vector3(x,height*.5,5.43),Vector3(4.72,height,5.44),stone)
  boxes.add(Vector3(x,11.69,8.18),Vector3(4.84,.25,.36),trim)
  if central:
   # The center gable and its sign sit forward of the main roof.
   portal(root,boxes,Vector3(x,0,8.19),3.99,6.85,pale)
   var seal=Geo.cylinder(root,Vector3(x,7.08,8.42),.77,.16,copper)
   seal.rotation.x=PI*.5
   var inset=Geo.cylinder(root,Vector3(x,7.08,8.53),.55,.09,gold)
   inset.rotation.x=PI*.5
   boxes.add(Vector3(x,9.27,8.38),Vector3(5.42,2.72,.26),pale)
   boxes.add(Vector3(x,9.27,8.54),Vector3(5.18,2.48,.16),dark)
   Details.add(root,"bank_sign",Vector3(x,9.28,8.66),Vector2(5.12,2.45))
  else:
   window(root,Vector3(x,5.05,8.19),0,1.52,3.42,false)
   boxes.add(Vector3(x,3.24,8.20),Vector3(.42,2.78,.10),copper)
  window(root,Vector3(x,height-3.69,8.17),0,1.56,3.27,false)
  roof(root,Vector3(x,height-.12,7.0),5.13,2.8,2.42,slate,slate,0,Shapes.BARREL,stone)
  roof(root,Vector3(x,14.4,-4.6),3.35,3.7,1.65,slate,slate,0,Shapes.BARREL,stone)
 for side in [-1,1]:
  var edge=side*10.24
  Shapes.bank_end(root,edge,pale,trim,dark)
  for band in [-1,1]:Carvings.add(root,"bank_frieze",Vector3(edge+side*.52,15.2,band*2.5),Vector2(5.0,1.8),side*PI*.5)
  for z in [-6.65,6.73]:
   var p=Vector3(side*10.35,0,z)
   boxes.add(p+Vector3.UP*5.6,Vector3(2.05,11.2,2.08),base)
   Geo.beam(root,p+Vector3(side*.33,2.9,0),p+Vector3(-side*.38,13.42,0),.62,pale)
   for level in [1.18,3.54,7.18,11.23,13.42]:
    boxes.add(p+Vector3.UP*level,Vector3(2.23,.28,2.24),trim)
   Geo.cylinder(root,p+Vector3.UP*14.19,.56,1.36,slate,false,.12)
  for z in [-4.05,-1.35,1.35,4.05]:
   window(root,Vector3(side*10.81,5.5,z),side*PI*.5,1.10,3.41,false)
  for level in [5.33,9.23,14.43]:
   boxes.add(Vector3(edge,level,0),Vector3(1.62,.33,13.58),trim)
  for z in [-5.63,0,5.63]:
   var p=Vector3(edge,16.04-absf(z)*.34,z)
   Geo.cylinder(root,p,.54,1.79,trim,false,.22)
   Geo.sphere(root,p+Vector3.UP*.98,Vector3.ONE*.39,pale)

static func cathedral(root:Node3D,boxes,stone:Material,pale:Material,trim:Material,base:Material,slate:Material,ridge:Material,copper:Material):
 boxes.add(Vector3(0,.39,0),Vector3(25.7,.78,34.3),base)
 boxes.add(Vector3(0,8.2,-.50),Vector3(16.4,16.4,33.3),stone)
 roof(root,Vector3(0,16.05,-.48),17.1,33.4,6.7,slate,trim,0.0,[],stone)
 for side in [-1,1]:
  boxes.add(Vector3(side*9.57,5.85,-.25),Vector3(5.56,11.7,30.9),pale)
  boxes.add(Vector3(side*9.58,11.69,-.25),Vector3(5.94,.36,31.1),trim)
  for z in [-10.6,-5.3,0.0,5.3,10.6]:
   window(root,Vector3(side*12.37,1.61,z),side*PI*.5,2.60,8.35,true)
   window(root,Vector3(side*8.23,12.34,z),side*PI*.5,1.51,3.80,true)
   var pier=Vector3(side*12.05,0,z-2.56)
   boxes.add(pier+Vector3.UP*4.97,Vector3(1.77,9.94,1.32),pale)
   boxes.add(pier+Vector3.UP*.67,Vector3(1.96,1.34,1.58),base)
   boxes.add(pier+Vector3.UP*10.04,Vector3(2.04,.45,1.58),trim)
   Geo.beam(root,pier+Vector3.UP*10.11,Vector3(side*8.0,14.7,pier.z),.39,pale)
  for z in [-13.95,13.95]:
   var tower=Vector3(side*10.43,0,z)
   spire(root,tower,2.53,16.6 if z>0 else 17.3,stone,trim,slate,ridge,copper)
   window(root,tower+Vector3(0,4.5,2.35 if z>0 else -2.35),0 if z>0 else PI,1.38,6.64,true)
   window(root,tower+Vector3(side*2.36,4.5,0),side*PI*.5,1.38,6.64,true)
  spire(root,Vector3(side*4.9,0,14.56),1.38,19.8,pale,trim,slate,ridge,copper)
  spire(root,Vector3(side*3.72,19.8,-5.8),.82,8.7,stone,trim,slate,ridge,copper)
 boxes.add(Vector3(0,9.8,15.28),Vector3(7.4,19.6,3.94),pale)
 window(root,Vector3(0,8.65,17.29),0,4.38,8.90,true)
 portal(root,boxes,Vector3(0,0,17.32),3.68,6.88,trim)
 spire(root,Vector3(0,20.0,-5.7),3.43,11.8,stone,trim,slate,ridge,copper)
 for side in [-1,1]:
  window(root,Vector3(side*3.13,24.4,-5.7),side*PI*.5,1.50,4.78,true)

static func hospital(root:Node3D,boxes,stone:Material,pale:Material,trim:Material,base:Material,slate:Material,ridge:Material,copper:Material):
 boxes.add(Vector3(0,.46,-.2),Vector3(13.45,.92,21.4),base)
 boxes.add(Vector3(0,4.65,-1.0),Vector3(12.0,9.3,18.7),stone)
 roof(root,Vector3(0,8.75,-1.2),13.2,20.1,6.55,slate,trim,0.0,[],stone)
 for side in [-1,1]:
  for z in [-6.7,-2.0,2.56]:
   window(root,Vector3(side*6.025,2.3,z),side*PI*.5,1.38,4.9,false)
  var buttress=Vector3(side*5.98,0,-3.15)
  boxes.add(buttress+Vector3.UP*3.3,Vector3(1.61,6.6,1.54),pale)
  Geo.cylinder(root,buttress+Vector3.UP*7.67,1.0,2.10,trim,false,.26)
  boxes.add(Vector3(side*3.33,2.6,8.35),Vector3(2.43,5.2,4.29),pale)
  boxes.add(Vector3(side*3.33,5.11,8.35),Vector3(2.68,.47,4.49),trim)
 boxes.add(Vector3(0,7.68,7.39),Vector3(6.62,15.36,6.58),pale)
 for height in [5.56,11.47,15.1]:
  boxes.add(Vector3(0,height,7.39),Vector3(6.89,.29,6.85),trim)
 for i in 5:
  var spread=(i-2)*1.30
  for side in [-1,1]:
   boxes.add(Vector3(spread,15.81,7.39+side*3.16),Vector3(.65,1.03,.69),trim)
   if i>0 and i<4:boxes.add(Vector3(side*3.16,15.81,7.39+spread),Vector3(.69,1.03,.65),trim)
 for side in [-1,1]:
  window(root,Vector3(side*3.33,10.33,7.48),side*PI*.5,1.36,3.61,false)
  roof(root,Vector3(side*3.34,13.48,7.44),1.25,1.72,.75,slate,ridge,side*PI*.5,[],stone)
 window(root,Vector3(0,10.24,10.72),0,1.67,3.86,false)
 roof(root,Vector3(0,13.43,10.75),2.05,1.65,1.0,slate,ridge,0.0,[],stone)
 portal(root,boxes,Vector3(0,0,10.74),3.21,5.21,trim)
 roof(root,Vector3(0,4.62,11.42),4.42,2.61,1.65,slate,trim,0.0,[],stone)
 for side in [-1,1]:
  var p=Vector3(side*1.97,0,12.28)
  var timber=Fort.material(Color("715037"),false)
  Geo.cylinder(root,p+Vector3.UP*2.33,.24,4.66,timber,false,.19)
  for h in [.34,1.63,3.18,4.35]:Geo.cylinder(root,p+Vector3.UP*h,.29,.22,timber)
 Details.add(root,"healer",Vector3(0,8.28,10.86),Vector2(1.70,2.55))

static func spire(root:Node3D,p:Vector3,radius:float,height:float,stone:Material,trim:Material,slate:Material,ridge:Material,copper:Material):
 var shaft=Geo.cylinder(root,p+Vector3.UP*height*.5,radius,height,stone,false,radius*.90)
 shaft.mesh.radial_segments=8
 for level in [.045,.19,.62,.87,.974]:
  var band=Geo.cylinder(root,p+Vector3.UP*(height*level),radius*(1.05-level*.09),.28,trim)
  band.mesh.radial_segments=8
 var bottom=radius
 var y=height
 for step in [[.94,.53],[.66,.48],[.39,.43],[.06,.45]]:
  var rise:float=radius*step[1]
  var roof_part=Geo.cylinder(root,p+Vector3.UP*(y+rise*.5),bottom,rise,slate,false,radius*step[0])
  roof_part.mesh.radial_segments=8
  var line=Geo.cylinder(root,p+Vector3.UP*y,bottom+.054,.12,ridge)
  line.mesh.radial_segments=8
  bottom=radius*step[0]
  y+=rise
 Geo.sphere(root,p+Vector3.UP*(y+.14),Vector3.ONE*.31,copper)
 Geo.spike(root,p+Vector3.UP*(y+.22),p+Vector3.UP*(y+1.17),.089,copper)

static func roof(root:Node3D,p:Vector3,width:float,length_:float,height:float,slate:Material,trim:Material,yaw:float=0.0,profile:Array=[],gables:Material=null):
 var holder=Node3D.new()
 holder.position=p
 holder.rotation.y=yaw
 root.add_child(holder)
 var mesh=SurfaceTool.new()
 mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var ends=SurfaceTool.new();ends.begin(Mesh.PRIMITIVE_TRIANGLES)
 var end_surface=mesh if gables==null else ends
 var rims=SurfaceTool.new();rims.begin(Mesh.PRIMITIVE_TRIANGLES)
 Shapes.Parts.prepare_primitives()
 var rim_radius=.28 if root.get_meta("original_graphic",0)==10010 else .15
 if profile.is_empty():profile=[Vector2(1,0),Vector2(.79,.12),Vector2(.57,.40),Vector2(.30,.72),Vector2(0,1)]
 for side in [-1,1]:
  for i in profile.size()-1:
   var a=Vector3(side*profile[i].x*width*.5,profile[i].y*height,-length_*.5)
   var b=Vector3(side*profile[i+1].x*width*.5,profile[i+1].y*height,-length_*.5)
   var dz=Vector3.BACK*length_
   if side>0:quad(mesh,a,a+dz,b+dz,b)
   else:quad(mesh,a,b,b+dz,a+dz)
   Shapes.Parts.rod(rims,a,b,rim_radius)
   Shapes.Parts.rod(rims,a+dz,b+dz,rim_radius)
   var toe=Vector3(0,0,a.z)
   for point in ([a,b,toe,a+dz,toe+dz,b+dz] if side>0 else [a,toe,b,a+dz,b+dz,toe+dz]):
    end_surface.add_vertex(point)
 mesh.generate_normals()
 var result=mesh.commit();result.surface_set_material(0,slate)
 if gables!=null:
  ends.generate_normals();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,ends.commit().surface_get_arrays(0));result.surface_set_material(1,gables)
 var roof_mesh=Geo.mesh(holder,result,Vector3.ZERO,null)
 roof_mesh.set_meta("falan_roof_profile",profile)
 Geo.mesh(holder,rims.commit(),Vector3.ZERO,trim).set_meta("falan_roof_rim",true)
 Geo.beam(holder,Vector3(0,height,-length_*.5),Vector3(0,height,length_*.5),.22,slate)

static func lancet()->Mesh:
 if lancet_mesh!=null:return lancet_mesh
 var mesh=SurfaceTool.new()
 mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var outline=Shapes.LANCET
 for i in range(1,outline.size()-1):
  for p in [outline[0],outline[i],outline[i+1]]:
   mesh.set_normal(Vector3.BACK)
   mesh.set_uv(Vector2(p.x+.5,1.0-p.y))
   mesh.add_vertex(p)
 lancet_mesh=mesh.commit()
 return lancet_mesh

static func window(root:Node3D,p:Vector3,yaw:float,width:float,height:float,glass:bool):
 var trim=Fort.material(Color("ded3b8"),false)
 var shadow=Fort.material(Color("293535"),false)
 var face=Node3D.new()
 # Clear the projecting stone courses so they do not cut through native panes.
 face.position=p+Vector3(sin(yaw),0,cos(yaw))*.17 if root.has_meta("falan_window_feature") else p
 face.rotation.y=yaw
 root.add_child(face)
 Geo.mesh(face,lancet(),Vector3.ZERO,trim).scale=Vector3(width+.42,height+.20,1)
 Geo.mesh(face,lancet(),Vector3(0,.11,.041),shadow).scale=Vector3(width,height-.05,1)
 if root.has_meta("falan_window_feature"):
  var feature:String=root.get_meta("falan_window_feature")
  var pane=Geo.mesh(face,lancet(),Vector3(0,.15,.062),Details.material(feature))
  pane.scale=Vector3(width*.92,height-.22,1)
  pane.set_meta("falan_source_feature",feature)
  for side in [-1,1]:
   Geo.box(face,Vector3(side*width*.143,height*.39,.085),Vector3(.055,height*.61,.065),trim)
  Geo.box(face,Vector3(0,.035,.13),Vector3(width+.56,.21,.33),trim)
  if root.get_meta("original_graphic",0)==10010:
   Geo.mesh(face,Shapes.bank_frame(width,height),Vector3.ZERO,trim).set_meta("falan_bank_moulding",true)
  return
 var palette=[Geo.mat("3e7890",.05,.15),Geo.mat("b98a49",.05,.17),Geo.mat("995b75",.05,.15),Geo.mat("4f8a83",.05,.16)]
 for column in [-1,0,1]:
  var maximum=7 if glass else 4
  for i in maximum:
   var color=palette[posmod(column*3+i,4)] if glass else Fort.material(Color("4b5350"),false)
   var scale_=.80 if i==maximum-1 and column!=0 else 1.0
   Geo.box(face,Vector3(column*width*.28,.22+(i+.5)*height*.73/maximum,.061),Vector3(width*.227*scale_,height*.68/maximum,.05),color)
 for side in [-1,1]:
  Geo.box(face,Vector3(side*width*.143,height*.39,.075),Vector3(.065,height*.61,.085),trim)
 Geo.box(face,Vector3(0,.035,.13),Vector3(width+.56,.21,.33),trim)

static func portal(root:Node3D,boxes,p:Vector3,width:float,height:float,trim:Material):
 var wood=Fort.material(Color("67462f"),false)
 var gap=Fort.material(Color("34352f"),false)
 Geo.mesh(root,lancet(),p,trim).scale=Vector3(width+.85,height+.27,1)
 Geo.mesh(root,lancet(),p+Vector3(0,.08,.095),gap).scale=Vector3(width,height,1)
 for i in 8:
  var x=(i-3.5)*width*.117
  boxes.add(p+Vector3(x,height*.327,.14),Vector3(width*.110,height*.57,.13),wood)
 for side in [-1,1]:
  boxes.add(p+Vector3(side*(width*.5+.17),height*.32,.07),Vector3(.40,height*.64,.34),trim)
 boxes.add(p+Vector3(0,.12,.35),Vector3(width+.68,.23,1.02),trim)
 if root.get_meta("original_graphic",0)==10010:
  Geo.mesh(root,Shapes.bank_frame(width,height),p,trim).set_meta("falan_bank_moulding",true)

static func quad(mesh:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
 for p in [a,b,c,a,c,d]:mesh.add_vertex(p)

static func collision_parts(anchor:Vector2i,spec:Array)->Array[AABB]:
 var result:Array[AABB]=[bounds(anchor,spec)]
 var doors=preload("res://assets/maps/falan/interior_data.gd").DOORS.get(1000,[])
 for door in doors:
  if door[1]!=spec[0]:continue
  var at:Vector2=door[0]-Vector2(anchor)*6
  var next:Array[AABB]=[]
  for box in result:
   var floor=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
   if not floor.grow(.7).has_point(at):next.append(box);continue
   var distances=[absf(at.x-floor.position.x),absf(at.x-floor.end.x),absf(at.y-floor.position.y),absf(at.y-floor.end.y)]
   var side=distances.find(distances.min())
   var cut=Rect2(at-Vector2(1.3,1.3),Vector2(2.6,2.6))
   if side==0:cut.position.x=floor.position.x-1;cut.end=Vector2(at.x+1.0,cut.end.y)
   elif side==1:cut.position.x=at.x-1.0;cut.end=Vector2(floor.end.x+1,cut.end.y)
   elif side==2:cut.position.y=floor.position.y-1;cut.end=Vector2(cut.end.x,at.y+1.0)
   else:cut.position.y=at.y-1.0;cut.end=Vector2(cut.end.x,floor.end.y+1)
   cut=cut.intersection(floor)
   # Source door coordinates own their existing open portal; preserve that lane through the fitted body.
   var pieces=[Rect2(floor.position,Vector2(cut.position.x-floor.position.x,floor.size.y)),Rect2(Vector2(cut.end.x,floor.position.y),Vector2(floor.end.x-cut.end.x,floor.size.y)),Rect2(Vector2(cut.position.x,floor.position.y),Vector2(cut.size.x,cut.position.y-floor.position.y)),Rect2(Vector2(cut.position.x,cut.end.y),Vector2(cut.size.x,floor.end.y-cut.end.y))]
   for piece:Rect2 in pieces:
    if piece.size.x>.001 and piece.size.y>.001:next.append(AABB(Vector3(piece.position.x,box.position.y,piece.position.y),Vector3(piece.size.x,box.size.y,piece.size.y)))
  result=next
 return result
