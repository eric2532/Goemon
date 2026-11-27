"""Prepare the two source-confirmed humanoid bosses in the existing native bank."""
import argparse
import json
from pathlib import Path

from prepare_east_region_population import append_native_bank
from recover_habaru_encounter import recover

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/characters/crossgate/sokia_region'
REPORT=ROOT/'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Scripted Bosses'


def records():
    # Preserve the existing playable Shin/Maze world size per original source pixel.
    return [dict(id=100452,name='杰特',key='original:2719',height=88/86,source_body_pixels=88,
                 fit_reference='existing Shin100450 pixel scale GOEMON_HEIGHT/86; joy754 is pixel-identical'),
            dict(id=100527,name='梅兹',key='original:2737',height=82/83,source_body_pixels=82,
                 fit_reference='existing Maze/Kaz pixel scale GOEMON_HEIGHT/83; joy598 is pixel-identical')]


def stage():
    folder=REPORT/'Staged'
    folder.mkdir(parents=True,exist_ok=True)
    recover(ROOT.parent/'Magic Power',shalena=True,species_override=records(),output_override=folder)
    data=json.loads((folder/'motions.json').read_text())
    for variant,record in zip(data['variants'],records()):variant['height']=record['height']
    (folder/'motions.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
    return folder


def append_scripted_actors():
    current=json.loads((OUT/'motions.json').read_text())
    if len(current['variants'])>=18:
        assert [r['id']for r in current['variants'][16:18]]==[100452,100527]
        return
    assert len(current['variants'])==16,'Append only after the preserved Cape16 publication'
    append_native_bank(OUT,stage(),[0,1],records())


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if not args.check:append_scripted_actors()
    data=json.loads((OUT/'motions.json').read_text())
    assert [r['id']for r in data['variants'][16:18]]==[100452,100527]
    print('SOKIA_SCRIPTED_ACTORS source2719/2737; existing sixteen slots retained')


if __name__=='__main__':main()
