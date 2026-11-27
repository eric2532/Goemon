extends RefCounted
## Source-composed Dragon Hourglass study. No route, actor or collision ownership.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Hours=preload("res://scripts/forest/forest_east_hourglasses.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const ROOT="res://assets/maps/falan/east_region/dragon_hourglass/"
const GLASSES=[[Vector2(92,332),148.,53.,198.,Color("d8a51b"),2.5],[Vector2(374,334),156.,54.,205.,Color("5844a6"),2.5],[Vector2(220,387),200.,20.,224.,Color("77a950"),2.8]]
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func point(pixel:Vector2,height:float,g:Dictionary)->Vector3:
 var native=pixel+Vector2(g.origin[0],g.origin[1]);var floor_y=native.y+height/.045
 return Vector3(native.x*3./64.-floor_y/16.,height,native.x*3./64.+floor_y/16.)
static func native_paint(model:Mesh,g:Dictionary,texture:Texture2D)->Mesh:
 var paint=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,.045)
 for slot in model.get_surface_count():
  var arrays:Array=model.get_meta("east_cpu_arrays")[slot] if model.has_meta("east_cpu_arrays") else model.surface_get_arrays(slot)
  var indices:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty();var count_:int=indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()
  for i in range(0,count_,3):
   var ids=[indices[i],indices[i+1],indices[i+2]] if indexed else [i,i+1,i+2]
   var normal:Vector3=(arrays[Mesh.ARRAY_NORMAL][ids[0]]+arrays[Mesh.ARRAY_NORMAL][ids[1]]+arrays[Mesh.ARRAY_NORMAL][ids[2]]).normalized()
   if normal.dot(Vector3(-1./16.,.045,1./16.).normalized())<.25:continue
   # Reuse the approved small-glass front hemisphere: upward normals alone
   # otherwise carry opaque frontal paint onto the unseen curved rear.
   if not g.broken and slot==0 and normal.dot(Vector3(-1,0,1))<.15:continue
   var bounded=true
   for index:int in ids:
    var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index]
    var pixel=-Vector2(g.origin[0],g.origin[1])+Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.-p.y/.045)
    bounded=bounded and Rect2(0,0,g.size[0],g.size[1]).has_point(pixel)
   if not bounded:continue
   for index:int in ids:
    var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index];paint.projected_vertex(p+normal*.004,normal,p)
 var overlay=paint.finish();var material=ShaderMaterial.new();material.shader=Hours.FRONT_SHADER;material.set_shader_parameter("base_texture",texture);overlay.surface_set_material(0,material)
 return East.combine([model,overlay])
static func glass_profile(radius:float,height:float,waist:float)->Array:
 return [Vector2(radius,0),Vector2(radius*.99,height*.08),Vector2(radius*.90,height*.19),Vector2(radius*.61,waist*.76),Vector2(radius*.19,waist*.94),Vector2(radius*.065,waist),Vector2(radius*.19,waist+(height-waist)*.06),Vector2(radius*.61,waist+(height-waist)*.26),Vector2(radius*.9,waist+(height-waist)*.56),Vector2(radius*.99,waist+(height-waist)*.83),Vector2(radius,height)]
static func shattered_glass(shell:Mesh,g:Dictionary,texture:Texture2D,center:Vector3,color:Color)->Mesh:
 # Thin broken glass follows original alpha on the curved envelope. Hidden
 # circumference continues only its edge pattern, with independent glass color.
 var front=Furniture.tool();var back=Furniture.tool();var arrays:Array=shell.get_meta("east_cpu_arrays")[0]
 var indices:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty();var count_:int=indices.size()if indexed else arrays[Mesh.ARRAY_VERTEX].size();var axis=Vector3(-1,0,1).normalized()
 for i in range(0,count_,3):
  var ids=[indices[i],indices[i+1],indices[i+2]]if indexed else[i,i+1,i+2]
  var normal:Vector3=(arrays[Mesh.ARRAY_NORMAL][ids[0]]+arrays[Mesh.ARRAY_NORMAL][ids[1]]+arrays[Mesh.ARRAY_NORMAL][ids[2]]).normalized()
  if absf(normal.y)>.97:continue
  var observed=normal.dot(axis)>=0.;var target=front if observed else back
  for index:int in ids:
   var point:Vector3=arrays[Mesh.ARRAY_VERTEX][index];var sample=point if observed else point-axis*(2.*(point-center).dot(axis))
   var uv=(-Vector2(g.origin[0],g.origin[1])+Vector2((sample.x+sample.z)*32./3.,(sample.z-sample.x)*8.-sample.y/.045))/Vector2(g.size[0],g.size[1])
   target.set_normal(arrays[Mesh.ARRAY_NORMAL][index]);target.set_uv(uv);target.add_vertex(point)
 var visible=front.commit();var source_paint=ShaderMaterial.new();source_paint.shader=Hours.FRONT_SHADER;source_paint.set_shader_parameter("base_texture",texture);visible.surface_set_material(0,source_paint)
 var hidden=back.commit();var tint=ShaderMaterial.new();tint.shader=preload("res://scripts/forest/forest_east_hourglass_back.gdshader");tint.set_shader_parameter("native_mask",texture);tint.set_shader_parameter("glass_color",Color(color.lightened(.25),.08));hidden.surface_set_material(0,tint)
 tint.set_shader_parameter("maximum_opacity",.10)
 return East.combine([visible,hidden])
