extends "res://tests/forest-shrine/east_classic_architecture_review.gd"
const Posts=preload("res://scripts/forest/forest_east_architecture_posts.gd")
const POST_ROOT="res://assets/maps/falan/east_region/classic_architecture/posts/"
var post_meshes:Dictionary={}

func run():
 root.size=Vector2i(1200,900);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARCH_OUT))
 source_graphics=JSON.parse_string(FileAccess.get_file_as_string(POST_ROOT+"data.json")).graphics
 var paths=["tests/forest-shrine/east_architecture_posts_review.gd","tests/forest-shrine/east_classic_architecture_review.gd","scripts/forest/forest_east_architecture_posts.gd","scripts/forest/forest_falan_lamps.gd","scripts/forest/forest_coastal_buildings.gd","scripts/forest/forest_coastal_mesh.gd","scripts/forest/forest_falan_proportions.gd","scripts/forest/forest_falan_building_shapes.gd","assets/maps/falan/east_region/classic_architecture/posts/data.json"]
 for token:String in source_graphics:
  for suffix in [".png","-front.png","-surfaces.png"]:paths.append(POST_ROOT.trim_prefix("res://")+token+suffix)
 var before=Sources.snapshot(paths)
 Maps.Art.load_east();await source_models()
 var changed=Sources.changed(before);check(changed.is_empty(),"Loaded post/lamp sources remain current through capture")
 var file=FileAccess.open(ARCH_OUT+"posts-source-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"mesh_audit":mesh_audit,"source_hashes":before,"source_changed_during_run":changed,"scope":"Exact12post/lamp source/reverse candidates; no runtime dispatch. Source checks do not establish actual-map placement or visual acceptance."},"  "));file.close()
 print("EAST_ARCHITECTURE_POSTS_RESULT checks=",checks," failures=",errors," meshes=",mesh_audit.size())
 quit(1 if errors else 0)

func prepared_source(serial:int)->Mesh:
 if not post_meshes.has(serial):post_meshes[serial]=Posts.mesh(source_graphics[str(serial)],load(POST_ROOT+str(serial)+"-front.png"),load(POST_ROOT+str(serial)+"-surfaces.png"))
 return post_meshes[serial]
