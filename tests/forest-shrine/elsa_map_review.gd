extends "res://tests/forest-shrine/original_maps_test.gd"
## Fixed walkable viewpoints only. Direct scene placement is art evidence, not journey completion.
const Elsa=preload("res://scripts/forest/forest_elsa_route.gd")
const OUTPUT="res://build/Other Files/Asset Toolkit/Elsa Island/Full Island Review/"
var capture_output=OUTPUT

func _initialize():
 create_timer(900).timeout.connect(func():printerr("ELSA_REVIEW_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 var first=0;var count_=24;var only=0;var only_maps:Array[int]=[];var labels=PackedStringArray();var pick=Vector2.INF;var picks:Array[Vector2]=[]
 var atlas_probe="--probe-atlas" in OS.get_cmdline_user_args()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--first="):first=int(argument.get_slice("=",1))
  if argument.begins_with("--count="):count_=int(argument.get_slice("=",1))
  if argument.begins_with("--map="):only=int(argument.get_slice("=",1))
  if argument.begins_with("--labels="):labels=argument.get_slice("=",1).split(",")
  if argument.begins_with("--maps="):
   for id in argument.get_slice("=",1).split(","):only_maps.append(int(id))
  if argument.begins_with("--pick="):
   var xy=argument.get_slice("=",1).split(",");pick=Vector2(float(xy[0]),float(xy[1]))
  if argument.begins_with("--picks="):
   for coordinate in argument.get_slice("=",1).split(":"):
    var xy=coordinate.split(",");picks.append(Vector2(float(xy[0]),float(xy[1])))
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Elsa Island/review-points.json"))
 if only>0:points=points.filter(func(point):return int(point.map)==only)
 if not only_maps.is_empty():points=points.filter(func(point):return int(point.map) in only_maps)
 if not labels.is_empty():points=points.filter(func(point):return point.label in labels)
 points=points.slice(first,mini(points.size(),first+count_))
 if points.is_empty():printerr("ELSA_REVIEW_EMPTY_SELECTION");quit(1);return
 await setup_review_game()
 var observations=[]
 for point in points:
  var id=int(point.map);var cell=Vector2i(point.cell[0],point.cell[1]);var state:Dictionary=Original.state(id)
  check(Original.open(state.bits,state.size,cell),"Review stands on original walkable ground "+point.label)
  check(Elsa.owned_cell(id,cell),"Review belongs to the island or a documented blocked branch "+point.label)
  var at=Original.source_point(id,cell)
  var started=Time.get_ticks_msec()
  if game.model.falan_floor!=id:
   Tour.travel(game,Original.layout(id),{"arrival":at,"yaw":0.,"velocity":Vector3.ZERO})
   for i in 6:await physics_frame
  await prepare_review_point(point)
  if FileAccess.file_exists("res://assets/maps/falan/elsa/scenery/terrain/%d.json"%id):check(is_zero_approx(game.model.surface_height(at.x,at.y)),"Trial navigation remains on its original zero-height ground "+point.label)
  game.player.position=game.model.world_point(at,.15);game.player.velocity=Vector3.ZERO;game.falan_crossing_position=Vector2.INF
  game.player.reset_physics_interpolation();game.camera_rig.reset_follow()
  var views=[]
  var angles:Array=point.get("angles",[0.,-PI*.25]);assert(angles.size()==2,"Fixed review needs two recorded gameplay angles")
  for view_index in 2:
   var angle=float(angles[view_index])
   game.camera_rig.yaw=angle+float(point.get("yaw",0.));game.camera_rig.pitch=float(point.get("pitch",game.COMBAT_CAMERA_PITCH))
   game.camera_rig.distance=clampf(float(point.get("distance",game.ViewPreferences.CAMERA_DEFAULT)),game.ViewPreferences.CAMERA_MIN,game.ViewPreferences.CAMERA_MAX)
   game.camera_rig.current_distance=game.camera_rig.combat_distance()
   for i in 8:await process_frame
   # Freeze the settled rig so pixel probes use the camera that drew the capture.
   game.camera_rig.set_process(false)
   game.camera_rig.reset_physics_interpolation()
   game.camera_rig.camera.reset_physics_interpolation()
   await physics_frame
   for i in 2:await RenderingServer.frame_post_draw
   await RenderingServer.frame_post_draw
   var camera:Camera3D=game.camera_rig.camera;var at_camera=camera.global_position;var frame=camera.global_basis
   views.append({"angle":angle,"actual_distance":game.camera_rig.current_distance,"camera":[at_camera.x,at_camera.y,at_camera.z],"camera_basis":[[frame.x.x,frame.x.y,frame.x.z],[frame.y.x,frame.y.y,frame.y.z],[frame.z.x,frame.z.y,frame.z.z]],"fov":camera.fov,"h_offset":camera.h_offset,"v_offset":camera.v_offset})
   root.get_texture().get_image().save_png(capture_output+point.label+("-play" if view_index==0 else "-native")+".png")
   if angle==0. and (atlas_probe or pick.is_finite() or not picks.is_empty()):await probe_scene_atlas(point.label)
   if pick.is_finite() and angle==0.:pick_art(pick,point.label)
   if angle==0.:
    for screen in picks:pick_art(screen,point.label+"-%d-%d"%[int(screen.x),int(screen.y)])
   game.camera_rig.set_process(true)
  check(game.model.falan_floor==id,"Fixed view does not accidentally cross a doorway "+point.label)
  if Original.Art.data().maps.get(Original.path_for(id),{}).get("group","")=="elsa":
   check(game.exploration_loot.slots.all(func(slot):return not slot.active or not slot.chest),"Source art view contains no generic area-entry chest "+point.label)
  observations.append({"map":id,"cell":[cell.x,cell.y],"label":point.label,"yaw":float(point.get("yaw",0.)),"pitch":float(point.get("pitch",game.COMBAT_CAMERA_PITCH)),"distance":game.camera_rig.distance,"actual_distance":game.camera_rig.current_distance,"views":views,"milliseconds":Time.get_ticks_msec()-started,"static_memory":OS.get_static_memory_usage(),"fixture_only":true})
  print("ELSA_REVIEW ",point.label," map=",id," cell=",cell)
 var observation_name="observations-%d-%d.json"%[only,first] if labels.is_empty() else "observations-%s-%d.json"%[points[0].label,points.size()]
 var file=FileAccess.open(capture_output+observation_name,FileAccess.WRITE)
 file.store_string(JSON.stringify(observations," "));file.close()
 print("ELSA_REVIEW_RESULT views=",points.size()*2," checks=",checks," failures=",failures)
 await finish()

func prepare_review_point(_point:Dictionary):
 pass

func setup_review_game():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-elsa-map-review.cfg"
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.explorer_clock.save_left=600.
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_output))

