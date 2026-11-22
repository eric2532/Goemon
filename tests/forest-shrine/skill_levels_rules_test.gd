extends SceneTree
const Rules=preload("res://scripts/spells/skill_levels.gd")
var failures=0
var checks=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():
 for row in [[-1,0],[1,0],[9,0],[10,1],[18,1],[19,2],[27,2],[28,3],[29,3],[30,4],[99,4]]:
  check(Rules.shine_tier(row[0])==row[1],"Shine tier boundary "+str(row[0]))
 for row in [["sure-strike",1,1.1],["sure-strike",30,4.0],["double-edge",30,7.4],["combo",1,.8],["combo",2,.9],["combo",3,.9],["combo",30,2.3],["two-birds",30,4.0],["counter",30,7.3],["random-shot",30,.85],["qigong",30,7.3],["moon",30,5.75],["mirror-image",30,2.3],["barrage-shadows",30,1.29]]:
  check(is_equal_approx(float(Rules.stats("test/"+row[0],row[1]).damage),row[2]),"Damage "+str(row))
 for row in [["combo",1,3],["combo",3,4],["combo",30,17],["counter",4,1],["counter",5,2],["counter",30,7],["random-shot",30,32],["qigong",1,1],["qigong",2,2],["qigong",30,16],["moon",3,3],["moon",4,4],["moon",30,10],["mirror-image",30,9],["barrage-shadows",30,7]]:
  check(Rules.stats("test/"+row[0],row[1]).count==row[2],"Count "+str(row))
 for kind in Rules.ELEMENTS:
  for row in [[1,100,1,0],[9,900,2,0],[10,1000,3,1],[18,1800,4,1],[19,1900,4,2],[27,2700,6,2],[28,2800,6,3],[29,2900,6,3],[30,3000,7,4]]:
   var s=Rules.stats("kazi/"+kind,row[0])
   check(s.base_damage==row[1] and s.count==row[2] and s.effect_tier==row[3],"Element boundary "+kind+str(row[0]))
 check(Rules.family("kazi/qigong")==Rules.family("maze/qigong"),"Qi colors share levels")
 check(is_equal_approx(Rules.stats("shin/sure-strike",30).size,1.29),"Approved size growth is one percent per level")
 check(Rules.stats("shin/double-edge",30).get("hit_area",1.0)==1.0,"Double Edge level growth does not enlarge its impact area")
 check(Rules.stats("kazi/assassination",1).chance==.25 and Rules.stats("kazi/assassination",30).chance==1.0,"Assassination endpoints")
 check(Rules.stats("kazi/kagerou",1).chance==.25 and Rules.stats("kazi/kagerou",30).chance==.99,"Dodge endpoints")
 for row in [[1,.20,0],[9,.28,0],[10,.29,1],[18,.37,1],[19,.38,2],[27,.46,2],[28,.47,3],[30,.49,4]]:
  var s=Rules.stats("uru/recovery",row[0])
  check(is_equal_approx(s.healing,row[1]) and s.effect_tier==row[2],"Recovery boundary "+str(row[0]))
 for row in [[9,0],[10,10],[19,10],[20,20],[29,20],[30,30]]:
  check(Rules.stats("kazi/qigong",row[0]).critical_bonus==row[1],"Qi crit milestone "+str(row[0]))
 for level in range(1,31):
  var guard_break=Rules.stats("crossgate/guard-break",level)
  check(is_equal_approx(guard_break.damage,1.8+.2*(level-1)) and is_equal_approx(guard_break.size,1.0+.01*(level-1)),"Guard Break damage and effect size level "+str(level))
  var meditation=Rules.stats("shin/meditation",level)
  check(is_equal_approx(meditation.healing,.05+.01*(level-1)),"Meditation missing-health healing level "+str(level))
  check(meditation.effect_tier==Rules.shine_tier(level) and not meditation.has("size"),"Meditation uses original artwork without synthetic size growth at level "+str(level))
  check(Rules.stats("bog/meditation",level)==meditation,"Native and equipped meditation share rules")
 check(Rules.stats("bog/cave-bears",30).is_empty(),"Undefined progression preserves the existing skill")
 print("SKILL_LEVEL_RULES checks=",checks," failures=",failures)
 quit(1 if failures else 0)
