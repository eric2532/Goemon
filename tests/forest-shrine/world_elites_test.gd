extends "res://tests/forest-shrine/world_counter_test.gd"

const EliteOut="res://build/Other Files/Asset Toolkit/World Elites/"
const Patrols=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
const Dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")

func run():
 create_timer(240).timeout.connect(func():printerr("WORLD_ELITES_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(EliteOut);root.size=Vector2i(1280,800)
 await setup_fixture(Tour.Regions.layout("north_coast"))
 game.player.select_character(game.player.RogueRoster.KAZI_ID)
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.camera_rig.set_process(false);game.music.stop();game.tuning.invincible=true
 game.training_dummy.position=Vector3.DOWN*1000
 var army=game.army_runtime;army.clear();game.model.enemies.clear();army.refresh_navigation(0)
 var waves=game.model.waves
 print("WORLD_ELITE_MAP area=",game.model.falan_area," road=",game.model.falan_road," posts=",waves.patrol_posts.size())
 waves.spawn_clock=0
 var population_hero=Vector3(0,0,10000)
 for i in waves.patrol_posts.size()+1:waves.tick_outer_road(1,population_hero)
 army.import_arrivals();army.sync_compatibility()
 var elites=[];var regular=[]
 for slot in waves.patrol_owners:
  var id_:int=waves.patrol_owners[slot]
  if not game.model.enemies.has(id_):continue
  var row:Dictionary=game.model.enemies[id_]
  var elite:bool=row.get("elite",false)
  var multiplier=3 if elite else 1
  var size_=2.0 if elite else 1.0
  var stats=Patrols.progression(row.skin,Patrols.area_levels("north_coast",waves.patrol_posts[slot]))
  check(row.max_hp==stats.hp*multiplier and row.xp_reward_tenths==stats.xp_reward_tenths*multiplier,"Patrol HP and XP use the exact elite multiplier")
  check(is_equal_approx(row.damage_scale*Patrols.STATS.damage,stats.damage*multiplier),"Patrol damage uses the exact elite multiplier")
  var handle:int=army.handles[id_]
  check(army.unit_state(handle).body_scale==size_,"Native unit retains its own body scale")
  var box=Dimensions.bounds(army.pet_geometry,20,row.skin)
  check(army.enemy_target(id_).local_combat_box().size.is_equal_approx(box.size*size_),"Player/pet contact box matches the scaled body")
  if elite:elites.append(row)
  else:regular.append(row)
 check(not elites.is_empty() and not regular.is_empty(),"The real map contains both elites and ordinary patrols")
 for leader:Dictionary in elites:
  var escorts=game.model.enemies.values().filter(func(row):return row.get("elite_leader",0)==leader.id)
  check(escorts.size()==5,"Every elite arrives with exactly five escorts")
  var slots={}
  for row:Dictionary in escorts:
   slots[row.escort_slot]=true
   check(row.max_hp*3==leader.max_hp and row.xp_reward_tenths*3==leader.xp_reward_tenths,"Escorts retain ordinary species stats and XP")
   check(army.unit_state(army.handles[row.id]).escort_leader==army.handles[leader.id],"Each escort is bound to its generation-checked native leader")
  check(slots.size()==5,"All five party posts are assigned once")
 check(game.model.enemies.size()<=waves.ACTIVE_CAP,"Elites retain the existing native population cap")
 var count:int=game.model.enemies.size()
 for i in 10:waves.tick_outer_road(1,population_hero)
 check(game.model.enemies.size()==count,"Repeated population cannot duplicate elite posts")
 for first in range(0,waves.patrol_posts.size(),20):
  var drawn=0
  for slot in range(first,mini(first+20,waves.patrol_posts.size())):drawn+=int(waves.elite_posts.has(slot))
  check(drawn<=1,"Each twenty-post shuffle bag contains at most one elite")
 print("WORLD_ELITE_POPULATION total=",count," elites=",elites.size()," assigned=",waves.elite_posts.size())
 if elites.is_empty():quit(1);return
 var elite:Dictionary=elites[0]
 var normal:Dictionary=regular.filter(func(row):return row.skin==elite.skin)[0]
 var center:Vector3=elite.pos
 var found=false
 for x in range(-240,241,24):
  for z in range(-240,241,24):
   var point:Vector3=game.model.world_point(Vector2(x,z))
   if army.native.ally_ground_clear(point,20):center=point;found=true;break
  if found:break
 check(found,"Visual comparison uses a clear part of the actual map")
 army.set_pose(army.handles[elite.id],center,PI)
 var normal_at=center+Vector3.RIGHT*8;normal_at.y=game.model.world_height(normal_at.x,normal_at.z)
 army.set_pose(army.handles[normal.id],normal_at,PI)
 army.sync_compatibility();game.model.update_vision(center/game.model.falan_scale)
 game.player.position=center+Vector3.BACK*20
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=center+Vector3(4,8,18);camera.look_at(center+Vector3(4,2,0));camera.reset_physics_interpolation()
 game.crowd.present_army(army.render_snapshot(),[]);await frames(3);await RenderingServer.frame_post_draw
 if DisplayServer.get_name()!="headless":check(root.get_texture().get_image().save_png(EliteOut+"elite-and-normal.png")==OK,"Captured the same species at normal and elite size")
 var packed:Dictionary=army.native.instance_buffers(army.render_snapshot(),game.crowd.army.native_profiles)
 var elite_rendered=false
 for batch:Dictionary in packed.batches:
  for at in range(0,batch.buffer.size(),16):
   var position_=Vector3(batch.buffer[at+3],batch.buffer[at+7],batch.buffer[at+11])
   if position_.distance_to(center)<.01:elite_rendered=is_equal_approx(batch.buffer[at+5],2.0)
 check(elite_rendered,"Native batched elite transform doubles all sprite dimensions")
 var group=game.model.enemies.values().filter(func(row):return row.get("elite_leader",0)==elite.id)
 var spacing=maxf(1.0,(elite.footprint*army.pet_geometry[Dimensions.offset(20,elite.skin)+6]*3.0+1.0)/7.0)
 army.native.set_guard(army.handles[elite.id],center,14.0)
 for row:Dictionary in group:
  var offset:Vector3=game.model.waves.Formation.POSTS[row.escort_slot]
  var point=center+Vector3(-offset.x,0,offset.z)*spacing
  point.y=game.model.world_height(point.x,point.z)
  army.set_pose(army.handles[row.id],point,PI)
 game.player.position=center+Vector3.BACK*70
 var before:Vector3=army.unit_state(army.handles[elite.id]).position
 var timings=[]
 var profiling="--profile-elites" in OS.get_cmdline_user_args()
 var samples=[]
 army.profile_enabled=profiling
 for tick in 480:
  if profiling:army.profile_totals.clear();army.native.simulation_profile(true)
  var started=Time.get_ticks_usec();army.integration_tick(DT)
  var duration=Time.get_ticks_usec()-started;timings.append(duration)
  if profiling:samples.append({"tick":tick,"wall_us":duration,"native":army.native.simulation_profile(false),"bridge":army.profile_totals.duplicate()})
  if tick%30==0:await frames(1)
 if profiling:
  check(not army.native.prepare_routes(PackedFloat32Array([1.0]),-1) and not army.native.prepare_routes(PackedFloat32Array([1.0]),2),"Routing preparation rejects invalid teams")
  var route_builds=0
  for sample:Dictionary in samples:route_builds+=int(sample.native.nav_topology_builds)
  check(route_builds==0,"All outdoor body-size routing grids are prepared before active movement")
  var report=FileAccess.open(EliteOut+"elite-step-profile.json",FileAccess.WRITE)
  report.store_string(JSON.stringify({"seed":game.model.seed_value,"count":count,"elites":elites.size(),"samples":samples},"  "))
  army.profile_enabled=false
 var after:Vector3=army.unit_state(army.handles[elite.id]).position
 check(after.distance_to(before)>1.0,"The elite walks naturally while its five escorts follow")
 check(group.all(func(row):return army.unit_state(army.handles[row.id]).position.distance_to(after)<25),"The five escorts remain with their moving elite")
 camera.global_position=after+Vector3(14,18,25);camera.look_at(after+Vector3.UP);camera.reset_physics_interpolation()
 game.crowd.present_army(army.render_snapshot(),[]);await frames(3);await RenderingServer.frame_post_draw
 if DisplayServer.get_name()!="headless":check(root.get_texture().get_image().save_png(EliteOut+"elite-five-escorts.png")==OK,"Captured the elite and all five travelling escorts")
 timings.sort();print("ELITE_GROUP_STEP_US p95=",timings[int(timings.size()*.95)]," max=",timings[-1]," total=",army.handles.size())
 var rewards=game.model.team_progression;rewards.reset();rewards.cards_enabled=false
 var expected=load("res://scripts/forest/team_progression.gd").new();expected.cards_enabled=false;expected.award_enemy(elite.xp_reward_tenths)
 game.paused=false
 var loot=game.exploration_loot;loot.set_process(false);loot.clear()
 army.apply_hit(army.handles[elite.id],{"amount":elite.max_hp*2,"magical":true})
 check(rewards.level==expected.level and is_equal_approx(rewards.experience(),expected.experience()),"Actual native elite death awards triple XP")
 army.flush_presentation()
 var presentation=game.crowd.army.presentation
 check(presentation.corpses.back().body_scale==2.0,"Elite keeps its doubled size through death presentation")
 presentation.draw_corpses()
 var corpse_batch:MultiMeshInstance3D=presentation.corpse_batches[20]
 check(corpse_batch.visible,"The elite corpse enters the existing species batch")
 var chest_count=loot.slots.filter(func(slot):return slot.active and slot.chest).size()
 check(chest_count==1,"An actual elite death guarantees one standard chest")
 army.damage_enemy(elite.id,elite.max_hp*2)
 check(rewards.level==expected.level and is_equal_approx(rewards.experience(),expected.experience()),"A dead elite cannot award XP twice")
 check(loot.slots.filter(func(slot):return slot.active and slot.chest).size()==chest_count,"Repeated corpse damage cannot duplicate its guaranteed chest")
 army.integration_tick(DT)
 check(group.all(func(row):return army.valid(army.handles[row.id]) and army.unit_state(army.handles[row.id]).escort_leader==0),"Living escorts detach safely after their elite dies")
 loot.clear()
 for i in loot.slots.size():check(loot.spawn_chest(0,center),"Fill the existing chest slots")
 var full=loot.slots.size()
 var pet=army.spawn(army.HOUND_ID,1,19,center+Vector3.RIGHT*3,150,.5)
 check(pet!=0 and elites.size()>1,"Prepare a real companion source and a second elite")
 var second:Dictionary=elites[1]
 army.apply_hit(army.handles[second.id],{"amount":second.max_hp*2,"magical":true,"source_id":army.HOUND_ID})
 check(loot.slots.filter(func(slot):return slot.active and slot.chest).size()==full+1,"A pet's elite kill guarantees its chest even when every loot slot was full")
 check(loot.slots.size()==full+1,"A full loot pool retains the next required chest without deleting loot")
 presentation.tick(10)
 check(not corpse_batch.visible,"The corpse batch hides again when its final corpse expires")
 game.queue_free();current_scene=null;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("WORLD_ELITES_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
