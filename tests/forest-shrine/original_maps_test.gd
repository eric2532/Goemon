extends SceneTree
## Original geography integrated into the existing Falan exploration.
const Original=preload("res://scripts/forest/forest_original_maps.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Winter=preload("res://scripts/forest/forest_frostpass.gd")
const OUT="res://build/Other Files/Asset Toolkit/Shalena Recovery/"
var game
var failures=0
var checks=0

func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("SHALENA_FAIL ",message)

func _initialize():
 create_timer(420).timeout.connect(func():printerr("SHALENA_TIMEOUT");quit(1))
 run.call_deferred()

func connected(id:int,from:Vector2,to:Vector2,seed_:int=0)->bool:
 var row=Original.state(id,seed_)
 var a=Vector2i(((from-row.origin)/3).round());var b=Vector2i(((to-row.origin)/3).round())
 if not Original.open(row.bits,row.size,a) or not Original.open(row.bits,row.size,b):return false
 var visited={a:true};var queue=[a];var cursor=0
 while cursor<queue.size():
  var c:Vector2i=queue[cursor];cursor+=1
  if c==b:return true
  for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
   var next:Vector2i=c+d
   if not visited.has(next) and Original.open(row.bits,row.size,next):visited[next]=true;queue.append(next)
 return false

func data_checks():
 var road=[51001,51002,51003,Original.SHALENA_SOUTH,14000,14001,14002,Original.SHALENA_NORTH,51011,Original.SHALENA_NORTH,51012]
 for i in road.size()-1:
  var from:int=road[i];var target:int=road[i+1]
  check(Original.links(from).any(func(l):return l.get("floor")==target),"Route forward %d → %d"%[from,target])
  check(Original.links(target).any(func(l):return l.get("floor")==from),"Route return %d → %d"%[target,from])
 for id in road+[51005,51006,51007,51008,51021,51022,51023,51009,51010,15522,15523]:
  check(Tour.Document.validate(Original.layout(id)).is_empty(),"Existing map document accepts "+str(id))
  var row=Original.state(id,341)
  for link in Original.links(id,341):
   var cell=Vector2i(((link.at-row.origin)/3).round())
   check(Original.open(row.bits,row.size,cell),"Walk-in gate is on original open ground %d %s"%[id,cell])
 for n in range(1,61):
  var id=Winter.Decree.floor_id(n)
  var row=Original.state(id)
  check(row.raw==Original.Art.raw_map(Original.path_for(id)),"Maze floor %d retains every source cell"%n)
  var encounters=Winter.Decree.encounters(id)
  check(encounters.size()==2 if n==60 else encounters.size()==10 if n%10==0 else encounters.size()>=Winter.Decree.PATROLS[Winter.Decree.section_index(id)].size() and encounters.size()<=240,"Recovered guardian/patrol counts "+str(n))
  if n%10!=0:
   check(Original.links(id).any(func(l):return l.get("floor")==Winter.Decree.floor_id(n+1)),"Maze floor has its original next stair "+str(n))
 for seed_ in range(48):
  for id in Winter.SNOW_FLOORS:
   var row=Original.state(id,seed_)
   check(row.raw==Original.state(id,seed_).raw,"Snow seed is reproducible")
   check(connected(id,Original.point(id,Original.generated().doors(id,seed_)[0],seed_),Original.point(id,Original.generated().doors(id,seed_)[1],seed_),seed_),"Generated snow stairs connect")
   check(Winter.patrols(id,seed_).size()==Winter.SNOW_PATROLS,"Snow native population retained")
 var snow_layouts={}
 for seed_ in range(48):snow_layouts[hash(Original.state(51009,seed_).raw)]=true
 check(snow_layouts.size()>1,"Snow seeds select multiple original layout snapshots")
 var first_bag={}
 for n in range(1,13):first_bag[hash(Original.state(Original.generated().floor_id("mountain",n),341).raw)]=true
 check(first_bag.size()==12,"Snow shuffle bag uses every native template before refilling")

func check_surface_projection():
 for serial in [12756,13000,15827]:
  var g:Dictionary=Original.Art.data().graphics[str(serial)]
  var texture=Original.Art.surface_texture(int(g.surfaces[0]))
  var mesh=Original.Forms.mesh(serial,"wall" if serial==15827 else "rock",g,texture)
  if mesh.has_meta("native_cliff_profile"):
   var row:Dictionary=Original.Forms.Cliffs.data()[str(serial)]
   var rect=Rect2(row.paint_rect[0],row.paint_rect[1],row.paint_rect[2],row.paint_rect[3])
   var atlas=Original.Forms.Cliffs.texture().get_size()
   var valid=true
   for uv:Vector2 in mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
    valid=valid and rect.has_point(uv*atlas)
   check(valid,"Measured cliff UVs stay inside their own complete native painting "+str(serial))
   continue
  var uv2=mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
  var valid=true
  for i in range(0,uv2.size(),3):valid=valid and uv2[i]==uv2[i+1] and uv2[i]==uv2[i+2]
  check(valid,"Stone triangles do not interpolate between separate atlas tiles "+str(serial))
 var texture=Original.Art.surface_texture(0)
 var skin=Original.Forms.Source.new([Rect2(0,0,128,128),Vector2(64,64),Vector2.ONE,0],texture,.045)
 check(skin.projection_center==Vector3.ZERO,"Existing scenery keeps the original projector default")
 skin.projection_center=Vector3(3,0,-3)
 for i in 3:skin.vertex(Vector3(7,0,-2),Vector3.RIGHT)
 var mesh=skin.surface.commit()
 var uv:Vector2=mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV][0]
 check(uv.is_equal_approx(Vector2(32,56)/texture.get_size()),"Footprint reflections use the recovered solid's centre")
 var cone=Original.Forms.Source.new([Rect2(0,0,128,128),Vector2(64,64),Vector2.ONE,0],texture,.045)
 cone.quad(Vector3.RIGHT,Vector3.UP,Vector3.UP,Vector3.FORWARD)
 var normal:Vector3=cone.surface.commit().surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
 check(normal.length()>.99,"Pointed roofs and plants retain a lit solid face at their tips")

