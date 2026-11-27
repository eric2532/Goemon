extends RefCounted
## Original-source furniture. Maps explicitly enrolls only the11accepted forms.
const Goods=preload("res://scripts/forest/forest_falan_market_goods.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Reuse=preload("res://scripts/forest/forest_east_room_furniture.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const ROOT="res://assets/maps/falan/east_region/misc_furniture/"
const IDS=[10043,10044,10433,10497,11575,11576,11580,16818,16852,16853,16854,16855,16864,16865,16866]
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func owns(serial:int)->bool:return serial in IDS
static func place(stage:Node3D,mesh:Mesh,pose:Transform3D=Transform3D.IDENTITY):
 var node=MeshInstance3D.new();node.mesh=mesh;node.transform=pose;stage.add_child(node)
static func mailbox(serial:int)->Mesh:
 var post=Furniture.tool();var body=Furniture.tool();var seam=Furniture.tool()
 Furniture.Parts.rod(post,Vector3.ZERO,Vector3.UP*1.8,.055)
 # The existing mailbox's post/body proportions are retained. The missing
 # rounded housing is one closed arch made with the existing extrusion tool.
 var outline=PackedVector2Array([Vector2(-.4,1.5),Vector2(.4,1.5),Vector2(.4,1.91)])
 for i in range(1,17):
  var angle=i*PI/16.;outline.append(Vector2(cos(angle)*.4,1.91+sin(angle)*.34))
 var housing=Furniture.Shapes.extrude(outline,.9)
 body.append_from(housing,0,Transform3D.IDENTITY)
 Furniture.Parts.block(seam,Vector3(0,1.76,.46),Vector3(.34,.035,.035))
 var paint=Color("629267")if serial==11580 else Color("b5381e")
 return Furniture.finish([post,body,seam],[Fort.material(paint.darkened(.15),false),Fort.material(paint,false),Fort.material(Color("5a4231"),false)])
static func raw(serial:int,g:Dictionary)->Mesh:
 Furniture.Parts.prepare_primitives()
 var stage=Node3D.new();var boxes=Boxes.new()
 var wood=Fort.material(Color("88643e"),false);var cut=Fort.material(Color("b98c51"),false)
 match g.role:
  "wheelbarrow":
   var flowers=[]
   Goods.flower_cart(stage,boxes,Vector3.ZERO,serial==10043,wood,cut,Fort.material(Color("5a6054"),false),flowers)
   # The complete cart is reusable, but its old low flower strip misses this
   # drawing's tall planted basket. Add only that missing tapered container.
   var pot=CylinderMesh.new();pot.top_radius=.43;pot.bottom_radius=.30;pot.height=.68;pot.radial_segments=24
   var planting=Furniture.tool();planting.append_from(pot,0,Transform3D(Basis.IDENTITY,Vector3.UP*1.22))
   var basket=planting.commit();basket.surface_set_material(0,wood);place(stage,basket)
   for index in flowers.size():flowers[index].origin.y+=.66
   Assets.batch(stage,"flowers_coral",flowers)
  "open_crate","open_wicker_crate":
   Goods.crate(stage,boxes,Vector3.ZERO,1.8,false,wood,cut)
   if serial in[10433,10497]:
    # Keep the master's floor/posts/open top; these two originals have close
    # side boards rather than the wicker crate's widely spaced open rails.
    for side in[-1,1]:
     for level in[.33,.57]:
      boxes.add(Vector3(0,1.8*level,side*1.8*.49),Vector3(1.8,.252,.086),cut)
      boxes.add(Vector3(side*1.8*.49,1.8*level,0),Vector3(.086,.252,1.8),cut)
  "mailbox":place(stage,mailbox(serial))
  "display_plinth":
   var cloth=Furniture.tool()
   Furniture.rounded_block(cloth,Vector3.UP*.95,Vector3(1.8,1.9,2.8 if serial in[16855,16866]else 1.8),.025)
   var mesh=cloth.commit();mesh.surface_set_material(0,Fort.material(Color("eee8ce"),false));place(stage,mesh)
  _:assert(false,"Unprepared private furniture "+str(serial))
 boxes.build(stage,true);var result=East.reusable_node_mesh(stage);stage.free();return result
static func mesh(serial:int,graphic:Dictionary)->Mesh:
 assert(owns(serial),"Only the fifteen prepared furniture forms")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)]
 assert(graphic.rgba_sha256==g.source_rgba_sha256,"Regenerate exact native furniture references")
 var turn=PI*.5 if int(g.footprint[0])>int(g.footprint[1])else 0.
 if serial in[11576,11580]:turn+=PI*.5
 var model=Reuse.fitted(raw(serial,g),g,turn)
 var texture:Texture2D=load(ROOT+str(serial)+"-front.png");assert(texture!=null,"Import prepared furniture references before construction")
 var skin=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,.045)
 for slot in model.get_surface_count():
  var arrays:Array=model.get_meta("east_cpu_arrays")[slot]
  var indices:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty()
  var count_:int=indices.size()if indexed else arrays[Mesh.ARRAY_VERTEX].size()
  for i in range(0,count_,3):
   var ids=[indices[i],indices[i+1],indices[i+2]]if indexed else[i,i+1,i+2]
   var n:Vector3=(arrays[Mesh.ARRAY_NORMAL][ids[0]]+arrays[Mesh.ARRAY_NORMAL][ids[1]]+arrays[Mesh.ARRAY_NORMAL][ids[2]]).normalized()
   if n.y<.45 and n.dot(Vector3(-1,0,1))<.2:continue
   for index:int in ids:
    var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index];skin.projected_vertex(p+n*.003,n,p)
 var result=East.combine([model,skin.finish()]);result.set_meta("east_native_misc_furniture",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("inferred_hidden_construction",true)
 meshes[serial]=result;return result
