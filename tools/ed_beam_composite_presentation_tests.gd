extends SceneTree
## GPU regression checks for the production beam's display-only smoothing.
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Ed Original Restore/Beam Smoothing/"
const SHADER=preload("res://assets/characters/recovered_leaders/ed/beam/native_composite.gdshader")
const DISPLAY=Vector2i(1280,800)
const NATIVE=Vector2i(384,240)
const HUD=Rect2i(1200,16,64,48)
var checks:Array=[]
var background_material:ShaderMaterial
var composite_material:ShaderMaterial
var overlay:ColorRect
var texture:ImageTexture

func _initialize():run.call_deferred()
func capture()->Image:
	for _frame in 3:await process_frame
	RenderingServer.force_draw(false)
	var image=root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image

func check(label:String,passed:bool,details:Dictionary={}):
	checks.append({"name":label,"passed":passed,"details":details})
	print("ED_SMOOTH_CHECK ",label," ","PASS" if passed else "FAIL"," ",details)

func set_foreground(image:Image):
	if texture==null:
		texture=ImageTexture.create_from_image(image)
		composite_material.set_shader_parameter("foreground_rgb5",texture)
	else:texture.update(image)
	overlay.show()

func mismatch_count(a:Image,b:Image)->int:
	var aa=a.get_data();var bb=b.get_data()
	if aa==bb:return 0
	var count=0
	for i in range(0,aa.size(),4):
		if aa[i]!=bb[i] or aa[i+1]!=bb[i+1] or aa[i+2]!=bb[i+2] or aa[i+3]!=bb[i+3]:count+=1
	return count

func run():
	await process_frame
	if current_scene!=null:
		current_scene.queue_free();current_scene=null;await process_frame
	paused=false
	root.size=DISPLAY;root.content_scale_size=DISPLAY
	create_timer(60).timeout.connect(func():push_error("Beam presentation GPU test timed out");quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	var background_layer=CanvasLayer.new();background_layer.layer=-2;root.add_child(background_layer)
	var background=ColorRect.new();background.size=Vector2(DISPLAY);background_layer.add_child(background)
	var bg_shader=Shader.new();bg_shader.code="""
shader_type canvas_item;render_mode unshaded,blend_disabled;
uniform int pattern=0;
void fragment(){
 ivec2 p=ivec2(FRAGCOORD.xy);
 ivec3 value=ivec3(17+(p.x%2)*154,31+(p.y%2)*131,47+((p.x+p.y)%2)*137);
 if(pattern==1){value=ivec3(0);}
 if(pattern==2){value=ivec3(200,213,229);}
 COLOR=vec4(vec3(value)/255.0,1.0);
}
"""
	background_material=ShaderMaterial.new();background_material.shader=bg_shader;background.material=background_material
	var effect_layer=CanvasLayer.new();effect_layer.layer=-1;root.add_child(effect_layer)
	overlay=ColorRect.new();overlay.size=Vector2(DISPLAY);effect_layer.add_child(overlay)
	composite_material=ShaderMaterial.new();composite_material.shader=SHADER
	composite_material.set_shader_parameter("canvas_linear",false);overlay.material=composite_material;overlay.hide()
	var hud_layer=CanvasLayer.new();hud_layer.layer=0;root.add_child(hud_layer)
	var hud=ColorRect.new();hud.position=Vector2(HUD.position);hud.size=Vector2(HUD.size);hud.color=Color(0.2,0.7,0.9);hud_layer.add_child(hud)
	var baseline:Image=await capture();baseline.save_png(OUT+"background.png")
	var empty=Image.create(NATIVE.x,NATIVE.y,false,Image.FORMAT_RGBA8)
	empty.fill(Color(0,0,0,0));set_foreground(empty)
	var absent:Image=await capture()
	var absent_errors=mismatch_count(absent,baseline)
	check("uncovered foreground preserves high-frequency background",absent_errors==0,{"mismatched_pixels":absent_errors})
	empty.fill(Color(0,0,0,1));set_foreground(empty)
	var black:Image=await capture();black.save_png(OUT+"covered-black.png")
	var black_errors=mismatch_count(black,baseline)
	check("covered black foreground preserves high-frequency background",black_errors==0,{"mismatched_pixels":black_errors})
	background_material.set_shader_parameter("pattern",1)
	var step=Image.create(NATIVE.x,NATIVE.y,false,Image.FORMAT_RGBA8);step.fill(Color(0,0,0,1))
	step.fill_rect(Rect2i(NATIVE.x/2,0,NATIVE.x/2,NATIVE.y),Color(8.0/255.0,0,0,1));set_foreground(step)
	var transition:Image=await capture();transition.save_png(OUT+"foreground-transition.png")
	var distinct:Dictionary={};var row:Array=[]
	for x in range(DISPLAY.x/2-8,DISPLAY.x/2+8):
		var value=roundi(transition.get_pixel(x,DISPLAY.y/2).r*255.0);distinct[value]=true;row.append(value)
	var intermediate=0
	for value in distinct:if value>0 and value<66:intermediate+=1
	check("foreground edge has interpolated display colors",intermediate>=2,{"intermediate_colors":intermediate,"transition_row":row})
	background_material.set_shader_parameter("pattern",2)
	var bright=Image.create(NATIVE.x,NATIVE.y,false,Image.FORMAT_RGBA8);bright.fill(Color(31.0/255.0,31.0/255.0,31.0/255.0,1));set_foreground(bright)
	var saturated:Image=await capture();saturated.save_png(OUT+"saturation.png")
	var value=saturated.get_pixel(200,200)
	check("bright foreground saturates to white",value.r==1.0 and value.g==1.0 and value.b==1.0)
	var hud_same=saturated.get_region(HUD).get_data()==baseline.get_region(HUD).get_data()
	check("HUD is unchanged above the composite layer",hud_same)
	var failures=0
	for item in checks:failures+=int(not item.passed)
	var report={"passed":failures==0,"checks":checks,"failures":failures,"display_extent":[DISPLAY.x,DISPLAY.y],"native_extent":[NATIVE.x,NATIVE.y],"shader_sha256":FileAccess.get_sha256("res://assets/characters/recovered_leaders/ed/beam/native_composite.gdshader")}
	FileAccess.open(OUT+"presentation-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ED_BEAM_PRESENTATION_TESTS ",JSON.stringify(report))
	background_layer.queue_free();effect_layer.queue_free();hud_layer.queue_free()
	texture=null;background_material=null;composite_material=null;overlay=null
	finish.call_deferred(0 if failures==0 else 1)

func finish(code:int):
	await create_timer(0.35).timeout
	quit(code)
