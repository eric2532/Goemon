extends RefCounted
## Original palette, anchors and painter order; no regenerated scenery.
const ROOT="res://assets/maps/original_crossgate/"
static var catalog:Dictionary={}
static var elsa_loaded=false
static var east_loaded=false
static var sokia_server_loaded=false
static var sokia_water_loaded=false
static var black_prayer_loaded=false
static var sokia_cape_access_loaded=false
static var freyja_trial_loaded=false
static var sokia_wind_loaded=false
static var sokia_desert_temple_loaded=false
static var sokia_dragon_summit_loaded=false
static var explore_recovered_loaded=false
const EXPLORE_RECOVERED_IDS=preload("res://assets/maps/original_crossgate/explore_recovered/map_ids.gd").IDS
const SOKIA_SERVER_IDS=[5005,5006,5009,5010,13504,13509,13512,15549,15556,15560,15562,15577,15800]
const EXPLORE_SERVER_IDS=[15549,15556,15560,15562,15577,15800]
const SOKIA_WATER_IDS=[13503,13505,13506,13507,13508,13510,13511,13513,13514,13515]
const SOKIA_CAPE_ACCESS_IDS=[15517,15520,15524,15528,15529]
const FREYJA_TRIAL_IDS=[11006,11007,11008,11009,11010,11011,11013,11014,11500,11501,11502]
const SOKIA_WIND_IDS=[301,302,20002,20003,20301,20302,20303,20304,20305,20306,20307,20308,20309,20310]
const SOKIA_DESERT_TEMPLE_IDS=[13016,13017,13018,13019,13020,13021,13022]
const SOKIA_DRAGON_SUMMIT_IDS=[15568,15569,15570,15571,15572,15573,15574,15575,15576,15578,15579,15580,15581,15582,15583,15584,15585,15586,15587,15588,15589,15590]
static var solid_textures:Dictionary={}
static var page_textures:Dictionary={}
static var page_images:Dictionary={}
static var pending_page_uploads:Dictionary={}
static var cpu_page_records:Dictionary={}
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
  var region=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/fixed/catalog.json"))
  var page_offset=catalog.pages.size();var surface_offset=catalog.surface_pages.size()
  for key in ["pages","solid_pages","surface_pages"]:
   for page in region[key]:catalog[key].append("../falan/sokia/fixed/"+page)
  for serial in region.graphics:
   if catalog.graphics.has(serial):continue
   var graphic:Dictionary=region.graphics[serial].duplicate(true);graphic.page+=page_offset
   if graphic.has("surfaces"):graphic.surfaces[0]+=surface_offset
   catalog.graphics[serial]=graphic
  catalog.maps.merge(region.maps,false)
  for supplement in ["university/catalog.json"]:
   var regional=JSON.parse_string(FileAccess.get_file_as_string(ROOT+supplement))
   assert(regional is Dictionary and regional.get("schema")==1,"Missing regional map supplement: "+supplement)
   var shift=catalog.pages.size()-page_offset;var surface_shift=catalog.surface_pages.size()-surface_offset
   for serial in regional.graphics:
    regional.graphics[serial].page+=shift
    if regional.graphics[serial].has("surfaces"):regional.graphics[serial].surfaces[0]+=surface_shift
   catalog.maps.merge(regional.maps,true)
   catalog["university_mountain_templates"]=regional.mountain_templates
   catalog.graphics.merge(regional.graphics)
   for key in ["pages","surface_pages","solid_pages"]:catalog[key].append_array(regional[key])
 return catalog

static func load_elsa():
 if elsa_loaded:return
 var base=data()
 var regional=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"elsa/catalog.json"))
 assert(regional is Dictionary and regional.get("schema")==1,"Missing Elsa map supplement")
 var offset=base.pages.size()-int(regional.page_offset)
 for serial in regional.graphics:regional.graphics[serial].page+=offset
 base.maps.merge(regional.maps,true);base.graphics.merge(regional.graphics)
 for key in ["pages","surface_pages","solid_pages"]:base[key].append_array(regional[key])
 elsa_loaded=true

static func load_east():
 if east_loaded:return
 var base=data()
 var regional=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"east/catalog.json"))
 assert(regional is Dictionary and regional.get("schema")==1,"Missing eastern region map supplement")
 if "elsa" in regional.get("requires",[]):load_elsa()
 var page_offset:int=base.pages.size();var surface_offset:int=base.surface_pages.size()
 for serial in regional.graphics:
  var graphic:Dictionary=regional.graphics[serial].duplicate(true)
  graphic.page+=page_offset
  if graphic.has("surfaces"):graphic.surfaces[0]+=surface_offset
  base.graphics[serial]=graphic
 base.maps.merge(regional.maps,true)
 for key in ["pages","surface_pages","solid_pages"]:base[key].append_array(regional[key])
 east_loaded=true

