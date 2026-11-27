"""Measured native exterior masses for the later continental branches.

Hidden faces use separate material samples. Repeated variants share their visible
kit; these are scenery profiles and never create rooms, routes or collision.
"""
from copy import deepcopy


REGIONAL={
1233180:dict(blocks=[
 dict(feet=[[70,497],[323,667],[638,450]],height_pixels=130,material='temple_stone',window='temple_window'),
 dict(feet=[[125,348],[323,486],[576,317]],level_pixels=130,height_pixels=90,material='temple_stone',window='temple_window'),
 dict(feet=[[208,248],[350,342],[510,231]],level_pixels=220,height_pixels=95,material='temple_stone',window='temple_window'),
 ],towers=[
 dict(base=[354,248],level_pixels=315,height_pixels=198,diameter=198,material='temple_stone',sides=4,angle_offset=.785398,profile=[[0,1],[.35,.8],[.55,.65],[.78,.55],[1,0]]),
 dict(base=[323,684],height_pixels=306,diameter=125,material='temple_stone',sides=4,angle_offset=.785398,top=[371,378],profile=[[0,1],[.08,.84],[.7,.53],[1,.17]]),
 dict(base=[38,506],height_pixels=326,diameter=116,material='temple_stone',sides=4,angle_offset=.785398,top=[118,180],profile=[[0,1],[.08,.84],[.7,.53],[1,.17]]),
 dict(base=[640,483],height_pixels=304,diameter=117,material='temple_stone',sides=4,angle_offset=.785398,top=[597,179],profile=[[0,1],[.08,.84],[.7,.53],[1,.17]]),
 ],stairs=[dict(near=[[143,582],[181,608]],far=[[194,492],[231,517]],height_pixels=70,steps=12)],details=[[348,0,387,66],[98,164,134,213],[351,366,391,416],[581,167,610,208]]),
1230113:dict(blocks=[dict(feet=[[65,439],[254,565],[467,425]],height_pixels=101,material='sandstone'),dict(feet=[[158,305],[271,380],[379,305]],level_pixels=101,height_pixels=107,material='sandstone')],towers=[dict(base=[263,263],level_pixels=208,height_pixels=260,diameter=205,material='sandstone',sides=4,angle_offset=.785398,profile=[[0,1],[.15,.9],[.3,.84],[.4,.6],[.57,.58],[.62,.82],[.74,.82],[1,0]])],crowns=[[11,134,159,329],[328,155,516,363],[76,287,225,464],[315,307,466,472]],trunks=[dict(base=[135,481],top=[107,187],height_pixels=294,diameter=29,material='bark',tiled_front=True,recess=0,profile=[[0,1.6],[.25,.8],[.8,.58],[1,.18]]),dict(base=[393,468],top=[413,206],height_pixels=262,diameter=27,material='bark',tiled_front=True,recess=0,profile=[[0,1.6],[.25,.8],[.8,.58],[1,.18]])]),
1230114:dict(blocks=[dict(feet=[[28,371],[174,449],[319,358]],height_pixels=95,material='sandstone'),dict(feet=[[104,262],[204,328],[279,275]],level_pixels=95,height_pixels=113,material='sandstone')],towers=[dict(base=[203,219],level_pixels=208,height_pixels=213,diameter=177,material='sandstone',sides=4,angle_offset=.785398,profile=[[0,1],[.15,.9],[.3,.84],[.4,.6],[.57,.58],[.62,.82],[.74,.82],[1,0]])],crowns=[[220,195,350,375]],trunks=[dict(base=[287,392],top=[287,234],height_pixels=158,diameter=25,material='bark',tiled_front=True,recess=0,profile=[[0,1.4],[.2,.8],[.8,.48],[1,.15]])],details=[[104,128,215,337]]),
1233172:dict(houses=[dict(feet=[[92,443],[349,623],[591,447]],eaves=[[106,304],[350,467],[577,312]],apex=[335,174],wall_pixels=141,roof='roof_rust',wall='basalt',base_material='basalt',window='dark_palace_window',trim='basalt')],
 towers=[
 dict(base=[168,411],height_pixels=100,diameter=94,material='basalt',window='dark_palace_window',profile=[[0,1],[.1,1.02],[.95,.88],[1,.95]]),dict(base=[168,313],level_pixels=100,height_pixels=140,diameter=117,material='roof_rust',profile=[[0,.8],[.1,1],[.32,.93],[.68,.63],[.9,.38],[1,.05]]),
 dict(base=[350,620],height_pixels=174,diameter=98,material='basalt',window='dark_palace_window',profile=[[0,1],[.1,1.02],[.95,.88],[1,.95]]),dict(base=[350,448],level_pixels=174,height_pixels=139,diameter=119,material='roof_rust',profile=[[0,.8],[.1,1],[.32,.93],[.68,.63],[.9,.38],[1,.05]]),
 dict(base=[519,424],height_pixels=91,diameter=95,material='basalt',window='dark_palace_window',profile=[[0,1],[.1,1.02],[.95,.88],[1,.95]]),dict(base=[519,335],level_pixels=91,height_pixels=156,diameter=118,material='roof_rust',profile=[[0,.8],[.1,1],[.32,.93],[.68,.63],[.9,.38],[1,.05]]),
 dict(base=[326,253],level_pixels=185,height_pixels=71,diameter=83,material='basalt',window='dark_palace_window',profile=[[0,1],[.95,.88],[1,.95]]),dict(base=[326,184],level_pixels=256,height_pixels=130,diameter=117,material='roof_rust',profile=[[0,.8],[.1,1],[.32,.93],[.68,.63],[.9,.38],[1,.05]]),
 dict(base=[332,292],level_pixels=238,height_pixels=48,diameter=97,material='basalt',window='dark_palace_window',profile=[[0,1],[1,1]]),dict(base=[332,246],level_pixels=286,height_pixels=85,diameter=110,material='roof_rust',profile=[[0,.83],[.15,1],[.45,.9],[.75,.58],[1,.05]]),
 dict(base=[251,282],level_pixels=195,height_pixels=70,diameter=77,material='basalt',profile=[[0,1],[1,.9]]),dict(base=[251,214],level_pixels=265,height_pixels=62,diameter=94,material='roof_rust',profile=[[0,.83],[.18,1],[.52,.8],[.85,.4],[1,.05]]),
 ],stairs=[dict(near=[[119,584],[248,678]],far=[[179,494],[308,588]],height_pixels=76,steps=15)],terraces=[dict(points=[[34,446],[310,251],[671,470],[382,720]],height_pixels=33,material='basalt',solid=True)],details=[[151,126,185,184],[308,7,345,63],[500,131,537,195],[335,280,372,326]]),
}


