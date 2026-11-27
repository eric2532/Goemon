extends "res://tests/forest-shrine/freyja_trial_review.gd"
## Texture-only comparison; original art, layout, geometry and native support stay intact.
const HALL_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Trial caves/Hall source wall paint/"
const WALLS=[17087,17088,17089]
var wall_report={"cases":[],"goal_complete":false,"production_changed":false}
func _initialize():
 create_timer(600).timeout.connect(func():printerr("TRIAL_HALL_PAINT_TIMEOUT");quit(1))
 run.call_deferred()
func clear_wall_cache():
 for key in Original.Forms.meshes.keys():
  if key is Array and key[0]in WALLS:Original.Forms.meshes.erase(key)
func wall_shapes()->Dictionary:
 var result={}
 for key in Original.Forms.meshes:
  if key is Array and key[0]in WALLS:
   var mesh:Mesh=Original.Forms.meshes[key]
   result[str(key)]={"bounds":str(mesh.get_aabb()),"surfaces":mesh.get_surface_count()}
 return result
func take_view(label_:String,cell:Vector2i,yaw:float=0.,screen_offset:float=0.):
 await super.take_view(label_,cell,yaw,screen_offset)
 if DisplayServer.get_name()=="headless":return
 var target=HALL_OUT+label_+".png"
 check(DirAccess.rename_absolute(ProjectSettings.globalize_path(TRIAL_OUT+label_+".png"),ProjectSettings.globalize_path(target))==OK,"Hall comparison saved "+label_)
 server_report.captures[-1].image=target
func run():
 var published_only="--published-only"in OS.get_cmdline_user_args()
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-hall-paint-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.player.set_auto_attack(false);freeze()
 var saved=JSON.stringify(get_meta("falan_venture"));Original.Art.load_freyja_trial()
 var source:Dictionary=Original.Art.data().maps[Original.path_for(11011)];var flag=source.sokia_visual_only;source.sokia_visual_only=false
 var original_texture=Original.Art.solid_texture(11);var shape_before={};var native_before=[]
 for case_ in (["published"]if published_only else["baseline","original-opaque-rgb"]):
  if case_=="original-opaque-rgb":
   var image=Image.load_from_file(HALL_OUT+"opaque-source-restored.png")
   check(image!=null and image.get_size()==Vector2i(2048,2048),"Scoped CPU candidate keeps the original atlas dimensions")
   Original.Art.solid_textures[11]=ImageTexture.create_from_image(image)
  clear_wall_cache();await visit(11011)
  var shapes=wall_shapes();var support=[]
  for cell in [Vector2i(25,25),Vector2i(22,15),Vector2i(24,13)]:
   var at=game.model.world_point(Original.source_point(11011,cell),.15)
   support.append(game.army_runtime.native.can_reach(at,at,.4))
  if case_!="original-opaque-rgb":shape_before=shapes;native_before=support
  else:
   check(shapes==shape_before,"Only wall texture changes; source wall bounds/surface counts stay exact")
   check(support==native_before,"Native support at all three fixed original stations stays exact")
  check(shapes.size()==3,"All three original wall serials retain their existing solid owner")
  await take_view(case_+"-hall",Vector2i(25,25),0.)
  await take_view(case_+"-5047",Vector2i(22,15),0.,.12)
  await take_view(case_+"-6073",Vector2i(24,13),0.,.12)
  wall_report.cases.append({"name":case_,"shapes":shapes,"native_support":support})
 Original.Art.solid_textures[11]=original_texture;clear_wall_cache();source.sokia_visual_only=flag
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Hall comparison preserves user adventure")
 wall_report.checks=checks;wall_report.failures=errors;wall_report.captures=server_report.captures
 wall_report.qualification="Current canonical imported texture; no fixture paint override."if published_only else"Candidate CPU texture changes only7541alteredopaque source pixels in3wallrectangles. All other atlas pixels remain exact; no production publication, geometry change or visual acceptance implied."
 var file=FileAccess.open(HALL_OUT+("review-published.json"if published_only else"review.json"),FileAccess.WRITE);file.store_string(JSON.stringify(wall_report,"  ")+"\n");file.close()
 print("TRIAL_HALL_PAINT_RESULT checks=",checks," failures=",errors," captures=",server_report.captures.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
