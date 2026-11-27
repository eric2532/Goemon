extends Node3D
## Bounded cosmetics only. Simulation never reads these pools or their capacity.
const DragonFX=preload("res://assets/rogue/scripts/effects.gd")
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const Finale=preload("res://scripts/forest/dark_lumina_3_kit.gd")
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Hound=preload("res://scripts/forest/crowd/hound_sprites.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Slime=preload("res://scripts/forest/crowd/slime_sprites.gd")
const Zombie=preload("res://scripts/forest/crowd/zombie_sprites.gd")
const Grave=preload("res://scripts/forest/crowd/grave_sprites.gd")
const Undersea=preload("res://scripts/forest/crowd/undersea_sprites.gd")
const UNDERSEA_BODY_HEIGHT=Hound.Dimensions.KAZ_HEIGHT*Hound.Dimensions.HEIGHTS.undersea[0]
const CursedSpells=preload("res://scripts/forest/crowd/cursed_guardian_spells.gd")
const Cursed=preload("res://scripts/forest/crowd/cursed_maze_sprites.gd")
const Decree=preload("res://scripts/forest/forest_holy_decree.gd")
const Ruby=preload("res://scripts/forest/crowd/ruby_boss_sprites.gd")
const Falken=preload("res://scripts/forest/crowd/falken_sprites.gd")
var boss_spell_clips={}
var boss_spell_sounds={}
const Habaru=preload("res://scripts/forest/crowd/habaru_sprites.gd")
const MoveAudio=preload("res://scripts/move_audio.gd")
const DAMAGE_FONT=preload("res://assets/characters/crossgate/hit_feedback/damage.fnt")
const HEAL_FONT=preload("res://assets/characters/crossgate/hit_feedback/healing.fnt")
const BATTLE_TEXT_FONT=preload("res://assets/ui/fonts/crossgate_battle.tres")
const GOLD_SPARKS=["gold-hit-a","gold-hit-b","gold-hit-c"]
const GOLD_FRAME_TIME=2.0/60
const CRITICAL_FRAME_TIME=4.0/60
const CRITICAL_SCALE=2.8
const COMBO_FRAME_TIME=4.0/60/.9
const SURE_STRIKE_FRAMES=9
const SURE_STRIKE_FRAME_TIME=6.0/60
const DOUBLE_EDGE_FRAMES=7
const DOUBLE_EDGE_FRAME_TIME=8.0/60
const SHIN_COMBO_FRAMES=7
const SHIN_COMBO_FRAME_TIME=8.0/60
const SHIN_COMBO_WIDTH=1.0
const TWO_BIRDS_FRAMES=6
const TWO_BIRDS_FRAME_TIME=5.0/60
const BLADE_DANCE_FRAMES=6
const BLADE_DANCE_FRAME_TIME=5.0/60
const WATER_BOOMERANG_FRAMES=3
const WATER_BOOMERANG_FRAME_TIME=1.0/12
const CONTACT_PIXEL_SIZE=.02
const ENEMY_GUARD_BREAK_WINDUP=723
const ENEMY_GUARD_RAISED=724
const GUARD_CUE_COLOR=Color("78caff")
const COMBO_BURST_SIZE_PIXELS=192.0
const SHIN_COMBO_SIZE_PIXELS=264.0
const MONSTER_SOUNDS={6:{"melee":preload("res://assets/characters/recovered_monsters/audio/vambee/bite_column2.wav"),"damage":preload("res://assets/characters/recovered_monsters/audio/vambee/hit_column2.wav")},9:{"melee":preload("res://assets/characters/recovered_monsters/audio/karate_wolf/kick.wav"),"damage":preload("res://assets/characters/recovered_monsters/audio/karate_wolf/hit_column1.wav"),"death":preload("res://assets/characters/recovered_monsters/audio/karate_wolf/death.wav")},14:{"melee":preload("res://assets/characters/recovered_monsters/audio/vambee/bite_column2.wav"),"death":preload("res://assets/characters/recovered_monsters/audio/vambee/vanish_column2.wav")},16:{"melee":preload("res://assets/characters/recovered_monsters/audio/haya_wolf/kick.wav"),"damage":preload("res://assets/characters/recovered_monsters/audio/haya_wolf/hit_column1.wav"),"death":preload("res://assets/characters/recovered_monsters/audio/haya_wolf/death.wav")}}
const MAX_EFFECTS=384
const MELEE_WIND_LIFE=.22
const PUNCH_WIND_LIFE=.26
const PUNCH_CREST_START=(.10+.18+.30)*2.0/1.65-1.0
static var melee_wind_mesh:QuadMesh
const FLY_SOUND=preload("res://assets/audio/crossgate/cgbtl06.wav")
const FLY_LIFE=.8
const FLY_DISTANCE=10.0
const FLY_HEIGHT=3.0
const MAX_CORPSES=128
const MAX_LABELS=32
const MAX_PROJECTILES=16384
var enemy_size=1.0
var dragon_scale=1.0
var effect_capacity=MAX_EFFECTS
var corpse_capacity=MAX_CORPSES
var label_capacity=MAX_LABELS
var native_packer:Object
var game:Node
var meshes:Dictionary={}
var effects:Array[Dictionary]=[]
var corpses:Array[Dictionary]=[]
var labels:Array[Label3D]=[]
var label_ages=PackedFloat32Array()
var voices:Array[AudioStreamPlayer3D]=[]
var batches:Dictionary={}
var corpse_batches:Dictionary={}
var projectile_batches:Dictionary={}
var last_serial=0
var projectile_count=0
var shield_count=0
var clock=0.0
var next_sound=0.0
var pet_audio:Dictionary={}
var pet_audio_frame=0
var next_gold_spark=0
var effect_snapshot:Dictionary={}
func configure(owner_:Node,shared_meshes:Dictionary={}):
 Dark.prepare();Finale.prepare()
 game=owner_;meshes=load("res://assets/characters/ally_crowd/visuals.res").get_meta("meshes")
 for key in ["ring","shield","spark","smoke"]:batches[key]=make_batch(meshes[key],"ArmyFX_"+key)
 var ice_shard=PrismMesh.new();ice_shard.size=Vector3(.17,.26,.1)
 var ice_paint=StandardMaterial3D.new();ice_paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ice_paint.albedo_color=Color("c6efff")
 ice_shard.material=ice_paint;batches["ice-thaw"]=make_batch(ice_shard,"ArmyFX_IceThaw")
 batches["melee-wind"]=make_batch(prepare_melee_wind(),"ArmyFX_MeleeWind")
 batches["melee-wind"].multimesh.instance_count=MAX_EFFECTS
 batches["melee-wind"].multimesh.visible_instance_count=0
 for sheet in [
  ["bodyguard-mark",preload("res://assets/characters/crossgate/hit_feedback/exclamation.png"),1],
  [GOLD_SPARKS[0],preload("res://assets/characters/crossgate/elements/wind-hit-1.png"),7],
  [GOLD_SPARKS[1],preload("res://assets/characters/crossgate/elements/wind-hit-2.png"),7],
  [GOLD_SPARKS[2],preload("res://assets/characters/crossgate/elements/wind-hit-3.png"),7],
  ["undersea-meditation",preload("res://assets/characters/crossgate/shin/meditation.png"),7],
  ["critical",preload("res://assets/characters/crossgate/hit_feedback/critical.png"),4],
  ["guard-break",preload("res://assets/characters/crossgate/hit_feedback/guard-break.png"),8],
  ["guard-break-ex",preload("res://assets/characters/crossgate/skill_tiers/111052.png"),8,2],
  ["guard-break-charge",preload("res://assets/characters/crossgate/skill_tiers/110103.png"),8,2],
  ["joint-glyph",preload("res://assets/characters/crossgate/hit_feedback/joint-attack.png"),17],
  ["kazi_combo",preload("res://assets/characters/crossgate/kazi/combo-impact.png"),7],
  ["shin_combo",preload("res://assets/characters/crossgate/shin/combo-ex.png"),SHIN_COMBO_FRAMES],
  ["shin_sure_strike",preload("res://assets/characters/crossgate/shin/sure-strike.png"),SURE_STRIKE_FRAMES],
  ["shin_double_edge",preload("res://assets/characters/crossgate/shin/double-edge.png"),DOUBLE_EDGE_FRAMES],
  ["shin_two_birds",preload("res://assets/characters/crossgate/shin/two-birds.png"),TWO_BIRDS_FRAMES],
  ["shin_two_birds_ex",preload("res://assets/characters/crossgate/skill_tiers/111054.png"),8,2],
  ["maze_assassination",preload("res://assets/characters/crossgate/maze/assassination-kill.png"),1],
  ["maze_blade_dance",preload("res://assets/characters/crossgate/maze/blade-dance-impact.png"),BLADE_DANCE_FRAMES],
  ["water-boomerang-wave",preload("res://assets/characters/crossgate/shin/900050/boomerang/contact-wave.png"),WATER_BOOMERANG_FRAMES,8],
 ]:
  var rows:int=sheet[3] if sheet.size()>3 else 1
  var mesh=QuadMesh.new();mesh.size=sheet[1].get_size()/Vector2(sheet[2],rows)*CONTACT_PIXEL_SIZE
  if sheet[0] in GOLD_SPARKS:mesh.size*=1.7
  var material=ShaderMaterial.new()
  material.shader=preload("res://assets/characters/crossgate/hit_feedback/critical.gdshader")
  material.set_shader_parameter("atlas",sheet[1]);material.set_shader_parameter("frame_count",float(sheet[2]))
  material.set_shader_parameter("frame_rows",float(rows))
  if sheet[0]=="critical":material.render_priority=1
  mesh.material=material;batches[sheet[0]]=make_batch(mesh,"ArmyFX_"+sheet[0])
  batches[sheet[0]].multimesh.instance_count=MAX_EFFECTS
  batches[sheet[0]].multimesh.visible_instance_count=0
 var charge=QuadMesh.new();charge.size=Vector2(345,357)*CONTACT_PIXEL_SIZE
 var charge_material=ShaderMaterial.new();charge_material.shader=preload("res://assets/characters/crossgate/hit_feedback/critical.gdshader")
 charge_material.set_shader_parameter("atlas",preload("res://assets/characters/crossgate/qigong/charge.png"))
 charge_material.set_shader_parameter("frame_count",8.0);charge_material.set_shader_parameter("frame_rows",2.0)
 charge.material=charge_material
 batches["undersea-charge"]=make_batch(charge,"ArmyFX_UnderseaCharge")
 batches["hound_summon"]=make_batch(Hound.summon_mesh(),"ArmyFX_HoundSummon")
 batches["hound_summon"].multimesh.instance_count=32
 batches["hound_summon"].multimesh.visible_instance_count=0
 for kind in preload("res://scripts/forest/forest_enemy_roles.gd").RIGID_TYPES:corpse_batches[kind]=make_batch(shared_meshes[kind] if shared_meshes.has(kind) else Soldier.make_mesh(kind),"ArmyCorpse_%d"%kind)
 if shared_meshes.has(Roles.CAVE_BEAR):corpse_batches[Roles.CAVE_BEAR]=make_batch(shared_meshes[Roles.CAVE_BEAR],"ArmyBearCorpses")
 if shared_meshes.has(Roles.GATEKEEPER_HOUND):corpse_batches[Roles.GATEKEEPER_HOUND]=make_batch(shared_meshes[Roles.GATEKEEPER_HOUND],"ArmyHoundCorpses")
 if shared_meshes.has(Roles.SLIME):corpse_batches[Roles.SLIME]=make_batch(shared_meshes[Roles.SLIME],"ArmySlimeCorpses",true)
 corpse_batches[Roles.VAMBEE_LEGS]=make_batch(Soldier.make_mesh(Roles.VAMBEE_LEGS),"ArmyDetachedLegs")
 for key in meshes:
  if key not in batches:projectile_batches[key]=make_batch(meshes[key],"ArmyProjectile_"+key)
 var ball=QuadMesh.new();ball.size=Vector2.ONE*2.304
 var ball_mat=ShaderMaterial.new();ball_mat.shader=preload("res://assets/characters/recovered_skullpion/effects/volley.gdshader");ball_mat.set_shader_parameter("atlas",preload("res://assets/characters/recovered_skullpion/effects/volley.png"));ball_mat.set_shader_parameter("frames",12.0);ball_mat.set_shader_parameter("billboard",true);ball_mat.set_shader_parameter("instanced",true);ball.material=ball_mat
 projectile_batches["skullpion-ball"]=make_batch(ball,"ArmySkullpionVolley")
 var qi=QuadMesh.new();qi.size=Vector2(5.04,4.9536)
 var qi_material=ShaderMaterial.new();qi_material.shader=preload("res://assets/characters/crossgate/qigong/orbs.gdshader")
 qi_material.set_shader_parameter("atlas",preload("res://assets/characters/crossgate/qigong/orbs.png"))
 qi_material.set_shader_parameter("instanced",true);qi.material=qi_material
 projectile_batches["undersea-qi"]=make_batch(qi,"ArmyUnderseaQi")
 for key in ["dragon-descent","dragon-eruption"]:
  var node=make_batch(preload("res://assets/rogue/effects/dragoon_energy_dragon.res"),"ArmyFX_"+key)
  var material=ShaderMaterial.new();material.shader=preload("res://assets/rogue/shaders/dragoon_energy.gdshader")
  material.set_shader_parameter("instanced",true);material.set_shader_parameter("descending",key=="dragon-descent");material.set_shader_parameter("intensity",.75)
  node.material_override=material;batches[key]=node
 var dragon=make_batch(preload("res://assets/rogue/effects/dragoon_energy_dragon.res"),"ArmyHuntingDragons")
 var dragon_material=ShaderMaterial.new();dragon_material.shader=preload("res://assets/rogue/shaders/dragoon_energy.gdshader")
 dragon_material.set_shader_parameter("hunting",true);dragon_material.set_shader_parameter("instanced",true)
 dragon.material_override=dragon_material;projectile_batches["dragon"]=dragon
 projectile_batches["dark-lumina-ball"]=make_batch(Dark.meshes.fire,"ArmyDarkLuminaFire")
 for key in ["impact","ember","shock_dome","shock_ring","fragment","stomp_wave"]:batches["dark-"+key]=make_batch(Dark.meshes[key],"ArmyDarkLumina_"+key)
 batches["dark-spin_dust"]=make_batch(meshes.smoke,"ArmyDarkLuminaSpinDust")
 batches["dark-spin_debris"]=make_batch(Dark.meshes.spin_debris,"ArmyDarkLuminaSpinDebris")
 for key in Finale.meshes:batches["finale-"+key]=make_batch(Finale.meshes[key],"ArmyFinale_"+key)
 for i in 6:projectile_batches["finale-shot%d"%i]=make_batch(Finale.shot_mesh(i),"ArmyFinaleShot%d"%i)
 projectile_batches["finale-shot6"]=make_batch(Finale.meshes.sword_cross,"ArmyFinaleCross")
 for batch in projectile_batches.values():hide_batch(batch)
 hide_batch(batches.shield)
 label_ages.resize(MAX_LABELS)
 for i in MAX_LABELS:
  var label=Label3D.new();label.font=DAMAGE_FONT;label.font_size=36;label.pixel_size=.00065;label.fixed_size=true;label.outline_size=0;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;label.hide();add_child(label);labels.append(label)
 for i in 8:
  var voice=AudioStreamPlayer3D.new();voice.stream=preload("res://assets/characters/thirstquencher/projectiles/gunshot_43a.wav");voice.max_distance=65;voice.unit_size=12;voice.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master";add_child(voice);voices.append(voice)
func make_batch(mesh:Mesh,label_:String,enemy_sprite:bool=false)->MultiMeshInstance3D:
 var node=MultiMeshInstance3D.new();node.name=label_;node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_custom_data=true;node.multimesh.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);Hound.apply_world_scale(node,game.model)
 if enemy_sprite:node.set_instance_shader_parameter("map_enemy_scale",Roles.MAP_ENEMY_SCALE)
 return node
