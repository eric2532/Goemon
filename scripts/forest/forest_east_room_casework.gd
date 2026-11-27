extends RefCounted
## Compatible complete furniture kits; native ornament stays on the observed faces.
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Reuse=preload("res://scripts/forest/forest_east_room_furniture.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const ROOT="res://assets/maps/falan/east_region/room_casework/"
const IDS=[10430,10431,10438,10440,10492,10567,16014,16016,16017,16020,16021,16023,16162,16169,17008,17010,17011,17542,17547]
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static func owns(serial:int)->bool:return serial in IDS
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func material()->Material:return Fort.material(Color("78492f"),false)
static func raw_shell(width:float,depth:float,height:float,drawers:int=0,doors:int=0)->Mesh:
 # Reuse the rounded furniture board primitive and its turned leg/rod pieces.
 var wood=Furniture.tool();var trim=Furniture.tool();var brass=Furniture.tool()
 Furniture.Parts.prepare_primitives()
 Furniture.rounded_block(wood,Vector3(0,height*.50,0),Vector3(width,height*.90,depth),.055)
 for y in [.11,height-.05]:Furniture.rounded_block(trim,Vector3(0,y,0),Vector3(width+.12,.16,depth+.12),.07)
 for row in drawers:
  var level=.24+(row+.5)*(height-.39)/drawers
  Furniture.Parts.block(trim,Vector3(-width*.505,level,0),Vector3(.08,(height-.39)/drawers-.05,depth*.87))
  Furniture.Parts.rod(brass,Vector3(-width*.56,level,-depth*.12),Vector3(-width*.56,level,depth*.12),.025)
 for door in doors:
  var z=(door+.5)*depth/doors-depth*.5
  Furniture.Parts.block(trim,Vector3(-width*.505,height*.5,z),Vector3(.08,height*.72,depth/doors-.10))
  Furniture.Parts.oval(brass,Vector3(-width*.56,height*.48,z+depth/doors*.23),Vector3(.07,.07,.07))
 for x in [-1,1]:
  for z in [-1,1]:Furniture.Parts.rod(wood,Vector3(x*width*.42,0,z*depth*.42),Vector3(x*width*.42,.24,z*depth*.42),.05)
 return Furniture.finish([wood,trim,brass],[material(),Fort.material(Color("a16b43"),false),Fort.material(Color("aa8c4d"),false)])
static func shelf(rows:int,hutch:bool)->Mesh:
 var parts=[];var original=Furniture.cabinet(2.,4.,false) if hutch else Reuse.bookcase_shell()
 # The complete cabinet supplies the side boards, base doors and cap. Bottles
 # from its original service are omitted; source contents are bounded flat art.
 for slot in mini(2,original.get_surface_count()):
  var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(original.surface_get_primitive_type(slot),original.surface_get_arrays(slot));mesh.surface_set_material(0,original.surface_get_material(slot));parts.append(mesh)
 if not hutch:
  var boards=Furniture.tool()
  for row in range(1,rows+1):Furniture.Parts.block(boards,Vector3(0,.18+row*3.45/(rows+1),0),Vector3(.96,.08,4.5))
  var mesh=boards.commit();mesh.surface_set_material(0,Fort.material(Color("a57249"),false));parts.append(mesh)
 return East.combine(parts)
static func raw(serial:int,g:Dictionary)->Mesh:
 match g.role:
  "closed_wardrobe":
   var base=raw_shell(1.05,2.5,3.7,0,2)
   if serial==16023:
    var crown=PackedVector2Array([Vector2(-1.25,3.55),Vector2(1.25,3.55),Vector2(1.25,4.),Vector2(.92,3.85),Vector2(.70,3.91),Vector2(0,4.2),Vector2(-.70,3.91),Vector2(-.92,3.85),Vector2(-1.25,4.)])
    var shape=Furniture.Shapes.extrude(crown,.15);shape=East.transformed_existing(shape,Transform3D(Basis(Vector3.UP,-PI*.5),Vector3(-.5,0,0)),material());base=East.combine([base,shape])
   return base
  "low_cabinet":return raw_shell(1.1,3.8,2.2,2,3)
  "narrow_drawers":return raw_shell(.70,.87,3.8,5)
  "arched_drawers":return raw_shell(1.0,2.2,3.4,4)
  "covered_side_cabinet":return raw_shell(1.45,2.7,2.7,0,2)
  "empty_shelf":return shelf(2 if serial==10438 else 4,false)
  "open_hutch","glass_hutch":return shelf(2,true)
  "wall_kitchen_unit":
   var base=raw_shell(.85,3.3,2.,2)
   var wall=Furniture.tool();Furniture.Parts.block(wall,Vector3(.18,3.65,0),Vector3(.22,3.5,3.3))
   var panel=wall.commit();panel.surface_set_material(0,Fort.material(Color("d5c49c"),false));return East.combine([base,panel])
  "dresser_mirror":
   var base=raw_shell(1.25,1.6,1.8,3);var frame=Furniture.tool();var glass=Furniture.tool()
   Furniture.Parts.block(frame,Vector3(.42,2.9,0),Vector3(.16,2.35,1.35))
   for side in [-1,1]:Furniture.Parts.rod(frame,Vector3(.42,1.75,side*.74),Vector3(.42,4.15,side*.74),.055)
   Furniture.Parts.block(glass,Vector3(.315,2.9,0),Vector3(.025,1.95,1.1))
   var timber=frame.commit();timber.surface_set_material(0,material());var reflection=glass.commit();reflection.surface_set_material(0,Fort.material(Color("4e747d"),false));return East.combine([base,timber,reflection])
 assert(false,"Unprepared native casework role "+g.role);return null
static func native_front(model:Mesh,serial:int,g:Dictionary)->Mesh:
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(ROOT+str(serial)+"-front.png"),.045)
 for slot in model.get_surface_count():
  var arrays:Array=model.get_meta("east_cpu_arrays")[slot] if model.has_meta("east_cpu_arrays") else model.surface_get_arrays(slot)
  var indices:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty();var count_:int=indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()
  for i in range(0,count_,3):
   var ids=[indices[i],indices[i+1],indices[i+2]] if indexed else [i,i+1,i+2]
   var n:Vector3=(arrays[Mesh.ARRAY_NORMAL][ids[0]]+arrays[Mesh.ARRAY_NORMAL][ids[1]]+arrays[Mesh.ARRAY_NORMAL][ids[2]]).normalized()
   if n.y<.45 and n.dot(Vector3(-1,0,1))<.15:continue
   for index:int in ids:
    var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index];front.projected_vertex(p+n*.003,n,p)
 return East.combine([model,front.finish()])
static func mesh(serial:int,graphic:Dictionary)->Mesh:
 assert(owns(serial),"Exact East casework scope")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)];assert(graphic.rgba_sha256==g.source_rgba_sha256,"Regenerate native casework evidence")
 if serial==10567:
  var clock:Mesh=load("res://scripts/forest/forest_east_mounted_details.gd").mesh(serial,graphic)
  clock.set_meta("east_native_casework",serial);meshes[serial]=clock;return clock
 var turn=PI*.5 if int(g.footprint[0])>int(g.footprint[1]) else 0.
 if g.role in ["open_hutch","glass_hutch","empty_shelf"]:turn=-PI*.5 if int(g.footprint[0])>int(g.footprint[1]) else PI
 if serial in [16017,16021,17010]:turn+=PI
 var result=Reuse.fitted(raw(serial,g),g,turn);result=native_front(result,serial,g)
 result.set_meta("east_native_casework",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("inferred_closed_reverse",true);meshes[serial]=result
 return result
