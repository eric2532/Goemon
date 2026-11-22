"""Rectify the original western-town paint for the existing solid scenery builders."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image
from build_village_building_surfaces import surface_atlas
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/original_crossgate'
PATCHES={
 'plaster':(11400,[(65,183),(71,187),(71,197),(65,193)],False,(64,64)),
 'woodwall':(11413,[(133,264),(155,264),(155,280),(133,280)],False,(64,64)),
 'timber':(11413,[(133,264),(155,264),(155,280),(133,280)],False,(64,64)),
 'trim':(11413,[(138,316),(155,316),(155,319),(138,319)],False,(64,64)),
 'stone':(11413,[(145,330),(161,327),(161,340),(145,343)],False,(64,64)),
 'snowroof':(11411,[(155,65),(171,65),(171,79),(155,79)],False,(96,64)),
 'orange_roof':(11400,[(78,91),(119,118),(157,91),(115,65)],False,(96,64)),
 'green_roof':(11403,[(135,100),(171,126),(207,99),(172,74)],False,(96,64)),
 'blue_roof':(11409,[(78,91),(119,118),(157,91),(115,65)],False,(96,64)),
 'brown_roof':(11416,[(135,100),(171,126),(207,99),(172,74)],False,(96,64)),
 'thatch':(11451,[(130,85),(162,85),(162,117),(130,117)],False,(64,64)),
 'plankroof':(11083,[(205,190),(235,209),(258,184),(228,165)],False,(96,64)),
 'window':(11400,[(202,230),(225,214),(225,250),(202,266)],True,(48,76)),
 'door':(11400,[(96,213),(125,234),(125,302),(96,281)],True,(48,104)),
 'round_door':(11408,[(276,318),(308,296),(308,365),(276,387)],True,(48,104)),
 'round_window':(11413,[(114,211),(168,211),(168,241),(114,241)],True,(96,52)),
 'tina_trim':(11409,[(174,252),(179,248),(179,307),(174,311)],False,(32,96)),
 'tina_pub_door':(11416,[(84,169),(119,192),(119,268),(84,245)],True,(48,104)),
 'tina_pub_window':(11416,[(271,209),(290,196),(290,235),(271,248)],True,(48,76)),
 'tina_pub_sign':(11416,[(158,239),(189,259),(189,278),(158,258)],True,(72,55)),
 'jenova_11400_left':(11400,[(28,170),(144,250),(144,331),(28,251)],True,(112,112)),
 'jenova_11400_right':(11400,[(145,253),(293,151),(293,239),(145,341)],True,(112,112)),
 'jenova_11403_left':(11403,[(61,147),(203,245),(203,375),(61,277)],True,(112,112)),
 'jenova_11403_right':(11403,[(208,242),(345,148),(345,277),(208,371)],True,(112,112)),
 'jenova_11404_right':(11404,[(305,271),(435,182),(435,351),(305,441)],True,(112,112)),
 'jenova_11404_left':(11404,[(84,150),(126,179),(126,306),(84,277)],True,(112,112)),
 'jenova_11405_left':(11405,[(34,165),(174,261),(174,407),(34,311)],True,(112,112)),
 'jenova_11405_right':(11405,[(174,263),(329,156),(329,304),(174,411)],True,(112,112)),
 'jenova_round_window':(11402,[(111,239),(154,246),(154,278),(111,271)],True,(76,56)),
 'jenova_round_door':(11402,[(27,276),(74,306),(74,410),(27,379)],True,(48,104)),
 'jenova_11405_banner':(11405,[(183,228),(202,240),(202,284),(183,272)],True,(40,92)),
 'jenova_11405_sign':(11405,[(250,217),(275,200),(275,243),(250,260)],True,(48,76)),
 'jenova_trim':(11400,[(156,323),(162,319),(162,343),(156,347)],False,(32,64)),
 'jenova_well_wood':(11393,[(73,119),(78,119),(78,140),(73,140)],False,(32,96)),
 'tina_11409_left':(11409,[(26,153),(147,236),(147,332),(26,249)],True,(112,112)),
 'tina_11409_right':(11409,[(147,236),(291,138),(291,235),(147,332)],True,(112,112)),
 'tina_11410_left':(11410,[(25,145),(145,230),(145,340),(25,255)],True,(112,112)),
 'tina_11410_right':(11410,[(147,230),(285,137),(285,247),(147,340)],True,(112,112)),
 'tina_11416_left':(11416,[(69,151),(197,239),(197,330),(69,242)],True,(112,112)),
 'tina_11416_right':(11416,[(200,240),(333,149),(333,240),(200,331)],True,(112,112)),
 'tina_11411_left':(11411,[(23,140),(154,234),(154,318),(23,224)],True,(112,112)),
 'tina_11411_right':(11411,[(157,234),(294,141),(294,223),(157,316)],True,(112,112)),
 'tina_11412_left':(11412,[(40,160),(169,244),(169,334),(40,250)],True,(112,112)),
 'tina_11412_right':(11412,[(173,241),(306,149),(306,238),(173,333)],True,(112,112)),
 'tina_11415_left':(11415,[(89,154),(217,242),(217,333),(89,245)],True,(112,112)),
 'tina_11415_right':(11415,[(220,243),(353,152),(353,243),(220,334)],True,(112,112)),
 'tina_round_window':(11414,[(117,207),(176,207),(176,232),(117,232)],True,(96,52)),
 'tina_round_door':(11414,[(43,220),(80,242),(80,315),(43,294)],True,(48,104)),
 'tina_wood':(11414,[(119,255),(146,255),(146,290),(119,290)],False,(64,64)),
 'tina_green_bay_roof':(11407,[(197,172),(247,172),(247,215),(197,215)],False,(64,64)),
 'tina_shelter_roof':(11451,[(57,32),(273,174),(217,257),(5,112)],True,(112,112)),
 'tina_steps':(11414,[(37,324),(51,333),(46,340),(32,331)],False,(64,64)),
 'tina_11403_left':(11403,[(65,148),(201,240),(201,326),(65,234)],True,(112,112)),
 'tina_11403_right':(11403,[(204,240),(340,147),(340,235),(204,328)],True,(112,112)),
 'tina_fence_wood':(11363,[(17,5),(19,5),(19,17),(17,17)],False,(32,64)),
 'tina_fence_rope':(11363,[(14,20),(16,20),(16,21),(14,21)],False,(32,32)),
 'tina_log_bark':(11462,[(22,37),(36,45),(34,49),(20,41)],False,(48,48)),
 'tina_log_end':(11462,[(31,66),(36,62),(43,69),(38,74)],False,(48,48)),
 'tina_crate_trim':(11468,[(7,42),(10,44),(10,65),(7,63)],False,(32,64)),
 'tina_boat_red':(11501,[(242,304),(246,299),(255,304),(251,309)],False,(48,48)),
 'tina_boat_blue':(11501,[(119,190),(121,190),(121,192),(119,192)],False,(32,32)),
 'tina_boat_green':(11500,[(147,213),(149,213),(149,215),(147,215)],False,(32,32)),
 'tina_boat_white':(11500,[(263,307),(269,311),(267,315),(261,311)],False,(48,48)),
 'tina_boat_cask':(11500,[(181,267),(185,261),(196,266),(192,272)],False,(48,48)),
 'tina_sign_bark':(11499,[(16,62),(18,62),(18,67),(16,67)],False,(32,64)),
 'tina_ruin_stone':(11338,[(27,46),(36,46),(36,62),(27,62)],False,(48,64)),
 'tina_barrel_brown':(10017,[(18,27),(24,27),(24,32),(18,32)],False,(48,48)),
 'tina_barrel_red':(10033,[(27,69),(33,69),(33,77),(27,77)],False,(48,48)),
 'tina_barrel_green':(10033,[(12,100),(20,100),(20,110),(12,110)],False,(48,48)),
 'tina_box_plank':(10055,[(7,31),(11,34),(11,39),(7,36)],False,(48,48)),
 'tina_box_inner':(10055,[(21,21),(25,23),(25,27),(21,25)],False,(48,48)),
 'tina_barrel_hoop':(10017,[(30,26),(32,26),(32,27),(30,27)],False,(32,32)),
 'tina_hollow_bark':(11482,[(20,23),(25,23),(25,28),(20,28)],False,(48,48)),
 'tina_wash_wood':(11464,[(18,48),(25,51),(25,60),(18,57)],False,(48,48)),
 'tina_pail_wood':(11481,[(11,22),(18,25),(18,32),(11,29)],False,(48,48)),
 'tina_wash_water':(11464,[(37,25),(54,34),(39,47),(27,39)],False,(48,48)),
 'tina_soft_snow':(11465,[(24,45),(31,45),(31,52),(24,52)],False,(48,48)),
 'tina_mitten_red':(11465,[(6,3),(8,3),(8,5),(6,5)],False,(48,48)),
 'tina_snowman_mouth':(11465,[(24,25),(27,25),(27,27),(24,27)],False,(32,32)),
 'tina_stack_end_green':(11460,[(91,42),(96,39),(100,44),(95,47)],False,(48,48)),
 'tina_camp_ash':(11484,[(21,14),(24,14),(24,17),(21,17)],False,(32,32)),
 'tina_camp_charcoal':(11484,[(24,7),(27,7),(27,10),(24,10)],False,(32,32)),
 'tina_snow_bay_window':(11408,[(45,230),(73,249),(73,285),(45,266)],True,(48,76)),
 'tina_11407_left':(11407,[(81,157),(211,247),(211,364),(81,274)],True,(112,112)),
 'tina_11407_right':(11407,[(300,296),(435,203),(435,319),(300,413)],True,(112,112)),
 'tina_11408_left':(11408,[(28,214),(133,287),(133,383),(28,310)],True,(112,112)),
 'tina_11408_right':(11408,[(246,255),(378,163),(378,259),(246,351)],True,(112,112)),
 'tina_bay_fence':(11408,[(433,302),(437,300),(437,316),(433,318)],False,(32,64)),
 'tina_ruin_snow':(11338,[(27,7),(32,7),(32,13),(27,13)],False,(48,48)),
 'tina_blue_porch':(11409,[(109,301),(113,304),(113,324),(109,321)],False,(32,96)),
}

def prepare():
 sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
 import cg_library as library
 lookup=library.serial_index();images={};provenance={}
 for serial in {v[0] for v in PATCHES.values()}:
  source=lookup[serial];image=library.image_from_record(source['pack'],source['row'])
  images[serial]=image
  provenance[serial]={'pack':source['pack'],'row':source['row'],'rgba_sha256':hashlib.sha256(image.tobytes()).hexdigest()}
 atlas,lines=surface_atlas(images,PATCHES)
 lines[1]='## Generated by tools/recover_western_building_surfaces.py; original Blue CG paint.'
 return atlas,'\n'.join(lines+['}'])+'\n',{'graphics':provenance,'patches':PATCHES}

def well_paint():
 catalog=json.loads((OUT/'catalog.json').read_text());g=catalog['graphics']['11393'];x,y,w,h=g['rect']
 original=Image.open(OUT/catalog['pages'][g['page']]).convert('RGBA').crop((x,y,x+w,y+h))
 assert hashlib.sha256(original.tobytes()).hexdigest()==g['rgba_sha256']
 def timber(pixel):return pixel[3]>0 and pixel[0]>40 and pixel[0]>pixel[1]*1.35 and pixel[0]>pixel[2]*1.5
 mask={(x,y) for y in range(105,167) for x in range(21,112) if timber(original.getpixel((x,y)))}
 image=original.copy()
 for x,y in sorted(mask):
  candidates=[u for u in range(21,112) if (u,y) not in mask and original.getpixel((u,y))[3]>200]
  assert candidates,'Well timber must have adjacent visible stone or interior paint'
  u=min(candidates,key=lambda u:abs(u-x));color=original.getpixel((u,y))
  image.putpixel((x,y),color[:3]+(original.getpixel((x,y))[3],))
 return image,{'source_graphic':11393,'source_rgba_sha256':g['rgba_sha256'],'reconstructed_pixels':len(mask),'method':'Occluding timber inside the stone region is replaced by nearest unobscured paint on the same row; original sprite and alpha are preserved.','output_rgba_sha256':hashlib.sha256(image.tobytes()).hexdigest()}

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 atlas,code,provenance=prepare();stone,stone_proof=well_paint()
 if args.check:
  assert Image.open(OUT/'building-surfaces.png').tobytes()==atlas.tobytes()
  assert (OUT/'building-surfaces.gd').read_text()==code
  assert json.loads((OUT/'building-surfaces.json').read_text())==json.loads(json.dumps(provenance))
  assert Image.open(OUT/'jenova-well-stone.png').convert('RGBA').tobytes()==stone.tobytes()
  assert json.loads((OUT/'jenova-well-stone.json').read_text())==stone_proof
  print('PASS: native western building surfaces, feature crops and original graphic hashes')
 else:
  atlas.save(OUT/'building-surfaces.png')
  (OUT/'building-surfaces.gd').write_text(code)
  (OUT/'building-surfaces.json').write_text(json.dumps(provenance,indent=2)+'\n')
  stone.save(OUT/'jenova-well-stone.png');(OUT/'jenova-well-stone.json').write_text(json.dumps(stone_proof,indent=2)+'\n')
  print('Prepared',len(PATCHES),'original western building surfaces')
if __name__=='__main__':main()