func detail_checks():
 var catalog=Original.Art.data()
 check(is_equal_approx(Original.Forms.source_height(catalog.graphics["16562"]),1.575),"Long table height excludes its original isometric ground span")
 check(is_equal_approx(Original.Forms.source_height(catalog.graphics["16530"]),.855),"Small stools use their visible footprint instead of full-cell height")
 check(Original.Forms.kind(17644,false,catalog.graphics["17644"])=="void","Transparent source markers never become black solids")
 check(catalog.graphics["16303"].channel_edges==[true,true,false,false],"Native parallel water banks retain their original axis")
 check(catalog.graphics["16309"].channel_edges==[true,false,false,true],"Native corner water banks retain both original sides")
 var bank:Dictionary=catalog.graphics["12566"]
 check(Original.Forms.kind(12566,false,bank)=="bank","Tall ground artwork becomes a shoreline with depth")
 var bank_mesh=Original.Forms.mesh(12566,"bank",bank,Original.Art.solid_texture(int(bank.page)))
 check(bank_mesh.get_aabb().position.y< -1 and bank_mesh.get_aabb().end.y>0,"Native bank joins submerged stone to its original land cap")
 var water:Dictionary=catalog.graphics["5000"]
 var water_mesh=Original.Forms.mesh(5000,"water",water,load(Original.Art.ROOT+catalog.pages[int(water.page)]))
 check(water_mesh.get_aabb().end.y< -2,"Outdoor water lies below the recovered shore")
 for serial in [10023,10556,11013,15329,16929,11389]:
  var g:Dictionary=catalog.graphics[str(serial)]
  var mesh=Original.Forms.mesh(serial,Original.Forms.kind(serial,false,g),g,Original.Art.solid_texture(int(g.page)))
  check(mesh.get_surface_count()>0 and mesh.get_aabb().size.y>.05,"Cabin detail retains solid geometry "+str(serial))
 for serial in [10611,10624,10626,10627,10629,16286,16294,16296,16300,16303,16309,16324,17680,13517,17791,11461,11467,11481,11465,11485,12409,12463,12497,16540,16548,16564,16629,16790,17195,10530,16579,16537,16583,17031,17145,17531,11394,15215,12184,12200,12222,12388,12411,12420,12429,12440,12445,12486,12298,17212,17213,17215,16555,16562,16530,16585]:
  var g:Dictionary=catalog.graphics[str(serial)]
  var family=Original.Forms.kind(serial,false,g)
  var texture=Original.Art.solid_texture(int(g.page))
  var mesh=Original.Forms.mesh(serial,family,g,texture)
  check(mesh!=null and mesh.get_surface_count()>0,"Native detail has solid geometry "+str(serial))
  check(mesh==Original.Forms.mesh(serial,family,g,texture),"Repeated native details share a prepared mesh "+str(serial))
  var valid=true
  for slot in mesh.get_surface_count():
   var vertices=mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX]
   for p:Vector3 in vertices:valid=valid and p.is_finite()
  check(valid,"Detail vertices remain finite "+str(serial))
  if family not in ["channel"]:check(mesh.get_aabb().size.y>.05,"Recovered detail has real height "+str(serial))


