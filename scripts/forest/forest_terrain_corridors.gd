extends RefCounted
## Terrain support is independent of destructible structure weights/contacts.
## Borrowed records/points are read-only; callers perform fresh wall checks.
const Kai=preload("res://scripts/forest/forest_kai_terrain.gd")
const BloodGulch=preload("res://scripts/forest/forest_blood_gulch_terrain.gd")
const Ramparts=preload("res://scripts/forest/forest_ramparts.gd")
const MAX_ENTRIES=8192
const MAX_SAMPLES=262144
const ROAD_AXES=[Vector3.ZERO,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]
var model_ref:WeakRef
var navigation_ref:WeakRef
var revision=-1
var terrain_id=0
var signature=[]
var entries:Dictionary={}
var sample_count=0
var native_sampler:Object
func _init(model,navigation):model_ref=weakref(model);navigation_ref=weakref(navigation)
func clear():entries.clear();sample_count=0
func _refresh(model):
 var terrain=model.terrain
 if revision==model.navigation_revision and terrain_id==terrain.get_instance_id():return
 # Blood Gulch substitutes the field and its world origin; sampling math is Kai's.
 # Admit these exact scripts so custom subclasses still use their own methods.
 var native_field=terrain.get_script()==Kai or terrain.get_script()==BloodGulch
 var scale_=terrain.get("horizontal_scale") if terrain.get_script()==BloodGulch else null
 var origin=240.0*(float(scale_) if scale_!=null else 1.0)
 var bounds=Rect2(-243,-243,480,480)
 var rect_bounds=false
 if model.has_method("world_bounds"):
  bounds=model.world_bounds();rect_bounds=terrain.get_script()==BloodGulch
 elif model.has_method("navigation_bounds"):
  bounds=model.navigation_bounds();rect_bounds=terrain.get_script()==BloodGulch
 var next=[terrain.get_instance_id(),terrain.pieces.duplicate(true),model.trees.duplicate(),model.roads.duplicate()]
 if native_field:
  next.append_array([terrain.width,terrain.spacing,terrain.heights.duplicate(),terrain.covered.duplicate(),origin,bounds,rect_bounds])
 elif terrain.get_script()!=Ramparts:
  # Custom terrain may have extra mutable geometry outside native fields.
  next.append(model.navigation_revision)
 var changed=signature!=next
 if changed:clear();signature=next
 if native_field and terrain.pieces.is_empty() and ClassDB.class_exists("GoemonTerrainMath"):
  if native_sampler==null:
   native_sampler=ClassDB.instantiate("GoemonTerrainMath");changed=true
  if changed:native_sampler.configure_field(terrain.width,terrain.spacing,terrain.heights,terrain.covered)
  if native_sampler.has_method("set_domain"):native_sampler.set_domain(origin,bounds.position,bounds.end,rect_bounds)
  elif origin!=240.0 or bounds!=Rect2(-243,-243,480,480) or rect_bounds:native_sampler=null
  # An older installed library can still accelerate the original domain.
  if native_sampler!=null:
   var trees=PackedVector2Array();var roads=PackedVector2Array();var walls=PackedVector3Array()
   for cell in model.trees:trees.append(Vector2(cell.x*model.CELL,cell.y*model.CELL))
   for cell in model.roads:roads.append(Vector2(cell))
   var navigation=navigation_ref.get_ref();navigation._refresh_candidates()
   for wall_bounds in navigation.building_contact_bounds.values():
    for index in range(0,wall_bounds.size(),2):walls.append(wall_bounds[index]);walls.append(wall_bounds[index+1])
   native_sampler.set_obstacles(trees,roads,walls)
 else:native_sampler=null
 revision=model.navigation_revision;terrain_id=terrain.get_instance_id()
func walls_clear(points:PackedVector3Array,radius:float)->bool:
 var model=model_ref.get_ref();_refresh(model)
 if native_sampler!=null:return native_sampler.walls_clear(points,radius)
 var navigation=navigation_ref.get_ref()
 for point in points:
  if navigation.blocker(point,radius)>=0:return false
 return true
func support(from:Vector3,to:Vector3,radius:float,spacing:float,on_road:bool,horizontal:bool)->Dictionary:
 var model=model_ref.get_ref();var navigation=navigation_ref.get_ref();_refresh(model)
 var key=[from,to,radius,spacing,on_road,horizontal]
 if entries.has(key):return entries[key]
 if native_sampler!=null:
  var native_points:PackedVector3Array=native_sampler.sample(from,to,radius,spacing,horizontal,on_road)
  return _store(key,not native_points.is_empty(),native_points)
 var distance=Vector2(to.x-from.x,to.z-from.z).length() if horizontal else from.distance_to(to)
 var steps=maxi(1,ceili(distance/spacing));var points=PackedVector3Array();var previous=from
 var terrain=model.terrain;var field_radius=14.75 if radius>=8.5 else radius
 var flat=terrain.has_method("flat_corridor") and terrain.flat_corridor(from,to,field_radius)
 var floor_y:float=model.surface_height(from.x,from.z) if flat else 0.0
 var supported=true
 for index in range(1,steps+1):
  var point=from.lerp(to,float(index)/steps);point.y=floor_y if flat else model.surface_height(point.x,point.z)
  if flat:
   if not navigation.terrain_obstacles_clear(point,radius):supported=false;break
  elif not terrain.step_clear(previous,point) or not navigation.terrain_clear(point,radius):supported=false;break
  if on_road:
   for axis in ROAD_AXES:
    if not model.roads.has(model.cell_of(point+axis*radius)):supported=false;break
   if not supported:break
  points.append(point);previous=point
 if not supported:points=PackedVector3Array()
 return _store(key,supported,points)
func _store(key:Array,supported:bool,points:PackedVector3Array)->Dictionary:
 var result={"clear":supported,"points":points};result.make_read_only()
 if entries.size()>=MAX_ENTRIES or sample_count+points.size()>MAX_SAMPLES:clear()
 if points.size()<=MAX_SAMPLES:entries[key]=result;sample_count+=points.size()
 return result
