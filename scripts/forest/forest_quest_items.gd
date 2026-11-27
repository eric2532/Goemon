extends Control
const Events=preload("res://scripts/forest/forest_east_events.gd")
const MenuSkin=preload("res://scripts/forest/preparation_skin.gd")
const ITEMS="university_quest_items"
var hub:Control
var panel:Panel
var pictures:Dictionary={}
var atlas:Texture2D

static func held(items:Dictionary,catalog:Dictionary)->Array:
 var rows=[]
 for key in items:
  if not str(key).begins_with("source_item_"):continue
  var suffix=str(key).trim_prefix("source_item_")
  if not suffix.is_valid_int() or int(items[key])<=0:continue
  var id=int(suffix);var record:Dictionary=catalog.get(suffix,{})
  rows.append({"id":id,"name":record.get("name","道具 %d"%id),"count":int(items[key]),"icon":int(record.get("icon",0)),"usable":record.get("program") is Dictionary and record.get("function_code","")=="IuMs"})
 rows.sort_custom(func(a,b):return int(a.id)<int(b.id))
 return rows

func label(value:String,at:Vector2,extent:Vector2,font_size:int=20)->Label:
 var node=Label.new();node.text=value;node.position=at;node.size=extent
 node.add_theme_font_size_override("font_size",font_size);node.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(node);return node

func _ready():
 name="QuestItems";process_mode=Node.PROCESS_MODE_ALWAYS;theme=MenuSkin.theme()
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();shade.color=Color(0,0,0,.7);add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=Panel.new();panel.size=Vector2(780,620);panel.add_theme_stylebox_override("panel",MenuSkin.panel());add_child(panel)
 label("任務道具",Vector2(28,20),Vector2(590,40),28)
 var close=Button.new();close.text="返回";close.position=Vector2(640,24);close.size=Vector2(112,36)
 close.pressed.connect(queue_free);panel.add_child(close)
 var scroll=ScrollContainer.new();scroll.position=Vector2(28,80);scroll.size=Vector2(724,510)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
 var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",8);scroll.add_child(list)
 pictures=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/east_region/item-icons.json")).art
 atlas=load("res://assets/maps/falan/east_region/item-icons.png")
 var rows=held(hub.game.get_tree().get_meta(ITEMS,{}),Events.item_data().items)
 if rows.is_empty():label("目前沒有任務道具。",Vector2(28,90),Vector2(680,40))
 for item in rows:
  var row=HBoxContainer.new();row.custom_minimum_size=Vector2(690,58);row.add_theme_constant_override("separation",16);list.add_child(row)
  var icon=TextureRect.new();icon.custom_minimum_size=Vector2(54,54);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  if pictures.has(str(item.icon)):
   var texture=AtlasTexture.new();texture.atlas=atlas;var rect:Array=pictures[str(item.icon)].rect
   texture.region=Rect2(rect[0],rect[1],rect[2],rect[3]);texture.filter_clip=true;icon.texture=texture
  row.add_child(icon)
  var title=Label.new();title.text="%s × %d"%[item.name,item.count];title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.tooltip_text=item.name;row.add_child(title)
  var use=Button.new();use.name="UseQuestItem%d"%item.id;use.text="使用";use.custom_minimum_size=Vector2(100,46);use.disabled=not item.usable
  use.pressed.connect(hub.use_quest_item.bind(int(item.id)));row.add_child(use)
 resized.connect(layout);layout();close.grab_focus()

func layout():
 var factor=minf(1.,minf((size.x-24)/780.,(size.y-24)/620.))
 panel.scale=Vector2.ONE*factor;panel.position=(size-panel.size*factor)*.5

func _unhandled_key_input(event:InputEvent):
 if event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled();queue_free()
