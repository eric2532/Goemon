"""Measured native cap outlines and material samples for closed East wall parts."""
import math

from PIL import Image

VOID={(0,0,0),(20,20,20)}


def hull(points):
    points=sorted(set(points))
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    lower=[]
    for p in points:
        while len(lower)>=2 and cross(lower[-2],lower[-1],p)<=0:lower.pop()
        lower.append(p)
    upper=[]
    for p in reversed(points):
        while len(upper)>=2 and cross(upper[-2],upper[-1],p)<=0:upper.pop()
        upper.append(p)
    return lower[:-1]+upper[:-1]


def native_cap(image):
    points=[]
    for x in range(image.width):
        runs=[y for y in range(min(48,image.height)) if image.getpixel((x,y))[3] and image.getpixel((x,y))[:3] in VOID]
        if not runs:continue
        first=runs[0]
        # The tile cap is the first continuous black run, above the mirrored
        #48px cap boundary. Dark mortar below it must not enlarge the footprint.
        for y in range(first,min(image.height,48-first)):
            p=image.getpixel((x,y))
            if not p[3] or p[:3] not in VOID:break
            points.extend([(x,y),(x+1,y),(x+1,y+1),(x,y+1)])
    return hull(points)


def rectified_material(image,g,wood=False):
    """Rectify a whole compatible native face at its actual source pixel/world pitch."""
    from recover_falan_architecture import opaque_paint
    height=(-g['origin'][1]-24)*.045
    def pixel(x,y,z):return ((x+z)*(32/3)-g['origin'][0],(z-x)*8-y/.045-g['origin'][1])
    # These compatible1x1 wall masters have a3m native face. Rough cap paint
    # fragments must not turn its short bevel edges into the material scale.
    assert g['footprint']==[1,1]
    faces=[((-1.5,-1.5),(-1.5,1.5)),((-1.5,1.5),(1.5,1.5))]
    def observed(face):
        a,b=face;score=0
        for t in [.2,.35,.5,.65,.8]:
            for f in [.25,.4,.55,.7,.85]:
                px,py=pixel(a[0]+(b[0]-a[0])*t,height*f,a[1]+(b[1]-a[1])*t)
                if 0<=px<image.width and 0<=py<image.height:
                    color=image.getpixel((round(px),round(py)));score+=color[3]>128 and color[:3] not in VOID
        return score
    a,b=max(faces,key=observed)
    length=math.dist(a,b);along=((b[0]-a[0])/length,(b[1]-a[1])/length);mid=((a[0]+b[0])/2,(a[1]+b[1])/2)
    span=min(2.4,length*.75,height*.75)
    def patch(y,vertical):
        corners=[]
        for across,up in [(-.5,.5),(-.5,-.5),(.5,-.5),(.5,.5)]:
            corners.append(pixel(mid[0]+along[0]*span*across,y+vertical*up,mid[1]+along[1]*span*across))
        h=max(1,round(128*vertical/span));quad=tuple(v for point in corners for v in point)
        result=image.transform((128,h),Image.Transform.QUAD,quad,Image.Resampling.BICUBIC)
        result=opaque_paint(result);assert result.getchannel('A').getextrema()==(255,255)
        tile=Image.new('RGBA',(128,128))
        for y0 in range(0,128,h):tile.paste(result,(0,y0))
        # Reuse the approved ruin-material edge blend only on inferred backs.
        for axis in (0,1):
            original=tile.copy()
            for edge_along in range(128):
                for edge in range(8):
                    for side in (edge,127-edge):
                        p=(side,edge_along) if axis==0 else (edge_along,side);q=(127-side,edge_along) if axis==0 else (edge_along,127-side)
                        a=original.getpixel(p);b=original.getpixel(q);t=(8-edge)/16
                        tile.putpixel(p,tuple(round(a[k]*(1-t)+b[k]*t) for k in range(4)))
        return tile,[list(p) for p in corners]
    body,quad=patch(height*.52,span);trim,trim_quad=patch(.30,min(.24,span)) if wood else (body,quad)
    atlas=Image.new('RGBA',(384,128));atlas.paste(body,(0,0));atlas.paste(trim,(128,0));atlas.paste(body,(256,0))
    return atlas,{'native_face_pixels':quad,'native_trim_pixels':trim_quad,'world_pitch':span,'rectified_from_whole_face':True,'compatible_face_world_endpoints':[list(a),list(b)]}


def closed_wall(image,g,wood_trim=False):
    """The native top mask encodes a horizontal cap, not a painted black roof."""
    cap_cut=48;cap=native_cap(image)
    assert len(cap)>=3,('No measured native cap',g['origin'],image.size)
    height=(-g['origin'][1]-24)*.045
    assert height>.2
    front=image.copy()
    unseen_columns=set()
    for x in range(image.width):
        samples=[image.getpixel((x,y)) for y in range(48,image.height) if image.getpixel((x,y))[3]>128]
        if len(samples)>=min(16,image.height*.2) and sum(p[:3] in VOID for p in samples)>len(samples)*.95:unseen_columns.add(x)
    for y in range(front.height):
        for x in range(front.width):
            r,green,b,a=front.getpixel((x,y))
            if a and (r,green,b) in VOID and (x in unseen_columns or image.height<=64):front.putpixel((x,y),(r,green,b,0))
    observed=front.getbbox() is not None
    row={'cap_pixels':cap,'wall_height':round(height,6),'cap_only':image.height<=64,'wood_trim':wood_trim,
         'observed_face_available':observed,
         'cap_method':'First continuous native black cap run per column, clipped to the mirrored48px tile-cap band; dark body mortar is excluded. Height uses original sourceY and24px midpoint; no bbox grounding.'}
    # Native glass bounds locate the existing protruding frame; no passable window is created.
    blue=[]
    if observed and wood_trim:
        for y in range(cap_cut,min(front.height,math.floor(-g['origin'][1]))):
            for x in range(front.width):
                r,green,b,a=front.getpixel((x,y))
                if a and b>r*1.18 and green>r*1.12 and b>65:blue.append((x,y))
    if len(blue)>=12:
        row['window_pixels']=[max(0,min(x for x,y in blue)-3),max(cap_cut,min(y for x,y in blue)-3),min(front.width,max(x for x,y in blue)+4),min(front.height,max(y for x,y in blue)+4)]
        row['window_native_points']=hull(blue)
    return row,front
