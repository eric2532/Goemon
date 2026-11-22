extends "res://scripts/recovered_leaders_tests.gd"

const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Slimes=preload("res://scripts/forest/crowd/slime_sprites.gd")
const OUTPUT="res://build/Other Files/Asset Toolkit/Cross Gate Slimes/Survival/"

func run():
 create_timer(180).timeout.connect(func():quit(1))
 var args=OS.get_cmdline_user_args()
 var large="--large" in args
 var testing="--crossgate-pet-test" in args
 var map_path="res://assets/maps/forest_wind_meadow_large.json" if large else "res://assets/maps/forest_wind_meadow.json"
 if not testing:map_path="res://tests/forest-shrine/reference/maps/forest_wind_meadow_large_valley.json" if large else "res://tests/forest-shrine/reference/maps/forest_wind_meadow_valley.json"
 set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string(map_path)))
 game=load("res://scenes/forest_shrine.tscn").instantiate()
 game.settings_path="user://crossgate-slime-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;await frames(4)
 var model=game.model;var army=game.army_runtime
 var renderer=game.crowd.army;var fx=renderer.presentation
 game.set_physics_process(false);game.set_process(false)
 game.player.set_physics_process(false);game.camera_rig.set_process(false)
 if testing:
  check(game.player.character_id==game.player.RogueRoster.KAZI_ID,"Slime mode starts with the default fighter Kaz")
  check(model.shrine().is_empty() and not model.occupancy.has(Vector2i.ZERO) and not game.world.structure_nodes.has(1),"The statue, its footprint and its world node are absent in preparation")
  check(not game.forest_ui.shrine_health_bar.visible and game.forest_ui.team_xp_bar.is_visible_in_tree(),"The HUD keeps team XP without the statue meter")
  game.show_enemy_balance(false)
  var picker=game.menu.find_child("BalanceEnemy",true,false)
  check(picker.item_count==1 and picker.get_item_text(0)=="Slime","The test has one editable Slime profile")
  game.update_enemy_tuning(Roles.SLIME,"hp",124)
  game.update_enemy_tuning(Roles.SLIME,"damage",6)
  game.update_enemy_tuning(Roles.SLIME,"speed",3)
  game.load_settings()
  check(game.core_balance.enemy_profiles[str(Roles.SLIME)].hp==124,"The shared profile survives saving and loading")
  game.reset_enemy_tuning(Roles.SLIME)
  game.menu.free();game.menu=null
 game.settings.forest_level_up_cards=false
 model.team_progression.cards_enabled=false
 game.start_wave()
 game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 game.forest_ui.set_process_unhandled_input(false);root.gui_disable_input=true
 check(model.phase=="wave" and game.painterly_preview,"The standard Start Battle control enters the painterly battlefield")
 var spawn_samples=PackedFloat64Array()
 army.profile_enabled=testing
 var startup=Time.get_ticks_usec()
 game._physics_process(1.0/60)
 if testing:
  print("SLIME_FIRST_WORLD_STEP_MS=",(Time.get_ticks_usec()-startup)*.001," profile=",army.profile_totals)
 var worst_spawn={};var worst_ms=0.0
 var wave_size:int=Roles.SLIME_COLORS if testing else 0
 for i in 240 if testing else 120:
  if testing:army.profile_totals.clear()
  var started=Time.get_ticks_usec()
  game._physics_process(1.0/60)
  if testing:
   var elapsed=(Time.get_ticks_usec()-started)*.001
   spawn_samples.append(elapsed)
   if elapsed>worst_ms:
    worst_ms=elapsed;worst_spawn=army.profile_totals.duplicate()
  if testing and army.latest.kinds.count(Roles.SLIME)==wave_size:break
 army.profile_enabled=false
 var snapshot=army.render_snapshot()
 if testing:
  print("SLIME_SIDE_COUNTS ",model.waves.slime_arrivals," cursors=",model.waves.slime_placement_cursors)
  check(complete_packs(snapshot,1),"The first wave has all 29 appearances at the north entrance only")
  check(snapshot.teams.count(0)==wave_size and snapshot.kinds.count(Roles.SLIME)==wave_size and model.enemies.size()==wave_size,"All 29 opening enemies are slimes")
  check(model.enemies.values().all(func(row):return row.level==1 and row.xp_reward_tenths==10),"Each opening slime is level one and worth one XP")
  check(Array(snapshot.max_hp).all(func(hp):return is_equal_approx(hp,700)),"Every slime starts with 700 HP")
  check(model.waves.role_stats(Roles.SLIME).damage==20 and model.waves.role_stats(Roles.SLIME).speed==3,"The shared default is 20 damage and 3 m/s")
  check(Slimes.motions().variants.size()==29 and Slimes.sounds.size()==5,"All source variants and WAVs are available")
  check(renderer.meshes[Roles.SLIME].material.get_shader_parameter("actions_per_skin")==10,"The shared atlas retains all ten source action slots")
  var shader=renderer.meshes[Roles.SLIME].material
  var shapes=preload("res://scripts/forest/forest_enemy_contact.gd").shapes(Roles.SLIME)
  check(shader.get_shader_parameter("enemy_size")==3 and is_equal_approx(shapes[0].bounds.size.y,5.4*Roles.MAP_ENEMY_SCALE),"The arena slime keeps its existing size preset and uses the shared enemy multiplier on its fitted height")
  army.flush_presentation()
  check(renderer.submitted==wave_size,"The native batches submit all 29 live sprites")
  if failures==0:
   verify_pack(snapshot)
   await verify_combat(snapshot)
   if failures==0:verify_rebirths()
   if failures==0:await verify_waves()
   if failures==0:await verify_survival()
  if not spawn_samples.is_empty():
   spawn_samples.sort()
   print("SLIME_SETUP_WORLD_STEP_MAX_MS=",spawn_samples[-1]," profile=",worst_spawn)
 else:
  check(snapshot.teams.has(0) and not snapshot.kinds.has(Roles.SLIME),"Regular launch still sends its original roster")
  check(not renderer.meshes.has(Roles.SLIME),"The normal renderer skips the slime atlas")
  check(not model.shrine().is_empty() and game.world.structure_nodes.has(1),"Regular mode has its statue")
  game.player.invuln=0;game.player.take_hit(1000000.0,Vector3.FORWARD)
  check(model.phase=="wave" and game.respawn_left>0,"Regular mode still schedules a hero respawn")
  model.damage_building(1,1000000.0)
  check(model.phase=="defeat","Regular mode ends when its statue falls")
 var path=game.settings_path
 stop_audio(game);current_scene=null;game.queue_free();paused=false;await frames(3)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("CROSSGATE_SLIME_RESULT checks=%d failures=%d large=%s test=%s"%[checks,failures,large,testing])
 quit(1 if failures else 0)

