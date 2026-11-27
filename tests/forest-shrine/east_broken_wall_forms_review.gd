extends "res://tests/forest-shrine/east_classic_architecture_review.gd"
const BrokenWalls=preload("res://scripts/forest/forest_east_broken_wall_forms.gd")
const BROKEN_ROOT="res://assets/maps/falan/east_region/classic_architecture/broken_walls/"
var broken_meshes:Dictionary={}
func run():
 root.size=Vector2i(1200,900);source_graphics=JSON.parse_string(FileAccess.get_file_as_string(BROKEN_ROOT+"data.json")).graphics
 var paths=["tests/forest-shrine/east_broken_wall_forms_review.gd","tests/forest-shrine/east_classic_architecture_review.gd","scripts/forest/forest_east_broken_wall_forms.gd","scripts/forest/forest_east_architecture_sections.gd","scripts/forest/forest_coastal_mesh.gd","assets/maps/original_crossgate/building-surfaces.png",BROKEN_ROOT.trim_prefix("res://")+"data.json"]
 for token:String in source_graphics:
  for suffix in [".png","-front.png","-ground.png"]:paths.append(BROKEN_ROOT.trim_prefix("res://")+token+suffix)
 var before=Sources.snapshot(paths);Maps.Art.load_east();await source_models();var changed=Sources.changed(before)
 check(changed.is_empty(),"Loaded broken-wall source parts stay current through native/reverse capture")
 var file=FileAccess.open(ARCH_OUT+"broken-walls-source-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"mesh_audit":mesh_audit,"source_hashes":before,"source_changed_during_run":changed,"scope":"Twenty exact native wall/arch candidates with closed depth and native open contours; no runtime dispatch, collision or route changes. Source checks do not establish actual-map or visual acceptance."},"  "));file.close()
 print("EAST_BROKEN_WALL_FORMS_RESULT checks=",checks," failures=",errors," meshes=",mesh_audit.size());quit(1 if errors else 0)
func prepared_source(serial:int)->Mesh:
 if not broken_meshes.has(serial):broken_meshes[serial]=BrokenWalls.mesh(source_graphics[str(serial)],load(BROKEN_ROOT+str(serial)+"-front.png"),load(BROKEN_ROOT+str(serial)+"-ground.png"))
 return broken_meshes[serial]
