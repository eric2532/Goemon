extends "res://tests/forest-shrine/weapon_equipment_test.gd"
## Actual selected sprites, every attack frame, and contact sheets for every skin/weapon.
const AUDIT="res://build/Other Files/Asset Toolkit/Cross Gate Attack Silhouettes/"
var audit_rows=[]
var audit_frames=0
var audit_cases=0
var audit_shots=[]
var audit_board:Image
var audit_page=0
var audit_row=0

func face(direction:int):
 var camera=game.camera_rig.camera
 var right=camera.global_basis.x;right.y=0;right=right.normalized()
 var back=camera.global_basis.z;back.y=0;back=back.normalized()
 game.player.facing=right*sin((direction-1)*TAU/8)-back*cos((direction-1)*TAU/8)

func audit_sprite(visual,action:int,key:String,index:int)->bool:
 var data:Array=visual.body_clip(action,key).frames[index]
 return (visual.sprite.texture==visual.atlases[int(data[0])]
  and visual.sprite.region_rect==Rect2(data[1],data[2],data[3],data[4])
  and visual.sprite.offset.is_equal_approx(Vector2(float(data[5])+float(data[3])*.5,visual.FEET_OFFSET_PIXELS-float(data[6])-float(data[4])*.5))
  and visual.sprite.material_override.get_shader_parameter("sprite_texture")==visual.sprite.texture)

func stamp(visual,column:int,phase:float,direction:int=4):
 if DisplayServer.get_name()=="headless":return
 face(direction)
 var action:int=visual.normal_attack_pattern().pose
 var key="%d:%d"%[action,direction];var clip:Dictionary=visual.body_clip(action,key)
 visual.show_pose(action,float(clip.duration)*phase,false)
 await RenderingServer.frame_post_draw
 var picture=root.get_texture().get_image().get_region(Rect2i(450,200,440,460))
 picture.resize(180,188,Image.INTERPOLATE_LANCZOS)
 picture.convert(Image.FORMAT_RGBA8)
 audit_board.blit_rect(picture,Rect2i(0,0,180,188),Vector2i(column*180,audit_row*216+28))

func save_board(character:int):
 if DisplayServer.get_name()=="headless" or audit_row==0:return
 check(audit_board.save_png(AUDIT+"rendered-%d-%02d.png"%[character,audit_page])==OK,"Rendered all skin/weapon rows on page")
 print("ATTACK_OUTLINE_PAGE character=",character," page=",audit_page," rows=",audit_row)
 audit_page+=1;audit_row=0

func live_attack(visual):
 var p=game.player;var kit=p.active_ability
 kit.cancel(true);p.attack_chain.reset();kit.start_attack();face(4)
 var valid=true;var ticks=0
 while kit.is_attacking() and ticks<600:
  kit.tick(DT);visual.animate(DT,0,true,0,0,false,0,false);ticks+=1
  if visual.current_clip.begins_with("5:") or visual.current_clip.begins_with("7:"):
   valid=valid and audit_sprite(visual,int(visual.current_clip.get_slice(":",0)),visual.current_clip,visual.current_frame)
  if DisplayServer.get_name()!="headless":await process_frame
 for shot in audit_shots:
  if is_instance_valid(shot) and shot.pool_live:shot.retire()
 audit_shots.clear()
 check(valid and not kit.is_attacking(),"Real basic attack follows the current frame and recovers")

