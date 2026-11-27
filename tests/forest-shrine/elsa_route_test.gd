extends "res://tests/forest-shrine/original_maps_test.gd"
## Check the archived route before normal-play and fixed-camera reviews.
const Elsa=preload("res://scripts/forest/forest_elsa_route.gd")
const Population=preload("res://scripts/forest/crowd/elsa_region_sprites.gd")
const Music=preload("res://scripts/forest/crossgate_music.gd")

func run():
 if "--build-probe" in OS.get_cmdline_user_args():
  var started=Time.get_ticks_msec();var stage=Node3D.new()
  Original.build(stage,59520)
  print("ELSA_BUILD_PROBE milliseconds=",Time.get_ticks_msec()-started," cached_form_meshes=",Original.Forms.meshes.size()," children=",stage.get_child_count()," static_memory=",OS.get_static_memory_usage())
  stage.free();await finish();return
 if "--views" in OS.get_cmdline_user_args():await art_views();await finish();return
 if "--art-probe" in OS.get_cmdline_user_args():await art_probe();await finish();return
 if "--play" in OS.get_cmdline_user_args():await normal_play();await finish();return
 if "--doors" in OS.get_cmdline_user_args():await branch_doors();await finish();return
 check(not Original.Art.elsa_loaded,"Existing regions do not eagerly load Elsa artwork")
 check(Original.owns(59520),"Elsa source map is available through the original map owner")
 var route=[59511,59510,59500,59501,59520]
 var source_cells=[Vector2i(19,17),Vector2i(96,138),Vector2i(124,168),Vector2i(264,108)]
 var arrivals=[Vector2i(97,32),Vector2i(108,124),Vector2i(224,68),Vector2i(112,102)]
 for i in route.size()-1:
  var links=Original.links(route[i]).filter(func(l):return l.get("floor")==route[i+1] and l.at==Original.source_point(route[i],source_cells[i]))
  check(links.size()==1,"Archived crossing %d → %d"%[route[i],route[i+1]])
  if not links.is_empty():check(links[0].arrival==Original.source_point(route[i+1],arrivals[i]),"Exact archived landing "+str(route[i+1]))
 var start=Elsa.stone_links("castle",0)[0]
 check(start.floor==59511 and start.at==Vector2(96,39),"Castle source (28,88) activates the time passage")
 check(not Tour.is_walk_in("castle",start),"Castle activation requires normal interaction")
 var back=Elsa.stone_links("interior",59520)[0]
 check(back.to=="castle" and back.arrival==Vector2(78,42),"Island return lands at castle source (27,82)")
 check(not Tour.is_walk_in("interior",back),"Return stone does not activate by walking past immigration")
 var legs=[[59511,Vector2i(19,19),Vector2i(19,17)],[59510,Vector2i(97,32),Vector2i(96,138)],
  [59500,Vector2i(108,124),Vector2i(124,168)],[59501,Vector2i(224,68),Vector2i(264,108)],
  [59520,Vector2i(112,102),Vector2i(140,104)]]
 for leg in legs:
  check(connected(leg[0],Original.source_point(leg[0],leg[1]),Original.source_point(leg[0],leg[2])),"Walking mask connects journey leg "+str(leg[0]))
 var count_=0
 var door_inventory=[]
 for path in Original.Art.data().maps:
  var row:Dictionary=Original.Art.data().maps[path]
  if row.get("group","")!="elsa":continue
  count_+=1
  check(Music.key("interior",int(row.id))==Music.ELSA_SOUNDS[int(row.music)],"Native area music ID "+str(row.id))
  check(Tour.Document.validate(Original.layout(int(row.id))).is_empty(),"Existing map document accepts "+str(row.id))
  check(Original.state(int(row.id)).size==Vector2i(row.size[0],row.size[1]),"Entire original map is retained "+str(row.id))
  var id:int=row.id;var state:Dictionary=Original.state(id)
  for link in Original.links(id):
   if id==59752 and not connected(id,Original.source_point(id,Vector2i(266,208)),link.at):continue
   var cell=Vector2i(((link.at-state.origin)/3.).round())
   check(Original.open(state.bits,state.size,cell),"Original island interaction has a reachable source tile %d %s"%[id,cell])
   var record={"map":id,"cell":[cell.x,cell.y],"kind":"battle" if link.has("elsa_battle") else "event" if link.has("elsa_event") else "door","blocked":link.get("elsa_blocked",false),"paired":link.get("paired_return",false)}
   if link.has("floor"):
    var destination:Dictionary=Original.state(int(link.floor));var landing=Vector2i(((link.arrival-destination.origin)/3.).round())
    check(Original.open(destination.bits,destination.size,landing),"Original island door retains open landing %d → %d"%[id,link.floor])
    record.target=int(link.floor);record.landing=[landing.x,landing.y]
   door_inventory.append(record)
 check(count_==95,"All island branches and journey maps are inventoried")
 check(Original.links(59736).any(func(link):return link.get("floor",0)==59716 and link.get("elsa_blocked",false)),"Unverified bishop transfer stays closed instead of trapping the player")
 check(not Original.links(59752).any(func(link):return link.get("floor",0)==4419 and connected(59752,Original.source_point(59752,Vector2i(266,208)),link.at)),"Island quest room cannot reach independently owned University returns in the shared file")
 var inventory_file=FileAccess.open("res://build/Other Files/Asset Toolkit/Elsa Island/runtime-links.json",FileAccess.WRITE)
 inventory_file.store_string(JSON.stringify(door_inventory," "));inventory_file.close()
 for id in [59500,59501,59510,59520]:check(Original.outdoor(id),"Outdoor lighting classification "+str(id))
 for id in [59511,59520,59530,59531,59534,59535,59536,59537]:check(not Population.owns(id),"Original safe area has no encounters "+str(id))
 check(Population.data().species.size()==29,"Native source creature roster includes the event bosses")
 check(Population.timelines().size()==29*32*8,"Native timeline contract keeps every source skin and reserved slot")
 var rng=RandomNumberGenerator.new();rng.seed=3394
 var bags={}
 for zone in Population.data().zones:
  if zone.groups.is_empty():continue
  var members=Population.group(zone,bags,rng)
  check(not members.is_empty() and members.size()<=int(zone.maximum),"Source group maximum is preserved "+str(zone.id))
  for member in members:check(member[0]>=0 and member[0]<29 and member[1]>=1,"Source member skin and level are valid")
 print("ELSA_DATA checks=",checks," failures=",failures)
 await finish()

