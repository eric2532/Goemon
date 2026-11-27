"""Private exact native Kanabella BG assemblies; no shared map/art owner changes."""
import hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw
from review_east_backgrounds import ROOT,CATALOG,Native,decode

LEDGER=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Background Layers/kanabella-house-compounds.json'
OUT=ROOT/'assets/maps/falan/east_region/kanabella_bg'
REPORT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Kanabella BG Houses'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def prepare():
    source=json.loads(LEDGER.read_text());catalog=json.loads(CATALOG.read_text());native=Native();models={};maps={}
    OUT.mkdir(parents=True,exist_ok=True);REPORT.mkdir(parents=True,exist_ok=True);(REPORT/'.gdignore').touch()
    for mid,context in source['maps'].items():
        row=next(r for r in catalog['maps'].values() if r['id']==int(mid));w,h,raw,values,bits,aliases=decode(row)
        assert sha(raw)==context['source_raw_sha256'],('Refresh exact source ledger before preparation',mid)
        groups=[]
        for index,group in enumerate(context['groups']):
            ax,ay,_,_=group['bounds'];tuples=sorted([t['cell'][0]-ax,t['cell'][1]-ay,t['native_graphic']] for t in group['tiles'])
            signature=sha(json.dumps(tuples,separators=(',',':')).encode());assert signature==group['canonical_native_tuple_sha256']
            token=signature[:16];pieces=[];left=top=10**9;right=bottom=-10**9
            for t in group['tiles']:
                x,y=t['cell'];serial=t['native_graphic'];assert values[y*w+x]==serial
                alias=aliases.get(serial,serial);g=native.table[alias][0];dx,dy=x-ax,y-ay
                px=(dx+dy)*32+g['origin'][0];py=(dy-dx)*24+g['origin'][1];pw,ph=g['rect'][2:]
                pieces.append(dict(cell=[x,y],relative_cell=[dx,dy],native_graphic=serial,graphic=alias,draw_at=[px,py],size=[pw,ph],native_origin=g['origin'],source_rgba_sha256=g['rgba_sha256'],original_open=t['original_open']))
                left=min(left,px);top=min(top,py);right=max(right,px+pw);bottom=max(bottom,py+ph)
            if token not in models:
                image=Image.new('RGBA',(right-left,bottom-top))
                for p in sorted(pieces,key=lambda p:(p['relative_cell'][1],p['relative_cell'][0])):image.alpha_composite(native.crop(p['graphic']),(p['draw_at'][0]-left,p['draw_at'][1]-top))
                image.save(OUT/f'{token}-native.png')
                models[token]=dict(native_tuple_sha256=signature,native_origin=[left,top],native_size=list(image.size),native_rgba_sha256=sha(image.tobytes()),
                    native_cells=[dict(relative_cell=p['relative_cell'],native_graphic=p['native_graphic'],graphic=p['graphic'],draw_at=p['draw_at'],source_rgba_sha256=p['source_rgba_sha256']) for p in pieces],
                    contexts=[],geometry_status='Source assembly only; measured roof/wall/door masks and compatible parts pending. Associated grass is not building volume.')
            models[token]['contexts'].append(dict(map=int(mid),group=index,anchor=[ax,ay]))
            groups.append(dict(group=index,model=token,anchor=[ax,ay],source_bounds=group['bounds'],exact_bg_cells=pieces,
                nearby_directed_entrances_and_returns=group['nearby_directed_entrances_and_returns'],nearby_pg1=group['nearby_pg1'],
                navigation='Original open bits/door/return cells are preserved. Nearby records may include an adjacent house; no route is inferred from cluster bounds.'))
        maps[mid]=dict(title=row['title'],size=[w,h],source_raw_sha256=sha(raw),groups=groups)
    data=dict(schema=1,scope='PRIVATE source-only BG house assemblies; no live dispatch, map, collision or quest changes.',catalog_sha256=sha(CATALOG.read_bytes()),
        source_ledger_sha256=sha(LEDGER.read_bytes()),source_catalogs=native.pins,models=models,maps=maps,translation_proofs=source['translation_proofs'],
        reuse_plan='No complete match among38 prepared whole houses. Reuse existing curved roof/gable/dormer, plaster/stone walls, rail/stair and column parts; author only the missing measured curled eave/silhouette pieces.',
        inferences_pending=['Separate source architecture from associated grass without removing green ceramic roof paint.','Measure walls, roof ridge/eaves, dormers, doors and stairs from each native assembly.','Continue hidden plaster/roof/trim rhythm using independent materials; never replay a front door on the back.'])
    (OUT/'data.json').write_text(json.dumps(data,indent=2)+'\n');(REPORT/'source-assembly.json').write_text(json.dumps(data,indent=2)+'\n')
    tokens=list(models);contact=Image.new('RGB',(1600,500*((len(tokens)+3)//4)),(36,42,39));draw=ImageDraw.Draw(contact)
    for i,token in enumerate(tokens):
        image=Image.open(OUT/f'{token}-native.png').convert('RGBA');image.thumbnail((390,445))
        xx=(i%4)*400;yy=(i//4)*500;contact.paste(image,(xx+(400-image.width)//2,yy+38),image.getchannel('A'))
        c=models[token]['contexts'];draw.text((xx+7,yy+5),f'{i}: {token[:10]} | {len(c)} placements',fill='white')
        draw.text((xx+7,yy+20),'33500 groups '+','.join(str(x['group']) for x in c if x['map']==33500),fill='white')
    contact.save(REPORT/'native-assemblies.jpg',quality=95)
    print('KANABELLA_SOURCE groups=',sum(len(r['groups']) for r in maps.values()),'models=',len(models),'maps=',len(maps))
if __name__=='__main__':prepare()
