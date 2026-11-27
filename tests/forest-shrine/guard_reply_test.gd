extends "res://tests/forest-shrine/crossgate_primary_targeting_test.gd"

const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const GuardCapture="res://build/Other Files/Asset Toolkit/Guard Reply/"
const ChargeCapture="res://build/Other Files/Asset Toolkit/Enemy Charge/"
const EnemyBreakCapture="res://build/Other Files/Asset Toolkit/Enemy Guard Break/"
const SkillRushCapture="res://build/Other Files/Asset Toolkit/Targeted Skills/"
var exploring:bool

func guard_key(down:bool):
 var event=InputEventKey.new();event.physical_keycode=KEY_X;event.pressed=down
 root.push_input(event,true)

func opponent(distance:float)->Ninja:
 var at=home+Vector3.FORWARD*distance
 at.y=game.model.world_height(at.x,at.z)
 var army=game.army_runtime
 var row=game.model.waves.spawn_enemy(20,at)
 row.hp=10000;row.max_hp=row.hp
 if exploring:row.frontier_patrol=true;row.skin=1
 army.import_arrivals();army.sync_targets()
 return army.enemy_target(row.id)

func aim_reply_target(target:Ninja):
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=home+Vector3(0,3.5,8)
 camera.look_at(AttackChain.aim_point(target));camera.make_current()
 await physics_frame

func charge_case(response:String)->float:
 var p=game.player;var army=game.army_runtime
 await settle(p.RogueRoster.KAZI_ID)
 p.timed_dodge.shadow_counter_enabled=false
 var target=opponent(7.0);var handle=target.handle
 await aim_reply_target(target)
 p.active_ability.primary_tab_target=weakref(target)
 p.auto_attack_enabled=false
 if response=="brace":
  key();key(false)
  check(not p.timed_dodge.reacting,"Space before the cue leaves X available for the impact")
 var actions=[]
 await driver.advance(1,func(_dt):
  for i in 150:
   advance(1)
   var action:int=army.unit_state(handle).action
   if actions.is_empty() or actions.back()!=action:actions.append(action)
   if army.native.hero_dodge_threat().get("charge",false):break)
 var threat:Dictionary=army.native.hero_dodge_threat()
 var state:Dictionary=army.unit_state(handle)
 print("CHARGE_CASE response=",response," actions=",actions," warning=",threat)
 check(threat.get("charge",false) and threat.source_id==target.forest_id and actions.has(719),"The map patrol winds up and shows ! before impact")
 if not threat.get("charge",false):return 0.0
 p.timed_dodge.hide()
 var voice_before:int=game.voice_idx
 p.timed_dodge._process(0)
 check(p.timed_dodge.visible and game.voice_idx==voice_before,"The actual player ! cue is visible and silent for a charge")
 if response=="brace":await capture_charge("charge-windup",target)
 var before:float=p.hp
 var first_event:int=army.event_log.size()
 if response=="brace":guard_key(true)
 if response=="dodge":
  key();key(false)
  check(p.timed_dodge.reacting,"Physical Space accepts the incoming charge warning")
 await driver.advance(1,func(_dt):
  for i in 130:
   advance(1)
   if army.unit_state(handle).action==721:break)
 state=army.unit_state(handle)
 var contacts:Array=army.event_log.slice(first_event).filter(func(event):return event.kind=="external_damage" and event.action_index==720 and event.source_id==target.forest_id)
 check(state.action==721,"Charge reaches a finite recovery")
 if response=="brace":
  check(p.guard_reply_left>0 and p.hp<before and state.position.z<p.position.z,"Holding X before impact takes chip and stops the attacker in front")
  await capture_charge("charge-block",target)
  guard_key(false)
 elif response=="dodge":
  check(p.hp==before and absf(p.position.x-home.x)>.35 and state.position.z>home.z,"Space moves sideways and the charge goes past without damage")
 else:
  check(p.hp<before and state.position.z<p.position.z,"An unbraced charge hits and stops in front of the player")
  await capture_charge("charge-unbraced-stop",target)
 check(contacts.size()==(0 if response=="dodge" else 1),"The charge delivers at most one contact")
 var stopped:Vector3=state.position
 await driver.advance(1,func(_dt):advance(15))
 check(army.unit_state(handle).position.distance_to(stopped)<.001,"The charge stays stopped during recovery: "+response)
 return before-p.hp

