extends RefCounted
## Small, cached illustrated symbols. No per-frame image generation or 3D portraits.
var textures: Dictionary={}
const DRAWINGS={
	"gold":"<ellipse cx='24' cy='37' rx='17' ry='8' fill='#c89942'/><path d='M7 29v8m34-8v8' stroke='#f1cf79'/><ellipse cx='24' cy='29' rx='17' ry='8' fill='#e8bc61'/><ellipse cx='24' cy='21' rx='17' ry='8' fill='#f5d58c'/><path d='M24 17v8m-4-6h8m-8 4h8' stroke='#8a682f'/>",
	"raider":"<path d='M13 12 8 4l13 7m14 1 5-8-13 7' fill='#c77e69'/><path d='M10 11h28l-2 23-12 10-12-10Z' fill='#d9dbcc'/><path d='m15 22 7 3m11-3-7 3m-8 9h12' stroke='#7d443f' stroke-width='4'/>",
	"archer":"<path d='M29 5c-23 8-23 30 0 38L20 24Z' fill='none' stroke='#e2bd77' stroke-width='3'/><path d='M29 5v38M8 24h32m-6-5 7 5-7 5' stroke='#c3d9b5'/>",
	"giant":"<path d='M8 39C0 16 11 5 24 5s24 11 16 34Z' fill='#c06d57'/><ellipse cx='24' cy='21' rx='13' ry='11' fill='#f1dbac'/><path d='m15 18 6 2m12-2-6 2m-10 7h14' stroke='#35463f' stroke-width='3'/><path d='M16 36h16m-8-4v10' stroke='#e8bb66' stroke-width='3'/>",
	"runner":"<path d='M18 9V5h12v4M24 39v6M13 13l-5-3m27 3 5-3' fill='none'/><path d='M14 11h20l5 9v12l-5 8H14l-5-8V20Z' fill='#e3b16c'/><path d='M12 19h24M11 31h26M19 12v26m10-26v26' stroke='#ad6d46'/><path d='m20 24 8 4-8 4Z' fill='#653d36' stroke='none'/>"
}
func get_icon(kind: String)->Texture2D:
	if kind=="worker":return preload("res://assets/ui/forest/worker_goemon.png")
	if not textures.has(kind):
		var svg="<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'><g stroke='#243c34' stroke-width='2' stroke-linejoin='round' stroke-linecap='round'>"+DRAWINGS[kind]+"</g></svg>"
		var image=Image.new();image.load_svg_from_string(svg);textures[kind]=ImageTexture.create_from_image(image)
	return textures[kind]
