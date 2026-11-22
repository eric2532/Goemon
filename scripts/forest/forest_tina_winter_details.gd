extends RefCounted
## Native winter props, assembled once in the original-map mesh cache.
const Harbor=preload("res://scripts/forest/forest_tina_harbor_details.gd")
const Tina=preload("res://scripts/forest/forest_tina_building_details.gd")
const IDS=[11460,11461,11465,11484,11485]
static var paint_material:ShaderMaterial

static func finish(paint)->Mesh:
 var result:Mesh=paint.finish()
 if paint_material==null:
  # Only these rounded props need lit source paint; keep the shared archive material immutable.
  paint_material=result.surface_get_material(0).duplicate()
  paint_material.set_shader_parameter("original_palette",false)
  paint_material.set_shader_parameter("surface_kind",5.0)
  var brush=Image.create(1,1,false,Image.FORMAT_RGBA8);brush.fill(Color(.5,.5,.5))
  paint_material.set_shader_parameter("brush_texture",ImageTexture.create_from_image(brush))
  paint_material.set_shader_parameter("base_color",Color(.85,.85,.85))
 result.surface_set_material(0,paint_material)
 return result

static func oval(paint,at:Vector3,size_:Vector3,grounded:bool=false):
 if Geo.sphere_mesh==null:
  var holder=Node3D.new();Geo.sphere(holder,Vector3.ZERO,Vector3.ONE,null);holder.free()
 var pose=Transform3D(Basis.IDENTITY.scaled(size_),at);var normal=pose.basis.inverse().transposed()
 var arrays=Geo.sphere_mesh.surface_get_arrays(0)
 for i in arrays[Mesh.ARRAY_INDEX]:
  var p:Vector3=pose*arrays[Mesh.ARRAY_VERTEX][i]
  if grounded:p.y=maxf(.025,p.y)
  paint.surface.set_normal((normal*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
  paint.surface.set_uv(Vector2(p.x,-p.y)/1.5);paint.surface.set_uv2(paint.tiles[paint.part]);paint.surface.add_vertex(p)

static func mesh(serial:int,g:Dictionary)->Mesh:
 var paint=Harbor.structure()
 var center=Vector3((int(g.footprint[0])-1)*1.5,0,(1-int(g.footprint[1]))*1.5)
 if serial in [11460,11461]:
  var axis=Vector3.BACK if serial==11460 else Vector3.RIGHT
  var across=Vector3.UP.cross(axis);var radius=.55;var length_=4.9
  for row in 3:
   for column in 5:
    var at=center+across*(column-2)*radius*1.98+Vector3.UP*(.18+radius+row*radius*1.91)
    Tina.timber_log(paint,at,axis,length_,radius,"tina_hollow_bark","tina_stack_end_green" if serial==11460 else "tina_log_end")
    if row==2:
     paint.part="tina_soft_snow"
     oval(paint,at+Vector3.UP*radius*.86,Vector3(radius*2.04,.32,length_*1.02) if serial==11460 else Vector3(length_*1.02,.32,radius*2.04))
  for end in [-1,1]:
   Harbor.rod(paint,center+Vector3.UP*.13+axis*end*length_*.39-across*radius*5,center+Vector3.UP*.13+axis*end*length_*.39+across*radius*5,.13,"tina_hollow_bark")
  var result=finish(paint);result.set_meta("source_stack_logs",15);result.set_meta("source_stack_axis",axis);return result
 if serial==11465:
  paint.part="tina_soft_snow"
  oval(paint,Vector3(0,.055,0),Vector3(2.6,.075,2.35))
  oval(paint,Vector3(0,1.20,0),Vector3(2.9,2.75,2.65),true)
  var head=Vector3(-.08,3.05,.03)
  oval(paint,head,Vector3(1.95,1.93,1.85))
  var forward=Vector3(-1,0,.6).normalized();var right=Vector3.UP.cross(forward)
  paint.part="tina_mitten_red"
  for side in [-1,1]:oval(paint,head+forward*.85+right*side*.32+Vector3.UP*.18,Vector3(.19,.21,.14))
  paint.part="tina_snowman_mouth"
  for i in 5:
   var x=(i-2)*.10
   oval(paint,head+forward*.91+right*x+Vector3.UP*(-.30+absf(x)*.12),Vector3(.13,.09,.085))
  var arms=[[-1,Vector3(-2.25,3.85,0)],[1,Vector3(2.22,3.05,0)]]
  for arm in arms:
   var side:int=arm[0];var tip=right*arm[1].x+Vector3.UP*arm[1].y
   var root=right*side*1.12+Vector3.UP*2.0
   Harbor.rod(paint,root,tip,.075,"tina_hollow_bark")
   if side<0:
    paint.part="tina_mitten_red";oval(paint,tip+Vector3.UP*.18,Vector3(.48,.65,.40))
   else:
    Harbor.rod(paint,tip-right*.20-Vector3.UP*.14,tip+right*.38+Vector3.UP*.03,.045,"tina_hollow_bark")
    Harbor.rod(paint,tip-right*.20-Vector3.UP*.14,tip+Vector3.UP*.37,.045,"tina_hollow_bark")
  var result=finish(paint);result.set_meta("source_mitten_tip",right*-2.25+Vector3.UP*4.03);result.set_meta("source_face",forward);return result
 # Source 11484/11485 are cold charred campfires, without flames or large rocks.
 paint.part="tina_soft_snow" if serial==11485 else "tina_camp_ash"
 if serial==11485:oval(paint,Vector3(0,.04,0),Vector3(2.9,.08,2.55))
 else:
  for patch in [[Vector3.ZERO,Vector3(1.35,.035,1.15)],[Vector3(-.5,0,-.3),Vector3(.5,.025,.15)],[Vector3(.55,0,.4),Vector3(.4,.025,.15)],[Vector3(-.3,0,.55),Vector3(.15,.025,.35)],[Vector3(.4,0,-.55),Vector3(.15,.025,.4)]]:
   oval(paint,patch[0]+Vector3.UP*.04,patch[1])
 for ends in [[Vector3(-1.02,.22,-.65),Vector3(.95,.22,.72)],[Vector3(-.38,.32,.95),Vector3(.32,.32,-.98)],[Vector3(-1.1,.19,.28),Vector3(.95,.19,-.15)]]:
  var a:Vector3=ends[0];var b:Vector3=ends[1];var axis=(b-a).normalized()
  Tina.timber_log(paint,(a+b)*.5,axis,a.distance_to(b),.16,"tina_hollow_bark")
  Harbor.rod(paint,a.lerp(b,.17),a.lerp(b,.83),.17,"tina_camp_charcoal")
  if serial==11485:
   paint.part="tina_soft_snow";oval(paint,(a+b)*.5+Vector3.UP*.14,Vector3(1.35,.15,.23) if absf(axis.x)>absf(axis.z) else Vector3(.23,.15,1.35))
 for i in 9:
  var angle=i*TAU/9
  paint.part="tina_camp_charcoal" if i%3==0 else "tina_camp_ash"
  oval(paint,Vector3(cos(angle)*(1.1+(i%2)*.18),.04,sin(angle)*(1.0+(i%2)*.15)),Vector3(.10+(i%3)*.035,.07,.13))
 var result=finish(paint);result.set_meta("source_cold_campfire",true);return result
