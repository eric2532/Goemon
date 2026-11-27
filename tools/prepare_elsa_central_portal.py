"""Stage one joined59530 arch and its original two supporting posts."""
import json
from PIL import Image,ImageDraw,ImageChops
import recover_elsa_island as source
import prepare_elsa_central_assembly as central
from prepare_elsa_gate import native_layers
from prepare_elsa_props import nearest_material_paint
from prepare_elsa_inner_hall import portal_edges
from prepare_elsa_hall_entry_floor import pack

OUT=central.OUT/'Portal'
RECT=(5888,-1088,6656,384)
# The native profile spans foreground and background. These role cuts are
# inferred boundaries; source alpha clips them and native RGB is never repainted.
BG_ARCH=[(235,430),(237,354),(245,291),(259,244),(280,211),(306,187),
         (334,178),(360,183),(383,196),(421,204),(383,229),(350,274),
         (347,286),(346,305),(341,333),(337,360),(335,386),
         (335,399),(323,412),(306,421),(285,429),(260,444)]
LEFT=[(202,218),(230,218),(256,237),(256,313),(249,328),(260,344),
      (258,402),(250,413),(259,425),(256,480),(250,492),(256,502),
      (255,805),(246,825),(244,839),(229,846),(204,846),(181,829),
      (181,502),(188,486),(182,469),(182,431),(175,415),(177,350),
      (183,328),(183,239)]