func art_probe():
 Original.Art.load_elsa()
 var row:Dictionary=Original.Art.data().maps[Original.path_for(59511)]
 var serial=int(row.art_remap["1000"]);var graphic:Dictionary=Original.Art.data().graphics[str(serial)]
 var tex:Texture2D=load(Original.Art.ROOT+Original.Art.data().pages[int(graphic.page)])
 var im=tex.get_image();var rect=Rect2i(graphic.rect[0],graphic.rect[1],graphic.rect[2],graphic.rect[3])
 im.get_region(rect).save_png("res://build/Other Files/Asset Toolkit/Elsa Island/engine-time-floor.png")
 check(imported_pixels_match(tex,graphic),"Imported native colors and alpha survive regional atlas rebasing")
 var university=JSON.parse_string(FileAccess.get_file_as_string(Original.Art.ROOT+"university/catalog.json"))
 var key:String=university.graphics.keys()[0];var old:Dictionary=Original.Art.data().graphics[key]
 var old_texture:Texture2D=load(Original.Art.ROOT+Original.Art.data().pages[int(old.page)])
 check(imported_pixels_match(old_texture,old),"Existing University paint stays correct after another region adds an atlas")
 var mesh=Original.Forms.mesh(serial,"floor",graphic,tex)
 var bounds=mesh.get_aabb()
 check(bounds.size.x==6.0 and bounds.size.z==6.0,"Native CUT rectangle spans both logical floor diamonds")
 var scenery=load("res://scripts/forest/forest_elsa_scenery.gd")
 var source_pixel=Vector2(12,-30)
 var native_point=scenery.Fit.native_coastal_frame()*scenery.pixel_point(source_pixel)
 check(scenery.Fit.project(Basis(Vector3.UP,PI*.5)*native_point).distance_to(source_pixel)<.001,"Elsa uses the existing Falan source-camera height calibration")
 for foot in [Vector2(.42,160),Vector2(-.59,31),Vector2(0,-48)]:
  var grounded=scenery.Fit.native_coastal_frame()*scenery.relief_point(source_pixel,foot)
  check(scenery.Fit.project(Basis(Vector3.UP,PI*.5)*grounded).distance_to(source_pixel)<.001,"Grounded source walls and props retain their original camera projection")
 var tower:Dictionary=scenery.data().tower;var tower_anchor=Vector2(tower.anchor[0]-tower.rect[0],tower.anchor[1]-tower.rect[1])
 for pixel in [Vector2(518,50),Vector2(518,1500),Vector2(320,1800),Vector2(700,1850)]:
  var curved=scenery.Fit.native_coastal_frame()*scenery.tower_shell_point(pixel,tower)
  check(scenery.Fit.project(Basis(Vector3.UP,PI*.5)*curved).distance_to(pixel-tower_anchor)<.001,"Curved tower front retains the original painted pixel")
 for part in tower.roots:
  var pixel=Vector2(part.origin[0],part.origin[1]+part.rect[3]-part.rect[1])
  check(absf(scenery.relief_point(pixel,Vector2(part.foot[0],part.foot[1]),part.vertical).y)<.001,"Original gold buttress lands on its recovered source foot")
  var top=scenery.relief_point(Vector2(part.origin[0],part.origin[1]),Vector2(part.foot[0],part.foot[1]),part.vertical)
  check(absf(top.y-part.height_pixels*.045)<.001,"Four original support tips share the inferred physical height")
 check(scenery.Fit.project(Basis(Vector3.UP,PI*.5)*scenery.sky_point(source_pixel)).distance_to(source_pixel)<.001,"Original star backdrop keeps its native projection behind the hanging islands")
 var props:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/props/data.json"))
 for part in props.groups.values().filter(func(item):return item.has("bridge")):
  var origin=Vector2(part.origin[0],part.origin[1]);var edge=Vector2(part.bridge.edge[0],part.bridge.edge[1])
  for sample in [[edge.x*240.+edge.y-8.,part.bridge.height_pixels*.045],[edge.x*240.+part.bridge.footer,0.]]:
   var pixel=Vector2(sample[0],240.);var bridge_point=scenery.bridge_point(pixel,origin,part.bridge)
   check(scenery.Fit.project(Basis(Vector3.UP,PI*.5)*(scenery.Fit.native_coastal_frame()*bridge_point)).distance_to(pixel+origin)<.001,"Bridge deck and arch side retain their original projected paint")
   check(absf(bridge_point.y-sample[1])<.001,"Decorative span has a raised level deck and a grounded lower footer")
 var hanging:Dictionary=props.groups.values().filter(func(part):return int(part.master)==300945)[0]
 var stone:Mesh=scenery.rock_part({"rect":hanging.rect,"origin":hanging.origin},load("res://assets/maps/falan/elsa/props/solid-%d.png"%int(hanging.page)),hanging.rock.model,hanging.rock.parts[0],true)
 check(stone.get_aabb().end.y<.001 and stone.get_aabb().size.y>0.,"Hanging rock bodies extend below their walkable top")
 var gate=load("res://scripts/forest/forest_elsa_gate.gd");var gate_mesh:Mesh=gate.mesh()
 check(gate_mesh.get_surface_count()==2,"Arrival gate has solid architecture and the separate original grille")
 check(gate.mesh(gate.data().others[0]).get_surface_count()>=2,"Ferry gate shares solid towers and retains its original wall wings")
 var island:Dictionary=Original.state(59520)
 var marker:int=island.raw.decode_u16(20+(island.size.x*island.size.y+104*island.size.x+141)*2)
 check(Original.Art.data().graphics[str(marker)].family=="void","Zero-area island return marker does not draw a whole gate over the stone")
 var return_stone=scenery.return_stone()
 check(return_stone.sprite_frames.get_frame_count(&"default")==4 and return_stone.sprite_frames.get_animation_speed(&"default")==8.,"Return stone uses its original four-frame 500 ms idle")
 return_stone.free()
 var temple=load("res://scripts/forest/forest_elsa_temple.gd")
 check(temple.data().parts.size()==5 and temple.mesh().get_surface_count()==5,"Temple has separate original entrance and wing volumes with closed hidden surfaces")
 print("ELSA_ART_PROBE serial=",serial," graphic=",graphic," tex=",tex.resource_path," uv=",mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV])

