extends SceneTree
const Art=preload("res://scripts/forest/forest_travel_stone_art.gd")
const Street=preload("res://assets/maps/falan/city_street_data.gd")
const OUT="res://build/Other Files/Asset Toolkit/Falan Travel Stones 3D/"
var camera:Camera3D
var errors=0
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1200,1000)
 var stage=Node3D.new();root.add_child(stage)
 var env=WorldEnvironment.new();var environment=Environment.new();env.environment=environment
 environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("535d5d")
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("e8ebed");environment.ambient_light_energy=.60
 environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;stage.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-35,0);sun.light_color=Color("ffe9cd");sun.light_energy=1.1;sun.shadow_enabled=true;stage.add_child(sun)
 var ground=PlaneMesh.new();ground.size=Vector2(200,200)
 Geo.mesh(stage,ground,Vector3(0,-.02,0),Geo.mat("819476"))
 for row in Street.GARDEN_ORNAMENTS:
  var at:Vector2=row[0]-Vector2(36,36)
  if absf(at.x)>3 or absf(at.y)>3:continue
  Art.ornament(stage,Vector3(at.x,0,at.y),row[1])
 Art.crystal(stage,Vector3.ZERO)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=13;stage.add_child(camera)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 if DisplayServer.get_name()!="headless":
  var angle=0
  for direction in [Vector3(1,0,1),Vector3(-1,0,1),Vector3(-1,0,-1),Vector3(1,0,-1)]:
   camera.position=direction*12+Vector3.UP*22;camera.look_at(Vector3.UP*2)
   await capture("kit-angle-"+str(angle))
   if angle==0:
    var before=root.get_texture().get_image().get_data()
    await create_timer(.20).timeout
    await RenderingServer.frame_post_draw
    if before==root.get_texture().get_image().get_data():
     errors+=1;printerr("The solid crystal must visibly turn over time")
    await capture("kit-crystal-turn")
   angle+=1
  for part in ["Crescent","Post","Lectern","Crystal"]:
   var node=Art.piece(stage,part,Vector3(30,0,0))
   camera.size=7 if part=="Crescent" else 4
   camera.position=Vector3(36,5.7,8);camera.look_at(Vector3(30,2 if part=="Crescent" else 1,0))
   await capture("part-"+part)
   stage.remove_child(node);node.free()
 stage.queue_free()
 for i in 3:await process_frame
 print("TRAVEL_STONE_3D_REVIEW failures=",errors)
 quit(errors)
func capture(name_:String):
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 if root.get_texture().get_image().save_png(OUT+name_+".png")!=OK:errors+=1
