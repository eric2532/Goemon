extends RefCounted
## Ordinary actors share cached routes, but occupy stable lanes within their safe corridor.
## This only supplies steering; swept_move remains the physical movement authority.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const BUCKET_SIZE=4.0
const BUCKET_CAP=12
const MAX_ONWARD_CERTIFICATES=4096
const MAX_CORRIDOR_CERTIFICATES=16384
const LANES=[-6.6,-4.4,-2.2,0.0,2.2,4.4,6.6]
var reference:WeakRef
var buckets:Dictionary={}
var onward_certificates:Dictionary={}
var onward_revision=-1
var corridor_certificates:Dictionary={}
var corridor_revision=-1
var corridor_terrain=0
var m:
 get:return reference.get_ref()
func _init(model):reference=weakref(model)
static func ordinary(e:Dictionary)->bool:return e.variant in [0,1,3]
static func bucket(p:Vector3)->Vector2i:return Vector2i(floori(p.x/BUCKET_SIZE),floori(p.z/BUCKET_SIZE))
func begin_tick():
 buckets.clear()
 for e in m.enemies.values():
  if e.hp<=0:continue
  var key=bucket(e.pos)
  if not buckets.has(key):buckets[key]=[]
  # Cap pathological overlap work as well as the normal spatial neighborhood.
  if buckets[key].size()<BUCKET_CAP:buckets[key].append({"id":e.id,"pos":e.pos,"radius":Roles.footprint_radius(e.variant)})
func corridor_clear(e:Dictionary,from:Vector3,to:Vector3,on_road:bool)->bool:
 # Exact actor roots only: a nearby offset can cross a cliff or wall edge.
 # Cache blocked queries too, so a stationary crowd cannot rescan the same
 # failed lane every tick. Physical movement remains independently swept.
 var model=m;var terrain_id:int=model.terrain.get_instance_id()
 if corridor_revision!=model.navigation_revision or corridor_terrain!=terrain_id:
  corridor_certificates.clear();corridor_revision=model.navigation_revision;corridor_terrain=terrain_id
 var key=[from,to,Roles.footprint_radius(e.variant),on_road]
 if corridor_certificates.has(key):return bool(corridor_certificates[key])
 var clear=_sample_corridor(e,from,to,on_road)
 if corridor_certificates.size()>=MAX_CORRIDOR_CERTIFICATES:corridor_certificates.clear()
 corridor_certificates[key]=clear
 return clear
func _sample_corridor(e:Dictionary,from:Vector3,to:Vector3,on_road:bool)->bool:
 var model=m;var navigation=model.waves.navigation;var radius=Roles.footprint_radius(e.variant)
 # Terrain and trees survive a wall collapse. Retain their exact sampled
 # support while checking the live structure contacts on every revision.
 var supported=navigation.supported_corridor(from,to,radius,.1 if model.has_elevation() else .75,on_road,true)
 if not supported.clear:return false
 return navigation.corridor_walls_clear(supported.points,radius)
func onward_clear(e:Dictionary,from:Vector3,to:Vector3,on_road:bool)->bool:
 # Only fixed lane geometry is shared. Incoming actor roots still receive a
 # fresh corridor_clear check, including offset entry positions at cliffs.
 var revision:int=m.navigation_revision
 if onward_revision!=revision:
  onward_certificates.clear();onward_revision=revision
 var key=[from,to,Roles.footprint_radius(e.variant),on_road,revision]
 if onward_certificates.has(key):return bool(onward_certificates[key])
 var clear=corridor_clear(e,from,to,on_road)
 if onward_certificates.size()>=MAX_ONWARD_CERTIFICATES:onward_certificates.clear()
 onward_certificates[key]=clear
 return clear
func route_point(e:Dictionary,on_road:bool)->Vector3:
 var center:Vector3=m.point(e.path.front())
 if not ordinary(e):return center
 var next:Vector2i=e.path[1] if e.path.size()>1 else e.path.front()
 var key=[e.path.front(),next,e.path.back(),m.navigation_revision,on_road]
 if e.get("flow_key",[])==key:return e.flow_point
 var tangent:Vector3=m.point(next)-center
 if Vector2(tangent.x,tangent.z).length_squared()<.001:tangent=center-e.pos
 tangent.y=0;tangent=tangent.normalized()
 var side=Vector3(-tangent.z,0,tangent.x)
 var arrival:Vector3=m.point(e.path.back())
 var taper=pow(minf(1.0,Vector2(center.x-arrival.x,center.z-arrival.z).length()/24.0),2.0)
 var offset:float=LANES[posmod(int(e.id),LANES.size())]*taper
 var point=center
 for fraction in [1.0,.66,.33]:
  var candidate=center+side*offset*fraction
  candidate.y=m.surface_height(candidate.x,candidate.z)
  # A supported outer waypoint can still strand a broad actor at its
  # following corner. Certify the onward path before choosing that lane.
  if corridor_clear(e,e.pos,candidate,on_road) and onward_clear(e,candidate,m.point(next),on_road):point=candidate;break
 e.flow_key=key;e.flow_point=point;e.flow_tangent=tangent;e.flow_origin=e.pos
 return point
func direction(e:Dictionary,point:Vector3)->Vector3:
 var desired:Vector3=e.pos.direction_to(point)
 if not ordinary(e) or buckets.is_empty():return desired
 var tangent:Vector3=e.get("flow_tangent",desired);var side=Vector3(-tangent.z,0,tangent.x)
 var push=0.0;var key=bucket(e.pos);var radius=Roles.footprint_radius(e.variant)
 for dx in range(-1,2):
  for dz in range(-1,2):
   for other in buckets.get(key+Vector2i(dx,dz),[]):
    if other.id==e.id or absf(e.pos.y-other.pos.y)>3:continue
    var away:Vector3=e.pos-other.pos;away.y=0
    var spacing=minf(3.5,radius+other.radius+.6);var distance=away.length()
    if distance>=spacing:continue
    var lateral=away.dot(side)
    if absf(lateral)<.01:lateral=1.0 if int(e.id)>int(other.id) else -1.0
    push+=signf(lateral)*(1-distance/spacing)
 # Fade on both sides of a waypoint. Reapplying full separation immediately
 # after arrival reverses steering and wastes net movement around the corner.
 var departure:Vector3=e.get("flow_origin",e.pos-desired*2)
 var fade=minf(1.0,minf(e.pos.distance_to(point),e.pos.distance_to(departure))/2)
 var strength=clampf(push,-.32,.32)*fade
 var steered=(desired+side*strength).normalized()
 # A cheap one-step road envelope avoids drifting off the corridor under separation.
 if e.get("flow_road",false):
  var probe:Vector3=e.pos+steered*.5
  for axis in [Vector3.ZERO,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
   if not m.roads.has(m.cell_of(probe+axis*radius)):return desired
 return steered
