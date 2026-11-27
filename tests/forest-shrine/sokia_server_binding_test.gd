extends SceneTree
## Diagnostic only: exact warmed mesh, atlas context and batched material for failed5005.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server fixed maps/"
const SERIALS=[7668,7642,7670,7673,7639,7753]
var game
var report={}
var probe_ui:CanvasLayer
var probe_page_textures={}
func digest(bytes_:PackedByteArray)->String:
 var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes_)
 return context.finish().hex_encode()
func all_page_probe(label_:String):
 var previous=[];var rows=[];var textures=probe_page_textures
 for node in game.world.map_features.find_children("*","MeshInstance3D",true,false):
  if not node.get_meta("original_ground_batch",false):continue
  var material:ShaderMaterial=node.get_active_material(0);var imported:Texture2D=material.get_shader_parameter("base_texture")
  var page=imported.resource_path.trim_prefix(Original.Art.ROOT)
  var path=Original.Art.ROOT+"sokia_server/cpu-pages/"+page.replace("/","-").trim_suffix(".png")+".res"
  if not FileAccess.file_exists(path):continue
  if not textures.has(imported):
   var exact:Image=load(path);var raw=exact.get_data();var gpu=imported.get_image();gpu.convert(Image.FORMAT_RGBA8)
   var actual=gpu.get_data();var alpha_mismatch=0;var opaque_mismatch=0
   for i in range(0,raw.size(),4):
    if actual[i+3]!=raw[i+3]:alpha_mismatch+=1
    if raw[i+3]>0 and (actual[i]!=raw[i]or actual[i+1]!=raw[i+1]or actual[i+2]!=raw[i+2]):opaque_mismatch+=1
   gpu.save_png(OUT+label_+"-imported-"+page.replace("/","-"))
   var cpu=ImageTexture.create_from_image(exact);var readback=cpu.get_image();readback.convert(Image.FORMAT_RGBA8)
   rows.append({"page":page,"source_rgba_sha256":digest(raw),"imported_gpu_sha256":digest(actual),"imported_alpha_mismatch":alpha_mismatch,"imported_opaque_mismatch":opaque_mismatch,"cpu_upload_exact":readback.get_data()==raw,"cpu_identity":cpu.get_instance_id(),"reused":false})
   textures[imported]=cpu
  else:rows.append({"page":page,"cpu_identity":textures[imported].get_instance_id(),"reused":true})
  var override_:ShaderMaterial=material.duplicate();override_.set_shader_parameter("base_texture",textures[imported])
  previous.append([node,node.material_override]);node.material_override=override_
 for i in 4:await process_frame
 RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+label_+"-all-cpu-pages.png")
 for row in previous:row[0].material_override=row[1]
 report[label_+"_all_cpu_pages"]=rows
