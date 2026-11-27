extends "res://tests/forest-shrine/sokia_server_binding_test.gd"
## Diagnostic raw bindings first; production mode never performs a fixture texture update.
const PRAYER_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer source route/Floor pages/"
var exact_images={}
var fresh_textures={}
func cabinet_bindings()->Array:
 var rows=[]
 for node in game.world.map_features.find_children("*","GeometryInstance3D",true,false):
  var mesh:Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh!=null else null
  if mesh==null or int(mesh.get_meta("black_prayer_source_fixture",0))not in[16511,16534,16583]:continue
  var serial=int(mesh.get_meta("black_prayer_source_fixture"));var slot=mesh.get_surface_count()-1
  var material:ShaderMaterial=node.material_override if node.material_override!=null else mesh.surface_get_material(slot)
  if material==null:continue
  var bound:Texture2D=material.get_shader_parameter("base_texture");var graphic:Dictionary=Original.Art.data().graphics[str(serial)]
  var source:String=Original.Art.ROOT+Original.Art.data().pages[int(graphic.page)]
  if not exact_images.has(source):
   var original=Image.load_from_file(ProjectSettings.globalize_path(source));original.convert(Image.FORMAT_RGBA8);exact_images[source]=original
  var expected:Image=exact_images[source];var actual=bound.get_image()
  if actual.is_compressed():actual.decompress()
  actual.convert(Image.FORMAT_RGBA8)
  var wanted=expected.get_data();var found=actual.get_data();var opaque=0;var alpha=0
  assert(wanted.size()==found.size())
  for i in range(0,wanted.size(),4):
   if wanted[i+3]!=found[i+3]:alpha+=1
   if wanted[i+3]>0 and(wanted[i]!=found[i]or wanted[i+1]!=found[i+1]or wanted[i+2]!=found[i+2]):opaque+=1
  var retained:Array=mesh.get_meta("east_cpu_arrays",[])
  var arrays:Array=retained[slot]if retained.size()>slot else mesh.surface_get_arrays(slot)
  var low=Vector2.INF;var high=-low
  for uv:Vector2 in arrays[Mesh.ARRAY_TEX_UV]:low=low.min(uv);high=high.max(uv)
  var r:Array=graphic.rect;var size_=Vector2(expected.get_size())
  rows.append({"serial":serial,"node":str(node.get_path()),"last_surface":slot,"surfaces":mesh.get_surface_count(),"graphic":graphic,"source":source,"bound_class":bound.get_class(),"bound_path":bound.resource_path,"bound_rid":bound.get_rid().get_id(),"cached_rid":Original.Art.page_texture(int(graphic.page)).get_rid().get_id(),"matches_cache":bound==Original.Art.page_texture(int(graphic.page)),"uv_min":str(low),"uv_max":str(high),"expected_rect_min":str(Vector2(r[0],r[1])/size_),"expected_rect_max":str(Vector2(r[0]+r[2],r[1]+r[3])/size_),"opaque_mismatch":opaque,"alpha_mismatch":alpha,"source_rgba_sha256":digest(wanted),"gpu_rgba_sha256":digest(found),"uniforms":material_state(material)})
 return rows
