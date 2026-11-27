extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Bounded review of the six mapped city rooms omitted by blocked-only fixture recovery.
const REVIEW="res://build/Other Files/Asset Toolkit/Falan City Reconstruction/Visual Continuation/Interior Coverage/"
const ROOMS=[1810,1811,1156,1182,1181,1172]
var checks=0

func _initialize():
 if "--metrics-only" in OS.get_cmdline_user_args():
  model_metrics.call_deferred();return
 if "--baseline" in OS.get_cmdline_user_args():
  printerr("The pre-fixture room baseline is frozen; this review now verifies the recovered rooms.");quit(1);return
 create_timer(600).timeout.connect(func():printerr("FALAN_ROOM_COVERAGE_TIMEOUT");quit(1))
 run.call_deferred()

func model_metrics():
 var kit=load("res://scripts/forest/forest_falan_city_room_fixtures.gd")
 for serial in [10031,11017,11018,11019,16552,16553,16060]:
  var g:Dictionary=kit.data().graphics[str(serial)];var mesh:Mesh=kit.shape(serial,g,0)
  print("FALAN_MODEL_SIZE ",serial," family=",g.family," bounds=",mesh.get_aabb())
 quit()

func check(ok:bool,message:String):
 checks+=1;super.check(ok,message)

func collision_signature()->String:
 var rows=[]
 for node in game.world.find_children("*","CollisionShape3D",true,false):
  if not node.get_parent() is StaticBody3D:continue
  var shape:Shape3D=node.shape
  var content=var_to_bytes([node.global_transform,node.get_parent().collision_layer,node.get_parent().collision_mask,shape.get_class()])
  if shape is BoxShape3D:content.append_array(var_to_bytes(shape.size))
  elif shape is ConcavePolygonShape3D:content.append_array(shape.get_faces().to_byte_array())
  else:content.append_array(var_to_bytes(shape.get_debug_mesh().get_aabb()))
  var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(content);rows.append(hash_.finish().hex_encode())
 rows.sort();return JSON.stringify(rows)

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var phase="after"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 var saved=JSON.stringify(get_meta("falan_venture"));var signatures={}
 var selected=[]
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--only-rooms="):
   for value in argument.trim_prefix("--only-rooms=").split(","):selected.append(int(value))
 for id in ROOMS:
  if not selected.is_empty() and id not in selected:continue
  if id==1172:
   await room(1170)
   await room(1171)
  await room(id)
  check(Tour.area(game.model)=="interior" and game.model.falan_floor==id,"Mapped city room remains reachable: "+str(id))
  if game.model.falan_floor!=id:continue
  var info:Array=Tour.Indoor.floor_info(id)
  signatures[str(id)]={"navigation":JSON.stringify(info),"colliders":collision_signature()}
  var expected:int=load("res://scripts/forest/forest_falan_city_room_fixtures.gd").data().maps[str(id)].placements.size()
  var recovered=0
  for node in game.world.find_children("*","MultiMeshInstance3D",true,false):
   if node.get_meta("falan_city_room",0)==id:
    recovered+=node.multimesh.instance_count
    check(node.multimesh.mesh!=null and node.multimesh.mesh.get_surface_count()>0,"Fixture batch has its prepared model: "+node.name)
  check(recovered==expected,"All original fixture placements render for room "+str(id))
  for link in game.model.get_meta("falan_links",[]):
   var point=Vector3(link.at.x,1.2,link.at.y)*game.model.falan_scale;var blocked=[]
   for node in game.world.find_children("*","MultiMeshInstance3D",true,false):
    if node.get_meta("falan_city_room",0)!=id:continue
    for i in node.multimesh.instance_count:
     var bounds:AABB=(node.global_transform*node.multimesh.get_instance_transform(i))*node.multimesh.mesh.get_aabb()
     if bounds.has_point(point):blocked.append(node.get_meta("original_graphic"))
   check(blocked.is_empty(),"Recovered fixtures leave doorway visible in room "+str(id)+": "+str(blocked))
  if not "--gameplay-only" in OS.get_cmdline_user_args():
   await room_shot(id,info,phase,Vector3(70,72,70),"source")
   await room_shot(id,info,phase,Vector3(-70,54,-70),"reverse")
  await gameplay_room_shot(id,info)
  if id==1172:
   await room(1171)
   await room(1170)
  var exits:Array=game.model.get_meta("falan_links",[]).filter(func(link):return link.to=="city")
  check(not exits.is_empty(),"Mapped room has its original city return: "+str(id))
  if not exits.is_empty():
   await position_at(exits[0].at)
   if Tour.area(game.model)=="interior":await walk_through_entry()
   check(Tour.area(game.model)=="city","Mapped room returns to its own city door: "+str(id))
 var after=FileAccess.open(REVIEW+("collision-after.json" if selected.is_empty() else "collision-focused.json"),FileAccess.WRITE);after.store_string(JSON.stringify(signatures,"  "));after.close()
 var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"collision-before.json"))
 for id in signatures:
  check(signatures[id].navigation==baseline[id].navigation,"Original navigation remains unchanged: "+id)
  check(signatures[id].colliders==baseline[id].colliders,"Original static collision remains unchanged: "+id)
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Room recovery preserves the saved adventure")
 print("FALAN_ROOM_COVERAGE_RESULT checks=",checks," failures=",errors)

