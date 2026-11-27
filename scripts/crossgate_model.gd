extends HeroModel
## Original recovered sprites; shared Hero owns movement and collisions.
const CROSSGATE_ROOT="res://assets/characters/crossgate/"
const ROOT=CROSSGATE_ROOT+"kazi/"
const Skins=preload("res://scripts/kaz_skins.gd")
const Roster=preload("res://scripts/rogue_roster.gd")
const SpriteArt=preload("res://scripts/crossgate_sprite_art.gd")
const Skills=preload("res://scripts/spells/spell_catalog.gd")
const Proportions=preload("res://scripts/character_proportions.gd")
const BODY_HEIGHT_PIXELS=Proportions.KAZ_BODY_PIXELS
const FEET_OFFSET_PIXELS=Proportions.CROSSGATE_FEET_PIXELS
# Rounded ground strides at the shared standing height; source drawings stay intact.
const WALK_STRIDE=2.8
const RUN_STRIDE=4.4
const GUARD_CELL=Vector2(100,112)
const GUARD_ORIGIN=Vector2(50,91)
const GUARD_ROW={102488:0,109890:1,109891:2,109146:3,
 100028:4,100034:5,100040:6,100046:7,100049:8,100891:9,
 100918:10,100969:11,105564:12,105570:13,105608:14}
const WEAPON_GUARD_CELL=Vector2(120,132)
const WEAPON_GUARD_ORIGIN=Vector2(62,100)
const JUMP_GUARD_RISE=.06
const JUMP_FLINCH_END=.13
const JUMP_LANDING=.22
# BlueCG states 0x1d and 0x0b use four source pixels per update.
const KAGEROU_HZ=60
const KAGEROU_STEP_PIXELS=4.0
const KAGEROU_BACK_TICKS=13
const KAGEROU_RETURN_TICK=28
const KAGEROU_HOME_TICK=40
const KAGEROU_GHOST_TICKS=12
const KAGEROU_EMIT_TICKS=2
const KAGEROU_SHADOWS=6
const SHIN_COUNTER_FRAMES=18
const SHIN_COUNTER_FRAME_TIME=3.0/60
const BEAST_CAST_DURATION=.38
const BEAST_CAST_WAIT=1.1
const BODY_SHADER=preload("res://assets/materials/crossgate_body.gdshader")
const SHADOW_SHADER=preload("res://assets/materials/crossgate_shadow.gdshader")
var body_materials:Dictionary={}
var food_glow_tint=Color.TRANSPARENT
var shadow_materials:Dictionary={}
static var profiles:Dictionary={}
static var wind_motions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CROSSGATE_ROOT+"weapons/wind-motion-cues.json"))
static var attack_audio:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/crossgate/player-attacks.json"))
static var attack_samples:Dictionary={}
var native_root=""
var gear_weapon=""
var beast_master:bool:
 get:return gear_weapon=="beast-master"
var gear_route:Dictionary={}
var gear_external=false
var gear_sounds:Dictionary={}
var character=34
var kaz_skin=Skins.DEFAULT
var variant_skin=0
var shin_skin=0
var shin_weapon_index=0
var maze_weapon=Roster.MazeWeapon.KATANA
var primary_throwing_weapon:int:
 get:
  var setting:String=fighter.get("primary_setting","")
  return int(get_parent().game.skin_primary_kunai(character)) if not setting.is_empty() else int(fighter.get("primary_weapon",Roster.MazeWeapon.KATANA))
var daggers:bool:
 get:return maze_weapon==Roster.MazeWeapon.KUNAI
var fighter:Dictionary
var native_skills:Dictionary
var recovery_key:String
var motions:Dictionary
var appearance:Dictionary
var atlases:Array[Texture2D]
var combat:Node
var pressure_trail:MeshInstance3D
var sprite:Sprite3D
var explosion:Sprite3D
var combo_glow:Sprite3D
var shin_counter_fx:Sprite3D
var shin_counter_age=0.0
var shin_counter_linger=0.0
var shin_counter_frame=-1
var stat_counter_shadow:Sprite3D
var counter_is_basic=false
var qi_punch:Dictionary={}
var qi_atlas:Array[Texture2D]
var kagerou_shadows:Array[Sprite3D]=[]
var kagerou_time=0.0
var kagerou_tick=-1
var kagerou_step=Vector3.ZERO
var kagerou_dash_left=0.0
var kagerou_afterimages=true
var kagerou_offset_sprite=true
var clock=0.0
var cast_clock=0.0
var cast_owner:Node
var beast_cast_left=0.0
var beast_cast_wait_left=0.0
var current_clip=""
var current_frame=-1
var player_jump=false
var jump_guard_atlas:Texture2D
var jump_count=0
var jump_age=-1.0
var jump_landing_left=0.0
var body_height_pixels=BODY_HEIGHT_PIXELS
var cosmetic_layers:RefCounted
var weapon_combo_clips:Array[Dictionary]=[]
var weapon_combo_step=-1:
 set(value):
  if weapon_combo_step==value:return
  weapon_combo_step=value;current_clip="";current_frame=-1
var weapon_combo_next=0

func refresh_cosmetics():
 var hero=get_parent()
 var gear=preload("res://scripts/forest/equipment.gd")
 var slots=gear.cosmetic_slots(hero.game.settings.get("cosmetic_loadouts",{}),gear.character_key(character))
 var ids=[]
 for slot in gear.COSMETIC_SLOTS:
  var id:String=slots.get(slot,"")
  if gear.Cosmetics.items().has(id):ids.append(id)
 if cosmetic_layers==null and ids.is_empty():return
 if cosmetic_layers!=null and cosmetic_layers.selected==ids:return
 if cosmetic_layers==null:cosmetic_layers=preload("res://scripts/forest/cosmetic_layers.gd").new()
 prepare_cosmetic_heads()
 cosmetic_layers.configure(body,ids)

func prepare_cosmetic_heads():
 var textures:Array=atlases+qi_atlas
 if jump_guard_atlas!=null:textures.append(jump_guard_atlas)
 preload("res://scripts/forest/cosmetic_catalog.gd").prepare_heads(textures)

