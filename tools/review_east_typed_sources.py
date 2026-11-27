"""Bounded native contacts for the larger already-typed East dependencies."""
import json
from collections import defaultdict
from pathlib import Path
from PIL import Image,ImageDraw
from prepare_east_nature import ROOT,sources
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Remaining Fallback Audit'

def main():
    original=json.loads((OUT/'typed-native-candidates.json').read_text())['graphics'];lookup,pages,_=sources();runtime={}
    typed=OUT/'typed-owner-inventory.json'
    if typed.exists():runtime={int(r['graphic']):r for r in json.loads(typed.read_text())['typed_graphics']}
    aliases=sorted((r for r in original if r['graphic']>=1000000),key=lambda r:r['graphic'])
    groups=defaultdict(list)
    for row in original:
        if row['graphic']<1000000:groups[row['graphic']//100].append(row)
    selected=[]
    for band,rows in sorted(groups.items()):
        for row in sorted(rows,key=lambda r:r['pixels'][0]*r['pixels'][1],reverse=True)[:2]+sorted(rows,key=lambda r:r['placements'],reverse=True)[:1]:
            if row not in selected:selected.append(row)
    index=[]
    floors=sorted((r for r in runtime.values() if r['family']=='floor'),key=lambda r:r['graphic'])
    for title,rows in [('typed-aliased',aliases),('typed-classic-family',selected),('typed-floor',floors)]:
        for start in range(0,len(rows),24):
            sheet=Image.new('RGB',(1200,1320),'#243039');draw=ImageDraw.Draw(sheet);name=f'{title}-{start//24+1:02}.png'
            for slot,row in enumerate(rows[start:start+24]):
                serial=row['graphic'];g,page=lookup[serial]
                if page not in pages:pages[page]=Image.open(page).convert('RGBA')
                x,y,w,h=map(int,g['rect']);native=pages[page].crop((x,y,x+w,y+h));native.thumbnail((285,165))
                left=slot%4*300;top=slot//4*220;sheet.paste(native,(left+(300-native.width)//2,top),native)
                role=runtime.get(serial,{}).get('family','type-pending')
                draw.text((left+6,top+171),f'{serial} {role}',fill='white')
                draw.text((left+6,top+187),f'{w}x{h} / fp{g["footprint"]} ground={g.get("ground",0)}',fill='white')
                draw.text((left+6,top+203),f'{row["placements"]} uses / maps '+','.join(str(c['map']) for c in row['contexts'][:3]),fill='#fbd25f')
                index.append({'graphic':serial,'sheet':name,'slot':slot+1,'family':role,'source_rgba_sha256':g['rgba_sha256']})
            sheet.save(OUT/name)
    (OUT/'typed-contact-index.json').write_text(json.dumps({'contacts':index,'all_aliases':len(aliases),'classic_family_representatives':len(selected),'scope':'All aliased larger typed candidates plus size/use representatives from each classic100-ID band. This is source triage, not full visual acceptance.'},ensure_ascii=False,indent=2)+'\n')
    print('EAST_TYPED_SOURCE_CONTACTS',len(aliases),'aliases +',len(selected),'classic family representatives')

if __name__=='__main__':main()