func imported_pixels_match(texture:Texture2D,g:Dictionary)->bool:
 var rect=Rect2i(g.rect[0],g.rect[1],g.rect[2],g.rect[3])
 var native=Image.load_from_file(texture.resource_path).get_region(rect);native.convert(Image.FORMAT_RGBA8)
 var actual=texture.get_image().get_region(rect);actual.convert(Image.FORMAT_RGBA8)
 var expected=native.get_data();var imported=actual.get_data()
 var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(expected)
 check(hash_.finish().hex_encode()==g.rgba_sha256,"Native PNG retains its full original RGBA hash "+texture.resource_path)
 # Godot extends invisible border RGB; alpha and every visible palette value must stay exact.
 for i in range(0,expected.size(),4):
  if expected[i+3]==0 and imported[i+3]==0:
   for channel in 3:imported[i+channel]=expected[i+channel]
 return imported==expected

func normal_play():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-elsa-route-test.cfg"
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false
 game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true
 game.explorer_clock.save_left=600.
 print("ELSA_NORMAL_START ",Tour.area(game.model))
 if Tour.area(game.model)!="city":
  var to_city=Tour.LINKS[Tour.area(game.model)].filter(func(l):return l.to=="city")[0]
  Tour.enter_link(game,Tour.area(game.model),to_city,to_city.at)
  for i in 6:await physics_frame
 check(Tour.area(game.model)=="city","Normal Explore reaches Falan")
 var castle=game.model.get_meta("falan_links",[]).filter(func(l):return l.to=="castle")[0]
 await position_at(castle.at+Vector2(4,0))
 game.falan_crossing_position=castle.at+Vector2(4,0)
 game.player.position=game.model.world_point(castle.at,.15)
 check(Tour.cross_on_foot(game),"Normal castle doorway accepts the player")
 for i in 6:await physics_frame
 check(Tour.area(game.model)=="castle","Journey starts in the existing castle")
 game.settings.music_enabled=true
 check_area_music("m0")
 await position_at(Elsa.castle_point(Vector2i(28,88)))
 game.model.team_progression.level=1;game.model.gold=0
 var saved_preferences=FileAccess.get_file_as_bytes(game.settings_path)
 check(preload("res://scripts/forest/forest_travel_stones.gd").open(game),"E interaction opens the castle time passage")
 check(is_instance_valid(game.dialogue),"Castle activation asks before travelling")
 game.dialogue.chosen.emit("cancel")
 for i in 3:await physics_frame
 check(Tour.area(game.model)=="castle" and not game.transitioning,"Cancelling the stone preserves the current area")
 check(preload("res://scripts/forest/forest_travel_stones.gd").open(game),"Castle stone can be used again after cancelling")
 game.dialogue.chosen.emit("travel")
 for i in 6:await physics_frame
 check(game.model.falan_floor==59511,"Castle stone enters the actual time passage")
 check(game.model.team_progression.level==1 and game.model.gold==0,"Castle stone accepts level 1 with zero gold and charges no fee")
 check_area_music("")
 game.settings.music_enabled=false;game.apply_music_setting()
 game.settings.music_enabled=true;game.apply_music_setting()
 check(not game.music.playing,"Time passage remains silent when music is re-enabled")
 check(game.explorer_clock.fixed_space,"Time passage uses its recovered dark environment")
 await fixed_view("time-passage")
 for step in [[59510,Vector2i(19,17)],[59500,Vector2i(96,138)],[59501,Vector2i(124,168)],[59520,Vector2i(264,108)]]:
  var id:int=game.model.falan_floor;var at=Original.source_point(id,step[1])
  var link=game.model.get_meta("falan_links",[]).filter(func(l):return l.get("floor")==step[0] and l.at==at)[0]
  check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(at,.15),.5),"Native navigation connects the real journey crossing "+str(id))
  game.falan_crossing_position=at+Vector2(4,0)
  game.player.position=game.model.world_point(at,.15);game.player.velocity=Vector3.ZERO
  check(Tour.cross_on_foot(game),"On-foot journey crossing "+str(step[0]))
  for i in 6:await physics_frame
  check(game.model.falan_floor==step[0],"Real crossing reaches "+str(step[0]))
  check_area_music({59510:"puk2_haikyo",59500:"puk2_field1",59501:"puk2_field1",59520:"puk2_mati"}[step[0]])
  var landed=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  check(landed.distance_to(link.arrival)<.5,"Real crossing keeps the archived landing "+str(step[0]))
  await fixed_view("arrival-"+str(step[0]))
 await position_at(Original.source_point(59520,Vector2i(140,104)))
 game.model.gold=1234
 var return_gold=game.model.gold
 var return_progression=game.model.team_progression
 check(game.army_runtime.handles.is_empty(),"The island arrival remains safe")
 check(preload("res://scripts/forest/forest_travel_stones.gd").open(game),"Return stone uses the ordinary E interaction")
 game.dialogue.chosen.emit("travel")
 for i in 6:await physics_frame
 check(Tour.area(game.model)=="castle","Return stone completes the round trip")
 check(game.model.gold==return_gold,"The return stone preserves the gold balance (%d → %d)"%[return_gold,game.model.gold])
 check(game.model.team_progression==return_progression,"The return stone keeps the current character progression")
 check_area_music("m0")
 check(not game.explorer_clock.fixed_space,"Castle restores normal Explore lighting after the time passage")
 check(game.player.position.distance_to(game.model.world_point(Elsa.castle_point(Vector2i(27,82)),.15))<.5,"Exact castle return landing")
 check(FileAccess.get_file_as_bytes(game.settings_path)==saved_preferences,"Round trip does not rewrite saved preferences or home state")
 await fixed_view("castle-return")
 print("ELSA_NORMAL_ROUND_TRIP checks=",checks," failures=",failures," fixture_waypoints=true continuous=false")

