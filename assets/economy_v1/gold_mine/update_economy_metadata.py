import os,bpy,json,struct
D=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(D,'goldmine_v1.blend'))
bpy.data.objects['GoldMine_Root']['base_income_gold_per_second']=2
for k,v in {'income_phase':'combat_only','setup_income_gold_per_second':0,'pause_income_gold_per_second':0,'cleanup_combat_status':'undecided'}.items():bpy.data.objects['GoldMine_Root'][k]=v
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(D,'goldmine_v1.blend'),compress=True)
p=os.path.join(D,'goldmine_v1.glb');b=open(p,'rb').read();ln,ty=struct.unpack_from('<II',b,12);j=json.loads(b[20:20+ln]);rest=b[20+ln:]
for n in j['nodes']:
 if n.get('name')=='GoldMine_Root':n['extras'].update({'base_income_gold_per_second':2,'income_phase':'combat_only','setup_income_gold_per_second':0,'pause_income_gold_per_second':0,'cleanup_combat_status':'undecided'})
x=json.dumps(j,separators=(',',':')).encode();x+=b' '*((-len(x))%4)
open(p,'wb').write(struct.pack('<4sII',b'glTF',2,20+len(x)+len(rest))+struct.pack('<II',len(x),ty)+x+rest)
p=os.path.join(D,'goldmine_metrics.json');j=json.load(open(p));j['base_income_gold_per_second']=2;j['income_phase']='combat_only';j['setup_income_gold_per_second']=0;j['pause_income_gold_per_second']=0;j['cleanup_combat_status']='undecided';j['visible_height_m']=2.8934;j['footprint_m']=[4.547,4.732];j['embedded_below_ground_m']=.418
json.dump(j,open(p,'w'),indent=2)
print('ECONOMY_METADATA_UPDATED_TO_2_GOLD_PER_SECOND')
