extends "res://tests/forest-shrine/ruby_carvings_test.gd"
const COURT_REVIEW="res://build/Other Files/Asset Toolkit/Ruby Curtains Armor/"
func review_folder()->String:return COURT_REVIEW
func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var saved=JSON.stringify(get_meta("falan_venture"))
 await approach_black_prayer();await room(Tour.Prayer.ENTRY)
 await check_black_prayer_floors()
 await check_populated_combat()
 await room(Ruby.ROOM);await position_at(Vector2(-3,-6))
 for frame in 8:await physics_frame
 check(game.model.enemies.size()==10,"Ruby keeps her original ten-person party despite the denser mazes")
 var props=game.world.find_child("ArchivedRubyProps",true,false)
 var ids=[16465,16466,16193,16196]
 var originals=Tour.Indoor.RoomArt.RubyProps.PLACEMENTS[Ruby.ROOM].filter(func(row):return row[1] in ids)
 var models=props.get_children().filter(func(node):return node.get_meta("blue_cg_serial",0) in ids)
 check(models.size()==9 and models.size()==originals.size(),"Both native curtains and all seven armored statues use solid scenery")
 var shared={};var placed_triangles=0;var mesh_triangles={}
 for node in models:
  var serial:int=node.get_meta("blue_cg_serial")
  check(originals.any(func(row):return row[0]==node.get_meta("source_cell") and row[1]==serial),"Court scenery retains every exact original placement")
  check(node.find_children("*","Sprite3D",true,false).is_empty() and node.find_children("*","CollisionObject3D",true,false).is_empty(),"Solid court props add no sprite or collision owner")
  var model:MeshInstance3D=node.get_child(0)
  if shared.has(serial):check(shared[serial]==model.mesh,"Repeated armored statues share the same prepared mesh")
  shared[serial]=model.mesh
  var bounds:AABB=model.mesh.get_aabb()
  check(bounds.size.z>.4 and bounds.position.y>=-.02 and bounds.end.y<=8.51,"Curtains and armor have real depth and fit below the palace ceiling")
  var count_=0;var cloth_depths=[]
  for surface in model.mesh.get_surface_count():
   var arrays:Array=model.mesh.surface_get_arrays(surface)
   var indices=arrays[Mesh.ARRAY_INDEX]
   count_+=(indices.size() if indices!=null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
   for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    if serial in [16193,16196] and point.y<1.5:check(absf(point.x)<=1.5 and absf(point.z)<=1.5,"Statue feet and low spear stay in their original blocked cell")
   if serial in [16465,16466] and surface==0:
    var uv2s:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
    for i in uv2s.size():
     if uv2s[i]==Art.Scenery.TILES["curtain_"+str(serial)]:cloth_depths.append(arrays[Mesh.ARRAY_VERTEX][i].z)
  if serial in [16465,16466]:
   check(bounds.size.x<=6.01 and bounds.size.z<=3.01,"The curved canopy and pleated cloth fit the original two-cell footprint")
   check(not cloth_depths.is_empty() and cloth_depths.max()-cloth_depths.min()>.15,"The original red/gold curtain paint follows modeled folds")
  placed_triangles+=count_;mesh_triangles[str(serial)]=count_
 var empty=Node3D.new();game.world.add_child(empty)
 for pass_ in 3:
  for serial in ids:
   var copy=Art.court_prop(empty,Vector2i.ZERO,Vector2.ZERO,serial)
   check(copy.get_child(0).mesh==shared[serial],"Repeated room setup reuses immutable court meshes/materials")
   copy.queue_free()
  await process_frame
 empty.queue_free()
 print("RUBY_COURT_MESHES ",JSON.stringify({"placed_triangles":placed_triangles,"unique_meshes":shared.size(),"triangles":mesh_triangles}))
 if DisplayServer.get_name()!="headless":await capture_court(models)
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Court recovery and denser encounters preserve the user's saved adventure")
 print("RUBY_COURT_RESULT props=",models.size()," population=",Tour.Prayer.PATROL_COUNT," checks=",checks," failures=",errors)
func check_populated_combat():
 check(game.model.falan_floor==Tour.Prayer.FLOORS.back(),"The combat review follows the connected route to the sixth floor")
 var at=Tour.Prayer.point(Tour.Prayer.room_center(Vector2i(0,3)))
 var camera=game.camera_rig.camera
 camera.global_position=game.model.world_point(at+Vector2(6,8),8)
 camera.look_at(game.model.world_point(at,1.2));camera.fov=80;camera.reset_physics_interpolation()
 var runtime=game.army_runtime
 check(game.model.enemies.size()==96 and runtime.handles.size()>=96,"The combat review starts with the full 96 live native enemies")
 var initial={}
 for row in game.model.enemies.values():initial[row.id]=row.hp
 var event=InputEventKey.new();event.keycode=KEY_J;event.physical_keycode=KEY_J;event.pressed=true
 for frame in 30:await physics_frame
 game.player.set_auto_attack(false)
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true)
 check(game.player.auto_attack_enabled,"The normal J control enables Kaz's automatic melee for the encounter")
 await position_at(at)
 var frames_ms=[]
 runtime.native.simulation_profile(true)
 for frame in 600:
  await physics_frame
  if frame>60:frames_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
 var profile:Dictionary=runtime.native.simulation_profile(false)
 game.player.set_auto_attack(false)
 check(game.model.enemies.values().any(func(row):return initial.has(row.id) and row.hp<initial[row.id]) or game.model.enemies.size()<96,"Kaz damages real native enemies in the populated maze")
 var damaged=game.model.enemies.values().filter(func(row):return initial.has(row.id) and row.hp<initial[row.id])
 frames_ms.sort()
 print("RUBY_MAZE_COMBAT ",JSON.stringify({"start":96,"remaining":game.model.enemies.size(),"damaged":damaged.size(),"physics_ticks":600,"native_steps":profile.steps,"native_step_mean_ms":profile.total_ms/maxf(1,profile.steps),"whole_frame_p95_ms":frames_ms[int(frames_ms.size()*.95)],"whole_frame_max_ms":frames_ms[-1]}))
 if DisplayServer.get_name()!="headless":await shot("populated-maze-combat",game.model.world_point(at+Vector2(6,8),8),game.model.world_point(at,1.2),80)
