extends RefCounted
## Round glass/cap parts shared by the native ceremonial and giant-hourglass studies.
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const ROOT="res://assets/maps/falan/east_region/hourglasses/"
const IDS=[1235180,1235181,1235182]
const FRONT_SHADER=preload("res://scripts/forest/forest_east_hourglass_front.gdshader")
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static func owns(serial:int)->bool:return serial in IDS
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func lathe(profile:Array,material:Material,segments:int=48,smooth:bool=false)->Mesh:
 var surface=Furniture.tool();var maximum_radius=0.
 for ring:Vector2 in profile:maximum_radius=maxf(maximum_radius,ring.x)
 for level in profile.size()-1:
  var lo:Vector2=profile[level];var hi:Vector2=profile[level+1]
  var slope=(hi.x-lo.x)/maxf(.00001,hi.y-lo.y)
  var previous:Vector2=profile[maxi(0,level-1)];var next:Vector2=profile[mini(profile.size()-1,level+2)]
  var low_slope=(hi.x-previous.x)/maxf(.00001,hi.y-previous.y)if smooth else slope
  var high_slope=(next.x-lo.x)/maxf(.00001,next.y-lo.y)if smooth else slope
  for side in segments:
   var a=-side*TAU/segments;var b=-(side+1)*TAU/segments
   var points=[Vector3(cos(a)*lo.x,lo.y,sin(a)*lo.x),Vector3(cos(a)*hi.x,hi.y,sin(a)*hi.x),Vector3(cos(b)*hi.x,hi.y,sin(b)*hi.x),Vector3(cos(b)*lo.x,lo.y,sin(b)*lo.x)]
   for index in [0,1,2,0,2,3]:
    var p:Vector3=points[index];var normal_slope=low_slope if index in[0,3]else high_slope
    surface.set_normal(Vector3(p.x,-normal_slope*sqrt(p.x*p.x+p.z*p.z),p.z).normalized());surface.set_uv(Vector2(atan2(p.z,p.x)*maximum_radius/1.8,(p.y-profile[0].y)/1.35));surface.add_vertex(p)
 for top in [false,true]:
  var ring:Vector2=profile[-1] if top else profile[0];var center=Vector3.UP*ring.y
  for side in segments:
   var a=side*TAU/segments;var b=(side+1)*TAU/segments
   var p=center+Vector3(cos(a)*ring.x,0,sin(a)*ring.x);var q=center+Vector3(cos(b)*ring.x,0,sin(b)*ring.x)
   surface.set_normal(Vector3.UP if top else Vector3.DOWN)
   for v:Vector3 in ([center,p,q] if top else [center,q,p]):surface.set_uv(Vector2(v.x,v.z)/1.8);surface.add_vertex(v)
 var result=surface.commit();result.surface_set_material(0,material);return result
static func glass(color:Color,maximum_opacity:float=.62)->Material:
 var paint=ShaderMaterial.new();paint.shader=preload("res://scripts/forest/forest_east_hourglass_back.gdshader");paint.set_shader_parameter("use_native_mask",false);paint.set_shader_parameter("glass_color",Color(color.lightened(.25),.22))
 paint.set_shader_parameter("maximum_opacity",maximum_opacity)
 return paint
