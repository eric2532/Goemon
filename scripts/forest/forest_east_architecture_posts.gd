extends RefCounted
## Native weather vanes are closed thin metal above real round posts, not sprite boxes.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Lamps=preload("res://scripts/forest/forest_falan_lamps.gd")
const Round=preload("res://scripts/forest/forest_coastal_buildings.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")

static func paint_triangles(base,front,mesh:Mesh,pose:Transform3D):
 var arrays=mesh.surface_get_arrays(0);var indices=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty()
 for j in (indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()):
  var i=indices[j] if indexed else j;var p:Vector3=pose*arrays[Mesh.ARRAY_VERTEX][i];var n:Vector3=(pose.basis*arrays[Mesh.ARRAY_NORMAL][i]).normalized()
  base.surface.set_normal(n);base.surface.set_uv2(base.tiles.metal);base.surface.set_uv(Vector2(p.x+p.z,-p.y)/.8);base.surface.add_vertex(p)
  if n.dot(Vector3(-1,0,1))>.01:front.projected_vertex(p+n*.005,n,p)

static func full_lamp(g:Dictionary,texture:Texture2D)->Mesh:
 var raw=Lamps.shape(int(g.serial));var b:Array=g.visible
 var target=Rect2(Vector2(g.origin[0]+b[0],g.origin[1]+b[1]),Vector2(b[2]-b[0],b[3]-b[1]))
 var pose=Fit.measure(Fit.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),target)
 var result=Fit.transformed(raw,Transform3D(Basis.IDENTITY.scaled(Vector3(1,.045*Fit.VERTICAL,1)),Vector3.ZERO)*pose)
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,.045)
 for slot in result.get_surface_count():
  var arrays=result.surface_get_arrays(slot);var indices=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty()
  for j in (indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()):
   var i=indices[j] if indexed else j;var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var n:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
   if n.dot(Vector3(-1,0,1))>.01:front.projected_vertex(p+n*.005,n,p)
 var native=front.finish();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,native.surface_get_arrays(0));result.surface_set_material(result.get_surface_count()-1,native.surface_get_material(0))
 return result

static func mesh(g:Dictionary,texture:Texture2D,materials:Texture2D)->Mesh:
 if g.style=="whole_lamp":return full_lamp(g,texture)
 var base=Source.new([],materials,.045);base.tiles={"metal":Vector2.ZERO};base.part="metal";base.pitches={"metal":.8}
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,.045)
 # Reuse the existing16-sided coastal ring primitive for the measured native shaft/base.
 var rings=[]
 for row:Array in g.profile:rings.append(Vector2(row[0],row[1]))
 var center=Vector3(g.center[0],0,g.center[1]);var core=Source.new([],materials,.045);core.tiles=base.tiles;core.part="metal";core.pitches=base.pitches
 Round.kili_round(core,center,rings)
 for top in [false,true]:
  var row:Vector2=rings[-1] if top else rings[0];var p=center+Vector3.UP*row.y
  for side in 16:
   var a=side*TAU/16.;var b=(side+1)*TAU/16.;var u=p+Vector3(cos(a)*row.x,0,sin(a)*row.x);var v=p+Vector3(cos(b)*row.x,0,sin(b)*row.x)
   core.quad(p,u,v,v) if top else core.quad(p,v,u,u)
 paint_triangles(base,front,core.finish(),Transform3D.IDENTITY)
 # Row runs preserve native holes in cut metal, including crescents and crossed arrows.
 # Each run has front/back and closed edges; the back uses the existing lamp metal shader at measured native color.
 for run:Array in g.ornament_runs:
  var outline=PackedVector2Array();var plane=float(center.z)+.06
  for pixel in [Vector2(run[0],run[2]+1),Vector2(run[1],run[2]+1),Vector2(run[1],run[2]),Vector2(run[0],run[2])]:
   var x=(pixel.x+float(g.origin[0]))/(32./3.)-plane
   var y=((plane-x)*8.-pixel.y-float(g.origin[1]))*.045;outline.append(Vector2(x,y))
  paint_triangles(base,front,Shapes.extrude(outline,.08),Transform3D(Basis.IDENTITY,Vector3(0,0,plane-.04)))
 if Lamps.metal_paint==null:Lamps.shape(10424)
 var result=base.finish();var backing:ShaderMaterial=Lamps.metal_paint.duplicate()
 backing.set_shader_parameter("base_color",Color(g.metal_rgb[0],g.metal_rgb[1],g.metal_rgb[2]));result.surface_set_material(0,backing)
 var native=front.finish();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,native.surface_get_arrays(0));result.surface_set_material(1,native.surface_get_material(0))
 return result
