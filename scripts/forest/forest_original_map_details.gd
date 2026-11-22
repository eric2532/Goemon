extends RefCounted
## Native scenery families missing from the shared western kit; assembled once at map setup.
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
const Statues=preload("res://scripts/forest/forest_falan_garden_statues.gd")
const Chamber=preload("res://scripts/forest/forest_falken_chamber_props.gd")
const Coastal=preload("res://scripts/forest/forest_coastal_rooms.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Paint=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Harbor=preload("res://scripts/forest/forest_tina_harbor_details.gd")
const GROUPS={
 "room_wall":[11236,11241,11242,11243,11246,11247,11249,11250,15839,15841,15845,16191,16250,16251,16258,16260,16274,16276,16293,16344,16685,16686,16687,16688,16689,16690,16692,16693,16694,16695,16696,16697,16698,16699,16700,16701,16702,16703,16704,16705,16706,16707,16708,16709,16711,16713,16714,16715,16719,16720,16724,16725,16726,16727,16728,16729,16730,16731,16732,16733,16734,16735,16738,16739,16740,16741,16742,16743,16744,16745,16746,16747,16952,16957,16960,16975,16976,17072,17101,17102,17639],
 "pillar":[10463,11248,11583,11584,11586],
 "column":[16272],"obelisk":[11566,11574],
 "parapet":[10621],"building":[10604],"fortification":[10609,10640,10641,10642,10643,10644,10646,10647,10648,10649],
 "lamp":[10422,10423,10426],"planter":[10465,10468,10469,10471],
 "fence":[10457,10474,11391,11492,11493],
 "boulder":[12136,12137,12138,12139,12140,12141,12142,12143,12144,12145,12146,12147,12148,15023,15025,15028,15029,15030,15031,15032,15033,15034,15035,15036,15285,15286,15287,15288,15289,15290,15291,15292,15293,15294,15295,15296,15297,15298,15299,15300,15301,15302],
 "ice":[15568,15574,15575],"gem":[15082,15083,15084,15085,15088,15090],
 "stove":[16554],"coast_side_barrel":[10022],
 "coast_logs":[11000],"coast_stair":[16589,16591,16593,16596,16626],
 "coast_pot":[16180,16182,16183,16519,16648,16651],"coast_basket":[16189,16510,16542,16580,16581],
 "coast_shelf":[16587,16588],
 "coast_cabinet":[10442],"detail_wardrobe":[10439,10441,10493,10502,10503,16015,16513],
 "shelf":[10437,10501,10494,10499],"table":[10528,16028,16030,16166],
 "coast_desk":[10534,16027,16506,16508,16533,16534,16763,16807,17633,17634],
 "coast_clock":[10436,10495,10525],"coast_hanging":[16632,16633,16636],
 "coast_tool":[16521,16522],"coast_picture":[10568,16129,16130,16131,16132,16133,16224,16557,17520,17564,17565,17608],
 "coast_rug":[16135,16142,16291],"coast_flowers":[16211,16213],
 "inn_produce":[10535,10536,10537,10538],"inn_bucket":[16163],"bed":[16065],"chair":[16011,16012],
 "drawers":[10435,10491,10496,16018,16024,16025,17009],
 "armor":[17034,17035,17038,17039,17040,17041,17042],"civic_statue":[10402],
 "detail_bones":[15191,15192,15193,15194,15195,15196,15197,15198,15199,15200,15202,15203,15204,15205,15206,15207,15208,15209,15210,15211,15213,15214],
 "detail_remains":[15231,15232,15233,15234,15235,15236,15237,15238,15239,15240,15241,15242,15243,15244,15245,15246,15247,15248,15249,15250,15251,15252,15253,15254,15279,15281,15282,15283,15284],
 "detail_piano":[16515,16516,17506],"civic_pew":[17526],"detail_books":[10555,10560,17192,17193,17194],
 "detail_lectern":[16559,17580,17581,17582],"detail_candles":[10522,16607],
 "detail_tomb":[11048,11050,11051,11053,11056,11058,11062,11470,11471,11473,11474],
 "detail_snow_stump":[11455],"detail_snow_boards":[11456,11457,11458,11459],
 "detail_snow_log_deck":[11454],"detail_snowman":[11465],
 "detail_open_trough":[11482,11483],
 "detail_sign":[10413,11116,11121,11489,11491,11495,11496,11497,11499,11557,11563,16750,16804,17607],
 "detail_flower_bed":[16333],"detail_aquatic":[11512,11513,11514,11515,11517,11518,11519,11520,11521,11522,11523,11524,11525,11526,11527,11528,11529,11530,11531],
 "detail_mushrooms":[11098,11099,11100,11101,11109],
 "detail_hay":[11020,11021,11022,11033,11034,11035,11093,11094],
 "detail_trough":[11086],"detail_snow_bench":[11486,11487],"detail_potted":[10011,10434,11087,11088,11089],
 "detail_bench":[10037,11041],"detail_boat":[11500,11501],"detail_shelter":[10510,10511,11043,11452],
 "detail_curtain":[16266,16267],"detail_green_gem":[16337,16338],
 "detail_stone_basin":[11037,16302],"detail_altar":[16348],
 "detail_rubble":[17630],
 "detail_dummy":[17169,17170,17171,17173,17174,17175,17176,17216,17217,17218,17219,17220],
 "detail_hat_stand":[17221,17222,17223,17225,17226,17229],"detail_armor_stand":[17632],
 "detail_bust":[16101,17093,17094,17095,17096,17097,17231,17232,17233],
 "detail_horse":[10462,17151,17153,17164],"detail_pedestal":[17045],
 "detail_globe":[16273],"detail_cards":[16277],"detail_tea":[16278],
 "detail_stairs":[17388,17562,17970,17986],"detail_downstairs":[15892,17987],
 "detail_pit":[13997,15891,17971],"detail_arch":[17683],"detail_ruin_gate":[11505],"detail_bridge":[17179],
 "detail_balustrade":[17178,17181,17242],"detail_drying":[11299],
 "detail_well":[11393],"detail_mailbox":[11581],"detail_spinning":[16603,16604,16606],
 "detail_clothes":[16654,16655,16656],"detail_food":[10520,10557,16609,16602],
 "detail_flat_panel":[17605,17656,17669,17672,17673],"detail_tools":[17627,17628],
 "detail_castle":[10036],
 "detail_vent":[16031],"detail_round_table":[16529],"detail_empty_basket":[16539],
 "detail_boiler":[16643,16644],"detail_bellows":[17631],"detail_palisade":[11140,11142,11143,11145,11146],
}
static var kinds:Dictionary={}

static func kind(serial:int)->String:
 if serial in [16133,16136,16138]:return "coast_picture"
 if kinds.is_empty():
  for family in GROUPS:
   for id in GROUPS[family]:
    assert(not kinds.has(id),"Duplicate recovered scenery family "+str(id))
    kinds[id]=family
 return kinds.get(serial,"")

static func build(serial:int,family:String)->Node3D:
 Parts.prepare_primitives()
 var stage=Node3D.new();var root=Node3D.new();stage.add_child(root);var boxes=Boxes.new()
 var wood=Fort.material(Color("795235"),false);var trim=Fort.material(Color("aa8552"),false)
 var stone=Fort.material(Color("8c9485"),false);var pale=Fort.material(Color("c9c7af"),false)
 var dark=Fort.material(Color("353d39"),false);var bone=Fort.material(Color("b7ad89"),false)
 match family:
  "detail_bones","detail_remains":remains(root,serial,family=="detail_remains",bone,dark)
  "detail_piano":
   if serial==17506:grand_piano(root,boxes,wood,trim,pale,dark)
   else:
    piano(root,boxes,wood,trim,pale,dark)
    if serial==16515:root.rotation.y=-PI*.5
  "detail_books":books(root,boxes,serial,wood,pale)
  "detail_lectern":
   Geo.mesh(root,Furniture.desk(3,2,true),Vector3.ZERO,null)
   boxes.add(Vector3(0,1.50,0),Vector3(1.8,.08,1.1),pale)
   for side in [-1,1]:Geo.box(root,Vector3(side*.42,1.56,0),Vector3(.82,.08,1.1),pale).rotation.z=-side*.10
  "detail_candles":Geo.mesh(root,Chamber.lamps(false),Vector3.ZERO,null)
  "detail_tomb":tomb(root,boxes,serial,stone,pale,dark)
  "detail_snow_stump","detail_snow_boards","detail_snow_log_deck","detail_snowman","detail_snow_bench","detail_open_trough":snow_fixture(root,boxes,serial,family,wood,trim,dark)
  "detail_flower_bed":
   boxes.add(Vector3.UP*.2,Vector3(3,.4,2.4),wood)
   boxes.add(Vector3.UP*.41,Vector3(2.8,.03,2.2),dark)
   for i in 9:
    var at=Vector3((i%3-1)*.8,.5,(i/3-1)*.6)
    Geo.beam(root,at,at+Vector3.UP*.5,.035,Fort.material(Color("55734a"),false))
    for petal in 5:Geo.sphere(root,at+Vector3(cos(petal*TAU/5)*.14,.5,sin(petal*TAU/5)*.14),Vector3(.23,.13,.23),pale)
  "detail_aquatic":aquatic(root,serial,wood)
  "detail_mushrooms":
   for i in 4:
    var at=Vector3(cos(i*2.4)*.5,0,sin(i*2.4)*.5);var high=.4+i*.14
    Geo.cylinder(root,at+Vector3.UP*high*.5,.07,high,pale)
    Geo.sphere(root,at+Vector3.UP*high,Vector3(.55,.25,.55),Fort.material(Color("a16a3f" if serial in [11098,11099] else "5c7da1"),false))
  "detail_hay":
   for i in 3:Geo.sphere(root,Vector3((i-1)*.75,.45+(i%2)*.4,0),Vector3(1.2,.9,1.3),Fort.material(Color("c0aa70"),false))
   for side in [-1,1]:boxes.add(Vector3(side*.55,.6,0),Vector3(.06,1.2,1.34),wood)
  "detail_trough":
   Coastal.furnish(root,boxes,Vector3.ZERO,Vector2(3,1),serial,"coast_trough",{})
  "detail_potted":
   var base=.9 if serial in [10011,10434] else 0.0
   if base>0:
    boxes.add(Vector3.UP*.83,Vector3(3,.14,1),wood)
    for side in [-1,1]:boxes.add(Vector3(side*1.2,.4,0),Vector3(.15,.8,.8),wood)
   for i in 3:
    var at=Vector3((i-1)*.8,base,0)
    Geo.cylinder(root,at+Vector3.UP*.3,.25,.6,pale,false,.38)
    Geo.sphere(root,at+Vector3.UP*.85,Vector3(.7,.9,.7),Fort.material(Color("547743"),false))
  "detail_bench":
   boxes.add(Vector3.UP*.8,Vector3(3,.2,1),wood)
   boxes.add(Vector3(0,1.5,-.46),Vector3(3,.7,.16),wood)
   for x in [-1.2,1.2]:boxes.add(Vector3(x,.4,0),Vector3(.2,.8,.85),wood)
  "detail_shelter":shelter(root,boxes,serial,wood,pale)
  "detail_boat":boat(root,boxes,serial,wood,pale)
  "detail_curtain":curtain(root,boxes,serial,pale,trim)
  "detail_green_gem":
   var frost=load("res://scripts/forest/forest_frostpass_art.gd")
   var tool=Furniture.tool()
   for i in 12:frost.ice_blade(tool,Vector3(cos(i*2.4)*.9,0,sin(i*2.4)*.9),1.0+(i%4)*.4,Vector2(.18,.18),Vector2.ZERO,i,.1)
   tool.generate_normals();Geo.mesh(root,tool.commit(),Vector3.ZERO,Fort.material(Color("82ba85"),false))
  "detail_stone_basin":
   for side in [-1,1]:
    boxes.add(Vector3(side*1.35,.25,0),Vector3(.3,.5,3),stone)
    boxes.add(Vector3(0,.25,side*1.35),Vector3(3,.5,.3),stone)
   boxes.add(Vector3.UP*.1,Vector3(2.7,.05,2.7),Geo.mat("4a7884",.18))
  "detail_altar":
   boxes.add(Vector3.UP*.3,Vector3(3,.6,1.5),pale)
   boxes.add(Vector3.UP*.62,Vector3(2.5,.06,1.2),Fort.material(Color("754889"),false))
   for side in [-1,1]:Geo.mesh(root,Chamber.lamps(false),Vector3(side*1.1,.65,0),null).scale=Vector3.ONE*.35
  "detail_rubble":Geo.mesh(root,Chamber.maze_rubble(),Vector3.ZERO,null)
  "detail_dummy":dummy(root,boxes,serial,wood,trim,dark)
  "detail_bust":
   boxes.add(Vector3.UP*.5,Vector3(1.3,1,1.3),stone)
   Geo.sphere(root,Vector3(0,1.4,0),Vector3(.9,.8,.7),pale)
   Geo.sphere(root,Vector3(0,1.9,.08),Vector3(.55,.7,.6),pale)
  "detail_horse":Statues.build(root,boxes,Vector3.ZERO,10462)
  "detail_hat_stand","detail_pedestal","detail_globe":display(root,boxes,serial,family,wood,trim,dark)
  "detail_cards","detail_tea":display_table(root,boxes,family,wood,trim,pale,dark)
  "detail_armor_stand":armor_display(root,boxes,wood,trim,dark,false)
  "detail_stairs","detail_downstairs":
   for i in 6:
    var high=(i+1)*.3
    boxes.add(Vector3(0,high*.5,-1.25+i*.5 if family=="detail_downstairs" else 1.25-i*.5),Vector3(3,high,.51),stone)
  "detail_pit":
   boxes.add(Vector3.UP*.06,Vector3(3,.12,3),dark)
   for side in [-1,1]:
    boxes.add(Vector3(side*1.45,1,0),Vector3(.1,2,3),stone)
    boxes.add(Vector3(0,1,side*1.45),Vector3(3,2,.1),stone)
  "detail_arch":Geo.mesh(root,Chamber.arch(),Vector3.ZERO,null)
  "detail_ruin_gate":
   for side in [-1,1]:
    for z in [-1.2,1.2]:
     boxes.add(Vector3(side*1.5,1.5,z),Vector3(.85,3,.85),stone)
     for y in [.15,2.75,3.05]:boxes.add(Vector3(side*1.5,y,z),Vector3(1.12,.22,1.12),pale)
   for z in [-1.2,1.2]:
    boxes.add(Vector3(0,3.0,z),Vector3(3.8,.60,.9),stone)
    for i in 5:boxes.add(Vector3((i-2)*.74,3.48,z),Vector3(.45,.42,.92),pale)
  "detail_bridge":
   var arch=load("res://scripts/forest/forest_freyja_art.gd").arch_mesh(2.6,stone)
   Geo.mesh(root,arch,Vector3.ZERO,stone).rotation.y=PI*.5
   boxes.add(Vector3.UP*5.3,Vector3(12,.2,3),pale)
   for side in [-1,1]:
    for i in 13:Geo.cylinder(root,Vector3(i-6,5.95,side*1.4),.10,1.1,pale)
    boxes.add(Vector3(0,6.55,side*1.4),Vector3(12,.13,.23),pale)
  "detail_balustrade":
   for side in [-1,1]:boxes.add(Vector3(0,.15,side),Vector3(3,.3,.25),pale)
   for i in 7:
    var x=(i-3)*.45
    Geo.cylinder(root,Vector3(x,.7,1),.07,1.1,pale)
    Geo.cylinder(root,Vector3(x,.7,-1),.07,1.1,pale)
   for side in [-1,1]:boxes.add(Vector3(0,1.3,side),Vector3(3,.12,.2),pale)
  "detail_drying":
   for side in [-1,1]:boxes.add(Vector3(side*1.45,1.5,0),Vector3(.12,3,.12),wood)
   Geo.beam(root,Vector3(-1.45,2.8,0),Vector3(1.45,2.8,0),.025,trim)
   for i in 4:boxes.add(Vector3((i-1.5)*.65,2.4,0),Vector3(.45,.65,.04),Fort.material(Color(["667e67","a56b58","6f7391"][i%3]),false))
  "detail_well":well(root,boxes,wood,stone)
  "detail_mailbox":
   boxes.add(Vector3.UP*.9,Vector3(.14,1.8,.14),wood)
   boxes.add(Vector3.UP*1.8,Vector3(.8,.6,.6),Fort.material(Color("4c8665"),false))
  "detail_spinning":
   Geo.torus(root,Vector3(0,1.1,0),.7,.8,wood).rotation.x=PI*.5
   for i in 8:Geo.beam(root,Vector3.UP*1.1,Vector3(cos(i*TAU/8)*.7,1.1+sin(i*TAU/8)*.7,0),.035,wood)
   for side in [-1,1]:Geo.beam(root,Vector3(side*.6,0,0),Vector3.UP*1.1,.06,wood)
  "detail_clothes":
   for i in 2:
    boxes.add(Vector3((i-.5)*.7,.15,0),Vector3(.5,.3,.8),wood)
    Geo.cylinder(root,Vector3((i-.5)*.7,.45,-.2),.2,.6,trim)
  "detail_food":
   for i in 5:Geo.sphere(root,Vector3(cos(i*2.4)*.45,.18,sin(i*2.4)*.45),Vector3(.5,.35,.5),Fort.material(Color("b78c47"),false))
  "detail_flat_panel":boxes.add(Vector3.UP*.02,Vector3(3,.04,3),wood)
  "detail_tools":
   boxes.add(Vector3.UP*.05,Vector3(2,.1,1),wood)
   for i in 3:
    var at=Vector3((i-1)*.45,.13,0)
    Geo.beam(root,at-Vector3.BACK*.3,at+Vector3.BACK*.3,.035,pale)
    boxes.add(at+Vector3.BACK*.35,Vector3(.14,.035,.23),dark)
  "detail_castle":castle(root,boxes,stone,pale)
  "detail_wardrobe":
   boxes.add(Vector3.UP*1.5,Vector3(2,3,.85),wood)
   for side in [-1,1]:
    boxes.add(Vector3(side*.48,1.5,.46),Vector3(.90,2.65,.12),trim)
    boxes.add(Vector3(side*.48,1.55,.53),Vector3(.73,2.15,.05),Fort.material(Color("475e58"),false) if serial in [10502,10503] else wood)
    Geo.sphere(root,Vector3(side*.12,1.4,.58),Vector3(.10,.10,.10),trim)
   boxes.add(Vector3.UP*3.06,Vector3(2.12,.12,.98),stone if serial==10493 else trim)
  "detail_vent":
   boxes.add(Vector3.UP*.65,Vector3(1.5,1.3,1.2),stone)
   for i in 8:boxes.add(Vector3(0,.2+i*.12,.62),Vector3(1.2,.05,.08),dark)
  "detail_round_table":
   Geo.cylinder(root,Vector3.UP*1.1,1.3,.16,wood)
   Geo.cylinder(root,Vector3.UP*.5,.14,1.0,wood)
   for i in 4:Coastal.furnish(root,boxes,Vector3(cos(i*TAU/4)*1.2,0,sin(i*TAU/4)*1.2),Vector2.ONE,16530,"coast_stool",{})
   Geo.cylinder(root,Vector3.UP*1.3,.18,.25,pale,false,.25)
  "detail_empty_basket":
   Geo.cylinder(root,Vector3.UP*.3,.4,.6,trim,false,.6)
   Geo.cylinder(root,Vector3.UP*.605,.5,.025,dark)
   Geo.torus(root,Vector3.UP*.63,.50,.60,trim)
  "detail_boiler":
   boxes.add(Vector3.UP*.5,Vector3(1.2,1,1.1),dark)
   Geo.cylinder(root,Vector3.UP*1.05,.42,.16,trim)
   Geo.beam(root,Vector3(0,1.1,0),Vector3(0,2.2,0),.10,dark)
   Geo.beam(root,Vector3(0,2.2,0),Vector3(.55 if serial==16644 else -.55,2.6,0),.10,dark)
   for side in [-1,1]:boxes.add(Vector3(side*.46,.1,.38),Vector3(.12,.2,.12),wood)
  "detail_bellows":
   boxes.add(Vector3.UP*.15,Vector3(1.4,.3,1.0),wood)
   var body=Shapes.extrude(PackedVector2Array([Vector2(-.7,.3),Vector2(.7,.3),Vector2(.35,1.15),Vector2(-.35,.95)]),.7)
   Geo.mesh(root,body,Vector3.ZERO,trim)
   for i in 5:Geo.beam(root,Vector3(-.56,.37+i*.11,.38),Vector3(.56,.37+i*.11,.38),.025,wood)
  "detail_palisade":
   boxes.add(Vector3.UP*.6,Vector3(3,1.2,.9),stone)
   for i in 6:Geo.cylinder(root,Vector3((i-2.5)*.48,1.5+(i%2)*.12,0),.23,1.0,wood)
  _:assert(false,"Unknown native detail family "+family)
 boxes.build(root,true)
 return stage

static func remains(root:Node3D,serial:int,blackened:bool,bone:Material,dark:Material):
 var material=dark if blackened else bone
 var tool=Furniture.tool()
 var count_=5 if serial in [15231,15232,15233,15234,15235,15236,15237,15238] else 15
 for i in count_:
  var angle=i*2.39996+serial*.37
  var p=Vector3(cos(angle)*.75*sqrt(float(i)/count_),.07+(i%3)*.04,sin(angle)*.62*sqrt(float(i)/count_))
  var axis=Vector3(cos(angle),.05,sin(angle))*(.16+.12*(i%3))
  Parts.rod(tool,p-axis,p+axis,.033)
  for side in [-1,1]:Parts.oval(tool,p+axis*side,Vector3(.11,.09,.11))
 var skull=Vector3(-.30 if serial%2 else .38,.20,-.25)
 Parts.oval(tool,skull,Vector3(.44,.38,.40))
 Parts.block(tool,skull+Vector3(0,-.10,.17),Vector3(.28,.12,.17))
 Geo.mesh(root,tool.commit(),Vector3.ZERO,material)
 for side in [-1,1]:Geo.sphere(root,skull+Vector3(side*.10,.01,.18),Vector3(.095,.09,.035),Geo.mat("161b19"))
 if serial%4==1:
  var ribs=Furniture.tool()
  for i in 5:
   var z=(i-2)*.12
   Parts.rod(ribs,Vector3(-.32,.10,z),Vector3(0,.27,z),.026)
   Parts.rod(ribs,Vector3(0,.27,z),Vector3(.32,.10,z),.026)
  Geo.mesh(root,ribs.commit(),Vector3(.1,0,.12),material)

static func piano(root:Node3D,boxes,wood:Material,trim:Material,pale:Material,dark:Material):
 boxes.add(Vector3(0,1.35,-.35),Vector3(3,2.7,.72),wood)
 boxes.add(Vector3(0,.93,.16),Vector3(2.65,1.86,.32),wood)
 boxes.add(Vector3(0,1.03,.34),Vector3(2.35,1.4,.06),trim)
 boxes.add(Vector3(0,2.05,.28),Vector3(3,.3,.65),trim)
 boxes.add(Vector3(0,2.24,.30),Vector3(2.75,.08,.55),pale)
 for i in 24:
  var x=(i-11.5)*.11
  boxes.add(Vector3(x,2.285,.30),Vector3(.009,.015,.52),dark)
  if i%7 not in [2,6]:boxes.add(Vector3(x+.05,2.31,.13),Vector3(.045,.065,.28),dark)
 for side in [-1,1]:boxes.add(Vector3(side*1.32,1.05,.50),Vector3(.18,2.10,.18),wood)
 for x in [-.18,0,.18]:boxes.add(Vector3(x,.12,.52),Vector3(.08,.08,.35),trim)
 boxes.add(Vector3(0,2.52,-.33),Vector3(3.15,.16,.86),trim)

static func grand_piano(root:Node3D,boxes,wood:Material,trim:Material,pale:Material,dark:Material):
 var outline=PackedVector2Array([Vector2(-1.45,-1.4),Vector2(1.45,-1.4),Vector2(1.45,-.8),Vector2(1.30,-.2),Vector2(.91,.37),Vector2(.85,1.05),Vector2(.65,1.52),Vector2(.22,1.82),Vector2(-.40,1.90),Vector2(-1.0,1.67),Vector2(-1.36,1.22),Vector2(-1.45,.55)])
 var body=Geo.mesh(root,Shapes.extrude(outline,.40),Vector3.UP*1.32,wood);body.rotation.x=PI*.5
 var lid=Geo.mesh(root,Shapes.extrude(outline,.075),Vector3.UP*1.56,Fort.material(Color("633b29"),false));lid.rotation.x=PI*.5
 boxes.add(Vector3(0,1.37,-1.55),Vector3(2.90,.32,.42),wood)
 boxes.add(Vector3(0,1.57,-1.60),Vector3(2.65,.07,.45),pale)
 for i in 28:
  var x=(i-13.5)*.092
  boxes.add(Vector3(x,1.615,-1.60),Vector3(.008,.02,.43),dark)
  if i%7 not in [2,6]:boxes.add(Vector3(x+.04,1.65,-1.49),Vector3(.04,.07,.23),dark)
 Geo.box(root,Vector3(0,1.87,-1.17),Vector3(1.15,.58,.10),wood).rotation.x=-.18
 for at in [Vector3(-1.18,.60,-1.12),Vector3(1.18,.60,-1.12),Vector3(-.10,.60,1.51)]:
  Geo.cylinder(root,at,.10,1.20,wood,false,.16)
  Geo.sphere(root,at-Vector3.UP*.56,Vector3(.19,.13,.19),dark)
 for x in [-.20,0,.20]:boxes.add(Vector3(x,.19,-1.2),Vector3(.09,.07,.4),trim)
 root.rotation.y=-PI*.5

static func snow_fixture(root:Node3D,boxes,serial:int,family:String,wood:Material,trim:Material,dark:Material):
 var snow=Fort.material(Color("e1eeed"),false)
 if family=="detail_snow_stump":
  Geo.cylinder(root,Vector3.UP*.32,.43,.64,wood,false,.32)
  for i in 5:Geo.beam(root,Vector3.UP*.35,Vector3(cos(i*TAU/5)*.85,.04,sin(i*TAU/5)*.85),.16,wood)
  Geo.sphere(root,Vector3.UP*.62,Vector3(.95,.21,.95),snow)
  Geo.beam(root,Vector3(0,.60,0),Vector3(-.37,1.45,0),.075,wood)
  Geo.beam(root,Vector3(-.04,.72,.02),Vector3(-.35,1.44,.02),.045,snow)
 elif family=="detail_snow_boards":
  var count_=2 if serial==11456 else 3 if serial==11459 else 1
  for i in count_:
   var board=Node3D.new();root.add_child(board)
   board.rotation.y=PI*.5*i if serial==11456 else (i-1)*.45 if serial==11459 else PI*.5 if serial==11458 else 0.0
   board.position=Vector3(0,i*.065,0)
   Geo.box(board,Vector3.UP*.07,Vector3(.21,.14,1.65),wood)
   Geo.box(board,Vector3.UP*.16,Vector3(.26,.07,1.69),snow)
  if serial==11459:root.rotation.y=PI*.25
 elif family=="detail_snow_log_deck":
  for i in 5:
   var x=(i-2)*.36
   Geo.beam(root,Vector3(x,.27,-1.35),Vector3(x,.27,1.35),.18,wood)
   Geo.beam(root,Vector3(x,.40,-1.33),Vector3(x,.40,1.33),.10,snow)
  for z in [-.95,.95]:Geo.beam(root,Vector3(-1,.10,z),Vector3(1,.10,z),.12,trim)
 elif family=="detail_snowman":
  Geo.sphere(root,Vector3.UP*.75,Vector3(1.65,1.50,1.55),snow)
  Geo.sphere(root,Vector3(0,1.75,.05),Vector3(1.05,.95,1.0),snow)
  var red=Fort.material(Color("a84329"),false)
  for side in [-1,1]:
   Geo.sphere(root,Vector3(side*.19,1.84,.50),Vector3(.13,.13,.09),red)
   var end=Vector3(side*1.1,1.58,0)
   Geo.beam(root,Vector3(side*.48,1.18,0),end,.045,wood)
   if side<0:Geo.sphere(root,end+Vector3.UP*.08,Vector3(.27,.37,.23),red)
   else:
    for tip in [Vector3(.17,.15,0),Vector3(.23,0,.02)]:Geo.beam(root,end-Vector3.RIGHT*.15,end+tip,.025,wood)
  for i in 5:Geo.sphere(root,Vector3((i-2)*.09,1.55-abs(i-2)*.015,.51),Vector3(.055,.045,.035),dark)
 elif family=="detail_snow_bench":
  boxes.add(Vector3.UP*.49,Vector3(2.8,.15,.65),wood)
  for side in [-1,1]:boxes.add(Vector3(side*1.03,.23,0),Vector3(.16,.46,.57),wood)
  boxes.add(Vector3.UP*.60,Vector3(2.9,.13,.73),snow)
  if serial==11487:root.rotation.y=-PI*.5
 else:
  boxes.add(Vector3.UP*.13,Vector3(2.8,.18,.65),wood)
  for side in [-1,1]:
   boxes.add(Vector3(0,.42,side*.37),Vector3(2.8,.55,.12),wood)
   boxes.add(Vector3(side*1.34,.42,0),Vector3(.12,.55,.72),wood)
   boxes.add(Vector3(0,.72,side*.37),Vector3(2.85,.08,.15),snow)
  boxes.add(Vector3.UP*.32,Vector3(2.50,.03,.59),Fort.material(Color("6a9294"),false))
  if serial==11482:root.rotation.y=-PI*.5

static func display_table(root:Node3D,boxes,family:String,wood:Material,trim:Material,pale:Material,dark:Material):
 boxes.add(Vector3.UP*.12,Vector3(4.1,.24,1.40),wood)
 boxes.add(Vector3.UP*.65,Vector3(3.75,1.05,1.15),trim)
 boxes.add(Vector3.UP*1.22,Vector3(4.2,.20,1.45),trim)
 boxes.add(Vector3.UP*1.34,Vector3(3.75,.045,1.25),Fort.material(Color("315c4e"),false))
 for i in 8:Geo.cylinder(root,Vector3((i-3.5)*.45,.67,.60),.07,.65,wood)
 if family=="detail_cards":
  for i in 3:
   var card=Geo.box(root,Vector3(.05+i*.40,1.49,-.10+i*.08),Vector3(.40,.065,.70),pale)
   card.rotation.y=(i-1)*.25;card.rotation.x=-.30
   var face=Geo.box(card,Vector3.UP*.039,Vector3(.31,.016,.59),Fort.material(Color(["63549a","bd7541","8c464a"][i]),false))
   for end in [-1,1]:Geo.box(face,Vector3(0,.012,end*.20),Vector3(.22,.012,.025),trim)
  Geo.cylinder(root,Vector3(-1.15,1.43,.20),.18,.15,trim)
  Geo.torus(root,Vector3(-.98,1.48,.20),.12,.16,trim).rotation.x=PI*.5
 else:
  for i in 3:
   var at=Vector3((i-1)*.69+.32,1.37,-.05)
   var height=.48+i*.14
   var metal=Fort.material(Color(["849da0","72918d","8c8964"][i]),false)
   Geo.cylinder(root,at+Vector3.UP*height*.43,.29,height*.86,metal,false,.37)
   Geo.cylinder(root,at+Vector3.UP*height*.92,.29,.07,metal,false,.12)
   Geo.sphere(root,at+Vector3.UP*(height+.04),Vector3(.13,.12,.13),trim)
   Geo.torus(root,at+Vector3(.30,height*.55,0),.19,.24,metal).rotation.x=PI*.5
   Geo.beam(root,at+Vector3(-.17,height*.55,0),at+Vector3(-.54,height*.88,0),.065,metal)
  Geo.cylinder(root,Vector3(-1.25,1.40,.10),.24,.08,wood)
  for i in 3:
   var at=Vector3(-1.25+(i-1)*.16,1.44,.10)
   Geo.cylinder(root,at+Vector3.UP*(.19+i%2*.07),.035,.38+i%2*.14,pale)
   Geo.sphere(root,at+Vector3.UP*(.43+i%2*.14),Vector3(.06,.10,.06),trim)

static func armor_display(root:Node3D,boxes,wood:Material,trim:Material,dark:Material,pedestal:bool):
 var base=.95 if pedestal else .12
 if pedestal:
  boxes.add(Vector3.UP*.45,Vector3(1.35,.90,1.15),wood)
  boxes.add(Vector3.UP*.94,Vector3(1.47,.12,1.27),trim)
 else:boxes.add(Vector3.UP*.06,Vector3(.9,.12,.65),dark)
 Geo.beam(root,Vector3(0,base,0),Vector3(0,base+1.65,0),.055,wood)
 var steel=Fort.material(Color("8d9b9c"),false)
 Geo.sphere(root,Vector3(0,base+1.02,0),Vector3(.67,.80,.34),steel)
 for side in [-1,1]:
  Geo.sphere(root,Vector3(side*.42,base+1.25,0),Vector3(.39,.39,.42),steel)
  Geo.sphere(root,Vector3(side*.31,base+.24,.29),Vector3(.26,.42,.20),steel)
  for i in 3:boxes.add(Vector3(side*.31,base+.16+i*.065,.40),Vector3(.22,.022,.025),dark)
 Geo.sphere(root,Vector3(0,base+1.66,0),Vector3(.59,.55,.52),steel)
 boxes.add(Vector3(0,base+1.62,.28),Vector3(.48,.11,.07),dark)
 for side in [-1,1]:Geo.beam(root,Vector3(side*.25,base+1.75,0),Vector3(side*.38,base+2.10,0),.035,dark)

static func books(root:Node3D,boxes,serial:int,wood:Material,paper:Material):
 var count_=2 if serial==17193 else 7 if serial==17194 else 1
 for i in count_:
  var book=Node3D.new();book.position=Vector3((i%2)*.24,i*.13,(i%3)*.1);book.rotation.y=(i%3-1)*.13;root.add_child(book)
  var cover=Fort.material(Color(["784e3c","506d78","7c6948","5f7653"][i%4]),false)
  Geo.box(book,Vector3.UP*.10,Vector3(1,.16,1.3),paper)
  for y in [.015,.19]:Geo.box(book,Vector3.UP*y,Vector3(1.07,.035,1.37),cover)
  Geo.box(book,Vector3(-.52,.10,0),Vector3(.05,.20,1.37),cover)
  for band in [-.40,.40]:Geo.box(book,Vector3(-.55,.10,band),Vector3(.025,.21,.04),wood)

static func tomb(root:Node3D,boxes,serial:int,stone:Material,pale:Material,dark:Material):
 var snowy=serial in [11470,11471,11473,11474]
 var slab=Shapes.extrude(PackedVector2Array([Vector2(-.5,0),Vector2(.5,0),Vector2(.5,1.05),Vector2(.34,1.30),Vector2(0,1.44),Vector2(-.34,1.30),Vector2(-.5,1.05)]),.28)
 Geo.mesh(root,slab,Vector3.ZERO,stone)
 boxes.add(Vector3.UP*.07,Vector3(1.25,.14,.75),pale)
 for y in [.49,.62,.75,.88]:boxes.add(Vector3(0,y,.148),Vector3(.52,.018,.008),dark)
 if snowy:Geo.sphere(root,Vector3.UP*1.37,Vector3(.88,.24,.4),pale)
 if serial in [11050,11051,11058,11062]:
  boxes.add(Vector3(0,.06,.9),Vector3(1.2,.12,1.7),pale)
 if serial in [11051,11058,11471]:
  for i in 4:
   var at=Vector3((i-1.5)*.19,.07,.55)
   Geo.beam(root,at,at+Vector3.UP*.36,.025,stone)
   Geo.sphere(root,at+Vector3.UP*.36,Vector3(.23,.13,.23),Fort.material(Color("8e8ca4"),false))

static func sign_mesh(serial:int,g:Dictionary)->Mesh:
 if serial in Harbor.SIGNS:return Harbor.sign_mesh(serial,g)
 var texture:Texture2D=load(Art.ROOT+Art.data().pages[int(g.page)])
 var rect=Rect2i(g.rect[0],g.rect[1],g.rect[2],g.rect[3])
 var image=texture.get_image().get_region(rect)
 var crop=Rect2i(0,0,rect.size.x,maxi(1,int(rect.size.y*(.67 if serial==10413 else 1.0))))
 var mask=BitMap.new();mask.create_from_image_alpha(image.get_region(crop),.35)
 mask.grow_mask(-1,Rect2i(Vector2i.ZERO,crop.size));mask.grow_mask(1,Rect2i(Vector2i.ZERO,crop.size))
 var points=[];var mean=Vector2.ZERO
 for y in crop.size.y:
  for x in crop.size.x:
   if mask.get_bitv(Vector2i(x,y)):
    points.append(Vector2(x,y));mean+=Vector2(x,y)
 mean/=maxi(1,points.size())
 var covariance=0.0
 for p:Vector2 in points:
  covariance+=(p.x-mean.x)*(p.y-mean.y)
 var tangent=Vector3.BACK if covariance>0 else Vector3.RIGHT
 var outward=tangent.cross(Vector3.UP)
 var turn=Basis(Vector3.UP,atan2(-tangent.z,tangent.x))
 var front=Furniture.tool();var edge=Furniture.tool()
 var min_y=INF;var max_y=-INF
 for outline:PackedVector2Array in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,crop.size),.65):
  if outline.size()<3:continue
  var profile=PackedVector2Array()
  for pixel:Vector2 in outline:
   var across=((pixel.x+float(g.origin[0]))*3.0/32.0-(outward.x+outward.z)*.06)/(tangent.x+tangent.z)
   var at=tangent*across+outward*.06
   var y=(-float(g.origin[1])+(at.z-at.x)*8.0-pixel.y)*.045
   profile.append(Vector2(across,y));min_y=minf(min_y,y);max_y=maxf(max_y,y)
  var shape=Shapes.extrude(profile,.12)
  var arrays=shape.surface_get_arrays(0)
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   var p:Vector3=turn*arrays[Mesh.ARRAY_VERTEX][i];var local_normal:Vector3=arrays[Mesh.ARRAY_NORMAL][i];var normal:Vector3=turn*local_normal
   var tool=front if local_normal.z>.9 else edge
   tool.set_normal(normal)
   if tool==front:
    var pixel=Vector2(-float(g.origin[0])+(p.x+p.z)*32/3.0,-float(g.origin[1])+(p.z-p.x)*8.0-p.y/.045)
    tool.set_uv((Vector2(rect.position)+pixel)/texture.get_size())
   tool.add_vertex(p)
 assert(is_finite(min_y),"Native sign must retain a printable solid board")
 var px=0.0;var count_=0
 var row=clampi(roundi(-float(g.origin[1])),0,image.get_height()-1)
 for x in image.get_width():
  if image.get_pixel(x,row).a<.5:continue
  px+=x;count_+=1
 var base=(px/maxi(1,count_)+float(g.origin[0]))*3.0/64.0
 Parts.prepare_primitives()
 edge.index()
 Parts.rod(edge,Vector3(base,0,base),Vector3(base,maxf(.2,(min_y+max_y)*.5),base),.055)
 return Furniture.finish([front,edge],[Paint.material(texture),Fort.material(Color("795235"),false)])

