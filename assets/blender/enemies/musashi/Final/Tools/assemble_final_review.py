from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import json, hashlib
p=Path(__file__).resolve().parents[1]/'Validation'
BG=(232,230,221,255); INK=(35,42,43); MUTED=(90,98,98)
H=1400; W=500; TOP=146; BOTTOM=70; GAP=28; MARGIN=40
font='/System/Library/Fonts/Supplemental/Arial.ttf'
bold='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
def ft(n,b=False): return ImageFont.truetype(bold if b else font,n)
def normalize(path):
 im=Image.open(path).convert('RGBA'); bbox=im.getchannel('A').point(lambda x:255 if x>128 else 0).getbbox()
 crop=im.crop(bbox); scale=H/crop.height; width=round(crop.width*scale)
 resized=crop.resize((width,H),Image.Resampling.LANCZOS)
 out=Image.new('RGBA',(W,H),(0,0,0,0)); x=(W-width)//2; out.alpha_composite(resized,(x,0))
 return out,{'source':str(path),'alpha_threshold':128,'source_bbox':bbox,'uniform_scale':scale,'normalized_height_px':H,'normalized_width_px':width,'canvas_x':x,'canvas_y':0}
def solid(im):
 o=Image.new('RGBA',im.size,(0,0,0,0));o.putalpha(im.getchannel('A'));return o
def flat(im):
 o=Image.new('RGBA',im.size,BG);o.alpha_composite(im);return o.convert('RGB')

def sheet(items,outname,subtitle):
 n=len(items); width=MARGIN*2+n*W+(n-1)*GAP
 out=Image.new('RGB',(width,TOP+H+BOTTOM),(246,245,240));d=ImageDraw.Draw(out)
 d.text((MARGIN,20),'MUSASHI / FINAL APPROVED CHARACTER',font=ft(25,True),fill=INK)
 d.text((MARGIN,55),subtitle,font=ft(18),fill=MUTED)
 for i,(title,sub,im) in enumerate(items):
  x=MARGIN+i*(W+GAP)
  d.text((x,91),title,font=ft(23,True),fill=INK)
  d.text((x,121),sub,font=ft(16),fill=MUTED)
  out.paste(im,(x,TOP))
  d.line((x,TOP+H,x+W,TOP+H),fill=(156,160,155),width=1)
 d.text((MARGIN,TOP+H+20),'Equal character height: 1400 px  |  Uniform scale, centered bounds, shared foot baseline  |  Design preserved; cleanup documented',font=ft(18),fill=MUTED)
 out.save(p/outname)

from PIL import ImageChops
ref,rm=normalize(p.parent/'Reference/Musashi_Original_Reference.png')
clean,bm=normalize(p/'previous_approved_full.png')
paint,pm=normalize(p/'final_full.png')
ref_flat=flat(ref);clean_flat=flat(clean);paint_flat=flat(paint);over=Image.blend(ref_flat,paint_flat,.5)
sheet([('01 ORIGINAL REFERENCE','Original supplied character artwork',ref_flat),('02 PREVIOUS APPROVED','Previous approved model / neutral studio',clean_flat),('03 FINAL APPROVED','MUSASHI_FINAL_APPROVED / neutral studio',paint_flat),('04 50% OVERLAY','Reference + final model, equal weight',over)],'00_final_comparison.png','Final painted art direction. Approved design and reference camera preserved; technical cleanup documented.')
for name,im in [('01_original_reference.png',ref_flat),('02_previous_approved.png',clean_flat),('03_final_approved.png',paint_flat),('04_reference_overlay.png',over)]:im.save(p/name)
a=Image.open(p/'previous_approved_full.png').getchannel('A');b=Image.open(p/'final_full.png').getchannel('A')
diff=ImageChops.difference(a,b)
alpha_identical=diff.getbbox() is None
print('ALPHA IDENTICAL:',alpha_identical)
report={'reference':rm,'clean':bm,'stylized':pm,'alignment':'Same whole-character normalization as prior review: alpha > 128 bounding box, uniform 1400 px character height, shared baseline, centered bounds. No warping.','same_lighting_clean_and_stylized':True,'alpha_identical':alpha_identical,'overlay':'50% original + 50% stylized over identical neutral background.'}
(p/'comparison_alignment.json').write_text(json.dumps(report,indent=2))
# Crop the exact same normalized coordinates for each comparison. Reference columns retain their authentic low resolution.
regions=[('05_face_closeup.png','FACE',(69,139,225,246)),('06_hair_closeup.png','HAIR',(12,0,248,186)),('07_jacket_vest_closeup.png','JACKET + VEST',(40,235,255,465)),('08_pants_closeup.png','PANTS',(23,445,205,671)),('09_shoes_closeup.png','SHOES + WRAPS',(0,607,216,800))]
for filename,title,box in regions:
 x0,y0,x1,y1=box
 cropbox=(round(26+x0*1.75),round(y0*1.75),round(26+x1*1.75),round(y1*1.75))
 cw=520;ch=round(cw*(y1-y0)/(x1-x0));margin=28;gap=20;top=105
 out=Image.new('RGB',(margin*2+cw*4+gap*3,top+ch+54),(246,245,240));d=ImageDraw.Draw(out)
 d.text((margin,16),'MUSASHI / '+title+' FINAL REVIEW',font=ft(26,True),fill=INK)
 for i,(label,im) in enumerate([('01 ORIGINAL',ref_flat),('02 PREVIOUS APPROVED',clean_flat),('03 FINAL APPROVED',paint_flat),('04 50% OVERLAY',over)]):
  x=margin+i*(cw+gap);d.text((x,66),label,font=ft(22,True),fill=INK)
  out.paste(im.crop(cropbox).resize((cw,ch),Image.Resampling.LANCZOS),(x,top))
 d.text((margin,top+ch+16),'Approved design and framing preserved. Final materials plus documented technical cleanup.',font=ft(18),fill=MUTED)
 out.save(p/filename)
print('Four-panel sheet and five material close-ups complete.')
