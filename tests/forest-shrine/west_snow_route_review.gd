extends "res://tests/forest-shrine/original_maps_test.gd"
## Jump between unchanged source anchors; fixed noon/cameras and isolated preferences.
var review_root="res://build/Other Files/Asset Toolkit/West Gate Snow Route/"
var records=[]
var phase="Before"
var route:Dictionary
var stage:Dictionary
var baseline_poses:Dictionary={}
var first_snow=false
var freeze_physics=false
var reuse_gameplay_baseline=true

func local_point(cell:Vector2)->Vector2:
 if stage.area!="interior":return Tour.Regions.frame(stage.area).inverse()*(cell*3)
 if stage.source==null:return Original.point(int(stage.floor),Vector2i(cell),341)
 return Original.source_point(int(stage.floor),Vector2i(cell))

func world_point(cell:Vector2,height:float=0)->Vector3:
 var at=local_point(cell)
 return game.model.world_point(at,height)

func source_vector(vector:Vector2)->Vector2:
 return Tour.Regions.frame(stage.area).inverse().basis_xform(vector) if stage.area!="interior" else vector

func hide_canvas(node:Node):
 if node is CanvasLayer:node.hide()
 for child in node.get_children():hide_canvas(child)

func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--stage="):phase=arg.trim_prefix("--stage=")
 first_snow="--first-snow" in OS.get_cmdline_user_args()
 if "--baseline-scenery" in OS.get_cmdline_user_args():
  # Test-only replay: source 400's original tree placement/scale and unfilled native cliffs.
  Original.WestScenery.catalog().maps.erase("400")
 route=JSON.parse_string(FileAccess.get_file_as_string(review_root+"route.json"))
 var selected=Array(OS.get_cmdline_user_args()).filter(func(a):return a.begins_with("--area="))
 if not selected.is_empty() and FileAccess.file_exists(review_root+phase+"/route.json"):
  route=JSON.parse_string(FileAccess.get_file_as_string(review_root+phase+"/route.json"))
 if not selected.is_empty() and FileAccess.file_exists(review_root+phase+"/cameras.json"):
  var prefixes=selected.map(func(p):return p.trim_prefix("--area="))
  var bridge_only=OS.get_cmdline_user_args().has("--bridge-only")
  records=JSON.parse_string(FileAccess.get_file_as_string(review_root+phase+"/cameras.json")).filter(func(p):
   if first_snow:return not ("first-snow" in p.name)
   if bridge_only:return not ("-bridge-" in p.name)
   return "-bridge-" in p.name or not prefixes.any(func(prefix):return p.name.begins_with(prefix)))
 if phase!="Before":
  for pose in JSON.parse_string(FileAccess.get_file_as_string(review_root+"Before/cameras.json")):
   if reuse_gameplay_baseline or pose.kind!="gameplay":baseline_poses[pose.name]=pose
 if phase=="After" and FileAccess.file_exists(review_root+"Replay/cameras.json"):
  for pose in JSON.parse_string(FileAccess.get_file_as_string(review_root+"Replay/cameras.json")):
   if "first-snow" in pose.name:baseline_poses[pose.name]=pose
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-west-snow-review-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.set_process(false)
 if freeze_physics:game.set_physics_process(false);game.player.set_physics_process(false)
 if phase!="Before":
  game.run_seed=int(JSON.parse_string(FileAccess.get_file_as_string(review_root+"Before/cameras.json"))[0].seed)
 game.camera_rig.set_process_unhandled_input(false)
 for row in route.stages:
  stage=row
  var filters=Array(OS.get_cmdline_user_args()).filter(func(a):return a.begins_with("--area="))
  if not filters.is_empty() and not filters.any(func(p):return stage.key.begins_with(p.trim_prefix("--area="))):continue
  print("WEST_SNOW_ENTER ",stage.key)
  game.explorer_clock.load_hour(12)
  var at=local_point(Vector2(stage.anchors[0][0],stage.anchors[0][1]))
  var layout=Original.layout(int(stage.floor)) if stage.area=="interior" else Tour.outdoor_layout(get_meta("falan_venture"),stage.area)
  layout=layout.duplicate(true);layout.seed=341
  Tour.travel(game,layout,{"arrival":at,"yaw":0.0,"velocity":Vector3.ZERO})
  if freeze_physics:game.set_physics_process(false);game.player.set_physics_process(false)
  for i in 6:await physics_frame
  game.set_process(false);game.player.set_physics_process(false)
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
  game.camera_rig.set_process(false);hide_canvas(game)
  var static_stats={"area":stage.key,"meshes":0,"surfaces":0,"triangles":0,"instances":0,"collision_shapes":game.world.map_features.find_children("*","CollisionShape3D",true,false).size()}
  for node in game.world.map_features.find_children("*","GeometryInstance3D",true,false):
   var mesh:Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D else null
   if mesh==null:continue
   static_stats.meshes+=1;static_stats.surfaces+=mesh.get_surface_count()
   static_stats.instances+=node.multimesh.instance_count if node is MultiMeshInstance3D else 1
   for slot in mesh.get_surface_count():
    var arrays=mesh.surface_get_arrays(slot)
    static_stats.triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
  var stats_dir=review_root+phase+"/"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stats_dir))
  var stats_file=FileAccess.open(stats_dir+stage.key+"-geometry.json",FileAccess.WRITE);stats_file.store_string(JSON.stringify(static_stats,"  "));stats_file.close()
  if OS.get_cmdline_user_args().has("--bridge-only"):
   for view in [["bridge-east-approach",Vector2i(264,181)],["bridge-crossing",Vector2i(256,181)]]:
    var c:Vector2i=view[1]
    await gameplay({"key":stage.key+"-"+view[0],"at":[c.x,c.y],"start":[c.x+1,c.y],"end":[c.x-1,c.y]})
   write_records();continue
  if first_snow:
   await exact_snow_views()
   if phase=="Replay":await gameplay({"key":stage.key+"-anchor-00","at":stage.anchors[0],"start":stage.anchors[0],"end":stage.anchors[1]})
   write_records();continue
  var environment_:Environment=game.world.get_world_3d().environment
  var fog=environment_.fog_enabled
  environment_.fog_enabled=false
  var ceilings=game.world.find_children("*Ceiling*","MeshInstance3D",true,false).filter(func(n):return n.visible)
  for node in ceilings:node.hide()
  if stage.source==null:
   var state=Original.state(int(stage.floor),game.model.seed_value)
   stage.sections=[]
   var first=Vector2i(stage.anchors[0][0],stage.anchors[0][1]);var last=Vector2i(stage.anchors[1][0],stage.anchors[1][1])
   var queue=[first];var previous={first:first};var cursor=0
   while cursor<queue.size() and not previous.has(last):
    var cell:Vector2i=queue[cursor];cursor+=1
    for offset in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     var next:Vector2i=cell+offset
     if previous.has(next) or not Original.open(state.bits,state.size,next):continue
     previous[next]=cell;queue.append(next)
   check(previous.has(last),"The unchanged generated floor connects both route stairs")
   var path=[];var cell=last
   while cell!=first:path.push_front([cell.x,cell.y]);cell=previous[cell]
   path.push_front([first.x,first.y]);stage.path=path
   for i in range(0,path.size()-1,16):
    var part=path.slice(i,mini(i+17,path.size()))
    stage.sections.append({"key":stage.key+"-route-%02d"%(i/16+1),"at":part[part.size()/2],"start":part[0],"end":part[-1],"path":part})
   check(state.raw==Original.state(int(stage.floor),game.model.seed_value).raw,"Generated review layout repeats")
  var path:Array=stage.path
  if path.is_empty():path=stage.sections.map(func(s):return s.at)
  var low=Vector2.INF;var high=-low
  for cell in path:
   var p=Vector2(cell[0],cell[1]);low=low.min(p);high=high.max(p)
  var center=(low+high)*.5
  await overhead(stage.key+"-whole",center,maxf((high-low).x*.625,(high-low).y)*3+60)
  for section in stage.sections:
   var cell=Vector2(section.at[0],section.at[1])
   await isometric(section.key,cell,96.0)
  for node in ceilings:node.show()
  environment_.fog_enabled=fog
  # Every ordinary section is inspected overhead; normal follow views cover each bend and both sides of every transition.
  var views=[]
  for index in stage.sections.size():
   if index%3==0 or index==stage.sections.size()-1:views.append(stage.sections[index])
  for section in views:
   await gameplay(section)
  if stage.source==null:
   for i in 3:
    var cell=Original.safe_cell(int(stage.floor),Vector2i(15,21) if i==0 else Vector2i(20,13) if i==1 else Vector2i(25,4),game.model.seed_value)
    var section={"key":stage.key+"-%02d"%(i+1),"at":[cell.x,cell.y],"start":[cell.x,cell.y],"end":[cell.x+1,cell.y]}
    await isometric(section.key,Vector2(cell),96)
    if i in [0,2]:await gameplay(section)
  for index in stage.anchors.size():
   var here=stage.anchors[index]
   var start=stage.anchors[maxi(0,index-1)]
   var end=stage.anchors[mini(stage.anchors.size()-1,index+1)]
   await gameplay({"key":stage.key+"-anchor-%02d"%index,"at":here,"start":start,"end":end})
  if phase=="After" and int(stage.floor)==51031 and FileAccess.file_exists(review_root+"Replay/cameras.json"):await exact_snow_views()
  write_records()
 write_records()
 print("WEST_SNOW_REVIEW_RESULT failures=",failures," captures=",records.size())
 game.queue_free();await process_frame;quit(1 if failures else 0)

