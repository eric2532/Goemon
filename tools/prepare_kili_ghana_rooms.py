"""Reproduce the three recovered room masks and their original door destinations."""
import argparse,re
from pathlib import Path
import build_freyja_destinations as d
import review_kili_ghana as r
from prepare_field_assets import navigation_grid

def prepared():
 p=r.ROOT/'assets/maps/falan/freyja_destinations_data.gd';text=p.read_text();prefix,blocks=text.split('const ROOMS={',1);rooms,tail=blocks.split('const DOORS={',1);doors,rest=tail.split('const TITLES={',1)
 for n,(_,_,cell) in d.GHANA_HOMES.items():
  w,h,f,o,_=d.load_map(r.source.review.lib,n);walk=navigation_grid(w,h,f,o,r.source.review.lib.serial_index());seed=cell[1]*w+cell[0]
  assert walk[seed],(n,cell)
  reached={seed};queue=[seed]
  for i in queue:
   for x,y in [(i%w-1,i//w),(i%w+1,i//w),(i%w,i//w-1),(i%w,i//w+1)]:
    j=y*w+x
    if 0<=x<w and 0<=y<h and walk[j] and j not in reached:reached.add(j);queue.append(j)
  bits=bytearray((w*h+7)//8)
  for i in reached:bits[i>>3]|=1<<(i&7)
  row=f' {n}:[Vector2i({w},{h}),Vector2({-w//2*3},{-h//2*3}),"{bits.hex()}"],'
  rooms,count=re.subn(rf'^ {n}:.*$',lambda _:row,rooms,flags=re.M);assert count==1
 links=d.interior_links(r.ROOT.parent/'Magic Power')
 for n in [3000,*d.GHANA_HOMES]:
  rows=[]
  for source,x,y,target,tx,ty in links:
   if source!=n:continue
   sw,sh,*_=d.load_map(r.source.review.lib,source);tw,th,*_=d.load_map(r.source.review.lib,target)
   rows.append(f'[Vector2({(x-sw//2)*3},{(y-sh//2)*3}),{target},Vector2({(tx-tw//2)*3},{(ty-th//2)*3})]')
  old=re.search(rf'^ {n}:(.*)$',doors,re.M)[1]
  if n==3000:
   for target in d.GHANA_HOMES:
    row=next(v for v in rows if re.search(rf'\),{target},',v))
    old,count=re.subn(rf'\[Vector2\([^)]*\),{target},Vector2\([^)]*\)\]',lambda _:row,old);assert count==1
   row=f' {n}:{old}'
  else:row=f' {n}:[{",".join(rows)}],'
  doors,count=re.subn(rf'^ {n}:.*$',lambda _:row,doors,flags=re.M);assert count==1
 return p,prefix+'const ROOMS={'+rooms+'const DOORS={'+doors+'const TITLES={'+rest

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();p,text=prepared()
 if args.check:assert p.read_text()==text
 else:p.write_text(text)
 print('PASS three recovered room masks and four housing door rows; all other data retained')
if __name__=='__main__':main()
