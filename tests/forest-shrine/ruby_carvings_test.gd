extends "res://tests/forest-shrine/ruby_holy_shield_test.gd"
const CARVING_REVIEW="res://build/Other Files/Asset Toolkit/Ruby Carvings/"
const Art=preload("res://scripts/forest/forest_black_prayer_art.gd")
func review_folder()->String:return CARVING_REVIEW
func mesh_bounds(node:Node3D,pose:Transform3D=Transform3D.IDENTITY)->Array:
 pose=pose*node.transform
 var boxes=[]
 if node is MeshInstance3D:boxes.append(pose*node.mesh.get_aabb())
 for child in node.get_children():
  if child is Node3D:boxes.append_array(mesh_bounds(child,pose))
 return boxes
func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var saved=JSON.stringify(get_meta("falan_venture"))
 await approach_black_prayer();await room(Tour.Prayer.ENTRY)
 for id:int in Tour.Prayer.FLOORS:await room(id)
 await room(Ruby.ROOM)
 await check_ruby_furniture()
 var props=game.world.find_child("ArchivedRubyProps",true,false)
 var source=Tour.Indoor.RoomArt.RubyProps.PLACEMENTS[Ruby.ROOM]
 var ornaments=props.get_children().filter(func(node):return node.get_meta("blue_cg_serial",0) in [16137,17680])
 check(ornaments.size()==13,"Twelve original tripod ornaments and the arched mirror use solid source-painted scenery")
 for node in ornaments:
  var serial:int=node.get_meta("blue_cg_serial")
  check(source.any(func(row):return row[0]==node.get_meta("source_cell") and row[1]==serial),"The recovered ornament keeps its exact source cell")
  check(node.find_children("*","CollisionObject3D",true,false).is_empty(),"Decorative geometry adds no new collision or gameplay owner")
 var carvings=props.find_children("*","MeshInstance3D",true,false).filter(func(node):return node.has_meta("ruby_carving"))
 check(carvings.size()==24,"Nine carved chair backs, two cabinets, twelve plates and one mirror retain native paint")
 var shared={}
 for node in carvings:
  var feature:String=node.get_meta("ruby_carving")
  if shared.has(feature):check(node.mesh==shared[feature],"All repeated native carvings share one relief mesh")
  shared[feature]=node.mesh
  check(node.material_override==Art.SourceMesh.material(Art.Carved.ATLAS),"Native carving paint shares the prepared immutable material")
  var aabb:AABB=node.mesh.get_aabb()
  check(aabb.size.z>.001 and aabb.size.z<=Art.Carved.FEATURES[feature][1]+.001,"Carved depth follows the bounded source-derived relief")
 for node in props.get_children():
  var serial:int=node.get_meta("blue_cg_serial",0)
  if serial not in [16115,16124,16140,16137,17680]:continue
  var span:Vector2i=Tour.Indoor.RoomArt.RubyProps.GRAPHICS[serial][1]
  var limits=Rect2(Vector2(node.position.x,node.position.z)-Vector2(span)*1.5,Vector2(span)*3)
  for box:AABB in mesh_bounds(node):
   check(box.position.x>=limits.position.x-.01 and box.end.x<=limits.end.x+.01 and box.position.z>=limits.position.y-.01 and box.end.z<=limits.end.y+.01,"Carvings and all assembled parts stay in their original blocked cells")
   check(box.position.y>=-.02 and box.end.y<=8.51,"New ornament silhouettes fit the source room ceiling")
 var mirror_rect:Rect2i=Art.Carved.FEATURES.arched_mirror[0]
 var glass=mirror_rect.position+Vector2i(mirror_rect.size.x/2,mirror_rect.size.y*3/5)
 check(Art.Carved.DEPTH.get_image().get_pixelv(glass).r==0,"The mirror's painted reflection stays flat while its frame is carved")
 var empty=Node3D.new();game.world.add_child(empty)
 var chair=Art.Interior.chair()
 var triangles=0
 for surface in chair.get_surface_count():
  var arrays:Array=chair.surface_get_arrays(surface)
  triangles+=(arrays[Mesh.ARRAY_INDEX].size() if not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
 check(triangles==1340,"The original plain chair geometry remains available unchanged")
 var before=Art.carving_meshes.duplicate();var bodies=Art.silhouettes.duplicate()
 for pass_ in 3:
  for serial in [16137,17680]:
   var copy=Art.ornament(empty,Vector2i.ZERO,Vector2.ZERO,serial);copy.queue_free()
  for frame in 2:await process_frame
 for key in before:check(before[key]==Art.carving_meshes[key],"Repeated setup reuses existing carved meshes")
 for key in bodies:check(bodies[key]==Art.silhouettes[key],"Repeated setup reuses original silhouette meshes")
 empty.queue_free()
 if DisplayServer.get_name()!="headless":await capture_carvings(props,ornaments)
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Furniture carving recovery preserves the user's saved adventure")
 print("RUBY_CARVINGS_RESULT carvings=",carvings.size()," ornaments=",ornaments.size()," checks=",checks," failures=",errors)
func capture_carvings(props:Node3D,ornaments:Array):
 var gallery=Node3D.new();gallery.position=Vector3(2000,0,2000)*game.model.falan_scale;gallery.scale=Vector3.ONE*game.model.falan_scale;game.world.add_child(gallery)
 for serial in [16124,16140,16137,17680]:
  var source=props.get_children().filter(func(node):return node.get_meta("blue_cg_serial",0)==serial)[0]
  var copy=source.duplicate();copy.position=Vector3.ZERO;gallery.add_child(copy)
  await shot("carved-"+str(serial),gallery.to_global(Vector3(4,3.5,6)),gallery.to_global(Vector3(0,2,0)),60)
  if serial==16124:await shot("chair-carving-side",gallery.to_global(Vector3(-3,2.6,4)),gallery.to_global(Vector3(0,2,0)),52)
  copy.queue_free();await process_frame
 gallery.queue_free();await process_frame
 var original=ornaments.filter(func(node):return node.get_meta("source_cell")==Vector2i(20,22))[0]
 await shot("tripods-source-hall",original.to_global(Vector3(10.5,5.5,18)),original.to_global(Vector3(10.5,2.0,4.5)),70)
 check(game.camera_rig.camera.is_position_in_frustum(original.to_global(Vector3(0,2.8,0))),"The original hall tripod is visible in the context capture")
