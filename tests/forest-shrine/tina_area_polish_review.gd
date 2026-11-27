extends "res://tests/forest-shrine/original_maps_test.gd"
const OUT_POLISH="res://build/Other Files/Asset Toolkit/Tina Recovery/Area Polish/"
const PROPS=[11348,11349,11350,11351,11352,11353,11354,11355,11356,11358,11361,11362,11466,11491]
const HOUSES=[11403,11409,11410,11411]
func run():
 var round_stone="--round-stone" in OS.get_cmdline_user_args()
 var remaining="--remaining-street" in OS.get_cmdline_user_args()
 var houses=[11412,11415,11416] if remaining else HOUSES
 var props=[10037,11041,11016,11098,11099] if remaining else PROPS
 if round_stone:
  houses=[11413,11414];props=[11048,11050,11051,11053,11056,11058,11062,11470,11471,11473,11474]
 var baseline="--baseline" in OS.get_cmdline_user_args()
 var output=("res://build/Other Files/Asset Toolkit/Tina Recovery/Round and Stone Polish/" if round_stone else "res://build/Other Files/Asset Toolkit/Tina Recovery/Remaining Street Polish/" if remaining else OUT_POLISH)+("Before/" if baseline else "After/")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));root.size=Vector2i(800,800)
 var stage=Node3D.new();root.add_child(stage)
 var world=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR
 world.environment.background_color=Color("d8d1bb");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.8;stage.add_child(world)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-30,0);sun.light_energy=.7;stage.add_child(sun)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;stage.add_child(camera)
 if not baseline and not round_stone:
  for serial in houses:
   var g:Dictionary=Original.Art.data().graphics[str(serial)];var profile=Original.Forms.Tina.shell_profile(serial,15,15)
   var w:float=profile[0];var d:float=profile[1];var wall:float=profile[2];var rise:float=profile[3]
   var source=Original.Forms.Source.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),Vector2.ZERO,Vector2.ONE,0],load(Original.Art.ROOT+Original.Art.data().pages[int(g.page)]),.045)
   Original.Forms.Tina.hip(source,serial,w*1.09,d*1.09,wall,rise,Vector3.ZERO)
   var mesh=source.finish();var arrays=mesh.surface_get_arrays(0);var aligned=true;var no_duplicate=true;var count_=0;var roof_normals=[]
   var left:Array=Original.Forms.Tina.crops()[Original.Forms.Tina.facade_key(serial,"left")][1]
   var right:Array=Original.Forms.Tina.crops()[Original.Forms.Tina.facade_key(serial,"right")][1]
   var anchor=(Vector2(left[2][0],left[2][1])+Vector2(right[3][0],right[3][1]))*.5
   var scale=float(left[1][0]-left[0][0]+right[1][0]-right[0][0])/((w+d)*.70710678)
   var corner=Vector3(-w*.5,0,d*.5)
   for i in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
    var n:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
    if not (n.x<-.1 and absf(n.x)>absf(n.z) or n.z>.1 and absf(n.z)>absf(n.x)):continue
    if n.x<-.1 and absf(n.x)>absf(n.z):roof_normals.append(n)
    var center=Vector2.ZERO
    for j in 3:
     var point:Vector3=arrays[Mesh.ARRAY_VERTEX][i+j]-corner
     var pixel=arrays[Mesh.ARRAY_TEX_UV][i+j]*source.texture.get_size()-source.graphic[0].position
     var projected=anchor+Vector2((point.x+point.z)*.70710678,-(point.x-point.z)*.52981294-point.y*.66226618)*scale
     aligned=aligned and projected.distance_to(pixel)<.005;center+=pixel/3;count_+=1
    for record in Original.Forms.Tina.gable_records(serial):no_duplicate=no_duplicate and not Geometry2D.is_point_in_polygon(center,PackedVector2Array(record[1]))
   check(count_>0 and aligned,"Roof paint aligns with the facade in the original camera "+str(serial))
   check(no_duplicate,"Raised dormer paint is not repeated or buried in the front roof "+str(serial))
   check(roof_normals.any(func(n):return n.distance_to(roof_normals[0])>.01),"Source alignment retains a curved hip instead of a flat pyramid "+str(serial))
   var edges={}
   for i in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
    for j in 3:
     var a:Vector3=arrays[Mesh.ARRAY_VERTEX][i+j];var b:Vector3=arrays[Mesh.ARRAY_VERTEX][i+(j+1)%3]
     var aa=Vector3i((a*10000).round());var bb=Vector3i((b*10000).round())
     var key=str(aa)+str(bb) if str(aa)<str(bb) else str(bb)+str(aa)
     if not edges.has(key):edges[key]=[0,(a+b)*.5]
     edges[key][0]+=1
   var closed=true
   for edge in edges.values():
    var at:Vector3=edge[1]
    if at.x>0 and at.z<0 and at.y>wall+rise*.25 and at.y<mesh.get_aabb().end.y-.04:closed=closed and edge[0]==2
   check(closed,"The rear roof ridge has no open internal seams "+str(serial))
 if not baseline and round_stone:
  for serial in houses:
   var g:Dictionary=Original.Art.data().graphics[str(serial)]
   var profile=Original.Forms.Tina.circular_profile(serial,15,18)
   for angle in [PI*.5,PI*.75,PI,PI*1.2]:
    var level=[1,.5,profile.bottom,profile.ry]
    var point=Original.Forms.Tina.source_round_point(angle,level,profile.rx,profile)
    var actual=Vector2(profile.cx+(point.x+point.z)*.70710678*profile.scale,profile.reference-((point.x-point.z)*.52981294+point.y*.66226618)*profile.scale)
    var expected=Original.Forms.Tina.round_pixel(angle,level,profile.cx,profile.rx)
    check(actual.distance_to(expected)<.005,"Round facade preserves its original front-view coordinates "+str(serial))
 var stats=[]
 var ids=props+houses
 for serial in Original.Forms.Street.WALLS:
  if serial not in ids:ids.append(serial)
 for serial in ids:
  print("POLISH_GRAPHIC ",serial)
  var g:Dictionary=Original.Art.data().graphics[str(serial)];var family=Original.Forms.kind(serial,false,g)
  var mesh=Original.Forms.mesh(serial,family,g,Original.Art.solid_texture(int(g.page)))
  check(mesh==Original.Forms.mesh(serial,family,g,Original.Art.solid_texture(int(g.page))),"Source scenery keeps the shared mesh cache "+str(serial))
  var finite=true;var triangles=0
  for surface in mesh.get_surface_count():
   var arrays=mesh.surface_get_arrays(surface);triangles+=arrays[Mesh.ARRAY_VERTEX].size()/3
   for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:finite=finite and p.is_finite()
  check(finite and mesh.get_aabb().size.y>.1,"Finite solid scenery "+str(serial))
  if not baseline and serial in props:
   var material=mesh.surface_get_material(1 if serial in [11016,11466] else 0)
   check(material.get_shader_parameter("base_texture").resource_path==Original.Art.ROOT+Original.Art.data().pages[int(g.page)],"Visible detail retains its own original paint "+str(serial))
   if remaining:
    if serial in Original.Forms.Street.BENCHES:
     check(mesh.get_meta("source_bench_backrest")== (serial==11041),"The two native benches retain distinct backrest forms "+str(serial))
     check(mesh.get_aabb().end.y<1.8 if serial==10037 else mesh.get_aabb().end.y>4,"Only the source-backed bench has a raised back panel "+str(serial))
     check(mesh.get_aabb().position.y>=-.001,"Bench supports rest on the original ground datum "+str(serial))
    if serial in Original.Forms.Street.MUSHROOMS:
     check(mesh.get_meta("source_mushroom_count")== (3 if serial==11098 else 5),"Mushroom cluster keeps its original three/five cap count "+str(serial))
     check(material.get_shader_parameter("original_palette")==false,"Rounded cap shading has an owned lit material "+str(serial))
     var image=Image.load_from_file(Original.Art.ROOT+Original.Art.data().pages[int(g.page)])
     var opaque=true
     for uv:Vector2 in mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
      var pixel=image.get_pixelv(Vector2i((uv*Vector2(image.get_size())).floor()))
      opaque=opaque and pixel.a>.99 and not (is_equal_approx(pixel.r,71.0/255) and pixel.r==pixel.g and pixel.g==pixel.b)
     check(opaque,"Cap and stem paint samples exclude source transparency and checkerboard shadows "+str(serial))
     check(Original.Forms.Source.material(load(Original.Art.ROOT+Original.Art.data().pages[int(g.page)])).get_shader_parameter("original_palette")==true,"Mushroom shading leaves the shared source material unchanged")
   if serial in range(11348,11363):
    var bounds=mesh.get_aabb()
    check(bounds.position.y>=-.001 and minf(bounds.size.x,bounds.size.z)<1.61,"Snowy broken wall stands on terrain with closed narrow depth "+str(serial))
    camera.position=Vector3(-1,1.6,1)*100;camera.look_at(Vector3.ZERO)
    var view=camera.transform.affine_inverse();var low=Vector2.INF;var high=-low
    var pixels_low=low;var pixels_high=high;var a=mesh.surface_get_arrays(0);var texture=material.get_shader_parameter("base_texture")
    for p:Vector3 in a[Mesh.ARRAY_VERTEX]:
     var q:Vector3=view*p;low=low.min(Vector2(q.x,q.y));high=high.max(Vector2(q.x,q.y))
    for uv:Vector2 in a[Mesh.ARRAY_TEX_UV]:pixels_low=pixels_low.min(uv*texture.get_size());pixels_high=pixels_high.max(uv*texture.get_size())
    check(absf((high-low).aspect()-(pixels_high-pixels_low).aspect())<.025,"Snow wall silhouette keeps native proportions "+str(serial))
  if not baseline and round_stone:
   if serial in props:
    check(family=="detail_tomb" and mesh.get_surface_count()==2,"Original marker has a source-painted face and closed solid depth "+str(serial))
    var bounds=mesh.get_aabb()
    var thin=bounds.size.y if serial==11050 else minf(bounds.size.x,bounds.size.z)
    check(bounds.position.y>=-.001 and (thin<=.141 or serial==11062),"Marker contours meet the ground without oversized slab depth "+str(serial))
    if serial in [11050,11062]:
     var normals:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
     var floor_face=false;var upright_face=false
     for normal in normals:
      floor_face=floor_face or normal.y>.9;upright_face=upright_face or normal.x<-.9
     check(floor_face,"Original floor plaque has a horizontal engraved top "+str(serial))
     check(upright_face== (serial==11062),"Only the combined memorial adds an upright headstone "+str(serial))
    check(mesh.get_meta("source_grave_components",0)>0,"Small original marker components are retained "+str(serial))
    var rect=Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]).grow(.01);var inside=true
    var texture=mesh.surface_get_material(0).get_shader_parameter("base_texture")
    for uv:Vector2 in mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:inside=inside and rect.has_point(uv*texture.get_size())
    check(inside,"Marker lettering and decorations sample only their own original graphic "+str(serial))
   if serial in houses:
    var texture=mesh.surface_get_material(1).get_shader_parameter("base_texture");var arrays=mesh.surface_get_arrays(1)
    var low=INF;var high=-INF;var profile=Original.Forms.Tina.circular_profile(serial,15,18)
    var joint_count=0;var joint_positions={};var inner=285 if serial==11413 else 280
    var center=Vector3((int(g.footprint[0])-1)*1.5,0,(1-int(g.footprint[1]))*1.5)
    for i in arrays[Mesh.ARRAY_VERTEX].size():
     var pixel:Vector2=arrays[Mesh.ARRAY_TEX_UV][i]*texture.get_size()-Vector2(g.rect[0],g.rect[1])
     var point:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
     if absf(normal.y)<.05 and pixel.y>120:low=minf(low,point.y);high=maxf(high,point.y)
     if pixel.distance_to(Vector2(profile.cx,inner+65))<.01 and (point.z-center.z)-(point.x-center.x)>0:
      joint_count+=1;joint_positions[str(Vector3i((point*10000).round()))]=true
    check(high-low<2*profile.rx/profile.scale*.9,"Round walls retain house proportions instead of a stretched tower "+str(serial))
    check(joint_count>=6 and joint_positions.size()==1,"Garden and foundation share a closed source seam "+str(serial))
  var node=MeshInstance3D.new();node.mesh=mesh;stage.add_child(node)
  var bounds=mesh.get_aabb();var center=bounds.get_center();var span=bounds.size.length()
  stats.append({"graphic":serial,"family":family,"triangles":triangles,"surfaces":mesh.get_surface_count()})
  if DisplayServer.get_name()!="headless" and serial in props+houses:
   camera.size=span*(1.05 if remaining or round_stone else .85)
   for side in 2:
    camera.position=center+Vector3(-1 if side==0 else 1,1.6,1 if side==0 else -1).normalized()*span*2;camera.look_at(center)
    for i in 4:await process_frame
    DisplayServer.window_move_to_foreground();await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"%d-%d.png"%[serial,side])
  stage.remove_child(node);node.free()
 var report=FileAccess.open(output+"stats.json",FileAccess.WRITE);report.store_string(JSON.stringify(stats,"  "))
 stage.queue_free();finish()
