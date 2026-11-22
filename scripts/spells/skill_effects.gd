extends RefCounted
## Original sheets are loaded at setup and reused by all casts and pooled projectiles.
const Levels=preload("res://scripts/spells/skill_levels.gd")
const PHYSICAL_SHINES=["110103","110102","110101","110100","111016"]
const ELEMENT_SHINES=["110055","110054","110053","110052","111001"]
const ROOT="res://assets/characters/crossgate/skill_tiers/"
static var data:Dictionary={}
static var textures:Dictionary={}

static func prepare():
 if not data.is_empty():return
 data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
 var hashes={}
 for ref in data.clips:
  var digest:String=data.clips[ref].sha256
  if not hashes.has(digest):hashes[digest]=load(data.clips[ref].runtime_path)
  textures[ref]=hashes[digest]

static func clip(ref:String)->Dictionary:return data.clips[ref]

static func sheet(sprite:Sprite3D,ref:String):
 var row:Dictionary=data.clips[ref]
 sprite.texture=textures[ref];sprite.hframes=int(row.columns)
 sprite.vframes=ceili(float(row.frames)/float(row.columns));sprite.frame=0

static func element(kind:String,tier:int)->Dictionary:return data.elements[kind][clampi(tier,0,Levels.EX_TIER)]

static func recovery(tier:int)->Dictionary:return data.recovery[clampi(tier,0,Levels.EX_TIER)]

static func charge_frame(ticket:Dictionary,frame:float,ordinary_frames:int,ex_frames:int)->int:
 var frames=ex_frames if Levels.is_ex(ticket) else ordinary_frames
 return clampi(floori(frame*frames/ordinary_frames),0,frames-1)

static func physical_shine(sprite:Sprite3D,ticket:Dictionary):
 var tier=Levels.shine_tier(int(ticket.get("skill_level",1))) if ticket.has("skill_rules") or Levels.is_ex(ticket) else 3
 var ref:String=PHYSICAL_SHINES[tier];var row=clip(ref)
 sheet(sprite,ref)
 sprite.offset=Vector2(float(row.bounds[0])+float(row.width)*.5,-float(row.bounds[1])-float(row.height)*.5)

static func meditation_shine(sprite:Sprite3D,ticket:Dictionary):
 var ref:String=data.meditation[int(ticket.get("skill_rules",{}).get("effect_tier",3))]
 var row=clip(ref)
 sheet(sprite,ref)
 sprite.offset=Vector2(float(row.bounds[0])+float(row.width)*.5,-float(row.bounds[1])-float(row.height)*.5)

static func elemental_shine(ticket:Dictionary)->String:
 return ELEMENT_SHINES[Levels.shine_tier(int(ticket.get("skill_level",1)))]
