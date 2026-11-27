extends "res://tests/forest-shrine/original_maps_test.gd"
## Fixed normal-camera evidence for the source-100 near-city surface notch.
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja union audit/Residual alpha audit/"
var captures=[]
var evidence={}
var before=false

func _initialize():
 create_timer(480).timeout.connect(func():printerr("FREYJA_RESIDUAL_TIMEOUT");quit(1))
 before="--freyja-gap-before" in OS.get_cmdline_user_args()
 run.call_deferred()

func point(area:String,cell:Vector2)->Vector2:return Tour.Regions.frame(area).inverse()*(cell*3.)

func repair_checks(area:String,terrain,field:Resource,old:Resource):
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/freyja_residual/provenance.json"))
 var changed={}
 for cell in data.areas[area].repaired_cells:
  var at=point(area,Vector2(cell[0],cell[1]));var index=Vector2i(terrain.coordinate(at.x,at.y).round())
  changed[index.y*terrain.width+index.x]=true
 var exact=true;var changed_values={};var unexpected=[]
 for key in ["heights","bed","covered","bridges"]:
  var actual=field.get_meta(key);var previous=old.get_meta(key);var count=0
  for i in actual.size():
   if actual[i]!=previous[i]:
    count+=1
    if not changed.has(i):
     exact=false
     if unexpected.size()<12:unexpected.append({"key":key,"index":i,"cell":[i%terrain.width,i/terrain.width],"old":previous[i],"actual":actual[i]})
  changed_values[key]=count
 check(exact,"Every height/coverage/bridge sample outside prepared source cells stays byte-exact "+area)
 evidence[area].changed_native_samples=changed_values
 evidence[area].unexpected_native_samples=unexpected
 var base=Image.load_from_file(ProjectSettings.globalize_path(REVIEW+"fresh/"+area+"-mask.png"))
 var actual=terrain.mask_texture().get_image();var protected=true;var full_alpha=true;var pixel_errors=[]
 var pixels={}
 for cell in data.areas[area].repaired_cells:
  var at=point(area,Vector2(cell[0],cell[1]));var p=Vector2i(((at-terrain.mask_origin())/3.).round());pixels[p]=true
  full_alpha=full_alpha and actual.get_pixelv(p).a>.99
 for y in actual.get_height():
  for x in actual.get_width():
   if not pixels.has(Vector2i(x,y)):
    var actual_pixel=actual.get_pixel(x,y);var old_pixel=base.get_pixel(x,y)
    if not actual_pixel.is_equal_approx(old_pixel):
     protected=false
     if pixel_errors.size()<12:pixel_errors.append([x,y,str(actual.get_pixel(x,y)),str(base.get_pixel(x,y))])
 check(protected and full_alpha,"Prepared mask restores source cells and preserves every other pixel "+area)
 var city:MeshInstance3D=game.world.find_child("CompleteFalanGround",true,false)
 check(city!=null,"Existing adjoining-city renderer remains the city owner "+area)
 var materials=[]
 for node in game.world.find_children("*","MeshInstance3D",true,false):
  var mat=node.material_override
  if mat is ShaderMaterial and mat.get_shader_parameter("adjoining_city_bounds") is Vector4 and mat.get_shader_parameter("adjoining_city_bounds").z>0:
   materials.append(mat)
 var active=0;var city_active=false
 for mat:ShaderMaterial in materials:
  if mat.get_shader_parameter("use_adjoining_source_repair")==true:
   active+=1
   if mat.get_shader_parameter("adjoining_city_layer")==true:city_active=true
 check(active>=4 and city_active,"The same prepared exception clips both city fill/water and exterior layers "+area)
 var art=game.world.find_child("FreyjaResidualSourceBanks",true,false);var anchors=[];var poses_exact=true;var instances=0;var errors=[]
 if art!=null:
  for part in art.get_children():
   var rows:Array=part.get_meta("source_anchors");instances+=part.multimesh.instance_count
   for i in rows.size():
    var pose:Transform3D=part.get_meta("prepared_poses")[i]if DisplayServer.get_name()=="headless"else part.multimesh.get_instance_transform(i)
    var source_point:Vector2=Tour.Regions.frame(area)*Vector2(pose.origin.x,pose.origin.z)/3.
    var distance=source_point.distance_to(Vector2(rows[i][0],rows[i][1]));poses_exact=poses_exact and distance<.0001
    if distance>=.0001:errors.append([rows[i],str(source_point),distance])
    anchors.append(rows[i])
 check(art!=null and instances==data.areas[area].shores.size() and poses_exact,("Prepared"if DisplayServer.get_name()=="headless"else"Actual rendered")+"original shore stations retain their exact source anchors "+area)
 check(art!=null and art.find_children("*","CollisionObject3D",true,false).is_empty(),"Recovered shore presentation introduces no additional collider "+area)
 evidence[area].actual_shore_instances=instances
 evidence[area].shore_errors=errors
 evidence[area].bank_owner_path=str(art.get_path())if art!=null else"absent"
 evidence[area].mask_errors=pixel_errors
 var helper=load("res://scripts/forest/forest_freyja_residual_art.gd")
 var blocks=helper.collisions(game.model);var blocked_source={};var rectangles_exact=true
 for row in blocks:
  var box:AABB=row[2]
  var source_rect:Rect2=Tour.Regions.frame(area)*Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
  var wanted:Array=row[3]
  rectangles_exact=rectangles_exact and source_rect.is_equal_approx(Rect2(Vector2(wanted[0],wanted[1])*3.-Vector2.ONE*1.5,Vector2(wanted[2],wanted[3])*3.))
  for y in range(wanted[1],wanted[1]+wanted[3]):
   for x in range(wanted[0],wanted[0]+wanted[2]):blocked_source[Vector2i(x,y)]=true
 var gap_source=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"source-gaps.json"));var no_open_blocked=true
 for cell in gap_source.records:no_open_blocked=no_open_blocked and not blocked_source.has(Vector2i(cell.cell[0],cell.cell[1]))
 check(rectangles_exact and blocked_source.size()==data.areas[area].blocked_cells.size()and no_open_blocked,"Merged source-closed dry/cache100 blocks preserve exact cells and never cover any audited source-open point "+area)
 var bodies=0
 for body in game.world.find_children("*","StaticBody3D",true,false):bodies+=int(body.get_meta("freyja_source_collision",false))
 check(bodies==blocks.size(),"Actual static bodies reuse the existing source-block owner for every prepared rectangle "+area)
 evidence[area].source_blocked_cells=blocked_source.size();evidence[area].source_block_rectangles=blocks.size();evidence[area].actual_source_block_bodies=bodies
 var reused=ShaderMaterial.new();reused.shader=preload("res://scripts/forest/wind_meadow_ground.gdshader")
 helper.clipping(reused,terrain,true)
 var other=terrain.get_script().new();other.variant="south_gate"
 helper.clipping(reused,other,true)
 check(reused.get_shader_parameter("use_adjoining_source_repair")==false and reused.get_shader_parameter("adjoining_source_bounds")==Vector4.ZERO and reused.get_shader_parameter("adjoining_source_repair")==null,"Reused material clears exception texture/bounds on travel to an unaffected map "+area)