func capture_charge(name_:String,target:Ninja):
 if DisplayServer.get_name()=="headless":return
 DirAccess.make_dir_recursive_absolute(ChargeCapture)
 var camera:Camera3D=game.camera_rig.camera
 var previous=camera.global_transform
 camera.global_position+=Vector3(6,1,0)
 camera.look_at(game.player.global_position.lerp(target.global_position,.5)+Vector3.UP*1.5)
 camera.reset_physics_interpolation()
 game.army_runtime.flush_presentation()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(ChargeCapture+name_+".png")==OK,"Captured "+name_)
 camera.global_transform=previous;camera.reset_physics_interpolation()

func capture_guard_cue(target:Ninja,stem:String):
 if DisplayServer.get_name()=="headless":return
 var camera:Camera3D=game.camera_rig.camera
 var view=camera.global_transform
 camera.global_position=target.position+Vector3(11,4,10)
 camera.look_at(target.combat_head()-Vector3.UP*.8)
 camera.reset_physics_interpolation()
 game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 DirAccess.make_dir_recursive_absolute(SkillRushCapture)
 await RenderingServer.frame_post_draw
 var path=SkillRushCapture+("north-coast" if exploring else "arena")+"-"+stem+".png"
 check(root.get_texture().get_image().save_png(path)==OK,"Captured "+stem+" during actual play")
 camera.global_transform=view
 camera.reset_physics_interpolation()

