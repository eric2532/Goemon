extends SceneTree
## Paid map placement and local guarding replace the five free hotkey summons.
var game
var checks=0
var failures=0
var cfg="user://guard-hiring-%d.cfg"%OS.get_process_id()
func _initialize():
 set_meta("forest_army_backend","legacy");set_meta("forest_painterly_preview",true)
 create_timer(60).timeout.connect(func():printerr("FAIL: guard hiring timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func settle():
 for i in 3:await process_frame
func capture(label_:String):
 if "--visual" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Guard Hiring/"+label_+".png")
func point_for(helpers,slot:int,exclude:int=0)->Vector3:
 for z in range(4,18):
  for x in range(-12,13):
   var point=game.model.point(Vector2i(x,z))
   if helpers.placement_error(slot,point,exclude).is_empty():return point
 return Vector3.INF
func run():
 root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 await settle();AudioServer.set_bus_mute(0,true)
 var h=game.explorer_helpers;var ui=game.forest_ui
 check(h.has_method("purchase") and h.has_method("begin_placement"),"Preparation exposes paid guard placement")
 if not h.has_method("purchase"):await finish();return
 game.model.gold=2000;game.player.select_character(14);ui.sync()
 game.model.build("barracks",Vector2i(12,10),0)
 check(ui.loadout_buttons.all(func(button):return button.disabled and not button.button_pressed),"Ed has five empty inactive number slots")
 check(ui.helper_portraits.all(func(icon):return not icon.visible),"Unused slots have no summon portraits")
 var initial_gold=game.model.gold
 for slot in 5:
  ui.select_loadout_slot(slot)
  var key=InputEventKey.new();key.physical_keycode=KEY_1+slot;key.pressed=true;root.push_input(key,true)
  key=key.duplicate();key.pressed=false;root.push_input(key,true)
 await settle()
 check(h.active_units().is_empty() and game.model.gold==initial_gold,"Empty slots neither summon nor spend ryo")
 game.player.select_character(1);ui.sync();ui.select_loadout_slot(1)
 check(ui.loadout_buttons.slice(0,3).all(func(button):return not button.disabled) and ui.helper_portraits.slice(0,3).all(func(icon):return icon.visible),"Goemon retains his three assigned weapon slots")
 game.player.select_character(18);ui.sync();ui.select_loadout_slot(3)
 check(game.player.master_chief_combat.weapon_slot==4,"Chief retains all five real weapons")
 game.player.select_character(14);ui.sync()
 ui.show_guard_shop();await settle()
 check(ui.get_node_or_null("GuardShop")!=null,"Preparation opens a clickable guard shop")
 root.size=Vector2i(960,600);await settle()
 check(root.get_visible_rect().encloses(ui.guard_shop.panel.get_global_rect()),"The hiring panel fits a smaller window")
 check(ui.preparation_actions.get_children().all(func(button):return root.get_visible_rect().encloses(button.get_global_rect())),"Preparation actions wrap inside a smaller window")
 root.size=Vector2i(1280,800);await settle()
 for slot in 5:
  var button=ui.find_child("HireGuard%d"%slot,true,false)
  check(button!=null and str(h.COSTS[slot]) in button.text,"Each individual ally displays its ryo price")
 await capture("guard-shop")
 var shop_button=ui.find_child("HireGuard1",true,false)
 var shop_click=InputEventMouseButton.new();shop_click.button_index=MOUSE_BUTTON_LEFT;shop_click.pressed=true;shop_click.position=shop_button.get_global_rect().get_center()
 root.push_input(shop_click,true);await process_frame
 shop_click=shop_click.duplicate();shop_click.pressed=false;root.push_input(shop_click,true);await settle()
 check(h.selected_slot==1 and h.active_units().is_empty() and game.model.gold==initial_gold,"Choosing a Ranger previews placement without charging")
 check(ui.guard_shop_open(),"Choosing an ally keeps the hiring menu open for map placement")
 check(not h.purchase(1,Vector3.INF),"Nonfinite placement is rejected")
 check(not h.purchase(1,game.model.center(game.model.shrine())),"A guard cannot be placed inside a building")
 check(not h.purchase(1,Vector3(10000,0,10000)),"Out-of-map placement is rejected")
 check(game.model.gold==initial_gold and h.active_units().is_empty(),"Invalid placement spends nothing and creates nothing")
 var point=point_for(h,1)
 check(point.is_finite(),"The original map offers valid guard ground")
 if not point.is_finite():await finish();return
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=game.camera_rig.camera.unproject_position(point)
 game._unhandled_input(click)
 check(h.active_units(1).size()==1,"A map click through the real preparation input hires a Ranger")
 check(h.active_units(1).size()==1,"One purchase hires exactly one individual Ranger")
 check(game.model.gold==initial_gold-h.COSTS[1],"Successful placement deducts the displayed price exactly once")
 var unit=h.active_units(1)[0]
 game.pan=unit.guard_post;game.preparation_size=90;game.update_preparation_camera()
 var motion=InputEventMouseMotion.new();motion.position=game.camera_rig.camera.unproject_position(unit.guard_post);root.push_input(motion,true);await settle()
 h.set_process(false);h.show_guard_area(unit.guard_post,true)
 check(h.guard_preview.visible and h.guard_preview.mesh!=null,"The guard area has a visible map preview")
 await capture("guard-post")
 h.set_process(true)
 check(unit.state=="prepared" and unit.guard_post.distance_to(point)<.2,"The hired ally waits at its assigned guard post")
 check(h.selected_slot==-1,"Purchase exits placement mode to prevent accidental repeat charges")
 check(ui.guard_shop_open(),"A completed purchase keeps the mercenary menu open")
 var money=game.model.gold;var another=point_for(h,1)
 check(not h.purchase(1,point),"A second ally cannot overlap an occupied guard post")
 check(game.model.gold==money and h.active_units().size()==1,"Overlapping placement is transactional")
 unit.hp=73
 click.position=game.camera_rig.camera.unproject_position(unit.guard_post);game._unhandled_input(click)
 check(h.moving_actor==unit.gate_id,"Clicking a placed ally selects its guard post")
 click.position=game.camera_rig.camera.unproject_position(another);game._unhandled_input(click)
 check(h.moving_actor==0,"A second map click finishes guard relocation")
 check(game.model.gold==money and unit.hp==73 and unit.guard_post.distance_to(another)<.2,"Repositioning preserves ryo, health and the same ally")
 game.model.gold=h.COSTS[0]-1
 check(not h.begin_placement(0) and not h.purchase(0,point),"Insufficient ryo blocks purchase and selection")
 check(game.model.gold==h.COSTS[0]-1,"Failed purchase cannot make the balance negative")
 game.model.gold=money
 check(h.begin_placement(0),"A second ally can be previewed")
 var cancel=InputEventMouseButton.new();cancel.button_index=MOUSE_BUTTON_RIGHT;cancel.pressed=true;game._unhandled_input(cancel)
 check(h.selected_slot==-1 and game.model.gold==money,"Right-click cancels a preview without spending")
 check(ui.guard_shop_open(),"Canceling a preview keeps the menu open until Esc")
 ui.show_guard_shop()
 var escape=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true;game._input(escape)
 check(not ui.guard_shop_open() and not game.ordinary_pause,"Escape closes the hiring shop without opening Pause")
 h.begin_placement(0);game.select_build("wall")
 check(h.selected_slot==-1 and game.build_kind=="wall","Selecting construction cancels guard placement")
 game.build_kind=""
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.set_process(false);game.player.set_physics_process(false);unit.set_physics_process(false)
 check(not h.purchase(0,point) and not h.begin_placement(0),"Allies cannot be bought during a wave")
 check(not h.relocate(unit.gate_id,point),"Guard posts cannot move during a wave")
 ui.sync();check(not ui.guard_shop_button.visible,"The hire button hides during combat")
 unit.invuln=0;unit.take_hit(10,Vector3.BACK,true)
 var wounded_hp=unit.hp
 unit._physics_process(.4);unit.take_hit(10,Vector3.BACK,true)
 check(unit.state=="prepared" and unit.hp<wounded_hp,"A waiting guard remains vulnerable to repeated distant shots after brief immunity expires")
 unit.hp=73;unit.invuln=0
 var near=game.model.waves.spawn_enemy(0,unit.guard_post+Vector3(5,0,0));near.hp=100000;near.max_hp=100000
 var far=game.model.waves.spawn_enemy(0,unit.guard_post+Vector3(80,0,0));far.hp=100000;far.max_hp=100000
 game.sync_enemies();await settle()
 for actor in game.actors.values():actor.set_physics_process(false)
 for data in [near,far]:game.model.visible_cells[game.model.cell_of(data.pos)]=true
 game.player.position=far.pos;unit.think()
 check(unit.ai_target==game.actors[near.id],"A guard acquires an enemy inside its assigned area")
 game.actors[near.id].dead=true;near.hp=0
 unit.position=unit.guard_post+Vector3(4,0,0);unit.think()
 check(unit.ai_target==game.actors[far.id] and not unit.auto_attack_enabled,"A mercenary acquires a distant enemy after the nearby one falls")
 check(unit.route_goal!=game.model.cell_of(unit.guard_post) and unit.ai_move.length_squared()>0,"A mercenary pursues its distant enemy instead of returning to its post")
 game.model.phase="preparing";h.rest()
 check(unit.guard_post.distance_to(another)<.2 and unit.position.distance_to(another)<.2,"The assigned guard post survives the next preparation phase")
 check(unit.hp==73,"Resting preserves the surviving ally's health")
 await finish()
func finish():
 if is_instance_valid(game):game.sound_library.cancel();game.music.stop();game.queue_free()
 paused=false;await settle()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GUARD_HIRING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