func prepare_zombie_warning():
 if batches.has("zombie-warning"):return
 var ring:Mesh=meshes.ring
 var batch=make_batch(ring,"ArmyZombieWarning")
 var material:ShaderMaterial=ring.surface_get_material(0).duplicate()
 material.set_shader_parameter("custom_palette",true)
 material.set_shader_parameter("ink_tint",Color("ff6f37"))
 batch.material_override=material
 batches["zombie-warning"]=batch
var cave_sprites:Script
func prepare_undersea():
 if batches.has("undersea-afterimage"):return
 var mesh:QuadMesh=Undersea.make_mesh().duplicate()
 var material:ShaderMaterial=mesh.material.duplicate()
 material.shader=preload("res://assets/materials/hound_afterimage.gdshader")
 mesh.material=material
 batches["undersea-afterimage"]=make_batch(mesh,"ArmyFX_UnderseaAfterimage",true)
func prepare_ruby():
 Ruby.prepare_spells()
 boss_spell_clips.merge(Ruby.spell_art.clips);boss_spell_sounds.merge(Ruby.spell_sounds)
 if cave_sprites==Falken:
  Falken.prepare_spells();boss_spell_clips.merge(Falken.spell_art.clips);boss_spell_sounds.merge(Falken.spell_sounds)
 if cave_sprites==Cursed:
  CursedSpells.prepare();boss_spell_clips.merge(CursedSpells.manifest.clips);boss_spell_sounds.merge(CursedSpells.sounds)
 for ref in boss_spell_clips:
  if batches.has("ruby-native-"+ref):continue
  var clip:Dictionary=boss_spell_clips[ref]
  var pixel_size:float=Ruby.KAZ_HEIGHT*1.1/clip.reference_body_pixels if clip.has("reference_body_pixels") else CONTACT_PIXEL_SIZE
  var mesh=QuadMesh.new();mesh.size=Vector2(clip.width,clip.height)*pixel_size
  var material=ShaderMaterial.new();material.shader=preload("res://assets/characters/crossgate/hit_feedback/critical.gdshader")
  material.set_shader_parameter("atlas",CursedSpells.textures[ref] if cave_sprites==Cursed else Falken.spell_textures[ref] if cave_sprites==Falken and Falken.spell_textures.has(ref) else Ruby.spell_textures[ref]);material.set_shader_parameter("frame_count",float(clip.columns))
  material.set_shader_parameter("frame_rows",float(ceili(float(clip.frames)/clip.columns)))
  mesh.material=material;batches["ruby-native-"+ref]=make_batch(mesh,"ArmyRubyNative_"+ref)
 if cave_sprites==Cursed:
  for kind in [Roles.GATEKEEPER_HOUND,Roles.SLIME,Roles.CAVE_BEAR]:
   var key="guardian-arrival-"+str(kind)
   if batches.has(key):continue
   var mesh:QuadMesh=get_parent().meshes[kind].duplicate()
   var material:ShaderMaterial=mesh.material.duplicate();material.shader=preload("res://assets/materials/hound_afterimage.gdshader")
   mesh.material=material;batches[key]=make_batch(mesh,"ArmyGuardianArrival_"+str(kind),kind==Roles.SLIME)

func ruby_sheet(ref:String,point:Vector3,owner:int=0,life:float=0.0,delay:float=0.0)->Dictionary:
 var row:Dictionary=boss_spell_clips[ref]
 var duplicate_cue=effects.any(func(e):return e.kind=="ruby-native-"+ref and is_equal_approx(e.age,-delay))
 var effect=add_effect("ruby-native-"+ref,point,life if life>0 else row.duration/1000.0,1.0,0,owner)
 if not effect.is_empty():
  effect.handle=game.army_runtime.handles.get(owner,0) if owner!=0 else 0
  effect.age=-delay;effect.loop=life>row.duration/1000.0
  if cave_sprites==Cursed and not row.has("reference_body_pixels"):effect.scale=Ruby.KAZ_HEIGHT/float(CursedSpells.manifest.reference_body_pixels)/CONTACT_PIXEL_SIZE
  effect.sound_index=row.sounds.size() if duplicate_cue else 0
  if cave_sprites==Falken and ref=="110065":effect.opacity=float(Falken.spell_art.skills.drain.targetAlpha)/255.0
 return effect

func ruby_cast(event:Dictionary):
 var action=int(event.action_index)
 var at:Vector3=event.position
 var row=undersea_row(event.source_id)
 if row>=0:at=effect_snapshot.positions[row]
 var support=not (Ruby.magic_attack(action) or Falken.magic_attack(action))
 ruby_sheet("110083" if support else "110054",at,event.source_id)
 play_sound(at,(Falken.sounds if cave_sprites==Falken else Ruby.sounds).get("0:135"),.85,35,true)
 play_sound(at,Ruby.spell_sounds.get("261"),.6,35,true)
 game.toast(("法爾肯 · "+Falken.SPELL_NAMES[action]) if cave_sprites==Falken else "露比 · "+Ruby.SPELL_NAMES[action])
 if support:return
 add_effect("zombie-warning",event.position+Vector3.UP*.065,event.source_tick/30.0,event.amount,0,event.source_id)
 if action==Ruby.FROST:
  for offset:Vector3 in [Vector3.ZERO,Vector3(2,0,0),Vector3(-2,0,0),Vector3(0,0,2),Vector3(0,0,-2)]:
   ruby_sheet("110026",event.position+offset,0,0,.66)
 elif action==Ruby.METEOR:
  for i in 3:
   var meteor=ruby_sheet(str(110038+i),event.position+Vector3((i-1)*2,0,0),0,1.12)
   if not meteor.is_empty():meteor.flight=true;meteor.loop=false
  play_sound(event.position,Ruby.spell_sounds.get("262"),.7,35,true)

func guardian_cast(event:Dictionary):
 var tech=int(event.amount)
 var source:Dictionary=game.model.enemies.get(event.source_id,{})
 game.toast(source.get("enemy_name","守護者")+" · "+CursedSpells.NAMES.get(tech,str(tech)))
 if CursedSpells.physical(tech):return
 var spec=CursedSpells.visual(tech)
 var at:Vector3=source.get("pos",event.position)
 ruby_sheet(spec.get("cast","110083"),at,event.source_id)
 if spec.has("castSound"):play_sound(at,CursedSpells.sounds.get(str(spec.castSound.id)),.6,35,true)
 if tech in [2702,2802,2902,3002,2705,2805,2905,3005]:
  add_effect("zombie-warning",event.position+Vector3.UP*.065,2.0,6.0,0,event.source_id)

func guardian_impact(event:Dictionary):
 var tech=int(event.amount)
 var spec=CursedSpells.visual(tech)
 if spec.has("impactSound"):play_sound(event.position,CursedSpells.sounds.get(str(spec.impactSound.id)),.75,35,true)
 if tech not in [2702,2802,2902,3002,2705,2805,2905,3005]:return
 # Native resolution owns the burst: interrupted casts cannot leave a delayed impact.
 for i in spec.targets.size():
  var target=ruby_sheet(spec.targets[i],event.position+Vector3((i-(spec.targets.size()-1)*.5)*1.7,0,0))
  if not target.is_empty() and spec.has("targetAlpha"):target.opacity=float(spec.targetAlpha)/255.0

func guardian_affliction(event:Dictionary):
 var status=int(event.action_index)-CursedSpells.AFFLICTION
 var hero=event.get("external_kind",-1)==0
 var owner=0 if hero else int(event.target_id)
 if event.amount<=0:
  for i in range(effects.size()-1,-1,-1):
   var effect=effects[i]
   if effect.get("guardian_status",-1)==status and effect.get("hero",false)==hero and effect.owner_id==owner and (event.get("ticket_id",0)==0 or effect.handle==event.ticket_id):effects.remove_at(i)
  return
 if hero and (game.player.hp<=0 or game.player.cursed_afflictions[status]<=0):return
 for effect in effects:
  if effect.has("guardian_status") and effect.get("hero",false)==hero and effect.owner_id==owner:
   if not hero and effect.handle!=game.army_runtime.handles.get(owner,0):effects.erase(effect);break
   if effect.guardian_status==status:effect.life=maxf(effect.life,effect.age+event.amount)
   return
 var effect=ruby_sheet(CursedSpells.manifest.status_icons[status],event.position,owner,event.amount)
 if not effect.is_empty():
  effect.hero=hero;effect.guardian_status=status;effect.opacity=1.0

func guardian_magic_seal(event:Dictionary):
 var spec:Dictionary=CursedSpells.manifest.magic_seal
 var key="ruby-native-"+spec.resource
 for effect in effects:
  if effect.kind==key:
   effect.life=maxf(effect.life,effect.age+event.amount)
   return
 var center=game.model.world_point(Decree.point(Decree.Encounters.SEALS[5],game.model.falan_floor),.08)
 var effect=ruby_sheet(spec.resource,center,0,event.amount)
 if not effect.is_empty():effect.ground=true;effect.opacity=1.0
 play_sound(center,CursedSpells.sounds.get(str(spec.sound)),.75,35,true)

func guardian_arrival(event:Dictionary):
 var id:int=event.source_id
 if effects.any(func(e):return str(e.kind).begins_with("guardian-arrival-") and e.owner_id==id and e.handle==event.ticket_id):return
 # The arriving body must remain visible even when ordinary cosmetic slots are full.
 if effects.size()>=effect_capacity:
  for i in effects.size():
   if not str(effects[i].kind).begins_with("guardian-arrival-"):effects.remove_at(i);break
 var body=add_effect("guardian-arrival-"+str(int(event.unit_kind)),event.position,event.amount,1.0,0,id)
 if not body.is_empty():body.handle=event.ticket_id
 var spec:Dictionary=CursedSpells.manifest.summon
 var light=ruby_sheet(spec.resource,event.position,id,event.amount)
 if not light.is_empty():light.opacity=spec.opacity;light.arrival=true

func undersea_row(id:int)->int:
 return snapshot_row(game.army_runtime.handles.get(id,0))
func snapshot_row(handle:int)->int:
 var slot:int=handle&0xffffffff
 var rows:PackedInt32Array=effect_snapshot.get("rows_by_slot",PackedInt32Array())
 if handle==0 or slot>=rows.size():return -1
 var row:int=rows[slot]
 if row<0 or effect_snapshot.handles[row]!=handle:return -1
 return row
func active_guard_row(handle:int)->int:
 var row=snapshot_row(handle)
 return row if row>=0 and (effect_snapshot.status[row]&17)==16 else -1

func show_guard_cue(handle:int,kind:int):
 var row=active_guard_row(handle)
 if row<0:return
 var lift=3.0
 if not game.army_runtime.pet_geometry.is_empty():
  lift=Hound.Dimensions.bounds(game.army_runtime.pet_geometry,kind,effect_snapshot.pose_rows[row]).end.y+1.0
 var at:Vector3=effect_snapshot.positions[row]+Vector3.UP*lift
 var label=label_damage(at,0,false,false,false,null,false,0.0,false)
 if label==null:return
 label.text="!";label.font=ThemeDB.fallback_font;label.font_size=58;label.pixel_size=.001
 label.modulate=GUARD_CUE_COLOR;label.outline_size=8;label.outline_modulate=Color("102943")
 label.set_meta("guard_cue",[handle,lift])

