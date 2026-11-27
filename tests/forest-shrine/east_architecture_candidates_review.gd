extends "res://tests/forest-shrine/east_classic_architecture_review.gd"
## Consolidated private studies replace three waiting source-only jobs.
const Posts=preload("res://scripts/forest/forest_east_architecture_posts.gd")
const Doors=preload("res://scripts/forest/forest_east_architecture_doors.gd")
const BrokenWalls=preload("res://scripts/forest/forest_east_broken_wall_forms.gd")
var candidate_meshes:Dictionary={}
var candidate_roots:Dictionary={}
func run():
 root.size=Vector2i(1200,900);Maps.Art.load_east()
 var paths=review_source_paths()+["tests/forest-shrine/east_classic_architecture_review.gd","scripts/forest/forest_east_classic_architecture.gd","scripts/forest/forest_east_architecture_sections.gd","scripts/forest/forest_east_architecture_posts.gd","scripts/forest/forest_east_architecture_doors.gd","scripts/forest/forest_east_broken_wall_forms.gd","scripts/forest/forest_falan_lamps.gd","scripts/forest/forest_coastal_buildings.gd","scripts/forest/forest_falan_building_shapes.gd","scripts/forest/forest_falan_magic_shop.gd","scripts/forest/forest_falan_proportions.gd","assets/maps/original_crossgate/building-surfaces.png","assets/maps/falan/east_region/classic_architecture/data.json","assets/maps/falan/east_region/classic_architecture/profiles.json"]
 var roots=[Architecture.ROOT+"broken_walls/",Architecture.ROOT+"posts/",Architecture.ROOT+"doors/",Architecture.ROOT+"sections/",Architecture.ROOT]
 for source_root:String in roots:
  var catalog_path=source_root+"data.json";paths.append(catalog_path)
  var rows:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(catalog_path)).graphics
  for token:String in rows:
   if source_root==Architecture.ROOT and int(token) not in [10075,17502,17503]:continue
   if source_root.ends_with("sections/") and int(token) not in [15804,15851,16970]:continue
   source_graphics[token]=rows[token];candidate_roots[int(token)]=source_root
   for suffix in [".png","-front.png","-surfaces.png","-ground.png"]:
    var path=source_root+token+suffix
    if FileAccess.file_exists(path):paths.append(path)
 var before=Sources.snapshot(paths);await source_models();var changed=Sources.changed(before)
 check(changed.is_empty(),"Consolidated candidate sources remain current through source/reverse capture")
 var counts={}
 for token:String in source_graphics:
  var family:String=source_graphics[token].kit;counts[family]=counts.get(family,0)+1
 var file=FileAccess.open(ARCH_OUT+"consolidated-candidates-source-review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"family_counts":counts,"mesh_audit":mesh_audit,"source_hashes":before,"source_changed_during_run":changed,"scope":"Private source/reverse candidates:20native broken walls,12posts,3closed doors,3current wall-material representatives and existing MagicShop/two round columns. No additional runtime dispatch or visual acceptance inferred."},"  "));file.close()
 print("EAST_ARCHITECTURE_CANDIDATES_RESULT checks=",checks," failures=",errors," meshes=",mesh_audit.size())
 quit(1 if errors else 0)
func prepared_source(serial:int)->Mesh:
 if candidate_meshes.has(serial):return candidate_meshes[serial]
 var g:Dictionary=source_graphics[str(serial)];var source_root:String=candidate_roots[serial];var mesh:Mesh
 match g.kit:
  "native_broken_wall":mesh=BrokenWalls.mesh(g,load(source_root+str(serial)+"-front.png"),load(source_root+str(serial)+"-ground.png"))
  "native_post":mesh=Posts.mesh(g,load(source_root+str(serial)+"-front.png"),load(source_root+str(serial)+"-surfaces.png"))
  "native_door":mesh=Doors.mesh(g,load(source_root+str(serial)+"-front.png"))
  "native_cap_wall":mesh=Sections.wall(g,load(source_root+str(serial)+"-surfaces.png"),load(source_root+str(serial)+"-front.png"))
  _:mesh=Architecture.mesh(serial,Maps.Art.data().graphics[str(serial)])
 candidate_meshes[serial]=mesh;return mesh
