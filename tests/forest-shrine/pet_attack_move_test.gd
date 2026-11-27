extends "res://tests/forest-shrine/pet_focus_test.gd"

const EVIDENCE="res://build/Other Files/Asset Toolkit/Attack Move/"
var pack_handles=[]

func ground_aim(point:Vector3):
 var camera=game.camera_rig.camera
 camera.global_position=game.player.position+Vector3(0,24,22)
 camera.look_at(point);camera.reset_physics_interpolation()
 await physics_frame;await physics_frame

func capture_move(label_:String):
 if DisplayServer.get_name()=="headless":return
 DisplayServer.window_move_to_foreground()
 game.crowd.present_army(army.render_snapshot(),[])
 var camera=game.camera_rig.camera
 camera.global_position=home+Vector3(42,65,48);camera.look_at(home+Vector3(0,0,-22))
 camera.reset_physics_interpolation();await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(EVIDENCE+label_+".png")==OK,"Captured "+label_)

func enemy_at(id:int,offset:Vector3)->int:
 var point=home+offset;point.y=game.model.world_height(point.x,point.z)
 var handle:int=army.spawn(id,0,Roles.SLIME,point,1000000,.5)
 army.apply_hit(handle,{"element":"ice","status_seconds":100.0,"provoke":false})
 return handle