OBSERVATORY=dict(towers=[
 dict(base=[124,514],height_pixels=414,diameter=31,material='timber',tiled_front=True,profile=[[0,1.1],[.18,1],[.75,.7],[1,.85]]),
 dict(base=[124,161],level_pixels=350,height_pixels=70,diameter=113,material='timber',profile=[[0,.94],[1,.94]]),
 dict(base=[124,94],level_pixels=420,height_pixels=86,diameter=153,material='metal_dark',profile=[[0,.9],[.18,1],[.55,.93],[.83,.63],[1,.04]]),
 ],platforms=[dict(base=[124,449],level_pixels=50,height_pixels=7,diameter=247,material='timber',paint_top=True,cap_inner=.29,rail_pixels=29),dict(base=[124,145],level_pixels=354,height_pixels=7,diameter=247,material='timber',paint_top=True,rail_pixels=29)],
 stairs=[dict(near=[[18,551],[54,571]],far=[[56,487],[93,511]],height_pixels=48,steps=9)],
 rods=[dict(a=[48,400],b=[92,290],ground_pixel=[124,514],radius=.23,material='timber'),dict(a=[202,401],b=[155,290],ground_pixel=[124,514],radius=.23,material='timber'),dict(a=[76,367],b=[91,190],ground_pixel=[124,514],radius=.19,material='timber'),dict(a=[173,365],b=[155,190],ground_pixel=[124,514],radius=.19,material='timber'),dict(a=[33,52],b=[119,47],ground_pixel=[124,514],radius=.8,material='metal_dark')])


