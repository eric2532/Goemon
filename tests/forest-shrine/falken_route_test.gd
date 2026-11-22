extends "res://tests/forest-shrine/sokia_native_fronds_test.gd"
const Falken=preload("res://scripts/forest/crowd/falken_sprites.gd")
const ROUTE_REVIEW="res://build/Other Files/Asset Toolkit/Falken Tower/"
func _initialize():
 create_timer(600).timeout.connect(func():printerr("FALKEN_ROUTE_TIMEOUT");quit(1))
 run.call_deferred()
func shot(label_:String,eye:Vector3,target:Vector3,fov:float,_refresh:bool=false):
 if DisplayServer.get_name()=="headless":return
 var before=paused;paused=true;game.ui.hide();game.set_process(false)
 var labels=game.world.find_children("*","Label3D",true,false).filter(func(node):return node.visible)
 for label in labels:label.hide()
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.reset_physics_interpolation()
 for frame in 3:await process_frame
 RenderingServer.force_draw()
 var folder=ROUTE_REVIEW+"after/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 check(root.get_texture().get_image().save_png(folder+label_+".png")==OK,"Captured "+label_)
 for label in labels:label.show()
 game.set_process(true);game.ui.show();paused=before
func reachable_door(point:Vector3)->bool:
 if game.army_runtime.native.can_reach(game.player.position,point,.5):return true
 var id:int=game.model.falan_floor
 if not Falken.Route.owns(id):return false
 var info:Array=Falken.Route.floor_info(id);var size:Vector2i=info[0];var origin:Vector2=info[1]
 var mask=Tour.Indoor.walk_mask(id,size,info[2].hex_decode(),game.model.seed_value)
 var from=Vector2i(((map_position()-origin)/3.0).round())
 var goal=Vector2i(((Vector2(point.x,point.z)/game.model.falan_scale-origin)/3.0).round())
 var queue=[from];var seen={from:true}
 # The army's 6 m global grid can miss 3 m village alleys; prove each exact local segment.
 for cell:Vector2i in queue:
  if cell==goal:return true
  for direction:Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
   var next=cell+direction
   if not Rect2i(Vector2i.ZERO,size).has_point(next) or seen.has(next):continue
   var i=next.y*size.x+next.x
   if (mask[i>>3] & (1<<(i&7)))==0:continue
   var a=game.model.world_point(origin+Vector2(cell)*3.0);var b=game.model.world_point(origin+Vector2(next)*3.0)
   if not game.army_runtime.native.can_reach(a,b,.5):continue
   seen[next]=true;queue.append(next)
 return false
func follow(target:int,outside:bool=false):
 var source_floor:int=game.model.falan_floor
 var candidates=game.model.get_meta("falan_links",[]).filter(func(link):return link.to=="freyja_outside" if outside else link.get("site",link.get("floor",-1))==target)
 check(not candidates.is_empty(),"A visible playable doorway reaches "+str(target))
 if candidates.is_empty():return
 var link:Dictionary=candidates[0]
 var previous_model=game.model
 var point:Vector3=game.model.world_point(link.at)
 check(game.model.terrain.disk_clear(point/game.model.falan_scale,.5),"Doorway is on native walkable ground")
 check(reachable_door(point),"Current arrival connects to its next doorway "+str(source_floor)+" -> "+str(target))
 await position_at(link.at)
 if game.model==previous_model:await walk_through_entry()
 check(Tour.area(game.model)=="sokia_desert" if outside else game.model.falan_floor==target,"Walking through the doorway loads "+str(target))
 for i in 5:await physics_frame
func check_maze_contract():
 var signatures={}
 for id in Falken.Route.FLOORS:
  var info:Array=Falken.Route.floor_info(id);var size:Vector2i=info[0]
  check(size.x>=40 and size.x<=80 and size.y>=40 and size.y<=80,"Tower size follows the original 40–80 tile contract")
  var original:PackedByteArray=Falken.Route.maze(id,111).bits.duplicate()
  var other:PackedByteArray=Falken.Route.maze(id,222).bits.duplicate()
  check(original!=other and original==Falken.Route.maze(id,111).bits,"Every tower floor changes with the run seed and reproduces exactly")
  var maze=Falken.Route.maze(id,111);var queue=[maze.stairs[0]];var seen={queue[0]:true}
  for cell:Vector2i in queue:
   for direction:Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
    var next=cell+direction
    if not Rect2i(Vector2i.ZERO,size).has_point(next) or seen.has(next):continue
    var i=next.y*size.x+next.x
    if (original[i>>3] & (1<<(i&7)))==0:continue
    seen[next]=true;queue.append(next)
  check(seen.has(maze.stairs[1]) and maze.posts.size()>=80,"All tower stairs connect and each floor has a dense monster population")
  check(maze.posts.all(func(row):return row[1] in [1,2] and row[2]>=22 and row[2]<=25),"Tower monsters use the original two species and level range")
  signatures[id]=original.hex_encode().sha256_text()
 check(signatures.values().size()==16,"All sixteen floors retain independent identities")
