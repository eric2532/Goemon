extends PanelContainer
## Original equipment textures; choosing a look leaves all restored moves available.
var game:Node
var preview
var toggles:Array[CheckButton]=[]
var age=0.0
func _ready():
	name="MusashiEquipment";process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left=-340;offset_right=340;offset_top=-270;offset_bottom=270
	var style=StyleBoxFlat.new();style.bg_color=Color("172e2d");style.border_color=Color("bba4f2");style.set_border_width_all(2);style.set_corner_radius_all(12)
	for side in ["left","right","top","bottom"]:style.set("content_margin_"+side,20)
	add_theme_stylebox_override("panel",style)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",24);add_child(row)
	var view_box=SubViewportContainer.new();view_box.custom_minimum_size=Vector2(280,450);row.add_child(view_box)
	var viewport=SubViewport.new();viewport.size=Vector2i(280,450);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view_box.add_child(viewport)
	var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("203a3b");viewport.add_child(environment)
	preview=load("res://scripts/recovered_musashi_model.gd").new();preview.presentation_scale=1.0;viewport.add_child(preview)
	var camera=Camera3D.new();viewport.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.9;camera.position=Vector3(-2,1.5,-4);camera.look_at(Vector3.UP*.95);camera.make_current()
	var column=VBoxContainer.new();column.custom_minimum_size.x=300;column.add_theme_constant_override("separation",10);row.add_child(column)
	var title=Label.new();title.text="MUSASHI · EQUIPMENT";title.add_theme_font_size_override("font_size",23);column.add_child(title)
	var note=Label.new();note.text="Original equipment looks\nDouble jump stays unlocked.";note.add_theme_font_size_override("font_size",16);column.add_child(note)
	for item in preview.equipment_sources().equipment:
		var toggle=CheckButton.new();toggle.name="MusashiGear_"+item.id;toggle.text=item.label;toggle.custom_minimum_size.y=40;column.add_child(toggle);toggles.append(toggle)
		toggle.toggled.connect(func(_on):_sync_mask())
	var presets=HBoxContainer.new();column.add_child(presets)
	for entry in [["Original",0,"MusashiGearOriginal"],["All equipment",31,"MusashiGearAll"]]:
		var button=Button.new();button.text=entry[0];button.name=entry[2];button.pressed.connect(_set_mask.bind(entry[1]));presets.add_child(button)
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(spacer)
	var apply=Button.new();apply.name="MusashiGearApply";apply.text="Use this look";apply.custom_minimum_size.y=44;column.add_child(apply)
	apply.pressed.connect(func():
		if is_instance_valid(game):
			game.select_musashi_equipment(preview.outfit_mask)
			game.choose_rogue_character(13)
		queue_free())
	var close=Button.new();close.text="Back";close.pressed.connect(queue_free);column.add_child(close)
	var mask=game.player.character_models[13].outfit_mask if is_instance_valid(game) and game.player.character_models.has(13) else 31
	_set_mask(mask)
func _set_mask(mask:int):
	for i in toggles.size():toggles[i].set_pressed_no_signal((mask&(1<<i))!=0)
	preview.set_outfit_mask(mask)
func _sync_mask():
	var mask=0
	for i in toggles.size():
		if toggles[i].button_pressed:mask|=1<<i
	preview.set_outfit_mask(mask)
func _process(delta:float):
	if not is_instance_valid(preview):return
	age+=delta;preview.animate(delta,0,true,0,0,false,0,false)
	preview.rotation.y=sin(age*.35)*.35
