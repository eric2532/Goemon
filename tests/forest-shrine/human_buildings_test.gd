extends SceneTree
## Real Wind Meadow art, save compatibility, shared resources and style lifecycle.
class Battle extends "res://scripts/forest/forest_game.gd":
 func _sync_camera_mouse():
  if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const OUT="res://build/Other Files/Asset Toolkit/Warcraft Human Buildings Review/Gameplay/"
var checks=0
var failures=0
var game
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: building review timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func shapes(world)->Array:
 var result=[]
 for node in world.structure_nodes.values():
  for shape in node.find_children("*","CollisionShape3D",true,false):result.append(shape.get_instance_id())
 result.sort();return result
func art(node:Node)->MeshInstance3D:return node.find_children("*","MeshInstance3D",true,false)[0]
func run():
 for asset in ["barracks","watchtower","barracks_ruins","tower_ruins"]:
  var scene=load(Meadow.DIR+"buildings/"+asset+".glb").instantiate()
  var mesh=art(scene)
  check(scene.find_children("*","MeshInstance3D",true,false).size()==1,asset+" has one shared static mesh")
  check(mesh.mesh.get_surface_count()<=(2 if asset in ["barracks","watchtower"] else 3),asset+" retains its small shared material budget")
  check(scene.find_children("*","Skeleton3D",true,false).is_empty() and scene.find_children("*","AnimationPlayer",true,false).is_empty(),asset+" has no per-building animation runtime")
  check(mesh.mesh.get_aabb().position.y>=-.001,asset+" excludes buried native foundations")
  if asset in ["barracks","watchtower"]:
   check(scene.has_node("DeckCenter") and scene.has_node("Entrance"),asset+" retains original anchor names")
   check(is_equal_approx(scene.get_node("DeckCenter").position.y,6 if asset=="barracks" else 20),asset+" retains occupied deck height")
   var bounds=mesh.mesh.get_aabb()
   check(bounds.size.x<18 if asset=="barracks" else bounds.size.x<12,asset+" fits its existing grid footprint")
  scene.free()
 check(preload("res://scripts/forest/forest_ui.gd").LABELS.barracks=="Farm","Build menu calls the existing barracks save key Farm")
 check(preload("res://scripts/forest/forest_map_editor.gd").LABELS.barracks=="Farm","Map editor uses Farm without changing saved map IDs")
 root.size=Vector2i(1280,800);root.title="Goemon · Human Farm and Guard Tower"
 set_meta("forest_painterly_preview",true);set_meta("forest_fighter",1)
 game=Battle.new();game.settings_path="user://human-buildings-test-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 10:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 var m=game.model;var world=game.world
 check(m.terrain_source=="wind_meadow" and m.has_enemy_castles(),"Real playable valley keeps its four enemy castles")
 var cell=Vector2i(9999,9999)
 m.gold=10000
 for z in range(-5,6):
  for x in range(-5,6):
   var candidate=Vector2i(x,z)
   if cell.x==9999 and m.placement_error("barracks",candidate,0).is_empty():cell=candidate
 check(cell.x!=9999,"A farm can be placed through normal validation")
 if cell.x==9999:finish();return
 var food=m.food_capacity();var money=m.gold
 var farm:Dictionary=m.build("barracks",cell,0);world.sync(0)
 check(farm.kind=="barracks" and m.food_capacity()==food+5 and m.gold==money-250,"Farm preserves existing saved kind, five capacity and 250 gold cost")
 var farm_node:Node3D=world.structure_nodes[farm.id]
 var tower:Dictionary=m._make_building("tower",Vector2i(-4,8),0);m.rebuild_navigation();m.revision+=1;world.sync(0)
 var tower_node:Node3D=world.structure_nodes[tower.id]
 for node in [farm_node,tower_node]:
  var visual:Node3D=node.get_node("WindMeadowAsset")
  check(art(visual).is_visible_in_tree(),"Imported Human building remains visible in painterly mode")
  var paint=art(visual).get_active_material(0)
  check(paint is ShaderMaterial and paint.get_shader_parameter("surface_kind")==5 and paint.get_shader_parameter("base_texture")!=null,"Original painted texture reuses Goemon's painterly shader")
 check(world.painterly_pilot.scenery==null,"Valley retains its native scenery instead of adding the older procedural buildings")
 var second:Node3D=Meadow.building(Node3D.new(),"watchtower")
 check(art(second).mesh==art(tower_node.get_node("WindMeadowAsset")).mesh,"Tower placements share the imported mesh")
 second.get_parent().free()
 var collisions=shapes(world);var state=m.buildings.duplicate(true)
 for i in 4:
  world.set_painterly_preview(false);await process_frame
  world.set_painterly_preview(true);await process_frame
 check(shapes(world)==collisions and m.buildings==state,"Repeated style changes preserve collision identities, placement and health")
 var resources=Meadow.building_style.materials.size()
 for i in 4:m.revision+=1;world.sync(0)
 check(Meadow.building_style.materials.size()==resources,"Routine updates do not duplicate shared painted materials")
 world.show_preview("barracks",cell+Vector2i(4,0),1,true)
 check(art(world.ghost_art.get_node("WindMeadowAsset")).mesh==art(farm_node.get_node("WindMeadowAsset")).mesh,"Farm placement ghost shares the real exported art")
 world.preview.hide();world.sight_ring.hide()
 var worker:Dictionary=m.workers.values()[0];m.workforce.release_job(worker)
 farm.hp-=100;var hp:float=farm.hp;money=m.gold
 check(m.workforce._assign(worker,farm),"Farm accepts the existing interior repair job")
 worker.pos=m.point(m.entry(farm));worker.timer=0;m.workforce.repairs.tick(worker,farm,.25)
 check(is_equal_approx(farm.hp,hp+12.5) and m.gold==money-1,"Farm preserves current repair health, cost and interval")
 farm.hp=farm.max_hp
 m.workforce.release_job(worker)
 check(not m.workforce._assign(worker,tower),"Automatic Guard Tower does not accept a worker job")
 world.sync(0)
 check(worker.job==-1 and m.workforce.count_job(tower.id)==0,"Worker stays available outside the Guard Tower")
 if DisplayServer.get_name()!="headless":
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));game.forest_ui.hide();DisplayServer.window_move_to_foreground()
  var fp:Vector3=m.center(farm)
  await shot("farm-front",fp+Vector3(24,16,28),fp+Vector3(0,3,0),47)
  await shot("farm-back",fp+Vector3(-24,14,-26),fp+Vector3(0,3,0),47)
  var tp:Vector3=m.center(tower)
  var inward=Vector3(-tp.x,0,-tp.z).normalized()
  await shot("guard-tower",tp+inward*32+Vector3.UP*29,tp+Vector3(0,15,0),48)
  await shot("guard-tower-crew",tp+inward*18+Vector3.UP*26,tp+Vector3(0,21,0),48)
  await shot("castle-overview",Vector3(120,95,140),Vector3(0,11,0),58)
  await build_angle_shot("build-angle-current",Vector3(0,160,110))
  await build_angle_shot("build-angle-proposed",Vector3(55,150,118))
  var objective=game.enemy_objectives[0];var enemy_pos:Vector3=objective.global_position
  await shot("enemy-farm",enemy_pos+Vector3(23,15,30),enemy_pos+Vector3(0,3,0),48)
 m.workforce.release_job(worker);worker.state="idle";world.sync(0)
 check(world.worker_nodes[worker.id].get_node("WorkerBody").visible,"Recalling the crew restores the same pooled worker body")
 m._remove_building(farm.id);m.rebuild_navigation();m.revision+=1;world.sync(0)
 check(m.food_capacity()==food,"Removing a farm removes its housing through the existing owner")
 for i in 3:await process_frame
 check(Meadow.building_style.materials.size()==resources,"Removing a farm retains only the shared material cache")
 for i in 5:
  var reused:Dictionary=m.build("barracks",cell,i%4);world.sync(0)
  check(not reused.is_empty(),"Farm can be rebuilt at every rotation")
  m._remove_building(reused.id);m.rebuild_navigation();m.revision+=1;world.sync(0)
  for frame in 3:await process_frame
 check(Meadow.building_style.materials.size()==resources and world.structure_nodes.size()==m.buildings.size(),"Repeated building/removal retains one material cache and no old structure nodes")
 finish()
func shot(file:String,eye:Vector3,focus:Vector3,fov:float):
 var camera:Camera3D=game.camera_rig.camera;camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.global_position=eye;camera.look_at(focus);camera.fov=fov;camera.far=2000
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+file+".png"))
func build_angle_shot(file:String,offset:Vector3):
 var camera:Camera3D=game.camera_rig.camera;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=170;camera.far=2000
 camera.global_position=offset;camera.look_at(Vector3.ZERO)
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+file+".png"))
func finish():
 if is_instance_valid(game):game.queue_free();await process_frame
 print("HUMAN_BUILDINGS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
