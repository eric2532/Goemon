extends "res://tests/forest-shrine/elsa_map_review.gd"
## Check production CPU pages, or diagnose a frozen view with a late fresh load.
var fresh_pages:Array[Texture2D]=[]
var cpu_candidate=false
var review_initialized=false

func _initialize():
 cpu_candidate="--cpu-pages" in OS.get_cmdline_user_args()
 capture_output=OUTPUT+("cpu-page-review/" if cpu_candidate else "resident-all-pages-review/")
 super._initialize()
 if cpu_candidate:
  var art=Original.Art
  art.load_elsa()
  var pages:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(art.ROOT+"elsa/cpu-pages/provenance.json"))
  assert(pages.size()==4,"Prepare the four documented Elsa trial pages before this review")
  for path in pages:
   assert(path in ["elsa/atlas-40.png","elsa/atlas-41.png","elsa/atlas-42.png","elsa/atlas-43.png"] and not art.page_textures.has(art.data().pages.find(path)),"Candidate must initialize before its first map texture load")
 review_initialized=true

func run():
 if not review_initialized:
  printerr("ELSA_RESIDENT_REVIEW_INIT_FAILED");quit(1);return
 await super.run()

func probe_scene_atlas(label:String):
 if cpu_candidate:
  review_cpu_pages(label)
  return
 await super.probe_scene_atlas(label)
 var folder=capture_output+"resident-rebind/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.get_texture().get_image().save_png(folder+label+"-before.png")
 var pages={}
 for node in game.world.find_children("*","MeshInstance3D",true,false):
  if node.mesh==null or not node.is_visible_in_tree() or node.get_world_3d()!=game.camera_rig.camera.get_world_3d():continue
  for surface in node.mesh.get_surface_count():
   var material=node.get_active_material(surface)
   if not material is ShaderMaterial:continue
   var texture=material.get_shader_parameter("base_texture")
   if not texture is Texture2D or not texture.resource_path.begins_with("res://assets/maps/original_crossgate/elsa/atlas-"):continue
   var path:String=texture.resource_path
   if not pages.has(path):pages[path]={"resident":texture,"materials":{}}
   pages[path].materials[material.get_instance_id()]=material
 var records=[]
 for path in pages:
  var original=Image.load_from_file(path);var resident_image:Image=pages[path].resident.get_image()
  var fresh:Texture2D=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE);fresh_pages.append(fresh)
  var image=fresh.get_image();var differences=visible_differences(original,image)
  check(differences==0,"Fresh page retains all alpha and all visible original RGB: "+path)
  var resident_differences=visible_differences(original,resident_image)
  resident_image.save_png(folder+path.get_file().trim_suffix(".png")+"-resident.png")
  image.save_png(folder+path.get_file().trim_suffix(".png")+"-fresh.png")
  for material in pages[path].materials.values():material.set_shader_parameter("base_texture",fresh)
  for i in 3:await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(folder+label+"-after-"+path.get_file())
  records.append({"page":path,"resident_differences":resident_differences,"fresh_differences":differences,"materials":pages[path].materials.size()})
 check(pages.size()>=3,"The control covers every actually bound native BG page")
 root.get_texture().get_image().save_png(folder+label+"-after-all.png")
 var file=FileAccess.open(folder+label+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"pages":records,"same_frozen_camera":true,"diagnostic_only":true}," "));file.close()
 print("ELSA_RESIDENT_REBIND pages=",records)

func review_cpu_pages(label:String):
 var pages={}
 for node in game.world.find_children("*","MeshInstance3D",true,false):
  if node.mesh==null or not node.is_visible_in_tree() or node.get_world_3d()!=game.camera_rig.camera.get_world_3d():continue
  for surface in node.mesh.get_surface_count():
   var material=node.get_active_material(surface)
   if not material is ShaderMaterial:continue
   var texture=material.get_shader_parameter("base_texture")
   if not texture is Texture2D:continue
   var path:String=texture.get_meta("original_source_page",texture.resource_path)
   if path.begins_with(Original.Art.ROOT+"elsa/atlas-"):pages[path]=texture
 var records=[]
 for path in pages:
  var key:String=path.trim_prefix(Original.Art.ROOT);var page:int=Original.Art.data().pages.find(key)
  var texture:Texture2D=pages[path];var native=Image.load_from_file(path)
  var differences=visible_differences(native,texture.get_image())
  check(texture is ImageTexture and Original.Art.page_textures.get(page)==texture and Original.Art.page_images.has(page),"Bound trial texture reuses the existing prepared CPU image owner: "+key)
  check(differences==0,"Every bound trial page retains all native visible RGB and alpha after complete map setup: "+key)
  var prepared:Image=Original.Art.page_image(page)
  check(prepared==Original.Art.page_images.get(page) and visible_differences(native,prepared.duplicate())==0 and not prepared.has_mipmaps(),"Minimap and sign sampling retain the same unmodified source Image: "+key)
  records.append({"page":key,"visible_pixel_differences":differences,"shared_prepared_image":Original.Art.page_images.has(page)})
 check(pages.size()>=3 and Original.Art.pending_page_uploads.is_empty(),"All bound trial pages finish their existing one-time setup upload")
 var file=FileAccess.open(capture_output+label+"-cpu-pages.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"pages":records,"production_cpu_pages":true,"driver_args":OS.get_cmdline_args()}," "));file.close()
 print("ELSA_CPU_PAGE_REVIEW ",records)

func visible_differences(original:Image,image:Image)->int:
 original.convert(Image.FORMAT_RGBA8);image.convert(Image.FORMAT_RGBA8)
 original.clear_mipmaps();image.clear_mipmaps()
 if original.get_size()!=image.get_size():return -1
 var expected=original.get_data();var actual=image.get_data();var differences=0
 if actual.size()!=expected.size():return -1
 for i in range(0,expected.size(),4):
  if actual[i+3]!=expected[i+3] or expected[i+3]>0 and (actual[i]!=expected[i] or actual[i+1]!=expected[i+1] or actual[i+2]!=expected[i+2]):differences+=1
 return differences
