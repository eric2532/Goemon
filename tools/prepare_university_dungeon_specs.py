"""Retain the pinned regional floor counts, dimensions and dungeon endpoints as runtime data."""
import argparse
import hashlib
import json
from pathlib import Path
import review_university_region as review

OUT=review.ROOT/'assets/maps/falan/university_region/dungeon_specs.gd'
BRANCHES={401:('scientist',51801,'科學家的牢房',[13996,13997],False),
          402:('mountain',51301,'積雪的山路',[17956,17957],True),
          403:('lizard',51401,'蜥蜴之巢',[12000,12002],False),
          404:('tunnel',51501,'奇怪的坑道',[17954,17955],False),
          406:('permafrost',51601,'永久凍土',[17956,17957],True),
          407:('abyss',51701,'深淵',[17974,17975],False)}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args()
    source=review.SOURCE/'dungeonconf.txt';specs={};proof=[]
    for line in source.read_bytes().decode('gb18030').splitlines():
        row=line.split('\t')
        if len(row)<52 or not row[3].isdigit() or int(row[3]) not in BRANCHES:continue
        config=int(row[3]);key,first,title,stairs,frozen=BRANCHES[config]
        entry=list(map(int,row[9:12]));rectangle=list(map(int,row[10:14]))
        if config==404:entry=[400,365,357]
        specs[key]=dict(first=first,minimum=int(row[39]),maximum=int(row[40]),size=list(map(int,row[41:45])),
                        ground=int(row[22]),stairs=stairs,title=title,entry=entry,end=list(map(int,row[15:18])),
                        frozen=frozen,encounter=int(row[49]),levels=list(map(int,row[50:52])),config=config,entry_rect=rectangle,
                        terminal_enemy=int(row[97] or 0),terminal_enemy_count=int(row[98] or 0),
                        terminal_npc=int(row[99] or 0),terminal_placement=int(row[100] or -1))
        proof.append(dict(branch=key,raw=row))
    assert set(specs)=={r[0] for r in BRANCHES.values()}
    fixed=[r['source'] for r in json.loads((review.OUT/'scope.json').read_text())['fixed']]
    text='extends RefCounted\n## Generated from the pinned original-reference dungeon configuration.\nconst FIXED='+json.dumps(fixed)+'\nconst SPECS='+json.dumps(specs,ensure_ascii=False,indent=1)+'\n'
    if args.check:assert OUT.read_text()==text,'Regional dungeon specs are stale'
    else:OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_text(text)
    (review.OUT/'dungeon-specs.json').write_text(json.dumps(dict(source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),specs=specs,reference_rows=proof,
        limits=['Counts, dimensions, terrain/stair identities and endpoints are preserved. The original random graph algorithm/probability distribution was not supplied; the existing Goemon room graph remains an explicit adaptation.',
                'All snow floors select complete original native snapshots in a seeded shuffle bag; stable first-two floor IDs are retained.']),ensure_ascii=False,indent=2)+'\n')
    print('UNIVERSITY_DUNGEON_SPECS',len(specs),'source-backed branches')


if __name__=='__main__':main()
