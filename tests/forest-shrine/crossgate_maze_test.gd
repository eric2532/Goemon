extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Roster=preload("res://scripts/rogue_roster.gd")
const Weapon=Roster.MazeWeapon
const Pool=preload("res://scripts/character_projectile_pool.gd")
const OUT="res://build/Other Files/Asset Toolkit/Kaz Skins and Maze/"
var shots:Array[Node3D]=[]

func capture(title:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+title+".png")==OK,"Captured "+title)

func tap_number(code:Key):
 var key=InputEventKey.new()
 key.physical_keycode=code;key.pressed=true;game.player._unhandled_input(key)
 key.pressed=false;game.player._unhandled_input(key)

func swap_weapon():
 game.player.swap_weapon()

func equip_weapon(weapon:int):
 for i in 3:
  if game.player.model.maze_weapon==weapon:return
  swap_weapon()

func check_ranged_mirrors(p:Hero,owner:Node,pool:Node,home:Vector3):
 # Exercise the same worker integration, compact events, and body ticks as a live wave.
 for id in owner.handles.keys():owner.despawn(owner.handles[id])
 owner.sync_compatibility()
 p.select_character(Roster.MAZE_ID);p.global_position=home
 p.spell_loadout.clear_cooldowns()
 equip_weapon(Weapon.KUNAI)
 var target_point=home+Vector3.FORWARD*28.0
 target_point.y=game.model.surface_height(target_point.x,target_point.z)+.1
 var target=game.model.waves.spawn_enemy(0,target_point)
 target.hp=100000;target.max_hp=100000
 owner.integration_tick(1.0/60)
 var target_handle:int=owner.handles[target.id]
 owner.apply_hit(target_handle,{"element":"ice","status_seconds":10.0})
 var initial_hp:float=owner.unit_state(target_handle).hp
 tap_number(KEY_3)
 p.spell_loadout.tick(.45)
 var images=p.spell_loadout.instances["%d:blademaster/mirror-image"%Roster.MAZE_ID].controller.mirrors
 check(images.handles.size()==5,"Kunai Mirror Image starts in a live wave")
 var origins=images.bodies.map(func(body):return body.global_position)
 var first_shot=shots.size()
 var misses:int=pool.misses
 var jobs:int=owner.worker_jobs
 var thrown_by={}
 var blade_dance_by={}
 var in_flight={}
 var launch_distances=[]
 var pictured=false
 for i in 120:
  if owner.begin_integration(1.0/60,true):owner.finish_integration()
  else:owner.integration_tick(1.0/60)
  while first_shot<shots.size():
   var shot=shots[first_shot];first_shot+=1
   if is_instance_valid(shot) and shot.pool_live and images.bodies.has(shot.hero):
    in_flight[shot]=true
    thrown_by[shot.hero]=true
    if shot.attack_ticket.get("action")==p.spell_loadout.Catalog.BLADE_DANCE:blade_dance_by[shot.hero]=true
    launch_distances.append(shot.global_position.distance_to(target_point))
  if not pictured and thrown_by.size()==5:
   pictured=true
   await capture("Maze Mirrors Throw at Range")
  for shot in in_flight.keys():
   if shot.pool_live:shot._physics_process(1.0/60)
   else:in_flight.erase(shot)
 check(owner.worker_jobs>jobs and not owner.record_events,"The live worker and compact event path ran")
 check(thrown_by.size()==5 and launch_distances.all(func(reach):return reach>20.0),"All five copies throw kunai before entering melee range")
 var farthest_move=0.0
 for i in origins.size():
  farthest_move=maxf(farthest_move,Vector2(images.bodies[i].global_position.x-origins[i].x,images.bodies[i].global_position.z-origins[i].z).length())
 check(blade_dance_by.size()==5,"All five copies choose Blade Dance when it is ready")
 check(farthest_move<.5,"Kunai copies stay at their spawn positions while the target is in range")
 check(owner.unit_state(target_handle).hp<initial_hp and pool.misses==misses,"The ranged knives hit the native enemy using existing leases")
 images.clear()

 p.spell_loadout.clear_cooldowns()
 equip_weapon(Weapon.FIST)
 var gold_users={}
 var gold_shots=[]
 var observe_gold=func(shot):
  if shot.attack_ticket.get("action")!=p.spell_loadout.Catalog.MAZE_QI:return
  gold_users[shot.hero]=true;gold_shots.append(shot);shot.set_physics_process(false)
 pool.launched.connect(observe_gold)
 tap_number(KEY_3)
 p.spell_loadout.tick(.45)
 var initial_positions=images.bodies.map(func(body):return body.global_position)
 for i in 150:
  if owner.begin_integration(1.0/60,true):owner.finish_integration()
  else:owner.integration_tick(1.0/60)
  if gold_users.size()==5 and i>=100:break
 check(gold_users.size()==5 and gold_shots.size()==40,"Five Fist copies cast their equipped Qi Blast on their own")
 check(images.bodies.any(func(body):return body.global_position.distance_to(initial_positions[images.bodies.find(body)])>2.0),"Fist copies advance toward the enemy while Qi Blast cools down")
 await capture("Maze Mirrors Seek and Cast")
 pool.launched.disconnect(observe_gold)
 images.clear()

 p.spell_loadout.clear_cooldowns()
 equip_weapon(Weapon.KATANA)
 check(p.spell_loadout.equip(Roster.MAZE_ID,"equip","kazi/qigong"),"Katana copies inherit a competing ranged spell")
 tap_number(KEY_3)
 p.spell_loadout.tick(.45)
 # Compare attack priority with the same reachable approach for every copy.
 var reachable=images.bodies.filter(func(body):return not body.active_ability.next_combo_hop({},body.active_ability.ASSASSINATION_RANGE,owner.enemy_target(target.id),true).is_empty())
 check(not reachable.is_empty(),"Assassination priority fixture has a collision-checked approach")
 if not reachable.is_empty():
  var approach:Vector3=reachable[0].global_position
  var probe=images.bodies[0]
  probe.global_position=approach;probe.ai_target=owner.enemy_target(target.id)
  var wall=StaticBody3D.new();var collision=CollisionShape3D.new();var box=BoxShape3D.new()
  box.size=Vector3(4,6,4);collision.shape=box;wall.add_child(collision);game.add_child(wall)
  wall.global_position=approach.lerp(probe.ai_target.global_position,.5)+Vector3.UP
  await physics_frame
  check(probe.active_ability.next_combo_hop({},probe.active_ability.ASSASSINATION_RANGE,probe.ai_target,true).is_empty(),"A solid wall blocks the Assassination approach")
  probe.perform_ready(0,probe.ai_target.global_position,false)
  check(probe.action_history.size()==1 and probe.actions[probe.action_history[0]][1]=="equip" and probe.spell_loadout.current!=null,"A blocked Assassination falls back to the equipped Qi Blast")
  probe.spell_loadout.cancel();probe.active_ability.cancel();probe.action_history.clear()
  wall.queue_free();await physics_frame;await physics_frame
  for body in images.bodies:
   body.global_position=approach
   owner.native.set_pose(body.native_handle,approach,0.0)
 var assassins={}
 for i in 45:
  if owner.begin_integration(1.0/60,true):owner.finish_integration()
  else:owner.integration_tick(1.0/60)
  for body in images.bodies:
   if body.active_ability.assassinating():assassins[body]=true
 check(assassins.size()==5 and images.bodies.all(func(body):return body.actions[body.action_history[0]][1]==body.active_ability.ASSASSINATION),"All five Katana copies open with Assassination over their equipped Qi Blast")
 for i in 75:
  if owner.begin_integration(1.0/60,true):owner.finish_integration()
  else:owner.integration_tick(1.0/60)
 if owner.valid(target_handle):owner.despawn(target_handle)
 var second_target=game.model.waves.spawn_enemy(0,target_point)
 second_target.hp=100000;second_target.max_hp=100000
 owner.integration_tick(1.0/60)
 target_handle=owner.handles[second_target.id]
 owner.apply_hit(target_handle,{"element":"ice","status_seconds":10.0})
 for i in 80:
  if owner.begin_integration(1.0/60,true):owner.finish_integration()
  else:owner.integration_tick(1.0/60)
 check(images.bodies.all(func(body):return body.spell_loadout.cooldown_for("equip")>0),"Copies use their other ready spell during the Assassination cooldown")
 images.clear()
 p.spell_loadout.equip(Roster.MAZE_ID,"equip","")

 owner.despawn(target_handle)
 owner.sync_compatibility()
 p.spell_loadout.clear_cooldowns()
 equip_weapon(Weapon.FIST)
 tap_number(KEY_3)
 p.spell_loadout.tick(.45)
 var walk_to=home+Vector3.RIGHT*18
 walk_to.y=game.model.surface_height(walk_to.x,walk_to.z)+.1
 p.global_position=walk_to
 initial_positions=images.bodies.map(func(body):return body.global_position)
 for i in 90:
  if owner.begin_integration(1.0/60,true):owner.finish_integration()
  else:owner.integration_tick(1.0/60)
 var following=true
 for i in images.bodies.size():
  following=following and images.bodies[i].global_position.distance_to(walk_to)<initial_positions[i].distance_to(walk_to)-4.0
 check(following,"All five follow the moving caster when there is no enemy")
 var next_point=walk_to+Vector3.FORWARD*15
 next_point.y=game.model.surface_height(next_point.x,next_point.z)+.1
 game.model.update_vision(walk_to)
 var next_enemy=game.model.waves.spawn_enemy(0,next_point)
 next_enemy.hp=100000;next_enemy.max_hp=100000
 owner.integration_tick(1.0/60)
 var next_handle:int=owner.handles[next_enemy.id]
 owner.apply_hit(next_handle,{"element":"ice","status_seconds":10.0})
 for i in 90:
  if owner.begin_integration(1.0/60,true):owner.finish_integration()
  else:owner.integration_tick(1.0/60)
 check(images.bodies.all(func(body):return body.action_history.has(2)),"Following copies break away and cast when a new enemy appears")
 owner.despawn(next_handle)
 owner.sync_compatibility()
 p.global_position=home
 initial_positions=images.bodies.map(func(body):return body.global_position)
 for i in 120:
  if owner.begin_integration(1.0/60,true):owner.finish_integration()
  else:owner.integration_tick(1.0/60)
 check(images.bodies.any(func(body):return body.global_position.distance_to(home)<initial_positions[images.bodies.find(body)].distance_to(home)-2.0),"Copies resume following after the target is gone")
 images.clear()