func _ready():
 preload("res://scripts/spells/skill_effects.gd").prepare()
 player_jump=not get_parent().ai_controlled
 fighter=Roster.CROSSGATE[character].duplicate()
 recovery_key="%d:%s"%[character,Skills.RECOVERY]
 if fighter.get("throwing",false) and player_jump:maze_weapon=primary_throwing_weapon
 if fighter.has("skin_set"):
  shin_skin=Roster.ShinSkins.valid_id(fighter.skin_set=="special",shin_skin)
  load_appearance(Roster.ShinSkins.root(shin_skin))
 elif Roster.has_variant_skins(character):
  variant_skin=Roster.valid_skin(character,variant_skin)
  load_appearance(Roster.skin_root(character,variant_skin))
  motions=appearance
 else:
  var root=CROSSGATE_ROOT+fighter.root+"/"
  motions=profile(CROSSGATE_ROOT+fighter.get("motion_root",fighter.root)+"/")
  load_appearance(root if kaz_skin==Skins.DEFAULT else root+"skins/%d/"%kaz_skin)
 select_stance(int(fighter.get("start_weapon",0)))
 if player_jump:
  if fighter.get("throwing",false):maze_weapon=get_parent().game.skin_weapon(character,primary_throwing_weapon,Roster.MazeWeapon.FIST)
  elif fighter.has("skin_set"):select_stance(get_parent().game.skin_weapon(character,int(fighter.get("start_weapon",0)),appearance.get("weapons",[]).size()))
 if fighter.has("root"):
  var qi_root=CROSSGATE_ROOT+fighter.root+"/qi-punch/"
  if ResourceLoader.exists(qi_root+"atlas-0.png"):
   qi_punch=profile(qi_root)
   for path in SpriteArt.paths(qi_root,qi_punch):qi_atlas.append(load(path))
   prepare_body_materials(qi_atlas)
 body=Node3D.new();add_child(body)
 head=driver("Head",Vector3(0,1.7,0))
 arms.assign([driver("Arm_L",Vector3(-.3,1.2,0)),driver("Arm_R",Vector3(.3,1.2,0))])
 legs.assign([driver("Leg_L",Vector3(-.2,.5,0)),driver("Leg_R",Vector3(.2,.5,0))])
 scarf=driver("Sash",Vector3.ZERO)
 hair_normal=Node3D.new();body.add_child(hair_normal)
 hair_gold=Node3D.new();body.add_child(hair_gold);hair_gold.hide()
 pipe=Node3D.new();body.add_child(pipe)
 coin=Node3D.new();body.add_child(coin);coin.hide()
 chain_pipe=ChainPipeVisual.new();body.add_child(chain_pipe);chain_pipe.hide()
 locomotion=preload("res://scripts/master_chief_locomotion.gd").new(self)
 sprite=Sprite3D.new();sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 sync_standing_size()
 sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
 sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.region_enabled=true
 sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 body.add_child(sprite)
 sprite.set_instance_shader_parameter("grounded",locomotion.grounded)
 var throwing=Roster.has_crossgate_throws(character)
 # Copies can borrow charge skills regardless of their weapon family.
 var assault_image=get_parent().mirror_copy and get_parent().get("assault_copy")==true
 var barrage_image=get_parent().mirror_copy and get_parent().get("shadow_barrage")==true
 var player_controlled=not get_parent().ai_controlled
 var weapon_skills=fighter.get("weapon_skills",false) and player_controlled
 if player_controlled or barrage_image or Roster.is_crossgate_archer(character) or assault_image:
  combo_glow=Sprite3D.new()
  combo_glow.texture=preload("res://assets/characters/crossgate/qigong/charge.png")
  combo_glow.hframes=8;combo_glow.vframes=2
  combo_glow.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  combo_glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  combo_glow.pixel_size=Proportions.GOEMON_HEIGHT*2.2/165.0
  combo_glow.position.y=Proportions.GOEMON_HEIGHT*.55
  combo_glow.offset=Vector2(22.5,-10.5)
  body.add_child(combo_glow);combo_glow.hide()
  if Roster.is_crossgate_archer(character):set_shin_charge_art(false)
 if weapon_skills:
  set_shin_charge_art(false)
  prepare_shin_counter()
 if player_controlled:
  stat_counter_shadow=sprite.duplicate()
  stat_counter_shadow.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
  stat_counter_shadow.modulate.a=128.0/255.0
  stat_counter_shadow.top_level=true
  body.add_child(stat_counter_shadow);stat_counter_shadow.hide()
 if weapon_skills or ((Roster.has_kagerou(character) or fighter.get("combo",false) or throwing) and (player_controlled or assault_image)):
  prepare_kagerou_shadows()
 show_pose(0,0,true)

func prepare_shin_counter():
 prepare_kagerou_shadows()
 if shin_counter_fx!=null:return
 shin_counter_fx=combo_glow.duplicate()
 refresh_counter_theme()
 shin_counter_fx.hframes=6;shin_counter_fx.vframes=3
 shin_counter_fx.pixel_size=Proportions.GOEMON_HEIGHT*4.0/334.0
 shin_counter_fx.offset=Vector2(22,-13)
 shin_counter_fx.top_level=true
 shin_counter_fx.hide()
 body.add_child(shin_counter_fx)

func prepare_kagerou_shadows():
 if not kagerou_shadows.is_empty():return
 for i in KAGEROU_SHADOWS:
  var shadow:Sprite3D=sprite.duplicate()
  shadow.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
  shadow.modulate.a=128.0/255.0
  shadow.top_level=true
  body.add_child(shadow);shadow.hide()
  kagerou_shadows.append(shadow)

func set_shin_charge_art(meditation:bool):
 combo_glow.frame=0
 combo_glow.texture=preload("res://assets/characters/crossgate/shin/meditation.png") if meditation else preload("res://assets/characters/crossgate/qigong/charge.png")
 combo_glow.hframes=7 if meditation else 8
 combo_glow.vframes=1 if meditation else 2
 combo_glow.pixel_size=Proportions.GOEMON_HEIGHT*(5.5/340.0 if meditation else 5.0/345.0)
 combo_glow.offset=Vector2(4,-2) if meditation else Vector2(21.5,-8.5)