func probe_scene_atlas(label:String):
 # Isolate texture readback before the picker asks the GPU for mesh arrays.
 var path="res://assets/maps/original_crossgate/elsa/atlas-40.png"
 var texture:Texture2D=load(path);var image=texture.get_image();var native=Image.load_from_file(path);var samples=[]
 image.save_png(capture_output+"scene-atlas-"+label+"-resident.png")
 var fresh:Texture2D=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
 var fresh_image=fresh.get_image();fresh_image.save_png(capture_output+"scene-atlas-"+label+"-fresh.png")
 var uploaded=ImageTexture.create_from_image(native);var uploaded_image=uploaded.get_image()
 for pixel in [Vector2i(153,1746),Vector2i(1925,1688),Vector2i(305,1744)]:
  samples.append({"pixel":[pixel.x,pixel.y],"native":native.get_pixelv(pixel).to_html(),"readback":image.get_pixelv(pixel).to_html(),"fresh":fresh_image.get_pixelv(pixel).to_html(),"uploaded":uploaded_image.get_pixelv(pixel).to_html()})
 var file=FileAccess.open(capture_output+"scene-atlas-"+label+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"texture":path,"samples":samples,"before_mesh_readback":true,"driver_args":OS.get_cmdline_args()}," "));file.close()
 print("ELSA_SCENE_ATLAS ",samples)

