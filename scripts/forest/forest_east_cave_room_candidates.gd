extends RefCounted
## Private source-measured wall study. Existing map/collision owners are unchanged.
const Sections=preload("res://scripts/forest/forest_east_architecture_sections.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Timber=preload("res://scripts/forest/forest_il_laruka_buildings.gd")
const Native=preload("res://scripts/forest/forest_original_cliffs.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit/Cave Room Candidate/"
static var catalog:Dictionary={}
static var textures:Dictionary={}
static var meshes:Dictionary={}

static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog

static func texture(name:String)->Texture2D:
 if not textures.has(name):textures[name]=ImageTexture.create_from_image(Image.load_from_file(ROOT+name))
 return textures[name]

static func owns(serial:int)->bool:return data().graphics.has(str(serial))

static func source_depth(pixel:Vector2,g:Dictionary)->float:
 var depth=0.
 for patch:Dictionary in g.get("source_patches",[]):
  var delta=(pixel-Vector2(patch.center[0],patch.center[1]))/Vector2(patch.radius[0],patch.radius[1])
  depth=maxf(depth,float(patch.depth_m)*exp(-delta.length_squared()*1.65))
 return depth

static func cave(g:Dictionary,atlas:Texture2D,paint:Texture2D)->Mesh:
 var base=Source.new([],atlas,.045);base.tiles={"wall":Vector2.ZERO,"trim":Vector2(128,0),"cap":Vector2(256,0)};base.part="wall"
 base.surface.set_color(Color(g.inferred_moss_rgb[0],g.inferred_moss_rgb[1],g.inferred_moss_rgb[2]))
 var pitch=float(g.rectified_material.world_pitch);base.pitches={"wall":pitch,"trim":pitch,"cap":pitch}
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],paint,.045)
 var inward=Vector3(1,-.045*16.,-1).normalized()*float(g.closed_source_depth)
 for cell:Array in g.source_alpha_cells:
  var pixels=[Vector2(cell[0],cell[1]),Vector2(cell[0],cell[3]),Vector2(cell[2],cell[3]),Vector2(cell[2],cell[1])];var points=[]
  for pixel:Vector2 in pixels:points.append(alpha_point(pixel,g))
  var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  if normal.dot(-inward)<0:pixels.reverse();points.reverse();normal=-normal
  for index in [0,1,2,0,2,3]:
   front.surface.set_normal(normal);front.surface.set_uv(pixels[index]/Vector2(g.size[0],g.size[1]));front.surface.add_vertex(points[index])
  base.quad(points[3]+inward,points[2]+inward,points[1]+inward,points[0]+inward)
 for edge:Array in g.source_alpha_edges:
  var a=alpha_point(Vector2(edge[0],edge[1]),g);var b=alpha_point(Vector2(edge[2],edge[3]),g)
  base.quad(a,b,b+inward,a+inward)
 append_back_stones(base,g)
 var result=base.finish(true);var body_arrays:Array=result.get_meta("source_surface_arrays")
 for i in body_arrays[Mesh.ARRAY_VERTEX].size():body_arrays[Mesh.ARRAY_TEX_UV][i]=Sections.projected(body_arrays[Mesh.ARRAY_VERTEX][i],g)/Vector2(g.size[0],g.size[1])
 result.clear_surfaces();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,body_arrays);var arrays=[body_arrays]
 var hidden=ShaderMaterial.new();hidden.shader=preload("res://scripts/forest/forest_east_cliff_volume.gdshader");hidden.set_shader_parameter("native_paint",paint);hidden.set_shader_parameter("rock_texture",preload("res://assets/textures/edo/rock.png"));hidden.set_shader_parameter("native_eye",Vector3(-1,.045*16.,1).normalized());result.surface_set_material(0,hidden)
 front.surface.generate_normals();var observed=front.finish(true);var paint_arrays:Array=observed.get_meta("source_surface_arrays")
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint_arrays);result.surface_set_material(1,observed.surface_get_material(0));arrays.append(paint_arrays)
 result.set_meta("east_cpu_arrays",arrays)
 return result

