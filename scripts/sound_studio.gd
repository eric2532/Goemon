class_name SoundStudio
extends Control
var game: Node
var library: SoundLibrary
var from_pause=false
var slot=""
var move_key=""
var active_layer="weapon"
var layers: Dictionary={}
var list_labels: Dictionary={}
var status_label: Label
var meter: ProgressBar
var timer: Label
var devices: OptionButton
var slots: ItemList
# Aliases keep the selected layer available to existing studio integrations.
var record_button: Button
var stop_button: Button
var listen_button: Button
var save_button: Button
var discard_button: Button
var reset_button: Button
var volume: HSlider
var volume_label: Label
var search: LineEdit
var characters: OptionButton
var hub_title: Label
var paired_preview: Button

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	library=game.sound_library
	var panel=Panel.new();panel.position=Vector2(45,58);panel.size=Vector2(1220,785);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=StyleBoxFlat.new();style.bg_color=Color(0.025,0.075,0.10,0.96);style.border_color=Color("827750");style.set_border_width_all(1);style.set_corner_radius_all(12);panel.add_theme_stylebox_override("panel",style);add_child(panel)
	game.label_at(self,"SOUND STUDIO",Vector2(80,95),42)
	hub_title=game.label_at(self,"",Vector2(82,154),20,Color("dfc384"))
	characters=OptionButton.new();characters.name="SoundCharacter";characters.position=Vector2(80,205);characters.size=Vector2(330,42);add_child(characters)
	for id in range(1,13):characters.add_item(library.character_name(id),id)
	characters.select(library.character_id-1)
	characters.item_selected.connect(func(index):
		library.select_character(characters.get_item_id(index));search.clear();refresh_slots();refresh())
	search=LineEdit.new();search.position=Vector2(80,262);search.size=Vector2(330,36)
	search.placeholder_text="Find a move or sound…";add_child(search)
	search.text_changed.connect(func(_text):refresh_slots();refresh())
	slots=ItemList.new();slots.position=Vector2(80,310);slots.size=Vector2(330,422);slots.add_theme_font_size_override("font_size",18);add_child(slots)
	slots.item_selected.connect(func(index):
		if library.take:library.discard()
		else:library.cancel()
		select_slot(slots.get_item_metadata(index));refresh())
	game.label_at(self,"MICROPHONE · opens only when you press Record",Vector2(455,200),17)
	devices=OptionButton.new();devices.position=Vector2(455,235);devices.size=Vector2(540,42);add_child(devices)
	devices.item_selected.connect(func(index):library.device=devices.get_item_text(index);library.persist())
	game.button_at(self,"Refresh",Vector2(1010,230),refresh_devices,180)
	status_label=game.label_at(self,"",Vector2(455,286),16)
	status_label.size=Vector2(735,38);status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	meter=ProgressBar.new();meter.position=Vector2(455,330);meter.size=Vector2(560,14);meter.max_value=1;meter.show_percentage=false;add_child(meter)
	var fill=StyleBoxFlat.new();fill.bg_color=Color("61d9b2");meter.add_theme_stylebox_override("fill",fill)
	timer=game.label_at(self,"MIC OFF",Vector2(1030,325),17)
	make_layer("weapon",455,"Weapon")
	make_layer("voice",830,"Character voice")
	listen_button=game.button_at(self,"Listen to take",Vector2(455,700),func():library.listen(library.take,slot),205)
	save_button=game.button_at(self,"Save take",Vector2(675,700),func():library.save_take(),155)
	discard_button=game.button_at(self,"Discard",Vector2(845,700),library.discard,155)
	stop_button=game.button_at(self,"■ Stop",Vector2(1015,700),library.finish,175)
	paired_preview=game.button_at(self,"▶ Play weapon + voice",Vector2(455,770),func():library.listen_pair(library.character_id,move_key),350)
	game.label_at(self,"8 seconds per take · Saved locally",Vector2(830,786),16,Color("dfc384"))
	game.button_at(self,"Back to Settings",Vector2(80,770),func():game.show_settings(from_pause),330)
	library.changed.connect(refresh)
	refresh_slots();refresh_devices();refresh()

func make_layer(key: String,x: float,title: String):
	var card=Panel.new();card.position=Vector2(x,357);card.size=Vector2(360,328);card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=StyleBoxFlat.new();style.bg_color=Color("102d36");style.border_color=Color("526c68");style.set_border_width_all(1);style.set_corner_radius_all(8);card.add_theme_stylebox_override("panel",style);add_child(card)
	var controls={}
	controls.title=game.label_at(self,title,Vector2(x+18,370),24,Color("dfc384"))
	controls.state=game.label_at(self,"",Vector2(x+18,410),16);controls.state.size=Vector2(324,40);controls.state.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.label_at(self,"Volume",Vector2(x+18,460),17)
	controls.volume=HSlider.new();controls.volume.position=Vector2(x+18,492);controls.volume.size=Vector2(238,26);controls.volume.min_value=0;controls.volume.max_value=2;controls.volume.step=.05;add_child(controls.volume)
	controls.value=game.label_at(self,"100%",Vector2(x+270,491),17)
	controls.volume.value_changed.connect(func(value):
		var target=layer_slot(key)
		if not target.is_empty():library.set_gain(target,value))
	controls.mute=CheckButton.new();controls.mute.text="Mute";controls.mute.position=Vector2(x+18,526);controls.mute.size=Vector2(145,35);add_child(controls.mute)
	controls.mute.toggled.connect(func(value):
		var target=layer_slot(key)
		if not target.is_empty():library.set_muted(target,value))
	controls.play=game.button_at(self,"▶ Play",Vector2(x+18,569),func():
		var target=layer_slot(key)
		if not target.is_empty():library.listen(game.sound_preview(library.character_id,target),target),145)
	controls.record=game.button_at(self,"● Record",Vector2(x+180,569),func():choose_layer(key);library.begin(slot),162)
	controls.reset=game.button_at(self,"Restore default" if key=="weapon" else "Reset to silence",Vector2(x+18,628),func():library.reset_slot(layer_slot(key)),324)
	controls.reset.size.y=40;controls.reset.add_theme_font_size_override("font_size",17)
	layers[key]=controls

