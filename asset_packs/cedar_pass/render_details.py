from pathlib import Path
P=Path(__file__).resolve().parent
exec(compile((P/'build_pack.py').read_text().split('\nspec=')[0],__file__,'exec'))
render_group(['machiya_open','cedar','moss_boulder','lantern','cart'],[(0,0,0),(6,1,0),(5,-3,0),(-5,-4,0),(-3,-5,0)],'street_close.png',23)
render_group(['tea_house_open','cloud_pine','well'],[(0,0,0),(6,2,0),(-6,-1,0)],'tea_house_close.png',23)
# Low eye-level view proves the open shell and furnishing without hiding roofs.
reset();import_asset('tea_house_open');box('Ground',(0,0,-.16),(40,40,.25),'paper');setup_render((.1,-12,2.2),(0,0,1.9),11,P/'previews/interior_entry.png',(1300,900));bpy.ops.render.render(write_still=True)
