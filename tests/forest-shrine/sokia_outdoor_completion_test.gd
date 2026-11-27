extends "res://tests/forest-shrine/original_maps_test.gd"
## Existing outdoor owners, fixed source cameras, protected baseline fields.
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Sokia full-source outdoors/"
const FREYJA_REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source outdoors/"
const AREAS=["sokia_coast","sokia_desert","ghana_road","ghana_north_road"]
var before=false
var full_review=false
var foundation_review=false
var freyja_before=false
var captures=[]
var evidence={}
var baseline_cameras={}

func _initialize():
 before="--outdoor-before"in OS.get_cmdline_user_args()
 full_review="--outdoor-full"in OS.get_cmdline_user_args()
 foundation_review="--outdoor-foundation"in OS.get_cmdline_user_args()
 freyja_before="--freyja-source-before"in OS.get_cmdline_user_args()
 if not before:
  var prior=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"before-verification-rendered.json"))
  for c in prior.captures:baseline_cameras[c.name]=c
 if foundation_review:
  var prior=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"full-verification-rendered.json"))
  for c in prior.captures:baseline_cameras[c.name]=c
 create_timer(600).timeout.connect(func():printerr("SOKIA_OUTDOOR_TIMEOUT");quit(1))
 run.call_deferred()

func source_point(area:String,cell:Vector2)->Vector2:return Tour.Regions.frame(area).inverse()*(cell*3.)

func normal_view(label:String,cell:Vector2,yaw:float):
 var folder=FREYJA_REVIEW if game.model.falan_area=="south_lakes"else REVIEW
 var local=source_point(game.model.falan_area,cell)
 game.player.position=game.model.world_point(local,.15)
 if label not in ["preview-grass","preview-coast"]:
  check(game.model.terrain.contains(local.x,local.y),"Recovered dry source cell has native terrain support")
  check(absf(game.player.position.y-(Tour.Regions.land_height(cell*3.)*game.model.falan_scale+.15))<.001,"Recovered dry source cell uses the original stylized bank height")
 if label.ends_with("-clear"):
  var blocked=false
  for rect:Rect2i in game.model.terrain.Sokia.Data.BLOCKS[game.model.falan_area]:blocked=blocked or rect.has_point(Vector2i(cell))
  check(not blocked,"Clear compound camera stands on a decoder-open source cell")
  var probe=Vector3(local.x,game.model.surface_height(local.x,local.y)+1.,local.y)
  var obstacles=[]
  for key in game.model.scenery_obstacles:
   if game.model.scenery_obstacles[key].grow(.4).has_point(probe):obstacles.append(str(key))
  check(obstacles.is_empty(),"Clear compound stance preserves current native obstacle clearance "+str(obstacles))
 game.player.position.y=Tour.Regions.land_height(cell*3.)*game.model.falan_scale+.15
 game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation();game.model.hero_position=game.player.position;game.world.sync(0)
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0;game.camera_rig.camera.fov=63.
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true);game.camera_rig.set_process(false)
 var camera:Camera3D=game.camera_rig.camera;camera.reset_physics_interpolation()
 for i in 4:await process_frame
 var black_readbacks=0
 if DisplayServer.get_name()!="headless":
  var valid=false
  for attempt in 2:
   RenderingServer.force_draw();var picture=root.get_texture().get_image()
   for yy in range(0,picture.get_height(),16):
    for xx in range(0,picture.get_width(),16):
     var c=picture.get_pixel(xx,yy)
     if c.r+c.g+c.b>.02:valid=true;break
    if valid:break
   picture.save_png(folder+("before-"if before else"")+label+(""if valid else"-black-readback-"+str(attempt))+".png")
   if valid:break
   black_readbacks+=1
   for i in 8:await process_frame
  check(valid,"Fixed gameplay camera has a nonblank readback "+label)
 var info={"name":label,"black_readbacks_retained":black_readbacks,"area":game.model.falan_area,"source_cell":[cell.x,cell.y],"yaw":yaw,"eye":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"rotation":[camera.global_rotation.x,camera.global_rotation.y,camera.global_rotation.z],"fov":camera.fov,"fixed_source_bank_height":Tour.Regions.land_height(cell*3.),"source_anchor_kind":"recorded shoreline/water"if cell==Vector2(506,447)else"dry shoreline boundary; historical fixed comparison"if label=="preview-coast"else"native supported dry interior"}
 if not before and baseline_cameras.has(label):
  var old:Dictionary=baseline_cameras[label]
  var eye=Vector3(info.eye[0],info.eye[1],info.eye[2]);var old_eye=Vector3(old.eye[0],old.eye[1],old.eye[2])
  var angles=Vector3(info.rotation[0],info.rotation[1],info.rotation[2]);var old_angles=Vector3(old.rotation[0],old.rotation[1],old.rotation[2])
  check(eye.distance_to(old_eye)<.0001 and angles.distance_to(old_angles)<.0001 and info.fov==old.fov,"Same source-cell normal camera retained "+label)
 captures.append(info)