func layer_slot(key: String)->String:
	if not move_key.is_empty() and library.moves_for(library.character_id).has(move_key):return library.moves_for(library.character_id)[move_key][key]
	return slot if key=="weapon" else ""

func select_slot(selected: String):
	move_key="";slot=selected
	for key in library.moves_for(library.character_id):
		var move=library.moves_for(library.character_id)[key]
		if selected==move.weapon or selected==move.voice:
			move_key=key;slot=move[active_layer];break
	if move_key.is_empty():active_layer="weapon"

func choose_layer(key: String):
	if library.recording or layer_slot(key).is_empty():return
	if active_layer!=key:
		if library.take:library.discard()
		else:library.cancel()
	active_layer=key;slot=layer_slot(key);refresh()

func refresh_devices():
	if library.recording:return
	devices.clear()
	for device_name in library.devices():devices.add_item(device_name)
	for i in range(devices.item_count):
		if devices.get_item_text(i)==library.device:devices.select(i)
	if devices.item_count==0:library.status="No input devices detected. Connect a microphone, then Refresh."
	refresh()

func refresh():
	hub_title.text=library.character_name(library.character_id)+" · choose a move, then record either layer"
	characters.disabled=library.recording
	status_label.text=library.status
	stop_button.disabled=not library.recording
	devices.disabled=library.recording
	search.editable=not library.recording
	slots.mouse_filter=Control.MOUSE_FILTER_IGNORE if library.recording else Control.MOUSE_FILTER_STOP
	listen_button.disabled=library.recording or library.take==null
	save_button.disabled=listen_button.disabled
	discard_button.disabled=listen_button.disabled
	paired_preview.disabled=library.recording or move_key.is_empty() or slots.item_count==0
	for key in layers:
		var c=layers[key];var target=layer_slot(key);var available=not target.is_empty() and slots.item_count>0
		var recorded=available and library.custom.has(target)
		c.title.text=("Sound" if move_key.is_empty() else "Weapon") if key=="weapon" else "Character voice"
		c.state.text=("Recorded · your take" if recorded else ("Silent until you record" if key=="voice" else "Existing weapon sound")) if available else "Select a move to add character voice"
		if available and key=="weapon" and move_key.is_empty():c.state.text="Recorded · your take" if recorded else "Existing sound"
		if available and library.recording and library.active_slot==target:c.state.text="Recording this layer…"
		elif available and library.take and library.take_slot==target:c.state.text="Take ready · listen, then save below"
		c.volume.editable=available and not library.recording
		c.volume.set_value_no_signal(library.gain_for(library.character_id,target) if available else 1.0)
		c.value.text="%d%%"%roundi(c.volume.value*100)
		c.mute.disabled=not available or library.recording
		c.mute.set_pressed_no_signal(available and library.is_muted_for(library.character_id,target))
		c.record.disabled=not available or library.recording or devices.item_count==0
		c.play.disabled=not available or library.recording or game.sound_preview(library.character_id,target)==null
		c.reset.disabled=not available or library.recording or (not recorded and is_equal_approx(c.volume.value,1.0) and not c.mute.button_pressed)
	record_button=layers[active_layer].record;reset_button=layers[active_layer].reset
	volume=layers[active_layer].volume;volume_label=layers[active_layer].value
	for i in range(slots.item_count):
		slots.set_item_disabled(i,library.recording)
		var target=slots.get_item_metadata(i)
		var suffix=""
		if library.custom.has(target):suffix="  ✓"
		for key in library.moves_for(library.character_id):
			var move=library.moves_for(library.character_id)[key]
			if move.weapon==target and library.custom.has(move.voice):suffix="  ✓"
		slots.set_item_text(i,list_labels.get(target,target)+suffix)

func refresh_slots():
	var previous=layer_slot("weapon")
	slots.clear();list_labels.clear()
	var paired={};var shared={}
	for key in library.moves_for(library.character_id):
		var move=library.moves_for(library.character_id)[key]
		list_labels[move.weapon]=move.label
		paired[move.weapon]=true;paired[move.voice]=true
		shared[move.legacy]=true
	for key in library.slots_for(library.character_id):
		if paired.has(key):continue
		list_labels[key]=("Shared weapon · " if shared.has(key) else "Other · ")+library.slots_for(library.character_id)[key]
	var selected=false
	for key in list_labels:
		if not search.text.is_empty() and not search.text.to_lower() in list_labels[key].to_lower():continue
		var index=slots.add_item(list_labels[key]);slots.set_item_metadata(index,key)
		if key==previous:slots.select(index);select_slot(key);selected=true
	if not selected and slots.item_count>0:
		slots.select(0);select_slot(slots.get_item_metadata(0))
		if library.take:library.discard()

func _process(_delta):
	meter.value=library.level
	timer.text="%.1f / 8s"%library.elapsed if library.recording else "MIC OFF"

func _exit_tree():
	if library.changed.is_connected(refresh):library.changed.disconnect(refresh)
	library.discard()
