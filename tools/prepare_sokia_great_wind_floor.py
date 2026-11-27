"""Original map13001 floor planes, with the existing native stone-paint derivative."""
import argparse,hashlib,json,sys
from pathlib import Path
from PIL import Image
from recover_falan_forts import native_stone
from recover_falan_architecture import opaque_paint
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/sokia/scenery'
def prepare():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from build_freyja_destinations import load_map
    w,h,floor,_,_=load_map(lib,13001);lookup=lib.serial_index()
    graphics={};original=Image.new('RGBA',(544,208));painted=Image.new('RGBA',original.size)
    serials=sorted({s for s in floor if s>=1000})
    assert serials==list(range(7788,7820))
    for i,s in enumerate(serials):
        g=lookup[s];image=lib.image_from_record(g['pack'],g['row']);at=(2+i%8*68,2+i//8*52)
        derivative=native_stone(opaque_paint(image),.55) if s>=7804 else image.copy();derivative.putalpha(image.getchannel('A'))
        original.paste(image,at);painted.paste(derivative,at)
        graphics[str(s)]=dict(origin=[g['x'],g['y']],rect=[*at,*image.size],water=s<7804,rgba_sha256=hashlib.sha256(image.tobytes()).hexdigest())
    data=dict(source=13001,size=[w,h],recorded_cells=sum(s>=1000 for s in floor),floor=b''.join(int(s).to_bytes(2,'little') for s in floor).hex(),graphics=graphics,
              method='Every recorded original floor cell. Rock paint reuses native_stone to retain native mean tone/luminance without enlarged palette-dither chroma. Water pixels unchanged. No collision or walk-mask change.')
    return data,{'great-wind-floor-original.png':original,'great-wind-floor.png':painted}
def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args();data,images=prepare()
    if a.check:assert json.loads((OUT/'great-wind-floor.json').read_text())==data
    else:(OUT/'great-wind-floor.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
    for name,image in images.items():
        if a.check:assert Image.open(OUT/name).tobytes()==image.tobytes(),name
        else:image.save(OUT/name)
    print('SOKIA_GREAT_WIND_FLOOR source=',data['source'],'native cells=',data['recorded_cells'],'graphics=',len(data['graphics']))
if __name__=='__main__':main()