func exact_snow_views():
 for view in [["first-snow-edge",Vector2i(212,349)],["first-snow-cover",Vector2i(212,348)]]:
  var c:Vector2i=view[1]
  var section={"key":stage.key+"-"+view[0],"at":[c.x,c.y],"start":[c.x,c.y+1],"end":[c.x,c.y-1]}
  await isometric(section.key,Vector2(c),96)
  await gameplay(section)

func write_records():
 var folder=review_root+phase+"/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var file=FileAccess.open(folder+"cameras.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(records,"  "));file.close()
 var checklist=FileAccess.open(folder+"route.json",FileAccess.WRITE)
 checklist.store_string(JSON.stringify(route,"  "));checklist.close()

func basis_record(name_:String,kind:String,cell:Vector2)->Dictionary:
 var camera:Camera3D=game.camera_rig.camera
 var zero=world_point(Vector2.ZERO);zero.y=world_point(cell).y
 var x=world_point(Vector2.RIGHT);x.y=zero.y
 var y=world_point(Vector2.DOWN);y.y=zero.y
 var a=camera.unproject_position(zero);var b=camera.unproject_position(x);var c=camera.unproject_position(y)
 return {"name":name_,"kind":kind,"area":stage.area,"floor":stage.floor,"source":stage.source,"cell":[cell.x,cell.y],"eye":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"rotation":[camera.global_rotation.x,camera.global_rotation.y,camera.global_rotation.z],"size":camera.size,"fov":camera.fov,"projection":camera.projection,"seed":game.model.seed_value,"source_zero":[a.x,a.y],"source_x":[b.x-a.x,b.y-a.y],"source_y":[c.x-a.x,c.y-a.y],"scale":game.model.falan_scale,"links":game.model.get_meta("falan_links",[]).map(func(l):return {"at":str(l.at),"to":l.to,"floor":l.get("floor",0),"arrival":str(l.get("arrival",Vector2.ZERO))})}

