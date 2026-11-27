extends RefCounted
## Explicit Il-only candidate owner. No runtime caller or default publication.
const Caps=preload("res://scripts/forest/forest_east_bank_caps.gd")
static var catalogs:Dictionary={}

static func data(path:String)->Dictionary:
 if not catalogs.has(path):
  var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
  assert(int(source.source)==2000 and source.rows.size()==393 and int(source.counts.source_attribute_open)==389 and int(source.counts.source_blocked)==4,"Whole Il shore requires the exact393visual/389open/4blocked source contract")
  catalogs[path]=source
 return catalogs[path]

static func placements(path:String,frame:Transform2D=Transform2D.IDENTITY)->Array:
 var result=[]
 for source:Dictionary in data(path).rows:
  var row=source.duplicate(true);row.source_cell=Vector2i(source.source_cell[0],source.source_cell[1])
  row.anchor=frame*Vector2(source.anchor[0],source.anchor[1]);row.frame=Transform2D(frame.x,frame.y,Vector2.ZERO)
  result.append(row)
 return result

static func append_supports(terrain,rows:Array)->int:
 # Existing six proven strips remain owned; append the missing source-open cells once.
 var existing={}
 for piece:Dictionary in terrain.pieces:
  if piece.get("source_bank_cap",false) and piece.has("source_cell"):existing[piece.source_cell]=true
 var additions=[]
 for row:Dictionary in rows:
  if row.support_enabled and not existing.has(row.source_cell):additions.append(row);existing[row.source_cell]=true
 var start=terrain.pieces.size();Caps.append_pieces(terrain,additions)
 for index in range(start,terrain.pieces.size()):terrain.pieces[index].il_whole_shore=true
 return additions.size()

static func build(root:Node3D,rows:Array):
 var supported=[];var blocked={}
 for row:Dictionary in rows:
  if row.support_enabled:supported.append(row)
  else:
   assert(not row.source_attribute_open and row.support_only_rects.is_empty() and row.join_rects.is_empty(),"Blocked source bank controls never receive new physical support")
   if not blocked.has(int(row.serial)):blocked[int(row.serial)]=[]
   blocked[int(row.serial)].append(row)
 Caps.build(root,supported)
 # Blocked native drawings still have complete visual depth, without new floors.
 for serial:int in blocked:
  var instance=MultiMeshInstance3D.new();instance.name="NativeBlockedSourceBankCap_"+str(serial)
  instance.multimesh=MultiMesh.new();instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D;instance.multimesh.mesh=Caps.mesh(serial,4.)
  instance.multimesh.instance_count=blocked[serial].size()
  for index in blocked[serial].size():
   var row:Dictionary=blocked[serial][index];var frame:Transform2D=row.frame
   var basis=Basis(Vector3(frame.x.x,0,frame.x.y),Vector3.UP,Vector3(frame.y.x,0,frame.y.y))
   instance.multimesh.set_instance_transform(index,Transform3D(basis,Vector3(row.anchor.x,row.height,row.anchor.y)))
  instance.set_meta("source_graphic",serial);instance.set_meta("native_source_bank_cap",true);instance.set_meta("source_blocked_visual_only",true);root.add_child(instance)
