extends "res://tests/forest-shrine/east_classic_architecture_review.gd"
const Doors=preload("res://scripts/forest/forest_east_architecture_doors.gd")
const DOOR_ROOT="res://assets/maps/falan/east_region/classic_architecture/doors/"
var door_meshes:Dictionary={}
func run():
 root.size=Vector2i(1200,900);source_graphics=JSON.parse_string(FileAccess.get_file_as_string(DOOR_ROOT+"data.json")).graphics
 var paths=["tests/forest-shrine/east_architecture_doors_review.gd","tests/forest-shrine/east_classic_architecture_review.gd","scripts/forest/forest_east_architecture_doors.gd","scripts/forest/forest_coastal_mesh.gd","scripts/forest/forest_falan_building_shapes.gd","assets/maps/original_crossgate/building-surfaces.png","assets/maps/falan/east_region/classic_architecture/doors/data.json"]
 for token:String in source_graphics:
  for suffix in [".png","-front.png"]:paths.append(DOOR_ROOT.trim_prefix("res://")+token+suffix)
 var before=Sources.snapshot(paths);Maps.Art.load_east();await source_models();var changed=Sources.changed(before)
 check(changed.is_empty(),"Loaded native door sources remain current through capture")
 var file=FileAccess.open(ARCH_OUT+"doors-source-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"mesh_audit":mesh_audit,"source_hashes":before,"source_changed_during_run":changed,"scope":"Three exact closed native door candidates; source checks do not establish actual-map or visual acceptance."},"  "));file.close()
 print("EAST_ARCHITECTURE_DOORS_RESULT checks=",checks," failures=",errors," meshes=",mesh_audit.size());quit(1 if errors else 0)
func prepared_source(serial:int)->Mesh:
 if not door_meshes.has(serial):door_meshes[serial]=Doors.mesh(source_graphics[str(serial)],load(DOOR_ROOT+str(serial)+"-front.png"))
 return door_meshes[serial]
