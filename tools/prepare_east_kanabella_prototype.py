"""Private gold Kanabella cottage: traced source ownership and measured kit parts."""
import hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/maps/falan/east_region/kanabella_bg'
TOKEN='d6756ad06048f136'
# Separate component paint before giving the roof, chimney and attic real depth.
# These are observed source outlines; unseen thickness/back faces remain inferred.
OUTLINE=[[151,0],[164,0],[174,23],[205,30],[217,25],[229,35],[236,66],[239,95],[254,115],[257,139],[282,148],[285,170],[309,177],[306,196],[327,215],[365,242],[372,254],[366,258],[344,250],[338,266],[320,277],[309,306],[303,328],[288,338],[278,351],[250,368],[220,369],[206,375],[185,389],[174,397],[146,378],[119,359],[101,364],[81,363],[61,343],[59,319],[57,305],[55,270],[51,245],[40,230],[38,216],[46,205],[72,195],[78,173],[94,159],[105,123],[105,105],[126,86],[133,65],[138,39]]
PARTS={
 'window':[[106,120],[118,109],[149,128],[161,140],[161,180],[150,190],[117,171],[106,155]],
 'chimney':[[201,38],[214,34],[224,46],[225,81],[232,95],[227,117],[226,136],[240,139],[243,157],[237,174],[233,181],[240,199],[239,220],[232,234],[219,243],[201,242],[188,231],[190,211],[183,197],[189,178],[194,165],[187,150],[190,132],[199,115],[201,85]],
 'dormer':[[156,0],[176,25],[211,32],[223,29],[231,43],[233,65],[226,84],[211,100],[188,104],[175,121],[167,140],[149,159],[136,158],[119,145],[105,121],[107,98],[124,81],[134,57],[145,35]],
 'left_curl':[[42,195],[65,177],[84,177],[107,191],[111,214],[94,233],[76,235],[72,217],[59,209],[47,210],[44,227],[39,225],[37,211]],
 'front_curl':[[149,258],[165,243],[180,243],[197,254],[214,274],[234,287],[255,291],[274,306],[302,326],[301,339],[287,340],[277,329],[259,315],[245,310],[234,302],[216,306],[197,300],[185,286],[165,277],[153,278],[146,281],[139,277],[139,268]],
 'right_curl':[[274,204],[289,202],[308,211],[325,223],[344,236],[363,242],[371,253],[366,258],[355,252],[344,250],[335,256],[329,271],[319,280],[310,278],[310,265],[298,252],[289,242]],
 'roof':[[42,190],[97,166],[157,181],[169,202],[177,210],[207,207],[235,198],[258,192],[292,201],[318,219],[366,246],[367,256],[345,249],[330,259],[321,275],[303,286],[308,310],[301,332],[287,339],[275,329],[251,307],[238,302],[229,287],[202,290],[180,278],[153,262],[131,246],[108,243],[76,235],[44,226]],
 'stairs':[[83,319],[120,324],[134,345],[111,379],[82,364],[73,346]],
}
def sha(raw):return hashlib.sha256(raw).hexdigest()
def prepare():
    data=json.loads((OUT/'data.json').read_text());row=data['models'][TOKEN];source=Image.open(OUT/f'{TOKEN}-native.png').convert('RGBA');assert sha(source.tobytes())==row['native_rgba_sha256']
    outline=Image.new('1',source.size);ImageDraw.Draw(outline).polygon(OUTLINE,fill=1)
    masks={}
    for name,polygon in PARTS.items():
        mask=Image.new('1',source.size);ImageDraw.Draw(mask).polygon(polygon,fill=1);masks[name]=mask
    names=list(PARTS)+['walls','ground'];images={name:source.copy() for name in names}
    # The exact63-cell source variant omits20577, whose inspected native drawing
    # is only grass. This evidence separates that patch without color-keying roofs.
    variant=Image.open(OUT/'fa6f08d5457886a8-native.png').convert('RGBA')
    for yy in range(source.height):
        for xx in range(source.width):
            pixel=source.getpixel((xx,yy));owner='ground'
            plain_grass=pixel!=variant.getpixel((xx,yy)) and variant.getpixel((xx,yy))[3]==0
            if outline.getpixel((xx,yy)) and not plain_grass:owner=next((name for name in PARTS if masks[name].getpixel((xx,yy))),'walls')
            for name in names:images[name].putpixel((xx,yy),(*pixel[:3],pixel[3] if name==owner else 0))
    # Rear material is an independent small sample from an existing reusable
    # ceramic/timber/plaster atlas, never a replay of the complete source facade.
    atlas=Image.open(ROOT/'assets/maps/falan/east_region/landmarks/surfaces.png').convert('RGBA')
    patch=source.crop((172,262,204,294))
    for name,path,box,tone in [('roof','assets/textures/edo/tile.png',(384,0),(181,126,53)),('plaster','assets/textures/edo/plaster.png',(0,0),(229,228,210))]:
        master=Image.open(ROOT/path).convert('RGB').resize((128,128));levels=[sum(pixel)/3 for pixel in master.getdata()];mean=sum(levels)/len(levels);tile=Image.new('RGBA',(128,128));tile.putdata([(*(min(255,round(c*(.88+.12*v/mean)))for c in tone),255)for v in levels]);atlas.paste(tile,box)
    atlas.save(OUT/f'{TOKEN}-surfaces.png')
    tiles={'window':(384,128),'left_curl':(384,0),'front_curl':(384,0),'right_curl':(384,0)}
    for name,at in tiles.items():
        tile=atlas.crop((at[0],at[1],at[0]+128,at[1]+128));back=images[name].copy()
        for yy in range(source.height):
            for xx in range(source.width):
                pixel=back.getpixel((xx,yy));back.putpixel((xx,yy),(*tile.getpixel((xx%128,yy%128))[:3],pixel[3]))
        back.save(OUT/f'{TOKEN}-{name}-back.png')
    # A source-traced closed attic volume replaces the rejected generic tall
    # gable. Its whole outline is covered at the rear, including front occlusions.
    attic_mask=Image.new('1',source.size);ImageDraw.Draw(attic_mask).polygon(PARTS['dormer'],fill=1)
    attic_back=Image.new('RGBA',source.size);plaster=atlas.crop((0,0,128,128));ceramic=atlas.crop((384,0,512,128))
    for yy in range(source.height):
        for xx in range(source.width):
            tile=ceramic if yy<105 else plaster
            if attic_mask.getpixel((xx,yy)):attic_back.putpixel((xx,yy),(*tile.getpixel((xx%128,yy%128))[:3],255))
    attic_back.save(OUT/f'{TOKEN}-dormer-back.png')
    for name,image in images.items():image.save(OUT/f'{TOKEN}-{name}.png')
    spec=dict(model=TOKEN,native_origin=row['native_origin'],native_size=row['native_size'],source_rgba_sha256=row['native_rgba_sha256'],source_outline=OUTLINE,component_polygons=PARTS,
        main=dict(feet=[[66,315],[179,394],[300,325]],eaves=[[40,190],[191,293],[350,243]],apex=[214,136],wall_pixels=110,wall='plaster',base_material='plaster',back_upper_material='plaster',roof='roof_gold',trim='roof_gold',cap=False),
        dormer=dict(feet=[[109,188],[156,216],[201,187]],eaves=[[101,114],[154,142],[210,113]],ridge=[[154,8],[237,51]],ridge_axis=0,wall_pixels=74,wall='plaster',base_material='plaster',back_upper_material='plaster',roof='roof_gold',cap=False,roof_anchor=[156,216]),
        chimney=dict(base=[214,242],height_pixels=204,diameter=58,material='plaster',profile=[[0,1.],[.06,1.10],[.12,.84],[.2,.82],[.25,.96],[.30,.78],[.36,.88],[.44,.70],[.5,.67],[.58,.56],[.67,.63],[.73,.45],[.83,.42],[.9,.46],[1,.20]],ring_materials=['roof_gold','roof_gold','plaster','roof_gold','roof_gold','plaster','roof_gold','plaster','plaster','roof_gold','roof_gold','plaster','roof_gold','roof_gold','roof_gold']),
        stairs=dict(near=[[78,354],[107,375]],far=[[90,322],[125,343]],height_pixels=30,steps=7,support=True),
        reliefs=[dict(part='window',slope=-.75,anchor=[133,190],depth=1.15,material='timber'),dict(part='left_curl',slope=0,anchor=[81,213],depth=1.25,material='roof_gold'),dict(part='front_curl',slope=0,anchor=[214,279],depth=1.25,material='roof_gold'),dict(part='right_curl',slope=0,anchor=[310,246],depth=1.25,material='roof_gold')],
        derivatives={name:sha(image.tobytes()) for name,image in images.items()},
        material_files=[f'{TOKEN}-surfaces.png',f'{TOKEN}-dormer-back.png']+[f'{TOKEN}-{name}-back.png' for name in tiles],
        observed_material_patch=dict(source_box=[172,262,204,294],source_rgba_sha256=sha(patch.tobytes()),private_atlas_tile=[384,0],inference='Hidden roof/plaster reuse existing Edo tile/plaster grain with native warm ceramic/pale wall tones. The former shaded front patch is not repeated. Shared atlas remains untouched.'),
        plain_grass_exclusion=dict(native_graphic=20577,relative_cell=[7,7],evidence='Exact source variant differs only by this inspected grass drawing; keep it as ground even inside the coarse architecture outline.'),
        inference='Native drawing cells, image origins, visible doors/windows, roof/eave silhouettes and source paint are preserved. Main curved roof, round corner plaster supports, gabled attic, stack and seven tread parts reuse existing kits. Component depth, hidden plaster/ceramic continuation and rear window rhythm are inferred. No collision, route, map cell or event is changed. Private prototype, not visual acceptance.')
    (OUT/'prototype.json').write_text(json.dumps(spec,indent=2)+'\n');print('KANABELLA_GOLD_COMPONENTS',len(images),'source RGBA partition exact')
if __name__=='__main__':prepare()