func run():
 create_timer(180).timeout.connect(func():printerr("PET_ATTACK_MOVE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(EVIDENCE);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.settings.forest_pet_loadout=[]
 game.playing=false;game.begin_arena();game.choose_rogue_character(preload("res://scripts/rogue_roster.gd").KAZI_ID);await frames(3)
 if is_instance_valid(game.equipment_hub):game.equipment_hub.enter_button.pressed.emit();await frames(3)
 game.clear_menu();game.playing=true;game.paused=false;paused=false
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 army=game.army_runtime;army.set_process(false);army.set_physics_process(false);army.clear();army.record_events=true
 game.model.waves.crossgate_pet_test=true;army.refresh_kits();army.refresh_navigation(0)
 home=Vector3(0,0,60);home.y=game.model.world_height(home.x,home.z)
 game.player.position=home;game.player.hp=game.player.max_hp;game.player.smoke_mode=true
 game.model.update_vision(home/game.model.falan_scale)
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 var pack=Pets.sanitized([Pets.key(0),Pets.key(21),Pets.key(41),Pets.key(61),Pets.key(81)])
 game.settings.forest_pet_loadout=pack;army.queue_hounds()
 for i in 90:
  army.integration_tick(DT)
  if army.pending_hounds.is_empty():break
 for pet in pack:pack_handles.append(army.handles[army.HOUND_ID-Pets.skin(pet)])
 var bear:int=army.spawn(army.CAVE_BEAR_ID,1,Roles.CAVE_BEAR,home+Vector3(6,0,0),30000,1)
 army.native.set_guard(bear,home+Vector3(6,0,0),18);pack_handles.append(bear)
 for i in pack_handles.size():
  var point=home+Vector3((i-2.5)*2,0,0);point.y=game.model.world_height(point.x,point.z)
  army.set_pose(pack_handles[i],point,0)
 army.sync_compatibility()
 var behind=enemy_at(98101,Vector3(0,0,9))
 var side=enemy_at(98102,Vector3(30,0,0))
 var front=enemy_at(98103,Vector3(0,0,-18))
 var destination=home+Vector3(0,0,-55);destination.y=game.model.world_height(destination.x,destination.z)
 await ground_aim(destination);right_click()
 check(army.hound_order==army.HoundOrder.ATTACK and army.hound_focus_target==0 and army.hound_attack_move.is_finite(),"Real RMB on empty ground issues an attack-move destination")
 check(army.external_targets().hound_attack_move==army.hound_attack_move,"The destination reaches the native snapshot")
 await tick(180)
 print("FORWARD_STATES ",pack_handles.map(func(h):return [army.unit_state(h).logical_id,army.unit_state(h).target_id,army.unit_state(h).position]))
 check(pack_handles.all(func(h):return army.unit_state(h).target_id==98103),"Five pet families and the bear attack forward instead of the nearer rear or side enemy")
 check(army.unit_state(front).hp<1000000 and army.unit_state(behind).hp==1000000 and army.unit_state(side).hp==1000000,"Actual forward native contacts preserve enemies outside the ordered route")
 await capture_move("forward-engagement")
 check(pack_handles.any(func(h):return army.unit_state(h).action==1),"The party is actively attacking before the redirect")
 var locked_enemy=army.enemy_target(98103)
 game.player.active_ability.primary_tab_target=weakref(locked_enemy)
 var old_hp:float=army.unit_state(front).hp
 await ground_aim(home+Vector3(55,0,0));right_click();await tick(1)
 check(army.hound_focus_target==0 and game.player.active_ability.locked_primary_enemy()==locked_enemy,"The cursor redirects pets while the player's old Tab lock stays intact")
 check(pack_handles.all(func(h):return army.unit_state(h).target_id==0 and army.unit_state(h).action!=1 and not army.unit_state(h).get("pet_sequence",false)),"A real RMB interrupts every current attack on the first tick")
 check(army.unit_state(front).hp==old_hp,"Cancelled attacks deliver no late contact to the former enemy")
 await tick(240)
 check(pack_handles.all(func(h):return army.unit_state(h).target_id==98102) and army.unit_state(side).hp<1000000 and army.unit_state(front).hp==old_hp,"The whole party leaves the living enemy and fights another in the new direction")
 await capture_move("redirected-during-combat")
 await ground_aim(destination);right_click();await tick(240)
 check(pack_handles.all(func(h):return army.unit_state(h).target_id==98103),"Another click redirects the fighting party back again")
 var skill_pet=pack[0];var skill_handle:int=pack_handles[0]
 game.settings.forest_pet_skills={skill_pet:[Pets.Spells.BEE_FLURRY]};army.pet_skills.reconcile()
 army.native.set_pet_mana(skill_handle,float(army.unit_state(skill_handle).max_mana))
 for i in 180:
  await tick(1)
  if army.unit_state(skill_handle).get("pet_sequence",false):break
 var caster=army.pet_skills.casters[skill_pet]
 check(army.unit_state(skill_handle).get("pet_sequence",false) and caster.charge.visible,"An actual equipped Bee Flurry is charging before the redirect")
 var charge_position:Vector3=army.unit_state(skill_handle).position
 await ground_aim(home+Vector3(55,0,0));right_click();await tick(1)
 check(not army.unit_state(skill_handle).get("pet_sequence",false) and army.unit_state(skill_handle).target_id==0 and not caster.charge.visible and caster.sequence_target==null,"RMB cancels the native charge and releases its prepared visual and target")
 check(army.unit_state(skill_handle).position.distance_to(charge_position)<1.0,"Cancelling the flurry starts movement without blinking back to its cast origin")
 game.settings.forest_pet_skills={};army.pet_skills.reconcile();await frames(2)
 await ground_aim(destination);right_click();await tick(180)
 army.despawn(front);await tick(420)
 check(pack_handles.all(func(h):return army.unit_state(h).position.distance_to(army.hound_attack_move)<13 and army.unit_state(h).target_id==0),"After the fight the whole party resumes advancing to the destination")
 await capture_move("arrived-at-destination")
 var nodes=game.crowd.army.presentation.get_child_count();var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 var arrival=enemy_at(98104,Vector3(0,0,-60))
 var acquire_ticks=0
 while acquire_ticks<60 and not pack_handles.all(func(h):return army.unit_state(h).target_id==98104):
  await tick(1);acquire_ticks+=1
 print("PET_ARRIVAL_ACQUIRE seconds=",acquire_ticks*DT)
 check(acquire_ticks*DT<=.15,"The whole mixed party notices a nearby arrival within 150 ms")
 await tick(180)
 check(pack_handles.all(func(h):return army.unit_state(h).target_id==98104) and army.unit_state(arrival).hp<1000000,"The party finds and attacks a new enemy near its destination")
 key(KEY_F);await tick(1)
 var posts=pack_handles.map(func(h):return army.unit_state(h).position)
 await tick(90)
 check(pack_handles.map(func(h):return army.unit_state(h).position)==posts and not army.hound_attack_move.is_finite(),"F cancels attack move and holds every companion")
 key(KEY_Z);await tick(1)
 check(army.hound_order==army.HoundOrder.RETURN and pack_handles.all(func(h):return army.unit_state(h).target_id==0),"Z cancels the advance and recalls every companion")
 army.despawn(arrival);army.despawn(behind);army.despawn(side)
 await ground_aim(home+Vector3(45,0,0));right_click();await tick(420)
 check(pack_handles.all(func(h):return army.unit_state(h).position.distance_to(army.hound_attack_move)<13),"An empty attack move travels without needing an enemy")
 for cycle in 3:
  await ground_aim(home+Vector3(45,0,0));right_click();await tick(60)
 check(game.crowd.army.presentation.get_child_count()==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources+2,"Repeated directional commands reuse prepared presentation resources")
 await ground_aim(home+Vector3(0,0,-55))
 var serial:int=army.hound_order_serial;game.paused=true;right_click();game.paused=false
 check(army.hound_order_serial==serial,"Paused right clicks leave the current command unchanged")
 var camera=game.camera_rig.camera;camera.look_at(camera.global_position+Vector3(0,1,-.1));await physics_frame
 right_click();check(army.hound_attack_move.is_finite(),"Empty sky resolves to a finite advance in the aimed horizontal direction")
 army.clear();check(not army.hound_attack_move.is_finite(),"World reset clears the destination")
 times.sort();print("ATTACK_MOVE_STEP_US p95=",times[int(times.size()*.95)]," max=",times[-1]," samples=",times.size())
 game.queue_free();current_scene=null;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_ATTACK_MOVE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
