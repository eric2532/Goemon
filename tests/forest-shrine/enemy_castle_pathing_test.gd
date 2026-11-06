extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Kits=preload("res://scripts/forest/crowd/army_kit_data.gd")
var checks=0
var failures=0
var game
var runtime
var handles=[]
var output="res://build/Other Files/Castle Defense AI/Enemy Assault"
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():
 if "--large" in OS.get_cmdline_user_args():
  set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow_large.json")))
  output+="/Large"
 run.call_deferred()
func assault(targets:Dictionary,allowed:Array,required:Array=[])->Dictionary:
 if required.is_empty():required=handles.map(func(h):return runtime.unit_state(h).logical_id)
 runtime.native.set_targets(targets)
 var hits={};var paths={};var invalid={}
 for tick in 9000:
  runtime.step(.05,{})
  for event in runtime.take_events():
   if event.kind=="external_damage" and allowed.has(event.target_id):hits[event.source_id]=event.target_id
  if tick%60==0:
   game.crowd.army.present(runtime.render_snapshot(),[])
   for handle in handles:
    var state:Dictionary=runtime.unit_state(handle)
    if not paths.has(str(state.logical_id)):paths[str(state.logical_id)]=[]
    paths[str(state.logical_id)].append([state.position.x,state.position.y,state.position.z])
    var row:int=targets.ids.find(state.external_target) if state.external_kind==2 else -1
    if row>=0 and targets.hp[row]>0:
     var edge:Vector3=state.position.clamp(targets.minimum[row],targets.maximum[row])
     var distant_defense:bool=targets.assault_priority[row]==4 and Vector2(state.position.x-edge.x,state.position.z-edge.z).length()>28.1
     if not allowed.has(state.external_target) or distant_defense:invalid[state.logical_id]=state.external_target
   await process_frame
  if required.all(func(id):return hits.has(id)):return {"hits":hits,"paths":paths,"invalid":invalid,"seconds":(tick+1)*.05}
 return {"hits":hits,"paths":paths,"invalid":invalid,"seconds":450}
