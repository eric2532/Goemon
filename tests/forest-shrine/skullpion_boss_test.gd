extends SceneTree
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func run():
 var doc=preload("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_kai_highway();set_meta("forest_custom_layout",doc.data)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://skullpion-test-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.set_physics_process(false);game.set_process(false);game.player.set_physics_process(false);game.explorer_helpers.set_process(false)
 game.start_wave();game.model.waves.spawn_clock=100000;game.model.waves.pending=999
 var runtime=game.army_runtime
 var point=game.player.global_position+Vector3(0,0,18);point.y=game.model.surface_height(point.x,point.z)
 var row=game.model.waves.spawn_enemy(4,point)
 runtime.import_arrivals();var handle:int=runtime.handles[row.id]
 check(runtime.valid(handle),"Boss uses the sole native army owner")
 check(runtime.unit_state(handle).max_hp==30000,"Native boss spawns with exactly 30000 HP despite the general enemy health multiplier")
 var actor=game.actors[row.id]
 check(actor.variant==4 and not actor is Hero,"Boss is an enemy facade and never a playable character")
 check(actor.combat_bounds().size.is_equal_approx(Vector3(30,25,40)),"All hero/tower queries use the fitted boss dimensions")
 # Use open ground for the cue check; this manually placed boss overlaps the fort.
 runtime.set_navigation(100001,{"width":0})
 runtime.native.set_targets({"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([point+Vector3(0,0,5)]),"hp":PackedFloat32Array([1000])})
 runtime.native.step(1.1)
 var cues:Array=runtime.native.take_scene_events()
 check(cues.any(func(e):return e.kind=="status" and e.get("unit_kind",-1)==4 and e.get("source_id",-1)==row.id and e.get("amount",0)>0),"Compact native event dispatch retains boss warning points and durations")
 check(cues.any(func(e):return e.kind=="attack_started" and e.source_id==row.id),"Boss attack startup retains its source in compact delivery")
 var snapshot=runtime.render_snapshot();game.crowd.army.present(snapshot,[])
 var view=game.crowd.army.skullpions.get(row.id)
 check(is_instance_valid(view) and view.animations.get_animation_list().size()>=22,"Godot imports the complete recovered motion library")
 check(is_equal_approx(view.body.scale.x,12.0) and is_equal_approx(view.title.position.y,32.5),"Boss model and nameplate use the fivefold size")
 var index:int=snapshot.logical_ids.find(row.id)
 var first=view.body.find_child("Part_00",true,false)
 var rest=first.transform
 view.pose("801ade54",2.0,false)
 check(not first.transform.is_equal_approx(rest),"Source animation visibly changes the original rigid parts")
 snapshot.actions[index]=100;snapshot.action_time[index]=0;view.sync(snapshot,index)
 view.global_position=Vector3(-72,game.model.surface_height(-72,-128),-128);view.rotation.y=0;view.ground_body(100)
 var tail=view.body.find_child("Part_16",true,false)
 check(tail.global_position.y>=game.model.surface_height(tail.global_position.x,tail.global_position.z),"Idle tail stays above the sloping terrain")
 for action in [101,102,103,104,105,106,107,108]:
  snapshot.actions[index]=action;snapshot.action_time[index]=2.4;view.sync(snapshot,index)
  check(view.title.text.contains("SKULLPION"),"Boss presentation accepts native action %d"%action)
 check(view.effects.drill.find_child("Drill_02",true,false)!=null,"The drill includes its original two stone segments and forked tip")
 snapshot.actions[index]=103;snapshot.action_time[index]=3.1;view.sync(snapshot,index)
 check(view.sand.visible and view.sand.material_override is ShaderMaterial,"Sand breath uses its recovered animated texture")
 snapshot.actions[index]=105;snapshot.action_time[index]=2.0;view.sync(snapshot,index)
 check(view.drill.visible,"The recovered drill emerges at a native warning point")
 snapshot.actions[index]=100;snapshot.action_time[index]=0;view.sync(snapshot,index)
 check(not view.sand.visible and not view.drill.visible,"Returning to idle clears attack visuals")
 var old_volume:float=game.settings.volume;game.settings.volume=1.0;game.playing=true;game.ordinary_pause=false
 snapshot.actions[index]=102;snapshot.action_time[index]=.49;view.sync(snapshot,index)
 var played:int=view.audio_started
 snapshot.action_time[index]=.51;view.sync(snapshot,index)
 check(view.audio_started==played+1,"The first tail contact plays its original impact")
 view.sync(snapshot,index)
 check(view.audio_started==played+1,"Repeated presentation snapshots do not replay sounds")
 snapshot.action_time[index]=1.18;view.sync(snapshot,index);snapshot.action_time[index]=1.51;view.sync(snapshot,index)
 check(view.audio_started==played+3,"The second slam and full sweep play separate original cues")
 game.settings.volume=0
 check(not view.play_sound(0x55d,point),"Muting the game also mutes boss audio")
 game.settings.volume=old_volume
 snapshot.actions[index]=106;snapshot.air_phase[index]=1;snapshot.action_time[index]=2.2;view.sync(snapshot,index)
 played=view.audio_started
 snapshot.air_phase[index]=2;snapshot.pose_time[index]=.5;view.sync(snapshot,index)
 check(view.title.text.contains("CLIMBING CASTLE") and view.audio_started==played,"Climb animation follows the native stage without a timed impact in midair")
 snapshot.air_phase[index]=3;snapshot.pose_time[index]=0;view.sync(snapshot,index)
 check(view.audio_started==played+1 and view.title.text.contains("ON CASTLE WALL"),"Reaching the native crest triggers the recovered impact once")
 view.sync(snapshot,index)
 check(view.audio_started==played+1,"Repeated crest snapshots cannot replay its impact")
 snapshot.air_phase[index]=4;view.sync(snapshot,index)
 check(view.title.text.contains("FALLING"),"An interrupted climb uses the falling stage")
 snapshot.air_phase[index]=5;view.sync(snapshot,index)
 check(view.title.text.contains("JUMPING DOWN"),"The castle jump uses the recovered jump animation")
 snapshot.actions[index]=100;snapshot.air_phase[index]=0;view.sync(snapshot,index)
 check(view.audio_started==played+2,"Landing after the castle jump plays one impact")
 view.sync(snapshot,index)
 check(view.audio_started==played+2,"A repeated landing snapshot cannot duplicate the impact")
 game.player.skullpion_poison_left=4
 check(game.player.movement_multiplier()<game.player.progression.movement_multiplier(),"Poison slows player movement")
 game._respawn_player()
 check(game.player.skullpion_poison_left==0,"Respawning clears boss poison")
 var initial:float=runtime.unit_state(handle).hp
 actor.take_hit(1,Vector3.FORWARD,false,{"lethal_headshot":true})
 check(runtime.valid(handle) and runtime.unit_state(handle).hp>initial*.9,"A lethal ordinary-enemy headshot cannot bypass boss HP")
 # A core opening multiplies actual damage and remains controlled by native state.
 game.model.waves.spawn_groups={-1:{"members":{row.id:true},"engaged":false}}
 for hit in 7:
  actor.take_hit(initial*.03,Vector3.FORWARD,true,{"tower":true})
  check(runtime.unit_state(handle).action!=107,"A few heavy hits cannot expose the core")
 actor.take_hit(initial*.03,Vector3.FORWARD,true,{"tower":true})
 check(runtime.unit_state(handle).action==107,"Eight solid heavy hits expose the core")
 check(not game.model.waves.spawn_groups[-1].engaged,"An exposed-core reaction cannot release the next enemy group")
 var wave_model=load("res://scripts/forest/forest_model.gd").new()
 for previous_wave in 5:
  wave_model.reset(42,{"bosses_per_portal":1,"enemy_health_mult":4},doc.data)
  wave_model.wave=previous_wave;wave_model.phase="preparing";wave_model.waves.begin()
  var ordinary=0
  for slot in preload("res://scripts/forest/core_balance.gd").TYPES.size():
   if preload("res://scripts/forest/core_balance.gd").TYPES[slot]!=4:ordinary+=wave_model.waves.remaining_counts[slot]
  check(wave_model.waves.pending==ordinary+1 and wave_model.waves.boss_pending.size()==1,"Wave %d schedules one boss without changing soldier counts"%(previous_wave+1))
  check(wave_model.waves.spawn_one(),"Wave %d admits its boss through the authored map"%(previous_wave+1))
  var bosses=wave_model.enemies.values().filter(func(e):return e.variant==4)
  check(bosses.size()==1 and bosses[0].hp==30000 and bosses[0].max_hp==30000,"Wave %d creates one boss with exactly 30000 HP"%(previous_wave+1))
  check(wave_model.waves.boss_pending.is_empty() and wave_model.waves.pending==ordinary,"Successful boss arrival consumes its queue entry once")
  wave_model.waves.spawn_one()
  check(wave_model.enemies.values().filter(func(e):return e.variant==4).size()==1,"Further arrivals do not duplicate the wave boss")
 wave_model.reset(42,{"bosses_per_portal":0},doc.data);wave_model.wave=0;wave_model.phase="preparing";wave_model.waves.begin()
 check(wave_model.waves.boss_pending.is_empty(),"Saved encounter toggle disables boss arrivals")
 runtime.native.apply_hit(handle,{"amount":10000000.0,"heavy":true});runtime.dispatch_events();runtime.sync_compatibility()
 game.crowd.army.present(runtime.render_snapshot(),runtime.presentation_events)
 check(not game.crowd.army.skullpions.has(row.id),"Death retires the native target and boss view")
 game.model.phase="preparing";game.paused=true;view._process(3)
 check(view.is_queued_for_deletion(),"Death animation finishes when the last boss ends a wave")
 game.crowd.army.clear()
 check(game.crowd.army.skullpions.is_empty(),"Reset clears boss presentation")
 game.sound_library.cancel();game.music.stop();game.move_audio.stop();game.queue_free();current_scene=null;paused=false
 for i in 3:await process_frame
 print("SKULLPION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
