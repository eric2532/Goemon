extends "res://tests/forest-shrine/original_maps_test.gd"
## Staged source art through the existing outdoor owner; canonical map100 stays unchanged.
const REVIEW="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source art recovery/"
const STAGE=REVIEW+"Prepared/"
const FULL="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source outdoors/Prepared full/"
const West=preload("res://scripts/forest/forest_west_route_scenery.gd")
const Southwest=preload("res://scripts/forest/forest_venoa_southwest_scenery.gd")
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
class StudyTerrain extends Terrain:
 var snapshot:Image
 var paint:ImageTexture
 func mask_image()->Image:return snapshot
 func mask_texture()->Texture2D:
  if paint==null:paint=ImageTexture.create_from_image(snapshot)
  return paint
 func terrain_field()->Resource:
  if variant=="east_gate":
   if not fields.has(variant):fields[variant]=EastRoad.build_field(snapshot)
   return fields[variant]
  return super.terrain_field()
class StudyModel:
 var terrain
 func surface_height(x:float,z:float)->float:return terrain.height(x,z)
var captures=[]
var prepared={}
func _initialize():
 create_timer(600).timeout.connect(func():printerr("FREYJA_ART_STUDY_TIMEOUT");quit(1))
 run.call_deferred()
func read(path:String)->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func write(path:String,data):
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data,"  ")+"\n");file.close()
func flat(t:Transform3D)->Array:return [t.basis.x.x,t.basis.x.y,t.basis.x.z,t.basis.y.x,t.basis.y.y,t.basis.y.z,t.basis.z.x,t.basis.z.y,t.basis.z.z,t.origin.x,t.origin.y,t.origin.z]
func prepare_meshes():
 prepared=read(STAGE+"source-additions.json")
 var protected={};var generated={}
 for path in ["res://scripts/forest/forest_venoa_southwest_scenery.gd","res://scripts/geo.gd","res://scripts/forest/forest_frostpass_interiors.gd"]:protected[path]=FileAccess.get_sha256(path)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STAGE+"meshes/"))
 for key in prepared.graphics:
  var g:Dictionary=prepared.graphics[key]
  if g.recipe=="tree":
   protected[g.asset]=FileAccess.get_sha256(g.asset)
   g.prepared_fit=flat(West.source_tree_fit(g))
   check(g.prepared_fit.all(func(n):return is_finite(n)),"Prepared finite native tree fit "+key)
  else:
   if g.family=="flowers":protected[West.Meadow.DIR+g.studied_whole_asset+".glb"]=FileAccess.get_sha256(West.Meadow.DIR+g.studied_whole_asset+".glb")
   var mesh:Mesh=West.source_daisy_mesh(g)if g.recipe=="large_daisy"else West.source_flower_mesh(int(key),g)if g.family=="flowers"else Southwest.detail_mesh(int(key),g)
   g.prepared_mesh=STAGE+"meshes/"+key+".res"
   check(ResourceSaver.save(mesh,g.prepared_mesh)==OK,"Prepared existing native mesh "+key)
   check(mesh.get_aabb().size.y>.001 and mesh.get_aabb().size.is_finite(),"Prepared source detail has finite volume "+key)
   if g.recipe=="large_daisy":check(mesh.get_meta("source_petals")==10,"One source-observed ten-petal head retained "+key)
   var triangles=0;var vertices=0
   for surface in mesh.get_surface_count():
    var arrays:Array=mesh.surface_get_arrays(surface);vertices+=arrays[Mesh.ARRAY_VERTEX].size()
    triangles+=(arrays[Mesh.ARRAY_INDEX].size()if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty()else arrays[Mesh.ARRAY_VERTEX].size())/3
   generated[key]={"sha256":FileAccess.get_sha256(g.prepared_mesh),"surfaces":mesh.get_surface_count(),"bounds":str(mesh.get_aabb()),"triangles":triangles,"vertices":vertices}
 var models=protected.keys().duplicate()
 for path in models:
  if not path.ends_with(".glb"):continue
  var master:String=path.replace("/assets/models/","/assets/blender/").replace(".glb",".blend")
  if FileAccess.file_exists(master):protected[master]=FileAccess.get_sha256(master)
 for path in protected:check(FileAccess.get_sha256(path)==protected[path],"Original whole master remains unchanged "+path)
 prepared.prepared_source_sha256=FileAccess.get_sha256(STAGE+"source-additions.json")
 prepared.prepared_geometry_sha256=FileAccess.get_sha256("res://scripts/forest/forest_west_route_scenery.gd")
 write(STAGE+"prepared-additions.json",prepared)
 write(REVIEW+"mesh-preparation.json",{"checks":checks,"failures":failures,"protected":protected,"meshes":generated,"active":false,"limits":"Prepared source-fit geometry only; morphology and normal-camera acceptance remain separate. No collision/navigation, source activation, GLB/Blender master or canonical package changed."})
