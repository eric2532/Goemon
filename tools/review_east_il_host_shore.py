"""Read-only source100 bank/control components and private Il host height interfaces."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

from PIL import Image
from prepare_east_il_low_host import BOUNDS, OUT, ROOT
from prepare_east_region_maps import reference_map
from prepare_east_region_field import source_area, source_pixel


def main():
    sys.path.insert(0, str(ROOT.parent/'Magic Power/tools'))
    import cg_library as lib
    from prepare_field_assets import navigation_grid
    paths = {'reference':ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Version Expansion Source Audit/map__00100_field1',
             'active':ROOT/'assets/maps/falan/freyja_source/100.dat', 'private_host':OUT/'100.dat'}
    width, height, original, _ = reference_map(paths['reference'].read_bytes(),100)
    cells = width*height; lookup = lib.serial_index(); x0,z0,sx,sz = BOUNDS
    inside = lambda i: x0 <= i%width < x0+sx and z0 <= i//width < z0+sz
    full = (original[:cells], original[cells:])
    private = lib.parse_map(paths['private_host'].read_bytes())[2:4]
    active = lib.parse_map(paths['active'].read_bytes())[2:4]
    masks = {area:Image.open(ROOT/f'assets/maps/falan/east_region/{area}-surface.png').size for area in ['east_gate','north_coast']}
    city = Image.open(ROOT/'assets/maps/falan/city_surface.png').convert('RGBA')
    alyut_folder = ROOT/'assets/maps/falan/east_region/alyut_source_completion'
    alyut_handoffs = json.loads((alyut_folder/'gate-handoffs.json').read_text())
    alyut_overlaps = json.loads((alyut_folder/'source-overlaps.json').read_text())
    alyut_banks = json.loads((alyut_folder/'banks.json').read_text())
    field_exceptions = {tuple(r['field_cell']) for r in alyut_handoffs['handoff_cells']+alyut_overlaps['source100_overlap_cells']}
    exact_bank_graphics = {(int(r['source_cell'][0])+529,int(r['source_cell'][1])+20):int(r['serial']) for r in alyut_banks['rows']}
    def owner(i):
        x,z = i%width,i//width; area = source_area(x,z); px,pz = source_pixel(area,x,z)
        return area if 0 <= px < masks[area][0] and 0 <= pz < masks[area][1] else 'outside_current_east_envelopes'
    def component(bg,pg):
        walk = navigation_grid(width,height,bg,pg,lookup)
        wet = {i for i in range(cells) if walk[i] and (pg[i] == 252 or 12500 <= pg[i] < 12536)}
        pending = [i for i in wet if inside(i)]; seen = set(pending)
        for i in pending:
            x,z = i%width,i//width
            for nx,nz in [(x-1,z),(x+1,z),(x,z-1),(x,z+1)]:
                j = nz*width+nx
                if 0 <= nx < width and 0 <= nz < height and j in wet and j not in seen:
                    seen.add(j); pending.append(j)
        return walk,seen
    def groups(selected):
        remaining = set(selected); sizes = []
        while remaining:
            seed = min(remaining); remaining.remove(seed); pending = [seed]
            for i in pending:
                x,z = i%width,i//width
                for nx,nz in [(x-1,z),(x+1,z),(x,z-1),(x,z+1)]:
                    j = nz*width+nx
                    if 0 <= nx < width and 0 <= nz < height and j in remaining:remaining.remove(j);pending.append(j)
            sizes.append({'cells':len(pending),'source_bounds_inclusive':[min(i%width for i in pending),min(i//width for i in pending),max(i%width for i in pending),max(i//width for i in pending)]})
        return sorted(sizes,key=lambda r:-r['cells'])
    def contextual_owner(i):
        x,z = i%width,i//width
        if x < 440:return 'outside_goal_west'
        if 529 <= x < 629 and 20 <= z < 120 and (x,z) not in field_exceptions:return 'protected_full_alyut_source2400'
        if owner(i) == 'east_gate':
            local_x,local_z = 591-z*3,x*3-1251
            cx,cz = -135-local_x,-225-local_z
            px,pz = (cx+402)//3,(cz+438)//3
            if local_z < 54 and 0 <= px < city.width and 0 <= pz < city.height and city.getpixel((px,pz))[3] >= 128:return 'protected_falan_city1000'
        return owner(i)
    results = {}; components = {}
    for name,(bg,pg) in [('active',active),('private_host',private),('pinned_full',full)]:
        walk,seen = component(bg,pg); components[name] = seen
        outside = seen-{i for i in seen if inside(i)}
        results[name] = {'component_cells':len(seen), 'inside_host_window':len(seen)-len(outside), 'outside_host_window':len(outside),
                         'seeded_wet_component_count':len(groups(seen)), 'seeded_wet_components':groups(seen),
                         'source_bounds_inclusive':[min(i%width for i in seen),min(i//width for i in seen),max(i%width for i in seen),max(i//width for i in seen)],
                         'inside_east_branch_x440_or_greater':sum(i%width >= 440 for i in seen), 'outside_east_branch_x440_boundary':sum(i%width < 440 for i in seen),
                         'current_east_owner_counts':dict(Counter(owner(i) for i in seen)),
                         'contextual_owner_counts':dict(Counter(contextual_owner(i) for i in seen)),
                         'outside_window_owner_counts':dict(Counter(owner(i) for i in outside)),
                         'kinds':dict(Counter('control252' if pg[i]==252 else 'bank' for i in seen))}
    bg,pg = private; walk = navigation_grid(width,height,bg,pg,lookup); edges = []
    full_walk = navigation_grid(width,height,full[0],full[1],lookup)
    goal_wet = {i for i in range(cells) if i%width >= 440 and owner(i) != 'outside_current_east_envelopes' and full_walk[i] and (full[1][i]==252 or 12500 <= full[1][i] < 12536)}
    other_goal_wet = goal_wet-components['pinned_full']
    def row(i):
        serial = int(pg[i]); tile = int(bg[i])
        return {'cell':[i%width,i//width], 'floor':tile, 'object':serial, 'native_open':bool(walk[i]), 'owner':owner(i),
                'contextual_owner':contextual_owner(i), 'matches_current_full_alyut_bank':exact_bank_graphics.get((i%width,i//width))==serial,
                'kind':'bank' if 12500 <= serial < 12536 else 'control252' if serial == 252 else 'water' if 5000 <= tile <= 5008 else 'dry'}
    for z in range(z0,z0+sz):
        for x in range(x0,x0+sx):
            i = z*width+x
            if not walk[i]:continue
            for nx,nz in [(x-1,z),(x+1,z),(x,z-1),(x,z+1)]:
                j = nz*width+nx
                if 0 <= nx < width and 0 <= nz < height and not inside(j) and walk[j]:edges.append({'inside':row(i),'outside':row(j)})
    assert len(edges) == 77
    edge_counts = Counter(e['inside']['kind']+'→'+e['outside']['kind'] for e in edges)
    report = {'scope':'PRIVATE read-only source100 shore investigation. Raw unknown-only fill is a separate artifact; no live heights, masks, owners, cells or collision changed.',
              'source_host_window':BOUNDS, 'components':results, 'host_open_boundary_edges':edges, 'host_open_boundary_counts':dict(edge_counts),
              'private_connected_shore_rows':[row(i) for i in sorted(components['private_host'])],
              'protected_context_rows':[row(i) for i in sorted(components['private_host']) if contextual_owner(i).startswith('protected_')],
              'whole_east_shore_inventory':{'native_open_bank_control_cells':len(goal_wet),'host_seeded_union_cells':len(goal_wet&components['pinned_full']),
                                            'other_east_shore_cells':len(other_goal_wet),'other_east_shore_owner_counts':dict(Counter(contextual_owner(i) for i in other_goal_wet)),
                                            'other_east_shore_components':groups(other_goal_wet),
                                            'other_east_shore_rows':[{'cell':[i%width,i//width],'floor':int(full[0][i]),'object':int(full[1][i]),'owner':contextual_owner(i)} for i in sorted(other_goal_wet)]},
              'additional_pinned_shore_rows':[{'cell':[i%width,i//width], 'floor':int(full[0][i]), 'object':int(full[1][i]), 'owner':owner(i)} for i in sorted(components['pinned_full']-components['private_host'])],
              'source_hashes':{str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in [*paths.values(),Path(__file__),ROOT/'tools/prepare_east_region_field.py',
                                                                                                           alyut_folder/'banks.json',alyut_folder/'gate-handoffs.json',alyut_folder/'source-overlaps.json',ROOT/'assets/maps/falan/city_surface.png']},
              'height_constraints':[
                  'All77original-open boundary adjacencies must remain continuous; a uniformly lowered host rectangle alone fails its12wet interfaces.',
                  'Absolute6m joined-land height is inferred, not a native-source requirement. Marker252support at6m over visible2mwater is not an acceptable reconstruction.',
                  'Keep original2000low frame2.10/2m and exact fixed transfers independent of this source100shore scope.',
                  'Private source100shore grade should keep original-open control252floors at2m and native bank lips near2.10m; spread any inland rise through existing dry source geometry, not invisible air bridges or140newstairs.',
                  'Before geometry: intersect native-connected wet components with current east_gate/north_coast envelopes, connectedAlyut exact owner exclusions and explicit Falan/West goal boundaries. Retain every original adjacency as an individual check.',
                  'New source100raw tuple completion outside the9990cell window is not authorized by this preparer and is not performed here. Missing available-source areas remain actionable work.'],
              'acceptance_pending':['Measured bounded shore/inland height proposal and all77interface segments at1.3worldscale/fourradii.',
                                    'Exact owner preemption for canonicalFullAlyut117banks/12gatebuffers/6overlap cells before any private extension there.',
                                    'Original100closed-water/player/nativepet preservation and exact681,343entry/682,343return actual replay.']}
    OUT.mkdir(parents=True,exist_ok=True); (OUT/'shore-interface-plan.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'components':results,'host_open_boundary_counts':dict(edge_counts)},indent=2))


if __name__ == '__main__':main()
