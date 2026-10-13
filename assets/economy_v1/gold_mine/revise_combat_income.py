"""Update economy metadata without modifying mesh, materials or animation data."""
import bpy,os,json,struct,hashlib,copy
D=os.path.dirname(os.path.abspath(__file__))
def digest_blender():
 objects=[]
 for o in sorted(bpy.data.objects,key=lambda x:x.name):
  entry={'name':o.name,'type':o.type,'parent':o.parent.name if o.parent else None,'location':list(o.location),'rotation':list(o.rotation_euler),'scale':list(o.scale)}
  if o.type=='MESH':entry['vertices']=[list(v.co) for v in o.data.vertices];entry['polygons']=[list(p.vertices) for p in o.data.polygons];entry['materials']=[m.name for m in o.data.materials];entry['material_indices']=[p.material_index for p in o.data.polygons]
  objects.append(entry)
 actions=[]
 for a in sorted(bpy.data.actions,key=lambda x:x.name):
  actions.append({'name':a.name,'curves':[{'path':fc.data_path,'index':fc.array_index,'keys':[[*k.co,k.interpolation] for k in fc.keyframe_points]} for fc in a.fcurves]})
 return hashlib.sha256(json.dumps({'objects':objects,'actions':actions},sort_keys=True).encode()).hexdigest()
p=os.path.join(D,'goldmine_v1.blend');attrs={k:os.getxattr(p,k) for k in os.listxattr(p)}
bpy.ops.wm.open_mainfile(filepath=p);before_blend=digest_blender();root=bpy.data.objects['GoldMine_Root'];old_income=root['base_income_gold_per_second'];root['base_income_gold_per_second']=2
assert root['income_phase']=='combat_only' and root['setup_income_gold_per_second']==0 and root['pause_income_gold_per_second']==0
bpy.ops.wm.save_as_mainfile(filepath=p,compress=True)
for k,v in attrs.items():os.setxattr(p,k,v)
bpy.ops.wm.open_mainfile(filepath=p);after_blend=digest_blender();assert before_blend==after_blend
p=os.path.join(D,'goldmine_v1.glb');b=open(p,'rb').read();ln,ty=struct.unpack_from('<II',b,12);j=json.loads(b[20:20+ln]);rest=b[20+ln:];original=copy.deepcopy(j)
for n in j['nodes']:
 if n.get('name')=='GoldMine_Root':n['extras']['base_income_gold_per_second']=2
x=json.dumps(j,separators=(',',':')).encode();x+=b' '*((-len(x))%4);open(p,'wb').write(struct.pack('<4sII',b'glTF',2,20+len(x)+len(rest))+struct.pack('<II',len(x),ty)+x+rest)
# Strip only the changed metadata field when comparing the entire GLB JSON graph.
for value in [j,original]:
 for n in value['nodes']:
  if n.get('name')=='GoldMine_Root':n['extras'].pop('base_income_gold_per_second')
assert j==original
b2=open(p,'rb').read();ln2=struct.unpack_from('<I',b2,12)[0];assert b2[20+ln2:]==rest
p=os.path.join(D,'goldmine_metrics.json');m=json.load(open(p));m['base_income_gold_per_second']=2;json.dump(m,open(p,'w'),indent=2)
r={'change':'Level 1 mine combat income metadata','previous_gold_per_second':old_income,'current_gold_per_second':2,'income_phase':'combat_only','setup_income_gold_per_second':0,'pause_income_gold_per_second':0,'blender_semantic_sha256_before':before_blend,'blender_semantic_sha256_after':after_blend,'glb_geometry_animation_binary_sha256':hashlib.sha256(rest).hexdigest(),'glb_json_change_limited_to_income_extra':True,'geometry_animation_materials_unchanged':True,'passed':True}
json.dump(r,open(os.path.join(D,'verification','economy_metadata_revision.json'),'w'),indent=2);print(json.dumps(r,indent=2))
