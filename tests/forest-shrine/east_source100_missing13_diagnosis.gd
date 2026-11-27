extends "res://tests/forest-shrine/east_region_review.gd"
const DEST="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/"
func run():
 var paths=["res://scripts/forest/forest_falan_frontier.gd","res://scripts/forest/forest_freyja_regions.gd","res://scripts/forest/forest_freyja_terrain.gd","res://scripts/forest/forest_falan_streets.gd","res://scripts/forest/forest_east_road.gd","res://assets/maps/falan/east_region/field-scenery.json",DEST+"source.json"];var hashes={}
 for path in paths:hashes[path]=FileAccess.get_sha256(path)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east13-diagnosis-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID);game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false);await open_area("east_gate")
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DEST+"source.json"));var rows=[]
 for record:Dictionary in data.records:
  var row=record.duplicate(true);var at:Vector2=Tour.Regions.frame("east_gate").inverse()*(Vector2(record.cell[0],record.cell[1])*3.);var p=Vector3(at.x,game.model.surface_height(at.x,at.y),at.y);row.local_point=var_to_str(p);row.world_point=var_to_str(p*game.model.falan_scale);row.terrain_contains=game.model.terrain.contains(p.x,p.z);row.disk_clear12=game.model.terrain.disk_clear(p,1.2);row.disk_clear125=game.model.terrain.disk_clear(p+Vector3.UP*.1,1.25);row.protected_links=[];row.obstacles=[]
  for link in game.model.get_meta("falan_links",[]):
   if at.distance_squared_to(link.at)<pow(1.25+1.35,2):row.protected_links.append({"distance":at.distance_to(link.at),"link":var_to_str(link)})
  var cell:Vector2i=game.model.cell_of(p);var bounds=AABB(p-Vector3(1.25,0,1.25),Vector3(2.5,1.2,2.5))
  for x in range(cell.x-1,cell.x+2):
   for y in range(cell.y-1,cell.y+2):
    for anchor in game.model.scenery_cells.get(Vector2i(x,y),[]):
     var box:AABB=game.model.scenery_obstacles[anchor]
     if box.intersects(bounds):row.obstacles.append({"cell":var_to_str(anchor),"box":var_to_str(box)})
  row.first_reject="terrain-disk"if not row.disk_clear125 else"protected-link"if not row.protected_links.is_empty()else"scenery-obstacle"if not row.obstacles.is_empty()else"none";row.private_visual_hold=not row.protected_links.is_empty();rows.append(row)
 check(rows.size()==13,"Diagnosed all13confirmed source placements without changing filters")
 var changed=[]
 for path in hashes:
  if FileAccess.get_sha256(path)!=hashes[path]:changed.append(path)
 check(changed.is_empty(),"Source inputs unchanged during13-row diagnosis")
 var f=FileAccess.open(DEST+"diagnosis.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":errors,"source_changed":changed,"source_hashes":hashes,"records":rows,"scope":"Actual current model queries only. No props were added and no filter, Native navigation, route, terrain or production input changed."},"  "));f.close();print("EAST13_DIAGNOSIS checks=",checks," failures=",errors);await finish()
