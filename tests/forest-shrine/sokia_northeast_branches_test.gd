extends "res://tests/forest-shrine/sokia_coast_branches_test.gd"
## Original northeast ports use the shared renderer and actual movement crossings.
const NORTHEAST_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Northeast caves/"
var cameras=[]
func physical_state()->Dictionary:
 var terrain=game.model.terrain;var shapes=[]
 for node in game.world.find_children("*","CollisionShape3D",true,false):
  var payload:Variant=node.shape.size if node.shape is BoxShape3D else node.shape.get_faces() if node.shape is ConcavePolygonShape3D else Vector2(node.shape.radius,node.shape.height) if node.shape is CapsuleShape3D or node.shape is CylinderShape3D else node.shape.radius if node.shape is SphereShape3D else node.shape.get_instance_id() if node.shape!=null else null
  shapes.append([node.get_instance_id(),node.transform,payload])
 return {"walk":var_to_bytes([terrain.heights,terrain.covered,terrain.bridges]).hex_encode().sha256_text(),"collision":var_to_bytes(shapes).hex_encode().sha256_text(),"ports":JSON.stringify(game.model.get_meta("falan_links",[])).sha256_text()}
func _initialize():
 create_timer(600).timeout.connect(func():printerr("SOKIA_NORTHEAST_TIMEOUT");quit(1))
 run.call_deferred()
