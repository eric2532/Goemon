extends RefCounted
## Tina-only source-paint variants; shared masters and original placements stay immutable.
const Profiles=preload("res://assets/maps/falan/tina/scenery_profiles.gd")
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Harbor=preload("res://scripts/forest/forest_tina_harbor_details.gd")
const Tina=preload("res://scripts/forest/forest_tina_building_details.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const TREES=[10089,10092,10093]
const BUILDINGS=[11407,11409,11410,11414,11416,11451]
const BOATS=[11500,11501]
const LOGS=[11462,11463]
const ROOMS=[4206,4208,4209,4210,4211,4212,4213,4214,4220,4221,4222,4230,4232,4299]
const POTTED=[16226,16230,16231,16504,16543,17535]
const TABLES=[16560,16561,16562,16566,16567,16569,16573,16574,16575,16576,16577]
const ROOM_FAMILIES=["table","bench","chair","bed","shelf","crate","stove","drawers","plant","finial","moon","lectern","detail_piano","detail_lectern","detail_candles"]
static var meshes:Dictionary={}
static var building_fits:Dictionary={}

static func outdoor_structure(serial:int)->bool:
 return serial in BUILDINGS+BOATS+LOGS or serial in range(11363,11377) or serial in range(11378,11392)

static func owns(source:int,serial:int)->bool:
 if source in [4200,4201]:return serial==11015 or outdoor_structure(serial) or serial<13000 and Profiles.GRAPHICS.has(str(serial))
 if source not in ROOMS:return false
 var family=Forms.kind(serial,false,Art.data().graphics[str(serial)])
 return family in ROOM_FAMILIES or family.begins_with("inn_") or family.begins_with("coast_") and family!="coast_stair"

static func mesh(serial:int,g:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 if outdoor_structure(serial):meshes[serial]=structure(serial,g)
 elif serial==11015:meshes[serial]=shelter(g)
 elif (serial<13000 or serial in POTTED) and Profiles.GRAPHICS.has(str(serial)):
  var record:Dictionary=Profiles.GRAPHICS[str(serial)]
  assert(record.source_rgba_sha256==g.rgba_sha256,"Regenerate stale Tina scenery profiles")
  meshes[serial]=tree(serial,g,record) if serial in TREES else plant(serial,g,record)
 elif serial in TABLES or serial==16500:meshes[serial]=table(serial,g)
 else:meshes[serial]=room_paint(serial,g)
 meshes[serial].set_meta("tina_only_scenery",serial)
 return meshes[serial]

static func structure(serial:int,g:Dictionary)->Mesh:
 if serial not in BUILDINGS+BOATS+LOGS:
  var fence=Harbor.structure();Tina.fence(fence,serial,-float(g.origin[1])*.1,1.5)
  return fence.finish()
 var original=Harbor.boat_mesh(serial,g,true) if serial==11500 else Forms.mesh(serial,Forms.kind(serial,false,g),g,Art.solid_texture(int(g.page)))
 var pose=Transform3D(Basis.IDENTITY,Vector3(.96875,0,-.96875))
 if serial in BUILDINGS+LOGS:
  if building_fits.is_empty():building_fits=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/tina/building-fits.json"))
  var fit:Dictionary=building_fits[str(serial)]
  assert(fit.source_rgba_sha256==g.rgba_sha256,"Regenerate Tina building silhouette fits")
  pose=Transform3D(Basis.IDENTITY.scaled(Vector3(fit.scale[0],fit.scale[1],fit.scale[2])),Vector3(fit.offset[0],fit.offset[1],fit.offset[2]))
 if serial in LOGS:
  # The original snow, bark and cut ends belong to these cylinders, not a flat white tile.
  var native=Harbor.skin(g)
  native.projection_center=pose*original.get_aabb().get_center()
  var normals=pose.basis.inverse().transposed()
  for slot in original.get_surface_count():
   var arrays=original.surface_get_arrays(slot)
   var indices=arrays[Mesh.ARRAY_INDEX]
   var indexed=indices is PackedInt32Array and not indices.is_empty()
   for j in indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size():
    var i:int=indices[j] if indexed else j
    var point:Vector3=pose*arrays[Mesh.ARRAY_VERTEX][i]
    var normal:Vector3=(normals*arrays[Mesh.ARRAY_NORMAL][i]).normalized()
    var sample=point
    if normal.dot(Vector3(-1,1.6,1))<0:
     if normal.x>0:sample.x=2*native.projection_center.x-sample.x
     if normal.z<0:sample.z=2*native.projection_center.z-sample.z
    native.projected_vertex(point,normal,sample)
  var result=native.finish();result.set_meta("native_tina_logs",serial)
  return result
 # The boat's submerged datum displaced its source-angle silhouette; cancel
 # that screen shear in geometry while keeping its marker and water height.
 var result=ArrayMesh.new()
 for slot in original.get_surface_count():
  var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  surface.append_from(original,slot,pose);surface.commit(result)
  result.surface_set_material(slot,original.surface_get_material(slot))
 if serial==11407:return align_green_roof(result,g)
 return result

static func align_green_roof(mesh:Mesh,g:Dictionary)->Mesh:
 # Calibrate the local main roof's three eaves and apex to the native image.
 # The same affine transform closes its inferred rear slopes without changing shared houses.
 var slot=mesh.get_surface_count()-1
 var arrays=mesh.surface_get_arrays(slot).duplicate(true)
 var texture:Texture2D=mesh.surface_get_material(slot).get_shader_parameter("base_texture")
 var pixels=Tina.ROOFS[11407]
 var points=[]
 for pixel:Vector2 in [pixels[1],pixels[2],pixels[3]]:
  var closest=INF;var point=Vector3.ZERO
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
   if normal.x>=-.001 and normal.z<=.001:continue
   var error:float=(arrays[Mesh.ARRAY_TEX_UV][i]*texture.get_size()).distance_squared_to(pixel)
   if error<closest:closest=error;point=arrays[Mesh.ARRAY_VERTEX][i]
  assert(closest<.01,"Native green roof eave is missing")
  points.append(point)
 var apex=Vector3.ZERO;var count=0
 # Only the roof's highest ring participates; the body's finial is unrelated.
 var high=-INF
 for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:high=maxf(high,point.y)
 for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
  if absf(point.y-high)<.001:apex+=point;count+=1
 apex/=count
 var targets=[]
 for i in 3:targets.append(Harbor.point(pixels[i+1],points[i].y,g))
 var target_apex=Harbor.point(pixels[0],apex.y,g)
 var from=Basis(points[1]-points[0],points[2]-points[0],apex-points[0])
 var to=Basis(targets[1]-targets[0],targets[2]-targets[0],target_apex-targets[0])
 var basis=to*from.inverse();var pose=Transform3D(basis,targets[0]-basis*points[0])
 var normals=basis.inverse().transposed()
 for i in arrays[Mesh.ARRAY_VERTEX].size():
  arrays[Mesh.ARRAY_VERTEX][i]=pose*arrays[Mesh.ARRAY_VERTEX][i]
  arrays[Mesh.ARRAY_NORMAL][i]=(normals*arrays[Mesh.ARRAY_NORMAL][i]).normalized()
 var result=ArrayMesh.new()
 for i in mesh.get_surface_count():
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays if i==slot else mesh.surface_get_arrays(i))
  result.surface_set_material(i,mesh.surface_get_material(i))
 result.set_meta("native_green_roof_eaves",targets)
 return result

static func tree(serial:int,g:Dictionary,record:Dictionary)->Mesh:
 var result=ArrayMesh.new()
 var texture:Texture2D=load(Art.ROOT+Art.data().pages[int(g.page)])
 var turn=Basis(Vector3(.70710678,0,.70710678),Vector3.UP,Vector3(-.70710678,0,.70710678))
 for part in Meadow.source(Meadow.crossgate_tree(10088)):
  var original:Mesh=part.mesh;var arrays=original.surface_get_arrays(0).duplicate(true)
  var material:Material=original.surface_get_material(0)
  if part.name=="Canopy":
   # Reuse the complete existing leaf quads, as in prepare_crossgate_trees.py.
   for start in range(0,arrays[Mesh.ARRAY_VERTEX].size(),4):
    var middle=Vector3.ZERO
    for i in 4:middle+=arrays[Mesh.ARRAY_VERTEX][start+i]*.25
    var index=start/4;var sample:Array=record.samples[(index*811+serial)%record.samples.size()]
    var span:Array=record.spans[str(int(sample[1]))]
    var radius=maxf(1,(float(span[1])-float(span[0]))*.5)
    var axis=(float(span[1])+float(span[0]))*.5
    var depth=sqrt(maxf(0,radius*radius-pow(float(sample[0])-axis,2)))*sin(index*2.39996)*.9
    var at=Vector3((float(sample[0])+float(g.origin[0]))*.06629126,(-float(g.origin[1])-float(sample[1]))*.1+depth*.031*1.13137085,depth*.031)
    for i in 4:
     var j=start+i
     arrays[Mesh.ARRAY_VERTEX][j]=turn*(at+(arrays[Mesh.ARRAY_VERTEX][j]-middle)*1.25)
     arrays[Mesh.ARRAY_NORMAL][j]=turn*arrays[Mesh.ARRAY_NORMAL][j]
     var uv:Vector2=arrays[Mesh.ARRAY_TEX_UV][j]
     var pixel=Vector2(sample[0],sample[1])+(uv-Vector2.ONE*.5)*6
     pixel=pixel.clamp(Vector2.ONE*.5,Vector2(g.rect[2],g.rect[3])-Vector2.ONE*.5)
     arrays[Mesh.ARRAY_TEX_UV][j]=(Vector2(g.rect[0],g.rect[1])+pixel)/texture.get_size()
     arrays[Mesh.ARRAY_COLOR][j]=Color.WHITE
   var canopy=ShaderMaterial.new();canopy.shader=Meadow.WIND
   canopy.set_shader_parameter("tree",true);canopy.set_shader_parameter("canopy",true)
   canopy.set_shader_parameter("strength",.025);canopy.set_shader_parameter("use_source_paint",true)
   canopy.set_shader_parameter("source_cutout",true)
   canopy.set_shader_parameter("source_paint",texture)
   material=canopy
  else:
   var fit=Vector3(float(g.rect[2])/248.0*2.13843,float(-g.origin[1])/267.0*3.225806,float(g.rect[2])/248.0*2.13843)
   for i in arrays[Mesh.ARRAY_VERTEX].size():
    arrays[Mesh.ARRAY_VERTEX][i]=turn*(arrays[Mesh.ARRAY_VERTEX][i]*fit)
    arrays[Mesh.ARRAY_NORMAL][i]=(turn*(arrays[Mesh.ARRAY_NORMAL][i]/fit)).normalized()
    var sample:Array=record.bark[(i*37)%record.bark.size()]
    arrays[Mesh.ARRAY_TEX_UV][i]=(Vector2(g.rect[0]+sample[0],g.rect[1]+sample[1])+Vector2.ONE*.5)/texture.get_size()
   material=Forms.Source.material(texture)
  arrays[Mesh.ARRAY_TANGENT]=null
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  result.surface_set_material(result.get_surface_count()-1,material)
 result.set_meta("source_tree_crown",serial)
 return result

static func plant(serial:int,g:Dictionary,record:Dictionary)->Mesh:
 var native=Harbor.skin(g)
 var fern=serial in range(12471,12486)
 var pixel_width=.06629126 if serial<13000 else .046875
 var pixel_height=.1 if serial<13000 else .045
 var turn=Basis(Vector3(.70710678,0,.70710678),Vector3.UP,Vector3(-.70710678,0,.70710678))
 # Source-facing outlines preserve reed heads, rose blossoms and individual fronds.
 # shortcut: Unseen plant depth is shallow; replace it only with an additional original view.
 for outline in record.outlines:
  var profile=PackedVector2Array()
  for p in outline:profile.append(Vector2((float(p[0])+float(g.origin[0]))*pixel_width,(float(record.bottom)-float(p[1]))*pixel_height))
  var shape=Shapes.extrude(profile,.10 if fern else .18);var arrays=shape.surface_get_arrays(0)
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   var local:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
   var pixel=Vector2(local.x/pixel_width-float(g.origin[0]),float(record.bottom)-local.y/pixel_height)
   var base=Harbor.point(Vector2(-float(g.origin[0]),record.bottom),0,g) if serial<13000 else Vector3.ZERO
   var p=base+turn*local+Vector3.UP*.02
   if fern:
    # Fern art describes a low spreading ground plant, rather than an upright reed.
    p=Harbor.point(pixel,.10+local.y*.18,g)+turn*Vector3(0,0,local.z)
    normal=Vector3.UP if normal.z>.5 else Vector3.DOWN if normal.z<-.5 else turn*normal
   else:normal=turn*normal
   native.surface.set_normal(normal)
   native.surface.set_uv((native.graphic[0].position+pixel.clamp(Vector2.ONE*.5,Vector2(g.rect[2],g.rect[3])-Vector2.ONE*.5))/native.texture.get_size())
   native.surface.add_vertex(p)
 var result=native.finish();var material:ShaderMaterial=result.surface_get_material(0).duplicate()
 material.set_shader_parameter("use_brush_finish",false)
 result.surface_set_material(0,material);result.set_meta("source_plant_contours",record.outlines.size())
 return result

static func room_skin(g:Dictionary):
 return Harbor.Paint.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(Art.ROOT+Art.data().pages[int(g.page)]),Forms.HEIGHT_PER_PIXEL)

