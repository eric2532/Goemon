extends "res://tests/forest-shrine/shin_sword_rush_test.gd"

const Gear=preload("res://scripts/forest/equipment.gd")
const Capture="res://build/Other Files/Asset Toolkit/Shared Targeting/"

func click_attack():
 mouse_attack(true);mouse_attack(false)

func mouse_attack(pressed:bool):
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed
 click.position=game.crosshair_screen_position();click.global_position=click.position
 root.push_input(click,true)

func verify_weapon(character:int,weapon:String):
 var p=game.player
 game.settings.gear_loadouts={Gear.character_key(character):{"1":"weapon:"+weapon}}
 await settle(character)
 p.timed_dodge.shadow_counter_enabled=false
 var kit=p.active_ability
 var stem="%s / %s"%[p.RogueRoster.name_for(character),weapon]
 check(p.model.current_weapon()==Gear.allowed(character,game.settings)[weapon].get("base_weapon",weapon),stem+" equips the requested weapon")
 var ranged=weapon in ["bow","kunai","boomerang"]
 check(kit.primary_is_ranged()==ranged,stem+" uses the weapon's attack range")
 var reach:float=kit.primary_reach()
 var target=place_target(18.0 if ranged else reach+4.0)
 var camera=game.camera_rig
 camera.yaw=0;camera.pitch=.32;camera.reset_follow();camera.current_distance=camera.combat_distance();camera.update_camera(0)
 var screen:Vector2=game.crosshair_screen_position()
 var feet:Vector2=camera.camera.unproject_position(p.global_position)
 check(absf(feet.x-screen.x)<2 and feet.y>screen.y,stem+" uses centered combat framing")
 if ranged:
  camera.camera.look_at(home+Vector3(10,2,0))
  await physics_frame
  shots.clear()
  var before_cue:int=game.voice_idx
  click_attack();tap("heavy_attack")
  check(kit.mode.is_empty() and game.voice_idx==before_cue,stem+" ignores clicks without a selected enemy")
  p.set_auto_attack(true)
  await driver.advance(1,func(_dt):advance(80,false))
  check(shots.is_empty() and kit.mode.is_empty(),stem+" can only fire after target selection, including with auto attack enabled")
  p.set_auto_attack(false)
 var bounds:AABB=target.combat_bounds()
 camera.camera.look_at(Vector3(bounds.get_center().x,bounds.end.y+2.5,bounds.get_center().z))
 await physics_frame
 check(game.crosshair_ray_hit().get("collider")!=target,stem+" aims well above the enemy's actual body")
 click_attack()
 check(kit.selected_primary_enemy()==target and kit.mode==("attack" if ranged else "primary_approach"),stem+" accepts an above-head click without changing attack range")
 kit.cancel(true)
 await aim_sword(target)
 var hover_start:Vector3=p.position
 await driver.advance(1,func(_dt):advance(8,false))
 check(p.position.distance_to(hover_start)<.08 and kit.mode.is_empty() and target.hp==target.max_hp,stem+" stays idle under exact aim")
 var tab=InputEventKey.new();tab.physical_keycode=KEY_TAB;tab.pressed=true
 game._input(tab)
 game.forest_ui.sync_primary_target_marker()
 check(kit.locked_primary_enemy()==target and game.forest_ui.primary_target_marker.visible,stem+" marks the target in blue")
 var near:Ninja=place_target(6.0,4.0) if ranged else null
 var hp:float=target.hp
 var start:Vector3=p.position
 shots.clear()
 var before_attack_click:int=game.voice_idx
 click_attack()
 check(kit.selected_primary_enemy()==target and kit.mode==("attack" if ranged else "primary_approach"),stem+" fires from range or rushes the marked enemy")
 check(kit.primary_combo_hits==0,stem+" starts with a fresh combo")
 check(game.voice_idx==before_attack_click+1 and game.last_sound_voice.get_meta("kind")=="shin_target_select",stem+" confirms each accepted attack click")
 await driver.advance(1,func(_dt):
  var release_checked=false
  for i in 140:
   advance(1,false)
   if ranged and not release_checked and not shots.is_empty():
    check(kit.primary_combo_hits==0,stem+" earns no combo step on release")
    release_checked=true
   for shot in shots:
    if shot.pool_live:shot._physics_process(DT))
 check(target.hp<hp,stem+" lands its existing attack on the marked enemy")
 game.forest_ui.sync_shin_combo()
 check(kit.primary_combo_hits==1 and game.forest_ui.shin_combo_row.visible,stem+" earns exactly one visible combo step per attack")
 if ranged:
  check(not shots.is_empty() and p.position.distance_to(start)<.2,stem+" holds its ranged position with a nearer enemy present")
  if weapon=="bow":check(near.hp==near.max_hp,stem+" sends its arrow to the marked target")
  if p.model.daggers and p.model.fighter.get("kunai_count",1)>1:
   check(near.hp<near.max_hp,stem+" connects both blades without earning an extra step")
  var tempo=minf(p.ATTACK_SPEED_CAP,p.attack_speed_multiplier()*1.1)
  before_attack_click=game.voice_idx
  click_attack()
  check(game.voice_idx==before_attack_click+1 and game.last_sound_voice.get_meta("kind")=="shin_target_select",stem+" plays the click again for a repeat attack")
  check(is_equal_approx(kit.ticket.get("primary_combo_speed",0.0),1.1),stem+" starts its next shot at ×1.1 combo speed")
  await driver.advance(1,func(_dt):advance(1,false))
  check(is_equal_approx(kit.elapsed,DT*tempo),stem+" applies the combo to its real release clock")
  kit.cancel(true)
  if character==p.RogueRoster.LANCELOT_ID and weapon=="bow":
   var saved_spells:Dictionary=game.settings.spell_loadouts
   game.settings.spell_loadouts={str(character):{"surge":"kazi/wind"}}
   p.spell_loadout.prepare()
   tap("surge")
   var wind=p.spell_loadout.current
   check(wind!=null and is_equal_approx(kit.primary_combo_left,5.0),"A spell links the bow's HitCombo timer")
   if wind!=null:
    var charge:float=wind.controller.charge_left
    click_attack()
    await driver.advance(1,func(_dt):advance(1,false))
    check(p.spell_loadout.current==wind and not kit.is_attacking() and is_equal_approx(charge-wind.controller.charge_left,1.1*DT),"Bow combo speeds up the cast and leaves it in control through a click")
   await driver.advance(1,func(_dt):advance(301,false))
   game.forest_ui.sync_shin_combo()
   check(kit.primary_combo_hits==0 and not game.forest_ui.shin_combo_row.visible,"Five idle seconds clear the bow combo and its counter")
   game.settings.spell_loadouts=saved_spells
   p.spell_loadout.prepare()
   shots.clear();p.set_auto_attack(true)
   await driver.advance(1,func(_dt):
    for i in 100:
     advance(1,false)
     if not shots.is_empty():break)
   check(not shots.is_empty() and kit.selected_primary_enemy()==target,"Auto attack shoots the explicit Tab target")
   p.set_auto_attack(false);kit.cancel(true)
 else:check(p.position.distance_to(start)>.5 and shots.is_empty(),stem+" closes the gap and hits in melee")
 for shot in shots:
  if shot.pool_live:shot.retire()
 if DisplayServer.get_name()!="headless" and character==p.RogueRoster.LANCELOT_ID and weapon=="bow":
  camera.reset_follow();camera.current_distance=camera.combat_distance();camera.update_camera(0)
  game.crowd.present_army(game.army_runtime.render_snapshot(),[])
  game.forest_ui.sync_primary_target_marker()
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(Capture+"lancelot-target-lock.png")==OK,"Captured Lancelot's centered combat camera and blue target")