func dialogue_key(code:int,pressed:bool):
 var event=InputEventKey.new()
 event.physical_keycode=code
 event.pressed=pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()
func tap_dialogue_key(code:int):
 dialogue_key(code,true)
 dialogue_key(code,false)
func talk_to_falken(review:bool=false):
 check(is_instance_valid(game.falken_waiting) and game.model.enemies.is_empty(),"Falken and the guards wait out of combat on entry")
 if not is_instance_valid(game.falken_waiting):return
 if review:
  game.model.waves.tick(.5,game.player.position)
  tap_dialogue_key(KEY_F)
  check(not is_instance_valid(game.dialogue) and game.model.enemies.is_empty(),"F outside range leaves the encounter idle")
 var at=Falken.Route.point(Falken.ROOM,Falken.Route.BOSS_CELL)
 await position_at(at+Vector2(0,6))
 check(game.falken_talk_hint.visible and game.can_talk_falken(),"The same-level approach shows F to talk")
 var passage_labels=game.world.map_features.find_children("*","Label3D",false,false).filter(func(label):return label.visible)
 var pet_serial=game.army_runtime.hound_order_serial
 tap_dialogue_key(KEY_F)
 var dialogue=game.dialogue
 check(is_instance_valid(dialogue) and game.army_runtime.hound_order_serial==pet_serial,"F opens the conversation without issuing a pet order")
 if not is_instance_valid(dialogue):return
 check(dialogue.speaker=="法爾肯" and dialogue.portrait.texture==game.FalkenPortrait and game.paused and paused,"The painted portrait and shared dialogue pause the encounter")
 check(not passage_labels.is_empty() and passage_labels.all(func(label):return not label.visible),"Passage signs stay out of the conversation")
 tap_dialogue_key(KEY_SPACE)
 if review and DisplayServer.get_name()!="headless":
  var out="res://build/Other Files/Asset Toolkit/Falken Dialogue/"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(out+"dialogue.png")==OK,"Captured the boss conversation in the game")
 check(dialogue.page==0 and game.model.enemies.is_empty(),"Revealing the first page leaves the fight idle")
 tap_dialogue_key(KEY_SPACE)
 check(dialogue.page==1 and game.paused and game.model.enemies.is_empty(),"The second page keeps combat paused")
 tap_dialogue_key(KEY_SPACE)
 dialogue_key(KEY_SPACE,true)
 await process_frame
 check(is_instance_valid(game.dialogue) and game.model.enemies.is_empty(),"Holding Space on the last page still blocks combat")
 dialogue_key(KEY_SPACE,false)
 for i in 6:await physics_frame
 check(game.falken_dialogue_seen and not game.falken_waiting.visible and not game.paused and not is_instance_valid(game.dialogue),"Final Space release starts the fight and restores the HUD")
 check(game.player.jump_buffer<=0 and game.player.velocity.y<=0,"The closing Space does not cause a jump")
 check(passage_labels.all(func(label):return label.visible),"Passage signs return when the fight begins")
 check(game.model.enemies.size()==6 and game.army_runtime.handles.size()>=6,"The boss and five guards spawn through native combat")
