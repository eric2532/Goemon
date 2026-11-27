extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const OUT="res://build/Other Files/Asset Toolkit/Sokia Region Reconstruction/"
var failures=0
var checks=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("SOKIA_EXPANSION_FAIL ",message)
func _initialize():run.call_deferred()
func run():
 var baseline="--baseline" in OS.get_cmdline_user_args()
 var controls={}
 var expanded=["sokia_coast","sokia_desert","ghana_road"]
 var locations={"sokia_coast":[Vector2(52,158),Vector2(148,199),Vector2(356,334),Vector2(369,351),Vector2(280,399)],"sokia_desert":[Vector2(402,304),Vector2(488,314),Vector2(675,403),Vector2(626,209)],"ghana_road":[Vector2(671,157),Vector2(704,148),Vector2(626,209)]}
 for area in ["kili","sokia_coast","sokia_desert","ghana_road","ghana_north_road"]:
  var layout=Tour.Regions.layout(area)
  var model=Model.new();model.reset(41829558,{},layout,false)
  check(Tour.Document.validate(layout).is_empty(),"Current layout validates: "+area)
  var terrain=model.terrain
  var samples=[]
  for y in range(-300,301,30):
   for x in range(-300,301,30):samples.append(terrain.height(x,y))
  var field=terrain.terrain_field()
  controls[area]={"samples":samples,"width":field.get_meta("width"),"expansion":model.map_expansion}
  if area=="kili":
   controls[area].field_sha256=var_to_bytes([field.get_meta("heights"),field.get_meta("bed"),field.get_meta("covered"),field.get_meta("bridges")]).hex_encode().sha256_text()
  if not baseline:
   if area in expanded:
    check(model.map_expansion==1.5 and terrain.width==481,"Recovered source crop fits the existing expanded terrain field: "+area)
    var frame=Tour.Regions.frame(area)
    for cell in locations[area]:
     var at=frame.inverse()*(cell*3.)
     check(terrain.mask_bounds().has_point(at) and model.world_bounds().has_point(at),"Native coast cell is inside terrain/navigation bounds: "+str(cell))
     check(is_finite(terrain.height(at.x,at.y)),"Native coast has a finite height at "+str(cell))
    var old=layout.duplicate(true);old.erase("map_expansion")
    check(Tour.Document.validate(old).is_empty(),"Legacy saved coast layout remains accepted")
    var restored=Model.new();restored.reset(41829558,{},old,false)
    check(restored.map_expansion==1.5 and restored.terrain.width==481,"Legacy coast receives the recovered field without changing saved coordinates")
   else:check(model.map_expansion==1.,"Other maps retain their existing size: "+area)
 if baseline:
  var file=FileAccess.open(OUT+"terrain-before.json",FileAccess.WRITE);file.store_string(JSON.stringify(controls,"  "));file.close()
 else:
  var before=JSON.parse_string(FileAccess.get_file_as_string(OUT+"terrain-before.json"))
  for area in controls:
   for i in controls[area].samples.size():check(is_equal_approx(controls[area].samples[i],before[area].samples[i]),"Existing native ground height retained: %s/%d"%[area,i])
   if area not in expanded:check(controls[area].width==before[area].width,"Other field dimensions unchanged: "+area)
  check(controls.kili.field_sha256==before.kili.field_sha256,"Every Kili terrain/coverage/bridge sample remains byte-identical")
  var file=FileAccess.open(OUT+"terrain-after.json",FileAccess.WRITE);file.store_string(JSON.stringify(controls,"  "));file.close()
 print("SOKIA_EXPANSION_RESULT baseline=",baseline," checks=",checks," failures=",failures)
 quit(1 if failures else 0)