func sync_standing_size():
 body_height_pixels=Proportions.crossgate_body_pixels(character,shin_skin if Roster.is_shin(character) else variant_skin if Roster.has_variant_skins(character) else kaz_skin)
 sprite.pixel_size=Proportions.GOEMON_HEIGHT/body_height_pixels

func standing_height()->float:
 return Proportions.GOEMON_HEIGHT*sprite.global_basis.y.length()

static func profile(root:String)->Dictionary:
 if not profiles.has(root):
  var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root+"motions.json"))
  var definitions:Array=attack_audio.profiles.get(root,[])
  var stances=[data]+data.get("weapons",[])
  var ids={}
  for i in definitions.size():
   for key in definitions[i]:
    stances[i].clips[key].audio_cues=definitions[i][key]
    var impacts:Array=definitions[i][key][1]
    var effects=[]
    # One-contact skills keep a selected effect carried by a later normal hit.
    var single=impacts[0]
    for id in impacts:
     var layered=attack_audio.mix_recipes.has(str(int(id)))
     effects.append(id if layered else 0)
     if layered:single=id
    stances[i].clips[key].effect_impacts=effects
    stances[i].clips[key].single_strike_impact=single
    for cues in definitions[i][key]:
     for id in cues:ids[int(id)]=true
  for stance in stances:
   var source:String=stance.get("key",data.get("key",""))
   for pose in stance.clips:
    if pose.begins_with("5:"):
     stance.clips[pose].wind_motions=wind_motions.get(source,[])
     stance.clips[pose].wind_source=source
  data.source_audio_ids=ids.keys()
  var art_path=root+"art.json"
  if FileAccess.file_exists(art_path):
   var json=JSON.new()
   var valid=json.parse(FileAccess.get_file_as_string(art_path))==OK
   var problem=SpriteArt.apply(root,data,json.data) if valid else json.get_error_message()
   if not problem.is_empty():push_warning(art_path+": "+problem+" Using original art.")
  profiles[root]=data
 return profiles[root]

func attack_sound(contact:bool,index:int=0,attack:Dictionary={})->AudioStream:
 if attack.is_empty():attack=body_clip(5,"5:%d"%direction())
 var cues:Array=attack.get("audio_cues",[])
 if cues.is_empty():return null
 var ids:Array=cues[1 if contact else 0]
 return gear_sounds.get(int(ids[mini(index,ids.size()-1)])) if not ids.is_empty() else null

func single_strike_sound(attack:Dictionary={})->AudioStream:
 if attack.is_empty():attack=body_clip(5,"5:%d"%direction())
 return gear_sounds.get(int(attack.single_strike_impact)) if attack.has("single_strike_impact") else attack_sound(true,0,attack)

func attack_effect_sound(index:int,attack:Dictionary)->AudioStream:
 var effects:Array=attack.get("effect_impacts",[])
 var id=int(effects[mini(index,effects.size()-1)]) if not effects.is_empty() else 0
 return gear_sounds.get(id) if id!=0 else null

func melee_wind_motion(index:int)->String:
 if current_weapon()=="unarmed":return "puff"
 var cues:Array=body_clip(5,"5:%d"%direction()).get("wind_motions",[])
 # shortcut: unreviewed source poses use a neutral puff until their weapon motion is reviewed.
 return str(cues[mini(index,cues.size()-1)]) if not cues.is_empty() else "puff"

func prepare_body_materials(textures:Array):
 for texture in textures:
  if body_materials.has(texture):continue
  var material=ShaderMaterial.new();material.shader=BODY_SHADER
  material.set_shader_parameter("sprite_texture",texture)
  body_materials[texture]=material
  var shadow=ShaderMaterial.new();shadow.shader=SHADOW_SHADER
  shadow.set_shader_parameter("sprite_texture",texture)
  shadow_materials[texture]=shadow

func refresh_counter_theme():
 if shin_counter_fx==null:return
 shin_counter_fx.texture=load(CROSSGATE_ROOT+"shin/900050/counter-blue.png") if shin_skin==900050 else preload("res://assets/characters/crossgate/shin/counter.png")

func prepare_attack_audio(data:Dictionary):
 for id in data.get("audio",{}):gear_sounds[int(id)]=load(data.audio[id])
 for id in data.get("source_audio_ids",[]):
  if not attack_samples.has(id):
   var path:String=attack_audio.samples[str(id)]
   if path.is_empty():
    var silence=AudioStreamWAV.new();silence.format=AudioStreamWAV.FORMAT_16_BITS;silence.data=PackedByteArray([0,0])
    attack_samples[id]=silence
   else:attack_samples[id]=load(path)
  gear_sounds[id]=attack_samples[id]

func load_appearance(root:String,weapon_override:bool=false):
 body_materials.clear()
 shadow_materials.clear()
 if not weapon_override:native_root=root
 appearance=profile(root)
 gear_sounds.clear()
 prepare_attack_audio(appearance)
 atlases.clear()
 for path in SpriteArt.paths(root,appearance):atlases.append(load(path))
 weapon_combo_clips.clear();weapon_combo_step=-1;weapon_combo_next=0
 jump_guard_atlas=null
 if player_jump and not appearance.clips.has("9:0"):
  var guard_path=(ROOT if fighter.get("root","")=="kazi" else root)+"jump-guard.png"
  if ResourceLoader.exists(guard_path):jump_guard_atlas=load(guard_path)
 prepare_body_materials(atlases)
 prepare_body_materials(qi_atlas)
 if jump_guard_atlas!=null:prepare_body_materials([jump_guard_atlas])
 refresh_counter_theme()
 if cosmetic_layers!=null:prepare_cosmetic_heads()

