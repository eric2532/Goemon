extends "res://scripts/recovered_leaders_tests.gd"
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const OUT="res://build/Other Files/Arena/"
func run():
 create_timer(180).timeout.connect(func():printerr("ARENA_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800)
 for path in [Document.WIND_MEADOW_PATH,Document.WIND_MEADOW_LARGE_PATH]:
  var doc=Document.new(false)
  var error=doc.read_file(path)
  if error.is_empty():error=doc.play_error()
  check(error.is_empty(),"Four arena entrances validate: "+path+" "+error)
  var model=Model.new();model.reset(42,{},doc.data,false)
  check(model.survival_run and model.shrine().is_empty() and not model.has_enemy_camps() and not model.has_enemy_castles(),"Pure survival has no friendly/enemy castles")
  check(model.portals.size()==4 and model.buildings.is_empty(),"Open floor has four cardinal spawn entrances")
  var field=Runtime.navigation_data(model)
  check(field.heights==model.terrain.heights and field.width==model.terrain.width,"Native terrain shares the exact arena height field")
  var radius:float=model.terrain.floor_radius()
  check(model.surface_height(0,0)>0 and model.terrain.disk_clear(model.point(Vector2i(0,3)),3.9),"The original raised platform supports the player and slimes")
  var saved=Document.new(false);saved.capture(model);saved.data.title=doc.data.title
  var restored=Document.new(false)
  check(restored.decode(saved.encode()).is_empty() and restored.data.terrain_detail==Model.Arena.ID,"Save/reload preserves the arena design")
  var invalid=doc.data.duplicate(true);invalid.raised_castle=true
  check(not Document.validate(invalid).is_empty(),"Conflicting raised castles are rejected")
  invalid=doc.data.duplicate(true);invalid.falan_area=17
  check(not Document.validate(invalid).is_empty(),"Malformed area data returns a validation error")
  invalid=doc.data.duplicate(true);invalid.portals="four"
  check(not Document.validate(invalid).is_empty(),"Malformed entrances return a validation error")
  set_meta("forest_custom_layout",doc.data);set_meta("forest_painterly_preview",true)
  game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://arena-%d.cfg"%OS.get_process_id()
  root.add_child(game);current_scene=game;await frames(5)
  if not game.combat_warmup.complete:await game.combat_warmup.finished
  check(game.combat_warmup.complete,"Shared combat graphics, including Cave Bear, finish startup warmup")
  game.set_process(false);game.set_physics_process(false);game.camera_rig.set_process(false);game.player.set_physics_process(false)
  game.set_process_input(false);game.set_process_unhandled_input(false);game.player.set_process_input(false);game.player.set_process_unhandled_input(false);root.gui_disable_input=true
  check(game.enemy_objectives.is_empty() and game.world.map_features.find_child("FalanSurvivalArena",true,false)!=null,"The real scene builds the Falan arena without castle objectives")
  check(game.world.map_features.find_child("FalanArenaInlays",true,false)!=null,"The original five colored Cross Gate emblems render")
  var wall=game.world.map_features.find_child("ArenaOriginalTextureWalls",true,false)
  var wall_height:float=model.terrain.wall_height()
  check(wall is MeshInstance3D and absf(wall.mesh.get_aabb().end.y-wall_height)<.01 and wall_height>=160,"Continuous Cross Gate walls reach the former ceiling height")
  check(wall.material_override.get_shader_parameter("base_texture")==Model.Arena.Room.WallAtlas,"Tall walls reuse the original archived wall texture")
  check(wall.material_override.get_shader_parameter("panel_size")==Vector2(12,36),"Original wall decorations keep their proportions at a fixed detailed scale")
  var wall_tiles:Vector2i=wall.get_meta("archive_wall_tiles")
  check(wall_tiles.x!=wall_tiles.y and wall_tiles.x>0 and wall_tiles.y>0,"The facade reuses distinct original wall and pier panels")
  var vertices:PackedVector3Array=wall.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  check(vertices.size()<1000,"Wide full-height bays replace the dense repeated wall grid")
  var one_course=true
  for vertex:Vector3 in vertices:
   if absf(vertex.y)>0.01 and absf(vertex.y-wall_height)>.01 and absf(vertex.y-24.0*model.terrain_scale)>.01:one_course=false
  check(one_course,"Windows and cornices occur once in height instead of repeating in stacked rows")
  check(wall.material_override.get_shader_parameter("roof_cutaway_height")==wall_height,"Overhead cameras retain the wall cutaway")
  var original_material=Model.Arena.Room.painted_atlas(Model.Arena.Room.WallAtlas)
  check([null,0.0].has(original_material.get_shader_parameter("roof_cutaway_height")),"Original city materials retain their default visibility")
  check(game.world.map_features.find_child("ArenaCeilingUnderside",true,false)==null and game.world.map_features.find_child("ArenaCeilingCollision",true,false)==null,"The roof and its physical lid are removed")
  var sky_ray=PhysicsRayQueryParameters3D.create(Vector3(0,model.surface_height(0,0)+10,0),Vector3(0,wall_height+100,0),1)
  check(game.world.get_world_3d().direct_space_state.intersect_ray(sky_ray).is_empty(),"The arena is fully open to the sky")
  check(game.world.get_world_3d().environment.background_mode==Environment.BG_SKY,"The arena shows the existing sunlit sky")
  var map_ray=PhysicsRayQueryParameters3D.create(Vector3(0,wall_height+50,18),Vector3(0,-10,18),1)
  var map_hit=game.world.get_world_3d().direct_space_state.intersect_ray(map_ray)
  check(not map_hit.is_empty() and absf(map_hit.position.y-model.surface_height(0,18))<.01,"Overhead map picking reaches the arena floor")
  var wall_boxes:Array=game.model.get_meta("cave_combat_walls",[])
  var native_data=Runtime.navigation_data(game.model)
  check(wall_boxes.size()==12 and wall_boxes.all(func(box):return box.end in native_data.ray_max and box.position in native_data.obstacle_min),"Both native teams and projectile cover share the twelve wall/header bounds")
  var bounds:Rect2=model.terrain.arena_bounds()
  var reliefs=game.world.map_features.find_children("ArenaWallRelief*","Node3D",true,false)
  check(reliefs.size()==12,"Every wall span and entrance header has dimensional stone trim")
  var pillars=game.world.map_features.find_children("ArenaWallPillars","MultiMeshInstance3D",true,false)
  var banners=game.world.map_features.find_children("ArenaWallBanners","MultiMeshInstance3D",true,false)
  check(pillars.size()==8 and banners.size()==12,"Shared courtyard pillars and keep ornaments dress all four sides")
  var decoration_clear=true;var cutaway=true;var instances=0
  var shared_pier:Mesh=pillars[0].multimesh.mesh
  for batch:MultiMeshInstance3D in pillars+banners:
   if batch.name=="ArenaWallPillars" and batch.multimesh.mesh!=shared_pier:decoration_clear=false
   for surface in batch.multimesh.mesh.get_surface_count():
    var material:ShaderMaterial=batch.multimesh.mesh.surface_get_material(surface)
    if material.get_shader_parameter("roof_cutaway_height")!=wall_height:cutaway=false
   instances+=batch.multimesh.instance_count
   for index in batch.multimesh.instance_count:
    var box=batch.global_transform*batch.multimesh.get_instance_transform(index)*batch.multimesh.mesh.get_aabb()
    if Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).intersects(bounds.grow(-.01)):decoration_clear=false
  check(decoration_clear,"Shared relief meshes stay beyond the playable floor and entrance routes")
  check(cutaway,"All pillar, window and banner materials retain the overhead cutaway")
  check(reliefs.all(func(node):return node.find_children("*","CollisionObject3D",true,false).is_empty()),"Wall decoration adds no gameplay blockers")
  check([null,0.0].has(Model.Arena.wall_detail_meshes()[0].surface_get_material(0).get_shader_parameter("roof_cutaway_height")),"Cached source decorations keep their original city material visibility")
  print("ARENA_WALL_DETAILS batches=%d instances=%d shared_pier_surfaces=%d"%[pillars.size()+banners.size(),instances,shared_pier.get_surface_count()])
  var bays=game.world.map_features.find_children("ArenaGateBay*","Node3D",true,false)
  check(bays.size()==4,"All four entrance openings have finished recessed gate bays")
  for bay:Node3D in bays:
   check(bay.find_children("*","CollisionObject3D",true,false).is_empty(),"Exterior gate scenery adds no collision to the native arrival routes")
   var parts:Array[AABB]=[]
   for batch:MultiMeshInstance3D in bay.get_children():
    for index in batch.multimesh.instance_count:
     parts.append(batch.transform*batch.multimesh.get_instance_transform(index)*batch.multimesh.mesh.get_aabb())
   var sealed=true
   for x in [-45.0,0.0,45.0]:
    for y in [3.0,12.0,21.0]:
     var start=Vector3(x,y,-10)
     var end=Vector3(x,y,30)
     if not parts.any(func(box):return box.intersects_segment(start,end)):sealed=false
   check(sealed,"Solid gate backing covers the opening from floor to header and across its width")
   var outside=true
   for part:AABB in parts:
    if part.position.z<-.001:outside=false
   check(outside,"Gate bays stay outside the original playable floor")
  for edge in [Vector3(bounds.position.x-10,wall_height*.5,0),Vector3(bounds.end.x+10,wall_height*.5,0),Vector3(0,wall_height*.5,bounds.position.y-10),Vector3(0,wall_height*.5,bounds.end.y+10)]:
   var wall_ray=PhysicsRayQueryParameters3D.create(Vector3(0,wall_height*.5,0),edge,1)
   var wall_hit=game.world.get_world_3d().direct_space_state.intersect_ray(wall_ray)
   check(not wall_hit.is_empty() and wall_hit.collider.name.begins_with("ArenaPerimeterCollision"),"Wall headers close the upper hall on each side")
  var jump_pose=Transform3D(Basis.IDENTITY,Vector3(0,model.surface_height(0,18)+.1,18))
  check(not game.player.test_move(jump_pose,Vector3.UP*(wall_height+50)),"The player can rise freely through the open roof")
  var native=Runtime.new();native.configure(null);native.set_navigation(1,Runtime.navigation_data(game.model))
  var emblem_arrays=game.world.map_features.find_child("FalanArenaInlays",true,false).mesh.surface_get_arrays(0)
  var emblem_vertices:PackedVector3Array=emblem_arrays[Mesh.ARRAY_VERTEX]
  var emblem_normals:PackedVector3Array=emblem_arrays[Mesh.ARRAY_NORMAL]
  var inlay=game.world.map_features.find_child("FalanArenaInlays",true,false)
  check(inlay.mesh==Model.Arena.carved_inlay_mesh() and inlay.mesh.get_surface_count()==1,"All five carved emblems share one cached static mesh and material")
  check(inlay.material_override.get_shader_parameter("inlay_carving")==true and inlay.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"Recessed patterns receive groove shading and cast real sun shadows")
  check(inlay.material_override.get_shader_parameter("base_texture")==preload("res://assets/maps/falan/arena_inlays_detail.png"),"Finer recovered emblem pixels align with the detailed carving mesh")
  check([null,false].has(original_material.get_shader_parameter("inlay_carving")),"Original city artwork does not inherit the arena carving treatment")
  var ground=game.world.kai_materials.filter(func(material):return material.get_shader_parameter("arena_floor")==true)[0]
  var cutouts:PackedVector4Array=ground.get_shader_parameter("arena_inlay_cutouts")
  check(cutouts.size()==5,"The flat floor is cut away underneath all five recessed meshes")
  var emblem_index=0
  for row in Model.Arena.Room.Arena.Data.ARENA_MARKS:
   if row[0].y<90:continue
   var source=Model.Arena.SOURCE_ORIGIN+Vector2(row[0])*3.0
   var p=(source-Model.Arena.CENTER)*model.terrain_scale*2.0
   var baseline=Model.Arena.Room.Arena.surface_height(1401,source.x,source.y)
   var expected=(baseline+Model.Arena.PAD_RISE)*model.terrain_scale*2.0*Model.Arena.RISE_SCALE
   check(absf(model.surface_height(p.x,p.y)-expected)<.01,"Each colored emblem has a real raised terrain platform")
   var first=emblem_index*Model.Arena.INLAY_GRID*Model.Arena.INLAY_GRID
   var top=baseline+Model.Arena.PAD_RISE+.047
   var deepest=top;var tilted=0
   for vertex_index in range(first,first+Model.Arena.INLAY_GRID*Model.Arena.INLAY_GRID):
    deepest=minf(deepest,emblem_vertices[vertex_index].y)
    if emblem_normals[vertex_index].y<.9:tilted+=1
    check_surface_bounds(emblem_vertices[vertex_index].y,top)
   check(absf(emblem_vertices[first].y-top)<.01,"Original colored art keeps a sealed rim on its raised platform")
   check(top-deepest>Model.Arena.CARVE_DEPTH*.9 and tilted>100,"The original crest, letters and rings have genuine recessed geometry and beveled normals")
   check(top-deepest>=1.4 and deepest>baseline,"Deep cuts stay clearly recessed without piercing the raised stone base")
   var ray=PhysicsRayQueryParameters3D.create(Vector3(p.x,30,p.y),Vector3(p.x,-10,p.y),1)
   var hit=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
   check(not hit.is_empty() and absf(hit.position.y-expected)<.01,"The physical raised platform matches native slime terrain")
   check(native.native.can_reach(game.model.point(Vector2i(0,3)),Vector3(p.x,expected,p.y),3.9),"Slimes can walk onto each colored platform")
   emblem_index+=1
  for portal in model.portals:
   var p=game.model.waves.slime_entry(Vector3(portal.x,0,portal.z).normalized(),Vector3.ZERO)
   p.y=game.model.surface_height(p.x,p.z)
   check(native.native.can_reach(p,game.model.point(Vector2i(0,3)),3.9),"Native slimes have an unbroken route through each entrance")
   var from=Transform3D(Basis.IDENTITY,p+Vector3.UP*.1)
   check(not game.player.test_move(from,-p.normalized()*30),"The real player collider fits through the entrance")
  native.free()
  var edge=model.terrain.arena_bounds().end+Vector2.ONE*6
  var point=Vector3(edge.x,0,edge.y)
  check(not model.waves.navigation.move_clear(point,3.9) and game.world.playable_bounds==model.terrain.arena_bounds(),"The arena boundary limits native and player movement")
  for p in [Vector2(0,18),Vector2(-48,60),Vector2(70,-75),Vector2(0,150)]:
   var ray=PhysicsRayQueryParameters3D.create(Vector3(p.x,30,p.y),Vector3(p.x,-10,p.y),1)
   var hit=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
   check(not hit.is_empty() and absf(hit.position.y-game.model.surface_height(p.x,p.y))<.01,"Physical platform/carpet support matches the native height field at "+str(p))
  game.open_map_editor();await frames(2)
  check(game.map_editor.active and game.map_editor.document.data.terrain_detail==Model.Arena.ID,"Editor keeps the arena terrain")
  var preview_walls:Array=game.model.get_meta("cave_combat_walls",[])
  check(preview_walls==wall_boxes,"Reusing the arena in the editor preserves its native wall cover")
  game.map_editor.close_discard();await frames(2)
  check(not game.forest_ui.map_size_controls.visible and not game.resize_preparation_map(1),"Fixed arena sizes do not expose the valley lawn expansion control")
  if DisplayServer.get_name()!="headless":
   game.forest_ui.hide();game.ui.hide()
   var camera:Camera3D=game.camera_rig.camera
   camera.size=radius*2.1;camera.global_position=Vector3(0,600,600);camera.look_at(Vector3.ZERO)
   await frames(4);await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+("large" if model.terrain_scale==3 else "standard")+"-overview.png")
   camera.size=radius*.95;camera.global_position=Vector3(85,220,180);camera.look_at(Vector3(0,4,0))
   await frames(4);await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+("large" if model.terrain_scale==3 else "standard")+"-gate.png")
   camera.size=radius*.75;camera.global_position=Vector3(200,100,200);camera.look_at(Vector3(0,3,0))
   await frames(4);await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+("large" if model.terrain_scale==3 else "standard")+"-platforms.png")
   camera.size=200;camera.global_position=Vector3(-230,35,190);camera.look_at(Vector3(-110,5,60))
   await frames(4);await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+("large" if model.terrain_scale==3 else "standard")+"-platform-close.png")
   var scale_:float=model.terrain_scale*2.0
   var center=(Model.Arena.SOURCE_ORIGIN+Vector2(22,108)*3.0-Model.Arena.CENTER)*scale_
   var top:float=model.surface_height(center.x,center.y)
   camera.size=Model.Arena.INLAY_SIZE*scale_*1.25
   camera.global_position=Vector3(center.x+18,top+32,center.y+48);camera.look_at(Vector3(center.x,top,center.y))
   await frames(4);await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+("large" if model.terrain_scale==3 else "standard")+"-carved-pattern.png")
   camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=90
   for index in bays.size():
    var bay:Node3D=bays[index]
    camera.fov=75
    camera.global_position=bay.to_global(Vector3(20,9,-65));camera.look_at(bay.to_global(Vector3(0,11,12)))
    await frames(4);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OUT+"Wall Infill/"+("large" if model.terrain_scale==3 else "standard")+"-gate-%d.png"%index)
    camera.global_position=bay.to_global(Vector3(70,18,-100));camera.look_at(bay.to_global(Vector3(95,39,-3)))
    await frames(4);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OUT+"Wall Decoration/"+("large" if model.terrain_scale==3 else "standard")+"-wall-%d.png"%index)
   camera.fov=90
   camera.global_position=Vector3(0,12,100);camera.look_at(Vector3(0,wall_height*.7,-150))
   await frames(4);await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+("large" if model.terrain_scale==3 else "standard")+"-open-sky.png")
  var cfg=game.settings_path;stop_audio(game);current_scene=null;game.queue_free();paused=false;await frames(3)
  DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 # Saved valleys remain loadable; the new preset never rewrites user maps.
 var legacy=Document.new(false)
 check(legacy.read_file("res://tests/forest-shrine/reference/maps/forest_wind_meadow_valley.json").is_empty() and not legacy.data.has("terrain_detail"),"The previous valley remains a compatible excluded fixture")
 print("ARENA_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func check_surface_bounds(height:float,top:float):
 assert(height<=top+.001 and height>=top-Model.Arena.CARVE_DEPTH-.001,"Carving must only recess into the stone")

