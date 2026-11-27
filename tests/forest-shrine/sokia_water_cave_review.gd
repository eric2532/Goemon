extends "res://tests/forest-shrine/sokia_server_npcs_review.gd"
## Existing source map/NPC/native owners; review flags change only inside this process.
const WATER_OUT=SERVER_OUT+"Water Cave/"
func wall_bindings():
 Original.Art.load_sokia_water();var rows=[]
 for id in [13506,13507,13510]:
  var scene=Node3D.new();root.add_child(scene);Original.build(scene,id)
  for node in scene.find_children("*","GeometryInstance3D",true,false):
   var mesh:Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D else null
   if mesh==null:continue
   var surfaces=[]
   for slot in mesh.get_surface_count():
    var material:Material=node.material_override if node.material_override!=null else mesh.surface_get_material(slot)
    var texture:Texture2D=material.get_shader_parameter("base_texture")if material is ShaderMaterial else null
    var arrays:Array=mesh.surface_get_arrays(slot);var low=Vector2.INF;var high=-low
    for uv:Vector2 in arrays[Mesh.ARRAY_TEX_UV]:low=low.min(uv);high=high.max(uv)
    surfaces.append({"material":material.get_class(),"texture":texture.resource_path if texture!=null else"","texture_source":texture.get_meta("original_source_page","")if texture!=null else"","uv_min":str(low),"uv_max":str(high),"base_color":str(material.get_shader_parameter("base_color"))if material is ShaderMaterial else"","use_base_texture":material.get_shader_parameter("use_base_texture")if material is ShaderMaterial else null,"archive_triplanar":material.get_shader_parameter("archive_triplanar")if material is ShaderMaterial else null,"falan_source_projection":material.get_shader_parameter("falan_source_projection")if material is ShaderMaterial else null,"atlas_tile_pixels":material.get_shader_parameter("atlas_tile_pixels")if material is ShaderMaterial else null})
   rows.append({"map":id,"node":str(node.get_path()),"class":node.get_class(),"source_graphic":node.get_meta("source_graphic",0),"bounds":str(mesh.get_aabb()),"surfaces":surfaces})
  scene.queue_free();await process_frame
 var file=FileAccess.open(WATER_OUT+"wall-bindings-headless.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "));file.close()
 print("SOKIA_WATER_WALL_BINDINGS ",rows.size());quit()
func branch(id:String,answers:Array,ctx:Dictionary={})->Dictionary:
 var source:Dictionary=Population.server_events(int({"6704":13503,"6706":13505,"6715":13514,"6716":13515}.get(id,13506)))
 var actor:Dictionary=source.actors[id]
 var session=Events.begin_context(actor,source.scripts[actor.script],context()if ctx.is_empty()else ctx)
 for answer in answers:
  if session.status!="window":break
  Events.choose_context(session,answer)
 npc_report.branches.append({"actor":id,"status":session.status,"destination":session.get("destination",[]),"blocker":session.get("blocker",{})})
 return session
func source_branches():
 var eating=branch("6706",["OK","OK","OK","OK","YES","OK"])
 check(eating.status=="warp"and eating.destination==[0,13506,6,8],"Original six-window choice retains the exact dining-room landing")
 var last=branch("6715",["OK","OK"])
 check(last.status=="warp"and last.destination==[0,13515,6,3],"Original solo branch reaches the final Water Cave room")
 var ctx=context()
 for item in [18431,18432,18433,18434]:ctx.items["source_item_%d"%item]=6
 var returning=branch("6716",["OK"],ctx)
 check(returning.status=="warp"and returning.destination==[0,13503,41,39],"All four exact six-item predicates preserve the source return")
 var unknown=branch("6707",[])
 check(unknown.status=="blocked","Unknown original skill/capacity predicates cannot choose a multi-destination branch")
func take_view(label_:String,cell:Vector2i,yaw:float=0.,screen_offset:float=0.):
 await super.take_view("Water Cave/"+label_.trim_prefix("NPCs and gates/"),cell,yaw,screen_offset)
