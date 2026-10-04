class_name DefenseBarracks
extends DefenseKennel

# The two rosters share lifecycle rules but own independent slots and cooldowns.
const MAX_HEROES=8
const HERO_CATALOG_PATH="res://scripts/defense_hero_catalog.gd"
const Hero=preload("res://scripts/defense_hero.gd")
var heroes: Array:
	get:return dogs

func definitions()->Array:
	return load(HERO_CATALOG_PATH).definitions()

func get_profile(id: String)->Dictionary:
	return load(HERO_CATALOG_PATH).get_hero(id)

func capacity()->int:return MAX_HEROES
func make_actor():return Hero.new()
func full_message()->String:return "Your company is full · 8 heroes."

func spawn_position(index: int)->Vector3:
	var origin=Vector3(0,.15,203)
	var authored=game.world.get("hero_spawn_position")
	if authored is Vector3:origin=authored
	return origin+Vector3((float(index%4)-1.5)*1.8,0,float(index/4)*2.7)