func prepare_weapon_combo():
 if not player_jump or not weapon_combo_clips.is_empty():return
 var routes:Dictionary=preload("res://scripts/forest/equipment.gd").allowed(character,get_parent().game.settings)
 var sword_clips={}
 for facing in 8:
  var key="5:%d"%facing
  sword_clips[key]=body_clip(5,key)
 weapon_combo_clips.append(sword_clips)
 for weapon in ["polearm","axe"]:
  var route:Dictionary=routes[weapon]
  var donor_root:String=route.get("root",native_root)
  var data=profile(donor_root)
  var donor:Dictionary=data if route.has("root") or int(route.native)==0 else data.weapons[int(route.native)-1]
  prepare_attack_audio(data)
  var page_offset=0
  if donor_root!=gear_route.get("root",native_root):
   page_offset=atlases.size()
   for path in SpriteArt.paths(donor_root,data):atlases.append(load(path))
  var clips={}
  for facing in 8:
   var key="5:%d"%facing
   var base:Dictionary=sword_clips[key]
   var source:Dictionary=donor.clips[key]
   var attack=base.duplicate()
   for field in ["audio_cues","effect_impacts","single_strike_impact"]:attack[field]=source[field]
   var frames=[]
   var contacts:Array=base.get("contacts",[])
   var contact=floori(float(base.get("contact",float(contacts[0])/base.duration if not contacts.is_empty() else 5.0/11.0))*base.frames.size())
   var source_contact=floori(float(source.contact)*source.frames.size())
   # Align the borrowed strike and recovery with the equipped sword's hit clock.
   for i in base.frames.size():
    var index=roundi(float(i)*source_contact/maxi(1,contact)) if i<=contact else source_contact+roundi(float(i-contact)*(source.frames.size()-1-source_contact)/maxi(1,base.frames.size()-1-contact))
    var frame:Array=source.frames[index].duplicate()
    frame[0]+=page_offset;frames.append(frame)
   attack.frames=frames;clips[key]=attack
  weapon_combo_clips.append(clips)
 prepare_body_materials(atlases)
 if cosmetic_layers!=null:prepare_cosmetic_heads()

func advance_weapon_combo():
 if weapon_combo_clips.is_empty() or gear_weapon!="three-weapon":return
 weapon_combo_step=weapon_combo_next
 weapon_combo_next=(weapon_combo_next+1)%weapon_combo_clips.size()
 current_clip="";current_frame=-1

func set_shin_skin(id:int):
 if id==shin_skin:return
 restore_gear_weapon()
 shin_skin=id
 load_appearance(Roster.ShinSkins.root(id))
 sync_standing_size()
 select_stance(int(fighter.get("start_weapon",0)))
 if is_instance_valid(combat):
  combat.clear_shin_counter()
 var hero=get_parent()
 if hero.character_id==character:hero.spell_loadout.refresh_numbered_slots()
 current_clip="";current_frame=-1
 if player_jump and show_jump_pose(locomotion.grounded,locomotion.vertical):return
 show_pose(0,0,true)

func select_stance(index:int):
 var weapons:Array=appearance.get("weapons",[])
 shin_weapon_index=clampi(index,0,weapons.size())
 if shin_weapon_index>0:motions=weapons[shin_weapon_index-1]
 elif fighter.has("skin_set") or fighter.has("skins") or appearance.has("source_weapons") or not weapons.is_empty():motions=appearance
 fighter.strike=Roster.CROSSGATE[character].strike
 if appearance.has("source_weapons"):
  fighter.strike="bow" if motions.weapon=="bow" else "staff" if character==Roster.RUBY_ID and motions.weapon=="staff" else "timed"
 refresh_native_skills()

func refresh_native_skills():
 if beast_master:
  native_skills={}
  return
 var identity=Roster.CROSSGATE[character].duplicate()
 if gear_external:
  identity.throwing=false
  if identity.get("strike","")=="bow" and motions.weapon!="bow":identity.strike="timed"
 native_skills=Skills.crossgate_native_skills(identity,motions.get("weapon",""))

func restore_gear_weapon():
 clear_beast_cast()
 if not gear_external:
  if not gear_weapon.is_empty():
   if fighter.get("throwing",false):maze_weapon=get_parent().game.skin_weapon(character,primary_throwing_weapon,Roster.MazeWeapon.FIST)
   elif can_swap_stance():select_stance(get_parent().game.skin_weapon(character,int(fighter.get("start_weapon",0)),appearance.weapons.size()))
  gear_weapon="";gear_route={};return
 gear_external=false;gear_weapon="";gear_route={};gear_sounds.clear()
 fighter=Roster.CROSSGATE[character].duplicate()
 load_appearance(native_root)
 motions=appearance if fighter.has("skins") or fighter.has("skin_set") else profile(CROSSGATE_ROOT+fighter.get("motion_root",fighter.root)+"/")
 select_stance(int(fighter.get("start_weapon",0)))
 if fighter.get("throwing",false):maze_weapon=get_parent().game.skin_weapon(character,primary_throwing_weapon,Roster.MazeWeapon.FIST)
 elif can_swap_stance():select_stance(get_parent().game.skin_weapon(character,int(fighter.get("start_weapon",0)),appearance.weapons.size()))

func apply_gear_weapon(weapon:String,route:Dictionary)->bool:
 if weapon==gear_weapon and route==gear_route:return false
 weapon_combo_step=-1;weapon_combo_next=0
 restore_gear_weapon()
 if not weapon.is_empty():
  if route.has("root"):
   gear_external=true
   load_appearance(route.root,true);motions=appearance
   fighter=Roster.CROSSGATE[character].duplicate()
   var family:String=route.get("base_weapon",weapon)
   fighter.strike="bow" if family=="bow" else "throw" if family in ["kunai","boomerang"] else "timed"
   fighter.throwing=false;maze_weapon=Roster.MazeWeapon.KATANA
  elif fighter.get("throwing",false):maze_weapon=int(route.native)
  else:select_stance(int(route.native))
 gear_weapon=weapon;gear_route=route
 if weapon=="three-weapon":prepare_weapon_combo()
 refresh_native_skills()
 current_clip="";current_frame=-1
 if sprite!=null:
  clear_kagerou_dodge()
  if not player_jump or not show_jump_pose(locomotion.grounded,locomotion.vertical):show_pose(0,clock,true)
 return true

