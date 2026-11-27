"""Stage private59530 BG UVs for the recovered stair mesh; preserve native RGB."""
import json
from pathlib import Path
from PIL import Image, ImageChops
import recover_elsa_island as source

OUT=source.REPORT/'Temple Interior/Hall Entry Candidate'
PAGE=2048
CANON=source.ROOT/'assets/maps/falan/elsa/scenery/entry-pedestals'
BG_STAIR=source.ROOT/'assets/maps/falan/elsa/scenery/temple-bg-stair'


def compose_canonical_floor(output=CANON,ground_folder=None):
    """One canonical BG derivative combines only published source families."""
    pedestal=json.loads((CANON/'data.json').read_text())
    regions=[('bg_pedestals',Image.open(CANON/'bg-pedestal-relocated-mask.png').convert('L'),pedestal['native_rect'])]
    if (BG_STAIR/'mesh.json').exists():
        stair=json.loads((BG_STAIR/'mesh.json').read_text());u,v=stair['native_origin'];w,h=stair['size']
        regions.append(('bg_stair',Image.open(BG_STAIR/'bg-photo-mask.png').convert('L'),[u,v,u+w,v+h]))
    ground_folder=ground_folder or BG_STAIR
    ground=None;ground_record=None
    if (ground_folder/'parent-ground.json').exists():
        ground_record=json.loads((ground_folder/'parent-ground.json').read_text())
        image=Image.open(ground_folder/'parent-ground.png').convert('RGBA');u,v=ground_record['origin']
        ground=(image,[u,v,u+image.width,v+image.height])
    bounds=[r[2] for r in regions]+([ground[1]] if ground else [])
    rect=[min(r[0] for r in bounds),min(r[1] for r in bounds),max(r[2] for r in bounds),max(r[3] for r in bounds)]
    mask=Image.new('L',(rect[2]-rect[0],rect[3]-rect[1]));metadata={}
    for name,part,bounds in regions:
        assert part.size==(bounds[2]-bounds[0],bounds[3]-bounds[1])
        overlay=Image.new('L',mask.size);overlay.paste(part,(bounds[0]-rect[0],bounds[1]-rect[1]));mask=ImageChops.lighter(mask,overlay)
        metadata[name]=dict(native_rect=bounds,mask_sha256=source.sha(part.tobytes()),selected_pixels=sum(bool(v) for v in part.tobytes()))
    output.mkdir(parents=True,exist_ok=True)
    filename='published-bg-photo-mask.png';mask.save(output/filename)
    record,distinct=pack(mask,rect,output,512,infill=ground)
    record.update(map=59530,native_rect=rect,role_mask_file=filename,source_mask_sha256=source.sha(mask.tobytes()),candidate_only=output!=CANON,pedestals_only=len(regions)==1,regions=metadata,
                  limits=['Only published BG pedestal/stair photographs relocate to their source-painted3D geometry.',
                          'Original BG RGB/alpha stay exact outside the explicit inferred parent-paving mask; CUT extents/origins and walking stay unchanged.',
                          'Unfinished private portal/wall/central FG masks are not publication inputs.'])
    if ground_record:record['ground_infill']=dict(native_rect=ground[1],pixels=ground_record['pixels'],rgba_sha256=ground_record['rgba_sha256'],source_rgba_sha256=ground_record['source_rgba_sha256'],stair_photo_mask_sha256=ground_record['stair_photo_mask_sha256'])
    target=output/'floor-data.json';temp=target.with_suffix('.tmp');temp.write_text(json.dumps(record,separators=(',',':'))+'\n');temp.replace(target)
    print('ELSA_CANONICAL_FLOOR' if output==CANON else 'ELSA_STAGED_FLOOR',list(metadata),len(record['placements']),'native crops;',distinct,'distinct;',record['pages'],'pages',flush=True)
    return record