func hold_case(character:int,weapon:String):
 var p=game.player
 game.settings.gear_loadouts={Gear.character_key(character):{"1":"weapon:"+weapon}}
 await settle(character)
 var kit=p.active_ability
 p.timed_dodge.shadow_counter_enabled=false
 var target=place_target(18.0 if weapon=="bow" else kit.primary_reach()*.65)
 await aim_sword(target)
 var camera:Camera3D=game.camera_rig.camera
 var aim=camera.global_transform
 camera.look_at(home+Vector3(10,2,0))
 await physics_frame
 shots.clear();mouse_attack(true)
 await driver.advance(1,func(_dt):advance(80,false))
 check(kit.primary_hold_target==null and kit.mode.is_empty() and shots.is_empty() and target.hp==target.max_hp,weapon+" cannot attack by holding on empty space")
 mouse_attack(false);camera.global_transform=aim
 await physics_frame
 var cue:int=game.voice_idx
 mouse_attack(true)
 check(kit.selected_primary_enemy()==target and game.voice_idx==cue+1,weapon+" starts the hold with one selection click")
 camera.look_at(home+Vector3(10,2,0))
 await driver.advance(1,func(_dt):
  for i in 250:
   advance(1,false)
   for shot in shots:
    if shot.pool_live:shot._physics_process(DT)
   if kit.primary_combo_hits>=2:break)
 check(kit.primary_combo_hits==2 and target.hp<target.max_hp,weapon+" lands repeated hits on the selected enemy while held")
 mouse_attack(false)
 await driver.advance(1,func(_dt):
  for i in 100:
   advance(1,false)
   for shot in shots:
    if shot.pool_live:shot._physics_process(DT))
 var after_release:float=target.hp
 var launches=shots.size()
 await driver.advance(1,func(_dt):advance(100,false))
 check(kit.primary_hold_target==null and kit.mode.is_empty() and target.hp==after_release and shots.size()==launches,weapon+" stops repeating after release")
 if weapon=="bow":
  await aim_sword(target)
  mouse_attack(true)
  var decoy=place_target(15,8)
  camera.look_at(AttackChain.effect_anchor(decoy).position)
  target.take_hit(target.hp*2,Vector3.FORWARD,true)
  await driver.advance(1,func(_dt):advance(100,false))
  check(kit.primary_hold_target==null and shots.size()==launches and decoy.hp==decoy.max_hp,"Losing the held bow target stops fire without switching to another enemy")
  mouse_attack(false)
 for shot in shots:
  if shot.pool_live:shot.retire()

