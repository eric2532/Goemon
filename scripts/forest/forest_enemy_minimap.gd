extends Control
## Cross Gate area chart. Prepared scenery and live markers share one 2D canvas.
const PrepSkin=preload("res://scripts/forest/preparation_skin.gd")
const UPDATE_INTERVAL=.10
const MARGIN=20.0
const RIM=Color(.76,.69,.48,.65)
const DOT=Color(1.0,.38,.32,.98)
const PLAYER=Color("8df3eb")
var game: Node
var markers=PackedVector2Array()
var player_marker=Vector2.ZERO
var update_clock=0.0
var dot_instances:MultiMesh
var dot_radius=-1.0
var chart=preload("res://scripts/forest/forest_falan_chart.gd").new()
var expanded=false
var compact_size=168.0
var frame=PrepSkin.compact_panel()
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_mode=Control.FOCUS_NONE
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 visible=false
 dot_instances=MultiMesh.new();dot_instances.transform_format=MultiMesh.TRANSFORM_2D
 # A color buffer keeps WebGL's canvas pass from leaving an integer default in the scene's UV2 slot.
 dot_instances.use_colors=OS.has_feature("web")
 set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
func set_layout(hud_scale:float,available_height:float):
 var diameter=minf(clampf(168.0*hud_scale,128,210),maxf(64,available_height))
 compact_size=diameter
 update_layout()
func update_layout():
 var screen=get_viewport_rect().size
 var target=Vector2(minf(screen.x-44.0,1060),minf(screen.y-84.0,670)) if expanded else Vector2.ONE*compact_size
 var inset=(screen-target)*.5 if expanded else Vector2.ONE*MARGIN
 if size.is_equal_approx(target) and is_equal_approx(offset_left,inset.x):return
 offset_left=inset.x;offset_right=inset.x+target.x;offset_top=-inset.y-target.y;offset_bottom=-inset.y
 z_index=50 if expanded else 0
 _prepare_dot_mesh()
 if visible:refresh()
 else:queue_redraw()
func set_active(active:bool):
 if visible==active:return
 visible=active
 if active:refresh();update_clock=UPDATE_INTERVAL
 else:
  if expanded:
   expanded=false
   update_layout()
  markers.clear();dot_instances.visible_instance_count=0
func handle_map_input(event:InputEvent)->bool:
 if not visible or chart.texture==null or not event is InputEventKey:return false
 if event.alt_pressed or event.ctrl_pressed or event.meta_pressed or event.shift_pressed:return false
 var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
 if code!=KEY_M and not (expanded and code==KEY_ESCAPE):return false
 if event.pressed and not event.echo:
  expanded=not expanded
  update_layout()
 return true
func refresh():
 markers.clear()
 if not is_instance_valid(game) or game.model==null:return
 var model=game.model
 chart.refresh(model)
 if is_instance_valid(game.get("explore_access")):
  chart.pins=chart.pins.filter(func(pin):return not pin.get("explore_encounter",false))
  for pin in game.explore_access.pins():
   pin.explore_encounter=true;chart.pins.append(pin)
 var rectangles=map_rectangles()
 player_marker=project_point(game.player.global_position,rectangles[0],rectangles[1])
 var runtime=game.get("army_runtime");var view=runtime.snapshot_view if is_instance_valid(runtime) else null
 var handles:Dictionary=runtime.handles if view!=null else {}
 # Bosses remain visible outside shared sight; ordinary enemies stay off the map.
 for enemy in model.enemies.values():
  if enemy.hp<=0 or not enemy.get("boss",false):continue
  if is_instance_valid(game.get("explore_access")):
   var access=game.explore_access
   if access.enabled():access.discover(enemy)
   var key=access.scope()+":"+access.group(enemy)
   if not access.encounters.get(key,{}).get("discovered",false):continue
  var point:Vector3=enemy.pos
  if view!=null:
   var handle:int=handles.get(enemy.id,0);var slot:int=handle&0xffffffff
   var index:int=view.rows_by_slot[slot] if handle!=0 and slot<view.rows_by_slot.size() else -1
   if index>=0 and index<view.handles.size() and view.handles[index]==handle:point=view.positions[index]
  markers.append(project_point(point,rectangles[0],rectangles[1]))
 # Reuse one instanced circle mesh, avoiding hundreds of separate canvas draws.
 if markers.size()>dot_instances.instance_count:dot_instances.instance_count=nearest_po2(markers.size())
 dot_instances.visible_instance_count=markers.size()
 for i in markers.size():dot_instances.set_instance_transform_2d(i,Transform2D(0.0,markers[i]))
 queue_redraw()