func run():
 data_checks()
 check_surface_projection()
 detail_checks()
 print("SHALENA_DATA_COMPLETE checks=",checks)
 if "--data-only" in OS.get_cmdline_user_args():finish();return
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-shalena-test.cfg"
 root.add_child(game);current_scene=game
 root.gui_disable_input=true
 for i in 4:await process_frame
 check(game.find_child("ForestOriginalMaps",true,false)==null,"No separate Original Maps panel")
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false
 game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true
 if "--route-only" in OS.get_cmdline_user_args():
  await route_checks()
  finish();return
 var projection:int=game.camera_rig.camera.projection
 var samples=[51001,Original.SHALENA_SOUTH,51011,51012,51009,15522,Winter.Decree.floor_id(1),51025]
 if "--snow-only" in OS.get_cmdline_user_args():samples=[51009,51010]
 if "--towns-only" in OS.get_cmdline_user_args():samples=[51004,51005,51011,51012]
 if "--caves" in OS.get_cmdline_user_args():samples=[51002,51003,14000,14001,14002,51005,51021,51022,51023,51010,15523]
 if "--details-only" in OS.get_cmdline_user_args():samples=[51011,51012,4410,4401,4418,51021,15523,51101,51025,51001,14002]
 if "--completeness" in OS.get_cmdline_user_args():samples=[51011,51012,4417,4411,4453,51021,15522,15523,51009,51025,51152,51027]
 if "--refinement" in OS.get_cmdline_user_args():samples=[51011,51012,4453,4417,4411,15522,15523,51005,51027]
 for id in samples:
  print("SHALENA_ENTER ",id)
  var arrival=Tour.Indoor.safe_point(id,Vector2.ZERO,game.model.seed_value)
  if id==51011:arrival=Original.source_point(id,Vector2i(37,64))
  if id==51012:arrival=Original.source_point(id,Vector2i(75,110))
  if id==Original.SHALENA_SOUTH:arrival=Original.source_point(id,Vector2i(196,443))
  if ("--completeness" in OS.get_cmdline_user_args() or "--refinement" in OS.get_cmdline_user_args()) and id not in [51012,51009]:
   var raw=Original.state(id,game.model.seed_value)
   var interesting=[]
   var preferred:Array={51011:[11496,11497],4417:[17506],4411:[17221,17222,17169],4453:[16515],51025:[15231,15232,15233],51152:[15891,15892],51027:[17683]}.get(id,[])
   if "--refinement" in OS.get_cmdline_user_args():preferred={51011:[11454,11455,11456,11465],51012:[11457,11458,11459],4453:[16515,16516],4417:[17506],4419:[17045],4411:[17632],15522:[11465],51005:[11482,11483],51027:[17683]}.get(id,[])
   for i in raw.size.x*raw.size.y:
    var serial=raw.raw.decode_u16(20+(raw.size.x*raw.size.y+i)*2)
    if serial<1000:continue
    var family=Original.Forms.kind(serial,false,Original.Art.data().graphics[str(serial)])
    if (serial in preferred if not preferred.is_empty() else family.begins_with("detail_") or serial==17526):interesting.append(Vector2i(i%raw.size.x,i/raw.size.x))
   if not interesting.is_empty():arrival=Original.point(id,Original.safe_cell(id,interesting[interesting.size()/2]+Vector2i(0,2),game.model.seed_value),game.model.seed_value)
  Tour.travel(game,Original.layout(id),{"arrival":arrival,"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 6:await physics_frame
  var source=game.world.map_features
  check(source.get_meta("recovered_source_map",0)==Original.source_id(id),"Existing exploration builds recovered geography "+str(id))
  check(source.get_meta("recovered_solid_placements",0)>0,"Solid 3D scenery "+str(id))
  check(source.find_children("*","Sprite3D",true,false).is_empty(),"Scenery does not use isometric picture panels "+str(id))
  check(game.camera_rig.camera.projection==projection and projection==Camera3D.PROJECTION_PERSPECTIVE,"Normal 3D game camera retained "+str(id))
  check(not game.model.get_meta("falan_links",[]).is_empty(),"Normal travel links are present "+str(id))
  if id==51012:
   var gate=game.model.world_point(Original.source_point(id,Vector2i(75,171)),.15)
   check(game.army_runtime.native.can_reach(game.player.position,gate,.5),"Native navigation covers the university entrance beyond the old flat-ground bounds")
  var info=Original.floor_info(id,game.model.seed_value)
  var tile=Vector2i(((Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale-info[1])/3).round())
  check(Original.open(info[2].hex_decode(),info[0],tile),"Player stands on recovered walking mask "+str(id))
  if DisplayServer.get_name()!="headless":await capture(id)
 finish()

func position_at(at:Vector2):
 game.player.position=game.model.world_point(at,.15)
 game.player.velocity=Vector3.ZERO
 for i in 4:await physics_frame

func cross(target:int)->bool:
 var choices=game.model.get_meta("falan_links",[]).filter(func(link):return link.to=="freyja_outside" and link.get("area")=="west_lakes" if target==0 else link.get("floor",-1)==target)
 check(not choices.is_empty(),"Normal exploration exposes doorway to "+str(target))
 if choices.is_empty():return false
 var link:Dictionary=choices[0]
 if Original.source_id(game.model.falan_floor) in [15000,15001,15002,14000,14001,14002] or Original.generated().owns(game.model.falan_floor):
  check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(link.at,.15),.5),"Native navigation follows the recovered cave between its stairs "+str(game.model.falan_floor))
 game.falan_crossing_position=link.at+Vector2(4,0)
 game.player.position=game.model.world_point(link.at,.15)
 game.player.velocity=Vector3.ZERO
 check(Tour.cross_on_foot(game),"Normal on-foot crossing accepts doorway to "+str(target))
 for i in 6:await physics_frame
 var reached=Tour.area(game.model)=="west_lakes" if target==0 else game.model.falan_floor==target
 check(reached,"On-foot crossing loads "+str(target))
 print("SHALENA_CROSSED ",target)
 return reached

