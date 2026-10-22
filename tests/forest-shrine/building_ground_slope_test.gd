extends SceneTree
const Terrain=preload("res://scripts/forest/forest_kai_terrain.gd")
const Ramparts=preload("res://scripts/forest/forest_ramparts.gd")
const BloodGulch=preload("res://scripts/forest/forest_blood_gulch_terrain.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func plane(x_slope:float=0.,z_slope:float=0.):
 var ground=Terrain.new();ground.width=161;ground.spacing=3.0
 ground.heights.resize(161*161);ground.covered.resize(161*161);ground.covered.fill(1)
 for z in 161:
  for x in 161:ground.heights[z*161+x]=(x-80)*3*x_slope+(z-80)*3*z_slope
 return ground
func run():
 var long_wall=[Vector2i.ZERO,Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(4,0),Vector2i(5,0)]
 var slope=plane(.25)
 check(slope.building_error(long_wall).is_empty(),"A continuous 1:4 hillside supports a long building despite nine metres of total rise")
 check(slope.has_method("building_ground_range"),"Terrain exposes the support heights needed by raised building bases")
 if slope.has_method("building_ground_range"):
  var bounds:Vector2=slope.building_ground_range(long_wall)
  check(bounds.is_equal_approx(Vector2(-.75,8.25)),"The building's floor and foundation reach both ends of its supported slope")
  check(is_equal_approx(slope.foundation_depth(long_wall,bounds.y),9.),"Foundation support spans the whole hillside rather than a capped rise")
 var hill=plane()
 for z in 161:
  for x in 161:hill.heights[z*161+x]=3.-absf((x-85)*3.)*.2
 check(hill.building_error(long_wall).is_empty(),"A shallow continuous ridge under the middle of a footprint is buildable")
 var hole=plane(.25);hole.covered[80*161+85]=0
 check(not hole.building_error(long_wall).is_empty(),"A hole inside a long footprint remains unsupported")
 if hole.has_method("building_ground_range"):check(not is_finite(hole.building_ground_range(long_wall).y),"Unsupported ground never supplies a usable building floor height")
 var cliff=plane()
 for z in 161:
  for x in range(85,161):cliff.heights[z*161+x]=8.
 check(not cliff.building_error(long_wall).is_empty(),"A sharp elevation step through the middle cannot be hidden by clear corners")
 var diagonal=plane(.3,.3)
 check(not diagonal.building_error([Vector2i.ZERO]).is_empty(),"A steep diagonal plane is checked along its actual gradient")
 var low_relief=plane();low_relief.heights[80*161+80]=1.1
 check(low_relief.building_error([Vector2i.ZERO]).is_empty(),"An already supported low-relief patch keeps its existing construction permission")
 var outside=plane()
 check(not outside.building_error([Vector2i(-40,-40)]).is_empty(),"Footprints extending beyond the terrain field remain unsupported")
 var raised=Ramparts.new();raised.configure([{"ax":0,"az":0,"bx":0,"bz":4,"width":3,"h0":6.,"h1":6.}])
 check(not raised.building_error([Vector2i.ZERO]).is_empty(),"Raised-wall surfaces remain reserved physical structures")
 var flat=Ramparts.new();flat.configure([])
 check(flat.has_method("building_ground_range"),"Flat terrain shares the ground-height contract")
 if flat.has_method("building_ground_range"):check(flat.building_ground_range(long_wall)==Vector2.ZERO,"Level settlement ground retains its original zero base")
 # A shifted grid makes the supporting vertices extend outside the footprint.
 # The returned heights must bound the actual six-metre tile, not that excess.
 var shifted=plane(.25);shifted.spacing=3.6
 for z in 161:
  for x in 161:shifted.heights[z*161+x]=(x*3.6-240.)*.25
 if shifted.has_method("building_ground_range"):
  check(shifted.building_ground_range([Vector2i.ZERO]).is_equal_approx(Vector2(-.75,.75)),"Scaled terrain measures heights at the real footprint boundary")
 var blood=BloodGulch.new();blood.horizontal_scale=1.2;blood.configure([])
 var blood_site=[Vector2i(-18,-39),Vector2i(-17,-39),Vector2i(-18,-38),Vector2i(-17,-38)]
 check(blood.building_error(blood_site).is_empty(),"A real outer Blood Gulch hillside supports a tower")
 if blood.has_method("building_ground_range"):
  var bounds:Vector2=blood.building_ground_range(blood_site)
  check(bounds.y-bounds.x>3.,"The native Blood Gulch regression site exercises terrain beyond the old height cap")
 var kai=Terrain.new();kai.configure([])
 var kai_site=[Vector2i(7,-32),Vector2i(8,-32),Vector2i(7,-31),Vector2i(8,-31)]
 check(kai.building_error(kai_site).is_empty(),"A real Kai hillside supports a tower")
 if kai.has_method("building_ground_range"):
  var bounds:Vector2=kai.building_ground_range(kai_site)
  check(bounds.y-bounds.x>3.,"The native Kai regression site exercises terrain beyond the old height cap")
 print("BUILDING_GROUND_SLOPE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