static func aquatic(root:Node3D,serial:int,wood:Material):
 var green=Fort.material(Color("648046"),false)
 var tool=Furniture.tool()
 for i in 7:
  var angle=i*2.39996;var at=Vector3(cos(angle)*.38,0,sin(angle)*.38)
  var high=.8+(i%3)*.4
  Parts.rod(tool,at,at+Vector3(.12,high,.08),.025)
  for side in [-1,1]:Parts.oval(tool,at+Vector3(side*.18,high*.6,.08),Vector3(.45,.10,.16))
  if serial in [11512,11513,11514]:Geo.sphere(root,at+Vector3(.12,high,.08),Vector3(.15,.40,.15),wood)
 Geo.mesh(root,tool.commit(),Vector3.ZERO,green)

static func shelter(root:Node3D,boxes,serial:int,wood:Material,pale:Material):
 for x in [-1.35,1.35]:
  for z in [-.9,.9]:boxes.add(Vector3(x,1.0,z),Vector3(.14,2,.14),wood)
 var roof=Furniture.tool()
 for side in [-1,1]:Shapes.quad(roof,Vector3(-1.6,1.9,side*1.1),Vector3(-1.6,2.5,0),Vector3(1.6,2.5,0),Vector3(1.6,1.9,side*1.1))
 Geo.mesh(root,roof.commit(),Vector3.ZERO,pale)
 if serial in [11043,11452]:boxes.add(Vector3.UP*.9,Vector3(3,.18,1.5),wood)

