class_name SoundStudio
extends Control
var game: Node
var library: SoundLibrary
var from_pause=false
var slot="swing"
var status_label: Label
var meter: ProgressBar
var timer: Label
var devices: OptionButton
var slots: ItemList
var record_button: Button
var stop_button: Button
var listen_button: Button
var save_button: Button
var discard_button: Button
var reset_button: Button
var volume: HSlider
var volume_label: Label
var search: LineEdit

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	library=game.sound_library
	var panel=Panel.new();panel.position=Vector2(45,58);panel.size=Vector2(1220,785);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=StyleBoxFlat.new();style.bg_color=Color(0.025,0.075,0.10,0.96);style.border_color=Color("827750");style.set_border_width_all(1);style.set_corner_radius_all(12);panel.add_theme_stylebox_override("panel",style);add_child(panel)
	game.label_at(self,"SOUND STUDIO",Vector2(80,95),42)
	game.label_at(self,"Record your own combat sounds",Vector2(82,154),20,Color("dfc384"))
	search=LineEdit.new();search.position=Vector2(80,205);search.size=Vector2(330,36)
	search.placeholder_text="Find an attack or sound…";add_child(search)
	search.text_changed.connect(func(_text):refresh_slots();refresh())
	slots=ItemList.new();slots.position=Vector2(80,250);slots.size=Vector2(330,440);slots.add_theme_font_size_override("font_size",18);slots.fixed_icon_size=Vector2i(0,0)
	add_child(slots)
	refresh_slots()
	slots.item_selected.connect(func(index):library.discard();slot=slots.get_item_metadata(index);refresh())
	game.label_at(self,"MICROPHONE",Vector2(470,195),17)
	devices=OptionButton.new();devices.position=Vector2(470,230);devices.size=Vector2(490,45);add_child(devices)
	devices.item_selected.connect(func(index):library.device=devices.get_item_text(index);library.persist())
	game.button_at(self,"Refresh",Vector2(990,226),refresh_devices,160)
	status_label=game.label_at(self,"",Vector2(470,302),18)
	status_label.size=Vector2(720,78);status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	meter=ProgressBar.new();meter.position=Vector2(470,386);meter.size=Vector2(530,20);meter.max_value=1;meter.show_percentage=false;add_child(meter)
	var fill=StyleBoxFlat.new();fill.bg_color=Color("61d9b2");meter.add_theme_stylebox_override("fill",fill)
	timer=game.label_at(self,"MIC OFF",Vector2(1020,381),18)
	record_button=game.button_at(self,"● Record",Vector2(470,435),func():library.begin(slot),210)
	stop_button=game.button_at(self,"■ Stop",Vector2(700,435),library.finish,180)
	listen_button=game.button_at(self,"Listen to take",Vector2(470,507),func():library.listen(library.take,slot),210)
	save_button=game.button_at(self,"Save take",Vector2(700,507),func():library.save_take(),180)
	discard_button=game.button_at(self,"Discard",Vector2(900,507),library.discard,180)
	game.label_at(self,"Slot volume",Vector2(470,590),18)
	volume=HSlider.new();volume.position=Vector2(640,590);volume.size=Vector2(330,30);volume.min_value=0;volume.max_value=2;volume.step=0.05;add_child(volume)
	volume_label=game.label_at(self,"100%",Vector2(990,590),18)
	volume.value_changed.connect(func(value):library.gains[slot]=value;volume_label.text="%d%%"%int(value*100);library.persist())
	game.button_at(self,"Play saved / default",Vector2(470,645),func():library.listen(library.custom.get(slot,game.sounds[slot]),slot),280)
	reset_button=game.button_at(self,"Restore default",Vector2(780,645),func():library.reset_slot(slot),270)
	game.label_at(self,"Up to 8 seconds · Silence trimmed · Saved locally on this computer",Vector2(470,714),16,Color("dfc384"))
	game.button_at(self,"Back to Settings",Vector2(80,765),func():game.show_settings(from_pause),300)
	library.changed.connect(refresh)
	refresh_devices();refresh()

func refresh_devices():
	if library.recording:return
	devices.clear()
	for name in library.devices():devices.add_item(name)
	for i in range(devices.item_count):
		if devices.get_item_text(i)==library.device:devices.select(i)
	if devices.item_count==0:library.status="No input devices detected. Connect a microphone, then Refresh."
	refresh()

func refresh():
	status_label.text=library.status
	record_button.disabled=library.recording or devices.item_count==0 or slots.item_count==0
	stop_button.disabled=not library.recording
	devices.disabled=library.recording
	search.editable=not library.recording
	slots.mouse_filter=Control.MOUSE_FILTER_IGNORE if library.recording else Control.MOUSE_FILTER_STOP
	listen_button.disabled=library.recording or library.take==null
	save_button.disabled=listen_button.disabled
	discard_button.disabled=library.recording or library.take==null
	reset_button.disabled=library.recording or not library.custom.has(slot)
	volume.set_value_no_signal(float(library.gains.get(slot,1)))
	volume_label.text="%d%%"%int(volume.value*100)
	for i in range(slots.item_count):
		slots.set_item_disabled(i,library.recording)
		var key=slots.get_item_metadata(i)
		slots.set_item_text(i,library.SLOTS[key]+("  ✓" if library.custom.has(key) else ""))

func refresh_slots():
	slots.clear()
	var selected=false
	for key in library.SLOTS:
		if not search.text.is_empty() and not search.text.to_lower() in library.SLOTS[key].to_lower():continue
		var index=slots.add_item(library.SLOTS[key]+("  ✓" if library.custom.has(key) else ""))
		slots.set_item_metadata(index,key)
		if key==slot:slots.select(index);selected=true
	if not selected and slots.item_count>0:
		slots.select(0);slot=slots.get_item_metadata(0);library.discard()

func _process(_delta):
	meter.value=library.level
	timer.text="%.1f / 8s"%library.elapsed if library.recording else "MIC OFF"

func _exit_tree():
	if library.changed.is_connected(refresh):library.changed.disconnect(refresh)
	library.discard()
