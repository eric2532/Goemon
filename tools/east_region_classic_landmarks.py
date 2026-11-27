"""East-only enrollment of classic native forms; shared city/village masters stay intact."""

# Whole models are preferred where their exact original graphic already has an owner.
REUSED={
 11268:dict(kit='il_chief',owner='scripts/forest/forest_il_chief.gd',finial=[143,0,180,64]),
 11269:dict(kit='coastal_village',owner='scripts/forest/forest_east_village_buildings.gd'),
 11272:dict(kit='il_house',owner='scripts/forest/forest_east_village_buildings.gd'),
 11273:dict(kit='il_house',owner='scripts/forest/forest_east_village_buildings.gd'),
 10304:dict(kit='falan_house',owner='scripts/forest/forest_falan_houses.gd',style=3),
 10077:dict(kit='falan_house',owner='scripts/forest/forest_falan_houses.gd',style=3),
 10605:dict(kit='falan_house',owner='scripts/forest/forest_falan_houses.gd',style=2),
 10606:dict(kit='falan_special',owner='scripts/forest/forest_falan_special_exteriors.gd'),
 10603:dict(kit='falan_office',owner='scripts/forest/forest_falan_civic_exterior.gd',turn=-90),
 10607:dict(kit='falan_office',owner='scripts/forest/forest_falan_civic_exterior.gd',turn=-180),
 10655:dict(kit='falan_round_tower',owner='scripts/forest/forest_falan_fort_parts.gd',turn=-90),
 10657:dict(kit='falan_round_tower',owner='scripts/forest/forest_falan_fort_parts.gd',turn=-90),
 17572:dict(kit='writing_desk',owner='scripts/forest/forest_falan_interior_furniture.gd'),
}

SHELTERS={
 11081:dict(feet=[[153,356],[250,421],[495,247]],eaves=[[110,263],[251,359],[530,129]],ridge=[[184,218],[471,5]],ridge_axis=1,apex=[471,5],wall_pixels=109,roof='classic_thatch',wall='timber',post_pixels=[[156,354],[250,418],[345,349],[406,299],[490,243]],rear_wall=True,details=[[254,301,306,369],[345,241,390,302],[417,191,458,252]]),
 11082:dict(feet=[[44,240],[287,415],[383,357]],eaves=[[2,129],[285,355],[426,260]],ridge=[[62,3],[345,216]],apex=[62,3],wall_pixels=109,roof='classic_thatch',wall='timber',post_pixels=[[46,238],[133,300],[221,363],[287,413],[383,356]],rear_wall=True,details=[[48,168,101,245],[135,228,180,307],[220,294,260,368]]),
 11084:dict(feet=[[42,368],[150,437],[416,230]],eaves=[[0,275],[144,359],[462,126]],ridge=[[64,231],[407,0]],ridge_axis=1,apex=[407,0],wall_pixels=132,roof='classic_wood_roof',wall='classic_plaster',post_pixels=[[44,367],[151,435],[239,364],[328,297],[414,231]],rear_wall=True,details=[[226,275,296,346],[304,220,363,278],[352,169,409,227]]),
}

COMPOUNDS={
 10013:dict(blocks=[dict(feet=[[4,343],[201,490],[326,414]],height_pixels=200,material='classic_stone',window='classic_tower_window')],towers=[dict(base=[115,210],level_pixels=200,height_pixels=201,diameter=121,material='classic_stone',sides=8,hollow_top=True,paint_top=True,crenellations=True,profile=[[0,1],[.91,.98],[1,1.04]]),dict(base=[212,288],level_pixels=200,height_pixels=201,diameter=120,material='classic_stone',sides=8,hollow_top=True,paint_top=True,crenellations=True,profile=[[0,1],[.91,.98],[1,1.04]])]),
 11278:dict(houses=[dict(feet=[[35,351],[153,405],[318,295]],eaves=[[3,180],[157,301],[341,177]],ridge=[[76,142],[246,0]],apex=[246,0],ridge_axis=1,wall_pixels=143,roof='classic_slate',wall='classic_plaster',base_material='classic_stone',back_upper_material='timber',window='tree_window',trim='timber')]),
 11417:dict(houses=[dict(feet=[[45,316],[145,405],[281,325]],eaves=[[13,245],[159,294],[309,233]],apex=[161,13],wall_pixels=97,roof='classic_thatch',wall='classic_plaster',base_material='classic_stone',back_upper_material='timber',trim='timber',window='tree_window',cap=False)],towers=[dict(base=[27,314],height_pixels=171,diameter=31,material='classic_stone',sides=4,angle_offset=.785398,profile=[[0,1],[1,.9]])],terraces=[dict(points=[[213,349],[269,307],[318,271],[269,315]],height_pixels=22)],details=[[73,96,138,180]]),
 11420:dict(houses=[dict(feet=[[26,310],[139,379],[290,287]],eaves=[[5,234],[144,285],[305,229]],apex=[156,8],wall_pixels=97,roof='classic_thatch',wall='classic_plaster',base_material='classic_stone',back_upper_material='timber',trim='timber',window='tree_window',cap=False)],terraces=[dict(points=[[8,275],[56,307],[105,337],[58,309]],height_pixels=22)],details=[[71,90,135,172]]),
 17636:dict(towers=[dict(base=[122,203],height_pixels=110,diameter=226,material='classic_earth',sides=32,profile=[[0,.9],[.22,1],[.5,.91],[.75,.65],[1,.17]]),dict(base=[55,89],level_pixels=70,height_pixels=78,diameter=51,material='classic_stone',sides=4,angle_offset=.785398,profile=[[0,1],[.87,1],[.9,1.1],[1,1.1]])],details=[[136,108,209,174]]),
}

ROCKS={12548:'rock_moss',12563:'classic_rock',12564:'classic_rock',12565:'classic_rock'}
HOLES={12548:[[49,359],[57,288],[61,224],[79,190],[107,180],[132,218],[144,323]],12564:[[45,343],[54,272],[81,210],[111,189],[143,222],[158,317]],12565:[[65,332],[71,264],[91,216],[117,215],[138,250],[147,311]]}

SURFACES={
 'classic_thatch':(11082,[(183,147),(203,147),(203,169),(183,169)],False,(64,64)),
 'classic_wood_roof':(11084,[(273,102),(293,102),(293,123),(273,123)],False,(64,64)),
 'classic_slate':(11278,[(195,86),(215,86),(215,106),(195,106)],False,(64,64)),
 'classic_plaster':(11278,[(129,322)]*4,False,(64,64)),
 'classic_stone':(10013,[(46,318)]*4,False,(64,64)),
 'classic_tower_window':(10013,[(44,252),(57,261),(57,296),(44,287)],True,(48,96)),
 'classic_rock':(12563,[(87,218),(106,218),(106,238),(87,238)],False,(64,64)),
 'classic_earth':(17636,[(111,70),(132,70),(132,90),(111,90)],False,(64,64)),
}
