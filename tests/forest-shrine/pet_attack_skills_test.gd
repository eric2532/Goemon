extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Qi=preload("res://scripts/qigong_combat.gd")
const OUT="res://build/Other Files/Asset Toolkit/Qi Skill Selection/Pet Casting/"
const DT=1.0/60
var home=Vector3(-100,0,100)
var shots:Array=[]
var costs:Array[int]=[]
var driver
var hit_anchors:Array=[]
func simultaneous_skins()->Array:return [0,21,41,61,81]
func advance(_dt:float=DT):
 var started=Time.get_ticks_usec()
 game.army_runtime.integration_tick(DT)
 for shot in shots:
  if is_instance_valid(shot) and shot.pool_live:shot._physics_process(DT)
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(DT)
 game.army_runtime.flush_presentation()
 costs.append(Time.get_ticks_usec()-started)
func spawn(offset:Vector3,hp_:float=1000000)->Ninja:
 var at=home+offset;at.y=game.model.surface_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(Roles.SLIME,at);row.hp=hp_;row.max_hp=hp_
 game.army_runtime.import_arrivals();game.army_runtime.sync_targets()
 return game.army_runtime.enemy_target(row.id)
func equip_pack(skins:Array,loadouts:Array):
 var army=game.army_runtime
 army.clear();game.model.enemies.clear();await frames(2);game.enemies=game.enemies.filter(is_instance_valid)
 game.settings.forest_pet_loadout=skins.map(func(skin):return Pets.key(skin))
 game.settings.forest_pet_skills={}
 for i in skins.size():game.settings.forest_pet_skills[Pets.key(skins[i])]=loadouts[i]
 army.refresh_kits();army.queue_hounds()
 for tick in 100:
  advance()
  if army.pending_hounds.is_empty():break
 check(army.pending_hounds.is_empty(),"Every selected pet arrives through the native guard lifecycle")
 shots.clear();army.event_log.clear()
 for i in skins.size():
  var handle:int=army.handles[army.HOUND_ID-skins[i]]
  var point=home+Vector3((i-2)*10,0,0);point.y=game.model.surface_height(point.x,point.z)
  army.set_pose(handle,point,0);army.native.set_guard(handle,point,18)