func present(events:Array,snapshot:Dictionary={}):
 effect_snapshot=snapshot
 for i in labels.size():
  var label=labels[i]
  if not label.has_meta("guard_cue"):continue
  var cue:Array=label.get_meta("guard_cue")
  var row=active_guard_row(cue[0])
  if row<0:
   label.hide();label_ages[i]=0;label.remove_meta("guard_cue")
  else:label.position=snapshot.positions[row]+Vector3.UP*float(cue[1])
 for event in events:
  var serial=int(event.get("serial",0))
  if serial>0 and serial<=last_serial:continue
  last_serial=maxi(last_serial,serial)
  if event.kind=="status" and event.get("action_index",0)==6010 and int(event.source_id)!=0:
   var skin=-1000000-int(event.source_id)
   var height=Hound.Dimensions.companion_body(skin).size.y if skin>=0 and skin<Pets.COUNT else 3.0
   var marker=add_effect("bodyguard-mark",event.direction+Vector3.UP*(height+.8),.55,2.0,0,int(event.source_id))
   if not marker.is_empty():marker.handle=int(event.ticket_id);marker.head_height=height+.8
   play_sound(event.position,preload("res://assets/audio/crossgate/cgefc01.wav"),1.0,65.0,true,true)
  var kind=str(event.get("kind",""));var point:Vector3=event.get("position",Vector3.ZERO)
  var type:int=event.get("unit_kind",-1)
  if kind=="status" and event.get("action_index",0)==802:
   var missed=label_damage(point+Vector3.UP*2,0)
   if missed!=null:missed.text="MISS";missed.font=ThemeDB.fallback_font;missed.font_size=28
   continue
  if kind=="status" and event.action_index==ENEMY_GUARD_RAISED:
   show_guard_cue(event.ticket_id,type)
   continue
  if kind=="status" and event.get("action_index",0)==ENEMY_GUARD_BREAK_WINDUP:
   var height=2.0
   var row=undersea_row(int(event.source_id))
   if row>=0 and not game.army_runtime.pet_geometry.is_empty():
    height=Hound.Dimensions.bounds(game.army_runtime.pet_geometry,type,effect_snapshot.pose_rows[row]).size.y
   var charge:Dictionary=add_effect("guard-break-charge",point,event.amount,height,0,int(event.source_id))
   if not charge.is_empty():charge.handle=event.ticket_id
   var warning=label_damage(point+Vector3.UP*maxf(.2,height*.52-1.6),0,false,false,false,null,true)
   if warning!=null:style_guard_break_text(warning,"崩擊 · Release X")
   var playback=game.sound_library.playback_for(game.sound_library.Roster.KAZI_ID,"cg_guard_break_charge",null)
   if not playback.muted:play_sound(point,playback.stream,playback.gain*.8,35,true)
   continue
  if kind=="status" and event.get("action_index",0)==6000:
   var height=Soldier.hurt_bounds(type).size.y*enemy_size
   if type==Roles.BOSS:height=12.0*Roles.BOSS_SCALE
   if type==Roles.SLIME and cave_sprites!=null:
    var row=undersea_row(int(event.source_id))
    if row>=0:height=float(cave_sprites.motions().variants[effect_snapshot.pose_rows[row]].get("standing_height",height))
   var record:Dictionary=add_effect("ice-thaw",point,2.0,height,0,int(event.source_id))
   if not record.is_empty():record.handle=event.ticket_id
   continue
  if type==Roles.GATEKEEPER_HOUND and kind in ["damage","death"]:pet_reaction(event)
  if kind=="damage" and int(event.get("action_index",0))==13:block_feedback(point)
  if kind in ["damage","external_damage"] and int(event.get("action_index",0))==722:
   block_feedback(point,true,event.get("guard_break_ex",false),event.get("guard_break_scale",1.0))
   var head:Vector3=event.get("guard_break_head",point+Vector3.UP*2.3)
   if kind=="damage" and type==Roles.SLIME and cave_sprites==null:head.y=maxf(head.y,point.y-1.0+Slime.HURT_HEAD_HEIGHT)
   guard_break_notice("Guard Break",head,event.get("guard_break_target"))
  if kind=="hound_summon":
   add_effect(kind,point,Hound.SUMMON_LIFE,1.0)
   # A pack arrives within one cue's duration, so share the voice across arrivals.
   if not voices.any(func(voice):return voice.playing and voice.stream==Hound.SUMMON_SOUND):
    play_sound(point,Hound.SUMMON_SOUND,.9,35,true)
  if kind=="hound_recall":play_sound(point,Hound.RECALL_SOUND,.9,35,true)
  if kind=="status" and int(event.get("action_index",0))==CursedSpells.ARRIVAL:guardian_arrival(event);continue
  if kind=="status" and int(event.get("action_index",0)) in range(790,796):guardian_affliction(event);continue
  if type==Roles.CAVE_BEAR and kind=="status":
   if int(event.action_index)==499:add_effect("smoke",point+Vector3.UP*.6,.28,1.35)
   else:play_sound(point,Habaru.sounds.get("%d:%d"%[Habaru.VENOA_BEAR_SKIN,int(event.action_index)-500]),.85,35,false,true)
  var healed_pet=type==Roles.GATEKEEPER_HOUND and kind=="status" and event.get("amount",0)>0 and int(event.action_index) in [Zombie.HEAL,Ruby.RECOVER_TICK,Ruby.HEAL_EFFECT]
  if type==Roles.GATEKEEPER_HOUND and kind=="status" and not healed_pet:
   if int(event.action_index)==499:add_effect("smoke",point+Vector3.UP*.6,.28,1.35)
   elif int(event.action_index)==Habaru.DOUBLE_EDGE:
    if event.amount>0:sure_strike_burst(point,2.6,true,.01)
    else:
     var label=label_damage(point+Vector3.UP*.9,0)
     if label!=null:
      label.text="諸刃"
      label.font=ThemeDB.fallback_font
      label.modulate=Color("ffc18b")
   else:play_sound(point,Pets.sounds.get(int(event.action_index)-500),1.5,35,true,true)
  if (type==Roles.SLIME or healed_pet) and kind=="status":
   match int(event.action_index):
    CursedSpells.CAST:
     guardian_cast(event)
    CursedSpells.IMPACT:
     guardian_impact(event)
    Grave.MAGIC_SEAL:
     if cave_sprites==Cursed:guardian_magic_seal(event)
    Undersea.MEDITATION:
     add_effect("undersea-meditation",point,1.2,UNDERSEA_BODY_HEIGHT*5.5/(340*CONTACT_PIXEL_SIZE),0,event.source_id)
     play_sound(point,game.sound_library.original_for(game.sound_library.Roster.SHIN_ID,"cg_shin_meditation"),.6,40,true)
     game.toast("熊哥 · 明鏡止水")
    Undersea.HAZE:
     if event.get("amount",0)==0:
      add_effect("undersea-charge",point,.45,UNDERSEA_BODY_HEIGHT*2.2/(165*CONTACT_PIXEL_SIZE),0,event.source_id)
      play_sound(point,game.sound_library.CROSSGATE_FLASH,.8,40,true)
      game.toast("熊哥 · 陽炎 · 50% dodge")
    Undersea.EVADE:
     var label=label_damage(point,0)
     if label!=null:
      label.text="MISS";label.font=ThemeDB.fallback_font;label.font_size=28
     if not effects.any(func(row):return row.kind=="undersea-afterimage" and row.owner_id==event.source_id):
      var row=undersea_row(event.source_id)
      if row>=0:
       var pose:Color=get_parent().pose_sample(effect_snapshot,row)
       var away:Vector3=(point-game.player.position)*Vector3(1,0,1)
       if away.is_zero_approx():away=Vector3.BACK
       for i in 6:
        var ghost=add_effect("undersea-afterimage",point+away.normalized()*i*.28,.2,1.0,effect_snapshot.yaw[row],event.source_id)
        if not ghost.is_empty():ghost.age=-i*2.0/60;ghost.pose=pose
      play_sound(point,game.sound_library.KAZ_KAGEROU_DODGE,.8,40,true)
    Undersea.QIGONG:
     add_effect("undersea-charge",point,.45,UNDERSEA_BODY_HEIGHT*2.2/(165*CONTACT_PIXEL_SIZE),0,event.source_id)
     play_sound(point,game.sound_library.CROSSGATE_FLASH,.8,40,true)
     game.toast("熊哥 · 氣功彈")
    Zombie.DRAIN:
     game.toast("Parukes · Life Drain" if cave_sprites==Grave else "Modified Zombie · Life Drain")
    Zombie.HEAL:
     label_damage(point,event.amount,false,false,true)
     if cave_sprites==Undersea:play_sound(point,game.sound_library.original_for(game.sound_library.Roster.SHIN_ID,"cg_shin_meditation_heal"),1.0,40,true)
    Zombie.CHARGE:
     add_effect("zombie-warning",point+Vector3.UP*.065,event.source_tick/30.0,event.amount,0.0,event.source_id)
     play_sound(point,Zombie.sounds.get("0:157"),.85,35,true)
     game.toast("Self-destruct · Get clear!")
    Grave.EARTH_WARNING:
     add_effect("zombie-warning",point+Vector3.UP*.065,event.source_tick/30.0,event.amount,0.0,event.source_id)
     game.toast("Parukes · Earth Rage")
    Ruby.MEND,Ruby.HEAL,Ruby.RECOVER,Ruby.GROUP_RECOVER,Ruby.HOLY_SHIELD,Ruby.PHYSICAL_ABSORB,Ruby.MAGIC_ABSORB,Ruby.PHYSICAL_REFLECT,Ruby.MAGIC_REFLECT,Ruby.PHYSICAL_NULL,Ruby.MAGIC_NULL,Ruby.FROST,Ruby.METEOR,Ruby.CONFUSION:
     ruby_cast(event)
    Falken.DRAIN,Falken.DEATH,Falken.SUMMON:
     ruby_cast(event)
    Falken.DRAIN_EFFECT:
     ruby_sheet("110065",point)
    Falken.DEATH_EFFECT:
     if cave_sprites==Cursed:
      var death=ruby_sheet(CursedSpells.manifest.death,point)
      if not death.is_empty():
       var row=undersea_row(int(event.target_id)) if event.get("external_kind",-1)!=0 else -1
       var height=Ruby.KAZ_HEIGHT
       if row>=0 and effect_snapshot.kinds[row] in [Roles.GATEKEEPER_HOUND,Roles.SLIME,Roles.CAVE_BEAR]:height=Hound.Dimensions.bounds(game.army_runtime.pet_geometry,effect_snapshot.kinds[row],effect_snapshot.pose_rows[row]).size.y
       if row>=0 and effect_snapshot.has("body_scales"):height*=effect_snapshot.body_scales[row]
       death.anchor_y=height*.5;death.opacity=1.0
     if event.amount<=0:
      var missed=label_damage(point+Vector3.UP*2,0)
      if missed!=null:missed.text="MISS";missed.font=ThemeDB.fallback_font;missed.font_size=28
    Ruby.FROST_IMPACT:
     pass
    Ruby.METEOR_IMPACT:
     play_sound(point,Ruby.spell_sounds.get("131"),.85,35,true)
    Ruby.HEAL_EFFECT:
     var spec=CursedSpells.visual(int(event.amount)) if cave_sprites==Cursed else {}
     ruby_sheet(spec.targets[0] if not spec.is_empty() else "110087",point,event.source_id)
    Ruby.RECOVER_TICK:
     for i in range(effects.size()-1,-1,-1):
      if effects[i].kind=="ruby-native-110178" and effects[i].owner_id==event.source_id:effects.remove_at(i)
     var recovery=ruby_sheet("110179" if event.source_tick==6602 else "110178",point,event.source_id,event.amount)
     if not recovery.is_empty() and event.source_tick==6602:recovery.half_height=true
    Ruby.WARD_ACTIVE:
     pass
    Ruby.WARD_BLOCK:
     var holy=int(event.amount)==Ruby.HOLY_SHIELD
     var ref:String=Ruby.spell_art.holy_shield if holy else Ruby.spell_art.ward_contacts.get(str(int(event.amount)),"")
     if not ref.is_empty():
      var contact=ruby_sheet(ref,point,event.source_id)
      if not contact.is_empty():contact.half_height=true
      if holy:play_sound(point,Ruby.spell_sounds[str(131+randi()%2)],.75,35,true)
     var ward_label=label_damage(point+Vector3.UP*2,0)
     if ward_label!=null:
      ward_label.text=Ruby.SPELL_NAMES.get(int(event.amount),"防護");ward_label.font=ThemeDB.fallback_font;ward_label.font_size=25
    Ruby.CONFUSED:
     var victim=int(event.target_id)
     var swirl=ruby_sheet(Ruby.spell_art.confusion,point,victim,event.amount)
     if not swirl.is_empty():
      swirl.hero=event.get("external_kind",-1)==0
      swirl.confusion=true
      swirl.handle=game.army_runtime.handles.get(victim,0)
    Habaru.BRACE:
     add_effect("zombie-warning",point+Vector3.UP*.065,event.source_tick/30.0,event.amount,0.0,event.source_id)
     play_sound(point,game.sound_library.CROSSGATE_FLASH,.8,40,true)
     var warning=label_damage(point+Vector3.UP*(Hound.Dimensions.KAZ_HEIGHT*Hound.Dimensions.HEIGHTS.habaru[0]*.65-1.1),0,false,false,false,null,true)
     if warning!=null:
      warning.text="!";warning.font=ThemeDB.fallback_font;warning.font_size=96;warning.pixel_size=.0018;warning.outline_size=6;warning.modulate=Color("ff9b37")
      warning.set_meta("habaru_warning",event.source_id);label_ages[labels.find(warning)]=event.source_tick/30.0
     game.toast("熊弟蓄力反擊 · 繞到背後！")
    Habaru.RESET:
     for i in labels.size():
      if labels[i].get_meta("habaru_warning",0)==event.source_id:label_ages[i]=0;labels[i].hide()
     for i in range(effects.size()-1,-1,-1):
      if effects[i].kind=="zombie-warning" and effects[i].owner_id==event.source_id:effects.remove_at(i)
    Habaru.DOUBLE_EDGE:
     sure_strike_burst(point,.85*6.0*252.0/194.0,true)
    Zombie.BLAST, Grave.EARTH_IMPACT:
     add_effect("finale-blast",point+Vector3.UP*.12,.85,1.0)
     play_sound(point,Finale.sounds.earth_impact,1.0,45,true)
   var cue=int(event.action_index)-500
   var stream=Slime.sounds.get(cue)
   if cave_sprites!=null:
    var skin:int=game.model.enemies.get(int(event.get("source_id",0)),{}).get("skin",1)
    stream=cave_sprites.sounds.get("%d:%d"%[skin,cue])
   play_sound(point,stream,.85,35,false,true)
  if type==31 and int(event.get("team",0))==1:
   var slot="wc_spin" if kind=="status" and int(event.get("action_index",0))==9 else "wc_mirror_end" if kind=="death" else "wc_slam" if int(event.get("action_index",0))==2 else "wc_attack_%d"%(int(event.get("action_index",0))%2+1)
   if kind in ["melee","death","status"]:
    var playback=game.sound_library.playback_for(31,slot,null)
    if not playback.muted and MoveAudio.ally_nearby(game,point):play_sound(point,playback.stream,playback.gain*.65)
  if type==Finale.ROLE:
   if kind=="status" and int(event.get("action_index",0))>=300:finale_cue(point,int(event.action_index)-300,event.get("direction",Vector3.FORWARD),-int(event.source_id),int(event.get("source_tick",0)))
   elif kind=="projectile_impact":
    var impact=int(event.get("action_index",0))
    finale_cue(point,43 if impact==0 and event.get("source_tick",0)>0 else 42 if impact==2 and event.get("source_tick",0)>0 else 20+impact,event.get("direction",Vector3.FORWARD),-int(event.source_id))
   elif kind=="damage":cancel_finale(-int(event.target_id));finale_sound(point,"hit_strong" if event.get("heavy",false) else "hit")
   elif kind=="death":cancel_finale(-int(event.target_id));finale_cue(point,30)
  if type==Dark.ROLE:
   if kind=="status" and int(event.get("action_index",0))>=200:
    var direction:Vector3=event.get("direction",Vector3.FORWARD)
    dark_cue(point,int(event.action_index)-200,atan2(-direction.x,-direction.z),-int(event.source_id),1.0,float(event.get("amount",1)))
   elif kind=="projectile_impact":dark_sound(point,"fire_impact");add_effect("dark-impact",point,.53,1)
   elif kind=="damage":cancel_dark_spin(-int(event.target_id));dark_sound(point,"hurt")
   elif kind=="death":cancel_dark_spin(-int(event.target_id));dark_sound(point,"death");dark_cue(point,15)
  if MONSTER_SOUNDS.has(type) and MONSTER_SOUNDS[type].has(kind):play_sound(point,MONSTER_SOUNDS[type][kind])
  if kind=="status" and int(event.get("action_index",0))==18 and is_instance_valid(game):
   var playback=game.sound_library.playback_for(7,"knight_finisher_hit",null)
   if not playback.muted and MoveAudio.ally_nearby(game,point):play_sound(point,playback.stream,playback.gain)
  if kind=="status" and int(event.get("action_index",0))==17 and int(event.get("amount",-1))==Roles.VAMBEE and corpses.size()<corpse_capacity:
   var direction:Vector3=event.get("direction",Vector3.BACK)
   corpses.append({"age":0.0,"life":1.0,"kind":Roles.VAMBEE_LEGS,"position":point,"velocity":Vector3.ZERO,"yaw":atan2(direction.x,direction.z),"pitch":0.0,"tumble":false})
  if kind=="death":
   if int(event.get("xp_reward_tenths",0))>0:label_experience(point,event.xp_reward_tenths)
   if event.has("overkill_target") and corpses.size()>=corpse_capacity:
    for i in corpses.size():
     if not corpse_held(corpses[i]):corpses.remove_at(i);break
   var corpse_count=corpses.size()
   if type==Roles.SLIME and cave_sprites==Habaru and int(event.action_index)==0:
    for i in labels.size():
     if labels[i].get_meta("habaru_warning",0)==event.target_id:label_ages[i]=0;labels[i].hide()
   if type==Roles.SLIME and ((cave_sprites==Zombie and int(event.action_index)==0) or (cave_sprites==Grave and int(event.action_index)==2) or (cave_sprites==Habaru and int(event.action_index)==0)):
    for i in range(effects.size()-1,-1,-1):
     if effects[i].kind=="zombie-warning" and effects[i].owner_id==event.target_id:effects.remove_at(i)
   if type in [Roles.GATEKEEPER_HOUND,Roles.SLIME,Roles.CAVE_BEAR] and corpse_batches.has(type) and corpses.size()<corpse_capacity:
    var skin=int(event.action_index);var direction:Vector3=event.direction
    var data=Habaru.motions() if type==Roles.CAVE_BEAR else (cave_sprites if cave_sprites!=null else Slime).motions() if type==Roles.SLIME else Pets.motions()
    corpses.append({"age":0.0,"life":data.variants[skin].fall_duration+.2,"kind":type,"position":point,"yaw":atan2(direction.x,direction.z),"pitch":0.0,"tumble":false,"skin":skin})
   elif type not in [Roles.GATEKEEPER_HOUND,Roles.SLIME,Roles.CAVE_BEAR] and int(event.get("team",0))==0 and Soldier.supports(type) and corpses.size()<corpse_capacity:
    var direction:Vector3=event.get("direction",Vector3.BACK);var yaw=atan2(direction.x,direction.z)
    var tumble=not Roles.RECOVERED.has(type)
    var source:Resource=Soldier.data(type);var clips:Dictionary=source.get_meta("clips");var semantic:Dictionary=source.get_meta("semantics")
    corpses.append({"age":0.0,"life":.8 if tumble else float(clips[semantic.death].ticks)/30+(80.0/30 if type==Dark.ROLE else .2),"kind":type,"position":point+Vector3.UP*.36*Soldier.SCALE*enemy_size if tumble else point,"velocity":(Vector3.UP*4.8+Vector3(sin(yaw),0,cos(yaw))*2.4)*Soldier.SCALE*enemy_size if tumble else Vector3.ZERO,"yaw":yaw,"pitch":deg_to_rad(67.5) if tumble else 0.0,"tumble":tumble})
   if corpses.size()>corpse_count and event.has("death_launch"):
    var body=corpses.back()
    body.flight_origin=point;body.flight_direction=event.death_launch;body.flight_started=false
    body.life=FLY_LIFE;body.tumble=false
   if corpses.size()>corpse_count:corpses.back().body_scale=event.get("body_scale",1.0)
   if corpses.size()>corpse_count and event.has("overkill_target"):
    corpses.back().overkill_target=event.overkill_target
   if not event.get("quiet_contact",false) and not event.has("overkill_target"):add_effect("smoke",point+Vector3.UP,.45,1.5)
  elif kind=="damage":
   if int(event.get("joint_count",0))>=2:joint_attack_feedback(event)
   var critical:bool=event.get("critical",false)
   if event.get("quiet_contact",false):
    if critical:critical_burst(point,float(event.get("impact_scale",1.0)))
    continue
   var heavy:bool=event.get("heavy",false)
   var target=game.actors.get(int(event.get("target_id",0))) if is_instance_valid(game) and int(event.get("team",0))==0 else null
   if event.get("shin_area_impact",false):point.y+=Roles.height(type,enemy_size)*.8
   hit_feedback(null if event.has("impact_point") else target,event.get("impact_point",point),float(event.get("impact_scale",1.0)),critical)
   label_damage(point,event.amount,heavy,critical)
   if event.has("sure_strike_effect"):
    var burst:Dictionary=event.sure_strike_effect
    sure_strike_burst(burst.position,burst.size,burst.polearm,burst.depth)
   if event.has("combo_hit_effect"):
    var burst:Dictionary=event.combo_hit_effect
    combo_burst(burst.position,preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT,burst.shin,burst.size,burst.depth)
  elif kind=="landing_pulse":
   var pulse=clampi(int(event.get("action_index",0)),0,2)
   add_effect("ring",point,.38,[12.6,16.2,19.8][pulse]*dragon_scale)
   if pulse<2 and is_instance_valid(game):
    var playback=game.sound_library.playback_for(8,"move_secondary_voice" if pulse==0 else "dragoon_hunt",null)
    if not playback.muted and MoveAudio.ally_nearby(game,point):play_sound(point,playback.stream,playback.gain)
  elif kind=="status" and int(event.get("action_index",0))==14:add_effect("ring",point,.7,9)
  elif kind=="muzzle":add_effect("spark",point,.12,.6)
  elif kind=="bullet" and int(event.get("action_index",0))==Undersea.QIGONG:
   if int(event.get("source_tick",0))==0:play_sound(point,preload("res://assets/audio/crossgate/kazi/cgefc03.wav"))
  elif kind=="bullet" and int(event.get("team",0))==0 and type not in [Dark.ROLE,Finale.ROLE]:gunshot(point)
  elif kind=="projectile_impact" and int(event.get("action_index",0))==Undersea.QIGONG:
   play_sound(point,preload("res://assets/audio/crossgate/kazi/cgefc04.wav"));add_effect("spark",point,.16,.55)
  elif kind=="projectile_impact" and type not in [Dark.ROLE,Finale.ROLE]:add_effect("spark",point,.16,.55)
