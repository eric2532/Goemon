extends "res://tests/forest-shrine/falan_interiors_test.gd"
const OFFICE_REVIEW="res://build/Other Files/Asset Toolkit/Falan Office Interiors/"
func review_folder()->String:return OFFICE_REVIEW
func interior_rooms()->Array:return [1091,1092]
func detail_serials()->Array:return [17573,17587,17539,17572,17027,17028,17013]
func expected_art(id:int)->Array:return ["office_notice","office_door_crown"] if id==1091 else ["guild_notice"]
func furniture_details(id:int)->Array:
 var rows=Tour.Indoor.RoomArt.Data.EMPLOYMENT_DETAILS if id==1091 else Tour.Indoor.RoomArt.Data.GUILD_DETAILS
 return rows.filter(func(row):return row[1] in [17532,17534,17559])
func detail_eye(serial:int,row:Array)->Vector3:
 if serial in [17573,17587,17013]:return Basis(Vector3.UP,-PI*.5 if row[1].x>row[1].y else 0.0)*Vector3(6,4.5,0)
 return Vector3(6,5,8)

func check_room_furniture(id:int):
 super.check_room_furniture(id)
 for node in game.world.find_children("*","MeshInstance3D",true,false):
  if not node.has_meta("falan_interior_serial"):continue
  var family:String=node.get_meta("falan_furniture_family")
  var faces:PackedVector3Array=node.mesh.get_faces()
  check(faces.size()>0 and Array(faces).all(func(p):return p.is_finite()),"Prepared furniture has finite referenced triangles")
  if family=="chair":
   var area=0.0
   for i in range(0,faces.size(),3):
    if minf(faces[i].y,minf(faces[i+1].y,faces[i+2].y))>1.20:
     area+=(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length()*.5
   check(area>2.0,"Curved solid chair back is referenced by the rendered triangles")
   var facing=node.basis*Vector3.LEFT
   var target_serial=17539 if node.get_meta("falan_interior_serial")==17027 else 17572
   var row:Array=Tour.Indoor.RoomArt.Data.FIXTURES[id].filter(func(fixture):return fixture[3]==target_serial)[0]
   var info:Array=Tour.Indoor.floor_info(id)
   var at:Vector2=info[1]+(Vector2(row[0])+Vector2(row[1]-Vector2i.ONE)*.5)*3
   var desk_position=Vector3(at.x,0,at.y)
   check(facing.dot((desk_position-node.position).normalized())>.8,"Tall chair faces its original writing desk")
  if family=="desk":
   var rim=0
   for point in faces:
    if point.y>1.48 and point.y<1.58:rim+=1
   check(rim>250,"Rounded desk top is referenced by the rendered triangles")

func extra_detail_shots(id:int):
 var captured={}
 for node in game.world.find_children("*","MeshInstance3D",true,false):
  if not node.has_meta("falan_interior_serial"):continue
  var family:String=node.get_meta("falan_furniture_family")
  if family not in ["stool","bench","door"] or captured.has(family):continue
  if id==1091 and family=="stool" and node.position.z>0:continue
  captured[family]=true
  var target=Vector3(0,1.9,-1.45) if family=="door" else Vector3.UP*.6
  var eye=Vector3(0,1,5.8) if family=="door" else Vector3(3,2,4)
  await shot("detail-%d-"%id+family,node.to_global(target+eye),node.to_global(target),48)
