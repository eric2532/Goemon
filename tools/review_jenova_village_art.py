"""Package the three fixed-camera gameplay comparisons and the coverage sheets."""
import json
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/Other Files/Asset Toolkit/Jenova Village Art'

def main():
    before=json.loads((OUT/'Before/cameras.json').read_text())
    after=json.loads((OUT/'After/cameras.json').read_text())
    font_path='/System/Library/Fonts/Supplemental/Arial.ttf'
    font=ImageFont.truetype(font_path,30);small=ImageFont.truetype(font_path,22)
    audit=[];pairs=[]
    for i,(title,a,b) in enumerate(zip(['Entrance looking into town','Main street / round landmark','House street / green shop'],before[:3],after[:3]),1):
        numbers=lambda s:list(map(float,re.findall(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?',s.split('(',1)[1])))
        av,bv=numbers(a['camera']),numbers(b['camera']);delta=max(abs(x-y) for x,y in zip(av,bv))
        assert delta<1e-6 and a['cell']==b['cell'] and a['fov']==b['fov'] and a['player']==b['player']
        canvas=Image.new('RGB',(2880,980),'#242b2c');draw=ImageDraw.Draw(canvas)
        draw.text((24,12),f'{i}. {title}',font=font,fill='#f0e4c8')
        draw.text((24,50),'BEFORE',font=small,fill='white');draw.text((1464,50),'AFTER',font=small,fill='white')
        for x,phase in [(0,'Before'),(1440,'After')]:canvas.paste(Image.open(OUT/phase/(a['name']+'.png')).convert('RGB'),(x,80))
        filename=f'comparison-{i:02}.png';canvas.save(OUT/filename)
        pairs.append(canvas.resize((1440,490),Image.Resampling.LANCZOS))
        audit.append({'name':title,'comparison':filename,'cell':a['cell'],'maximum_camera_component_difference':delta,'fov':a['fov'],'resolution':[1440,900]})
    contact=Image.new('RGB',(1440,1470))
    for i,im in enumerate(pairs):contact.paste(im,(0,i*490))
    contact.save(OUT/'three-comparisons.jpg',quality=94)
    for pattern,name in [('sector-*.png','sector-survey.jpg'),('house-*.png','house-survey.jpg')]:
        files=sorted((OUT/'After').glob(pattern));sheet=Image.new('RGB',(1600,((len(files)+3)//4)*274),'#242b2c');draw=ImageDraw.Draw(sheet)
        for i,path in enumerate(files):
            sheet.paste(Image.open(path).resize((400,250)),(i%4*400,i//4*274+24));draw.text((i%4*400+8,i//4*274+3),path.stem,font=small,fill='white')
        sheet.save(OUT/name,quality=92)
    (OUT/'comparison-audit.json').write_text(json.dumps(audit,indent=2)+'\n')
    print('Three matched pairs, 16 reachable-sector captures and ten house views packaged')
if __name__=='__main__':main()
