extends SceneTree
## Prepare the existing painted Shin portrait as game and launcher icons.
func _initialize():run.call_deferred()

func run():
	var launcher="--launcher" in OS.get_cmdline_user_args()
	var name_="Play Goemon" if launcher else "Cross Gate"
	var destination="res://build/Other Files/Game Icon/Play Goemon" if launcher else "res://icon"
	var icon=Image.load_from_file("res://assets/ui/portraits/crossgate/shin.png")
	assert(icon!=null and not icon.is_empty(),"Cannot load the preserved Shin portrait")
	icon.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
	assert(icon.get_pixel(0,0).a==0 and icon.get_pixel(512,512).a>.9,"Icon must show Shin on transparency")
	assert(icon.save_png(destination+".png")==OK,"Cannot save game icon")
	var iconset=ProjectSettings.globalize_path("res://build/Other Files/Game Icon/"+name_+".iconset")
	assert(DirAccess.make_dir_recursive_absolute(iconset)==OK,"Cannot create native icon staging folder")
	for size in [16,32,128,256,512]:
		for density in [1,2]:
			var scaled=icon.duplicate();scaled.resize(size*density,size*density,Image.INTERPOLATE_LANCZOS)
			assert(scaled.save_png(iconset.path_join("icon_%dx%d%s.png"%[size,size,"@2x" if density==2 else ""]))==OK,"Cannot save native icon size")
	var output=[]
	assert(OS.execute("/usr/bin/iconutil",["-c","icns",iconset,"-o",ProjectSettings.globalize_path(destination+".icns")],output,true)==0,"Cannot package macOS icon: "+str(output))
	print("GAME_ICON_RENDERED size=1024 source=painted_shin_portrait destination=",destination);quit()