static func boat(root:Node3D,_boxes,serial:int,_wood:Material,_pale:Material):
 Geo.mesh(root,Harbor.boat_mesh(serial,Art.data().graphics[str(serial)]),Vector3.ZERO,null)

static func curtain(root:Node3D,boxes,serial:int,pale:Material,trim:Material):
 boxes.add(Vector3(0,2.8,-.3),Vector3(3,5.6,.6),pale)
 var cloth=Furniture.tool()
 for i in 16:
  var x0=-1.3+i*.10;var x1=x0+.10
  var z0=.08+cos(i*PI*.5)*.055;var z1=.08+cos((i+1)*PI*.5)*.055
  Shapes.quad(cloth,Vector3(x0,.2,z0),Vector3(x0,5.1,z0),Vector3(x1,5.1,z1),Vector3(x1,.2,z1))
 Geo.mesh(root,cloth.commit(),Vector3.ZERO,Fort.material(Color("633b99"),false))
 Geo.beam(root,Vector3(-1.4,5.2,.1),Vector3(.5,5.2,.1),.055,trim)
 if serial==16267:root.rotation.y=PI*.5

static func dummy(root:Node3D,boxes,serial:int,wood:Material,trim:Material,dark:Material):
 boxes.add(Vector3.UP*.15,Vector3(1.3,.3,1.3),trim)
 var model=Statues.sculpt(10401)
 Geo.mesh(root,model,Vector3.UP*.3,wood)
 if serial>=17216:
  var hat=Fort.material(Color("528044" if serial==17219 else "3d6590" if serial==17220 else "b9a87b" if serial==17217 else "71513e"),false)
  Geo.cylinder(root,Vector3.UP*2.83,.39,.08,hat)
  Geo.cylinder(root,Vector3.UP*3.05,.27,.42 if serial!=17219 else .70,hat,false,0.0 if serial==17219 else .26)
 elif serial in [17171,17173,17174,17175,17176]:
  var cloth=Fort.material(Color("65447e" if serial==17173 else "252f32" if serial==17174 else "b5a66a" if serial==17175 else "6d8188"),false)
  boxes.add(Vector3(0,1.65,.27),Vector3(.64,.65,.08),cloth)
  if serial==17173:
   var cape=Furniture.tool()
   Shapes.quad(cape,Vector3(-.33,2.05,-.28),Vector3(.33,2.05,-.28),Vector3(.58,.5,-.42),Vector3(-.58,.5,-.42))
   Shapes.quad(cape,Vector3(.33,2.05,-.28),Vector3(-.33,2.05,-.28),Vector3(-.58,.5,-.42),Vector3(.58,.5,-.42))
   Geo.mesh(root,cape.commit(),Vector3.ZERO,cloth)

