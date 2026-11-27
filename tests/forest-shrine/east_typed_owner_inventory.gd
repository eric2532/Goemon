extends SceneTree
## Read-only routed type inventory; this does not claim an existing owner is visually correct.
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Maps=preload("res://scripts/forest/forest_original_maps.gd")
const OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/"
func _initialize():run.call_deferred()
func run():
 East.Art.load_east();var input=JSON.parse_string(FileAccess.get_file_as_string(OUT+"object-contexts.json"));var typed=[];var candidates=[];var families={};var early=[];var failures=[]
 for token in input.graphics:
  var serial=int(token);var context:Dictionary=input.graphics[token]
  if serial<1000 or context.get("generated_ground_only",false):continue
  if not East.Art.data().graphics.has(token):failures.append(token);continue
  var g:Dictionary=East.Art.data().graphics[token];var owner=""
  if East.owns(0,serial):owner="EastArt"
  elif Maps.EastRuins.owns(serial):owner="EastRuins"
  elif Maps.EastColumns.owns(serial):owner="EastColumns"
  elif Maps.EastAnnexes.owns(serial):owner="EastAnnexes"
  if owner!="":early.append({"graphic":serial,"owner":owner});continue
  var family=Forms.kind(serial,false,g)
  if family=="prop":continue
  var row:Dictionary=context.duplicate(true);row.family=family;row.pixels=[g.rect[2],g.rect[3]];row.origin=g.origin;row.footprint=g.footprint;row.source_rgba_sha256=g.rgba_sha256;row.source_height=Forms.source_height(g)
  row.tall_object_ground=family=="floor" and float(g.rect[3])>float(g.rect[2])*.85
  row.large=family!="floor" and (float(g.rect[3])>=128. or maxf(float(g.footprint[0]),float(g.footprint[1]))>=3. or float(row.source_height)>=3.)
  row.review_candidate=row.tall_object_ground or row.large or family in ["door","gate","arch","room_wall","wall","cave","cave_mouth","cliff","coast_cliff"]
  typed.append(row);families[family]=int(families.get(family,0))+1
  if row.review_candidate:candidates.append(row)
 var file=FileAccess.open(OUT+"typed-owner-inventory.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"typed_graphics":typed,"candidate_graphics":candidates,"families":families,"early_explicit_owners":early,"failures":failures,"source_forms_sha256":FileAccess.get_sha256("res://scripts/forest/forest_original_map_solids.gd"),"source_catalog_sha256":FileAccess.get_sha256("res://assets/maps/original_crossgate/east/catalog.json"),"scope":"Read-only actual Forms.kind classifications for all reached object/dependency graphics, excluding current explicit East early owners. A typed owner or small-size filter does not certify the visual. Large/tall hybrid/structural source references require native-contact and recipe review."},"  "));file.close()
 print("EAST_TYPED_OWNER_INVENTORY typed=",typed.size()," review_candidates=",candidates.size()," families=",families.size()," failures=",failures.size());quit(failures.size())