func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 check_maze_contract()
 check(Falken.motions().variants.map(func(row):return int(row.id))==[101531,101110,101701],"The source Falken/skeleton/lizard actor identities are restored")
 await open_area("sokia_desert")
 await follow(3300);await follow(3301);await follow(23000)
 var scroll=game.model.get_meta("falan_links",[]).filter(func(link):return link.to=="falken_scroll")
 check(scroll.size()==1,"Original Riyong marker grants the curse-breaking scroll")
 if not scroll.is_empty():Tour.enter_link(game,"interior",scroll[0],scroll[0].at)
 check(get_meta(Falken.Route.SCROLL,false),"The quest scroll is retained through the tower")
 await follow(23003);await follow(Falken.Route.FLOORS[0])
 var counts={}
 for id in Falken.Route.FLOORS:
  check(game.model.falan_floor==id,"The original tower climb reaches "+str(id))
  if game.model.falan_floor!=id:return
  game.model.waves.tick(.5,game.player.position);game.army_runtime.import_arrivals()
  counts[id]=game.model.enemies.size()
  check(counts[id]>=80 and counts[id]<=96,"Tower floor has 80–96 native enemies")
  for row:Dictionary in game.model.enemies.values():
   check(row.level>=22 and row.level<=25 and game.model.terrain.disk_clear(row.pos/game.model.falan_scale,.45),"Native tower monster uses a clear original-level spawn")
  var before=game.model.enemies.size();game.model.waves.tick(1,game.player.position)
  check(before==game.model.enemies.size(),"Repeated ticks cannot duplicate the floor population")
  check(game.world.find_children("HabaruStair_*","Node3D",true,false).size()==2,"Both original 12000/12002 stair forms are solid 3D")
  if id in [30201,30208,30216]:
   await shot("tower-"+str(id),game.player.position+Vector3(35,48,42)*game.model.falan_scale,game.player.position,62)
  var next=Falken.Route.FLOORS.find(id)+1
  await follow(Falken.ROOM if next==16 else Falken.Route.FLOORS[next])
 check(game.model.falan_floor==Falken.ROOM,"The tower exits at the original top chamber")
 check(game.model.enemies.is_empty() and is_instance_valid(game.falken_waiting),"The antechamber stays clear until the conversation")
 var outer=map_position()
 check(outer.distance_to(Falken.Route.point(Falken.ROOM,Vector2i(23,45)))<4,"The final stair lands at original (23,45)")
 await follow(Falken.ROOM)
 check(map_position().distance_to(Falken.Route.point(Falken.ROOM,Vector2i(23,23)))<4,"Yeka opens the original barrier passage")
 await talk_to_falken(true)
 var bosses=game.model.enemies.values().filter(func(row):return row.skin==0)
 check(bosses.size()==1,"Exactly one native Falken owns the boss fight")
 if bosses.is_empty():return
 var boss:Dictionary=bosses[0];var runtime=game.army_runtime
 var handle:int=runtime.handles[boss.id]
 var boss_at:Vector3=runtime.unit_state(handle).position
 print("FALKEN_FIGHT_ENTRY floor=",game.model.falan_floor," boss=",boss.id," at=",boss_at," player=",map_position())
 game.player.position=game.model.world_point(Tour.Indoor.safe_point(Falken.ROOM,Vector2(boss_at.x,boss_at.z)/game.model.falan_scale+Vector2(0,2.0)),.15)
 game.player.velocity=Vector3.ZERO;game.falan_crossing_position=Vector2.INF
 game.player.set_physics_process(false)
 for i in 2:runtime.apply_hit(handle,{"amount":22000,"reflected":true})
 runtime.record_events=true;runtime.event_log.clear()
 game.player.max_hp=100000;game.player.hp=100000;game.player.invuln=0;game.tuning.invincible=true
 var spells={}
 for tick in 7200:
  await physics_frame
  for event in runtime.event_log:
   if event.kind=="status" and event.source_id==boss.id and event.source_tick==30:spells[int(event.action_index)]=true
  if spells.has(Falken.DRAIN) and spells.has(753) and (spells.has(756) or spells.has(757)):break
 print("FALKEN_FIGHT_CASTS floor=",game.model.falan_floor," player=",map_position()," spells=",spells.keys())
 check(spells.has(Falken.DRAIN) and spells.has(753),"Actual native fight casts life drain and Holy Shield")
 check(spells.has(756) or spells.has(757),"Actual native fight casts its original reflection wards")
 check(runtime.event_log.any(func(event):return event.kind=="external_damage" and event.source_id==boss.id),"Falken's native spells or attacks reach the player")
 await shot("falken-spells",game.player.position+Vector3(11,8,14)*game.model.falan_scale,game.player.position+Vector3.UP*2,55)
 game.tuning.invincible=true
 for row:Dictionary in game.model.enemies.values():
  if row.id!=boss.id:runtime.damage_enemy(row.id,row.max_hp*2)
 for tick in 1800:
  await physics_frame
  if game.model.enemies.values().filter(func(row):return row.skin in [1,2] and row.hp>0).size()==5:break
 var guards=game.model.enemies.values().filter(func(row):return row.skin in [1,2] and row.hp>0)
 check(guards.size()==5 and guards.all(func(row):return row.skin==guards[0].skin),"With escorts cleared, native summon restores exactly five of one original family")
 var summoned=game.model.enemies.size();game.model.waves.reinforce_falken(boss.id,1)
 check(summoned==game.model.enemies.size(),"Duplicate summon callbacks cannot overpopulate the chamber")
 runtime.record_events=false
 game.player.set_physics_process(true)
 for tick in 120:
  if not runtime.handles.has(boss.id):break
  runtime.apply_hit(runtime.handles[boss.id],{"amount":boss.max_hp*100,"reflected":true})
  await physics_frame
 for i in 6:await physics_frame
 check(get_meta(Falken.SLAIN,{}).has(Vector2i(Falken.ROOM,0)),"Native boss death remains recorded")
 await follow(23002)
 check(game.model.falan_floor==23002,"Victory opens the original reward chamber")
 await shot("liberated-palace",game.player.position+Vector3(25,30,34)*game.model.falan_scale,game.player.position,60)
 await follow(0,true)
 check(Tour.area(game.model)=="sokia_desert","The original temporal exit returns to Sokia")
 print("FALKEN_TOWER_POPULATIONS ",counts)
 print("FALKEN_TOWER_SPELLS ",spells.keys())
 print("FALKEN_TOWER_RESULT checks=",checks," failures=",errors)