func spawn_side(position_:Vector3)->int:
 if absf(position_.x)>absf(position_.z):return 1 if position_.x>0 else 3
 return 2 if position_.z>0 else 0

func complete_packs(snapshot:Dictionary,sides:int,existing:PackedInt64Array=PackedInt64Array())->bool:
 var by_side=[[],[],[],[]]
 for i in snapshot.handles.size():
  if snapshot.handles[i] in existing:continue
  if snapshot.teams[i]!=0 or snapshot.kinds[i]!=Roles.SLIME:return false
  by_side[spawn_side(snapshot.positions[i])].append(snapshot.pose_rows[i])
 for side in 4:
  by_side[side].sort()
  if by_side[side]!=(range(Roles.SLIME_COLORS) if side<sides else []):return false
 return true

func verify_pack(initial:Dictionary):
 var army=game.army_runtime
 game.tuning.invincible=true
 var samples=PackedFloat64Array()
 for i in 420:
  var started=Time.get_ticks_usec()
  army.integration_tick(1.0/60)
  samples.append((Time.get_ticks_usec()-started)*.001)
  army.flush_presentation()
 var approaching={}
 var now:Dictionary=army.latest
 for i in now.handles.size():
  var at:int=initial.handles.find(now.handles[i])
  var before:Vector3=initial.positions[at]
  var after:Vector3=now.positions[i]
  if Vector2(before.x,before.z).length()-Vector2(after.x,after.z).length()>3:
   approaching[spawn_side(before)]=true
 check(approaching.size()==1,"Slimes close on the starting area from the north entrance")
 samples.sort()
 print("SLIME_FULL_PACK advancing_sides=",approaching.size()," samples=",samples.size()," integration_p95_ms=",samples[floori((samples.size()-1)*.95)]," max_ms=",samples[-1])
 game.tuning.invincible=false

