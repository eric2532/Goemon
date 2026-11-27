extends Control
## Local city travel reuses the archived markers, menu skin and current world.
const Data=preload("res://assets/maps/falan/travel_stone_data.gd")
const Art=preload("res://scripts/forest/forest_travel_stone_art.gd")
const MenuSkin=preload("res://scripts/forest/preparation_skin.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const RADIUS=4.5
var game
var source=-1

static func nearby(game)->int:
 if Tour.area(game.model)!="city":return -1
 var at=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 for i in Data.STONES.size():
  if at.distance_squared_to(Data.STONES[i][2])<=RADIUS*RADIUS and absf(game.player.position.y-game.model.world_height(at.x*game.model.falan_scale,at.y*game.model.falan_scale))<2.5*game.model.falan_scale:return i
 return -1

static func build(root:Node3D,model):
 for row in Data.STONES:
  var node=Art.crystal(root,model.world_point(row[2])/model.falan_scale)
  node.name="FalanTravelStone_%d_%d"%[row[1].x,row[1].y]
  node.set_meta("source_cell",row[1])

static func open(game)->bool:
 if not game.playing or game.paused or game.transitioning or game.settings_open or game.rogue_roster_open or is_instance_valid(game.team_upgrade_picker) or game.model.phase!="wave" or game.player.hp<=0:return false
 if Tour.Elsa.open(game):return true
 var index=nearby(game)
 if index<0:return false
 game.ordinary_pause=true;game.paused=true;game.get_tree().paused=true;Engine.time_scale=1
 game.player.cancel_charge(true);game.player.reset_auto_attack();game.player.rogue_controls.reset()
 game.model.workforce.cancel_rally();game._sync_camera_mouse()
 var menu=load("res://scripts/forest/forest_travel_stones.gd").new()
 menu.game=game;menu.source=index;game.travel_panel=menu;game.ui.add_child(menu)
 return true

func _ready():
 name="FalanTravelMenu";process_mode=Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();shade.color=Color(0,0,0,.22);add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var center=CenterContainer.new();add_child(center);center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var panel=PanelContainer.new();panel.theme=MenuSkin.theme();center.add_child(panel)
 var list=VBoxContainer.new();list.custom_minimum_size=Vector2(360,0);list.add_theme_constant_override("separation",10);panel.add_child(list)
 var title=Label.new();title.text="法蘭城 · 傳送石";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;list.add_child(title)
 var hint=Label.new();hint.text="From "+Data.STONES[source][0];hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;list.add_child(hint)
 for i in Data.STONES.size():
  var button=Button.new();button.text=Data.STONES[i][0];button.custom_minimum_size.y=42
  MenuSkin.apply_button(button);button.disabled=i==source;button.pressed.connect(choose.bind(i));list.add_child(button)
  if i==posmod(source+1,Data.STONES.size()):button.grab_focus.call_deferred()
 var cancel=Button.new();cancel.text="Esc · Cancel";MenuSkin.apply_button(cancel);cancel.pressed.connect(close);list.add_child(cancel)

func handle_input(event:InputEvent):
 if event is InputEventKey:
  var key=event.physical_keycode if event.physical_keycode!=0 else event.keycode
  if key in [KEY_ESCAPE,KEY_E] and event.pressed and not event.echo:close()
  if key not in [KEY_TAB,KEY_ENTER,KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:get_viewport().set_input_as_handled()

func choose(index:int):
 if index<0 or index>=Data.STONES.size() or index==source or nearby(game)!=source:return
 var at:Vector2=Tour.village_door(game.model,Data.STONES[index][2])
 var point=game.model.world_point(at,.15)
 if not game.model.terrain.disk_clear(point/game.model.falan_scale,.55) or game.model.scenery_obstacles.values().any(func(box):return box.grow(.55).has_point(point/game.model.falan_scale)):
  game.toast("This travel stone is blocked");return
 game.player.position=point;game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
 game.model.hero_position=point;game.checkpoint=point;game.falan_crossing_position=Vector2.INF
 game.camera_rig.reset_follow();close()

func close():
 hide();game.travel_panel=null;queue_free();game.resume()
