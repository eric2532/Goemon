extends Node
var game: Node
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+label)
 else:print("PASS: ",label)
func frames(count: int):
 for i in range(count):await get_tree().physics_frame
func run():
 var probe_path="user://maps/__codex_builder_persistence_probe.json"
 if "--map-save-probe-write" in OS.get_cmdline_user_args():
  var doc=load("res://scripts/map_document.gd").new();doc.reset_blank();doc.rename("Persistence Probe")
  doc.place("cherry",Vector3(50,0,150),90)
  check(doc.save(probe_path)==OK,"First app process saves named scenery map")
  finish();return
 if "--map-save-probe-read" in OS.get_cmdline_user_args():
  game.open_map_editor();await frames(3);game.map_editor.load_path(probe_path)
  var doc=game.map_editor.document;var tree=doc.find_kind("cherry")
  check(doc.data.title=="Persistence Probe" and tree.size()==1 and tree[0].x==50 and tree[0].rotation==90,"Second fresh app process reloads authored scenery and rotation")
  check(not doc.dirty and game.map_editor.current_path==probe_path,"Reloaded map retains its saved slot")
  DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_path));game.map_editor.close_editor();finish();return
 check(game.has_method("open_map_editor"),"Main game exposes in-game editor")
 if not game.has_method("open_map_editor"):finish();return
 game.open_map_editor();await frames(3)
 var editor=game.map_editor
 check(is_instance_valid(editor) and game.paused and not game.playing and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Builder pauses gameplay with usable pointer")
 check(editor.document.validate().is_empty(),"Builder opens playable starter")
 var initial_count=editor.document.data.pieces.size()
 editor.choose_piece("lantern");editor.place_at(Vector3(32,0,154))
 check(editor.document.data.pieces.size()==initial_count+1,"Editor placement adds chosen scenery")
 var uid=editor.selected_uid
 editor.document.move_item(uid,Vector3(34,0,154));editor.select_tool();editor.rotate_selected();editor.refresh_preview()
 check(editor.document.item(uid).rotation==90,"Editor rotation updates selected piece")
 editor.undo();check(editor.document.item(uid).rotation==0,"Editor undo restores visual placement")
 editor.redo();check(editor.document.item(uid).rotation==90,"Editor redo reapplies rotation")
 editor.name_field.text="Builder Integration Test"
 editor.save_map();check(not editor.document.dirty,"Editor save clears dirty state")
 var file=editor.current_path
 editor.choose_piece("lantern");editor.place_at(Vector3(38,0,154));editor.load_path(file)
 check(editor.document.data.pieces.size()==initial_count+1,"Load restores saved scene instead of unsaved extra piece")
 var doc=load("res://scripts/map_document.gd").new();doc.reset_blank()
 doc.move_item(doc.find_kind("enemy")[0].uid,Vector3(-30,0,110))
 doc.move_item(doc.find_kind("base")[0].uid,Vector3(30,0,300))
 doc.move_item(doc.find_kind("spawn")[0].uid,Vector3(45,0,240))
 doc.place("waypoint",Vector3(30,0,110));doc.place("waypoint",Vector3(30,0,170));doc.place("waypoint",Vector3(-30,0,170));doc.place("waypoint",Vector3(-30,0,140));doc.place("waypoint",Vector3(-30,0,240))
 doc.place("tower",Vector3(45,0,180));doc.place("mine",Vector3(45,0,205));doc.place("rock",Vector3(60,0,270))
 check(doc.validate().is_empty(),"Authored horizontal and backward route is playable")
 editor.document=doc;editor.play_map();await frames(4)
 check(game.is_fire_siege() and game.world.get("custom_map")==true,"Play Map launches authored Fire Siege world")
 check(game.world.spawn_point==Vector3(45,.15,240) and game.player.position.distance_to(Vector3(45,.15,240))<1,"Hero uses authored spawn")
 check(game.encounters.site_states.size()==1 and game.encounters.mine_states.size()==1,"Authored tower and mine become constructible structures")
 check(game.world.lanes[1].size()==7 and game.world.lanes[1][1]==Vector3(30,0,110),"Runtime uses authored route order")
 var query=PhysicsRayQueryParameters3D.create(Vector3(60,1,260),Vector3(60,1,275),1)
 check(not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"New boulder has real gameplay collision")
 var draft=game.map_editor_draft.encode()
 game.tuning.freeze_ai=true;game.encounters.set_physics_process(false)
 game.encounters.update_start_input(0,false);game.encounters.update_start_input(3,true);game.encounters.tick(.2)
 var enemy=game.enemies.filter(func(e):return is_instance_valid(e) and not e.dead)[0]
 enemy.defense_offset=Vector3.ZERO;enemy.position=Vector3(-30,.15,110)
 check(game.encounters.lane_direction(enemy).x>.99,"First horizontal segment moves east without skipping")
 enemy.position=Vector3(30,.15,110);var direction=game.encounters.lane_direction(enemy)
 check(enemy.defense_waypoint==2 and direction.z>.99,"Reaching east turn advances to next segment")
 enemy.position=Vector3(30,.15,170);direction=game.encounters.lane_direction(enemy)
 check(enemy.defense_waypoint==3 and direction.x<-.99,"Route turns west")
 enemy.position=Vector3(-30,.15,170);direction=game.encounters.lane_direction(enemy)
 check(enemy.defense_waypoint==4 and direction.z<-.99,"Backward segment moves north instead of skipping")
 enemy.position=game.world.base_position+Vector3(0,.15,-5);enemy.defense_waypoint=1
 game.encounters.lane_direction(enemy)
 enemy._physics_process(1.0/60)
 check(not enemy.dead,"Passing close to shrine on an earlier segment does not breach")
 enemy.defense_waypoint=game.world.lanes[1].size()-1;game.encounters.lane_direction(enemy)
 check(not enemy.dead and game.encounters.shrine.handles(enemy) and game.encounters.wave_breaches==1,"Final-segment arrival admits one living shrine attacker")
 game.encounters.tick(.2)
 enemy=game.enemies.filter(func(e):return is_instance_valid(e) and not e.dead)[0];enemy.defense_waypoint=4
 enemy.position=Vector3(-100,-8,152)
 check(game.encounters.recover_escaped_actor(enemy) and game.world.playable_bounds.has_point(Vector2(enemy.position.x,enemy.position.z)),"Knockback recovery returns enemy to custom route")
 game.show_pause();check(game.menu.find_child("ReturnToMapBuilder",true,false)!=null,"Custom run pause offers return to editor")
 game.open_map_editor();await frames(3)
 check(game.map_editor.document.encode()==draft and not game.playing,"Return to editor preserves exact authored draft")
 game.map_editor.close_editor();await frames(3)
 game.start_mode("defense");await frames(3)
 check(game.world.get("custom_map")!=true and game.world.cannon_sites.size()==12,"Ordinary Fire Siege still uses original latest map")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
 game.show_main_menu();finish()
func finish():
 print("MAP_BUILDER_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