func owner_checks():
 var results={}
 for area in prepared.maps:
  var t=StudyTerrain.new();t.variant=area;t.snapshot=load(FULL+"cpu-masks/"+area+".res")
  t.horizontal_scale=2.;t.expansion=1.5 if area=="south_lakes"else 1.
  Terrain.fields.erase(area);t.configure([])
  var model=StudyModel.new();model.terrain=t
  var parent=Node3D.new();root.add_child(parent)
  var added=West.build_additions(parent,area,model,prepared);var stations={};var valid=true
  for node in added.get_children():
   if not node is MultiMeshInstance3D:continue
   var cells:Array=node.get_meta("source_addition_cells");var serial:int=node.get_meta("source_addition_serial")
   valid=valid and node.multimesh.instance_count==cells.size()
   for cell in cells:stations[[cell[0],cell[1],serial]]=true
  check(stations.size()==prepared.maps[area].size(),"Every staged owner station is mounted "+area)
  check(valid,"Existing local batches retain every declared instance "+area)
  check(added.find_children("*","CollisionObject3D",true,false).is_empty(),"Source additions own no independent collision "+area)
  results[area]={"stations":stations.size(),"batches":added.get_child_count(),"renderer_positions_verified":false}
  parent.queue_free();await process_frame
 write(REVIEW+"owner-staging.json",{"checks":checks,"failures":failures,"areas":results,"active":false,"limits":"Existing owner setup on all seven staged CPU terrains. Counts/group inputs only; Dummy MultiMesh transforms are not valid rendered-position proof. Normal-camera visual/anchor validation remains scoped to its captured source stations."})
func source_point(cell:Vector2)->Vector2:return Tour.Regions.frame("west_lakes").inverse()*(cell*3.)
func view(label:String,cell:Vector2,yaw:float,fixed:Dictionary={}):
 var local=source_point(cell)
 check(game.model.terrain.contains(local.x,local.y),"Gameplay camera stands on staged dry terrain "+label)
 game.player.position=game.model.world_point(source_point(cell),.15);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
 game.model.hero_position=game.player.position;game.world.sync(0)
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0;game.camera_rig.camera.fov=63.
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 var camera:Camera3D=game.camera_rig.camera
 var info={"name":label,"source_cell":[cell.x,cell.y],"yaw":yaw,"fov":camera.fov,"eye":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"rotation":[camera.global_rotation.x,camera.global_rotation.y,camera.global_rotation.z]}
 if not fixed.is_empty():
  var old_eye=Vector3(fixed.eye[0],fixed.eye[1],fixed.eye[2]);var old_rotation=Vector3(fixed.rotation[0],fixed.rotation[1],fixed.rotation[2])
  check(camera.global_position==old_eye and camera.global_rotation==old_rotation and info.fov==fixed.fov,"Exact before/after gameplay camera retained")
 for i in 5:await process_frame
 if DisplayServer.get_name()!="headless":
  RenderingServer.force_draw();var image=root.get_texture().get_image();var colors={}
  for y in range(0,image.get_height(),32):
   for x in range(0,image.get_width(),32):colors[image.get_pixel(x,y).to_rgba32()]=true
  check(colors.size()>20,"Normal gameplay image is nonblank "+label)
  check(image.save_png(REVIEW+"WestLakes study/"+label+".png")==OK,"Normal gameplay image saved "+label)
 captures.append(info)
