extends "res://tests/forest-shrine/weapon_equipment_test.gd"
## Every Emilia outfit/weapon, plus source-clock playback and native copy reuse.
const REVIEW="res://build/Other Files/Asset Toolkit/Emilia Skin Review/"
const Mirrors=preload("res://scripts/warcraft_mirrors.gd")
var reviewed_frames=0

func review_attack_motion(visual,skin:int):
 if DisplayServer.get_name()=="headless":return
 var motion_dir=REVIEW+"Attack Motion/"
 DirAccess.make_dir_recursive_absolute(motion_dir)
 var p=game.player;var kit=p.active_ability
 var right=game.camera_rig.camera.global_basis.x;right.y=0;right=right.normalized()
 var back=game.camera_rig.camera.global_basis.z;back.y=0;back=back.normalized()
 for direction in 8:
  kit.cancel(true);p.attack_chain.reset()
  kit.start_attack()
  p.facing=right*sin((direction-1)*TAU/8)-back*cos((direction-1)*TAU/8)
  var seen={}
  for tick in 123:
   kit.tick(DT);visual.animate(DT,0,true,0,0,false,0,false)
   if visual.current_clip=="5:%d"%direction and not seen.has(visual.current_frame):
    seen[visual.current_frame]=true
    await RenderingServer.frame_post_draw
    if direction==4:
     var image=root.get_texture().get_image().get_region(Rect2i(450,200,440,460))
     check(image.save_png(motion_dir+"%d-%02d.png"%[skin,visual.current_frame])==OK,"Captured live staff frame")
   await process_frame
  check(seen.size()==38 and not kit.is_attacking(),"Skin %d direction %d renders all 38 live staff frames and recovers (seen=%d)"%[skin,direction,seen.size()])

func review_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REVIEW+stem+".png")==OK,"Rendered "+stem)

func review_frames(visual):
 var valid=true;var clocks=true
 var right=game.camera_rig.camera.global_basis.x;right.y=0;right=right.normalized()
 var back=game.camera_rig.camera.global_basis.z;back.y=0;back=back.normalized()
 var nodes=visual.get_child_count()
 for key in visual.motions.clips:
  var action=int(key.get_slice(":",0));var direction=int(key.get_slice(":",1))
  var clip:Dictionary=visual.body_clip(action,key)
  var angle=(direction-1)*TAU/8
  game.player.facing=right*sin(angle)-back*cos(angle)
  clocks=clocks and visual.direction()==direction and clip.duration>0 and not clip.frames.is_empty()
  for index in clip.frames.size():
   visual.show_pose(action,(index+.01)*float(clip.duration)/clip.frames.size(),false)
   var data:Array=clip.frames[index]
   valid=valid and visual.sprite.texture==visual.atlases[int(data[0])] and visual.sprite.region_rect==Rect2(data[1],data[2],data[3],data[4])
   valid=valid and Rect2(Vector2.ZERO,visual.sprite.texture.get_size()).encloses(visual.sprite.region_rect)
   valid=valid and visual.sprite.offset.is_equal_approx(Vector2(float(data[5])+float(data[3])*.5,visual.FEET_OFFSET_PIXELS-float(data[6])-float(data[4])*.5))
   clocks=clocks and visual.current_clip==key and visual.current_frame==index
   reviewed_frames+=1
  visual.show_pose(action,float(clip.duration)*2,false)
  clocks=clocks and visual.current_frame==clip.frames.size()-1
  visual.show_pose(action,float(clip.duration)*2+.00001,true)
  clocks=clocks and visual.current_frame==0
 check(valid,"Every frame keeps its selected atlas, rectangle and source anchor")
 check(clocks,"Every action/facing advances, ends and loops on its prepared clock")
 check(visual.get_child_count()==nodes,"Full playback reuses the existing presentation nodes")

func review_alpha_import():
 for file in ["atlas-0.png","portrait.png"]:
  var path="res://assets/characters/crossgate/fighters/emilia/106706/"+file
  var original=Image.load_from_file(path)
  var expected=original.duplicate();expected.fix_alpha_edges()
  var imported=load(path).get_image();imported.convert(Image.FORMAT_RGBA8)
  check(imported.get_data()==expected.get_data() and imported.get_data()!=original.get_data(),"Pink Ayame "+file+" imports corrected transparent edges from unchanged source art")

