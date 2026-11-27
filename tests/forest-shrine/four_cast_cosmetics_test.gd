extends "res://tests/forest-shrine/four_crossgate_cast_test.gd"
const CosmeticCatalog=preload("res://scripts/forest/cosmetic_catalog.gd")

func run():
 create_timer(900).timeout.connect(func():printerr("FOUR_CAST_COSMETICS_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.save_settings()
 game.begin_arena();game.choose_rogue_character(52);await frames(3)
 game.equipment_hub.enter_button.pressed.emit();await frames(3)
 var p=game.player;var appearances=0;var weapons=0;var sampled=0
 for character in CAST:
  game.settings.cosmetic_loadouts[Gear.character_key(character)]={"qi_color":"","slots":{"1":"cosmetic:119802","2":"cosmetic:119010"}}
  p.select_character(character)
  for skin in Gear.Roster.skin_catalog(character):
   choose_skin(character,skin);appearances+=1
   for weapon in Gear.allowed(character,game.settings):
    if weapon=="three-weapon":continue
    equip_weapon(character,weapon);weapons+=1
    var visual=p.model;var covered=true
    for action in [0,1,3,5,6,8,9,10]:
     for direction in 8:
      var pose="%d:%d"%[action,direction];var clip:Dictionary=visual.body_clip(action,pose)
      for index in [0,clip.frames.size()/2,clip.frames.size()-1]:
       visual.show_frame(action,pose,int(index))
       visual.cosmetic_layers.update(.016,visual.sprite,pose,true)
       sampled+=1
       covered=covered and CosmeticCatalog.frame_anchors(visual.sprite.texture.resource_path).has(Vector2i(visual.sprite.region_rect.position))
       covered=covered and visual.cosmetic_layers.nodes.slice(0,2).all(func(node):return node.visible and node.texture!=null)
    check(covered,"Skin %d %s uses prepared cosmetic heads through movement, attacks, casting and reactions"%[skin,weapon])
   await frames(1)
  choose_skin(character,Gear.Roster.CROSSGATE[character].skin_default)
  equip_weapon(character,"unarmed")
  p.position=Vector3(-100,game.model.world_height(-100,100)+.15,100)
  game.camera_rig.camera.global_position=p.position+Vector3(0,3,9)
  game.camera_rig.camera.look_at(p.position+Vector3.UP*1.6)
  p.model.show_frame(0,"0:4",0);p.model._process(.016)
  await cast_picture("cosmetics-%d"%character)
  var visual=p.model;var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  for i in 300:visual.cosmetic_layers.update(.016,visual.sprite,"0:4",true)
  check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Warmed new-character cosmetic playback retains its resources")
  for skin in ({52:[120168],53:[106775],54:[105112,115257,124999],55:[111676,120447]}[character]):
   choose_skin(character,skin)
   equip_weapon(character,str(p.model.profile(p.model.native_root).weapon))
   var copies=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
   for i in 3:
    check(copies.reinforce(character,p.position+Vector3(i*2,0,-8)),"Special skin uses the native army copy owner")
    var copy=copies.bodies.back()
    check(copy.model.variant_skin==skin and copy.model.current_weapon()==p.model.current_weapon(),"Simultaneous copies retain the equipped special skin and weapon")
    var clip:Dictionary=copy.model.body_clip(5,"5:4")
    copy.model.show_frame(5,"5:4",roundi(float(clip.contact)*clip.frames.size()))
    copy.model._process(.016)
    check(copy.model.cosmetic_layers.selected==p.model.cosmetic_layers.selected,"Special-skin native copies retain the prepared cosmetic layers")
   copies.dispose();await frames(2)
 print("FOUR_CAST_COSMETICS_RESULT checks=%d failures=%d skins=%d weapons=%d sampled_frames=%d"%[checks,failures,appearances,weapons,sampled])
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
