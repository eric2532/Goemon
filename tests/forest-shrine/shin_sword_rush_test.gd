extends "res://tests/forest-shrine/timed_dodge_test.gd"
const RUSH_OUT="res://build/Other Files/Asset Toolkit/Shin Sword Rush/"

func place_target(distance:float,side:float=0.0)->Ninja:
 var point=home+Vector3(side,0,-distance)
 point.y=game.model.surface_height(point.x,point.z)
 var row=game.model.waves.spawn_enemy(0,point);row.hp=1000000;row.max_hp=row.hp
 game.army_runtime.import_arrivals();game.army_runtime.sync_targets()
 return game.army_runtime.enemy_target(row.id)

func aim_sword(target:Ninja):
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=home+Vector3(0,3.5,8)
 camera.look_at(AttackChain.aim_point(target))
 camera.make_current()
 await physics_frame
 check(game.crosshair_ray_hit().get("collider")==target,"The crosshair selects the intended native enemy")

func rush_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(RUSH_OUT+stem+".png")==OK,"Captured "+stem)

func range_circle_hidden()->bool:
 return not game.world.attack_materials.is_empty() and game.world.attack_materials.all(
  func(material):
   var value=material.get_shader_parameter("attack_radius")
   return is_zero_approx(value if value!=null else 0.0))

func combo_swing(target:Ninja,speed:float,link_after_hit:bool=false):
 var p=game.player;var kit=p.active_ability;var hp:float=target.hp
 click_attack()
 check(kit.mode=="attack" and is_equal_approx(kit.ticket.get("primary_combo_speed",0.0),speed),"Next sword swing uses ×%.1f tempo"%speed)
 await driver.advance(1,func(_dt):
  for i in 8:
   advance(1,false)
   if kit.elapsed>0:break)
 var actual_speed=minf(3.0,p.attack_speed_multiplier()*speed)
 check(is_equal_approx(kit.elapsed,DT*actual_speed),"The attack clock advances at ×%.2f after bonuses (measured ×%.2f)"%[actual_speed,kit.elapsed/DT])
 if link_after_hit:
  var contact_ticks=ceili(kit.shin_contact/actual_speed/DT)
  await driver.advance(1,func(_dt):advance(contact_ticks,false))
  check(target.hp<hp and kit.is_attacking(),"The sword connects while some recovery remains")
  return
 var recovery=ceili(kit.duration/actual_speed/DT)+8
 await driver.advance(1,func(_dt):advance(recovery,false))
 check(target.hp<hp and not kit.is_attacking(),"The faster swing lands and finishes")

