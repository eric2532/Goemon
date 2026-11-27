extends SceneTree
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const Dungeons=preload("res://scripts/forest/forest_freyja_dungeons.gd")
const Sources=preload("res://tests/forest-shrine/east_review_sources.gd")
func _initialize():
 create_timer(90,true,false,true).timeout.connect(func():printerr("ROOFLESS_CONTRACT_TIMEOUT");quit(2))
 run.call_deferred()
func run():
 var hashes=Sources.snapshot([get_script().resource_path,"scripts/forest/forest_original_maps.gd","scripts/forest/forest_freyja_dungeons.gd","assets/maps/original_crossgate/catalog.json","assets/maps/original_crossgate/east/catalog.json"])
 Maps.Art.load_east()
 var changed=[];var checks=0
 for source in Maps.EastIndex.FIXED:
  var id=Maps.runtime_id(int(source));var path=Maps.path_for(id);var row:Dictionary=Maps.Art.data().maps.get(path,{})
  if row.get("east_existing_owner",false):continue
  var bits=Maps.state(id).bits.duplicate();var links=Maps.links(id).duplicate(true)
  var prior=Maps.owns(id)and not Maps.outdoor(id)and not(id>=59500 and id<59800)
  var inferred=bool(row.get("inferred_roofless",false))
  assert(Maps.cave(id)==(prior and not inferred),"Only declared roofless inference may alter roof contract")
  assert(Dungeons.roofed(id)==Maps.cave(id),"World ceiling owner follows recovered roof contract")
  assert(Maps.state(id).bits==bits and Maps.links(id)==links,"Roof inference preserves walk/connection data")
  checks+=3
  if prior!=Maps.cave(id):changed.append(int(source))
 changed.sort()
 var expected=[11031,11039,11040,32094,32095,32096,32097,32098,32099,32153,32158,32159,34012]
 if changed!=expected:printerr("Unexpected roof contract changes ",changed);quit(1);return
 var stale=Sources.changed(hashes)
 if not stale.is_empty():printerr("Roof sources changed ",stale);quit(1);return
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/East Gate Region/Verification/roofless-contract.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks+2,"failures":0,"changed_roof_contracts":changed,"source_hashes":hashes,"source_changed_during_run":stale,"scope":"Honor13existing rooflessness inferences; all owned East fixed-map walk/links and outdoor classification retained. Rendered physical ceiling absence is a separate actual-map check."},"  "));file.close()
 print("EAST_ROOFLESS_CONTRACT_RESULT checks=",checks+2," failures=0 changed=",changed);quit()