func current_weapon()->String:
 if not gear_weapon.is_empty():return str(gear_route.get("base_weapon",gear_weapon))
 if fighter.get("throwing",false):return ["sword","kunai","unarmed"][maze_weapon]
 return str(motions.get("weapon",fighter.get("weapon","sword")))

func shin_has_skills()->bool:
 return fighter.get("weapon_skills",false) and motions.get("weapon","") in ["sword","polearm","axe"]

func show_shin_counter(origin:Vector3,attack:Dictionary,basic:bool=false):
 if stat_counter_shadow!=null:stat_counter_shadow.hide()
 if not kagerou_shadows.is_empty():kagerou_shadows[0].hide()
 counter_is_basic=basic
 shin_counter_linger=0.0
 var shadow=stat_counter_shadow if basic else kagerou_shadows[0]
 stamp_kagerou(shadow,origin-get_parent().global_position)
 shadow.global_position=origin+(body.global_position-get_parent().global_position)
 shin_counter_frame=-1
 pose_shin_counter(attack,0.0)
 if basic:
  if shin_counter_fx!=null:shin_counter_fx.hide()
  return
 shin_counter_age=0.0
 shin_counter_fx.frame=0
 shin_counter_fx.global_transform=body.global_transform
 shin_counter_fx.global_position=origin+body.global_basis*Vector3.UP*Proportions.GOEMON_HEIGHT*.55
 shin_counter_fx.modulate.a=.35 if get_parent().game.settings.get("reduced_flashes",false) else 1.0
 shin_counter_fx.show()

func pose_shin_counter(attack:Dictionary,time:float):
 var frames:Array=attack.frames
 var frame=clampi(floori(time/float(attack.duration)*frames.size()),0,frames.size()-1)
 if frame==shin_counter_frame:return
 shin_counter_frame=frame
 apply_frame(stat_counter_shadow if counter_is_basic else kagerou_shadows[0],frames[frame],atlases)

func tick_shin_counter(delta:float,rate:float):
 if shin_counter_linger>0:
  shin_counter_linger=maxf(0,shin_counter_linger-delta)
  if shin_counter_linger==0:(stat_counter_shadow if counter_is_basic else kagerou_shadows[0]).hide()
 if shin_counter_fx==null or not shin_counter_fx.visible:return
 shin_counter_age+=delta*rate
 var frame=floori(shin_counter_age/SHIN_COUNTER_FRAME_TIME)
 if frame>=SHIN_COUNTER_FRAMES:shin_counter_fx.hide()
 else:shin_counter_fx.frame=frame

func can_swap_stance()->bool:
 return not appearance.get("weapons",[]).is_empty()

func swap_stance():
 set_stance((shin_weapon_index+1)%(appearance.weapons.size()+1))

func set_stance(index:int):
 select_stance(index)
 var action=int(current_clip.get_slice(":",0))
 current_clip="";current_frame=-1
 if player_jump and show_jump_pose(locomotion.grounded,locomotion.vertical):return
 if action in [1,3]:
  show_pose(action,phase*float(motions.clips["%d:0"%action].duration),true)
 else:show_pose(0,clock,true)

func set_kaz_skin(id:int):
 id=Skins.model_skin(id)
 if id==kaz_skin:return
 if is_instance_valid(combat) and get_parent().model==self:combat.clear_shin_counter()
 restore_gear_weapon()
 if current_clip.begins_with("qi:"):show_pose(0,0,false)
 var action=int(current_clip.get_slice(":",0))
 var attack_progress=(current_frame+.5)/appearance.clips[current_clip].frames.size() if action==5 else 0.0
 kaz_skin=id
 load_appearance(ROOT if id==Skins.DEFAULT else ROOT+"skins/%d/"%id)
 sync_standing_size()
 if action==5:current_frame=floori(attack_progress*appearance.clips[current_clip].frames.size())
 for shadow in kagerou_shadows:
  shadow.hide();shadow.texture=null
 if not current_clip.is_empty():draw_pose(action)

func set_variant_skin(id:int):
 if id==variant_skin:return
 if is_instance_valid(combat) and get_parent().model==self:combat.clear_shin_counter()
 restore_gear_weapon()
 variant_skin=id
 load_appearance(Roster.skin_root(character,id))
 sync_standing_size()
 select_stance(0)
 clear_kagerou_dodge()
 for shadow in kagerou_shadows:shadow.texture=null
 current_clip="";current_frame=-1
 if player_jump and show_jump_pose(locomotion.grounded,locomotion.vertical):return
 show_pose(0,clock,true)

func show_kagerou_dodge(direction:Vector3,afterimages:bool=true,offset_sprite:bool=true)->bool:
 if (afterimages and kagerou_shadows.is_empty()) or kagerou_tick>=0:return false
 if kagerou_dash_left>0:clear_kagerou_dodge()
 var away=Vector3(direction.x,0,direction.z).normalized()
 if away.is_zero_approx():away=-get_parent().facing
 kagerou_step=away*KAGEROU_STEP_PIXELS*sprite.pixel_size*global_basis.x.length()
 kagerou_time=0
 kagerou_tick=0
 kagerou_afterimages=afterimages
 kagerou_offset_sprite=offset_sprite
 return true

func stamp_kagerou(shadow:Sprite3D,offset_:Vector3=Vector3.ZERO):
 shadow.texture=sprite.texture
 shadow.material_override=shadow_materials[sprite.texture]
 shadow.set_instance_shader_parameter("grounded",sprite.get_instance_shader_parameter("grounded"))
 shadow.pixel_size=sprite.pixel_size
 shadow.region_rect=sprite.region_rect
 shadow.offset=sprite.offset
 shadow.global_transform=sprite.global_transform
 shadow.global_position+=offset_
 shadow.show()

