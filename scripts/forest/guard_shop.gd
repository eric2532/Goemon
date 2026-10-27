extends Control
## Mercenary cards recruit directly at the castle through the shared purchase path.
var director
var buttons:Array[Button]=[]
var panel:PanelContainer
const PreparationSkin=preload("res://scripts/forest/preparation_skin.gd")
func _ready():
 name="GuardShop";process_mode=Node.PROCESS_MODE_ALWAYS;theme=PreparationSkin.theme()
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel=PanelContainer.new();panel.name="MercenaryTray";add_child(panel)
 layout_panel();resized.connect(layout_panel)
 panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 var row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",7);panel.add_child(row)
 buttons.resize(director.KITS.size())
 var shortcuts=director.game.forest_ui.MERCENARY_SHORTCUTS
 for slot in shortcuts:
  var prefix=("%d · "%(shortcuts.find(slot)+1)) if slot in shortcuts else ""
  var button=Button.new();button.name="HireGuard%d"%slot;button.text="%s%s\n%d ryo"%[prefix,director.NAMES[slot],director.COSTS[slot]]
  var portrait=preload("res://scripts/rogue_roster.gd").portrait(director.KITS[slot])
  var face=AtlasTexture.new();face.atlas=portrait
  # Match the existing HUD crop so each character is recognizable at card size.
  face.region=Rect2(portrait.get_size()*Vector2(.3375,.20),portrait.get_size()*Vector2(.325,.52))
  PreparationSkin.apply_card(button,face)
  button.custom_minimum_size.x=0;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.tooltip_text="Hire at the castle · 2 food · Attacks nearby enemies"
  button.pressed.connect(director.request.bind(slot));row.add_child(button);buttons[slot]=button
 refresh()
func layout_panel():
 PreparationSkin.layout_cards(panel)
func refresh():
 for slot in buttons.size():
  buttons[slot].disabled=not director.available() or director.game.model.gold<director.COSTS[slot] or not director.game.model.can_recruit(2)
func _process(_delta):refresh()