func capture_court(models:Array):
 var presentation=game.crowd.army.presentation
 var visible_before:bool=presentation.visible;presentation.hide()
 var gallery=Node3D.new();gallery.position=Vector3(2000,0,2000)*game.model.falan_scale;gallery.scale=Vector3.ONE*game.model.falan_scale;game.world.add_child(gallery)
 for serial in [16465,16466,16193,16196]:
  var source=models.filter(func(node):return node.get_meta("blue_cg_serial")==serial)[0]
  var copy=source.duplicate();copy.position=Vector3.ZERO;gallery.add_child(copy)
  await shot("solid-"+str(serial),gallery.to_global(Vector3(-6 if serial in [16193,16196] else 6,5.8,10)),gallery.to_global(Vector3(-.2,4.0,0)),54)
  if serial==16193:await shot("armor-side",gallery.to_global(Vector3(-6,3.7,7)),gallery.to_global(Vector3(0,2.1,0)),48)
  copy.queue_free();await process_frame
 gallery.queue_free();await process_frame
 var curtain=models.filter(func(node):return node.get_meta("blue_cg_serial")==16465)[0]
 await shot("curtains-original-palace",curtain.to_global(Vector3(1,5,10)),curtain.to_global(Vector3(-6,3.8,1)),77)
 var armor_=models.filter(func(node):return node.get_meta("source_cell")==Vector2i(45,30))[0]
 await shot("armor-original-hall",armor_.to_global(Vector3(-8,5,11)),armor_.to_global(Vector3(-3,2.5,1)),74)
 presentation.visible=visible_before