func normal_capture(area:String,label:String,cell:Vector2,yaw:float=0.):
 game.player.position=game.model.world_point(point(area,cell),.15)
 # Fixed source bank elevation prevents the failed before surface moving the camera.
 game.player.position.y=6.*game.model.falan_scale+.15
 game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
 game.model.hero_position=game.player.position;game.world.sync(0)
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.camera.fov=63.;game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true);game.camera_rig.set_process(false)
 var camera:Camera3D=game.camera_rig.camera;camera.reset_physics_interpolation()
 var kind="normal_gameplay_camera"
 if not before:
  var previous=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"before-verification-rendered.json"))
  for old in previous.captures:
   if old.name!=area+"-"+label:continue
   var eye=Vector3(old.eye[0],old.eye[1],old.eye[2])
   if camera.global_position.distance_to(eye)>.0001:
    for i in 4:await process_frame
    if DisplayServer.get_name()!="headless":RenderingServer.force_draw();root.get_texture().get_image().save_png(REVIEW+area+"-"+label+"-native-camera.png")
    captures.append({"name":area+"-"+label+"-native-camera","area":area,"source_cell":[cell.x,cell.y],"kind":"normal_gameplay_camera","eye":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"rotation":[camera.global_rotation.x,camera.global_rotation.y,camera.global_rotation.z],"fov":camera.fov})
    camera.global_position=eye;camera.global_rotation=Vector3(old.rotation[0],old.rotation[1],old.rotation[2]);camera.reset_physics_interpolation()
    kind="controlled_old_approach_after_source_collision_repair"
   break
 for i in 4:await process_frame
 if DisplayServer.get_name()!="headless":
  RenderingServer.force_draw();root.get_texture().get_image().save_png(REVIEW+("before-"if before else"")+area+"-"+label+".png")
 captures.append({"name":area+"-"+label,"area":area,"source_cell":[cell.x,cell.y],"kind":kind,"fixed_source_bank_height":6.,"eye":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"rotation":[camera.global_rotation.x,camera.global_rotation.y,camera.global_rotation.z],"fov":camera.fov})

