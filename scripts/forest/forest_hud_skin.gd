extends RefCounted
## Shared 2D lacquer, medallion and mouse artwork. Rasterized once per HUD.
var textures: Dictionary={}
const ART={
	"lacquer":"<svg xmlns='http://www.w3.org/2000/svg' width='256' height='112'><defs><linearGradient id='ink' x2='0' y2='1'><stop stop-color='#29473c'/><stop offset='.42' stop-color='#172f29'/><stop offset='1' stop-color='#0c1e1b'/></linearGradient><linearGradient id='gold' x2='0' y2='1'><stop stop-color='#b7a16b'/><stop offset='1' stop-color='#625338'/></linearGradient></defs><rect x='1' y='3' width='254' height='108' rx='17' fill='#08110f' fill-opacity='.5'/><rect x='3' y='1' width='250' height='107' rx='15' fill='url(#ink)' stroke='url(#gold)' stroke-width='2'/><rect x='7' y='5' width='242' height='99' rx='12' fill='none' stroke='#d8c08b' stroke-opacity='.12'/><path d='M22 9h212M23 101h210' stroke='#f1d499' stroke-opacity='.16'/><path d='M20 29q54-4 107 0t109-1M18 46q56 4 111 0t110 1M20 65q59-3 113 0t102-1M21 84q53 3 108 0t106 1' fill='none' stroke='#c0ad79' stroke-opacity='.045'/></svg>",
	"ring":"<svg xmlns='http://www.w3.org/2000/svg' width='164' height='164'><defs><linearGradient id='g' x2='.6' y2='1'><stop stop-color='#fff0bd'/><stop offset='.35' stop-color='#d8b76f'/><stop offset='.7' stop-color='#897143'/><stop offset='1' stop-color='#ead49d'/></linearGradient></defs><circle cx='82' cy='85' r='78' fill='#081411' fill-opacity='.65'/><circle cx='82' cy='82' r='77' fill='#182b27' stroke='#54482f' stroke-width='2'/><circle cx='82' cy='82' r='72' fill='#2d3c3b' stroke='url(#g)' stroke-width='5'/><circle cx='82' cy='82' r='67' fill='none' stroke='#e6d29d' stroke-opacity='.55'/><path d='m82 2 7 8-7 8-7-8Zm0 144 7 8-7 8-7-8ZM2 82l8-7 8 7-8 7Zm144 0 8-7 8 7-8 7Z' fill='url(#g)' stroke='#473e2e' stroke-width='1'/></svg>",
	"cooldown":"<svg xmlns='http://www.w3.org/2000/svg' width='72' height='72'><circle cx='36' cy='36' r='35' fill='#06120f' fill-opacity='.8'/></svg>",
	"mouse_left":"<svg xmlns='http://www.w3.org/2000/svg' width='24' height='30' viewBox='0 0 24 30'><path d='M3 14V10a9 9 0 0 1 9-9v13Z' fill='#edcd8b'/><rect x='3' y='1' width='18' height='28' rx='9' fill='none' stroke='#ebd9ae' stroke-width='1.6'/><path d='M12 2v11M4 14h16' fill='none' stroke='#ebd9ae' stroke-width='1.5'/></svg>",
	"mouse_right":"<svg xmlns='http://www.w3.org/2000/svg' width='24' height='30' viewBox='0 0 24 30'><path d='M12 1a9 9 0 0 1 9 9v4h-9Z' fill='#edcd8b'/><rect x='3' y='1' width='18' height='28' rx='9' fill='none' stroke='#ebd9ae' stroke-width='1.6'/><path d='M12 2v11M4 14h16' fill='none' stroke='#ebd9ae' stroke-width='1.5'/></svg>"
}
func texture(key: String)->Texture2D:
	if not textures.has(key):
		var image=Image.new();image.load_svg_from_string(ART[key]);textures[key]=ImageTexture.create_from_image(image)
	return textures[key]
func lacquer()->StyleBoxTexture:
	var box=StyleBoxTexture.new();box.texture=texture("lacquer")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		box.set_texture_margin(side,18);box.set_content_margin(side,12)
	return box
func attack_style()->StyleBoxFlat:
	var box=StyleBoxFlat.new();box.bg_color=Color("203d34");box.border_color=Color("9c8959")
	box.set_border_width_all(1);box.set_corner_radius_all(12)
	box.shadow_color=Color(0,0,0,.25);box.shadow_size=3;box.shadow_offset=Vector2(0,2);return box
static func format_gold(amount: int)->String:
	var digits=str(absi(amount));var formatted=""
	for i in range(digits.length()):
		if i>0 and (digits.length()-i)%3==0:formatted+=","
		formatted+=digits[i]
	return ("-" if amount<0 else "")+formatted
