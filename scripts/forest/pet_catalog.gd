@static_unload
extends RefCounted
const MAX_ACTIVE=5
const MAX_NAME_LENGTH=32
const BASE_HEALTH=150.0
const BASE_MANA=50.0
const MANA_REGEN=1.0
const BASE_DAMAGE=50.0
const BEE_DODGE_BONUS=10.0
const PASSIVES={
 "Dragon lizards":{"name":"水龍再生","stat":"regeneration","step":5.0,"upgrade":true},
 "Mantises":{"name":"螳螂會心","stat":"critical_chance","step":15.0,"upgrade":true},
 "Bees":{"name":"Bee Mirage","stat":"dodge_chance","step":BEE_DODGE_BONUS,"upgrade":false},
}
const RANGED_REACH=16.0
const Spells=preload("res://scripts/spells/spell_catalog.gd")
const Levels=preload("res://scripts/spells/skill_levels.gd")
const MAX_SKILLS=3
# Stable native wire order; append new entries to preserve saved techniques.
const SKILLS={Spells.SURE_STRIKE:Spells.SHIN_SURE_STRIKE_NAME,Spells.COMBO:Spells.KAZ_COMBO_NAME,
 "kazi/qigong":"氣功蛋",Spells.MAZE_QI:"氣功蛋",Spells.MOON:"追月",
 "kazi/fire":"Fire","kazi/ice":"Ice","kazi/wind":"Wind","kazi/meteor":"隕石",Spells.SPIRIT:Spells.SPIRIT_NAME,
 Spells.BEE_FLURRY:"Bee Flurry",
 Spells.BODYGUARD:"護衛"}
const CONTACT_CUES=[143,138,133,135,137,131,132,264,267,290]
const COUNT=617
const ROOT="res://assets/characters/crossgate/guard_pets/"
const HOUND_HEADS=preload("res://assets/characters/crossgate/hounds/hud-heads.png")
const MANTIS_PORTRAITS=preload("res://assets/characters/crossgate/mantises/portraits.png")
const DRAGON_PORTRAITS=preload("res://assets/characters/crossgate/dragon_lizards/portraits.png")
const BEE_PORTRAITS=preload("res://assets/characters/crossgate/bees/portraits.png")
const DEFAULT=["original:2818","puk2:703","ch1:491","puk3:870","ex:1765"]
const HOUND_NAMES=["Ember","Jade","Amber","Silver","Orchid","Aqua","Sand","Teal","Gold","Lilac","Blue","Sun","Onyx","Rose","Frost","Bronze","Spark","Purgatory","White aura","Pink flame","Three-headed"]
const MANTIS_NAMES=["Green","Killer","Red-eye","Ash","Deadly","Pink","Lavender","Violet","Crescent","Pale green","Snow (archive)","Red aura","Snow","White","Black","Green XL","Killer XL","Red-eye XL","Ash XL","Deadly XL"]
const DRAGON_NAMES=["Earth","Water","Fire","Wind","Pink / white spines","Purple / gold spines","Pink / gold spines","Deep purple","Teal","Charcoal / blue spines","Coral","White","Black","Snow (archive)","Snow","Green aura","Earth XL","Water XL","Fire XL","Wind XL"]
const BEE_NAMES=["Killer","Alien","Hornet","Yellow","Death","Cyan","Orange","Pink","Purple","Green","Magenta / gold wings","Pink / orange wings","White","Snow (archive)","Snow","Lightning","Killer XL","Alien XL","Hornet XL","Yellow XL","Death XL"]
const EFFECT_SKINS=[17,18,19,29,31,32,33,54,55,56,74,75,76]
static var data:Dictionary={}
static var portraits:Dictionary={}
static var sounds:Dictionary={}
static var audio_clips:Array[Dictionary]=[]
static var family_portraits:Dictionary={}
static var key_indices:Dictionary={}
static func motions()->Dictionary:
 if data.is_empty():
  data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"motions.json"))
  for i in data.variants.size():key_indices[data.variants[i].key]=i
 return data
