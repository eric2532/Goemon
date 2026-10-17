extends RefCounted
## Shared authored terrain: native geometry, AI and portals use the same surface.
var pieces: Array=[]
func configure(source: Array):
 pieces.clear()
 for item in source:
  var a=Vector2(item.ax*6,item.az*6);var b=Vector2(item.bx*6,item.bz*6)
  var along=(b-a).normalized();var half=float(item.width)*3
  var ramp=not is_equal_approx(float(item.h0),float(item.h1))
  var start=0.0 if ramp or not item.get("cap_start",true) else -half
  var end=a.distance_to(b)+(0.0 if ramp or not item.get("cap_end",true) else half)
  pieces.append({"a":a,"b":b,"along":along,"side":Vector2(-along.y,along.x),"half":half,"length":a.distance_to(b),"start":start,"end":end,"h0":float(item.h0),"h1":float(item.h1)})
func overlaps_tile(cell: Vector2i)->bool:
 var tile=Rect2(Vector2(cell.x*6-3,cell.y*6-3),Vector2.ONE*6)
 for piece in pieces:
  if maxf(piece.h0,piece.h1)<.01:continue
  var first: Vector2=piece.a+piece.along*piece.start
  var last: Vector2=piece.a+piece.along*piece.end
  var padding: Vector2=piece.side.abs()*piece.half
  var bounds=Rect2(first.min(last)-padding,(last-first).abs()+padding*2)
  if bounds.intersects(tile):return true
 return false
func height(x: float,z: float)->float:
 var p=Vector2(x,z);var result=0.0
 for piece in pieces:
  var offset=p-piece.a;var u=offset.dot(piece.along)
  if u<piece.start-.001 or u>piece.end+.001 or absf(offset.dot(piece.side))>piece.half+.001:continue
  result=maxf(result,lerpf(piece.h0,piece.h1,clampf(u/piece.length,0,1)))
 return result
func disk_clear(point: Vector3,radius: float)->bool:
 if pieces.is_empty():return true
 var center=height(point.x,point.z)
 # Slopes are at most 1:3. A vertical face fails even on a small movement step.
 var tolerance=.15+radius*.35
 for axis in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(.707,.707),Vector2(-.707,.707),Vector2(.707,-.707),Vector2(-.707,-.707)]:
  if absf(height(point.x+axis.x*radius,point.z+axis.y*radius)-center)>tolerance:return false
 return true
func step_clear(from: Vector3,to: Vector3)->bool:
 var distance=Vector2(to.x-from.x,to.z-from.z).length()
 return absf(height(to.x,to.z)-height(from.x,from.z))<=.15+distance*.35
func cliff_cell(cell: Vector2i)->bool:
 if pieces.is_empty():return false
 var center=height(cell.x*6,cell.y*6)
 for step in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
  if absf(height((cell.x+step.x)*6,(cell.y+step.y)*6)-center)>2.11:return true
 return false
static func validation_error(value)->String:
 if not value is Array or value.size()>24:return "Use at most 24 raised-wall segments."
 for item in value:
  if not item is Dictionary:return "Invalid raised-wall segment."
  for key in ["ax","az","bx","bz","width","h0","h1"]:
   var v=item.get(key)
   if not (v is int or v is float) or not is_finite(float(v)):return "Invalid raised-wall dimensions."
  for key in ["ax","az","bx","bz"]:
   if item[key]!=floor(item[key]) or absf(item[key])>36:return "Raised walls must stay inside the map."
  if item.width!=floor(item.width) or int(item.width) not in [3,5,7] or item.h0<0 or item.h0>30 or item.h1<0 or item.h1>30:return "Invalid raised-wall width or height."
  var distance=Vector2(item.bx-item.ax,item.bz-item.az).length()*6
  if distance<6 or (item.ax!=item.bx and item.az!=item.bz) or absf(item.h1-item.h0)>distance/3:return "Walls need straight segments and a gradual ramp."
  for key in ["cap_start","cap_end"]:
   if item.has(key) and not item[key] is bool:return "Invalid raised-wall end cap."
 return ""