func room_shot(id:int,info:Array,phase:String,eye:Vector3,label:String):
 if DisplayServer.get_name()=="headless":return
 var center:Vector2=info[1]+Vector2(info[0]-Vector2i.ONE)*1.5
 var at=Vector3(center.x,1.5,center.y)*game.model.falan_scale
 game.ui.hide();game.set_process(false);root.grab_focus()
 var camera:Camera3D=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=maxf(info[0].x,info[0].y)*2.6*game.model.falan_scale
 camera.global_position=at+eye*game.model.falan_scale;camera.look_at(at);camera.reset_physics_interpolation()
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REVIEW+phase+"/"+str(id)+"-"+label+".png")==OK,"Captured original city room "+str(id)+" "+label)
 game.set_process(true);game.ui.show()

func gameplay_room_shot(id:int,info:Array):
 if DisplayServer.get_name()=="headless":return
 var rows:Array=load("res://scripts/forest/forest_falan_city_room_fixtures.gd").data().maps[str(id)].placements
 var desired=Vector2.ZERO
 for row in rows:desired+=info[1]+(Vector2(row.cell[0],row.cell[1])+Vector2(row.span[0]-1,row.span[1]-1)*.5)*3.
 desired/=rows.size()
 var rig=game.camera_rig;rig.distance=game.settings.forest_camera_distance
 var framing:float=rig.framing_scale();var distance_:float=rig.combat_distance()
 var town=game.world.get("furnished_town");var indoors=is_instance_valid(town) and town.indoor
 var view_pitch=maxf(game.COMBAT_CAMERA_PITCH,.74) if indoors else game.COMBAT_CAMERA_PITCH+rig.combat_camera_angle+(.13 if rig.centered_combat_frame() else 0.)
 if indoors:distance_=8.
 var at=Vector2.INF;var score=-INF;var yaw=0.;var furniture:Array[AABB]=[]
 for node in game.world.find_children("*","MultiMeshInstance3D",true,false):
  if node.get_meta("falan_city_room",0)!=id:continue
  for i in node.multimesh.instance_count:furniture.append((node.global_transform*node.multimesh.get_instance_transform(i))*node.multimesh.mesh.get_aabb())
 var space=game.world.get_world_3d().direct_space_state
 for y in info[0].y:
  for x in info[0].x:
   var candidate:Vector2=info[1]+Vector2(x,y)*3.
   if game.model.get_meta("falan_links",[]).any(func(link):return link.at.distance_to(candidate)<4.):continue
   if not game.model.terrain.disk_clear(Vector3(candidate.x,.5,candidate.y),.7):continue
   var anchor:Vector3=game.model.world_point(candidate,.15)+Vector3.UP*1.4*framing
   if furniture.any(func(bounds:AABB):return bounds.has_point(anchor)):continue
   for angle in [0.,PI*.5,PI,-PI*.5,PI*.25,PI*.75,-PI*.25,-PI*.75]:
    var offset=Vector3(sin(angle)*cos(view_pitch),sin(view_pitch),cos(angle)*cos(view_pitch));var safe=distance_
    for probe in [Vector3.ZERO,Vector3(.24,0,0),Vector3(-.24,0,0),Vector3(0,.22,0),Vector3(0,-.22,0)]:
     var query=PhysicsRayQueryParameters3D.create(anchor+probe,anchor+offset*distance_+probe,1)
     if indoors:query.exclude=town.camera_exclusions
     var hit=space.intersect_ray(query)
     if not hit.is_empty():safe=minf(safe,maxf(.55,anchor.distance_to(hit.position)-.38))
    var value=safe*5.-candidate.distance_to(desired)*game.model.falan_scale*.15
    if value>score:at=candidate;score=value;yaw=angle
 check(at.is_finite(),"Room has a reachable gameplay camera station: "+str(id))
 if not at.is_finite():return
 var player=game.player;var position_before:Vector3=player.position;var facing_before:Vector3=player.facing
 var crossing_before:Vector2=game.falan_crossing_position;var physics=player.is_physics_processing()
 player.set_physics_process(false);player.position=game.model.world_point(at,.15);player.velocity=Vector3.ZERO
 player.facing=Vector3.LEFT;player.reset_physics_interpolation();game.falan_crossing_position=at
 for i in 4:await process_frame
 game.set_process(false);game.ui.hide()
 rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 rig.yaw=yaw;rig.pitch=game.COMBAT_CAMERA_PITCH;rig.reset_follow()
 for i in 90:rig.update_camera(1./60.)
 rig.camera.reset_physics_interpolation()
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 check(rig.camera.global_position.distance_to(player.global_position)>framing*3.,"Gameplay camera remains outside the fighter: "+str(id))
 print("FALAN_ROOM_CAMERA ",id," player=",at," yaw=",yaw," distance=",rig.current_distance," fov=",rig.camera.fov)
 check(root.get_texture().get_image().save_png(REVIEW+"after/"+str(id)+"-play.png")==OK,"Captured second interior view through actual Explore rig: "+str(id))
 player.position=position_before;player.facing=facing_before;player.reset_physics_interpolation()
 game.falan_crossing_position=crossing_before;player.set_physics_process(physics);game.set_process(true);game.ui.show()