static func skin(key:String)->int:
 motions()
 return key_indices.get(key,-1)
static func key(index:int)->String:return motions().variants[index].key
static func display_name(index:int,names:Dictionary)->String:
 var default_name=label(index)
 if default_name.is_empty() or default_name.begins_with("Variant "):default_name="Pet %d"%(index+1)
 return names.get(key(index),default_name)
static func clean_name(value:String)->String:
 return value.strip_escapes().strip_edges().left(MAX_NAME_LENGTH).strip_edges()
static func sanitized_names(value)->Dictionary:
 var result={}
 if not value is Dictionary:return result
 for id in value:
  if not id is String or skin(id)<0 or not value[id] is String:continue
  var name_=clean_name(value[id])
  if not name_.is_empty():result[id]=name_
 return result
static func sanitized(value)->Array[String]:
 var result:Array[String]=[]
 if not value is Array:value=DEFAULT
 for entry in value:
  if entry is String and skin(entry)>=0 and available(skin(entry)) and entry not in result:result.append(entry)
  if result.size()==MAX_ACTIVE:break
 return result
static func sanitized_skills(value)->Dictionary:
 var result={}
 if not value is Dictionary:return result
 for pet in value:
  if not pet is String or skin(pet)<0:continue
  var saved=value[pet]
  if saved is String:saved=[saved]
  if not saved is Array:continue
  var slots=["","",""]
  var families=[]
  for slot in mini(MAX_SKILLS,saved.size()):
   var id=saved[slot]
   if not id is String or not SKILLS.has(id):continue
   var family=Levels.family(id)
   if family in families:continue
   families.append(family);slots[slot]=id
  if slots.any(func(id):return not id.is_empty()):result[pet]=slots
 return result
static func skill_slots(value:Dictionary,key_:String)->Array:
 return value.get(key_,["","",""])
static func skill_codes(slots:Array)->PackedInt32Array:
 var result=PackedInt32Array()
 for id in slots:result.append(22 if id==Spells.BODYGUARD else SKILLS.keys().find(id)+1)
 return result
static func skill_id(code:int)->String:
 if code==22:return Spells.BODYGUARD
 return SKILLS.keys()[code-1] if code>=1 and code<=11 else ""
static func native_mana_costs()->PackedFloat32Array:
 var result=PackedFloat32Array();result.resize(22)
 for id in SKILLS:result[skill_codes([id])[0]-1]=Spells.mana_cost(id)
 return result
static func attack_pattern(skin_:int)->Dictionary:
 var rows:Array=motions().timelines
 var result={"pose":5,"duration":1.0,"contacts":[0.0],"sounds":[],"direction":4}
 for direction in 8:
  var at=(skin_*8+direction)*int(motions().timeline_stride);var contacts=[];var sounds=[]
  for cue in int(rows[at+1]):
   var tick=float(rows[at+2+cue*2])/30.0
   if contact_cue(int(rows[at+3+cue*2])):contacts.append(tick)
   else:sounds.append(tick)
  if contacts.size()>=result.contacts.size():result={"pose":5,"duration":float(rows[at])/30.0,"contacts":contacts,"sounds":sounds,"direction":direction}
 return result
