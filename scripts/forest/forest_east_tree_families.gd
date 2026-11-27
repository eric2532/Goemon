extends RefCounted
## Existing whole tree masters or source-traced limbs; called only at map setup.
const Base=preload("res://scripts/forest/forest_east_region_art.gd")

static func mesh(g:Dictionary,spec:Dictionary)->Mesh:
 if spec.kind=="seasonal_tree":return seasonal(g,spec)
 if spec.kind=="native_canopy_tree":return native_canopy(g,spec)
 return native_branches(g,spec)

static func seasonal(g:Dictionary,spec:Dictionary)->Mesh:
 var row:Dictionary=g.duplicate(true);row.cut=[spec.source_serial]
 var reference:Mesh=Base.Elsa.fitted_model(spec.asset,row,Rect2(spec.visible[0],spec.visible[1],spec.visible[2]-spec.visible[0],spec.visible[3]-spec.visible[1]))
 reference=Base.transformed_existing(reference,Transform3D.IDENTITY)
 var leaves:Texture2D=load(str(spec.get("texture_root",Base.ROOT))+str(int(spec.graphic_id))+"-leaves.png")
 for slot in reference.get_surface_count():
  var material:Material=reference.surface_get_material(slot)
  if material is ShaderMaterial and material.shader==Base.Meadow.WIND:
   material=material.duplicate();material.set_shader_parameter("source_paint",leaves);material.set_shader_parameter("foliage_tint",Vector3.ONE)
   reference.surface_set_material(slot,material)
 if spec.get("detail_boxes",[]).is_empty():return reference
 var detail_g:Dictionary=g.duplicate(true);detail_g.rect=[0,0,g.rect[2],g.rect[3]]
 var details=Base.native_skin(detail_g,load(str(spec.get("texture_root",Base.ROOT))+str(int(spec.graphic_id))+"-details.png"))
 var ray=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized()
 for box in spec.detail_boxes:
  var pixel=Vector2((box[0]+box[2])*.5,(box[1]+box[3])*.5);var origin=Base.projected(pixel,g,0.,float(spec.ground_offset))+ray*200.
  var nearest=INF;var hit:Variant=null
  for arrays:Array in reference.get_meta("east_cpu_arrays"):
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
   var count=indices.size() if indices is PackedInt32Array and not indices.is_empty() else vertices.size()
   for index in range(0,count,3):
    var a=vertices[indices[index] if indices is PackedInt32Array and not indices.is_empty() else index]
    var b=vertices[indices[index+1] if indices is PackedInt32Array and not indices.is_empty() else index+1]
    var c=vertices[indices[index+2] if indices is PackedInt32Array and not indices.is_empty() else index+2]
    var candidate=Geometry3D.ray_intersects_triangle(origin,-ray,a,b,c)
    if candidate!=null and origin.distance_squared_to(candidate)<nearest:nearest=origin.distance_squared_to(candidate);hit=candidate
  var ground=float(spec.ground_offset) if hit==null else (hit.z-hit.x)*8.
  var points=[]
  for corner in [Vector2(box[0],box[1]),Vector2(box[0],box[3]),Vector2(box[2],box[3]),Vector2(box[2],box[1])]:points.append(Base.projected(corner,g,0.,ground)+ray*.035)
  Base.painted_quad(details,points[0],points[1],points[2],points[3])
 return Base.combine([reference,details.finish()])

static func branch_point(pixel:Vector2,g:Dictionary,spec:Dictionary)->Vector3:
 var ray=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized()
 var depth=sin(pixel.x/float(g.rect[2])*PI)*sin(pixel.y/float(g.rect[3])*PI)*float(spec.branch_depth)
 return Base.projected(pixel,g,0.,float(spec.ground_offset))+ray*depth