func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-freyja-residual-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true
 var source=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"source-gaps.json"))
 for area in ["freyja","east_gate"]:
  Tour.travel(game,Tour.Regions.layout(area),{"arrival":point(area,Vector2(440,80)),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 4:await physics_frame
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting();game.army_runtime.refresh_navigation(0)
  var terrain=game.model.terrain;var mask=terrain.mask_texture().get_image();var bounds:Rect2=terrain.mask_bounds()
  var source_samples=[];var reachable=0;var terrain_clear=0
  for row in source.records:
   var at=point(area,Vector2(row.cell[0],row.cell[1]));var pixel=Vector2i(((at-terrain.mask_origin())/3.).round())
   var color=mask.get_pixelv(pixel);var world=game.model.world_point(at)
   var native=game.army_runtime.native.can_reach(world,world,.1)
   var clear=terrain.disk_clear(Vector3(at.x,terrain.height(at.x,at.y),at.y),.1)
   terrain_clear+=int(clear)
   reachable+=int(native)
   source_samples.append({"cell":row.cell,"rgba":[roundi(color.r*255),roundi(color.g*255),roundi(color.b*255),roundi(color.a*255)],"height":terrain.height(at.x,at.y),"terrain_disk_clear":clear,"native_self_reachable":native})
  evidence[area]={"mask_size":[mask.get_width(),mask.get_height()],"native_width":terrain.width,"spacing":terrain.spacing,"origin":[terrain.mask_origin().x,terrain.mask_origin().y],"source_samples":source_samples,"native_self_reachable":reachable,"terrain_disk_clear":terrain_clear,"ports":JSON.stringify(Tour.links(game.model,self)),"enemy_restriction":"Existing Goemon FalanFrontier.ENEMY_EDGE220 adaptation is preserved; source encounter1000/1006/1008 reconciliation remains required. This is not evidence of original safety."}
  check(reachable==0,"Existing Goemon enemy restriction remains unchanged for all1252source cells "+area)
  var field:Resource=terrain.terrain_field();var save_path=REVIEW+"before-field-"+area+".res"
  if before:check(ResourceSaver.save(field,save_path)==OK,"Before field stored for exact non-repair preservation "+area)
  else:
   var old:Resource=load(save_path)
   check(old!=null and old.get_meta("width")==field.get_meta("width") and old.get_meta("spacing")==field.get_meta("spacing"),"Existing native field dimensions and spacing stay exact "+area)
   if old!=null:repair_checks(area,terrain,field,old)
   var previous=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"before-verification-rendered.json"))
   check(evidence[area].ports==previous.evidence[area].ports,"Source route/port declarations remain unchanged "+area)
  check(mask.get_size()==Vector2i(321,229)if area=="freyja"else mask.get_size()==Vector2i(387,459),"Mask dimensions stay unchanged "+area)
  check(bounds.has_point(point(area,Vector2(437,47))),"Source notch remains in the existing owner envelope "+area)
  await normal_capture(area,"north-grass",Vector2(437,47))
  await normal_capture(area,"middle-shore",Vector2(434,83))
  if not before:await normal_capture(area,"middle-shore-facing-coast",Vector2(434,83),PI)
  if not before:
   var view_at=point(area,Vector2(426,83))
   check(terrain.disk_clear(Vector3(view_at.x,terrain.height(view_at.x,view_at.y),view_at.y),.1),"Additional normal view stands on recovered source-open physical ground "+area)
   await normal_capture(area,"middle-shore-reachable",Vector2(426,83),0. if area=="freyja"else PI)
  await normal_capture(area,"city-edge",Vector2(418,120))
 if not before:
  var previous=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"before-verification-rendered.json"))
  for b in previous.captures:
   var a:Dictionary=captures.filter(func(row):return row.name==b.name)[0]
   var same=a.name==b.name and a.source_cell==b.source_cell and a.fov==b.fov
   for axis in 3:same=same and absf(a.eye[axis]-b.eye[axis])<.0001 and absf(a.rotation[axis]-b.rotation[axis])<.0001
   check(same,"Same source cell/eye/rotation/FOV before and after "+a.name)
 var result={"checks":checks,"failures":failures,"before":before,"evidence":evidence,"captures":captures,"qualification":"Source/mask/native samples and fixed gameplay-camera evidence; visual judgment is separate."}
 var file=FileAccess.open(REVIEW+("before-"if before else"")+"verification-"+("headless"if DisplayServer.get_name()=="headless"else"rendered")+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
 print("FREYJA_RESIDUAL_RESULT ",checks," checks ",failures," failures ",captures.size()," fixed cameras")
 quit(1 if failures else 0)
