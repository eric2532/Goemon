extends SceneTree
## Native Metal gate: compare original authored body silhouettes on actual Kai supports.
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Large Army Rebuild/"
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
var failures=0
func _initialize():run.call_deferred()
func capture()->Image:
 await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image();image.resize(640,480);return image
func run():
 if RenderingServer.get_rendering_device()==null:printerr("ARMY_VISUAL_RESULT requires native GPU");quit(1);return
 root.size=Vector2i(640,480);root.use_taa=false;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_DISABLED
 var fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture);var game=await fixture.make_game("kai")
 Engine.time_scale=1;Engine.physics_ticks_per_second=60;DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);game.ui.hide();game.player.hide();game.crowd.hide();game.set_process_input(false);game.set_process_unhandled_input(false);game.camera_rig.set_process_input(false)
 var camera=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=63
 for helper in game.explorer_helpers.pool:helper.hide()
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 var renderer=load("res://scripts/forest/crowd/army_renderer.gd").new();root.add_child(renderer);renderer.configure(game);renderer.use_native_buffers(runtime.native);renderer.presentation.hide()
 if "--legacy-pack" in OS.get_cmdline_user_args():renderer.native_packer=null;renderer.health.hide()
 var supports={"flat":Vector3(0,0,60)}
 var terrain=game.model.terrain
 var hill=Vector3.ZERO;var highest=-INF;var bridge=Vector3.ZERO
 for index in terrain.heights.size():
  var p=Vector3((index%terrain.width)*terrain.spacing-240,0,(index/terrain.width)*terrain.spacing-240)
  if absf(p.x)>190 or absf(p.z)>190:continue
  p.y=game.model.surface_height(p.x,p.z)
  if p.y>highest and terrain.disk_clear(p,.4):highest=p.y;hill=p
  if terrain.bridges[index]!=0 and terrain.disk_clear(p,.4):bridge=p
 supports.hill=hill;supports.bridge=bridge
 for layout in supports:
  var point:Vector3=supports[layout];point.y=game.model.surface_height(point.x,point.z)
  camera.global_position=point+Vector3(11,10,17);camera.look_at(point+Vector3.UP*2.5)
  var sheet=Image.create(640*4,480*4,false,Image.FORMAT_RGB8);var slot=0
  for kind in [0,1,3,11,5,7,8,10]:
   runtime.clear();runtime.spawn(1,0 if kind in [0,1,3] else 1,kind,point,200,.4)
   var snapshot=runtime.render_snapshot();var original:Node3D
   var posed:Node3D
   if kind in [0,1,3]:
    var mesh=MeshInstance3D.new();mesh.mesh=cpu_soldier(kind);root.add_child(mesh);mesh.position=point;original=mesh
    snapshot.pose_rows[0]=int(Soldier.data(kind).get_meta("clips")["Source__801b0118"].rows[12])
   else:
    original=game.explorer_helpers.pool.filter(func(u):return u.kit_id==kind)[0]
    original.position=point;original.model.rotation.y=PI;original.facing=Vector3.BACK
    var c=original.active_ability;var actor=original.model.actor;c.active=true;c.reset_run();actor.seed=0;c.player.bladeSide=load("res://assets/crowd/army_kit_profiles.tres").get_meta("profiles")[kind].primary[0].get("swingSide",1);c.player.rangerShots=0;c.aim=Vector3.BACK*10;c.player.pos=Vector3.ZERO
    c.Actions.begin_attack(c,c.Actions.primary_config(c,0),0)
    for frame in 13:
     var state:Dictionary=c.player.duplicate(true);state.graphicsQuality=0;state.grounded=true;state.vertical=0;state.flip=-1;state.landing=0;state.motionSpeed=0;state.localMotion=Vector3.ZERO;state.attack.time=frame/60.0;state.meleeVisualScale=state.attack.get("meleeVisualScale",1)
     actor.animate_pose(state,1.0/60 if frame else 0,frame/60.0,0)
    snapshot.render_actions[0]=8;snapshot.render_time[0]=.2;snapshot.action_indices[0]=0
   if kind not in [0,1,3]:original.health_display.hide()
   for label in original.find_children("*","Label3D",true,false):label.hide()
   for mesh in original.find_children("*","GeometryInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   original.hide();renderer.hide();var background:Image=await capture()
   original.show();var source:Image=await capture()
   original.hide();renderer.show();renderer.present(snapshot,[]);renderer.health.hide();var native:Image=await capture()
   var union=0;var mismatch=0;var color_error=0.0;var overlap=0
   for y in range(40,440):
    for x in range(80,560):
     var bg=background.get_pixel(x,y);var a=source.get_pixel(x,y);var b=native.get_pixel(x,y)
     var am=(Vector3(a.r,a.g,a.b)-Vector3(bg.r,bg.g,bg.b)).length()>.12
     var bm=(Vector3(b.r,b.g,b.b)-Vector3(bg.r,bg.g,bg.b)).length()>.12
     if am or bm:union+=1
     if am!=bm:mismatch+=1
     if am and bm:overlap+=1;color_error+=(Vector3(a.r,a.g,a.b)-Vector3(b.r,b.g,b.b)).length()
   var error=float(mismatch)/maxi(1,union);var colors=color_error/maxi(1,overlap)
   if union<100 or error>.04 or colors>.06:failures+=1
   print("ARMY_VISUAL kind=",kind," support=",layout," height=",point.y," pixels=",union," silhouette_error=",error," mean_color_error=",colors," draw_calls=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
   sheet.blit_rect(source,Rect2i(0,0,640,480),Vector2i((slot%4)*640,(slot/4)*960));sheet.blit_rect(native,Rect2i(0,0,640,480),Vector2i((slot%4)*640,(slot/4)*960+480));slot+=1
   if kind in [0,1,3]:original.queue_free()
  sheet.save_png(OUT+"army_visual_"+("gd_" if "--legacy-pack" in OS.get_cmdline_user_args() else "native_")+layout+".png")
 runtime.clear();runtime.free();renderer.queue_free();await fixture.close();fixture.queue_free();await process_frame
 print("ARMY_VISUAL_RESULT failures=",failures);quit(1 if failures else 0)
func cpu_soldier(kind:int)->ArrayMesh:
 var resource=Soldier.data(kind);var mesh:ArrayMesh=resource.get_meta("mesh");var image:Image=resource.get_meta("pose_texture").get_image();var row:int=resource.get_meta("clips")["Source__801b0118"].rows[12];var result=ArrayMesh.new();var reference=Soldier.make_mesh(kind,true)
 for surface in mesh.get_surface_count():
  var a=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
  for i in vertices.size():
   var part=roundi(a[Mesh.ARRAY_TEX_UV2][i].x);var x=image.get_pixel(part*3,row);var y=image.get_pixel(part*3+1,row);var z=image.get_pixel(part*3+2,row)
   var basis=Basis(Vector3(x.r,x.g,x.b),Vector3(y.r,y.g,y.b),Vector3(z.r,z.g,z.b));vertices[i]=basis*vertices[i]+Vector3(x.a,y.a,z.a);normals[i]=(basis*normals[i]).normalized()
  a[Mesh.ARRAY_VERTEX]=vertices;a[Mesh.ARRAY_NORMAL]=normals
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
  var material:ShaderMaterial=reference.surface_get_material(surface)
  var shader=Shader.new();var code=material.shader.code;var begin=code.find("void vertex(){");var end=code.find("void fragment(){")
  shader.code=code.substr(0,begin)+"void vertex(){frozen_tint=0.0;surface_row=0.0;}\n"+code.substr(end);material.shader=shader
  result.surface_set_material(surface,material)
 Soldier.update_environment(result,root.world_3d.environment)
 return result
