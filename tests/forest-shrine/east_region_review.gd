extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Fixed baseline: normal city exit/return, then direct-spawn landmark reviews.
const REVIEW="res://build/Other Files/Asset Toolkit/East Gate Region/Verification/"
var checks=0
var observations=[]
var captures=[]
var phase="Recovered"

func _initialize():
 create_timer(600,true,false,true).timeout.connect(func():printerr("EAST_REGION_REVIEW_TIMEOUT");quit(1))
 run.call_deferred()

func check(ok:bool,message:String):
 checks+=1
 observations.append({"check":message,"passed":ok})
 super.check(ok,message)

func run():
 root.size=Vector2i(1440,900)
 root.title="Cross Gate · East Region Review"
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/east-region-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false
 game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false
 game.tuning.invincible=true
 game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 for i in 8:await physics_frame
 check(Tour.area(game.model)=="city","Normal title, Cross Gate fighter and Enter Map starts in Falan City")
 await normal_gate_round_trip()
 if "--gate-only" not in OS.get_cmdline_user_args():await baseline_landmarks()
 var file=FileAccess.open(REVIEW+phase+"/verification.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"scope":"East Gate normal on-foot exit and return; landmark direct spawns and fixed-camera baseline only. No complete region or visual-fidelity certification."},"  "));file.close()
 print("EAST_REGION_REVIEW_RESULT checks=",checks," failures=",errors," captures=",captures.size())
 await finish()

func normal_gate_round_trip():
 # Position once inside the city approach, then use actual player movement.
 await position_at(Vector2(-138,-273))
 game.camera_rig.yaw=0.0
 Input.action_press("move_forward")
 for i in 1500:
  await physics_frame
  if Tour.area(game.model)=="east_gate":break
 Input.action_release("move_forward")
 check(Tour.area(game.model)=="east_gate","Normal East Gate exit crosses from the Falan approach on foot")
 if Tour.area(game.model)!="east_gate":return
 var native=Tour.Regions.frame("east_gate")*map_position()/3.0
 check(native.distance_to(Vector2(475,196))<.20,"East Gate exit lands at original map 100 cell (475,196)")
 check(game.player.facing.dot(Vector3.BACK)>.99 and cos(game.camera_rig.yaw)<-.99,"East Gate arrival preserves outward player and camera direction")
 await gameplay_capture("east-gate-outward","normal exit",PI)
 var landing=map_position()
 await fixed_capture("east-gate-second-angle",game.model.world_point(landing+Vector2(9,4))+Vector3.UP*8,game.model.world_point(landing+Vector2(0,-9))+Vector3.UP*4,"fixed second angle from the walkable gate approach")
 game.camera_rig.yaw=PI
 Input.action_press("move_forward")
 for i in 18:await physics_frame
 Input.action_release("move_forward")
 check((Tour.Regions.frame("east_gate")*map_position()/3.0).x>475.3,"Forward continues east after the normal exit")
 game.camera_rig.yaw=0.0
 Input.action_press("move_forward")
 for i in 500:
  await physics_frame
  if Tour.area(game.model)=="city":break
 Input.action_release("move_forward")
 check(Tour.area(game.model)=="city","Walking back through the same East Gate returns to Falan")
 if Tour.area(game.model)=="city":
  check(map_position().distance_to(Vector2(-138,-372))<.40,"East Gate return uses original Falan map 1000 cell (277,88)")
  await gameplay_capture("falan-east-gate-return","normal return",PI)

func baseline_landmarks():
 await open_area("east_gate")
 var regions=Tour.Regions
 var source_points=[
  ["east-road-bridge",Vector2(552,233),PI],
  ["east-road-habaru-mouth",Vector2(669,225),-PI*.75],
 ]
 for row in source_points:
  var p=regions.frame("east_gate").inverse()*(row[1]*3.0)
  await position_at(p)
  check(game.model.terrain.disk_clear(Vector3(p.x,0,p.y),.55),"Baseline source-map 100 position is walkable: "+row[0])
  await gameplay_capture(row[0],"direct spawn at map 100 source cell "+str(row[1]),row[2])
 await site(2000,"il_village")
 await village_landmark("il-guild",Vector2(65,77),Vector2(78,81),Vector2(73,72))
 await village_landmark("il-chief",Vector2(47,88),Vector2(59,87),Vector2(51,83))
 for id in [11003,11004,11005]:
  var links=Tour.Regions.Sites.DOORS.get(id,[])
  var at:Vector2=Tour.Indoor.safe_point(id,links[0][0] if not links.is_empty() else Vector2.ZERO,game.model.seed_value)
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":at,"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 8:await physics_frame
  check(game.model.falan_floor==id,"Direct-spawn baseline loads existing Habaru floor "+str(id))
  check(game.model.terrain.disk_clear(Vector3(at.x,0,at.y),.55),"Existing Habaru arrival uses walkable source grid "+str(id))
  await gameplay_capture("habaru-"+str(id),"direct spawn; floor path and boss endpoint not verified",Tour.CAVE_FACING.get(id,{}).get(at,0.0))
 await open_area("north_coast")
 var south=regions.village_transform("alyut")*regions.ALYUT_SOUTH_GATE
 await position_at(south+Vector2(0,7))
 await gameplay_capture("alyut-south-gate","direct spawn on existing North Coast approach",0.0)
 await position_at(south+Vector2(-6,-9))
 await gameplay_capture("alyut-south-gate-second","direct spawn at alternate village approach",PI*.75)

func village_landmark(label:String,a:Vector2,b:Vector2,target:Vector2):
 var origin:Vector2=Tour.Regions.Sites.VILLAGES.il_village[2]
 var placement=Tour.Regions.village_transform("il_village")
 for i in 2:
  var local=origin+(a if i==0 else b)*3.0
  var p:Vector2=placement*local
  await position_at(p)
  var facing:Vector2=(placement*(origin+target*3.0)-p).normalized()
  check(game.model.terrain.disk_clear(Vector3(p.x,0,p.y),.55),"Landmark camera point is on original walk grid: %s/%d"%[label,i])
  await gameplay_capture(label+("-normal" if i==0 else "-second"),"direct spawn at Il source cell "+str(a if i==0 else b),atan2(-facing.x,-facing.y))

func gameplay_capture(label:String,method:String,yaw:float):
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=.32;game.camera_rig.reset_follow()
 for i in 18:
  await physics_frame
  game.camera_rig.update_camera(1.0/60.0)
 var camera:Camera3D=game.camera_rig.camera
 await fixed_capture(label,camera.global_position,camera.global_position-camera.global_basis.z*10,method)

func fixed_capture(label:String,eye:Vector3,target:Vector3,method:String):
 if DisplayServer.get_name()=="headless":return
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 game.ui.hide();game.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 camera.global_position=eye;camera.look_at(target);camera.reset_physics_interpolation()
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REVIEW+phase+"/"+label+".png")==OK,"Capture "+label)
 captures.append({"name":label,"area":Tour.area(game.model),"floor":game.model.falan_floor,"map_position":var_to_str(map_position()),"camera":var_to_str(camera.global_transform),"fov":camera.fov,"method":method})
 game.set_process(true);game.ui.show()
