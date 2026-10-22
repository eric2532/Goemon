extends SceneTree
## Render the real recovered sprites: their bright heads must lead each spoke,
## including after the camera turns. Catches upright or reversed billboards.
const Fixture=preload("res://scripts/ed_assault_orb_tests.gd")
var checks=0
var failures=0
var output=""

func _initialize():run.call_deferred()

func check(ok: bool,message: String):
 checks+=1
 if not ok:failures+=1
 print("PASS: " if ok else "FAIL: ",message)

func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):output=arg.trim_prefix("--capture-dir=")
 root.size=Vector2i(1280,800)
 var arena=Fixture.OrbArena.new();root.add_child(arena)
 arena.world=Fixture.World.new();arena.add_child(arena.world)
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("101820")
 arena.add_child(environment)
 var hero=Hero.new();arena.player=hero
 var ball=RecoveredEdAssaultOrb.new();ball.game=arena;ball.hero=hero
 arena.add_child(ball);ball.position=Vector3.UP*1.4;ball.set_physics_process(false)
 ball._explode();ball._spread(3.0)
 var camera=Camera3D.new();arena.add_child(camera);camera.make_current()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=42
 var view=0
 for at in [Vector3(10,42,14),Vector3(-28,44,12)]:
  camera.position=at;camera.look_at(Vector3.UP*1.4)
  await process_frame;await process_frame;RenderingServer.force_draw(false)
  var pixels=root.get_texture().get_image()
  var pixel_scale=Vector2(pixels.get_size())/root.get_visible_rect().size
  if not output.is_empty():pixels.save_png(output+"/fire-view-%d.png"%view)
  for i in 8:
   var lift=ball.flames[i].material_override.get_shader_parameter("billboard_lift")
   var origin=ball.flames[i].global_position+Vector3.UP*float(lift if lift!=null else 0)
   var center=camera.unproject_position(origin)*pixel_scale
   var outward=(camera.unproject_position(origin+ball.directions[i]*2)*pixel_scale-center).normalized()
   var bright=Vector2.ZERO;var tail=Vector2.ZERO;var bright_count=0;var tail_count=0
   for y in range(maxi(0,int(center.y)-70),mini(pixels.get_height(),int(center.y)+71)):
    for x in range(maxi(0,int(center.x)-70),mini(pixels.get_width(),int(center.x)+71)):
     var color=pixels.get_pixel(x,y)
     if color.r>.55 and color.g>.4 and color.r>color.b*1.4:
      bright+=Vector2(x,y);bright_count+=1
     elif color.r>.12 and color.g<.35 and color.r>color.g*1.6 and color.r>color.b*1.8:
      tail+=Vector2(x,y);tail_count+=1
   var alignment=-1.0
   if bright_count>0 and tail_count>0:alignment=(bright/bright_count-tail/tail_count).normalized().dot(outward)
   check(alignment>.9,"View %d spoke %d: bright flame head leads outward, red tail trails (dot %.3f, center %s, pixels %d/%d)"%[view,i,alignment,center,bright_count,tail_count])
  view+=1
 ball.queue_free();hero.free();arena.queue_free()
 for i in 6:await process_frame
 print("ED_OUTWARD_FIRE_VISUAL_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