func guard_break_case():
 var p=game.player;var army=game.army_runtime;var id:int=p.RogueRoster.KAZI_ID
 game.model.waves.crossgate_pet_test=true;army.refresh_kits()
 var skill:String=p.spell_loadout.Catalog.GUARD_BREAK
 game.settings.gear_loadouts={Gear.character_key(id):{"1":"weapon:sword"}}
 await settle(id)
 var archer:int=p.RogueRoster.LANCELOT_ID
 var bow_gear={Gear.character_key(archer):{"1":"weapon:bow"}}
 var bow_skills={Gear.Roster.loadout_key(archer,game.settings):{"equip":skill}}
 check(Gear.skill_weapon_error(bow_gear,bow_skills,archer,game.settings).begins_with("Equip a melee weapon"),"A bow-only loadout receives the Guard Break requirement")
 game.show_equipment_hub(true)
 var hub=game.equipment_hub
 hub.show_page("skills")
 check(hub.collection.has("skill:"+skill),"Guard Break appears in Equipment Skills when carrying a sword")
 hub.assign_skill(skill)
 check(p.spell_loadout.spell_for(id,"equip")==skill,"Guard Break saves from the Equipment Skills picker")
 game.back_from_equipment()
 p.auto_attack_enabled=false
 var kit=p.active_ability
 var args=OS.get_cmdline_user_args()
 var ex="--ex" in args
 var level_=30 if ex else 10 if "--mid" in args else 1
 kit.Skills.set_level(p,skill,level_)
 check(game.skill_card_targets().has(skill)==(not ex),"Guard Break takes skill cards until level 30")
 var shine_id="111016" if ex else "110102" if level_==10 else "110103"
 var visual_scale=1.0+.01*(level_-1)
 var target=opponent(kit.primary_reach()*.4)
 var at=target.position
 army.native.set_pose(target.handle,at,PI)
 await aim_reply_target(target)
 kit.primary_tab_target=weakref(target)
 var press=func(down:bool):
  var event=InputEventKey.new();event.physical_keycode=KEY_1;event.pressed=down
  root.push_input(event,true)
 var before:float=target.hp
 p.mana=p.max_mana
 var mana_before:float=p.mana
 guard_key(true);press.call(true);press.call(false);guard_key(false)
 check(game.forest_ui.message=="Release X to use Guard Break" and p.mana==mana_before,"The numbered key tells a guarding player to release X")
 game.forest_ui.message=""
 var open_position:Vector3=p.position+Vector3.FORWARD*(kit.primary_reach()+target.combat_bounds().size.z*.5+2.6)
 open_position.y=game.model.world_height(open_position.x,open_position.z)
 var start_position:Vector3=p.position
 army.native.set_pose(target.handle,open_position,PI);army.sync_targets()
 press.call(true);press.call(false)
 check(kit.mode=="primary_approach" and p.mana==mana_before,"An open target still starts the Guard Break approach")
 await driver.advance(1,func(_dt):
  for tick in 20:
   if kit.mode!="primary_approach":break
   advance(1,false))
 check(p.position.distance_to(start_position)>1.0 and kit.clip=="6" and p.mana==mana_before-5,"The missed attempt still rushes and spends mana on the charge")
 check(p.model.combo_glow.texture==kit.ShineTiers.textures[shine_id] and p.model.combo_glow.visible,"The missed attempt still shows the recovered charge flash")
 await driver.advance(1,func(_dt):
  for tick in 20:
   if kit.clip!="6":break
   advance(1,false))
 check(kit.is_attacking() and kit.clip=="5" and kit.ticket.has("guard_break_target"),"The missed attempt still plays the equipped weapon's swing")
 click_attack()
 check(kit.ticket.has("guard_break_target") and not kit.state.has("next_primary_target"),"A normal click cannot replace or queue through the wasted swing")
 await driver.advance(1,func(_dt):
  for tick in 120:
   if not kit.is_attacking():break
   advance(1,false))
 check(not kit.is_attacking() and target.hp==before and game.forest_ui.message.is_empty(),"The full attempt finishes with zero damage and no HUD announcement")
 var presentation=game.crowd.army.presentation
 check(presentation.labels.any(func(label):return label.visible and label.text=="Miss" and label.position.y>target.combat_bounds().end.y),"Miss appears above the attempted target")
 check(not presentation.effects.any(func(effect):return effect.kind in ["guard-break","guard-break-ex"]),"The miss plays no Guard Break impact sheet")
 await capture_guard_cue(target,"miss")
 p.position=start_position;p.velocity=Vector3.ZERO
 army.native.set_pose(target.handle,at,PI);army.sync_targets()
 army.record_events=false
 await driver.advance(1,func(_dt):
  for i in 3:
   army.native.set_pose(target.handle,at,PI)
   target.take_hit(10,Vector3.FORWARD,false,{"action":"kazi_sword","critical":false})
   advance(10)
  for i in 40:
   if army.unit_state(target.handle).blocking:break
   advance(1))
 check(army.unit_state(target.handle).blocking,"Three frontal hits make the native enemy raise its guard")
 army.flush_presentation()
 var fx=game.crowd.army.presentation
 var snapshot=army.render_snapshot()
 var index:int=snapshot.handles.find(target.handle)
 var guard_pose:Color=game.crowd.army.pose_sample(snapshot,index)
 check(int(guard_pose.g)==262 and is_equal_approx(guard_pose.b,snapshot.render_time[index]),"The guarding enemy uses its own guard clip clock with the silhouette border")
 check(fx.labels.any(func(label):return label.visible and label.text=="!" and label.modulate==fx.GUARD_CUE_COLOR and label.position.y>target.combat_bounds().end.y),"The blue exclamation mark appears above the guarded target")
 await capture_guard_cue(target,"guard")
 army.native.set_pose(target.handle,at,PI);army.sync_targets()
 army.record_events=true
 var event_start:int=army.event_log.size()
 before=target.hp
 p.mana=4.0
 press.call(true);press.call(false)
 check(not kit.is_attacking() and p.mana==4,"Even a guarding target requires at least five mana")
 game.forest_ui.message=""
 await driver.advance(1,func(_dt):advance(10))
 var distant:Vector3=p.position+Vector3.FORWARD*(kit.primary_reach()+target.combat_bounds().size.z*.5+2.6)
 distant.y=game.model.world_height(distant.x,distant.z)
 army.native.set_pose(target.handle,distant,PI);army.sync_targets()
 check(not kit.primary_in_range(target,Vector3.FORWARD),"The guarding target starts outside exact contact reach")
 p.mana=50
 mana_before=p.mana
 var origin:Vector3=p.position
 kit.primary_tab_target=weakref(target)
 press.call(true);press.call(false)
 check(kit.mode=="primary_approach" and kit.selected_primary_enemy()==target and p.mana==mana_before,"Guard Break accepts the distant Tab target without paying for travel")
 await driver.advance(1,func(_dt):
  for i in 20:
   if kit.mode!="primary_approach":break
   advance(1))
 check(p.position.distance_to(origin)>1.0,"Guard Break rushes into equipped melee reach")
 check(kit.is_attacking() and kit.clip=="6" and kit.ticket.has("guard_break_target") and p.mana==mana_before-5,"Guard Break charges the original shine and spends five mana on a guarding target")
 # Put the active guard comfortably inside the swing after checking the real approach.
 var contact_position:Vector3=p.position+Vector3.FORWARD*kit.primary_reach()*.6
 contact_position.y=game.model.world_height(contact_position.x,contact_position.z)
 army.native.set_pose(target.handle,contact_position,PI);army.sync_targets()
 var glow:Sprite3D=p.model.combo_glow
 var shine_diameter:float=357.0*glow.pixel_size*glow.get_parent().global_basis.get_scale().x*glow.scale.x
 check(glow.texture==kit.ShineTiers.textures[shine_id] and is_equal_approx(shine_diameter,kit.Skills.BASE_DIAMETER*1.25*visual_scale),"Guard Break uses the recovered tier sheet and level-scaled starting shine")
 kit.Skills.set_level(p,skill,29 if ex else level_+1)
 check(is_instance_valid(game.last_sound_voice) and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_FLASH and game.last_sound_voice.get_meta("kind")=="cg_guard_break_charge","Guard Break plays recovered sound cue 251")
 if DisplayServer.get_name()!="headless":
  DirAccess.make_dir_recursive_absolute(SkillRushCapture)
  await driver.advance(1,func(_dt):advance(4))
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(SkillRushCapture+("north-coast-charge" if exploring else "arena-charge")+".png")==OK,"Captured the recovered charge")
 var expected:float=50*(1.8+.2*(level_-1))*p.damage_multiplier()*p.attack_chain.damage_for(kit.ticket)
 await driver.advance(1,func(_dt):
  for frame in 60:
   if not kit.is_attacking() or target.hp<before:break
   advance(1))
 var hits_:Array=army.event_log.slice(event_start).filter(func(event):return event.kind=="damage" and event.target_id==target.forest_id and event.action_index==722)
 check(hits_.size()==1 and expected>0 and is_equal_approx(before-target.hp,expected) and not army.unit_state(target.handle).blocking,"Guard Break deals full skill damage in one hit and drops the native guard")
 check(game.forest_ui.message.is_empty(),"Guard Break leaves the top HUD clear")
 army.flush_presentation()
 snapshot=army.render_snapshot()
 check(game.crowd.army.pose_sample(snapshot,snapshot.handles.find(target.handle)).g<256,"The outline clears as soon as the native guard breaks")
 check(not fx.labels.any(func(label):return label.visible and label.has_meta("guard_cue")),"The mark clears as soon as the guard breaks")
 var head_y:float=target.combat_bounds().end.y if exploring else target.position.y+fx.Slime.HURT_HEAD_HEIGHT
 check(fx.labels.any(func(label):return label.visible and label.text=="Guard Break" and label.font==fx.BATTLE_TEXT_FONT and label.position.y>head_y),"Guard Break uses small Cross Gate lettering above the target's hurt pose")
 var effect_kind="guard-break-ex" if ex else "guard-break"
 check(fx.effects.any(func(effect):return effect.kind==effect_kind and is_equal_approx(effect.scale,visual_scale)),"A confirmed guard break plays the tier and scale snapshotted at cast start")
 var impact_atlas:Texture2D=fx.batches[effect_kind].multimesh.mesh.material.get_shader_parameter("atlas")
 var original_sheet="res://assets/characters/crossgate/"+("skill_tiers/111052.png" if ex else "hit_feedback/guard-break.png")
 check(impact_atlas.resource_path==original_sheet,"The pooled burst uses the recovered Guard Break sheet")
 if DisplayServer.get_name()!="headless":
  await driver.advance(1,func(_dt):advance(16,false))
  await capture_guard_cue(target,"break")