func combo_case(shin:int):
 var p=game.player
 game.settings.spell_loadouts={str(shin):{"equip":"shin/sure-strike","surge":"kazi/wind","special_4":"uru/recovery","special_5":"blademaster/mirror-image"}}
 await settle(shin);p.timed_dodge.shadow_counter_enabled=false
 var kit=p.active_ability
 var target=place_target(kit.melee_visual_reach()*.65)
 await aim_sword(target)
 var ui=game.forest_ui
 await combo_swing(target,1.0)
 ui.sync_shin_combo()
 check(ui.shin_combo_glyphs==[1] and ui.shin_combo_number.size==Vector2(15,29),"The first hit uses the 1 extracted from the original 10")
 for speed in [1.1,1.2,1.3,1.4,1.5]:await combo_swing(target,speed)
 ui.sync_shin_combo()
 check(ui.shin_combo_number.is_visible_in_tree() and ui.shin_combo_glyphs==[6] and ui.shin_combo_word.is_visible_in_tree(),"The corner row shows the original six beside HitCombo")
 check_combo_word()
 await rush_picture("shin-hitcombo-top-right")
 tap("surge")
 var wind=p.spell_loadout.current
 check(wind!=null and is_equal_approx(kit.primary_combo_speed(),1.6) and is_equal_approx(kit.primary_combo_left,5.0),"Wind refreshes the chain without adding a sword hit")
 if wind!=null:
  var charge:float=wind.controller.charge_left
  var cooldown:float=wind.controller.cooldown
  click_attack()
  check(p.spell_loadout.current==wind and not kit.is_attacking(),"A click cannot interrupt or queue through Wind")
  tap("dodge")
  check(p.spell_loadout.current==wind and p.dodge_time==0,"C does not interrupt Shin's spell or start an evade")
  await driver.advance(1,func(_dt):advance(1,false))
  check(is_equal_approx(charge-wind.controller.charge_left,1.6*DT) and is_equal_approx(cooldown-wind.controller.cooldown,DT),"Wind charges at combo speed while its cooldown runs normally")
 await driver.advance(1,func(_dt):advance(105,false))
 check(p.spell_loadout.current==null and not kit.is_attacking(),"Wind finishes without a buffered sword attack")
 await combo_swing(target,1.6)
 tap("special_4")
 check(is_equal_approx(kit.primary_combo_left,5.0),"Recovery links the timer")
 var recovery=p.spell_loadout.instances["%d:uru/recovery"%shin].controller
 click_attack()
 check(p.spell_loadout.primary_skill_busy() and not kit.is_attacking() and is_equal_approx(recovery.cast_speed,1.7),"Recovery takes the chain speed and owns the cast through to healing")
 await driver.advance(1,func(_dt):advance(42,false))
 check(not p.spell_loadout.primary_skill_busy() and not kit.is_attacking(),"Recovery releases attack input when it finishes")
 for speed in [1.7,1.8]:await combo_swing(target,speed)
 await combo_swing(target,1.9,true)
 ui.sync_shin_combo()
 check(ui.shin_combo_glyphs==[10] and ui.shin_combo_number.size==Vector2(36,29),"Ten hits use the original whole 10")
 tap("equip")
 check(kit.ticket.get("action")=="shin_sure_strike" and is_equal_approx(kit.primary_combo_speed(),2.0),"Sure Strike links without changing the next sword step")
 click_attack()
 await driver.advance(1,func(_dt):advance(1,false))
 check(kit.clip=="6" and is_equal_approx(kit.elapsed,2.0*DT),"Sure Strike links from the recovery and charges faster despite a click")
 await driver.advance(1,func(_dt):advance(115,false))
 for step in range(10,20):await combo_swing(target,1.0+.1*step)
 check(is_equal_approx(kit.primary_combo_speed(),3.0),"Landed swings reach ×3 without another spell")
 ui.sync_shin_combo()
 check(ui.shin_combo_glyphs==[2,0] and ui.shin_combo_number.size==Vector2(47,29),"Twenty hits use the original 2 and the 0 extracted from 10")
 var capped_hits:int=kit.primary_combo_hits
 for i in 2:await combo_swing(target,3.0)
 check(kit.primary_combo_hits==capped_hits+2 and is_equal_approx(kit.primary_combo_speed(),3.0),"Swings still add to the hit count at the final speed cap")
 ui.sync_shin_combo()
 check(ui.shin_combo_shown==capped_hits+2 and ui.shin_combo_glyphs==[2,2],"The count grows past the original joint-attack numerals")
 check_combo_corner()
 root.size=Vector2i(960,640);await frames(3)
 check_combo_corner()
 await rush_picture("shin-hitcombo-top-right-small")
 root.size=Vector2i(1280,800);await frames(3)
 await driver.advance(1,func(_dt):advance(305,false))
 check(kit.primary_combo_hits==0 and is_equal_approx(kit.primary_combo_speed(),1.0),"Five seconds without a link clears the count and speed")
 ui.sync_shin_combo()
 check(not ui.shin_combo_number.is_visible_in_tree() and not ui.shin_combo_word.is_visible_in_tree(),"The number and HitCombo disappear together when the combo breaks")
 await rush_picture("shin-hitcombo-cleared")
 await combo_swing(target,1.0)
 tap("special_5")
 var mirror=p.spell_loadout.current
 check(mirror!=null and mirror.spec.id=="blademaster/mirror-image","Mirror Image starts as a skill cast")
 if mirror!=null:
  click_attack()
  await driver.advance(1,func(_dt):advance(1,false))
  check(p.spell_loadout.current==mirror and is_equal_approx(mirror.controller.elapsed,1.1*DT),"Mirror Image recovers faster and keeps control through a click")