func check_mirror_size(p:Hero):
 p.select_character(Roster.KAZI_ID)
 game.update_character_tuning(Roster.KAZI_ID,"model_scale",1.4)
 p.select_character(Roster.MAZE_ID)
 equip_weapon(Weapon.KATANA)
 p.buildings_broken=24
 p.grow_from_building()
 p.spell_loadout.clear_cooldowns()
 tap_number(KEY_3)
 p.spell_loadout.tick(.45)
 var images=p.spell_loadout.instances["%d:blademaster/mirror-image"%Roster.MAZE_ID].controller.mirrors
 var bodies:Array=images.bodies.duplicate()
 check(images.handles.size()==5 and bodies.all(func(body):return is_equal_approx(body.model.standing_height(),p.model.standing_height())),"All five copies match Maze's standing height with custom size and building growth")
 await capture("Maze Mirror Image Grown")
 p.buildings_broken=0
 p.scale=Vector3.ONE
 p.spell_loadout.clear_cooldowns()
 tap_number(KEY_3)
 p.spell_loadout.tick(.45)
 check(images.handles.size()==5 and images.bodies==bodies and bodies.all(func(body):return is_equal_approx(body.model.standing_height(),p.model.standing_height())),"Recast reuses all five copies at Maze's new standing height")
 images.clear()

