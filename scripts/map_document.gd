extends RefCounted
const Pieces=preload("res://scripts/map_pieces.gd")
const BOUNDS=Rect2(-80,50,160,310)
const MAX_PIECES=512
const MAX_FILE_BYTES=262144
var data: Dictionary={}
var history: Array=[]
var future: Array=[]
var saved_text=""
var file_path=""
var next_uid=1
var dirty: bool:
 get:return encode()!=saved_text

func _init():reset_blank()
func reset_blank():
 data={"schema":1,"title":"My Siege Map","pieces":[]};next_uid=1;file_path=""
 for marker in [["spawn",0,195],["enemy",0,110],["base",0,300]]:_append(marker[0],Vector3(marker[1],0,marker[2]),0)
 history.clear();future.clear();saved_text=encode()
func reset_template():
 reset_blank();data.title="Fire Siege Garden"
 for z in [170,230,260]:_append("waypoint",Vector3(0,0,z),0)
 for x in [-12,12]:
  for z in [116,130,144,158]:_append("tower",Vector3(x,0,z),0)
 for x in [-16,-9,9,16]:_append("tower",Vector3(x,0,234),0)
 for p in [Vector3(-18,0,189),Vector3(18,0,189),Vector3(-18,0,208),Vector3(-16,0,282)]:_append("mine",p,0)
 for side in [-1,1]:
  for x in [12,20,28,36,44,52,60]:_append("wall",Vector3(side*x,0,230),0)
  for z in [138,186,268]:_append("lantern",Vector3(side*23,0,z),0)
  for z in [120,155,195,280,326]:_append("cherry" if z%2==0 else "cedar",Vector3(side*48,0,z),0)
  _append("bamboo",Vector3(side*34,0,209),0)
  _append("banner",Vector3(side*23,0,235),0)
 _append("torii",Vector3(0,0,96),0)
 _append("pavilion",Vector3(29,0,307),0)
 _append("crates",Vector3(33,0,251),0)
 _append("rock",Vector3(-37,0,270),0)
 history.clear();future.clear();saved_text=encode()
func _record():
 history.append(data.duplicate(true));if history.size()>100:history.pop_front()
 future.clear()
func _append(kind: String,p: Vector3,rotation: int)->int:
 var uid=next_uid;next_uid+=1
 data.pieces.append({"uid":uid,"kind":kind,"x":p.x,"z":p.z,"rotation":posmod(rotation,360)})
 return uid
func item(uid: int)->Dictionary:
 for entry in data.pieces:
  if entry.uid==uid:return entry
 return {}
func find_kind(kind: String)->Array:return data.pieces.filter(func(entry):return entry.kind==kind)
func point(entry: Dictionary)->Vector3:return Vector3(entry.x,0,entry.z)
func place(kind: String,p: Vector3,rotation: int=0)->int:
 if not Pieces.CATALOG.has(kind) or not valid_point(p):return -1
 if kind in Pieces.SINGLETONS:
  var uid=int(find_kind(kind)[0].uid);move_item(uid,p);return uid
 if data.pieces.size()>=MAX_PIECES or (kind=="waypoint" and find_kind(kind).size()>=64):return -1
 _record();return _append(kind,p,rotation)
func valid_point(p: Vector3)->bool:return p.is_finite() and BOUNDS.grow(-2).has_point(Vector2(p.x,p.z))
func move_item(uid: int,p: Vector3)->bool:
 var entry=item(uid)
 if entry.is_empty() or not valid_point(p) or point(entry)==p:return false
 _record();entry.x=p.x;entry.z=p.z;return true
func rotate_item(uid: int)->bool:
 var entry=item(uid)
 if entry.is_empty():return false
 _record();entry.rotation=posmod(int(entry.rotation)+90,360);return true
func remove_item(uid: int)->bool:
 var entry=item(uid)
 if entry.is_empty() or entry.kind in Pieces.SINGLETONS:return false
 _record();data.pieces.erase(entry);return true
func duplicate_item(uid: int)->int:
 var entry=item(uid)
 if entry.is_empty() or entry.kind in Pieces.SINGLETONS:return -1
 return place(entry.kind,point(entry)+Vector3(4,0,4),entry.rotation)
func reorder_waypoint(uid: int,step: int)->bool:
 var points=find_kind("waypoint");var index=points.find(item(uid));var target=index+step
 if index<0 or target<0 or target>=points.size():return false
 var a=data.pieces.find(points[index]);var b=data.pieces.find(points[target]);_record()
 var temp=data.pieces[a];data.pieces[a]=data.pieces[b];data.pieces[b]=temp;return true
func rename(title: String):
 var value=title.strip_edges().left(48)
 if value.is_empty() or data.title==value:return
 _record();data.title=value
func undo()->bool:
 if history.is_empty():return false
 future.append(data.duplicate(true));data=history.pop_back();return true
func redo()->bool:
 if future.is_empty():return false
 history.append(data.duplicate(true));data=future.pop_back();return true
func route()->Array:
 var result=[point(find_kind("enemy")[0])]
 for entry in find_kind("waypoint"):result.append(point(entry))
 result.append(point(find_kind("base")[0]));return result