func snow_hound_guard_case():
 var army=game.army_runtime
 var key_="original:2821"
 var skin=Pets.skin(key_)
 await settle(game.player.RogueRoster.KAZI_ID)
 army.reconcile_pet_loadout()
 var at=home+Vector3.FORWARD*6
 at.y=game.model.world_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(19,at)
 row.skin=skin;row.hp=10000;row.max_hp=row.hp;row.facing=PI
 army.import_arrivals();army.sync_targets()
 var target=army.enemy_target(row.id)
 await driver.advance(1,func(_dt):
  for i in 3:
   army.native.set_pose(target.handle,at,PI)
   target.take_hit(10,Vector3.FORWARD,false,{"action":"kazi_sword","critical":false})
   advance(10)
  for i in 50:
   if army.unit_state(target.handle).blocking:break
   advance(1))
 var state=army.unit_state(target.handle)
 check(state.blocking and state.pose_row==skin,"The glacier hellhound raises its native guard")
 var mesh=game.crowd.army.meshes[19]
 var page:int=Pets.motions().atlas_paths.find("res://assets/characters/crossgate/guard_pets/snow_hound_guard/atlas-0.png")
 check(page in mesh.get_meta("prepared_pages"),"The authentic hellhound guard atlas is prepared before combat")
 army.flush_presentation()
 var fx=game.crowd.army.presentation
 check(fx.labels.any(func(label):return label.visible and label.has_meta("guard_cue")),"The hellhound shows its Guard Break cue")
 if DisplayServer.get_name()!="headless":
  var camera:Camera3D=game.camera_rig.camera
  camera.global_position=at+Vector3(9,3,8)
  camera.look_at(at+Vector3.UP*2)
  camera.reset_physics_interpolation()
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(SkillRushCapture+"snow-hound-guard.png")==OK,"Captured the hellhound's original blocking pose")
 await driver.advance(1,func(_dt):
  for i in 90:
   if not army.unit_state(target.handle).blocking:break
   advance(1))
 army.flush_presentation()
 check(not fx.labels.any(func(label):return label.visible and label.has_meta("guard_cue")),"The mark clears when guard expires")

