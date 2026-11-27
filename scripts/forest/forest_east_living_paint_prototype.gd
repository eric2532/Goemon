extends RefCounted
## Private source-layer prototype. Canonical277data/native artwork are untouched.
const Base=preload("res://scripts/forest/forest_east_region_art.gd")
const ROOT="res://assets/maps/falan/east_region/living_house_paint/"
static var prepared:Mesh
static func axis_at(g:Dictionary,trunk:Dictionary,height:float)->Vector3:
 var level=float(trunk.get("level_pixels",0))/Base.Fit.VERTICAL;var end=float(trunk.height_pixels)/Base.Fit.VERTICAL+level
 var fraction=clampf((height-level)/maxf(.001,end-level),0.,1.);var trace:Array=trunk.trace
 var y=lerpf(float(trace[0][1]),float(trace[-1][1]),fraction)
 for index in trace.size()-1:
  var a:Array=trace[index];var b:Array=trace[index+1]
  if y<=float(a[1]) and y>=float(b[1]):return Base.point(Vector2(lerpf(float(a[0]),float(b[0]),inverse_lerp(float(a[1]),float(b[1]),y)),y),height,g)
 return Base.point(Base.v(trunk.base),height,g)
static func coherent_bark(reference:Mesh,g:Dictionary,trunk:Dictionary)->Mesh:
 var result=ArrayMesh.new();var retained=[];var radius=float(trunk.diameter)/(2.*Base.Fit.HORIZONTAL*sqrt(2.))
 for slot in reference.get_surface_count():
  var arrays:Array=reference.get_meta("east_cpu_arrays")[slot].duplicate(true);var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var tiles:Variant=arrays[Mesh.ARRAY_TEX_UV2]
  if tiles is PackedVector2Array and not tiles.is_empty():
   for start in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
    if tiles[start]!=Base.Surfaces.TILES.living_bark:continue
    var angles=[]
    for corner in 3:
     var p:Vector3=arrays[Mesh.ARRAY_VERTEX][start+corner];var center=axis_at(g,trunk,p.y);angles.append(atan2(p.z-center.z,p.x-center.x))
    var seam=float(angles.max())-float(angles.min())>PI
    for corner in 3:
     var angle=float(angles[corner]);var p:Vector3=arrays[Mesh.ARRAY_VERTEX][start+corner]
     if seam and angle<0.:angle+=TAU
     uv[start+corner]=Vector2(angle*radius/2.6,-p.y/2.6)
   arrays[Mesh.ARRAY_TEX_UV]=uv
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(slot,reference.surface_get_material(slot));retained.append(arrays)
 result.set_meta("east_cpu_arrays",retained);return result
static func roof_only(reference:Mesh,minimum_y:float)->Mesh:
 var result=ArrayMesh.new();var retained=[]
 for slot in reference.get_surface_count():
  var arrays:Array=reference.get_meta("east_cpu_arrays")[slot];var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);var count=0
  for start in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
   var roof=true
   for corner in 3:roof=roof and arrays[Mesh.ARRAY_VERTEX][start+corner].y>=minimum_y-.001
   if not roof:continue
   for corner in 3:
    var at=start+corner;tool.set_normal(arrays[Mesh.ARRAY_NORMAL][at]);tool.set_uv(arrays[Mesh.ARRAY_TEX_UV][at])
    if arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array and not arrays[Mesh.ARRAY_TEX_UV2].is_empty():tool.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][at])
    tool.add_vertex(arrays[Mesh.ARRAY_VERTEX][at]);count+=1
  if count==0:continue
  var built=Base.Source.committed_arrays(tool.commit_to_arrays());result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,built);result.surface_set_material(result.get_surface_count()-1,reference.surface_get_material(slot));retained.append(built)
 result.set_meta("east_cpu_arrays",retained);return result