func check_area_music(key:String):
 game.battle_music_left=0.;game.sync_area_music();game.apply_music_setting()
 var stream:AudioStream=Music.STREAMS.get(key)
 check(game.music.stream==stream,"Journey selects original area track "+key)
 check(game.music.playing if stream!=null else not game.music.playing,"Journey honors original playback or silence "+key)

func branch_doors():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-elsa-door-test.cfg"
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.explorer_clock.save_left=600.
 # Direct placement isolates each entrance. --play also uses fixture waypoints;
 # continuous input-driven travel is a separate required journey check.
 var cases=[[59520,175,62,59530],[59530,79,55,59520],[59520,200,95,59530],[59530,59,93,59520],
  [59520,228,128,59530],[59530,81,133,59520],[59530,95,80,59534],[59534,44,41,59531],
  [59531,34,34,59535],[59535,48,61,59536],[59536,27,28,59535],[59531,17,33,59537],
  [59537,105,76,59531],[59537,104,88,59600],[59537,80,64,59607],[59537,103,65,59614],
  [59537,81,87,59621],[59530,155,96,59741]]
 for entry in cases:
  var id:int=entry[0];var at=Original.source_point(id,Vector2i(entry[1],entry[2]))
  Tour.travel(game,Original.layout(id),{"arrival":at,"yaw":0.,"velocity":Vector3.ZERO})
  for i in 4:await physics_frame
  var links:Array=game.model.get_meta("falan_links",[]).filter(func(link):return link.at==at and link.get("floor",0)==entry[3])
  check(links.size()==1,"Targeted entrance exists %s"%[entry])
  if links.is_empty():continue
  var link:Dictionary=links[0]
  if link.has("elsa_event"):
   check(Elsa.open(game),"Original branch uses normal E interaction %s"%[entry])
   if not is_instance_valid(game.dialogue):continue
   if link.get("elsa_stone","")=="temple_return":
    check(not link.get("walk_in",false),"Temple return stone never activates as an automatic reverse doorway")
    game.dialogue.chosen.emit("cancel")
    for i in 2:await physics_frame
    check(game.model.falan_floor==id,"Cancelling the temple return preserves the room")
    check(Elsa.open(game),"The temple stone can be activated again after cancelling")
   var options:Array=game.dialogue.pages[game.dialogue.page].options
   var selected=options.filter(func(option):return str(option[0])=="travel" if link.get("elsa_stone","")=="temple_return" else str(option[1])==str(link.caption))
   check(selected.size()==1,"Branch menu identifies its original destination %s"%[entry])
   if selected.is_empty():game.dialogue.chosen.emit("cancel");continue
   game.dialogue.chosen.emit(str(selected[0][0]))
  else:
   check(link.get("walk_in",false),"Source door uses normal on-foot travel %s"%[entry])
   game.falan_crossing_position=at+Vector2(2.5,0)
   game.player.position=game.model.world_point(at,.15);game.player.velocity=Vector3.ZERO
   check(Tour.cross_on_foot(game),"Source door accepts the crossing %s"%[entry])
  for i in 6:await physics_frame
  check(game.model.falan_floor==entry[3],"Door reaches its source destination %s"%[entry])
  var landed=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  check(landed.distance_to(link.arrival)<.5,"Door keeps the original landing %s"%[entry])
  print("ELSA_DOOR ",entry)
 print("ELSA_DOORS_RESULT checks=",checks," failures=",failures)

