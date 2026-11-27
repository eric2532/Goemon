extends "res://tests/forest-shrine/tina_explorer_review.gd"
## Fixed source-coordinate cameras; no walking and no user preference writes.
const AUDIT="res://build/Other Files/Asset Toolkit/Tina Recovery/Full Village Audit/"
var audit_path=AUDIT
const VIEWS=[
 ["01-north-entrance",Vector2i(29,20),36.0],
 ["02-north-storage",Vector2i(47,13),46.0],
 ["03-hospital",Vector2i(36,27),43.0],
 ["04-mayor-west-street",Vector2i(33,42),49.0],
 ["05-east-yards-graveyard",Vector2i(70,43),61.0],
 ["06-pub-square",Vector2i(48,54),49.0],
 ["07-west-house",Vector2i(24,57),43.0],
 ["08-green-house-south-gate",Vector2i(35,64),55.0],
 ["09-harbor-south-shore",Vector2i(52,80),65.0],
 ["10-east-shore",Vector2i(85,66),55.0],
 ["11-west-north-verge",Vector2i(13,33),59.0],
 ["12-south-west-verge",Vector2i(16,76),60.0],
 ["13-far-north-east",Vector2i(75,17),66.0],
 ["14-far-south-east",Vector2i(78,87),64.0]]

func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--audit-out="):audit_path=arg.trim_prefix("--audit-out=").trim_suffix("/")+"/"
 root.size=Vector2i(1440,1000)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-tina-full-audit-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.set_process(false);game.explorer_clock.load_hour(12)
 await visit_source(51005,Vector2i(43,55))
 snapshot_layout()
 hide_canvas(game)
 game.camera_rig.set_process(false)
 var camera=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.far=10000
 var phase="Before" if "--baseline" in OS.get_cmdline_user_args() else "After"
 var folder=audit_path+phase+"/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var poses=[]
 var views=VIEWS.duplicate()
 for z in 4:
  for x in 4:views.append(["sector-%d%d"%[z,x],Vector2i(x*25+12,z*25+12),78.0])
 for view in views:
  var at=game.model.world_point(Original.source_point(51005,view[1]))
  camera.size=view[2]*game.model.falan_scale*1.45
  camera.global_position=at+Vector3(-1,1.6,1)*200*game.model.falan_scale
  camera.look_at(at)
  await audit_snap(folder+view[0]+".png")
  var zero=game.model.world_point(Original.source_point(51005,Vector2i.ZERO))
  var screen=camera.unproject_position(zero)
  var right=camera.unproject_position(zero+Vector3(3*game.model.falan_scale,0,0))
  poses.append({"name":view[0],"source_map":4200,"cell":[view[1].x,view[1].y],"span":view[2],"position":str(camera.global_position),"size":camera.size,"native_origin_screen":[screen.x,screen.y],"native_pixel_scale":(right.x-screen.x)/32.0})
 var at=game.model.world_point(Original.source_point(51005,Vector2i(50,50)))
 camera.size=330*game.model.falan_scale
 camera.global_position=at+Vector3(-1,1.6,1)*500*game.model.falan_scale;camera.look_at(at)
 await audit_snap(folder+"00-whole-village.png")
 var zero=game.model.world_point(Original.source_point(51005,Vector2i.ZERO))
 var screen=camera.unproject_position(zero)
 var right=camera.unproject_position(zero+Vector3(3*game.model.falan_scale,0,0))
 poses.append({"name":"00-whole-village","source_map":4200,"native_origin_screen":[screen.x,screen.y],"native_pixel_scale":(right.x-screen.x)/32.0})
 camera.size=315*game.model.falan_scale
 camera.global_position=at+Vector3.UP*600*game.model.falan_scale;camera.look_at(at,Vector3.FORWARD)
 await audit_snap(folder+"00-overhead.png")
 var corner=game.model.world_point(Original.source_point(51005,Vector2i.ZERO))+Vector3(-1.5,0,-1.5)*game.model.falan_scale
 var a=camera.unproject_position(corner);var b=camera.unproject_position(corner+Vector3(300,0,300)*game.model.falan_scale)
 var overhead=FileAccess.open(folder+"overhead.json",FileAccess.WRITE);overhead.store_string(JSON.stringify({"source_bounds":[0,0,100,100],"screen_bounds":[a.x,a.y,b.x,b.y]}))
 for view in [["play-hospital",Vector2i(40,35),PI*.25],["play-pub",Vector2i(42,60),-PI*.25],["play-harbor",Vector2i(50,76),-PI*.5]]:
  game.player.global_position=game.model.world_point(Original.source_point(51005,view[1]))+Vector3.UP
  camera.projection=Camera3D.PROJECTION_PERSPECTIVE
  game.camera_rig.pitch=.65;game.camera_rig.yaw=view[2];game.camera_rig.distance=18
  game.camera_rig.reset_follow();game.camera_rig.set_process(true)
  for i in 12:await process_frame
  await audit_snap(folder+view[0]+".png")
  game.camera_rig.set_process(false)
 game.explorer_clock.load_hour(0)
 await visit_source(4201,Vector2i(43,55))
 snapshot_layout(4201)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera_rig.set_process(false);hide_canvas(game)
 var night_views=[VIEWS[2],VIEWS[5],VIEWS[6],VIEWS[8]]
 for z in 4:
  for x in 4:night_views.append(["sector-%d%d"%[z,x],Vector2i(x*25+12,z*25+12),78.0])
 for view in night_views:
  var target=game.model.world_point(Original.source_point(4201,view[1]))
  camera.size=view[2]*game.model.falan_scale*1.45
  camera.global_position=target+Vector3(-1,1.6,1)*200*game.model.falan_scale;camera.look_at(target)
  var name_="night-"+view[0]
  await audit_snap(folder+name_+".png")
  zero=game.model.world_point(Original.source_point(4201,Vector2i.ZERO));screen=camera.unproject_position(zero)
  right=camera.unproject_position(zero+Vector3(3*game.model.falan_scale,0,0))
  poses.append({"name":name_,"source_map":4201,"native_origin_screen":[screen.x,screen.y],"native_pixel_scale":(right.x-screen.x)/32.0})
 var file=FileAccess.open(folder+"cameras.json",FileAccess.WRITE);file.store_string(JSON.stringify(poses,"  "))
 finish()

