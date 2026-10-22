@static_unload
extends "res://scripts/forest/forest_kai_terrain.gd"
## The recovered canyon uses the same triangulated ground for paths and physics.
const BLOOD_GULCH_FIELD_PATH="res://assets/maps/blood_gulch/surface.res"
static var blood_gulch_field:Resource
var horizontal_scale=1.0
func configure(source:Array):
 super.configure(source)
 spacing*=horizontal_scale
func coordinate(x:float,z:float)->Vector2:
 return Vector2(x+240*horizontal_scale,z+240*horizontal_scale)/spacing
func terrain_field()->Resource:
 if blood_gulch_field==null and ResourceLoader.exists(BLOOD_GULCH_FIELD_PATH):blood_gulch_field=load(BLOOD_GULCH_FIELD_PATH)
 return blood_gulch_field