static func prepare_melee_wind()->QuadMesh:
 if melee_wind_mesh==null:
  melee_wind_mesh=QuadMesh.new();melee_wind_mesh.size=Vector2.ONE*2
  var material=ShaderMaterial.new()
  material.shader=preload("res://assets/materials/crossgate_melee_wind.gdshader")
  material.set_shader_parameter("wind_atlas",preload("res://assets/characters/crossgate/kazi/moon-waves-relief.png"))
  melee_wind_mesh.material=material
 return melee_wind_mesh

func melee_wind(from:Vector3,to:Vector3,padding:float,sweep:PackedVector3Array,weapon:String,motion:String,body_height:float,range_growth:float):
 var forward=to-from;forward.y=0
 var length_=forward.length()
 if length_<.001 or padding<=0:return
 forward/=length_
 var side=forward.cross(Vector3.UP)
 var arc=0.0
 for endpoint in sweep:
  arc=maxf(arc,absf(forward.signed_angle_to((endpoint-from).normalized(),Vector3.UP)))
 var style=0
 if motion=="puff":style=5 if weapon=="unarmed" else 1
 elif motion=="push":style=5
 elif motion in ["sweep","spin"]:style=2
 elif motion.begins_with("arc_") or motion in ["up","down"]:style=9 if weapon=="staff" else 8 if weapon=="axe" else 3
 elif weapon=="staff":style=7
 var life=PUNCH_WIND_LIFE if style in [5,9] else .28 if style==8 else MELEE_WIND_LIFE
 var record=add_effect("melee-wind",from,life,1.0)
 if record.is_empty():return
 record.style=style;record.motion=motion;record.padding=padding/length_;record.arc=arc
 var reach=length_+padding
 # Range still reaches the hit boundary; only the cosmetic breadth grows more gently.
 var width_growth=sqrt(maxf(1.0,range_growth))
 var width_padding=padding/width_growth
 if style==2:
  arc=PI*.45 if motion=="spin" else PI/3;record.arc=arc
  record.pose=Transform3D(Basis(side,forward,Vector3.UP).scaled_local(Vector3((length_*sin(arc)+padding)/width_growth,length_*.5+padding,1)),from+forward*length_*.5+Vector3.UP*body_height*.22)
 elif style==1:
  record.pose=Transform3D(Basis(side,forward,Vector3.UP).scaled_local(Vector3(length_*.40,length_*.40,1)),from+forward*length_*.55)
 else:
  var camera=get_viewport().get_camera_3d()
  var view=camera.global_basis.orthonormalized() if camera!=null else Basis.IDENTITY
  var axis=forward-view.z*forward.dot(view.z)
  axis=axis.normalized() if axis.length_squared()>.001 else view.x
  var across=axis.cross(view.z).normalized()
  if style in [3,8]:
   record.cut=1 if motion in ["arc_up","up"] else -1;record.arc=0.0 if record.cut>0 else 1.0
   record.padding=forward.dot(view.z)
   var tangent=view.z.cross(axis).normalized()
   if tangent.dot(Vector3.UP)<0:tangent=-tangent
   var start=minf(length_*.1,body_height*.25)
   var height=maxf(body_height*(.53 if style==8 else .4)+width_padding*.3,reach/width_growth*(.35 if style==8 else .25))
   record.pose=Transform3D(Basis(axis,tangent,view.z).scaled_local(Vector3(reach-start,height,1)),from+forward*start+Vector3.UP*body_height*.1)
  elif style==0:
   record.arc=0;record.padding=forward.dot(view.z)
   record.pose=Transform3D(Basis(across,axis,view.z).scaled_local(Vector3(body_height*.12+width_padding*.55,reach*.5,1)),from+forward*reach*.5+Vector3.UP*body_height*.35)
  elif style==9:
   var sign_=1 if motion=="up" else -1
   axis=(view.y*sign_+axis*.4).normalized();across=axis.cross(view.z).normalized()
   var half_depth=body_height*.42+width_padding*.2
   record.arc=0;record.padding=0
   # The third quad axis carries the blunt swing's world travel; its source UV crest stays intact.
   record.pose=Transform3D(Basis(across*(body_height*.18+width_padding),axis*half_depth,forward*reach+Vector3.UP*body_height*.5*sign_),from-axis*PUNCH_CREST_START*half_depth+Vector3.UP*body_height*(.2 if sign_>0 else .7))
  else:
   var width=(body_height*.18+width_padding)*(1.15 if style==5 else 1.0)
   var depth=(body_height*.45+length_/width_growth*.18)*(1.15 if style==5 else 1.0)
   var half_depth=depth*.5+width*.25
   var crest_start=PUNCH_CREST_START if style==5 else (.25+.62/2.2+.30)*2.0/1.65-1.0
   record.arc=(forward.dot(view.z)+1.0)*.5
   # The shared custom-data slot carries real reach for GPU-only travel of the approved crest.
   record.padding=reach/half_depth
   record.pose=Transform3D(Basis(across,axis,view.z).scaled_local(Vector3(width,half_depth,1)),from-axis*crest_start*half_depth+Vector3.UP*body_height*.45)

