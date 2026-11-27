extends "res://tests/forest-shrine/east_landmark_review.gd"
const Architecture=preload("res://scripts/forest/forest_east_classic_architecture.gd")
const Sections=preload("res://scripts/forest/forest_east_architecture_sections.gd")
const ARCH_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Classic Architecture/"
const SECTION_ROOT="res://assets/maps/falan/east_region/classic_architecture/sections/"
var mesh_audit=[]
var architecture_sources:Dictionary={}
var candidate_walls=false
var with_walls=false
var wall_meshes:Dictionary={}
var source_graphics:Dictionary={}
func review_path()->String:return ARCH_OUT
func run():
 root.size=Vector2i(1200,900)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARCH_OUT))
 candidate_walls="--candidate-walls" in OS.get_cmdline_user_args()
 with_walls="--with-walls" in OS.get_cmdline_user_args()
 var source_paths=["tests/forest-shrine/east_classic_architecture_review.gd","scripts/forest/forest_east_classic_architecture.gd","scripts/forest/forest_coastal_mesh.gd","scripts/forest/forest_east_region_art.gd","assets/maps/falan/east_region/classic_architecture/data.json","assets/maps/falan/east_region/classic_architecture/profiles.json","assets/maps/original_crossgate/building-surfaces.png"]
 for name in ["forest_falan_architecture","forest_falan_houses","forest_falan_magic_shop","forest_venoa_buildings","forest_il_laruka_buildings","forest_coastal_buildings","forest_kili_art","forest_venoa_walls","forest_original_map_details","forest_east_fallback_families","forest_falan_lamps","forest_falan_courtyard","forest_stone_fort","forest_static_boxes","forest_falan_proportions"]:source_paths.append("scripts/forest/"+name+".gd")
 if candidate_walls or with_walls:source_paths.append_array(["scripts/forest/forest_east_architecture_sections.gd","assets/maps/falan/east_region/classic_architecture/sections/data.json"])
 Maps.Art.load_east()
 source_graphics=JSON.parse_string(FileAccess.get_file_as_string(SECTION_ROOT+"data.json")).graphics if candidate_walls else Architecture.data().graphics.duplicate()
 if with_walls:source_graphics.merge(JSON.parse_string(FileAccess.get_file_as_string(SECTION_ROOT+"data.json")).graphics)
 for token:String in source_graphics:
  var source_root=SECTION_ROOT if source_graphics[token].kit=="native_cap_wall" else Architecture.ROOT
  for suffix in [".png","-front.png","-surfaces.png"]:
   var path=source_root.trim_prefix("res://")+token+suffix
   if FileAccess.file_exists("res://"+path):source_paths.append(path)
 architecture_sources=Sources.snapshot(source_paths)
 await source_models()
 var changed=Sources.changed(architecture_sources)
 check(changed.is_empty(),"Loaded architecture sources remain current through the source/reverse capture")
 var subset=Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--ids="))
 var filename="subset-source-review.json" if subset else "all-candidates-source-review.json" if with_walls else "candidate-walls-source-review.json" if candidate_walls else "source-review.json"
 var file=FileAccess.open(ARCH_OUT+filename,FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"mesh_audit":mesh_audit,"source_hashes":architecture_sources,"source_changed_during_run":changed,"subset_only":subset,"scope":"Every enrolled exact source architecture/reverse model unless subset_only is true. Pending IDs do not dispatch. No actual-map or visual acceptance inferred from source checks."},"  "));file.close()
 print("EAST_CLASSIC_ARCHITECTURE_SOURCE_RESULT checks=",checks," failures=",errors," meshes=",mesh_audit.size())
 quit(1 if errors else 0)

func prepared_source(serial:int)->Mesh:
 if source_graphics[str(serial)].kit!="native_cap_wall":return Architecture.mesh(serial,Maps.Art.data().graphics[str(serial)])
 if not wall_meshes.has(serial):wall_meshes[serial]=Sections.wall(source_graphics[str(serial)],load(SECTION_ROOT+str(serial)+"-surfaces.png"),load(SECTION_ROOT+str(serial)+"-front.png"))
 return wall_meshes[serial]

func source_models():
 var viewport=SubViewport.new();viewport.size=Vector2i(640,640);viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage=Node3D.new();viewport.add_child(stage)
 var environment=WorldEnvironment.new();var settings=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("27313a")
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.85
 environment.environment=settings;stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=.65;stage.add_child(light)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
 var ids=source_graphics.keys().map(func(token):return int(token));ids.sort()
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--ids="):ids=Array(arg.trim_prefix("--ids=").split(",")).map(func(token):return int(token))
 for serial:int in ids:
  var g:Dictionary=source_graphics[str(serial)]
  var mesh=prepared_source(serial)
  check(prepared_source(serial)==mesh,"Immutable existing architecture cached "+str(serial))
  check(mesh.get_surface_count()>0,"Existing owner has physical surfaces "+str(serial))
  check(mesh.get_aabb().size.y>.05,"Existing architecture has source-sized vertical geometry "+str(serial))
  var count=0
  for slot in mesh.get_surface_count():count+=mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX].size()/3
  check(count>8 and count<60000,"Existing complete master remains bounded "+str(serial))
  mesh_audit.append({"graphic":serial,"kit":g.kit,"triangles":count,"surfaces":mesh.get_surface_count(),"bounds":var_to_str(mesh.get_aabb()),"source_rgba_sha256":g.source_rgba_sha256,"source_footprint":g.footprint})
  var node=MeshInstance3D.new();node.mesh=mesh;node.scale.y=1./(.045*Landmarks.Fit.VERTICAL);stage.add_child(node)
  var across=(g.origin[0]+g.size[0]*.5)/(2.*Landmarks.Fit.HORIZONTAL)
  var target=Vector3(across,(-g.origin[1]-g.size[1]*.5)/Landmarks.Fit.VERTICAL,across)
  camera.size=g.size[1]/(sqrt(2.)*32./3.)*1.14
  for angle in 2:
   if angle==1:
    target=node.transform*mesh.get_aabb().get_center()
    camera.size=maxf(mesh.get_aabb().size.length(),mesh.get_aabb().size.y/(.045*Landmarks.Fit.VERTICAL))*1.2
   camera.position=target+(Vector3(-1,1.603567,1) if angle==0 else Vector3(1,1.15,-1)).normalized()*100.
   camera.look_at(target);camera.current=true
   if DisplayServer.get_name()!="headless":
    for i in 4:await process_frame
    await RenderingServer.frame_post_draw
    check(viewport.get_texture().get_image().save_png(ARCH_OUT+str(serial)+("-source-axis.png" if angle==0 else "-reverse.png"))==OK,"Captured existing native architecture "+str(serial)+" "+str(angle))
  node.queue_free();await process_frame
 viewport.queue_free();await process_frame
