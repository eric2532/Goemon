extends Control
var game
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paper=PanelContainer.new();paper.add_theme_stylebox_override("panel",game.forest_ui.style(Color("e7d9b4")))
	add_child(paper);paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	paper.offset_left=60;paper.offset_right=510;paper.offset_top=-230;paper.offset_bottom=230
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",20);paper.add_child(column)
	for row in [["A CLEARING IN THE DEEP WOODS",15],["FOREST\nSHRINE",54],["Build your settlement. Rally your workers.\nDefend the shrine with twelve heroes.",20],["Plan from above between waves.\nFight on the ground when the forest stirs.",18]]:
		var label=Label.new();label.text=row[0];label.add_theme_font_size_override("font_size",row[1]);label.add_theme_color_override("font_color",Color("263c35"));column.add_child(label)
	var play=game.forest_ui.make_button("PLAY FOREST SHRINE  →",game.begin_forest,390);play.name="ForestPlay";column.add_child(play)
	var quit=game.forest_ui.make_button("Quit",game.quit_clean,390);quit.custom_minimum_size.y=44;column.add_child(quit)
