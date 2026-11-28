extends "res://tests/forest-shrine/original_maps_test.gd"
const Battles=preload("res://scripts/forest/forest_east_battles.gd")
func run():
 var prefix="3|||||||||"
 check(Battles.encounter_choices(prefix+"9034,9035,9036")==[9034,9035,9036],"Original comma alternatives retain their order and membership")
 check(Battles.encounter_choices(prefix+"12008")==[12008],"Existing single encounters keep their original selection")
 check(Battles.encounter_choices(prefix+"9034,9034,9035")==[9034,9034,9035],"Repeated original entries retain their distribution tickets")
 for invalid in["","0","-1","9034,,9036","9034,x,9036",",".join(range(1,18).map(func(i):return str(i)))]:
  check(Battles.encounter_choices(prefix+invalid).is_empty(),"Malformed or oversized encounter lists cannot start an invisible or unintended battle")
 var routes=preload("res://scripts/forest/forest_explore_routes.gd");routes.data()
 for actor in["80072","80073","80074"]:
  var rows=routes.catalog.bosses["21014"].filter(func(row):return str(row.actor)==actor)
  check(rows.size()==1 and Battles.encounter_choices(rows[0].declarations[0])==[9034,9035,9036],"The original ninja declaration remains unchanged: "+actor)
 print("STANDENEMY_SELECTION_RESULT checks=",checks," failures=",failures)
 finish()