static func frieze_material()->Material:
 var paint=StandardMaterial3D.new();paint.albedo_texture=load(ROOT+"frieze-tile.png");paint.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;paint.roughness=.85;return paint
static func mesh(source:int)->Mesh:
 if meshes.has(source):return meshes[source]
 var g:Dictionary=data().maps[str(source)];var native:Texture2D=load(ROOT+str(source)+"-form.png");var floor_texture:Texture2D=load(ROOT+str(source)+"-ground.png")
 var floor_skin=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],floor_texture,.045)
 var pixels=[Vector2.ZERO,Vector2(g.size[0],0),Vector2(g.size[0],g.size[1]),Vector2(0,g.size[1])]
 for index in [0,1,2,0,2,3]:
  floor_skin.surface.set_normal(Vector3.UP);floor_skin.surface.set_uv(pixels[index]/Vector2(g.size[0],g.size[1]));floor_skin.surface.add_vertex(point(pixels[index],.025,g))
 var parts=[floor_skin.finish()];var white=Fort.material(Color("bdcddb"),false);var rim=Fort.material(Color("d4cbb0"),false);var frieze=frieze_material()
 var core_offset=Vector2(512,6);var landmark_bounds=AABB();var first=true
 for spec in GLASSES:
  var base_pixel:Vector2=spec[0];var radius=float(spec[1])/(2.*sqrt(2.)*32./3.);var height=(base_pixel.y-float(spec[2]))*.045;var base_y:float=spec[5]
  var center=point(base_pixel+core_offset,base_y,g);var waist=(base_pixel.y-float(spec[3]))*.045
  var local=[];var glass_material=Hours.glass(spec[4],.10)
  # The giant bulb's fill opacity is independent of its grazing rim opacity.
  glass_material.set_shader_parameter("glass_color",Color(spec[4].lightened(.25),.08))
  var body=Hours.lathe(glass_profile(radius,height,waist),glass_material,48,true)
  if g.broken:
   var shell=East.transformed_existing(body,Transform3D(Basis.IDENTITY,center));parts.append(shattered_glass(shell,g,native,center,spec[4]))
  else:local.append(body)
  local.append(Hours.lathe([Vector2(radius*.98,-1.25),Vector2(radius*1.08,-1.15),Vector2(radius*1.08,-.22),Vector2(radius*1.13,-.10),Vector2(radius*1.13,.04)],frieze))
  local.append(Hours.lathe([Vector2(radius*1.01,-.03),Vector2(radius*1.08,.05),Vector2(radius*1.08,.16),Vector2(radius*1.01,.24)],rim))
  local.append(Hours.lathe([Vector2(radius*1.01,height-.08),Vector2(radius*1.1,height),Vector2(radius*1.1,height+.85),Vector2(radius*1.01,height+1.02)],frieze))
  var ornaments=Furniture.tool();Furniture.Parts.prepare_primitives()
  for spire in 12:
   var angle=spire*TAU/12.;var axis=Vector3(cos(angle),0,sin(angle));var at=axis*radius*1.04+Vector3.UP*(height+.84)
   var high=1.25 if spire%3==0 else .85;var tangent=Vector3(-axis.z,0,axis.x)
   Furniture.Parts.rod(ornaments,at,at+Vector3.UP*high,radius*.020)
   Furniture.Parts.oval(ornaments,at+Vector3.UP*high,Vector3(radius*.055,.32,radius*.055))
   for side in [-1,1]:
    var old=at+Vector3.UP*high*.38
    for step in range(1,9):
     var t=step/8.;var next=at+tangent*side*radius*.11*sin(t*PI*.75)+Vector3.UP*(high*.38+high*.48*t)
     Furniture.Parts.rod(ornaments,old,next,radius*.015);old=next
  # Source-confirmed round construction continues around the unseen rim.
  var carving=ornaments.commit();carving.surface_set_material(0,white);local.append(carving)
  if spec==GLASSES[-1]:
   var feet=Furniture.tool()
   for side in 3:
    var angle=PI*.25+side*TAU/3.;var axis=Vector3(cos(angle),0,sin(angle));var old=axis*radius*.55+Vector3.UP*(-1.12)
    for step in range(1,25):
     var t=step/24.;var r=radius*(.55+.75*sin(t*PI*.72));var y=-1.12-(base_y-1.1)*sin(t*PI*.72)+.45*pow(t,4);var next=axis*r+Vector3.UP*y
     Furniture.Parts.rod(feet,old,next,.35*(1.-t)+.15);old=next
   var supports=feet.commit();supports.surface_set_material(0,white);local.append(supports)
  var form=East.transformed_existing(East.combine(local),Transform3D(Basis.IDENTITY,center));parts.append(native_paint(form,g,native))
  landmark_bounds=form.get_aabb() if first else landmark_bounds.merge(form.get_aabb());first=false
 var result=East.combine(parts);result.set_meta("east_dragon_hourglass",source);result.set_meta("source_background_placements",g.source_components.size());result.set_meta("native_composite_rgba_sha256",g.native_rgba_sha256);result.set_meta("inferred_hidden_depth",true);result.set_meta("hourglass_bounds",landmark_bounds);meshes[source]=result
 return result
