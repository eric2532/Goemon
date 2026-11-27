extends RefCounted
## Exact unknown-only Il supplement. Legacy Laruka/West and known Il rows stay owned.
const ROOT="res://assets/maps/falan/east_region/il_source_completion/"
const Caps=preload("res://scripts/forest/forest_east_bank_caps.gd")
static var catalog:Dictionary={}
static var native_bits=PackedByteArray()

static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog

static func rows(source_id:int,existing:Array)->Array:
 if source_id!=2000:return existing
 var source_rows=existing.duplicate();var anchors={}
 for row:Array in existing:anchors[Vector2i(row[0],row[1])]=int(row[2])
 for row:Array in data().additional_scenery_rows:
  var cell=Vector2i(row[0],row[1])
  assert(not anchors.has(cell),"Il completion cannot replace a recorded scenery anchor")
  assert(int(row[2]) in range(12500,12536),"The audited Il supplement contains only existing lower shore-bank forms")
  source_rows.append([int(row[0]),int(row[1]),int(row[2]),str(row[3])])
 return source_rows

static func source_open(cell:Vector2i)->bool:
 var size_=Vector2i(data().size[0],data().size[1])
 if not Rect2i(Vector2i.ZERO,size_).has_point(cell):return false
 if native_bits.is_empty():native_bits=Marshalls.base64_to_raw(data().native_walk.after_bits)
 var index=cell.y*size_.x+cell.x
 return bool(native_bits[index>>3] & (1<<(index&7)))

static func mask()->Texture2D:return load(ROOT+"mask.png")
static func ground_index()->Texture2D:return load(ROOT+"ground-index.png")

static func owns_bank(source_id:int,row:Array)->bool:
 if source_id!=2000:return false
 for cap:Dictionary in data().new_bank_caps:
  if int(row[0])==int(cap.source_cell[0]) and int(row[1])==int(cap.source_cell[1]) and int(row[2])==int(cap.serial):return true
 return false

static func bank_placements(frame:Transform2D=Transform2D.IDENTITY)->Array:
 var result=[]
 for source:Dictionary in data().new_bank_caps:
  var row=source.duplicate(true);row.source_cell=Vector2i(source.source_cell[0],source.source_cell[1])
  row.anchor=frame*Vector2(source.anchor[0],source.anchor[1]);row.frame=Transform2D(frame.x,frame.y,Vector2.ZERO)
  result.append(row)
 return result

static func install(model):
 var context=load("res://scripts/forest/forest_freyja_regions.gd").private_source_context
 if context!=null and (context.owns(model) or context.host(model.falan_area)):return
 # Called only at terrain/navigation setup. No walk-mask or height-field mutation.
 if model.falan_area not in ["il_village","east_gate"]:return
 var terrain=model.terrain;var start=int(terrain.get_meta("il_source_cap_start",-1))
 if start>=0 and start<terrain.pieces.size() and terrain.pieces[start].get("il_source_completion",false):return
 var frame=Transform2D.IDENTITY
 if model.falan_area=="east_gate":frame=load("res://scripts/forest/forest_freyja_regions.gd").village_transform("il_village")
 var placements=bank_placements(frame)
 for row:Dictionary in placements:
  var source:Dictionary=row.source_approach_land;var cell=Vector2i(source.cell[0],source.cell[1])
  assert(source.cached_cell_known and source.native_attribute_open and source.dry_land and source_open(cell),"Cap approach requires original-open recorded dry source land")
  assert(row.join_rects.is_empty() or row.source_dry_neighbor.dry_land,"No seam join can support an adjoining water cell")
  var at=frame*Vector2((cell.x-45)*3,(cell.y-60)*3)
  assert(absf(terrain.height(at.x,at.y)-float(row.height))<.025,"Cap must meet the existing neighboring6m land without a step")
 start=terrain.pieces.size();Caps.append_pieces(terrain,placements)
 for index in range(start,terrain.pieces.size()):terrain.pieces[index].il_source_completion=true
 terrain.set_meta("il_source_cap_start",start)

static func build_banks(root:Node3D,model,area:String,offset:Vector2=Vector2.ZERO,approach:bool=false):
 var context=load("res://scripts/forest/forest_freyja_regions.gd").private_source_context
 if context!=null and context.owns(model):return
 if area!="il_village":return
 install(model)
 var placements=[]
 for row:Dictionary in bank_placements():
  if approach and (row.anchor.x< -12 or absf(row.anchor.y+18)>36):continue
  row.anchor+=offset;placements.append(row)
 Caps.build(root,placements)
