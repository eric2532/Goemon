extends SceneTree
var heights=PackedFloat32Array()
var spacing=3.0
func field_height(x:float,z:float)->float:
 var p=Vector2(x+240,z+240)/spacing
 var ix=clampi(floori(p.x),0,159);var iz=clampi(floori(p.y),0,159)
 var u=clampf(p.x-ix,0,1);var v=clampf(p.y-iz,0,1);var at=iz*161+ix
 var h00=heights[at];var h10=heights[at+1];var h01=heights[at+161];var h11=heights[at+162]
 return h00+(h10-h00)*u+(h01-h00)*v if u+v<=1 else h11+(h01-h11)*(1-u)+(h10-h11)*(1-v)
func _initialize():
 GDExtensionManager.load_extension("res://native/terrain_math/terrain_math.gdextension")
 var native=ClassDB.instantiate("GoemonTerrainMath")
 var covered=PackedByteArray();covered.resize(161*161);covered.fill(1)
 heights.resize(161*161)
 for z in range(161):
  for x in range(161):heights[z*161+x]=sin(float(x)*.15)*.1+cos(float(z)*.13)*.1
 native.configure_field(161,spacing,heights,covered)
 native.set_obstacles(PackedVector2Array(),PackedVector2Array(),PackedVector3Array())
 seed(87923)
 for query in range(1000):
  var from=Vector3(randf_range(-220,220),randf_range(-1,1),randf_range(-220,220))
  var to=from+Vector3(randf_range(-5,5),randf_range(-1,1),randf_range(-5,5))
  var horizontal=query%2==0
  var steps=maxi(1,ceili((Vector2(to.x-from.x,to.z-from.z).length() if horizontal else from.distance_to(to))/.7))
  var points:PackedVector3Array=native.sample(from,to,0.0,.7,horizontal,false)
  assert(points.size()==steps,"sample count differs")
  for index in range(steps):
   var expected=from.lerp(to,float(index+1)/steps);expected.y=field_height(expected.x,expected.z)
   assert(points[index]==expected,"point differs: %s vs %s, height bits %s vs %s"%[points[index],expected,var_to_bytes(points[index].y),var_to_bytes(expected.y)])
 print("GoemonTerrainMath numeric smoke passed:1000 sampled paths match GDScript Vector3 and triangulated field")
 quit()
