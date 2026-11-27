"""Private source-space shore/inland grade measurements; no runtime height edits."""
from collections import Counter
import hashlib
import json
from math import cos, hypot, sin, sqrt
from pathlib import Path
import sys

from prepare_east_il_low_host import OUT, ROOT
from prepare_east_region_field import source_area
from prepare_east_region_maps import reference_map

GRADE = .20
FLAT_DRY_RING = sqrt(18.)


def smooth(a,b,x):
    t = max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3.-2.*t)


def rectangle_distance(x,z,left,top,width,height):
    return hypot(x-max(left,min(left+width,x)),z-max(top,min(top+height,z)))


def old_dry_height(x,z):
    sx,sz = x*3.,z*3.
    world = 6.+sin(sx*.014+sz*.008)*1.6+cos(sz*.018-sx*.008)*1.1
    if source_area(x,z) == 'north_coast':
        distance = rectangle_distance((x-579)*3.,(z-70)*3.,-150.,-150.,300.,300.)
        return 6.+(world-6.)*smooth(0.,18.,distance)
    lx,lz = 591.-sz,sx-1251.
    bank = 6.
    if lz > 244.:bank += (3.*sin(lx*.023+lz*.016)+2.*cos(lz*.027-lx*.011))*smooth(244.,326.,lz)
    bank += (6.-bank)*smooth(105.,140.,-lx)
    bank += (world-bank)*smooth(370.,405.,lz)
    # Current Il joined frame: source100−(636,312), local origin(-135,-180).
    distance = rectangle_distance((x-681)*3.,(z-372)*3.,-135.,-180.,270.,360.)
    return 6.+(bank-6.)*smooth(0.,18.,distance)


