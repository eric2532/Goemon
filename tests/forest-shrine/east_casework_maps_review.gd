extends "res://tests/forest-shrine/east_landmark_review.gd"
## Native placement census plus actual-source room batches and gameplay camera pairs.
const Furniture=preload("res://scripts/forest/forest_east_room_casework.gd")
const Counters=preload("res://scripts/forest/forest_east_room_counters.gd")
const LIVE_IDS=[10430,10431,10438,10440,10492,10567,16014,16016,16017,16020,16021,17008,17010,17011,17542,17547,16876,16878,16879,16881,16882,16883,16884]
const ROOM_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Room Casework/Actual Rooms/"
var census={}
func review_path()->String:return ROOM_OUT
func site_owned(_source:int,serial:int)->bool:return serial in LIVE_IDS
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Furniture.mesh(serial,g) if Furniture.owns(serial) else Counters.mesh(serial,g)
func site_visible(serial:int,g:Dictionary)->Array:return Furniture.data().graphics[str(serial)].bounds
func source_census_path()->String:return ROOM_OUT+"native-placements.json"
func fixture_source_paths()->Array:return ["tests/forest-shrine/east_casework_maps_review.gd","scripts/forest/forest_original_map_art.gd","scripts/forest/forest_east_room_casework.gd","scripts/forest/forest_east_room_counters.gd","scripts/forest/forest_east_mounted_details.gd","scripts/camera.gd","scripts/forest/forest_original_water_camera.gd","assets/maps/falan/east_region/room_casework/data.json","assets/maps/falan/east_region/mounted_details/data.json","assets/maps/falan/east_region/mounted_details/10567-front.png","assets/maps/falan/east_region/mounted_details/10567-back.png"]
func fixture_scope()->String:return "Full source census for23 exact published casework/plinth appearances,137 placements in67 fixed maps; ten actual source placements in nine rooms with immutable batch/count checks and original-walk gameplay cameras. Does not certify other room art or source event behavior."
func fixture_sites()->Array:
 return [
  [43140,10430,Vector2i(36,35),"goral-low-cabinet",Vector2i(35,36),Vector2i(36,37)],
  [33297,10431,Vector2i(14,21),"native-open-hutch",Vector2i(11,22),Vector2i(16,22)],
  [43900,10438,Vector2i(45,12),"native-empty-shelf",Vector2i(44,14),Vector2i(47,14)],
  [33510,10440,Vector2i(30,17),"covered-side-cabinet",Vector2i(28,18),Vector2i(30,18)],
  [32280,10567,Vector2i(7,9),"native-wall-clock",Vector2i(6,11),Vector2i(9,11)],
  [32280,17010,Vector2i(7,13),"native-dresser-mirror",Vector2i(6,15),Vector2i(9,15)],
  [43172,16014,Vector2i(11,10),"native-narrow-drawers",Vector2i(10,12),Vector2i(13,12)],
  [37001,16016,Vector2i(31,35),"native-closed-wardrobe",Vector2i(30,36),Vector2i(31,36)],
  [32089,17547,Vector2i(23,27),"native-reversed-empty-shelf",Vector2i(22,28),Vector2i(25,28)],
  [31959,16878,Vector2i(65,7),"native-plinth-row",Vector2i(63,9),Vector2i(67,9)],
 ]
func run():
 var output=review_path()
 var hashes=Sources.snapshot(review_source_paths()+fixture_source_paths()+[source_census_path()])
 root.size=Vector2i(1440,900);root.title="Cross Gate · Native Room Placements"
 Maps.Art.load_east()
 var expected=JSON.parse_string(FileAccess.get_file_as_string(source_census_path()))
 for token in expected.counts:
  var source=int(token);var id=Maps.runtime_id(source);var row=Maps.state(id);var aliases:Dictionary=Maps.Art.data().maps[Maps.path_for(id)].get("graphic_aliases",{})
  var counts={};var cells:int=row.size.x*row.size.y
  for i in cells:
   var native=int(row.raw.decode_u16(20+(cells+i)*2));var serial=int(aliases.get(str(native),native))
   if not site_owned(source,serial):continue
   var key=str(serial);counts[key]=int(counts.get(key,0))+1
  var wanted={}
  for serial in expected.counts[token]:wanted[str(serial)]=int(expected.counts[token][serial])
  check(counts==wanted,"Full original source placement census "+token)
  census[token]=counts
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-fixtures-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false
 game.tuning.invincible=true;game.player.set_auto_attack(false);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 for site in fixture_sites():
  var id=Maps.runtime_id(int(site[0]));var before_bits=Maps.state(id).bits.duplicate();var before_links=Maps.links(id).duplicate(true)
  await landmark(site)
  verify_batches(int(site[0]))
  check(Maps.state(id).bits==before_bits and Maps.links(id)==before_links,"Original walk cells and connection records unchanged "+str(site[0]))
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Loaded room-owner sources remain current through the capture")
 var file=FileAccess.open(output+"review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"census":census,"observations":observations,"captures":captures,"metrics":metrics,"source_hashes":hashes,"source_changed_during_run":changed,"scope":fixture_scope()},"  "));file.close()
 print("EAST_CASEWORK_MAPS_RESULT checks=",checks," failures=",errors," captures=",captures.size());await finish()
func verify_batches(source:int):
 var actual={}
 for batch:MultiMeshInstance3D in game.world.find_children("RecoveredShalenaSolid_*","MultiMeshInstance3D",true,false):
  var serial=int(batch.get_meta("source_graphic",0))
  if not site_owned(source,serial):continue
  var key=str(serial);actual[key]=int(actual.get(key,0))+batch.multimesh.instance_count
  check(batch.multimesh.mesh==site_mesh(source,serial,Maps.Art.data().graphics[key]),"Actual source room uses immutable fixture owner "+str(source)+":"+key)
 check(actual==census[str(source)],"All original furniture/column placements are retained in scene "+str(source))
 observations.append({"source":source,"expected_source_counts":census[str(source)],"actual_scene_counts":actual})