func show_kagerou_dash(travel:Vector3):
 clear_kagerou_dodge()
 if kagerou_shadows.is_empty() or travel.length_squared()<.01:return
 kagerou_dash_left=float(KAGEROU_GHOST_TICKS)/KAGEROU_HZ
 for i in 3:stamp_kagerou(kagerou_shadows[i],travel*(i/3.0))

func tick_kagerou_dodge(delta:float):
 if kagerou_dash_left>0:
  kagerou_dash_left-=delta
  if kagerou_dash_left<=.00001:clear_kagerou_dodge()
 if kagerou_tick<0:return
 kagerou_time+=delta
 var end_tick=mini(floori(kagerou_time*KAGEROU_HZ+.00001),KAGEROU_HOME_TICK+KAGEROU_GHOST_TICKS if kagerou_afterimages else KAGEROU_HOME_TICK)
 while kagerou_tick<end_tick:
  kagerou_tick+=1
  if kagerou_afterimages and kagerou_tick%KAGEROU_EMIT_TICKS==1:
   var shadow=kagerou_shadows[(kagerou_tick>>1)%KAGEROU_SHADOWS]
   shadow.visible=kagerou_tick<KAGEROU_HOME_TICK
   if shadow.visible:stamp_kagerou(shadow)
  if kagerou_offset_sprite and kagerou_tick<KAGEROU_HOME_TICK:
   var steps=mini(kagerou_tick,KAGEROU_BACK_TICKS)-maxi(0,kagerou_tick-KAGEROU_RETURN_TICK)
   sprite.position=body.global_basis.inverse()*kagerou_step*steps
  elif kagerou_tick==KAGEROU_HOME_TICK:sprite.position=Vector3.ZERO
 if kagerou_tick==(KAGEROU_HOME_TICK+KAGEROU_GHOST_TICKS if kagerou_afterimages else KAGEROU_HOME_TICK):clear_kagerou_dodge()

func clear_kagerou_dodge():
 kagerou_tick=-1
 kagerou_dash_left=0.0
 sprite.position=Vector3.ZERO
 for shadow in kagerou_shadows:shadow.hide()

func direction()->int:
 return direction_for(get_parent().facing)

func direction_for(facing:Vector3)->int:
 var camera=get_viewport().get_camera_3d()
 if camera==null:return 4
 var right=Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
 var back=Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
 # This sprite's order is NW, N, NE, E, SE, S, SW, W.
 return posmod(roundi(atan2(facing.dot(right),-facing.dot(back))*8/TAU)+1,8)

func show_pose(action:int,time:float,loop:bool):
 if kagerou_tick>=0 and kagerou_tick<KAGEROU_HOME_TICK and action in [0,1,3]:
  action=0 if kagerou_tick>KAGEROU_BACK_TICKS and kagerou_tick<=KAGEROU_RETURN_TICK else 1
  time=kagerou_time;loop=true
 var facing_index=direction()
 var key="%d:%d"%[action,facing_index]
 var clip:Dictionary=body_clip(action,key) if action in [5,7] else motions.clips[key]
 var progress=time/maxf(.001,float(clip.duration))
 var frame=posmod(floori(progress*clip.frames.size()),clip.frames.size()) if loop else clampi(floori(progress*clip.frames.size()),0,clip.frames.size()-1)
 show_frame(action,key,frame)

func show_frame(action:int,key:String,frame:int):
 if key==current_clip and frame==current_frame:return
 current_clip=key;current_frame=frame
 draw_pose(action)

func body_clip(action:int,key:String)->Dictionary:
 if action==5 and weapon_combo_step>=0:return weapon_combo_clips[weapon_combo_step][key]
 var clips:Dictionary=motions.clips if gear_external or fighter.has("skin_set") or can_swap_stance() else appearance.clips
 if not gear_external and maze_weapon!=Roster.MazeWeapon.KATANA:
  if action==5 and maze_weapon==Roster.MazeWeapon.FIST:return clips["fist:"+key]
  if action not in [5,7]:return clips["dagger:"+key]
 return clips[key]

func normal_attack_pattern(facing:Vector3=Vector3.ZERO)->Dictionary:
 var pose=7 if Roster.has_crossgate_throws(character) and daggers else 5
 var attack=body_clip(pose,"%d:%d"%[pose,direction() if facing.is_zero_approx() else direction_for(facing)])
 var contacts:Array=[]
 var style:String=fighter.strike
 if pose==7:contacts=[float(attack.duration)*int(appearance.release_frame)/attack.frames.size()]
 elif style in ["bow","throw"]:contacts=[float(attack.release)]
 elif style=="staff":
  for cue in attack.get("sounds",[]):
   if int(cue.id)==139:contacts.append(float(cue.atMs)/1000.0)
 elif attack.has("contacts"):contacts=attack.contacts
 elif style=="timed":contacts=[float(attack.duration)*float(attack.contact)]
 else:contacts=[.6*5.0/11.0,.6*6.0/11.0]
 var sounds:Array=[]
 for cue in attack.get("sounds",[]):
  if int(cue.get("id",0))!=139:sounds.append(float(cue.atMs)/1000.0)
 if sounds.is_empty() and style=="timed":sounds=[float(attack.duration)*float(attack.swing)]
 if style in ["bow","throw"]:sounds=[float(attack.draw)]
 return {"pose":pose,"attack":attack,"duration":float(attack.duration),"contacts":contacts,"sounds":sounds,"projectiles":int(fighter.get("kunai_count",1)) if pose==7 and not beast_master else 1}

func draw_pose(action:int):
 if action==9 and jump_guard_atlas!=null:
  var kaz=fighter.get("root","")=="kazi"
  var cell=GUARD_CELL if kaz else WEAPON_GUARD_CELL
  var origin=GUARD_ORIGIN if kaz else WEAPON_GUARD_ORIGIN
  var row:int=GUARD_ROW[kaz_skin] if kaz else shin_weapon_index if can_swap_stance() else int(maze_weapon!=Roster.MazeWeapon.KATANA)
  sprite.texture=jump_guard_atlas
  sprite.material_override=body_materials[jump_guard_atlas]
  sprite.region_rect=Rect2(Vector2(int(current_clip.get_slice(":",1)),row)*cell,cell)
  sprite.offset=origin-cell*.5+Vector2(0,FEET_OFFSET_PIXELS)
  sync_food_glow_frame()
  return
 var pose=body_clip(action,current_clip)
 apply_frame(sprite,pose.frames[current_frame],atlases)