func add_effect(kind:String,at:Vector3,life:float,scale_:float,yaw:float=0.0,owner_id:int=0):
 if effects.size()>=effect_capacity:return {}
 if kind=="ring":at+=Vector3.UP*.065
 var record={"kind":kind,"position":at,"age":0.0,"life":life,"scale":scale_,"yaw":yaw,"owner_id":owner_id}
 if kind.begins_with("undersea-"):record.handle=game.army_runtime.handles.get(owner_id,0)
 effects.append(record);return record
func hit_feedback(target:Ninja,at:Vector3,scale_:float,critical:bool=false)->Dictionary:
 if effects.size()+(2 if critical else 1)>effect_capacity:return {}
 var camera=get_viewport().get_camera_3d()
 if is_instance_valid(target) and camera!=null:
  at=AttackChain.contact_point(target,Vector3(camera.global_position.x,at.y,camera.global_position.z),at)
  at+=(camera.global_position-at).normalized()*.04
 if not hit_visible(at,camera):return {}
 var spark=add_effect(GOLD_SPARKS[next_gold_spark],at,7*GOLD_FRAME_TIME,scale_)
 next_gold_spark=(next_gold_spark+1)%GOLD_SPARKS.size()
 if critical:add_effect("critical",at,4*CRITICAL_FRAME_TIME,scale_*CRITICAL_SCALE)
 return spark

func block_feedback(at:Vector3,broken:bool=false,ex:bool=false,scale_:float=1.0):
 if broken:add_effect("guard-break-ex" if ex else "guard-break",at,.544,scale_)
 else:
  add_effect("spark",at,.14,.65)
  var playback=game.sound_library.playback_for(game.sound_library.Roster.KAZI_ID,"coin_hit",null)
  if not playback.muted:play_sound(at,playback.stream,playback.gain*.7)

func guard_break_notice(words:String,head:Vector3,target_ref:WeakRef=null):
 var at=head+Vector3.UP*.45
 var label=label_damage(at,0,false,false,false,null,true,0.0,false)
 if label==null:return
 style_guard_break_text(label,words)
 label.font_size=32;label.pixel_size=.0008
 var target=target_ref.get_ref() if target_ref!=null else null
 if is_instance_valid(target) and not target.dead:label.set_meta("hit_follow",[target_ref,at-target.global_position])

func style_guard_break_text(label:Label3D,words:String):
 label.text=words;label.font=BATTLE_TEXT_FONT;label.modulate=Color("fff3a2")
 label.font_size=36;label.pixel_size=.0012;label.outline_size=5;label.outline_modulate=Color("172b18")

func player_hit_feedback(hero:Hero,amount:float):
 var scale_:float=hero.model.global_basis.y.length()
 var offset=Vector3.UP*hero.Proportions.GOEMON_HEIGHT*scale_*.55
 var at=hero.global_position+offset
 var anchor=weakref(hero)
 var spark=hit_feedback(null,at,hero.hit_effect_scale())
 if not spark.is_empty():
  spark.anchor=anchor
  spark.anchor_offset=offset
 var label=label_damage(at,amount)
 if label!=null:label.set_meta("hit_follow",[anchor,offset+Vector3.UP*1.6])

func hit_visible(at:Vector3,camera:Camera3D)->bool:
 return (not is_instance_valid(game) or game.forest_point_visible(at)) and (camera==null or camera.is_position_in_frustum(at))

func critical_burst(at:Vector3,scale_:float=1.0):
 if hit_visible(at,get_viewport().get_camera_3d()):add_effect("critical",at,4*CRITICAL_FRAME_TIME,scale_*CRITICAL_SCALE)

func joint_attack_feedback(event:Dictionary):
 var count_=clampi(int(event.joint_count),2,10)
 var at:Vector3=event.position+Vector3.UP*1.8
 if not hit_visible(at,get_viewport().get_camera_3d()):return
 for record in effects:
  if record.kind=="joint-glyph" and record.owner_id==int(event.target_id) and record.slot==0:
   if record.count==count_:return
 for i in range(effects.size()-1,-1,-1):
  if effects[i].kind=="joint-glyph" and effects[i].owner_id==int(event.target_id):effects.remove_at(i)
 var glyphs=[count_-2,9,10,11,12,13,14,15,13]
 var offsets=[0,34,54,66,88,108,131,152,171]
 var order=[0,8,7,6,5,4,3,2,1]
 if count_==10:glyphs.append(16);offsets.append(88);order.append(9)
 if effects.size()+glyphs.size()>effect_capacity:return
 for i in glyphs.size():
  var record=add_effect("joint-glyph",at,4.0,.6,0,int(event.target_id))
  if record.is_empty():break
  record.glyph=glyphs[i];record.offset=Vector2(offsets[i]-85.5,-32 if i==9 else 0)
  record.delay=order.find(i)*4;record.slot=i;record.count=count_
func combo_burst(at:Vector3,body_height:float,shin:bool,effect_size:float,depth:float):
 var burst=add_effect("shin_combo" if shin else "kazi_combo",at,(SHIN_COMBO_FRAMES*SHIN_COMBO_FRAME_TIME if shin else 7*COMBO_FRAME_TIME),effect_size*body_height/((SHIN_COMBO_SIZE_PIXELS if shin else COMBO_BURST_SIZE_PIXELS)*CONTACT_PIXEL_SIZE))
 if not burst.is_empty():burst.contact_depth=depth
func sure_strike_burst(at:Vector3,diameter:float,polearm:bool,depth:float=0.0):
 # Large billboards can overlap the screen with an offscreen origin.
 if not is_instance_valid(game) or game.forest_point_visible(at):
  var burst=add_effect("shin_double_edge" if polearm else "shin_sure_strike",at,(DOUBLE_EDGE_FRAMES*DOUBLE_EDGE_FRAME_TIME if polearm else SURE_STRIKE_FRAMES*SURE_STRIKE_FRAME_TIME),diameter/((252.0 if polearm else 232.0)*CONTACT_PIXEL_SIZE))
  if depth>0 and not burst.is_empty():burst.contact_depth=depth
func two_birds_burst(at:Vector3,body_height:float,rear:bool,ex:bool=false):
 if hit_visible(at,get_viewport().get_camera_3d()):
  var burst=add_effect("shin_two_birds_ex" if ex else "shin_two_birds",at,TWO_BIRDS_FRAMES*TWO_BIRDS_FRAME_TIME,(9.0 if rear else 4.5)*body_height/((278.0 if ex else 238.0)*CONTACT_PIXEL_SIZE))
  if not burst.is_empty():burst.rear=rear
func blade_dance_burst(enemy:Ninja,at:Vector3):
 if not game.forest_point_visible(at):return
 var center:Vector3=enemy.combat_bounds().get_center() if enemy.has_method("combat_bounds") else AttackChain.aim_point(enemy)
 add_effect("maze_blade_dance",center,BLADE_DANCE_FRAMES*BLADE_DANCE_FRAME_TIME,6.0)
func water_boomerang_burst(at:Vector3,facing:int,scale_:float):
 if not hit_visible(at,get_viewport().get_camera_3d()):return
 var burst=add_effect("water-boomerang-wave",at,WATER_BOOMERANG_FRAMES*WATER_BOOMERANG_FRAME_TIME,scale_)
 if not burst.is_empty():burst.facing=facing
func label_experience(at:Vector3,reward_tenths:int)->Label3D:
 if reward_tenths<=0:return null
 var label=label_damage(at,0,false,false,false,null,false,4.0)
 if label!=null:
  label.text="+%d EXP"%roundi(reward_tenths/10.0)
  label.font=BATTLE_TEXT_FONT;label.font_size=32;label.pixel_size=.0012
  label.modulate=Color("ce8cff");label.outline_size=5;label.outline_modulate=Color("29143f")
 return label

func label_damage(at:Vector3,amount:float,heavy:bool=false,critical:bool=false,healing:bool=false,follow:Hero=null,priority:bool=false,height:float=1.6,screen_only:bool=true)->Label3D:
 if is_instance_valid(game) and not game.forest_point_visible(at):return null
 at+=Vector3.UP*height
 var camera=get_viewport().get_camera_3d()
 if screen_only and camera!=null and not camera.is_position_in_frustum(at):return null
 var capacity=mini(maxi(label_capacity,1 if follow!=null or priority else 0),labels.size())
 for i in capacity:
  if label_ages[i]>0 and ((follow==null and not priority) or i<capacity-1):continue
  var label=labels[i]
  var hero_heal=healing and follow!=null
  label_ages[i]=.65;label.position=at;label.set_meta("habaru_warning",0);label.remove_meta("guard_cue")
  label.text=("+" if healing and not hero_heal else "")+str(roundi(amount))
  label.font=HEAL_FONT if healing else DAMAGE_FONT
  label.font_size=(52 if hero_heal else 44) if healing else (52 if critical else (48 if heavy else 36))
  label.modulate=Color.WHITE;label.pixel_size=.00065;label.outline_size=0;label.outline_modulate=Color.BLACK
  label.set_meta("hit_follow",[weakref(follow),at-follow.global_position] if follow!=null else null)
  label.show();return label
 return null
func gunshot(point:Vector3):
 play_sound(point,preload("res://assets/characters/thirstquencher/projectiles/gunshot_43a.wav"))
func play_sound(point:Vector3,stream:AudioStream,gain:float=1.0,audible_range:float=65.0,priority:bool=false,bypass_cooldown:bool=false):
 if stream==null or not is_instance_valid(game) or not game.playing or game.paused or game.transitioning or game.sound_library.recording or (clock<next_sound and not priority and not bypass_cooldown):return
 var volume=float(game.settings.get("volume",.65))
 if volume<=0 or point.distance_squared_to(game.player.position)>audible_range*audible_range:return
 var selected:AudioStreamPlayer3D
 for voice in voices:
  if not voice.playing:selected=voice;break
  if priority and voice.get_meta("loop_until",0)==0 and (selected==null or voice.get_meta("started",0)<selected.get_meta("started",0)):selected=voice
 # Foreground cues can reclaim a native loop when all ordinary voices are busy.
 if selected==null and priority:
  for voice in voices:
   if voice.get_meta("loop_owner",0)<0 and (selected==null or voice.get_meta("started",0)<selected.get_meta("started",0)):selected=voice
 if selected==null:return null
 selected.stop();selected.set_meta("loop_until",0);selected.set_meta("loop_owner",0);selected.set_meta("finale_loop","");selected.set_meta("audio_ticket",{});selected.set_meta("pet_motion_owner",0);selected.set_meta("started",clock)
 selected.max_distance=audible_range;selected.unit_size=12*audible_range/65
 # The Master bus already applies the user's game volume.
 selected.stream=stream;selected.position=point;selected.pitch_scale=1.0;selected.volume_db=linear_to_db(maxf(.0001,.55*gain));selected.play()
 if not bypass_cooldown:next_sound=clock+.035
 return selected
