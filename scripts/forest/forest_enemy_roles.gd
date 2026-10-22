extends RefCounted
## Simulation roles use the exported world dimensions, independent of wave number.
const PATHS=["res://assets/characters/thirstquencher/soldier_1.glb","res://assets/characters/thirstquencher/soldier_2.glb","res://assets/models/enemies/forest_redesign_v02/daruma_breaker.glb","res://assets/characters/thirstquencher/soldier_3.glb"]
const BOSS=4
const COUNT=5
const BOSS_SIZE=Vector3(8,11,7)
const HEIGHTS=[6.048,6.048,23.10,6.048,11.0]
const RADII=[3.9,3.9,8.5,3.9,5.35]
const DATA=[
	{"hp":64.0,"speed":4.32,"damage":11.0,"windup":13.0/30,"recovery":7.0/30,"range":7.5,"turn_speed":5.0,"stride":6.912},
	{"hp":80.0,"speed":2.16,"damage":25.0,"windup":18.0/30,"recovery":12.0/30,"range":24.0,"turn_speed":4.0,"stride":4.32},
	{"hp":3000.0,"speed":.75,"damage":120.0,"windup":1.5,"recovery":3.5,"range":10.0,"turn_speed":.45,"stride":3.0},
	{"hp":72.0,"speed":4.32,"damage":11.0,"windup":13.0/30,"recovery":7.0/30,"range":7.5,"turn_speed":7.0,"stride":6.912},
	{"hp":24000.0,"speed":1.5,"damage":90.0,"windup":1.2,"recovery":2.0,"range":7.0,"turn_speed":1.5,"stride":2.0}]
static func stats(variant: int)->Dictionary:return DATA[clampi(variant,0,COUNT-1)].duplicate()
static func asset_path(variant: int)->String:return "" if variant==BOSS else PATHS[clampi(variant,0,3)]
static func height(variant: int)->float:return HEIGHTS[clampi(variant,0,COUNT-1)]
static func footprint_radius(variant: int)->float:return RADII[clampi(variant,0,COUNT-1)]
static func hurt_point(enemy: Dictionary,from: Vector3)->Vector3:
	return preload("res://scripts/forest/forest_enemy_contact.gd").contact(enemy,from)

static func visibility_radius(variant: int)->float:return 14.0 if variant==2 else footprint_radius(variant)
