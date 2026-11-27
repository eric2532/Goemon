extends "res://tests/forest-shrine/east_region_review.gd"
## The default-null integration must preserve the normal city exit and return.
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
var source_snapshot:Dictionary={}
func run():
 phase="Source Context Default Off"
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Source Context Audit/Prototype/shared-hooks-source.json"))
 var paths:Array=manifest.files.duplicate()
 paths.append_array([get_script().resource_path,"tests/forest-shrine/east_region_review.gd","tests/forest-shrine/freyja_villages_habaru_test.gd","scripts/forest/forest_original_maps.gd","scripts/forest/forest_freyja_terrain.gd","scripts/forest/forest_game.gd"])
 source_snapshot=Fresh.snapshot(paths)
 check(Tour.Regions.private_source_context==null,"The source-context hook defaults to null")
 await super.run()
func baseline_landmarks():
 # This focused integration regression uses the existing normal gate walk;
 # unchanged broad scenery reviews keep their separately pinned evidence.
 pass
func finish():
 check(Tour.Regions.private_source_context==null,"Normal title and gate travel never activates private source scenes")
 for script_path in ["forest_east_source_context_review","forest_east_il_low_source","forest_east_alyut_source_context","forest_east_host_source_context"]:
  check(not ResourceLoader.has_cached("res://scripts/forest/"+script_path+".gd"),"Default travel does not load private script "+script_path)
 var changed=Fresh.changed(source_snapshot);check(changed.is_empty(),"Default gate review used a stable source snapshot")
 var path=REVIEW+phase+"/verification.json";var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 report.checks=checks;report.failures=errors;report.observations=observations;report.source_hashes=source_snapshot;report.source_changed_during_run=changed
 report.scope="Default-null13module hook integration only: actual normal Falan East Gate exit/return, source cells, direction and fixed views. Private scripts remain unloaded. No active private source scene, whole-region route or art completion claim."
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("EAST_SOURCE_CONTEXT_DEFAULT_GATE checks=",checks," failures=",errors)
 await super.finish()
