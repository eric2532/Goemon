extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Gear=preload("res://scripts/forest/equipment.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const PetDimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const OUT="res://build/Other Files/Asset Toolkit/Beast Master Rush/"
const DT=1.0/60.0
const SKINS=[21,42,64,0,82]
const DISTANT_TARGET_RANGE=50.0
var army

func number(slot:int,pressed:bool=true,echo:bool=false):
 var event=InputEventKey.new()
 event.physical_keycode=KEY_1+slot-1
 event.pressed=pressed
 event.echo=echo
 game.forest_ui._input(event)

func press(slot:int):
 number(slot)
 number(slot,false)

func left_click():
 var event=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT
 event.position=game.crosshair_screen_position();event.global_position=event.position
 event.pressed=true;root.push_input(event,true)
 event.pressed=false;root.push_input(event,true)

func animate_hero():
 game.player.model.animate(DT,0.0,true,0.0,0.0,false,0,false)

func pet_handle(skin:int)->int:
 return army.handles.get(army.HOUND_ID-skin,0)

func waiting()->Array:
 return SKINS.map(func(skin):return army.beast_pet_orders.get(skin,{}).get("waiting",0))

func advance(ticks:int,samples:Variant=null):
 for i in ticks:
  var started=Time.get_ticks_usec()
  army.integration_tick(DT)
  if samples!=null:samples.append(Time.get_ticks_usec()-started)
  army.flush_presentation()

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await frames(3)
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func metrics(samples:Array)->Array:
 samples.sort()
 return [samples[samples.size()/2],samples[floori((samples.size()-1)*.95)],samples.back()]

func distant_point(home:Vector3,heading:Vector3,distance:float,used:Array[Vector3])->Vector3:
 for turn in [0.0,.15,-.15,.30,-.30,.45,-.45,.60,-.60,.75,-.75]:
  var point=home+heading.rotated(Vector3.UP,turn)*distance
  point.y=game.model.world_height(point.x,point.z)
  if absf(point.y-home.y)>4.0 or not army.native.ally_ground_clear(point,4.0):continue
  if used.any(func(other):return point.distance_to(other)<12.0):continue
  return point
 return Vector3.INF

func check_strike_cover(enemy_id:int,point:Vector3):
 var source:int=army.HOUND_ID-SKINS[0]
 var first:int=army.event_log.size()
 press(1);advance(1)
 check(army.event_log.slice(first).any(func(event):return event.kind=="attack_started" and event.source_id==source),"The cover probe starts a real native strike before the obstacle changes")
 var nav:Dictionary=army.navigation_data(game.model)
 var collision:Dictionary=army.static_collision_data(game.world)
 nav.air_faces=collision.faces;nav.air_owner=collision.owners
 # Close the strike ray at the victim during windup on the same terrain patch.
 nav.ray_min=PackedVector3Array([point-Vector3(.25,.25,.25)])
 nav.ray_max=PackedVector3Array([point+Vector3(.25,8.0,.25)])
 nav.ray_owner=PackedInt64Array([-1])
 army.native.set_navigation(nav)
 advance(180)
 check(not army.event_log.slice(first).any(func(event):return event.kind=="damage" and event.source_id==source and event.target_id==enemy_id),"Cover added during windup still blocks the exact native strike")
 check(army.beast_pet_orders.is_empty(),"The blocked strike finishes and recalls its pet")
 army.navigation_revision=-1;army.refresh_navigation(0)

func run():
 create_timer(180).timeout.connect(func():printerr("BEAST_MASTER_TIMEOUT");quit(1))
 cfg="/tmp/beast-master-test-%d.cfg"%OS.get_process_id()
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1280,800)
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 army=game.army_runtime
 army.set_process(false);army.set_physics_process(false)
 game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE
 game.player.select_character(Gear.Roster.MAZE_ID)
 game.show_equipment_hub(true)
 await frames(3)
 var p=game.player
 var owner=Gear.character_key(p.character_id)
 var hub=game.equipment_hub
 var loadout=SKINS.map(func(skin):return Pets.key(skin))
 check(game.save_pet_loadout(loadout,{loadout[0]:[Pets.Spells.COMBO]}),"Saved five ordered pets in isolated Equipment settings")
 check(is_instance_valid(army.pet_skills) and army.pet_skills.casters.has(loadout[0]),"The equipped pet skill is prepared by the normal caster owner")
 var ordinary_slots:Array=p.spell_loadout.numbered_slots.duplicate(true)
 var ordinary_spells:Dictionary=p.spell_loadout.assignments(p.character_id).duplicate(true)
 check("weapon:beast-master" in hub.available_items(),"Equipment lists Beast Master for Maze")
 hub.selected_item="weapon:beast-master";hub.equip_selected()
 check(Gear.equipped(game.settings.gear_loadouts,p.character_id)=="weapon:beast-master","Equipment saves the selected Beast Master item")
 check(p.model.gear_weapon=="beast-master" and p.model.current_weapon()=="kunai","Beast Master uses the actual dagger route")
 hub.select_category_slot("accessories",Gear.ACCESSORY_SLOTS[0])
 hub.selected_item="accessory:217";hub.equip_selected()
 check(game.settings.gear_loadouts[owner].get(Gear.ACCESSORY_SLOTS[0])=="accessory:217" and not p.accessory_bonuses.has("primary"),"Equipped Fire Earrings cannot replace the Beast Master dagger")
 hub.show_page("weapons")
 p.powerups.damage=1.0
 hub.stats.refresh_attack_damage(p)
 check(hub.stats.attack_damage.text==str(roundi(Skills.BASIC_ATTACK_DAMAGE*p.base_character_attack_multiplier())),"Equipment displays the same base dagger damage while a pickup is active")
 p.powerups.damage=0.0
 await picture("equipment")
 hub.enter_map();await frames(3)
 check(game.playing and not game.paused and game.model.phase=="wave","The isolated Equipment loadout enters live combat")
 if not game.playing or game.paused or game.model.phase!="wave" or not p.model.beast_master:
  await finish();return
 army.clear();game.model.enemies.clear();game.model.waves.patrol_posts.clear()
 game.model.waves.crossgate_pet_test=true
 army.refresh_kits();army.record_events=true
 var home=Vector3(-100,0,100)
 home.y=game.model.surface_height(home.x,home.z)
 p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.smoke_mode=true
 p.set_auto_attack(false);game.model.update_vision(home)
 if is_instance_valid(game.training_dummy):
  game.training_dummy.home=home+Vector3.DOWN*1000
  game.training_dummy.position=game.training_dummy.home
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=home+Vector3(0,16,24)
 camera.look_at(home+Vector3(0,1,-2));camera.reset_physics_interpolation()
 var ui=game.forest_ui
 ui.sync()
 var weapon_icon:Texture2D=Gear.ITEMS["weapon:beast-master"].icon
 check(ui.primary_icon.texture==weapon_icon and ui.helper_portraits[5].texture==weapon_icon,"HUD uses the four-pet icon for the weapon and key 6")
 for i in SKINS.size():
  check(ui.helper_portraits[i].texture==Pets.portrait(SKINS[i]) and not ui.loadout_buttons[i].disabled,"Number %d displays the pet in the matching saved slot"%[i+1])
 check(p.spell_loadout.numbered_slots.size()==6 and p.spell_loadout.numbered_slots.all(func(slot):return slot[1]=="pet_attack"),"The six numbered bindings replace the regular skill display")

 var shots:Array=[]
 Pool.service(game).launched.connect(func(shot):
  shots.append(shot)
  shot.set_physics_process(false))
 var point=home+Vector3.FORWARD*8.0
 point.y=game.model.surface_height(point.x,point.z)
 var dagger_enemy:Dictionary=game.model.waves.spawn_enemy(army.Roles.SLIME,point)
 dagger_enemy.hp=1000000.0;dagger_enemy.max_hp=dagger_enemy.hp;dagger_enemy.footprint=.5
 army.import_arrivals();army.sync_targets();army.sync_compatibility()
 var dagger_handle:int=army.handles[dagger_enemy.id]
 var aimed_enemy:Ninja=army.enemy_target(dagger_enemy.id)
 camera.look_at(aimed_enemy.combat_bounds().get_center());camera.reset_physics_interpolation()
 await physics_frame
 p.accessory_bonuses.attack=123.0
 p.powerups.damage=1.0
 p.attack_chain.reset()
 left_click()
 check(p.active_ability.selected_primary_enemy()==aimed_enemy and p.active_ability.clip=="7","Left click selects the live target and commits the dagger throw")
 var mana_before:float=p.mana
 var spell_instance_count:int=p.spell_loadout.instances.size()
 press(1);animate_hero()
 check(p.model.current_clip.begins_with("7:") and p.model.beast_cast_wait_left>0.0,"Dagger animation takes priority while the pet gesture waits")
 for i in 120:
  p.active_ability.tick(DT);animate_hero()
  if p.model.current_clip.begins_with("6:"):break
 check(shots.size()==1,"Left click releases exactly one dagger")
 if shots.size()==1:
  check(is_equal_approx(shots[0].damage,Skills.BASIC_ATTACK_DAMAGE*p.base_character_attack_multiplier()),"Dagger damage excludes accessory attack and pickup damage bonuses")
 check(p.model.current_clip.begins_with("6:") and p.model.beast_cast_left>0.0,"The queued pet command plays the recovered casting pose after the dagger")
 var cast_left:float=p.model.beast_cast_left
 press(1)
 check(is_equal_approx(p.model.beast_cast_left,cast_left) and p.model.beast_cast_wait_left==0.0 and waiting()==[2,0,0,0,0],"A rapid tap adds an attack without restarting the casting gesture")
 check(p.mana==mana_before and p.spell_loadout.instances.size()==spell_instance_count and p.spell_loadout.current==null and p.active_ability.mode.is_empty(),"The gesture uses no mana, skill instance or combat action")
 for i in 60:animate_hero()
 press(1);animate_hero()
 check(p.model.current_clip.begins_with("6:") and p.model.beast_cast_left>0.0,"A follow-up after recovery replays the casting gesture")
 for i in 10:animate_hero()
 await picture("pet-command-pose")
 army.recall_beast_pets();p.model.clear_beast_cast();animate_hero()
 for shot in shots:
  if shot.pool_live:shot.retire()
 p.accessory_bonuses.erase("attack");p.powerups.damage=0.0;p.active_ability.cancel(true);p.impact_pause=0.0
 army.despawn(dagger_handle);army.sync_compatibility()
 camera.look_at(home+Vector3(0,1,-2));camera.reset_physics_interpolation()

 for index in SKINS.size():
  press(index+1)
  check(army.beast_pet_orders.keys()==[SKINS[index]] and waiting()[index]==1,"Key %d queues only its corresponding pet"%[index+1])
  army.recall_beast_pets()
 check(army.pending_hounds.is_empty(),"Canceling pending work removes every queued arrival")

 army.refresh_navigation(0)
 var enemy_ids:Array[int]=[]
 var enemy_points:Array[Vector3]=[]
 for post in army.PET_FORMATION_POSTS:
  var target=distant_point(home,Vector3(post.x,0,-post.z).normalized(),DISTANT_TARGET_RANGE,enemy_points)
  if not target.is_finite():continue
  enemy_points.append(target)
  var row:Dictionary=game.model.waves.spawn_enemy(army.Roles.SLIME,target)
  row.hp=1000000.0;row.max_hp=row.hp;row.footprint=.5
  enemy_ids.append(int(row.id))
 check(enemy_points.size()==5 and enemy_points.all(func(point):return Vector2(point.x-home.x,point.z-home.z).length()>=48.0),"Five enemies stand on clear ground at least 48 m from the player")
 if enemy_points.size()!=5:
  await finish();return
 army.import_arrivals()
 for enemy_id in enemy_ids:
  army.apply_hit(army.handles[enemy_id],{"element":"stun","status_seconds":30.0})
 var first:int=army.event_log.size()
 var pet_ids=SKINS.map(func(skin):return army.HOUND_ID-skin)
 press(1)
 number(1,true,true);number(1,false)
 check(waiting()==[1,0,0,0,0],"A release and OS echo add no attacks and slot 1 alone queues its pet")
 press(1);press(6)
 check(waiting()==[3,1,1,1,1] and army.pending_hounds.size()==5,"A second tap stacks and key 6 adds exactly one attack per pet")
 check(p.spell_loadout.assignments(p.character_id)==ordinary_spells,"Pet commands preserve the saved character skills")
 var summon_positions:Array[Vector3]=[]
 var first_commits:Dictionary={}
 army.integration_tick(DT)
 for event in army.presentation_events:
  if event.kind=="hound_summon":summon_positions.append(event.position)
 var first_tick:Array=army.event_log.slice(first)
 for event in first_tick:
  if event.kind=="attack_started" and event.source_id in pet_ids:first_commits[event.source_id]=1
 check(not first_tick.any(func(event):return event.kind=="damage" and event.source_id in pet_ids),"Instant summon preserves the normal attack windup before dealing damage")
 army.flush_presentation()
 var handles=SKINS.map(pet_handle)
 check(handles.all(func(handle):return handle!=0 and army.valid(handle)),"All five pets arrive in the same native tick")
 if handles.any(func(handle):return handle==0 or not army.valid(handle)):
  await finish();return
 var arrivals=handles.map(func(handle):return army.unit_state(handle))
 check(first_commits.size()==5 and arrivals.all(func(pet):return pet.beast_pet_active and pet.target_id in enemy_ids),"All five pets commit to their distant targets in the first native tick")
 var targeted:Dictionary={}
 var slot_targets:Array[int]=[]
 var body_gaps:Array[float]=[]
 var near_count=0
 for i in arrivals.size():
  var pet:Dictionary=arrivals[i]
  slot_targets.append(pet.target_id)
  if pet.target_id not in enemy_ids:continue
  targeted[pet.target_id]=true
  var bounds:AABB=army.enemy_target(pet.target_id).combat_bounds()
  var offset:Vector3=pet.position-pet.position.clamp(bounds.position,bounds.end)
  var gap=Vector2(offset.x,offset.z).length()
  var size:Vector3=PetDimensions.companion_body(SKINS[i]).size
  var radius=Vector2(size.x,size.z).length()*.5
  body_gaps.append(gap)
  if gap<=radius+.35:near_count+=1
 print("BEAST_MASTER_LANDING targets=",slot_targets," body_gaps=",body_gaps," first_ticks=",first_commits)
 check(near_count==5 and targeted.size()>=3,"Fast starts land beside the enemies and preserve spread")
 check(summon_positions.size()==5 and arrivals.all(func(pet):return summon_positions.any(func(point):return point.distance_to(pet.position)<.25)),"Each pooled summon effect appears at the corresponding pet's landing")
 var orders:Array=[]
 for pet in arrivals:
  orders.append(pet.beast_pet_attacks+int(first_commits.has(pet.logical_id)))
 check(orders==[3,1,1,1,1],"Arrivals account for every queued or committed attack")
 var previous:int=army.unit_state(handles[0]).beast_pet_attacks
 press(1)
 check(pet_handle(SKINS[0])==handles[0] and army.unit_state(handles[0]).beast_pet_attacks==previous+1,"Tapping after arrival extends the same pet's queue")
 ui.sync()
 check(ui.loadout_buttons.slice(0,6).all(func(button):return button.button_pressed),"The HUD highlights all five active pets and key 6")
 camera.global_position=home+Vector3(0,116,72);camera.look_at(home);camera.reset_physics_interpolation()
 await picture("five-pet-landing")
 for i in 12:
  advance(60)
  if army.beast_pet_orders.is_empty():break
 var events:Array=army.event_log.slice(first)
 var starts:Array=[]
 var damaging_pets:=0
 for skin in SKINS:
  var source:int=army.HOUND_ID-skin
  starts.append(events.filter(func(event):return event.kind=="attack_started" and event.source_id==source).size())
  if events.any(func(event):return event.kind=="damage" and event.source_id==source and event.amount>0.0 and event.target_id in enemy_ids):damaging_pets+=1
 check(starts==[4,1,1,1,1],"Pets execute precisely the queued ordinary attacks: %s"%[starts])
 check(damaging_pets==5,"All five native ordinary attacks reach an exact strike against a real distant target")
 check(not events.any(func(event):return event.kind.begins_with("pet_skill_")),"Beast Master does not cast the equipped pet skill")
 check(army.beast_pet_orders.is_empty() and handles.all(func(handle):return not army.valid(handle)),"Pets automatically recall after their attacks finish")
 ui.sync()
 check(ui.loadout_buttons.slice(0,6).all(func(button):return not button.button_pressed),"Recall clears all pet and whole-party active indicators")
 press(1)
 advance(5)
 var reused=pet_handle(SKINS[0])
 check(reused!=0 and reused!=handles[0] and not army.valid(handles[0]) and army.native.beast_pet_busy(reused),"A later tap reuses the summon with a fresh native handle")

 game.show_equipment_hub(true);await frames(3)
 hub=game.equipment_hub
 hub.selected_item="weapon:sword";hub.equip_selected();hub.enter_map()
 await frames(3)
 check(p.model.gear_weapon=="sword" and p.spell_loadout.numbered_slots==ordinary_slots,"Switching to sword restores the original numbered skills")
 check(p.accessory_bonuses.get("primary")=="fire","The unchanged Fire Earrings resume their normal effect on sword")
 check(army.beast_pet_orders.is_empty() and army.pending_hounds.is_empty() and not army.valid(reused),"Weapon switch immediately clears pending work and recalls its live pet")
 check(game.settings.forest_pet_loadout==loadout and Gear.equipped(game.settings.gear_loadouts,p.character_id)=="weapon:sword","Weapon switch retains the ordered five-pet loadout")
 number(1);number(1,false)
 check(army.beast_pet_orders.is_empty(),"Regular numbered input no longer orders Beast Master pets")
 p.active_ability.cancel(true)

 var draft:Dictionary=game.settings.gear_loadouts.duplicate(true)
 draft[owner]["1"]="weapon:beast-master"
 check(game.save_equipment_loadouts(draft,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Re-equipping Beast Master uses the same saved item")
 var idle:Array=[]
 advance(120,idle)
 press(6);advance(240)
 await frames(3)
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var repeated:Array=[]
 for cycle in 4:
  press(6);advance(240,repeated)
  check(army.beast_pet_orders.is_empty() and not SKINS.any(func(skin):return pet_handle(skin)!=0),"Targeted attacks complete and the party recalls in repeat cycle %d"%[cycle+1])
 await frames(3)
 var node_growth=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes
 var resource_growth=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 print("BEAST_MASTER_NATIVE_STEP_USEC p50,p95,max idle=",metrics(idle)," repeated=",metrics(repeated)," warm_node_growth=",node_growth," warm_resource_growth=",resource_growth)
 check(node_growth<=0 and resource_growth<=0,"Warm repeated summons retain no extra nodes or resources")
 for id in enemy_ids.slice(1):army.despawn(army.handles[id])
 check_strike_cover(enemy_ids[0],enemy_points[0])
 army.despawn(army.handles[enemy_ids[0]])
 var far_point=distant_point(home,Vector3.FORWARD,62.0,[])
 check(far_point.is_finite(),"A 62 m enemy has an open placement outside the summon radius")
 if far_point.is_finite():
  var far_enemy:Dictionary=game.model.waves.spawn_enemy(army.Roles.SLIME,far_point)
  army.import_arrivals()
  var far_handle:int=army.handles[far_enemy.id]
  army.apply_hit(far_handle,{"element":"stun","status_seconds":30.0})
  var first_far:int=army.event_log.size()
  press(6)
  army.integration_tick(DT)
  check(army.presentation_events.all(func(event):return event.kind!="hound_summon") and army.beast_pet_orders.is_empty(),"An enemy beyond 60 m produces no arrival")
  check(not army.event_log.slice(first_far).any(func(event):return event.kind=="attack_started" and event.source_id in pet_ids),"No pet commits to the enemy beyond the player-centered radius")
  army.flush_presentation()
  army.despawn(far_handle)
 var first_empty:int=army.event_log.size()
 press(6)
 var empty_flashes=0
 for i in 6:
  army.integration_tick(DT)
  empty_flashes+=army.presentation_events.filter(func(event):return event.kind=="hound_summon").size()
  army.flush_presentation()
 check(army.beast_pet_orders.is_empty() and not SKINS.any(func(skin):return pet_handle(skin)!=0),"An empty-field order leaves the party offstage")
 check(empty_flashes==0 and not army.event_log.slice(first_empty).any(func(event):return event.kind=="attack_started" and event.source_id in pet_ids),"An empty field produces neither a summon flash nor an empty swing")
 if DisplayServer.get_name()!="headless":await picture("after-recall")
 await finish()

func finish():
 army.clear()
 game.sound_library.cancel();game.music.stop();game.queue_free();current_scene=null;paused=false
 await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("BEAST_MASTER_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
