extends RefCounted
## Immutable recovered pixels; prepare selected textures before animation begins.
const ROOT="res://assets/characters/crossgate/cosmetics/"
const SHADER=preload("res://assets/materials/crossgate_body.gdshader")
static var data:Dictionary={}
static var definitions:Dictionary={}
static var pages:Dictionary={}
static var materials:Dictionary={}
static var head_tables:Dictionary={}
static var head_bytes:PackedByteArray
static var bound_tables:Dictionary={}
static var icon_atlas:Texture2D

static func items()->Dictionary:
 if definitions.is_empty():
  data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"catalog.json"))
  for item in data.items:definitions[item.id]=item
 return definitions

static func icon(id:String)->AtlasTexture:
 if icon_atlas==null:icon_atlas=load(ROOT+"icons.png")
 var index=items().keys().find(id)
 var result=AtlasTexture.new();result.atlas=icon_atlas;result.region=Rect2(index%20*64,index/20*64,64,64);result.filter_clip=true
 return result

static func prepare(id:String):
 var item:Dictionary=items()[id]
 for clip in item.clips.values():
  for frame in clip.frames:
   var page=int(frame[0])
   if pages.has(page):continue
   var texture:Texture2D=load(ROOT+"atlas-%d.png"%page)
   var material=ShaderMaterial.new();material.shader=SHADER;material.set_shader_parameter("sprite_texture",texture)
   pages[page]=texture;materials[page]=material

static func prepare_heads(textures:Array):
 for texture in textures:
  frame_anchors(texture.resource_path)

static func frame_anchors(path:String)->Dictionary:
 if head_tables.is_empty():
  head_tables=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"anchors.json"))
  head_bytes=FileAccess.get_file_as_bytes(ROOT+"anchors.bin")
 if not bound_tables.has(path):
  var table={};var span:Array=head_tables.get(path,[0,0])
  for i in int(span[1]):
   var at=int(span[0])+i*8
   table[Vector2i(head_bytes.decode_u16(at),head_bytes.decode_u16(at+2))]=Vector2(head_bytes.decode_s16(at+4),head_bytes.decode_s16(at+6))*.25
  bound_tables[path]=table
 return bound_tables[path]

static func head(texture:Texture2D,region:Rect2)->Vector2:
 # shortcut: newly authored poses need an offline head fit before their next cosmetic review.
 return bound_tables.get(texture.resource_path,{}).get(Vector2i(region.position),Vector2(region.size.x*.5,region.size.y*.2))