def select(original,points):
    mask=Image.new('L',original.size);ImageDraw.Draw(mask).polygon(points,fill=255)
    for y in range(original.height):
        for x in range(original.width):
            color=original.getpixel((x,y))
            if not color[3] or max(color[:3])<=3:mask.putpixel((x,y),0)
    return mask


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    props=json.loads((central.PROPS/'data.json').read_text())
    foreground,background=native_layers(props['maps']['59530'],RECT,59530)
    native=Image.alpha_composite(background,foreground)
    left=select(background,LEFT)
    bg_arch=select(background,BG_ARCH)
    fg_arch=Image.new('L',native.size)
    fg_arch.paste(Image.open(central.OUT/'right-half-arch-mask.png').convert('L'),
                  (central.ORIGIN[0]-RECT[0],central.ORIGIN[1]-RECT[1]))
    # The right post is independently mapped across414/422. Keep it ahead of
    # the arch at their original occlusion; do not paint cap fragments on the arch.
    right_local=Image.open(central.OUT/'right-post-mask.png').convert('L')
    right=Image.new('L',native.size)
    right.paste(right_local,(central.ORIGIN[0]-RECT[0],central.ORIGIN[1]-RECT[1]))
    fg_arch=ImageChops.subtract(fg_arch,right)
    arch=ImageChops.lighter(bg_arch,fg_arch)
    left=ImageChops.subtract(left,arch)
    observed=ImageChops.lighter(bg_arch,left)
    bg_mask=ImageChops.multiply(observed,background.getchannel('A'))
    fg_mask=ImageChops.multiply(ImageChops.lighter(fg_arch,right),foreground.getchannel('A'))
    coping_probes=[]
    for u,v in [(404,342),(420,330),(436,318),(452,306),(468,294),(484,282),(500,270)]:
        assert bg_mask.getpixel((u,v))==0
        coping_probes.append(dict(native=[RECT[0]+u,RECT[1]+v],rgba=list(background.getpixel((u,v)))))
    bg_mask.save(OUT/'bg-photo-mask.png');fg_mask.save(OUT/'fg-photo-mask.png')
    native.save(OUT/'native.png');background.save(OUT/'native-background.png')
    foreground.save(OUT/'native-foreground.png')
    columns=[]
    for name,mask,original in [('left-bg-post',left,background),('right-post',right,native)]:
        art=original.copy();art.putalpha(ImageChops.multiply(original.getchannel('A'),mask))
        bounds=art.getbbox();crop=art.crop(bounds)
        crop.save(OUT/(name+'-source.png'))
        nearest_material_paint(crop).save(OUT/(name+'-paint.png'))
        if name=='right-post':
            shape=central.POSTS[name]
            foot=[central.ORIGIN[i]+shape['foot'][i]-RECT[i] for i in [0,1]]
            cap=[central.ORIGIN[i]+shape['cap'][i]-RECT[i] for i in [0,1]]
            profile=[[x+central.ORIGIN[0]-RECT[0],y+central.ORIGIN[1]-RECT[1],w] for x,y,w in shape['profile']]
        else:
            foot=[220,842];cap=[220,250]
            profile=[[220,y,w] for y,w in [(842,66),(831,78),(815,66),(502,66),
                (489,80),(477,70),(435,70),(422,84),(407,70),(349,70),
                (336,82),(322,66),(253,79),(237,84),(218,60)]]
        cap=[cap[i]-bounds[i] for i in [0,1]]
        assert crop.getpixel(tuple(cap))[3],(name,cap)
        columns.append(dict(name=name,origin=[RECT[i]+bounds[i] for i in [0,1]],size=list(crop.size),crop=list(bounds),
            paint=name+'-paint.png',source=name+'-source.png',
            shape=dict(foot=[foot[i]-bounds[i] for i in [0,1]],
                       profile=[[x-bounds[0],y-bounds[1],w] for x,y,w in profile],
                       native_faces=True,sides=8,cap_paint_pixel=cap),
            inferred='Source cap/collars/shaft guide the profile; hidden continuation and octagonal depth are inferred.'))
    art=background.copy();art.putalpha(ImageChops.multiply(background.getchannel('A'),bg_arch))
    front=foreground.copy();front.putalpha(ImageChops.multiply(foreground.getchannel('A'),fg_arch))
    art.alpha_composite(front)
    bounds=art.getbbox();crop=art.crop(bounds)
    crop.save(OUT/'arch-source.png');nearest_material_paint(crop).save(OUT/'arch-solid.png')
    edges=portal_edges(crop)
    # Each contact lies within the supporting octagonal cap's native horizontal
    # radius. The line joins their original ground feet, rather than grounding
    # the arch's elevated leg photographs as if they were standing on the floor.
    contacts=[[6136,-246],[6445,-104]]
    slope=(contacts[1][1]-contacts[0][1])/(contacts[1][0]-contacts[0][0])
    footer=contacts[0][1]-slope*contacts[0][0]
    profile=dict(origin=[RECT[i]+bounds[i] for i in [0,1]],size=list(crop.size),crop=list(bounds),
                 paint='arch-source.png',solid='arch-solid.png',edges=edges,
                 foot=[slope,footer],depth=1.5,source_contacts=contacts,
                 inferred='Ground contact line follows the two measured post feet; selected arch contacts, unseen rear and 1.5m depth are inferred. Native front paint/projection is retained.')
    floor,distinct=pack(bg_mask,RECT,OUT,1024,clear_matte=False)
    floor.update(map=59530,candidate_only=True,native_rect=list(RECT),role_mask_file='bg-photo-mask.png',
                 source_mask_sha256=source.sha(bg_mask.tobytes()))
    (OUT/'floor-data.json').write_text(json.dumps(floor,separators=(',',':'))+'\n')
    review=native.copy()
    for mask,color in [(arch,(202,112,218)),(left,(230,170,65)),(right,(90,170,240))]:
        tint=Image.new('RGBA',native.size,(*color,0));tint.putalpha(mask.point(lambda v:85 if v else 0));review.alpha_composite(tint)
    review.save(OUT/'roles-review.png')
    data=dict(map=59530,candidate_only=True,rect=list(RECT),arch=profile,columns=columns,
              native_rgba_sha256=source.sha(native.tobytes()),
              bg_rgba_sha256=source.sha(background.tobytes()),fg_rgba_sha256=source.sha(foreground.tobytes()),
              bg_photo_pixels=sum(bool(v) for v in bg_mask.tobytes()),
              fg_photo_pixels=sum(bool(v) for v in fg_mask.tobytes()),
              excluded_background_coping=dict(probes=coping_probes,
                  interpretation='Inferred ownership from the continuous diagonal BG wall coping behind the opening. Keep its native pixels in the existing BG owner, not on the arch.'),
              limits=['All geometry is private and adds no collision or walking cells.',
                      'Left BG post, full joined arch and right FG post are one source assembly.',
                      'Background wall coping visible through the arch stays with the original BG placement; it is not an arch fragment.',
                      'Landings, rails, flights and the rest of the room remain separate unfinished work.'])
    (OUT/'data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('ELSA_CENTRAL_PORTAL_SOURCE',len(edges),'arch edges;',len(columns),'posts;',len(floor['placements']),'BG crops;',distinct,'distinct')


if __name__=='__main__':build()