func verify_combat(snapshot:Dictionary):
 var model=game.model;var army=game.army_runtime;var fx=game.crowd.army.presentation
 var origin=Vector3(-60,0,90) if model.terrain_detail==model.Arena.ID else Vector3(-150,0,127)
 origin.y=model.surface_height(origin.x,origin.z)
 game.player.position=origin
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=origin+Vector3(0,30,60);camera.look_at(origin+Vector3(0,0,-19))
 var chosen={}
 var staged:Array[int]=[]
 for i in snapshot.kinds.size():
  if spawn_side(snapshot.positions[i])!=0:continue
  var skin:int=snapshot.pose_rows[i]
  var point=origin+Vector3((skin%10-4.5)*8.5,0,-14.0-(skin/10)*9.0)
  point.y=model.surface_height(point.x,point.z)
  var handle:int=snapshot.handles[i];army.set_pose(handle,point,PI);staged.append(handle)
  var id=int(Slimes.motions().variants[skin].id)
  if id in [101500,101501,108335]:chosen[id]=handle
 game.crowd.present_army(army.render_snapshot(),[])
 await capture("Slime lineup")
 var distant=origin+Vector3(0,0,-48)
 distant.y=model.surface_height(distant.x,distant.z)
 for i in staged.size():
  var holding=distant+Vector3((i%10-4.5)*3.0,0,-(i/10)*4.0)
  holding.y=model.surface_height(holding.x,holding.z)
  army.set_pose(staged[i],holding,PI)
  if staged[i] not in chosen.values():army.apply_hit(staged[i],{"element":"stun","status_seconds":8.0})
 army.record_events=true;army.compact_scene_events=false
 game.settings.volume=.7
 game.tuning.invincible=false
 var heard={}
 var hp_before:float=game.player.hp
 var samples=PackedFloat64Array()
 var point=origin+Vector3(0,0,-4.5)
 point.y=model.surface_height(point.x,point.z)
 for id in chosen:
  army.set_pose(chosen[id],point,PI)
  for i in 86:
   var started=Time.get_ticks_usec()
   army.integration_tick(1.0/60)
   samples.append((Time.get_ticks_usec()-started)*.001)
   army.flush_presentation()
   for voice in fx.voices:
    if voice.playing and Slimes.sounds.values().has(voice.stream):heard[voice.stream.resource_path]=true
  army.set_pose(chosen[id],distant,PI)
 var sounds={}
 var damaged=false
 for event in army.event_log:
  if event.kind=="status" and event.unit_kind==Roles.SLIME:sounds[int(event.action_index)-500]=true
  if event.kind=="external_damage" and event.unit_kind==Roles.SLIME and event.target_id==0 and is_equal_approx(event.amount,20):damaged=true
 print("SLIME_ATTACK_SOUNDS=",sounds.keys())
 check(sounds.has(112) and sounds.has(138) and sounds.has(164) and sounds.has(165),"Native attacks emit each original melee cue")
 check(not heard.is_empty(),"The existing spatial voice pool plays the imported WAVs")
 check(damaged and game.player.hp<hp_before,"Slimes deal 20 damage to the player through native melee")
 var victim:int=chosen[101500]
 var state:Dictionary=army.unit_state(victim)
 var actor=army.enemy_target(state.logical_id)
 check(is_instance_valid(actor) and actor.combat_segment_hit(actor.position+Vector3.UP,actor.position+Vector3.UP*2,.1),"The normal player hit query reaches the slime")
 army.set_pose(victim,point,PI)
 army.integration_tick(1.0/60)
 var player=game.player
 player.select_character(34)
 player.facing=Vector3.FORWARD;player.ai_controlled=true;player.ai_aim=origin+Vector3.FORWARD*10
 var kit=player.active_ability
 kit.start_attack();kit.ticket.critical_chance=0.0
 check(kit.cut_times.size()==2,"Kazi's equipped sword has two authored contact beats")
 if kit.cut_times.size()!=2:return
 var second_contact:float=kit.cut_times[1]
 var tempo:float=player.attack_speed_multiplier()
 kit.tick((kit.cut_times[0]+.001)/tempo)
 check(army.valid(victim) and army.unit_state(victim).hp<state.hp,"Kazi's real sword contact damages the slime")
 army.apply_hit(victim,{"amount":army.unit_state(victim).hp-1.0})
 kit.tick((second_contact-kit.elapsed+.001)/tempo)
 army.flush_presentation()
 check(not army.valid(victim) and fx.corpses.any(func(row):return row.kind==Roles.SLIME and row.skin==0),"Kazi's second cut retires the slime and preserves its skin in the fall animation")
 check(model.waves.kill_spawn_pending==0,"Slime kills cannot queue Musashi Realm reinforcements")
 army.integration_tick(1.0/60)
 game.forest_ui.sync()
 await capture("Slime combat")
 samples.sort()
 print("SLIME_INTEGRATION_MS samples=",samples.size()," p95=",samples[floori((samples.size()-1)*.95)]," max=",samples[-1])

