extends RefCounted
## Private measured leaf-cloud derivative of the existing whole Meadow canopy.
## Repose intact leaf quads from source pixels; no whole-front plane or photo wrap.
const Native=preload("res://scripts/forest/forest_east_native_trees.gd")
const Base=Native.Base
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Tree Leaf Only Candidate/"
static var result:Mesh
static func mesh(serial:int)->Mesh:
 assert(serial==10074,"One source crown prototype before extending any family")
 if result!=null:return result
 Base.Art.load_east();var g:Dictionary=Base.Art.data().graphics[str(serial)];var spec:Dictionary=Native.data().graphics[str(serial)];var master_parts=[]
 for part:Dictionary in Base.Meadow.source(spec.asset):
  if part.name=="Canopy":master_parts.append(Base.transformed_existing(part.mesh,part.transform,part.material))
 var master:Mesh=Base.combine(master_parts);assert(master.get_surface_count()==1)
 var raw:Array=master.get_meta("east_cpu_arrays")[0];var arrays:Array=raw.duplicate(true);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 assert(vertices.size()%4==0 and colors.size()==vertices.size())
 var original:Image=Image.load_from_file(ROOT+"10074-native.png");var leaves:Image=Image.load_from_file(Native.ROOT+"10074-foliage.png");var samples=[];var spans={}
 # The original visible wood begins at235; lower olive bark is not canopy.
 for y in range(0,235):
  var left=100000;var right=-1
  for x in original.get_width():
   if leaves.get_pixel(x,y).a<.9:continue
   left=mini(left,x);right=maxi(right,x)
   if x%2==0 and y%2==0:samples.append(Vector2(x,y))
  if right>=left:spans[y]=Vector2(left,right)
 assert(samples.size()>1000)
 var ray=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized();var depths=[];var deepest=.001
 for at in range(0,vertices.size(),4):
  var center=(vertices[at]+vertices[at+1]+vertices[at+2]+vertices[at+3])*.25;var depth=center.z;depths.append(depth);deepest=maxf(deepest,absf(depth))
 var patch:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source.json")).leaf_patch;var mean=Vector3(patch.mean_linear[0],patch.mean_linear[1],patch.mean_linear[2]);var gain=Vector3.ONE;var quad_count=vertices.size()/4;var projection_error=0.
 for quad in quad_count:
  var at=quad*4;var center=(vertices[at]+vertices[at+1]+vertices[at+2]+vertices[at+3])*.25;var pixel:Vector2=samples[int(quad*samples.size()/quad_count)];var span:Vector2=spans[int(pixel.y)];var axis=(span.x+span.y)*.5;var radius=maxf(1.,(span.y-span.x)*.5)
  var depth=sqrt(maxf(0.,radius*radius-(pixel.x-axis)*(pixel.x-axis)))/(sqrt(2.)*Base.Fit.HORIZONTAL)*float(depths[quad])/deepest
  var target=Base.projected(pixel,g,0.,float(spec.ground_offset))+ray*depth
  var projected=Vector2((target.x+target.z)*Base.Fit.HORIZONTAL,(target.z-target.x)*Base.Fit.FLOOR-target.y*Base.Fit.VERTICAL)-Vector2(g.origin[0],g.origin[1]);projection_error=maxf(projection_error,projected.distance_to(pixel))
  var colour=original.get_pixelv(Vector2i(pixel)).srgb_to_linear();var target_tint=Vector3(colour.r,colour.g,colour.b)/mean;gain=Vector3(maxf(gain.x,target_tint.x),maxf(gain.y,target_tint.y),maxf(gain.z,target_tint.z))
  # Intact existing leaf quads keep their UV/index topology and material;
  # their pose/depth and source palette are the explicit reconstruction.
  var yaw=(float(depths[quad])/deepest)*.45;var turn=Basis(Vector3.UP,yaw)
  for j in 4:
   vertices[at+j]=target+turn*(vertices[at+j]-center)*.90;normals[at+j]=(turn*normals[at+j]).normalized();colors[at+j]=Color(target_tint.x,target_tint.y,target_tint.z,1.)
   assert(vertices[at+j].is_finite()and normals[at+j].is_finite())
 for i in colors.size():
  colors[i]=Color(colors[i].r/gain.x,colors[i].g/gain.y,colors[i].b/gain.z,1.)
  assert(colors[i].r<=1. and colors[i].g<=1. and colors[i].b<=1.)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
 assert(projection_error<.0001 and arrays[Mesh.ARRAY_INDEX]==raw[Mesh.ARRAY_INDEX]and arrays[Mesh.ARRAY_TEX_UV]==raw[Mesh.ARRAY_TEX_UV])
 var cloud=ArrayMesh.new();cloud.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);cloud.set_meta("east_cpu_arrays",[arrays]);var leaf_image=Image.load_from_file(ROOT+"leaf-paint.png");leaf_image.generate_mipmaps()
 var paint=ShaderMaterial.new();paint.shader=Base.Meadow.WIND;paint.set_shader_parameter("tree",true);paint.set_shader_parameter("canopy",true);paint.set_shader_parameter("strength",.025);paint.set_shader_parameter("use_source_paint",true);paint.set_shader_parameter("source_paint",ImageTexture.create_from_image(leaf_image));paint.set_shader_parameter("source_cutout",true);paint.set_shader_parameter("foliage_tint",gain);cloud.surface_set_material(0,paint)
 result=Base.owner_frame(Base.combine([Native.Traced.native_branches(g,spec),cloud]));result.set_meta("private_source_leaf_cloud",serial);result.set_meta("source_leaf_samples",samples.size());result.set_meta("reused_leaf_quads",quad_count);result.set_meta("leaf_sample_projection_error",projection_error);result.set_meta("leaf_only_bottom",235);result.set_meta("no_source_photo_overlay",true);result.set_meta("uv_and_index_preserved",true);result.set_meta("leaf_color_uniform_gain",gain);return result