func run():
 if "--wall-bindings"in OS.get_cmdline_user_args():await wall_bindings();return
 root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WATER_OUT));source_branches()
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-water-cave-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.player.set_auto_attack(false);game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"));Original.Art.load_sokia_water();var flags={}
 for id in range(13500,13516):
  var source:Dictionary=Original.Art.data().maps[Original.path_for(id)];flags[id]=source.get("sokia_visual_only",false)
  check(Original.owns(id)and not flags[id],"Verified Water floors use normal production dispatch without fixture review overrides")
 var zone_ids={13507:7035,13508:7036,13509:7037,13511:7038,13512:7039,13513:7041,13515:7042}
 for id in range(13500,13516):
  print("SOKIA_WATER_ENTER ",id);await visit(id)
  var candidates=candidate_cells(id);var cell=clear_cell(id,candidates)
  check(game.world.map_features.get_meta("recovered_source_map")==id,"The existing static map owner builds every Water Cave floor "+str(id))
  check(game.world.map_features.find_child("WaterCaveSourceCliffs",true,false)!=null,"Source contours reuse the continuous cliff owner "+str(id))
  var tall=Original.Art.data().sokia_water_cliffs.profiles.keys().filter(func(key):return float(Original.Art.data().sokia_water_cliffs.profiles[key].height)>=3.)
  check(not game.world.map_features.find_children("*","MultiMeshInstance3D",true,false).any(func(node):return str(node.get_meta("source_graphic",0))in tall),"Every tall source fragment has one continuous owner, without generic solid columns")
  check(Original.Art.pending_page_uploads.is_empty(),"Setup completes pending exact page uploads")
  await take_view("%d-source-normal"%id,cell,PI*.5)
  var source:Dictionary=Population.server_events(id);var actors=source.actors.values().filter(func(a):return int(a.source)==id)
  for actor in actors:await interact_source(actor.id)
  npc_report.maps.append({"id":id,"cell":str(cell),"actors":actors.map(func(a):return a.id),"review_only_before_fixture":flags[id],"source_flags_available":Original.Art.data().maps[Original.path_for(id)].get("source_flags_available",true)})
  if zone_ids.has(id):
   var zone:Dictionary=Population.data().zones.filter(func(z):return int(z.id)==int(zone_ids[id]))[0]
   var in_zone=candidates.filter(func(c):return int(Population.zone_at(id,c).get("id",-1))==int(zone.id))
   check(not in_zone.is_empty(),"A source-confirmed ordinary zone has a reachable study cell")
   if not in_zone.is_empty():await direct_group(id,clear_cell(id,in_zone),"server:7032",zone)
  if id==13507:
   for pair in [[7040,"server:7028"],[7043,"server:7030"]]:
    var zone:Dictionary=Population.water_data().zones.filter(func(z):return int(z.id)==pair[0])[0]
    var in_zone=candidates.filter(func(c):return int(Population.zone_at(id,c).get("id",-1))==int(zone.id))
    check(not in_zone.is_empty(),"Each rare source strip has a reachable source cell")
    if not in_zone.is_empty():await direct_group(id,clear_cell(id,in_zone),pair[1],zone)
 for id in [13500,13501,13502,13503]:
  for link in Original.links(id):
   if int(link.get("floor",-1))not in[13500,13501,13502,13503]:continue
   await visit(id);Tour.enter_link(game,"interior",link,link.at)
   for i in 5:await physics_frame
   freeze();check(game.model.falan_floor==int(link.floor),"Existing fixed-port owner realizes exact Water Cave transfer")
   npc_report.ports.append({"source":id,"target":link.floor,"arrival":str(link.get("source_arrival",link.arrival))})
 check(not Original.links(13502).any(func(link):return int(link.get("floor",-1))in[13503,13504]),"Unknown Warp13/item-phase branches do not become unconditional inbound gates")
 for id in flags:Original.Art.data().maps[Original.path_for(id)].sokia_visual_only=flags[id]
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Water Cave source QA preserves saved adventure data")
 npc_report.checks=checks;npc_report.failures=errors;npc_report.captures=server_report.captures;npc_report.groups=server_report.groups
 npc_report.limitations=["Unknown source Warp13 extra operands, skill/capacity and multi-destination selection remain guarded.","Original encounter count/stat/probability-ramp execution is unverified; fixed source levels/weights and rare identities use the existing native adaptation.","One normal camera per floor is an initial rendered review, not whole-map visual completion.","Solid cliff backs/caps are inferred; original source cells, flags, profiles and map/NPC anchors are preserved."]
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var file=FileAccess.open(WATER_OUT+"review-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(npc_report,"  ")+"\n");file.close()
 print("SOKIA_WATER_RESULT checks=",checks," failures=",errors," maps=",npc_report.maps.size()," actors=",npc_report.actors.size()," groups=",npc_report.groups.size()," captures=",npc_report.captures.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
