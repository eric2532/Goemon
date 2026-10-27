extends RefCounted
## Shared 2D lacquer, medallion and mouse artwork. Rasterized once per HUD.
var textures: Dictionary={}
const ART={
	"ring":"<svg xmlns='http://www.w3.org/2000/svg' width='164' height='164'><defs><linearGradient id='g' x2='.6' y2='1'><stop stop-color='#ffffff'/><stop offset='.35' stop-color='#d5d9e3'/><stop offset='.7' stop-color='#777181'/><stop offset='1' stop-color='#e9e5ed'/></linearGradient></defs><circle cx='82' cy='85' r='78' fill='#160a14' fill-opacity='.65'/><circle cx='82' cy='82' r='77' fill='#301120' stroke='#7c7180' stroke-width='2'/><circle cx='82' cy='82' r='72' fill='#552139' stroke='url(#g)' stroke-width='5'/><circle cx='82' cy='82' r='67' fill='none' stroke='#f3e4ef' stroke-opacity='.55'/><path d='m82 2 7 8-7 8-7-8Zm0 144 7 8-7 8-7-8ZM2 82l8-7 8 7-8 7Zm144 0 8-7 8 7-8 7Z' fill='url(#g)' stroke='#6c5d70' stroke-width='1'/></svg>",
	"cooldown":"<svg xmlns='http://www.w3.org/2000/svg' width='72' height='72'><circle cx='36' cy='36' r='35' fill='#06120f' fill-opacity='.8'/></svg>",
	"mouse_left":"<svg xmlns='http://www.w3.org/2000/svg' width='24' height='30' viewBox='0 0 24 30'><path d='M3 14V10a9 9 0 0 1 9-9v13Z' fill='#edcd8b'/><rect x='3' y='1' width='18' height='28' rx='9' fill='none' stroke='#ebd9ae' stroke-width='1.6'/><path d='M12 2v11M4 14h16' fill='none' stroke='#ebd9ae' stroke-width='1.5'/></svg>",
	"mouse_right":"<svg xmlns='http://www.w3.org/2000/svg' width='24' height='30' viewBox='0 0 24 30'><path d='M12 1a9 9 0 0 1 9 9v4h-9Z' fill='#edcd8b'/><rect x='3' y='1' width='18' height='28' rx='9' fill='none' stroke='#ebd9ae' stroke-width='1.6'/><path d='M12 2v11M4 14h16' fill='none' stroke='#ebd9ae' stroke-width='1.5'/></svg>"
}
func texture(key: String)->Texture2D:
	if not textures.has(key):
		var image=Image.new();image.load_svg_from_string(ART[key]);textures[key]=ImageTexture.create_from_image(image)
	return textures[key]
func lacquer()->StyleBoxTexture:
	var box=preload("res://scripts/forest/preparation_skin.gd").panel()
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_content_margin(side,12)
	return box
func statue_frame()->StyleBoxTexture:
	var box=StyleBoxTexture.new();box.texture=preload("res://assets/ui/maroon/statue_frame.svg")
	box.texture_margin_left=64;box.texture_margin_right=64;box.texture_margin_top=34;box.texture_margin_bottom=28
	box.content_margin_left=46;box.content_margin_right=46;box.content_margin_top=34;box.content_margin_bottom=20
	return box
func attack_style()->StyleBoxFlat:
	var box=StyleBoxFlat.new();box.bg_color=Color("421a2d");box.border_color=Color("cbc8d3")
	box.set_border_width_all(1);box.set_corner_radius_all(12)
	box.shadow_color=Color(0,0,0,.25);box.shadow_size=3;box.shadow_offset=Vector2(0,2);return box
static func format_gold(amount: int)->String:
	var digits=str(absi(amount));var formatted=""
	for i in range(digits.length()):
		if i>0 and (digits.length()-i)%3==0:formatted+=","
		formatted+=digits[i]
	return ("-" if amount<0 else "")+formatted
