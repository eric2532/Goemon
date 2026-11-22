extends RefCounted
## Chamber coordinates use the same three-metre tiles as the surrounding floor.
const BOUNDS=Rect2(-16.5,-22.5,21.0,18.0)
const STEP=3.0
const RISE=1.02
const FLOOR_SHADER=preload("res://scripts/forest/forest_falken_paving.gdshader")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
static var paving:ShaderMaterial
static var mesh:ArrayMesh
static var navigation_grid:Dictionary={}

static func add_navigation(data:Dictionary):
 var origin:Vector3=data.bounds_min-Vector3(1.5,0,1.5)
 var size_:Vector3=data.bounds_max-origin
 var width=ceili(maxf(size_.x,size_.z)/STEP)+1
 if navigation_grid.get("origin")!=origin or navigation_grid.get("width")!=width:
  var heights=PackedFloat32Array()
  heights.resize(width*width)
  var covered=PackedByteArray()
  covered.resize(heights.size())
  covered.fill(1)
  # Only the raised corners need writes; the rest of the room is level.
  for z in range(1,int(BOUNDS.size.y/STEP)):
   for x in range(1,int(BOUNDS.size.x/STEP)):
    var at=BOUNDS.position+Vector2(x,z)*STEP
    var sample=Vector2i(((at-Vector2(origin.x,origin.z))/STEP).round())
    heights[sample.y*width+sample.x]=vertex_height(at)
  navigation_grid={"width":width,"spacing":STEP,"origin":origin,"heights":heights,"covered":covered}
 data.merge(navigation_grid,true)

static func vertex_height(at:Vector2)->float:
 var from_edge=minf(at.x-BOUNDS.position.x,BOUNDS.end.x-at.x)
 from_edge=minf(from_edge,minf(at.y-BOUNDS.position.y,BOUNDS.end.y-at.y))
 return clampf(from_edge/STEP,0.0,1.0)*RISE

static func height(x:float,z:float)->float:
 var point=Vector2(x,z)
 if not BOUNDS.has_point(point):return 0.0
 var tile=(point-BOUNDS.position)/STEP
 var corner=BOUNDS.position+tile.floor()*STEP
 var uv=tile-tile.floor()
 var east=vertex_height(corner+Vector2.RIGHT*STEP)
 var south=vertex_height(corner+Vector2.DOWN*STEP)
 # Match the native terrain sampler's northeast-to-southwest triangle split.
 if uv.x+uv.y<=1.0:
  var west=vertex_height(corner)
  return west+(east-west)*uv.x+(south-west)*uv.y
 var far=vertex_height(corner+Vector2.ONE*STEP)
 return far+(south-far)*(1.0-uv.x)+(east-far)*(1.0-uv.y)

static func material()->ShaderMaterial:
 if paving==null:
  paving=ShaderMaterial.new()
  paving.shader=FLOOR_SHADER
  paving.set_shader_parameter("stone_grain",Fort.ROCK)
  paving.set_shader_parameter("dais_bounds",Vector4(BOUNDS.position.x,BOUNDS.position.y,BOUNDS.end.x,BOUNDS.end.y))
 return paving

static func build(parent:Node3D):
 if mesh==null:
  var surface=SurfaceTool.new()
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  var corners=[Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
  for z in int(BOUNDS.size.y/STEP):
   for x in int(BOUNDS.size.x/STEP):
    for corner:Vector2 in corners:
     var vertex=BOUNDS.position+(Vector2(x,z)+corner)*STEP
     surface.add_vertex(Vector3(vertex.x,vertex_height(vertex),vertex.y))
  surface.generate_normals()
  mesh=surface.commit()
 var node=Geo.mesh(parent,mesh,Vector3.ZERO,material(),true)
 node.name="ChamberRaisedDais"
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var lighting=Node3D.new()
 lighting.name="ChamberDaisLights"
 parent.add_child(lighting)
 for offset:Vector2 in [Vector2(-6,-4.5),Vector2(6,-4.5),Vector2(-6,4.5),Vector2(6,4.5)]:
  var point=BOUNDS.get_center()+offset+Vector2.LEFT*3.0
  light(lighting,point,2.1,Color("ffb772"),1.45,8.8)
 for point:Vector2 in [Vector2(-31.5,-10.5),Vector2(19.5,-10.5)]:
  light(lighting,point,1.55,Color("64e2df"),.95,13.0)

static func light(parent:Node3D,point:Vector2,lift:float,tint:Color,energy:float,reach:float):
 var lamp=OmniLight3D.new()
 lamp.position=Vector3(point.x,height(point.x,point.y)+lift,point.y)
 lamp.light_color=tint
 lamp.light_energy=energy
 lamp.omni_range=reach*parent.global_basis.get_scale().x
 lamp.omni_attenuation=1.35
 parent.add_child(lamp)
