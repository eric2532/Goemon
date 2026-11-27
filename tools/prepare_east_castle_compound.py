"""Prove and enroll the exact71-piece native31954Beast Castle compound."""
import argparse
import base64
import hashlib
import json
import struct
import zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/classic_architecture/castle_compound/data.json'


def products():
    original=json.loads((ROOT/'assets/maps/original_crossgate/catalog.json').read_text())
    east=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())
    def raw(row):
        encoded=row['reference_variant_raw'] if row.get('active_layout_variant')=='pinned-reference' else row.get('restored_raw',row['raw'])
        return zlib.decompress(base64.b64decode(encoded))
    before=raw(original['maps']['BlueCrossgate/map/0/400.dat']);after=raw(east['maps']['BlueCrossgate/map/0/31954.dat'])
    def piece(data,layer,x,z):
        width,height=struct.unpack_from('<II',data,12);return struct.unpack_from('<H',data,20+(layer*width*height+z*width+x)*2)[0]
    source=[];target=[]
    for layer in range(2):
        for z in range(326,334):
            for x in range(131,140):
                serial=piece(before,layer,x,z)
                if layer==0 and 1600<=serial<=1692 or layer==1 and serial==10011:
                    source.append([layer,x,z,serial]);target.append([layer,x+625,z-275,serial])
    assert len(source)==71
    actual=[]
    for layer in range(2):
        for z in range(51,59):
            for x in range(756,765):
                serial=piece(after,layer,x,z)
                if layer==0 and 1600<=serial<=1692 or layer==1 and serial==10011:actual.append([layer,x,z,serial])
    assert sorted(actual)==sorted(target),'The compound must retain every exact source tuple and no additional castle tuple'
    size=list(struct.unpack_from('<II',after,12))
    return (json.dumps({'schema':1,'source':31954,'size':size,'anchor':[760,58],'source_graphic_anchor':[756,58],
        'reused_source':400,'reused_anchor':[135,333],'translation':[625,-275],
        'source_raw_sha256':hashlib.sha256(after).hexdigest(),'reused_restored_raw_sha256':hashlib.sha256(before).hexdigest(),
        'pieces':sorted(target),'piece_count':71,'exact_tuple_equality':True,
        'owner':'res://scripts/forest/forest_beast_castle.gd','scale_contract':'Reuse every Source400XZvertex at the translated source anchor. The isolated East derivative applies canonical ownerY=.045*Fit.VERTICAL exactly once; no sprite bbox fit or callerYconversion. Source400/West remains unchanged.',
        'scope':'Only these71source layer/cell/graphic tuples in31954 are composed by the existing whole master; source bytes/walk/warps/other drawings are unchanged.'},indent=2)+'\n').encode()


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();payload=products()
    if args.check:
        assert OUT.exists() and OUT.read_bytes()==payload,'Stale exact castle compound metadata'
    else:
        OUT.parent.mkdir(parents=True,exist_ok=True)
        if not OUT.exists() or OUT.read_bytes()!=payload:OUT.write_bytes(payload)
    print(('Verified' if args.check else 'Prepared')+' exact71tuple castle reuse; originals unchanged.')


if __name__=='__main__':main()