func run():
 game=preload("res://scripts/forest/forest_game.gd").new();game.settings_path="user://enemy-pathing-test-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 5:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 game.camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera_rig.camera.fov=63
 game.ui.hide();root.title="Goemon · Enemy assault verification"
 var model=game.model;model.workers.clear();model.balance.enemy_size_mult=1.0
 check(model.terrain_source=="wind_meadow" and is_equal_approx(model.terrain_scale,3.0 if "--large" in OS.get_cmdline_user_args() else 2.0),"Requested Wind Meadow map size loads")
 runtime=Runtime.new();root.add_child(runtime);check(runtime.configure(null),"Native runtime initializes")
 var kits=Kits.from_model(model);runtime.configure_kits(kits)
 game.crowd.army.configure_profiles(kits);game.crowd.army.use_native_buffers(runtime.native)
 DirAccess.make_dir_recursive_absolute(output)
 var targets:Dictionary=game.army_runtime.external_targets();var gates=[];var military=[];var shrine_id:int=model.shrine().id
 for i in targets.ids.size():
  if targets.kinds[i]!=2:targets.targetable[i]=0
  var building:Dictionary=model.buildings.get(targets.ids[i],{})
  if targets.kinds[i]==2 and building.get("kind","")=="gate":
   gates.append(targets.ids[i]);check(targets.assault_priority[i]==1,"Live main-castle gate receives breach priority")
  if targets.kinds[i]==2 and targets.ids[i]==shrine_id:check(targets.assault_priority[i]==2,"Live shrine receives assault priority")
  if targets.kinds[i]==2 and building.get("kind","") in ["barracks","tower"]:
   military.append(building.id);check(targets.assault_priority[i]==4,"Military buildings receive local aggro priority")
 runtime.set_navigation(model.navigation_revision,Runtime.navigation_data(model))
 for camp in 4:
  for kind in [0,1,3]:
   var point:Vector3=model.waves.routes.exit_point(model.portals[camp],kind);point.y=model.surface_height(point.x,point.z)
   handles.append(runtime.spawn(100+camp*10+kind,0,kind,point,100000,1.3))
 # Isolate the main base from player, worker and defense distractions.
 var sealed=targets.duplicate(true)
 for i in sealed.ids.size():
  if sealed.ids[i]!=shrine_id:sealed.targetable[i]=0
 runtime.native.set_targets(sealed)
 var starts=handles.map(func(handle):return runtime.unit_state(handle).position.distance_to(model.center(model.shrine())))
 for tick in 600:
  runtime.step(.05,{})
  runtime.take_events()
  if tick%60==0:await process_frame
 for i in handles.size():
  var state:Dictionary=runtime.unit_state(handles[i])
  check(state.position.distance_to(model.center(model.shrine()))<starts[i]-5,"Troop %d advances toward the main base without a player target"%state.logical_id)
 var closed={};var defenses={}
 if not gates.is_empty():
  closed=await assault(targets,gates+military)
  await capture("gate",targets,closed)
  for handle in handles:
   var state:Dictionary=runtime.unit_state(handle)
   check(closed.hits.has(state.logical_id),"Troop %d damages a reachable defense or breaches its gate"%state.logical_id)
  check(closed.invalid.is_empty(),"Troops select reachable gates or local defenses")
  for id in gates:model.buildings[id].breached=true
  model.rebuild_navigation()
  targets=game.army_runtime.external_targets()
  for i in targets.ids.size():
   if targets.kinds[i]!=2:targets.targetable[i]=0
  runtime.set_navigation(model.navigation_revision,Runtime.navigation_data(model))
 if not military.is_empty():
  defenses=await assault(targets,military+[shrine_id])
  await capture("military",targets,defenses)
  for handle in handles:
   check(defenses.hits.has(runtime.unit_state(handle).logical_id),"Every troop advances to the castle or a nearby defense")
  check(defenses.invalid.is_empty(),"Open-castle assault selects shrine or local defense")
 for i in targets.ids.size():
  if targets.kinds[i]==2 and military.has(targets.ids[i]):targets.hp[i]=0
 var opened:Dictionary=await assault(targets,[shrine_id])
 await capture("shrine",targets,opened)
 for handle in handles:
  var state:Dictionary=runtime.unit_state(handle)
  check(opened.hits.has(state.logical_id),"Troop %d advances through the breach and damages the shrine"%state.logical_id)
 check(opened.invalid.is_empty(),"Breach releases gate targeting and selects the shrine")
 var hero_row:int=targets.kinds.find(0)
 targets.minimum[hero_row]=Vector3.ZERO;targets.maximum[hero_row]=Vector3.ZERO;targets.targetable[hero_row]=1
 var player_hits={};var player_assault=[]
 for direction in [Vector3.BACK,Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT]:
  var point:Vector3=model.center(model.shrine())+direction*18
  point.y=model.surface_height(point.x,point.z);game.player.position=point;targets.positions[hero_row]=point
  var nearby=[]
  for handle in handles:
   var state:Dictionary=runtime.unit_state(handle)
   if Vector2(state.position.x-point.x,state.position.z-point.z).length()<=28:nearby.append(state.logical_id)
  check(not nearby.is_empty(),"Player approaches living shrine attackers")
  var result:Dictionary=await assault(targets,[0],nearby)
  check(nearby.all(func(id):return result.hits.has(id)),"Every nearby troop leaves the shrine to damage the player")
  player_hits.merge(result.hits);player_assault.append(result)
  await capture("player-%d"%player_assault.size(),targets,result)
 for handle in handles:
  check(player_hits.has(runtime.unit_state(handle).logical_id),"Each troop attacks the player when approached")
 targets.targetable[hero_row]=0
 var resumed:Dictionary=await assault(targets,[shrine_id])
 check(resumed.hits.size()==handles.size(),"All troops resume shrine damage when the player becomes untargetable")
 var file=FileAccess.open(output+"/castle-routes.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"terrain_scale":model.terrain_scale,"closed":closed,"military":defenses,"opened":opened,"player":player_assault,"resumed":resumed},"  "));file.close()
 runtime.clear();runtime.queue_free();game.sound_library.cancel();game.music.stop();game.queue_free()
 for i in 3:await process_frame
 print("ENEMY_CASTLE_PATHING_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
func capture(label_:String,targets:Dictionary,result:Dictionary):
 if DisplayServer.get_name()=="headless" or result.hits.is_empty():return
 var id:int=result.hits.values()[0];var at:int=targets.ids.find(id);var point:Vector3=targets.positions[at]
 game.camera_rig.camera.global_position=point+Vector3(24,65,34)
 game.camera_rig.camera.look_at(point+Vector3.UP*2)
 game.crowd.army.present(runtime.render_snapshot(),[])
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/assault-"+label_+".png")
