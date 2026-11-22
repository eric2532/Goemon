extends "res://tests/forest-shrine/pet_loadout_test.gd"
const EXPANSION_OUT="res://build/Other Files/Asset Toolkit/Cross Gate Pet Expansion/Gameplay/"
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(EXPANSION_OUT+stem+".png")==OK,"Captured "+stem)
func run():
 create_timer(240).timeout.connect(func():quit(1));DirAccess.make_dir_recursive_absolute(EXPANSION_OUT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data);game.player.select_character(34);fresh()
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.player.position=Vector3(-150,0,127);game.player.position.y=game.model.surface_height(-150,127)
 var army=game.army_runtime;var groups={}
 for i in range(82,Pets.COUNT):
  if not Pets.listed(i):continue
  var category_=Pets.category(i)
  if not groups.has(category_):groups[category_]=[]
  groups[category_].append(i)
 check(groups.size()==22,"All reviewed pet families, including A/S and sponsor rewards, are selectable")
 for character in game.player.RogueRoster.CROSSGATE:
  game.player.select_character(character);game.show_pet_loadout();await frames()
  check(game.pet_loadout_panel.cards.size()==Pets.COUNT and game.pet_loadout_panel.category_picker.item_count==Pets.categories().size(),"Expanded selection works for Cross Gate fighter "+str(character))
  game.close_pet_loadout();await frames()
 game.player.select_character(34)
 press_p(true);await frames();var panel=game.pet_loadout_panel
 check(panel.cards.size()==Pets.COUNT and panel.cards.all(func(c):return c.icon!=null),"Every existing and new skin has a picker image")
 check(panel.category_picker.item_count==Pets.categories().size(),"Family selector includes all families and the existing effects filter")
 var first_pack:Array[String]=[]
 for category_ in groups:
  panel.filter(category_)
  check(panel.cards.filter(func(c):return c.visible).size()==groups[category_].size(),"Exact family membership: "+category_)
  await capture("picker-"+category_.to_lower().replace(" ","-"))
  if first_pack.size()<5:first_pack.append(Pets.key(groups[category_][0]))
 panel.selected=first_pack;panel.refresh();panel.apply();game.close_pet_loadout();army.queue_hounds();arrive()
 check(population()==5,"Five mixed new families arrive through the existing native owner")
 var id=army.HOUND_ID-Pets.skin(first_pack[0]);var handle:int=army.handles[id]
 army.apply_hit(handle,{"amount":30.0});arrive();var wounded:float=army.unit_state(handle).hp
 army.queue_hounds();arrive()
 check(population()==5 and army.unit_state(handle).hp==wounded,"Missing-only queuing keeps the new pets and their wounds")
 for order in [army.HoundOrder.HOLD,army.HoundOrder.ATTACK,army.HoundOrder.RETURN]:
  check(army.order_hounds(order),"F/G/H commands use the shared native pet owner")
  arrive()
 game.forest_ui.sync();game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 var camera=game.camera_rig.camera;camera.global_position=game.player.position+Vector3(-4,18,30);camera.look_at(game.player.position+Vector3.UP)
 var mesh:QuadMesh=game.crowd.army.meshes[19]
 var prepared:Array=mesh.get_meta("prepared_pages")
 check(prepared.size()<int(Pets.motions().pages),"Only selected-pack atlas pages are resident")
 var texture=mesh.material.get_shader_parameter("pixels")
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT));var times=[]
 for i in 180:
  var started=Time.get_ticks_usec();army.integration_tick(1.0/60);army.flush_presentation();game.crowd.army.presentation.tick(1.0/60)
  times.append((Time.get_ticks_usec()-started)/1000.0)
 check(mesh.material.get_shader_parameter("pixels")==texture,"Repeated combat never reloads/rebuilds the selected sprite atlas")
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=nodes+2 and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources+2,"Warmed mixed-pet nodes and resources stay bounded")
 game.crowd.army.presentation.tick(1.0);game.crowd.present_army(army.render_snapshot(),[]);await capture("mixed-families")
 times.sort();print("EXPANSION_PACK_METRICS pages=",prepared.size()+1," total_pages=",Pets.motions().pages," step_p95_ms=",times[170]," step_max_ms=",times[-1])
 var effects:Array[String]=[]
 for i in range(82,Pets.COUNT):
  if Pets.effect(i) and effects.size()<5:effects.append(Pets.key(i))
 check(game.save_pet_loadout(effects),"Special/event appearance pack saves")
 army.queue_hounds();arrive();check(population()==5,"Five simultaneous effect variants use the same lifecycle")
 var prior_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 6:
  game.show_pet_loadout();await frames();game.close_pet_loadout();await frames()
 check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=prior_resources+2,"Repeated expanded picker openings retain no additional resources")
 game.load_settings();check(game.settings.forest_pet_loadout==effects,"New exact source keys survive settings reload")
 game.show_pet_loadout();panel=game.pet_loadout_panel;panel.filter("Aura & effects");root.size=Vector2i(960,640);await frames();await capture("effects-small-window")
 check(root.get_visible_rect().encloses(panel.panel.get_global_rect()),"Expanded family picker fits the smaller window")
 check(panel.panel.get_global_rect().encloses(panel.category_picker.get_global_rect()) and panel.panel.get_global_rect().encloses(panel.find_child("ClosePetLoadout",true,false).get_global_rect()),"Family selector and Close remain reachable")
 game.close_pet_loadout();game.save_pet_loadout([]);press_p();arrive();check(population()==0,"An empty pack recalls new pets without adding a fallback")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PET_EXPANSION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