func set_maze_weapon(weapon:int):
 if maze_weapon==weapon:return
 maze_weapon=weapon
 if current_clip.begins_with("5:") or current_clip.begins_with("qi:"):show_pose(0,0,false)
 elif not current_clip.is_empty():draw_pose(int(current_clip.get_slice(":",0)))

func apply_frame(target:Sprite3D,data:Array,textures:Array[Texture2D]):
 target.texture=textures[int(data[0])]
 target.material_override=(body_materials if target==sprite else shadow_materials)[target.texture]
 target.region_rect=Rect2(data[1],data[2],data[3],data[4])
 target.offset=Vector2(float(data[5])+float(data[3])*.5,FEET_OFFSET_PIXELS-float(data[6])-float(data[4])*.5)
 if target==sprite:sync_food_glow_frame()

func sync_food_glow_frame():
 if food_glow_tint.a<=0:return
 var dimensions=sprite.texture.get_size()
 var first=sprite.region_rect.position/dimensions
 var last=sprite.region_rect.end/dimensions
 sprite.set_instance_shader_parameter("food_frame",Vector4(first.x,first.y,last.x,last.y))

func set_food_glow(tint:Color):
 if food_glow_tint==tint:return
 food_glow_tint=tint
 sprite.set_instance_shader_parameter("food_glow",tint)
 if tint.a>0:sync_food_glow_frame()


func reset_jump_pose():
 jump_count=0
 jump_age=-1.0
 jump_landing_left=0.0

func update_jump_pose(delta:float,grounded:bool,vertical:float):
 var hero=get_parent()
 if hero.flying:
  reset_jump_pose()
 elif grounded:
  jump_count=0
  jump_landing_left=JUMP_LANDING if jump_age>=0 else maxf(0,jump_landing_left-delta)
  jump_age=-1.0
 else:
  jump_landing_left=0.0
  if vertical>0 and (hero.jumps_used>jump_count or is_equal_approx(hero.wall_jump_recovery,hero.WALL_JUMP_RECOVERY)):
   jump_count=hero.jumps_used
   jump_age=0.0
  elif jump_age>=0:jump_age+=delta

func show_jump_pose(grounded:bool,vertical:float)->bool:
 var action:int
 var frame:int
 if grounded and locomotion.jump_compression>0:
  action=9
 elif grounded and jump_landing_left>0:
  action=10
  var impact=jump_landing_left>JUMP_LANDING-.10
  frame=5 if impact else 3
  # Uru turns away midway through his fall; use the earlier forward brace.
  if character==Roster.RUBY_ID:frame=2 if impact else 0
 elif not grounded and jump_age>=0:
  if vertical>0 and jump_age<JUMP_FLINCH_END:
   var first_takeoff=jump_count==1 and get_parent().wall_jump_recovery<=0
   action=9 if first_takeoff and jump_age<JUMP_GUARD_RISE else 8
  else:
   action=3
   frame=3 if vertical>0 else 15
 else:return false
 if action==9 and jump_guard_atlas==null and not motions.clips.has("9:0"):action=8
 var key="%d:%d"%[action,direction()]
 if action==3 or (action==10 and character!=Roster.RUBY_ID):
  # Keep the approved pose fraction on stances with fewer frames than Kaz.
  var last:int=body_clip(action,key).frames.size()-1
  frame=roundi(frame*last/(17.0 if action==3 else 11.0))
 show_frame(action,key,frame)
 return true

func preview_beast_cast():
 if beast_cast_left<=0 and motions.clips.has("6:0"):beast_cast_wait_left=BEAST_CAST_WAIT

func clear_beast_cast():
 beast_cast_left=0.0;beast_cast_wait_left=0.0

func animate(delta:float,speed:float,grounded:bool,vertical:float,_attack:float,_heavy:bool,_combo:int,dodge:bool):
 clock+=delta;cast_owner=null;cast_clock=0
 beast_cast_left=maxf(0,beast_cast_left-delta)
 beast_cast_wait_left=maxf(0,beast_cast_wait_left-delta)
 if locomotion.grounded!=grounded:sprite.set_instance_shader_parameter("grounded",grounded)
 locomotion.grounded=grounded;locomotion.vertical=vertical
 if player_jump:update_jump_pose(delta,grounded,vertical)
 locomotion.actual_speed=Vector2(locomotion_velocity.x,locomotion_velocity.z).length()
 var travel_speed=locomotion.actual_speed if grounded else speed
 var action=1 if travel_speed<=2.5 else 3
 var running=is_instance_valid(combat) and combat.mode=="primary_approach" and combat.state.get("approach_dashing",false)
 if not running and not get_parent().ai_controlled and (not Input.is_action_pressed("sprint") or Input.is_action_pressed("walk_modifier")):
  action=1
 if grounded and travel_speed>.1:
  var before=phase
  var stride=(WALK_STRIDE if action==1 else RUN_STRIDE)*global_basis.x.length()
  phase+=delta*travel_speed/maxf(.001,stride)
  if travel_speed>.25:locomotion.step_events+=floori(phase*2)-floori(before*2)
  phase=fposmod(phase,1.0)
 if is_instance_valid(combat) and combat.mode in ["attack","combined_wait","hurt","dead"]:
  var pose=int(combat.clip) if combat.mode in ["attack","combined_wait"] else 8 if combat.mode=="hurt" else 10
  if pose==6 and (not motions.clips.has("6:0") or (combat.ticket.action!="shin_meditation" and (fighter.strike=="bow" or fighter.get("weapon_skills",false)))):pose=0
  show_pose(pose,combat.elapsed,false)
 elif get_parent().crossgate_guarding():show_frame(9,"9:%d"%direction(),0)
 elif player_jump and not dodge and (kagerou_tick<0 or kagerou_tick>=KAGEROU_HOME_TICK) and show_jump_pose(grounded,vertical):return
 elif not dodge and kagerou_tick<0 and (beast_cast_left>0 or beast_cast_wait_left>0):
  if beast_cast_left<=0:
   beast_cast_wait_left=0.0;beast_cast_left=BEAST_CAST_DURATION
  var progress=1.0-beast_cast_left/BEAST_CAST_DURATION
  show_pose(6,progress*float(motions.clips["6:0"].duration),false)
 elif travel_speed>.1:
  # Keep the original frame order and clip duration through direction changes.
  show_pose(action,phase*float(motions.clips["%d:0"%action].duration),true)
 else:
  var hero=get_parent()
  var recovery=hero.spell_loadout.instances.get(recovery_key) if not hero.ai_controlled else null
  if recovery!=null and recovery.controller.cast_left>0 and motions.clips.has("6:0"):
   var progress:float=1.0-recovery.controller.cast_left/recovery.controller.WINDUP
   show_pose(6,progress*float(motions.clips["6:0"].duration),false)
  else:show_pose(0,clock,true)