static func room_paint(serial:int,g:Dictionary)->Mesh:
 var family=Forms.kind(serial,false,g)
 var original=Forms.mesh(serial,family,g,Art.solid_texture(int(g.page)))
 var native=room_skin(g)
 native.projection_center=Vector3((int(g.footprint[0])-1)*1.5,0,(1-int(g.footprint[1]))*1.5)
 var result=ArrayMesh.new()
 for slot in original.get_surface_count():
  var material:Material=original.surface_get_material(slot)
  # Already recovered source paint stays on its original surface.
  if material is ShaderMaterial and material.get_shader_parameter("original_palette")==true:
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,original.surface_get_arrays(slot))
   result.surface_set_material(result.get_surface_count()-1,material)
   continue
  var arrays=original.surface_get_arrays(slot);var indices=arrays[Mesh.ARRAY_INDEX]
  var indexed=indices is PackedInt32Array and not indices.is_empty();var unseen=PackedInt32Array()
  for j in range(0,indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size(),3):
   var triangle=[indices[j],indices[j+1],indices[j+2]] if indexed else [j,j+1,j+2]
   var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][triangle[0]]
   # Only the original's two visible faces/top have evidence for new paint.
   if normal.dot(Vector3(-1,1.6,1))<=.01:
    unseen.append_array(PackedInt32Array(triangle));continue
   for i in triangle:native.vertex(arrays[Mesh.ARRAY_VERTEX][i],arrays[Mesh.ARRAY_NORMAL][i])
  if not unseen.is_empty():
   arrays=arrays.duplicate();arrays[Mesh.ARRAY_INDEX]=unseen
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   result.surface_set_material(result.get_surface_count()-1,material)
 var painted=native.surface.commit()
 if painted!=null and painted.get_surface_count()>0:
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,painted.surface_get_arrays(0))
  result.surface_set_material(result.get_surface_count()-1,Harbor.Paint.material(native.texture))
 return result

