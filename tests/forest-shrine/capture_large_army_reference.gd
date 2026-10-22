extends SceneTree
func _initialize():run.call_deferred()
func run():
 var fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
 await fixture.make_game("original")
 var reference={"input_map":fixture.input_map(),"protected_hashes":fixture.protected_hashes(),"players":{},"allies":{}}
 for id in range(1,19):
  reference.players[str(id)]=await fixture.trace_player(id,[])
 for kit in [5,7,8,10,11]:reference.allies[str(kit)]=await fixture.trace_ally(kit,"opening")
 var path="res://tests/forest-shrine/fixtures/large_army_reference.json"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(reference,"\t"))
 await fixture.close();fixture.queue_free();await process_frame
 print("LARGE_ARMY_REFERENCE_CAPTURED");quit()