func verify_rebirths():
 var model=game.model;var army=game.army_runtime;var waves=model.waves
 check(waves.slime_rebirth_pending==1,"One native death queues exactly one stronger return")
 var returned:Dictionary
 for generation in range(1,4):
  var before:int=waves.slime_returned
  for tick in 12:waves.spawn_slimes(game.player.position)
  check(waves.slime_returned==before,"Generation %d waits for the next wave boundary"%generation)
  waves.tick(waves.wave_clock,game.player.position)
  var clock:float=waves.wave_clock
  for tick in 600:
   waves.spawn_slimes(game.player.position);army.integration_tick(1.0/60)
   if waves.slime_returned>before:break
  var candidates=model.enemies.values().filter(func(row):return row.health_scale>1.2 if generation>1 else row.health_scale>1)
  check(candidates.size()==1 and waves.slime_rebirth_pending==0,"Generation %d returns once through the existing entrance"%generation)
  if candidates.size()!=1:return
  returned=candidates[0]
  var scale=pow(waves.SLIME_REBIRTH_GROWTH,generation)
  var handle:int=army.handles[returned.id]
  var state:Dictionary=army.unit_state(handle)
  check(returned.skin==0 and returned.slime_side==0,"The returning slime keeps its appearance and entrance")
  check(returned.level==generation+1 and returned.xp_reward_tenths==10*(generation+1),"Each return adds one slime level and one XP to its reward")
  check(is_equal_approx(state.max_hp,700*scale) and is_equal_approx(state.hp,state.max_hp) and is_equal_approx(returned.damage_scale,scale),"Generation %d starts at full %.1f HP and %.2f damage"%[generation,700*scale,20*scale])
  check(waves.spawned==waves.slime_scheduled_total() and waves.wave_clock==clock and model.enemies.size()==waves.slime_scheduled_total(),"Returning slimes preserve scheduled wave counts and timing")
  army.record_events=true;army.compact_scene_events=false;army.event_log.clear()
  var holding:Vector3=state.position
  var point:Vector3=game.player.position+Vector3.FORWARD*4.5
  point.y=model.surface_height(point.x,point.z)
  army.set_pose(handle,point,PI);game.player.invuln=0;game.player.hp=game.player.max_hp
  var hp_before:float=game.player.hp
  for tick in 120:
   army.integration_tick(1.0/60)
   if army.event_log.any(func(event):return event.kind=="external_damage" and event.source_id==returned.id):break
  check(army.event_log.any(func(event):return event.kind=="external_damage" and event.source_id==returned.id and is_equal_approx(event.amount,20*scale)) and game.player.hp<hp_before,"Generation %d deals its increased damage through native melee"%generation)
  army.set_pose(handle,holding,PI)
  if generation<3:
   var xp_before:int=model.team_progression.total_kills
   army.apply_hit(handle,{"amount":1000000.0})
   var stale:Dictionary=army.apply_hit(handle,{"amount":1000000.0})
   check(not stale.accepted and waves.slime_rebirth_pending==1,"A stale hit cannot queue a duplicate rebirth")
   check(model.team_progression.total_kills-xp_before==returned.level,"Native death credits a returning slime's XP exactly once")
   army.integration_tick(1.0/60)
 var fresh=model.enemies.values().filter(func(row):return row.health_scale==1 and row.slime_side==1)
 var simultaneous=[fresh[0],fresh.back()]
 for row in simultaneous:army.apply_hit(army.handles[row.id],{"amount":1000000.0})
 check(waves.slime_rebirth_pending==2,"Simultaneous deaths retain two independent returns")
 waves.tick(waves.wave_clock,game.player.position)
 for tick in 600:
  waves.spawn_slimes(game.player.position);army.integration_tick(1.0/60)
  if waves.slime_rebirth_pending==0:break
 check(model.enemies.values().filter(func(row):return is_equal_approx(row.health_scale,1.1)).size()==2 and is_equal_approx(returned.health_scale,pow(1.1,3)),"Simultaneous returns start at 770 HP without strengthening survivors")
 army.record_events=false;army.compact_scene_events=true