static func native_branches(g:Dictionary,spec:Dictionary)->Mesh:
 var wood=Base.structure();var ray=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized()
 var endpoints={}
 for path in spec.branches:
  for p in [path[0],path[-1]]:
   var key=Vector2i(p[0],p[1]);endpoints[key]=int(endpoints.get(key,0))+1
 for path in spec.branches:
  for index in path.size()-1:
   var a:Array=path[index];var b:Array=path[index+1]
   var radius_a=maxf(.035,float(a[2])/(Base.Fit.HORIZONTAL*sqrt(2.)));var radius_b=maxf(.035,float(b[2])/(Base.Fit.HORIZONTAL*sqrt(2.)))
   tapered_limb(wood,branch_point(Vector2(a[0],a[1]),g,spec),branch_point(Vector2(b[0],b[1]),g,spec),radius_a,radius_b,index==0 and endpoints[Vector2i(a[0],a[1])]==1,index==path.size()-2 and endpoints[Vector2i(b[0],b[1])]==1)
 var rods:Mesh=wood.finish();var material:ShaderMaterial=rods.surface_get_material(0).duplicate()
 material.set_shader_parameter("surface_kind",4.0);material.set_shader_parameter("use_base_texture",false);material.set_shader_parameter("original_palette",false)
 material.set_shader_parameter("base_color",Color(float(spec.bark_color[0])/255.,float(spec.bark_color[1])/255.,float(spec.bark_color[2])/255.).srgb_to_linear());rods.surface_set_material(0,material)
 var fine_g:Dictionary=g.duplicate(true);fine_g.rect=[0,0,g.rect[2],g.rect[3]]
 var paint:Texture2D=load(str(spec.get("texture_root",Base.ROOT))+str(int(spec.graphic_id))+"-branches.png")
 var native=Base.native_skin(fine_g,paint)
 var arrays:Array=rods.get_meta("east_cpu_arrays")[0];var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 for index in range(0,vertices.size(),3):
  if normals[index].dot(ray)<=0.:continue
  for offset in 3:native.projected_vertex(vertices[index+offset]+normals[index+offset]*.012,normals[index+offset],vertices[index+offset])
 var fine=Base.native_skin(fine_g,paint)
 var w=int(g.rect[2]);var h=int(g.rect[3])
 for y in range(0,h,8):
  for x in range(0,w,8):
   var points=[]
   for pixel in [Vector2(x,y),Vector2(x,mini(y+8,h)),Vector2(mini(x+8,w),mini(y+8,h)),Vector2(mini(x+8,w),y)]:points.append(branch_point(pixel,g,spec)+ray*.018)
   var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
   for index in [0,1,2,0,2,3]:fine.projected_vertex(points[index],normal,points[index])
   for index in [3,2,0,2,1,0]:fine.projected_vertex(points[index]-ray*.012,-normal,points[index])
 return Base.combine([rods,native.finish(),fine.finish()])

static func tapered_limb(wood,a:Vector3,b:Vector3,low_radius:float,high_radius:float,cap_low:bool,cap_high:bool):
 # Reuse the cached12-sided timber cylinder's exact rings/UVs. Junctions stay open;
 # only actual free ends are capped, removing the stacked discs between source branches.
 var delta=b-a;var length=delta.length()
 if length<.0001:return
 if Base.rod_arrays.is_empty():
  Base.Harbor.Parts.prepare_primitives();Base.rod_arrays=Base.Harbor.Parts.cylinder.surface_get_arrays(0)
 var arrays:Array=Base.rod_arrays;var basis=Basis(Quaternion(Vector3.UP,delta/length));var center=(a+b)*.5
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for offset in range(0,indices.size(),3):
  var cap_normal:Vector3=arrays[Mesh.ARRAY_NORMAL][indices[offset]]
  if cap_normal.y<-.5 and not cap_low or cap_normal.y>.5 and not cap_high:continue
  for corner in 3:
   var index=indices[offset+corner];var vertex:Vector3=arrays[Mesh.ARRAY_VERTEX][index];var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][index]
   var radius=lerpf(low_radius,high_radius,vertex.y+.5)
   if absf(normal.y)<.5:normal=Vector3(normal.x,(low_radius-high_radius)/length,normal.z).normalized()
   wood.surface.set_normal(basis*normal);wood.surface.set_uv(arrays[Mesh.ARRAY_TEX_UV][index]);wood.surface.set_uv2(wood.tiles.bark)
   wood.surface.add_vertex(center+basis*Vector3(vertex.x*radius*2.,vertex.y*length,vertex.z*radius*2.))

static func native_canopy(g:Dictionary,spec:Dictionary)->Mesh:
 var wood=native_branches(g,spec)
 var paint:Texture2D=load(str(spec.get("texture_root",Base.ROOT))+str(int(spec.graphic_id))+"-foliage.png")
 var leaves=Base.foliage(g,paint,[0,0,g.rect[2],g.rect[3]],float(spec.ground_offset),Base.v(spec.crown_junction))
 return Base.combine([wood,leaves])