func isometric(name_:String,cell:Vector2,span:float):
 var environment_:Environment=game.world.get_world_3d().environment
 var fog=environment_.fog_enabled;environment_.fog_enabled=false
 var ceilings=game.world.find_children("*Ceiling*","MeshInstance3D",true,false).filter(func(n):return n.visible)
 for node in ceilings:node.hide()
 game.player.position=world_point(cell,.15);game.model.hero_position=game.player.position
 game.world.sync(0)
 var camera:Camera3D=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=span*game.model.falan_scale;camera.far=20000
 var at=world_point(cell)
 var vector=source_vector(Vector2(-1,1))
 camera.global_position=at+Vector3(vector.x,1.60356745,vector.y)*200*game.model.falan_scale;camera.look_at(at)
 await shot(name_+"-iso")
 records.append(basis_record(name_+"-iso","isometric",cell))
 for node in ceilings:node.show()
 environment_.fog_enabled=fog

func overhead(name_:String,cell:Vector2,span:float):
 var camera:Camera3D=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=span*game.model.falan_scale;camera.far=20000
 var at=world_point(cell)
 var up=source_vector(Vector2(0,-1))
 camera.global_position=at+Vector3.UP*2000*game.model.falan_scale;camera.look_at(at,Vector3(up.x,0,up.y))
 await shot(name_+"-overhead")
 records.append(basis_record(name_+"-overhead","overhead",cell))

func gameplay(section:Dictionary):
 var cell=Vector2(section.at[0],section.at[1]);var a=Vector2(section.start[0],section.start[1]);var b=Vector2(section.end[0],section.end[1])
 var ahead=local_point(b)-local_point(a)
 game.player.position=world_point(cell,.15);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
 game.model.hero_position=game.player.position;game.world.sync(0)
 var camera:Camera3D=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 game.camera_rig.yaw=atan2(-ahead.x,-ahead.y);game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH
 game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT;game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance()
 game.camera_rig.set_process(true)
 for i in 12:await process_frame
 game.camera_rig.set_process(false)
 # Reuse the exact baseline eye/rotation even if scenery changes camera occlusion.
 var previous=review_root+"Before/cameras.json"
 if reuse_gameplay_baseline and phase!="Before" and FileAccess.file_exists(previous):
  for pose in JSON.parse_string(FileAccess.get_file_as_string(previous)):
   if pose.name!=section.key+"-play":continue
   camera.global_position=Vector3(pose.eye[0],pose.eye[1],pose.eye[2]);camera.global_rotation=Vector3(pose.rotation[0],pose.rotation[1],pose.rotation[2]);camera.fov=pose.fov
   break
 await shot(section.key+"-play")
 records.append(basis_record(section.key+"-play","gameplay",cell))

func shot(name_:String):
 if baseline_poses.has(name_):
  var pose:Dictionary=baseline_poses[name_];var camera:Camera3D=game.camera_rig.camera
  camera.projection=int(pose.projection);camera.size=pose.size;camera.fov=pose.fov
  camera.global_position=Vector3(pose.eye[0],pose.eye[1],pose.eye[2]);camera.global_rotation=Vector3(pose.rotation[0],pose.rotation[1],pose.rotation[2])
 var folder=review_root+phase+"/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 game.camera_rig.camera.reset_physics_interpolation()
 for i in 3:await process_frame
 RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(folder+name_+".png")==OK,"Save "+name_)
