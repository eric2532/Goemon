extends RefCounted
## Private source-specific shop displays; original services remain with their NPCs.
const Misc=preload("res://scripts/forest/forest_east_misc_furniture.gd")
const Cases=preload("res://scripts/forest/forest_east_room_casework.gd")
const Reuse=preload("res://scripts/forest/forest_east_room_furniture.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const ROOT="res://assets/maps/falan/east_region/misc_furniture/"
const IDS=[16749,16754,16765,16766,16824,16825,16828,17044,17052,17182,17183,17528]
static var meshes:Dictionary={}
static func data()->Dictionary:return Misc.data()
static func owns(serial:int)->bool:return serial in IDS
static func arched_board(width:float,base:float,rise:float,depth:float)->Mesh:
 var outline=PackedVector2Array([Vector2(-width*.5,base),Vector2(width*.5,base)])
 for i in range(17):
  var angle=float(i)*PI/16.
  outline.append(Vector2(cos(angle)*width*.5,base+rise*.64+sin(angle)*rise*.36))
 var board=Furniture.Shapes.extrude(outline,depth)
 return East.transformed_existing(board,Transform3D(Basis(Vector3.UP,-PI*.5),Vector3(.49,0,0)),Cases.material())
static func raw(serial:int)->Mesh:
 Furniture.Parts.prepare_primitives()
 var parts=[];var cap=Furniture.tool();var stone=Furniture.tool();var metal=Furniture.tool()
 match serial:
  16749,16765,16766:
   parts.append(Cases.raw_shell(1.05,1.45,1.25,0,2))
   parts.append(arched_board(1.45,1.18,1.65,.12))
   # The original open display shelf, rather than a solid upper cabinet.
   for y in[1.27,1.74]:Furniture.rounded_block(cap,Vector3(-.04,y,0),Vector3(1.10,.10,1.45),.035)
  16754:
   parts.append(Cases.raw_shell(.90,2.15,.68,0,2))
   parts.append(arched_board(2.15,.60,2.5,.14))
   for y in[1.17,1.85,2.45]:Furniture.Parts.rod(cap,Vector3(-.43,y,-.94),Vector3(-.43,y,.94),.045)
  16824,16825,16828:
   Furniture.rounded_block(stone,Vector3.UP*.77,Vector3(1.30,1.54,1.30),.035)
   for y in[.10,1.48]:Furniture.rounded_block(cap,Vector3.UP*y,Vector3(1.43,.16,1.43),.035)
   if serial==16824:Furniture.rounded_block(cap,Vector3.UP*1.74,Vector3(1.25,.34,1.25),.035)
   else:parts.append(East.transformed_existing(Cases.raw_shell(.95,1.05,1.85,6),Transform3D(Basis.IDENTITY,Vector3.UP*1.57)))
  17044:
   parts.append(Cases.raw_shell(1.10,1.40,1.32,0,2))
   # Two bent original pipes rise from a timber mount. Keep their open spacing.
   for z in[-.32,.32]:
    Furniture.Parts.rod(metal,Vector3(.05,1.34,z),Vector3(.05,2.30,z),.075)
    var previous=Vector3(.05,2.30,z)
    for i in range(1,17):
     var t=float(i)*PI/16.;var next=Vector3(.05-.27*(1.-cos(t)),2.30+.27*sin(t),z)
     Furniture.Parts.rod(metal,previous,next,.075);previous=next
  17052,17182:
   parts.append(Cases.raw_shell(.95,1.50,1.38,0,2))
   parts.append(arched_board(1.50,1.27,1.48,.12))
   for y in[1.43,1.88,2.25]:Furniture.rounded_block(cap,Vector3(-.04,y,0),Vector3(1.05,.08,1.50),.025)
   Furniture.rounded_block(stone,Vector3.UP*.12,Vector3(1.12,.24,1.64),.035)
  17183:
   parts.append(Cases.raw_shell(1.35,1.35,1.35,0,2))
   Furniture.rounded_block(stone,Vector3.UP*1.42,Vector3(1.49,.16,1.49),.035)
   Furniture.rounded_block(cap,Vector3.UP*1.50,Vector3(1.29,.08,1.29),.025)
  17528:
   parts.append(Cases.raw_shell(1.25,1.25,1.30,0,2))
   Furniture.rounded_block(cap,Vector3.UP*1.36,Vector3(1.43,.16,1.43),.035)
  _:assert(false,"Unprepared exact shop display")
 var tools=[];var materials=[]
 for entry in[[cap,Fort.material(Color("ad7846"),false)],[stone,Fort.material(Color("ccc6b0"),false)],[metal,Fort.material(Color("b9bfbc"),false)]]:
  var arrays:Array=entry[0].commit_to_arrays()
  if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array and not arrays[Mesh.ARRAY_VERTEX].is_empty():tools.append(entry[0]);materials.append(entry[1])
 if not tools.is_empty():parts.append(Furniture.finish(tools,materials))
 return East.combine(parts)
static func mesh(serial:int,graphic:Dictionary)->Mesh:
 assert(owns(serial),"Only source-confirmed display forms")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)]
 assert(g.source_rgba_sha256==graphic.rgba_sha256,"Regenerate exact native display references")
 var turn=PI*.5 if int(g.footprint[0])>int(g.footprint[1])else 0.
 if serial==16828:turn+=PI*.5
 var model=Reuse.fitted(raw(serial),g,turn)
 var skin=East.PreparedSkin.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(ROOT+str(serial)+"-front.png"),.045)
 for arrays:Array in model.get_meta("east_cpu_arrays"):
  var ids:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=ids is PackedInt32Array and not ids.is_empty()
  var count_:int=ids.size()if indexed else arrays[Mesh.ARRAY_VERTEX].size()
  for i in range(0,count_,3):
   var indices=[ids[i],ids[i+1],ids[i+2]]if indexed else[i,i+1,i+2]
   var normal:Vector3=(arrays[Mesh.ARRAY_NORMAL][indices[0]]+arrays[Mesh.ARRAY_NORMAL][indices[1]]+arrays[Mesh.ARRAY_NORMAL][indices[2]]).normalized()
   if normal.y<.45 and normal.dot(Vector3(-1,0,1))<.15:continue
   for index:int in indices:
    var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index];skin.projected_vertex(p+normal*.003,normal,p)
 var result=East.combine([model,skin.finish(true)])
 result.set_meta("east_native_display_furniture",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("inferred_hidden_construction",true)
 meshes[serial]=result;return result
