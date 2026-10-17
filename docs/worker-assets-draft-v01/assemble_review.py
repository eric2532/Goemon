"""Lay out the actual Blender renders; never repaint or synthesize the asset."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,zipfile
OUT=Path(__file__).resolve().parent
FONT=Path('/System/Library/Fonts/Supplemental/Arial.ttf')
BOLD=Path('/System/Library/Fonts/Supplemental/Arial Bold.ttf')
def font(size,bold=False):return ImageFont.truetype(str(BOLD if bold else FONT),size)
canvas=Image.new('RGB',(2748,1300),'#efeee8')
d=ImageDraw.Draw(canvas)
d.text((1374,45),'WORKER  |  3D ASSET DRAFT',font=font(44,True),fill='#30362f',anchor='mm')
for i,view in enumerate(['front','side','back']):
    image=Image.open(OUT/'renders'/('worker-'+view+'.png')).convert('RGB')
    assert image.size==(900,1100)
    x=12+i*912
    canvas.paste(image,(x,95))
    d.text((x+450,1230),view.upper(),font=font(37,True),fill='#3c4139',anchor='mm')
d.text((1374,1280),'ANGRY EXPRESSION  /  NOT IMPLEMENTED IN GAME',font=font(23),fill='#63685e',anchor='mm')
canvas.save(OUT/'worker-front-side-back.png')
assert json.loads((OUT/'verification.json').read_text())['game_integration'] is False
with zipfile.ZipFile(OUT/'worker-assets-draft-v01.zip','w',zipfile.ZIP_DEFLATED) as bundle:
    for folder in ['source','export','textures','renders']:
        for path in sorted((OUT/folder).rglob('*')):
            if path.is_file() and path.suffix not in ['.blend1','.blend2']:
                bundle.write(path,Path('worker-assets-draft-v01')/path.relative_to(OUT))
    for name in ['.gdignore','README.txt','asset-report.json','verification.json','live-files-before.json','paint_worker.py','build_worker.py','verify_worker.py','assemble_review.py','worker-front-side-back.png','approved-worker-concept.png']:
        bundle.write(OUT/name,Path('worker-assets-draft-v01')/name)
print('WORKER_REVIEW_ASSEMBLED',OUT/'worker-front-side-back.png')
