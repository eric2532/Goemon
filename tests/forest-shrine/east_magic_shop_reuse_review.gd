extends "res://tests/forest-shrine/east_classic_architecture_review.gd"
const MAGIC_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Classic Architecture/Magic Shop Reuse/Focused Actual/"
const MAGIC_SITES=[[32276,10075,Vector2i(166,99),"hanako-native-magic-shop",Vector2i(160,96),Vector2i(173,96)],[32277,10075,Vector2i(56,42),"aki-native-magic-shop",Vector2i(50,39),Vector2i(63,39)]]
func review_path()->String:return MAGIC_OUT
func site_owned(_source:int,serial:int)->bool:return serial==10075 and Architecture.owns(serial)
func site_mesh(_source:int,serial:int,g:Dictionary)->Mesh:return Architecture.mesh(serial,g)
func site_visible(serial:int,_g:Dictionary)->Array:return Architecture.data().graphics[str(serial)].visible
func review_source_paths()->Array:
 var paths=super.review_source_paths()
 paths.append_array(["scripts/forest/forest_east_classic_architecture.gd","scripts/forest/forest_falan_magic_shop.gd","scripts/forest/forest_falan_proportions.gd","assets/maps/falan/east_region/classic_architecture/data.json","assets/maps/falan/east_region/classic_architecture/profiles.json","assets/maps/falan/east_region/classic_architecture/10075.png"])
 return paths

func run():
 root.size=Vector2i(1440,900);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAGIC_OUT))
 var before=Sources.snapshot(review_source_paths());Maps.Art.load_east()
 source_graphics={"10075":Architecture.data().graphics["10075"]};await source_models()
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-magic-shop-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.model.team_progression.cards_enabled=false
 game.tuning.invincible=true;game.player.set_auto_attack(false);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 for site:Array in MAGIC_SITES:
  var state=Maps.state(Maps.runtime_id(site[0]));var bits:PackedByteArray=state.bits.duplicate()
  await landmark(site);await original_contract(site)
  check(state.bits==bits,"Whole-model reuse preserves every original walk bit "+str(site[0]))
 var changed=Sources.changed(before);check(changed.is_empty(),"Loaded whole-model/source owners stay current through both actual maps")
 var file=FileAccess.open(MAGIC_OUT+"review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"observations":observations,"captures":captures,"source_mesh_audit":mesh_audit,"source_hashes":before,"source_changed_during_run":changed,"scope":"Exact10075complete existing Magic Shop reuse at two original restored placements; native-source plus ordinary/second actual images and source-walk/nav checks. The drawings do not create a new entrance or any new route. Images require independent visual judgment."},"  "));file.close()
 print("EAST_MAGIC_SHOP_REUSE_RESULT checks=",checks," failures=",errors," captures=",captures.size())
 await finish()

func original_contract(site:Array):
 var id=Maps.runtime_id(site[0]);var state=Maps.state(id);var anchor=Maps.source_point(id,site[2]);var cells=state.size.x*state.size.y;var count=0;var batches=0
 var native:Dictionary=Maps.Art.data().graphics["10075"]
 check(Vector2i(native.footprint[0],native.footprint[1])==Vector2i(7,7) and Vector2i(native.origin[0],native.origin[1])==Vector2i(-216,-509),"Native7x7footprint and signed source origin remain exact "+str(site[0]))
 for index in cells:
  if state.raw.decode_u16(20+(cells+index)*2)==10075:
   count+=1;var local_cell=Vector2i(index%state.size.x,index/state.size.x)
   check(local_cell+Maps.crop(id).position==site[2],"Original object-plane castle anchor remains exact "+str(site[0]))
 check(count==1,"One exact original castle drawing is retained on this source map")
 for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
  if int(node.get_meta("source_graphic",0))!=10075:continue
  batches+=node.multimesh.instance_count
  check(node.multimesh.mesh==Architecture.mesh(10075,native),"Actual10075batch uses the complete existing master owner")
  for index in node.multimesh.instance_count:
   var pose=node.global_transform*node.multimesh.get_instance_transform(index)
   check(pose.origin.distance_to(game.model.world_point(anchor))<.01,"Native source anchor receives no cityNPC offset "+str(site[0]))
   check(pose.basis.get_scale().distance_to(Vector3.ONE*game.model.falan_scale)<.01,"Caller applies no second height fit "+str(site[0]))
 check(batches==1,"The mistaken tree family creates no duplicate10075owner")
 var open_count=0;var failures=[]
 for z in range(-9,3):
  for x in range(-2,9):
   var source_cell:Vector2i=site[2]+Vector2i(x,z);var local=source_cell-Maps.crop(id).position
   if not Maps.open(state.bits,state.size,local) or not camera_component.has(local):continue
   open_count+=1;var at=game.model.world_point(Maps.point(id,local))
   if not game.army_runtime.native.ally_ground_clear(at,.25):failures.append([source_cell.x,source_cell.y])
 check(open_count>0,"Original-open walk cells surround the native building")
 check(failures.is_empty(),"Source-open nearby centers retain native clearance "+str(failures))
 check(game.army_runtime.native.can_reach(game.player.position,game.player.position,.35),"The final actual gameplay eye is native-clear")
 observations.append({"source":site[0],"anchor_cell":[site[2].x,site[2].y],"native_origin":native.origin,"native_footprint":native.footprint,"source_rgba_sha256":native.rgba_sha256,"source_object_count":count,"actual_instances":batches,"nearby_original_open_centers":open_count,"native_clearance_failures":failures,"fixed_magic_shop_door_claimed":false,"geometry_reuse":"Complete existing forest_falan_magic_shop.prepare; original Source origin fit once, final.045owner frame"})