static func display(root:Node3D,boxes,serial:int,family:String,wood:Material,trim:Material,dark:Material):
 if family=="detail_pedestal":
  armor_display(root,boxes,wood,trim,dark,true)
  return
 boxes.add(Vector3.UP*.45,Vector3(1,.9,1),wood)
 boxes.add(Vector3.UP*.94,Vector3(1.12,.12,1.12),trim)
 if family=="detail_globe":
  Geo.sphere(root,Vector3.UP*1.45,Vector3(.9,.9,.9),Geo.mat("4f6b97",.18))
  Geo.torus(root,Vector3.UP*1.45,.52,.56,trim).rotation.x=PI*.5
 elif family=="detail_hat_stand":
  var hat=Fort.material(Color("3a6390" if serial in [17221,17225] else "a6513c" if serial in [17222,17226] else "252a2a" if serial==17229 else "9daba8"),false)
  Geo.cylinder(root,Vector3.UP*1.12,.16,.30,dark)
  Geo.cylinder(root,Vector3.UP*1.32,.48,.10,hat)
  if serial in [17225,17229]:Geo.cylinder(root,Vector3.UP*1.63,.28,.62,hat,false,0.0 if serial==17225 else .28)
  else:Geo.sphere(root,Vector3.UP*1.50,Vector3(.65,.42,.65),hat)

