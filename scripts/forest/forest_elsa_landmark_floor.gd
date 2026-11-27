extends RefCounted
## Private BG color derivatives; keep each original tile's geometry and ownership.
const ROOT="res://assets/maps/falan/elsa/scenery/landmark-floor/"
const ENTRY="res://assets/maps/falan/elsa/scenery/entry-pedestals/"
const PAGE_OFFSET=100000
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
static var record:Dictionary={}
static var textures:Dictionary={}
static var infill:Mesh
static var regional_records:Dictionary={}
static var regional_textures:Dictionary={}

static func available(id:int)->bool:
 return id==59520 or regional_records.has(id) or id==59530 and FileAccess.file_exists(ENTRY+"floor-data.json")

static func data(id:int=59520)->Dictionary:
 if id!=59520:
  if not regional_records.has(id):
   assert(id==59530);regional_records[id]=JSON.parse_string(FileAccess.get_file_as_string(ENTRY+"floor-data.json"))
  return regional_records[id]
 if record.is_empty():record=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return record

static func graphic(index:int,original:Dictionary,id:int=59520)->Dictionary:
 var row:Dictionary=data(id).placements.get(str(index),{})
 if row.is_empty():return original
 # The rect changes UVs only. Extents, native origin and the original placement
 # index still feed shore_floor/terrain_floor, including their vertical profiles.
 assert(row.rect[2]==original.rect[2] and row.rect[3]==original.rect[3])
 assert(row.origin==original.origin)
 var result=original.duplicate();result.rect=row.rect;result.page=PAGE_OFFSET+int(row.page)
 return result

static func texture(page:int,id:int=59520)->Texture2D:
 assert(page>=PAGE_OFFSET)
 if id!=59520:
  if not regional_textures.has([id,page]):
   assert(id==59530);regional_textures[[id,page]]=load(ENTRY+"floor-atlas-%d.png"%(page-PAGE_OFFSET))
  return regional_textures[[id,page]]
 if not textures.has(page):textures[page]=load(ROOT+"atlas-%d.png"%(page-PAGE_OFFSET))
 return textures[page]

static func ground(pixel:Vector2)->Vector3:
 return Vector3(pixel.x*3./64.-pixel.y/16.,0,pixel.x*3./64.+pixel.y/16.)

static func build(root:Node3D,origin:Vector2):
 if infill==null:
  var r:Array=data().rect;var paint:Texture2D=load(ROOT+"ground-infill.png")
  var skin=Source.new([Rect2(Vector2.ZERO,paint.get_size()),-Vector2(r[0],r[1]),Vector2.ONE,0],paint,1./Fit.VERTICAL)
  skin.reflection_threshold=2.
  skin.quad(ground(Vector2(r[0],r[1])),ground(Vector2(r[2],r[1])),ground(Vector2(r[2],r[3])),ground(Vector2(r[0],r[3])))
  infill=skin.finish()
 var node=MeshInstance3D.new();node.name="ElsaOccludedLandmarkGround";node.mesh=infill;node.position=Vector3(origin.x,.013,origin.y)
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.set_meta("inferred_occluded_ground",true);root.add_child(node)
