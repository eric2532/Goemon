"""Visible native furniture roles, reviewed on all six numbered furniture sheets.

These are visual design roles, not unverified original item or NPC names. Source
objects never gain service/event behavior from a scenery recipe.
"""
GROUPS={
 'plant_table':[10035], 'plain_bench':[10038], 'wheelbarrow':[10043,10044],
 'low_cabinet':[10430], 'open_hutch':[10431], 'open_crate':[10433,10497],
 'empty_shelf':[10438,17542,17547], 'covered_side_cabinet':[10440,10492],
 'ritual_table':[10523], 'wall_clock':[10567],
 'laundry_line':[11003,11004,11005,11006,11031], 'hand_cart':[11023],
 'backed_wood_bench':[11038,11039,11040], 'roofed_post_fixture':[11042],
 'mailbox':[11575,11576,11580], 'spilled_barrel':[11730], 'broken_crate':[11731,11732],
 'upholstered_armchair':[16010,16013], 'narrow_drawers':[16014],
 'closed_wardrobe':[16016,16017,16020,16021,16023], 'metal_stove':[16032],
 'hospital_bed':[16035,16036,16038],
 'wood_bed':[16039,16040,16044,16046,16047,16049,16050,16051,16052,16053,16055,16056,16057,16058,16059,16062],
 'low_open_display':[16070,16071], 'marble_low_table':[16074,16121],
 'bookcase':[16085,16087,16098,16147,16150,17000,17001,17588,17589],
 'covered_low_seat':[16141], 'tea_table':[16156], 'glass_hutch':[16162], 'kitchen_counter':[16164,16165,16167,16168],
 'wall_kitchen_unit':[16169], 'standing_mirror':[16223], 'range_with_pans':[16244,16245,16538],
 'writing_table':[16536], 'hammock':[16631], 'piano':[16646],
 'helmet_display':[16749], 'sword_display':[16754], 'instrument_display':[16765], 'kettle_display':[16766],
 'earring_board':[16805], 'open_wicker_crate':[16818], 'mat_and_scroll':[16823],
 'pedestal_with_stamp':[16824], 'pedestal_with_drawers':[16825,16828],
 'display_plinth':[16852,16853,16854,16855,16864,16865,16866],
 'covered_counter':[16876,16878,16879,16881,16882,16883,16884],
 'arched_drawers':[17008], 'dresser_mirror':[17010,17011], 'pipe_display':[17044],
 'jewel_counter':[17052,17182], 'plain_wood_counter':[17055,17056,17578],
 'weapon_rack':[17063,17064], 'shield_and_sword_table':[17165], 'plant_counter':[17183],
 'counter_segment':[17197,17199], 'shield_display':[17230], 'wood_chair':[17513,17514,17515],
 'capped_wood_crate':[17528], 'curved_counter':[17566,17567,17571],
 'goods_counter':[17593,17594], 'drawer_over_firewood':[17618],
 'firewood_counter':[17620,17622], 'writing_hutch':[17637],
}

ROLES={serial:role for role,serials in GROUPS.items() for serial in serials}
assert len(ROLES)==sum(map(len,GROUPS.values())), 'Duplicate furniture recipe'
