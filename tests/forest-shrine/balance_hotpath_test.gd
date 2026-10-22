extends SceneTree
const Balance=preload("res://scripts/character_balance.gd")
const Roster=preload("res://scripts/rogue_roster.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
# Previous implementation is a performance reference only. Literal assertions
# below independently check the gameplay values and live override behavior.
func reference(baseline:Dictionary,id:int,key:String)->float:
	var result=float(baseline.get(key,1.0));var native=Roster.data(id)
	if key=="max_hp":result*=float(native.maxHealth)/100
	elif key in ["walk_speed","sprint_speed"]:result*=float(native.speed)/5.15
	elif key in ["jump_speed","second_jump_speed"] and native.id=="dragoon":result*=sqrt(3)
	elif key in ["jump_speed","second_jump_speed"] and native.id=="ranger":result*=sqrt(2)
	return result
func _initialize():
	var baseline={"walk_speed":10.0,"max_hp":100.0,"jump_speed":20.0,"damage_mult":2.0}
	check(is_equal_approx(Balance.value(baseline,{},5,"walk_speed"),11.3592233),"Ninja keeps its authored movement speed")
	check(is_equal_approx(Balance.value(baseline,{},10,"max_hp"),90.0),"Ranger keeps its authored health ratio")
	check(is_equal_approx(Balance.value(baseline,{},8,"jump_speed"),34.6410162),"Dragoon keeps its authored jump multiplier")
	check(is_equal_approx(Balance.value(baseline,{},10,"jump_speed"),28.2842712),"Ranger keeps its authored jump multiplier")
	check(Balance.value(baseline,{},5,"damage_mult")==2.0,"Native stat scaling does not alter damage")
	var profile={"ninja":{"walk_speed":30.0}}
	check(Balance.value(baseline,profile,5,"walk_speed")==30,"Explicit speed override wins over native scaling")
	profile.ninja.walk_speed=35.0
	check(Balance.value(baseline,profile,5,"walk_speed")==35,"Edited overrides take effect immediately")
	baseline.walk_speed=20.0
	check(is_equal_approx(Balance.value(baseline,{},5,"walk_speed"),22.7184466),"Baseline changes take effect immediately")
	var old_us=9223372036854775807;var new_us=old_us
	var old_sum=0.0;var new_sum=0.0
	for trial in 3:
		var start=Time.get_ticks_usec();old_sum=0
		for i in 30000:old_sum+=reference(baseline,3+i%10,"walk_speed")
		old_us=mini(old_us,Time.get_ticks_usec()-start)
		start=Time.get_ticks_usec();new_sum=0
		for i in 30000:new_sum+=Balance.value(baseline,{},3+i%10,"walk_speed")
		new_us=mini(new_us,Time.get_ticks_usec()-start)
	check(is_equal_approx(old_sum,new_sum),"Army stat reads retain the previous gameplay values")
	check(new_us<old_us*.6,"Repeated army stat reads avoid copying entire class definitions")
	print("BALANCE_HOTPATH_TIMING reference_us=",old_us," optimized_us=",new_us)
	print("BALANCE_HOTPATH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