def main():
    sys.path.insert(0,str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    interfaces_path = OUT/'shore-interface-plan.json'; interfaces = json.loads(interfaces_path.read_text())
    raw_path = OUT/'100.dat'; w,h,bg,pg,flags = lib.parse_map(raw_path.read_bytes())
    reference = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Version Expansion Source Audit/map__00100_field1'
    rw,rh,native,_ = reference_map(reference.read_bytes(),100); assert (w,h)==(rw,rh)
    source_bg,source_pg = native[:w*h],native[w*h:]
    walk = navigation_grid(w,h,source_bg,source_pg,lib.serial_index())
    wet = {tuple(r['cell']):r for r in interfaces['private_connected_shore_rows'] if not r['contextual_owner'].startswith('protected_')}
    protected = {tuple(r['cell']) for r in interfaces['protected_context_rows']}
    alyut_folder = ROOT/'assets/maps/falan/east_region/alyut_source_completion'
    handoff_path,overlap_path = alyut_folder/'gate-handoffs.json',alyut_folder/'source-overlaps.json'
    handoffs,overlaps = json.loads(handoff_path.read_text()),json.loads(overlap_path.read_text())
    field_exceptions = {tuple(r['field_cell']) for r in handoffs['handoff_cells']+overlaps['source100_overlap_cells']}
    def protected_alyut(cell):
        x,z = cell
        return 529 <= x < 629 and 20 <= z < 120
    offsets = [(dx,dz,hypot(dx,dz)*3.) for dz in range(-13,14) for dx in range(-13,14) if hypot(dx,dz)*3. <= 38.]
    nearest = {}
    for x,z in wet:
        for dx,dz,distance in offsets:
            key = (x+dx,z+dz)
            if 0 <= key[0] < w and 0 <= key[1] < h and not protected_alyut(key) and (key not in nearest or distance < nearest[key]):nearest[key]=distance
    rows = []; proposed = {}
    for (x,z),distance in sorted(nearest.items(),key=lambda row:(row[0][1],row[0][0])):
        i = z*w+x; tile,serial = source_bg[i],source_pg[i]
        if (x,z) in wet:
            height = 2. if serial==252 else 2.10
            kind = 'source_open_water_floor' if serial==252 else 'source_open_native_bank'
        elif tile not in (0,100) and not 5000 <= tile <= 5008:
            height = min(old_dry_height(x,z),2.10+max(0.,distance-FLAT_DRY_RING)*GRADE)
            kind = 'existing_source_dry_grade'
            if abs(height-old_dry_height(x,z)) < .000001:continue
        else:continue
        old = old_dry_height(x,z)
        proposed[x,z]=height
        rows.append({'cell':[x,z], 'kind':kind, 'floor':int(tile), 'object':int(serial), 'original_open':bool(walk[i]),
                     'old_inferred_land_datum':old, 'candidate_height':height, 'distance_to_native_wet_component':distance,
                     'active_tuple_present':bool(bg[i] or pg[i]), 'active_tuple_matches_pinned':(bg[i],pg[i])==(tile,serial),
                     'active_recorded_marker':bool(flags[i]&0xc000), 'owner':source_area(x,z)})
    def value(cell):
        x,z = cell; i = z*w+x
        return proposed.get((x,z),2. if source_pg[i]==252 else old_dry_height(x,z))
    assert not any(protected_alyut(tuple(r['cell'])) for r in rows), 'Retain the entire published Alyut overlay, including all18field exceptions'
    edge_rows = []
    for edge in interfaces['host_open_boundary_edges']:
        a,b = edge['inside']['cell'],edge['outside']['cell']
        edge_rows.append({'inside_cell':a,'outside_cell':b,'inside_kind':edge['inside']['kind'],'outside_kind':edge['outside']['kind'],
                          'inside_height':value(a),'outside_height':value(b),
                          'endpoint_difference_world':abs(value(a)-value(b))*1.3})
    def minimum_distance(points):
        return min((hypot(x-a,z-b)*3.,[x,z],[a,b]) for x,z in points for a,b in wet)
    bridges = {'city_bridge':minimum_distance([(x,z) for x in range(438,469) for z in range(193,200)]),
               'il_river_bridge':minimum_distance([(x,z) for x in range(554,560) for z in range(232,235)]),
               'original_il_entry_return':minimum_distance([(681,343),(682,343)]),
               'alyut_south_return':minimum_distance([(595,83),(596,83)])}
    report = {'scope':'PRIVATE measured height proposal only. No shared/active height field, geometry, floor support, raw tuple, mask, bridge, actor, route or collider mutation.',
              'proposal':{'source_open_water_height':2.,'source_open_bank_height':2.10,'inland_grade_maximum':GRADE,
                          'flat_existing_dry_ring_metres':FLAT_DRY_RING,
                          'rule':'Native open bank/control components supply the coast datum. Existing source dryland rises naturally toward its current inferred land height at no more than1:5, after one full eight-neighbor dry ring. This is a source-space height inference, not extra land/stairs/bridges.'},
              'counts':{'affected_height_cells':len(rows), 'kinds':dict(Counter(r['kind'] for r in rows)), 'owners':dict(Counter(r['owner'] for r in rows)),
                        'affected_dry_current_unknown_tuple_cells':sum(r['kind']=='existing_source_dry_grade' and not r['active_tuple_present'] for r in rows),
                        'protected_full_alyut_wet_cells_excluded':len(protected),'protected_full_alyut_entire_overlay_excluded':True,
                        'protected_alyut_field_exceptions_unchanged':len(field_exceptions),'host_interface_edges':len(edge_rows)},
              'height_cells':rows,'host_interface_edges':edge_rows,'nearest_current_bridge_or_gate':bridges,
              'source_hashes':{str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in [interfaces_path,raw_path,reference,Path(__file__),ROOT/'scripts/forest/forest_east_road.gd',ROOT/'scripts/forest/forest_freyja_regions.gd',handoff_path,overlap_path]},
              'limits':['The proposed cells are a measurement ledger, not a proof that the current3mfield sampler or player/nativephysics follows this continuous grade.',
                        'Sourceclosed dry cells in the visible grade remain closed. Their height may support a source building datum but grants no floor or new route.',
                        'Source0/100/ordinary closed water are excluded. Unknown dry cells outside the private host raw fill require separately bounded source completion before any physical/render publication.',
                        '430canonical FullAlyut source2400cells are excluded; cross-owner shore interfaces await Verification original100/2400 comparison.',
                        'Bank cap heightfield interpolation, complete source-open disks at sourcecell edges, continuous dry approaches, all77interfaces and sourceblocked-water enforcement require the same isolatedNative/Kai/player/pet gates as the lowIl proof.',
                        'No current bridge floor is enrolled merely because it is near the coast. Exact owner geometry and its distance are measured separately.']}
    (OUT/'height-proposal.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'counts':report['counts'],'nearest_current_bridge_or_gate':bridges},indent=2))


if __name__ == '__main__':main()