func tick(delta:float):
 if is_instance_valid(game) and (game.paused or game.transitioning):
  for voice in voices:voice.stop()
  return
 var dt=maxf(0,delta);clock+=dt
 for voice in voices:
  if voice.playing and not MoveAudio.ticket_audible(game,voice.get_meta("audio_ticket",{})):voice.stop()
  if voice.playing and float(voice.get_meta("loop_until",0))>0 and clock>=float(voice.get_meta("loop_until")):voice.stop()
 for i in range(effects.size()-1,-1,-1):
  var before:float=effects[i].age
  effects[i].age+=dt
  if str(effects[i].kind).begins_with("ruby-native-"):
   var effect=effects[i]
   if effect.has("guardian_status") and effect.get("hero",false) and (game.player.hp<=0 or game.player.cursed_afflictions[effect.guardian_status]<=0):effects.remove_at(i);continue
   if effect.handle!=0:
    var owner_row=undersea_row(effect.owner_id)
    if owner_row<0 or effect_snapshot.hp[owner_row]<=0 or effect_snapshot.handles[owner_row]!=effect.handle:effects.remove_at(i);continue
    if effect.get("arrival",false) and effect_snapshot.render_actions[owner_row]!=CursedSpells.ARRIVAL:effects.remove_at(i);continue
   var clip:Dictionary=boss_spell_clips[str(effect.kind).trim_prefix("ruby-native-")]
   while effect.sound_index<clip.sounds.size() and effect.age>=float(clip.sounds[effect.sound_index].at_ms)/1000.0:
    var point:Vector3=effect.position
    if effect.handle!=0:point=effect_snapshot.positions[undersea_row(effect.owner_id)]
    play_sound(point,boss_spell_sounds.get(str(int(clip.sounds[effect.sound_index].id))),.75,35,true)
    effect.sound_index+=1
  if str(effects[i].kind).begins_with("guardian-arrival-"):
   var effect=effects[i];var row=undersea_row(effect.owner_id)
   if row<0 or effect_snapshot.hp[row]<=0 or effect_snapshot.handles[row]!=effect.handle or effect_snapshot.render_actions[row]!=CursedSpells.ARRIVAL:effects.remove_at(i);continue
  if effects[i].kind=="pet-audio":
   if effects[i].handle!=0:
    var row=undersea_row(effects[i].owner_id)
    if row<0 or effect_snapshot.handles[row]!=effects[i].handle:effects.remove_at(i);continue
    effects[i].position=effect_snapshot.positions[row]+Vector3.UP
   pet_reaction_cues(effects[i],before,effects[i].age)
  if effects[i].kind=="finale-core":
   var audio_ticket:Dictionary=effects[i].get("audio_ticket",{})
   if before<.7 and effects[i].age>=.7:add_effect("finale-burst",effects[i].position,24.0/30,3.0/16,effects[i].yaw)
   if before<.1 and effects[i].age>=.1:finale_loop(effects[i].position,"core_loop",1.1,effects[i].owner_id if audio_ticket.get("allied",false) else 0,audio_ticket)
   for cue in [[.3,"core_hit"],[.7,"core_burst"],[1.2,"defeat"],[1.8,"ending"]]:
    if before<cue[0] and effects[i].age>=cue[0]:finale_sound(effects[i].position,cue[1],effects[i].get("foreground",false),audio_ticket)
  if effects[i].age>=effects[i].life:effects.remove_at(i)
 for i in range(corpses.size()-1,-1,-1):
  var row=corpses[i];var before:float=row.age;row.age+=dt
  if corpse_held(row):row.age=0;continue
  if row.has("flight_origin"):
   if not row.flight_started:
    row.flight_started=true;play_sound(row.position,FLY_SOUND,1.0)
   var progress=minf(row.age/FLY_LIFE,1.0)
   row.position=row.flight_origin+row.flight_direction*FLY_DISTANCE*progress+Vector3.UP*(.4+4*FLY_HEIGHT*progress*(1-progress))
  elif row.kind==Dark.ROLE:
   if before<2.1 and row.age>=2.1:dark_sound(row.position,"death_final")
   if before<140.0/30 and row.age>=140.0/30:dark_sound(row.position,"breakup")
  if row.age>=row.life:corpses.remove_at(i)
 var moving:Array[Dictionary]=[];var points=PackedVector3Array();var radii=PackedFloat64Array()
 for i in range(corpses.size()-1,-1,-1):
  var row=corpses[i]
  if not row.tumble or corpse_held(row):continue
  var before:Vector3=row.position;var next:Vector3=before+Vector3(row.velocity)*dt
  row.velocity.y-=13.5*Soldier.SCALE*enemy_size*dt;row.pitch-=deg_to_rad(22.5)*30*dt
  moving.append(row);points.append(next);radii.append(preload("res://scripts/forest/forest_enemy_roles.gd").footprint_radius(row.kind,enemy_size))
 var terrain:PackedFloat64Array=game.model.waves.navigation.terrain_corridors.probe(points,radii) if is_instance_valid(game) and not points.is_empty() else PackedFloat64Array()
 for i in moving.size():
  var row=moving[i];var before:Vector3=row.position;var next:Vector3=points[i];var floor_=terrain[i*2] if not terrain.is_empty() else 0.0
  if not terrain.is_empty():
   if terrain[i*2+1]==0:
    next.x=before.x;next.z=before.z;row.velocity.x=0;row.velocity.z=0
  if next.y<floor_:next.y=floor_;row.velocity=Vector3.ZERO
  row.position=next
 for i in labels.size():
  if label_ages[i]<=0:continue
  var label=labels[i]
  if label.has_meta("guard_cue"):continue
  label_ages[i]=maxf(0,label_ages[i]-dt)
  if label_ages[i]<=0:
   label.hide()
   label.set_meta("hit_follow",null)
   continue
  label.position.y+=dt*1.4/.65
  if label.has_meta("hit_follow"):
   var follow:Array=label.get_meta("hit_follow")
   var anchor=follow[0].get_ref()
   if is_instance_valid(anchor):
    label.position=anchor.global_position+Vector3(follow[1])+Vector3.UP*(.65-label_ages[i])*1.4/.65
  label.modulate.a=minf(1,label_ages[i]*5)
 draw_effects();draw_corpses()
func hide_batch(node:MultiMeshInstance3D):
 if node.visible:node.hide()
 if node.multimesh.visible_instance_count!=0:node.multimesh.visible_instance_count=0
func show_rows(node:MultiMeshInstance3D,poses:Array,custom:Array):
 if poses.is_empty():
  hide_batch(node)
  return
 var mm=node.multimesh
 if not node.visible:node.show()
 if poses.size()>mm.instance_count:mm.instance_count=nearest_po2(poses.size())
 for i in poses.size():mm.set_instance_transform(i,poses[i]);mm.set_instance_custom_data(i,custom[i])
 mm.visible_instance_count=poses.size();mm.custom_aabb=AABB(Vector3(-1000,-1000,-1000),Vector3.ONE*2000)
func draw_effects():
 var grouped={}
 var camera=get_viewport().get_camera_3d()
 var contact_basis=camera.global_basis.orthonormalized() if camera!=null else Basis.IDENTITY
 var contact_fade=.35 if is_instance_valid(game) and game.settings.get("reduced_flashes",false) else 1.0
 for record in effects:
  var key:String=record.kind
  if key=="pet-audio":continue
  if record.age<0:continue
  var undersea_cast=key in ["undersea-meditation","undersea-charge"]
  var foot:Vector3=record.position
  if undersea_cast or key=="undersea-afterimage":
   var row=undersea_row(record.owner_id)
   if row<0 or effect_snapshot.hp[row]<=0 or effect_snapshot.handles[row]!=record.handle:continue
   if undersea_cast:
    var action:int=effect_snapshot.render_actions[row]
    if action!=(Undersea.MEDITATION if key=="undersea-meditation" else Undersea.QIGONG) and not (key=="undersea-charge" and action==Undersea.HAZE):continue
    foot=effect_snapshot.positions[row]
  if not grouped.has(key):grouped[key]=[[],[]]
  var poses:Array=grouped[key][0];var colors:Array=grouped[key][1]
  if key.begins_with("guardian-arrival-"):
   var row=undersea_row(record.owner_id)
   if row<0 or effect_snapshot.hp[row]<=0 or effect_snapshot.handles[row]!=record.handle or effect_snapshot.render_actions[row]!=CursedSpells.ARRIVAL:continue
   var spec:Dictionary=CursedSpells.manifest.summon
   var frame=mini(int(spec.updates),floori(effect_snapshot.render_time[row]*60.0+.00001))
   var size_:float=spec.scales[frame]*(effect_snapshot.body_scales[row] if effect_snapshot.has("body_scales") else 1.0)
   var pose:Color=get_parent().pose_sample(effect_snapshot,row);pose.a=spec.opacity
   poses.append(Transform3D(Basis(Vector3.UP,effect_snapshot.yaw[row]).scaled(Vector3.ONE*size_),effect_snapshot.positions[row]));colors.append(pose)
   continue
  if key in ["dark-spin_dust","dark-spin_debris"]:
   dark_spin_poses(record,poses,colors);continue
  var t=float(record.age)/record.life;var scale_=float(record.scale);var basis=Basis.IDENTITY
  if key=="bodyguard-mark":
   var row=undersea_row(record.owner_id)
   if row<0 or effect_snapshot.handles[row]!=record.handle or effect_snapshot.hp[row]<=0:continue
   poses.append(Transform3D(contact_basis.scaled(Vector3.ONE*scale_),effect_snapshot.positions[row]+Vector3.UP*record.head_height))
   colors.append(Color(0,1,0,0));continue
  if key=="ice-thaw":
   var row=undersea_row(record.owner_id)
   if row<0 or effect_snapshot.handles[row]!=record.handle or effect_snapshot.hp[row]<=0:continue
   if effect_snapshot.has("ice_visual") and effect_snapshot.ice_visual[row]>=0:continue
   foot=effect_snapshot.positions[row]
   for i in 12:
    var progress=clampf(t*1.8-float(i%4)*.16,0,1)
    var side=-1.0 if i%2==0 else 1.0
    var at=foot+contact_basis.x*(side*(.24+progress*.19)*scale_)+contact_basis.y*((.22+float(i%5)*.11-progress*progress*.44)*scale_)
    var size_=sin(progress*PI)*scale_/5.4
    poses.append(Transform3D(Basis(Vector3.FORWARD,i*.7+progress*3).scaled(Vector3.ONE*size_),at));colors.append(Color.WHITE)
   continue
  if key.begins_with("ruby-"):
   var hero_effect=record.get("hero",false)
   if hero_effect:
    if game.player.hp<=0:continue
    if record.has("guardian_status"):
     if game.player.cursed_afflictions[record.guardian_status]<=0:continue
    elif game.player.confusion_left<=0:continue
    foot=game.player.position
   elif record.owner_id!=0:
    var row=undersea_row(record.owner_id)
    if row<0 or effect_snapshot.hp[row]<=0 or effect_snapshot.handles[row]!=record.handle:continue
    foot=effect_snapshot.positions[row]
   if key.begins_with("ruby-native-"):
    var clip:Dictionary=boss_spell_clips[key.trim_prefix("ruby-native-")]
    var duration:float=clip.duration/1000.0
    var played:float=record.age
    if record.get("flight",false):
     foot+=Vector3.UP*7.0*maxf(0,1.0-record.age)
     played=maxf(0,record.age-1.0+duration)
    var frame=floori(played/duration*clip.frames)
    frame=frame%int(clip.frames) if record.get("loop",false) else mini(frame,int(clip.frames)-1)
    var pixel_size:float=Ruby.KAZ_HEIGHT*1.1/clip.reference_body_pixels if clip.has("reference_body_pixels") else CONTACT_PIXEL_SIZE
    var offset=Vector3(float(clip.bounds[0])+clip.width*.5,-float(clip.bounds[1])-clip.height*.5,.07)*pixel_size
    if record.has("guardian_status"):offset.y-=pixel_size
    if key=="ruby-native-110178" or record.get("half_height",false):foot+=Vector3.UP*Ruby.KAZ_HEIGHT*.55
    # shortcut: Fit the native cube to the 3D body; recover exact status anchors/repetition with the original scheduler.
    if record.get("confusion",false):foot+=Vector3.UP*Ruby.KAZ_HEIGHT*.6
    var effect_basis=Basis(Vector3.RIGHT,-PI/2) if record.get("ground",false) else contact_basis
    foot+=Vector3.UP*record.get("anchor_y",0.0)
    poses.append(Transform3D(effect_basis.scaled(Vector3.ONE*scale_),foot+effect_basis*offset*scale_));colors.append(Color(frame,contact_fade*record.get("opacity",.7),0,0));continue
   poses.append(Transform3D(Basis(Vector3.UP,record.age*.6).scaled(Vector3(.30,.65,1)),foot+Vector3.UP*2.0))
   colors.append(Color(record.age,contact_fade*minf(1,record.life-record.age)*.65,0,0));continue
  if key=="melee-wind":
   poses.append(record.pose);colors.append(Color(t,contact_fade,record.padding,record.arc+record.style*2.0));continue
  var contact_pose=Transform3D(contact_basis,record.position)
  if record.has("contact_depth") and camera!=null:
   contact_pose=AttackChain.centered_effect_pose(camera,record.position,Vector3.ONE,record.contact_depth)
  if key=="undersea-meditation":
   var at=foot+Vector3.UP*UNDERSEA_BODY_HEIGHT*.55+contact_basis*Vector3(4,-2,1)*CONTACT_PIXEL_SIZE*scale_
   poses.append(Transform3D(contact_basis.scaled(Vector3.ONE*scale_),at))
   colors.append(Color(floori(record.age/(2.0/60))%7,contact_fade*128.0/255,0,0));continue
  if key=="undersea-charge":
   var at=foot+Vector3.UP*UNDERSEA_BODY_HEIGHT*.55+contact_basis*Vector3(22.5,-10.5,1)*CONTACT_PIXEL_SIZE*scale_
   poses.append(Transform3D(contact_basis.scaled(Vector3.ONE*scale_),at))
   colors.append(Color(mini(8,floori(record.age*20)),contact_fade,0,0));continue
  if key=="guard-break-charge":
   var row=undersea_row(record.owner_id)
   if row<0 or effect_snapshot.handles[row]!=record.handle or effect_snapshot.render_actions[row]!=ENEMY_GUARD_BREAK_WINDUP:continue
   var at:Vector3=effect_snapshot.positions[row]+Vector3.UP*scale_*.55+contact_basis*Vector3(.12,-.03,.08)
   poses.append(Transform3D(contact_basis.scaled(Vector3.ONE*maxf(1,scale_*.5)),at))
   colors.append(Color(mini(8,floori(t*9)),contact_fade,0,0));continue
  if key=="undersea-afterimage":
   poses.append(Transform3D(Basis(Vector3.UP,record.yaw),record.position))
   colors.append(Color(record.pose.r,record.pose.g,record.pose.b,contact_fade*128.0/255));continue
  if key=="zombie-warning":
   poses.append(Transform3D(Basis(Vector3.RIGHT,-PI/2).scaled(Vector3.ONE*scale_),record.position))
   colors.append(Color(record.age,.66+.32*t,0,0));continue
  if key=="hound_summon":
   var offset=Vector3(Hound.SUMMON_CENTER.x,Hound.SUMMON_CENTER.y,.07)
   poses.append(Transform3D(contact_basis,record.position+contact_basis*offset))
   colors.append(Color(record.age,contact_fade*.25,0,0))
   continue
  if key=="maze_assassination":
   var at:Vector3=record.position+Vector3.UP*ease(minf(t*5,1.0),.4)*.6
   poses.append(Transform3D(contact_basis.scaled(Vector3.ONE*scale_),at+contact_basis.z*.15))
   colors.append(Color(0,contact_fade,0,0))
   continue
  if key=="maze_blade_dance":
   poses.append(Transform3D(contact_basis.scaled(Vector3.ONE*scale_),record.position+contact_basis*Vector3(0,0,.10)))
   colors.append(Color(floorf(record.age/BLADE_DANCE_FRAME_TIME),contact_fade,0,0))
   continue
  if key=="water-boomerang-wave":
   poses.append(Transform3D(contact_basis.scaled(Vector3.ONE*scale_),record.position+contact_basis.z*.08))
   colors.append(Color(record.facing*WATER_BOOMERANG_FRAMES+mini(WATER_BOOMERANG_FRAMES-1,floori(record.age/WATER_BOOMERANG_FRAME_TIME)),contact_fade,0,0))
   continue
  if key in ["guard-break","guard-break-ex"]:
   poses.append(Transform3D(contact_basis.scaled(Vector3.ONE*scale_),record.position+contact_basis*Vector3(.5,.5,2)*CONTACT_PIXEL_SIZE))
   var frame=mini(11,floori(12*record.age/record.life)) if key=="guard-break-ex" else mini(7,floori(record.age/.068))
   colors.append(Color(frame,contact_fade*.9,0,0))
   continue
  if key in GOLD_SPARKS:
   var at:Vector3=record.position
   if record.has("anchor"):
    var anchor=record.anchor.get_ref()
    if is_instance_valid(anchor):at=anchor.global_position+Vector3(record.anchor_offset)+contact_basis.z*.38*scale_
   poses.append(Transform3D(contact_basis.scaled(Vector3.ONE*scale_),at))
   colors.append(Color(floorf(record.age/GOLD_FRAME_TIME),contact_fade,0,0))
   continue
  if key=="joint-glyph":
   var tick_=floori(record.age*60)-int(record.delay)
   if tick_<0:continue
   var steps=mini(tick_,26)
   var entry=maxf(0,26*18-.7*26*25/2.0-(steps*18-.7*steps*(steps-1)/2.0))
   var offset=Vector3(record.offset.x+entry,-record.offset.y,0)*CONTACT_PIXEL_SIZE*scale_
   poses.append(Transform3D(contact_basis.scaled(Vector3.ONE*scale_),record.position+contact_basis*offset))
   colors.append(Color(record.glyph,minf(1,(record.life-record.age)*5),0,0))
   continue
  if key in ["shin_sure_strike","shin_double_edge","shin_combo","shin_two_birds","shin_two_birds_ex"]:
   var offset=Vector3.ZERO
   var frame_time=SHIN_COMBO_FRAME_TIME
   var width=1.0
   if key=="shin_sure_strike":
    offset=Vector3(-1,37.5,2);frame_time=SURE_STRIKE_FRAME_TIME
   elif key=="shin_double_edge":
    offset=Vector3(-3,38,2);frame_time=DOUBLE_EDGE_FRAME_TIME
   elif key=="shin_combo":width=SHIN_COMBO_WIDTH
   else:
    offset=Vector3(1,0,2);frame_time=TWO_BIRDS_FRAME_TIME
    if record.rear:width=1.35
   offset.x*=width
   offset*=CONTACT_PIXEL_SIZE*scale_
   if record.has("contact_depth"):offset=Vector3.ZERO
   poses.append(Transform3D(contact_pose.basis.scaled_local(Vector3(width,1,1)*scale_),contact_pose.origin+contact_basis*offset))
   var frame_count=11 if key=="shin_two_birds_ex" else TWO_BIRDS_FRAMES
   var frame=floorf(record.age/frame_time) if key!="shin_two_birds_ex" else minf(10,floorf(record.age*11.0/record.life))
   if record.get("rear",false):frame=frame_count-1-frame
   colors.append(Color(frame,contact_fade*.9,0,0))
   continue
  if key in ["critical","kazi_combo"]:
   # Emphasize criticals while preserving combo art's source opacity.
   var offset=Vector3.ZERO if key=="kazi_combo" else Vector3(0,.09*scale_,.065)
   poses.append(Transform3D(contact_pose.basis.scaled(Vector3.ONE*scale_),contact_pose.origin+contact_basis*offset))
   var opacity=.85 if key=="critical" else 128.0/255
   colors.append(Color(floorf(record.age/(COMBO_FRAME_TIME if key=="kazi_combo" else CRITICAL_FRAME_TIME)),contact_fade*opacity,0,0))
   continue
  if key.begins_with("finale-"):
   basis=Basis(Vector3.UP,float(record.yaw))
   if key in ["finale-sword_wave","finale-sword_cross"]:basis=Basis(Vector3.UP,float(record.yaw)+PI)
   if record.get("mirrored",false):basis.x=-basis.x
   if key=="finale-blast":scale_*=Finale.SHOT_RADIUS[4]/Finale.blast_radius
   elif key=="finale-core_rays":basis=basis.scaled(Vector3(1,1.5,1))
   elif key=="finale-burst":
    # Source 801AD700 emits eight 0x200-spaced rolls at scale 0x300/0x1000.
    for i in 8:
     poses.append(Transform3D((basis*Basis(Vector3.FORWARD,(i+.5)*TAU/8)).scaled(Vector3.ONE*scale_),record.position));colors.append(Color(record.age,1-t,0,0))
    continue
  elif key=="ring":scale_*=.25+t*.85;basis=Basis(Vector3.RIGHT,-PI/2)
  elif key in ["dark-shock_dome","dark-shock_ring"]:
   scale_*=.018*(1+record.age*30/16.0);basis=Basis(Vector3.UP,record.age*30*TAU/16*(1 if key=="dark-shock_dome" else -1))
  elif key=="dark-fragment":scale_*=.018;basis=Basis(Vector3.UP,t*TAU)
  elif key in ["dark-impact","dark-ember","dark-stomp_wave"]:pass
  elif key=="smoke":scale_*=.3+t*.7
  elif key=="dragon-eruption":basis=Basis(Vector3.UP,float(record.yaw)+sin(t*PI)*.4)
  else:scale_*=1-t
  var position_:Vector3=record.position
  if record.has("anchor"):
   var anchor=record.anchor.get_ref()
   if is_instance_valid(anchor):
    basis=Basis(Vector3.UP,atan2(-anchor.facing.x,-anchor.facing.z))
    position_=anchor.global_position+basis*Vector3(record.get("anchor_offset",Vector3.UP*1.2*Finale.SCALE))
    if record.get("mirrored",false):basis.x=-basis.x
  if record.has("rise"):position_+=Vector3.UP*record.rise*t
  if key=="finale-sky_copy" and record.has("center"):
   var turn=minf(record.age,record.orbit_left)*TAU*30/31*float(record.get("playback_rate",1.0))
   position_=record.center+(position_-Vector3(record.center)).rotated(Vector3.UP,turn);basis=Basis(Vector3.UP,record.yaw+turn)
  poses.append(Transform3D(basis.scaled(Vector3.ONE*maxf(.001,scale_)),position_));colors.append(Color(t,record.age,0,0) if key=="dragon-eruption" else Color(record.age*float(record.get("playback_rate",1.0)),1-t,0,0))
 for key in batches:
  if key in ["shield","dragon-descent"]:continue
  var rows=grouped.get(key)
  if rows==null:
   if batches[key].visible:hide_batch(batches[key])
  else:show_rows(batches[key],rows[0],rows[1])
