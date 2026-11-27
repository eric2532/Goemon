extends RefCounted
## Source market furniture, explicitly enrolled by East OBJECT placements.
const Goods=preload("res://scripts/forest/forest_falan_market_goods.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Reuse=preload("res://scripts/forest/forest_east_room_furniture.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const ROOT="res://assets/maps/falan/east_region/market_goods/"
const IDS=[10053,10054,10056,10057,10098]
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static func owns(serial:int)->bool:return serial in IDS
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func raw(serial:int,g:Dictionary)->Mesh:
 var stage=Node3D.new();var boxes=Boxes.new();var wood=Fort.material(Color("88613d"),false);var edge=Fort.material(Color("bd925c"),false)
 var food_material=Fort.material(Color("695437"),false);var sign_material=Fort.material(Color("b98f59"),false)
 if serial==10098:
  # The complete open crate supplies ventilated walls; preserve the holes rather
  # than filling them with the closed-crate master's solid center.
  Goods.crate(stage,boxes,Vector3.ZERO,1.8,false,wood,edge)
  for i in 6:boxes.add(Vector3((i-2.5)*.28,1.65,0),Vector3(.19,.12,1.82),edge)
 else:
  Goods.produce(stage,boxes,Vector3.ZERO,10056 if serial in[10056,10057]else 10053,wood,edge)
  # The original whole stand's fruit is a different assortment. Keep its frame;
  # the exact original food drawings sit on the four bounded product beds.
  for child in stage.get_children():child.free()
  var turned=serial in[10056,10057]
  var beds=Furniture.tool()
  for i in 4:
   var x=-.75 if i%2==0 else .75;var z=-.60 if i<2 else .60;var h=.97 if i<2 else .72
   var center=Vector3(z,h+.02,x)if turned else Vector3(x,h+.02,z)
   var dx=Vector3.FORWARD*.60 if turned else Vector3.RIGHT*.60;var dz=Vector3.RIGHT*.46 if turned else Vector3.FORWARD*.46
   var points=[center-dx-dz,center+dx-dz,center+dx+dz,center-dx+dz]
   if (points[2]-points[0]).cross(points[1]-points[0]).y<0.:points.reverse()
   Furniture.Shapes.quad(beds,points[0],points[1],points[2],points[3])
  var bed_mesh=beds.commit();bed_mesh.surface_set_material(0,food_material);var bed_node=MeshInstance3D.new();bed_node.mesh=bed_mesh;stage.add_child(bed_node)
  var high=1.8 if g.role=="produce_stand"else 1.95
  for x in([0.]if g.role=="produce_stand"else[-1.25,1.25]):boxes.add(Vector3(-.95,high*.5,x)if turned else Vector3(x,high*.5,-.95),Vector3(.07,high,.07),wood)
  var board_size=Vector3(.85,.28,.08)if g.role=="produce_stand"else Vector3(2.6,.72,.08)
  boxes.add(Vector3(-.95,high-.12,0)if turned else Vector3(0,high-.12,-.95),Vector3(board_size.z,board_size.y,board_size.x)if turned else board_size,sign_material)
 boxes.build(stage,true);var result=East.reusable_node_mesh(stage);stage.free()
 var paint_slots=[]
 for slot in result.get_surface_count():
  if serial==10098 or result.surface_get_material(slot)in[food_material,sign_material]:paint_slots.append(slot)
 assert(not paint_slots.is_empty() and (serial==10098 or paint_slots.size()<result.get_surface_count()),"Product paint must stay separate from timber frame parts")
 result.set_meta("native_product_paint_slots",paint_slots);return result
static func mesh(serial:int,graphic:Dictionary)->Mesh:
 assert(owns(serial),"Exact five native market forms")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)];assert(g.source_rgba_sha256==graphic.rgba_sha256,"Regenerate exact native market binding")
 var raw_model=raw(serial,g);var paint_slots:Array=raw_model.get_meta("native_product_paint_slots")
 var result=Reuse.fitted(raw_model,g)
 var texture:Texture2D=load(ROOT+str(serial)+"-front.png");assert(texture!=null,"Import prepared native market references")
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,.045)
 for slot in result.get_surface_count():
  # Keep vegetables/fish on product beds and signs, never down the timber legs.
  if slot not in paint_slots:continue
  var arrays:Array=result.get_meta("east_cpu_arrays")[slot];var indices:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty();var count_:int=indices.size()if indexed else arrays[Mesh.ARRAY_VERTEX].size()
  for i in range(0,count_,3):
   var ids=[indices[i],indices[i+1],indices[i+2]]if indexed else[i,i+1,i+2];var n:Vector3=arrays[Mesh.ARRAY_NORMAL][ids[0]]
   if n.y<.4 and n.dot(Vector3(-1,0,1))<.15:continue
   for index:int in ids:
    var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index];front.projected_vertex(p+n*.004,n,p)
 result=East.combine([result,front.finish()]);result.set_meta("east_native_market",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("inferred_hidden_geometry",true);meshes[serial]=result;return result