func check_combo_word():
 var word=game.forest_ui.shin_combo_word
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/crossgate/hit_feedback/joint-attack.json"))
 var frames=[9,10,11,12,13,14,15,13]
 var matches=word.get_child_count()==frames.size()
 for i in frames.size():
  var frame:int=frames[i];var glyph:Dictionary=source.glyphs[frame]
  var child=word.get_child(i);var texture:AtlasTexture=child.texture
  var origin=Vector2(glyph.origin[0],glyph.origin[1]);var dimensions=Vector2(glyph.size[0],glyph.size[1])
  matches=matches and texture.atlas.resource_path.ends_with("/joint-attack.png") and texture.region==Rect2(Vector2(frame*96+48,32)+origin,dimensions)
  matches=matches and child.position==Vector2(source.offsets[i+1]-20,12)+origin and child.size==dimensions
 check(matches,"HitCombo uses all eight archived glyphs on their original pixel grid")
 check_combo_corner()

func check_combo_corner():
 var ui=game.forest_ui
 var corner:Rect2=ui.reticle.get_global_rect()
 var row:Rect2=ui.shin_combo_row.get_global_rect()
 check(is_equal_approx(corner.end.x-row.end.x,24.0) and is_equal_approx(row.position.y-corner.position.y,24.0) and ui.shin_combo_word.position.x==ui.shin_combo_number.size.x+8 and ui.shin_combo_word.position.y+ui.shin_combo_word.size.y==ui.shin_combo_number.size.y,"The combo row keeps its margins, eight-pixel gap and original baseline")

func forgiving_click(shin:int):
 await settle(shin)
 var p=game.player
 var kit=p.active_ability
 var target=place_target(kit.melee_visual_reach()+13)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=home+Vector3(0,3.5,8)
 camera.make_current()
 var bounds:AABB=target.combat_bounds()
 var near_edge=bounds.get_center()
 near_edge.x=bounds.end.x+.25
 camera.look_at(near_edge+Vector3.RIGHT)
 await physics_frame
 var before_cue:int=game.voice_idx
 click_attack()
 check(kit.mode.is_empty() and game.voice_idx==before_cue,"Clicking outside the expanded target area starts no attack or cue")
 kit.cancel(true)
 camera.look_at(near_edge)
 check(game.crosshair_ray_hit().get("collider")!=target,"The exact ray misses the small enemy just outside its edge")
 await driver.advance(4,func(_dt):advance(1,false))
 check(kit.mode.is_empty(),"The wider click area does not start an aim-only approach")
 var wall=StaticBody3D.new()
 var collider=CollisionShape3D.new()
 var shape=BoxShape3D.new()
 shape.size=Vector3(5,5,.25);collider.shape=shape;wall.add_child(collider)
 game.add_child(wall)
 wall.global_position=home.lerp(bounds.get_center(),.5)+Vector3.UP
 await physics_frame;await physics_frame
 click_attack()
 check(kit.mode.is_empty() and game.voice_idx==before_cue,"A wall blocks the click without an attack or cue")
 kit.cancel(true)
 wall.queue_free()
 await physics_frame;await physics_frame
 var hp:float=target.hp
 click_attack()
 check(kit.selected_primary_enemy()==target and kit.mode=="primary_approach","An edge click selects the small enemy for a chase")
 await driver.advance(210,func(_dt):advance(1,false))
 check(target.hp<hp,"The expanded click area leads to a normal sword hit")

