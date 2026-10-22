@static_unload
extends "res://scripts/forest/forest_ramparts.gd"
## The same triangulated height field is used by physics, paths and buildings.
const DISK_AXES=[Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(.707,.707),Vector2(-.707,.707),Vector2(.707,-.707),Vector2(-.707,-.707)]
const MAX_FLAT_CORRIDORS=4096
const MAX_DISK_REGIONS=16384
const FIELD_PATH="res://assets/maps/kai_highway/surface.res"
static var field:Resource
var width=0
var spacing=3.0
var heights=PackedFloat32Array()
var covered=PackedByteArray()
var bridges=PackedByteArray()
var flat_corridor_cache:Dictionary={}
var disk_region_cache:Dictionary={}
var cliff_cache:Dictionary={}
var building_ground_cache:Dictionary={}
func is_flat()->bool:return false
func supports_planar_certificates()->bool:return false
func configure(source:Array):
 flat_corridor_cache.clear();disk_region_cache.clear();cliff_cache.clear();building_ground_cache.clear()
 super.configure(source)
 var surface=terrain_field()
 if surface==null:return
 width=surface.get_meta("width");spacing=surface.get_meta("spacing");heights=surface.get_meta("heights");covered=surface.get_meta("covered");bridges=surface.get_meta("bridges")
func terrain_field()->Resource:
 if field==null and ResourceLoader.exists(FIELD_PATH):field=load(FIELD_PATH)
 return field
func bridge_at(x:float,z:float)->bool:
 var p=coordinate(x,z)
 return width>0 and bridges[clampi(roundi(p.y),0,width-1)*width+clampi(roundi(p.x),0,width-1)]!=0
func coordinate(x:float,z:float)->Vector2:return Vector2(x+240,z+240)/spacing
func contains(x:float,z:float)->bool:
 if width<2:return false
 var p=coordinate(x,z);var ix=floori(p.x);var iz=floori(p.y)
 if ix<0 or iz<0 or ix>=width-1 or iz>=width-1:return false
 var offset=iz*width+ix
 return covered[offset]!=0 and covered[offset+1]!=0 and covered[offset+width]!=0 and covered[offset+width+1]!=0
func height(x:float,z:float)->float:
 if width<2:return 0
 var p=coordinate(x,z);var ix=clampi(floori(p.x),0,width-2);var iz=clampi(floori(p.y),0,width-2)
 var u=clampf(p.x-ix,0,1);var v=clampf(p.y-iz,0,1);var at=iz*width+ix
 var h00=heights[at];var h10=heights[at+1];var h01=heights[at+width];var h11=heights[at+width+1]
 var result=h00+(h10-h00)*u+(h01-h00)*v if u+v<=1 else h11+(h01-h11)*(1-u)+(h10-h11)*(1-v)
 return maxf(result,super.height(x,z)) if not pieces.is_empty() else result
func _covered_height(x:float,z:float)->float:
 # Preserve native Vector2 float32 coordinates and triangle arithmetic. A
 # covered query needs one coordinate/index calculation, shared by both tests.
 if width<2:return NAN
 var p=coordinate(x,z);var ix=floori(p.x);var iz=floori(p.y)
 if ix<0 or iz<0 or ix>=width-1 or iz>=width-1:return NAN
 var at=iz*width+ix
 if covered[at]==0 or covered[at+1]==0 or covered[at+width]==0 or covered[at+width+1]==0:return NAN
 var u=clampf(p.x-ix,0,1);var v=clampf(p.y-iz,0,1)
 var h00=heights[at];var h10=heights[at+1];var h01=heights[at+width];var h11=heights[at+width+1]
 var result=h00+(h10-h00)*u+(h01-h00)*v if u+v<=1 else h11+(h01-h11)*(1-u)+(h10-h11)*(1-v)
 return maxf(result,super.height(x,z)) if not pieces.is_empty() else result
func disk_clear(point:Vector3,radius:float)->bool:
 # Every native interpolation lies within its triangle vertex range. A
 # fully covered rectangle with a sufficiently small total height range
 # therefore proves all nine samples, including gently varying ground.
 if _disk_region_clear(point,radius):return true
 var center=_covered_height(point.x,point.z)
 if is_nan(center):return false
 var tolerance=.15+radius*.35
 for axis in DISK_AXES:
  var x=point.x+axis.x*radius;var z=point.z+axis.y*radius
  var sample=_covered_height(x,z)
  if is_nan(sample) or absf(sample-center)>tolerance:return false
 return true
