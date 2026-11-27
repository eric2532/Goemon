"""Compare reused Desert Temple native cache pixels with original archive frames."""
import json
import struct
import sys
from pathlib import Path

from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
import cg_assets as cg


def audit():
    folder=ROOT/'assets/characters/crossgate/guard_pets'
    manifest=json.loads((folder/'motions.json').read_text());table=(folder/'frames.bin').read_bytes()
    palette=Image.open(folder/'palette.png').convert('RGBA');columns=palette.width//256
    assert columns>0 and palette.width%256==0
    pages={};colours={};records=[];failures=[]
    def row(index):return struct.unpack_from('<4f',table,index*16)
    for skin in [242,258,399]:
        variant=manifest['variants'][skin];key=variant['key'];ident,_,clips=cg.actor(key)
        assert ident==variant['id'];source={(c['action'],c['direction']):c for c in clips}
        frames=0;checked_clips=0;blank=0;offsets=set();remaps=[]
        for ai,action in enumerate(manifest['actions']):
            native_action=variant.get('run_action',3) if action==3 else action
            if native_action!=action:remaps.append(dict(native_action=action,original_action=native_action))
            for direction in range(8):
                header=row((skin*len(manifest['actions'])+ai)*8+direction);original=source[native_action,direction]
                if int(header[1])!=len(original['frames']) or abs(header[2]-original['duration']/1000)>0.00001:
                    failures.append(dict(skin=skin,action=action,direction=direction,kind='clip_count_or_duration'));continue
                checked_clips+=1
                for index in range(int(header[1])):
                    frame=int(header[0])+index;x,y,w,h=map(int,row(manifest['clip_count']+frame*2))
                    ox,oy,page,colour=row(manifest['clip_count']+frame*2+1);page=int(page);colour=int(colour)
                    if page not in pages:pages[page]=Image.open(ROOT/manifest['atlas_paths'][page].removeprefix('res://')).convert('L')
                    if colour not in colours:colours[colour]=[palette.getpixel((i+(colour%columns)*256,colour//columns)) for i in range(256)]
                    actual=Image.new('RGBA',(w,h));actual.putdata([colours[colour][v] for v in pages[page].crop((x,y,x+w,y+h)).getdata()])
                    image,sx,sy=cg.frame_parts(key,original['index'],index);box=image.getbbox()
                    if box is None:
                        blank+=1
                        if actual.getbbox() is not None:failures.append(dict(skin=skin,action=action,direction=direction,index=index,kind='paint_in_original_blank'))
                    else:
                        expected=image.crop(box)
                        if actual.size!=expected.size or actual.tobytes()!=expected.tobytes():
                            failures.append(dict(skin=skin,action=action,direction=direction,index=index,kind='rgba_or_crop',actual=list(actual.size),original=list(expected.size)))
                        offsets.add((round(ox-sx-box[0],5),round(oy-sy-box[1],5)))
                    frames+=1
        if len(offsets)!=1:failures.append(dict(skin=skin,kind='inconsistent_source_anchor_offset',offsets=sorted(offsets)))
        records.append(dict(skin=skin,appearance=ident,key=key,clips=checked_clips,frames=frames,blank_frames=blank,
                            source_anchor_offsets=sorted(offsets),declared_run_action_remaps=remaps))
    result=dict(records=records,frames=sum(r['frames'] for r in records),clips=sum(r['clips'] for r in records),
                failures=len(failures),failure_examples=failures[:30],goal_complete=False,
                qualification='Original RGBA/crop/clip-duration comparison and consistent cache-origin offsets. Declared run_action fallback is followed. This does not certify body scale, animation contact or rendered appearance.')
    out=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Desert Temple/enemy-original-frame-proof.json'
    out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('DESERT_SOURCE_FRAMES',result['frames'],'frames',result['clips'],'clips',result['failures'],'failures')
    return not failures


if __name__=='__main__':raise SystemExit(0 if audit() else 1)
