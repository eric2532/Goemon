extends Control
## Simple battlefield overview with enemies and the player. One 2D canvas, no extra world rendering.
const UPDATE_INTERVAL=.10
const MARGIN=20.0
const BACKGROUND=Color(.035,.075,.065,.34)
const RIM=Color(.76,.69,.48,.65)
const DOT=Color(1.0,.38,.32,.98)
const PLAYER=Color(.38,1.0,.95,1.0)
var game: Node
var markers=PackedVector2Array()
var player_marker=Vector2.ZERO
var update_clock=0.0
var dot_instances:MultiMesh
var dot_radius=-1.0
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_mode=Control.FOCUS_NONE
 visible=false
 dot_instances=MultiMesh.new();dot_instances.transform_format=MultiMesh.TRANSFORM_2D
 set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
func set_layout(hud_scale:float,available_height:float):
 var diameter=minf(clampf(168.0*hud_scale,128,210),maxf(64,available_height))
 if is_equal_approx(size.x,diameter):return
 offset_left=MARGIN;offset_right=MARGIN+diameter;offset_top=-MARGIN-diameter;offset_bottom=-MARGIN
 _prepare_dot_mesh()
 if visible:refresh()
 else:queue_redraw()
func set_active(active:bool):
 if visible==active:return
 visible=active
 if active:refresh();update_clock=UPDATE_INTERVAL
 else:
  markers.clear();dot_instances.visible_instance_count=0
func refresh():
 markers.clear()
 if not is_instance_valid(game) or game.model==null:return
 var model=game.model
 player_marker=map_position(game.player.global_position)
 var runtime=game.get("army_runtime");var view=runtime.snapshot_view if is_instance_valid(runtime) else null
 var handles:Dictionary=runtime.handles if view!=null else {}
 var dimensions=Vector2(model.navigation_region.size)*model.CELL
 var origin=(Vector2(model.navigation_region.position)+Vector2(model.navigation_region.size)*.5-Vector2.ONE*.5)*model.CELL
 var middle=size*.5;var half=middle-Vector2.ONE*7.0
 # Read simulation positions directly, including portals outside shared sight.
 # Friendly units and the immortal training dummy are not wave enemies.
 for enemy in model.enemies.values():
  if enemy.hp<=0:continue
  var point:Vector3=enemy.pos
  if view!=null:
   var handle:int=handles.get(enemy.id,0);var slot:int=handle&0xffffffff
   var index:int=view.rows_by_slot[slot] if handle!=0 and slot<view.rows_by_slot.size() else -1
   if index>=0 and index<view.handles.size() and view.handles[index]==handle:point=view.positions[index]
  var offset=(Vector2(point.x,point.z)-origin)/dimensions
  markers.append(middle+(offset*half*2.0).clamp(-half,half))
 # Reuse one instanced circle mesh, avoiding hundreds of separate canvas draws.
 if markers.size()>dot_instances.instance_count:dot_instances.instance_count=nearest_po2(markers.size())
 dot_instances.visible_instance_count=markers.size()
 for i in markers.size():dot_instances.set_instance_transform_2d(i,Transform2D(0.0,markers[i]))
 queue_redraw()
func map_position(point:Vector3)->Vector2:
 var model=game.model
 var dimensions=Vector2(model.navigation_region.size)*model.CELL
 var origin=(Vector2(model.navigation_region.position)+Vector2(model.navigation_region.size)*.5-Vector2.ONE*.5)*model.CELL
 var offset=(Vector2(point.x,point.z)-origin)/dimensions
 var half=size*.5-Vector2.ONE*7.0
 return size*.5+(offset*half*2.0).clamp(-half,half)
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
 var shadow=Color(.025,.045,.035,.72)
 for i in 12:
  var a=Vector2.from_angle(TAU*i/12.0);var b=Vector2.from_angle(TAU*(i+1)/12.0)
  for point in [Vector2.ZERO,a*radius,b*radius]:vertices.append(point);colors.append(DOT)
  for point in [a*radius,a*(radius+.8),b*(radius+.8),a*radius,b*(radius+.8),b*radius]:vertices.append(point);colors.append(shadow)
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 dot_instances.mesh=mesh
func _draw():
 if size.x<=0 or size.y<=0:return
 var rect=Rect2(Vector2.ONE*1.5,size-Vector2.ONE*3.0)
 draw_rect(rect,BACKGROUND)
 draw_rect(rect,RIM,false,1.5)
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
 draw_circle(player_marker,radius+1.3,Color(.025,.045,.035,.9))
 draw_colored_polygon(diamond,PLAYER)
 diamond.append(diamond[0]);draw_polyline(diamond,Color(.9,1,1,.9),1.0,true)