func pick_art(screen:Vector2,label:String):
 var camera:Camera3D=game.camera_rig.camera;var from=camera.project_ray_origin(screen);var direction=camera.project_ray_normal(screen);var hits=[]
 var ground=Plane(Vector3.UP,0.).intersects_ray(from,direction)
 if ground!=null:
  var state:Dictionary=Original.state(game.model.falan_floor)
  var local=Vector2(ground.x,ground.z)/float(game.model.falan_scale)-state.origin
  var native=Vector2((local.x+local.y)*32./3.,(local.y-local.x)*8.)
  var probe={"screen":[screen.x,screen.y],"world_ground":[ground.x,ground.z],"native":[native.x,native.y],"map":game.model.falan_floor}
  var probe_file=FileAccess.open(capture_output+"ground-probe-"+label+".json",FileAccess.WRITE);probe_file.store_string(JSON.stringify(probe," "));probe_file.close()
 var images={}
 for node in game.find_children("*","GeometryInstance3D",true,false):
  if not node.is_visible_in_tree() or node.get_world_3d()!=camera.get_world_3d():continue
  var mesh:Mesh;var poses:Array[Transform3D]=[]
  if node is MeshInstance3D:mesh=node.mesh;poses.append(node.global_transform)
  elif node is MultiMeshInstance3D and node.multimesh!=null:
   mesh=node.multimesh.mesh
   for i in node.multimesh.instance_count:poses.append(node.global_transform*node.multimesh.get_instance_transform(i))
  if mesh==null:continue
  var faces:PackedVector3Array;var paint=[]
  for pose in poses:
   if absf(pose.basis.determinant())<.00000001:continue
   var inverse=pose.affine_inverse();var origin:Vector3=inverse*from;var ray=(inverse.basis*direction).normalized()
   if mesh.get_aabb().intersects_ray(origin,ray)==null:continue
   if faces.is_empty():
    faces=mesh.get_faces()
    for surface in mesh.get_surface_count():
     var arrays=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
     var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
     var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
     var material:Material=node.material_override if node.material_override!=null else mesh.surface_get_material(surface);var texture:Texture2D
     if material is ShaderMaterial:texture=material.get_shader_parameter("base_texture") if material.get_shader_parameter("use_base_texture")==true else material.get_shader_parameter("atlas")
     elif material is StandardMaterial3D:texture=material.albedo_texture
     var pixels:Image
     var pixel_source="gpu_readback"
     var cull=0
     if material is ShaderMaterial:
      var code=material.shader.get_code()
      cull=0 if code.contains("cull_disabled") else -1 if code.contains("cull_front") else 1
     elif material is BaseMaterial3D:cull=0 if material.cull_mode==BaseMaterial3D.CULL_DISABLED else -1 if material.cull_mode==BaseMaterial3D.CULL_FRONT else 1
     if texture!=null:
      if texture.resource_path.ends_with(".png"):pixel_source="native_png"
      if not images.has(texture):images[texture]=Image.load_from_file(texture.resource_path) if pixel_source=="native_png" else texture.get_image()
      pixels=images[texture]
     for triangle in range(0,indices.size() if not indices.is_empty() else vertices.size(),3):
      var coords=[]
      for k in 3:
       var index=indices[triangle+k] if not indices.is_empty() else triangle+k
       coords.append(uv[index] if uv.size()>index else Vector2.ZERO)
      paint.append({"uv":coords,"pixels":pixels,"texture":texture.resource_path if texture!=null else "","surface":surface,"cull":cull,"pixel_source":pixel_source})
   var distance=INF;var hit_point=Vector3.ZERO;var sampled={}
   for i in range(0,faces.size(),3):
    var facing=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).dot(ray)*signf(pose.basis.determinant())
    if paint[i/3].cull!=0 and facing*float(paint[i/3].cull)>=0.:continue
    var hit=Geometry3D.ray_intersects_triangle(origin,ray,faces[i],faces[i+1],faces[i+2])
    if hit!=null and from.distance_to(pose*hit)<distance and visible_pick(hit,faces[i],faces[i+1],faces[i+2],paint[i/3]):
     distance=from.distance_to(pose*hit);hit_point=pose*hit
     var info:Dictionary=paint[i/3];var sample_uv=pick_uv(hit,faces[i],faces[i+1],faces[i+2],info)
     sampled={"surface":info.surface,"texture":info.texture,"uv":[sample_uv.x,sample_uv.y],"cull":info.cull,"facing":facing,"pixel_source":info.pixel_source}
     if info.pixels!=null and sample_uv.is_finite():
      var pixel=Vector2i(int(fposmod(sample_uv.x,1.)*info.pixels.get_width()),int(fposmod(sample_uv.y,1.)*info.pixels.get_height()))
      sampled.pixel=[pixel.x,pixel.y];sampled.color=info.pixels.get_pixelv(pixel).to_html()
   if is_finite(distance):
    var graphic=int(node.get_meta("source_graphic",-1));var row:Dictionary=Original.Art.data().graphics.get(str(graphic),{})
    hits.append({"node":node.name,"source":row.cut[0] if row.has("cut") else graphic,"distance":distance,"position":[pose.origin.x,pose.origin.y,pose.origin.z],"hit":[hit_point.x,hit_point.y,hit_point.z],"paint":sampled})
 hits.sort_custom(func(a,b):return a.distance<b.distance)
 var file=FileAccess.open(capture_output+"art-pick-"+label+".json",FileAccess.WRITE);file.store_string(JSON.stringify(hits.slice(0,20)," "));file.close()
 print("ELSA_ART_PICK ",label," ",hits.slice(0,6))

func visible_pick(hit:Vector3,a:Vector3,b:Vector3,c:Vector3,paint:Dictionary)->bool:
 var image:Image=paint.pixels
 if image==null:return true
 var uv=pick_uv(hit,a,b,c,paint)
 if not uv.is_finite():return false
 return image.get_pixel(clampi(int(fposmod(uv.x,1.)*image.get_width()),0,image.get_width()-1),clampi(int(fposmod(uv.y,1.)*image.get_height()),0,image.get_height()-1)).a>.5

func pick_uv(hit:Vector3,a:Vector3,b:Vector3,c:Vector3,paint:Dictionary)->Vector2:
 var ab=b-a;var ac=c-a;var at=hit-a;var aa=ab.dot(ab);var bb=ac.dot(ac);var cross_=ab.dot(ac);var denominator=aa*bb-cross_*cross_
 if absf(denominator)<.00000001:return Vector2.INF
 var beta=(bb*at.dot(ab)-cross_*at.dot(ac))/denominator;var gamma=(aa*at.dot(ac)-cross_*at.dot(ab))/denominator
 return paint.uv[0]*(1.-beta-gamma)+paint.uv[1]*beta+paint.uv[2]*gamma
