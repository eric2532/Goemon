"""Measured living-tree axes; hidden depth and reverse root growth are inferred.

Coordinates stay in each original native graphic.  The visible cut rim is the same
painted form translated in 0039/0065 and reflected in 0063; 0065's left side is
partly hidden by its original leaves.  No map, collision, door or route is changed.
"""
import copy
import math

RIM_BACK=[(273,26),(283,12),(294,12),(301,5),(315,0),(329,3),(337,10),(346,9),(363,11),(369,20),(376,25),(379,34)]
RIM_FRONT=[(273,26),(281,35),(289,42),(297,43),(306,50),(315,51),(330,55),(344,51),(356,47),(367,43),(371,34),(379,34)]


def rim_offsets(center, transform=lambda x,y:(x,y)):
    back=sorted(transform(x,y) for x,y in RIM_BACK)
    front=sorted(transform(x,y) for x,y in RIM_FRONT)
    radius=107/(2*(32/3)*math.sqrt(2))
    def interpolate(x,points):
        for a,b in zip(points,points[1:]):
            if a[0]<=x<=b[0]:return a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0])
        return points[0][1] if x<points[0][0] else points[-1][1]
    result=[]
    for side in range(32):
        angle=side*math.tau/32
        x=center[0]+(math.cos(angle)+math.sin(angle))*radius*(32/3)
        y=center[1]+(math.sin(angle)-math.cos(angle))*radius*8
        result.append(round(y-interpolate(x,front if math.sin(angle)-math.cos(angle)>0 else back),2))
    return result


def stem(base,top,height,diameter,trace,*,cut=False,level=0,rim_transform=None):
    result=dict(base=base,top=top,height_pixels=height,level_pixels=level,diameter=diameter,
                trace=trace,cut_stump=cut,material='bark',tiled_front=True,
                profile=[[0,1.3],[.5,1],[1,.12]],
                inference='The native painted axis and house core determine placement. Hidden trunk depth, taper and root lobes are reconstructed around that axis.')
    if cut:
        result.update(stump_diameter=107,stump_height_pixels=107,
                      rim_offsets=rim_offsets(top,rim_transform or (lambda x,y:(x,y))),
                      rim_evidence='Observed native cut-rim outline; no randomized contour. The reverse circumference is inferred from its visible front and rim.')
    return result


SHAPES={
1230039:dict(crown_ground_source=[265.5],trunks=[
    stem([174,265.5],[158,31],234.5,55,
         [[174,265.5,1.30],[173,225,1.14],[168,181,1.02],[161,145,1.25],[158,112,1.52]],
         cut=True,rim_transform=lambda x,y:(x-168,y))]),
1230064:dict(crown_ground_source=[323,323],trunks=[
    stem([165,323],[172,80],243,55,
         [[165,323,1.30],[165,270,1.10],[166,220,1.],[167,165,.72],[170,120,.40],[172,80,.12]])]),
1230062:dict(crown_ground_source=[412,463,463],trunks=[
    stem([261,451],[326,31],432,55,
         [[261,451,1.30],[282,400,1.08],[304,349,1.02],[326,295,1.15],[330,241,1.02],[324,190,.94],[320,145,1.25],[326,112,1.52]],cut=True),
    stem([380,412],[451,88],324,33,
         [[380,412,1.30],[398,352,1.06],[421,288,.85],[439,225,.66],[448,162,.40],[451,88,.12]])]),
1230063:dict(crown_ground_source=[408.5,460,460],trunks=[
    stem([287,465.5],[232,31],429,55,
         [[287,465.5,1.30],[267,410,1.08],[246,350,1.02],[225,295,1.15],[222,240,1.02],[226,190,.94],[230,145,1.25],[232,112,1.52]],
         cut=True,rim_transform=lambda x,y:(558-x,y)),
    stem([174,408.5],[82,88],320.5,33,
         [[174,408.5,1.30],[153,350,1.06],[127,300,.85],[105,225,.66],[85,165,.40],[82,88,.12]])]),
1230065:dict(crown_ground_source=[368.5,460.5,460.5],trunks=[
    stem([187.5,368.5],[161,125],243.5,55,
         [[187.5,368.5,1.30],[182,320,1.12],[177,280,1.10],[166,245,1.28],[161,206,1.52]],
         cut=True,rim_transform=lambda x,y:(x-165,y+94)),
    stem([326,460.5],[282,227],233.5,55,
         [[326,460.5,1.30],[315,410,1.10],[301,355,1.],[291,300,.80],[284,260,.45],[282,227,.12]])]),
1230066:dict(crown_ground_source=[458.5,458.5,479,479],trunks=[
    stem([259,479],[297,77.5],381,55,
         [[259,479,1.30],[275,420,1.10],[295,350,1.02],[322,290,1.10],[336,245,.90],[332,200,.72],[318,150,.48],[300,100,.28],[297,77.5,.12]]),
    stem([383,399.5],[375,245],154.5,38,
         [[383,399.5,1.30],[383,350,1.04],[379,300,.70],[375,245,.12]])]),
1230040:dict(crown_ground_source=[648,619,619,648],trunks=[
    stem([136.5,648],[111,183],465,55,
         [[136.5,648,1.50],[125,580,1.20],[116,510,1.10],[112,440,1.05],[108,365,1.],[105,290,.80],[111,220,.40],[111,183,.12]]),
    stem([300.5,463.5],[279,303],160.5,55,
         [[300.5,463.5,1.40],[297,420,1.10],[289,380,1.],[284,340,.50],[279,303,.12]],level=133),
    stem([445,522],[362,32],490,55,
         [[445,522,1.30],[425,460,1.20],[404,390,1.10],[385,320,1.],[371,250,.80],[364,180,.65],[362,110,.35],[362,32,.12]],level=97)]),
}