static func well(root:Node3D,boxes,wood:Material,stone:Material):
 Geo.cylinder(root,Vector3.UP*.45,.9,.9,stone)
 Geo.cylinder(root,Vector3.UP*.91,.72,.025,Geo.mat("243b37"))
 for side in [-1,1]:boxes.add(Vector3(side*.95,1.2,0),Vector3(.16,2.4,.16),wood)
 var roof=Furniture.tool()
 for side in [-1,1]:Shapes.quad(roof,Vector3(-1.2,2.1,side*.8),Vector3(-1.2,2.8,0),Vector3(1.2,2.8,0),Vector3(1.2,2.1,side*.8))
 Geo.mesh(root,roof.commit(),Vector3.ZERO,wood)

static func castle(root:Node3D,boxes,stone:Material,pale:Material):
 boxes.add(Vector3(0,2,-1),Vector3(5,4,3),stone)
 for side in [-1,1]:
  Geo.cylinder(root,Vector3(side*2.7,2,1),1.1,4,stone)
  for i in 8:
   var a=i*TAU/8
   boxes.add(Vector3(side*2.7+cos(a)*1.0,4.2,1+sin(a)),Vector3(.35,.45,.35),pale)
 boxes.add(Vector3(0,3.5,1),Vector3(3.5,1,1),pale)