func capture_view(name_:String,cell:Vector2i,toward:Vector2):
 if DisplayServer.get_name()=="headless":return
 game.set_physics_process(false);game.player.set_physics_process(false)
 var at=Original.source_point(game.model.falan_floor,cell) if game.model.falan_area=="interior" else Tour.Regions.frame(game.model.falan_area).inverse()*(Vector2(cell)*3.)
 game.player.position=game.model.world_point(at,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
 game.camera_rig.yaw=atan2(-toward.x,-toward.y);game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH
 game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT;game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.set_process(true)
 for i in 6:await process_frame
 game.camera_rig.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 cameras.append({"name":name_,"area":game.model.falan_area,"floor":game.model.falan_floor,"source_cell":[cell.x,cell.y],"seed":game.model.seed_value,"hour":game.explorer_clock.hour,"eye":var_to_str(camera.global_position),"rotation":var_to_str(camera.global_rotation),"fov":camera.fov,"projection":camera.projection})
 RenderingServer.force_draw();root.get_texture().get_image().save_png(NORTHEAST_OUT+name_+".png")
func run():
 root.size=Vector2i(1280,800)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NORTHEAST_OUT))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-sokia-northeast-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 var saved=JSON.stringify(get_meta("falan_venture"));var records=[]
 for port in [[760,59,15527,15,27],[755,81,15530,5,6]]:
  var id:int=port[2];var cell=Vector2i(port[0],port[1]);var arrival=Vector2i(port[3],port[4])
  var source="BlueCrossgate/map/0/%d.dat"%id
  check(Original.owns(id),"Original renderer owns northeast map "+str(id))
  check(Original.state(id).raw==Original.Art.raw_map(source),"All source map planes retained: "+str(id))
  check(Original.Art.data().warps.any(func(w):return Array(w).map(func(v):return int(v))==[300,port[0],port[1],id,port[3],port[4]]),"Source confirms outward northeast port "+str(id))
  check(Original.Art.data().warps.any(func(w):return Array(w).map(func(v):return int(v))==[id,port[3],port[4],300,port[0],port[1]]),"Source confirms reciprocal northeast port "+str(id))
  var area="ghana_north_road";var at=Tour.Regions.frame(area).inverse()*(Vector2(cell)*3.)
  Tour.travel(game,Tour.Regions.layout(area),{"arrival":at,"yaw":0.,"velocity":Vector3.ZERO})
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
  var links:Array=game.model.get_meta("falan_links",[]).filter(func(l):return int(l.get("site",-1))==id)
  check(links.size()==1 and links[0].at.distance_to(at)<.01,"One exact outdoor port in northeast source component: "+str(id))
  var before=physical_state()
  var material:ShaderMaterial=game.world.kai_materials.filter(func(m):return m.get_meta("sokia_northeast_clip",false)).front()
  var other=game.model.terrain.get_script().new();other.variant="city"
  Tour.Regions.Sokia.northeast_clip_material(material,other,true)
  check(material.get_shader_parameter("sokia_ne_clip")==false and material.get_shader_parameter("sokia_ne_entry")==Vector4.ZERO,"Reused actual ground material clears the northeast cut outside its map")
  Tour.Regions.Sokia.northeast_clip_material(material,game.model.terrain,true)
  var after=physical_state()
  for key in before:check(before[key]==after[key],"Source "+key+" stays unchanged by cave visual material setup")
  await capture_view(str(id)+"-mouth",cell+Vector2i.DOWN,Vector2.UP)
  if id==15527:
   var castle=game.world.find_child("SokiaNortheastCastle",true,false)
   check(castle!=null and castle.get_meta("original_source_anchor")==Vector2i(760,58),"Northeast castle reuses the complete existing source-matched solid at its original anchor")
   check(game.world.find_children("SokiaNativeProp_10011_*","MultiMeshInstance3D",true,false).is_empty(),"Floating upper-castle billboard is replaced once")
  if id==15530:
   var mouth=game.world.find_child("UnderseaMouth_755_81",true,false)
   check(mouth!=null and mouth.get_meta("sokia_native_aperture",false),"Recorded northeast cave mouth uses its traced original opening")
   await capture_view("15530-mouth-front",cell+Vector2i.LEFT*2,Vector2.RIGHT)
  var entered=await try_gate(at,"interior",id)
  check(entered,"Normal movement enters northeast source cave "+str(id))
  if not entered:continue
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  for i in 3:await process_frame
  check(game.world.map_features.get_meta("recovered_source_map")==id,"Shared solid renderer builds northeast room "+str(id))
  check(Tour.SouthPopulation.source_cell(game.model,Original.source_point(id,arrival))==arrival,"Source NPC/navigation frame agrees in "+str(id))
  var expected:Array=Tour.SouthPopulation.coast_data().npcs.filter(func(n):return int(n.source)==id)
  check(game.explorer_npcs.actors.size()==expected.size(),"Every prepared source NPC appears once: "+str(id))
  check(not Tour.SouthPopulation.encounters_own(game.model),"No random pool invented for a source scripted-fight room "+str(id))
  for wanted in [arrival+Vector2i.UP*2,Vector2i(15,15),Vector2i(20,9)]:
   await capture_view(str(id)+"-room-"+str(wanted.x)+"-"+str(wanted.y),Original.safe_cell(id,wanted),Vector2.UP)
  var exit=Original.source_point(id,arrival)
  var returned=false
  for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
   game.set_physics_process(true);game.player.set_physics_process(true)
   await walk_gate(exit,direction)
   if game.model.falan_area!="interior":returned=true;break
  check(returned,"Normal movement returns to source northeast component "+str(id))
  if returned:
   var actual=Tour.SouthPopulation.source_cell(game.model,Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale)
   check(Vector2(actual-cell).length()<3.,"Original outdoor return cell retained: "+str(id))
  records.append({"map":id,"source_sha256":Original.Art.data().maps[source].sha256,"source_actors":expected.map(func(n):return n.id),"entered":entered,"returned":returned,"scripted_fight":"Source trigger/quest contract remains pending; no unconditional fight invented."})
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Existing adventure data preserved")
 var mode="headless" if DisplayServer.get_name()=="headless" else "rendered"
 var file=FileAccess.open(NORTHEAST_OUT+"verification-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"maps":records,"cameras":cameras},"  "));file.close()
 print("SOKIA_NORTHEAST_RESULT maps=",records.size()," captures=",cameras.size()," checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