func run():
 if "--prepare-only"in OS.get_cmdline_user_args():
  prepare_meshes();print("FREYJA_ART_PREPARE ",checks," checks ",failures," failures");quit(1 if failures else 0);return
 prepared=read(STAGE+"prepared-additions.json")
 check(prepared.prepared_source_sha256==FileAccess.get_sha256(STAGE+"source-additions.json"),"Prepared fits/meshes match staged source rows")
 check(prepared.prepared_geometry_sha256==FileAccess.get_sha256("res://scripts/forest/forest_west_route_scenery.gd"),"Prepared geometry matches its existing owner recipe")
 if "--owners-only"in OS.get_cmdline_user_args():
  await owner_checks();print("FREYJA_ART_OWNERS ",checks," checks ",failures," failures");quit(1 if failures else 0);return
 var assets={}
 for path in ["res://assets/maps/falan/freyja_source/100.dat","res://assets/maps/falan/freyja_residual/full/data.gd","res://assets/maps/falan/freyja_ground_index.png","res://assets/maps/falan/freyja_ground_atlas.png"]:assets[path]=FileAccess.get_sha256(path)
 root.size=Vector2i(1280,800);game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-freyja-art-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true
 Tour.travel(game,Tour.Regions.layout("west_lakes"),{"arrival":source_point(Vector2(130,156)),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 var old=game.model.terrain;var old_field=old.terrain_field();var old_heights:PackedFloat32Array=old_field.get_meta("heights");var t=StudyTerrain.new()
 t.variant="west_lakes";t.snapshot=load(FULL+"cpu-masks/west_lakes.res");t.horizontal_scale=old.horizontal_scale;t.expansion=old.expansion
 Terrain.fields.erase("west_lakes");Terrain.recent_geometry.clear();t.configure([]);game.model.terrain=t
 game.world.reload_map()
 for i in 4:await process_frame
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 # The fixture supplies the matching staged floor data from CPU images; production bindings remain unchanged.
 var index_image=Image.load_from_file(ProjectSettings.globalize_path(FULL+"freyja_ground_index.png"));var atlas=Image.load_from_file(ProjectSettings.globalize_path(FULL+"freyja_ground_atlas.png"))
 var index=ImageTexture.create_from_image(index_image);var tiles:Array[Image]=[]
 for y in atlas.get_height()/36:
  for x in 32:
   var tile=atlas.get_region(Rect2i(x*36+2,y*36+2,32,32));tile.generate_mipmaps();tiles.append(tile)
 var layers=Texture2DArray.new();check(layers.create_from_images(tiles)==OK,"Matching staged original floor tiles prepared")
 var valley=game.world.map_features.find_child("WindMeadowValley",true,false)
 var ground:ShaderMaterial=valley.get_child(0).material_override
 ground.set_shader_parameter("freyja_ground_index",index);ground.set_shader_parameter("freyja_ground_atlas",layers)
 index.update(index_image);t.paint.update(t.snapshot)
 for i in tiles.size():layers.update_layer(tiles[i],i)
 var historical=read(REVIEW+"Before rounded plant correction/WestLakes study/verification-rendered.json")
 await view("west-lakes-before",Vector2(130,156),0.,historical.captures[0])
 var subset=prepared.duplicate(true);subset.maps={"west_lakes":prepared.maps.west_lakes.filter(func(row):return Rect2i(128,152,8,8).has_point(Vector2i(row.cell[0],row.cell[1])))}
 check(subset.maps.west_lakes.size()==57,"Every original study station is staged, including the single daisy and tree")
 var native_before=JSON.stringify(game.model.scenery_obstacles)
 var added=West.build_additions(game.world.map_features,"west_lakes",game.model,subset)
 # The ordinary meadow setup registers these after scenery build; this fixture adds its stage afterward.
 for material in West.Meadow.wind_materials.values():
  if material.get_shader_parameter("canopy")==true and material not in game.world.fog_materials:game.world.fog_materials.append(material)
 game.world.sync(0.)
 var canopy_policy=true
 for node in added.get_children():
  if node.get_meta("crossgate_tree_part","")=="Canopy":
   canopy_policy=canopy_policy and node.material_override in game.world.fog_materials and node.material_override.get_shader_parameter("canopy_cutaway")==(game.model.phase=="wave")
 check(canopy_policy,"Added canopy uses the existing world phase/hero cutaway owner")
 check(added.get_meta("source_addition_anchors").size()==57,"Existing source scenery owner instantiated every study station")
 var stations={};var maximum_error=0.
 if DisplayServer.get_name()!="headless":
  for node in added.get_children():
   if not node is MultiMeshInstance3D:continue
   var serial:int=node.get_meta("source_addition_serial");var cells:Array=node.get_meta("source_addition_cells")
   for i in cells.size():
    var pose:Transform3D=node.multimesh.get_instance_transform(i)
    var g:Dictionary=subset.graphics[str(serial)]
    if g.recipe=="tree":
     for part in West.Meadow.source(g.asset):
      if part.name==node.get_meta("crossgate_tree_part",""):pose*=part.transform.affine_inverse();break
     var f:Array=g.prepared_fit
     pose*=Transform3D(Basis(Vector3(f[0],f[1],f[2]),Vector3(f[3],f[4],f[5]),Vector3(f[6],f[7],f[8])),Vector3(f[9],f[10],f[11])).affine_inverse()
    var actual:Vector2=Tour.Regions.frame("west_lakes")*Vector2(pose.origin.x,pose.origin.z)/3.
    maximum_error=maxf(maximum_error,actual.distance_to(Vector2(cells[i][0],cells[i][1])))
    stations[[cells[i][0],cells[i][1],serial]]=true
  check(stations.size()==57 and maximum_error<.0001,"Actual renderer buffers retain every source cell/graphic and native anchor")
 check(added.find_children("*","CollisionObject3D",true,false).is_empty(),"Scenery study adds no new collision/navigation owner")
 check(JSON.stringify(game.model.scenery_obstacles)==native_before,"Existing native obstacle declarations stay unchanged")
 await view("west-lakes-after",Vector2(130,156),0.,captures[0])
 await view("west-lakes-context",Vector2(130,146),PI)
 check(old_field.get_meta("heights")==old_heights,"Protected current terrain field is not mutated by staged source study")
 for path in assets:check(FileAccess.get_sha256(path)==assets[path],"Canonical source/terrain assets remain unchanged "+path)
 write(REVIEW+"WestLakes study/verification-"+("headless"if DisplayServer.get_name()=="headless"else"rendered")+".json",{"checks":checks,"failures":failures,"captures":captures,"active":false,"staged_stations":57,"rendered_stations":stations.size(),"maximum_anchor_error_cells":maximum_error,"source_sha256":prepared.source_sha256,"limits":"Fixture-only staged full-source terrain/floor inputs and57source-anchored visual additions. No full100 publication, encounter/native/source/layout changes. Source/normal-camera visual judgment remains separate."})
 print("FREYJA_ART_STUDY ",checks," checks ",failures," failures ",captures.size()," cameras");quit(1 if failures else 0)
