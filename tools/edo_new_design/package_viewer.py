"""Package actual mesh data inline; no model network requests are needed."""
import argparse,base64,gzip
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,default=ROOT/'docs/edo-new-design/edo-new-design.html')
dest=parser.parse_args().output.resolve()
dest.parent.mkdir(parents=True,exist_ok=True)
data=(ROOT/'docs/edo-new-design/viewer-data.json').read_bytes()
source=(Path(__file__).parent/'viewer.template.html').read_text()
fragment=source.replace('__MODEL_GZIP__',base64.b64encode(gzip.compress(data,mtime=0)).decode())
assert len(fragment.encode())<1_000_000
dest.write_text(fragment)
print(dest,len(fragment.encode()),'bytes')