static func ceremonial(g:Dictionary)->Mesh:
 var metal=Fort.material(Color("bc963e" if g.metal=="gold" else "923e22" if g.metal=="copper" else "4c5257"),false)
 var color=Color("edab1c" if g.glass=="amber" else "92c4d5")
 var body=lathe([Vector2(1.30,.69),Vector2(1.30,.92),Vector2(1.20,1.18),Vector2(.94,1.45),Vector2(.58,1.76),Vector2(.22,2.03),Vector2(.13,2.15),Vector2(.25,2.32),Vector2(.62,2.58),Vector2(.98,2.85),Vector2(1.25,3.12),Vector2(1.31,3.44)],glass(color),48,true)
 var parts=[body,lathe([Vector2(1.25,.42),Vector2(1.48,.48),Vector2(1.53,.57),Vector2(1.45,.70),Vector2(1.31,.74)],metal),lathe([Vector2(1.30,3.40),Vector2(1.52,3.48),Vector2(1.52,3.62),Vector2(1.40,3.75)],metal)]
 var support=Furniture.tool();Furniture.Parts.prepare_primitives()
 for side in 3:
  var angle=-PI*.25+side*TAU/3.;var axis=Vector3(cos(angle),0,sin(angle))
  var old=axis*1.20+Vector3.UP*3.65
  for step in range(1,13):
   var t=step/12.;var radius=1.20-.30*sin(t*PI)+.48*pow(t,3);var next=axis*radius+Vector3.UP*(3.65+t*1.85)
   Furniture.Parts.rod(support,old,next,.065+(1.-t)*.055);old=next
  var foot=axis*.78+Vector3.UP*.53
  for step in range(1,9):
   var t=step/8.;var next=axis*(.78+.82*t)+Vector3.UP*(.53*pow(1.-t,1.5))
   Furniture.Parts.rod(support,foot,next,.065+(1.-t)*.055);foot=next
 var frame=support.commit();frame.surface_set_material(0,metal);parts.append(frame)
 var sand=Furniture.tool();Furniture.Parts.oval(sand,Vector3.UP*.91,Vector3(2.2,.45,2.2));Furniture.Parts.oval(sand,Vector3.UP*1.05,Vector3(1.1,.42,1.1));Furniture.Parts.rod(sand,Vector3.UP*1.20,Vector3.UP*2.65,.025)
 var grains=sand.commit();grains.surface_set_material(0,Fort.material(Color("e49428" if g.glass=="amber" else "d3e0dc"),false));parts.append(grains)
 return East.combine(parts)
static func native_front(model:Mesh,serial:int,g:Dictionary)->Mesh:
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(ROOT+str(serial)+"-front.png"),.045)
 for slot in mini(4,model.get_surface_count()):
  var arrays:Array=model.get_meta("east_cpu_arrays")[slot] if model.has_meta("east_cpu_arrays") else model.surface_get_arrays(slot)
  var indices:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=indices is PackedInt32Array and not indices.is_empty();var count_:int=indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()
  for i in range(0,count_,3):
   var ids=[indices[i],indices[i+1],indices[i+2]] if indexed else [i,i+1,i+2]
   var n:Vector3=(arrays[Mesh.ARRAY_NORMAL][ids[0]]+arrays[Mesh.ARRAY_NORMAL][ids[1]]+arrays[Mesh.ARRAY_NORMAL][ids[2]]).normalized()
   if slot==0:
    if n.dot(Vector3(-1./16.,.045,1./16.).normalized())<.30 or n.dot(Vector3(-1,0,1))<.15:continue
   elif n.dot(Vector3(-1./16.,.045,1./16.).normalized())<.15:continue
   for index:int in ids:
    var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index];front.projected_vertex(p+n*.003,n,p)
 var paint=front.finish();var material=ShaderMaterial.new();material.shader=FRONT_SHADER;material.set_shader_parameter("base_texture",load(ROOT+str(serial)+"-front.png"));paint.surface_set_material(0,material)
 return East.combine([model,paint])
static func mesh(serial:int,graphic:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)];assert(graphic.rgba_sha256==g.source_rgba_sha256,"Regenerate native hourglass references")
 var native=Vector2(26.+float(g.origin[0]),124.+float(g.origin[1]));var center=Vector3(native.x*3./64.-native.y/16.,0,native.x*3./64.+native.y/16.)
 var model=East.transformed_existing(ceremonial(g),Transform3D(Basis.IDENTITY,center));model=native_front(model,serial,g)
 model.set_meta("east_native_hourglass",serial);model.set_meta("source_rgba_sha256",g.source_rgba_sha256);model.set_meta("inferred_closed_reverse",true);meshes[serial]=model
 return model