func area_skill_approach(skill:String,weapon:String):
 var p=game.player;var army=game.army_runtime
 var ranged=weapon=="bow"
 var id:int=p.RogueRoster.LANCELOT_ID if ranged else p.RogueRoster.KAZI_ID
 game.settings.gear_loadouts={Gear.character_key(id):{"1":"weapon:"+weapon}}
 await settle(id);p.set_auto_attack(false)
 check(p.spell_loadout.equip(id,"equip",skill),"Equipped the requested skill")
 var kit=p.active_ability
 var target=place_target(16.0 if ranged else kit.primary_reach()+3.5)
 await aim_sword(target)
 kit.primary_tab_target=weakref(target)
 var before:float=target.hp
 var origin:Vector3=p.position
 var mana:float=p.mana
 tap("equip")
 if ranged:
  check(kit.ticket.get("skill_id")==skill and kit.selected_primary_enemy()==target,"The bow charges on the selected enemy from its current range")
 else:
  check(kit.mode=="primary_approach" and kit.selected_primary_enemy()==target and p.mana==mana,"The melee skill queues the aimed enemy before committing mana")
  click_attack()
  check(kit.state.get("approach_skill")==skill,"A regular click does not replace the queued skill")
 var landed:Dictionary={}
 var event_start:int=army.event_log.size()
 await driver.advance(1,func(_dt):
  for i in 150:
   advance(1,false)
   if kit.clip=="6":landed.merge(kit.ticket)
   for shot in shots:
    if shot.pool_live:shot._physics_process(DT)
   if target.hp<before:break)
 check(landed.get("skill_id")==skill and target.hp<before,"The selected enemy takes the equipped skill's contact")
 check(p.position.distance_to(origin)<.2 if ranged else p.position.distance_to(origin)>1.0,"The skill uses regular weapon spacing")
 check(army.event_log.slice(event_start).any(func(event):return event.kind=="damage" and event.target_id==target.forest_id),"The selected hit uses native combat")
 for shot in shots:
  if shot.pool_live:shot.retire()
 shots.clear()

func click_chain():
 var p=game.player
 var id:int=p.RogueRoster.SHIN_ID
 game.settings.gear_loadouts={Gear.character_key(id):{"1":"weapon:sword"}}
 await settle(id);p.set_auto_attack(false)
 var kit=p.active_ability
 var first=place_target(kit.primary_reach()*.65)
 var second=place_target(kit.primary_reach()+2.6,3.5)
 await aim_sword(first)
 var cue:int=game.voice_idx
 kit.primary_tab_target=weakref(first)
 click_attack()
 kit.primary_tab_target=weakref(second)
 click_attack()
 check(game.voice_idx==cue+2 and kit.selected_primary_enemy()==first,"A quick second click confirms immediately without interrupting the first swing")
 var rush=[false,0.0]
 await driver.advance(1,func(_dt):
  for i in 120:
   var before:Vector3=p.position
   advance(1,false)
   rush[0]=rush[0] or kit.state.get("approach_rushing",false)
   rush[1]=maxf(rush[1],before.distance_to(p.position))
   if kit.mode=="attack" and kit.selected_primary_enemy()==second:break)
 check(first.hp<first.max_hp and kit.selected_primary_enemy()==second,"The first hit lands and the queued click reaches the new target")
 check(rush[0] and rush[1]<=kit.PRIMARY_RUSH_SPEED*DT+.05,"The character covers the gap in a bounded dash")
 var before:float=second.hp
 cue=game.voice_idx
 click_attack()
 check(game.voice_idx==cue+1,"A third click during the next swing gets immediate feedback")
 await driver.advance(1,func(_dt):advance(130,false))
 check(kit.primary_combo_hits==3 and second.hp<before and not kit.is_attacking(),"Three clicks land three attacks and leave the fighter ready")

