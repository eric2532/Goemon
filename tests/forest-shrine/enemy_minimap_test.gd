extends SceneTree
var game
var checks=0
var failures=0
var cfg="user://enemy-minimap-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(45).timeout.connect(func():printerr("FAIL: enemy minimap timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 print("PASS: " if ok else "FAIL: ",label_)
 if not ok:failures+=1
func frames(n:int=3):
 for i in n:await process_frame
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 var radar=game.forest_ui.get_node_or_null("EnemyMinimap")
 check(radar!=null,"HUD has a compact enemy minimap")
 if radar==null:await finish();return
 check(not radar.visible,"Preparation leaves building controls free of the combat minimap")
 game.start_wave();game.model.waves.spawn_clock=100000;game.model.waves.pending=999;game.set_physics_process(false);game.player.set_physics_process(false);await frames()
 check(radar.visible,"Minimap appears when combat begins")
 var center=Vector3(-3,0,-3)
 var north=game.model.waves.spawn_enemy(0,center+Vector3(0,0,-120))
 var east=game.model.waves.spawn_enemy(1,center+Vector3(120,0,0))
 var dead=game.model.waves.spawn_enemy(3,center+Vector3(0,0,120));dead.hp=0
 var corner=game.model.waves.spawn_enemy(2,Vector3(280.8,0,280.8))
 game.model.visible_cells.clear();radar.refresh()
 check(radar.markers.size()==3,"Radar shows all living wave enemies, including arrivals beyond shared sight")
 var middle=radar.size*.5
 check(radar.markers[0].y<middle.y and absf(radar.markers[0].x-middle.x)<.1,"North enemy appears above the map center")
 check(radar.markers[1].x>middle.x and absf(radar.markers[1].y-middle.y)<.1,"East enemy appears right of the map center")
 check(Array(radar.markers).all(func(point):return Rect2(Vector2(4,4),radar.size-Vector2(8,8)).has_point(point)),"Even far corner enemies remain inside the square rim")
 check(radar.markers.size()==game.model.enemies.values().filter(func(e):return e.hp>0).size(),"Defenders, workers, the player and training dummy create no markers")
 check(radar.markers[2].x>radar.size.x*.9 and radar.markers[2].y>radar.size.y*.9,"Square map uses its corners for battlefield corners")
 game.player.position=center;radar.refresh()
 check(radar.get("player_marker") is Vector2,"Minimap tracks a distinct player marker")
 if radar.get("player_marker") is Vector2:
  check(radar.player_marker.is_equal_approx(middle),"Character at battlefield center appears in map center")
  game.player.position=center+Vector3(120,20,0);radar.refresh()
  check(radar.player_marker.is_equal_approx(radar.markers[1]),"Player and enemy positions use the same scale, ignoring height")
 var old=radar.markers.duplicate();game.camera_rig.yaw=PI*.7;game.player.position+=Vector3(80,0,80);radar.refresh()
 check(radar.markers==old,"Whole battlefield stays north-up when the player or camera moves")
 if radar.get("player_marker") is Vector2:
  check(radar.player_marker.x>old[1].x and radar.player_marker.y>middle.y,"Character marker follows movement while enemy map stays fixed")
 north.pos+=Vector3(18,0,0);radar.refresh()
 check(radar.markers[0].x>old[0].x,"Enemy movement updates its marker location")
 game.model.enemies.erase(east.id);radar.refresh()
 check(radar.markers.size()==2,"Removed enemies immediately leave the radar")
 for scale_ in [.65,1.25]:
  game.set_forest_hud_scale(scale_);game.forest_ui.sync();await frames()
  var rect=radar.get_global_rect();var screen=root.get_visible_rect()
  check(rect.size.x==rect.size.y and rect.size.x>=100 and rect.size.x<=220,"HUD scaling keeps a small square map (%s)"%scale_)
  check(rect.position.x>=12 and absf(screen.end.y-rect.end.y-20)<1,"Minimap stays anchored to the bottom-left (%s)"%scale_)
  check(not rect.intersects(game.forest_ui.loadout_slots.get_global_rect()),"Minimap does not overlap the top-left HUD (%s)"%scale_)
 check(radar.mouse_filter==Control.MOUSE_FILTER_IGNORE and radar.focus_mode==Control.FOCUS_NONE,"Minimap cannot capture combat clicks or keyboard focus")
 check(radar.get_child_count()==0,"Enemy radar adds no world viewport, labels or detailed map layers")
 game.show_pause();game.forest_ui.sync();check(not radar.visible,"Pause hides the combat minimap")
 game.resume();game.forest_ui.sync();check(radar.visible,"Resuming restores the minimap")
 game.model.phase="preparing";game.set_phase_view();game.forest_ui.sync();check(not radar.visible,"Returning to preparation hides the radar")
 game.show_title();check(not radar.is_visible_in_tree(),"Title does not display the minimap")
 await finish()
func finish():
 game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("ENEMY_MINIMAP_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
