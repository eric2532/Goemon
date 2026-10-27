extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Kits=preload("res://scripts/forest/crowd/army_kit_data.gd")
var checks=0
var failures=0
var game
var runtime
var handles=[]
var output="res://build/Other Files/Enemy Assault"
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
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
    if state.external_kind==2 and targets.ids.has(state.external_target) and not allowed.has(state.external_target):invalid[state.logical_id]=state.external_target
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
 runtime=Runtime.new();root.add_child(runtime);check(runtime.configure(null),"Native runtime initializes")
 var kits=Kits.from_model(model);runtime.configure_kits(kits)
 game.crowd.army.configure_profiles(kits);game.crowd.army.use_native_buffers(runtime.native)
 DirAccess.make_dir_recursive_absolute(output)
 var targets:Dictionary=game.army_runtime.external_targets();var gates=[];var shrine_id:int=model.shrine().id
 for i in targets.ids.size():
  if targets.kinds[i]!=2:targets.targetable[i]=0
  var building:Dictionary=model.buildings.get(targets.ids[i],{})
  if targets.kinds[i]==2 and building.get("kind","")=="gate":
   gates.append(targets.ids[i]);check(targets.assault_priority[i]==1,"Live main-castle gate receives breach priority")
  if targets.kinds[i]==2 and targets.ids[i]==shrine_id:check(targets.assault_priority[i]==2,"Live shrine receives assault priority")
 check(not gates.is_empty(),"Real castle has a closed gate")
 runtime.set_navigation(model.navigation_revision,Runtime.navigation_data(model))
 for camp in 4:
  for kind in [0,1,3]:
   var point:Vector3=model.waves.routes.exit_point(model.portals[camp],kind);point.y=model.surface_height(point.x,point.z)
   handles.append(runtime.spawn(100+camp*10+kind,0,kind,point,100000,1.3))
 var closed:Dictionary=await assault(targets,gates)
 await capture("gate",targets,closed)
 for handle in handles:
  var state:Dictionary=runtime.unit_state(handle)
  check(closed.hits.has(state.logical_id),"Troop %d from its real enemy base reaches and damages a castle gate"%state.logical_id)
 check(closed.invalid.is_empty(),"Assault stays directed at the main castle while its gate is closed")
 for id in gates:model.buildings[id].breached=true
 model.rebuild_navigation()
 targets=game.army_runtime.external_targets()
 for i in targets.ids.size():
  if targets.kinds[i]!=2:targets.targetable[i]=0
 runtime.set_navigation(model.navigation_revision,Runtime.navigation_data(model))
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
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"closed":closed,"opened":opened,"player":player_assault,"resumed":resumed},"  "));file.close()
 runtime.clear();runtime.queue_free();game.queue_free()
 for i in 3:await process_frame
 print("ENEMY_CASTLE_PATHING_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
func capture(label_:String,targets:Dictionary,result:Dictionary):
 if DisplayServer.get_name()=="headless" or result.hits.is_empty():return
 var id:int=result.hits.values()[0];var at:int=targets.ids.find(id);var point:Vector3=targets.positions[at]
 game.camera_rig.camera.global_position=point+Vector3(24,30,34)
 game.camera_rig.camera.look_at(point+Vector3.UP*2)
 game.crowd.army.present(runtime.render_snapshot(),[])
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/assault-"+label_+".png")
