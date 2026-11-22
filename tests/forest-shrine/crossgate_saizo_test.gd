extends "res://tests/forest-shrine/crossgate_maze_test.gd"

const SAIZO_OUT="res://build/Other Files/Asset Toolkit/Saizo/"

func capture(title:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await frames()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(SAIZO_OUT+title+".png")==OK,"Captured "+title)

func profile_poses(visual:Node)->float:
 var start=Time.get_ticks_usec()
 for i in 1200:
  visual.animate(1.0/60,5.0,true,0,0,false,0,false)
 return (Time.get_ticks_usec()-start)/1200.0

func run():
 create_timer(80).timeout.connect(func():printerr("SAIZO_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(SAIZO_OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player
 var home=Vector3(-150,0,150)
 home.y=game.model.surface_height(home.x,home.z)+.1
 p.position=home;game.model.update_vision(home)
 game.camera_rig.camera.global_position=home+Vector3(0,3.8,9)
 game.camera_rig.camera.look_at(home+Vector3.UP*1.5)
 p.select_character(Roster.MAZE_ID)
 var maze=p.model
 var maze_hotbar=p.spell_loadout.numbered_slots.duplicate(true)
 game.show_rogue_roster();await frames(4)
 var card=game.menu.find_child("RogueFighter_saizo",true,false)
 var picker:Button=card.find_child("SaizoSkin",true,false)
 check(picker.catalog.size()==13 and picker.selected_id==106477 and picker.text.to_lower().contains("shigure"),"Saizo's gallery starts with Shigure and offers all thirteen colors")
 await capture("Saizo gallery")
 card.pressed.emit()
 check(p.character_id==Roster.SAIZO_ID and p.model.appearance.id==106477,"Gallery selects Saizo with Shigure")
 check(p.spell_loadout.numbered_slots==maze_hotbar and p.active_ability.get_script()==p.character_abilities[Roster.MAZE_ID].get_script(),"Saizo uses Maze's combat controller and default shortcuts")
 check(SoundLibrary.original_for(Roster.SAIZO_ID,"step")==SoundLibrary.GOEMON_FOOTSTEP and SoundLibrary.original_for(Roster.SAIZO_ID,"land")==SoundLibrary.HUMANOID_LANDING,"Saizo uses the prepared Goemon footstep and landing")
 var visual=p.model
 var kit=p.active_ability
 game.show_rogue_roster();await frames()
 card=game.menu.find_child("RogueFighter_saizo",true,false)
 picker=card.find_child("SaizoSkin",true,false)
 for index in picker.catalog.size():
  picker.select_skin(picker.catalog.keys()[index])
  var id=picker.catalog.keys()[index]
  game.forest_ui.sync_character()
  check(p.model==visual and visual.motions.id==id and visual.sprite.texture.resource_path.begins_with(Roster.SaizoSkins.root(id)) and game.forest_ui.hero_portrait.texture==game.forest_ui.PaintedHeads.portrait(Roster.SAIZO_ID,game.settings),"Skin %d updates the same model and matching painted HUD head"%id)
  for weapon in [Weapon.KATANA,Weapon.KUNAI,Weapon.FIST]:
   kit.set_weapon(weapon)
   var source="dagger:" if weapon!=Weapon.KATANA else ""
   var original=true
   for direction in 8:
    for action in [0,1,3,6,8,9,10]:
     var key="%d:%d"%[action,direction]
     original=original and visual.body_clip(action,key)==visual.appearance.clips[source+key]
   check(original and visual.motions.clips["1:0"].duration==.697 and visual.motions.clips["3:0"].duration==.425 and visual.motions.clips["3:0"].frames.size()==6,"Skin %d stance %d uses Saizo's original motion in eight directions"%[id,weapon])
 var config=ConfigFile.new()
 check(config.load(cfg)==OK and config.get_value("settings","saizo_skin")==119308,"Saizo's skin persists in settings")
 await capture("Saizo skin picker")
 game.close_rogue_roster()
 game.select_saizo_skin(106477)
 game.select_maze_primary(true,Roster.SAIZO_ID)
 check(p.model.daggers and not game.skin_primary_kunai(Roster.MAZE_ID),"Saizo's saved weapon order is independent of Maze's")
 swap_weapon()
 check(p.model.maze_weapon==Weapon.KATANA,"Cycling follows Saizo's saved weapon order")
 game.select_maze_primary(false,Roster.SAIZO_ID)
 var dummy=game.training_dummy
 dummy.position=home+Vector3.FORWARD*3;dummy.home=dummy.position
 p.facing=Vector3.FORWARD
 await physics_frame
 tap("light_attack")
 var cuts:Array=kit.cut_times
 kit.tick((float(cuts[0])+.001)/p.attack_speed_multiplier())
 visual.show_pose(5,kit.elapsed,false)
 check(cuts.size()==1 and contacts.size()==1 and visual.current_frame==6,"Saizo's single sword slash hits on its original contact drawing")
 await capture("Saizo katana contact")
 kit.tick((kit.duration-kit.elapsed+.001)/p.attack_speed_multiplier())
 check(contacts.size()==1 and not kit.is_attacking(),"Sword recovery adds no second hit")
 tap_number(KEY_1)
 tap("light_attack")
 check(kit.assassinating(),"Katana key 1 arms Maze's Assassination")
 kit.tick(kit.ASSASSINATION_PASS_START+.001)
 check(visual.current_clip.begins_with("3:"),"Assassination's pass uses Saizo's original run")
 kit.cancel()
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):
  if shot.attack_ticket.get("action","") in ["maze_dagger",p.spell_loadout.Catalog.BLADE_DANCE]:
   shots.append(shot);shot.set_physics_process(false))
 equip_weapon(Weapon.KUNAI)
 var created:int=pool.created
 var misses:int=pool.misses
 for i in 8:
  p.attack_chain.reset()
  tap("light_attack")
  kit.tick(kit.throw_release/p.attack_speed_multiplier()-.001)
  check(shots.size()==i,"Kunai waits for the release marker")
  kit.tick(.002);visual.show_pose(7,kit.elapsed,false)
  check(shots.size()==i+1 and visual.current_frame==7 and shots.back().attack_ticket.crossgate_sound_source==Roster.SAIZO_ID,"Kunai uses Saizo's release drawing, projectile and sound profile")
  if i==0:await capture("Saizo kunai release")
  shots.back()._physics_process(.1)
  kit.tick(.3)
 check(pool.created==created and pool.misses==misses,"Eight throws reuse prepared projectile leases")
 equip_weapon(Weapon.FIST)
 check(p.spell_loadout.numbered_slots[0][0]=="Qi Blast · Gold","Fist exposes Maze's gold Qi Blast")
 dummy.position=home+Vector3.FORWARD*1.5;dummy.home=dummy.position
 contacts.clear();p.attack_chain.reset()
 tap("light_attack")
 kit.tick((float(kit.cut_times[0])+.001)/p.attack_speed_multiplier())
 visual.show_pose(5,kit.elapsed,false)
 check(contacts.size()==1 and visual.current_frame==7,"Saizo's unarmed punch hits on Maze's fist marker")
 kit.tick(1)
 tap_number(KEY_1);p.spell_loadout.tick(.36)
 check(visual.current_clip.begins_with("qi:5:"),"Gold Qi Blast uses Saizo's punch art")
 p.spell_loadout.tick(1)
 tap_number(KEY_6)
 check(p.try_kagerou_dodge(Vector3.BACK),"Saizo can use Maze's Kagerou dodge")
 kit.disable_kagerou()
 visual.locomotion_velocity=Vector3.FORWARD*5
 visual.animate(1.0/60,5,true,0,0,false,0,false)
 check(visual.current_clip.begins_with("3:"),"Sprint plays Saizo's original run")
 await capture("Saizo sprint")
 visual.jump_age=.01;visual.jump_count=1
 check(visual.show_jump_pose(false,5) and visual.current_clip.begins_with("9:"),"Jump takeoff plays Saizo's own guard")
 visual.jump_age=.3
 check(visual.show_jump_pose(false,-2) and visual.current_clip.begins_with("3:"),"Jump descent uses Saizo's run frames")
 visual.jump_landing_left=visual.JUMP_LANDING
 check(visual.show_jump_pose(true,0) and visual.current_clip.begins_with("10:"),"Landing uses Saizo's fall frames")
 visual.reset_jump_pose()
 equip_weapon(Weapon.KUNAI)
 var owner=game.army_runtime
 owner.set_physics_process(false);owner.set_process(false)
 var enemy=game.model.waves.spawn_enemy(0,home+Vector3.FORWARD*28)
 enemy.hp=100000;enemy.max_hp=100000
 owner.integration_tick(1.0/60)
 var handle:int=owner.handles[enemy.id]
 owner.apply_hit(handle,{"element":"ice","status_seconds":10.0})
 game.select_saizo_skin(120234)
 check(p.model.maze_weapon==Weapon.KATANA,"An unedited skin restores its own default weapon")
 game.select_skin_weapon(Roster.SAIZO_ID,Weapon.KUNAI)
 tap_number(KEY_3);p.spell_loadout.tick(.45)
 var images=p.spell_loadout.instances["39:blademaster/mirror-image"].controller.mirrors
 check(images.handles.size()==5 and images.bodies.all(func(body):return body.model.variant_skin==120234 and body.model.daggers and body.model.sprite.texture==visual.sprite.texture),"Five native mirrors inherit the active skin, stance and atlas")
 await capture("Saizo Mirror Image")
 var observed={}
 var first=shots.size()
 for i in 120:
  if owner.begin_integration(1.0/60,true):owner.finish_integration()
  else:owner.integration_tick(1.0/60)
  while first<shots.size():
   var shot=shots[first];first+=1
   if images.bodies.has(shot.hero):observed[shot.hero]=true
   if shot.pool_live:shot._physics_process(2.0)
 check(observed.size()==5 and pool.misses==misses,"All five native copies fire from the prepared pools")
 images.clear()
 maze.locomotion_velocity=Vector3.FORWARD*5
 print("SAIZO_POSE_US maze=%.2f saizo=%.2f"%[profile_poses(maze),profile_poses(visual)])
 game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SAIZO_RESULT checks=%d failures=%d"%[checks,failures])
 quit(1 if failures else 0)
