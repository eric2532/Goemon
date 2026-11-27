"""Pinned original Ghana housing sources; no server programs are run."""
import argparse,hashlib,json,sys,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/references/crossgate_ghana_houses'
REV='6e5794f591ae40838e86d3229e4d930c7ce297b4'
HASHES={3804:'b026c28b28ca8c358c646c0deb4fb82850df5d42fcbe16a38872ab03372ffa63',3805:'9f93230e891a5740a476b0f8bd121f602417adf73efad02091dfaabf7469b74a',3806:'0969637f63b805181a09a3c977f0f1608a495e294b11eb42661d37469b30aac9'}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args()
 from build_freyja_destinations import read_housing_map
 OUT.mkdir(parents=True,exist_ok=True);files=[];plans=set()
 for n,sha in HASHES.items():
  name=f'{n:05d}_room';path=f'gmsv/data/map/{name}';target=OUT/name
  raw=target.read_bytes() if target.exists() else urllib.request.urlopen(f'https://raw.githubusercontent.com/awafer/crossgate/{REV}/{path}',timeout=30).read()
  assert hashlib.sha256(raw).hexdigest()==sha,n
  data=read_housing_map(raw,n);plans.add(tuple(data[2]+data[3]))
  assert data[:2]==(20,20)
  if not args.check:target.write_bytes(raw)
  files.append(dict(name=name,path=path,sha=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest(),sha256=sha))
 assert len(plans)==3
 manifest=dict(repository='https://github.com/awafer/crossgate',revision=REV,files=files,limits='Classic server layouts; original BlueCG client snapshots for these IDs are absent. No live BlueCG parity or dialogue authenticity is claimed.',source_doors={'3804':{'entrance':[76,79],'threshold':[3,10],'return':[76,79]},'3805':{'entrance':[85,69],'threshold':[12,16],'return':[85,69]},'3806':{'entrance':[38,63],'threshold':[10,14],'return':[36,64]}})
 if args.check:assert json.loads((OUT/'provenance.json').read_text())==manifest
 else:(OUT/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('PASS three pinned, distinct Ghana house maps and original return thresholds')
if __name__=='__main__':main()