def shifted(spec,dx=0,dy=0):
    result=deepcopy(spec)
    for family in ('blocks','houses','towers','trunks','stairs','platforms','rods','terraces'):
        for part in result.get(family,[]):
            for key in ('base','top','apex','a','b','ground_pixel'):
                if key in part:part[key]=[part[key][0]+dx,part[key][1]+dy]
            for key in ('feet','eaves','ridge','near','far','points'):
                if key in part:part[key]=[[p[0]+dx,p[1]+dy] for p in part[key]]
    return result


for serial in (1233260,1233265):REGIONAL[serial]=shifted(OBSERVATORY)
REGIONAL[1233268]=shifted(OBSERVATORY,125)
REGIONAL[1233268]['visible_override']=[125,0,375,577]
REGIONAL[1233268]['source_canvas_note']='Original500x1166canvas retains itsRGBA; reconstruction uses the actual upper tower and ignores the disconnected white footer/padding below the native floor anchor.'
REGIONAL[1233268]['rods'][-1].update(a=[334,42],b=[247,42])


SURFACES={
 'temple_stone':(1233180,[(354,313)]*4,False,(64,64)),
 'temple_window':(1233180,[(286,402),(310,418),(310,451),(286,435)],True,(64,96)),
 'sandstone':(1230113,[(265,96)]*4,False,(64,64)),
 'basalt':(1233172,[(277,401)]*4,False,(64,64)),
 'roof_rust':(1233172,[(322,80),(341,93),(338,108),(320,95)],False,(64,64)),
 'dark_palace_window':(1233172,[(154,348),(180,365),(180,399),(154,382)],True,(64,96)),
 'metal_dark':(1233265,[(131,39)]*4,False,(64,64)),
 'rock_gray':(1238110,[(52,228),(72,228),(72,248),(52,248)],False,(64,64)),
 'rock_moss':(1233217,[(102,174),(122,174),(122,194),(102,194)],False,(64,64)),
}

SOURCE_ROCKS={serial:('rock_gray' if serial>=1238000 else 'rock_moss') for serial in list(range(1238110,1238125))+[1233217,1233218,1233219,1233221]}
SOURCE_ROCKS.update({serial:'rock_gray' for serial in range(15012,15021)})
ROCK_HOLES={1233218:[[49,200],[57,153],[70,126],[91,113],[113,134],[128,194]]}

REGIONAL[1233250]=dict(houses=[dict(feet=[[48,411],[229,561],[411,459]],eaves=[[5,185],[229,398],[423,279]],apex=[145,26],ridge=[[145,26],[376,194]],ridge_axis=1,wall_pixels=163,roof='roof_blue',wall='ruin_stone',base_material='ruin_stone',back_upper_material='timber',window='tree_window',trim='timber')],terraces=[dict(points=[[86,407],[122,385],[166,423],[128,453]],height_pixels=68)])
REGIONAL[1233251]=dict(houses=[dict(feet=[[1,354],[92,411],[180,354]],eaves=[[0,88],[94,154],[187,94]],apex=[124,1],ridge=[[42,56],[124,1]],wall_pixels=257,roof='roof_blue',wall='ruin_stone',base_material='ruin_stone',back_upper_material='timber',window='tree_window',trim='timber')])
REGIONAL[1233252]=dict(houses=[dict(feet=[[48,270],[105,334],[236,251]],eaves=[[1,132],[111,241],[271,113]],apex=[154,24],wall_pixels=99,roof='roof_blue',wall='timber',base_material='timber',window='tree_window',trim='timber')],towers=[dict(base=[156,98],level_pixels=168,height_pixels=86,diameter=27,material='ruin_stone',profile=[[0,1],[.15,1.2],[.85,.85],[1,1.15]]),dict(base=[54,120],level_pixels=170,height_pixels=40,diameter=50,material='timber',sides=4,angle_offset=.785398,profile=[[0,1],[.6,1],[1,0]])])
REGIONAL[1233255]=dict(houses=[dict(feet=[[36,249],[167,332],[224,268]],eaves=[[1,111],[161,239],[271,130]],apex=[118,22],wall_pixels=99,roof='roof_blue',wall='timber',base_material='timber',window='tree_window',trim='timber')],towers=[dict(base=[102,96],level_pixels=168,height_pixels=86,diameter=27,material='ruin_stone',profile=[[0,1],[.15,1.2],[.85,.85],[1,1.15]]),dict(base=[218,118],level_pixels=170,height_pixels=40,diameter=50,material='timber',sides=4,angle_offset=.785398,profile=[[0,1],[.6,1],[1,0]])])
REGIONAL[1233258]=dict(houses=[dict(feet=[[21,310],[105,375],[213,302]],eaves=[[3,150],[103,269],[234,165]],apex=[6,10],ridge=[[6,10],[183,65]],ridge_axis=1,wall_pixels=103,roof='roof_blue',wall='ruin_stone',base_material='ruin_stone',back_upper_material='timber',window='tree_window',trim='timber')])

