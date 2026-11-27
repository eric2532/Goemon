extends "res://tests/forest-shrine/west_snow_route_review.gd"
## Test-only fixed jumps; physics is frozen before an exit tile can trigger travel.
func _initialize():
 review_root="res://build/Other Files/Asset Toolkit/Ruby Region Reconstruction/"
 freeze_physics=true
 create_timer(1500).timeout.connect(func():printerr("RUBY_REGION_REVIEW_TIMEOUT");quit(1))
 run.call_deferred()

func local_point(cell:Vector2)->Vector2:
 if stage.area=="interior":return Tour.Indoor.floor_info(int(stage.floor))[1]+cell*3.
 if stage.area in ["venoa","kili"]:return Tour.Regions.Sites.VILLAGES[stage.area][2]+cell*3.
 return Tour.Regions.frame(stage.area).inverse()*(cell*3.)

func source_vector(vector:Vector2)->Vector2:
 return vector if stage.area in ["interior","venoa","kili"] else super.source_vector(vector)

func basis_record(name_:String,kind:String,cell:Vector2)->Dictionary:
 var pose=super.basis_record(name_,kind,cell)
 pose.actual_floor=game.model.falan_floor;pose.actual_area=game.model.falan_area
 pose.hour=game.explorer_clock.hour
 check(pose.actual_area==stage.area and pose.actual_floor==int(stage.floor),"Capture retains labeled map "+name_)
 return pose