static func contact_cue(cue:int)->bool:return cue<20000 and (cue>=10000 or cue in CONTACT_CUES)
static func label(index:int)->String:return motions().variants[index].label if index>=82 else HOUND_NAMES[index] if index<21 else MANTIS_NAMES[index-21] if index<41 else DRAGON_NAMES[index-41] if index<61 else BEE_NAMES[index-61]
static func title(index:int)->String:return label(index)+(" · "+category(index) if index>=82 else " hound" if index<21 else " mantis" if index<41 else " dragon lizard" if index<61 else " bee")
static func category(index:int)->String:return motions().variants[index].category if index>=82 else "Hounds" if index<21 else "Mantises" if index<41 else "Dragon lizards" if index<61 else "Bees"
static func has_bee_dodge(index:int)->bool:return index>=0 and index<COUNT and category(index)=="Bees"
static func passive(index:int)->Dictionary:return PASSIVES.get(category(index),{}) if index>=0 and index<COUNT else {}
static func passive_value(index:int,level_:int=1)->float:
 var row=passive(index)
 if row.is_empty():return 0.0
 var value:float=row.step*(level_ if row.upgrade else 1)
 return value if row.stat=="regeneration" else minf(100.0,value)
static func passive_hint(index:int,level_:int=1)->String:
 var row=passive(index)
 if row.is_empty():return ""
 var value=passive_value(index,level_)
 if row.stat=="regeneration":return "This pet in your party grants the player +%d HP per second."%value
 return "This pet in your party grants the player +%d percentage points of %s chance, up to 100%%."%[value,"critical" if row.stat=="critical_chance" else "dodge"]
static func available(index:int)->bool:return not OS.has_feature("web") or index<82
static func listed(index:int)->bool:return available(index) and (category(index)!="bosses" or not motions().variants[index].has("motion_key"))
static func categories()->Array:
 var result=["All","Hounds","Mantises","Dragon lizards","Bees"]
 for index in range(82,COUNT):
  if not available(index):continue
  var family=category(index)
  if family not in result:result.append(family)
 result.append("Aura & effects")
 return result
static func effect(index:int)->bool:return motions().variants[index].effect if index>=82 else index in EFFECT_SKINS
static func portrait(index:int)->Texture2D:
 if not available(index):return null
 if not portraits.has(index):
  var texture=AtlasTexture.new();texture.filter_clip=true
  if index>=82:
   var variant:Dictionary=motions().variants[index];var path:String=variant.portrait_path
   if not family_portraits.has(path):family_portraits[path]=load(path)
   texture.atlas=family_portraits[path]
   texture.region=Rect2(Vector2(int(variant.portrait_cell)%5,int(variant.portrait_cell)/5)*96,Vector2.ONE*96)
   portraits[index]=texture
   return texture
  texture.atlas=HOUND_HEADS if index<21 else MANTIS_PORTRAITS if index<41 else DRAGON_PORTRAITS if index<61 else BEE_PORTRAITS
  var cell=index if index<21 else index-21 if index<41 else index-41 if index<61 else index-61
  var columns=7 if index<21 else 5
  var width=32 if index<21 else 96
  texture.region=Rect2(Vector2(cell%columns,cell/columns)*width,Vector2.ONE*width)
  portraits[index]=texture
 return portraits[index]
static func make_mesh(selected:Array=DEFAULT)->QuadMesh:
 var source=motions()
 if sounds.is_empty():
  for id in source.sounds:sounds[int(id)]=load("res://"+source.sounds[id].goemon_file)
  for variant in source.variants:
   var clips={}
   for clip in variant.get("clips",[]):
    if int(clip.action) in [0,1,3,8,10] and not clip.sounds.is_empty():clips[int(clip.action)*8+int(clip.direction)]=clip
   audio_clips.append(clips)
 var mesh=preload("res://scripts/forest/crowd/hound_sprites.gd").make_mesh(ROOT,source)
 prepare(selected)
 return mesh
static func prepare(selected:Array,corpses:Array=[])->void:
 var source=motions();var pages=[];var skins=[]
 for key_ in selected:
  var index=skin(key_)
  if index>=0:skins.append(index)
 for row in corpses:
  if int(row.get("kind",-1))==19:skins.append(int(row.skin))
 for index in skins:
  for page_value in source.skin_pages[index]:
   var page=int(page_value)
   if page not in pages:pages.append(page)
 preload("res://scripts/forest/crowd/hound_sprites.gd").prepare_pages(ROOT,source,pages)
