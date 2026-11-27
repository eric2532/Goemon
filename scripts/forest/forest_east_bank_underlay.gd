extends RefCounted
## Visual-only replacement of source water-cell terrain by enrolled native banks.
## Callers must cover the complete visible ground mesh and refuse any existing
## enabled visibility owner. No height, collision, mask or support arrays change.
static var prepared:Dictionary={}

static func visual_bounds(mesh:Mesh)->Rect2:
 var box=mesh.get_aabb();var low=Vector2(box.position.x,box.position.z);var high=Vector2(box.end.x,box.end.z)
 low=(low/3.).floor()*3.-Vector2.ONE*1.5
 high=(high/3.).ceil()*3.+Vector2.ONE*1.5
 return Rect2(low,high-low)

static func settings(bounds:Rect2,placements:Array,source_water_cuts:Array=[])->Dictionary:
 var size_=Vector2i((bounds.size/3.).round())
 assert(size_.x>0 and size_.y>0 and Vector2(size_)*3.==bounds.size,"Underlay bounds must contain complete3m visual cells")
 var cuts={}
 for row:Dictionary in placements:
  assert(int(row.serial) in range(12500,12536),"Only explicitly enrolled lower native banks replace their terrain underlay")
  var anchor:Vector2=row.anchor;var cell=Vector2i(((anchor-bounds.position)/3.).floor())
  assert(Rect2i(Vector2i.ZERO,size_).has_point(cell),"Every enrolled bank must lie inside complete visual bounds")
  assert((bounds.position+(Vector2(cell)+Vector2.ONE*.5)*3.).distance_to(anchor)<.0001,"Bank source anchor must match the terrain-local3m grid")
  var frame:Transform2D=row.get("frame",Transform2D.IDENTITY)
  assert(is_equal_approx(frame.x.length(),1.) and is_equal_approx(frame.y.length(),1.) and absf(frame.x.dot(frame.y))<.0001 and minf(absf(frame.x.x),absf(frame.x.y))<.0001,"Underlay cutouts require the original unit quarter-turn source frame")
  assert(not cuts.has(cell),"A source bank cell may have only one visual replacement")
  cuts[cell]=true
 var cells=cuts.keys();cells.sort_custom(func(a:Vector2i,b:Vector2i):return a.y<b.y or (a.y==b.y and a.x<b.x))
 var water_cells=[]
 for row:Dictionary in source_water_cuts:
  assert(int(row.source_bg) in range(5000,5009),"Additional underlay cuts require explicit original BGwater")
  var anchor:Vector2=row.anchor;var cell=Vector2i(((anchor-bounds.position)/3.).floor())
  assert(Rect2i(Vector2i.ZERO,size_).has_point(cell) and (bounds.position+(Vector2(cell)+Vector2.ONE*.5)*3.).distance_to(anchor)<.0001,"Source-water cuts must use exact terrain-local3m cells")
  assert(not cuts.has(cell),"Source-water cuts remain distinct from bank cells and each other")
  cuts[cell]=true;water_cells.append(cell)
 water_cells.sort_custom(func(a:Vector2i,b:Vector2i):return a.y<b.y or (a.y==b.y and a.x<b.x))
 var key=var_to_str([bounds,cells,water_cells])
 if not prepared.has(key):
  var image=Image.create(size_.x,size_.y,false,Image.FORMAT_RGBA8);image.fill(Color(1,1,1,1))
  for cell:Vector2i in cuts:image.set_pixelv(cell,Color(1,0,1,1))
  var texture=ImageTexture.create_from_image(image)
  texture.set_meta("source_cpu_image",image);texture.set_meta("source_bank_cut_cells",cells);texture.set_meta("source_water_cut_cells",water_cells);texture.set_meta("source_bank_visual_bounds",bounds)
  prepared[key]=texture
 return {"use_native_land_visibility":true,"native_land_visibility":prepared[key],"native_visibility_bounds":Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y)}