func priority_skill_case():
 var p=game.player
 var id:int=p.RogueRoster.SHIN_ID
 var skill:String=p.spell_loadout.Catalog.SURE_STRIKE
 await settle(id);p.set_auto_attack(false)
 check(p.spell_loadout.equip(id,"equip",skill),"Equipped 乾坤 for the priority test")
 var kit=p.active_ability
 var target=place_target(kit.primary_reach()*.55)
 await aim_sword(target)
 kit.primary_tab_target=weakref(target)
 click_attack();click_attack()
 var base:float=kit.primary_attack_tempo()
 tap("equip")
 check(kit.state.get("next_area_skill",{}).get("id")==skill and not kit.state.has("next_primary_target"),"A skill press replaces a buffered click during the normal windup")
 var cue:int=game.voice_idx
 click_attack()
 check(game.voice_idx==cue and is_equal_approx(kit.primary_attack_tempo(),minf(p.ATTACK_SPEED_CAP,base*1.5)),"The current swing speeds up and clicks yield to the skill")
 var before:float=target.hp
 await driver.advance(1,func(_dt):
  for i in 100:
   advance(1,false)
   if kit.clip=="6":break)
 check(target.hp<before and kit.primary_combo_hits==1 and kit.ticket.get("skill_id")==skill,"The normal attack connects before the priority skill charges")
 before=target.hp
 await driver.advance(1,func(_dt):advance(100,false))
 check(target.hp<before and kit.primary_combo_hits==1 and not kit.is_attacking(),"The skill hits next and the displaced click stays cleared")

func enemy_guard_break_case(release:bool):
 var p=game.player;var army=game.army_runtime
 game.model.waves.crossgate_pet_test=true
 await settle(p.RogueRoster.KAZI_ID)
 var target=opponent(1.7)
 var handle=target.handle
 army.native.set_pose(handle,target.position,PI)
 await aim_reply_target(target)
 p.auto_attack_enabled=false
 guard_key(true)
 check(p.crossgate_guarding(),"Physical X raises the player's guard")
 var before:float=p.hp
 army.record_events=false
 await driver.advance(1,func(_dt):
  for i in 20:
   advance(1)
   if army.unit_state(handle).action==723:break)
 check(army.unit_state(handle).action==723,"A guard-capable enemy charges against a blocking player")
 army.flush_presentation()
 var fx=game.crowd.army.presentation
 check(fx.effects.any(func(effect):return effect.kind=="guard-break-charge" and effect.handle==handle),"The compact event plays the original charge on the attacker")
 check(fx.labels.any(func(label):return label.visible and label.text=="崩擊 · Release X"),"The charge shows the release prompt")
 check(fx.voices.any(func(voice):return voice.stream==SoundLibrary.CROSSGATE_FLASH),"The enemy uses the recovered charge cue")
 if release:guard_key(false)
 if not release:await capture_enemy_break("windup",8)
 army.record_events=true
 var first:int=army.event_log.size()
 await driver.advance(1,func(_dt):
  for i in 100:
   advance(1)
   if army.unit_state(handle).action==0 or p.hp<before:break)
 var contacts:Array=army.event_log.slice(first).filter(func(event):return event.kind=="external_damage" and event.source_id==target.forest_id)
 if release:
  check(contacts.is_empty() and p.hp==before and p.combat_hold_left==0,"Releasing X makes the entire committed guard break miss")
 else:
  check(contacts.size()==1 and contacts[0].action_index==722,"Holding X through contact receives exactly one guard break")
  if contacts.size()==1:
   var defense:float=p.team_progression.stat_incoming_multiplier(p.food_defense()) if p.uses_level_stats() else 100.0/(100.0+p.food_defense())
   check(is_equal_approx(before-p.hp,contacts[0].amount*game.tuning.enemy_damage*defense),"Enemy Guard Break bypasses the ordinary block damage reduction")
  check(not p.defend_held and p.guard_reply_left==0 and p.combat_hold_left>0,"Guard Break ends guard, staggers the player, and leaves no guard reply")
  army.flush_presentation()
  check(fx.effects.any(func(effect):return effect.kind=="guard-break"),"A broken player guard shows the recovered impact")
  await capture_enemy_break("impact",6)
 guard_key(false)

func capture_enemy_break(stem:String,ticks:int):
 if DisplayServer.get_name()=="headless":return
 if ticks>0:
  await driver.advance(1,func(_dt):advance(ticks))
  game.army_runtime.flush_presentation()
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(EnemyBreakCapture)
 check(root.get_texture().get_image().save_png(EnemyBreakCapture+("north-coast-" if exploring else "arena-")+stem+".png")==OK,"Captured enemy guard break "+stem)

