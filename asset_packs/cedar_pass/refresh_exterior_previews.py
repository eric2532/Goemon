"""Refresh exterior-context previews without rebuilding source assets."""
from pathlib import Path
P=Path(__file__).resolve().parent
exec(compile((P/'build_pack.py').read_text().split('\nspec=')[0],str(P/'build_pack.py'),'exec'))
original_setup=setup_render
def setup_render(loc,target,ortho,path,res=(1200,900)):
 original_setup(loc,target,ortho,path,(1200,900));bpy.context.scene.cycles.samples=32
render_group(['machiya_open','cedar','moss_boulder','lantern','cart'],[(0,0,0),(6,1,0),(5,-3,0),(-5,-4,0),(-3,-5,0)],'street_close.png',23)
render_group(['tea_house_open','cloud_pine','well'],[(0,0,0),(6,2,0),(-6,-1,0)],'tea_house_close.png',23)
render_group(['shrine','torii','sakura','river_rock'],[(0,2,0),(0,-5,0),(6,2,0),(-5,-3,0)],'shrine_close.png',24)
reset();import_asset('tea_house_open');box('Ground',(0,0,-.16),(40,40,.25),'paper');setup_render((.1,-12,2.2),(0,0,1.9),11,P/'previews/interior_entry.png');bpy.ops.render.render(write_still=True)