func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--stage="):phase=arg.trim_prefix("--stage=")
 route=JSON.parse_string(FileAccess.get_file_as_string(review_root+"route.json"))
 var landmarks=OS.get_cmdline_user_args().has("--landmarks")
 var filters=Array(OS.get_cmdline_user_args()).filter(func(a):return a.begins_with("--area="))
 if not filters.is_empty() and FileAccess.file_exists(review_root+phase+"/cameras.json"):
  records=JSON.parse_string(FileAccess.get_file_as_string(review_root+phase+"/cameras.json")).filter(func(p):return not filters.any(func(f):return p.name.begins_with(f.trim_prefix("--area="))))
 if phase!="Before":
  for pose in JSON.parse_string(FileAccess.get_file_as_string(review_root+"Before/cameras.json")):baseline_poses[pose.name]=pose
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-ruby-region-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.run_seed=41829558
 game.camera_rig.set_process_unhandled_input(false)
 for row in route.stages:
  stage=row
  if not filters.is_empty() and not filters.any(func(f):return stage.key.begins_with(f.trim_prefix("--area="))):continue
  print("RUBY_REGION_REVIEW_ENTER ",stage.key)
  var layout=Tour.Indoor.layout(int(stage.floor)) if stage.area=="interior" else Tour.outdoor_layout(get_meta("falan_venture"),stage.area)
  layout=layout.duplicate(true);layout.seed=341
  var first=stage.sections[0].at if not stage.sections.is_empty() else [9,9]
  # Village positioning uses the loaded model's frame; correct it immediately after setup.
  Tour.travel(game,layout,{"arrival":Vector2.ZERO,"yaw":0.0,"velocity":Vector3.ZERO})
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting();hide_canvas(game)
  if stage.source==null:
   var id=int(stage.floor);var stairs_=Tour.Prayer.stairs(id,game.model.seed_value);stage.sections=[]
   for y in 4:
    for x in 4:
     var c=Tour.Prayer.room_center(Vector2i(x,y))
     stage.sections.append({"key":stage.key+"-room-%02d"%(y*4+x+1),"at":[c.x,c.y],"start":[c.x,c.y+1],"end":[c.x,c.y-1]})
   for i in 2:
    var c:Vector2i=stairs_[i]
    stage.sections.append({"key":stage.key+"-actual-stair-%d"%i,"at":[c.x,c.y],"start":[c.x,c.y+1],"end":[c.x,c.y-1]})
   stage.bounds=[[0,0],[63,63]]
  game.player.position=world_point(Vector2(first[0],first[1]),.15);game.model.hero_position=game.player.position
  for tick in 5:await process_frame
  validate_visual_supports()
  if landmarks:
   var lo=Vector2(stage.bounds[0][0],stage.bounds[0][1]);var hi=Vector2(stage.bounds[1][0],stage.bounds[1][1])
   var environment_:Environment=game.world.get_world_3d().environment;var fog=environment_.fog_enabled;environment_.fog_enabled=false
   var ceilings=game.world.find_children("*Ceiling*","MeshInstance3D",true,false).filter(func(n):return n.visible)
   for node in ceilings:node.hide()
   await overhead(stage.key+"-complete-plan",(lo+hi)*.5,maxf((hi-lo).x,(hi-lo).y*1.6)*3.+64.)
   for node in ceilings:node.show()
   environment_.fog_enabled=fog
   if stage.source==null:
    var info=Tour.Indoor.floor_info(int(stage.floor))
    var bits=Tour.Indoor.walk_mask(int(stage.floor),info[0],info[2].hex_decode(),game.model.seed_value)
    var plan=FileAccess.open(review_root+phase+"/"+stage.key+"-plan.json",FileAccess.WRITE)
    plan.store_string(JSON.stringify({"width":info[0].x,"height":info[0].y,"bits":bits.hex_encode(),"seed":game.model.seed_value}));plan.close()
   for view in landmark_sections():await gameplay(view)
   write_records();continue
  var env:Environment=game.world.get_world_3d().environment;var fog=env.fog_enabled;env.fog_enabled=false
  var ceilings=game.world.find_children("*Ceiling*","MeshInstance3D",true,false).filter(func(n):return n.visible)
  for n in ceilings:n.hide()
  var lo=Vector2(stage.bounds[0][0],stage.bounds[0][1]);var hi=Vector2(stage.bounds[1][0],stage.bounds[1][1])
  await overhead(stage.key+"-whole",(lo+hi)*.5,maxf((hi-lo).x*.625,(hi-lo).y)*3.+36.)
  for section in stage.sections:await isometric(section.key,Vector2(section.at[0],section.at[1]),75.)
  for n in ceilings:n.show()
  env.fog_enabled=fog
  for i in stage.sections.size():
   if i%3==0 or i==stage.sections.size()-1 or "stair" in stage.sections[i].key:await gameplay(stage.sections[i])
  var info=Tour.Indoor.floor_info(int(stage.floor)) if stage.area=="interior" else []
  var bits=Tour.Indoor.walk_mask(int(stage.floor),info[0],info[2].hex_decode(),game.model.seed_value) if not info.is_empty() else PackedByteArray()
  var stats={"floor":game.model.falan_floor,"area":game.model.falan_area,"seed":game.model.seed_value,"mask_sha256":bits.hex_encode().sha256_text(),"collision_shapes":game.world.map_features.find_children("*","CollisionShape3D",true,false).size(),"stairs":str(Tour.Prayer.stairs(int(stage.floor),game.model.seed_value)) if int(stage.floor) in Tour.Prayer.FLOORS else ""}
  var folder=review_root+phase+"/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
  var file=FileAccess.open(folder+stage.key+"-geometry.json",FileAccess.WRITE);file.store_string(JSON.stringify(stats,"  "));file.close()
  write_records()
 print("RUBY_REGION_REVIEW_RESULT maps=",route.stages.size()," captures=",records.size()," checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)

func landmark_sections()->Array:
 var fixed={
  "01-palace":[["arrival",39,8,39,13],["gallery",39,27,39,31],["central-hall",25,26,25,19]],
  "02-prayer-entrance":[["return-stairs",9,6,7,4],["maze-stairs",12,14,14,14]],
  "09-undersea-middle":[["suspicious-rock",34,10,34,7],["freyja-stairs",49,44,49,46],["coast-stairs",27,31,27,29]],
  "10-undersea-freyja":[["departure-stairs",10,7,10,5],["middle-stairs",20,35,18,34]],
  "11-undersea-coast":[["middle-stairs",24,15,24,13],["coast-exit",11,45,11,44]],
  "12-venoa":[["east-gate",63,46,67,46],["village-street",45,43,45,38]],
  "13-southern-lakes":[["venoa-arrival",332,480,330,480],["cave-mouth",341,496,343,497]],
  "14-sokia-coast":[["cave-arrival",237,265,240,265],["west-gate",274,291,274,294],["east-gate",297,325,294,325]],
  "15-kili":[["west-gate",60,48,58,46],["east-gate",75,76,79,76],["village-street",65,62,65,58]],
 }
 var result=[]
 var rows:Array=fixed.get(stage.key,[])
 if stage.source==null:
  var stairs_=Tour.Prayer.stairs(int(stage.floor),game.model.seed_value)
  for i in 2:
   var at:Vector2i=stairs_[i]+(Vector2i.UP if i==0 else Vector2i.LEFT)
   var toward:Vector2i=at+(Vector2i.UP if i==0 else Vector2i.LEFT)*2
   rows.append(["stair-"+str(i),at.x,at.y,toward.x,toward.y])
 for row in rows:
  result.append({"key":stage.key+"-landmark-"+row[0],"at":[row[1],row[2]],"start":[row[1],row[2]],"end":[row[3],row[4]]})
 return result

func validate_visual_supports():
 if int(stage.floor)==16508:
  var art=Tour.Indoor.RoomArt.PrayerArt
  var props=game.world.find_child("ArchivedRubyProps",true,false)
  for node in props.get_children():
   var serial=int(node.get_meta("blue_cg_serial",0))
   if serial not in [16130,16131,16132,16218,16219]:continue
   var cell:Vector2i=node.get_meta("source_cell");var pose:Transform3D=node.transform
   pose.origin-=Vector3(-75+cell.x*3,0,-75+cell.y*3)
   var actual=art.Proportions.projected_bounds(art.Proportions.mesh_points(node.mesh,pose),Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO))
   var b:Array=art.palace_data().graphics[str(serial)].bounds
   check(actual.position.distance_to(Vector2(b[0],b[1]))<.05 and actual.size.distance_to(Vector2(b[2],b[3]))<.05,"Supported furnishing retains native source projection "+str(serial))
   if serial in [16130,16131,16132]:
    check(absf((node.transform*node.mesh.get_aabb()).end.x-(-75+(cell.x+1)*3-1.515))<.01,"Picture back meets native wall face")
   else:
    var support=props.get_children().filter(func(n):return n.get_meta("blue_cg_serial",0) in [16204,16205] and n.get_meta("source_cell")==node.get_meta("ruby_native_support"))[0]
    check(absf(node.position.y-(support.transform*support.mesh.get_aabb()).end.y)<.01,"Flower pot rests on its source stool")
 elif int(stage.floor)==15004:
  var native=game.world.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.get_meta("ruby_undersea_annex",false))
  var expected=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/black_prayer/undersea-annex.json"))
  check(native.size()==expected.placements.size(),"Every omitted native guard-area prop is restored")
  for node in native:check(node.find_children("*","CollisionObject3D",true,false).is_empty(),"Guard-area scenery adds no physical owner")