func run():
 create_timer(1200).timeout.connect(func():printerr("ATTACK_OUTLINE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(AUDIT);root.size=Vector2i(1280,800);root.gui_disable_input=true
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 for node in [game,game.player,game.camera_rig]:node.set_process_input(false);node.set_process_unhandled_input(false)
 game.settings.forest_pet_loadout=[];game.settings.gear_loadouts={};game.settings.skin_equipment={};game.settings.cosmetic_loadouts={};game.settings.disable_character_cooldowns=false
 game.begin_arena();game.choose_rogue_character(34);await frames(3);game.equipment_hub.enter_button.pressed.emit();await frames(3)
 game.clear_menu();game.forest_ui.hide();game.playing=true;game.paused=false;paused=false
 home=Vector3(0,0,60);home.y=game.model.world_height(home.x,home.z)+.05
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):audit_shots.append(shot);shot.set_physics_process(false))
 var p=game.player;p.set_auto_attack(false)
 for character in Gear.Roster.CROSSGATE:
  if character==34:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").DEFAULT
  if character==36:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE
  p.select_character(character);audit_page=0;audit_row=0
  var skins=Gear.Roster.skin_catalog(character).keys() if character!=36 else [0]
  var first=true
  for skin in skins:
   if character==34 and skin==preload("res://scripts/kaz_skins.gd").MAZE:continue
   choose_skin(character,skin);p.position=home;p.model.show()
   game.camera_rig.camera.global_position=home+Vector3(0,4,14);game.camera_rig.camera.look_at(home+Vector3.UP*1.6);game.camera_rig.camera.make_current()
   if audit_row==0:audit_board=Image.create(2160,1728,false,Image.FORMAT_RGBA8);audit_board.fill(Color("eee6d3"))
   var choices:Dictionary=Gear.allowed(character,game.settings)
   var native=Gear.default_weapon(character,game.settings)
   var order=[native]+choices.keys().filter(func(weapon):return weapon!=native)
   var labels=[]
   for weapon in order:
    p.active_ability.cancel(true);p.attack_chain.reset();p.model.apply_gear_weapon(weapon,choices[weapon]);audit_cases+=1
    var visual=p.model;var action:int=visual.normal_attack_pattern().pose
    var nodes=visual.get_child_count();var valid=true
    for direction in 8:
     var key="%d:%d"%[action,direction];var clip:Dictionary=visual.body_clip(action,key)
     for index in clip.frames.size():
      visual.show_frame(action,key,index);valid=valid and audit_sprite(visual,action,key,index);audit_frames+=1
    check(valid and visual.sprite.is_visible_in_tree(),"Frame bindings %d:%d %s stay current and visible"%[character,skin,weapon])
    check(visual.get_child_count()==nodes and visual.kagerou_shadows.all(func(shadow):return not shadow.visible) and (visual.stat_counter_shadow==null or not visual.stat_counter_shadow.visible),"Attack %d:%d %s leaves no old body/counter copy"%[character,skin,weapon])
    if weapon==native:
     for phase in 5:await stamp(visual,phase,phase*.249)
     await stamp(visual,5,.5,5)
     labels.append("native "+weapon+" 0 / 25 / 50 / 75 / end; front")
     if first:await live_attack(visual);first=false
    else:
     var pattern:Dictionary=visual.normal_attack_pattern()
     var phase:float=float(pattern.contacts[0])/maxf(.001,float(pattern.duration)) if not pattern.contacts.is_empty() else .5
     await stamp(visual,6+labels.size()-1,phase);labels.append(weapon)
   audit_rows.append({"character":character,"name":Gear.Roster.name_for(character),"skin":skin,"native":native,"weapons":order,"page":audit_page,"row":audit_row,"labels":labels})
   audit_row+=1
   if audit_row==8:save_board(character)
   await frames(1)
  save_board(character)
  print("ATTACK_OUTLINE_CHARACTER id=",character," skins=",audit_rows.size()," weapons=",audit_cases," frames=",audit_frames," failures=",failures)
 if DisplayServer.get_name()!="headless":
  var file=FileAccess.open(AUDIT+"runtime-audit.json",FileAccess.WRITE)
  file.store_string(JSON.stringify({"characters":Gear.Roster.CROSSGATE.size(),"skins":audit_rows.size(),"weapons":audit_cases,"frames":audit_frames,"checks":checks,"failures":failures,"rows":audit_rows},"  "));file.close()
 print("ATTACK_OUTLINE_RESULT checks=%d failures=%d characters=%d skins=%d weapons=%d frames=%d"%[checks,failures,Gear.Roster.CROSSGATE.size(),audit_rows.size(),audit_cases,audit_frames])
 game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
