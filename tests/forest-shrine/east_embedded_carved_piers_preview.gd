extends "res://tests/forest-shrine/east_hourglass_preview.gd"
const Piers=preload("res://scripts/forest/forest_east_embedded_carved_piers.gd")
const OUTPUT="res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Room Piers/Embedded Four Private/"
func run():
 var geometry_only="--geometry-only"in OS.get_cmdline_user_args()
 var selected=Piers.IDS
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--only="):
   var serial=int(argument.trim_prefix("--only="));assert(serial in Piers.IDS);selected=[serial]
 var hashes=Sources.snapshot([get_script().resource_path,"scripts/forest/forest_east_embedded_carved_piers.gd","scripts/forest/forest_east_carved_pier_study.gd","scripts/forest/forest_east_mouse_room_piers.gd","scripts/forest/forest_east_room_furniture.gd","scripts/forest/forest_east_fallback_families.gd","scripts/forest/forest_coastal_mesh.gd",Piers.Base.Measurements.ROOT+"data.json",Piers.Base.MASONRY,"assets/maps/original_crossgate/east/catalog.json"])
 hashes.merge(Sources.snapshot([Piers.Base.NATIVE_CPU,"assets/maps/original_crossgate/east/carved-cpu-pages/provenance.json"]))
 hashes.merge(Sources.snapshot([Piers.INFERRED_FRONT54,"assets/maps/falan/east_region/carved_pier_study/inferred-1230054-front-provenance-v1.json"]))
 root.size=Vector2i(1440,900);root.title="Cross Gate · Embedded source pier profiles"
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("243039");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("dae4e3");env.environment.ambient_light_energy=.65;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);stage.add_child(sun)
 var camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=55
 Art.load_east();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 for serial in selected:
  var graphic:Dictionary=Art.data().graphics[str(serial)];var model=Piers.mesh(serial,graphic)
  check(model==Piers.mesh(serial,graphic)and model.get_surface_count()==2,"One immutable two-surface variant "+str(serial))
  var arrays:Array=model.get_meta("east_cpu_arrays")[0];var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var welded={};var edges={};var projection=Rect2();var first=true
  for p:Vector3 in points:
   var pixel=Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.-p.y/.045)
   projection=Rect2(pixel,Vector2.ZERO)if first else projection.expand(pixel);first=false
  for i in range(0,ids.size(),3):
   var tri=[]
   for j in 3:
    var key=Vector3i((points[ids[i+j]]*100000.).round())
    if not welded.has(key):welded[key]=welded.size()
    tri.append(welded[key])
   if tri[0]==tri[1]or tri[1]==tri[2]or tri[2]==tri[0]:continue
   for pair in[[tri[0],tri[1]],[tri[1],tri[2]],[tri[2],tri[0]]]:
    var key=Vector2i(mini(pair[0],pair[1]),maxi(pair[0],pair[1]));edges[key]=int(edges.get(key,0))+1
  check(edges.values().all(func(count_):return count_==2),"Closed body through infill/profile junctions "+str(serial))
  var g:Dictionary=Piers.Base.Measurements.data().graphics[str(serial)];var expected=Rect2(Vector2(g.origin[0]+g.bounds[0],g.origin[1]+g.bounds[1]),Vector2(g.bounds[2]-g.bounds[0],g.bounds[3]-g.bounds[1]))
  check(projection.position.distance_to(expected.position)<.08 and projection.size.distance_to(expected.size)<.08 and absf(model.get_aabb().position.y)<.01,"Source projection and ground datum "+str(serial))
  var node=MeshInstance3D.new();node.mesh=model;stage.add_child(node);var bounds=model.get_aabb();var target=bounds.get_center()
  for angle in (0 if geometry_only else 2):
   camera.position=target+(Vector3(-1,.65,1)if angle==0 else Vector3(1,.7,-1)).normalized()*bounds.size.length()*1.4;camera.look_at(target);camera.reset_physics_interpolation()
   for frame in 12:await process_frame
   await RenderingServer.frame_post_draw
   var filename=str(serial)+("-normal.png"if angle==0 else"-reverse.png")
   check(root.get_texture().get_image().save_png(OUTPUT+filename)==OK,"Captured "+filename);captures.append(filename)
  observations.append({"graphic":serial,"bounds":var_to_str(bounds),"source_projection":var_to_str(projection),"inferred":model.get_meta("inferred_details")});node.queue_free();await process_frame
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Sources unchanged through preview")
 var report=("geometry.json"if geometry_only else"review-"+str(selected[0])+".json"if selected.size()==1 else"review.json")
 var file=FileAccess.open(OUTPUT+report,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"selected":selected,"observations":observations,"captures":captures,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Private selected embedded variants, geometry and paint review only. No canonical dispatch or whole-room acceptance."},"  "));file.close();print("EAST_EMBEDDED_PIERS_PREVIEW checks=",checks," failures=",failures);quit(failures)
