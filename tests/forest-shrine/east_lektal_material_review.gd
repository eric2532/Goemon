extends "res://tests/forest-shrine/east_lektal_annexes_review.gd"
## Material-only source/reverse studies; the372native/player/pet gate stays historical.
func run():
 root.size=Vector2i(1200,900);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ANNEX_OUT))
 var paths=["tests/forest-shrine/east_lektal_material_review.gd","tests/forest-shrine/east_lektal_annexes_review.gd","scripts/forest/forest_east_lektal_annexes.gd","scripts/forest/forest_coastal_mesh.gd","assets/maps/falan/east_region/lektal_annexes/data.json","assets/maps/falan/east_region/lektal_annexes/surfaces.png","assets/maps/falan/east_region/lektal_annexes/1233256.png","assets/maps/falan/east_region/lektal_annexes/1233257.png"]
 var before=Sources.snapshot(paths);await source_views();var changed=Sources.changed(before)
 check(changed.is_empty(),"Material-only loaded sources remain current through asset capture")
 var file=FileAccess.open(ANNEX_OUT+"material-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"mesh_audit":mesh_audit,"source_hashes":before,"source_changed_during_run":changed,"wood_sample":Annexes.data().tile_samples.wood,"scope":"Material-only source/reverse images of the two frozen annex meshes.372native/player/pet assertions retain their earlier exact source snapshot; geometry/support/front PNG are unchanged. Images require independent visual judgment."},"  "));file.close()
 print("EAST_LEKTAL_MATERIAL_RESULT checks=",checks," failures=",errors," meshes=",mesh_audit.size())
 quit(1 if errors else 0)