static func table(serial:int,g:Dictionary)->Mesh:
 var native=room_skin(g);var center=Vector3((int(g.footprint[0])-1)*1.5,0,(1-int(g.footprint[1]))*1.5)
 native.projection_center=center
 var height=Forms.source_height(g);var w=int(g.footprint[0])*3.0;var d=int(g.footprint[1])*3.0
 var fit=minf(1,float(g.rect[2])/((w+d)*32/3));w*=fit;d*=fit
 var thick=minf(.14,height*.20)
 native.box(AABB(center+Vector3(-w*.5,height-thick,-d*.5),Vector3(w,thick,d)))
 if serial in TABLES and serial not in [16560,16561,16562]:
  for pixel in Profiles.GRAPHICS[str(serial)].feet:
   var sum=(float(pixel[0])+float(g.origin[0]))*3/32
   var difference=(float(pixel[1])+float(g.origin[1]))/8
   var foot=Vector3((sum-difference)*.5,0,(sum+difference)*.5)
   native.box(AABB(foot-Vector3(.075,0,.075),Vector3(.15,height-thick,.15)))
 elif serial==16500:
  # The native long plank bench has two trestles, with no cushion or bookcase.
  for side in [-1,1]:
   var x=center.x+side*w*.36
   for end in [-1,1]:native.box(AABB(Vector3(x-.075,0,center.z+end*d*.30-.075),Vector3(.15,height-thick,.15)))
   native.box(AABB(Vector3(x-.12,.10,center.z-d*.42),Vector3(.24,.10,d*.84)))
 else:
  for side in [-1,1]:
   for end in [-1,1]:native.box(AABB(center+Vector3(side*w*.40-.075,0,end*d*.40-.075),Vector3(.15,height-thick,.15)))
 var result=native.finish();result.set_meta("native_plain_table",serial)
 return result

