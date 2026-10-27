extends SceneTree
## Preserve recovered source looks for asset review and their per-instance materials.
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func pages(m)->Array:
	var result=[]
	for material in m.palette_materials:
		var texture=material.get_shader_parameter("albedo_texture")
		if texture!=null:result.append(texture.get_image().get_data())
	return result
func run():
	var a=load("res://scripts/recovered_musashi_model.gd").new();check(a.outfit_mask==31,"New models default to the full recovered equipment");a.outfit_mask=0;root.add_child(a)
	var b=load("res://scripts/recovered_musashi_model.gd").new();b.outfit_mask=0;root.add_child(b)
	await process_frame
	check(a.has_method("set_outfit_mask"),"Recovered equipment has a playable model appearance API")
	if not a.has_method("set_outfit_mask"):a.free();b.free();finish();return
	var original=pages(a);check(original.size()==5,"Five unique source CLUT pages survive material consolidation")
	var cluts=[]
	for material in a.palette_materials:
		if material.has_meta("source_clut"):cluts.append(material.get_meta("source_clut"))
	cluts.sort();check(cluts==[16918,16982,17046,17174,17238],"Each original equipment CLUT retains its independent binding")
	for mask in range(1,32):
		a.set_outfit_mask(mask)
		check(pages(a)!=original,"Original equipment flag %d changes the model's actual textures"%mask)
		check(pages(b)==original,"Appearance flag %d does not modify another Musashi instance"%mask)
		a.animate(.1,0,true,0,0,false,0,false)
		check(a.outfit_mask==mask and pages(a)!=original,"Imported animation sampling retains equipment flag %d"%mask)
	a.set_outfit_mask(0);check(pages(a)==original,"Original look restores the exact base atlas pixels")
	a.free();b.free();finish()
func finish():
	print("MUSASHI_OUTFIT_MODEL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