func talk_source(source_id:String)->bool:
 game.explorer_npcs.prepare()
 var choices=game.explorer_npcs.actors.filter(func(actor):return actor.record.id=="source:"+source_id)
 check(choices.size()==1,"One source interaction exists: "+source_id)
 if choices.size()!=1:return false
 var actor:Dictionary=choices[0];var record:Dictionary=actor.node.get_meta("npc_record")
 var id:int=game.model.falan_floor;var state=Original.state(id,game.model.seed_value)
 for z in range(-1,2):
  for x in range(-1,2):
   var cell=Vector2i(int(record.cell[0])+x,int(record.cell[1])+z)-Original.crop(id).position
   if not Original.open(state.bits,state.size,cell):continue
   var local=Original.point(id,cell,game.model.seed_value);var target=game.model.world_point(local,.15)
   if not game.army_runtime.native.can_reach(game.player.position,target,.5):continue
   await position_at(local)
   game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
   if game.explorer_npcs.nearest.get("node")!=actor.node:continue
   var event=InputEventKey.new();event.physical_keycode=KEY_F;event.pressed=true;game._input(event)
   var talked=is_instance_valid(game.dialogue) and game.explorer_npcs.selected.get("id")=="source:"+source_id
   check(talked,"F opens the source interaction: "+source_id)
   if not talked:return false
   game.explorer_npcs.finish()
   for i in 6:await physics_frame
   return true
 check(false,"The source interaction is reachable and unobstructed: "+source_id)
 return false