static func mesh()->Mesh:
 if prepared!=null:return prepared
 var g:Dictionary=Base.Art.data().graphics["1230040"];var spec:Dictionary=Base.data().graphics["1230040"].duplicate(true)
 var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"));var houses:Array=spec.houses;spec.houses=[]
 for trunk:Dictionary in spec.trunks:
  var level=float(trunk.get("level_pixels",0.))
  if level<=0.:continue
  var first:Array=trunk.trace[0];trunk.base=[trunk.base[0],float(trunk.base[1])+level];trunk.height_pixels=float(trunk.height_pixels)+level;trunk.level_pixels=0
  trunk.trace=[[first[0],float(first[1])+level,1.80],[first[0],float(first[1])+level*.5,1.55]]+trunk.trace
 var rest:Dictionary=spec.duplicate(true);rest.trunks=[];rest.crowns=[];rest.crown_anchors=[]
 var parts=[Base.compound(g,rest),Base.crown_branches(g,spec)]
 for trunk:Dictionary in spec.trunks:parts.append(coherent_bark(Base.living_tree_body(g,trunk),g,trunk))
 for index in spec.crowns.size():parts.append(Base.foliage(g,load(Base.ROOT+"1230040-crown-"+str(index)+".png"),spec.crowns[index],float(spec.crown_ground_pixels[index]),Base.v(spec.crown_anchors[index])))
 for index in houses.size():
  var house:Dictionary=houses[index];house.wall="living_bark"
  var shape:Mesh=roof_only(Base.house(g,house),(float(house.get("level_pixels",0))+float(house.wall_pixels))/Base.Fit.VERTICAL);var result=ArrayMesh.new();var retained=[]
  for slot in shape.get_surface_count():
   var arrays:Array=shape.get_meta("east_cpu_arrays")[slot].duplicate(true)
   if slot==0:
    var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var texture_size=Base.texture(g).get_size()
    for at in uv.size():uv[at]=(uv[at]*texture_size-Vector2(g.rect[0],g.rect[1]))/Vector2(g.rect[2],g.rect[3])
    arrays[Mesh.ARRAY_TEX_UV]=uv
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);retained.append(arrays)
   var material:Material=shape.surface_get_material(slot)
   if slot==0:material=Base.Source.material(load(ROOT+metadata.houses[index].file))
   elif material is ShaderMaterial and material.get_shader_parameter("base_texture")==Base.Atlas:
    material=material.duplicate();material.set_shader_parameter("base_texture",load(ROOT+"surfaces.png"))
   result.surface_set_material(slot,material)
  result.set_meta("east_cpu_arrays",retained);parts.append(result)
  var hub:Dictionary=metadata.root_hubs[index].duplicate(true);hub.material="living_bark";hub.profile=[[0,1.05],[.16,1.08],[.4,.97],[.67,.76],[.85,.60],[1.,.45]]
  var body:Mesh=Base.round_body(g,hub);var hub_mesh=ArrayMesh.new();var hub_arrays=[]
  for slot in body.get_surface_count():
   var arrays:Array=body.get_meta("east_cpu_arrays")[slot].duplicate(true);var material:Material=body.surface_get_material(slot)
   if slot==0:
    var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var page=Base.texture(g).get_size()
    for at in uv.size():uv[at]=(uv[at]*page-Vector2(g.rect[0],g.rect[1]))/Vector2(g.rect[2],g.rect[3])
    arrays[Mesh.ARRAY_TEX_UV]=uv;material=Base.Source.material(load(ROOT+metadata.houses[index].feature_file))
   hub_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);hub_mesh.surface_set_material(slot,material);hub_arrays.append(arrays)
  hub_mesh.set_meta("east_cpu_arrays",hub_arrays)
  var hub_axis={"base":hub.base,"level_pixels":hub.level_pixels,"height_pixels":hub.height_pixels,"diameter":hub.diameter,"trace":[[hub.base[0],hub.base[1],1.],[hub.base[0],float(hub.base[1])-float(hub.height_pixels),1.]]}
  parts.append(coherent_bark(hub_mesh,g,hub_axis))
  var roots=Base.structure();roots.part="living_bark";var foot=Base.point(Base.v(spec.trunks[index].base),0.,g);var high_center=Base.point(Base.v(hub.base),float(hub.level_pixels)/Base.Fit.VERTICAL,g);var radius=float(hub.diameter)/(2.*Base.Fit.HORIZONTAL*sqrt(2.))
  for side in 8:
   var radial=Vector3(cos(side*TAU/8.),0,sin(side*TAU/8.));var high=high_center+radial*radius*.8+Vector3.UP*.5;var low=foot.lerp(Vector3(high.x,0,high.z),.75)
   Base.root_buttress(roots,[low,low.lerp(high,.5)+radial*.4,high],[.72,.56,.38])
  parts.append(Base.bark_finish(roots))
 for flag:Dictionary in metadata.flags:
  var box:Array=flag.box;var row:Dictionary=g.duplicate(true);row.rect=[0,0,box[2]-box[0],box[3]-box[1]];row.origin=[g.origin[0]+box[0],g.origin[1]+box[1]]
  var skin=Base.native_skin(row,load(ROOT+flag.file));var points=[]
  for pixel in [Vector2(box[0],box[1]),Vector2(box[2],box[1]),Vector2(box[2],box[3]),Vector2(box[0],box[3])]:points.append(Base.projected(pixel,g,0.,float(flag.ground)))
  var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for at in [0,1,2,0,2,3]:skin.projected_vertex(points[at],normal,points[at])
  for at in [3,2,1,3,1,0]:skin.projected_vertex(points[at]-normal*.015,-normal,points[at])
  parts.append(skin.finish())
 prepared=Base.owner_frame(Base.combine(parts));return prepared