func crowded_click(shin:int):
 await settle(shin)
 var kit=game.player.active_ability
 var reach:float=kit.melee_visual_reach()
 var nearer=place_target(reach+11,.4)
 var centered=place_target(reach+14)
 var near_center:Vector3=AttackChain.effect_anchor(nearer).position
 var far_center:Vector3=AttackChain.effect_anchor(centered).position
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=home+Vector3(0,3.5,8)
 camera.look_at(far_center)
 camera.make_current()
 await physics_frame
 check(game.crosshair_ray_hit().get("collider")==nearer,"The exact ray clips the nearer enemy on the way to the centered one")
 click_attack()
 check(kit.selected_primary_enemy()==centered,"The chase click picks the enemy centered under the crosshair")
 camera.look_at(near_center)
 click_attack()
 check(kit.selected_primary_enemy()==nearer,"Moving the crosshair onto the neighbor switches the chase")
 kit.cancel(true)
 camera.global_position=near_center.lerp(far_center,-3.0)
 camera.look_at(far_center)
 click_attack()
 check(kit.selected_primary_enemy()==nearer,"Enemies at the same screen position favor the nearer one")
 kit.cancel(true)
 camera.look_at(home+Vector3.RIGHT*8)

func tab_cycle(shin:int):
 await settle(shin)
 var kit=game.player.active_ability
 var reach:float=kit.melee_visual_reach()
 var nearer=place_target(reach+8,-1.5)
 var farther=place_target(reach+12,1.5)
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=home+Vector3(0,3.5,8)
 camera.look_at(home+Vector3(0,2,-reach-10))
 camera.make_current()
 await physics_frame
 var tab=InputEventKey.new();tab.physical_keycode=KEY_TAB;tab.pressed=true
 var before_cue:int=game.voice_idx
 game._input(tab)
 check(kit.locked_primary_enemy()==nearer and kit.mode.is_empty(),"Tab selects the nearer visible enemy without moving")
 check(game.voice_idx==before_cue+1 and game.last_sound_voice.get_meta("kind")=="shin_target_select","The first Tab lock confirms the target once")
 click_attack()
 check(kit.selected_primary_enemy()==nearer and game.voice_idx==before_cue+2,"Clicking to attack the locked enemy plays the cue")
 kit.cancel(true)
 game._input(tab)
 check(kit.locked_primary_enemy()==farther,"A second Tab cycles to the next visible enemy")
 check(game.voice_idx==before_cue+3,"Cycling to another enemy plays the cue")
 game._input(tab)
 check(kit.locked_primary_enemy()==null and game.voice_idx==before_cue+3,"Tab after the last enemy clears the lock quietly")

func moving_target_click(shin:int):
 await settle(shin)
 var p=game.player
 var kit=p.active_ability
 kit.reset_primary_combo()
 var target=place_target(kit.melee_visual_reach()+4.5)
 await aim_sword(target)
 var hp:float=target.hp
 click_attack()
 for i in 35:
  if kit.mode!="primary_approach":break
  await driver.advance(1,func(_dt):advance(1,false))
 check(kit.mode=="attack" and kit.selected_primary_enemy()==target and target.hp==hp,"The chase starts a windup on the clicked enemy")
 var start:Vector3=p.global_position
 var followed=false
 for i in 60:
  if target.hp<hp or not kit.is_attacking():break
  var point:Vector3=target.global_position+Vector3(.10,0,-.13)
  point.y=game.model.surface_height(point.x,point.z)
  game.army_runtime.set_pose(target.handle,point,PI)
  game.army_runtime.sync_targets()
  await driver.advance(1,func(_dt):advance(1,false))
  if kit.state.has("approach_velocity"):followed=true
 check(followed and p.global_position.distance_to(start)>.3,"Shin follows a walking target that steps outside his swing during windup")
 var damage:float=kit.Skills.basic_damage(p.model.normal_attack_pattern())*p.damage_multiplier()
 check(is_equal_approx(hp-target.hp,damage) and kit.primary_combo_hits==1,"One click lands one normal hit on the moving enemy (%.2f / %.2f)"%[hp-target.hp,damage])
 await driver.advance(42,func(_dt):advance(1,false))
 check(kit.selected_primary_enemy()==null and is_equal_approx(hp-target.hp,damage),"One connected slash clears the selection and does not repeat")

