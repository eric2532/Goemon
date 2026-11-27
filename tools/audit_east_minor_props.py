"""Inventory actual East fixed-map object use; render bounded native contact sheets after Godot classification."""
import base64
from collections import Counter
import json
from pathlib import Path
import struct
import zlib
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'assets/maps/original_crossgate'
OUT=ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks'


def usage():
    catalog=json.loads((ART/'east/catalog.json').read_text());rows={}
    for row in catalog['maps'].values():
        key='reference_variant_raw' if row.get('active_layout_variant')=='pinned-reference' else 'restored_raw' if 'restored_raw' in row else 'raw'
        raw=zlib.decompress(base64.b64decode(row[key]));w,h=struct.unpack_from('<II',raw,12);cells=w*h
        counts=Counter(struct.unpack_from(f'<{cells}H',raw,20+cells*2));aliases=row.get('graphic_aliases',{})
        for serial,count in counts.items():
            if not serial:continue
            alias=int(aliases.get(str(serial),serial));token=str(alias)
            result=rows.setdefault(token,{'graphic':alias,'placements':0,'map_count':0,'maps':[]})
            result['placements']+=count;result['map_count']+=1
            if len(result['maps'])<12:result['maps'].append(row['id'])
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'source-object-usage.json').write_text(json.dumps({'maps':len(catalog['maps']),'graphics':rows},ensure_ascii=False,separators=(',',':'))+'\n')
    print('EAST_SOURCE_OBJECT_USAGE',len(rows),'native graphics in',len(catalog['maps']),'fixed maps')


def contacts():
    audit=json.loads((OUT/'minor-prop-audit.json').read_text());catalog=json.loads((ART/'east/catalog.json').read_text())
    for path in [ART/'catalog.json',ROOT/'assets/maps/falan/sokia/fixed/catalog.json',ART/'university/catalog.json',ART/'elsa/catalog.json']:
        other=json.loads(path.read_text())
        offset=other.get('page_offset',13 if path.parent.name=='university' else 0)
        for serial,g in other['graphics'].items():
            if serial in catalog['graphics']:continue
            g=dict(g);g['absolute_page']=path.parent/other['pages'][g['page']-offset];catalog['graphics'][serial]=g
    rows=sorted(audit['graphics'],key=lambda row:row['placements'],reverse=True)
    # Representatives include frequent props and largest unclassified source forms.
    chosen=[]
    for row in rows[:28]+sorted(rows,key=lambda row:row['pixels'][0]*row['pixels'][1],reverse=True)[:20]:
        if row not in chosen:chosen.append(row)
    pages={}
    for start in range(0,len(chosen),16):
        group=chosen[start:start+16];sheet=Image.new('RGB',(1200,1080),'#242b2c');draw=ImageDraw.Draw(sheet)
        for index,row in enumerate(group):
            g=catalog['graphics'][str(int(row['graphic']))];page=g.get('absolute_page') or ART/catalog['pages'][g['page']]
            if str(page) not in pages:pages[str(page)]=Image.open(page).convert('RGBA')
            x,y,w,h=g['rect'];image=pages[str(page)].crop((x,y,x+w,y+h));image.thumbnail((280,220))
            left=index%4*300;top=index//4*270;sheet.paste(image,(left+(300-image.width)//2,top),image)
            draw.text((left+8,top+226),f"{row['graphic']} | {row['placements']} placements",fill='white')
            draw.text((left+8,top+243),row['presentation'],fill='white')
        sheet.save(OUT/f'minor-prop-native-sheet-{start//16+1}.png')
    print('EAST_MINOR_PROP_CONTACTS',len(chosen),'representative native graphics')


if __name__=='__main__':
    import sys
    contacts() if '--contacts' in sys.argv else usage()
