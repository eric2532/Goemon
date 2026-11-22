extends "res://tests/forest-shrine/timed_dodge_test.gd"

const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Patrols=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
const Dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
const CAPTURE_DIR="res://build/Other Files/Asset Toolkit/Crosshair/"

func lock_goblin_behind_shin(goblin:Ninja):
 var p=game.player
 var kit=p.active_ability
 var camera:Camera3D=game.camera_rig.camera
 camera.global_position=home+Vector3(0,3,-8)
 camera.look_at(home+Vector3.UP*p.model.standing_height())
 camera.make_current()
 await physics_frame
 check(game.crosshair_ray_hit().get("collider")!=goblin,"Shin is in the aim line and the exact ray misses the small goblin")
 var tab=InputEventKey.new();tab.physical_keycode=KEY_TAB;tab.pressed=true
 game.set_process_input(true)
 root.push_input(tab,true)
 tab.pressed=false;root.push_input(tab,true)
 game.set_process_input(false)
 game.forest_ui._physics_process(0)
 check(kit.locked_primary_enemy()==goblin and kit.mode.is_empty() and game.forest_ui.primary_target_marker.visible,"Tab marks the goblin without needing to aim at its body or move Shin")
 check(game.forest_ui.patrol_target.visible and game.forest_ui.patrol_target.text=="%s · Lv.2"%Patrols.NAMES[Patrols.GOBLIN],"The blue lock identifies the goblin by name and level")
 if DisplayServer.get_name()!="headless":
  game.crowd.present_army(game.army_runtime.render_snapshot(),[])
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
  check(root.get_texture().get_image().save_png(CAPTURE_DIR+"shin-goblin-tab-target.png")==OK,"Captured the blue lock on the small goblin")

func run():
 create_timer(60).timeout.connect(func():printerr("GOBLIN_RETALIATION_TIMEOUT");quit(1))
 await setup_fixture(Tour.Regions.layout("east_gate"))
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.music.stop();game.tuning.invincible=false
 var p=game.player
 var army=game.army_runtime
 army.set_process(false);army.set_physics_process(false)
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 var shin=p.RogueRoster.SHIN_ID
 game.settings.gear_loadouts={"character:%d"%shin:{"1":"weapon:sword"}}
 var edge:float=Tour.Frontier.ENEMY_EDGE
 p.global_position=game.model.world_point(Vector2(3,edge-1),.05)
 check(army.external_targets().targetable[0]==0,"The gate approach inside the enemy boundary stays safe")
 var patrol_point=Vector3.INF
 army.refresh_navigation(0)
 for x in [3,0,6,-3,9,-6,12,-9,15,-12,18,-15,-18,21,-21,24,-24,27,-27,30,-30]:
  var at:Vector2=Vector2(x,Tour.Frontier.COMBAT_EDGE-3)
  var start:Vector3=game.model.world_point(at,.05)
  var end:Vector3=game.model.world_point(at+Vector2(0,2.2))
  var behind=start+Vector3(-7,0,-9)
  behind.y=game.model.world_height(behind.x,behind.z)
  if not army.native.ally_ground_clear(behind,5.0):continue
  if not army.native.ally_ground_clear(start,.85) or not army.native.can_reach(end,start,.85):continue
  home=start;patrol_point=end
  break
 check(patrol_point.is_finite(),"The East Gate has a clear path in the formerly protected strip")
 if patrol_point.is_finite():
  await settle(shin)
  game.model.update_vision(home/game.model.falan_scale)
  var stats=Patrols.progression(Patrols.GOBLIN,0)
  var row=game.model.waves.spawn_enemy(game.model.waves.Roles.SLIME,patrol_point,-1,Patrols.GOBLIN)
  row.frontier_patrol=true;row.footprint=Patrols.FOOTPRINT;row.patrol_radius=Patrols.LEASH
  row.hp=stats.hp;row.max_hp=stats.hp;row.health_scale=stats.hp/Patrols.STATS.hp
  row.damage_scale=stats.damage/Patrols.STATS.damage
  row.level=stats.level;row.enemy_name=Patrols.NAMES[Patrols.GOBLIN]
  army.import_arrivals();army.sync_targets()
  var goblin=army.enemy_target(row.id)
  check(goblin.local_combat_box().size.is_equal_approx(Dimensions.body(Patrols,Patrols.GOBLIN).size*game.model.waves.Roles.MAP_ENEMY_SCALE),"The patrol's targetable body uses the shared scale in all three dimensions")
  if DisplayServer.get_name()!="headless":
   game.crowd.present_army(army.render_snapshot(),[])
   for key in game.crowd.army.batches:
    if key.x==game.model.waves.Roles.SLIME:
     check(is_equal_approx(game.crowd.army.batches[key].get_instance_shader_parameter("map_enemy_scale"),game.model.waves.Roles.MAP_ENEMY_SCALE),"The live goblin sprite matches its enlarged combat body")
  await lock_goblin_behind_shin(goblin)
  await process_frame
  var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
  click.position=game.crosshair_screen_position();click.global_position=click.position
  root.push_input(click,true)
  click.pressed=false;root.push_input(click,true)
  check(p.active_ability.selected_primary_enemy()==goblin,"Left-click commits the marked goblin")
  await driver.advance(1,func(_dt):advance(50,false))
  check(goblin.hp>0 and goblin.hp<stats.hp,"The goblin survives Shin's real sword hit (%.1f of %.1f HP)"%[goblin.hp,stats.hp])
  check(army.external_targets().targetable[0]==1,"The player can be targeted where outdoor patrols can walk")
  var hp:float=p.hp
  for i in 180:
   if p.hp<hp:break
   await driver.advance(1,func(_dt):advance(1))
  check(is_equal_approx(hp-p.hp,stats.damage),"The wounded goblin retaliates with a native melee hit (%.1f damage)"%(hp-p.hp))
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOBLIN_RETALIATION_RESULT checks=%d failures=%d"%[checks,failures])
 quit(1 if failures else 0)