static func append_back_stones(base,g:Dictionary):
 var master:Dictionary=data().rounded_stone_master;var eye=Vector3(-1,.045*16.,1).normalized();var across=Vector3(1,0,1).normalized();var vertical=across.cross(eye).normalized()
 for patch:Dictionary in g.get("source_patches",[]):
  var radius=Vector3(patch.hidden_stone_radii_m[0],patch.hidden_stone_radii_m[1],patch.hidden_stone_radii_m[2])
  var basis=Basis(across,eye,vertical).scaled_local(radius);var normal_basis=basis.inverse().transposed()
  var at=alpha_point(Vector2(patch.center[0],patch.center[1]),g)-eye*(float(g.closed_source_depth)+radius.y*.20)
  var vertices=[];var normals=[];var low=INF;var high=-INF
  for row:Array in master.positions:
   var p=basis*Vector3(row[0],row[1],row[2])+at;vertices.append(p);low=minf(low,p.y);high=maxf(high,p.y)
  var shift=eye*(-low/eye.y) if low<0 else -eye*((high-float(g.wall_height))/eye.y) if high>float(g.wall_height) else Vector3.ZERO
  # Hidden continuation must stay behind the observed source envelope even
  # where neighboring front-corner/cap depths change across one boulder.
  var inset=0.
  for p:Vector3 in vertices:
   var at_point=p+shift;var recorded=alpha_point(Sections.projected(at_point,g),g)
   inset=maxf(inset,(at_point-recorded).dot(eye)+.10)
  shift-=eye*inset
  for row:Array in master.normals:normals.append((normal_basis*Vector3(row[0],row[1],row[2])).normalized())
  for index_ in master.indices:
   var index=int(index_);var p:Vector3=vertices[index]+shift;var n:Vector3=normals[index]
   var axis=Vector2(p.z,-p.y) if absf(n.x)>absf(n.z) else Vector2(p.x,-p.y)
   var palette:Array=patch.native_palette_rgb;var shade:Array=master.colors[index];var luma=clampf((shade[0]*.2126+shade[1]*.7152+shade[2]*.0722)/.42,.78,1.14)
   base.surface.set_color(Color(palette[0]*luma,palette[1]*luma,palette[2]*luma));base.surface.set_normal(n);base.surface.set_uv2(Vector2.ZERO);base.surface.set_uv(axis/float(g.rectified_material.world_pitch));base.surface.add_vertex(p)

static func alpha_point(pixel:Vector2,g:Dictionary)->Vector3:
 # Source -X/+Z walls meet at the recorded front corner. Above that edge,
 # their native cap follows the same physical height instead of a raised box.
 var across=(pixel.x+float(g.origin[0]))*3./32.
 var outer_depth=3.-absf(across);var height=clampf((outer_depth*8.-pixel.y-float(g.origin[1]))*.045,0.,float(g.wall_height))
 var depth=(height/.045+pixel.y+float(g.origin[1]))/8.
 var point=Vector3((across-depth)*.5,height,(across+depth)*.5)
 var fade=smoothstep(0.,.25,height)*smoothstep(0.,.25,float(g.wall_height)-height)
 return point+Vector3(-1,.045*16.,1).normalized()*source_depth(pixel,g)*fade

static func room(g:Dictionary,atlas:Texture2D,paint:Texture2D)->Mesh:
 var base=Source.new([],atlas,.045);base.tiles={"wall":Vector2.ZERO,"wood":Vector2(128,0),"stone":Vector2(256,0),"cornice":Vector2(384,0),"cap":Vector2(512,0),"frame":Vector2(640,0)}
 var pitch=float(g.rectified_material.world_pitch)
 for name in base.tiles:base.pitches[name]=pitch
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],paint,.045)
 var footprint=PackedVector2Array([Vector2(-1.5,-1.5),Vector2(-1.5,1.5),Vector2(1.5,1.5),Vector2(1.5,-1.5)])
 var height=float(g.native_source_height);var bands=[[0.,.16,"stone"],[.16,1.85,"wood"],[1.85,2.00,"wood"],[2.00,height-.25,"wall"],[height-.25,height,"cornice"]] if int(g.serial)==17065 else [[0.,.20,"stone"],[.20,1.32,"wood"],[1.32,height-.16,"wall"],[height-.16,height,"cornice"]]
 for band:Array in bands:
  base.part=band[2];Sections.vertical_section(base,front,footprint,band[0],band[1])
 if int(g.serial) in [17075,17076]:
  # Reuse closed timber bars on the recorded window face. The original grey
  # plinth must not be mistaken for blue glass and enlarge the window hull.
  var right=int(g.serial)==17075;var normal=Vector3(0,0,1) if right else Vector3(-1,0,0);var along=Vector3.RIGHT if right else Vector3.BACK
  var plane=Vector3(0,0,1.54) if right else Vector3(-1.54,0,0);var low=1.48;var high=height-.22
  var points=[plane-along*1.20+Vector3.UP*low,plane-along*1.20+Vector3.UP*high,plane+along*1.20+Vector3.UP*high,plane+along*1.20+Vector3.UP*low]
  base.part="frame"
  for i in 4:Timber.bar(base,points[i],points[(i+1)%4],.045)
  Timber.bar(base,plane+Vector3.UP*low,plane+Vector3.UP*high,.035)
  for i in [1,2,3]:
   var y=lerpf(low,high,float(i)/4.);Timber.bar(base,plane-along*1.20+Vector3.UP*y,plane+along*1.20+Vector3.UP*y,.028)
 var result=base.finish(true);var base_arrays:Array=result.get_meta("source_surface_arrays");var mapping=["wall","wood","stone","cornice","cap","frame"]
 for i in base_arrays[Mesh.ARRAY_VERTEX].size():
  var point:Vector3=base_arrays[Mesh.ARRAY_VERTEX][i];var slot=roundi(base_arrays[Mesh.ARRAY_TEX_UV2][i].x/128.);var band:Dictionary=g.rectified_material.native_bands[mapping[slot]]
  var uv:Vector2=base_arrays[Mesh.ARRAY_TEX_UV][i];uv.x*=float(g.rectified_material.world_pitch)/float(band.horizontal_span)
  if mapping[slot]=="cap":uv.y*=float(g.rectified_material.world_pitch)/float(band.horizontal_span)
  else:uv.y=(float(band.top_world_y)-point.y)/float(band.vertical_span)
  base_arrays[Mesh.ARRAY_TEX_UV][i]=uv
 result.clear_surfaces();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,base_arrays);result.surface_set_material(0,Source.material(atlas,true));var arrays=[base_arrays]
 var back:ShaderMaterial=result.surface_get_material(0).duplicate();back.set_shader_parameter("original_palette",false);result.surface_set_material(0,back)
 var observed=front.finish(true);var paint_arrays:Array=observed.get_meta("source_surface_arrays");result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,paint_arrays);result.surface_set_material(1,observed.surface_get_material(0));arrays.append(paint_arrays);result.set_meta("east_cpu_arrays",arrays)
 return result