func hide_canvas(node:Node):
 if node is CanvasLayer:node.hide()
 for child in node.get_children():hide_canvas(child)

func recovered_root(node:Node,source:int)->Node:
 if node.get_meta("recovered_source_map",0)==source:return node
 for child in node.get_children():
  var found=recovered_root(child,source)
  if found!=null:return found
 return null

func snapshot_layout(id:int=51005):
 var source=Original.source_id(id)
 var map_root=recovered_root(game,source)
 check(map_root!=null,"Actual Explorer contains the complete Tina source map")
 var actual=[];var expected=[]
 var row=Original.state(id);var art=Original.Art.new();art.load_map(Original.path_for(id))
 for child in map_root.get_children():
  if not child is MultiMeshInstance3D or not child.has_meta("source_graphic"):continue
  var serial=int(child.get_meta("source_graphic"))
  for i in child.multimesh.instance_count:
   var at=child.position+child.multimesh.get_instance_transform(i).origin
   var cell=Vector2i(roundi((at.x-row.origin.x)/3),roundi((at.z-row.origin.y)/3))
   actual.append("%d:%d:%d"%[serial,cell.x,cell.y])
 for placement in art.placements:
  if placement[4]<10000:continue
  var serial:int=placement[3];var g:Dictionary=Original.Art.data().graphics[str(serial)]
  var family=Original.Forms.kind(serial,false,g)
  if family in ["void","floor","water","detail_flat_panel","flowers"] and not Original.TinaGround.shore(serial) and not Original.TinaScenery.owns(source,serial):continue
  expected.append("%d:%d:%d"%[serial,placement[5].x,placement[5].y])
 actual.sort();expected.sort()
 check(actual==expected,"Every actual scenery instance has its original map anchor and count")
 var file=FileAccess.open(audit_path+("runtime-layout.json" if source==4200 else "runtime-layout-night.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"source_map":source,"source_placements":art.placements.size(),"rendered_source_placements":map_root.get_meta("recovered_source_placements"),"expected_solids":expected,"actual_solids":actual,"anchors_match":actual==expected,"links":Original.links(id)},"  "))

func audit_snap(path:String):
 DisplayServer.window_move_to_foreground()
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
 print("TINA_FULL_VIEW ",path)
