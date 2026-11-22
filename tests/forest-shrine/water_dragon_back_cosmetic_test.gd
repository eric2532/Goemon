extends "res://tests/forest-shrine/cosmetic_equipment_test.gd"
const CROSS="cosmetic:water-dragon-cross"
const REVIEW="res://build/Other Files/Asset Toolkit/Water Dragon Cross/"

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 if stem!="equipped-menu":
  var camera=game.camera_rig.camera
  camera.h_offset=0;camera.v_offset=0
  camera.global_position=game.player.global_position+Vector3(0,1.8,5)
  camera.look_at(game.player.global_position+Vector3.UP*.9)
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REVIEW+stem+".png")==OK,"Capture "+stem)

func run():
 cfg="user://water-dragon-back-%d.cfg"%OS.get_process_id()
 create_timer(180).timeout.connect(func():printerr("WATER_DRAGON_BACK_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(REVIEW);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg
 root.add_child(game);current_scene=game;await frames()
 game.settings.gear_loadouts={};game.settings.cosmetic_loadouts={};game.settings.forest_pet_loadout=[]
 game.begin_arena();game.choose_rogue_character(37);await frames()
 var hub=game.equipment_hub;hub.select_skin(900050);hub.show_page("cosmetics")
 check(Catalog.items().has(CROSS) and hub.collection.has(CROSS),"Crossed weapons appear in the existing cosmetic collection")
 check(Gear.ITEMS[CROSS].name=="水龍 · Crossed Spear & Axe","Special cosmetic keeps its name without a fabricated source ID")
 hub.selected_slot="1";hub.selected_item=CROSS;hub.equip_selected()
 check(hub.preview_layers.selected==[CROSS],"The equipped menu preview uses the crossed weapons")
 await picture("equipped-menu")
 hub.enter_map();await frames(4)
 game.set_physics_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player;p.set_physics_process(false)
 p.position=Vector3(-120,0,125);p.velocity=Vector3.ZERO
 p.position.y=game.world.surface_height_at(p.position)+.1
 game.camera_rig.set_process(false)
 game.camera_rig.camera.position=p.position+Vector3(0,3.4,7)
 game.camera_rig.camera.look_at(p.position+Vector3.UP*1.5)
 game.load_settings();Gear.apply(p)
 var model=p.model;model.set_process(false)
 check(model.cosmetic_layers.selected==[CROSS],"Equipped cosmetic survives disk reload and reaches gameplay")
 for direction in 8:
  for action in [0,1,3,5,6,8,10]:
   var pose="%d:%d"%[action,direction]
   if not model.motions.clips.has(pose):continue
   model.show_frame(action,pose,0);model.cosmetic_layers.update(.016,model.sprite,pose,true)
   var node:Sprite3D=model.cosmetic_layers.nodes[0]
   check(node.visible and node.texture!=null,"Prepared crossed weapons follow "+pose)
   var depth:float=node.get_instance_shader_parameter("layer_depth")
   check((depth>0)==(direction in [0,1,2]),"Weapons stay behind the body in front views: "+pose)
  model.show_frame(0,"0:%d"%direction,0);model.cosmetic_layers.update(0,model.sprite,model.current_clip,true)
  await picture("facing-%d"%direction)
 var count=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 600:
  model.show_frame(3,"3:%d"%(i%8),0);model.cosmetic_layers.update(.016,model.sprite,model.current_clip,true)
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==count and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated animation retains existing nodes and resources")
 model.set_process(true);p.facing=Vector3.BACK;p.set_physics_process(true)
 var start=p.position
 control("move_left",true);await create_timer(.35).timeout;await picture("walking")
 control("sprint",true);await create_timer(.35).timeout;await picture("sprinting")
 control("sprint",false);control("move_left",false);await create_timer(.15).timeout
 check(p.position.distance_to(start)>.2 and not Input.is_action_pressed("sprint"),"Normal walk and Shift press/release move the equipped wearer")
 p.set_physics_process(false)
 var copies=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 3:
  check(copies.reinforce(37,p.position+Vector3.RIGHT*i),"Native copy uses the existing owner")
  copies.bodies.back().model._process(.016)
  check(copies.bodies.back().model.cosmetic_layers.selected==[CROSS],"Native copy inherits the same cosmetic")
 var retired=copies.bodies.duplicate();copies.dispose();await frames()
 check(retired.all(func(body):return not is_instance_valid(body)),"Native retirement releases cosmetic children")
 for character in Gear.Roster.CROSSGATE:
  game.settings.cosmetic_loadouts[Gear.character_key(character)]={"qi_color":"","slots":{"1":CROSS}}
  p.select_character(character);Gear.apply(p)
  var visual=p.model
  for direction in 8:
   var pose="0:%d"%direction
   visual.show_frame(0,pose,0);visual.cosmetic_layers.update(0,visual.sprite,pose,true)
   check(visual.cosmetic_layers.nodes[0].visible and Catalog.bound_tables.get(visual.sprite.texture.resource_path,{}).has(Vector2i(visual.sprite.region_rect.position)),"Prepared back attachment on Cross Gate character %d facing %d"%[character,direction])
 p.select_character(37);Gear.apply(p)
 game.show_equipment_hub(true);await frames();hub=game.equipment_hub;hub.show_page("cosmetics")
 hub.selected_slot="1";hub.unequip()
 check(not p.model.cosmetic_layers.selected.has(CROSS),"Unequip removes the back cosmetic")
 game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("WATER_DRAGON_BACK_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