func run():
 create_timer(600).timeout.connect(func():printerr("EMILIA_REVIEW_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(REVIEW);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false;game.save_settings()
 game.begin_arena();game.choose_rogue_character(42);await frames(3)
 var hub=game.equipment_hub;var picker=hub.portrait_button
 picker.open_gallery();await frames(3)
 check(picker.choices.get_theme_stylebox("hovered") is StyleBoxEmpty and picker.tooltip_text.is_empty(),"Skin selector has no hover highlight or button tooltip")
 var saved_hash=FileAccess.get_sha256(cfg)
 var selected=picker.selected_id;var draft=hub.appearance_draft.duplicate()
 for i in picker.choices.item_count:
  check(not picker.choices.is_item_tooltip_enabled(i),"Skin labels do not create hover tooltips")
  var icon:AtlasTexture=picker.choices.get_item_icon(i)
  check((icon.region.size+icon.margin.size).is_equal_approx(Vector2(124,128)*80/83),"All twenty Emilia previews share body scale and foot framing")
 var move=InputEventMouseMotion.new();move.position=picker.choices.get_global_rect().get_center();root.push_input(move,true)
 await create_timer(.75).timeout
 check(picker.selected_id==selected and hub.appearance_draft==draft and FileAccess.get_sha256(cfg)==saved_hash,"Hover leaves selected skin, equipment draft and saved settings unchanged")
 check(root.find_children("*","PopupPanel",true,false).size()==1,"Hover does not open a tooltip popup")
 await review_picture("gallery-normalized")
 picker.choices.get_v_scroll_bar().value=picker.choices.get_v_scroll_bar().max_value
 await review_picture("gallery-special-skins")
 picker.gallery.hide();hub.enter_button.pressed.emit();await frames(3)
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 var p=game.player;p.position=home
 game.model.team_progression.cards_enabled=false;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 game.camera_rig.camera.global_position=home+Vector3(0,4,14);game.camera_rig.camera.look_at(home+Vector3.UP*1.6)
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(target,_strength,_time):weapon_hits.append(target))
 if DisplayServer.get_name()!="headless":review_alpha_import()
 var combinations=0
 for skin in Gear.Roster.skin_catalog(42):
  choose_skin(42,skin)
  var visual=p.model
  for weapon in Gear.allowed(42,game.settings):
   equip_weapon(42,weapon);combinations+=1
   print("EMILIA_REVIEW skin=",skin," weapon=",weapon," clips=",visual.motions.clips.size())
   review_frames(visual);attack_case(42,weapon)
  var gear=game.settings.gear_loadouts.duplicate(true);gear.erase(Gear.character_key(42))
  check(game.save_equipment_loadouts(gear,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Restore outfit's original weapon")
  var mirrors=Mirrors.new(p,0)
  for i in 5:check(mirrors.reinforce(42,home+Vector3((i-2)*1.2,0,-2)),"Native Emilia copy arrives")
  check(mirrors.bodies.all(func(body):return body.model.variant_skin==skin and body.model.atlases==visual.atlases and body.model.current_weapon()==visual.current_weapon()),"Five native copies share the selected outfit and prepared textures")
  for body in mirrors.bodies:body.active_ability.start_attack()
  for i in 180:
   for body in mirrors.bodies:
    body.active_ability.tick(DT);body.model.animate(DT,0,true,0,0,false,0,false)
  check(mirrors.bodies.all(func(body):return not body.active_ability.is_attacking()),"Five simultaneous native attacks finish without a stuck animation")
  mirrors.dispose();await frames(2)
  if skin in [120387,120388,106706,120389,111669]:
   game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.flush_presentation()
   p.position=home;p.facing=Vector3(1,0,1).normalized();visual.show_pose(0,0,true)
   await review_picture("gameplay-%d"%skin)
   var key="5:%d"%visual.direction();var attack:Dictionary=visual.body_clip(5,key)
   for phase in [0,attack.frames.size()/2,attack.frames.size()-1]:
    visual.show_frame(5,key,int(phase));await review_picture("attack-%d-%d"%[skin,phase])
   if skin in [120387,120388,111669]:await review_attack_motion(visual,skin)
  print("EMILIA_REVIEW_COMPLETE skin=",skin)
 check(Gear.Roster.skin_catalog(42).size()==20 and combinations>90,"All twenty Emilia appearances and available weapon combinations were reviewed")
 choose_skin(42,120387);equip_weapon(42,"staff");p.active_ability.cancel(true)
 for i in 20:attack_case(42,"staff");p.model.animate(DT,5,true,0,0,false,0,false)
 game.crowd.army.presentation.clear()
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(10)
 await create_timer(.75).timeout;await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created;var misses=pool.misses
 for i in 30:attack_case(42,"staff");p.model.animate(DT,5,true,0,0,false,0,false)
 game.crowd.army.presentation.clear()
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(10)
 await create_timer(.75).timeout;await frames(3)
 print("EMILIA_REVIEW_REUSE nodes=",nodes,"/",get_node_count()," resources=",resources,"/",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)," pool=",created,"/",pool.created," misses=",misses,"/",pool.misses)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.created==created and pool.misses==misses,"Repeated warmed attacks retain no nodes/resources or pool growth")
 print("EMILIA_REVIEW_RESULT checks=%d failures=%d skins=20 weapons=%d frames=%d"%[checks,failures,combinations,reviewed_frames])
 game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