func _disk_region_clear(point:Vector3,radius:float)->bool:
 if width<2 or not pieces.is_empty() or radius<0:return false
 var low=coordinate(point.x-radius,point.z-radius)
 var high=coordinate(point.x+radius,point.z+radius)
 var x0=floori(low.x);var z0=floori(low.y)
 var x1=floori(high.x)+1;var z1=floori(high.y)+1
 if x0<0 or z0<0 or x1>=width or z1>=width:return false
 var key=Vector4i(x0,z0,x1,z1)
 var limits:Vector2
 if disk_region_cache.has(key):limits=disk_region_cache[key]
 else:
  if disk_region_cache.size()>=MAX_DISK_REGIONS:disk_region_cache.clear()
  limits=Vector2(INF,-INF)
  for z in range(z0,z1+1):
   for x in range(x0,x1+1):
    var index=z*width+x
    if covered[index]==0:
     disk_region_cache[key]=Vector2(INF,INF);return false
    var h=heights[index];limits.x=minf(limits.x,h);limits.y=maxf(limits.y,h)
  disk_region_cache[key]=limits
 # Reserve margin for floating arithmetic. An inconclusive proof always
 # falls back to the original sampler; no collision tolerance is increased.
 return is_finite(limits.x) and limits.y-limits.x<=.15+radius*.35-.000001
func flat_corridor(from:Vector3,to:Vector3,radius:float)->bool:
 # Every triangle touching the expanded segment box must have four covered
 # vertices with the exact same height. No slope/edge approximation is used.
 if width<2 or not pieces.is_empty() or radius<0:return false
 var low=coordinate(minf(from.x,to.x)-radius,minf(from.z,to.z)-radius)
 var high=coordinate(maxf(from.x,to.x)+radius,maxf(from.z,to.z)+radius)
 var x0=floori(low.x);var z0=floori(low.y)
 var x1=floori(high.x)+1;var z1=floori(high.y)+1
 if x0<0 or z0<0 or x1>=width or z1>=width:return false
 var key=Vector4i(x0,z0,x1,z1)
 if flat_corridor_cache.has(key):return bool(flat_corridor_cache[key])
 if flat_corridor_cache.size()>=MAX_FLAT_CORRIDORS:flat_corridor_cache.clear()
 flat_corridor_cache[key]=false
 var level=heights[z0*width+x0]
 for z in range(z0,z1+1):
  for x in range(x0,x1+1):
   var index=z*width+x
   if covered[index]==0 or heights[index]!=level:return false
 flat_corridor_cache[key]=true
 return true
func cliff_cell(cell:Vector2i)->bool:
 if cliff_cache.has(cell):return bool(cliff_cache[cell])
 var result=_sample_cliff_cell(cell)
 # Fit a complete six-metre navigation grid, including scaled canyon fields.
 # The old 8,192 limit repeatedly flushed a 9,216-cell map on every gate revision.
 var extent=ceili(width*spacing/6.0)+2
 var capacity=maxi(8192,mini(65536,extent*extent))
 if cliff_cache.size()>=capacity:cliff_cache.clear()
 cliff_cache[cell]=result
 return result
func _sample_cliff_cell(cell:Vector2i)->bool:
 var x=cell.x*6.;var z=cell.y*6.
 if not contains(x,z):return true
 var center=height(x,z)
 for step in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
  if not contains(x+step.x*6,z+step.y*6) or absf(height(x+step.x*6,z+step.y*6)-center)>2.11:return true
 return false
func overlaps_tile(cell:Vector2i)->bool:
 if super.overlaps_tile(cell):return true
 var center=height(cell.x*6,cell.y*6)
 for offset in [Vector2.ZERO,Vector2(-3,-3),Vector2(3,-3),Vector2(-3,3),Vector2(3,3)]:
  var x=cell.x*6+offset.x;var z=cell.y*6+offset.y
  if not contains(x,z) or absf(height(x,z)-center)>.18:return true
 return false
func building_error(cells:Array)->String:
 return _building_ground_info(cells).error