func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation();game.forest_ui.sync();await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Captured "+name_)
func run():
 create_timer(300).timeout.connect(func():printerr("PET_ATTACK_SKILLS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime;var fx=game.crowd.army.presentation
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false)
 p.select_character(34);fresh();home.y=game.model.surface_height(home.x,home.z)+.05;p.position=home+Vector3.RIGHT*30
 game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;army.refresh_kits();army.record_events=true
 for node in [game,p,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true;game.model.update_vision(home)
 game.impact_confirmed.connect(func(enemy,_strength,_time):hit_anchors.append(AttackChain.effect_anchor(enemy).position))
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):
  if is_instance_valid(shot.hero) and shot.hero.get("pet_key")!=null:shots.append(shot);shot.set_physics_process(false))
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 # Native pets with one, two, three, four and six contacts all share the cast total.
 var skins_by_count={}
 for skin in Pets.COUNT:skins_by_count[Pets.attack_pattern(skin).contacts.size()]=skin
 for count_ in skins_by_count:
  var skin:int=skins_by_count[count_]
  game.camera_rig.camera.global_basis=Basis(Vector3.UP,(int(Pets.attack_pattern(skin).direction)-1)*PI/4.0)
  await equip_pack([skin],[[Pets.Spells.SURE_STRIKE,"",""]])
  var handle:int=army.handles[army.HOUND_ID-skin];var at:Vector3=army.unit_state(handle).position
  var victim=spawn(at-home+Vector3.FORWARD*3)
  var view=Basis(Vector3.UP,(int(Pets.attack_pattern(skin).direction)-1)*PI/4.0)
  game.camera_rig.camera.global_position=at+view*Vector3(0,6,16)
  game.camera_rig.camera.look_at(at+Vector3(0,2,-1.5))
  hit_anchors.clear()
  var before=victim.hp;var source=army.HOUND_ID-skin;var contact_count=0;var expected=0
  var captured_contact=false
  for tick in 240:
   if skin==20 and DisplayServer.get_name()!="headless":await driver.advance(1,advance)
   else:advance()
   if skin==20 and not captured_contact and not hit_anchors.is_empty():
    captured_contact=true
    for effect in fx.effects:
     if effect.kind=="shin_sure_strike":effect.age=5*fx.SURE_STRIKE_FRAME_TIME
    await capture("hound-six-contact-skill")
   var starts=army.event_log.filter(func(event):return event.kind=="pet_skill_started" and event.source_id==source)
   if not starts.is_empty():expected=roundi(1.0/float(starts[0].amount))
   contact_count=army.event_log.filter(func(event):return event.kind=="pet_skill_contact" and event.source_id==source).size()
   if expected>0 and contact_count>=expected:break
  var hits=army.event_log.filter(func(event):return event.kind=="damage" and event.get("sure_strike_effect")!=null)
  var caster=army.pet_skills.casters[Pets.key(skin)]
  check(caster.charge.texture==caster.ShineTiers.textures["110103"] and caster.charge.scale.is_equal_approx(Vector3.ONE*caster.Skills.shine_factor(caster.ticket)),"Pet shine uses the shared saved tier and modifiers")
  print("PET_CONTACT_REVIEW skin=",skin," max=",count_," expected=",expected," contacts=",contact_count," damage=",before-victim.hp," hits=",hits.map(func(event):return [event.amount,event.get("sure_strike_effect"),event.get("source_id")])," body=",victim.combat_bounds())
  check(expected==count_ and contact_count==expected,"Pet skin %d releases on all %d native contacts"%[skin,count_])
  check(is_equal_approx(before-victim.hp,275),"Level-one pet 乾坤 shares its level-rule damage across its real contacts")
  check(hits.size()==expected and hits.all(func(event):return hit_anchors.has(event.sure_strike_effect.position)),"Every confirmed pet hit has one enemy-body explosion")
 game.camera_rig.yaw=0
 # Every offered ranged attack really launches and damages through the existing pool.
 for id in Pets.SKILLS:
  if id in [Pets.Spells.SURE_STRIKE,Pets.Spells.COMBO,Pets.Spells.BEE_FLURRY,Pets.Spells.BODYGUARD]:continue
  var skin:=20 if id==Pets.Spells.MOON else 0
  await equip_pack([skin],[[id,"",""]])
  if skin==20:game.camera_rig.camera.global_basis=Basis.IDENTITY
  var handle:int=army.handles[army.HOUND_ID-skin];var at:Vector3=army.unit_state(handle).position
  var victim=spawn(at-home+Vector3.FORWARD*12);var before=victim.hp;var expected=0
  army.apply_hit(victim.handle,{"element":"ice","status_seconds":10.0})
  army.order_hounds(army.HoundOrder.HOLD)
  var focused:bool=id=="kazi/qigong"
  if focused:
   var decoy=spawn(at-home+Vector3.RIGHT*6)
   army.apply_hit(decoy.handle,{"element":"ice","status_seconds":10.0})
   check(army.order_hounds(army.HoundOrder.ATTACK,victim.handle),"A ranged pet accepts a focused target with a closer enemy present")
   game.camera_rig.camera.global_position=at+Vector3(9,9,7)
   game.camera_rig.camera.look_at(at+Vector3(0,1,-6))
  var grounded_charge=false
  var checked_aim=false
  for tick in 240:
   advance()
   if focused and not checked_aim and not shots.is_empty():
    checked_aim=true
    check(shots[0].target==victim and is_equal_approx(float(shots[0].attack_ticket.native_strike_fraction),1.0),"The first Qi orb carries full cast damage toward the focused enemy")
    for flight in 10:advance()
    await capture("focused-ranged-pet")
   if not grounded_charge and id in ["kazi/fire","kazi/ice","kazi/wind","kazi/meteor"]:
    var caster=army.pet_skills.casters[Pets.key(skin)]
    if caster.controllers[id].charge_fx.visible:
     check(caster.controllers[id].charge_fx.global_position.is_equal_approx(caster.global_position),"Pet %s charge rises from its feet"%id)
     grounded_charge=true
   var starts=army.event_log.filter(func(event):return event.kind=="pet_skill_started")
   if not starts.is_empty():expected=roundi(1.0/float(starts[0].amount))
   if expected>0 and army.event_log.filter(func(event):return event.kind=="pet_skill_contact").size()>=expected:break
  army.native.set_guard(handle,at,0)
  for tick in 240:advance()
  check(not shots.is_empty() and shots.all(func(shot):return shot.attack_ticket.is_empty() or shot.attack_ticket.get("allied",false)),"Pet %s uses prepared allied projectiles"%id)
  if id in ["kazi/qigong",Pets.Spells.MAZE_QI]:
   check(not shots.is_empty() and shots.all(func(shot):return float(shot.visual.get_instance_shader_parameter("gold_palette"))==0.0 and float(shot.visual.get_instance_shader_parameter("uru_palette"))==0.0 and shot.visual.get_instance_shader_parameter("qi_tint")==Color.WHITE),"Pet %s defaults to the same blue Qi, including saved color aliases"%id)
  var contacts_=army.event_log.filter(func(event):return event.kind=="pet_skill_contact")
  check(not contacts_.is_empty() and contacts_[0].position.distance_to(at)<.02 and contacts_[0].target_id==victim.forest_id,"Pet %s casts toward its chosen enemy without closing to melee"%id)
  if id==Pets.Spells.MOON:
   var moon=army.pet_skills.casters[Pets.key(skin)].controllers[id]
   check(expected==1 and Pets.attack_pattern(skin).contacts.size()==6 and shots.size()==moon.skill_count(Qi.MOON_SHOTS,moon.ticket),"Moon releases its full quota on the actual one-contact facing")
  if focused:check(checked_aim,"The focused ranged cast released a real projectile")
  check(victim.hp<before,"Pet %s causes real native enemy damage"%id)
  check(pool.misses==0,"Pet %s prepares capacity outside combat"%id)
  if id in ["kazi/fire","kazi/ice","kazi/wind","kazi/meteor"]:check(grounded_charge,"Pet %s displayed a grounded charge"%id)
 # Live count changes also warm pet-owned pools and apply to the next combo.
 await equip_pack([0],[["kazi/qigong","",""]])
 game.update_skill_balance("kazi/qigong","count",32)
 var prepared=army.pet_skills.casters[Pets.key(0)].controllers["kazi/qigong"]
 check(pool.all[prepared.pool_key].size()>=64,"Changing a pet's orb count warms both overlapping volleys before use")
 var orb_handle:int=army.handles[army.HOUND_ID];var orb_at:Vector3=army.unit_state(orb_handle).position
 spawn(orb_at-home+Vector3.FORWARD*3)
 for tick in 240:
  advance()
  if army.event_log.filter(func(event):return event.kind=="pet_skill_contact").size()>=1:break
 # Saved count 32 adds 24 to level one's quota of 1, all on the first contact.
 check(shots.size()==25 and pool.misses==0,"A pet applies +24 saved orbs to its level-one quota: %d launches, no pool misses"%shots.size())
 check(shots.all(func(shot):return shot.start_delay>=0.0 and shot.start_delay<=.05 and is_equal_approx(shot.visual.scale.x*Qi.Shot.DIAMETER,shot.effect_height*shot.skill_factor("size")*.3)),"A pet's complete 40% smaller Qi volley starts within 50 ms")
 game.reset_skill_balance("kazi/qigong")
 for limit in [8,3]:
  await equip_pack([0],[[Pets.Spells.COMBO,"",""]])
  game.update_skill_balance(Pets.Spells.COMBO,"count",limit)
  var combo_handle:int=army.handles[army.HOUND_ID];var combo_at:Vector3=army.unit_state(combo_handle).position
  var victims=[]
  for i in 9:victims.append(spawn(combo_at-home+Vector3((i%3-1)*12,0,-4-floori(i/3.0)*12),1.0))
  var hops=int(preload("res://scripts/spells/skill_balance.gd").effective(army.pet_skills.casters[Pets.key(0)],Pets.Spells.COMBO,"count"))
  for tick in 1200:
   advance()
   var contacts=army.event_log.filter(func(event):return event.kind=="pet_skill_contact" and event.source_id==army.HOUND_ID)
   if contacts.size()>=hops*Pets.attack_pattern(0).contacts.size():break
  check(army.event_log.filter(func(event):return event.kind=="death" and event.team==0).size()==1,"Pet combo keeps %d level-plus-tuning hops on one defeated target"%hops)
  var still=army.unit_state(combo_handle).position
  army.order_hounds(army.HoundOrder.HOLD)
  for tick in 120:advance()
  check(army.unit_state(combo_handle).position.distance_to(still)<.02,"Hold cancels a pet combo without another blink")
 game.reset_skill_balance(Pets.Spells.COMBO)
 # Three ready skills are chosen separately, and each keeps its own cooldown.
 await equip_pack([0],[[Pets.Spells.SURE_STRIKE,"kazi/qigong","kazi/fire"]])
 var handle:int=army.handles[army.HOUND_ID];var at:Vector3=army.unit_state(handle).position
 spawn(at-home+Vector3.FORWARD*3)
 for tick in 1200:advance()
 var starts=army.event_log.filter(func(event):return event.kind=="pet_skill_started")
 var choices=[]
 for event in starts:
  if not choices.has(int(event.action_index)):choices.append(int(event.action_index))
 check(choices.size()==3,"The native pet randomly uses all three equipped attacks")
 # A dead, recalled or replaced caster cannot keep producing late skill hits.
 army.despawn(handle);var hp_before=game.model.enemies.values().map(func(row):return row.hp)
 for tick in 240:advance()
 check(game.model.enemies.values().map(func(row):return row.hp)==hp_before,"Recalling a pet cancels every leased projectile and queued effect")
 await equip_pack([0],[["kazi/qigong","",""]])
 handle=army.handles[army.HOUND_ID];at=army.unit_state(handle).position
 spawn(at-home+Vector3.FORWARD*3)
 for tick in 240:
  advance()
  if not shots.is_empty():break
 # A recent enemy contact can briefly protect the pet; wait for a legal lethal hit.
 for tick in 60:
  if army.apply_hit(handle,{"amount":1000000.0}).get("dead",false):break
  advance()
 hp_before=game.model.enemies.values().map(func(row):return row.hp)
 for tick in 240:advance()
 check(army.pet_skills.casters[Pets.key(0)].native_handle==0 and game.model.enemies.values().map(func(row):return row.hp)==hp_before,"Native pet death retires its caster and prevents late projectile damage")
 army.queue_hounds()
 for tick in 100:
  advance()
  if army.pending_hounds.is_empty():break
 check(army.handles.has(army.HOUND_ID) and army.handles[army.HOUND_ID]!=handle and army.pet_skills.casters[Pets.key(0)].native_handle==army.handles[army.HOUND_ID],"Resummoning binds the saved skills to a fresh native handle")
 # Same five pets and twenty enemies, with ordinary attacks, for a local timing baseline.
 await equip_pack(simultaneous_skins(),[["","",""],["","",""],["","",""],["","",""],["","",""]])
 for i in 20:spawn(Vector3((i%5-2)*10,0,-5-floori(i/5.0)*8))
 for tick in 1800:advance()
 await frames(3)
 var baseline_start=costs.size()
 for tick in 1200:advance()
 var baseline=costs.slice(baseline_start);baseline.sort()
 print("PET_BASIC_STEP_US p95=",baseline[floori(baseline.size()*.95)]," max=",baseline.back())
 # A five-pet pack uses the same system simultaneously without setup growth.
 await equip_pack(simultaneous_skins(),[[Pets.Spells.SURE_STRIKE,"kazi/qigong","kazi/fire"],[Pets.Spells.SURE_STRIKE,Pets.Spells.MOON,"kazi/ice"],[Pets.Spells.SURE_STRIKE,"kazi/wind","kazi/meteor"],[Pets.Spells.SURE_STRIKE,Pets.Spells.MAZE_QI,Pets.Spells.SPIRIT],[Pets.Spells.SURE_STRIKE,"kazi/qigong","kazi/fire"]])
 for i in 20:spawn(Vector3((i%5-2)*10,0,-5-floori(i/5.0)*8))
 for tick in 1800:advance()
 await frames(3)
 var steady_start=costs.size()
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created
 for tick in 1200:advance()
 await frames(3)
 var steady=costs.slice(steady_start);steady.sort()
 print("PET_STEADY_STEP_US p95=",steady[floori(steady.size()*.95)]," max=",steady.back()," nodes=",nodes,"/",get_node_count()," resources=",resources,"/",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.created==created and pool.misses==0,"Repeated five-pet casting keeps warmed nodes, resources and projectile capacity")
 check(army.pet_skills.casters.size()==5,"Only the selected five pets own prepared skill adapters")
 game.camera_rig.camera.global_position=home+Vector3(10,25,30);game.camera_rig.camera.look_at(home+Vector3(0,2,-10))
 await capture("five-pets-casting")
 if DisplayServer.get_name()!="headless":
  var rendered:Array[int]=[];var previous=Time.get_ticks_usec()
  for frame in 180:
   await driver.advance(1,advance)
   await process_frame
   var now=Time.get_ticks_usec();rendered.append(now-previous);previous=now
  rendered.sort();print("PET_RENDERED_FRAME_US p95=",rendered[floori(rendered.size()*.95)]," max=",rendered.back())
 for voice in game.voices:voice.stop()
 costs.sort();print("PET_SKILL_STEP_US p95=",costs[floori(costs.size()*.95)]," max=",costs.back()," pool_created=",pool.created," pool_misses=",pool.misses)
 game.queue_free();paused=false;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_ATTACK_SKILLS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