func distant_selection(shin:int):
 await settle(shin);game.player.timed_dodge.shadow_counter_enabled=false
 var p=game.player;var kit=p.active_ability;var ui=game.forest_ui
 var reach:float=kit.melee_visual_reach()
 var target=place_target(reach+31)
 var alternate=place_target(reach+23.5,3.5)
 await aim_sword(target)
 await driver.advance(6,func(_dt):advance(1,false))
 ui.sync_primary_target_marker()
 check(kit.mode.is_empty() and not ui.primary_target_marker.visible,"Distant aim leaves movement and blue selection idle")
 var start:Vector3=p.position
 var before_cue:int=game.voice_idx
 click_attack()
 ui.sync_primary_target_marker()
 check(kit.selected_primary_enemy()==target and ui.primary_target_marker.visible,"Click selects a distant target and shows its blue pointer")
 check(game.voice_idx==before_cue+1 and game.last_sound_voice.get_meta("kind")=="shin_target_select" and game.last_sound_voice.stream.resource_path.ends_with("/cgsys00.wav"),"A new chase uses the original Blue Cross Gate cgsys00 click once")
 click_attack()
 check(game.voice_idx==before_cue+1,"Clicking the already selected enemy does not repeat the cue")
 check(ui.primary_target_marker.texture==ui.pet_focus_marker.texture and ui.primary_target_marker.material.get_shader_parameter("tint")==Color("57b7ff"),"Shin reuses the pet pointer texture with a blue tint")
 game.army_runtime.hound_focus_actor=target
 ui.sync_pet_focus_marker();ui.sync_primary_target_marker()
 check(ui.pet_focus_marker.visible and ui.primary_target_marker.position.y<ui.pet_focus_marker.position.y,"Both pointers remain distinct when Shin and pets select the same enemy")
 var camera:Camera3D=game.camera_rig.camera
 var camera_transform=camera.global_transform
 camera.global_position=target.position+Vector3(15,12,27)
 camera.look_at(target.position+Vector3.BACK*8)
 ui.sync_pet_focus_marker();ui.sync_primary_target_marker()
 await rush_picture("shin-blue-target")
 camera.global_transform=camera_transform
 game.army_runtime.hound_focus_actor=null
 await driver.advance(8,func(_dt):advance(1,false))
 check((start.z-p.position.z)/(8*DT)>p.combat_tuning("walk_speed")*p.movement_multiplier()*1.2,"Shin sprints on a distant click")
 await aim_sword(alternate)
 before_cue=game.voice_idx
 click_attack()
 check(kit.selected_primary_enemy()==alternate,"Clicking another distant enemy switches the selection")
 check(game.voice_idx==before_cue+1 and game.last_sound_voice.get_meta("kind")=="shin_target_select","Switching targets confirms the new chase")
 await driver.advance(285,func(_dt):advance(1,false))
 ui.sync_primary_target_marker()
 check(alternate.hp<1000000 and target.hp==1000000,"Shin hits the new target only (new %.0f, old %.0f, position %s)"%[alternate.hp,target.hp,p.position])
 check(not ui.primary_target_marker.visible and kit.selected_primary_enemy()==null,"The pointer clears after the slash")
 await aim_sword(alternate)
 before_cue=game.voice_idx
 var before_hp:float=alternate.hp
 click_attack()
 check(kit.selected_primary_enemy()==alternate and game.voice_idx==before_cue+1 and game.last_sound_voice.get_meta("kind")=="shin_target_select","A fresh click on the same enemy plays the cue after the last attack ends")
 await driver.advance(60,func(_dt):advance(1,false))
 check(alternate.hp<before_hp,"The repeated click lands its attack")

