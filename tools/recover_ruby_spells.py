"""Prepare verified level-five Ruby spell sheets, reusing existing original atlases."""
import argparse, hashlib, json, sys
from pathlib import Path, PureWindowsPath
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/characters/crossgate/black_prayer/spells'
REFS=('110054','110026','110038','110039','110040','110083','110087','110178','110109','110113','110117','110121','110125','110129','110163','110098')
CONTACTS={'754':'110117','755':'110121','756':'110109','757':'110113','758':'110125','759':'110129'}
TECHS={'6104','6204','6404','6550','850','5504','5604','5704','5804','5904','6004','2704','2804','4804'}

def prepare(source):
    assets=source/'godot/assets'
    original=json.loads((assets/'humanoid-spells/manifest.json').read_text())
    shared=json.loads((ROOT/'assets/characters/crossgate/skill_tiers/manifest.json').read_text())
    result={'snapshot_sha256':original['snapshotSha256'],'level':5,'clips':{},'sounds':{},'tech_rows':{},'enemy_rows':{}}
    result['ward_contacts']=CONTACTS;result['confusion']='110163';result['holy_shield']='110098'
    holy_raw=(ROOT/'assets/references/black_prayer/holy-shield-factory.json').read_bytes()
    holy=json.loads(holy_raw)
    assert holy['snapshot_sha256']==original['snapshotSha256']
    assert all(r['resources']==[110098] and r['protocol_queries']==[8] for r in holy['cases'] if r['flags']==1024)
    result['holy_factory_sha256']=hashlib.sha256(holy_raw).hexdigest()
    evidence=(ROOT/'assets/references/black_prayer/spell-effect-factory.json').read_bytes()
    proof=json.loads(evidence)
    assert proof['snapshot_sha256']==original['snapshotSha256']
    for row in proof['cases']:
        ref=CONTACTS.get(str(row['action']),result['confusion'])
        assert str(row['objects'][0]['resource'])==ref
        if row['action']!=763:assert row['skill_queries']==[row['protocolType']]
    result['effect_factory_sha256']=hashlib.sha256(evidence).hexdigest()
    sys.path.insert(0,str(source/'tools'))
    import cg_assets as cg
    import cg_sounds
    cg.SOURCE=source/'research/newclient20261030/source/bin'
    from recover_habaru_encounter import body_rows
    ruby_clip=next(c for c in cg.metadata('original:1184')['clips'] if c['action']==0 and c['direction']==4)
    ruby_image,_,_=cg.frame_parts('original:1184',ruby_clip['index'],0)
    top,foot=body_rows(ruby_image)
    outputs={}
    for ref in REFS:
        if ref in original['clips']:
            spec=original['clips'][ref]
            raw=(assets/spec['file']).read_bytes()
        else:
            key='original:'+str(cg.latest_animation_rows('original')[int(ref)])
            info=cg.metadata(key);meta=info['clips'][0];frames=cg.actor(key)[2][0]['frames']
            assert len(info['clips'])==1 and meta['available'] and meta['action']==0 and meta['direction']==0
            raw=cg.png(cg.sheet_image(key,0,info=info))
            cues=[]
            for i,frame in enumerate(frames):
                ident=frame[3]%10000
                if not ident:continue
                name=PureWindowsPath(cg_sounds.sound_table()[str(ident)]['file']).name
                sound=(cg.SOURCE/'se'/name).read_bytes()
                cues.append({'id':ident,'atMs':i*meta['duration']/meta['frameCount'],'file':'humanoid-spells/'+name.lower(),'sha256':hashlib.sha256(sound).hexdigest()})
            spec={'frames':meta['frameCount'],'columns':meta['columns'],'width':meta['cellWidth'],'height':meta['cellHeight'],'duration':meta['duration'],'bounds':meta['bounds'],'sha256':hashlib.sha256(raw).hexdigest(),'hitMs':[],'sounds':cues}
            result.setdefault('native_clips',{})[ref]={'key':key,'frames':[list(f) for f in frames]}

        assert hashlib.sha256(raw).hexdigest()==spec['sha256'],ref
        if ref in shared['clips']:
            path=shared['clips'][ref]['runtime_path']
            assert hashlib.sha256((ROOT/path.removeprefix('res://')).read_bytes()).hexdigest()==spec['sha256']
        else:
            path='res://'+str((OUT/(ref+'.png')).relative_to(ROOT));outputs[ref+'.png']=raw
        result['clips'][ref]={k:spec[k] for k in ['frames','columns','width','height','duration','bounds','sha256']}
        if ref=='110098':result['clips'][ref]['reference_body_pixels']=foot-top
        result['clips'][ref]['runtime_path']=path
        result['clips'][ref]['hit_ms']=spec['hitMs']
        result['clips'][ref]['sounds']=[{'at_ms':c['atMs'],'id':c['id']} for c in spec['sounds']]
        for cue in spec['sounds']:
            source_sound=assets/cue['file']
            if not source_sound.exists():source_sound=cg.SOURCE/'se'/PureWindowsPath(cg_sounds.sound_table()[str(cue['id'])]['file']).name
            sound=source_sound.read_bytes()
            assert hashlib.sha256(sound).hexdigest()==cue['sha256']
            name=Path(cue['file']).name
            # Reuse an existing identical sound instead of introducing a second sample.
            matches=sorted((ROOT/'assets').glob('**/'+name))
            match=next((p for p in matches if hashlib.sha256(p.read_bytes()).hexdigest()==cue['sha256']),None)
            path='res://'+str(match.relative_to(ROOT)) if match else 'res://'+str((OUT/name).relative_to(ROOT))
            if match is None:outputs[name]=sound
            result['sounds'][str(cue['id'])]={'runtime_path':path,'sha256':cue['sha256']}
    for ident in [131,132]:
        name=PureWindowsPath(cg_sounds.sound_table()[str(ident)]['file']).name
        raw=(cg.SOURCE/'se'/name).read_bytes();digest=hashlib.sha256(raw).hexdigest()
        match=next((p for p in sorted((ROOT/'assets').glob('**/'+name.lower())) if hashlib.sha256(p.read_bytes()).hexdigest()==digest),None)
        path='res://'+str(match.relative_to(ROOT)) if match else 'res://'+str((OUT/name.lower()).relative_to(ROOT))
        if match is None:outputs[name.lower()]=raw
        result['sounds'][str(ident)]={'runtime_path':path,'sha256':digest}
    for cue in [original['skills']['heal']['5']['castSound'],original['skills']['h_super_earth']['5']['targetSound'],original['skills']['h_super_earth']['5']['impactSound']]:
        raw=(assets/cue['file']).read_bytes();assert hashlib.sha256(raw).hexdigest()==cue['sha256']
        name=Path(cue['file']).name
        match=next((p for p in sorted((ROOT/'assets').glob('**/'+name)) if hashlib.sha256(p.read_bytes()).hexdigest()==cue['sha256']),None)
        path='res://'+str(match.relative_to(ROOT)) if match else 'res://'+str((OUT/name).relative_to(ROOT))
        if match is None:outputs[name]=raw
        result['sounds'][str(cue['id'])]={'runtime_path':path,'sha256':cue['sha256']}
    data=source/'research/cgmsv-20261031/source/gmsv/data'
    for filename in ['enemy.txt','enemybase.txt','enemyai.txt','tech.txt']:
        raw=(data/filename).read_bytes()
        for line in raw.decode('gb18030').splitlines():
            r=line.split('\t')
            chosen=(filename=='enemy.txt' and len(r)>2 and r[2]=='260092') or (filename=='enemybase.txt' and len(r)>1 and r[1]=='3002') or (filename=='enemyai.txt' and r[0]=='11017')
            if chosen:result['enemy_rows'][filename]=line
            if filename=='tech.txt' and len(r)>3 and r[3] in TECHS:result['tech_rows'][r[3]]=line
    assert len(result['enemy_rows'])==3 and set(result['tech_rows'])==TECHS
    return outputs,result

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power');p.add_argument('--check',action='store_true');a=p.parse_args()
    files,meta=prepare(a.source.resolve())
    if a.check:
        assert json.loads((OUT/'manifest.json').read_text())==meta
        for name,raw in files.items():assert (OUT/name).read_bytes()==raw,name
        print('RUBY_SPELL_SOURCE_CHECK original sheets, sounds and matched Black Prayer/tech records preserved')
    else:
        OUT.mkdir(parents=True,exist_ok=True)
        for name,raw in files.items():(OUT/name).write_bytes(raw)
        (OUT/'manifest.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
        print('Prepared',len(meta['clips']),'original spell clips;',len(files),'new shared-source files')
if __name__=='__main__':main()