static func mesh(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)];var atlas=texture(str(serial)+"-surfaces.png");var paint=texture(str(serial)+"-front.png")
 var result:Mesh=room(g,atlas,paint) if g.role=="native_room_section" else cave(g,atlas,paint)
 result.set_meta("east_cave_room_candidate",serial);result.set_meta("east_candidate_not_enrolled",true)
 result.set_meta("east_native_source_height",g.native_source_height);result.set_meta("east_source_rgba_sha256",g.source_rgba_sha256)
 result.set_meta("east_native_wall_role",g.role);result.set_meta("east_visual_inference",true)
 meshes[serial]=result
 return result

static func build_mass(root:Node3D,source:int,state:Dictionary)->Dictionary:
 assert(source in [11037,34018],"Private context mass is bounded to the reviewed cave/tree rooms")
 var profiles={};var graphics={};var tiles={};var placements=[];var count_=int(state.size.x*state.size.y)
 for token in data().graphics:
  var g:Dictionary=data().graphics[token]
  if g.role=="native_room_section":continue
  profiles[token]=g.context_wall_profile;graphics[token]={"origin":g.origin,"footprint":g.footprint};tiles[token]=[0,0]
 for index in count_:
  var serial=int(state.raw.decode_u16(20+(count_+index)*2))
  if not profiles.has(str(serial)):continue
  placements.append([0,0,Vector2.ZERO,serial,count_+index,Vector2i(index%state.size.x,index/state.size.x)])
 var peer=13612 if source==34018 else 13721;var sample=texture(str(peer)+"-surfaces.png")
 var context={"profiles":profiles,"graphics":graphics,"texture":sample,"original_palette":false,"wall_tiles":tiles,"wall_tile_scale":[126./2.4,126./2.4],"minimum_crown_fraction":1.,"cap_paint":{"cave":[0,0],"freyja":[0,0],"undersea":[0,0],"rock":[0,0],"snow":[0,0]}}
 var mass=Node3D.new();mass.name="PrivateSourceBlockedWallMass";root.add_child(mass)
 Native.build(mass,placements,state.size,state.bits,state.origin,source,Vector2i.ZERO,context)
 var result={"source":source,"source_wall_placements":placements.size(),"blocked_mass_cells":mass.get_meta("recovered_cliff_cells",[]).size(),"chunks":mass.get_meta("recovered_cliff_chunks",0),"triangles":mass.get_meta("recovered_cliff_triangles",0),"inferred":"Closed same-family rock/root continuation inside the original blocked wall cells; existing Native boundary/corner/chunk geometry and independent native material samples. Original source foreground/relief is separate. No new collision, walk or portal."}
 mass.set_meta("east_private_wall_mass",result)
 return result