func animate_qi_blast(_delta:float,progress:float):
 if progress<0:
  show_pose(0,0,false)
  return
 var key="5:%d"%direction()
 var maze=Roster.has_crossgate_throws(character) and not gear_external
 if maze or (not qi_punch.is_empty() and kaz_skin==Skins.DEFAULT):
  var punch:Dictionary=appearance.clips["fist:"+key] if maze else qi_punch.clips[key]
  var contact:float=7.0 if maze else qi_punch.contact_frame
  var last:int=14 if maze else punch.frames.size()-1
  var frame=clampi(floori(qi_attack_time(progress,contact,last)+.00001),0,last)
  if current_clip!="qi:"+key or current_frame!=frame:
   current_clip="qi:"+key;current_frame=frame
   apply_frame(sprite,punch.frames[frame],atlases if maze else qi_atlas)
  return
 var pose=body_clip(5,key)
 var contact:float=float(pose.contacts[0]) if pose.has("contacts") else float(pose.duration)*float(pose.get("contact",.44))
 show_pose(5,qi_attack_time(progress,contact,minf(float(pose.duration),contact+.12)),false)

func animate_spell(delta:float,spell:Node):
 if spell.spec.id in [Skills.COMBO,Skills.BEE_FLURRY] and spell.controller.state.has("combo_pattern") and spell.controller.clip!="6":
  show_pose(spell.controller.state.combo_pattern.get("pose",5),spell.controller.elapsed,false)
  return
 if spell.spec.id in [Skills.COMBO,Skills.BEE_FLURRY]:
  if spell.controller.clip=="6":show_pose(0,0,false)
  else:
   var attack=body_clip(5,"5:0")
   var contact:float=float(attack.contacts[0]) if attack.has("contacts") else float(attack.get("release",float(attack.duration)*float(attack.get("contact",5.0/11.0))))
   show_pose(5,qi_attack_time(spell.controller.combo_progress(),contact,float(attack.duration)),false)
  return
 if Roster.has_crossgate_throws(character) and spell.spec.id=="blademaster/mirror-image":
  show_pose(0,0,false)
  return
 if not motions.clips.has("6:0") and spell.spec.id!=Skills.MOON:
  show_pose(0,0,false)
  return
 if spell.spec.id=="uru/spirit":
  var skill:Node=spell.controller
  var progress=1.0-skill.charge_left/skill.SPIRIT_DURATION
  show_pose(6,progress*float(motions.clips["6:0"].duration)+.000001,false)
  return
 if spell.spec.id=="kazi/moon":
  var skill:Node=spell.controller
  var attack_time:float=skill.moon_elapsed-skill.MOON_ATTACK_START
  if attack_time<0:
   show_pose(0,0,false)
   return
  var sword:Dictionary=body_clip(5,"5:0")
  var cut_pose=float(sword.contacts[0])/float(sword.duration) if sword.has("contacts") else float(sword.get("contact",5.0/11.0))
  var release:float=skill.MOON_RELEASE-skill.MOON_ATTACK_START
  var progress=lerpf(0,cut_pose,attack_time/release)
  if attack_time>=release:
   var recovery:float=(skill.moon_elapsed-skill.MOON_RELEASE)/(skill.MOON_DURATION-skill.MOON_RELEASE)
   progress=lerpf(cut_pose,1.0,recovery)
  show_pose(5,progress*float(motions.clips["5:0"].duration)+.000001,false)
  return
 if cast_owner!=spell:cast_owner=spell;cast_clock=0
 var crossgate=spell.spec.id.begins_with("kazi/")
 var rate=float(spell.controller.get("cast_speed")) if crossgate else 1.0
 if spell.spec.id=="blademaster/mirror-image":rate=float(spell.controller.ticket.get("shin_cast_speed",1.0))
 if fighter.get("magic","")=="ruby" and crossgate:
  rate*=float(motions.clips["6:0"].duration)/(spell.controller.CHARGE if spell.controller.kind.is_empty() else spell.controller.ELEMENT_CHARGE)
 cast_clock+=delta*rate;show_pose(6,cast_clock,fighter.get("magic","")!="ruby")
 if not spell.busy():cast_owner=null
func _process(delta:float):
 if is_instance_valid(combat) and combat.mode=="dead":
  clear_beast_cast()
  combat.elapsed+=delta;show_pose(10,combat.elapsed,false)
 if cosmetic_layers!=null and is_visible_in_tree() and not current_clip.is_empty():cosmetic_layers.update(delta,sprite,current_clip,locomotion.grounded)
func sync_skeleton():pass
func set_cloak(_equipped:bool,_gold:bool):pass
func combat_pose(_attack:float,_heavy:bool,_combo:int,_dodge:bool):pass
func set_surge(_active:bool):pass
func apply_skin(_id:String):pass
