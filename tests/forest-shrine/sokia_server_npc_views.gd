extends "res://tests/forest-shrine/sokia_server_npcs_review.gd"
## Same real F/port checks; only the subsequent fixed camera study moves to clear native ground.
func position_camera(cell:Vector2i,yaw_:float):
 var point=game.model.world_point(Original.source_point(game.model.falan_floor,cell),.15)
 game.player.position=point;game.model.hero_position=point;game.player.reset_physics_interpolation()
 game.camera_rig.yaw=yaw_;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH
 game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT;game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
 game.camera_rig.impulse=0.;game.camera_rig.kick_strength=0.;game.camera_rig.kick_age=100.;game.camera_rig.camera.fov=63.
 game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
func projected_body(sprite:Sprite3D)->Rect2:
 var camera:Camera3D=game.camera_rig.camera
 var scale_=sprite.global_basis.get_scale();var unit=sprite.pixel_size*scale_.x
 var size_=(sprite.region_rect.size if sprite.region_enabled else Vector2(sprite.texture.get_width(),sprite.texture.get_height()))*unit
 var right=camera.global_basis.x;var up=camera.global_basis.y
 var center=sprite.global_position+(right*sprite.offset.x+up*sprite.offset.y)*unit
 var low=Vector2.INF;var high=-low
 for x in [-.5,.5]:
  for y in [-.5,.5]:
   var corner=center+right*size_.x*x+up*size_.y*y
   if camera.is_position_behind(corner):return Rect2()
   var pixel=camera.unproject_position(corner);low=low.min(pixel);high=high.max(pixel)
 return Rect2(low,high-low)
func take_view(label_:String,station:Vector2i,yaw_:float=0.,screen_offset:float=0.):
 if DisplayServer.get_name()=="headless":return
 var id=label_.get_file().split("-npc-")[1];var entry:Dictionary=find_actor(id)
 if entry.is_empty():check(false,"Named source actor remains available for clear study "+id);return
 var sprite:Sprite3D=entry.node;var actor:Dictionary=sprite.get_meta("npc_record")
 var anchor=Vector2i(actor.cell[0],actor.cell[1]);var state=Original.state(game.model.falan_floor)
 var original_station=game.model.world_point(Original.source_point(game.model.falan_floor,station),.15)
 var viewport=Rect2(Vector2(32,32),Vector2(root.size)-Vector2(64,64));var best={};var tested={}
 for radius in [1,2,3,4,5,6,8,10,12,16,20]:
  for angle in 16:
   var offset=Vector2.from_angle(TAU*float(angle)/16.)*radius
   var cell=anchor+Vector2i(offset.round())
   if tested.has(cell):continue
   tested[cell]=true
   if not Original.open(state.bits,state.size,cell):continue
   var point=game.model.world_point(Original.source_point(game.model.falan_floor,cell),.15)
   if not game.army_runtime.native.can_reach(point,original_station,.4):continue
   var toward=sprite.global_position-point;toward.y=0
   var turn=atan2(-toward.x,-toward.z)
   position_camera(cell,turn)
   if game.camera_rig.current_distance<6.:continue
   var bounds=projected_body(sprite)
   if not bounds.has_area()or not viewport.encloses(bounds):continue
   var camera:Camera3D=game.camera_rig.camera
   var foot=camera.unproject_position(game.player.position);var head=camera.unproject_position(game.player.position+Vector3.UP*4.)
   var hero=Rect2(Vector2(minf(foot.x,head.x)-55,minf(foot.y,head.y)),Vector2(absf(foot.x-head.x)+110,absf(foot.y-head.y)))
   if bounds.intersects(hero):continue
   var center=sprite.global_position+camera.global_basis.y*(sprite.offset.y*sprite.pixel_size*sprite.global_basis.get_scale().y)
   if not game._ryo_clear_path(camera.global_position,center):continue
   var score=bounds.get_area()
   if best.is_empty()or score>best.score:best={"cell":cell,"yaw":turn,"score":score,"body_bounds":str(bounds)}
 check(not best.is_empty(),"A connected normal camera can frame the complete original actor without hero overlap "+id)
 if best.is_empty():
  await super.take_view(label_+"-clear-unresolved",station,yaw_,screen_offset);return
 if not npc_report.has("clear_studies"):npc_report.clear_studies=[]
 npc_report.clear_studies.append({"actor":id,"source_cell":actor.cell,"camera_station":str(best.cell),"body_bounds":best.body_bounds,"purpose":"Presentation study after actual F; actor/source placement unchanged; connected native ground, normal63degree camera and visible hero."})
 await super.take_view(label_+"-clear",best.cell,best.yaw,0.)
