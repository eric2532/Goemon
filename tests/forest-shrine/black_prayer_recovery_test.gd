extends "res://tests/forest-shrine/falan_landmarks_test.gd"
const RUBY_REVIEW="res://build/Other Files/Asset Toolkit/Ruby Dungeon Recovery/"
func review_folder()->String:return RUBY_REVIEW
func shot(name_:String,eye:Vector3,target:Vector3,fov:float,refresh_army:bool=false):
 await super.shot(name_.replace("/","-"),eye,target,fov,refresh_army)
func check_east_il_road():
 game.tuning.invincible=true
 game.settings.forest_level_up_cards=false
 var saved=JSON.stringify(get_meta("falan_venture"))
 await check_ruby_boss()
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Recovery preserves the user's saved adventure")
 print("BLACK_PRAYER_RECOVERY_RESULT checks=",checks," failures=",errors)

func approach_black_prayer():
 await open_area("sokia_coast")
 await site(15004,"interior")