func encode()->String:return JSON.stringify(data)
func decode(source: String)->String:
 if source.to_utf8_buffer().size()>MAX_FILE_BYTES:return "Map file is too large."
 var parser=JSON.new()
 if parser.parse(source)!=OK:return "This file is not valid map JSON."
 var value=parser.data
 if not value is Dictionary or value.get("schema")!=1 or not value.get("title") is String or not value.get("pieces") is Array:return "Unsupported map format."
 if value.title.strip_edges().is_empty() or value.title.length()>48 or value.pieces.size()>MAX_PIECES:return "Map name or piece count is invalid."
 var ids={};var singles={};var next=1;var normalized=[];var waypoint_count=0
 for entry in value.pieces:
  if not entry is Dictionary:return "Invalid map piece."
  if not entry.get("kind") is String or not Pieces.CATALOG.has(entry.kind):return "Unknown map piece."
  for key in ["uid","x","z","rotation"]:
   if not (entry.get(key) is float or entry.get(key) is int) or not is_finite(float(entry[key])):return "Invalid piece coordinates."
  if entry.uid<1 or entry.uid>1000000000 or entry.uid!=floor(entry.uid) or ids.has(int(entry.uid)):return "Invalid or duplicate piece ID."
  if absf(entry.rotation)>360000 or entry.rotation!=floor(entry.rotation) or int(entry.rotation)%90!=0:return "Invalid piece rotation."
  if not valid_point(Vector3(entry.x,0,entry.z)):return "A piece is outside the map."
  ids[int(entry.uid)]=true;next=maxi(next,int(entry.uid)+1)
  if entry.kind in Pieces.SINGLETONS:
   if singles.has(entry.kind):return "Duplicate gameplay marker."
   singles[entry.kind]=true
  if entry.kind=="waypoint":waypoint_count+=1
  normalized.append({"uid":int(entry.uid),"kind":entry.kind,"x":float(entry.x),"z":float(entry.z),"rotation":posmod(int(entry.rotation),360)})
 if singles.size()!=3 or waypoint_count>64:return "Map needs one hero spawn, entrance and shrine, and at most 64 route points."
 data={"schema":1,"title":value.title,"pieces":normalized};next_uid=next
 history.clear();future.clear();saved_text=encode();return ""
func save(path: String)->Error:
 var folder=ProjectSettings.globalize_path(path.get_base_dir())
 var error=DirAccess.make_dir_recursive_absolute(folder)
 if error!=OK:return error
 var temporary=path+".tmp";var file=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:return FileAccess.get_open_error()
 file.store_string(encode());file.flush();error=file.get_error();file.close()
 if error!=OK:return error
 error=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
 if error==OK:saved_text=encode();file_path=path
 return error
func read_file(path: String)->String:
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null:return "Could not open this map."
 if file.get_length()>MAX_FILE_BYTES:return "Map file is too large."
 var error=decode(file.get_as_text())
 if error.is_empty():file_path=path
 return error
func obstacle_rects(entry: Dictionary)->Array:
 var rects=[];var angle=deg_to_rad(entry.rotation)
 for box in Pieces.collision_boxes(entry.kind):
  if box[0].y-box[1].y*.5>2:continue
  var center: Vector3=box[0].rotated(Vector3.UP,angle)+point(entry)
  var size: Vector3=box[1];var extent=Vector2(size.x,size.z)
  if int(entry.rotation)%180!=0:extent=Vector2(size.z,size.x)
  rects.append(Rect2(Vector2(center.x,center.z)-extent*.5,extent))
 return rects
func segment_crosses_rect(a: Vector2,b: Vector2,rect: Rect2)->bool:
 if rect.has_point(a) or rect.has_point(b):return true
 var corners=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
 for i in range(4):
  if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null:return true
 return false
func validate()->Array[String]:
 var errors: Array[String]=[];var path=route()
 if path[0].distance_to(path[-1])<30:errors.append("Move the enemy entrance at least 30m from the shrine.")
 for i in range(path.size()-1):
  if path[i].distance_to(path[i+1])<6:errors.append("Separate route points by at least 6m.");break
 if not BOUNDS.grow(-10).has_point(Vector2(path[0].x,path[0].z)):errors.append("Keep the enemy entrance at least 10m from the map edge.")
 for p in path:
  if not BOUNDS.grow(-7).has_point(Vector2(p.x,p.z)):errors.append("Keep the enemy route at least 7m from the map edge.");break
 var spawn=point(find_kind("spawn")[0])
 var spawn_points=[spawn]
 for side in [-1,1]:
  for slot in range(8):spawn_points.append(spawn+Vector3(side*5+(float(slot%4)-1.5)*1.8,0,float(slot/4)*2.7))
 for spawn_point in spawn_points:
  if not BOUNDS.grow(-3.5).has_point(Vector2(spawn_point.x,spawn_point.z)):
   errors.append("Move the hero spawn away from the map edge; leave room for allies.");break
 for entry in data.pieces:
  for rect in obstacle_rects(entry):
   if not BOUNDS.grow(-1).encloses(rect):errors.append(Pieces.CATALOG[entry.kind].name+" reaches beyond the map edge.");break
   var spawn_blocked=false
   for spawn_point in spawn_points:
    if rect.grow(1).has_point(Vector2(spawn_point.x,spawn_point.z)):spawn_blocked=true;break
   if spawn_blocked:errors.append("Move "+Pieces.CATALOG[entry.kind].name+" away from the hero and ally spawn area.");break
   var blocked=false
   for i in range(path.size()-1):
    if segment_crosses_rect(Vector2(path[i].x,path[i].z),Vector2(path[i+1].x,path[i+1].z),rect.grow(5.5)):
     errors.append("Move "+Pieces.CATALOG[entry.kind].name+" away from the enemy route (keep 6m clear).");blocked=true;break
   if blocked:break
 # Construction sites must not overlap other solids or sites.
 var sites=find_kind("tower")+find_kind("mine")
 for site in sites:
  var site_rects=obstacle_rects(site)
  for other in data.pieces:
   if other.uid==site.uid:continue
   var overlap=false
   for a in site_rects:
    for b in obstacle_rects(other):
     if a.grow(.6).intersects(b):overlap=true
   if overlap:errors.append("Give each tower and mine a clear footprint.");break
 return errors
