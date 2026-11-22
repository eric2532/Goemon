extends "res://tests/forest-shrine/falan_landmarks_test.gd"
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const INTERIOR_REVIEW="res://build/Other Files/Asset Toolkit/Falan Interiors/"
func interior_rooms()->Array:return [1101,1111,1112,1121]
func detail_serials()->Array:return [17012,17537,17541]
func furniture_details(id:int)->Array:return Tour.Indoor.RoomArt.Data.BANK_DETAILS.filter(func(row):return row[1]==17533) if id==1121 else []
func expected_art(id:int)->Array:return ["clock_10436","inn_notice"] if id==1101 else ["clock_10495"] if id==1121 else []
func detail_eye(serial:int,row:Array)->Vector3:
 if serial in [17012,17541]:return Basis(Vector3.UP,-PI*.5 if row[1].x>row[1].y else 0.0)*Vector3(6,4.5,0)
 return Vector3(6,5,8)
func review_folder()->String:return INTERIOR_REVIEW

func extra_detail_shots(_id:int):pass

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var before="--baseline" in OS.get_cmdline_user_args()
 var saved=JSON.stringify(get_meta("falan_venture"))
 var signatures={}
 var prepared={}
 for id in interior_rooms():
  await room(id)
  if Tour.area(game.model)!="interior" or game.model.falan_floor!=id:return
  signatures[str(id)]=[var_to_str(game.model.scenery_obstacles).sha256_text(),var_to_str(game.model.get_meta("cave_combat_walls",[])).sha256_text(),Tour.Indoor.floor_info(id)[2]]
  var collision_rows=[]
  for body in game.world.map_features.find_children("*","StaticBody3D",true,false):
   for shape_node in body.find_children("*","CollisionShape3D",true,false):
    if shape_node.shape!=null:collision_rows.append(var_to_str([body.collision_layer,body.collision_mask,shape_node.global_transform,shape_node.shape.get_class(),shape_node.shape.get_debug_mesh().get_aabb()]))
  collision_rows.sort();signatures[str(id)].append(var_to_str(collision_rows).sha256_text())
  var info:Array=Tour.Indoor.floor_info(id)
  var center:Vector2=info[1]+Vector2(info[0]-Vector2i.ONE)*1.5
  var scale_:float=game.model.falan_scale
  var floor_node=game.world.find_child("ArchivedRoomFloor",true,false)
  var bounds:AABB=floor_node.get_aabb()
  var focus:Vector3=floor_node.to_global(bounds.get_center())+Vector3.UP*scale_
  var extent=maxf(bounds.size.x,bounds.size.z)
  await shot("room-"+str(id),focus+Vector3(.50,.65,.80)*extent*scale_,focus,56)
  var selected=Tour.Indoor.RoomArt.Data.FIXTURES.get(id,[]).filter(func(row):return row[3] in detail_serials())
  for serial in detail_serials():
   var fixtures=selected.filter(func(row):return row[3]==serial)
   if fixtures.is_empty():continue
   var row:Array=fixtures[0]
   var at:Vector2=info[1]+(Vector2(row[0])+Vector2(row[1]-Vector2i.ONE)*.5)*3
   var p=floor_node.to_global(Vector3(at.x,1.4,at.y))
   await shot("detail-%d-%d"%[id,serial],p+detail_eye(serial,row)*scale_,p,48)
  print("FALAN_INTERIOR_SOURCE ",id," fixtures=",Tour.Indoor.RoomArt.Data.FIXTURES.get(id,[]).size())
  if not before:
   for panel in game.world.find_children("*","MeshInstance3D",true,false):
    if not panel.has_meta("falan_interior_art"):continue
    var label:String=panel.get_meta("falan_interior_art")
    var target=panel.global_position
    var eye=panel.global_basis.orthonormalized()*Vector3(0,.5,3.8)*scale_
    await shot("art-%d-"%id+label,target+eye,target,48)
   if id==1121:
    var seats=game.world.find_children("*","MeshInstance3D",true,false).filter(func(node):return node.has_meta("falan_interior_serial"))
    if not seats.is_empty():await shot("bank-waiting-seat",seats[0].to_global(Vector3(4,3,4)),seats[0].to_global(Vector3(0,.5,0)),48)
   await extra_detail_shots(id)
   check_room_furniture(id)
   for key in Furniture.meshes:prepared[key]=Furniture.meshes[key]
  var exits=game.model.get_meta("falan_links",[]).filter(func(link):return link.to=="city")
  check(not exits.is_empty(),"Interior retains its original Falan exit: "+str(id))
  if exits.is_empty():return
  var inside=game.model
  await position_at(exits[0].at)
  if game.model==inside:await walk_through_entry()
  check(Tour.area(game.model)=="city","Original exit returns from interior "+str(id))
  if Tour.area(game.model)!="city":return
 if before:
  var file=FileAccess.open(review_folder()+"collision-before.json",FileAccess.WRITE);file.store_string(JSON.stringify(signatures,"  "))
 else:check(signatures==JSON.parse_string(FileAccess.get_file_as_string(review_folder()+"collision-before.json")),"Every interior preserves its original collision and navigation mask")
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Interior recovery preserves the saved adventure")
 if not before:
  for key in prepared:check(is_same(Furniture.meshes[key],prepared[key]),"Room transitions reuse prepared furniture meshes")
 print("FALAN_INTERIORS_RESULT checks=",checks," failures=",errors)

