extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
const OUT="res://build/Other Files/Asset Toolkit/Pet Surround/"
const DT=1.0/60
var army
var home=Vector3(0,0,60)
var times=[]
var pet_radii={}
var blink_samples=0
var blink_spacing=1000.0

func key(code:int):
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;game._input(event)
func right_click():
 var event=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_RIGHT;event.position=game.crosshair_screen_position()
 event.pressed=true;root.push_input(event,true)
 event.pressed=false;root.push_input(event,true)
func tick(n:int):
 for i in n:
  var events_from:int=army.event_log.size()
  var started=Time.get_ticks_usec();army.integration_tick(DT);army.flush_presentation();times.append(Time.get_ticks_usec()-started)
  var landings={}
  for index in range(events_from,army.event_log.size()):
   var event:Dictionary=army.event_log[index]
   if event.kind=="status" and event.action_index==499:landings[event.source_id]=event.position
  for source in landings:
   var handle:int=army.handles.get(source,0)
   if not pet_radii.has(handle):continue
   for other in pet_radii:
    if other==handle or not army.valid(other):continue
    var position_:Vector3=army.unit_state(other).position
    if absf(position_.y-landings[source].y)<3:blink_spacing=minf(blink_spacing,position_.distance_to(landings[source])/(pet_radii[handle]+pet_radii[other]))
   blink_samples+=1
  if i%6==0:await frames(1)
func aim(enemy):
 var camera=game.camera_rig.camera
 camera.global_position=home+Vector3(0,6,14)
 camera.look_at(enemy.combat_bounds().get_center());camera.reset_physics_interpolation()
 await physics_frame;await physics_frame