LEAF_HUT=dict(towers=[dict(base=[140,365],height_pixels=126,diameter=215,material='timber',window='tree_window',profile=[[0,.84],[.13,1],[.92,.97],[1,1]]),dict(base=[141,267],level_pixels=126,height_pixels=256,diameter=284,material='leaf_roof_green',profile=[[0,1],[.12,.96],[.4,.80],[.67,.54],[.85,.28],[1,0]])],stairs=[dict(near=[[214,397],[251,370]],far=[[190,350],[228,324]],height_pixels=38,steps=7)],details=[[104,0,164,65]])
for serial,color in [(1233262,'green'),(1233267,'red')]:
 REGIONAL[serial]=deepcopy(LEAF_HUT);REGIONAL[serial]['towers'][1]['material']='leaf_roof_'+color
for serial,color in [(1233261,'green'),(1233264,'gold')]:
 spec=deepcopy(LEAF_HUT);spec['towers'][0]['base']=[139,360];spec['towers'][1]['base']=[139,262];spec['towers'][1]['material']='leaf_roof_'+color
 spec['stairs']=[dict(near=[[28,369],[65,395]],far=[[51,321],[88,348]],height_pixels=38,steps=7)];REGIONAL[serial]=spec

MUSHROOM_HUT=dict(towers=[dict(base=[98,249],height_pixels=104,diameter=176,material='timber',window='tree_window',profile=[[0,.83],[.12,1],[.94,.96],[1,1]]),dict(base=[99,164],level_pixels=104,height_pixels=141,diameter=200,material='thatch',profile=[[0,1],[.15,.92],[.4,.70],[.66,.45],[.9,.16],[1,0]])],details=[[64,0,108,62],[151,120,199,201]])
REGIONAL[1233177]=deepcopy(MUSHROOM_HUT)
REGIONAL[1233175]=shifted(MUSHROOM_HUT,-4,-7)
REGIONAL[1233175]['details']=[[36,0,88,81],[122,92,189,184]]