func art_views():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-elsa-views.cfg"
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.explorer_clock.save_left=600.
 var views=[[59511,Vector2i(19,19),"time-current"],[59520,Vector2i(140,104),"island-return-current"],[59520,Vector2i(146,99),"tower-current"],[59520,Vector2i(193,100),"temple-facade-current"],[59530,Vector2i(95,88),"temple-hall-current"],[59537,Vector2i(92,76),"elemental-hall-current"]]
 if "--facade" in OS.get_cmdline_user_args():views=views.filter(func(view):return view[2] in ["tower-current","temple-facade-current"])
 for view in views:
  var state:Dictionary=Original.state(view[0])
  check(Original.open(state.bits,state.size,view[1]),"Fixed gameplay camera stands on original walkable ground "+view[2])
  var at=Original.source_point(view[0],view[1]);var link=Original.door(at,view[0],at);link.yaw=0.
  Tour.enter_link(game,Tour.area(game.model),link,at)
  for i in 8:await physics_frame
  await position_at(at);await fixed_view(view[2])
  check(game.model.falan_floor==view[0],"Fixed review area "+view[2])
 print("ELSA_FIXED_VIEWS checks=",checks," failures=",failures)

func fixed_view(label:String):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.yaw=0.;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH
 game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance()
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 var folder="res://build/Other Files/Asset Toolkit/Elsa Island/First Gameplay/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.get_texture().get_image().save_png(folder+label+".png")