static func load_sokia_server():
 if sokia_server_loaded:return
 var base=data()
 load_east() # Reuse the223 existing source graphics; do not copy their pages.
 var regional=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"sokia_server/catalog.json"))
 assert(regional is Dictionary and regional.get("schema")==1,"Missing pinned Sokia server-map supplement")
 var page_offset:int=base.pages.size();var surface_offset:int=base.surface_pages.size()
 for serial in regional.graphics:
  if base.graphics.has(serial):
   assert(base.graphics[serial].rgba_sha256==regional.graphics[serial].rgba_sha256,"A reused native graphic must retain its exact source pixels")
   continue
  var graphic:Dictionary=regional.graphics[serial].duplicate(true);graphic.page+=page_offset
  if graphic.has("surfaces"):graphic.surfaces[0]+=surface_offset
  base.graphics[serial]=graphic
 for path in regional.maps:
  assert(not base.maps.has(path),"A server-only map must not replace an existing map owner")
  base.maps[path]=regional.maps[path]
 for key in ["pages","surface_pages","solid_pages"]:base[key].append_array(regional[key])
 sokia_server_loaded=true

static func raw_map(path:String)->PackedByteArray:
 var row:Dictionary=data().maps[path]
 if row.get("active_layout_variant","")=="pinned-reference":return Marshalls.base64_to_raw(row.reference_variant_raw).decompress(int(row.bytes),FileAccess.COMPRESSION_DEFLATE)
 return Marshalls.base64_to_raw(row.get("restored_raw",row.raw)).decompress(int(row.bytes),FileAccess.COMPRESSION_DEFLATE)

static func load_sokia_water():
 if sokia_water_loaded:return
 load_sokia_server()
 var base=data();var regional:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"sokia_server/water/catalog.json"))
 assert(regional.get("schema")==1,"Missing source Water Cave supplement")
 var page_offset:int=base.pages.size();var surface_offset:int=base.surface_pages.size()
 for serial in regional.graphics:
  assert(not base.graphics.has(serial),"Water Cave art must not replace a shared original graphic")
  var graphic:Dictionary=regional.graphics[serial].duplicate(true);graphic.page+=page_offset
  if graphic.has("surfaces"):graphic.surfaces[0]+=surface_offset
  base.graphics[serial]=graphic
 for path in regional.maps:
  assert(not base.maps.has(path),"Water Cave maps must retain one layout owner")
  base.maps[path]=regional.maps[path]
 for path in regional.layout_overrides:
  assert(base.maps.has(path)and base.maps[path].sha256==regional.layout_overrides[path].sha256,"A completed Water layout must preserve the same original client bytes")
  var previous:Dictionary=base.maps[path];var completed:Dictionary=regional.layout_overrides[path].duplicate(true)
  completed.sokia_visual_only=previous.get("sokia_visual_only",false)
  base.maps[path]=completed
 for key in ["pages","surface_pages","solid_pages"]:base[key].append_array(regional[key])
 base.sokia_water_cliffs=regional.source_cliffs;base.sokia_water_cliffs.texture_page+=page_offset
 base.sokia_water_cliffs.void_source_fragments=base.sokia_water_cliffs.void_source_fragments.map(func(value):return int(value))
 sokia_water_loaded=true

static func load_sokia_cape_access():
 if sokia_cape_access_loaded:return
 load_east()
 var base=data();var regional:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/cape/access/catalog.json"))
 assert(regional.get("schema")==1,"Missing source Cape access supplement")
 var page_offset:int=base.pages.size();var surface_offset:int=base.surface_pages.size()
 for serial in regional.graphics:
  if base.graphics.has(serial):
   assert(base.graphics[serial].rgba_sha256==regional.graphics[serial].rgba_sha256,"Cape access must preserve shared original pixels")
   continue
  var graphic:Dictionary=regional.graphics[serial].duplicate(true);graphic.page+=page_offset
  if graphic.has("surfaces"):graphic.surfaces[0]+=surface_offset
  base.graphics[serial]=graphic
 for path in regional.maps:
  assert(not base.maps.has(path),"Cape prerequisites must retain one layout owner")
  base.maps[path]=regional.maps[path]
 for key in ["pages","surface_pages","solid_pages"]:base[key].append_array(regional[key])
 sokia_cape_access_loaded=true

static func load_freyja_trial():
 if freyja_trial_loaded:return
 load_east()
 var base=data();var regional:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"freyja_trial/catalog.json"))
 assert(regional.get("schema")==1 and regional.graphics.is_empty(),"Trial caves reuse existing original graphics")
 var offset:int=base.pages.size()
 for path in regional.maps:
  assert(not base.maps.has(path),"Trial caves must retain one source layout owner")
  base.maps[path]=regional.maps[path]
 for key in ["pages","surface_pages","solid_pages"]:base[key].append_array(regional[key])
 base.freyja_trial_cliffs=regional.source_cliffs;base.freyja_trial_cliffs.texture_page+=offset
 base.freyja_trial_cliffs.void_source_fragments=base.freyja_trial_cliffs.void_source_fragments.map(func(value):return int(value))
 freyja_trial_loaded=true