REGIONAL[1233276]=dict(towers=[dict(base=[227,522],top=[253,22],height_pixels=500,diameter=274,material='ruin_stone',hollow_top=True,measure_rim=True,profile=[[0,1.05],[.12,1],[.3,.78],[.8,.72],[1,.62]]),dict(base=[72,433],height_pixels=275,diameter=111,material='ruin_stone',hollow_top=True,measure_rim=True,profile=[[0,1],[.2,.9],[1,.78]]),dict(base=[356,467],height_pixels=230,diameter=116,material='ruin_stone',hollow_top=True,measure_rim=True,profile=[[0,1],[.2,.9],[1,.78]])])
REGIONAL[1233277]=dict(towers=[dict(base=[190,410],top=[189,32],height_pixels=378,diameter=230,material='ruin_stone',hollow_top=True,measure_rim=True,profile=[[0,1.05],[.15,1],[.5,.8],[1,.68]])],terraces=[dict(points=[[40,227],[125,171],[161,198],[79,255]],height_pixels=148)])
REGIONAL[1233278]=dict(towers=[dict(base=[148,410],top=[137,35],height_pixels=375,diameter=222,material='ruin_stone',hollow_top=True,measure_rim=True,profile=[[0,1.05],[.15,1],[.5,.8],[1,.68]]),dict(base=[58,192],height_pixels=153,diameter=77,material='ruin_stone',hollow_top=True,measure_rim=True,profile=[[0,1],[1,.7]])])
for serial,h in [(1233270,288),(1233273,287),(1233274,286),(1233275,284)]:
 REGIONAL[serial]=dict(towers=[dict(base=[80,305],height_pixels=h,diameter=126,material='ruin_stone',sides=4,angle_offset=.785398,hollow_top=True,measure_rim=True,profile=[[0,1],[.88,.91],[1,.98]])])

REGIONAL[1260088]=dict(blocks=[dict(feet=[[28,308],[179,405],[316,304]],height_pixels=210,material='sandstone',window='temple_window')],towers=[dict(base=base,level_pixels=210,height_pixels=50,diameter=54,material='sandstone',sides=4,angle_offset=.785398,profile=[[0,.8],[.75,.8],[.78,1],[1,1]]) for base in [[78,162],[179,233],[286,161],[188,89]]],stairs=[dict(near=[[74,299],[128,339]],far=[[122,238],[171,274]],height_pixels=64,steps=11)])
REGIONAL[1233057]=dict(blocks=[dict(feet=[[2,146],[92,214],[189,151]],height_pixels=8,material='stone')],towers=[dict(base=[95,181],height_pixels=110,diameter=22,material='stone',profile=[[0,1.2],[.15,1.2],[.2,.8],[.6,.45],[.9,.75],[1,.6]]),dict(base=[95,117],level_pixels=70,height_pixels=16,diameter=89,material='stone',paint_top=True,cap_inner=.65,profile=[[0,.4],[.3,1],[.75,1],[1,.82]]),dict(base=[95,102],level_pixels=88,height_pixels=1,diameter=61,material='water',profile=[[0,1],[1,1]])],details=[[73,0,112,56]])

STATUES={}
for serial,w,h in [(1235177,256,305),(1235178,252,302),(1235176,244,254)]:
 scale_x=w/256;scale_y=h/305
 STATUES[serial]=dict(slope=0,depth=.65,back='stone',blocks=[dict(feet=[[8*scale_x,234*scale_y],[134*scale_x,301*scale_y],[248*scale_x,223*scale_y]],height_pixels=18,material='stone')],towers=[dict(base=[128*scale_x,217*scale_y],level_pixels=23,height_pixels=81*scale_y,diameter=85*scale_x,material='stone',profile=[[0,.65],[.4,1],[.8,.75],[1,.35]])],rods=[dict(a=[110*scale_x,180*scale_y],b=[102*scale_x,221*scale_y],ground_pixel=[134*scale_x,301*scale_y],radius=.45,material='stone'),dict(a=[158*scale_x,180*scale_y],b=[153*scale_x,229*scale_y],ground_pixel=[134*scale_x,301*scale_y],radius=.45,material='stone')])

SURFACES.update({
 'ruin_stone':(1233270,[(53,154),(73,168),(73,192),(53,178)],False,(64,64)),
 'leaf_roof_green':(1233262,[(133,137),(153,137),(153,162),(133,162)],False,(64,64)),
 'leaf_roof_red':(1233267,[(133,137),(153,137),(153,162),(133,162)],False,(64,64)),
 'leaf_roof_gold':(1233264,[(131,136),(151,136),(151,161),(131,161)],False,(64,64)),
 'thatch':(1233177,[(86,91),(108,91),(108,110),(86,110)],False,(64,64)),
 'water':(1233057,[(95,104)]*4,False,(64,64)),
})