static func shelter(g:Dictionary)->Mesh:
 var native=Harbor.skin(g);var wood=Harbor.structure()
 # Native roof corners: the long ridge is a single sloping plane, not a pyramid.
 var pixels=[Vector2(9,123),Vector2(24,103),Vector2(171,4),Vector2(194,47)]
 var heights=[3.4,5.3,5.3,3.4];var points=[]
 for i in 4:points.append(Harbor.point(pixels[i],heights[i],g))
 Tina.outward_quad(native,points.duplicate(),pixels.duplicate(),Vector3.UP)
 wood.part="tina_log_bark"
 for i in 4:
  var j=(i+1)%4
  wood.quad(points[i]-Vector3.UP*.14,points[j]-Vector3.UP*.14,points[j],points[i])
 wood.quad(points[3]-Vector3.UP*.14,points[2]-Vector3.UP*.14,points[1]-Vector3.UP*.14,points[0]-Vector3.UP*.14)
 for t in [0.0,.5,1.0]:
  for edge in [[0,3],[1,2]]:
   var at:Vector3=points[edge[0]].lerp(points[edge[1]],t)
   Harbor.rod(wood,Vector3(at.x,.02,at.z),at,.10,"tina_log_bark")
 var axis=(points[3]-points[0]).normalized();axis.y=0;axis=axis.normalized()
 var across=Vector3.UP.cross(axis);var center=(points[0]+points[1]+points[2]+points[3])*.25;center.y=.30
 var length_=points[0].distance_to(points[3])*.93
 for row in 2:
  for column in 3-row:Tina.timber_log(wood,center+across*(column-(2-row)*.5)*.55+Vector3.UP*row*.48,axis,length_,.28)
 # Original yellow hanging hides stay on their visible source face.
 var hides=[Vector2(54,169),Vector2(54,143),Vector2(163,70),Vector2(163,99)];var face=[]
 for i in 4:face.append(Harbor.point(hides[i],.85 if i in [0,3] else 2.9,g))
 Tina.outward_quad(native,face,hides,Vector3.BACK)
 return Tina.join(wood.finish(),native.finish(),Transform3D.IDENTITY)
