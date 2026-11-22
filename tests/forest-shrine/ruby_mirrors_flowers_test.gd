extends "res://tests/forest-shrine/ruby_court_details_test.gd"
const FLOWER_REVIEW="res://build/Other Files/Asset Toolkit/Ruby Mirrors Flowers/"
func review_folder()->String:return FLOWER_REVIEW
func flower_sources()->Dictionary:
 var hashes={}
 for asset in ["flowers_coral","flowers_ivory","flowers_blue","leafy_shrub"]:
  hashes[asset]=[]
  for part in Art.Meadow.source(asset):hashes[asset].append(var_to_bytes(part.mesh.surface_get_arrays(0)).hex_encode().sha256_text())
 return hashes
func check_east_il_road():
 var originals=flower_sources()
 await super.check_east_il_road()
 var props=game.world.find_child("ArchivedRubyProps",true,false)
 var ids=[16218,16219,16223,16232]
 var source=Tour.Indoor.RoomArt.RubyProps.PLACEMENTS[Ruby.ROOM].filter(func(row):return row[1] in ids)
 var models=props.get_children().filter(func(node):return node.get_meta("blue_cg_serial",0) in ids)
 check(models.size()==10 and models.size()==source.size(),"The remaining dressing mirror and all nine source flower arrangements use solid scenery")
 var shared={};var counts={};var placed=0
 for node in models:
  var serial:int=node.get_meta("blue_cg_serial")
  check(node is MeshInstance3D and source.any(func(row):return row[0]==node.get_meta("source_cell") and row[1]==serial),"The native mirror/arrangement remains in its original source cell")
  check(node.find_children("*","Sprite3D",true,false).is_empty() and node.find_children("*","CollisionObject3D",true,false).is_empty(),"Solid bouquets and mirror add no sprite or collision/gameplay owner")
  var span:Vector2i=Tour.Indoor.RoomArt.RubyProps.GRAPHICS[serial][1]
  var box:AABB=node.mesh.get_aabb()
  check(box.position.x>=-span.x*1.5 and box.end.x<=span.x*1.5 and box.position.z>=-span.y*1.5 and box.end.z<=span.y*1.5 and box.position.y>=-.001 and box.end.y<=8.5,"The complete mirror/flowers stay inside their original blocked footprint and ceiling")
  check(box.size.z>.5,"The recovered arrangements and mirror have real depth")
  if shared.has(serial):check(shared[serial]==node.mesh,"Repeated bouquets share one prepared complete mesh per source variant")
  shared[serial]=node.mesh
  var triangles=0
  for surface in node.mesh.get_surface_count():
   var arrays:Array=node.mesh.surface_get_arrays(surface);var indices=arrays[Mesh.ARRAY_INDEX]
   triangles+=(indices.size() if indices!=null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
  counts[str(serial)]=triangles;placed+=triangles
  if serial==16223:
   check(node.mesh.get_surface_count()==4 and node.mesh.surface_get_material(1)==Art.court_carving_paint,"The dressing mirror reuses native carved cabinet relief and two independent bouquet assemblies")
   var arrays:Array=node.mesh.surface_get_arrays(0);var glass=0
   for i in arrays[Mesh.ARRAY_VERTEX].size():
    if arrays[Mesh.ARRAY_TEX_UV2][i]!=Art.Scenery.TILES.mirror_glass:continue
    check(is_equal_approx(arrays[Mesh.ARRAY_VERTEX][i].z,-.315),"The original painted mirror reflection stays planar above its solid back")
    glass+=1
   check(glass>0,"Original native glass paint remains on the mirror")
   for surface in [2,3]:
    var roots:PackedVector3Array=node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
    var x=-1.58 if surface==2 else 1.58
    check(Array(roots).any(func(p):return absf(p.y-1.98)<.001 and Vector2(p.x-x,p.z-.10).length()<.16),"Each attached bouquet's stems meet its vase mouth")
  else:
   check(node.mesh.get_surface_count()==2,"Each native arrangement shares its solid pot and whole reused flower clusters")
   var arrays:Array=node.mesh.surface_get_arrays(1)
   check(arrays[Mesh.ARRAY_COLOR].size()==arrays[Mesh.ARRAY_VERTEX].size(),"Native petal/leaf palette is prepared on every reused flower vertex")
   var lip=.76 if serial==16218 else .78 if serial==16219 else .48
   check(Array(arrays[Mesh.ARRAY_VERTEX]).any(func(p):return absf(p.y-lip)<.001 and Vector2(p.x,p.z).length()<.16),"Prepared stems enter the native pot rather than floating above it")
 check(flower_sources()==originals,"Native bouquet recoloring preserves every source flower mesh array")
 check(Art.flower_material.cull_mode==BaseMaterial3D.CULL_DISABLED,"Thin original petals/leaves retain their source double-sided presentation")
 var parts=Art.flower_parts.duplicate();var empty=Node3D.new();game.world.add_child(empty)
 for pass_ in 3:
  for serial in ids:
   var copy=Art.floral_prop(empty,Vector2i.ZERO,Vector2.ZERO,serial)
   check(copy.mesh==shared[serial] and copy.mesh.get_surface_count()==(4 if serial==16223 else 2),"Repeated setup reuses complete floral meshes without appending surfaces")
   copy.queue_free()
  await process_frame
 for key in parts:check(parts[key]==Art.flower_parts[key],"Prepared native-colored flower parts remain shared across repeated room setup")
 empty.queue_free()
 if DisplayServer.get_name()!="headless":await capture_flowers(models)
 print("RUBY_MIRRORS_FLOWERS_RESULT ",JSON.stringify({"props":models.size(),"unique_meshes":shared.size(),"placed_triangles":placed,"triangles":counts,"checks":checks,"failures":errors}))
func capture_flowers(models:Array):
 var gallery=Node3D.new();gallery.position=Vector3(2000,0,2000)*game.model.falan_scale;gallery.scale=Vector3.ONE*game.model.falan_scale;game.world.add_child(gallery)
 for serial in [16218,16219,16232,16223]:
  var copy=models.filter(func(node):return node.get_meta("blue_cg_serial")==serial)[0].duplicate();copy.position=Vector3.ZERO;gallery.add_child(copy)
  var large=serial==16223
  await shot("recovered-"+str(serial),gallery.to_global(Vector3(4,4.5,8) if large else Vector3(3,2.5,4)),gallery.to_global(Vector3(0,3,0) if large else Vector3(0,1.3,0)),56)
  if large:await shot("mirror-side",gallery.to_global(Vector3(-5,3.6,7)),gallery.to_global(Vector3(0,2.7,0)),58)
  copy.queue_free();await process_frame
 gallery.queue_free();await process_frame
 var flowers=models.filter(func(node):return node.get_meta("source_cell")==Vector2i(42,29))[0]
 await shot("flowers-original-hall",flowers.to_global(Vector3(-5,4,8)),flowers.to_global(Vector3(-1,1.4,1)),72)
 var mirror=models.filter(func(node):return node.get_meta("blue_cg_serial")==16223)[0]
 await shot("mirror-original-room",mirror.to_global(Vector3(5,5,9)),mirror.to_global(Vector3(0,3,0)),72)
