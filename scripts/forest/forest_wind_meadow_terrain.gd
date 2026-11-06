extends "res://scripts/forest/forest_kai_terrain.gd"
## Physics, native armies and route queries share the same prepared triangles.
var horizontal_scale=1.0
const EXPANSIONS=[1.0,1.5,2.25]
const Layout=preload("res://scripts/forest/forest_wind_meadow_layout.gd")
var expansion=1.0
var raised_castle=false
var expanded_mesh:ArrayMesh
var expanded_collision:ConcavePolygonShape3D
static var expanded_fields:Dictionary={}
func terrain_field()->Resource:
 var source=load(asset_path("surface.res",horizontal_scale))
 if expansion==1.0 and not raised_castle:return source
 var key=Vector3(horizontal_scale,expansion,float(raised_castle))
 if expanded_fields.has(key):return expanded_fields[key]
 var original:int=source.get_meta("width");var count=roundi((original-1)*expansion)+1
 var padding=(count-original)/2
 var old:PackedFloat32Array=source.get_meta("heights")
 var values=PackedFloat32Array();values.resize(count*count)
 for z in count:
  var sz=clampi(z-padding,0,original-1)
  for x in count:
   var sx=clampi(x-padding,0,original-1)
   var world=Vector2(x*3.0,z*3.0)-Vector2.ONE*240*horizontal_scale*expansion
   var p=world/horizontal_scale
   var h:float
   if expansion==1.0:
    h=old[sz*original+sx]
   elif x-padding==sx and z-padding==sz:
    h=old[sz*original+sx]-rim_height(p,1.0)
   else:
    h=maxf(18*smoothstep(75,162,-p.y),maxf(10*smoothstep(75,162,p.x),maxf(12*smoothstep(75,162,-p.x),6*smoothstep(84,162,p.y))))
   # Move only the outer cliff rim, so the extra lawn connects to the valley.
   values[z*count+x]=h+(rim_height(p,expansion) if expansion!=1.0 else 0.0)
   # Stair support is prepared once alongside the courtyard and valley triangles.
   if raised_castle:values[z*count+x]=maxf(values[z*count+x],Layout.castle_height(world))
 var coverage=PackedByteArray();coverage.resize(values.size());coverage.fill(1)
 var bridge=PackedByteArray();bridge.resize(values.size())
 var result=Resource.new();result.set_meta("width",count);result.set_meta("spacing",3.0);result.set_meta("heights",values);result.set_meta("covered",coverage);result.set_meta("bridges",bridge)
 expanded_fields[key]=result
 return result
func rim_height(p:Vector2,size_:float)->float:
 if p.length_squared()<=176*176*size_*size_:return 0
 var angle=atan2(p.y,p.x)
 var rim=204+9*sin(angle*3+.6)+6*sin(angle*7-1.2)+3*sin(angle*11)
 var result=smoothstep((rim-10)*size_,(rim+9)*size_,p.length())*(42+10*sin(angle*5)+6*sin(angle*9+.4))
 if result==0:return 0
 for camp in Layout.CLEARINGS:
  var distance=p.distance_to(Vector2(camp.x,camp.z))
  result*=smoothstep(18,30,distance)
  if horizontal_scale>=2.0:result*=smoothstep(70,100,distance*horizontal_scale)
 return result
func mesh()->ArrayMesh:
 if expansion==1.0 and not raised_castle:return load(asset_path("terrain.res",horizontal_scale))
 if expanded_mesh!=null:return expanded_mesh
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var indices=PackedInt32Array()
 vertices.resize(width*width);normals.resize(width*width)
 var extent=240*horizontal_scale*expansion
 for z in width:
  for x in width:
   var i=z*width+x;vertices[i]=Vector3(x*spacing-extent,heights[i],z*spacing-extent)
   var dx=heights[z*width+mini(x+1,width-1)]-heights[z*width+maxi(0,x-1)]
   var dz=heights[mini(z+1,width-1)*width+x]-heights[maxi(0,z-1)*width+x]
   normals[i]=Vector3(-dx,spacing*2,-dz).normalized()
 indices.resize((width-1)*(width-1)*6)
 for z in width-1:
  for x in width-1:
   var i=z*width+x;var at=(z*(width-1)+x)*6
   indices[at]=i;indices[at+1]=i+1;indices[at+2]=i+width
   indices[at+3]=i+1;indices[at+4]=i+width+1;indices[at+5]=i+width
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
 expanded_mesh=ArrayMesh.new();expanded_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 if expansion==1.0:
  var source=load(asset_path("terrain.res",horizontal_scale))
  expanded_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(1))
 return expanded_mesh
func collision()->ConcavePolygonShape3D:
 if expansion==1.0 and not raised_castle:return load(asset_path("collision.res",horizontal_scale))
 if expanded_collision==null:
  var surface=ArrayMesh.new();surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh().surface_get_arrays(0))
  expanded_collision=surface.create_trimesh_shape()
 return expanded_collision
static func asset_path(file:String,scale_:float)->String:return "res://assets/maps/wind_meadow/"+("castles_large/" if scale_==3.0 else "castles/" if scale_==2.0 else "")+file
func coordinate(x:float,z:float)->Vector2:return Vector2(x+240*horizontal_scale*expansion,z+240*horizontal_scale*expansion)/spacing
func overlaps_tile(cell:Vector2i)->bool:
 var center=height(cell.x*6,cell.y*6)
 for offset in [Vector2.ZERO,Vector2(-3,-3),Vector2(3,-3),Vector2(-3,3),Vector2(3,3)]:
  var x=cell.x*6+offset.x;var z=cell.y*6+offset.y
  if not contains(x,z) or absf(height(x,z)-center)>.7:return true
 return false

func castle_wall_cells(cells:Array)->bool:
 return raised_castle and not cells.is_empty() and cells.all(func(cell):return maxi(absi(cell.x),absi(cell.y))==8)
func _building_ground_info(cells:Array)->Dictionary:
 # The original walls and empty gateway frames stay at the valley floor.
 if castle_wall_cells(cells):return {"error":"","minimum":0.0,"maximum":0.0}
 return super._building_ground_info(cells)
