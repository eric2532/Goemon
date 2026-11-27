extends RefCounted
## Prepared derivatives retain every source floor vertex, UV and material.
const ROOT="res://assets/maps/falan/east_region/ground/"
const INPUTS=["res://scripts/forest/forest_east_ground_motifs.gd","res://assets/maps/falan/east_region/ground_motifs/data.json","res://scripts/forest/forest_painterly_environment.gd","res://scripts/forest/forest_painterly_surface.gdshader","res://scripts/forest/forest_east_region_art.gd","res://assets/maps/falan/east_region/landmarks/profiles.json","res://scripts/geo.gd","res://assets/maps/original_crossgate/catalog.json","res://assets/maps/falan/sokia/fixed/catalog.json","res://assets/maps/original_crossgate/university/catalog.json","res://assets/maps/original_crossgate/elsa/catalog.json","res://assets/maps/original_crossgate/east/catalog.json","res://scripts/forest/forest_original_map_art.gd","res://scripts/forest/forest_original_maps.gd","res://scripts/forest/forest_original_map_solids.gd","res://scripts/forest/forest_coastal_mesh.gd"]
static var baking=false

static func signature()->Dictionary:
 var result={}
 for path in INPUTS:result[path]=FileAccess.get_sha256(path)
 return result

static func instantiate(source:int)->Node3D:
 if baking or source not in [33000,43000]:return null
 var manifest=ROOT+str(source)+".json"
 if not FileAccess.file_exists(manifest):return null
 var record=JSON.parse_string(FileAccess.get_file_as_string(manifest))
 if not record is Dictionary or record.get("inputs",{})!=signature():return null
 if FileAccess.get_sha256(ROOT+str(source)+".scn")!=record.get("scene_sha256",""):return null
 var resource=ResourceLoader.load(ROOT+str(source)+".scn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
 if not resource is PackedScene:return null
 var node:Node3D=resource.instantiate();node.set_meta("source_floor_placements",int(record.floor_placements))
 node.set_meta("source_placements",int(record.source_placements));node.set_meta("plane0_floor_placements",int(record.plane0_floor_placements))
 return node