func approach_case(shin:int):
 var p=game.player
 for scenario in ["aim-click","space","swap"]:
  await settle(shin);p.timed_dodge.shadow_counter_enabled=false
  var kit=p.active_ability
  var reach:float=kit.melee_visual_reach()
  var target=place_target(reach+9.5)
  await aim_sword(target)
  var start:Vector3=p.global_position;var hp:float=target.hp
  await driver.advance(24,func(_dt):advance(1,false))
  check(p.position.distance_to(start)<.08 and kit.mode.is_empty() and target.hp==hp,"Hovering over a nearby enemy leaves Shin idle")
  if scenario=="swap":
   p.swap_weapon()
   check(p.model.current_weapon()!="sword","Hovering still allows a weapon swap")
   await driver.advance(8,func(_dt):advance(1,false))
   check(p.position.distance_to(start)<.08 and kit.mode.is_empty(),"A weapon swap leaves the new weapon idle under the same aim")
   game.settings.gear_loadouts={"character:%d"%shin:{"1":"weapon:sword"}}
   continue
  click_attack()
  check(kit.selected_primary_enemy()==target,"A click selects the hovered enemy")
  await driver.advance(8,func(_dt):advance(1,false))
  var moved:float=start.z-p.position.z
  check(moved>.25 and kit.mode=="primary_approach" and not kit.state.approach_rushing,
   "Shin closes the gap after a click (moved %.2f, mode %s)"%[moved,kit.mode])
  if scenario=="aim-click":
   game.camera_rig.camera.look_at(p.position+Vector3(10,2,0))
   await driver.advance(150,func(_dt):advance(1,false))
   check(target.hp<hp and kit.selected_primary_enemy()==null,"The click lands and clears the queued slash after looking away")
   continue
  key();key(false)
  check(p.dodge_time==0 and not p.timed_dodge.reacting and kit.mode=="primary_approach","Space without a warning leaves the clicked approach active")
  tap("dodge")
  check(p.dodge_time==0 and kit.mode=="primary_approach","C leaves the clicked approach active")
  p.smoke_move=Vector2(0,1)
  var before:Vector3=p.global_position
  await driver.advance(36,func(_dt):advance(1,false))
  check(p.position.z>=before.z-.08 and kit.mode.is_empty() and target.hp==hp,"Manual movement cancels the approach without a late attack")
  p.smoke_move=Vector2.ZERO
  await driver.advance(8,func(_dt):advance(1,false))
  check(kit.mode.is_empty(),"Continued hover leaves Shin idle after cancellation")