func inspect_field(area:String):
 var terrain=game.model.terrain;var field:Resource=terrain.terrain_field();var image=terrain.mask_image()
 var info={"width":terrain.width,"spacing":terrain.spacing,"mask_size":[image.get_width(),image.get_height()],"origin":[terrain.mask_origin().x,terrain.mask_origin().y],"ports":JSON.stringify(Tour.links(game.model,self))}
 if before:
  check(ResourceSaver.save(field,REVIEW+"before-field-"+area+".res")==OK,"Protected source field saved "+area)
  check(image.save_png(REVIEW+"before-mask-"+area+".png")==OK,"Protected mask saved "+area)
 else:
  var old:Resource=load(REVIEW+"before-field-"+area+".res")
  var old_mask=Image.load_from_file(ProjectSettings.globalize_path(REVIEW+"before-mask-"+area+".png"))
  check(old!=null and old.get_meta("width")==terrain.width and old.get_meta("spacing")==terrain.spacing and old_mask.get_size()==image.get_size(),"Existing owner dimensions and spacing remain exact "+area)
  var changed={};var pixels=0
  for y in image.get_height():
   for x in image.get_width():
    if image.get_pixel(x,y)!=old_mask.get_pixel(x,y):
     pixels+=1
     var at=terrain.mask_origin()+Vector2(x,y)*3.;var p=Vector2i(terrain.coordinate(at.x,at.y).round())
     changed[p.y*terrain.width+p.x]=true
  var exact=true;var changed_values={}
  for key in ["heights","bed","covered","bridges"]:
   var a=field.get_meta(key);var b=old.get_meta(key);var count=0
   for i in a.size():
    if a[i]!=b[i]:count+=1;exact=exact and changed.has(i)
   changed_values[key]=count
  check(exact,"Every native sample outside actual mask additions remains byte-exact "+area)
  var baseline=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"before-fields.json"))
  check(info.ports==baseline[area].ports and info.origin==baseline[area].origin,"All original source frames and route/port declarations remain exact "+area)
  info.changed_mask_pixels=pixels;info.changed_native_samples=changed_values
 var population=load("res://scripts/forest/forest_south_kili_population.gd")
 var route:Dictionary=population.state(game.model);var wave_route:Dictionary=game.model.waves.route_state
 check(route.size==image.get_size()and route.origin==terrain.mask_origin()and route.bits==wave_route.bits,"Source encounter setup and native Waves share the CPU mask "+area)
 var dry=0;var open=0;var blocked=0
 for y in image.get_height():
  for x in image.get_width():dry+=int(image.get_pixel(x,y).r<.5)
 for rect:Rect2i in terrain.Sokia.Data.BLOCKS[area]:blocked+=rect.get_area()
 for value in route.bits:
  for bit in 8:open+=int((value&(1<<bit))!=0)
 check(open==dry-blocked,"Encounter setup retains the exact dry/blocked source restriction "+area)
 var chart=load("res://scripts/forest/forest_falan_chart.gd").new();chart.refresh(game.model)
 check(chart.texture!=null and chart.texture.get_size()==Vector2(image.get_size())and chart.bounds==terrain.mask_bounds(),"Chart setup retains the complete CPU source extent "+area)
 info.encounter_open_cells=open;info.chart_size=[chart.texture.get_width(),chart.texture.get_height()]
 evidence[area]=info

func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-sokia-outdoor-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true
 var areas=["sokia_coast","ghana_north_road"] if foundation_review else AREAS if DisplayServer.get_name()=="headless"or full_review else["sokia_desert"]
 if foundation_review and freyja_before:areas.append("south_lakes")
 for area in areas:
  Tour.travel(game,Tour.Regions.layout(area),{"arrival":source_point(area,Vector2(506,447))if area=="sokia_desert"else Tour.Regions.entry_point(area),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 4:await physics_frame
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
  if area!="south_lakes":inspect_field(area)
  if area=="sokia_desert":
   await normal_view("preview-grass",Vector2(506,447),0.)
   await normal_view("preview-coast",Vector2(501,447),PI*.5)
   if not before:await normal_view("preview-dry-land",Vector2(501,445),0.)
  if full_review or foundation_review:
   var studies=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"full-camera-source-points.json"))
   for study in studies:
    if study.area==area and (not foundation_review or area=="ghana_north_road"):await normal_view(study.name,Vector2(study.source_cell[0],study.source_cell[1]),study.yaw)
  if foundation_review and area=="sokia_coast":
   await normal_view("full-coast-pub-clear",Vector2(259,331),-PI*.5)
   await normal_view("full-coast-mainstreet-clear",Vector2(270,321),0.)
  if foundation_review and area=="south_lakes":await normal_view("southwest-source-before",Vector2(204,420),PI*.5)
 if before and DisplayServer.get_name()=="headless":
  var baseline=FileAccess.open(REVIEW+"before-fields.json",FileAccess.WRITE);baseline.store_string(JSON.stringify(evidence,"  ")+"\n");baseline.close()
 var output=FileAccess.open(REVIEW+("before-"if before else"cliff-foundation-"if foundation_review else"full-"if full_review else"")+"verification-"+("headless"if DisplayServer.get_name()=="headless"else"rendered")+".json",FileAccess.WRITE)
 output.store_string(JSON.stringify({"checks":checks,"failures":failures,"areas":evidence,"captures":captures},"  ")+"\n");output.close()
 if foundation_review and freyja_before:
  var prior=FileAccess.open(FREYJA_REVIEW+"before-camera-"+("headless"if DisplayServer.get_name()=="headless"else"rendered")+".json",FileAccess.WRITE)
  prior.store_string(JSON.stringify(captures.filter(func(c):return c.area=="south_lakes"),"  ")+"\n");prior.close()
 print("SOKIA_OUTDOOR_RESULT ",checks," checks ",failures," failures ",captures.size()," fixed cameras")
 quit(1 if failures else 0)