func production_page_probe(label_:String):
 var rows=[];var before={};var late="--late-cache-update"in OS.get_cmdline_user_args()
 var bindings=[]
 for node in game.world.map_features.find_children("*","MeshInstance3D",true,false):
  if not node.get_meta("original_ground_batch",false):continue
  var material:ShaderMaterial=node.get_active_material(0);var bound:Texture2D=material.get_shader_parameter("base_texture")
  var path:String=bound.get_meta("original_source_page",bound.resource_path);var page=Original.Art.data().pages.find(path.trim_prefix(Original.Art.ROOT))
  var cached:Texture2D=Original.Art.page_texture(page)if page>=0 else null
  bindings.append({"node":str(node.get_path()),"material_identity":material.get_instance_id(),"material_rid":material.get_rid().get_id(),"bound_class":bound.get_class(),"bound_path":bound.resource_path,"source_page":path,"page":page,"bound_identity":bound.get_instance_id(),"bound_rid":bound.get_rid().get_id(),"cached_identity":cached.get_instance_id()if cached!=null else 0,"cached_rid":cached.get_rid().get_id()if cached!=null else 0,"matches_cached":bound==cached})
 report[label_+"_production_bindings"]=bindings
 if late and not bindings.all(func(row):return row.matches_cached):
  report[label_+"_late_update_skipped"]="Actual floor binding differs from page cache"
  late=false
 for page in Original.Art.page_images:
  var image:Image=Original.Art.page_images[page];var path:String=Original.Art.data().pages[page]
  if digest(image.get_data())!=Original.Art.cpu_page_records[path].rgba_sha256:
   report[label_+"_late_update_skipped"]="Loaded CPU Image bytes differ from prepared source hash: "+path
   late=false
 if late:
  for page in Original.Art.page_images:
   var image:Image=Original.Art.page_images[page];var texture:ImageTexture=Original.Art.page_texture(page)
   var gpu=texture.get_image();gpu.convert(Image.FORMAT_RGBA8);before[page]=gpu.get_data()==image.get_data()
   texture.update(image)
  for i in 4:await process_frame
  RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+label_+"-late-before-texture-readback.png")
 for page in Original.Art.page_images:
  var expected:Image=Original.Art.page_images[page];var actual=Original.Art.page_texture(page).get_image();actual.convert(Image.FORMAT_RGBA8)
  var wanted=expected.get_data();var found=actual.get_data();var alpha_mismatch=0;var opaque_mismatch=0
  for i in range(0,wanted.size(),4):
   if wanted[i+3]!=found[i+3]:alpha_mismatch+=1
   if wanted[i+3]>0 and(wanted[i]!=found[i]or wanted[i+1]!=found[i+1]or wanted[i+2]!=found[i+2]):opaque_mismatch+=1
  rows.append({"page":Original.Art.data().pages[page],"rgba_exact":wanted==found,"alpha_mismatch":alpha_mismatch,"opaque_mismatch":opaque_mismatch,"expected_sha256":digest(wanted),"gpu_sha256":digest(found),"source_image_class":expected.get_class(),"source_image_path":expected.resource_path,"source_image_format":expected.get_format(),"source_image_size":var_to_str(expected.get_size()),"source_image_mipmaps":expected.has_mipmaps(),"source_image_identity":expected.get_instance_id(),"texture_identity":Original.Art.page_texture(page).get_instance_id(),"texture_rid":Original.Art.page_texture(page).get_rid().get_id(),"late_update":late,"exact_before_update":before.get(page,null)})
 report[label_+"_production_pages"]=rows
 RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+label_+"-production-pages.png")
func _initialize():run.call_deferred()
func mesh_binding(mesh:Mesh)->Dictionary:
 if mesh==null:return {"cached":false}
 var arrays:Variant=mesh.get_meta("source_surface_arrays",null)
 if not arrays is Array:arrays=mesh.surface_get_arrays(0)
 var material:ShaderMaterial=mesh.surface_get_material(0);var texture:Texture2D=material.get_shader_parameter("base_texture")
 return {"cached":true,"mesh":mesh.get_instance_id(),"vertices":arrays[Mesh.ARRAY_VERTEX].size(),
  "indices":arrays[Mesh.ARRAY_INDEX].size()if arrays[Mesh.ARRAY_INDEX]!=null else 0,
  "uv":var_to_str(arrays[Mesh.ARRAY_TEX_UV]),"texture":texture.resource_path,"texture_id":texture.get_instance_id(),
  "size":var_to_str(texture.get_size()),"atlas_tile_pixels":material.get_shader_parameter("atlas_tile_pixels"),"original_palette":material.get_shader_parameter("original_palette"),
  "uv_scale":var_to_str(material.get_shader_parameter("uv_scale")),"uv_offset":var_to_str(material.get_shader_parameter("uv_offset")),"archive_triplanar":material.get_shader_parameter("archive_triplanar"),"falan_source_projection":material.get_shader_parameter("falan_source_projection")}
func snapshot(label_:String):
 var rows=[]
 for serial in SERIALS:
  var g:Dictionary=Original.Art.data().graphics[str(serial)];var key=[serial,"floor"]
  rows.append({"serial":serial,"graphic":g.duplicate(true),"atlas_path":Original.Art.ROOT+Original.Art.data().pages[int(g.page)],"binding":mesh_binding(Original.Forms.meshes.get(key))})
 report[label_]=rows
