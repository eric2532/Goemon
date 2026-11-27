extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
const REVIEW="res://build/Other Files/Asset Toolkit/South Gate Kili Route/"
const STAGES=[
 ["city",0,1000,"法蘭城 South Gate",Vector2(312,0),Vector2(321,0)],
 ["south_gate",0,100,"South Gate approach",Vector2(3,171),Vector2(144,345)],
 ["interior",11000,11000,"維諾亞洞窟 法蘭側1F",Vector2(-30,-78),Vector2(-30,57)],
 ["interior",11001,11001,"維諾亞洞窟2F",Vector2(-18,-108),Vector2(-48,93)],
 ["interior",11002,11002,"維諾亞洞窟 維諾亞側1F",Vector2(15,-90),Vector2(-12,72)],
 ["south_lakes",0,100,"維諾亞 road",Vector2(1326,1047),Vector2(1029,1491)],
 ["interior",15005,15005,"索奇亞海底洞窟 芙蕾雅側1F",Vector2(-15,-60),Vector2(9,27)],
 ["interior",15003,15003,"索奇亞海底洞窟2F",Vector2(57,48),Vector2(-9,-3)],
 ["interior",15004,15004,"索奇亞海底洞窟 索奇亞側1F",Vector2(27,-36),Vector2(-12,57)],
 ["sokia_coast",0,300,"Sokia Coast",Vector2(720,795),Vector2(822,882)],
 ["kili",3200,3200,"其利村 reachable streets",Vector2(-48,-87),Vector2(3,-6)]
]
var captures=[]
var inventory=[]
var phase="Before"
func _initialize():
 create_timer(1200).timeout.connect(func():printerr("SOUTH_KILI_REVIEW_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 phase="After" if "--after" in OS.get_cmdline_user_args() else "Before"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-south-kili-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.run_seed=341
 for i in STAGES.size():
  var stage:Array=STAGES[i];print("SOUTH_KILI_REVIEW_ENTER ",i," ",stage[0]," ",stage[1])
  var layout=Tour.Indoor.layout(stage[1]) if stage[0]=="interior" else Tour.Regions.layout(stage[0]) if stage[0]!="city" else Tour.outdoor_layout(get_meta("falan_venture"),"city")
  layout.seed=341
  var at:Vector2=stage[4]
  if stage[0] in ["south_lakes","sokia_coast"]:at=Tour.Regions.frame(stage[0]).inverse()*at
  Tour.travel(game,layout,{"arrival":at,"yaw":0.,"velocity":Vector3.ZERO})
  for tick in 6:await physics_frame
  game.paused=false;game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
  var info={"key":"%02d-%s-%d"%[i,stage[0],stage[1]],"area":stage[0],"floor":stage[1],"source":stage[2],"title":stage[3],"entry":v(at),"links":game.model.get_meta("falan_links",[])}
  var mask:Image
  var origin:Vector2
  var size_:Vector2i
  var bits:PackedByteArray
  if stage[0]=="interior":
   var f=Tour.Indoor.floor_info(stage[1]);origin=f[1];size_=f[0];bits=f[2].hex_decode()
   mask=Image.create(size_.x,size_.y,false,Image.FORMAT_RGB8)
   for y in size_.y:
    for x in size_.x:
     var n=y*size_.x+x;mask.set_pixel(x,y,Color(0,1,0) if bits[n>>3]&(1<<(n&7)) else Color(1,0,0))
  else:
   mask=game.model.terrain.mask_texture().get_image();origin=game.model.terrain.mask_origin();size_=mask.get_size()
  info.origin=v(origin);info.size=[size_.x,size_.y];info.mask_sha256=mask.get_data().hex_encode().sha256_text()
  mask.save_png(REVIEW+phase+"/"+info.key+"-mask.png")
  info.npcs=[]
  var group=game.world.find_child("OriginalFalanNPCs",true,false)
  if group!=null:
   for npc in group.get_children():info.npcs.append({"name":npc.get_meta("npc_name",""),"at":v(Vector2(npc.position.x,npc.position.z))})
  inventory.append(info)
  for which in 3:
   var end:Vector2=stage[5]
   if stage[0] in ["south_lakes","sokia_coast"]:end=Tour.Regions.frame(stage[0]).inverse()*end
   var sample=at if which==0 else end if which==2 else at.lerp(end,.5)
   sample=safe_point(sample,mask,origin)
   await normal_view(info.key+"-%d"%which,sample,atan2(-(end-at).x,-(end-at).y),info)
  if phase=="After" and stage[0] in ["south_lakes","sokia_coast"]:
   var roads=preload("res://assets/maps/falan/undersea_entrances.gd")
   var road:Array=roads.VENOA_ROADS.bear_to_sea if stage[0]=="south_lakes" else roads.KILI_ROAD
   for sample_index in [1,2,3]:
    var index=int((road.size()-1)*sample_index/4.)
    var p:Vector2=Tour.Regions.frame(stage[0]).inverse()*(Vector2(road[index])*3.)
    var next:Vector2=Tour.Regions.frame(stage[0]).inverse()*(Vector2(road[mini(index+4,road.size()-1)])*3.)
    await normal_view(info.key+"-road-%d"%sample_index,p,atan2(-(next-p).x,-(next-p).y),info)
  var file=FileAccess.open(REVIEW+phase+"/inventory.json",FileAccess.WRITE);file.store_string(JSON.stringify(inventory,"  "));file.close()
  file=FileAccess.open(REVIEW+phase+"/cameras.json",FileAccess.WRITE);file.store_string(JSON.stringify(captures,"  "));file.close()
 print("SOUTH_KILI_REVIEW_RESULT maps=",inventory.size()," captures=",captures.size()," failures=",errors)
 game.queue_free();await process_frame;quit(1 if errors else 0)
func v(p:Vector2)->Array:return [p.x,p.y]
func safe_point(p:Vector2,mask:Image,origin:Vector2)->Vector2:
 var best=p;var distance=INF
 var center=Vector2i(((p-origin)/3.).round())
 for y in range(maxi(0,center.y-12),mini(mask.get_height(),center.y+13)):
  for x in range(maxi(0,center.x-12),mini(mask.get_width(),center.x+13)):
   if mask.get_pixel(x,y).r>.5:continue
   var at=origin+Vector2(x,y)*3
   if at.distance_squared_to(p)<distance:best=at;distance=at.distance_squared_to(p)
 return best
func normal_view(key:String,at:Vector2,yaw:float,info:Dictionary):
 game.player.position=game.model.world_point(at,.15);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
 game.model.hero_position=game.player.position;game.world.sync(0)
 game.camera_rig.yaw=yaw;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(1.,true);game.camera_rig.set_process(false)
 var camera:Camera3D=game.camera_rig.camera
 if phase=="After":
  for p in JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"Before/cameras.json")):
   if p.name==key:camera.global_position=Vector3(p.eye[0],p.eye[1],p.eye[2]);camera.global_rotation=Vector3(p.rotation[0],p.rotation[1],p.rotation[2])
 for c in game.get_children():
  if c is CanvasLayer:c.hide()
 for tick in 4:await process_frame
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png(REVIEW+phase+"/"+key+".png")
 captures.append({"name":key,"area":info.area,"floor":info.floor,"at":v(at),"eye":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"rotation":[camera.global_rotation.x,camera.global_rotation.y,camera.global_rotation.z],"fov":camera.fov})
