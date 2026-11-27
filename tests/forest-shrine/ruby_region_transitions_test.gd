extends "res://tests/forest-shrine/black_prayer_recovery_test.gd"
## Focused crossings, not a repeat of the continuous road walkthrough.
const REGION_REVIEW="res://build/Other Files/Asset Toolkit/Ruby Region Reconstruction/Transitions/"
func review_folder()->String:return REGION_REVIEW
func _initialize():
 create_timer(900).timeout.connect(func():printerr("RUBY_REGION_TRANSITIONS_TIMEOUT");quit(1))
 run.call_deferred()

func approach_black_prayer():
 await open_area("sokia_coast")
 await site(15004,"interior")
 check(game.model.falan_floor==15004,"The coast mouth enters the Sokia-side first floor")
 await room(15003)
 check(game.model.falan_floor==15003,"The coast branch reaches the actual Suspicious Rock room")

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 var saved=JSON.stringify(get_meta("falan_venture"))
 await open_area("south_lakes")
 await site(2100,"venoa")
 check(Tour.area(game.model)=="venoa","Venoa's original road entry still works")
 await leave_village("south_lakes")
 await site(15005,"interior")
 check(game.model.falan_floor==15005,"The Southern Lakes mouth enters Freyja-side 1F")
 await room(15003);await room(15004);await cave_exit("sokia_coast")
 check(Tour.area(game.model)=="sokia_coast","The three-room cave still reaches the coast exit")
 var regions=Tour.Regions
 await walk_habaru_threshold(regions.KILI_GATE+regions.KILI_TO_ROAD,Vector2.DOWN)
 check(Tour.area(game.model)=="kili","The coastal west gate still enters Kili")
 await walk_habaru_threshold(regions.KILI_EAST_GATE,Vector2.RIGHT)
 check(Tour.area(game.model)=="sokia_coast","Kili's east gate still exits to the coast")
 await walk_habaru_threshold(regions.KILI_EAST_GATE+regions.KILI_TO_ROAD,Vector2.LEFT)
 check(Tour.area(game.model)=="kili","Kili's east gate still returns to the village")
 await walk_habaru_threshold(regions.KILI_GATE,Vector2.UP)
 check(Tour.area(game.model)=="sokia_coast","Kili's west gate still returns to the original road")
 await check_ruby_boss()
 check(get_meta(Ruby.SLAIN,{}).size()==10,"The focused check actually defeated Ruby and all nine escorts")
 check(Tour.area(game.model)=="sokia_coast","Ruby's unlocked post-fight route still returns outside")
 check(JSON.stringify(get_meta("falan_venture"))==saved,"The region review preserves the saved adventure")
 print("RUBY_REGION_TRANSITIONS_RESULT checks=",checks," failures=",errors)
