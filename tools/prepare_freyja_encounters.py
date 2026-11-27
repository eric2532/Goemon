"""Stage every source-map100 encounter for the existing regional/native owner."""
import argparse
import hashlib
import json
from pathlib import Path

from prepare_snow_region_population import ROOT, SOURCE, rows

TABLES=('encount.txt','group.txt','enemy.txt','enemybase.txt')
DEFAULT=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja source encounters/prepared.json'
SCOPE=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja full-source outdoors/Prepared full/provenance.json'


def prepare(active=False):
    proofs={r['file']:r for r in json.loads((SOURCE/'references.json').read_text())}
    hashes={name:hashlib.sha256((SOURCE/name).read_bytes()).hexdigest() for name in TABLES}
    assert all(proofs[name]['sha256']==digest for name,digest in hashes.items())
    base_path=ROOT/'assets/maps/falan/south_kili_route/population.json'
    base=json.loads(base_path.read_text());species=base['species']
    indices={int(row['id']):i for i,row in enumerate(species)}
    bank_path=ROOT/'assets/characters/crossgate/falan_encounters/motions.json'
    bank=json.loads(bank_path.read_text())
    east=json.loads((ROOT/'assets/maps/falan/east_region/population.json').read_text())
    east_indices={int(row['id']):i for i,row in enumerate(east['species'])}
    enemies={r[2]:r for r in rows('enemy.txt')};bases={r[1]:r for r in rows('enemybase.txt')}
    original_groups={r[2]:r for r in rows('group.txt')};groups={};east_groups={};east_members={};zones=[];appearances=set()
    for raw in rows('encount.txt'):
        if raw[3]!='100':continue
        chosen=[]
        for slot,gid in enumerate(raw[14:24]):
            weight=int(raw[24+slot] or 0)
            if not gid or not weight:continue
            group=original_groups[gid];members=[];identities=[];eastern=[];details=[]
            for member_slot,eid in enumerate(group[5:15]):
                member_weight=int(group[15+member_slot] or 0)
                if not eid or eid=='0' or not member_weight:continue
                enemy=enemies[eid];appearance=int(bases[enemy[3]][30]);index=indices[appearance]
                record=species[index]
                assert record['family']=='falan_encounters'
                assert int(bank['variants'][int(record['skin'])]['id'])==appearance
                members.append([index,int(enemy[4]),int(enemy[5]),member_weight])
                identities.append(dict(enemy_id=eid,count=list(map(int,enemy[6:8])),mandatory=group[25+member_slot]=='1'))
                eastern_index=east_indices[appearance]
                assert east['species'][eastern_index]['bank'] in ('east_region','companion')
                east_members[str(index)]=eastern_index
                eastern.append([eastern_index,int(enemy[4]),int(enemy[5]),member_weight])
                details.append(dict(species=eastern_index,enemy=eid,raw_enemy=enemy,raw_base=bases[enemy[3]]))
                appearances.add(appearance)
            prepared=dict(members=members,raw=group,order=group[1],source_members=identities)
            if gid in base['groups']:
                assert all(base['groups'][gid][key]==prepared[key] for key in ('members','raw','order'))
            groups[gid]=prepared;chosen.append([gid,weight])
            old_east=east['groups'].get(gid,{})
            if old_east:assert old_east['raw']==group and old_east['order']==group[1]
            east_groups[gid]={**old_east,**prepared,'members':eastern,'details':details}
        zones.append(dict(id=int(raw[0]),map=100,bounds=list(map(int,raw[4:8])),
                          probability=list(map(int,raw[8:10])),maximum=int(raw[10]),minimum=1,
                          priority=int(raw[11]),groups=chosen,raw=raw,freyja_source=True))
    assert len(zones)==56 and len({r['id'] for r in zones})==56
    scope=json.loads(SCOPE.read_text())
    assert scope['source_map']==100 and not scope['preview_bounds']
    return dict(schema=1,active=active,source_map=100,zones=zones,groups=groups,
                east_groups=east_groups,east_member_indices=east_members,
                source_hashes=hashes,base_species_count=len(species),species=species,
                outdoor_scope={area:row['source_dry_open_spans'] for area,row in scope['areas'].items()},
                scope_source_sha256=scope['source_sha256'],
                scope_provenance_sha256=hashlib.sha256(SCOPE.read_bytes()).hexdigest(),
                base_sha256=hashlib.sha256(base_path.read_bytes()).hexdigest(),
                bank_sha256=hashlib.sha256(bank_path.read_bytes()).hexdigest(),
                appearances=sorted(appearances),
                limits=['Source encounter tables use existing native owners; incomplete terrain/art and original count/probability execution remain separately required.' if active else 'Staged only; no terrain, encounter, patrol, source-map or native-boundary activation.',
                        'Whole-map100 source inventory; regional boundary and safe-zone ownership require separate source-domain verification.',
                        'Scope spans identify full-source decoder-open dry cells with exact existing city/village exclusions. They do not activate missing terrain; runtime placement must intersect current native terrain/support and bounded local queries.',
                        'Every existing member index, raw group, level range and weight is preserved. Source member count caps and optional/mandatory flags are retained.',
                        'One-member minimum is the existing real-time adaptation; original group-size, per-member minimum and probability-ramp execution remain unverified.',
                        'Existing native combat, body fits and pooled presentation are reused; source AI parity is not certified.'])


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,default=DEFAULT);parser.add_argument('--check',action='store_true');parser.add_argument('--active',action='store_true');args=parser.parse_args()
    data=prepare(args.active)
    if args.check:assert json.loads(args.out.read_text())==data
    else:args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('FREYJA_SOURCE_ENCOUNTERS',len(data['zones']),'zones',len(data['groups']),'groups',len(data['appearances']),'existing appearances; active='+str(args.active).lower())