func material_state(material:ShaderMaterial)->Dictionary:
 var result={"shader":material.shader.resource_path,"shader_sha256":material.shader.code.sha256_text()}
 for uniform in material.shader.get_shader_uniform_list():
  var value:Variant=material.get_shader_parameter(uniform.name)
  result[uniform.name]={"path":value.resource_path,"id":value.get_instance_id()}if value is Texture2D else var_to_str(value)
 return result
func gpu_probe(label_:String):
 var camera=game.camera_rig.camera;var id:int=game.model.falan_floor
 game.player.position=game.model.world_point(Original.source_point(id,Vector2i(15,16)if id==5005 else Vector2i(8,7)),.15)
 game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation();game.model.hero_position=game.player.position
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.camera_rig.set_process(false);game.camera_rig.yaw=0.;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH
 game.camera_rig.distance=12.;game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 camera.fov=63.;game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for i in 4:await process_frame
 RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+label_+"-baseline-before-probe.png")
 if "--production-page-cache"in OS.get_cmdline_user_args()or"--late-cache-update"in OS.get_cmdline_user_args():
  await production_page_probe(label_)
  return
 if "--all-pages-only"in OS.get_cmdline_user_args():
  await all_page_probe(label_)
  return
 if probe_ui!=null:probe_ui.queue_free();await process_frame
 probe_ui=CanvasLayer.new();probe_ui.layer=127;game.add_child(probe_ui)
 var texture:Texture2D=load("res://assets/maps/original_crossgate/atlas-1.png")
 var actual=texture.get_image()
 if actual.is_compressed():actual.decompress()
 actual.save_png(OUT+label_+"-gpu-atlas.png")
 var raw=Image.load_from_file("res://assets/maps/original_crossgate/atlas-1.png")
 raw.convert(Image.FORMAT_RGBA8)
 var full_texture=ImageTexture.create_from_image(raw)
 var full_readback=full_texture.get_image();full_readback.convert(Image.FORMAT_RGBA8)
 report[label_+"_full_page_upload"]={"size":var_to_str(full_texture.get_size()),"rgba_exact":full_readback.get_data()==raw.get_data()}
 full_readback.save_png(OUT+label_+"-cpu-page-readback.png")
 var region=Rect2(1566,512,64,47);var atlas=AtlasTexture.new();atlas.atlas=texture;atlas.region=region
 for i in 2:
  var panel=TextureRect.new();panel.texture=atlas if i==0 else ImageTexture.create_from_image(raw.get_region(Rect2i(region)))
  panel.position=Vector2(16+i*280,16);panel.size=Vector2(256,188);panel.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  panel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;probe_ui.add_child(panel)
  var text_=Label.new();text_.text="GPU imported crop"if i==0 else"Fresh source crop";text_.position=Vector2(16+i*280,208);probe_ui.add_child(text_)
 var nodes=[];var previous=[];var original_materials=[];var states=[]
 for node in game.world.map_features.find_children("*","MeshInstance3D",true,false):
  if not node.get_meta("original_ground_batch",false):continue
  var material:ShaderMaterial=node.get_active_material(0);var paint:Texture2D=material.get_shader_parameter("base_texture")
  if paint!=texture:continue
  nodes.append(node);previous.append(node.material_override);original_materials.append(material);states.append(material_state(material))
  var arrays=node.mesh.surface_get_arrays(0)
  report[label_+"_committed"]={"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"first_uv":var_to_str(arrays[Mesh.ARRAY_TEX_UV].slice(0,18))}
 report[label_+"_materials"]=states
 for mode in ["original","unlit","duplicated-original","explicit-defaults","cpu-page-unlit","cpu-page-painterly"]:
  for i in nodes.size():
   if mode=="original":nodes[i].material_override=previous[i]
   elif mode in ["unlit","cpu-page-unlit"]:
    var material=StandardMaterial3D.new();material.albedo_texture=full_texture if mode=="cpu-page-unlit"else texture;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    nodes[i].material_override=material
   else:
    var material:ShaderMaterial=original_materials[i].duplicate()
    if mode=="cpu-page-painterly":material.set_shader_parameter("base_texture",full_texture)
    if mode=="explicit-defaults":
     material.set_shader_parameter("uv_scale",Vector2.ONE);material.set_shader_parameter("uv_offset",Vector2.ZERO)
     for key in ["archive_triplanar","falan_source_projection","armor_source_views","architecture_roof"]:material.set_shader_parameter(key,false)
     material.set_shader_parameter("atlas_tile_pixels",0.)
    nodes[i].material_override=material
  for i in 4:await process_frame
  RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+label_+"-"+mode+".png")
 for i in nodes.size():nodes[i].material_override=previous[i]
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-server-binding-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 snapshot("before_server_load");Original.Art.load_sokia_server();snapshot("after_server_load")
 Original.Art.data().maps[Original.path_for(5005)].sokia_visual_only=false
 Tour.travel(game,Tour.Indoor.layout(5005),{"arrival":Original.source_point(5005,Vector2i(17,14)),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await process_frame
 snapshot("after_map_build")
 if DisplayServer.get_name()!="headless":
  var all_pages="--all-pages-only"in OS.get_cmdline_user_args();var production="--production-page-cache"in OS.get_cmdline_user_args();var late="--late-cache-update"in OS.get_cmdline_user_args()
  await gpu_probe("5005-late-first"if late else"5005-retained-first"if production else"5005-allpages-first"if all_pages else"5005-first")
  Original.Art.data().maps[Original.path_for(5006)].sokia_visual_only=false
  Tour.travel(game,Tour.Indoor.layout(5006),{"arrival":Original.source_point(5006,Vector2i(8,7)),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 4:await process_frame
  Tour.travel(game,Tour.Indoor.layout(5005),{"arrival":Original.source_point(5005,Vector2i(15,16)),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 4:await process_frame
  await gpu_probe("5005-late-return"if late else"5005-retained-return"if production else"5005-allpages-return"if all_pages else"5005-return")
 report.fresh=[]
 var floor_serials=SERIALS.duplicate();var state_=Original.state(5005)
 for i in state_.size.x*state_.size.y:
  var serial:int=state_.raw.decode_u16(20+i*2)
  if serial!=100 and serial>0 and serial not in floor_serials:floor_serials.append(serial)
 for serial in floor_serials:
  var key=[serial,"floor"];var old:Mesh=Original.Forms.meshes.get(key);Original.Forms.meshes.erase(key)
  var g:Dictionary=Original.Art.data().graphics[str(serial)];var texture:Texture2D=load(Original.Art.ROOT+Original.Art.data().pages[int(g.page)])
  var fresh:Mesh=Original.Forms.mesh(serial,"floor",g,texture)
  var old_binding=mesh_binding(old);var new_binding=mesh_binding(fresh)
  report.fresh.append({"serial":serial,"old":old_binding,"fresh":new_binding,"cached_uv_exact":old==null or old_binding.uv==new_binding.uv})
  Original.Forms.meshes.erase(key)
  if old!=null:Original.Forms.meshes[key]=old
 report.batches=[]
 for node in game.world.map_features.find_children("*","MeshInstance3D",true,false):
  if not node.get_meta("original_ground_batch",false):continue
  var material:ShaderMaterial=node.get_active_material(0);var texture:Texture2D=material.get_shader_parameter("base_texture")
  report.batches.append({"texture":texture.resource_path,"id":texture.get_instance_id(),"atlas_tile_pixels":material.get_shader_parameter("atlas_tile_pixels"),"vertices":node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()})
 var file=FileAccess.open(OUT+"binding-diagnostic.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
 print("SOKIA_SERVER_BINDING_DIAGNOSTIC_COMPLETE")
 game.queue_free();await process_frame;quit(0)
