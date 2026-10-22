import json,struct,math,os
D=os.path.dirname(os.path.abspath(__file__))
b=open(os.path.join(D,'goldmine_v1.glb'),'rb').read();sz,typ=struct.unpack_from('<II',b,12);j=json.loads(b[20:20+sz]);off=20+sz;binsz,bintyp=struct.unpack_from('<II',b,off);binary=b[off+8:off+8+binsz]
def acc(i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];types={5126:('f',4),5123:('H',2),5125:('I',4)};fmt,n=types[a['componentType']];num={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']];o=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',n*num)
 return [struct.unpack_from('<'+fmt*num,binary,o+k*stride) for k in range(a['count'])]
clips={}
for a in j['animations']:
 channels={}
 for c in a['channels']:
  s=a['samplers'][c['sampler']];n=j['nodes'][c['target']['node']]['name'];channels[n+'::'+c['target']['path']]={'time':acc(s['input']),'value':acc(s['output'])}
 clips[a['name']]=channels
near=lambda a,b:all(abs(x-y)<1e-4 for x,y in zip(a,b))
bad_reverse=[];bad_loop=[]
for n,x in clips['build'].items():
 y=clips['reverse_build'][n]
 if not near(x['value'][0],y['value'][-1]) or not near(x['value'][-1],y['value'][0]):bad_reverse.append(n)
for n,x in clips['work_loop'].items():
 if not near(x['value'][0],x['value'][-1]):bad_loop.append(n)
root=next(n for n in j['nodes'] if n['name']=='GoldMine_Root')
r={'glb_bytes':len(b),'valid_magic':b[:4]==b'glTF','clip_durations':{k:max(z['time'][-1][0]-z['time'][0][0] for z in v.values()) for k,v in clips.items()},'reverse_endpoint_mismatches':bad_reverse,'loop_endpoint_mismatches':bad_loop,'base_cost_gold':root['extras']['base_build_cost_gold'],'base_income_gold_per_second':root['extras']['base_income_gold_per_second'],'external_resources':j.get('images',[]),'income_phase':root['extras']['income_phase'],'setup_income':root['extras']['setup_income_gold_per_second'],'pause_income':root['extras']['pause_income_gold_per_second'],'clip_start_times':{k:min(z['time'][0][0] for z in v.values()) for k,v in clips.items()}}
r['passed']=not bad_reverse and not bad_loop and r['base_cost_gold']==10 and r['base_income_gold_per_second']==2 and r['valid_magic'] and r['income_phase']=='combat_only' and r['setup_income']==0 and r['pause_income']==0 and all(x==0 for x in r['clip_start_times'].values())
json.dump(r,open(os.path.join(D,'verification','animation_contract.json'),'w'),indent=2);assert r['passed'],r;print(json.dumps(r,indent=2))