func building_ground_range(cells:Array)->Vector2:
 var ground=_building_ground_info(cells)
 return Vector2(ground.minimum,ground.maximum) if ground.error.is_empty() else Vector2(NAN,NAN)
func foundation_depth(cells:Array,anchor_height:float)->float:
 var ground=_building_ground_info(cells)
 return maxf(0.0,anchor_height-float(ground.minimum)) if ground.error.is_empty() else 0.0
func _building_ground_info(cells:Array)->Dictionary:
 if cells.is_empty():return {"error":"Choose a building"}
 var first:Vector2i=cells.front();var last=first
 for cell in cells:
  if super.overlaps_tile(cell):return {"error":"Keep the raised wall route clear"}
  first=first.min(cell);last=last.max(cell)
 var key=Vector4i(first.x,first.y,last.x,last.y)
 if building_ground_cache.has(key):return building_ground_cache[key]
 var result=_building_ground_result(first,last)
 if building_ground_cache.size()>=4096:building_ground_cache.clear()
 building_ground_cache[key]=result
 return result
func _building_ground_result(first:Vector2i,last:Vector2i)->Dictionary:
 # Check continuous support and local steepness, regardless of the total rise
 # under a long building. A foundation can follow a hill, but cannot bridge a
 # hole or turn a cliff face into usable ground.
 var low=coordinate(first.x*6.-3.,first.y*6.-3.)
 var high=coordinate(last.x*6.+3.,last.y*6.+3.)
 var x0=floori(low.x);var z0=floori(low.y)
 var x1=ceili(high.x);var z1=ceili(high.y)
 if width<2 or x0<0 or z0<0 or x1>=width or z1>=width:return {"error":"Needs solid ground under the whole building"}
 var vertex_minimum=INF;var vertex_maximum=-INF
 for z in range(z0,z1+1):
  for x in range(x0,x1+1):
   var index=z*width+x
   if covered[index]==0:return {"error":"Needs solid ground under the whole building"}
   vertex_minimum=minf(vertex_minimum,heights[index]);vertex_maximum=maxf(vertex_maximum,heights[index])
 var minimum=INF;var maximum=-INF
 # Preserve the small, solid bumps that were already buildable. Wider hills
 # need continuous gradual triangles, without an arbitrary total-rise cap.
 var check_steepness=vertex_maximum-vertex_minimum>1.2
 # Use the same gradual-slope allowance as terrain movement, measured over a
 # native triangle rather than over the entire building's width.
 var rise_limit_squared=pow(.15+spacing*.35,2)+.000001
 for z in range(z0,z1):
  for x in range(x0,x1):
   var index=z*width+x
   var h00=heights[index];var h10=heights[index+1];var h01=heights[index+width];var h11=heights[index+width+1]
   var u0=clampf(low.x-x,0.,1.);var v0=clampf(low.y-z,0.,1.)
   var u1=clampf(high.x-x,0.,1.);var v1=clampf(high.y-z,0.,1.)
   if check_steepness and u0+v0<1. and Vector2(h10-h00,h01-h00).length_squared()>rise_limit_squared:return {"error":"Keep the building clear of steep cliff faces"}
   if check_steepness and u1+v1>1. and Vector2(h11-h01,h11-h10).length_squared()>rise_limit_squared:return {"error":"Keep the building clear of steep cliff faces"}
   # Linear triangles attain their extrema at the clipped footprint corners
   # or where their diagonal crosses its edges. Do not lift the building to
   # a higher terrain vertex that lies outside its real footprint.
   var samples=[Vector2(u0,v0),Vector2(u1,v0),Vector2(u0,v1),Vector2(u1,v1)]
   for u in [u0,u1]:
    if 1.-u>=v0 and 1.-u<=v1:samples.append(Vector2(u,1.-u))
   for v in [v0,v1]:
    if 1.-v>=u0 and 1.-v<=u1:samples.append(Vector2(1.-v,v))
   for p in samples:
    var h=h00+(h10-h00)*p.x+(h01-h00)*p.y if p.x+p.y<=1. else h11+(h01-h11)*(1.-p.x)+(h10-h11)*(1.-p.y)
    minimum=minf(minimum,h);maximum=maxf(maximum,h)
 return {"error":"","minimum":minimum,"maximum":maximum}