func run():
 create_timer(90).timeout.connect(func():printerr("MAZE_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player
 var home=Vector3(-150,0,150)
 home.y=game.model.surface_height(home.x,home.z)+.1
 p.position=home;game.model.update_vision(home)
 game.camera_rig.camera.global_position=home+Vector3(0,4,10)
 game.camera_rig.camera.look_at(home+Vector3.UP*1.3)
 p.select_character(Roster.KAZI_ID)
 var kaz_scale:Vector3=p.model.scale
 var kaz_pixels:float=p.model.sprite.pixel_size
 var kaz_motions:Dictionary=p.model.motions
 var kaz_model=p.model
 var kaz_kit=p.active_ability
 game.show_rogue_roster()
 await frames(4)
 if game.menu==null:
  printerr("MAZE_FIXTURE_MENU phase=%s playing=%s paused=%s hp=%s roster=%s"%[game.model.phase,game.playing,game.paused,p.hp,game.rogue_roster_open])
  quit(1);return
 var skin:Button=game.menu.find_child("KazSkin",true,false)
 var gallery=game.menu.find_child("RosterGrid",true,false)
 check(gallery.get_children().map(func(card):return card.get_meta("fighter_id"))==Roster.selection_ids(),"The gallery shows the playable fighters")
 check(gallery.get_children().all(func(card):return card.find_child("SelectionPortrait",true,false).texture is AtlasTexture),"Every Cross Gate portrait uses the standing-body canvas")
 check(skin.catalog.size()==5,"Kaz has his four existing appearances and Maze")
 for id in [109890,109891,109146]:
  skin.select_skin(id)
  check(p.model==kaz_model and p.active_ability==kaz_kit and p.model.motions==kaz_motions,"Skin %d preserves the live controller and source timing"%id)
  check(p.model.appearance.id==id and p.model.sprite.texture.resource_path.contains("/%d/"%id),"Skin %d updates the existing world sprite"%id)
  var card=gallery.find_child("RogueFighter_kazi",true,false).find_child("SelectionPortrait",true,false)
  check(card.texture.atlas.resource_path.contains("/%d/"%id),"Skin %d updates the gallery portrait"%id)
  game.forest_ui.sync_character()
  check(game.forest_ui.hero_portrait.texture==game.forest_ui.PaintedHeads.portrait(Roster.KAZI_ID,game.settings),"Skin %d uses Kaz's selected-skin painted HUD head"%id)
  game.close_rogue_roster()
  p.model.show_pose(0,0,true)
  await capture("Kaz "+str(id))
  game.show_rogue_roster();await frames()
  skin=game.menu.find_child("KazSkin",true,false);gallery=game.menu.find_child("RosterGrid",true,false)
 check(skin.selected_id==109146,"Reopening the gallery remembers the skin")
 var config=ConfigFile.new()
 check(config.load(cfg)==OK and config.get_value("settings","kaz_skin")==109146,"Choice is saved in the existing settings")
 await capture("Three fighters")
 skin.select_skin(preload("res://scripts/kaz_skins.gd").MAZE)
 gallery.find_child("RogueFighter_kazi",true,false).pressed.emit()
 check(p.character_id==Roster.MAZE_ID and p.model.appearance.id==100528 and p.model.scale==kaz_scale and is_equal_approx(p.model.sprite.pixel_size,kaz_pixels),"Maze selects the look 7 body and matches Kaz's model scale")
 check(is_equal_approx(game.CharacterBalance.value({},{"kazi":{"model_scale":1.4}},Roster.MAZE_ID,"model_scale"),1.4),"Maze inherits a customized Kaz size")
 check(p.model.motions==kaz_motions and p.spell_loadout.numbered_slots[0][1]=="equip","Maze shares Kaz's movement clock and has a stance skill on 1")
 tap_number(KEY_1)
 check(not p.model.daggers and p.active_ability.assassination_enabled and not p.active_ability.is_attacking(),"Katana slot 1 arms Assassination without attacking")
 tap_number(KEY_1)
 game.show_rogue_roster();await frames()
 var button=game.menu.find_child("SpellEquipmentButton",true,false)
 check(button.text=="LOADOUT","Character Select exposes a Loadout button")
 button.pressed.emit();await frames()
 var loadout=game.menu.find_child("SpellEquipment",true,false)
 var primary:OptionButton=loadout.find_child("MazePrimary",true,false)
 var secondary:OptionButton=loadout.find_child("MazeSecondary",true,false)
 check(primary.is_visible_in_tree() and secondary.is_visible_in_tree() and primary.get_selected_id()==0 and secondary.get_selected_id()==1,"Loadout equips Katana and Kunai in separate slots")
 primary.select(1);primary.item_selected.emit(1)
 check(p.model.daggers and secondary.get_selected_id()==0 and game.skin_primary_kunai(Roster.MAZE_ID),"Choosing Kunai primary equips it and moves Katana to secondary")
 check(config.load(cfg)==OK and config.get_value("settings","skin_equipment")[str(Roster.MAZE_ID)].primary_kunai,"Weapon order is saved")
 check(loadout.choices.equip.visible and not loadout.choices.equip.disabled and loadout.choices.special_6.visible,"Loadout exposes skill slots 1 and 6")
 await capture("Maze Loadout")
 game.close_rogue_roster()
 swap_weapon()
 check(p.model.maze_weapon==Weapon.KATANA and game.skin_primary_kunai(Roster.MAZE_ID),"Cycling swaps live weapons without changing saved loadout order")
 swap_weapon()
 check(p.model.maze_weapon==Weapon.FIST and p.spell_loadout.numbered_slots[0][0]==p.spell_loadout.Catalog.all()[p.spell_loadout.Catalog.MAZE_QI].name,"The third stance equips Fist and puts blue Qi Blast on 1")
 swap_weapon()
 check(p.model.maze_weapon==Weapon.KUNAI,"Cycling loops back to the saved primary weapon")
 swap_weapon()
 var dummy=game.training_dummy
 dummy.position=home+Vector3.FORWARD*3;dummy.home=dummy.position
 p.facing=Vector3.FORWARD
 var owner=game.army_runtime
 owner.set_physics_process(false);owner.set_process(false)
 var enemy=game.model.waves.spawn_enemy(0,home+Vector3(2,0,-3))
 enemy.hp=10000;enemy.max_hp=10000
 owner.import_arrivals();owner.integration_tick(1.0/60)
 var handle:int=owner.handles[enemy.id]
 var enemy_hp:float=owner.unit_state(handle).hp
 await physics_frame
 tap("light_attack")
 var kit=p.active_ability
 check(is_equal_approx(kit.duration,.6) and kit.clip=="5","Katana keeps its .6-second action")
 var sword_times:Array=kit.cut_times
 kit.tick(float(sword_times[0])-.001)
 check(contacts.is_empty() and is_equal_approx(owner.unit_state(handle).hp,enemy_hp),"Katana windup leaves both targets untouched")
 kit.tick(.002)
 p.model.animate(0,0,true,0,0,false,0,false)
 check(contacts.size()==1 and is_equal_approx(enemy_hp-owner.unit_state(handle).hp,50),"The first cut hits the dummy and an off-axis native enemy once")
 check(p.model.current_frame==13,"The first cut lands on the recovered sword pose")
 await capture("Maze katana first cut")
 kit.tick(float(sword_times[1])-kit.elapsed-.001)
 check(contacts.size()==1,"The second cut waits for its own pose")
 kit.tick(.002)
 p.model.animate(0,0,true,0,0,false,0,false)
 check(contacts.size()==2 and is_equal_approx(enemy_hp-owner.unit_state(handle).hp,100),"The second cut hits both targets again for regular sword damage")
 check(p.model.current_frame==27 and p.model.explosion==null and is_equal_approx(game.camera_rig.kick_strength,.035),"The second recovered sword pose lands with a normal hit and no blast")
 await capture("Maze katana second cut")
 kit.tick(.5)
 check(contacts.size()==2 and is_equal_approx(enemy_hp-owner.unit_state(handle).hp,100),"Katana recovery adds no extra hit")
 var origin:Vector3=p.global_position
 owner.flush_presentation()
 game.crowd.army.presentation.tick(2.0)
 dummy.position=home+Vector3(8,0,-5);dummy.home=dummy.position
 var assassination_hp:float=p.hp
 var mouse=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true
 tap_number(KEY_1)
 game.forest_ui.sync()
 check(game.forest_ui.loadout_cooldowns[0].text=="ON","The Katana HUD shows that Assassination is armed")
 var assassination_voice_start:int=game.voice_idx
 p.facing=Vector3.BACK
 p._unhandled_input(mouse)
 check(kit.assassinating() and kit.fire_target.get_ref()==owner.enemies[enemy.id] and p.model.combo_glow.visible,"Left-click starts Assassination on the nearest native enemy")
 check(is_equal_approx(kit.duration,(.45+2.0+16.0/60+1.15)/2.0),"Assassination runs at double speed")
 kit.tick(.075)
 check(p.facing==Vector3.BACK and p.model.current_clip=="0:%d"%p.model.direction() and p.model.combo_glow.frame==2,"The charge flashes in the standing pose without turning Maze")
 await capture("Maze Assassination flash")
 p.take_hit(10,Vector3.BACK)
 check(p.hp==assassination_hp and p.global_position==origin,"Maze is invincible during the opening charge")
 kit.tick(.425)
 check(not p.model.sprite.visible and p.global_position==origin and p.facing==Vector3.BACK,"Maze keeps facing the same way until the teleport")
 var assassination_target=owner.enemies[enemy.id]
 var feet:Vector3=assassination_target.global_position
 owner.set_pose(handle,feet,-PI/2)
 assassination_target.sync(owner.unit_state(handle))
 kit.tick(.25)
 var rear:Vector3=p.global_position
 check(rear.x<feet.x and absf(rear.z-feet.z)<.05 and p.facing.dot(Vector3.RIGHT)>.99 and p.model.sprite.visible and p.model.sprite.modulate.a==.5,"Maze reappears directly behind the target using its updated facing")
 owner.reaction_dirty=true;owner.presentation_dirty=true
 owner.flush_presentation()
 await capture("Maze Assassination reappear")
 var assassination_presentation=game.crowd.army.presentation
 var event_start:int=owner.presentation_events.size()
 var original_exit:Vector3=kit.assassination_exit
 feet.x+=.6
 owner.set_pose(handle,feet,-PI/2)
 assassination_target.sync(owner.unit_state(handle))
 owner.reaction_dirty=true;owner.presentation_dirty=true
 owner.flush_presentation()
 kit.tick(kit.ASSASSINATION_PASS_START-kit.elapsed+.04)
 check(p.global_position==rear and p.model.current_clip.begins_with("5:"),"Maze uses the recovered normal attack before passing through")
 check(not p.model.kagerou_shadows.any(func(shadow):return shadow.visible),"Afterimages wait until the native strikes finish")
 check(owner.valid(handle) and assassination_presentation.effects.is_empty(),"KILL waits until Maze clears the target")
 await capture("Maze Assassination pass through")
 kit.tick(kit.state.assassination_pattern.duration+kit.ASSASSINATION_PASS_TIME-.04+.001)
 var exit_point:Vector3=p.global_position
 var hit_events:Array=owner.presentation_events.slice(event_start).filter(func(event):return event.get("target_id")==enemy.id and event.kind in ["damage","death"])
 check(hit_events.size()==2 and hit_events.all(func(event):return event.quiet_contact),"The single native hit and death omit ordinary hit feedback")
 owner.flush_presentation()
 check(not owner.valid(handle) and not Array(assassination_presentation.label_ages).any(func(age):return age>0),"The pass defeats the target without damage numbers")
 check(assassination_presentation.effects.size()==1 and assassination_presentation.effects[0].kind==kit.ASSASSINATION and kit.clip=="0" and not p.model.kagerou_shadows.any(func(shadow):return shadow.visible),"KILL appears alone after the dash")
 check(exit_point.x>feet.x and exit_point.x>original_exit.x+.3 and absf(exit_point.z-feet.z)<.05 and kit.assassinating(),"Maze finishes on the far side even if the enemy moves after the blink")
 var expected_cues=["cg_assassination_charge","maze_assassination_vanish","maze_assassination_strike","maze_assassination_arrive"].map(func(cue):return SoundLibrary.original_for(Roster.MAZE_ID,cue))
 var voices=game.voices.filter(func(voice):return voice.get_meta("order",-1)>assassination_voice_start and voice.stream in expected_cues)
 voices.sort_custom(func(a,b):return a.get_meta("order")<b.get_meta("order"))
 check(voices.map(func(voice):return voice.stream)==expected_cues,"Assassination plays the four recovered cues in order")
 p.take_hit(10,Vector3.BACK,true)
 check(p.hp==assassination_hp,"Maze is invincible through strike recovery")
 game.crowd.army.presentation.draw_effects()
 await capture("Maze Assassination KILL")
 kit.tick(.45)
 check(kit.assassinating() and p.global_position==exit_point,"The return waits out the complete KILL display")
 kit.tick(.15)
 check(not kit.assassinating() and p.global_position==origin and p.facing==Vector3.BACK and p.model.current_clip=="0:%d"%p.model.direction() and p.model.sprite.visible and not kit.protects_player(),"Maze returns home facing the original direction, visible and vulnerable again")
 for i in 2:
  p._unhandled_input(mouse)
  check(kit.assassinating() and kit.fire_target.get_ref()==dummy and kit.assassination_rate==2.0,"The next click is twice as fast after a kill")
  kit.tick(.25)
  kit.cancel(true)
  check(p.model.sprite.visible and p.model.sprite.modulate.a==1.0 and p.global_position==origin and not kit.protects_player(),"Interrupted vanish restores visibility and clears invincibility")
 p.attack_chain.reset()
 contacts.clear();p.model.show_pose(0,0,true)

 swap_weapon()
 check(p.model.maze_weapon==Weapon.FIST,"Cycling advances from the saved secondary weapon to Fist")
 swap_weapon()
 game.forest_ui.sync_character()
 check(p.model.daggers and p.melee_strike_reach()==0,"Physical Z loops to the kunai and clears the melee outline")
 check(game.forest_ui.ben_utility_tile.visible and game.forest_ui.utility_key.text=="Z" and game.forest_ui.leader_utility_icon.texture==game.forest_ui.MAZE_DAGGER,"The dedicated HUD icon shows the equipped kunai")
 await capture("Maze daggers")
 var pool=Pool.service(game)
 var dagger_key=pool.key_for(p,kit.Shot,"maze_dagger")
 var created:int=pool.created
 var dagger_created:int=pool.all[dagger_key].size()
 var misses:int=pool.misses
 pool.launched.connect(func(shot):
  if shot.attack_ticket.get("action","") in ["maze_dagger",p.spell_loadout.Catalog.BLADE_DANCE]:
   shots.append(shot);shot.set_physics_process(false))
 dummy.position=home+Vector3(-5,0,-2);dummy.home=dummy.position
 var farther=game.model.waves.spawn_enemy(0,home+Vector3.FORWARD*8)
 farther.hp=10000;farther.max_hp=10000
 owner.import_arrivals();owner.integration_tick(1.0/60)
 await physics_frame
 check(game.forest_enemy_visible(dummy),"Off-axis practice target is visible")
 p.smoke_mode=true;p.smoke_move=Vector2.RIGHT
 for i in 8:
  p._physics_process(1.0/60)
  await physics_frame
 var run_speed:float=p.velocity.x
 var windup_start:Vector3=p.position
 p.facing=Vector3.FORWARD
 tap("light_attack")
 check(kit.clip=="7" and kit.fire_target!=null and kit.fire_target.get_ref()==dummy,"Click locks the nearest visible target, away from the crosshair")
 check(is_equal_approx(kit.duration,.8/3.0),"Kunai action is 3× faster")
 var slowest=run_speed
 for i in 12:
  p._physics_process(1.0/60)
  slowest=minf(slowest,p.velocity.x)
  await physics_frame
 check(run_speed>1 and slowest>=run_speed-.05 and p.position.x>windup_start.x+run_speed*.16,"Maze keeps his lateral running speed through the throw windup")
 check(shots.is_empty(),"No knife launches before the recovered throw marker")
 p._physics_process(1.0/60)
 check(shots.size()==2 and shots[0].target.get_ref()==dummy and shots[1].target.get_ref()==owner.enemies[farther.id],"Two kunai leave together, each locked onto a different nearby enemy")
 check(is_equal_approx(shots[0].position.distance_to(shots[1].position),.6) and shots.all(func(knife):return knife.velocity.normalized().dot((AttackChain.aim_point(knife.target.get_ref(),knife.position)-knife.position).normalized())>.9999),"Each knife aims from its own release position at its enemy")
 var paired_native_hp:float=owner.unit_state(owner.handles[farther.id]).hp
 check(p.model.appearance.projectile_serial==21100 and shots[0].dagger_sprite.texture==preload("res://assets/characters/crossgate/maze/regular-dagger.png") and shots[0].dagger_sprite.texture.get_size()==Vector2(768,48),"Dagger uses the regular blade at 16 flight angles while preserving source metadata")
 var shot=shots[0]
 check(is_equal_approx(shot.velocity.length(),72) and is_equal_approx(shot.lifetime*shot.velocity.length(),120),"Kunai flies at 72 m/s with a 120 m base range")
 check(shot.position.x>windup_start.x+run_speed*.16 and p.velocity.x>=run_speed-.05,"Kunai launches from Maze's new position while he keeps running")
 check(shots.all(func(knife):return is_equal_approx(knife.dagger_sprite.pixel_size,kaz_pixels*2.25*.85*.85)),"Kunai sprites are another 15% smaller")
 swap_weapon()
 check(p.model.maze_weapon==Weapon.KATANA and kit.clip=="7" and shot.pool_live,"Z switches the next attack while the current throw finishes")
 equip_weapon(Weapon.KUNAI)
 for knife in shots:knife._physics_process(.025)
 p.model.show_pose(7,kit.elapsed,false)
 await capture("Maze throws two kunai")
 var chain_before=p.attack_chain.count
 for i in 60:
  for knife in shots:
   if knife.pool_live:knife._physics_process(1.0/60)
 check(contacts.size()==1 and is_equal_approx(paired_native_hp-owner.unit_state(owner.handles[farther.id]).hp,100.0/3) and shots.all(func(knife):return not knife.pool_live),"Each regular kunai hits its own enemy once and retires")
 check(p.attack_chain.count==chain_before+1,"The regular pair earns one attack-chain link")
 kit.tick(.08);contacts.clear()
 p.smoke_mode=false;p.smoke_move=Vector2.ZERO;p.velocity=Vector3.ZERO;p.position=home

 tap("light_attack")
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(12,4,1)
 shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=home+Vector3(0,1.5,-1)
 await physics_frame;await physics_frame
 kit.tick(.22)
 for knife in shots.slice(-2):knife._physics_process(.5)
 check(contacts.is_empty() and shots.slice(-2).all(func(knife):return not knife.pool_live),"A wall added during windup intercepts both kunai")
 kit.cancel(true);wall.queue_free();await frames(2)
 for i in 8:
  tap("light_attack");kit.tick(.28)
  for knife in shots.slice(-2):knife._physics_process(.5)
 check(shots.size()==20 and pool.created==created and pool.misses==misses,"Ten paired throws reuse the prepared projectile leases")
 p.position=home+Vector3.UP*130
 var long_shots:Array[Node3D]=[]
 for i in 7:
  tap("light_attack");kit.tick(.28);long_shots.append_array(shots.slice(-2))
 check(long_shots.size()==14 and pool.misses==misses and long_shots.all(func(knife):return knife.pool_live),"Seven full-range pairs fly together without growing the pool")
 shot=long_shots.front()
 var launch_position:Vector3=shot.position
 shot._physics_process(1.5)
 check(shot.pool_live and is_equal_approx(shot.position.distance_to(launch_position),108),"A clear throw travels beyond the old range and remains in flight at 108 m")
 for knife in long_shots:knife._physics_process(2.0)
 check(long_shots.all(func(knife):return not knife.pool_live),"Full-range projectiles expire and return to the pool")
 p.position=home
 var dummy_position:Vector3=dummy.position
 dummy.position=home+Vector3.DOWN*1000
 p.attack_chain.reset()
 var native_hp:float=owner.unit_state(owner.handles[farther.id]).hp
 tap("light_attack");kit.tick(.28)
 check(shots.slice(-2).all(func(knife):return knife.target!=null and knife.target.get_ref()==owner.enemies[farther.id]),"With one available enemy, both regular kunai aim at it")
 for knife in shots.slice(-2):knife._physics_process(.2)
 check(is_equal_approx(native_hp-owner.unit_state(owner.handles[farther.id]).hp,200.0/3),"Both regular kunai share their cycle's normalized damage on a native enemy")
 check(pool.created==created and pool.misses==misses,"Native paired contacts reuse prepared leases")
 p.attack_chain.reset()
 native_hp=owner.unit_state(owner.handles[farther.id]).hp
 tap("light_attack");kit.ticket.sure_strike_damage=5000.0;kit.tick(.28)
 check(shots.slice(-2).all(func(knife):return is_equal_approx(knife.damage,2500)),"An empowered pair splits its existing total damage")
 for knife in shots.slice(-2):knife._physics_process(.2)
 check(is_equal_approx(native_hp-owner.unit_state(owner.handles[farther.id]).hp,5000),"An empowered pair preserves its 5,000 total damage on a native enemy")
 dummy.position=dummy_position
 equip_weapon(Weapon.KATANA)
 check(p.model.maze_weapon==Weapon.KATANA and is_equal_approx(p.melee_strike_reach(),5.6),"Z restores the katana and its reach")
 check(SoundLibrary.original_for(Roster.MAZE_ID,"step")==SoundLibrary.GOEMON_FOOTSTEP and SoundLibrary.original_for(Roster.MAZE_ID,"land")==SoundLibrary.HUMANOID_LANDING,"Maze uses Goemon's prepared footstep and landing")
 tap_number(KEY_6)
 var health:float=p.hp
 p.take_hit(10,Vector3.BACK)
 check(kit.kagerou_enabled and p.hp==health and p.model.kagerou_tick==0,"Key 6 enables guaranteed dodge while wielding the katana")
 p.model.tick_kagerou_dodge(1.0)
 equip_weapon(Weapon.KUNAI)
 p.take_hit(10,Vector3.RIGHT,true)
 p.model.tick_kagerou_dodge(.15)
 check(p.model.daggers and p.hp==health and p.model.kagerou_shadows.any(func(shadow):return shadow.visible and shadow.texture==p.model.sprite.texture),"Kagerou also dodges projectiles and stamps Maze's dagger stance")
 game.forest_ui.sync()
 check(game.forest_ui.loadout_cooldowns[5].text=="ON","Slot 6 shows Kagerou's live toggle state")
 await capture("Maze Kagerou")
 tap_number(KEY_6)
 p.model.tick_kagerou_dodge(1.0)
 check(not kit.kagerou_enabled and not p.try_kagerou_dodge(Vector3.BACK),"Key 6 toggles Kagerou off")
 tap_number(KEY_6)
 check(p.spell_loadout.equip(Roster.MAZE_ID,"special_6","kazi/fire") and not kit.kagerou_enabled and p.spell_loadout.numbered_slots[5][1]=="special_6","Slot 6 can take another skill and clears active Kagerou")
 check(p.spell_loadout.equip(Roster.MAZE_ID,"equip","kazi/fire") and not p.spell_loadout.numbered_slots[0].is_empty(),"Slot 1 accepts a skill while both weapons stay equipped")
 p.spell_loadout.equip(Roster.MAZE_ID,"special_6","")
 p.spell_loadout.equip(Roster.MAZE_ID,"equip","")
 var before_dance=shots.size()
 var presentation=game.crowd.army.presentation
 dummy.position=home+Vector3(3,0,-4);dummy.home=dummy.position
 contacts.clear()
 presentation.tick(.7)
 await physics_frame
 tap_number(KEY_1)
 check(kit.clip=="6" and p.model.combo_glow.visible and p.model.combo_glow.texture==preload("res://assets/characters/crossgate/qigong/charge.png"),"Blade Dance starts with the recovered high-rank charge flash")
 check(is_equal_approx(p.model.combo_glow.pixel_size*165.0,2.2*kaz_pixels*p.model.BODY_HEIGHT_PIXELS),"Blade Dance's high-rank flash spans 2.2 body heights on its reference frame")
 check(game.last_sound_voice.get_meta("kind")=="cg_blade_dance_charge" and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_FLASH,"Blade Dance's charge control plays original cue 251")
 kit.tick(.16)
 check(shots.size()==before_dance and p.model.combo_glow.frame==3,"The flash advances before the kunai can leave")
 p.model.animate(0,0,true,0,0,false,0,false)
 await capture("Maze Blade Dance flash")
 kit.cancel(true)
 check(not p.model.combo_glow.visible and shots.size()==before_dance and kit.combo_cooldown==0,"Interrupting the flash leaves no projectile or cooldown")
 for i in 3:
  var volley_start=shots.size()
  tap_number(KEY_1)
  kit.tick(.45)
  check(kit.clip=="7" and not p.model.combo_glow.visible and shots.size()==volley_start,"The flash finishes before the throw pose starts")
  kit.tick(.28)
  var volley=shots.slice(volley_start)
  check(volley.size()==2 and volley[0].target.get_ref()==dummy and volley[1].target.get_ref()==owner.enemies[farther.id],"With two enemies, Blade Dance throws one kunai at each in distance order")
  check(game.last_sound_voice.stream==SoundLibrary.original_for(Roster.MAZE_ID,"cg_dagger_throw"),"Blade Dance uses the recovered knife release sound")
  game.forest_ui.sync()
  check(game.forest_ui.loadout_cooldowns[0].text=="5.0s","The hotbar shows the cooldown after release")
  tap_number(KEY_1)
  check(not kit.is_attacking(),"Cooldown blocks a second cast")
  var before_impact=game.voice_idx
  var before_effects=presentation.effects.size()
  for knife in volley:knife._physics_process(.2)
  var bursts=presentation.effects.slice(before_effects).filter(func(effect):return effect.kind=="maze_blade_dance")
  check(contacts.size()==i+1 and volley.all(func(knife):return not knife.pool_live) and bursts.size()==2,"Both contacts play hit bursts and retire the shots")
  if bursts.size()==2:
   check(bursts.all(func(burst):return burst.scale==6.0) and bursts[0].position.is_equal_approx(dummy.combat_bounds().get_center()) and bursts[1].position.is_equal_approx(owner.enemies[farther.id].combat_bounds().get_center()),"Hit bursts are three times larger and centered on both enemies")
  var impact_voices=game.voices.filter(func(voice):return voice.get_meta("order",-1)>before_impact)
  check(not impact_voices.is_empty() and impact_voices.all(func(voice):return voice.stream==preload("res://assets/audio/crossgate/maze/cgply15.wav")),"Contact dispatches only Blue Cross Gate impact cue 141")
  if i==0 and not bursts.is_empty():
   for burst in bursts:burst.age=.29
   presentation.draw_effects()
   await capture("Maze Blade Dance centered hit")
  kit.tick_timers(5.0)
 dummy.position=home+Vector3(35,0,-8)
 var nearest_ids=[farther.id]
 for offset in [Vector3(0,0,-11),Vector3(-5,0,-9),Vector3(-3,0,-8),Vector3(3,0,-8),Vector3(5,0,-9)]:
  var enemy_row=game.model.waves.spawn_enemy(0,home+offset)
  enemy_row.hp=10000;enemy_row.max_hp=10000
  nearest_ids.append(enemy_row.id)
 var excluded=game.model.waves.spawn_enemy(0,home+Vector3(0,0,-19))
 owner.import_arrivals();owner.integration_tick(1.0/60)
 await physics_frame
 var hp_before={}
 for id in nearest_ids+[excluded.id]:hp_before[id]=owner.unit_state(owner.handles[id]).hp
 var volley_start=shots.size()
 tap_number(KEY_1);kit.tick(.45);kit.tick(.22)
 var volley=shots.slice(volley_start)
 var locked=volley.map(func(knife):return knife.target.get_ref())
 check(volley.size()==6 and nearest_ids.all(func(id):return owner.enemies[id] in locked),"Blade Dance locks one kunai onto each of the six closest native soldiers")
 for knife in volley:knife._physics_process(.045)
 p.model.animate(0,0,true,0,0,false,0,false)
 await capture("Maze Blade Dance six kunai")
 for knife in volley:
  if knife.pool_live:knife._physics_process(.25)
 check(nearest_ids.all(func(id):return owner.unit_state(owner.handles[id]).hp<hp_before[id]),"Every locked soldier takes a hit, including two along the same line")
 check(owner.unit_state(owner.handles[excluded.id]).hp==hp_before[excluded.id] and contacts.size()==3,"Enemies beyond the six locks take no damage")
 kit.tick(.08)
 check(pool.all[dagger_key].size()==dagger_created and pool.misses==misses,"Repeated Blade Dance uses the existing kunai pool")
 check(volley.all(func(knife):return not knife.pool_live and knife.target==null and knife.attack_ticket.is_empty()),"Released Blade Dance leases clear targets and damage tickets")
 dummy.position=dummy.home
 var mirror_spell=p.spell_loadout.instances.get("%d:blademaster/mirror-image"%Roster.MAZE_ID)
 if mirror_spell==null:
  check(false,"Maze prepares the default Mirror Image controller on selection")
  quit(1);return
 var mirrors=mirror_spell.controller.mirrors
 equip_weapon(Weapon.KATANA)
 tap_number(KEY_3)
 check(game.last_sound_voice.get_meta("kind")=="cg_mirror_charge" and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_FLASH,"Mirror Image's opening flash uses its own control and original cue")
 p.spell_loadout.tick(.2)
 check(p.model.combo_glow.visible and p.model.combo_glow.frame==4 and mirrors.handles.is_empty(),"Key 3 plays Shining before any copies appear")
 game.crowd.army.presentation.tick(1.0)
 await capture("Maze Shining before Mirror Image")
 p.spell_loadout.interrupt()
 check(not p.model.combo_glow.visible and mirrors.handles.is_empty(),"Interrupting Shining cancels the summon and clears the sprite")
 tap_number(KEY_3)
 p.spell_loadout.tick(.45)
 check(not p.model.combo_glow.visible and mirrors.handles.size()==5 and mirrors.bodies.all(func(body):return body.leased and body.model.maze_weapon==Weapon.KATANA),"Shining finishes before five Katana Maze allies appear")
 game.forest_ui.sync()
 check(game.forest_ui.loadout_cooldowns[2].text=="22.0s","Key 3 shows the shared Mirror Image cooldown")
 await capture("Maze Mirror Image Katana")
 var before_mirror_cuts=contacts.size()
 for body in mirrors.bodies:
  body.global_position=dummy.global_position+Vector3.BACK*2
  body.perform(0,dummy.global_position)
  body.active_ability.tick(.2)
 check(contacts.size()==before_mirror_cuts+5,"Five native katana copies land the first cut")
 for body in mirrors.bodies:body.active_ability.tick(.42)
 check(contacts.size()==before_mirror_cuts+10,"Five native katana copies land exactly two cuts each")
 p.spell_loadout.tick(.5)
 equip_weapon(Weapon.KUNAI)
 tap_number(KEY_3)
 check(p.model.daggers and mirrors.bodies.all(func(body):return body.leased and not body.model.daggers),"Switching to Kunai preserves the Katana copies and cooldown")
 var first_handles=mirrors.handles.duplicate()
 mirrors.tick(29.99)
 check(first_handles.size()==5 and first_handles.all(func(handle):return owner.valid(handle)),"All five copies remain active just before 30 seconds")
 mirrors.tick(.02)
 check(first_handles.all(func(handle):return not owner.valid(handle)),"Katana copies expire through the native owner after 30 seconds")
 p.spell_loadout.tick(21.5)
 tap_number(KEY_3)
 check(p.model.combo_glow.visible and mirrors.handles.is_empty(),"Kunai also shows Shining before spawning copies")
 p.spell_loadout.tick(.45)
 check(mirrors.handles.size()==5 and mirrors.bodies.all(func(body):return body.leased and body.model.daggers),"Key 3 reuses the bodies as five Kunai Maze allies")
 check(mirrors.bodies.all(func(body):return not body.spell_loadout.instances.has("%d:blademaster/mirror-image"%Roster.MAZE_ID) and not body.actions.any(func(slot):return slot[1]=="sky_strike")),"Copies cannot prepare or cast Mirror Image")
 await capture("Maze Mirror Image Kunai")
 var mirror_start=shots.size()
 var mirror_misses:int=pool.misses
 check(mirrors.bodies.all(func(body):return body.actions.size()==3),"Kunai copies have normal throws and Blade Dance")
 for i in mirrors.handles.size():
  var body=mirrors.bodies[i]
  mirrors._action({"ticket_id":mirrors.handles[i],"action_index":400+i%2,"position":dummy.global_position})
  check(body.active_ability.clip=="7","Native mirror action selects the recovered Kunai throw")
  body.active_ability.tick(.22)
 check(shots.size()==mirror_start+10 and pool.misses==mirror_misses,"Five native copies release two kunai each from prepared leases")
 check(mirrors.bodies.all(func(body):return shots.slice(mirror_start).filter(func(knife):return knife.hero==body).size()==2),"Every Maze copy inherits the regular two-kunai attack")
 check(shots.slice(mirror_start).all(func(knife):return knife.pool_live and knife.dagger_sprite.is_visible_in_tree()),"Every native copy releases a visible kunai projectile")
 await capture("Maze Mirror Image Kunai Volley")
 equip_weapon(Weapon.KATANA)
 tap_number(KEY_1)
 var range_floor=StaticBody3D.new()
 var range_collider=CollisionShape3D.new()
 var range_box=BoxShape3D.new()
 range_box.size=Vector3(105,1,10)
 range_collider.shape=range_box
 range_floor.add_child(range_collider)
 game.add_child(range_floor)
 var range_origin=Vector3(origin.x,130.05,origin.z)
 range_floor.global_position=range_origin+Vector3(48,-.55,0)
 var old_dummy_position:Vector3=dummy.position
 p.global_position=range_origin
 dummy.position=range_origin+Vector3.RIGHT*97
 await physics_frame
 p._unhandled_input(mouse)
 check(not kit.assassinating(),"A target beyond 96 m cannot start Assassination")
 dummy.position=range_origin+Vector3.RIGHT*95
 p._unhandled_input(mouse)
 check(kit.assassinating() and kit.fire_target.get_ref()==dummy,"The tripled range locks a clear target at 95 m")
 kit.tick(kit.ASSASSINATION_APPEAR+.001)
 check(p.global_position.distance_to(range_origin)>94,"The long-range teleport reaches the target's rear")
 kit.tick(kit.ASSASSINATION_PASS_START-kit.elapsed+.001)
 kit.tick(kit.state.assassination_pattern.duration+kit.ASSASSINATION_PASS_TIME+.001)
 check(not kit.assassinating() and p.global_position==range_origin,"The practice cast completes its native strikes and returns without a kill label")
 kit.tick(kit.ASSASSINATION_LABEL_TIME+.001)
 check(not kit.assassinating() and p.global_position==range_origin,"The long-range cast returns to the exact casting position")
 check(p.attack_chain.maze_assassination_rate==1.0,"Practice targets grant no speed increase")
 for speed in [2,4,8,16,20,20]:
  var starting_facing:Vector3=p.facing
  var point=range_origin+Vector3.RIGHT*5
  var victim_row=game.model.waves.spawn_enemy(0,point)
  owner.import_arrivals()
  var victim_handle:int=owner.handles[victim_row.id]
  owner.set_pose(victim_handle,point,-PI/2)
  owner.enemies[victim_row.id].sync(owner.unit_state(victim_handle))
  p._unhandled_input(mouse)
  check(kit.assassinating() and kit.assassination_rate*kit.ASSASSINATION_SPEED==speed,"Assassination locks in %d× for the whole cast"%speed)
  var trail_seen=false
  var frames_used=0
  for tick in 200:
   if not kit.assassinating():break
   p.model.tick_kagerou_dodge(1.0/60)
   kit.tick(1.0/60)
   trail_seen=trail_seen or p.model.kagerou_shadows.any(func(shadow):return shadow.visible)
   frames_used+=1
  check(not owner.valid(victim_handle) and trail_seen and p.global_position==range_origin and p.facing.is_equal_approx(starting_facing) and not kit.assassinating(),"The %d× pass kills once and restores position and facing"%speed)
  check(p.attack_chain.maze_assassination_rate*kit.ASSASSINATION_SPEED==mini(speed*2,20),"The kill earns the next speed without exceeding 20×")
  check(frames_used<=((kit.ASSASSINATION_FINISH+p.model.normal_attack_pattern().duration)/kit.assassination_rate+maxf(kit.ASSASSINATION_MIN_LABEL_TIME,kit.ASSASSINATION_LABEL_TIME/kit.assassination_rate))*60+3,"The %d× cast finishes at its scaled timing"%speed)
 p.global_position=origin
 dummy.position=old_dummy_position
 range_floor.queue_free()
 p.attack_chain.reset();contacts.clear()
 mirrors.clear()
 game.crowd.army.presentation.tick(1.0)
 equip_weapon(Weapon.FIST)
 game.forest_ui.sync_character()
 check(game.forest_ui.ben_utility_tile.tooltip_text.begins_with("Fist") and is_equal_approx(p.melee_strike_reach(),2.42),"Fist HUD and melee range follow the equipped stance")
 p.facing=Vector3.FORWARD
 var fist_voice_start:int=game.voice_idx
 tap("light_attack")
 dummy.position=p.global_position+p.facing*1.5;dummy.home=dummy.position
 await physics_frame
 var punch:Dictionary=p.model.body_clip(5,"5:0")
 kit.tick(float(punch.contacts[0])-.01)
 check(contacts.is_empty() and punch.frames.size()==18,"Fist uses the recovered unarmed windup")
 kit.tick(.011)
 check(contacts.size()==1,"Fist lands one short-range hit at its recovered marker")
 var fist_voices=game.voices.filter(func(voice):return voice.get_meta("order",-1)>fist_voice_start and voice.get_meta("kind","") in ["swing","hit"])
 fist_voices.sort_custom(func(a,b):return a.get_meta("order")<b.get_meta("order"))
 check(fist_voices.map(func(voice):return voice.stream)==[kit.FIST_SWING,kit.FIST_CONTACT],"Fist plays the recovered swing and punch contact in order")
 p.model.show_pose(5,kit.elapsed,false)
 await capture("Maze Fist")
 kit.tick(.8)
 var orbs:Array[Node3D]=[]
 var qigong_id:String=p.spell_loadout.Catalog.MAZE_QI
 var observe_orb=func(orb):
  if orb.attack_ticket.get("action","")==qigong_id:
   orbs.append(orb);orb.set_physics_process(false)
 pool.launched.connect(observe_orb)
 var before_qi:int=pool.created
 var before_qi_misses:int=pool.misses
 tap_number(KEY_1)
 p.spell_loadout.tick(.2)
 var qi_cast:Node=p.spell_loadout.current.controller
 check(p.model.current_clip.begins_with("0:") and qi_cast.charge_fx.visible and qi_cast.charge_fx.global_position.is_equal_approx(p.model.qi_blast_chest()),"Maze shines from his torso in the standing pose")
 await capture("Maze Qi torso shine")
 p.spell_loadout.tick(.251)
 check(p.model.current_clip.begins_with("5:") and not qi_cast.charge_fx.visible and orbs.is_empty(),"Maze winds up his normal fist after the shine")
 p.spell_loadout.tick(float(qi_cast.native_pattern.contacts[0])-qi_cast.native_elapsed+.001)
 check(p.model.current_clip.begins_with("5:"),"Blue Qi releases at the native fist contact")
 check(orbs.size()==8 and orbs.all(func(orb):return orb.visual.get_instance_shader_parameter("gold_palette")==0.0),"Fist key 1 launches eight blue Qi Blasts from the pool")
 for orb in orbs.slice(0,3):
  orb.target=null
  orb._physics_process(orb.start_delay+.1)
 check(orbs.any(func(orb):return orb.pool_live and orb.visible and orb.age>0),"Blue Qi Blasts remain visible in flight")
 check(orbs.all(func(orb):return is_equal_approx(orb.hit_radius,6.88*.72*.5)),"Maze and borrowed Qi Blasts share the reduced contact radius")
 await capture("Maze Blue Qi Blast")
 var first_volley=orbs.duplicate()
 for orb in orbs:
  if orb.pool_live:orb.retire()
 orbs.clear()
 p.spell_loadout.tick(5.0)
 tap_number(KEY_1)
 p.spell_loadout.tick(.45)
 p.spell_loadout.tick(float(qi_cast.native_pattern.duration)+.001)
 check(orbs.size()==8 and orbs.all(func(orb):return first_volley.has(orb)) and pool.misses==before_qi_misses,"A repeated blue volley reuses the same eight leases")
 for orb in orbs:
  if orb.pool_live:orb.retire()
 orbs.clear()
 p.spell_loadout.tick(17.0)
 tap_number(KEY_3)
 p.spell_loadout.tick(.45)
 check(mirrors.handles.size()==5 and mirrors.bodies.all(func(body):return body.leased and body.model.maze_weapon==Weapon.FIST and body.actions.any(func(slot):return slot[0]==p.spell_loadout.Catalog.all()[p.spell_loadout.Catalog.MAZE_QI].name)),"Fist copies inherit the punch and blue Qi Blast")
 await capture("Maze Mirror Image Fist")
 var punching_copy=mirrors.bodies[0]
 var copy_start:Vector3=punching_copy.global_position
 punching_copy.global_position=p.global_position
 var copy_voice_start:int=game.voice_idx
 punching_copy.perform(0,dummy.global_position)
 punching_copy.active_ability.tick(float(punch.contacts[0])+.001)
 check(game.voices.any(func(voice):return voice.get_meta("order",-1)>copy_voice_start and voice.get_meta("kind","")=="hit" and voice.stream==kit.FIST_CONTACT),"Fist copy plays the same punch impact")
 punching_copy.active_ability.cancel(true)
 punching_copy.global_position=copy_start
 for body in mirrors.bodies:
  var index:int=body.actions.find([p.spell_loadout.Catalog.all()[p.spell_loadout.Catalog.MAZE_QI].name,"equip"])
  body.perform(index,dummy.global_position)
  body.spell_loadout.tick(.45)
 check(orbs.size()==40 and orbs.all(func(orb):return orb.visual.get_instance_shader_parameter("gold_palette")==0.0) and pool.created==before_qi and pool.misses==before_qi_misses,"Five Fist copies cast blue together without growing the pool")
 pool.launched.disconnect(observe_orb)
 game.select_kaz_skin(-1);p.select_character(Roster.KAZI_ID)
 check(mirrors.handles.is_empty(),"Changing fighters clears Maze's Mirror Image group")
 p.select_character(Roster.MAZE_ID)
 p.spell_loadout.clear_cooldowns()
 tap_number(KEY_3)
 var maze_glow:Sprite3D=p.model.combo_glow
 check(maze_glow.visible,"Maze can cast again after reselecting him")
 p.select_character(Roster.KAZI_ID)
 await frames(2)
 check(not maze_glow.visible,"Changing fighters during the windup clears Maze's Shining sprite")
 check(p.model.appearance.id==102488,"Invalid saved choice returns to Kaz's original")
 await check_ranged_mirrors(p,owner,pool,home)
 await check_mirror_size(p)
 game.queue_free();await frames(3)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MAZE_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
