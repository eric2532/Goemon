extends RefCounted
## Private source-bound counters and tables; no map enrollment until visual review.
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Reuse=preload("res://scripts/forest/forest_east_room_furniture.gd")
const Cases=preload("res://scripts/forest/forest_east_room_casework.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Bank=preload("res://scripts/forest/forest_falan_bank_art.gd")
const Inn=preload("res://scripts/forest/forest_falan_inn_art.gd")
const Guild=preload("res://scripts/forest/forest_falan_guild_art.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const IDS=[16070,16071,16074,16121,16141,16156,16164,16165,16167,16168,16536,16876,16878,16879,16881,16882,16883,16884,17055,17056,17566,17567,17571,17578,17593,17594,17618,17620,17622,17637]
static var meshes:Dictionary={}
static func owns(serial:int)->bool:return serial in IDS
static func data()->Dictionary:return Cases.data()
static func podium()->Mesh:
 var body=Furniture.tool();var top=Furniture.tool()
 Furniture.rounded_block(body,Vector3.UP*.83,Vector3(1.8,1.66,1.8),.06)
 Furniture.rounded_block(top,Vector3.UP*1.72,Vector3(1.92,.15,1.92),.06)
 return Furniture.finish([body,top],[Fort.material(Color("cfc7a5"),false),Fort.material(Color("935e36"),false)])
static func table(serial:int)->Mesh:
 # The existing inn table supplies the whole open-leg construction. Native
 # marble/wood/cloth remains on its observed top and sides, not on the back.
 var stage=Node3D.new();var boxes=Boxes.new()
 Inn.furnish(stage,boxes,Vector3.ZERO,2.,3.,false,serial,"inn_table")
 var result=East.reusable_node_mesh(stage);stage.free()
 return result
static func lower_storage(serial:int)->Mesh:
 Furniture.Parts.prepare_primitives()
 var frame=Furniture.tool();var logs=Furniture.tool();var ends=Furniture.tool()
 for side in [-1,1]:Furniture.rounded_block(frame,Vector3(0,.85,side*1.15),Vector3(1.6,1.7,.15),.04)
 for y in [.1,1.1,1.84]:Furniture.rounded_block(frame,Vector3(0,y,0),Vector3(1.7,.16,2.5),.045)
 if serial==17618:
  Furniture.rounded_block(frame,Vector3(0,1.49,0),Vector3(1.55,.6,2.25),.04)
  for z in [-.57,.57]:Furniture.Parts.block(frame,Vector3(-.82,1.49,z),Vector3(.08,.48,1.08))
 for row in 3:
  for col in 3-row:
   var z=(col-(2-row)*.5)*.55;var y=.28+row*.26
   Furniture.Parts.rod(logs,Vector3(-.72,y,z),Vector3(.72,y,z),.18)
   Furniture.Parts.rod(ends,Vector3(-.735,y,z),Vector3(-.73,y,z),.145)
 return Furniture.finish([frame,logs,ends],[Cases.material(),Fort.material(Color("75543a"),false),Fort.material(Color("c3a47c"),false)])
static func raw(serial:int,g:Dictionary)->Mesh:
 var stage=Node3D.new();var boxes=Boxes.new();var role:String=g.role
 match role:
  "curved_counter":Bank.furnish(stage,boxes,Vector3.ZERO,3.,4.8,false,"bank_counter",serial)
  "goods_counter":Guild.furnish(stage,boxes,Vector3.ZERO,"guild_counter",serial)
  "plain_wood_counter","kitchen_counter":
   Inn.furnish(stage,boxes,Vector3.ZERO,1.7,4.4 if role=="kitchen_counter" else 1.7,false,serial,"inn_counter")
  "covered_counter":stage.add_child(instance(podium()))
  "low_open_display","marble_low_table","tea_table":stage.add_child(instance(table(serial)))
  "covered_low_seat":stage.add_child(instance(Furniture.bench(2.,3.)))
  "writing_table":
   stage.add_child(instance(Furniture.desk(3.,4.,true)))
   var chair=instance(Furniture.chair());chair.position=Vector3(-1.5,0,.45);stage.add_child(chair)
  "drawer_over_firewood","firewood_counter":stage.add_child(instance(lower_storage(serial)))
  "writing_hutch":
   stage.add_child(instance(Furniture.desk(2.7,3.2,true)))
   var back=instance(Cases.raw_shell(.85,3.2,3.5,4));back.position=Vector3(.9,0,0);stage.add_child(back)
  _:assert(false,"Unprepared native counter role "+role)
 boxes.build(stage,true)
 var result=East.reusable_node_mesh(stage);stage.free();return result
static func instance(mesh:Mesh)->MeshInstance3D:
 var node=MeshInstance3D.new();node.mesh=mesh;return node
static func mesh(serial:int,graphic:Dictionary)->Mesh:
 assert(owns(serial),"Exact private counter scope")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=Cases.data().graphics[str(serial)]
 assert(g.source_rgba_sha256==graphic.rgba_sha256,"Regenerate native counter source references")
 var turn=PI*.5 if int(g.footprint[0])>int(g.footprint[1]) else 0.
 if serial in [16167,17056,17567,17622]:turn+=PI
 var result=Cases.native_front(Reuse.fitted(raw(serial,g),g,turn),serial,g)
 result.set_meta("east_native_counter",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("inferred_closed_reverse",true);meshes[serial]=result;return result
