extends Control
signal finished
signal chosen(value:String)
const MenuSkin=preload("res://scripts/forest/preparation_skin.gd")
const LETTERS_PER_SECOND=18.0
var speaker=""
var pages:Array=[]
var page=0
var canvas:Control
var portrait:TextureRect
var panel:Panel
var body:Label
var hint:Label
var revealed=0.0
var closing=false
var options:HBoxContainer
var entry:LineEdit

func _ready():
 assert(not pages.is_empty(),"Dialogue needs at least one page")
 name="ForestDialogue";process_mode=Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();shade.color=Color(0,0,0,.20);add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 canvas=Control.new();canvas.size=Vector2(1440,900);add_child(canvas)
 portrait=TextureRect.new()
 portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 portrait.position=Vector2(48,24);portrait.size=Vector2(544,680);canvas.add_child(portrait)
 panel=Panel.new();panel.add_theme_stylebox_override("panel",MenuSkin.panel())
 panel.position=Vector2(40,680);panel.size=Vector2(1360,190);canvas.add_child(panel)
 var badge=Panel.new();badge.add_theme_stylebox_override("panel",MenuSkin.compact_panel())
 var name_width=maxf(180,MenuSkin.FONT.get_string_size(speaker,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x+40)
 badge.position=Vector2(84,650);badge.size=Vector2(name_width,54);canvas.add_child(badge)
 var name_label=label(speaker,Vector2(104,655),Vector2(name_width-40,44),30)
 name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 body=label("",Vector2(88,720),Vector2(1240,96),32)
 body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_theme_constant_override("line_spacing",8)
 body.visible_characters=0
 hint=label("Space · 顯示全文",Vector2(1030,823),Vector2(290,30),22)
 hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 var choices_scroll=ScrollContainer.new();choices_scroll.position=Vector2(88,818);choices_scroll.size=Vector2(1264,56);choices_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;choices_scroll.follow_focus=true;canvas.add_child(choices_scroll)
 options=HBoxContainer.new();options.add_theme_constant_override("separation",12);choices_scroll.add_child(options)
 entry=LineEdit.new();entry.position=Vector2(88,771);entry.size=Vector2(1210,38);entry.max_length=120;entry.placeholder_text="輸入留言（最多 120 字）";canvas.add_child(entry)
 entry.add_theme_font_override("font",MenuSkin.FONT);entry.add_theme_font_size_override("font_size",24)
 entry.text_submitted.connect(func(_text):
  if pages[page].get("entry",false) and not pages[page].get("options",[]).is_empty():chosen.emit(str(pages[page].options[0][0])))
 show_page()
 resized.connect(layout);layout()

func show_page():
 portrait.texture=pages[page].portrait
 body.text=pages[page].text
 entry.visible=pages[page].get("entry",false);entry.text=""
 body.size.y=48 if entry.visible else 96
 revealed=0.0;closing=false;_process(0)
 for child in options.get_children():options.remove_child(child);child.queue_free()
 for choice in pages[page].get("options",[]):
  var button=Button.new();button.text=choice[1];button.custom_minimum_size=Vector2(140,40)
  MenuSkin.apply_button(button);button.pressed.connect(chosen.emit.bind(str(choice[0])));options.add_child(button)
 options.hide()

func label(value:String,at:Vector2,extent:Vector2,font_size:int)->Label:
 var control=Label.new();control.text=value;control.position=at;control.size=extent
 control.add_theme_font_override("font",MenuSkin.FONT);control.add_theme_font_size_override("font_size",font_size)
 control.add_theme_color_override("font_color",MenuSkin.PAPER);control.mouse_filter=Control.MOUSE_FILTER_IGNORE
 canvas.add_child(control);return control

func layout():
 var factor=minf(size.x/1440.0,size.y/900.0)
 canvas.scale=Vector2.ONE*factor;canvas.position=(size-canvas.size*factor)*.5

func _process(delta):
 revealed=minf(body.get_total_character_count(),revealed+delta*LETTERS_PER_SECOND)
 body.visible_characters=int(revealed)
 hint.text="Space · 繼續 ▼" if body.visible_characters>=body.get_total_character_count() else "Space · 顯示全文"
 if options!=null:
  var was_visible=options.visible
  options.visible=not pages[page].get("options",[]).is_empty() and body.visible_characters>=body.get_total_character_count()
  if options.visible and not was_visible and not entry.visible:options.get_child(0).grab_focus()
  if options.visible:hint.text="← → · 選擇　Enter · 確認"
  hint.position.y=687 if options.visible else 823

func handle_input(event:InputEvent):
 if not event is InputEventKey or event.echo:return
 if entry.visible and entry.has_focus():
  if event.pressed and event.keycode==KEY_ESCAPE:chosen.emit("cancel");get_viewport().set_input_as_handled()
  return
 get_viewport().set_input_as_handled()
 var key=event.physical_keycode if event.physical_keycode!=0 else event.keycode
 if options.visible:
  if event.pressed and key==KEY_ESCAPE:chosen.emit("cancel")
  elif event.pressed and key in [KEY_LEFT,KEY_RIGHT]:
   var index=options.get_children().find(get_viewport().gui_get_focus_owner())
   options.get_child(posmod(index+(-1 if key==KEY_LEFT else 1),options.get_child_count())).grab_focus()
  elif event.pressed and key==KEY_ENTER:
   var focused=get_viewport().gui_get_focus_owner()
   if focused!=null and focused.get_parent()==options:focused.pressed.emit()
  return
 if key!=KEY_SPACE:return
 if not event.pressed:
  # Resume on release so the dialogue's Space cannot become a gameplay jump.
  if closing:
   if page+1<pages.size():
    page+=1;show_page()
   else:finished.emit()
 elif body.visible_characters<body.get_total_character_count():
  revealed=body.get_total_character_count();_process(0)
 else:closing=true
