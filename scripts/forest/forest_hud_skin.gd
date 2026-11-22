extends RefCounted
## Warm charcoal HUD panels and shared mouse artwork. Prepared once per HUD.
var textures: Dictionary={}
const ART={
	"portrait_frame":"<svg xmlns='http://www.w3.org/2000/svg' width='112' height='112'><circle cx='56' cy='56' r='45' fill='#191c1b' stroke='#aa9160' stroke-width='3'/><circle cx='56' cy='56' r='41' fill='none' stroke='#53452e' stroke-width='1'/></svg>",
	"xp_track":"<svg xmlns='http://www.w3.org/2000/svg' width='112' height='112'><path d='M56 5a51 51 0 0 1 0 102' fill='none' stroke='#292032' stroke-width='6'/><path d='M56 1a55 55 0 0 1 0 110M56 9a47 47 0 0 1 0 94' fill='none' stroke='#73548f' stroke-width='1'/></svg>",
	"xp_fill":"<svg xmlns='http://www.w3.org/2000/svg' width='112' height='112'><circle cx='56' cy='56' r='51' fill='none' stroke='#a978df' stroke-width='6'/></svg>",
	"cooldown":"<svg xmlns='http://www.w3.org/2000/svg' width='72' height='72'><circle cx='36' cy='36' r='35' fill='#1a1613' fill-opacity='.8'/></svg>",
	"mouse_left":"<svg xmlns='http://www.w3.org/2000/svg' width='24' height='30' viewBox='0 0 24 30'><path d='M3 14V10a9 9 0 0 1 9-9v13Z' fill='#edcd8b'/><rect x='3' y='1' width='18' height='28' rx='9' fill='none' stroke='#ebd9ae' stroke-width='1.6'/><path d='M12 2v11M4 14h16' fill='none' stroke='#ebd9ae' stroke-width='1.5'/></svg>",
	"mouse_right":"<svg xmlns='http://www.w3.org/2000/svg' width='24' height='30' viewBox='0 0 24 30'><path d='M12 1a9 9 0 0 1 9 9v4h-9Z' fill='#edcd8b'/><rect x='3' y='1' width='18' height='28' rx='9' fill='none' stroke='#ebd9ae' stroke-width='1.6'/><path d='M12 2v11M4 14h16' fill='none' stroke='#ebd9ae' stroke-width='1.5'/></svg>"
}
func texture(key: String)->Texture2D:
	if not textures.has(key):
		var image=Image.new();image.load_svg_from_string(ART[key]);textures[key]=ImageTexture.create_from_image(image)
	return textures[key]
func lacquer()->StyleBoxFlat:
	var box=attack_style();box.bg_color=Color(.10,.085,.07,.58);box.border_color=Color("756248")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_content_margin(side,12)
	return box
func statue_frame()->StyleBoxFlat:
	var box=lacquer()
	box.content_margin_left=46;box.content_margin_right=46;box.content_margin_top=34;box.content_margin_bottom=20
	return box
func attack_style()->StyleBoxFlat:
	var box=StyleBoxFlat.new();box.bg_color=Color("26211ca3");box.border_color=Color("9d8660")
	box.set_border_width_all(1);box.set_corner_radius_all(6)
	box.shadow_color=Color(0,0,0,.25);box.shadow_size=3;box.shadow_offset=Vector2(0,2);return box