static func load_sokia_wind():
 if sokia_wind_loaded:return
 load_east()
 var base=data();var regional:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"sokia_wind_tower/catalog.json"))
 assert(regional.get("schema")==1,"Missing source Wind Tower supplement")
 var offset:int=base.pages.size();var surface_offset:int=base.surface_pages.size()
 for serial in regional.graphics:
  assert(not base.graphics.has(serial),"Wind Tower must reuse shared graphics instead of replacing them")
  var graphic:Dictionary=regional.graphics[serial].duplicate(true);graphic.page+=offset
  if graphic.has("surfaces"):graphic.surfaces[0]+=surface_offset
  base.graphics[serial]=graphic
 for path in regional.maps:
  assert(not base.maps.has(path),"Wind Tower retains one source layout owner")
  base.maps[path]=regional.maps[path]
 for key in ["pages","surface_pages","solid_pages"]:base[key].append_array(regional[key])
 sokia_wind_loaded=true

static func load_sokia_desert_temple():
 if sokia_desert_temple_loaded:return
 load_east()
 var base=data();var regional:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"sokia_desert_temple/catalog.json"))
 assert(regional.get("schema")==1,"Missing source Desert Temple supplement")
 var offset:int=base.pages.size();var surface_offset:int=base.surface_pages.size()
 for serial in regional.graphics:
  assert(not base.graphics.has(serial),"Desert Temple must reuse shared source graphics")
  var graphic:Dictionary=regional.graphics[serial].duplicate(true);graphic.page+=offset
  if graphic.has("surfaces"):graphic.surfaces[0]+=surface_offset
  base.graphics[serial]=graphic
 for path in regional.maps:
  assert(not base.maps.has(path),"Desert Temple retains one source map owner")
  base.maps[path]=regional.maps[path]
 for key in ["pages","surface_pages","solid_pages"]:base[key].append_array(regional[key])
 sokia_desert_temple_loaded=true

static func load_sokia_dragon_summit():
 if sokia_dragon_summit_loaded:return
 load_sokia_wind();load_sokia_desert_temple();load_sokia_server()
 var base=data();var regional:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"sokia_dragon_summit/catalog.json"))
 assert(regional.get("schema")==1,"Missing source Dragon/Summit supplement")
 var offset:int=base.pages.size();var surface_offset:int=base.surface_pages.size()
 for serial in regional.graphics:
  assert(not base.graphics.has(serial),"Dragon/Summit must reuse shared source graphics")
  var graphic:Dictionary=regional.graphics[serial].duplicate(true);graphic.page+=offset
  if graphic.has("surfaces"):graphic.surfaces[0]+=surface_offset
  base.graphics[serial]=graphic
 for path in regional.maps:
  assert(not base.maps.has(path),"Dragon/Summit retains one source map owner")
  base.maps[path]=regional.maps[path]
 for key in ["pages","surface_pages","solid_pages"]:base[key].append_array(regional[key])
 sokia_dragon_summit_loaded=true

static func load_black_prayer():
 if black_prayer_loaded:return
 var base=data();var prefix="../falan/black_prayer/events/return-maps/"
 var regional:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+prefix+"catalog.json"))
 var page_offset:int=base.pages.size();var surface_offset:int=base.surface_pages.size()
 for serial in regional.graphics:
  if base.graphics.has(serial):
   assert(base.graphics[serial].rgba_sha256==regional.graphics[serial].rgba_sha256,"A reused Ruby return-room graphic must retain source pixels")
   continue
  var graphic:Dictionary=regional.graphics[serial].duplicate(true);graphic.page+=page_offset
  if graphic.has("surfaces"):graphic.surfaces[0]+=surface_offset
  base.graphics[serial]=graphic
 for path in regional.maps:
  assert(not base.maps.has(path),"Ruby return rooms must not replace another map owner")
  base.maps[path]=regional.maps[path]
 for key in ["pages","surface_pages","solid_pages"]:
  for page in regional[key]:base[key].append(prefix+page)
 black_prayer_loaded=true

