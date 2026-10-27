extends SceneTree
var game
func _initialize():run.call_deferred()
func run():
 var doc=preload("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_kai_highway();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://skullpion-capture-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 5:await process_frame
 game.set_physics_process(false);game.set_process(false);game.player.set_physics_process(false);game.explorer_helpers.set_process(false);game.army_runtime.set_process(false)
 game.start_wave();game.model.waves.spawn_clock=100000;game.model.waves.pending=999
 assert(game.model.waves.spawn_skullpion([]))
 var row=game.model.enemies.values().filter(func(e):return e.variant==4)[0]
 var point:Vector3=row.pos+preload("res://scripts/forest/forest_routes.gd").direction(game.model.portals[row.get("portal_index",0)])*16
 point.y=game.model.surface_height(point.x,point.z)
 game.army_runtime.import_arrivals()
 game.army_runtime.set_pose(game.army_runtime.handles[row.id],point,0)
 var snapshot=game.army_runtime.render_snapshot();game.crowd.army.present(snapshot,[])
 var view=game.crowd.army.skullpions[row.id];var index:int=snapshot.logical_ids.find(row.id)
 view.show();view.set_process(false)
 var camera=Camera3D.new();root.add_child(camera);camera.position=point+Vector3(50,60,85);camera.look_at(point+Vector3(0,12,-15));camera.current=true;camera.fov=48
 game.model.visible_cells[game.model.cell_of(point)]=true
 game.player.global_position=point+Vector3(18,0,22);game.player.global_position.y=game.model.surface_height(game.player.global_position.x,game.player.global_position.z)
 var captures=[]
 for spec in [[100,0.0,"idle"],[102,1.15,"tail_sweep"],[103,3.1,"sand_blast"],[104,.9,"jump_stomp"],[105,2.0,"poison_drill"],[106,2.1,"wall_climb"],[107,.1,"core_exposed"],[108,2.4,"bouncing_volley"]]:
  if spec[0]==108:
   var runtime=game.army_runtime;var handle:int=runtime.handles[row.id]
   runtime.set_navigation(999999,{"width":0});runtime.set_pose(handle,Vector3.ZERO,0)
   runtime.native.apply_hit(handle,{"amount":150000.0})
   var context={"targets":{"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,0,30)]),"hp":PackedFloat32Array([1000000])}}
   for step in 2000:
    runtime.step(.05,context);snapshot=runtime.render_snapshot();index=snapshot.logical_ids.find(row.id)
    if snapshot.actions[index]==108 and snapshot.action_time[index]>=2.48:break
   assert(snapshot.actions[index]==108 and snapshot.projectile_ids.size()>0)
   var offset:Vector3=point-snapshot.positions[index]
   for unit in snapshot.positions.size():snapshot.positions[unit]+=offset
   for shot in snapshot.projectile_positions.size():snapshot.projectile_positions[shot]+=offset
   game.crowd.army.present(snapshot,[])
  else:snapshot.actions[index]=spec[0];snapshot.action_time[index]=spec[1]
  view.cue(game.player.global_position,1);view.sync(snapshot,index);view.show()
  await process_frame;await RenderingServer.frame_post_draw
  var path="res://build/Other Files/Asset Toolkit/Skullpion/"+spec[2]+".png"
  root.get_texture().get_image().save_png(path);captures.append(path)
 print("SKULLPION_CAPTURES ",captures)
 game.sound_library.cancel();game.music.stop();game.move_audio.stop();game.queue_free();current_scene=null;paused=false
 await process_frame;quit()
