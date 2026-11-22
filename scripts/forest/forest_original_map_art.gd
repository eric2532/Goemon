extends RefCounted
## Original palette, anchors and painter order; no regenerated scenery.
const ROOT="res://assets/maps/original_crossgate/"
static var catalog:Dictionary={}
static var solid_textures:Dictionary={}
static var surface_textures:Dictionary={}
var placements:Array=[]
var textures:Dictionary={}
var bounds=Rect2()
var source_path=""

static func data()->Dictionary:
 if catalog.is_empty():
  var parsed=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"catalog.json"))
  assert(parsed is Dictionary and parsed.get("schema")==1,"Missing original Cross Gate map catalog")
  catalog=parsed
 return catalog

static func raw_map(path:String)->PackedByteArray:
 var row:Dictionary=data().maps[path]
 return Marshalls.base64_to_raw(row.get("restored_raw",row.raw)).decompress(int(row.bytes),FileAccess.COMPRESSION_DEFLATE)

static func solid_texture(page:int)->Texture2D:
 if not solid_textures.has(page):solid_textures[page]=load(ROOT+data().solid_pages[page])
 return solid_textures[page]

static func surface_texture(page:int)->Texture2D:
 if not surface_textures.has(page):surface_textures[page]=load(ROOT+data().surface_pages[page])
 return surface_textures[page]

func load_map(path:String,override_raw:PackedByteArray=PackedByteArray(),override_size:Vector2i=Vector2i.ZERO):
 source_path=path
 placements.clear();textures.clear()
 var row:Dictionary=data().maps[path] if override_raw.is_empty() else {"size":[override_size.x,override_size.y],"bytes":override_raw.size()}
 var width=int(row.size[0]);var cells=width*int(row.size[1])
 var raw=raw_map(path) if override_raw.is_empty() else override_raw
 assert(raw.size()==int(row.bytes) and raw.slice(0,4)==PackedByteArray([77,65,80,1]))
 var low=Vector2.INF;var high=-low
 for layer in 2:
  for i in cells:
   var serial=raw.decode_u16(20+(layer*cells+i)*2)
   if serial==0 or (layer==1 and serial<1000):continue
   var graphic:Dictionary=data().graphics[str(serial)]
   var x=i%width;var y=i/width
   var p=Vector2((x+y)*32+graphic.origin[0],(y-x)*24+graphic.origin[1])
   var size_=Vector2(graphic.rect[2],graphic.rect[3])
   var depth=11*y-9*x-mini(int(graphic.footprint[0]),int(graphic.footprint[1]))*10
   placements.append([0 if layer==0 or graphic.ground else 1,depth,p,serial,layer*cells+i,Vector2i(x,y)])
   low=low.min(p);high=high.max(p+size_)
   var page=int(graphic.page)
   if not textures.has(page):textures[page]=load(ROOT+data().pages[page])
 placements.sort_custom(func(a,b):
  if a[0]!=b[0]:return a[0]<b[0]
  if a[1]!=b[1]:return a[1]<b[1]
  if a[2].x!=b[2].x:return a[2].x<b[2].x
  return a[4]<b[4])
 bounds=Rect2(low,high-low)