func check_room_furniture(id:int):
 var source:Array=Tour.Indoor.RoomArt.Data.FIXTURES.get(id,[])
 var expected=source.filter(func(row):return Furniture.handles(id,row[3])).size()
 expected+=furniture_details(id).size()
 var nodes=game.world.find_children("*","MeshInstance3D",true,false).filter(func(node):return node.has_meta("falan_interior_serial"))
 check(nodes.size()==expected and not nodes.is_empty(),"All selected original furnishings are recovered in room "+str(id))
 var art=game.world.find_children("*","MeshInstance3D",true,false).filter(func(node):return node.has_meta("falan_interior_art"))
 var expected_art=expected_art(id)
 check(art.size()==expected_art.size(),"Selected rooms retain original dial and notice artwork")
 for node in art:
  var feature:String=node.get_meta("falan_interior_art")
  check(feature in expected_art and node.material_override==Furniture.detail_materials[feature],"Original interior artwork uses its prepared shared material")
  if feature=="clock_10436":check(node.global_basis.z.normalized().dot(Vector3.RIGHT)>.99,"The inn clock faces into the room, clear of the adjacent cabinet")
 var info:Array=Tour.Indoor.floor_info(id)
 var metrics=[]
 for node in nodes:
  var serial:int=node.get_meta("falan_interior_serial")
  var family:String=node.get_meta("falan_furniture_family")
  var key:Array=node.get_meta("falan_furniture_key")
  check(is_same(node.mesh,Furniture.meshes[key]),"Identical source furnishings share one prepared mesh")
  var matches=source.filter(func(row):return row[3]==serial and (info[1]+(Vector2(row[0])+Vector2(row[1]-Vector2i.ONE)*.5)*3).is_equal_approx(Vector2(node.position.x,node.position.z)))
  if matches.is_empty():
   check(furniture_details(id).any(func(row):return row[1]==serial and (info[1]+Vector2(row[0])*3).is_equal_approx(Vector2(node.position.x,node.position.z))),"Detail furnishing keeps its original source station")
  else:check(matches.size()==1,"Recovered furnishing keeps its exact source station")
  var bounds:AABB=node.mesh.get_aabb()
  check(bounds.position.y>=-.001 and bounds.end.y<=4.01,"Original furniture remains on the floor and below room walls")
  if not matches.is_empty():
   var count_:Vector2i=matches[0][1]
   var footprint=Vector2(mini(count_.x,count_.y),maxi(count_.x,count_.y))*3
   check(bounds.size.x<=footprint.x+.01 and bounds.size.z<=footprint.y+.01,"Recovered furniture remains inside its original blocked cells")
  var valid=true
  for surface in node.mesh.get_surface_count():
   for normal:Vector3 in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL]:
    if not normal.is_finite():valid=false
  check(valid,"Furniture normals remain finite")
  if family=="bed":
   var upward=true
   for normal:Vector3 in node.mesh.surface_get_arrays(2)[Mesh.ARRAY_NORMAL]:
    if normal.y<=0:upward=false
   check(upward,"Soft bed covers face upward rather than being culled")
  metrics.append({"serial":serial,"family":family,"triangles":node.mesh.get_faces().size()/3,"surfaces":node.mesh.get_surface_count(),"bounds":str(bounds)})
 var file=FileAccess.open(review_folder()+"room-%d-meshes.json"%id,FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "))
 print("FALAN_RECOVERED_INTERIOR ",id," objects=",nodes.size())