def apply_living_shapes(compounds):
    for serial,shape in SHAPES.items():
        spec=compounds[serial]
        spec.update(copy.deepcopy(shape),living_tree=True)
        spec['inferred_living_back_material']='A separate native interior-wood grain patch continues unseen bark. Neutral dithering and cavity moss are filled from neighboring native brown colors; narrow grain repeats compensate the ownerY compression only in this inferred material; the original front and source textures remain unchanged.'
        spec['inferred_living_depth']='The source feet, roofs, cut-rim contour and branch pixels are measured. Unseen trunk depth, shared canopy plane, rear chamfer and root-covered infill continue the visible design; no extra room, door or route is created.'
        for house in spec['houses']:
            house.update(living_root_walls=True,base_material='living_bark',living_root_material='living_bark',trim='living_bark')
    # The upper shrine's right wall is only29.3% native paint; continue its
    # visible root ribs behind that sparse overlay instead of leaving plaster.
    compounds[1230040]['houses'][2].update(root_continuation_faces=[4],
        root_continuation_evidence='The measured upper/right face4 has29.3% source alpha coverage. Hidden bark/root continuation is inferred; its original sparse paint is retained, without another window or door.')
    # Four source-observed blue ceramic spires above the shrine's measured roofs.
    # Their opposite white bands and blue curved surfaces continue the native design.
    profile=[[0,.72],[.08,.85],[.12,1],[.17,.88],[.27,.57],[.42,.45],
             [.46,.60],[.50,.68],[.56,.47],[.72,.28],[.77,.38],[.83,.24],[1,0]]
    bands=['roof_blue','plaster','roof_blue','roof_blue','roof_blue','plaster',
           'roof_blue','roof_blue','roof_blue','plaster','roof_blue','roof_blue']
    compounds[1230040]['towers']=[dict(base=base,top=top,level_pixels=ground-base[1],
        height_pixels=base[1]-top[1],diameter=diameter,material='roof_blue',
        profile=copy.deepcopy(profile),ring_materials=bands[:],
        inference='Measured native blue ceramic spire. Its inferred attachment depth is the reconstructed curved roof intersected at the unchanged native base pixel. Unseen curved reverse and pale band rhythm continue its source-facing silhouette.')
        for base,top,ground,diameter in [([280,319],[276,192],581.625368,62),
            ([40,551],[31,476],636.115633,40),([472,416],[464,335],625.538459,43),
            ([118,592],[118,516],682.649765,40)]]