func map_position(point:Vector3)->Vector2:
 var rectangles=map_rectangles()
 return project_point(point,rectangles[0],rectangles[1])
func map_rectangles()->Array[Rect2]:
 var model=game.model
 if chart.texture!=null:
  return [Rect2(chart.bounds.position*model.falan_scale,chart.bounds.size*model.falan_scale),chart_rect()]
 var dimensions=Vector2(model.navigation_region.size)*model.CELL
 var origin=(Vector2(model.navigation_region.position)+Vector2(model.navigation_region.size)*.5-Vector2.ONE*.5)*model.CELL
 return [Rect2(origin-dimensions*.5,dimensions),Rect2(Vector2.ONE*7.0,size-Vector2.ONE*14.0)]
func project_point(point:Vector3,source:Rect2,plot:Rect2)->Vector2:
 return plot.position+((chart.map_frame*Vector2(point.x,point.z)-source.position)/source.size).clamp(Vector2.ZERO,Vector2.ONE)*plot.size
func chart_rect()->Rect2:
 var pad=Vector2(22,60) if expanded else Vector2(10,29)
 var space=size-pad-Vector2(26+minf(272,size.x*.34),52) if expanded else size-pad-Vector2(10,29)
 var span=chart.bounds.size*minf(space.x/chart.bounds.size.x,space.y/chart.bounds.size.y)
 return Rect2(pad+(space-span)*.5,span)
func chart_position(point:Vector2)->Vector2:
 var rect=chart_rect()
 return rect.position+((chart.map_frame*point-chart.bounds.position)/chart.bounds.size).clamp(Vector2.ZERO,Vector2.ONE)*rect.size
func _process(delta:float):
 if not visible or not is_visible_in_tree() or not is_instance_valid(game) or game.paused:return
 update_clock-=delta
 if update_clock<=0:
  refresh();update_clock=UPDATE_INTERVAL
func _prepare_dot_mesh():
 var radius=clampf(size.x/168.0*2.3,2.0,2.8)
 if is_equal_approx(radius,dot_radius):return
 dot_radius=radius
 var vertices=PackedVector2Array();var colors=PackedColorArray()
 var shadow=Color(.07,.055,.04,.72)
 for i in 12:
  var a=Vector2.from_angle(TAU*i/12.0);var b=Vector2.from_angle(TAU*(i+1)/12.0)
  for point in [Vector2.ZERO,a*radius,b*radius]:vertices.append(point);colors.append(chart.BOSS)
  for point in [a*radius,a*(radius+.8),b*(radius+.8),a*radius,b*(radius+.8),b*radius]:vertices.append(point);colors.append(shadow)
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 dot_instances.mesh=mesh
func _draw():
 if size.x<=0 or size.y<=0:return
 var rect=Rect2(Vector2.ONE*1.5,size-Vector2.ONE*3.0)
 draw_style_box(frame,rect)
 if chart.texture!=null:draw_chart()
 if dot_instances.mesh!=null:draw_multimesh(dot_instances,null)
 if is_instance_valid(game) and game.model.has_enemy_camps():
  for camp in game.model.portals:
   var point=map_position(Vector3(camp.x*6,0,camp.z*6))
   draw_rect(Rect2(point-Vector2.ONE*4,Vector2.ONE*8),DOT if camp.hp>0 else Color("6e8e72"))
  if game.model.enemy_camps_prototype:
   var statue=map_position(Vector3(0,0,198))
   draw_rect(Rect2(statue-Vector2.ONE*5,Vector2.ONE*10),Color("f3cf78"),false,2)
 # Draw the player last so they remain visible when enemies overlap them.
 var radius=clampf(size.x/168.0*4.2,3.6,5.0)
 var diamond=PackedVector2Array([player_marker+Vector2(0,-radius),player_marker+Vector2(radius,0),player_marker+Vector2(0,radius),player_marker+Vector2(-radius,0)])
 draw_circle(player_marker,radius+1.3,Color(.07,.055,.04,.9))
 draw_colored_polygon(diamond,PLAYER)
 diamond.append(diamond[0]);draw_polyline(diamond,Color(.98,.93,.82,.9),1.0,true)
 if chart.texture!=null:
  var forward:Vector3=-game.camera_rig.camera.global_basis.z
  var facing=chart.map_frame.basis_xform(Vector2(forward.x,forward.z)).normalized()
  draw_line(player_marker+facing*radius,player_marker+facing*(radius+6),PLAYER,2.0,true)

