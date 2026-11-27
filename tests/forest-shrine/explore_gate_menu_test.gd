extends SceneTree
const Dialogue=preload("res://scripts/forest/forest_dialogue.gd")
const OUT="res://build/Other Files/Asset Toolkit/Explore Access/"
var checks=0
var failures=0

func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("EXPLORE_MENU_FAIL "+message)

func run():
 for extent in[Vector2i(1280,800),Vector2i(1024,640)]:
  root.size=extent
  var dialogue=Dialogue.new();dialogue.speaker="Cross Gate"
  var choices=[]
  for n in 14:choices.append([str(n),"Explore 挑戰 · 原始目的地 %d"%(n+1)])
  dialogue.pages=[{"text":"選擇目的地。","portrait":null,"options":choices}]
  var selected={"value":""};dialogue.chosen.connect(func(value):selected.value=value)
  root.add_child(dialogue)
  for i in 3:await process_frame
  var key=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true;dialogue.handle_input(key)
  for i in 3:await process_frame
  check(dialogue.options.visible,"Normal Space reveal exposes destination choices")
  for n in choices.size()-1:
   key=InputEventKey.new();key.physical_keycode=KEY_RIGHT;key.pressed=true;dialogue.handle_input(key)
   await process_frame
  for i in 3:await process_frame
  var button:Button=dialogue.options.get_child(choices.size()-1)
  var clip:Rect2=dialogue.options.get_parent().get_global_rect()
  check(root.gui_get_focus_owner()==button,"Arrow input reaches the last destination")
  check(clip.encloses(button.get_global_rect().grow(-1.)),"Focused last destination scrolls fully into view")
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+"gate-menu-%dx%d.png"%[extent.x,extent.y])
  key=InputEventKey.new();key.physical_keycode=KEY_ENTER;key.pressed=true;dialogue.handle_input(key)
  check(selected.value=="13","Enter activates the focused destination")
  selected.value=""
  var point=button.get_global_rect().get_center()
  var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
  for pressed in[true,false]:
   var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=point;click.global_position=point;click.pressed=pressed;root.push_input(click,true)
   for i in 2:await process_frame
  check(selected.value=="13","Actual mouse input activates the visible scrolled destination")
  dialogue.queue_free();await process_frame
 print("EXPLORE_MENU_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
