extends SceneTree
var checks=0
var failures=0
func check(ok: bool, label: String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+label)
 else:print("PASS: ",label)
func _initialize():
 call_deferred("run")
func run():
 if not ResourceLoader.exists("res://scripts/map_document.gd"):
  check(false,"Editable map document exists");finish();return
 var Model=load("res://scripts/map_document.gd")
 var m=Model.new();m.reset_template()
 check(m.validate().is_empty(),"Starter map is playable with open route and spawn")
 var initial=m.encode()
 var uid=m.place("lantern",Vector3(30,0,150),90)
 check(uid>0 and m.item(uid).x==30 and m.item(uid).rotation==90,"Place a rotated new asset")
 m.move_item(uid,Vector3(34,0,152));m.rotate_item(uid)
 check(m.item(uid).x==34 and m.item(uid).rotation==180,"Move and rotate persist in document")
 m.undo();check(m.item(uid).rotation==90,"Undo restores rotation")
 m.redo();check(m.item(uid).rotation==180,"Redo restores rotation")
 m.undo();m.move_item(uid,Vector3(36,0,152));check(not m.redo(),"New edits discard obsolete redo history")
 m.remove_item(uid);check(m.item(uid).is_empty(),"Delete removes placed piece")
 m.undo();check(not m.item(uid).is_empty(),"Undo restores deleted piece")
 var other=Model.new();check(other.decode(m.encode()).is_empty(),"JSON reload succeeds")
 check(other.item(uid).x==36 and other.item(uid).rotation==90,"JSON reload preserves transform and IDs")
 var before=other.encode()
 for bad in ['{}','null','{"schema":99,"title":"x","pieces":[]}','{"schema":1,"title":"x","pieces":"no"}', '{"schema":1,"title":"x","pieces":[{"uid":1,"kind":"unknown","x":0,"z":100,"rotation":0}]}']:
  check(not other.decode(bad).is_empty() and other.encode()==before,"Malformed map is rejected without replacing draft")
 var corrupt=JSON.parse_string(before);corrupt.pieces[0].x=999999
 check(not other.decode(JSON.stringify(corrupt)).is_empty(),"Out-of-bounds coordinates rejected")
 corrupt=JSON.parse_string(before);corrupt.pieces[1].uid=corrupt.pieces[0].uid
 check(not other.decode(JSON.stringify(corrupt)).is_empty(),"Duplicate IDs rejected")
 var original_spawn=m.find_kind("spawn")[0].uid
 m.place("spawn",Vector3(8,0,210))
 check(m.find_kind("spawn").size()==1 and m.item(original_spawn).x==8,"Placing singleton moves existing hero spawn")
 check(not m.remove_item(original_spawn),"Required spawn cannot be deleted")
 m.reset_blank();check(m.validate().is_empty(),"Blank map has a usable floor and required gameplay markers")
 var wall=m.place("wall",Vector3(0,0,150))
 check(not m.validate().is_empty(),"Solid wall crossing enemy route prevents play")
 m.move_item(wall,Vector3(30,0,150));check(m.validate().is_empty(),"Moving obstacle off route restores playable layout")
 m.place("rock",Vector3(0,0,195));check(not m.validate().is_empty(),"Solid obstacle over hero spawn prevents play")
 m.reset_blank()
 m.move_item(m.find_kind("spawn")[0].uid,Vector3(-78,0,195))
 check(not m.validate().is_empty(),"Hero spawn cannot intersect fixed boundary")
 m.move_item(m.find_kind("spawn")[0].uid,Vector3(76,0,195))
 check(not m.validate().is_empty(),"Companion formation must fit inside playable floor")
 m.reset_blank()
 m.move_item(m.find_kind("spawn")[0].uid,Vector3(40,0,195));m.place("wall",Vector3(45,0,195))
 check(not m.validate().is_empty(),"Companion spawn formation cannot intersect placed walls")
 m.reset_blank()
 m.place("waypoint",Vector3(30,0,170));m.place("waypoint",Vector3(-30,0,170));m.place("waypoint",Vector3(-30,0,130))
 check(m.validate().is_empty(),"Horizontal and backward segments are legal")
 var path="user://map-builder-test-roundtrip.json"
 check(m.save(path)==OK,"Atomic save writes a real local file")
 var disk=Model.new();check(disk.read_file(path).is_empty() and disk.encode()==m.encode(),"Saved map reloads with all data intact")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 check(not disk.read_file("user://missing-map-builder-file.json").is_empty(),"Missing save reports a useful error")
 finish()
func finish():
 print("MAP_DOCUMENT_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