func run():
 create_timer(180).timeout.connect(func():printerr("SHIN_SWORD_RUSH_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(RUSH_OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.set_process_input(false);game.set_process_unhandled_input(false)
 game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.music.stop();game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false
 game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear()
 game.training_dummy.position=home+Vector3.DOWN*1000
 root.gui_release_focus()
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 var p=game.player
 var shin=p.RogueRoster.SHIN_ID
 game.settings.gear_loadouts={"character:%d"%shin:{"1":"weapon:sword"}}
 for scenario in ["close","rush","evade-rush","evade-slash","cover","aim-too-far","right-click","auto","lost-target","repeat"]:
  await settle(shin);p.timed_dodge.shadow_counter_enabled=false
  game.world.sync(0)
  check(range_circle_hidden(),"The ground and stairs hide Shin's circle before any hits")
  game.player.active_ability.reset_primary_combo()
  var kit=p.active_ability
  check(p.model.current_weapon()=="sword","Shin has his sword equipped")
  var reach:float=kit.melee_visual_reach()
  var distance=reach+4.5
  if scenario in ["close","evade-slash"]:distance=reach*.65
  if scenario in ["aim-too-far","auto"]:distance=reach+23
  var target=place_target(distance)
  var decoy=place_target(distance*.8,3.5) if scenario=="rush" else null
  await aim_sword(target)
  var wall:StaticBody3D
  if scenario=="cover":
   wall=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new()
   box.size=Vector3(5,4,.2);shape.shape=box;wall.add_child(shape);game.add_child(wall)
   wall.global_position=home+Vector3(0,1,-distance*.6)
   await physics_frame;await physics_frame
  var start:Vector3=p.global_position;var hp:float=target.hp
  if scenario=="auto":
   p.set_auto_attack(true)
  elif scenario=="right-click":tap("heavy_attack")
  elif scenario!="aim-too-far":click_attack()
  if scenario in ["rush","evade-rush","lost-target","repeat"]:
   check(kit.mode=="primary_approach" and target.hp==hp,"Left click starts a rush before any damage")
   await driver.advance(2,func(_dt):advance(1,false))
   check(p.position.z<start.z-.9 and kit.mode=="primary_approach","Shin moves almost a unit or more in two physics steps")
   if scenario=="rush":await rush_picture("approach")
  else:
   check(kit.mode!="primary_approach","%s begins without an approach"%scenario)
   if scenario=="close":check(kit.mode=="attack","A close click immediately starts the slash")
  if scenario in ["evade-rush","evade-slash"]:
   key();key(false)
   check(p.dodge_time==0 and not p.timed_dodge.reacting and p.invuln==0 and kit.is_attacking(),"Space without a warning leaves %s active and grants no protection"%scenario)
   tap("dodge")
   check(p.dodge_time==0 and p.invuln==0 and kit.is_attacking(),"C leaves %s active and grants no protection"%scenario)
   await driver.advance(85,func(_dt):advance(1,false))
   check(target.hp<hp,"The original sword attack still lands")
  elif scenario=="lost-target":
   var before:Vector3=p.position
   game.army_runtime.clear()
   await driver.advance(20,func(_dt):advance(1,false))
   check(not kit.is_attacking() and p.position.distance_to(before)<.08,"Losing the target cancels the rush without coasting")
  else:
   if scenario=="rush":
    for i in 15:
     if kit.mode!="primary_approach":break
     await driver.advance(1,func(_dt):advance(1,false))
    check(kit.ticket.get("action")=="shin_basic" and is_zero_approx(kit.elapsed) and target.hp==hp,"Arrival starts the original slash and its original windup")
    var travel=start.z-p.position.z
    check(travel>3.0 and travel<=5.05,"The longer rush stops in reach, traveled %.2f"%travel)
    game.world.sync(0.0)
    check(range_circle_hidden(),"Neither the rush nor windup reveals the circle")
    var contact_ticks=ceili(kit.shin_contact/p.attack_speed_multiplier()/DT)
    await driver.advance(contact_ticks,func(_dt):advance(1,false))
    game.world.sync(0.0)
    check(target.hp<hp and range_circle_hidden(),"The sword lands without showing a range circle")
    var camera:Camera3D=game.camera_rig.camera
    camera.global_position=p.position+Vector3(8,10,12)
    camera.look_at(p.position+Vector3.FORWARD*2)
    await rush_picture("slash-no-range-circle")
   var recovery_ticks=ceili(float(p.model.normal_attack_pattern().duration)/p.attack_speed_multiplier()/DT)+24
   await driver.advance(recovery_ticks,func(_dt):advance(1,false))
   if scenario in ["close","rush","repeat"]:
    var expected:float=kit.Skills.basic_damage(p.model.normal_attack_pattern())*p.damage_multiplier()
    check(is_equal_approx(hp-target.hp,expected),"%s lands exactly one normal sword hit, %.2f / %.2f"%[scenario,hp-target.hp,expected])
    if decoy!=null:check(decoy.hp==1000000,"An off-aim enemy does not attract the rush")
   else:
    game.world.sync(0)
    check(target.hp==hp and range_circle_hidden(),"%s deals no damage and leaves the circle hidden"%scenario)
   if scenario not in ["rush","repeat","right-click"]:check(absf(p.position.z-start.z)<.08,"%s does not move Shin toward an enemy"%scenario)
   check(not kit.is_attacking(),"%s finishes with no queued strike"%scenario)
   if scenario=="repeat":
    p.position=start;p.velocity=Vector3.ZERO
    await driver.advance(3,func(_dt):advance(1,false))
    hp=target.hp;click_attack()
    check(kit.mode=="primary_approach","A fresh click can rush again after recovery")
    await driver.advance(recovery_ticks,func(_dt):advance(1,false))
    check(target.hp<hp and not kit.is_attacking(),"A second rush lands and clears its state")
  p.set_auto_attack(false)
  game.world.sync(.36)
  if wall!=null:wall.queue_free()
 await approach_case(shin)
 await forgiving_click(shin)
 await crowded_click(shin)
 await tab_cycle(shin)
 await moving_target_click(shin)
 await distant_selection(shin)
 await combo_case(shin)
 print("SHIN_SWORD_RUSH_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
