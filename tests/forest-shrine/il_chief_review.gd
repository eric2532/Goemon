extends "res://tests/forest-shrine/east_region_review.gd"
## Same source axis plus two reachable normal-camera views, preserving the existing village owner.
const Chief=preload("res://scripts/forest/forest_il_chief.gd")
const FOLDER="res://build/Other Files/Asset Toolkit/East Gate Region/Il Chief/"
var anchor_cells={}

func _initialize():
 create_timer(600,true,false,true).timeout.connect(func():printerr("IL_CHIEF_REVIEW_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 root.size=Vector2i(1440,900);phase="IlChief"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 await source_axis()
 if "--source-only" in OS.get_cmdline_user_args():
  report();quit(1 if errors else 0);return
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/il-chief-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true
 game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 await open_area("east_gate");await site(2000,"il_village")
 var owner=game.world.find_child("BlueCGVillageBuilding_11268",true,false)
 check(owner!=null and owner.has_meta("source_inferred"),"Il chief uses recovered solid module through the existing village owner")
 if owner!=null:
  captures.append({"owner":"Il village","source_map":2000,"source_object_cell":[48,86],"source_footprint":[6,7],"source_door_cell":[47,83],"owner_transform":var_to_str(owner.global_transform),"falan_scale":game.model.falan_scale,"mesh_aabb":var_to_str(owner.mesh.get_aabb()),"inferred":owner.get_meta("source_inferred","")})
 var near=walkable_anchor(Vector2i(47,91))
 var second=walkable_anchor(Vector2i(39,81))
 var far=walkable_anchor(Vector2i(41,43))
 check(connected_anchors(near,second) and connected_anchors(near,far),"Both review corners and the farther view share the original village walk component")
 await village_landmark("chief-gameplay",Vector2(near),Vector2(second),Vector2(51,83))
 await position_at(village_cell(far))
 var facing=(village_cell(Vector2i(51,83))-village_cell(far)).normalized()
 await gameplay_capture("chief-distant-gameplay","ordinary camera at connected walk-grid source cell "+str(far),atan2(-facing.x,-facing.y))
 await fixed_village_view("chief-front-relief",near,Vector2(51,83))
 await fixed_village_view("chief-second-relief",second,Vector2(51,83))
 # A source-axis camera in the actual village confirms the standalone fit survives the owner's transform.
 var target=owner.global_transform*Vector3(1.265625,11.92654,1.265625) if owner!=null else village_world(Vector3(17.765625,11.92654,70.265625),"il_village")
 var camera:Camera3D=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=54.0*game.model.falan_scale
 var direction=owner.global_basis.orthonormalized()*Vector3(-1,1.603567,1).normalized() if owner!=null else Vector3(-1,1.603567,1).normalized()
 await fixed_source_capture("chief-village-source-axis",target+direction*130*game.model.falan_scale,target)
 report()
 print("IL_CHIEF_REVIEW_RESULT checks=",checks," failures=",errors," captures=",captures.size())
 await finish()

func village_cell(cell:Vector2i)->Vector2:
 var origin:Vector2=Tour.Regions.Sites.VILLAGES.il_village[2]
 return Tour.Regions.village_transform("il_village")*(origin+Vector2(cell)*3.0)

func open_cell(cell:Vector2i)->bool:
 if cell.x<0 or cell.y<0 or cell.x>=90 or cell.y>=120:return false
 if not anchor_cells.has(cell):
  var p=village_cell(cell)
  anchor_cells[cell]=game.model.terrain.disk_clear(Vector3(p.x,0,p.y),.55)
 return anchor_cells[cell]

func walkable_anchor(preferred:Vector2i)->Vector2i:
 for distance in 8:
  for y in range(-distance,distance+1):
   for x in range(-distance,distance+1):
    if maxi(absi(x),absi(y))!=distance:continue
    var cell=preferred+Vector2i(x,y)
    if open_cell(cell):return cell
 check(false,"No original walk-grid anchor near "+str(preferred));return preferred

func connected_anchors(start:Vector2i,end:Vector2i)->bool:
 var queue=[start];var seen={start:true};var cursor=0
 while cursor<queue.size():
  var cell:Vector2i=queue[cursor];cursor+=1
  if cell==end:return true
  for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next:Vector2i=cell+direction
   if not seen.has(next) and open_cell(next):seen[next]=true;queue.append(next)
 return false

func fixed_village_view(label:String,cell:Vector2i,target_cell:Vector2):
 var at=village_cell(cell);var target_at=village_cell(Vector2i(target_cell))
 var target=game.model.world_point(target_at)+Vector3.UP*8.5*game.model.falan_scale
 # Fixed camera is anchored over the verified reachable corner; no geometry-only stage substitutes for the village.
 var eye=game.model.world_point(at)+Vector3.UP*32*game.model.falan_scale
 await fixed_capture(label,eye,target,"fixed camera above verified source walk-grid corner "+str(cell))

func source_axis():
 var viewport=SubViewport.new();viewport.size=Vector2i(688,1044)
 viewport.own_world_3d=true;viewport.transparent_bg=false
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage=Node3D.new();viewport.add_child(stage)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("273039")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.9
 stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=.65;stage.add_child(light)
 var building=Chief.build(stage,Vector3.ZERO,true)
 var source_mesh=Chief.prepare();var points=source_mesh.get_aabb();var triangles=0
 for surface in source_mesh.get_surface_count():triangles+=source_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size()/3
 check(points.size.y>32 and points.size.y<40,"Chief roof and original rooster retain the city-camera source scale")
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=522.0/(sqrt(2.0)*32.0/3.0);stage.add_child(camera)
 var target=Vector3(27.0/(2*32.0/3.0),119.0/Chief.VERTICAL,27.0/(2*32.0/3.0))
 camera.position=target+Vector3(-1,1.603567,1).normalized()*100
 camera.look_at(target);camera.current=true
 if DisplayServer.get_name()!="headless":
  for i in 8:await process_frame
  await RenderingServer.frame_post_draw
  check(viewport.get_texture().get_image().save_png(FOLDER+"chief-source-axis.png")==OK,"Saved native-axis comparison capture")
 captures.append({"name":"chief-source-axis","camera":var_to_str(camera.transform),"orthographic_size":camera.size,"pixels_per_world":sqrt(2.0)*32.0/3.0,"reference_only_height_frame":"City Euclidean source-axis fit before the established village .045world/pixel vertical adaptation","actual_village_y_scale":Chief.VILLAGE_HEIGHT,"native_master":"build/Other Files/Asset Toolkit/Il and Laruka/Source/11268.png","model_bounds":var_to_str(points),"triangles":triangles,"mesh_surfaces":source_mesh.get_surface_count(),"mesh_instances":1,"source_sprite_instances":1,"inferred":building.get_meta("source_inferred")})
 viewport.queue_free()
 for i in 4:await process_frame

func fixed_source_capture(label:String,eye:Vector3,target:Vector3):
 if DisplayServer.get_name()=="headless":return
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.reset_physics_interpolation()
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(FOLDER+label+".png")==OK,"Saved source-axis camera in actual village")
 captures.append({"name":label,"camera":var_to_str(camera.global_transform),"orthographic_size":camera.size,"falan_scale":game.model.falan_scale})
 game.set_process(true);game.ui.show()

func report():
 var file=FileAccess.open(FOLDER+"review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"captures":captures,"observations":observations,"verified_scope":"Derivative SHA/currentness, source-axis and actual village normal/second reachable camera capture fixture. Visual approval requires image inspection.","inferred_visuals":["Stone-block depth and cap bevels","Thatch thickness and hidden slopes","Complete rear plaster/timber and source-style window rhythm","Thin vane/sign depth"],"unchanged_owners":["Original placement and6x7footprint","Existing village collider","Source doorway47,83","NPCs, quest gates, routes and interiors"]},"  "));file.close()
