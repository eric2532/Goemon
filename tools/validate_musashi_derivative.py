import bpy,os,hashlib,json
from collections import Counter
from mathutils import Matrix
import math
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
master=root+'/assets/blender/enemies/musashi/Final/Musashi_Final.blend'
bpy.ops.wm.open_mainfile(filepath=master)
conv=Matrix.Rotation(math.pi,4,'Z')@Matrix.Scale(.30,4)
def key(v):return tuple(round(c,5) for c in v)
source=Counter(key(conv@v.co) for o in bpy.data.objects if o.type=='MESH' for v in o.data.vertices)
bpy.ops.wm.open_mainfile(filepath=root+'/assets/blender/enemies/musashi/Musashi_Playable.blend')
o=bpy.data.objects['Musashi_Approved_Surface'];rig=bpy.data.objects['Musashi_Rig']
target=Counter(key(v.co) for v in o.data.vertices)
errors=[abs(sum(g.weight for g in v.groups)-1) for v in o.data.vertices]
result={'master_sha256':hashlib.sha256(open(master,'rb').read()).hexdigest(),'rest_vertices_match_approved':source==target,'vertices':len(o.data.vertices),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'max_weight_sum_error':max(errors),'unweighted_vertices':sum(not v.groups for v in o.data.vertices),'max_bone_influences':max(len(v.groups) for v in o.data.vertices),'anatomical_left_is_negative_x':rig.data.bones['Hand_L'].head_local.x<0,'materials':len(o.data.materials),'uv_layers':len(o.data.uv_layers)}
json.dump(result,open(root+'/tests/musashi/derivative-validation.json','w'),indent=2);print(result)
assert result['rest_vertices_match_approved'] and result['unweighted_vertices']==0 and result['max_weight_sum_error']<1e-6
