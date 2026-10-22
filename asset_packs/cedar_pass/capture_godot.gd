extends SceneTree
func _initialize():
 call_deferred("capture")
func capture():
 var scene = load("res://showcase.tscn").instantiate()
 root.add_child(scene)
 root.size = Vector2i(1600,1000)
 for shot in ["overview","shop","tea_house"]:
  if shot == "shop": scene.focus=Vector3(0,2,0);scene.distance=14;scene.angle=.15;scene.elevation=.38
  if shot == "tea_house": scene.focus=Vector3(36,2,0);scene.distance=14;scene.angle=.15;scene.elevation=.38
  for i in range(3): await process_frame
  await RenderingServer.frame_post_draw
  var image = root.get_texture().get_image()
  image.save_png("res://previews/godot_"+shot+".png")
 print("PASS: Godot rendered overview, shop and tea-house screenshots")
 quit()
