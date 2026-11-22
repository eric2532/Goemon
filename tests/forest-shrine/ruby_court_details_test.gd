extends "res://tests/forest-shrine/ruby_curtains_armor_test.gd"
const DETAILS_REVIEW="res://build/Other Files/Asset Toolkit/Ruby Court Details/"
func review_folder()->String:return DETAILS_REVIEW
func triangle_count(mesh:Mesh)->int:
 var count_=0
 for surface in mesh.get_surface_count():
  var arrays:Array=mesh.surface_get_arrays(surface);var indices=arrays[Mesh.ARRAY_INDEX]
  count_+=(indices.size() if indices!=null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
 return count_
func check_east_il_road():
 await super.check_east_il_road()
 var saved=JSON.stringify(get_meta("falan_venture"))
 var props=game.world.find_child("ArchivedRubyProps",true,false)
 var ids=[16128,16129]
 var source=Tour.Indoor.RoomArt.RubyProps.PLACEMENTS[Ruby.ROOM].filter(func(row):return row[1] in ids)
 var models=props.get_children().filter(func(node):return node.get_meta("blue_cg_serial",0) in ids)
 check(source.size()==8 and models.size()==source.size(),"All eight original small vase pedestals now use solid source-carved scenery")
 var meshes={};var counts={};var total=0
 for node in models:
  var serial:int=node.get_meta("blue_cg_serial")
  check(node is MeshInstance3D and source.any(func(row):return row[0]==node.get_meta("source_cell") and row[1]==serial),"Every vase pedestal retains its exact native map cell")
  check(node.find_children("*","Sprite3D",true,false).is_empty() and node.find_children("*","CollisionObject3D",true,false).is_empty(),"Solid vases and carved stands add no sprite or collision owner")
  var box:AABB=node.transform*node.mesh.get_aabb()
  check(box.position.x>=node.position.x-1.5 and box.end.x<=node.position.x+1.5 and box.position.z>=node.position.z-1.5 and box.end.z<=node.position.z+1.5 and box.position.y>=0 and box.end.y<=3.4,"Small carved pedestals fit their original blocked cells and source height")
  check(node.material_override==null and node.mesh.get_surface_count()==2 and node.mesh.surface_get_material(1)==Art.court_carving_paint,"Carved gilt and blue ceramics retain their separate prepared surfaces")
  if meshes.has(serial):check(node.mesh==meshes[serial],"Repeated carved vase stands share one mesh per source variant")
  meshes[serial]=node.mesh;counts[str(serial)]=triangle_count(node.mesh);total+=triangle_count(node.mesh)
 for serial in [16465,16466]:
  var mesh:Mesh=Art.scenery_meshes[["court",serial]]
  check(mesh.get_surface_count()==3 and mesh.surface_get_material(2)==Art.court_carving_paint,"Each curtain uses native embossed frieze paint on its curved solid header")
  var points:PackedVector3Array=mesh.surface_get_arrays(2)[Mesh.ARRAY_VERTEX];var depths=[]
  for p in points:
   var u=p.x/5.55+.5;var offset=p.y-Art.curtain_crown(serial,u)
   check(offset>=-1.051 and offset<=.001,"The frieze relief follows the source-specific curved cornice")
   depths.append(p.z)
  check(depths.min()>=.879 and depths.max()<=.966 and depths.max()-depths.min()>.005,"Native pale strokes produce bounded real depth on both curtain carvings")
 check(Art.armor_paint!=Art.SourceMesh.material(Art.SceneryAtlas,true) and Art.SourceMesh.material(Art.SceneryAtlas,true).get_shader_parameter("original_palette"),"Statue lighting is isolated from shared native scenery paint")
 for serial in [16193,16196]:
  var mesh:Mesh=Art.scenery_meshes[["court",serial]]
  check(mesh.get_surface_count()==4 and mesh.surface_get_material(0)==Art.armor_paint and mesh.surface_get_material(1)==Art.armor_materials.armor_edge and mesh.surface_get_material(2)==Art.armor_materials.armor_joint,"Solid armor keeps native plate paint, bright ridges and dark articulated seams separate")
  counts[str(serial)]=triangle_count(mesh)
 for serial in [16465,16466]:counts[str(serial)]=triangle_count(Art.scenery_meshes[["court",serial]])
 var temporary=Node3D.new();game.world.add_child(temporary)
 var materials=Art.armor_materials.duplicate();var reliefs=Art.carving_meshes.duplicate()
 for pass_ in 3:
  for serial in ids:
   var node=Art.furniture(temporary,Vector2i.ZERO,Vector2.ZERO,Vector2i.ONE,serial)
   check(node.mesh==meshes[serial] and node.mesh.get_surface_count()==2 and triangle_count(node.mesh)==counts[str(serial)],"Repeated room setup never appends another relief to the cached pedestal mesh")
   node.queue_free()
  for serial in [16193,16196,16465,16466]:Art.court_prop(temporary,Vector2i.ZERO,Vector2.ZERO,serial).queue_free()
  await process_frame
 for part in materials:check(materials[part]==Art.armor_materials[part],"Statue materials remain shared across repeated setups")
 for feature in reliefs:check(reliefs[feature]==Art.carving_meshes[feature],"Native relief meshes remain immutable across repeated setups")
 temporary.queue_free()
 if DisplayServer.get_name()!="headless":
  var gallery=Node3D.new();gallery.position=Vector3(2000,0,2000)*game.model.falan_scale;gallery.scale=Vector3.ONE*game.model.falan_scale;game.world.add_child(gallery)
  for serial in ids:
   var copy=models.filter(func(node):return node.get_meta("blue_cg_serial")==serial)[0].duplicate();copy.position=Vector3.ZERO;gallery.add_child(copy)
   await shot("carved-pedestal-"+str(serial),gallery.to_global(Vector3(3 if serial==16128 else -3,2.2,4)),gallery.to_global(Vector3(0,1.4,0)),54)
   copy.queue_free();await process_frame
  gallery.queue_free();await process_frame
  var original=models.filter(func(node):return node.get_meta("source_cell")==Vector2i(41,12))[0]
  await shot("pedestals-original-hall",original.to_global(Vector3(-6,4,7)),original.to_global(Vector3(0,1.7,-4)),70)
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Recovered court details preserve the user's saved adventure")
 print("RUBY_COURT_DETAILS_RESULT ",JSON.stringify({"pedestals":models.size(),"pedestal_placed_triangles":total,"triangles":counts,"checks":checks,"failures":errors}))
