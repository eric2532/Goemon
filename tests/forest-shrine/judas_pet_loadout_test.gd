extends "res://tests/forest-shrine/pet_loadout_test.gd"
const JUDAS_OUT="res://build/Other Files/Asset Toolkit/Cross Gate Judas Family/Gameplay/"
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(JUDAS_OUT+stem+".png")==OK,"Captured "+stem)
func run():
 create_timer(240).timeout.connect(func():quit(1));DirAccess.make_dir_recursive_absolute(JUDAS_OUT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data);game.player.select_character(34);fresh()
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.player.position=Vector3(-150,0,127);game.player.position.y=game.model.surface_height(-150,127)
 var army=game.army_runtime
 var skins=range(Pets.COUNT).filter(func(skin):return Pets.category(skin)=="bosses")
 check(skins.size()==36 and Pets.COUNT>=434,"All main and archive boss looks retain their original slots")
 check(skins.filter(func(s):return Pets.listed(s)).size()==24,"Only the 24 distinct boss looks are listed")
 check(range(Pets.COUNT).filter(func(s):return Pets.listed(s)).size()==Pets.COUNT-12,"Only twelve duplicate archive entries are hidden")
 check(Pets.skin("puk3:839")!=Pets.skin("puk3:920") and Pets.skin("puk3:916")>=398,"Reused numeric IDs keep their exact source identities")
 for character in game.player.RogueRoster.CROSSGATE:
  game.player.select_character(character);game.show_pet_loadout();await frames()
  var panel=game.pet_loadout_panel;panel.filter("bosses")
  check(panel.cards.filter(func(c):return c.visible).size()==24,"Distinct bosses selectable for Cross Gate fighter "+str(character))
  game.close_pet_loadout();await frames()
 game.player.select_character(34)
 game.show_pet_loadout();var panel=game.pet_loadout_panel;panel.filter("bosses");await capture("picker-bosses")
 root.size=Vector2i(960,640);await frames();await capture("picker-small")
 check(root.get_visible_rect().encloses(panel.panel.get_global_rect()) and panel.panel.get_global_rect().encloses(panel.find_child("ClosePetLoadout",true,false).get_global_rect()),"Boss picker and Close fit the small window")
 root.size=Vector2i(1280,800)
 var keys:Array[String]=["original:2980","puk3:874","puk3:712","puk3:916","original:605"]
 var skill_family=preload("res://scripts/spells/skill_balance.gd").Levels.family("kazi/qigong")
 game.model.team_progression.pet_skill_levels[keys[-1]]={skill_family:7}
 check(game.save_pet_loadout(game.settings.forest_pet_loadout,{keys[-1]:["kazi/qigong","",""]}),"Prepare the archived pet skill through the shared save owner")
 panel.selected=keys;panel.refresh();panel.apply();game.close_pet_loadout();game.load_settings()
 check(game.settings.forest_pet_loadout==keys,"Current, effect, remodeled and archive keys survive saving")
 check(game.settings.forest_pet_skills[keys[-1]][0]=="kazi/qigong" and game.model.team_progression.pet_skill_levels[keys[-1]][skill_family]==7,"Hidden archive pets retain their saved skill assignment and learned level")
 press_p();arrive();check(population()==5,"Five mixed boss variants arrive through the native queue")
 var skin=Pets.skin(keys[0]);var handle:int=army.handles[army.HOUND_ID-skin]
 army.apply_hit(handle,{"amount":30.0});arrive();var hp:float=army.unit_state(handle).hp
 army.queue_hounds();arrive();check(population()==5 and army.unit_state(handle).hp==hp,"Missing-only queuing neither duplicates nor heals a living boss pet")
 for order in [army.HoundOrder.HOLD,army.HoundOrder.ATTACK,army.HoundOrder.RETURN]:
  check(army.order_hounds(order),"Boss pets obey the existing F/G/H owner");arrive()
 var mesh:QuadMesh=game.crowd.army.meshes[19];var texture=mesh.material.get_shader_parameter("pixels")
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT));var times=[]
 for i in 180:
  var started=Time.get_ticks_usec();army.integration_tick(1.0/60);army.flush_presentation();game.crowd.army.presentation.tick(1.0/60)
  times.append((Time.get_ticks_usec()-started)/1000.0)
 check(mesh.material.get_shader_parameter("pixels")==texture,"Warmed boss combat keeps the prepared texture bank")
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=nodes+2 and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources+2,"Warmed five-boss workload retains bounded nodes and resources")
 game.forest_ui.sync();game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 var camera=game.camera_rig.camera;camera.global_position=game.player.position+Vector3(-4,18,30);camera.look_at(game.player.position+Vector3.UP)
 game.crowd.army.presentation.tick(1.0);game.crowd.present_army(army.render_snapshot(),[]);await capture("five-boss-pack")
 times.sort();print("JUDAS_PACK_METRICS pages=",mesh.get_meta("prepared_pages").size()+1," step_p95_ms=",times[170]," step_max_ms=",times[-1])
 army.apply_hit(handle,{"amount":100000.0});army.queue_hounds();arrive()
 check(population()==5 and army.handles[army.HOUND_ID-skin]!=handle,"A fallen boss is replaced without duplicating survivors")
 check(game.save_pet_loadout([]),"Empty boss loadout saves");press_p();arrive();check(population()==0,"Empty loadout recalls every boss pet")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("JUDAS_LOADOUT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