func study(label_:String):
 var capture_label=("cabinet-"if"--cabinet"in OS.get_cmdline_user_args()else"diagnostic-"if"--compare-cpu"in OS.get_cmdline_user_args()else"production-")+label_
 var camera:Camera3D=game.camera_rig.camera
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.camera_rig.set_process(false);game.camera_rig.yaw=0.;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH
 game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT;game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.impulse=0.;game.camera_rig.kick_strength=0.;game.camera_rig.kick_age=100.;camera.fov=63.
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for i in 4:await process_frame
 RenderingServer.force_draw();root.get_texture().get_image().save_png(PRAYER_OUT+capture_label+"-before-readback.png")
 var rows=[];var seen={};var overrides=[]
 for node in game.world.map_features.find_children("*","MeshInstance3D",true,false):
  if not node.get_meta("original_ground_batch",false):continue
  var material:ShaderMaterial=node.get_active_material(0);var bound:Texture2D=material.get_shader_parameter("base_texture")
  var path:String=bound.get_meta("original_source_page",bound.resource_path);var page=-1
  for i in Original.Art.data().pages.size():
   if (Original.Art.ROOT+Original.Art.data().pages[i]).simplify_path()==path.simplify_path():page=i;break
  assert(page>=0,"Actual floor texture has no source page owner")
  var source:String=Original.Art.ROOT+Original.Art.data().pages[page]
  if not exact_images.has(source):
   var image=Image.load_from_file(ProjectSettings.globalize_path(source));image.convert(Image.FORMAT_RGBA8);exact_images[source]=image
  var expected:Image=exact_images[source]
  if not seen.has(bound):
   var actual=bound.get_image()
   if actual.is_compressed():actual.decompress()
   actual.convert(Image.FORMAT_RGBA8)
   var wanted=expected.get_data();var found=actual.get_data();var opaque=0;var alpha=0
   assert(wanted.size()==found.size())
   for i in range(0,wanted.size(),4):
    if wanted[i+3]!=found[i+3]:alpha+=1
    if wanted[i+3]>0 and(wanted[i]!=found[i]or wanted[i+1]!=found[i+1]or wanted[i+2]!=found[i+2]):opaque+=1
   rows.append({"source":source,"page":page,"bound_class":bound.get_class(),"bound_path":bound.resource_path,"bound_rid":bound.get_rid().get_id(),"cached_rid":Original.Art.page_texture(page).get_rid().get_id(),"matches_cache":bound==Original.Art.page_texture(page),"material_rid":material.get_rid().get_id(),"source_rgba_sha256":digest(wanted),"gpu_rgba_sha256":digest(found),"opaque_mismatch":opaque,"alpha_mismatch":alpha,"size":str(expected.get_size()),"source_mipmaps":expected.has_mipmaps(),"uniforms":material_state(material)})
   seen[bound]=true
  if "--compare-cpu"in OS.get_cmdline_user_args():
   if not fresh_textures.has(source):fresh_textures[source]=ImageTexture.create_from_image(expected)
   var fresh:ImageTexture=fresh_textures[source];fresh.update(expected)
   var copy:ShaderMaterial=material.duplicate();copy.set_shader_parameter("base_texture",fresh)
   overrides.append([node,node.material_override]);node.material_override=copy
 if not overrides.is_empty():
  for i in 4:await process_frame
  RenderingServer.force_draw();root.get_texture().get_image().save_png(PRAYER_OUT+capture_label+"-diagnostic-cpu.png")
  for row in overrides:row[0].material_override=row[1]
 report[label_]={"bindings":rows,"capture_prefix":capture_label,"fov":camera.fov,"eye":str(camera.global_position),"rotation":str(camera.global_rotation),"fixture_cpu_comparison":"--compare-cpu"in OS.get_cmdline_user_args()}
 var variants=[]
 for serial in [3194,3200,3203,3210]:
  var key=[serial,"floor"];var old:Mesh=Original.Forms.meshes.get(key)
  if old==null:continue
  var graphic:Dictionary=Original.Art.data().graphics[str(serial)];var previous=mesh_binding(old)
  Original.Forms.meshes.erase(key)
  var fresh=Original.Forms.mesh(serial,"floor",graphic,Original.Art.page_texture(int(graphic.page)));var current=mesh_binding(fresh)
  variants.append({"serial":serial,"graphic":graphic.duplicate(true),"warmed":previous,"fresh":current,"uv_exact":previous.uv==current.uv})
  Original.Forms.meshes[key]=old
 report[label_].warmed_floor_comparison=variants
 if "--cabinet"in OS.get_cmdline_user_args():report[label_].cabinet_bindings=cabinet_bindings()
func run():
 root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PRAYER_OUT))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-prayer-pages-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.tuning.invincible=true
 var visits=[5011,3354,5011,3354];var counts={}
 for id in visits:
  var old=weakref(game.world.map_features);var cell=Vector2i(8,7)if id==5011 else Vector2i(10,10)
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Original.source_point(id,cell),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 5:await process_frame
  assert(old.get_ref()==null,"Previous map scene must retire")
  counts[id]=int(counts.get(id,0))+1;await study(str(id)+("-first"if counts[id]==1 else"-return"))
 var file=FileAccess.open(PRAYER_OUT+("cabinet-bindings"if"--cabinet"in OS.get_cmdline_user_args()else"diagnostic"if"--compare-cpu"in OS.get_cmdline_user_args()else"production")+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("BLACK_PRAYER_FLOOR_PAGES_COMPLETE visits=",visits.size()," diagnostic_cpu=","--compare-cpu"in OS.get_cmdline_user_args())
 fresh_textures.clear();exact_images.clear();game.queue_free()
 for i in 3:await process_frame
 quit(0)