func swing_damage(target:Ninja,critical:bool=false)->float:
 var kit=game.player.active_ability
 var before:float=target.hp
 var events:Array[Dictionary]=game.army_runtime.event_log
 var first_event=events.size()
 shots.clear()
 await driver.advance(1,func(_dt):
  for i in 180:
   if kit.is_attacking():kit.advance_attack(DT)
   for shot in shots:
    if shot.pool_live:shot._physics_process(DT))
 for shot in shots:
  if shot.pool_live:shot.retire()
 var contacts=events.slice(first_event).filter(func(event):return event.kind=="damage" and event.target_id==target.forest_id)
 check(not contacts.is_empty() and contacts.all(func(event):return event.critical==critical),"Every landed contact carries the expected critical flag (%s)"%critical)
 return before-target.hp

func reply_case(id:int,weapon:String):
 var p=game.player
 game.settings.gear_loadouts={Gear.character_key(id):{"1":"weapon:"+weapon}}
 await settle(id)
 p.timed_dodge.shadow_counter_enabled=false
 var kit=p.active_ability
 var target=opponent(12.0 if kit.primary_is_ranged() else kit.primary_reach()*.4)
 await aim_reply_target(target)
 guard_key(true);guard_key(false)
 click_attack()
 check(kit.mode=="attack" and kit.selected_primary_enemy()==target and not kit.ticket.get("guard_reply",false),weapon+" attacks normally after an empty guard")
 var normal_rate:float=kit.primary_attack_tempo()
 var normal_action:String=kit.ticket.get("action","")
 var normal_damage:float=await swing_damage(target)
 p.attack_chain.reset();kit.reset_primary_combo();p.impact_pause=0;p.invuln=0
 if weapon=="bow":p.accessory_bonuses.primary="random-shot"
 guard_key(true)
 var hp_:float=p.hp
 p.take_hit_from(16,Vector3.BACK,false,target.forest_id)
 check(p.defend_held and p.hp<hp_ and p.guard_reply_left>0,weapon+" primes on an accepted X block")
 click_attack()
 check(kit.mode.is_empty() and p.guard_reply_left>0,weapon+" waits for X release")
 guard_key(false)
 kit.primary_tab_target=weakref(target)
 p.auto_attack_enabled=true
 check(not p.auto_attack_running(),weapon+" reserves the reply for a left click")
 p.auto_attack_enabled=false
 click_attack()
 check(kit.mode=="attack" and kit.ticket.get("guard_reply",false) and kit.ticket.get("action","")==normal_action and p.guard_reply_left==0,weapon+" spends the reply on the equipped attack")
 var tempo:float=minf(p.ATTACK_SPEED_CAP,normal_rate*1.5)
 check(is_equal_approx(kit.primary_attack_tempo(),tempo),weapon+" runs at 1.5× up to the speed cap")
 await driver.advance(1,func(_dt):advance(1,false))
 check(is_equal_approx(kit.elapsed,DT*tempo),weapon+" advances the actual pose and contact clock faster")
 check(normal_damage>0 and is_equal_approx(await swing_damage(target,true),normal_damage*2.0),weapon+" guarantees double damage at zero base critical chance")
 p.accessory_bonuses.erase("primary")
 click_attack()
 check(kit.mode=="attack" and not kit.ticket.get("guard_reply",false),weapon+" spends the faster attack only once")
 kit.cancel(true)