func verify_waves():
 var model=game.model;var army=game.army_runtime;var waves=model.waves
 army.record_events=false;army.compact_scene_events=true
 game.player.ai_controlled=false;game.tuning.invincible=true
 var progression=model.team_progression
 var kills_before:int=game.kills
 var hero:Vector3=game.player.position
 for handle in army.render_snapshot().handles:army.despawn(handle)
 model.enemies.clear();progression.reset();progression.cards_enabled=false
 model.phase="preparing";waves.begin()
 var cap:int=waves.active_cap()
 var full_waves=11
 var previous={"handles":PackedInt64Array()}
 for wave in range(1,full_waves+1):
  if wave>1:
   waves.tick(waves.wave_clock-.1,hero)
   check(model.wave==wave-1,"Wave %d cannot arrive before its 30-second boundary"%wave)
   waves.tick(.1,hero)
  for tick in 600:
   waves.spawn_slimes(hero);army.integration_tick(1.0/60)
   if army.latest.kinds.size()==waves.slime_scheduled_total():break
  var next:Dictionary=army.render_snapshot()
  var sides=mini(4,(wave+1)/2)
  check(model.wave==wave and next.handles.size()==waves.slime_scheduled_total() and complete_packs(next,sides,previous.handles),"Wave %d adds 29 variants per active entrance, without a backlog at newly opened sides (live=%d sides=%s)"%[wave,next.handles.size(),str(waves.slime_arrivals)])
  if failures:return
  previous=next
  game.forest_ui.sync();army.flush_presentation()
  if wave in [1,3,5,7]:await capture("Progression wave %d"%wave)
 if DisplayServer.get_name()!="headless":
  var camera:Camera3D=game.camera_rig.camera
  var center:Vector3=model.fort_center()
  camera.global_position=center+Vector3(0,26,46);camera.look_at(center+Vector3(0,0,-14))
  game.camera_rig.set_process(false)
  var viewport=root.get_viewport_rid()
  RenderingServer.viewport_set_measure_render_time(viewport,true)
  army.profile_enabled=true
  game.set_process(true);game.set_physics_process(true)
  var intervals=[];var native_ms=[];var render_cpu=[];var render_gpu=[];var spikes=[]
  var frame=Time.get_ticks_usec()
  var end=frame+7600000
  var warmup=frame+3100000
  var focus_frames=0
  while Time.get_ticks_usec()<end:
   army.profile_totals.clear()
   await process_frame
   var now=Time.get_ticks_usec()
   var ms=(now-frame)*.001
   if now>=warmup:
    intervals.append(ms)
    native_ms.append(army.profile_totals.get("native_step",0.0))
    render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
    render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
    focus_frames+=int(DisplayServer.window_is_focused())
    if ms>40 and spikes.size()<10:spikes.append([ms,army.profile_totals.duplicate(),render_cpu.back(),render_gpu.back()])
   frame=now
  game.set_physics_process(false);game.set_process(false)
  army.profile_enabled=false
  var metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
  print("SLIME_DESKTOP frames=",intervals.size()," focus_frames=",focus_frames," live=",model.enemies.size()," frame_ms=",metrics.summary(intervals)," native_ms=",metrics.summary(native_ms)," render_cpu=",metrics.summary(render_cpu)," render_gpu=",metrics.summary(render_gpu))
  print("SLIME_DESKTOP_SPIKES ",spikes)
  await capture("Full slime roster")
 model.tick(waves.wave_clock+.01,hero)
 for tick in 240:
  game._physics_process(1.0/60)
  if army.latest.kinds.size()==cap:break
 var full:Dictionary=army.render_snapshot()
 check(model.wave==full_waves+1 and full.kinds.count(Roles.SLIME)==cap and waves.spawned==cap,"The next wave queues at the unchanged cap")
 progression.cards_enabled=true
 check(game.player.spell_loadout.equip(game.player.character_id,"equip","kazi/qigong"),"Equip Qi for the live skill-card draft")
 var picked=0
 for handle in full.handles:
  army.apply_hit(handle,{"amount":100000.0})
  if progression.pending()>0:
   game._process(0)
   var before:float=waves.wave_clock
   game._physics_process(1.0)
   check(is_instance_valid(game.team_upgrade_picker) and waves.wave_clock==before,"A card choice pauses the wave clock")
   check(progression.offer.has("kazi/qigong"),"The equipped skill is offered at level %d"%progression.level)
   var before_level=game.skill_card_level("kazi/qigong")
   check(game.choose_team_upgrade("kazi/qigong",progression.choice_level()),"The popup applies a Qi skill upgrade")
   check(game.skill_card_level("kazi/qigong")>before_level,"A skill choice raises the live level")
   picked+=1
  if picked==3:break
 check(picked==3 and progression.total_kills==96,"Three skill choices unlock after 16, 32 and 48 XP")
 for tick in 240:
  game._physics_process(1.0/60)
  if army.latest.kinds.size()==cap:break
 var live_after_refill:int=army.latest.kinds.count(Roles.SLIME)
 check(live_after_refill>cap-96 and live_after_refill<=cap and live_after_refill==waves.spawned+waves.slime_returned-(game.kills-kills_before),"Queued slimes refill freed slots as entrances clear (live=%d, spawned=%d)"%[live_after_refill,waves.spawned])
 progression.cards_enabled=false
 for handle in army.render_snapshot().handles:army.apply_hit(handle,{"amount":100000.0})
 for tick in 240:
  game._physics_process(1.0/60)
  if waves.spawned==waves.slime_scheduled_total():break
 army.integration_tick(1.0/60)
 var live:int=army.latest.kinds.count(Roles.SLIME)
 check(model.wave==full_waves+1 and waves.slime_arrivals==[348,290,232,174] and live>0 and live<=cap,"Every scheduled variant arrives after clearing space (wave=%d, live=%d, sides=%s)"%[model.wave,live,waves.slime_arrivals])
 var defeated:int=game.kills-kills_before
 check(live==waves.spawned+waves.slime_returned-defeated and live+waves.slime_rebirth_pending==waves.slime_scheduled_total(),"Blocked returns stay queued without losing or duplicating a slime (live=%d, new=%d, returned=%d, kills=%d, queued=%d)"%[live,waves.spawned,waves.slime_returned,defeated,waves.slime_rebirth_pending])
 for index in model.portals.size():
  model.damage_enemy_objective(index,1000000.0)
 check(model.phase=="wave" and waves.kill_spawn_pending==0,"Clearing old objectives keeps the slime waves active")

