extends RefCounted
## Simulation roles use the exported world dimensions, independent of wave number.
const PATHS=["res://assets/models/enemies/forest_redesign_v01/masked_raider.glb","res://assets/models/enemies/forest_redesign_v01/reed_archer.glb","res://assets/models/enemies/forest_redesign_v02/daruma_breaker.glb","res://assets/models/enemies/forest_redesign_v01/lantern_runner.glb"]
const HEIGHTS=[4.62,4.455,23.10,5.115]
const RADII=[.9,.85,8.5,.8]
const DATA=[
	{"hp":300.0,"speed":6.0,"damage":18.0,"windup":.55,"recovery":.85,"range":3.5,"turn_speed":5.0,"stride":1.3},
	{"hp":65.0,"speed":5.0,"damage":20.0,"windup":.75,"recovery":1.6,"range":24.0,"turn_speed":4.0,"stride":1.15},
	{"hp":3000.0,"speed":.75,"damage":120.0,"windup":1.5,"recovery":3.5,"range":10.0,"turn_speed":.45,"stride":3.0},
	{"hp":55.0,"speed":10.0,"damage":15.0,"windup":.4,"recovery":.75,"range":3.0,"turn_speed":7.0,"stride":1.0}]
static func stats(variant: int)->Dictionary:return DATA[clampi(variant,0,3)].duplicate()
static func asset_path(variant: int)->String:return PATHS[clampi(variant,0,3)]
static func height(variant: int)->float:return HEIGHTS[clampi(variant,0,3)]
static func footprint_radius(variant: int)->float:return RADII[clampi(variant,0,3)]
static func hurt_point(enemy: Dictionary,from: Vector3)->Vector3:
	return preload("res://scripts/forest/forest_enemy_contact.gd").contact(enemy,from)

static func visibility_radius(variant: int)->float:return 14.0 if variant==2 else footprint_radius(variant)
