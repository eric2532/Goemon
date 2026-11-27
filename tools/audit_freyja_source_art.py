"""Read-only source100 art inventory; never writes runtime assets or map activation."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage'
OUT = REPORT / 'Freyja full-source art inventory'
UNION = REPORT / 'Freyja full-source union'
CATALOGS = [
    ROOT / 'assets/maps/original_crossgate/catalog.json',
    ROOT / 'assets/maps/falan/sokia/fixed/catalog.json',
    ROOT / 'assets/maps/original_crossgate/university/catalog.json',
    ROOT / 'assets/maps/original_crossgate/elsa/catalog.json',
    ROOT / 'assets/maps/original_crossgate/east/catalog.json',
    ROOT / 'assets/maps/original_crossgate/sokia_server/catalog.json',
    ROOT / 'assets/maps/falan/black_prayer/events/return-maps/catalog.json',
]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inputs():
    sys.path.insert(0, str(ROOT.parent / 'Magic Power/tools'))
    import cg_library as lib
    gaps = json.loads((UNION / 'source-art-without-declaration.json').read_text())
    visibility = json.loads((UNION / 'art-visibility.json').read_text())
    visible = [r for r in gaps if visibility['graphics'][str(r['serial'])]['status'] == 'source_has_visible_pixels']
    assert len(visible) == 6943
    catalogs = defaultdict(list)
    for path in CATALOGS:
        for serial, graphic in json.loads(path.read_text())['graphics'].items():
            catalogs[int(serial)].append((path, graphic))
    lookup = lib.serial_index()
    graphics = {}
    for serial, count in sorted(Counter(r['serial'] for r in visible).items()):
        source = lookup[serial]
        picture = visibility['graphics'][str(serial)]
        assert (source['pack'], source['row']) == (picture['pack'], picture['row'])
        matches = [(p, g) for p, g in catalogs[serial] if g['rgba_sha256'] == picture['rgba_sha256']]
        g = matches[-1][1] if matches else {}
        bbox = picture['alpha_bbox']
        graphics[str(serial)] = dict(
            anchors=count, pack=source['pack'], row=source['row'],
            origin=[source['x'], source['y']], size=[source['w'], source['h']],
            footprint=[max(1, source['east']), max(1, source['south'])],
            visible_pixel_rect=[source['x'] + bbox[0], source['y'] + bbox[1], bbox[2]-bbox[0], bbox[3]-bbox[1]],
            rgba_sha256=picture['rgba_sha256'],
            native_kind_input=dict(family=g.get('family', ''), ground=int(source['ground']), shore_bank=12500 <= serial <= 12535),
            matching_catalogs=[str(p.relative_to(ROOT)) for p, _ in matches],
            catalog_conflicts=[str(p.relative_to(ROOT)) for p, g in catalogs[serial] if g['rgba_sha256'] != picture['rgba_sha256']],
        )
    data = dict(source_sha256=visibility['source_sha256'], visible_gap_anchors=6943,
                graphics=graphics, raw_gap_inventory_sha256=sha(UNION / 'source-art-without-declaration.json'),
                source_visibility_sha256=sha(UNION / 'art-visibility.json'),
                catalog_sha256={str(p.relative_to(ROOT)): sha(p) for p in CATALOGS},
                limits='Input declarations and original visible pixels only. Catalog presence does not establish renderer ownership, correct-looking geometry or full-source activation.')
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'graphics-source.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    return data


def transform(frame, point):
    return [frame['origin'][k] + frame['x'][k]*point[0] + frame['y'][k]*point[1] for k in (0, 1)]


def inverse(frame, point):
    delta = [point[k]-frame['origin'][k] for k in (0, 1)]
    return [sum(delta[k]*frame[axis][k] for k in (0, 1)) for axis in ('x', 'y')]


def key(row):
    return (*map(int, row['cell']), int(row['serial']))


def existing_owner_candidates(contracts, stations, lib):
    """Exact native-ID/station evidence only; renderer clipping is still a separate check."""
    matches = defaultdict(list)
    street = ROOT/'assets/maps/falan/city_street_data.gd'
    rows = re.findall(r'\[Vector2\(([-\d.]+),([-\d.]+)\),(\d+)', street.read_text())
    for row in contracts:
        if 'city' not in row:
            continue
        for x, y, serial in rows:
            local = inverse(row['city']['frame'], [float(x), float(y)])
            source = [v/3 for v in transform(row['frame'], local)]
            at = (*map(round, source), int(serial))
            if max(abs(source[k]-at[k]) for k in (0, 1)) < 1e-5 and at in stations:
                matches[at].append(dict(owner='city_street', area=row['area'],
                    input=str(street.relative_to(ROOT)), owner_local=[float(x), float(y)],
                    status='exact native serial/station input; child renderer/visibility filters unverified'))
    for row in contracts:
        if 'joined_village' not in row:
            continue
        village = row['joined_village']; number = {'il_village': 2000, 'alyut': 2400}[village['name']]
        with lib.connection() as db:
            ident = db.execute('SELECT id FROM files WHERE path=?', (f'BlueCrossgate/map/0/{number}.dat',)).fetchone()[0]
        raw = lib.source_file(ident)[1].read_bytes(); w, h, _, objects, _ = lib.parse_map(raw)
        for i, serial in enumerate(objects):
            if serial < 1000:
                continue
            village_point = [village['bounds'][0]+(i%w)*3, village['bounds'][1]+(i//w)*3]
            local = inverse(village['frame'], village_point)
            source = [v/3 for v in transform(row['frame'], local)]
            at = (*map(round, source), serial)
            if max(abs(source[k]-at[k]) for k in (0, 1)) < 1e-5 and at in stations:
                matches[at].append(dict(owner=village['name'], area=row['area'],
                    input=f'BlueCrossgate/map/0/{number}.dat', source_sha256=hashlib.sha256(raw).hexdigest(),
                    village_cell=[i%w, i//w],
                    status='exact native serial/station via existing joined-village transform; renderer filters unverified'))
    return matches


def family(serial, kind, east_props):
    """Reuse contracts, not a claim that the current generic kind is an adequate shape."""
    if 12500 <= serial <= 12535:
        return 'source_shore_profiles', 'forest_tina_ground.gd::bank_mesh', 'Measure per-profile floor/cap/descending-face interpretation; preserve source water and blocked clearance.'
    if 12536 <= serial <= 12565:
        return 'source_cliff_profiles', 'forest_original_cliffs.gd::{collect,build}', 'Reuse measured native profiles/continuous mass and existing source-fit paint; preserve every footprint, terrain and collider.'
    if serial in [11268,11269,11271,11272,11273,11275,11276,11279,11280,11281,11283,11284,11285,11286,11289,11290,11292,11293,11294,11295,11297,11298,11106]:
        if serial in [11276,11279,11280,11283,11284,11286]:
            owner = 'forest_venoa_buildings.gd::prepare'
        elif serial in [11281,11285,11106]:
            owner = 'forest_il_laruka_buildings.gd::prepare'
        else:
            owner = 'forest_coastal_buildings.gd::shape'
        return 'whole_native_buildings', owner, 'Reuse whole source-specific house before modular parts; verify origin/footprint, projected foot, height and normal-camera occlusion.'
    if 11251 <= serial <= 11266:
        return 'native_weathered_wall', 'forest_venoa_walls.gd::prepare', ('Existing exact variant profile.' if 11252 <= serial <= 11265 else 'Endpoint variant not in current Venoa FORMS; inspect compatible coastal wall parts before preparing its missing profile.')
    if serial in [10656,10658]:
        return 'whole_fort_tower', 'forest_falan_fort_parts.gd::prepare', 'Existing round hood/brace variant; preserve source footprint and use existing native frame.'
    if serial in range(10748,10767):
        return 'native_ground_drawings', 'forest_original_maps.gd::build (floor surfaces)', 'Original transparent ground drawings need an original-art decal/floor input; no solid prop or invented physics.'
    if serial in [11095,11096,11097]:
        return 'growing_wheat', 'forest_wind_meadow_assets.gd (compatible foliage parts)', 'Source is standing growing wheat; no exact recipe identified. Prepare a measured crown/stem variant using existing foliage parts, never hay piles or generic boxes.'
    if kind == 'tree' or serial == 10000:
        return 'source_fit_trees', 'forest_west_route_scenery.gd::{tree_fit,build} / forest_ruby_region_art.gd::tree_fit', 'Reuse whole Meadow trees with source measured crown/height/palette. Pair source station input and culling; do not broaden route spans alone.'
    if kind == 'floor':
        return 'native_floor_props', 'forest_original_maps.gd::build (floor surfaces)', 'Source ground attribute alone does not establish the correct floor/decal height or existing outdoor dispatch.'
    if kind.startswith('detail_') or kind.startswith('coast_') or kind.startswith('inn_'):
        return kind, 'forest_original_map_details.gd::{kind,build}', 'Existing serial-specific detail family; append only where its measured scene owner actually invokes this family.'
    if kind == 'prop':
        if serial in east_props:
            mode = east_props[serial]['mode']
            return 'existing_village_'+mode, 'forest_east_village_props.gd::mesh', 'Existing exact-serial '+mode+' recipe; preserve prepared native paint and footprint, and inspect source/normal-camera fit before outdoor append.'
        if serial in [10620,10631,10632]:
            return 'city_pier_quay', 'forest_falan_fortifications.gd::bridges / forest_falan_courtyard.gd::parapet', 'Reuse existing quay/pier body; review city visible callback and source anchor transform before adding any duplicate.'
        if serial == 11004:
            return 'whole_laundry_frame', 'forest_falan_street_details.gd::prepare', 'Reuse the prepared whole11004 compound, including native projected foot and existing cloth/support geometry.'
        if serial == 10416:
            return 'metal_noticeboard', 'forest_falan_street_details.gd::prepare', 'Reuse existing source-specific metal board, with exact native orientation and foot alignment.'
        if serial == 10424:
            return 'native_street_lamp', 'forest_falan_lamps.gd::shape', 'Reuse existing native lamp model and prepared metal paint.'
        if serial == 10035:
            return 'native_flower_display', 'forest_falan_gardens.gd', 'Existing city garden display variant; measure whole source profile before reusing it outside the city.'
        return 'unresolved_native_prop', 'existing source-specific scenery/architecture libraries', 'Default prop kind is not an acceptable generic box/card. Inspect the original serial and compatible whole model/parts, then add the smallest missing recipe.'
    if kind in ['rock','boulder','branch','grass','plant','flowers','arena_flower','leafy_shrub']:
        return 'native_'+kind, 'forest_west_route_scenery.gd::details / forest_original_map_solids.gd::mesh', 'Reuse compatible exact-source detail/foliage form and prepared palette; verify correct family dispatch and footprint.'
    return 'native_'+kind, 'forest_original_map_solids.gd::mesh', 'Existing named kind is a reuse candidate, not verified outdoor ownership or a visual match; inspect serial-specific dispatch before appending.'


def inventory(data):
    sys.path.insert(0, str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    from build_freyja_outlying import is_water
    outdoor = REPORT/'Freyja full-source outdoors'
    contracts = json.loads((outdoor/'Before assets/owner-contracts.json').read_text())['areas']
    full = json.loads((outdoor/'Prepared full/provenance.json').read_text())
    active_path = ROOT/'assets/maps/falan/freyja_residual/full/provenance.json'
    active = json.loads(active_path.read_text())
    source_path = outdoor/'Full source/100.dat'; raw = source_path.read_bytes()
    w, h, ground, objects, flags = lib.parse_map(raw)
    assert hashlib.sha256(raw).hexdigest() == data['source_sha256'] == full['source_sha256']
    client_path = ROOT.parent/'Magic Power/data/crossgate/source/BlueCrossgate/map/0/100.dat'
    _, _, cg, co, cf = lib.parse_map(client_path.read_bytes())
    walk = navigation_grid(w, h, ground, objects, lib.serial_index())
    kinds = json.loads((OUT/'native-kinds.json').read_text())
    assert kinds['source_sha256'] == data['source_sha256'] and kinds['anchors'] == 6943
    gaps = json.loads((UNION/'source-art-without-declaration.json').read_text())
    visible = [r for r in gaps if str(r['serial']) in data['graphics']]
    assert len(visible) == 6943 and len({key(r) for r in visible}) == len(visible)
    frozen_keys = {key(r) for r in visible}
    current_scenery = json.loads((ROOT/'assets/maps/falan/venoa_field/scenery.json').read_text())
    before_scenery = json.loads((REPORT/'Freyja full-source scenery/Before source/scenery.json').read_text())
    staged_scenery = json.loads((REPORT/'Freyja full-source scenery/Prepared/scenery.json').read_text())
    assert current_scenery['placements'][:80] == before_scenery['placements']
    published = {key(r) for r in current_scenery['placements']} - {key(r) for r in before_scenery['placements']}
    offshore = {key(r) for r in staged_scenery['offshore_placements']} - {key(r) for r in current_scenery['offshore_placements']}
    assert len(published) == 52 and published <= frozen_keys
    assert len(offshore) == 35 and offshore <= frozen_keys and not published & offshore
    existing = existing_owner_candidates(contracts, frozen_keys, lib)
    assert not published & existing.keys()
    masks = {name: {r['area']: Image.open(folder/(r['area']+'-surface.png')).convert('RGBA') for r in contracts}
             for name, folder in [('active', active_path.parent), ('full', outdoor/'Prepared full')]}
    mask_checks = 0
    for name, metadata in [('active', active), ('full', full)]:
        for area, image in masks[name].items():
            assert list(image.size) == metadata['areas'][area]['size']; mask_checks += 1
            assert hashlib.sha256(image.tobytes()).hexdigest() == metadata['areas'][area]['rgba_sha256']; mask_checks += 1
    east_props = {int(s): g for s,g in json.loads((ROOT/'assets/maps/falan/east_village_props/data.json').read_text())['graphics'].items()}
    stations = []; families = {}; checks = mask_checks
    for gap in visible:
        x, y, serial = key(gap); index = y*w+x; graphic = data['graphics'][str(serial)]
        assert objects[index] == serial and (co[index] == serial or co[index] == 0); checks += 1
        assert cg[index] == 0 or cg[index] == ground[index]; checks += 1
        kind = kinds['graphics'][str(serial)]['kind']; name, reuse, recipe = family(serial, kind, east_props)
        families[name] = dict(renderer='scripts/forest/'+reuse if reuse.startswith('forest_') else reuse, preparation=recipe)
        east, south = graphic['footprint']; centre = [x+(east-1)/2, y-(south-1)/2]
        owners = []
        for contract in contracts:
            area = contract['area']; row = full['areas'][area]
            local = inverse(contract['frame'], [x*3,y*3]); centre_local = inverse(contract['frame'], [v*3 for v in centre])
            pixel = [(local[k]-row['origin'][k])/3 for k in (0,1)]
            cp = [(centre_local[k]-row['origin'][k])/3 for k in (0,1)]
            corners = [inverse(contract['frame'], [xx*3,yy*3]) for xx in [x,x+east-1] for yy in [y,y-south+1]]
            pixels = [[(p[k]-row['origin'][k])/3 for k in (0,1)] for p in corners]
            inside = all(0 <= pixel[k] < row['size'][k] for k in (0,1))
            centred = all(0 <= cp[k] < row['size'][k] for k in (0,1))
            intersects = all(max(p[k] for p in pixels) >= 0 and min(p[k] for p in pixels) < row['size'][k] for k in (0,1))
            if not (inside or centred or intersects):
                continue
            samples = {}
            for label, metadata in [('active',active),('full',full)]:
                p = [(local[k]-metadata['areas'][area]['origin'][k])/3 for k in (0,1)]
                im = masks[label][area]
                samples[label] = list(im.getpixel(tuple(map(round,p)))) if all(0 <= round(p[k]) < im.size[k] for k in (0,1)) else None
            owners.append(dict(area=area, canonical_area=contract['canonical_area'], local_anchor=local,
                               mask_pixel=pixel, centre_local=centre_local, anchor_inside=inside,
                               footprint_centre_inside=centred, footprint_intersects=intersects, mask_anchor_rgba=samples))
        state = 'published_headland' if (x,y,serial) in published else 'existing_owner_requires_filter_audit' if (x,y,serial) in existing else 'root_staged_offshore' if (x,y,serial) in offshore else 'requires_append_or_recipe'
        stations.append(dict(cell=[x,y],serial=serial,family=name,native_kind=kind,footprint=[east,south],footprint_centre=centre,
            source_floor=ground[index],source_decoder_open=bool(walk[index]),client_object=co[index],client_ground=cg[index],
            source_surface_domain='water' if is_water(ground[index]) else 'control100' if ground[index]==100 else 'source0' if not ground[index] else 'dry',
            source_recorded_flag=bool(cf[index]&0xc000),server_only_object=co[index]==0,
            reconciliation=state,existing_owner_candidates=existing.get((x,y,serial),[]),owner_candidates=owners,
            water_visual_owner='forest_venoa_southwest_scenery.gd::build' if (x,y,serial) in offshore else None,
            catalog_ready=bool(graphic['matching_catalogs']),rgba_sha256=graphic['rgba_sha256']))
    assert len(stations) == 6943
    assert sum(r['reconciliation']=='published_headland' for r in stations) == 52
    assert sum(r['reconciliation']=='root_staged_offshore' for r in stations) == 35
    groups = defaultdict(list)
    for row in stations:
        if row['reconciliation'] not in ['requires_append_or_recipe','root_staged_offshore']:
            continue
        for owner in row['owner_candidates']:
            if owner['anchor_inside'] or owner['footprint_centre_inside']:
                groups[(row['family'], owner['area'])].append(dict(cell=row['cell'],serial=row['serial'],
                    server_only_object=row['server_only_object'],local_anchor=owner['local_anchor'],
                    footprint_centre=row['footprint_centre'],footprint=row['footprint'],reconciliation=row['reconciliation'],
                    source_floor=row['source_floor'],source_surface_domain=row['source_surface_domain'],source_decoder_open=row['source_decoder_open']))
    plan = [dict(family=name,area=area,canonical_area=next(r['canonical_area']for r in contracts if r['area']==area),
                 renderer=families[name]['renderer'],preparation=families[name]['preparation'],
                 server_only_stations=[r for r in rows if r['server_only_object']],
                 client_stations=[r for r in rows if not r['server_only_object']]) for (name,area),rows in sorted(groups.items())]
    plan.append(dict(family='root_reserved_offshore',area='source_water',canonical_area='south_lakes',
        renderer='scripts/forest/forest_venoa_southwest_scenery.gd::build',
        preparation='Root already staged35 exact original stations through the existing water/prop owner. Keep at existing water height; no land, support, navigation or physical obstacles.',
        server_only_stations=[dict(cell=r['cell'],serial=r['serial'],family=r['family'])for r in stations if r['reconciliation']=='root_staged_offshore' and r['server_only_object']],
        client_stations=[dict(cell=r['cell'],serial=r['serial'],family=r['family'])for r in stations if r['reconciliation']=='root_staged_offshore' and not r['server_only_object']]))
    planned = {(row['cell'][0],row['cell'][1],row['serial'])for group in plan for name in ['server_only_stations','client_stations']for row in group[name]}
    assert planned == {key(r)for r in stations if r['reconciliation']in ['requires_append_or_recipe','root_staged_offshore']}; checks += 1
    states = Counter(r['reconciliation']for r in stations)
    owner_counts = {area:{'candidate_anchors':sum(any(o['area']==area for o in r['owner_candidates'])for r in stations),
                         'append_candidates':sum(len(p['server_only_stations'])+len(p['client_stations'])for p in plan if p['area']==area),
                         'server_only_append_candidates':sum(len(p['server_only_stations'])for p in plan if p['area']==area)}for area in full['areas']}
    summary = dict(schema=1,source_sha256=data['source_sha256'],active_source_sha256=active['source_sha256'],
        frozen_visible_gap_anchors=6943,frozen_transparent_gap_anchors=len(gaps)-6943,
        reconciliation=dict(states),fresh_missing_input_declarations=6943-52,
        server_only_by_reconciliation={state:sum(r['reconciliation']==state and r['server_only_object']for r in stations)for state in states},
        existing_owner_candidates={owner:len({key(r)for r in stations if any(c['owner']==owner for c in r['existing_owner_candidates'])})for owner in ['city_street','il_village','alyut']},
        server_only_objects=sum(r['server_only_object']for r in stations),
        raw_catalog_missing_graphics=sum(not g['matching_catalogs']for g in data['graphics'].values()),
        raw_catalog_missing_anchors=sum(not r['catalog_ready']for r in stations),
        raw_catalog_missing_serials={serial:g['anchors']for serial,g in data['graphics'].items()if not g['matching_catalogs']},
        families={name:dict(families[name],anchors=sum(r['family']==name for r in stations),
            append_candidates=sum(r['family']==name and r['reconciliation']in ['requires_append_or_recipe','root_staged_offshore']for r in stations),
            serials=sorted({r['serial']for r in stations if r['family']==name}))for name in sorted(families)},
        owner_candidates=owner_counts,multiple_owner_candidates=sum(len(r['owner_candidates'])>1 for r in stations),
        owner_contracts={row['area']:dict(canonical_area=row['canonical_area'],frame=row['frame'],
            active_origin=active['areas'][row['area']]['origin'],active_size=active['areas'][row['area']]['size'],
            full_origin=full['areas'][row['area']]['origin'],full_size=full['areas'][row['area']]['size'],
            active_rgba_sha256=active['areas'][row['area']]['rgba_sha256'],full_rgba_sha256=full['areas'][row['area']]['rgba_sha256'])for row in contracts},
        input_sha256={str(path.relative_to(ROOT)):sha(path)for path in [Path(__file__),client_path,active_path,
            outdoor/'Prepared full/provenance.json',outdoor/'Before assets/owner-contracts.json',
            ROOT/'assets/maps/falan/city_street_data.gd',ROOT/'assets/maps/falan/venoa_field/scenery.json',
            REPORT/'Freyja full-source scenery/Before source/scenery.json',REPORT/'Freyja full-source scenery/Prepared/scenery.json']if path.is_relative_to(ROOT)},
        outside_all_owner_candidates=[dict(cell=r['cell'],serial=r['serial'],family=r['family'])for r in stations if not r['owner_candidates']],
        checks=checks+10,worlds_constructed=0,meshes_constructed=0,
        limits=['Frozen 6943 is a historical input gap count, not a fresh rendered absence count. 52 published headland stations are reconciled without rewriting it.',
                'Exact city/joined-village source-ID/station evidence requires renderer/clip/filter review; these candidates are held out of append lists to avoid duplicates.',
                'Owner candidates preserve all seven envelopes and east_coast/east_gate alias semantics. Lists overlap deliberately; select/integrate through each existing scene owner, not one global station backend.',
                'Append plan is source data only. No runtime, assets, source activation, Images, imports, collision or navigation changed.',
                'Generic prop boxes/cards are not a recovery plan. Named reuse candidates require original-art shape review and normal gameplay cameras; missing recipes and raw catalog gaps stay explicit.',
                'Source100 controls/transparent markers do not authorize visible meshes or waterwalk. Source decoder-open is not a finite-radius native reachability proof.'])
    OUT.mkdir(parents=True,exist_ok=True)
    for name,payload in [('stations.json',stations),('append-plan.json',plan),('inventory.json',summary)]:
        (OUT/name).write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
    # A small source-only study is a review order, never a filter on required whole-map coverage.
    clusters = defaultdict(list)
    for row in stations:
        if row['server_only_object'] and row['reconciliation']=='requires_append_or_recipe' and row['source_surface_domain']=='dry':
            for owner in row['owner_candidates']:
                if owner['anchor_inside'] and owner['area']==owner['canonical_area']:
                    clusters[(owner['area'],row['cell'][0]//8,row['cell'][1]//8)].append(row)
    studies = []
    for (area,bx,by),rows in sorted(clusters.items(),key=lambda item:(-len(item[1]),item[0]))[:12]:
        studies.append(dict(area=area,source_bounds=[bx*8,by*8,8,8],anchors=len(rows),families=dict(Counter(r['family']for r in rows)),
            stations=[dict(cell=r['cell'],serial=r['serial'],family=r['family'],source_floor=r['source_floor'])for r in rows],
            required_review='Original composite versus fixed normal gameplay camera; prove the existing owner dispatches every source station, preserve full terrain/collision/source layout, then extend the same family through all required inputs.'))
    (OUT/'source-only-study-order.json').write_text(json.dumps(studies,ensure_ascii=False,indent=2)+'\n')
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare-inputs', action='store_true')
    args = parser.parse_args()
    data = inputs()
    if not args.prepare_inputs:
        summary = inventory(data)
        print('FREYJA_ART_INVENTORY', json.dumps({k:summary[k]for k in ['reconciliation','existing_owner_candidates','server_only_objects','raw_catalog_missing_graphics','raw_catalog_missing_anchors','multiple_owner_candidates','checks']},sort_keys=True))
    print('FREYJA_ART_INPUTS', len(data['graphics']), 'graphics /', data['visible_gap_anchors'], 'visible source anchors; runtime unchanged')


if __name__ == '__main__':
    main()
