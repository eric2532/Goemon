"""Check actual rendered skin and hair against authored display colours.

This catches scene grading washing out the palette even when the GLB is valid.
Use the front capture from capture_recovered_musashi.gd.
"""
import argparse,json
from pathlib import Path
from PIL import Image

parser=argparse.ArgumentParser()
parser.add_argument('image',type=Path)
args=parser.parse_args()
im=Image.open(args.image).convert('RGB')
pixels=list(im.getdata())
targets={'golden_skin':(255,198,123),'navy_hair':(37,39,91)}
report={name:sum(max(abs(a-b) for a,b in zip(pixel,target))<=3 for pixel in pixels)
        for name,target in targets.items()}
print(json.dumps(report))
assert all(n>100 for n in report.values()),'Rendered palette differs from authored colours: '+str(report)