static func load_explore_recovered():
 if explore_recovered_loaded:return
 load_sokia_dragon_summit();load_sokia_cape_access()
 var base=data();var regional:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"explore_recovered/catalog.json"))
 var offset:int=base.pages.size();var surface_offset:int=base.surface_pages.size()
 for serial in regional.graphics:
  assert(not base.graphics.has(serial),"Explore recovery reuses shared original graphics")
  var graphic:Dictionary=regional.graphics[serial].duplicate(true);graphic.page+=offset
  if graphic.has("surfaces"):graphic.surfaces[0]+=surface_offset
  base.graphics[serial]=graphic
 for path in regional.maps:
  assert(not base.maps.has(path),"Recovered missing destinations retain one owner")
  base.maps[path]=regional.maps[path]
 for key in ["pages","surface_pages","solid_pages"]:base[key].append_array(regional[key])
 explore_recovered_loaded=true

static func page_texture(page:int)->Texture2D:
 if not page_textures.has(page):
  if cpu_page_records.is_empty():
   for manifest in ["sokia_server/cpu-pages/provenance.json","sokia_server/cpu-pages/prayer/provenance.json","elsa/cpu-pages/provenance.json"]:
    var records=JSON.parse_string(FileAccess.get_file_as_string(ROOT+manifest))
    assert(records is Dictionary and not records.is_empty(),"Missing prepared original-page CPU data")
    for source_page in records:
     assert(not cpu_page_records.has(source_page),"An original page must have one CPU source owner")
     cpu_page_records[source_page]=records[source_page]
  var path:String=data().pages[page]
  if cpu_page_records.has(path):
   # Keep the exact source Image and shared texture together during setup upload.
   var record:Dictionary=cpu_page_records[path];var image:Image=load(ROOT+record.resource)
   assert(image.get_meta("source_page")==ROOT+path and image.get_meta("rgba_sha256")==record.rgba_sha256 and image.get_meta("source_sha256")==record.source_sha256,"Stale original-page CPU data: "+path)
   page_images[page]=image
   var texture=ImageTexture.create_from_image(image);texture.set_meta("original_source_page",ROOT+path)
   page_textures[page]=texture;pending_page_uploads[page]=true
  else:page_textures[page]=load(ROOT+path)
 return page_textures[page]

static func page_image(page:int)->Image:
 # Sampling shares prepared source pixels; callers crop/duplicate before editing.
 var texture=page_texture(page)
 if page_images.has(page):return page_images[page]
 return texture.get_image()

static func finish_page_uploads():
 # Finish once after the map's later texture/mesh setup; keep the same shared RIDs.
 for page in pending_page_uploads:page_textures[page].update(page_images[page])
 pending_page_uploads.clear()

static func solid_texture(page:int)->Texture2D:
 if not solid_textures.has(page):solid_textures[page]=load(ROOT+data().solid_pages[page])
 return solid_textures[page]

static func surface_texture(page:int)->Texture2D:
 if not surface_textures.has(page):surface_textures[page]=load(ROOT+data().surface_pages[page])
 return surface_textures[page]

func load_map(path:String,override_raw:PackedByteArray=PackedByteArray(),override_size:Vector2i=Vector2i.ZERO,prepared_ground_plane:bool=false):
 source_path=path
 placements.clear();textures.clear()
 var row:Dictionary=data().maps.get(path,{}).duplicate() if not override_raw.is_empty() else data().maps[path]
 if not override_raw.is_empty():row.merge({"size":[override_size.x,override_size.y],"bytes":override_raw.size()},true)
 var width=int(row.size[0]);var cells=width*int(row.size[1])
 var raw=raw_map(path) if override_raw.is_empty() else override_raw
 assert(raw.size()==int(row.bytes) and raw.slice(0,4)==PackedByteArray([77,65,80,1]))
 var low=Vector2.INF;var high=-low
 for layer in range(1 if prepared_ground_plane else 0,2):
  for i in cells:
   var serial=raw.decode_u16(20+(layer*cells+i)*2)
   if serial==0 or (layer==1 and serial<1000):continue
   serial=int(row.get("graphic_aliases",{}).get(str(serial),serial))
   var graphic:Dictionary=data().graphics[str(serial)]
   var x=i%width;var y=i/width
   var p=Vector2((x+y)*32+graphic.origin[0],(y-x)*24+graphic.origin[1])
   var size_=Vector2(graphic.rect[2],graphic.rect[3])
   var depth=11*y-9*x-mini(int(graphic.footprint[0]),int(graphic.footprint[1]))*10
   placements.append([0 if layer==0 or graphic.ground else 1,depth,p,serial,layer*cells+i,Vector2i(x,y)])
   low=low.min(p);high=high.max(p+size_)
   var page=int(graphic.page)
   if not textures.has(page):textures[page]=page_texture(page)
 placements.sort_custom(func(a,b):
  if a[0]!=b[0]:return a[0]<b[0]
  if a[1]!=b[1]:return a[1]<b[1]
  if a[2].x!=b[2].x:return a[2].x<b[2].x
  return a[4]<b[4])
 bounds=Rect2(low,high-low)
