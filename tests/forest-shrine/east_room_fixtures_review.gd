extends "res://tests/forest-shrine/east_landmark_review.gd"
## Native placement census plus actual-source room batches and gameplay camera pairs.
const Furniture=preload("res://scripts/forest/forest_east_room_furniture.gd")
const Columns=preload("res://scripts/forest/forest_east_room_columns.gd")
const ROOM_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Room Furniture/Actual Rooms/"
var census={}
func review_path()->String:return ROOM_OUT
func site_owned(_source:int,serial:int)->bool:return Furniture.owns(serial) or Columns.owns(serial)
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Furniture.mesh(serial,g) if Furniture.owns(serial) else Columns.mesh(serial,g)
func site_visible(serial:int,g:Dictionary)->Array:return Furniture.data().graphics[str(serial)].bounds if Furniture.owns(serial) else [0,0,g.rect[2],g.rect[3]]
func run():
 var hashes=Sources.snapshot(review_source_paths()+["scripts/forest/forest_original_map_art.gd","scripts/forest/forest_east_room_furniture.gd","scripts/camera.gd","scripts/forest/forest_original_water_camera.gd","assets/maps/falan/east_region/room_furniture/data.json","assets/maps/falan/east_region/room_columns/data.json"])
 root.size=Vector2i(1440,900);root.title="Cross Gate · Native Room Placements"
 Maps.Art.load_east()
 var expected=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/East Gate Region/Room Furniture/native-placements.json"))
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
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOM_OUT))
 var sites_=[
  [33105,16085,Vector2i(14,10),"guest-room-bookcase",Vector2i(10,15),Vector2i(19,15)],
  [43130,17513,Vector2i(43,54),"dolphin-bar-chair",Vector2i(42,58),Vector2i(48,59)],
  [33265,16631,Vector2i(49,22),"below-deck-hammock",Vector2i(46,28),Vector2i(54,27)],
  [43770,16036,Vector2i(0,0),"lektal-hospital-bed"],
  [43757,1235142,Vector2i(26,12),"dojo-moulded-column",Vector2i(23,17),Vector2i(29,17)],
  [43815,1235156,Vector2i(15,2),"temple-round-column",Vector2i(14,8),Vector2i(20,7)],
 ]
 # Select the source hospital bed, rather than assuming a guessed anchor.
 var hospital=Maps.state(Maps.runtime_id(43770));var hc:int=hospital.size.x*hospital.size.y
 for i in hc:
  if hospital.raw.decode_u16(20+(hc+i)*2)==16036:sites_[3][2]=Vector2i(i%hospital.size.x,i/hospital.size.x);break
 for site in sites_:
  await landmark(site)
  verify_batches(int(site[0]))
 var changed=Sources.changed(hashes);check(changed.is_empty(),"Loaded room-owner sources remain current through the capture")
 var file=FileAccess.open(ROOM_OUT+"review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"census":census,"observations":observations,"captures":captures,"metrics":metrics,"source_hashes":hashes,"source_changed_during_run":changed,"scope":"Full source census for56 exact furniture/column appearances,6167 placements in148 fixed maps; six actual rooms with immutable batch/count checks and original-walk gameplay cameras. Does not certify other room art or source event behavior."},"  "));file.close()
 print("EAST_ROOM_FIXTURES_RESULT checks=",checks," failures=",errors," captures=",captures.size());await finish()
func verify_batches(source:int):
 var actual={}
 for batch:MultiMeshInstance3D in game.world.find_children("RecoveredShalenaSolid_*","MultiMeshInstance3D",true,false):
  var serial=int(batch.get_meta("source_graphic",0))
  if not site_owned(source,serial):continue
  var key=str(serial);actual[key]=int(actual.get(key,0))+batch.multimesh.instance_count
  check(batch.multimesh.mesh==site_mesh(source,serial,Maps.Art.data().graphics[key]),"Actual source room uses immutable fixture owner "+str(source)+":"+key)
 check(actual==census[str(source)],"All original furniture/column placements are retained in scene "+str(source))
 observations.append({"source":source,"expected_source_counts":census[str(source)],"actual_scene_counts":actual})
