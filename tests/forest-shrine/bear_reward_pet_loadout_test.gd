extends "res://tests/forest-shrine/pet_loadout_test.gd"
func reward_category()->String:return "灰熊厲害"
func reward_count()->int:return 127
func reward_keys()->Array[String]:return ["puk3:724","puk2:1318","ex:1705","ex:1101","ex:1102"]
func reward_output()->String:return "res://build/Other Files/Asset Toolkit/Bear Challenge Pets/A Rank Recheck/Gameplay/"
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(reward_output()+stem+".png")==OK,"Captured "+stem)
func run():
 create_timer(240).timeout.connect(func():quit(1));DirAccess.make_dir_recursive_absolute(reward_output())
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data);game.player.select_character(34);fresh()
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.player.position=Vector3(-150,0,127);game.player.position.y=game.model.surface_height(-150,127)
 for character in game.player.RogueRoster.CROSSGATE:
  game.player.select_character(character);game.show_pet_loadout();await frames()
  game.pet_loadout_panel.filter(reward_category())
  check(game.pet_loadout_panel.cards.filter(func(c):return c.visible).size()==reward_count(),reward_category()+" rewards selectable for Cross Gate fighter "+str(character))
  game.close_pet_loadout();await frames()
 game.player.select_character(34);game.show_pet_loadout();var panel=game.pet_loadout_panel
 panel.filter(reward_category());await capture("picker")
 root.size=Vector2i(960,640);await frames();await capture("picker-small")
 check(root.get_visible_rect().encloses(panel.panel.get_global_rect()) and panel.panel.get_global_rect().encloses(panel.find_child("ClosePetLoadout",true,false).get_global_rect()),"Reward picker and Close fit the small window")
 root.size=Vector2i(1280,800)
 var keys:Array[String]=reward_keys()
 for slot in keys.size():
  var index=Pets.skin(keys[slot])
  check(index>=0 and panel.cards[index].visible and panel.cards[index].icon!=null,"Reward has a visible picker card and portrait for "+keys[slot])
  panel.select_slot(slot);panel.cards[index].pressed.emit()
 game.close_pet_loadout();game.load_settings()
 check(game.settings.forest_pet_loadout==keys,"Reward source keys survive settings reload")
 press_p();arrive();check(population()==5,"Five distinct reward pets arrive through the native owner")
 var army=game.army_runtime;var handle:int=army.handles[army.HOUND_ID-Pets.skin(keys[0])]
 army.apply_hit(handle,{"amount":30.0});arrive();var hp:float=army.unit_state(handle).hp
 army.queue_hounds();arrive();check(population()==5 and army.unit_state(handle).hp==hp,"Reconciliation preserves survivors and wounds")
 for order in [army.HoundOrder.HOLD,army.HoundOrder.ATTACK,army.HoundOrder.RETURN]:
  check(army.order_hounds(order),"Reward pets obey the shared F/G/H commands");arrive()
 var mesh:QuadMesh=game.crowd.army.meshes[19];var texture=mesh.material.get_shader_parameter("pixels")
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT));var times=[]
 for i in 180:
  var started=Time.get_ticks_usec();army.integration_tick(1.0/60);army.flush_presentation();game.crowd.army.presentation.tick(1.0/60)
  times.append((Time.get_ticks_usec()-started)/1000.0)
 check(mesh.material.get_shader_parameter("pixels")==texture,"Warmed reward combat reuses its prepared atlas")
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=nodes+2 and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources+2,"Warmed reward nodes and resources remain bounded")
 game.forest_ui.sync();game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 var camera=game.camera_rig.camera;camera.global_position=game.player.position+Vector3(-4,18,30);camera.look_at(game.player.position+Vector3.UP)
 game.crowd.army.presentation.tick(1.0);game.crowd.present_army(army.render_snapshot(),[]);await capture("five-reward-pack")
 times.sort();print("REWARD_PACK_METRICS family=",reward_category()," pages=",mesh.get_meta("prepared_pages").size()+1," step_p95_ms=",times[170]," step_max_ms=",times[-1])
 press_p();arrive();check(population()==0,"P recalls the reward pack")
 press_p();arrive();check(population()==5,"P resummons the saved reward pack")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("REWARD_LOADOUT_RESULT family=",reward_category()," checks=",checks," failures=",failures);quit(1 if failures else 0)