func run():
 create_timer(240).timeout.connect(func():printerr("GUARD_REPLY_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800)
 var args=OS.get_cmdline_user_args()
 var snow_hound="--snow-hound" in args
 exploring="--explore" in args
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(Tour.Indoor.layout(Tour.Winter.SNOW_CAVE) if snow_hound else Tour.Regions.layout("north_coast") if exploring else doc.data)
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.army_runtime.record_events=true
 game.training_dummy.position=Vector3.DOWN*1000;game.music.stop();game.tuning.invincible=false
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 if snow_hound:
  home=game.model.world_point(Tour.Indoor.safe_point(Tour.Winter.SNOW_CAVE,Vector2.ZERO,game.model.seed_value))
 elif exploring:
  check(game.model.falan_area=="north_coast" and not game.model.waves.patrol_posts.is_empty(),"Loaded the north-coast exploration map and its patrol kits")
  game.army_runtime.refresh_navigation(0)
  var found=false
  for x in range(-240,241,24):
   for z in range(-240,241,24):
    var point:Vector3=game.model.world_point(Vector2(x,z))
    if game.army_runtime.native.ally_ground_clear(point,20.0):
     home=point;found=true;break
   if found:break
  check(found,"Exploration uses a real north-coast clearing")
 home.y=game.model.world_height(home.x,home.z)+.05
 game.model.update_vision(home/game.model.falan_scale)
 preload("res://scripts/character_projectile_pool.gd").service(game).launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 if snow_hound or "--guard-break" in args or "--enemy-guard-break" in args or "--skill-approach" in args:
  if snow_hound:await snow_hound_guard_case()
  elif "--skill-approach" in args:
   await area_skill_approach(game.player.spell_loadout.Catalog.SURE_STRIKE,"sword")
   await area_skill_approach(game.player.spell_loadout.Catalog.DOUBLE_EDGE,"sword")
   await area_skill_approach(game.player.spell_loadout.Catalog.SURE_STRIKE,"bow")
   await click_chain()
   await priority_skill_case()
  elif "--enemy-guard-break" in args:
   await enemy_guard_break_case(true)
   await enemy_guard_break_case(false)
  else:await guard_break_case()
  game.queue_free();current_scene=null;await frames(3)
  if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
  print("SKILL_APPROACH_RESULT" if "--skill-approach" in args else "GUARD_BREAK_RESULT"," explore=",exploring," checks=",checks," failures=",failures)
  quit(1 if failures else 0)
  return
 if "--charges" in OS.get_cmdline_user_args():
  await charge_case("dodge")
  var unbraced:float=await charge_case("unbraced")
  var braced:float=await charge_case("brace")
  check(unbraced>0 and is_equal_approx(braced,unbraced*.25),"X applies the existing 75% guard reduction to the charge")
  game.queue_free();current_scene=null;await frames(3)
  if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
  print("ENEMY_CHARGE_RESULT checks=",checks," failures=",failures)
  quit(1 if failures else 0)
  return
 var p=game.player;var roster=p.RogueRoster
 game.model.waves.crossgate_pet_test=true
 game.select_shin_skin(roster.SHIN_ID,900050)
 for weapon in ["sword","axe","polearm","staff","bow","kunai","boomerang","three-weapon"]:
  await reply_case(roster.SHIN_ID,weapon)
 await reply_case(roster.KAZI_ID,"sword")
 await reply_case(roster.LANCELOT_ID,"unarmed")
 await reply_case(roster.MAZE_ID,"kunai")
 var target=game.army_runtime.enemy_target(game.model.enemies.keys()[0])
 guard_key(true);p.invuln=0;p.take_hit_from(16,Vector3.BACK,false,target.forest_id);guard_key(false)
 await driver.advance(1,func(_dt):advance(60,false))
 click_attack()
 check(p.guard_reply_left==0 and p.active_ability.is_attacking() and not p.active_ability.ticket.get("guard_reply",false),"An old block expires and the click attacks normally")
 await settle(roster.KAZI_ID)
 target=opponent(2.0)
 await aim_reply_target(target)
 await driver.advance(1,func(_dt):
  for i in 100:
   advance(1)
   if game.army_runtime.native.hero_dodge_threat().get("source_id")==target.forest_id:break)
 check(game.army_runtime.native.hero_dodge_threat().get("source_id")==target.forest_id,"The ordinary strike commits before X is pressed")
 guard_key(true)
 await driver.advance(1,func(_dt):
  for i in 180:
   advance(1)
   if p.guard_reply_left>0:break)
 check(p.guard_reply_left>0 and p.hp<p.max_hp,"An actual native enemy strike primes the reply")
 guard_key(false);click_attack()
 check(p.active_ability.ticket.get("guard_reply",false) and p.active_ability.selected_primary_enemy()==target,"X release and click answer that live enemy with the equipped sword")
 check(await swing_damage(target,true)>0,"The reply to that native strike lands a critical hit")
 game.army_runtime.flush_presentation()
 var presentation=game.crowd.army.presentation
 check(presentation.effects.any(func(effect):return effect.kind=="critical"),"The guard counter draws the existing critical burst")
 check(presentation.labels.any(func(label):return label.visible and label.font_size==52),"The guard counter shows the larger critical damage number")
 if DisplayServer.get_name()!="headless":
  DirAccess.make_dir_recursive_absolute(GuardCapture)
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(GuardCapture+("north-coast-critical" if exploring else "arena-critical")+".png")==OK,"Captured the critical feedback in gameplay")
 p.active_ability.cancel(true);p.accessory_bonuses.primary="fire"
 guard_key(true);p.invuln=0;p.take_hit_from(16,Vector3.BACK,false,target.forest_id);guard_key(false)
 click_attack()
 check(p.active_ability.is_attacking() and p.active_ability.ticket.get("guard_reply",false) and p.active_ability.ticket.get("action","")=="kazi_sword","The Fire accessory leaves the equipped sword available for the reply")
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GUARD_REPLY_RESULT explore=",exploring," checks=",checks," failures=",failures)
 quit(1 if failures else 0)