func route_checks():
 # The fixture represents an already-qualified character; it does not prove the external title/job chain.
 set_meta("university_quest_items",{"opener":true,"job_rank":2})
 var edge:float=Tour.Frontier.OUTER_EDGE.freyja
 await position_at(Tour.Frontier.to_city("freyja",Vector2(3,edge-1)))
 await position_at(Tour.Frontier.to_city("freyja",Vector2(3,edge+1)))
 check(Tour.area(game.model)=="freyja","Existing Falan West Gate opens on foot")
 await position_at(Vector2(-39,419));await position_at(Vector2(-39,421))
 check(Tour.area(game.model)=="west_lakes","Western road remains connected to Falan")
 for id in [51001,51002,51003,Original.SHALENA_SOUTH,51004,Original.SHALENA_SOUTH,14000,14001,14002,Original.SHALENA_NORTH,51011,51021]:
  if not await cross(id):return
 if not await talk_source("6392") or not await talk_source("6399"):return
 check(game.model.falan_floor==51022,"Wild strawberry opens the original cellar")
 if not await talk_source("6397") or not await talk_source("6394"):return
 check(get_meta(Winter.Decree.BLADE,false),"Existing quest inventory retained")
 if not await cross(51023) or not await cross(4334) or not await talk_source("6407") or not await cross(51021):return
 var mountain=[]
 for n in range(1,Original.generated().count("mountain",game.model.seed_value)+1):mountain.append(Original.generated().floor_id("mountain",n))
 var route=[51011,Original.SHALENA_NORTH,51012,51014,51012,Original.SHALENA_NORTH]
 route.append_array(mountain);route.append_array([15522,15523,15522])
 mountain.reverse();route.append_array(mountain);route.append(Original.SHALENA_NORTH)
 for id in route:
  if not await cross(id):return
 for id in [14002,14001,14000,Original.SHALENA_SOUTH,51003,51002,51001,0,51001,51002,51003,Original.SHALENA_SOUTH,14000,14001,14002,Original.SHALENA_NORTH,24008,Winter.Decree.floor_id(1)]:
  if not await cross(id):return
 check(game.army_runtime.handles.size()==Winter.Decree.encounters(game.model.falan_floor).size(),"Recovered maze population uses the existing native army")


func capture(id:int):
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"play-%d.png"%id)
 game.camera_rig.set_process(false)
 var ceilings=[]
 for node:MeshInstance3D in game.world.find_children("*Ceiling*","MeshInstance3D",true,false):
  if node.visible:ceilings.append(node);node.hide()
 var at=game.player.position
 game.camera_rig.camera.global_position=at+(Vector3(13,18,16) if Original.cave(id) else Vector3(23,25,30))
 game.camera_rig.camera.look_at(at+Vector3.UP*2)
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 root.get_texture().get_image().save_png(OUT+"3d-%d.png"%id)
 for node in ceilings:node.show()
 game.camera_rig.set_process(true)

func finish():
 print("SHALENA_RESULT checks=",checks," failures=",failures)
 if is_instance_valid(game):game.queue_free()
 await process_frame
 quit(1 if failures else 0)