def build(pedestals_only=False):
    data=json.loads((OUT/'data.json').read_text());rect=data['rect']
    output=CANON if pedestals_only else OUT;output.mkdir(exist_ok=True)
    page_size=512 if pedestals_only else PAGE
    mask=Image.open(OUT/('bg-pedestal-relocated-mask.png' if pedestals_only else 'displaced-floor-mask.png')).convert('L')
    role_file='displaced-floor-mask.png'
    if pedestals_only:
        role_file='bg-pedestal-relocated-mask.png';mask.save(output/role_file)
        compose_canonical_floor();return
    elif (OUT/'props-data.json').exists():
        prop_mask=Image.open(OUT/'bg-pedestal-relocated-mask.png').convert('L')
        assert prop_mask.size==mask.size
        mask=ImageChops.lighter(mask,prop_mask);role_file='relocated-photo-mask.png';mask.save(OUT/role_file)
    packed_record,distinct=pack(mask,rect,output,page_size,clear_matte=not pedestals_only)
    placements=packed_record["placements"];pages=packed_record["pages"]
    removed_matte=packed_record["removed_matte_pixels"];removed_stairs=packed_record["relocated_photo_pixels"]
    record=dict(map=59530,placements=placements,pages=pages,native_rect=rect,role_mask_file=role_file,source_mask_sha256=source.sha(mask.tobytes()),candidate_only=not pedestals_only,pedestals_only=pedestals_only,
                removed_matte_pixels=removed_matte,relocated_photo_pixels=removed_stairs,
                limits=['All source RGB, native extents/origins, placement indexes and walking data are unchanged. Only alpha changes.',
                        'Exact native (2,2,2) matte goes to background depth in the review scene; it is not new terrain.',
                        'Not published: actor/native/collision support and original entry contact must be completed before activation.'])
    if pedestals_only:record['limits']=['Only the confirmed BG pedestal photograph relocates to its shared3D model. Original stair photographs, matte, extents, walking data and all source RGB are unchanged.']
    target=output/'floor-data.json';temporary=target.with_suffix('.tmp');temporary.write_text(json.dumps(record,separators=(',',':'))+'\n');temporary.replace(target)
    print('ELSA_HALL_ENTRY_FLOOR',len(placements),'placements;',distinct,'distinct crops;',pages,'pages;',removed_stairs,'relocated photo pixels;',removed_matte,'matte alpha pixels; pedestals_only=',pedestals_only,flush=True)


def pack(mask,rect,output,page_size,clear_matte=False,infill=None):
    """Reuse original CUT UVs for scoped photos and explicit concealed paving."""
    width,height,planes=source.reference_map(59530)
    pages=[];page=Image.new('RGBA',(page_size,page_size));px=py=row_height=0
    placements={};cuts={};packed={};removed_matte=0;removed_stairs=0;filled_ground=0
    for index,serial in enumerate(planes[0]):
        if serial<1000:continue
        if serial not in cuts:cuts[serial]=source.cut_image(59530,serial)
        art,origin,record=cuts[serial]
        if record[4]==record[5]==0:continue
        u=(index%width+index//width)*32+origin[0];v=(index//width-index%width)*24+origin[1]
        role=mask.crop((u-rect[0],v-rect[1],u-rect[0]+art.width,v-rect[1]+art.height))
        patch=infill[0].crop((u-infill[1][0],v-infill[1][1],u-infill[1][0]+art.width,v-infill[1][1]+art.height)) if infill else None
        if not clear_matte and role.getbbox() is None and (patch is None or patch.getchannel('A').getbbox() is None):continue
        derivative=art.copy();pixels=derivative.load();changed=False;matte=stairs=ground_pixels=0
        for y in range(art.height):
            for x in range(art.width):
                r,g,b,a=pixels[x,y]
                if patch is not None and patch.getpixel((x,y))[3]:
                    pixels[x,y]=patch.getpixel((x,y));changed=True;ground_pixels+=1
                    if a and role.getpixel((x,y)):stairs+=1
                    continue
                if not a:continue
                if role.getpixel((x,y)):
                    pixels[x,y]=(r,g,b,0);changed=True;stairs+=1
                elif clear_matte and (r,g,b)==(2,2,2):
                    pixels[x,y]=(r,g,b,0);changed=True;matte+=1
        if not changed:continue
        difference=ImageChops.difference(art,derivative)
        if patch is not None:
            untouched=ImageChops.invert(patch.getchannel('A'))
            assert all(ImageChops.multiply(difference.getchannel(c),untouched).getbbox() is None for c in ['R','G','B'])
        else:assert all(difference.getchannel(c).getbbox() is None for c in ['R','G','B'])
        digest=source.sha(derivative.tobytes());key=(art.width,art.height,digest)
        if key not in packed:
            assert art.width+2<=page_size and art.height+2<=page_size
            if px+art.width+2>page_size:px=0;py+=row_height;row_height=0
            if py+art.height+2>page_size:
                pages.append(page);page=Image.new('RGBA',(page_size,page_size));px=py=row_height=0
            page.paste(derivative,(px+1,py+1));packed[key]=[len(pages),[px+1,py+1,art.width,art.height]]
            px+=art.width+2;row_height=max(row_height,art.height+2)
        atlas,r=packed[key]
        placements[str(index)]=dict(page=atlas,rect=r,serial=serial,origin=list(origin),source_sha256=source.sha(art.tobytes()),rgba_sha256=digest,
                                    matte_alpha_pixels=matte,relocated_photo_pixels=stairs,inferred_ground_pixels=ground_pixels)
        if infill is None:placements[str(index)]['relocated_photo_alpha_pixels']=stairs
        removed_matte+=matte;removed_stairs+=stairs;filled_ground+=ground_pixels
    if packed:pages.append(page)
    for i,image in enumerate(pages):image.save(output/f'floor-atlas-{i}.png')
    return dict(placements=placements,pages=len(pages),removed_matte_pixels=removed_matte,relocated_photo_pixels=removed_stairs,inferred_ground_pixels=filled_ground),len(packed)


if __name__=='__main__':build()