func shot(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.crowd.present_army(army.render_snapshot(),[]);game.forest_ui.sync_pet_focus_marker()
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Captured "+name_)
func retaliation_case(pets:Array,marked:int):
 var first:int=army.event_log.size()
 right_click()
 check(army.hound_focus_target==marked,"Right click focuses the world patrol with five pets")
 var captured_guard=false
 for i in 200:
  await tick(6)
  var guard_state:Dictionary=army.unit_state(marked)
  if not captured_guard and guard_state.blocking and guard_state.action_time>.2:
   var snapshot:Dictionary=army.render_snapshot()
   var index:int=snapshot.logical_ids.find(98100)
   check(snapshot.render_actions[index]==13 and snapshot.status[index]&16,"Pet pressure publishes the actual guard pose and guard status")
   var camera:Camera3D=game.camera_rig.camera
   var view=camera.global_transform
   camera.global_position=guard_state.position+Vector3(-sin(guard_state.yaw)*10,7,-cos(guard_state.yaw)*10)
   camera.look_at(guard_state.position+Vector3.UP*1.5);camera.reset_physics_interpolation()
   await shot("world-pet-guard")
   camera.global_transform=view;camera.reset_physics_interpolation()
   captured_guard=true
 check(captured_guard,"The world patrol visibly uses its original guard pose against pets")
 var hitters={};var returns=0;var guards=0
 for event in army.event_log.slice(first):
  if event.kind=="damage" and event.target_id==98100:hitters[event.source_id]=true
  if event.kind=="damage" and event.source_id==98100:returns+=1
  if event.kind=="status" and event.source_id==98100 and event.action_index==724:guards+=1
 print("WORLD_RETALIATION contacts=",returns," pet_hitters=",hitters.size()," guards=",guards)
 check(hitters.size()==5,"All five actual pet families land their ordinary attacks")
 check(returns>=2,"The surrounded world patrol completes repeated attacks against pets")
 check(army.unit_state(marked).hp<1000000,"Stagger protection keeps the patrol vulnerable to damage")
 await shot("world-retaliation")
 key(KEY_F);await tick(1)
 check(army.hound_focus_target==0 and army.hound_order==army.HoundOrder.HOLD,"F still releases focus and holds the party")
 key(KEY_Z);await tick(1)
 check(army.hound_focus_target==0 and army.hound_order==army.HoundOrder.RETURN,"Z still recalls the party after retaliation")
 army.clear();game.queue_free();current_scene=null;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("WORLD_RETALIATION_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
func run():
 create_timer(180).timeout.connect(func():printerr("PET_FOCUS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 var exploring="--explore" in OS.get_cmdline_user_args()
 var retaliation="--retaliation" in OS.get_cmdline_user_args()
 if exploring:
  set_meta("forest_custom_layout",preload("res://scripts/forest/forest_falan_tour.gd").Regions.layout("north_coast"))
  game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
  game.settings.forest_pet_loadout=[];game.player.select_character(preload("res://scripts/rogue_roster.gd").KAZI_ID);game.start_wave();await frames(3)
 else:
  game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
  game.settings.forest_pet_loadout=[]
  game.begin_arena();game.choose_rogue_character(preload("res://scripts/rogue_roster.gd").KAZI_ID);await frames(3)
  game.equipment_hub.enter_button.pressed.emit();await frames(3)
 game.clear_menu();game.playing=true;game.paused=false;paused=false
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 army=game.army_runtime;army.set_process(false);army.set_physics_process(false);army.clear();army.record_events=true
 game.model.waves.crossgate_pet_test=true;army.refresh_kits();army.refresh_navigation(0)
 if exploring:
  var found_patch=false
  for x in range(-240,241,24):
   for z in range(-240,241,24):
    var patch=game.model.world_point(Vector2(x,z));patch.y=game.model.world_height(patch.x,patch.z)
    if army.native.ally_ground_clear(patch,20.0):home=patch+Vector3.BACK*16;found_patch=true;break
   if found_patch:break
  check(found_patch,"Exploration fixture uses an actual open clearing for the full mixed-size party")
  if not found_patch:quit(1);return
 home.y=game.model.world_height(home.x,home.z);game.player.position=home;game.model.update_vision(home/game.model.falan_scale)
 game.player.hp=game.player.max_hp;game.player.smoke_mode=true
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 game.model.next_id=98100
 var row:Dictionary=game.model.waves.spawn_enemy(Roles.SLIME,home+Vector3(0,0,-16))
 row.hp=1000000;row.max_hp=row.hp;row.footprint=.5
 if exploring:row.frontier_patrol=true;row.skin=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd").GOBLIN
 if retaliation:row.patrol_radius=14.0
 army.import_arrivals();var marked:int=army.handles[row.id]
 var enemy=army.enemy_target(98100)
 var found=false
 for direction in [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT]:
  var point=home+direction*16;point.y=game.model.world_height(point.x,point.z)
  if not army.native.can_reach(home,point,.5):continue
  army.set_pose(marked,point,0);army.sync_compatibility();await aim(enemy)
  if game.crosshair_ray_hit().get("collider")==enemy:found=true;break
 check(found,"Actual cursor ray picks a visible, reachable native enemy")
 if not found:quit(1);return
 if not retaliation:army.apply_hit(marked,{"element":"ice","status_seconds":100.0})
 var pack=Pets.sanitized([Pets.key(0),Pets.key(21),Pets.key(41),Pets.key(61),Pets.key(81)])
 var skill=Pets.Spells.COMBO if "--combo" in OS.get_cmdline_user_args() else Pets.Spells.BEE_FLURRY if "--flurry" in OS.get_cmdline_user_args() else ""
 if not skill.is_empty():
  var family=preload("res://scripts/spells/skill_levels.gd").family(skill)
  for pet in pack:
   game.settings.forest_pet_skills[pet]=[skill]
   game.model.team_progression.pet_skill_levels[pet]={family:7}
 game.settings.forest_pet_loadout=pack;army.queue_hounds()
 for i in 90:
  army.integration_tick(DT)
  if army.pending_hounds.is_empty():break
 var pets=[]
 for pet in pack:
  if army.handles.has(army.HOUND_ID-Pets.skin(pet)):
   var handle:int=army.handles[army.HOUND_ID-Pets.skin(pet)];pets.append(handle)
   var body=Dimensions.companion_body(Pets.skin(pet));pet_radii[handle]=Vector2(body.size.x,body.size.z).length()*.5
 if not retaliation:
  var bear=army.spawn(army.CAVE_BEAR_ID,1,Roles.CAVE_BEAR,home+Vector3(6,0,0),30000,1)
  army.native.set_guard(bear,home+Vector3(6,0,0),18);pets.append(bear)
  pet_radii[bear]=1.0
 if exploring:
  army.order_hounds(army.HoundOrder.HOLD);army.integration_tick(DT)
  var center:Vector3=army.unit_state(marked).position
  for i in pets.size():
   var angle=deg_to_rad(-75+i*30);var point=center+Vector3(sin(angle)*15,0,cos(angle)*15);point.y=game.model.world_height(point.x,point.z)
   check(army.native.ally_ground_clear(point,pet_radii[pets[i]]),"Prepared party approach clears the original landscape")
   army.set_pose(pets[i],point,angle);army.native.set_guard(pets[i],point,18)
  army.sync_compatibility()
 check(pets.size()==(5 if retaliation else 6),"All selected companions enter the fixture")
 if retaliation:
  await aim(enemy)
  await retaliation_case(pets,marked)
  return
 var camera=game.camera_rig.camera
 var bounds:AABB=enemy.combat_bounds()
 camera.look_at(Vector3(bounds.get_center().x,bounds.end.y+2.5,bounds.get_center().z))
 await physics_frame
 check(game.crosshair_ray_hit().get("collider")!=enemy,"Above-head aim misses the exact enemy ray")
 var kit=game.player.active_ability
 var before_cue:int=game.voice_idx
 game.player.combat_hold_left=.15
 right_click()
 game.player.combat_hold_left=0.0
 check(army.hound_focus_target==marked and not kit.is_attacking(),"Right click accepts above-head aim during player hit-stop and orders pets only")
 check(game.voice_idx==before_cue+1 and game.last_sound_voice.get_meta("kind")=="shin_target_select" and game.last_sound_voice.stream.resource_path.ends_with("/cgsys00.wav"),"A pet focus click plays the original targeting cue once")
 var serial:int=army.hound_order_serial
 key(KEY_G)
 check(army.hound_order_serial==serial and army.hound_focus_target==marked,"G leaves the current pet order alone")
 camera.look_at(camera.global_position+Vector3.UP+Vector3.FORWARD*.1)
 await physics_frame
 before_cue=game.voice_idx
 right_click()
 check(army.hound_order_serial==serial+1 and army.hound_focus_target==0 and army.hound_order==army.HoundOrder.ATTACK and game.voice_idx==before_cue,"An empty right click clears focus and attack moves without a target cue")
 await aim(enemy);key(KEY_TAB)
 check(kit.locked_primary_enemy()==enemy,"Tab locks the native enemy for the player's attacks")
 game.player.set_auto_attack(true)
 Input.action_press("heavy_attack")
 check(game.player.auto_attack_running(),"Holding right click leaves Tab auto-attack active")
 Input.action_release("heavy_attack")
 game.player.set_auto_attack(false)
 right_click()
 key(KEY_H)
 check(army.hound_focus_target==marked,"H leaves the current focus alone")
 key(KEY_Z)
 camera.look_at(camera.global_position+Vector3.UP+Vector3.FORWARD*.1)
 await physics_frame
 right_click()
 check(army.hound_focus_target==0 and army.hound_attack_move.is_finite() and kit.locked_primary_enemy()==enemy and not kit.is_attacking(),"Right click follows the cursor while preserving the player's Tab lock")
 key(KEY_Z);await aim(enemy)
 var wall=StaticBody3D.new()
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(3,8,3);shape.shape=box
 wall.add_child(shape);game.add_child(wall)
 wall.global_position=game.player.global_position.lerp(bounds.get_center(),.5)+Vector3.UP
 await physics_frame;await physics_frame
 right_click()
 check(army.hound_focus_target==0 and army.hound_order==army.HoundOrder.ATTACK,"A covered enemy cannot be marked and the pack attack moves instead")
 wall.queue_free();await physics_frame;await physics_frame
 game.paused=true;right_click();game.paused=false
 check(army.hound_focus_target==0,"Right click is ignored while paused")
 var ui=game.forest_ui
 var source_image=ui.pet_focus_marker.texture.get_image();source_image.convert(Image.FORMAT_RGBA8)
 var source_hash=HashingContext.new();source_hash.start(HashingContext.HASH_SHA256);source_hash.update(source_image.get_data())
 check(source_hash.finish().hex_encode()=="f1863c37e03a7b06d9174426e8ca41efb24b1a870cb261f4b6d31ff2946ed415","Red marker retains the exact original blue pointer pixels")
 var nodes=0;var resources=0
 for cycle in 3:
  await aim(enemy)
  right_click()
  check(army.hound_focus_target==marked,"Right click marks the enemy under the cursor")
  await tick((900 if exploring else 600) if cycle==0 else 180);ui.sync_pet_focus_marker()
  check(pets.all(func(h):return army.unit_state(h).target_id==98100),"All six companions retain the explicit target, cycle %d"%cycle)
  check(army.unit_state(marked).hp<1000000,"Focused pets land actual native damage")
  var hitters={}
  for event in army.event_log:
   if event.kind=="damage" and event.target_id==98100:hitters[event.source_id]=true
  check(pets.all(func(h):return hitters.has(army.unit_state(h).logical_id)),"Every actual pet family and the bear lands its original native contacts")
  if not skill.is_empty():
   var casters={}
   for event in army.event_log:
    if event.kind=="pet_skill_started":casters[event.source_id]=true
   check(casters.size()==5,"All five families actually use the equipped simultaneous skill")
  check(ui.pet_focus_marker.visible and ui.pet_focus_marker.texture.get_size()==Vector2(20,12) and ui.pet_focus_marker.material.get_shader_parameter("tint")==Color("ff3434"),"Marked enemy uses the original pointer with its owned red tint")
  var sectors={};var spacing=1000.0;var center:Vector3=army.unit_state(marked).position
  for h in pets:
   var point:Vector3=army.unit_state(h).position
   sectors[posmod(roundi(atan2(point.x-center.x,point.z-center.z)*4/PI),8)]=true
   for other in pets:
    if other!=h:spacing=minf(spacing,point.distance_to(army.unit_state(other).position)/(pet_radii[h]+pet_radii[other]))
  print("PET_SURROUND_RENDERED cycle=",cycle," sectors=",sectors.size()," min_spacing=",spacing)
  check(sectors.size()>=4 and spacing>=.9,"Actual mixed-size pets surround their target without stacked body footprints")
  if cycle==0:
   await shot("focused-enemy");nodes=game.crowd.army.presentation.get_child_count();resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
   game.camera_rig.camera.global_position=center+Vector3(23,33,29);game.camera_rig.camera.look_at(center+Vector3.UP)
   await shot("surround-overview");await aim(enemy)
   var before:Vector2=ui.pet_focus_marker.position
   game.camera_rig.camera.global_position+=Vector3.RIGHT*2;ui.sync_pet_focus_marker()
   check(ui.pet_focus_marker.visible and ui.pet_focus_marker.position!=before,"Overhead marker follows the projected target as the camera moves")
   game.paused=true;key(KEY_Z);ui.sync_pet_focus_marker()
   check(army.hound_focus_target==marked and not ui.pet_focus_marker.visible,"Paused commands leave focus unchanged and hide its marker")
   game.paused=false;await aim(enemy)
   root.size=Vector2i(960,640);await frames(3);ui.sync_pet_focus_marker()
   check(root.get_visible_rect().encloses(ui.pet_focus_marker.get_global_rect()),"Marker remains readable inside the smaller viewport")
   await shot("focused-enemy-small");root.size=Vector2i(1280,800);await frames(3)
  key(KEY_F);await tick(1);ui.sync_pet_focus_marker()
  check(army.hound_focus_target==0 and not ui.pet_focus_marker.visible and pets.all(func(h):return army.unit_state(h).velocity.length()<.01),"F clears the marker and holds selectable pets and bears")
  await aim(enemy);right_click();await tick(1);key(KEY_Z);await tick(1);ui.sync_pet_focus_marker()
  check(army.hound_focus_target==0 and not ui.pet_focus_marker.visible and pets.all(func(h):return army.unit_state(h).target_id==0),"Z clears focus and recalls the whole group")
  game.camera_rig.camera.look_at(home+Vector3.UP*100);await physics_frame
  right_click()
  check(army.hound_focus_target==0 and army.hound_order==army.HoundOrder.ATTACK,"Right click on empty sky starts a directional advance")
 check(game.crowd.army.presentation.get_child_count()==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources+2,"Repeated marks reuse presentation nodes/resources")
 if not skill.is_empty():
  print("PET_BLINK_SPACING samples=",blink_samples," min_spacing=",blink_spacing)
  check(blink_samples>0 and blink_spacing>=.9,"Simultaneous skill blinks keep their landing footprints clear of other pets")
 await aim(enemy);right_click();await tick(240)
 var center:Vector3=army.unit_state(marked).position
 var alternatives:Array[int]=[]
 for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
  var point=center+direction*9;point.y=game.model.world_height(point.x,point.z)
  if not army.native.can_reach(center,point,.5):continue
  var alternative:int=army.spawn(98200+alternatives.size(),0,Roles.SLIME,point,1000000,.5)
  army.apply_hit(alternative,{"element":"ice","status_seconds":100.0})
  alternatives.append(alternative)
 check(alternatives.size()>=2 and pets.all(func(h):return army.unit_state(h).target_id==98100),"The pack starts focused while other reachable enemies are alive")
 camera.look_at(camera.global_position+Vector3.UP+Vector3.FORWARD*.1);await physics_frame
 right_click();ui.sync_pet_focus_marker()
 check(not ui.pet_focus_marker.visible,"Attack move clears the red focus marker immediately")
 await tick(240)
 var pursuits=pets.map(func(h):return army.unit_state(h).target_id)
 check(army.unit_state(marked).hp>0 and pursuits.any(func(id):return id>=98200) and not pursuits.all(func(id):return id==pursuits[0]),"Empty right click selects nearby enemies along the advance after focus")
 right_click();await tick(30)
 check(pets.map(func(h):return army.unit_state(h).target_id)==pursuits,"Another empty click keeps valid directional pursuits stable")
 for alternative in alternatives:army.despawn(alternative)
 await aim(enemy);right_click();await tick(1)
 army.begin_integration(DT,true);ui.sync_pet_focus_marker()
 check(army.integration_pending,"The marker leaves the in-flight native worker alone")
 army.finish_integration()
 army.apply_hit(marked,{"amount":2000000.0,"provoke":false});await tick(1);ui.sync_pet_focus_marker()
 check(army.hound_focus_target==0 and army.hound_order==army.HoundOrder.DEFEND and not ui.pet_focus_marker.visible,"Death clears the generation-safe mark and returns to automatic defense")
 army.clear();check(army.hound_focus_target==0 and army.focused_enemy()==null,"World reset cannot retain a target reference")
 times.sort();print("PET_FOCUS_STEP_US p95=",times[int(times.size()*.95)]," max=",times[-1]," samples=",times.size())
 game.queue_free();current_scene=null;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_FOCUS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