func draw_chart():
 var font=PrepSkin.FONT
 var text_color=PrepSkin.PAPER
 var plot=chart_rect()
 draw_rect(plot.grow(3),Color("182a30"))
 draw_rect(plot,Color("34483e"))
 draw_texture_rect(chart.illustration if chart.illustration!=null else chart.texture,plot,false)
 draw_rect(plot.grow(1),Color("c8bc94"),false,1.0)
 var title_width=size.x-235 if expanded else size.x-24
 draw_string(font,Vector2(22,38) if expanded else Vector2(12,21),chart.title,HORIZONTAL_ALIGNMENT_LEFT,title_width,24 if expanded else 13,text_color)
 var caption="Wave %d"%game.model.wave if game.model.terrain_detail=="arena" else game.explorer_clock.caption()
 draw_string(font,Vector2(size.x-212,36) if expanded else Vector2(12,size.y-11),caption,HORIZONTAL_ALIGNMENT_RIGHT if expanded else HORIZONTAL_ALIGNMENT_LEFT,190 if expanded else size.x-24,16 if expanded else 11,text_color)
 var compass=plot.position+Vector2(plot.size.x-12,15)
 draw_circle(compass,10,Color("25343cdd"))
 draw_string(font,compass+Vector2(-4,4),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,text_color)
 if expanded:
  var x=22.0
  for entry in [[PLAYER,"You"],[chart.PIN,"Exits"],[chart.BOSS,"Boss"]]:
   draw_circle(Vector2(x+4,size.y-26),3.5,entry[0])
   draw_string(font,Vector2(x+16,size.y-21),entry[1],HORIZONTAL_ALIGNMENT_LEFT,84,14,text_color)
   x+=105
 var legend_x=size.x-minf(272,size.x*.34)
 var label_y=96.0
 if expanded:
  draw_line(Vector2(legend_x-14,60),Vector2(legend_x-14,size.y-52),RIM,1)
  draw_string(font,Vector2(legend_x,73),"AREA GUIDE",HORIZONTAL_ALIGNMENT_LEFT,size.x-legend_x-18,14,Color("dacb9c"))
 var used=[player_marker]
 for i in chart.pins.size():
  var pin:Dictionary=chart.pins[i]
  var anchor=chart_position(pin.at)
  var at=anchor
  if expanded and used.any(func(p):return p.distance_squared_to(at)<19.0*19.0):
   for offset:Vector2 in [Vector2(0,-23),Vector2(23,0),Vector2(-23,0),Vector2(0,23)]:
    var candidate=anchor+offset
    if not plot.grow(-8.0).has_point(candidate) or used.any(func(p):return p.distance_squared_to(candidate)<19.0*19.0):continue
    at=candidate
    draw_line(anchor,at,pin.color,1.0,true)
    break
  used.append(at)
  draw_circle(at,8.5 if expanded else 4.0,Color("211c17"))
  draw_circle(at,7.0 if expanded else 2.8,pin.color)
  if not expanded:continue
  var number=str(i+1)
  draw_string(font,at+Vector2(-3.7,3.6) if i<9 else at+Vector2(-6.4,3.6),number,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("29231c"))
  if label_y>size.y-52.0:continue
  draw_string(font,Vector2(legend_x,label_y),number+"   "+pin.label,HORIZONTAL_ALIGNMENT_LEFT,size.x-legend_x-18,14,pin.color)
  label_y+=24.0