func corpse_held(row:Dictionary)->bool:
 var target=row.overkill_target.get_ref() if row.has("overkill_target") else null
 return is_instance_valid(target) and target.sequence_users>0
func draw_corpses():
 var grouped={}
 for row in corpses:
  var kind:int=row.kind
  if not corpse_batches.has(kind):continue
  if not grouped.has(kind):grouped[kind]=[[],[]]
  var rows:Array=grouped[kind]
  var shrink=maxf(.01,1-clampf((row.age-(row.life-.2))/.2,0,1))
  var held=corpse_held(row)
  var basis=Basis(Vector3.UP,row.yaw)*Basis(Vector3.RIGHT,0.0 if held else -row.pitch)
  rows[0].append(Transform3D(basis.scaled(Vector3.ONE*shrink*row.get("body_scale",1.0)),row.position))
  if kind in [Roles.GATEKEEPER_HOUND,Roles.SLIME,Roles.CAVE_BEAR]:rows[1].append(Color(row.skin,3 if held else 4,.05 if held else row.age,0))
  else:rows[1].append(Color(Soldier.frame_state({"variant":kind},maxf(.00001,row.age)).row,0,0,0))
 for kind in corpse_batches:
  var rows=grouped.get(kind)
  if rows==null:
   if corpse_batches[kind].visible:hide_batch(corpse_batches[kind])
  else:show_rows(corpse_batches[kind],rows[0],rows[1])
func stop_pet_motion(id:int):
 var voice=pet_audio.get(id,{}).get("voice")
 if is_instance_valid(voice) and voice.get_meta("pet_motion_owner",0)==id:voice.stop()
func pet_reaction_cues(record:Dictionary,before:float,after:float):
 for cue in record.sound_clip.sounds:
  var at=float(cue.atMs)/1000.0
  if before<at and at<=after:play_sound(record.position,Pets.sounds.get(int(cue.id)),.85,35,true,true)
func pet_reaction(event:Dictionary):
 var dead=event.kind=="death"
 if not dead and float(event.hp)<=0:return
 var row=undersea_row(int(event.target_id))
 if not dead and row<0:return
 var skin=int(event.action_index) if dead else int(effect_snapshot.pose_rows[row])
 var yaw=atan2(event.direction.x,event.direction.z) if dead else float(effect_snapshot.yaw[row])
 var camera=get_viewport().get_camera_3d()
 var camera_yaw=atan2(-camera.global_basis.x.z,camera.global_basis.x.x) if camera!=null else 0.0
 var direction=posmod(roundi((camera_yaw-yaw)*4/PI)+1,8)
 var clip:Dictionary=Pets.audio_clips[skin].get((10 if dead else 8)*8+direction,{})
 for i in range(effects.size()-1,-1,-1):
  if effects[i].kind=="pet-audio" and effects[i].owner_id==int(event.target_id):effects.remove_at(i)
 if clip.is_empty():return
 var record:Dictionary=add_effect("pet-audio",event.position,float(clip.duration_ms)/1000.0,1.0,0,int(event.target_id))
 if record.is_empty():return
 record.sound_clip=clip
 record.handle=0 if dead else effect_snapshot.handles[row]
 pet_reaction_cues(record,-.000001,0)
func pet_motion_cues(clip:Dictionary,point:Vector3,before:float,after:float,id:int):
 var duration=float(clip.duration_ms)/1000.0
 for cue in clip.sounds:
  var at=float(cue.atMs)/1000.0
  if floorf((after-at)/duration)<=floorf((before-at)/duration):continue
  var stream:AudioStream=Pets.sounds.get(int(cue.id))
  if stream==null:continue
  var previous=pet_audio[id].get("voice")
  if is_instance_valid(previous) and previous.get_meta("pet_motion_owner",0)==id:previous.stop()
  var voice=play_sound(point,stream,.85,35,false,true)
  if voice!=null:voice.set_meta("pet_motion_owner",id);pet_audio[id].voice=voice
func present_pet_motion(s:Dictionary,i:int,camera_yaw:float):
 var id:int=s.handles[i];var skin:int=s.pose_rows[i]
 var pose:Color=get_parent().pose_sample(s,i)
 var slot=int(pose.g)%8
 if slot not in [0,1,5] or s.positions[i].distance_squared_to(game.player.position)>35*35:
  stop_pet_motion(id);pet_audio.erase(id);return
 var action=0 if slot==0 else int(Pets.motions().variants[skin].get("run_action",3)) if slot==1 else 1
 var direction=posmod(roundi((camera_yaw-float(s.yaw[i]))*4/PI)+1,8)
 var clip:Dictionary=Pets.audio_clips[skin].get(action*8+direction,{})
 if clip.is_empty():stop_pet_motion(id);pet_audio.erase(id);return
 var fresh=not pet_audio.has(id) or pet_audio[id].action!=action
 if fresh:
  stop_pet_motion(id);pet_audio[id]={"action":action,"time":float(pose.b)}
 pet_audio[id].frame=pet_audio_frame
 var voice=pet_audio[id].get("voice")
 if is_instance_valid(voice) and voice.get_meta("pet_motion_owner",0)==id:voice.position=s.positions[i]
 if fresh:pet_motion_cues(clip,s.positions[i],-.000001,0,id)
 else:pet_motion_cues(clip,s.positions[i],pet_audio[id].time,float(pose.b),id)
 pet_audio[id].time=float(pose.b)
func present_units(s:Dictionary):
 var poses=[];var custom=[]
 pet_audio_frame+=1
 var camera_yaw=0.0
 var camera=get_viewport().get_camera_3d()
 if camera!=null:camera_yaw=atan2(-camera.global_basis.x.z,camera.global_basis.x.x)
 for i in s.handles.size():
  if s.kinds[i]==Roles.GATEKEEPER_HOUND:present_pet_motion(s,i,camera_yaw)
  if poses.size()>=effect_capacity:continue
  if s.teams[i]!=1 or s.kinds[i]!=8 or s.air_phase[i] not in [1,2]:continue
  poses.append(DragonFX.diving_dragon_transform(s.positions[i],s.velocities[i],s.yaw[i],clampf(dragon_scale,.25,4.0)*1.15))
  custom.append(Color(.35,s.action_time[i],0,0))
 show_rows(batches["dragon-descent"],poses,custom)
 for id in pet_audio.keys():
  if pet_audio[id].frame!=pet_audio_frame:stop_pet_motion(id);pet_audio.erase(id)
