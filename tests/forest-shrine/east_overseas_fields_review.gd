extends "res://tests/forest-shrine/east_region_review.gd"
## Load both complete continental fields and sample the ordinary gameplay camera.
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Bank=preload("res://scripts/forest/crowd/east_region_sprites.gd")
const Region=preload("res://scripts/forest/forest_east_region.gd")
const DEST="res://build/Other Files/Asset Toolkit/East Gate Region/Verification/OverseasFields/"
var records=[]
var report_dir=DEST
func _initialize():
 create_timer(1200,true,false,true).timeout.connect(func():printerr("EAST_OVERSEAS_FIELDS_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1440,900);root.title="Cross Gate · Continental Fields"
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-overseas-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 report_dir=DEST+"Profiled/" if "--goral-only" in OS.get_cmdline_user_args() else DEST
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
 for source in ([43000] if "--goral-only" in OS.get_cmdline_user_args() else [33000,43000]):await field(source)
 var file=FileAccess.open(report_dir+"review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"fields":records,"scope":"Complete source-field direct loads, original city-gate landings, ordinary gameplay cameras and bounded quiet-map frame samples. No road walkthrough, combat stress or long-session smoothness claim."},"  "));file.close()
 print("EAST_OVERSEAS_FIELDS_RESULT checks=",checks," failures=",errors)
 await finish()

func field(source:int):
 var id=Maps.runtime_id(source);var entry=[]
 var city=33200 if source==33000 else 43100
 for row in Region.data().fixed:
  if int(row[0])==city and int(row[3])==source:entry=row;break
 check(not entry.is_empty(),"Original city-to-field connection exists "+str(source))
 if entry.is_empty():return
 var cell=Vector2i(entry[4],entry[5]);var at=Maps.source_point(id,cell)
 var started=Time.get_ticks_usec()
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":at,"yaw":0.,"velocity":Vector3.ZERO})
 var setup_ms=(Time.get_ticks_usec()-started)/1000.
 for i in 30:await physics_frame
 check(game.model.falan_floor==id and Bank.owns_model(game.model),"Full continental field keeps its source/native owner "+str(source))
 check(game.model.terrain.disk_clear(Vector3(at.x,0,at.y),.55),"Original field gate arrival is physically clear "+str(source))
 check(Bank.source_cell(game.model,map_position()).distance_to(cell)<=2.1,"Direct field arrival retains the original source cell "+str(source))
 var snapshot=[]
 for owner in [game.world.map_features]+game.world.map_features.find_children("*","Node3D",true,false):
  if owner.has_meta("recovered_source_map"):snapshot.append({"source":owner.get_meta("recovered_source_map"),"placements":owner.get_meta("recovered_source_placements",0),"floor_placements":owner.get_meta("recovered_floor_placements",0),"floor_array_reads":owner.get_meta("recovered_floor_array_reads",0),"floor_batches":owner.get_meta("recovered_floor_batches",0),"floor_cache":owner.get_meta("recovered_floor_cache",false)})
 for angle in 2:
  game.camera_rig.yaw=0. if angle==0 else PI*.5;game.camera_rig.pitch=.32;game.camera_rig.reset_follow()
  for i in 18:await physics_frame;game.camera_rig.update_camera(1./60.)
  if DisplayServer.get_name()!="headless":
   game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting();game.ui.hide()
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(report_dir+str(source)+("-normal.png" if angle==0 else "-second.png"))==OK,"Captured full-field gameplay view %d/%d"%[source,angle])
   game.ui.show()
 for i in 120:await process_frame
 game.army_runtime.profile_enabled=true;game.army_runtime.profile_totals.clear()
 var samples=[];var slow=[];var previous=Time.get_ticks_usec();var last_totals={}
 for i in 600:
  await process_frame
  var now=Time.get_ticks_usec();var elapsed=(now-previous)/1000.;samples.append(elapsed);previous=now
  var totals:Dictionary=game.army_runtime.profile_totals
  if elapsed>50.:
   var parts={}
   for key in totals:
    var duration=float(totals[key])-float(last_totals.get(key,0.))
    if duration>1.:parts[key]=duration
   slow.append({"frame":i,"ms":elapsed,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"profile_ms":parts})
  last_totals=totals.duplicate()
 var profile:Dictionary=game.army_runtime.profile_totals.duplicate();game.army_runtime.profile_enabled=false
 samples.sort()
 records.append({"source":source,"size":var_to_str(Maps.state(id,game.model.seed_value).size),"entry":[cell.x,cell.y],"setup_ms":setup_ms,"frame_sample_ms":{"p50":samples[300],"p95":samples[570],"max":samples[-1]},"slow_frames":slow,"profile_ms":profile,"enemies":game.model.enemies.size(),"video_memory_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),"nodes":get_node_count(),"collision_shapes":game.world.find_children("*","CollisionShape3D",true,false).size(),"static_bodies":game.world.find_children("*","StaticBody3D",true,false).size(),"source_batches":snapshot,"display":DisplayServer.get_name()})
 print("EAST_OVERSEAS_FIELD source=",source," setup_ms=",setup_ms," frame_p95=",samples[570]," slow_frames=",slow.size()," batches=",snapshot)