func verify_survival():
 var model=game.model;var player=game.player;var waves=model.waves
 game.tuning.invincible=false;player.invuln=0
 # This checks defeat delivery; the default 5% dodge/counter chance must not absorb the probe.
 for stat in ["dodge_chance","counter_chance"]:game.update_character_tuning(player.character_id,stat,0)
 player.model.clear_kagerou_dodge()
 model.damage_building(1,1000000.0)
 player.take_hit(1.0,Vector3.FORWARD)
 check(player.hp>0 and model.phase=="wave","Damage to the old statue ID and a nonlethal hit leave the run active")
 player.invuln=0;player.take_hit(1000000.0,Vector3.FORWARD)
 game._physics_process(1.0/60)
 check(player.hp==0 and model.phase=="defeat" and game.paused and game.respawn_left==0,"A lethal hit ends the slime run and schedules no respawn")
 var arrivals:int=waves.spawned;var remaining:float=waves.wave_clock
 game._physics_process(30.0)
 check(waves.spawned==arrivals and waves.wave_clock==remaining,"The defeated run stops spawning new waves")
 check(is_instance_valid(game.forest_ui.overlay) and game.forest_ui.overlay.find_children("*","Label",true,false).any(func(label):return label.text=="RUN OVER"),"The run-over overlay is shown")
 await capture("Run over")
 var fresh=load("res://scripts/forest/forest_model.gd").new()
 fresh.reset(42,{},JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow.json")),false)
 check(fresh.waves.begin() and fresh.waves.slime_rebirth_pending==0 and fresh.waves.slime_returned==0 and fresh.waves.slime_rebirths.all(func(queue):return queue.is_empty()) and fresh.waves.role_stats(Roles.SLIME).hp==700,"A fresh run clears all rebirth growth and restores the 700 HP baseline")

func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 await process_frame;RenderingServer.force_draw();await RenderingServer.frame_post_draw
 var directory=ProjectSettings.globalize_path(OUTPUT)
 DirAccess.make_dir_recursive_absolute(directory)
 var suffix=" Large" if "--large" in OS.get_cmdline_user_args() else " Standard"
 check(root.get_texture().get_image().save_png(directory+label_+suffix+".png")==OK,"Captured "+label_)
