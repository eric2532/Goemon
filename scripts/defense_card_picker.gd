extends Control
## A paused, keyboard-accessible draft. Card art is native vector drawing.
var game: Node
var director: Node
var chosen=false

class CardArt extends Control:
	var kind=""
	var tint=Color.WHITE
	func _draw():
		var c=size*.5
		draw_circle(c,43,Color(tint,.09))
		draw_arc(c,43,0,TAU,48,Color(tint,.35),1.5,true)
		match kind:
			"ice","shatter":
				for i in range(6):
					var d=Vector2.UP.rotated(i*TAU/6)
					draw_line(c,c+d*28,tint,3,true)
					for side in [-1,1]:draw_line(c+d*17,c+d*24+d.rotated(side*PI*.5)*8,tint,2,true)
			"fire","pool":
				var points=PackedVector2Array([c+Vector2(0,-31),c+Vector2(5,-10),c+Vector2(16,-19),c+Vector2(25,11),c+Vector2(13,28),c+Vector2(-15,27),c+Vector2(-24,10),c+Vector2(-9,-7),c+Vector2(-10,8)])
				draw_colored_polygon(points,tint)
				draw_colored_polygon(PackedVector2Array([c+Vector2(0,-1),c+Vector2(10,18),c+Vector2(0,26),c+Vector2(-9,17)]),Color("ffe8af"))
				if kind=="pool":draw_arc(c+Vector2(0,28),29,0,PI,24,tint,3,true)
			"gold":
				for shift in [-12,0,12]:
					draw_circle(c+Vector2(shift,shift*.4),19,Color("263b41"))
					draw_arc(c+Vector2(shift,shift*.4),19,0,TAU,32,tint,3,true)
				draw_line(c+Vector2(5,-7),c+Vector2(18,12),tint,3,true)
			"shield","heart":
				draw_colored_polygon(PackedVector2Array([c+Vector2(-24,-25),c+Vector2(24,-25),c+Vector2(21,10),c+Vector2(0,30),c+Vector2(-21,10)]),Color(tint,.35))
				draw_line(c+Vector2(0,-14),c+Vector2(0,14),tint,5,true)
				draw_line(c+Vector2(-14,0),c+Vector2(14,0),tint,5,true)
			"sight","blast":
				for radius in [13,26]:draw_arc(c,radius,0,TAU,32,tint,2,true)
				for i in range(4):
					var d=Vector2.UP.rotated(i*PI*.5);draw_line(c+d*19,c+d*34,tint,3,true)
			_:
				for i in range(3):
					var x=float(i-1)*17
					draw_line(c+Vector2(x,22),c+Vector2(x,-17),tint,5,true)
					draw_colored_polygon(PackedVector2Array([c+Vector2(x-7,-14),c+Vector2(x+7,-14),c+Vector2(x,-28)]),tint)

func label(words: String,font_size: int,tint: Color=Color("ecf3ec"))->Label:
	var result=Label.new();result.text=words
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",tint)
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(center)
	var layout=VBoxContainer.new();layout.custom_minimum_size=Vector2(1150,0);layout.add_theme_constant_override("separation",18);center.add_child(layout)
	var eyebrow=label(("R O G U E   S I E G E   /   %s" if game.rogue_roster_mode else "F I R E   S I E G E   /   %s") % ("HARD" if director.hard_mode else "BETA"),17,Color("e7c47e"));layout.add_child(eyebrow)
	layout.add_child(label("CHOOSE YOUR NEXT ADVANTAGE",37))
	var next_wave=director.card_choice_wave
	var boss_note="   ·   BOSS INCOMING" if next_wave in [5,10] else ""
	layout.add_child(label("WAVE %02d / 10%s    ·    Pick one card. Your choices last this run." % [next_wave,boss_note],18,Color("c6d7d5")))
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",20);layout.add_child(row)
	for index in range(director.card_offer.size()):
		var id=String(director.card_offer[index]);var data=DefenseCards.get_card(id);var tint=Color(data.color)
		var button=Button.new();button.name="DefenseCard_%d" % index;button.custom_minimum_size=Vector2(370,422)
		button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		var style=StyleBoxFlat.new();style.bg_color=Color("142a34");style.border_color=Color(tint,.65)
		style.set_border_width_all(2);style.set_corner_radius_all(12)
		var hover=style.duplicate();hover.bg_color=Color("233d46");hover.border_color=tint;hover.set_border_width_all(3)
		button.add_theme_stylebox_override("normal",style);button.add_theme_stylebox_override("hover",hover);button.add_theme_stylebox_override("focus",hover);button.add_theme_stylebox_override("pressed",hover)
		button.pressed.connect(select.bind(id));row.add_child(button)
		var contents=VBoxContainer.new();contents.mouse_filter=Control.MOUSE_FILTER_IGNORE
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);contents.offset_left=24;contents.offset_right=-24;contents.offset_top=20;contents.offset_bottom=-20
		contents.add_theme_constant_override("separation",13);button.add_child(contents)
		contents.add_child(label("0%d   /   %s" % [index+1,data.tag],12,tint))
		var art=CardArt.new();art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.kind=data.icon;art.tint=tint;art.custom_minimum_size.y=98;contents.add_child(art)
		contents.add_child(label(data.title,27))
		var description=label(data.description,18,Color("cbdad9"));description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.custom_minimum_size=Vector2(310,114);description.size_flags_vertical=Control.SIZE_EXPAND_FILL;contents.add_child(description)
		var rank=director.upgrade_level(id);var maximum=int(data.max_stacks)
		var bottom="[ %d ]  TAKE CARD" % (index+1)
		if maximum>1:bottom+="   ·   %d / %d" % [rank+1,maximum]
		contents.add_child(label(bottom,15,tint))
		if index==0:button.grab_focus()
	var current=director.card_summary()
	layout.add_child(label("YOUR BUILD  /  "+(current if not current.is_empty() else "Your first card shapes the opening wave."),15,Color("b6cbc9")))
	layout.add_child(label("Time is paused. Choose with 1 / 2 / 3, or click a card.   Esc · Pause menu"+("   Q · Change fighter" if game.rogue_roster_mode else ""),15,Color("91abae")))

func _input(event):
	if chosen or director.phase!="draft" or not is_visible_in_tree():return
	if event is InputEventKey and event.pressed and not event.echo:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		var index=[KEY_1,KEY_2,KEY_3].find(code)
		if index>=0:
			get_viewport().set_input_as_handled()
			select(String(director.card_offer[index]))

func select(id: String):
	if chosen:return
	chosen=true;set_process_input(false)
	if not director.choose_card(id):chosen=false;set_process_input(true)
