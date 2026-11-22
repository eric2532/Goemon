extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Gear=preload("res://scripts/forest/equipment.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const OUT="res://build/Other Files/Asset Toolkit/Equipment Hub/Cosmetic Preview/"
const ITEMS=["cosmetic:119802","cosmetic:119010","cosmetic:115809","cosmetic:115801"]
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 var hub=game.equipment_hub;var viewport=hub.character_preview.get_child(0)
 var bounds=hub.preview_bounds(hub.preview_body);var screen=Rect2(Vector2.ZERO,Vector2(viewport.size))
 check(screen.has_point(hub.preview_camera.unproject_position(Vector3(bounds.position.x,bounds.position.y,0))) and screen.has_point(hub.preview_camera.unproject_position(Vector3(bounds.end.x,bounds.end.y,0))),"The wearer stays inside the fixed preview: "+stem)
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)
func run():
 create_timer(180).timeout.connect(func():printerr("EQUIPMENT_COSMETIC_PREVIEW_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.forest_pet_loadout=[Pets.key(0)];game.save_settings()
 game.begin_arena()
 game.choose_rogue_character(37);await frames(3)
 var hub=game.equipment_hub;var visual=game.player.model
 check(hub.portrait.size.y>96 and is_equal_approx(hub.preview_camera.size,4.4),"The character has a larger preview with a closer camera")
 check(hub.character_preview.visible and not hub.portrait.visible,"Character preview renders the equipped body instead of the undecorated gallery image")
 check(hub.allowed_icons[0].position==Vector2(48,296),"Supported weapons remain left aligned above Weapons")
 var original_pose=visual.current_clip;var original_frame=visual.current_frame
 var click=InputEventMouseButton.new();click.device=517;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=hub.portrait_button.get_global_rect().get_center()
 root.push_input(click,true);click=click.duplicate();click.pressed=false;root.push_input(click,true);await frames(3)
 check(is_instance_valid(hub.portrait_button.gallery),"Clicking the larger preview still opens the skin picker")
 if is_instance_valid(hub.portrait_button.gallery):hub.portrait_button.gallery.hide();await frames(3)
 hub.show_page("cosmetics");await capture("shin-before")
 var camera_position=hub.preview_camera.position;var camera_size=hub.preview_camera.size
 for id in ["115354","115469","115470","115606"]:
  hub.selected_slot="1";hub.selected_item="cosmetic:"+id;hub.equip_selected()
  hub.preview_layers.elapsed=0.0;hub.preview_layers.update(0,hub.preview_body,"0:5",false)
  visual.cosmetic_layers.elapsed=0.0;visual._process(0.0)
  for placement in [[hub.preview_layers,"0:5"],[visual.cosmetic_layers,visual.current_clip]]:
   var item:Dictionary=Gear.Cosmetics.items()["cosmetic:"+id]
   var facing=placement[1].get_slice(":",placement[1].get_slice_count(":")-1)
   var clip:Dictionary=item.clips.get(placement[1],item.clips["0:"+facing])
   var frame:Array=clip.frames[0]
   var layer:Sprite3D=placement[0].nodes[0]
   var expected=Vector2(float(frame[5])+float(frame[3])*.5,visual.FEET_OFFSET_PIXELS-float(frame[6])-float(frame[4])*.5)
   check(layer.visible and layer.offset.is_equal_approx(expected),"Effect "+id+" starts at the feet in "+("Equipment" if placement[0]==hub.preview_layers else "gameplay"))
  await capture("foot-effect-"+id)
 hub.unequip()
 for action in hub.skill_buttons:
  var cell:Button=hub.skill_buttons[action];var level_:Label=hub.skill_levels[action]
  check(level_.position==cell.position+Vector2(3,1) and cell.get_rect().encloses(level_.get_rect()),"Skill level sits inside the top-left of its equipped cell")
  check(level_.get_theme_constant("outline_size")==3,"Skill level stays readable over the icon")
 for i in ITEMS.size():
  hub.selected_slot=str(i+1);hub.selected_item=ITEMS[i];hub.equip_selected()
  check(hub.preview_layers.selected==ITEMS.slice(0,i+1) and visual.cosmetic_layers.selected==hub.preview_layers.selected,"Menu and gameplay use the same equipped cosmetics")
  check(hub.preview_camera.position==camera_position and hub.preview_camera.size==camera_size,"Adding cosmetics preserves the character's screen position and scale")
 check(visual.current_clip==original_pose and visual.current_frame==original_frame,"Preview construction preserves the player's actual pose")
 var standing:Array=visual.body_clip(0,"0:5").frames[0]
 check(hub.preview_body.region_rect==Rect2(standing[1],standing[2],standing[3],standing[4]) and hub.preview_body.texture==visual.atlases[int(standing[0])],"Preview uses the selected skin's actual standing body frame")
 check(hub.preview_body.material_override==visual.body_materials[hub.preview_body.texture],"Preview shares the prepared immutable body material")
 var nodes=hub.preview_layers.nodes.duplicate();var viewport=hub.character_preview.get_child(0)
 var phases={}
 for i in 30:
  hub._process(.07)
  for node in nodes:phases[str(node.get_instance_id())+str(node.region_rect)]=true
 check(phases.size()>nodes.size(),"Equipped cosmetic animations advance in the menu")
 await capture("shin-equipped")
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=dimensions;await frames(3)
  check(hub.panel.get_global_rect().encloses(hub.character_preview.get_global_rect()),"The larger preview fits the menu at "+str(dimensions))
  check(hub.preview_body.pixel_size==visual.sprite.pixel_size and hub.preview_layers.nodes.all(func(node):return node.pixel_size==hub.preview_body.pixel_size),"Body and cosmetics retain the same source pixel scale")
  await capture("equipped-%dx%d"%[dimensions.x,dimensions.y])
 hub.selected_slot="1";hub.unequip()
 check(hub.preview_camera.position==camera_position and hub.preview_camera.size==camera_size,"Removing cosmetics keeps the same character framing")
 check(hub.preview_layers.selected==ITEMS.slice(1) and hub.preview_layers.nodes==nodes and not nodes.back().visible,"Unequip updates the preview and reuses its layers")
 var saved=hub.preview_layers.selected.duplicate();var path=game.settings_path
 game.settings_path="user://missing-preview-folder/settings.cfg";hub.selected_slot="1";hub.selected_item=ITEMS[0];hub.equip_selected();game.settings_path=path
 check(hub.preview_layers.selected==saved and game.player.model.cosmetic_layers.selected==saved,"A failed save restores the equipped preview")
 for i in 5:
  hub.selected_slot="1";hub.selected_item=ITEMS[0];hub.equip_selected();hub.unequip()
 check(hub.preview_layers.nodes==nodes and hub.character_preview.get_child(0)==viewport,"Repeated equipment changes retain one preview and reusable layer nodes")
 hub.select_owner(1)
 check(not hub.character_preview.visible and hub.portrait.visible and hub.portrait.texture==Pets.portrait(Pets.skin(Pets.key(0))),"Pet selection keeps its existing independent portrait")
 hub.select_owner(0)
 check(hub.character_preview.visible and hub.preview_layers.selected==saved,"Returning to the character restores its equipped appearance")
 # Review the shared standing attachment on the current Cross Gate roster only.
 for character in Gear.Roster.CROSSGATE:
  game.player.select_character(character);hub.refresh_party();hub.select_owner(0)
  var model=game.player.model;var frame:Array=model.body_clip(0,"0:5").frames[0]
  check(hub.preview_body.texture==model.atlases[int(frame[0])] and hub.preview_body.region_rect==Rect2(frame[1],frame[2],frame[3],frame[4]),"Cross Gate preview uses its own model: "+str(character))
 game.player.select_character(37);hub.refresh_party();hub.select_owner(0)
 var skin=Gear.Roster.skin_catalog(37).keys().filter(func(id):return id!=Gear.Roster.selected_skin(37,game.settings))[0]
 hub.select_skin(skin);await frames(3)
 check(hub.preview_body.texture.resource_path.begins_with(Gear.Roster.ShinSkins.root(skin)) and hub.preview_layers.selected==saved,"Changing skin updates the body while retaining its cosmetics")
 await capture("alternate-shin-equipped")
 hub.enter_map();await frames(3);game.show_equipment_hub(true);await frames(3);hub=game.equipment_hub
 check(hub.preview_layers.selected==saved and hub.enter_button.text=="Return","Reopening in game restores the saved cosmetic preview")
 game.back_from_equipment();await frames(3)
 check(not paused and game.playing,"Closing the preview returns to the existing gameplay")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("EQUIPMENT_COSMETIC_PREVIEW_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
