extends "res://tests/forest-shrine/original_maps_test.gd"

func run():
 var army=load("res://scripts/forest/crowd/army_runtime.gd").new();army.configure(null)
 var data={"width":0,"bounds_min":Vector3(-3,0,-12),"bounds_max":Vector3(3,0,12),"obstacle_min":PackedVector3Array([Vector3(-3,0,-1)]),"obstacle_max":PackedVector3Array([Vector3(3,10,1)]),"friendly_navigation":true,"friendly_obstacle_min":PackedVector3Array(),"friendly_obstacle_max":PackedVector3Array()}
 army.set_navigation(1,data)
 var from=Vector3(0,0,-4);var to=Vector3(0,0,5)
 check(not army.native.can_reach(from,to,.55),"Protected village edge still blocks enemies")
 check(army.native.can_reach_ally(from,to,.55),"Player station uses the existing friendly route through the protected village edge")
 check(not army.native.can_reach_ally(from,to,-1.) and not army.native.can_reach_ally(Vector3.INF,to,.55),"Friendly query rejects invalid radius and origin")
 data.friendly_obstacle_min=data.obstacle_min;data.friendly_obstacle_max=data.obstacle_max
 army.set_navigation(2,data)
 check(not army.native.can_reach_ally(from,to,.55),"Real walls still block the player station query")
 data.friendly_obstacle_min=PackedVector3Array([Vector3(-3,0,-1),Vector3(2,0,-1)])
 data.friendly_obstacle_max=PackedVector3Array([Vector3(-2,10,1),Vector3(3,10,1)])
 army.set_navigation(3,data)
 check(army.native.can_reach_ally(from,to,.55),"A physical doorway restores the friendly path without opening the enemy boundary")
 check(not army.native.can_reach(from,to,.55),"Friendly query leaves enemy navigation unchanged")
 army.clear();army.free()
 print("EXPLORE_PLAYER_REACH_RESULT checks=",checks," failures=",failures)
 finish()