func overhead_limits():
 var p=game.player
 game.settings.gear_loadouts={Gear.character_key(p.RogueRoster.SHIN_ID):{"1":"weapon:sword"}}
 await settle(p.RogueRoster.SHIN_ID)
 p.timed_dodge.shadow_counter_enabled=false
 var kit=p.active_ability
 var target=place_target(kit.primary_reach()*.65)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=home+Vector3(0,3.5,8)
 var bounds:AABB=target.combat_bounds()
 var above=Vector3(bounds.get_center().x,bounds.end.y+2.5,bounds.get_center().z)
 camera.look_at(above)
 await physics_frame
 var cue:int=game.voice_idx
 click_attack()
 check(kit.mode=="attack" and kit.selected_primary_enemy()==target and game.voice_idx==cue+1,"A close above-head click starts a normal attack immediately")
 if DisplayServer.get_name()!="headless":
  game.army_runtime.flush_presentation();game.forest_ui.sync_primary_target_marker()
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(Capture+"above-head-close-target.png")==OK,"Captured the above-head pointer and selected close enemy")
 kit.cancel(true)
 var visible=game.model.visible_cells.duplicate()
 game.model.visible_cells.clear()
 click_attack()
 check(kit.mode.is_empty() and game.voice_idx==cue+1,"The larger click target still rejects hidden enemies")
 game.model.visible_cells=visible
 var wall=StaticBody3D.new();wall.collision_layer=1
 var collider=CollisionShape3D.new();var box=BoxShape3D.new()
 box.size=Vector3(8,12,.25);collider.shape=box;wall.add_child(collider);game.add_child(wall)
 wall.global_position=home.lerp(bounds.get_center(),.5)+Vector3.UP*2
 await physics_frame;await physics_frame
 click_attack()
 check(kit.mode.is_empty() and game.voice_idx==cue+1,"Above-head clicks cannot select through cover")
 wall.queue_free();await physics_frame;await physics_frame
 camera.look_at(above+Vector3.UP*3)
 click_attack()
 check(kit.mode.is_empty() and game.voice_idx==cue+1,"Clicks beyond the overhead allowance remain empty")
 camera.look_at(above)
 var hp:float=target.hp
 click_attack()
 await driver.advance(1,func(_dt):advance(140,false))
 check(target.hp<hp and not kit.is_attacking(),"The close above-head click lands one normal attack and finishes")

func run():
 create_timer(180).timeout.connect(func():printerr("CROSSGATE_PRIMARY_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(Capture)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.music.stop();game.settings.forest_pet_loadout=[]
 game.training_dummy.position=home+Vector3.DOWN*1000
 root.gui_release_focus()
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 preload("res://scripts/character_projectile_pool.gd").service(game).launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 var roster=game.player.RogueRoster
 var weapons={}
 var combinations=0
 for character in roster.CROSSGATE:
  if character==roster.SHIN_ID:game.select_shin_skin(character,900050)
  var choices=Gear.allowed(character,game.settings)
  check(not choices.is_empty(),roster.name_for(character)+" has at least one tested weapon")
  for weapon in choices:
   await verify_weapon(character,weapon)
   combinations+=1;weapons[weapon]=true
 for weapon in ["unarmed","sword","axe","polearm","staff","bow","kunai","boomerang"]:
  check(weapons.has(weapon),"Tested weapon family "+weapon)
 await overhead_limits()
 await hold_case(roster.SHIN_ID,"sword")
 await hold_case(roster.LANCELOT_ID,"bow")
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("CROSSGATE_PRIMARY_RESULT checks=%d failures=%d fighters=%d weapons=%d loadouts=%d"%[checks,failures,roster.CROSSGATE.size(),weapons.size(),combinations])
 quit(1 if failures else 0)