func present_snapshot(s:Dictionary):
 if s.has("handles"):present_units(s)
 var shields=mini(128,mini(effect_capacity,s.shield_positions.size()))
 var shots=mini(MAX_PROJECTILES,s.projectile_ids.size())
 if shots==0 and shields==0:
  # Retire the last visible batches once, then leave them parked.
  if projectile_count>0:
   for batch in projectile_batches.values():hide_batch(batch)
  if shield_count>0:hide_batch(batches.shield)
  projectile_count=0;shield_count=0
  return
 var packed:Dictionary=native_packer.projectile_buffers(s,Soldier.SCALE/5.4,Vector2i(shots,shields))
 assert(packed.get("valid",false),"Invalid authoritative projectile snapshot")
 if not packed.get("valid",false):return
 projectile_count=shots;shield_count=shields
 var bounds=AABB(Vector3(-1000,-1000,-1000),Vector3.ONE*2000)
 if shields>0:preload("res://scripts/forest/crowd/army_renderer.gd").upload(batches.shield,packed.shields,bounds)
 elif batches.shield.visible:hide_batch(batches.shield)
 for key in projectile_batches:
  var buffer=packed.projectiles.get(key)
  if buffer!=null and not buffer.is_empty():preload("res://scripts/forest/crowd/army_renderer.gd").upload(projectile_batches[key],buffer,bounds)
  elif projectile_batches[key].visible:hide_batch(projectile_batches[key])
func clear():
 effect_snapshot={}
 effects.clear();corpses.clear();projectile_count=0;shield_count=0;last_serial=0;clock=0;next_sound=0
 pet_audio.clear();pet_audio_frame=0
 next_gold_spark=0
 for i in labels.size():label_ages[i]=0;labels[i].hide();labels[i].set_meta("hit_follow",null);labels[i].remove_meta("guard_cue")
 for voice in voices:voice.stop()
 for node in batches.values()+corpse_batches.values()+projectile_batches.values():hide_batch(node)
func counts()->Dictionary:
 var label_count=0;var playing=0
 for age in label_ages:
  if age>0:label_count+=1
 for voice in voices:
  if voice.playing:playing+=1
 return {"effects":effects.size(),"corpses":corpses.size(),"labels":label_count,"voices":playing,"projectiles":projectile_count,"shields":shield_count,"nodes":get_child_count()}

func suspend_audio():
 for voice in voices:voice.stop()

func dark_sound(point:Vector3,cue:String,foreground:bool=false,ticket:Dictionary={}):
 if not MoveAudio.ticket_audible(game,ticket):return
 if Dark.sounds.has(cue) and is_instance_valid(game):
  var playback=game.sound_library.playback_for(Dark.PLAYER,Dark.slot_for(cue),Dark.sounds[cue])
  if playback.muted:return
  if foreground:
   game.sound(Dark.slot_for(cue),1.0,false,ticket,Dark.PLAYER);return game.last_sound_voice
  return play_sound(point,playback.stream,playback.gain,Dark.SOUND_RANGE,cue=="slam")
func dark_cue(point:Vector3,cue:int,yaw:float=0.0,owner_id:int=0,playback_rate:float=1.0,spin_sign:float=1.0,play_audio:bool=true,foreground:bool=false,ticket:Dictionary={}):
 var names=["claw","fire_charge","step","","grab","throw_full","breath","fire_release","slam","","","spin","","","step"]
 if play_audio and cue>=0 and cue<names.size():dark_sound(point,names[cue],foreground,ticket)
 if cue==1:add_effect("dark-ember",point+Basis(Vector3.UP,yaw)*Dark.MOUTH,1.5,.8)
 if cue in [8,9]:add_effect("dark-stomp_wave",point+Vector3.UP*.08,56.0/30,Dark.SHOCK_RADIUS*(1.0 if cue==9 else .7)/1056.0)
 if cue==15:
  for key in ["shock_dome","shock_ring","fragment"]:
   var record=add_effect("dark-"+key,point+Vector3.UP*2,80.0/30 if key!="fragment" else .9,Dark.SCALE if key!="fragment" else 2)
   if not record.is_empty():record.age=-140.0/30
 if cue==11:
  for key in ["dark-spin_dust","dark-spin_debris"]:
   var record=add_effect(key,point,Dark.SPIN_END/30.0/playback_rate+2,1,yaw,owner_id)
   if not record.is_empty():record.rate=playback_rate;record.emit_until=Dark.SPIN_END;record.spin_sign=spin_sign

func cancel_dark_spin(owner_id:int):
 for record in effects:
  if record.owner_id==owner_id and record.kind in ["dark-spin_dust","dark-spin_debris"]:
   record.emit_until=minf(record.emit_until,record.age*record.rate*30)

func dark_spin_poses(record:Dictionary,poses:Array,colors:Array):
 # One pooled burst draws all 18 × 8 source dust puffs and 18 flying floor tiles.
 var debris:bool=record.kind=="dark-spin_debris"
 var life=2.0 if debris else .45
 for tick in range(Dark.SPIN_START,Dark.SPIN_END):
  var age:float=record.age-tick/30.0/record.rate
  if age<0 or age>=life or tick>record.emit_until:continue
  for i in (1 if debris else 8):
   var lane=posmod(tick*5,8) if debris else i
   var offset=Vector3(sin(tick*2.4+lane)*.55,0,(lane+1)*64*.018)*Dark.SCALE
   offset=offset.rotated(Vector3.UP,record.yaw+Dark.spin_turn(tick)*record.spin_sign)
   var at:Vector3=record.position+offset+Vector3.UP*(maxf(.05,.45+age*8-age*age*12) if debris else .25+age*2)*Dark.SCALE
   if debris:
    at+=Vector3(sin(tick*4.7),0,cos(tick*4.7))*age*4*Dark.SCALE
    poses.append(Transform3D(Basis.from_euler(Vector3(age*4,record.yaw+tick+age*7,age*2)).scaled(Vector3.ONE*(.25+.09*posmod(tick,4))),at));colors.append(Color(posmod(tick*7,32),0,0,0))
   else:
    var size=(.6+age*3)*Dark.SCALE*(1-age/life)
    poses.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),at));colors.append(Color(age,1-age/life,0,0))

func finale_cue(point:Vector3,cue:int,direction:Vector3=Vector3.FORWARD,owner_id:int=0,source_tick:int=0,playback_rate:float=1.0,visual_scale:float=1.0,ticket:Dictionary={}):
 var yaw=atan2(-direction.x,-direction.z)
 var sound=""
 if cue<6:
  if cue==1:
   var playback=game.sound_library.playback_for(30,"finale_wind_start",Finale.sounds.wind_start)
   if not playback.muted and MoveAudio.ticket_audible(game,ticket):
    var voice=play_sound(point,playback.stream,Finale.SOUND_GAIN.wind_start*playback.gain,Finale.SOUND_RANGE,owner_id>0)
    if voice!=null:voice.set_meta("loop_owner",owner_id);voice.set_meta("audio_ticket",ticket)
   for side in [-1,1]:
    for kind in ["finale-wind","finale-wind_outer"]:
     var wind=add_effect(kind,point+Vector3.UP*1.2*Finale.SCALE,316.0/30/playback_rate,visual_scale,yaw,owner_id)
     if not wind.is_empty():
      wind.playback_rate=playback_rate;wind.mirrored=side<0
      var controller=instance_from_id(owner_id) if owner_id>0 else null
      if is_instance_valid(controller) and is_instance_valid(controller.get("hero")):wind.anchor=weakref(controller.hero)
  elif cue in [2,3]:
   var offset=Vector3(0,64,-40)*.018*Finale.SCALE
   var aura=add_effect("finale-cast_aura",point+Basis(Vector3.UP,yaw)*offset,8.0/30/playback_rate,visual_scale,yaw,owner_id)
   if not aura.is_empty():
    aura.playback_rate=playback_rate
    var controller=instance_from_id(owner_id) if owner_id>0 else null
    if is_instance_valid(controller) and is_instance_valid(controller.get("hero")):aura.anchor=weakref(controller.hero);aura.anchor_offset=offset
  elif cue==5:add_effect("finale-sky_spark_2",point+Vector3.UP*Finale.SCALE,.8,visual_scale,yaw,owner_id)
  elif cue==4:sound="cast"
 elif cue==11:sound="sword_cross" if source_tick>88 else "sword_wave"
 elif cue==12:finale_loop(point,"wind_loop",(316-source_tick)/30.0/playback_rate,owner_id,ticket)
 elif cue==13:pass
 elif cue==14:sound="fire_fall"
 elif cue==15:
  sound="earth_impact";add_effect("finale-blast",point+Vector3.UP*.12,56.0/30,visual_scale,yaw)
  if source_tick<=40:
   for i in 16:
    var angle=i*TAU/16;var dust=add_effect("smoke",point+Vector3(sin(angle),0,cos(angle))*18*Finale.SCALE,1.25,3.5*Finale.SCALE*visual_scale,angle)
    if not dust.is_empty():dust.rise=3.0*Finale.SCALE
 elif cue==16:
  sound="sky_copy"
  var copy=add_effect("finale-sky_copy",point,(79+(source_tick-60))/30.0/playback_rate,visual_scale,yaw,owner_id)
  if not copy.is_empty():copy.center=point+direction*7*Finale.SCALE;copy.orbit_left=(91-source_tick)/30.0/playback_rate;copy.playback_rate=playback_rate
  add_effect("finale-sky_spark_0",point,.8,visual_scale,yaw)
 elif cue==17:sound="sky_launch";add_effect("finale-sky_spark_1",point,.8,visual_scale,yaw)
 elif cue==21:
  for side in [-1,1]:
   var wing=add_effect("finale-wind_gust",point,.4,Finale.WIND_VISUAL_SCALE*1.5*visual_scale,yaw)
   if not wing.is_empty():wing.mirrored=side<0
 elif cue==42:add_effect("finale-water_secondary",point,.5,visual_scale,yaw)
 elif cue in [20,22,23,25,43]:
  if cue==23:finale_loop(point,"fire_loop",2.7,owner_id,ticket)
  sound="water_burst" if cue==22 else "" if cue==23 else "impact"
  var effect="sword_wave" if cue==20 else "water" if cue==22 else "fire" if cue==23 else "sky_spark_1" if cue==25 else "sword_cross"
  add_effect("finale-"+effect,point+(Vector3.UP*.12 if cue==25 else Vector3.ZERO),1.0 if cue==22 else .8 if cue==25 else .16 if cue in [20,43] else .6,visual_scale,yaw)
 elif cue==30:
  sound="core_charge";var core=add_effect("finale-core",point+Vector3.UP*Finale.SCALE,2.2,visual_scale,yaw)
  if not core.is_empty():core.foreground=owner_id>0;core.audio_ticket=ticket
  add_effect("finale-core_open",point+Vector3.UP*Finale.SCALE,2,visual_scale,yaw);add_effect("finale-core_rays",point,2,.125,yaw);add_effect("finale-ending",point,2,.125,yaw)
 elif cue==31:cancel_finale(owner_id)
 elif cue==32:sound="cast"
 elif cue==33:sound="sword_swing"
 elif cue==34:sound="earth_rumble"
 elif cue==35:add_effect("finale-sky_spark_3",point+Vector3.UP*Finale.SCALE,.8,visual_scale,yaw)
 if not sound.is_empty():finale_sound(point,sound,owner_id>0,ticket)

func finale_sound(point:Vector3,cue:String,priority:bool=false,ticket:Dictionary={}):
 if not MoveAudio.ticket_audible(game,ticket):return
 var playback=game.sound_library.playback_for(30,"finale_"+cue,Finale.sounds[cue])
 if playback.muted:return
 var gain=float(Finale.SOUND_GAIN.get(cue,1.0))
 if priority:
  game.sound("finale_"+cue,gain,false,ticket,30);return game.last_sound_voice
 return play_sound(point,playback.stream,playback.gain*gain,Finale.SOUND_RANGE)

func cancel_finale(owner_id:int):
 if owner_id==0:return
 for i in range(effects.size()-1,-1,-1):
  if effects[i].get("owner_id",0)==owner_id:effects.remove_at(i)
 for voice in voices:
  if voice.get_meta("loop_owner",0)==owner_id:voice.stop()
func finale_loop(point:Vector3,cue:String,duration:float,owner_id:int,ticket:Dictionary={}):
 if not MoveAudio.ticket_audible(game,ticket):return
 if cue=="fire_loop" and not ticket.get("allied",false):owner_id=0
 for voice in voices:
  if voice.playing and voice.get_meta("loop_owner",0)==owner_id and voice.get_meta("finale_loop","")==cue:
   if cue=="wind_loop":voice.position=point
   voice.set_meta("loop_until",maxf(voice.get_meta("loop_until",0),clock+duration));return
 var playback=game.sound_library.playback_for(30,"finale_"+cue,Finale.sounds[cue])
 if playback.muted:return
 var stream=Finale.loops[cue] if playback.stream==Finale.sounds[cue] else game.sound_library.recorded_loop_for(30,"finale_"+cue,playback.stream)
 var voice=play_sound(point,stream,float(Finale.SOUND_GAIN.get(cue,.6))*playback.gain,Finale.SOUND_RANGE,owner_id>=0)
 if voice!=null:voice.set_meta("loop_until",clock+duration);voice.set_meta("loop_owner",owner_id);voice.set_meta("finale_loop",cue);voice.set_meta("audio_ticket",ticket)
