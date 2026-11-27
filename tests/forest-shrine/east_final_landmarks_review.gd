extends "res://tests/forest-shrine/east_landmark_review.gd"
## Final direct-spawn camera pairs; living trees have their own small fixture.
func _initialize():
 create_timer(1800,true,false,true).timeout.connect(func():printerr("EAST_FINAL_LANDMARK_TIMEOUT");quit(1))
 run.call_deferred()

func review_path()->String:
 return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Final Continental/" if "--continental" in OS.get_cmdline_user_args() else "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Final Main/"

func sites()->Array:
 if "--continental" in OS.get_cmdline_user_args():return [
  [43600,1233268,Vector2i(95,101),"luminas-observatory",Vector2i(87,97),Vector2i(100,105)],
  [43600,1233262,Vector2i(45,65),"luminas-leaf-hut"],
  [43600,10657,Vector2i(59,35),"luminas-round-tower"],
  [43700,1233250,Vector2i(87,49),"lektal-timber-house"],
  [43800,1233180,Vector2i(126,92),"cape-temple"],
  [50000,1233172,Vector2i(155,107),"nosferatu-black-palace"],
  [32086,1233276,Vector2i(47,55),"komatei-ruined-tower"],
  [51002,1235177,Vector2i(121,77),"black-palace-dragon",Vector2i(111,84),Vector2i(126,65)],
  [45004,11417,Vector2i(31,19),"fairyland-thatch-cottage"],
  [44000,17638,Vector2i(156,92),"cave-timber-mouth"],
 ]
 return [
  [43100,1233000,Vector2i(129,47),"goral-curved-house",Vector2i(127,56),Vector2i(141,56)],
  [43100,1233020,Vector2i(167,219),"goral-palace",Vector2i(164,221),Vector2i(178,214)],
  [43100,1233018,Vector2i(61,106),"goral-carved-frame",Vector2i(52,112),Vector2i(69,102)],
  [40000,1238094,Vector2i(49,48),"harbor-boarding-stair",Vector2i(52,49),Vector2i(54,46)],
  [41000,1230059,Vector2i(46,22),"ship-mast",Vector2i(68,19),Vector2i(54,17)],
 ]
